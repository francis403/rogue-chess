extends GutTest
## Match screen input through the real widgets: clicks during the opponent's turn,
## double presses, Esc / right-click cancel, the Redraw button state, and that the
## card-first and piece-first flows play exactly the expected card.

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")
const NO_SQUARE := BoardView.NO_SQUARE

var ui: UiDriver


func before_each() -> void:
	ui = UiDriver.new(self, "match_input")
	await ui.start()
	assert_true(ui.press(ui.button("New Game")))
	assert_true(await ui.wait_screen("SET_SELECT"))
	Game.new_run(4)
	assert_true(await ui.wait_screen("SET_SELECT"))


func after_each() -> void:
	await ui.stop()


func _start_real_match() -> void:
	var tile: SelectTile = ui.select_tiles()[0]
	ui.click(tile)
	ui.click(tile)  # double click on the set tile: one run start only
	assert_true(await ui.wait_screen("MAP"))
	assert_eq(Game.run.collection.size(), 16)
	var map_view: MapView = ui.find_all(ui.screen(), MapView)[0]
	var at := map_view.node_position("L1")
	ui.click(map_view, at)
	ui.click(map_view, at)  # double click on the map node: refused, travels once
	assert_true(await ui.wait_screen("MATCH_SETUP"))
	assert_eq(Game.run.visited, ["L1"] as Array[String])
	var start := ui.button("Start match")
	assert_true(ui.press(start))
	ui.force_press(start)  # double press: build_match_setup refused the second time
	assert_true(await ui.wait_screen("MATCH"))
	assert_true(await ui.wait_match_idle())


func test_input_during_the_opponent_turn_does_nothing() -> void:
	await _start_real_match()
	var game := ui.game()
	var round_before := game.current_round()
	var end_turn := ui.button("End turn", ui.screen())
	var redraw := ui.button("Redraw", ui.screen())
	assert_true(ui.press(end_turn))
	ui.force_press(end_turn)  # double press in the same frame
	assert_true(await ui.until(func() -> bool: return game.current_side() == ChessMatch.OPPONENT and ui.screen().is_busy()))
	var checks := 0
	# Hammer the UI on every frame of the opponent's turn.
	while game.current_side() == ChessMatch.OPPONENT and not game.is_over() and game.pending_escape_side() != ChessMatch.PLAYER:
		var hand_before := ui.hand_uids()
		var energy_before := game.energy(ChessMatch.PLAYER)
		assert_true(end_turn.disabled, "End turn is disabled during the opponent's turn")
		assert_true(redraw.disabled, "Redraw is disabled during the opponent's turn")
		for view: CardView in ui.hand_views():
			ui.click(view)
		for piece in game.pieces(ChessMatch.PLAYER):
			ui.click_square(piece.square)
		for piece in game.pieces(ChessMatch.OPPONENT):
			ui.click_square(piece.square)
		ui.force_press(end_turn)
		ui.force_press(redraw)
		assert_eq(ui.hand_uids(), hand_before, "clicks don't play or redraw cards")
		assert_eq(game.energy(ChessMatch.PLAYER), energy_before)
		for view: CardView in ui.hand_views():
			assert_false(view.is_selected, "no card gets selected")
		var board := ui.board()
		assert_eq(board.targets, [] as Array[Vector2i], "no targets highlighted")
		assert_eq(board.selected, NO_SQUARE, "no piece selected")
		checks += 1
		await ui.frames(1)
	assert_gt(checks, 0, "the opponent's turn took at least a frame")
	assert_true(await ui.wait_player_turn())
	if not game.is_over():
		assert_eq(game.current_round(), round_before + 1, "the double End turn passed exactly one turn")
		assert_eq(game.current_side(), ChessMatch.PLAYER)
	assert_eq(ui.failures, [] as Array[String])


