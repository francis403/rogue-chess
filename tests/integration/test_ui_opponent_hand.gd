extends GutTest
## The opponent's hand row in the match's side panel, through the real screen:
## it shows exactly visible_opponent_hand() face up plus hidden_card_count() backs
## (never a hidden card's face), fits the side column for any hidden count, flips
## cards when a Scout is played from the hand, and follows the opponent's new
## hand after its turn.

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")
const O := ChessMatch.OPPONENT
## Pieces with room to move for both sides.
const PLAYER_PIECES := [["king", 2, 0], ["pawn", 1, 1], ["pawn", 4, 1]]
const OPPONENT_PIECES := [["king", 2, 5], ["pawn", 4, 4], ["pawn", 1, 4]]
const OPPONENT_DECK := ["pawn", "move", "pawn", "move", "pawn", "move", "pawn", "move"]

var ui: UiDriver
var _old_size: Vector2i


## Plays one hidden card (a legal play of a card not in visible_opponent_hand()),
## then ends its turn; with `rook_move` it plays a rook from -> to instead.
class ScriptedAI extends MatchAI:
	var has_played: bool = false
	var rook_move: Array = []

	func choose_action(game: ChessMatch) -> Dictionary:
		if game.pending_escape_side() == side:
			return {"kind": "decline_escape"}
		if has_played:
			return {"kind": "end_turn"}
		has_played = true
		var hand := game.hand(side)
		var shown := game.visible_opponent_hand().map(func(card: CardData) -> int: return card.uid)
		for play in game.legal_plays(side):
			var card: CardData = hand[play["card_index"]]
			if rook_move.is_empty() and not shown.has(card.uid):
				return {"kind": "play", "card_index": play["card_index"], "from": play["from"], "to": play["to"]}
			if not rook_move.is_empty() and card.type == "rook" and play["from"] == rook_move[0] and play["to"] == rook_move[1]:
				return {"kind": "play", "card_index": play["card_index"], "from": play["from"], "to": play["to"]}
		return {"kind": "end_turn"}


func before_each() -> void:
	_old_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	ui = UiDriver.new(self, "opponent_hand")
	await ui.start()
	Game.new_run(4)
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	assert_true(await ui.wait_screen("MAP"))


func after_each() -> void:
	Settings.set_value("large_text", false)
	await ui.stop()
	get_tree().root.size = _old_size


func _row() -> OpponentHand:
	return ui.screen()._view.opponent_hand


func _uids(cards: Array) -> Array:
	return cards.map(func(card: CardData) -> int: return card.uid)


func _face_uids() -> Array:
	return _row().faces().map(func(face: CardView) -> int: return face.card.uid)


## The names line as plain " · "-joined text (it breaks its own lines and uses
## non-breaking spaces).
func _names_text() -> String:
	return _row().names_line.text.replace("\n", " · ").replace("\u00a0", " ")


## The row shows what the engine lets the player see, and nothing else.
func _assert_row_matches_engine(context: String) -> void:
	var game := ui.game()
	assert_eq(_face_uids(), _uids(game.visible_opponent_hand()), "faces are the visible cards, in hand order (%s)" % context)
	assert_eq(_row().back_count(), game.hidden_card_count(), "one back per hidden card (%s)" % context)
	assert_eq(_row().caption.text, OpponentHand.caption_text(game.visible_opponent_hand().size(), game.hidden_card_count()), context)
	_assert_no_hidden_face(context)


## No CardView anywhere on the screen shows a hidden opponent card's face.
func _assert_no_hidden_face(context: String) -> void:
	var game := ui.game()
	var hidden := _uids(game.hand(O)).filter(func(uid: int) -> bool: return not _uids(game.visible_opponent_hand()).has(uid))
	for view: CardView in ui.find_all(ui.screen(), CardView):
		if not view.is_back:
			assert_false(hidden.has(view.card.uid), "a hidden card's face is never shown (%s)" % context)


