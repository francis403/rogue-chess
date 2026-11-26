extends GutTest
## Through the real UI scenes: a run with unlocks pre-seeded (artifact step shown,
## artifacts selectable, Fire selectable) and the loss path (skip every turn ->
## defeat -> run end with an artifact unlock -> next run shows the artifact step).

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")
const REAL_META_PATH := "user://meta.json"
const RunEndScreen := preload("res://scripts/ui/screens/run_end_screen.gd")

var ui: UiDriver


func after_each() -> void:
	await ui.stop()


func test_second_run_with_unlocks_shows_artifacts_and_fire() -> void:
	var real_meta_before := UiDriver.read(REAL_META_PATH)
	var pool: Array = GameConfig.data("artifacts")["unlock_pool"]
	ui = UiDriver.new(self, "unlocked_run")
	await ui.start(["fire"], pool)

	# Title shows the unlock progress read from the (temp) meta file.
	assert_true(_has_label(ui.screen(), "2 / 2 unlocked"), "both piece sets shown as unlocked")
	assert_true(_has_label(ui.screen(), "%d / %d unlocked" % [pool.size(), pool.size()]), "every artifact shown as unlocked")

	assert_true(ui.press(ui.button("New Game")))
	assert_true(await ui.wait_screen("SET_SELECT"))
	var tiles := ui.select_tiles()
	assert_eq(tiles.size(), 2)
	assert_false(tiles[1].is_locked, "Fire is selectable once unlocked")
	ui.click(tiles[1])
	ui.click(tiles[1])  # double click: the second pick is refused, nothing doubles
	assert_true(await ui.wait_screen("ARTIFACT_SELECT"), "artifacts are unlocked, so the artifact step is shown")
	assert_eq(Game.run.piece_set, "fire")
	assert_eq(Game.run.collection.size(), 16, "one starting collection, not two")
	for piece in Game.run.collection:
		assert_eq(piece.piece_set, "fire")

	# Artifact step: one tile per unlocked artifact, at most 2, toggling works.
	var available := Game.run.available_artifacts()
	tiles = ui.select_tiles()
	assert_eq(tiles.size(), pool.size())
	ui.click(tiles[0])
	ui.click(tiles[1])
	ui.click(tiles[2])  # a third pick is refused
	assert_true(tiles[0].is_selected and tiles[1].is_selected)
	assert_false(tiles[2].is_selected, "at most %d artifacts" % Game.run.max_starting_artifacts())
	assert_true(_has_label(ui.screen(), "at most 2"), "the refusal is explained")
	ui.click(tiles[0])  # deselect
	ui.click(tiles[2])
	assert_false(tiles[0].is_selected)
	assert_true(tiles[1].is_selected and tiles[2].is_selected)
	assert_true(_has_label(ui.screen(), "2 / 2 chosen"))
	assert_true(ui.press(ui.button("Continue to the map")))
	assert_true(await ui.wait_screen("MAP"))
	var chosen: Array[String] = [available[1]["id"], available[2]["id"]]
	assert_eq(Game.run.artifacts, chosen)

	# The chosen artifacts reach the match.
	assert_true(ui.click_map_node("M1"))
	assert_true(await ui.wait_screen("MATCH_SETUP"))
	assert_true(ui.press(ui.button("Start match")), "the default Fire roster is valid")
	assert_true(await ui.wait_screen("MATCH"))
	assert_true(await ui.wait_match_idle())
	assert_eq(ui.game().artifacts(ChessMatch.PLAYER), chosen)
	for artifact_id: String in chosen:
		assert_true(_has_label(ui.screen(), Ui.artifact_name(artifact_id)), "%s chip shown in the match" % artifact_id)
	for piece in ui.game().pieces(ChessMatch.PLAYER):
		if piece.type != "king":
			assert_eq(piece.data.piece_set, "fire")
	assert_eq(UiDriver.read(REAL_META_PATH), real_meta_before, "the real meta.json is never touched")


