extends GutTest
## Raw piece movement (D16, D17, D18), independent of cards.

const H := preload("res://tests/unit/match/match_helper.gd")
const CENTER := Vector2i(2, 2)


func _game(player_extra: Array, opponent_extra: Array = [], options: Dictionary = {}) -> ChessMatch:
	var player_roster: Array = [H.piece("king", Vector2i(5, 0))] + player_extra
	var opponent_roster: Array = [H.piece("king", Vector2i(0, 5))] + opponent_extra
	return H.make(player_roster, opponent_roster, H.FIVE_MOVES, H.FIVE_MOVES, options)


func test_rook_slides_straight_to_the_edges() -> void:
	var game := _game([H.piece("rook", CENTER)])
	var expected := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
		Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]
	assert_eq(H.sorted(game.piece_moves(CENTER)), H.sorted(expected))


func test_rook_is_blocked_by_own_piece_and_captures_enemy() -> void:
	var game := _game([H.piece("rook", CENTER), H.piece("pawn", Vector2i(2, 4))], [H.piece("pawn", Vector2i(4, 2))])
	var moves := game.piece_moves(CENTER)
	assert_true(moves.has(Vector2i(2, 3)))
	assert_false(moves.has(Vector2i(2, 4)), "own piece blocks")
	assert_false(moves.has(Vector2i(2, 5)), "can't pass own piece")
	assert_true(moves.has(Vector2i(4, 2)), "can capture enemy")
	assert_false(moves.has(Vector2i(5, 2)), "can't pass enemy")


func test_bishop_slides_diagonally() -> void:
	var game := _game([H.piece("bishop", CENTER)])
	var expected := [Vector2i(3, 3), Vector2i(4, 4), Vector2i(5, 5), Vector2i(1, 1), Vector2i(0, 0),
		Vector2i(3, 1), Vector2i(4, 0), Vector2i(1, 3), Vector2i(0, 4)]
	assert_eq(H.sorted(game.piece_moves(CENTER)), H.sorted(expected))


func test_bishop_blocked_and_captures() -> void:
	var game := _game([H.piece("bishop", CENTER), H.piece("pawn", Vector2i(1, 1))], [H.piece("knight", Vector2i(4, 4))])
	var moves := game.piece_moves(CENTER)
	assert_false(moves.has(Vector2i(1, 1)))
	assert_false(moves.has(Vector2i(0, 0)))
	assert_true(moves.has(Vector2i(4, 4)))
	assert_false(moves.has(Vector2i(5, 5)))


func test_queen_combines_rook_and_bishop() -> void:
	var game := _game([H.piece("queen", CENTER)])
	assert_eq(game.piece_moves(CENTER).size(), 19)


func test_knight_jumps_in_l_shapes_over_pieces() -> void:
	var blockers := [H.piece("pawn", Vector2i(2, 3)), H.piece("pawn", Vector2i(3, 2)), H.piece("pawn", Vector2i(3, 3)),
		H.piece("pawn", Vector2i(1, 2)), H.piece("pawn", Vector2i(2, 1))]
	var game := _game([H.piece("knight", CENTER)] + blockers)
	var expected := [Vector2i(4, 3), Vector2i(4, 1), Vector2i(0, 3), Vector2i(0, 1),
		Vector2i(3, 4), Vector2i(1, 4), Vector2i(3, 0), Vector2i(1, 0)]
	assert_eq(H.sorted(game.piece_moves(CENTER)), H.sorted(expected))


func test_knight_in_corner_and_own_piece_on_target() -> void:
	var game := _game([H.piece("knight", Vector2i(0, 0)), H.piece("pawn", Vector2i(1, 2))])
	assert_eq(game.piece_moves(Vector2i(0, 0)), [Vector2i(2, 1)] as Array[Vector2i])


func test_king_moves_one_square_any_direction() -> void:
	var game := _game([H.piece("rook", Vector2i(5, 5))])
	assert_eq(game.piece_moves(Vector2i(5, 0)).size(), 3, "corner king")
	var center_game := H.make([H.piece("king", CENTER)], [H.piece("king", Vector2i(5, 5))])
	assert_eq(center_game.piece_moves(CENTER).size(), 8)


