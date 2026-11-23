extends GutTest
## Match keyboard shortcuts through the real viewport: 1-5 pick (and unpick) a card,
## Esc cancels, R redraws, E ends the turn; with an overlay open (deck, settings)
## none of them reaches the match underneath.

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")
const P := ChessMatch.PLAYER
const NO_SQUARE := BoardView.NO_SQUARE

var ui: UiDriver


func before_each() -> void:
	ui = UiDriver.new(self, "keyboard")
	await ui.start()
	Game.new_run(6)
	Game.run.choose_piece_set("standard")
	# Every card has a legal play: king, pawn, knight, bishop and rook all have room.
	assert_true(await ui.show_crafted_match(
		[["king", 2, 0], ["pawn", 0, 1], ["knight", 1, 0], ["bishop", 3, 0], ["rook", 5, 0]],
		[["king", 2, 5], ["pawn", 4, 4]],
		["pawn", "knight", "bishop", "move", "rook", "pawn", "knight", "move"],
		["move", "move", "move", "move", "move", "move"]))


func after_each() -> void:
	Settings.reset_bindings()
	await ui.stop()


func _selected() -> Array:
	var views := ui.hand_views()
	var picked: Array = []
	for i in views.size():
		if (views[i] as CardView).is_selected:
			picked.append(i)
	return picked


func _key(keycode: Key) -> void:
	ui.press_key(keycode)
	await ui.frames(2)


func test_number_keys_pick_and_unpick_cards() -> void:
	assert_eq(_selected(), [], "nothing selected at the start")
	await _key(KEY_1)
	assert_eq(_selected(), [0], "1 picks the first card")
	await _key(KEY_3)
	assert_eq(_selected(), [2], "3 picks the third card instead")
	await _key(KEY_3)
	assert_eq(_selected(), [], "the same key again unpicks it")
	await _key(KEY_9)
	assert_eq(_selected(), [], "a key past the hand does nothing")
	assert_eq(ui.board().targets.size() > 0, false, "no targets without a selection")


## Keys are read by position: on AZERTY the "2" key types "é" (keycode) but its
## physical code is still KEY_2; letters too (physical E ends the turn).
func test_keys_work_by_position_on_other_layouts() -> void:
	_push_key(KEY_NONE, KEY_2)
	await ui.frames(2)
	assert_eq(_selected(), [1], "physical 2 picks the second card")
	_push_key(KEY_A, KEY_2)
	await ui.frames(2)
	assert_eq(_selected(), [], "and unpicks it")
	var round_side := ui.game().current_side()
	_push_key(KEY_Z, KEY_E)
	assert_true(await ui.until(func() -> bool: return ui.screen().is_busy() or ui.game().current_side() != round_side), "physical E ends the turn")