## The row stays inside the fixed-width left column.
func _assert_fits(context: String) -> void:
	var row := _row()
	var panel := row.get_parent().get_parent() as Control
	var column := panel.get_parent() as Control
	assert_lte(row.get_combined_minimum_size().x, float(OpponentHand.WIDTH), "the cards fit the column (%s)" % context)
	assert_eq(column.size.x, float(Metrics.SIDE_COLUMN), "the left column keeps its width (%s)" % context)
	assert_lte(row.get_global_rect().end.x, panel.get_global_rect().end.x - Metrics.L + 0.5, "inside the panel's padding (%s)" % context)


func _show(player_deck: Array, hidden_cards: int, player_pieces: Array = PLAYER_PIECES) -> void:
	assert_true(await ui.show_crafted_match(player_pieces, OPPONENT_PIECES, player_deck, OPPONENT_DECK, hidden_cards))
	await ui.frames(2)


func test_default_match_shows_all_but_one_card() -> void:
	ui.travel(["L1"])
	assert_true(await ui.wait_screen("MATCH_SETUP"))
	assert_true(ui.press(ui.button("Start match")))
	assert_true(await ui.wait_screen("MATCH"))
	assert_true(await ui.wait_match_idle())
	var game := ui.game()
	var hand_size := game.hand(O).size()
	assert_gt(hand_size, 1)
	assert_eq(_row().faces().size(), hand_size - 1, "every card but one is face up")
	assert_eq(_row().back_count(), 1, "one card back")
	assert_eq(_row().caption.text, "%d shown · 1 hidden" % (hand_size - 1))
	_assert_row_matches_engine("default match")
	_assert_fits("default match")


func test_any_hidden_count_fits_and_matches_the_engine() -> void:
	for is_large in [false, true]:
		Settings.set_value("large_text", is_large)
		for hidden_cards in [0, 1, 3, 5, 7]:
			await _show(["pawn", "move", "pawn", "move", "pawn"], hidden_cards)
			var context := "hidden_cards %d, large text %s" % [hidden_cards, is_large]
			var hand_size := ui.game().hand(O).size()
			assert_eq(hand_size, 5, context)
			assert_eq(_row().back_count(), mini(hidden_cards, hand_size), context)
			assert_eq(_row().faces().size(), hand_size - mini(hidden_cards, hand_size), context)
			_assert_row_matches_engine(context)
			_assert_fits(context)
	await _show(["pawn", "move", "pawn", "move", "pawn"], 0)
	assert_eq(_row().caption.text, "all shown")
	await _show(["pawn", "move", "pawn", "move", "pawn"], 7)
	assert_eq(_row().caption.text, "all hidden")


func test_a_scout_from_the_hand_flips_two_backs() -> void:
	await _show(["scout", "pawn", "move", "move", "move"], 3)
	var game := ui.game()
	var faces_before := _face_uids()
	ui.click_card(ui.hand_index("scout"))
	assert_true(await ui.wait_match_idle())
	assert_eq(ui.hand_index("scout"), -1, "the Scout was played")
	assert_eq(game.energy(ChessMatch.PLAYER), 2, "a Scout costs 1 energy")
	assert_eq(game.current_side(), ChessMatch.PLAYER, "the turn goes on")
	assert_eq(_row().faces().size(), faces_before.size() + 2, "two cards turned face up")
	assert_eq(_row().back_count(), 1)
	for uid: int in faces_before:
		assert_true(_face_uids().has(uid), "the cards already shown stay shown")
	_assert_row_matches_engine("after a Scout")
	assert_true(_log_text().contains("You scouted 2 cards"), "the log says what the Scout did")
	var revealed: Array = _row().faces().filter(func(face: CardView) -> bool: return not faces_before.has(face.card.uid))
	assert_true(_log_text().contains("Revealed: " + " · ".join(revealed.map(func(face: CardView) -> String: return face.card.display_name()))),
		"the log names the revealed cards (no mouse needed)")
	for face: CardView in _row().faces():
		assert_eq(face.flip, 1.0, "every face has finished turning over")
		assert_eq(face.modulate.a, 1.0)