func test_player_pawn_moves_up_one_and_captures_diagonally() -> void:
	var game := _game([H.piece("pawn", Vector2i(2, 1)), H.piece("pawn", Vector2i(1, 2))], [H.piece("pawn", Vector2i(3, 2))])
	assert_eq(H.sorted(game.piece_moves(Vector2i(2, 1))), H.sorted([Vector2i(2, 2), Vector2i(3, 2)]))


func test_pawn_has_no_double_step_and_no_forward_capture() -> void:
	var game := _game([H.piece("pawn", Vector2i(2, 0)), H.piece("pawn", Vector2i(4, 1))], [H.piece("pawn", Vector2i(4, 2))])
	assert_eq(game.piece_moves(Vector2i(2, 0)), [Vector2i(2, 1)] as Array[Vector2i])
	assert_eq(game.piece_moves(Vector2i(4, 1)), [] as Array[Vector2i], "blocked by enemy in front")


func test_opponent_pawn_moves_down() -> void:
	var game := _game([H.piece("pawn", Vector2i(1, 3))], [H.piece("pawn", Vector2i(2, 4))])
	assert_eq(H.sorted(game.piece_moves(Vector2i(2, 4))), H.sorted([Vector2i(2, 3), Vector2i(1, 3)]))


func test_pawn_on_edge_file_captures_only_inward() -> void:
	var game := _game([H.piece("pawn", Vector2i(0, 2))], [H.piece("pawn", Vector2i(1, 3))])
	assert_eq(H.sorted(game.piece_moves(Vector2i(0, 2))), H.sorted([Vector2i(0, 3), Vector2i(1, 3)]))


func test_range_king_moves_two_with_clear_path() -> void:
	var game := H.make([H.piece("king", CENTER, "standard", "range"), H.piece("pawn", Vector2i(3, 2))], [H.piece("king", Vector2i(5, 5))])
	var moves := game.piece_moves(CENTER)
	assert_true(moves.has(Vector2i(4, 4)))
	assert_true(moves.has(Vector2i(2, 4)))
	assert_false(moves.has(Vector2i(3, 2)), "own piece")
	assert_false(moves.has(Vector2i(4, 2)), "path blocked")
	assert_eq(moves.size(), 14)


func test_range_pawn_moves_two_but_captures_one() -> void:
	var game := _game([H.piece("pawn", Vector2i(2, 1), "standard", "range")], [H.piece("pawn", Vector2i(4, 3)), H.piece("pawn", Vector2i(3, 2))])
	assert_eq(H.sorted(game.piece_moves(Vector2i(2, 1))), H.sorted([Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2)]))


func test_range_pawn_path_must_be_clear() -> void:
	var game := _game([H.piece("pawn", Vector2i(2, 1), "standard", "range"), H.piece("pawn", Vector2i(4, 1), "standard", "range")],
		[H.piece("pawn", Vector2i(2, 2)), H.piece("pawn", Vector2i(4, 3))])
	assert_eq(game.piece_moves(Vector2i(2, 1)), [] as Array[Vector2i])
	assert_eq(game.piece_moves(Vector2i(4, 1)), [Vector2i(4, 2)] as Array[Vector2i], "no forward capture at range 2")


func test_range_knight_gets_long_leaps() -> void:
	var game := _game([H.piece("knight", CENTER, "standard", "range")])
	var moves := game.piece_moves(CENTER)
	assert_eq(moves.size(), 12)
	for square in [Vector2i(5, 3), Vector2i(5, 1), Vector2i(3, 5), Vector2i(1, 5)]:
		assert_true(moves.has(square), str(square))


func test_range_has_no_effect_on_sliders() -> void:
	for type in ["rook", "bishop", "queen"]:
		var plain := _game([H.piece(type, CENTER)])
		var ranged := _game([H.piece(type, CENTER, "standard", "range")])
		assert_eq(H.sorted(ranged.piece_moves(CENTER)), H.sorted(plain.piece_moves(CENTER)), type)