func _push_key(keycode: Key, physical: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical
	event.pressed = true
	ui.main.get_viewport().push_input(event)
	var release := event.duplicate()
	release.pressed = false
	ui.main.get_viewport().push_input(release)


func test_esc_cancels_a_keyboard_selection() -> void:
	await _key(KEY_2)
	assert_eq(_selected(), [1])
	await _key(KEY_ESCAPE)
	assert_eq(_selected(), [], "Esc drops the card")
	assert_eq(ui.board().selected, NO_SQUARE, "and the piece")
	assert_true(ui.overlays().is_empty(), "Esc in a match never opens settings")


func test_r_redraws_only_when_nothing_is_playable() -> void:
	var game := ui.game()
	assert_false(game.can_redraw(), "a playable hand")
	var hand_before := ui.hand_uids()
	await _key(KEY_R)
	assert_eq(ui.hand_uids(), hand_before, "R does nothing while a card is playable")
	assert_eq(game.energy(P), 3)
	# Rook boxed in by its own pieces, a hand of rooks only: nothing playable.
	assert_true(await ui.show_crafted_match(
		[["king", 2, 0], ["rook", 0, 0], ["pawn", 0, 1], ["knight", 1, 0]],
		[["king", 2, 5], ["pawn", 4, 4]],
		["rook", "rook", "rook", "rook", "rook", "rook", "rook"], ["pawn", "move", "move", "move", "move"]))
	game = ui.game()
	assert_true(game.can_redraw())
	hand_before = ui.hand_uids()
	await _key(KEY_R)
	assert_true(await ui.wait_match_idle())
	assert_ne(ui.hand_uids(), hand_before, "a new hand")
	assert_eq(game.energy(P), 3 - int(GameConfig.value("match", "redraw_cost")), "redraw paid")
	assert_eq(game.current_side(), P, "still the player's turn")


func test_e_ends_the_turn() -> void:
	var game := ui.game()
	var round_before := game.current_round()
	await _key(KEY_E)
	assert_true(await ui.until(func() -> bool: return game.current_side() != P or game.current_round() > round_before), "E passed the turn")
	assert_true(await ui.wait_player_turn())
	if not game.is_over():
		assert_eq(game.current_round(), round_before + 1, "exactly one turn passed")


## Every match shortcut, pressed while `overlay_open` holds; nothing may change.
func _assert_shortcuts_blocked(what: String) -> void:
	var game := ui.game()
	var hand_before := ui.hand_uids()
	var energy_before := game.energy(P)
	var round_before := game.current_round()
	for keycode: Key in [KEY_1, KEY_2, KEY_R, KEY_E]:
		ui.press_key(keycode)
	await ui.frames(3)
	assert_eq(_selected(), [], "%s: number keys don't pick cards underneath" % what)
	assert_eq(ui.hand_uids(), hand_before, "%s: R doesn't redraw underneath" % what)
	assert_eq(game.energy(P), energy_before, "%s: no energy spent" % what)
	assert_eq(game.current_side(), P, "%s: E doesn't end the turn" % what)
	assert_eq(game.current_round(), round_before)
	assert_false(ui.screen().is_busy(), "%s: nothing started animating" % what)


func test_shortcuts_are_ignored_while_the_deck_overlay_is_open() -> void:
	await _key(KEY_D)
	assert_eq(ui.overlays().size(), 1, "D opens the deck overlay")
	assert_true(ui.overlays()[0] is ItemOverlay)
	await _assert_shortcuts_blocked("deck overlay")
	await _key(KEY_ESCAPE)
	await ui.frames(2)
	assert_true(ui.overlays().is_empty(), "Esc closes the overlay")
	await _key(KEY_1)
	assert_eq(_selected(), [0], "shortcuts work again once it is closed")


func test_deck_overlay_cards_take_focus_and_show_their_details() -> void:
	await _key(KEY_D)
	var overlay: ItemOverlay = ui.overlays()[0]
	var cards: Array = ui.find_all(overlay, CardView)
	assert_eq(cards.size(), ItemOverlay.group_cards(Game.run.deck).size(), "one view per kind of card (copies show ×N)")
	for card: CardView in cards:
		assert_eq(card.focus_mode, Control.FOCUS_ALL, "every card is reachable with the keyboard")
		assert_ne(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "hovering shows its tooltip")
	await ui.frames(2)
	assert_true((cards[0] as CardView).has_focus(), "the first card takes focus")
	var detail_shown := ui.find_all(overlay, Label).any(func(label: Label) -> bool:
		return label.text.begins_with((cards[0] as CardView).card.display_name()))
	assert_true(detail_shown, "the focused card's details are written out")
	assert_eq(_selected(), [], "nothing in the match was picked")


func test_esc_closes_the_overlay_before_touching_the_selection() -> void:
	await _key(KEY_1)
	assert_eq(_selected(), [0])
	await _key(KEY_D)
	assert_eq(ui.overlays().size(), 1)
	await _key(KEY_ESCAPE)
	assert_true(ui.overlays().is_empty(), "the first Esc closes the overlay")
	assert_eq(_selected(), [0], "the selection underneath is kept")
	await _key(KEY_ESCAPE)
	assert_eq(_selected(), [], "the second Esc cancels it")


func test_shortcuts_are_ignored_while_settings_are_open() -> void:
	await _key(KEY_F1)
	assert_eq(ui.overlays().size(), 1, "F1 opens settings in a match")
	assert_true(ui.overlays()[0] is SettingsPanel)
	await _assert_shortcuts_blocked("settings")
	await _key(KEY_F1)
	await ui.frames(2)
	assert_true(ui.overlays().is_empty(), "F1 toggles it closed")
	await _key(KEY_E)
	assert_true(await ui.until(func() -> bool: return ui.game().current_side() != P or ui.screen().is_busy()), "E works again")
	assert_true(await ui.wait_player_turn())


## Key caps on the cards and buttons, and the KEYS list, show the InputMap bindings
## and follow a rebind at once; the rebound key works.
func test_key_caps_follow_the_bindings() -> void:
	var views := ui.hand_views()
	for i in views.size():
		assert_eq((views[i] as CardView).key_hint, A11y.key_label(StringName("rc_card_%d" % (i + 1))), "card %d cap" % (i + 1))
	var view: MatchView = ui.screen()._view
	assert_eq(view._end_turn_cap.text, "E")
	Settings.bind("rc_end_turn", KEY_K)
	await ui.frames(1)
	assert_eq(view._end_turn_cap.text, A11y.key_name(KEY_K), "the End turn cap follows the rebind")
	assert_true(MatchView.keys_text(&"rc_end_turn") in _keys_lines(view), "the KEYS list follows too")
	await _key(KEY_E)
	assert_false(ui.screen().is_busy(), "E no longer ends the turn")
	var round_before := ui.game().current_round()
	await _key(KEY_K)
	assert_true(await ui.until(func() -> bool: return ui.screen().is_busy() or ui.game().current_round() > round_before), "K ends it")
	assert_true(await ui.wait_player_turn())


func _keys_lines(view: MatchView) -> Array:
	var lines: Array = []
	for line in view.keys_box.get_children():
		if line is HBoxContainer:
			lines.append((line.get_child(0) as Label).text)
	return lines


## Shift (rc_hurry) during the opponent's turn plays the rest of it at "instant"
## speed without touching the saved animation speed; the hurry ends with the turn.
func test_shift_hurries_the_opponent_turn() -> void:
	var speed: String = Settings.get_value("anim_speed")
	await _key(KEY_E)
	assert_true(await ui.until(func() -> bool: return ui.screen()._is_opponent_acting), "the opponent is acting")
	for card_view: CardView in ui.screen()._card_views:
		assert_false(card_view.is_playable, "held cards look unplayable during the opponent's turn")
	var hint: Label = ui.screen()._view.hurry_label
	assert_string_contains(hint.text, "Shift")
	ui.press_key(KEY_SHIFT)
	await ui.frames(1)
	assert_true(Motion.hurry, "Shift hurries the turn")
	assert_eq(Motion.speed(), float(GameConfig.data("ux")["anim_speeds"]["instant"]))
	assert_eq(Settings.get_value("anim_speed"), speed, "the saved speed is untouched")
	assert_true(await ui.wait_player_turn())
	assert_false(Motion.hurry, "the hurry ends with the opponent's turn")
	assert_eq(hint.text, "")


## An open modal (settings) holds the opponent's turn; it resumes on close.
func test_a_modal_pauses_the_opponent_turn() -> void:
	var game := ui.game()
	await _key(KEY_E)
	assert_true(await ui.until(func() -> bool: return ui.screen()._is_opponent_acting), "the opponent is acting")
	await _key(KEY_F1)
	assert_eq(ui.overlays().size(), 1, "settings open over the opponent's turn")
	# An action already playing may finish; after that nothing moves.
	await ui.screen()._fx.wait(1.0)
	var snapshot := [game.current_side(), game.energy(ChessMatch.OPPONENT), game.hand(ChessMatch.OPPONENT).size(), ui.screen()._view.log_lines.get_child_count()]
	await ui.screen()._fx.wait(1.5)
	assert_eq([game.current_side(), game.energy(ChessMatch.OPPONENT), game.hand(ChessMatch.OPPONENT).size(), ui.screen()._view.log_lines.get_child_count()], snapshot, "the opponent waits")
	assert_eq(game.current_side(), ChessMatch.OPPONENT, "still the opponent's turn")
	await _key(KEY_F1)
	assert_true(ui.overlays().is_empty())
	assert_true(await ui.wait_player_turn(), "the turn resumes when the modal closes")