func test_a_scout_never_reveals_more_than_is_hidden_and_is_refused_after() -> void:
	await _show(["scout", "scout", "pawn", "move", "move"], 1)
	var game := ui.game()
	ui.press_key(KEY_1 + ui.hand_index("scout"))  # by key this time
	assert_true(await ui.wait_match_idle())
	assert_eq(game.energy(ChessMatch.PLAYER), 2)
	assert_eq(_row().back_count(), 0, "the only hidden card turned face up")
	assert_eq(_row().caption.text, "all shown")
	_assert_row_matches_engine("one hidden, Scout played")
	# The second Scout has nothing left to reveal: refused, nothing spent.
	var hand_before := ui.hand_uids()
	ui.click_card(ui.hand_index("scout"))
	await ui.frames(2)
	assert_eq(ui.hand_uids(), hand_before, "the Scout stays in hand")
	assert_eq(game.energy(ChessMatch.PLAYER), 2, "no energy spent")
	assert_eq(ui.screen()._view.hint.text, "No hidden cards to reveal")
	assert_false(ui.hand_views()[ui.hand_index("scout")].is_playable, "it looks unplayable")


func test_a_scout_as_the_only_playable_card_is_not_stuck() -> void:
	# Rook boxed in by its own pieces and a hand of rooks: only the Scout can be played.
	await _show(["scout", "rook", "rook", "rook", "rook"], 1, [["king", 2, 0], ["rook", 0, 0], ["pawn", 0, 1], ["knight", 1, 0]])
	var game := ui.game()
	var end_turn := ui.button("End turn", ui.screen())
	assert_true(game.legal_plays(ChessMatch.PLAYER).is_empty())
	assert_eq(end_turn.text, "End turn", "a playable Scout: not stuck")
	assert_true(ui.screen()._view.hint.text.contains("Play Scout"), "the hint offers the Scout")
	ui.check_idle_invariants()
	ui.click_card(ui.hand_index("scout"))
	assert_true(await ui.wait_match_idle())
	assert_eq(end_turn.text, MatchView.END_TURN_STUCK, "nothing playable once the Scout is gone")
	assert_eq(ui.failures, [] as Array[String])


func test_the_opponent_turn_ends_with_a_new_hand_under_the_same_rule() -> void:
	await _show(["scout", "pawn", "move", "move", "move"], 2)
	var game := ui.game()
	ui.click_card(ui.hand_index("scout"))
	assert_true(await ui.wait_match_idle())
	assert_eq(game.hidden_card_count(), 0, "the Scout revealed both hidden cards")
	var old_hand := _uids(game.hand(O))
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.until(func() -> bool: return game.current_side() == O))
	# Every frame of the opponent's turn: no hidden face, and each card it plays
	# takes exactly its own face out of the row.
	var shown := _face_uids()
	var plays := 0
	while not ui.match_idle():
		_assert_no_hidden_face("opponent's turn")
		var now := _face_uids()
		if now.size() == shown.size() - 1 and _row().back_count() == 0:
			var played: Array = shown.filter(func(uid: int) -> bool: return not now.has(uid))
			assert_eq(played.size(), 1, "one face left the row")
			assert_true(old_hand.has(played[0]) and not _uids(game.hand(O)).has(played[0]), "the card it played")
			plays += 1
		shown = now
		await ui.frames(1)
	assert_gt(plays, 0, "the opponent played at least one card")
	assert_true(await ui.wait_player_turn())
	assert_ne(_uids(game.hand(O)), old_hand, "the opponent drew a new hand")
	assert_eq(game.hidden_card_count(), mini(2, game.hand(O).size()), "the reveal is gone: the rule applies again")
	_assert_row_matches_engine("the opponent's new hand")
	_assert_fits("the opponent's new hand")


func _log_text() -> String:
	var lines: Array = ui.screen()._view.log_lines.get_children().map(func(line: Label) -> String: return line.text)
	return "\n".join(lines)