func test_losing_by_skipping_every_turn_ends_the_run_with_an_artifact_unlock() -> void:
	var started := Time.get_ticks_msec()
	var real_meta_before := UiDriver.read(REAL_META_PATH)
	ui = UiDriver.new(self, "loss_run")
	await ui.start()
	assert_true(ui.press(ui.button("New Game")))
	assert_true(await ui.wait_screen("SET_SELECT"))
	Game.new_run(3)
	assert_true(await ui.wait_screen("SET_SELECT"))
	ui.click(ui.select_tiles()[0])
	assert_true(await ui.wait_screen("MAP"))
	assert_true(ui.click_map_node("L1"))
	assert_true(await ui.wait_screen("MATCH_SETUP"))
	assert_true(ui.press(ui.button("Start match")))
	assert_true(await ui.wait_screen("MATCH"))
	assert_true(await ui.wait_match_idle())

	# Skip every turn; each press passes exactly one turn.
	var turns := 0
	while not ui.game().is_over() and turns < 60:
		var round_before := ui.game().current_round()
		ui.check_idle_invariants()
		var end_turn := ui.button("End turn", ui.screen())
		assert_true(ui.press(end_turn))
		ui.force_press(end_turn)  # double press: ignored while the turn is handed over
		assert_true(await ui.wait_player_turn(), "opponent turn finished")
		if not ui.game().is_over():
			assert_eq(ui.game().current_round(), round_before + 1, "one press = one skipped turn")
		turns += 1
	assert_true(ui.game().is_over(), "the opponent wins against a player who always skips")
	assert_eq(ui.game().result()["winner"], ChessMatch.OPPONENT)
	assert_true(_has_label(ui.screen(), "Defeat"))

	var button := ui.button("See the run summary", ui.screen())
	assert_not_null(button, "a loss offers the run summary")
	assert_true(ui.press(button))
	ui.force_press(button)  # double press: finish_match must not run twice
	assert_true(await ui.wait_screen("RUN_END"))
	# The unlock opens soon after the figures (motion "unlock_hold"), not when the long
	# run stinger rings out; its fanfare takes over from the stinger.
	var run_end: Variant = ui.screen()
	var stinger_left := Sfx.stinger_time_left()
	var figures_done := Settings.time(Motion.seconds("reveal") + Motion.seconds("unlock_delay")
		+ Motion.seconds("run_count_stagger") * 4 + Motion.seconds("run_count_up"))
	var limit := figures_done + Motion.time("unlock_hold") + Settings.time(Motion.seconds("reveal")) + 0.3
	assert_gt(stinger_left, limit, "the run stinger outlasts the hold, so the hold is what's tested")
	assert_true(await ui.until(func() -> bool: return not is_instance_valid(run_end._seal), int(limit * 1000.0)),
		"the seal opens within the unlock_hold motion time of the last figure")
	assert_gt(Sfx.stinger_time_left(), 0.0, "the unlock fanfare sounds")
	var unlock := Game.run.unlock_result()
	assert_eq(unlock.get("kind"), "artifact")
	assert_true(unlock.get("is_new", false))
	assert_true(_has_label(ui.screen(), "Defeated on floor 1"))
	assert_true(_has_label(ui.screen(), Ui.artifact_name(unlock["id"])), "run end names the unlocked artifact")
	assert_true(_has_label(ui.screen(), String(unlock["text"])), "run end shows the unlock text")
	assert_eq(MetaStore.new(ui.meta_path()).unlocked_artifacts, [unlock["id"]] as Array[String], "exactly one artifact unlocked and saved")
	assert_eq(Game.run.summary()["wins"], 0)

	# The next run now has the artifact step with that one artifact.
	assert_true(ui.press(ui.button("Start new run")))
	assert_true(await ui.wait_screen("SET_SELECT"))
	assert_eq(Sfx.stinger_time_left(), 0.0, "leaving the run end fades its stinger out")
	assert_true(ui.select_tiles()[1].is_locked, "Fire is still locked after a loss")
	ui.click(ui.select_tiles()[0])
	assert_true(await ui.wait_screen("ARTIFACT_SELECT"))
	assert_eq(ui.select_tiles().size(), 1)
	assert_true(ui.press(ui.button("Continue to the map")), "taking no artifact is allowed")
	assert_true(await ui.wait_screen("MAP"))
	assert_eq(Game.run.artifacts, [] as Array[String])

	assert_eq(ui.failures, [] as Array[String])
	assert_eq(UiDriver.read(REAL_META_PATH), real_meta_before, "the real meta.json is never touched")
	gut.p("loss path took %d ms over %d skipped turns" % [Time.get_ticks_msec() - started, turns])


func _has_label(root: Node, text: String) -> bool:
	for node: Label in UiDriver.find_all(root, Label):
		if node.text.contains(text):
			return true
	return false