func test_esc_and_right_click_cancel_a_selection() -> void:
	await _start_real_match()
	var game := ui.game()
	var board := ui.board()
	var idle_movable := MatchUiLogic.movable_pieces(game)
	assert_eq(board.movable, idle_movable, "idle: every movable piece is outlined")

	# Card-first selection, cancelled with Esc.
	var card_index := _first_playable_card(game)
	assert_gte(card_index, 0)
	ui.click_card(card_index)
	assert_true(ui.hand_views()[card_index].is_selected)
	assert_eq(board.movable, game.pieces_for_card(card_index))
	ui.press_escape()
	await ui.frames(1)
	assert_false(ui.hand_views()[card_index].is_selected, "Esc deselects the card")
	assert_eq(board.selected, NO_SQUARE)
	assert_eq(board.targets, [] as Array[Vector2i])
	assert_eq(board.movable, idle_movable, "Esc returns to the idle highlights")

	# Piece-first selection, cancelled with Esc.
	var from := idle_movable[0]
	ui.click_square(from)
	assert_eq(board.selected, from)
	assert_false(board.targets.is_empty() and board.captures.is_empty())
	ui.press_escape()
	await ui.frames(1)
	assert_eq(board.selected, NO_SQUARE, "Esc deselects the piece")
	assert_eq(board.targets, [] as Array[Vector2i])

	# Right-click on the board cancels too; clicking the same card twice toggles it off.
	ui.click_card(card_index)
	ui.click_square(game.pieces_for_card(card_index)[0])
	ui.right_click(board)
	assert_eq(board.selected, NO_SQUARE, "right-click cancels")
	assert_false(ui.hand_views()[card_index].is_selected)
	ui.click_card(card_index)
	ui.click_card(card_index)
	assert_false(ui.hand_views()[card_index].is_selected, "clicking the selected card again cancels it")

	# Nothing was played by any of this.
	assert_eq(game.energy(ChessMatch.PLAYER), game.max_energy(ChessMatch.PLAYER))
	assert_eq(game.hand(ChessMatch.PLAYER).size(), 5)


func test_redraw_button_only_enabled_when_can_redraw() -> void:
	ui.click(ui.select_tiles()[0])
	assert_true(await ui.wait_screen("MAP"))
	# Rook boxed in by its own pieces, a hand of rooks only: nothing playable.
	assert_true(await ui.show_crafted_match(
		[["king", 2, 0], ["rook", 0, 0], ["pawn", 0, 1], ["knight", 1, 0]],
		[["king", 2, 5], ["pawn", 4, 4]],
		["rook", "rook", "rook", "rook", "rook", "rook", "rook"], ["pawn", "move", "move", "move", "move"]))
	var game := ui.game()
	var redraw := ui.button("Redraw", ui.screen())
	var end_turn := ui.button("End turn", ui.screen())
	assert_true(game.can_redraw())
	assert_false(redraw.disabled, "nothing playable: Redraw is enabled")
	assert_eq(end_turn.text, "End turn (nothing playable)")
	# Each press is one redraw (repeatable while affordable, D8) until energy runs out.
	for energy_left in [2, 1, 0]:
		var hand_before := ui.hand_uids()
		assert_true(ui.press(redraw), "Redraw pressable with %d energy" % (energy_left + 1))
		assert_true(await ui.wait_match_idle())
		assert_eq(game.energy(ChessMatch.PLAYER), energy_left, "one redraw costs 1 energy")
		assert_ne(ui.hand_uids(), hand_before, "a fresh hand was drawn")
		assert_eq(game.current_side(), ChessMatch.PLAYER, "redraw doesn't end the turn")
		ui.check_idle_invariants()
	assert_true(redraw.disabled, "no energy left: Redraw is disabled")
	ui.force_press(redraw)
	await ui.frames(2)
	assert_eq(game.energy(ChessMatch.PLAYER), 0, "a forced press on the disabled button does nothing")

	# A normal hand: Redraw disabled, and pressing it anyway does nothing.
	assert_true(await ui.show_crafted_match(
		[["king", 2, 0], ["pawn", 1, 1]],
		[["king", 2, 5], ["pawn", 4, 4]],
		["pawn", "move", "move", "move", "move"], ["pawn", "move", "move", "move", "move"]))
	game = ui.game()
	redraw = ui.button("Redraw", ui.screen())
	assert_false(game.can_redraw())
	assert_true(redraw.disabled, "a playable card: Redraw is disabled")
	var hand_before := ui.hand_uids()
	ui.force_press(redraw)
	await ui.frames(2)
	assert_eq(ui.hand_uids(), hand_before)
	assert_eq(game.energy(ChessMatch.PLAYER), 3)
	ui.check_idle_invariants()
	assert_eq(ui.failures, [] as Array[String])


