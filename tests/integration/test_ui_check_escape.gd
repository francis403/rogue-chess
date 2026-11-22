extends GutTest
## Check escape through the real match screen (D56-D62): the opponent answers the
## player's check on its own; the player's prompt only accepts escape squares, Stay and Esc.

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT

var ui: UiDriver


## Plays the given rook move once, then ends its turn (declines any escape of its own).
class ScriptedAI extends MatchAI:
	var rook_move: Array = []

	func choose_action(game: ChessMatch) -> Dictionary:
		if game.pending_escape_side() == side:
			return {"kind": "decline_escape"}
		if rook_move.is_empty():
			return {"kind": "end_turn"}
		var hand := game.hand(side)
		for i in hand.size():
			if hand[i].type == "rook":
				var move: Array = rook_move
				rook_move = []
				return {"kind": "play", "card_index": i, "from": move[0], "to": move[1]}
		return {"kind": "end_turn"}


func before_each() -> void:
	ui = UiDriver.new(self, "check_escape")
	await ui.start()
	Game.new_run(3)
	Game.run.choose_piece_set("standard")


func after_each() -> void:
	await ui.stop()


func test_player_check_is_answered_by_the_opponent() -> void:
	assert_true(await ui.show_crafted_match([["king", 0, 0], ["rook", 3, 1]], [["king", 2, 5]],
		["rook", "move", "move", "move", "move"], ["move", "move", "move", "move", "move"]))
	var game := ui.game()
	ui.click_card(ui.hand_index("rook"))
	ui.click_square(Vector2i(3, 1))
	ui.click_square(Vector2i(2, 1))
	assert_true(await ui.wait_match_idle())
	assert_eq(game.pending_escape_side(), -1, "the opponent answered the check")
	assert_eq(game.current_side(), P, "and the player's turn continues")
	assert_true(_log_has("Check!"), "the check is logged")
	var tag: Label = ui.screen()._opponent_penalty_tag
	if game.escape_penalty(O) > 0:
		assert_true(_log_has("escaped"))
		assert_eq(tag.text, "−1 next turn", "the opponent's penalty is visible")
	else:
		assert_true(_log_has("stayed in check"))
		assert_eq(tag.text, "")


func test_escape_prompt_accepts_only_escape_squares() -> void:
	await _opponent_gives_check()
	var game := ui.game()
	var king := Vector2i(2, 0)
	var squares := game.escape_squares()
	assert_false(squares.is_empty())
	var board := ui.board()
	assert_eq(board.selected, king, "the king is highlighted")
	assert_eq(board.threats, [Vector2i(2, 5)] as Array[Vector2i], "the checker is highlighted")
	assert_eq(_sorted(board.targets + board.captures), _sorted(squares), "escape squares are highlighted")
	assert_true(ui.button("End turn", ui.screen()).disabled)
	assert_true(ui.button("Stay", ui.screen()).is_visible_in_tree())
	ui.click_square(Vector2i(5, 0))  # not an escape square
	for view: CardView in ui.hand_views():
		ui.click(view)
	ui.press_escape()
	ui.right_click(board)
	await ui.frames(2)
	assert_eq(game.pending_escape_side(), P, "Esc, right-click and stray clicks keep the prompt")
	assert_eq(game.piece_at(king).type, "king")
	ui.click_square(squares[0])
	ui.click_square(squares[0])  # double click: one escape only
	assert_true(await ui.wait_player_turn())
	assert_eq(game.escape_penalty(P), 0, "the penalty was spent at the player's turn start")
	assert_eq(game.energy(P), game.max_energy(P) - 1, "the escape cost 1 energy of this turn")
	assert_true(_log_has("You escaped"))


func test_stay_declines_the_escape() -> void:
	await _opponent_gives_check()
	var game := ui.game()
	var stay := ui.button("Stay", ui.screen())
	assert_true(ui.press(stay))
	ui.force_press(stay)
	assert_true(await ui.wait_player_turn())
	assert_eq(game.piece_at(Vector2i(2, 0)).type, "king", "the king stayed")
	assert_eq(game.energy(P), game.max_energy(P), "declining costs nothing")
	assert_true(_log_has("You stayed in check"))
	var king_token := ui.board().token(game.piece_at(Vector2i(2, 0)).uid)
	assert_eq(king_token.is_in_check, game.in_check(P), "the king token shows the check")


## The player ends the turn; the scripted opponent rook moves onto the king's file.
func _opponent_gives_check() -> void:
	assert_true(await ui.show_crafted_match([["king", 2, 0], ["pawn", 5, 1]], [["king", 5, 5], ["rook", 3, 5]],
		["move", "move", "move", "move", "move"], ["rook", "rook", "rook", "rook", "rook"]))
	var scripted := ScriptedAI.new(O, 1, 0.0, RandomNumberGenerator.new())
	scripted.rook_move = [Vector2i(3, 5), Vector2i(2, 5)]
	ui.screen()._ai = scripted
	assert_true(ui.press(ui.button("End turn", ui.screen())))
	assert_true(await ui.wait_match_idle())
	assert_true(ui.escape_prompt_up(), "the player's escape prompt is up")


func _log_has(text: String) -> bool:
	for node: Label in ui.find_all(ui.screen(), Label):
		if node.text.contains(text):
			return true
	return false


func _sorted(squares: Array) -> Array:
	var copy := squares.duplicate()
	copy.sort()
	return copy
