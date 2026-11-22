extends GutTest
## Piece-first card choice and the other legal-play filters used by the match screen.

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER


func _game(deck: Array, extra: Array) -> ChessMatch:
	var roster: Array = [H.piece("king", Vector2i(0, 0))] + extra
	return H.make(roster, [H.piece("king", Vector2i(5, 5))], deck)


func test_pick_play_prefers_cheapest_card() -> void:
	var game := _game(["rook", "move", "pawn", "pawn", "pawn"], [H.piece("rook", Vector2i(3, 0))])
	var play := MatchUiLogic.pick_play(game, Vector2i(3, 0), Vector2i(3, 3))
	assert_eq(game.hand(P)[play["card_index"]].type, "move")


func test_pick_play_prefers_typed_card_on_tie() -> void:
	var game := _game(["move", "knight", "pawn", "pawn", "pawn"], [H.piece("knight", Vector2i(1, 0))])
	var play := MatchUiLogic.pick_play(game, Vector2i(1, 0), Vector2i(2, 2))
	assert_eq(game.hand(P)[play["card_index"]].type, "knight")


func test_pick_play_prefers_cheaper_upgraded_card() -> void:
	var game := _game(["move", "knight:cheaper", "pawn", "pawn", "pawn"], [H.piece("knight", Vector2i(1, 0))])
	var play := MatchUiLogic.pick_play(game, Vector2i(1, 0), Vector2i(2, 2))
	assert_eq(game.hand(P)[play["card_index"]].upgrade, "cheaper")


func test_pick_play_is_empty_for_illegal_target() -> void:
	var game := _game(["knight", "pawn", "pawn", "pawn", "pawn"], [H.piece("knight", Vector2i(1, 0))])
	assert_eq(MatchUiLogic.pick_play(game, Vector2i(1, 0), Vector2i(1, 1)), {})


func test_targets_for_piece_merges_all_cards() -> void:
	var game := _game(["pawn", "pawn", "pawn", "pawn", "pawn"], [H.piece("pawn", Vector2i(2, 1))])
	assert_eq(MatchUiLogic.targets_for_piece(game, Vector2i(2, 1)), [Vector2i(2, 2)] as Array[Vector2i])
	assert_eq(MatchUiLogic.targets_for_piece(game, Vector2i(0, 0)), [] as Array[Vector2i], "no Move card, king can't move")


func test_movable_pieces_lists_each_piece_once() -> void:
	var game := _game(["move", "move", "move", "move", "move"], [H.piece("pawn", Vector2i(2, 1))])
	assert_eq(H.sorted(MatchUiLogic.movable_pieces(game)), [Vector2i(0, 0), Vector2i(2, 1)])


func test_unplayable_reason_names_missing_piece() -> void:
	var game := _game(["rook", "pawn", "pawn", "pawn", "pawn"], [H.piece("pawn", Vector2i(2, 1))])
	var rook_index := H.card_index(game, "rook")
	assert_string_contains(MatchUiLogic.unplayable_reason(game, rook_index), "No rook")
	assert_eq(MatchUiLogic.unplayable_reason(game, H.card_index(game, "pawn")), "")


func test_event_text_names_squares() -> void:
	var line := EventText.describe({"type": "move", "side": 0, "piece_type": "knight", "from": Vector2i(1, 0), "to": Vector2i(2, 2)}, ["You", "Rex"])
	assert_eq(line, "Knight b1 → c3")
	assert_eq(EventText.describe({"type": "energy", "side": 0, "energy": 3}, ["You", "Rex"]), "")


func test_redraw_leaves_a_play_compares_with_cheapest_deck_card() -> void:
	var deck := H.cards(["rook", "queen", "knight"])
	assert_true(MatchUiLogic.redraw_leaves_a_play(2, 1, deck), "1 energy left pays for the knight")
	assert_false(MatchUiLogic.redraw_leaves_a_play(1, 1, deck), "0 energy left pays for nothing")
	assert_true(MatchUiLogic.redraw_leaves_a_play(1, 1, H.cards(["pawn:cheaper"])), "a 0-cost card counts")
	assert_false(MatchUiLogic.redraw_leaves_a_play(3, 1, []))


func _checking_game() -> ChessMatch:
	# The player's rook gives check along the file; the opponent king can step aside.
	var game := H.make([H.piece("king", Vector2i(0, 0)), H.piece("rook", Vector2i(3, 1))],
		[H.piece("king", Vector2i(2, 5))], ["rook", "rook", "rook", "rook", "rook"])
	game.play(H.card_index(game, "rook"), Vector2i(3, 1), Vector2i(2, 1))
	return game


func test_next_turn_energy_counts_pending_escapes() -> void:
	var game := _checking_game()
	assert_eq(game.pending_escape_side(), ChessMatch.OPPONENT)
	assert_eq(MatchUiLogic.next_turn_energy(game, ChessMatch.OPPONENT), 3)
	assert_eq(MatchUiLogic.next_turn_energy(game, ChessMatch.OPPONENT, 1), 2)
	game.escape(game.escape_squares()[0])
	assert_eq(MatchUiLogic.next_turn_energy(game, ChessMatch.OPPONENT), 2)


func test_escape_targets_split_moves_and_captures() -> void:
	var game := _checking_game()
	var targets := MatchUiLogic.escape_targets(game)
	assert_eq(targets["captures"], [] as Array[Vector2i])
	assert_eq(H.sorted(targets["moves"]), H.sorted(game.escape_squares()))
	assert_false(targets["moves"].is_empty())


func test_event_text_for_check_and_escape() -> void:
	var names := ["You", "Rex"]
	var check := {"type": "check", "side": 1, "king_square": Vector2i(2, 5), "can_escape": true}
	assert_eq(EventText.describe(check, names), "Check! Rex's king on c6 is attacked")
	var escape := {"type": "escape", "side": 1, "from": Vector2i(2, 5), "to": Vector2i(3, 5), "cost": 1}
	assert_string_contains(EventText.describe(escape, names), "c6 → d6")
	assert_eq(EventText.describe({"type": "escape_declined", "side": 0}, names), "You stayed in check")