func test_the_opponent_playing_a_hidden_card_removes_one_back_only() -> void:
	await _show(["pawn", "move", "move", "move", "move"], 2)
	var game := ui.game()
	ui.screen()._ai = ScriptedAI.new(O, 1, 0.0, RandomNumberGenerator.new())
	var faces_before := _row().faces()
	assert_eq(_row().back_count(), 2)
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.until(func() -> bool: return _row().back_count() == 1), "a back left the row")
	assert_eq(_row().faces(), faces_before, "every face is untouched (same cards, same nodes)")
	assert_eq(_row().caption.text, OpponentHand.caption_text(faces_before.size(), 1))
	assert_true(await ui.wait_player_turn())


func test_a_scout_does_nothing_outside_the_player_turn() -> void:
	# Hold Scouts: the player's hand is otherwise discarded before the opponent acts.
	# During the opponent's turn.
	await _show(["scout:hold", "move", "move", "move", "move"], 2)
	var game := ui.game()
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.until(func() -> bool: return game.current_side() == O and ui.screen().is_busy()))
	_assert_scout_ignored("the opponent's turn")
	assert_true(await ui.wait_player_turn())
	# While the player's escape prompt is up.
	assert_true(await ui.show_crafted_match([["king", 2, 0], ["pawn", 5, 1]], [["king", 5, 5], ["rook", 3, 5]],
		["scout:hold", "move", "move", "move", "move"], ["rook", "rook", "rook", "rook", "rook"], 2))
	game = ui.game()
	var scripted := ScriptedAI.new(O, 1, 0.0, RandomNumberGenerator.new())
	scripted.rook_move = [Vector2i(3, 5), Vector2i(2, 5)]
	ui.screen()._ai = scripted
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.wait_match_idle())
	assert_true(ui.escape_prompt_up(), "the rook gives check")
	_assert_scout_ignored("the escape prompt")
	assert_true(ui.screen()._view.escape_box.visible, "the check prompt stays up")
	# After the match is over: the rook takes the king.
	assert_true(await ui.show_crafted_match([["king", 0, 0], ["rook", 2, 0]], [["king", 2, 5], ["pawn", 4, 4]],
		["scout:hold", "rook", "move", "move", "move"], ["move", "move", "move", "move", "move"], 2))
	game = ui.game()
	ui.click_card(ui.hand_index("rook"))
	ui.click_square(Vector2i(2, 0))
	ui.click_square(Vector2i(2, 5))
	assert_true(await ui.wait_match_idle())
	assert_true(game.is_over())
	_assert_scout_ignored("match over")


## Clicking the Scout and pressing its key change nothing.
func _assert_scout_ignored(context: String) -> void:
	var game := ui.game()
	var state := [ui.hand_uids(), game.energy(ChessMatch.PLAYER), game.hidden_card_count(), _face_uids()]
	var hint: String = ui.screen()._view.hint.text
	var scout := ui.hand_index("scout", "hold")
	assert_gte(scout, 0, "the Scout is in hand (%s)" % context)
	ui.click_card(scout)
	ui.press_key(KEY_1 + scout)
	assert_eq([ui.hand_uids(), game.energy(ChessMatch.PLAYER), game.hidden_card_count(), _face_uids()], state, "nothing played (%s)" % context)
	assert_eq(ui.screen()._view.hint.text, hint, "the hint still says what is going on (%s)" % context)


func test_a_scout_cannot_be_dragged() -> void:
	await _show(["scout", "pawn", "move", "move", "move"], 2)
	var scout: CardView = ui.hand_views()[ui.hand_index("scout")]
	var pawn: CardView = ui.hand_views()[ui.hand_index("pawn")]
	assert_null(scout.drag_payload, "a Scout has nothing to drop")
	assert_null(scout._get_drag_data(Vector2.ZERO), "dragging it starts no drag")
	assert_not_null(pawn.drag_payload, "a piece card still drags")
	assert_eq(ui.game().hidden_card_count(), 2, "the drag attempt played nothing")


