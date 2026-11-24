extends GutTest
## Menu-screen behaviour through the real main scene: leaving a run from the
## settings panel (with its confirm step, also mid-match) and the HUD's points
## feedback (a sound whenever the run's points change).

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")

var ui: UiDriver
var _heard: Array[String] = []


func before_each() -> void:
	ui = UiDriver.new(self, "menus")
	await ui.start()
	_heard.clear()
	Sfx.played.connect(_on_played)


func after_each() -> void:
	Sfx.played.disconnect(_on_played)
	await ui.stop()


func _on_played(id: String) -> void:
	_heard.append(id)


func _settings() -> SettingsPanel:
	for overlay: Node in ui.overlays():
		if overlay is SettingsPanel:
			return overlay
	return null


func test_title_settings_offer_no_leave_run() -> void:
	assert_eq(ui.screen_name(), "TITLE")
	ui.press_key(KEY_F1)
	await ui.frames(2)
	assert_not_null(_settings(), "F1 opens settings on the title")
	assert_null(ui.button("Leave run", _settings()), "no run to leave on the title")


func test_leave_run_mid_match_asks_first_then_returns_to_the_title() -> void:
	Game.new_run(6)
	Game.run.choose_piece_set("standard")
	assert_true(await ui.show_crafted_match(
		[["king", 2, 0], ["pawn", 0, 1], ["knight", 1, 0]],
		[["king", 2, 5], ["pawn", 4, 4]],
		["pawn", "knight", "move", "move", "pawn"], ["move", "move", "move", "move", "move"]))
	ui.press_key(KEY_F1)
	await ui.frames(2)
	var panel := _settings()
	assert_not_null(panel)
	var ask := ui.button("Leave run…", panel)
	assert_not_null(ask, "a run is active: leaving is offered")
	assert_true(ui.press(ask))
	await ui.frames(2)
	assert_eq(ui.screen_name(), "MATCH", "the first press only asks")
	assert_not_null(Game.run)
	assert_true(ui.press(ui.button("Stay", panel)), "Stay takes the question back")
	await ui.frames(2)
	assert_eq(ui.screen_name(), "MATCH")
	assert_true(ui.press(ui.button("Leave run…", panel)))
	await ui.frames(1)
	var confirm: Button = null
	for node: Button in ui.buttons("Leave run", panel):
		if node.text == "Leave run":
			confirm = node
	assert_not_null(confirm, "the confirm button")
	assert_true(ui.press(confirm))
	ui.force_press(confirm)  # a double press is ignored
	assert_true(await ui.wait_screen("TITLE"), "back to the title")
	assert_null(Game.run, "the run is dropped")
	assert_true(ui.overlays().is_empty(), "the panel closed")
	await ui.frames(10)  # the freed match must not resume anything
	assert_true(ui.press(ui.button("New Game")), "a new run can start")
	assert_true(await ui.wait_screen("SET_SELECT"))


func test_hud_points_change_is_heard() -> void:
	Game.new_run(6)
	Game.run.choose_piece_set("standard")
	Game.run.choose_node(Game.run.available_nodes()[0])
	Game.run.build_match_setup(Game.run.default_roster())
	Game.run.finish_match({"winner": 0, "reason": "score", "scores": [10, 4]})
	_heard.clear()
	Game.show_phase()
	assert_true(await ui.wait_screen("REWARD"))
	await ui.frames(2)
	assert_true(_heard.has("score_tick"), "the win's points pop on the HUD with a tick")
	_heard.clear()
	OS.delay_msec(100)  # past score_tick's cooldown (real time; the driver speeds up game time)
	assert_true(ui.press(ui.button("Skip")))
	assert_true(await ui.wait_screen("MAP"))
	await ui.frames(2)
	assert_true(_heard.has("score_tick"), "the skip's point pops on the HUD with a tick")


func _send_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await ui.frames(2)


func test_roster_keyboard_chooses_the_square() -> void:
	Game.new_run(6)
	Game.run.choose_piece_set("standard")
	Game.run.choose_artifacts([])
	Game.show_phase()
	assert_true(await ui.wait_screen("MAP"))
	assert_true(ui.click_map_node(ui.screen()._map_view.choices()[0]))
	assert_true(await ui.wait_screen("MATCH_SETUP"))
	assert_true(ui.press(ui.button("Bench all", ui.screen())))
	await ui.frames(1)
	var row: RosterRow = ui._benched_row("knight")
	var knight: PieceData = row.piece  # rows are rebuilt on every change
	row.grab_focus()
	await _send_action(&"ui_accept")
	var cursor: Control = ui.screen()._cursor
	assert_true(cursor.has_focus(), "Enter on a benched piece puts the cursor on the board")
	var start: Vector2i = cursor.square
	await _send_action(&"ui_right")
	await _send_action(&"ui_up")
	var target := start + Vector2i(1, 1)
	assert_eq(cursor.square, target, "arrows walk the deploy squares")
	await _send_action(&"ui_up")
	assert_eq(cursor.square, target, "the cursor stays on your deploy ranks")
	await _send_action(&"ui_accept")
	assert_not_null(ui.board().token(knight.uid), "Enter places the piece")
	assert_eq(ui.board().token_square(knight.uid), target, "on the chosen square")
	assert_false(cursor.has_focus(), "focus goes back to the list")
	# Esc puts a picked piece back.
	var bishop_row: RosterRow = ui._benched_row("bishop")
	var bishop: PieceData = bishop_row.piece
	bishop_row.grab_focus()
	await _send_action(&"ui_accept")
	assert_true(cursor.has_focus())
	await _send_action(&"ui_cancel")
	assert_null(ui.board().token(bishop.uid), "Esc cancels: nothing placed")
	assert_eq(ui.screen_name(), "MATCH_SETUP", "and settings did not open")
	assert_true(ui.overlays().is_empty())


func test_large_text_rebuilds_the_theme_at_once() -> void:
	var body_size := func() -> int: return ui.main.theme.get_font_size("font_size", "Body")
	assert_eq(body_size.call(), UiTheme.BODY)
	Settings.set_value("large_text", true)
	assert_eq(body_size.call(), UiTheme.BODY + UiTheme.LARGE_TEXT_STEP, "applied live")
	Settings.set_value("large_text", false)
	assert_eq(body_size.call(), UiTheme.BODY)