func test_card_first_and_piece_first_play_the_expected_card() -> void:
	ui.click(ui.select_tiles()[0])
	assert_true(await ui.wait_screen("MAP"))
	assert_true(await ui.show_crafted_match(
		[["king", 2, 0], ["pawn", 1, 1], ["knight", 4, 0]],
		[["king", 2, 5], ["pawn", 4, 4], ["pawn", 0, 4]],
		["move", "pawn", "knight:cheaper", "knight", "rook"], ["pawn", "move", "move", "move", "move"]))
	var game := ui.game()
	var board := ui.board()
	var pawn_card: CardData = game.hand(ChessMatch.PLAYER)[ui.hand_index("pawn")]
	var move_card: CardData = game.hand(ChessMatch.PLAYER)[ui.hand_index("move")]
	var cheap_knight: CardData = game.hand(ChessMatch.PLAYER)[ui.hand_index("knight", "cheaper")]
	var knight_card: CardData = game.hand(ChessMatch.PLAYER)[ui.hand_index("knight")]

	# Piece-first, pawn b2 -> b3: Pawn and Move both cost 1, the pawn's own card is used.
	ui.click_square(Vector2i(1, 1))
	assert_eq(board.selected, Vector2i(1, 1))
	assert_eq(_sorted(board.targets + board.captures), _sorted(MatchUiLogic.targets_for_piece(game, Vector2i(1, 1))))
	_hover(board, Vector2i(1, 2))
	assert_true(ui.hand_views()[ui.hand_index("pawn")].is_highlighted, "hovering the target previews the Pawn card")
	assert_false(ui.hand_views()[ui.hand_index("move")].is_highlighted)
	ui.click_square(Vector2i(1, 2))
	assert_true(await ui.wait_match_idle())
	assert_false(ui.hand_uids().has(pawn_card.uid), "the Pawn card was played")
	assert_true(ui.hand_uids().has(move_card.uid), "Move stays in hand")
	assert_eq(game.energy(ChessMatch.PLAYER), 2)
	assert_eq(game.piece_at(Vector2i(1, 2)).type, "pawn")

	# Piece-first knight e1 -> d3: the 0-cost Cheaper knight beats the normal knight and Move.
	ui.click_square(Vector2i(4, 0))
	ui.click_square(Vector2i(3, 2))
	assert_true(await ui.wait_match_idle())
	assert_false(ui.hand_uids().has(cheap_knight.uid), "the cheapest card that allows the move was played")
	assert_true(ui.hand_uids().has(knight_card.uid))
	assert_eq(game.energy(ChessMatch.PLAYER), 2, "a 0-cost card costs nothing")
	assert_eq(game.piece_at(Vector2i(3, 2)).type, "knight")

	# Card-first: an unplayable card (no rook on the board) is refused, not selected.
	var rook_index := ui.hand_index("rook")
	ui.click_card(rook_index)
	assert_false(ui.hand_views()[rook_index].is_selected, "an unplayable card can't be selected")
	assert_eq(board.movable, MatchUiLogic.movable_pieces(game))

	# Card-first: Move -> king c1 -> c2 plays Move even though it is the only card for the king.
	var move_index := ui.hand_index("move")
	ui.click_card(move_index)
	assert_eq(board.movable, game.pieces_for_card(move_index), "Move outlines every piece it can move")
	assert_true(board.movable.has(Vector2i(2, 0)), "the king is movable with Move")
	ui.click_square(Vector2i(2, 0))
	assert_eq(_sorted(board.targets + board.captures), _sorted(game.targets(move_index, Vector2i(2, 0))))
	ui.click_square(Vector2i(2, 1))
	assert_true(await ui.wait_match_idle())
	assert_false(ui.hand_uids().has(move_card.uid))
	assert_eq(game.piece_at(Vector2i(2, 1)).type, "king")
	assert_eq(game.energy(ChessMatch.PLAYER), 1)

	# Card-first: Knight selected, clicking the pawn is refused, the selection stays; then the knight.
	var knight_index := ui.hand_index("knight")
	ui.click_card(knight_index)
	ui.click_square(Vector2i(1, 2))
	assert_true(ui.hand_views()[knight_index].is_selected, "a piece the card can't move doesn't drop the card")
	assert_eq(board.selected, Vector2i(3, 2), "the only knight was pre-selected")
	var target: Vector2i = game.targets(knight_index, Vector2i(3, 2))[0]
	ui.click_square(target)
	assert_true(await ui.wait_match_idle())
	assert_false(ui.hand_uids().has(knight_card.uid), "the selected Knight card was played")
	assert_eq(game.piece_at(target).type, "knight")
	assert_eq(game.energy(ChessMatch.PLAYER), 0)
	assert_eq(game.hand(ChessMatch.PLAYER).size(), 1, "only the Rook is left")


func _first_playable_card(game: ChessMatch) -> int:
	for i in game.hand(ChessMatch.PLAYER).size():
		if game.is_card_playable(i):
			return i
	return -1


func _hover(board: BoardView, square: Vector2i) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = board.square_centre(square)
	board._gui_input(motion)


func _sorted(squares: Array) -> Array:
	var copy := squares.duplicate()
	copy.sort()
	return copy