func test_the_left_column_fits_720p_with_large_text_and_five_cards() -> void:
	Settings.set_value("large_text", true)
	await _show(["pawn", "move", "pawn", "move", "pawn"], 2)
	await ui.frames(3)
	var panel := _row().get_parent().get_parent() as Control
	var column := panel.get_parent() as Control
	var window := ui.main.get_viewport_rect()
	assert_eq(_row().get_child_count(), 5)
	assert_lte(column.get_combined_minimum_size().y, column.size.y + 0.5, "the column's content fits its height")
	assert_lte(column.get_global_rect().end.y, window.end.y + 0.5, "the column ends inside the window")
	var bottom := column.get_global_rect().position.y
	for child: Control in column.get_children():
		var rect := child.get_global_rect()
		assert_gte(rect.position.y, bottom - 0.5, "%s doesn't overlap the panel above" % child.name)
		assert_gte(rect.size.y, child.get_combined_minimum_size().y - 0.5, "%s isn't squeezed (clipped)" % child.name)
		bottom = rect.end.y
	assert_lte(bottom, window.end.y + 0.5, "the legend ends inside the window")
	var names := _row().names_line
	assert_lte(names.get_global_rect().end.y, panel.get_global_rect().end.y, "the card names sit inside the panel")
	assert_gte((column.get_child(1) as Control).size.y, 100.0, "the log keeps room for a few lines")


func test_shown_card_names_are_in_text_and_the_log_reads_in_turn_order() -> void:
	await _show(["pawn", "move", "move", "move", "move"], 2)
	var game := ui.game()
	var expected := " · ".join(game.visible_opponent_hand().map(func(card: CardData) -> String: return card.display_name()))
	assert_eq(_names_text(), expected, "the shown cards are named without a mouse")
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.wait_player_turn())
	assert_eq(_names_text(), " · ".join(game.visible_opponent_hand().map(func(card: CardData) -> String: return card.display_name())))
	var lines := _log_text().split("\n")
	var header := lines.find("— Round 2 · Your turn —")
	assert_gt(header, 0, "the new round is logged")
	assert_eq(lines[header - 1], "Rookie Rex drew 5 cards", "the opponent's draw closes its own turn")
	var opening := Array(lines.slice(header + 1, header + 4))
	assert_true(opening.has("You drew 5 cards"), "the player's draw opens the new turn: %s" % [opening])
	assert_false(opening.has("Rookie Rex drew 5 cards"), "not the opponent's")
	assert_eq(lines.slice(0, 3), ["Rookie Rex drew 5 cards", "— Round 1 · Your turn —", "You drew 5 cards"] as PackedStringArray, "match start")


func test_a_swept_row_is_dealt_again_even_with_the_same_cards() -> void:
	# A reshuffle can deal the opponent the same cards in the same order.
	var row := OpponentHand.new()
	add_child_autofree(row)
	autofree(row.caption)  # the screen places these two; here they stay out of the tree
	autofree(row.names_line)
	var cards: Array[CardData] = [CardData.new("pawn"), CardData.new("move")]
	row.show_hand(cards, 1)
	row.sweep_out(0.01)
	await get_tree().create_timer(0.1).timeout
	row.show_hand(cards, 1)
	await get_tree().process_frame
	assert_eq(row.get_child_count(), 3)
	for view: Control in row.get_children():
		assert_false(view.is_queued_for_deletion(), "a fresh card, not the swept one")
		assert_eq(view.modulate.a, 1.0, "visible again")



func test_the_scout_reveal_text_waits_for_the_flips() -> void:
	Settings.set_value("anim_speed", "normal")  # frames to look at while the cards turn
	await _show(["scout", "pawn", "move", "move", "move"], 2)
	var caption_before: String = _row().caption.text
	var names_before := _names_text()
	var faces_before := _row().faces().size()
	var separation := _row().get_theme_constant("separation")
	var xs: Array = _row().get_children().map(func(card: Control) -> float: return card.position.x)
	ui.click_card(ui.hand_index("scout"))
	assert_true(await ui.until(func() -> bool: return _row().faces().size() == faces_before + 2), "the row turned the backs")
	assert_eq(_row().caption.text, caption_before, "the caption still counts the backs while they turn")
	assert_eq(_names_text(), names_before, "the names line doesn't name them yet")
	assert_false(_log_text().contains("Revealed:"), "nor does the log")
	assert_eq(_row().get_theme_constant("separation"), separation, "the row's spacing holds")
	assert_eq(_row().get_children().map(func(card: Control) -> float: return card.position.x), xs, "no card moves")
	assert_true(await ui.wait_match_idle())
	assert_eq(_row().caption.text, "all shown", "the caption tells the result once the cards have turned")
	assert_eq(_names_text(), " · ".join(ui.game().visible_opponent_hand().map(func(card: CardData) -> String: return card.display_name())))
	assert_true(_log_text().contains("Revealed:"))