func test_holes_block_sliders_pawns_and_kings() -> void:
	var holes: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
	var game := _game([H.piece("rook", CENTER), H.piece("pawn", Vector2i(3, 2)), H.piece("king", Vector2i(4, 2), "standard", "range")], [], {"holes": holes})
	var rook_moves := game.piece_moves(CENTER)
	assert_false(rook_moves.has(Vector2i(2, 3)), "can't stop on hole")
	assert_false(rook_moves.has(Vector2i(2, 4)), "can't pass hole")
	assert_eq(game.piece_moves(Vector2i(3, 2)), [] as Array[Vector2i], "pawn blocked by hole")
	var king_moves := game.piece_moves(Vector2i(4, 2))
	assert_false(king_moves.has(Vector2i(3, 3)))
	assert_false(king_moves.has(Vector2i(2, 4)), "range king blocked by hole")


func test_holes_block_bishops_and_queens() -> void:
	var holes: Array[Vector2i] = [Vector2i(3, 3)]
	var game := _game([H.piece("bishop", CENTER), H.piece("queen", Vector2i(4, 3))], [], {"holes": holes})
	assert_false(game.piece_moves(CENTER).has(Vector2i(4, 4)))
	var queen_moves := game.piece_moves(Vector2i(4, 3))
	assert_false(queen_moves.has(Vector2i(3, 3)))
	assert_false(queen_moves.has(Vector2i(2, 3)))


func test_knights_jump_over_holes_but_cannot_land_on_them() -> void:
	var holes: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2)]
	var game := _game([H.piece("knight", CENTER)], [], {"holes": holes})
	var moves := game.piece_moves(CENTER)
	assert_true(moves.has(Vector2i(3, 4)), "jumps over holes")
	assert_true(moves.has(Vector2i(4, 3)))
	var lander := _game([H.piece("knight", Vector2i(1, 1))], [], {"holes": holes})
	assert_false(lander.piece_moves(Vector2i(1, 1)).has(Vector2i(2, 3)), "can't land on hole")
	assert_false(lander.piece_moves(Vector2i(1, 1)).has(Vector2i(3, 2)))


func test_piece_moves_on_empty_square_is_empty() -> void:
	var game := _game([])
	assert_eq(game.piece_moves(CENTER), [] as Array[Vector2i])
	assert_eq(game.piece_moves(Vector2i(9, 9)), [] as Array[Vector2i])


func test_range_king_is_blocked_by_holes() -> void:
	var holes: Array[Vector2i] = [Vector2i(3, 3)]
	var game := H.make([H.piece("king", CENTER, "standard", "range")], [H.piece("king", Vector2i(5, 5))], H.FIVE_MOVES, H.FIVE_MOVES, {"holes": holes})
	var moves := game.piece_moves(CENTER)
	assert_false(moves.has(Vector2i(3, 3)), "can't stop on a hole")
	assert_false(moves.has(Vector2i(4, 4)), "can't pass a hole")
	assert_true(moves.has(Vector2i(4, 2)))
	assert_eq(moves.size(), 14)


func test_range_pawn_is_blocked_by_holes() -> void:
	var holes: Array[Vector2i] = [Vector2i(2, 3), Vector2i(4, 2)]
	var game := _game([H.piece("pawn", Vector2i(2, 1), "standard", "range"), H.piece("pawn", Vector2i(4, 1), "standard", "range")], [], {"holes": holes})
	assert_eq(game.piece_moves(Vector2i(2, 1)), [Vector2i(2, 2)] as Array[Vector2i], "hole on the second step")
	assert_eq(game.piece_moves(Vector2i(4, 1)), [] as Array[Vector2i], "hole on the first step blocks both")


func test_range_knight_long_leap_jumps_holes_but_cannot_land_on_one() -> void:
	var holes: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 1)]
	var game := _game([H.piece("knight", CENTER, "standard", "range")], [], {"holes": holes})
	var moves := game.piece_moves(CENTER)
	assert_true(moves.has(Vector2i(5, 3)), "long leap over holes")
	assert_false(moves.has(Vector2i(5, 1)), "can't land on a hole")
	assert_false(moves.has(Vector2i(4, 3)))