func test_the_names_line_never_ends_a_line_on_a_separator() -> void:
	Settings.set_value("large_text", true)
	assert_true(await ui.show_crafted_match(PLAYER_PIECES, OPPONENT_PIECES, ["pawn", "move", "pawn", "move", "pawn"],
		["bishop", "knight", "rook", "move", "pawn"], 0))
	await ui.frames(2)
	var names := _row().names_line
	var font := names.get_theme_font("font")
	var font_size := names.get_theme_font_size("font_size")
	var lines := names.text.split("\n")
	assert_gt(lines.size(), 1, "five names take two lines at Large text")
	for line in lines:
		assert_false(line.strip_edges().ends_with("·"), "no dangling separator: %s" % line)
		assert_false(line.strip_edges().begins_with("·"), "no leading separator: %s" % line)
		assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, float(OpponentHand.WIDTH), "the line fits")
	assert_eq(names.get_line_count(), lines.size(), "the label adds no breaks of its own")
	# The text size changes live: the lines are broken again.
	Settings.set_value("large_text", false)
	await ui.frames(2)
	assert_eq(names.text.split("\n").size(), 1, "one line at normal size")


func test_deep_vision_point_is_attributed_when_it_scores() -> void:
	# The player holds Deep Vision; the opponent's rook takes a pawn: +1 for the
	# pawn and +1 Deep Vision, named in the floats, the log and by the chip.
	Game.match_setup = {
		"seed": 5,
		"holes": [] as Array[Vector2i],
		"player": {"roster": UiDriver._roster([["king", 2, 0], ["pawn", 3, 3]]), "deck": UiDriver._cards(["move", "move", "move", "move", "move"]),
			"artifacts": ["foresight"] as Array[String]},
		"opponent": {"id": "easy", "name": "Rookie Rex", "difficulty": "Easy", "search_depth": 1, "random_chance": 0.0,
			"roster": UiDriver._roster([["king", 0, 5], ["rook", 3, 5]]), "deck": UiDriver._cards(["rook", "rook", "rook", "rook", "rook"]),
			"artifacts": [] as Array[String]},
	}
	ui.main.show_screen("MATCH")
	assert_true(await ui.wait_match_idle())
	var scripted := ScriptedAI.new(O, 1, 0.0, RandomNumberGenerator.new())
	scripted.rook_move = [Vector2i(3, 5), Vector2i(3, 3)]
	ui.screen()._ai = scripted
	var chip: Control = ui.screen()._view._artifact_chips[ChessMatch.PLAYER]["foresight"]
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.until(func() -> bool: return ui.game().current_side() == O))
	var floats := {}
	var chip_lit := false
	while not (ui.game().current_side() == ChessMatch.PLAYER and ui.match_idle()):
		for label: Label in ui.find_all(ui.screen()._view.board, Label):
			floats[label.text] = true
		chip_lit = chip_lit or chip.modulate.r > 1.0
		await ui.frames(1)
	assert_eq(ui.game().score(O), 2, "the pawn's point and Deep Vision's")
	assert_true(floats.has("+1") and floats.has("+1 Deep Vision"), "two floats: %s" % [floats.keys()])
	assert_true(_log_text().contains("Pawn captured on d4 (+2, incl. +1 Deep Vision)"), _log_text())
	assert_true(chip_lit, "the Deep Vision chip glows")

