extends GutTest
## Win/loss reasons (king, score, no_moves, turn_limit), D13 order and promotion (D12).

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT

var _saved_moves_first: Variant


func before_each() -> void:
	_saved_moves_first = GameConfig.data("match")["player_moves_first"]


func after_each() -> void:
	GameConfig.data("match")["player_moves_first"] = _saved_moves_first


func _assert_actions_rejected(game: ChessMatch) -> void:
	var before := H.snapshot(game)
	assert_eq(game.play(0, Vector2i(0, 0), Vector2i(0, 1))[0]["type"], "error")
	assert_eq(game.end_turn()[0]["reason"], "match_over")
	assert_eq(game.redraw()[0]["type"], "error")
	assert_false(game.can_redraw())
	assert_eq(game.legal_plays(game.current_side()), [] as Array[Dictionary])
	assert_eq(H.snapshot(game), before)


func test_capturing_the_enemy_king_wins() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 2))], [H.piece("king", Vector2i(0, 5))])
	var events := game.play(0, Vector2i(0, 2), Vector2i(0, 5))
	assert_true(game.is_over())
	var result := game.result()
	assert_eq(result["winner"], P)
	assert_eq(result["reason"], "king")
	assert_eq(H.events_of(events, "match_over")[0]["winner"], P)
	assert_eq(H.events_of(events, "capture")[0]["piece_type"], "king")
	assert_eq(game.score(P), 0, "king is worth 0")
	_assert_actions_rejected(game)


func test_losing_your_king_loses() -> void:
	var game := H.make([H.piece("king", Vector2i(0, 0))], [H.piece("king", Vector2i(5, 5)), H.piece("rook", Vector2i(0, 5))])
	game.end_turn()
	game.play(0, Vector2i(0, 5), Vector2i(0, 0))
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["reason"], "king")


func test_first_to_target_score_wins() -> void:
	assert_eq(GameConfig.value("match", "target_score"), 10.0)
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(3, 2))],
		[H.piece("king", Vector2i(0, 5)), H.piece("queen", Vector2i(3, 5)), H.piece("knight", Vector2i(4, 5))])
	game.play(0, Vector2i(3, 2), Vector2i(3, 5))
	assert_eq(game.score(P), 8)
	assert_false(game.is_over())
	var events := game.play(0, Vector2i(3, 5), Vector2i(4, 5))
	assert_eq(game.score(P), 11)
	assert_eq(game.result()["reason"], "score")
	assert_eq(game.result()["winner"], P)
	assert_eq(game.result()["scores"], [11, 0])
	var score_events := H.events_of(events, "score")
	assert_eq(score_events[0]["points"], 3)
	assert_eq(score_events[0]["total"], 11)


func test_side_without_any_piece_move_at_turn_start_loses() -> void:
	var game := H.make([H.piece("pawn", Vector2i(0, 4))], [H.piece("king", Vector2i(0, 5))])
	assert_true(game.is_over(), "player is stuck before playing")
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["reason"], "no_moves")
	assert_eq(H.events_of(game.initial_events(), "match_over").size(), 1)


func test_opponent_without_moves_loses_at_its_turn_start() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("pawn", Vector2i(5, 1))])
	assert_false(game.is_over())
	var events := game.end_turn()
	assert_eq(game.result()["winner"], P)
	assert_eq(game.result()["reason"], "no_moves")
	assert_eq(H.events_of(events, "match_over").size(), 1)


func test_bad_hand_is_not_a_loss() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("king", Vector2i(0, 5))], ["rook", "rook", "rook", "rook", "rook"])
	assert_false(game.is_over())
	assert_eq(game.legal_plays(P), [] as Array[Dictionary])


func _run_to_turn_limit(game: ChessMatch) -> int:
	var turns := 0
	while not game.is_over() and turns < 1000:
		game.end_turn()
		turns += 1
	return turns


func test_turn_limit_tie_goes_to_the_opponent() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("king", Vector2i(0, 5))])
	var max_rounds := int(GameConfig.value("match", "max_rounds"))
	assert_eq(game.max_rounds(), max_rounds)
	assert_eq(_run_to_turn_limit(game), max_rounds * 2)
	assert_eq(game.result()["reason"], "turn_limit")
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["rounds"], max_rounds)
	assert_eq(game.current_round(), max_rounds)


func test_turn_limit_higher_score_wins() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(0, 4))])
	game.play(0, Vector2i(0, 0), Vector2i(0, 4))
	_run_to_turn_limit(game)
	assert_eq(game.result()["reason"], "turn_limit")
	assert_eq(game.result()["winner"], P)


func test_turn_limit_opponent_higher_score_wins() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("pawn", Vector2i(0, 1))],
		[H.piece("king", Vector2i(5, 5)), H.piece("rook", Vector2i(0, 5))])
	game.end_turn()
	game.play(0, Vector2i(0, 5), Vector2i(0, 1))
	_run_to_turn_limit(game)
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["scores"], [0, 1])


func test_both_kings_in_one_explosion_loses_for_the_mover() -> void:
	var game := H.make([H.piece("king", Vector2i(1, 2)), H.piece("rook", Vector2i(2, 0))],
		[H.piece("king", Vector2i(3, 4)), H.piece("pawn", Vector2i(2, 3))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["exploding"]})
	game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["reason"], "king")


func test_both_sides_reaching_target_on_one_move_wins_for_the_mover() -> void:
	var game := H.make(
		[H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 2)), H.piece("queen", Vector2i(2, 1)), H.piece("knight", Vector2i(3, 3))],
		[H.piece("king", Vector2i(5, 5)), H.piece("queen", Vector2i(0, 4)), H.piece("rook", Vector2i(2, 5)), H.piece("knight", Vector2i(3, 4))],
		H.FIVE_MOVES, H.FIVE_MOVES, {"player_artifacts": ["exploding"]})
	game.play(0, Vector2i(0, 2), Vector2i(0, 4))
	assert_eq(game.score(P), 8)
	game.end_turn()
	game.play(0, Vector2i(2, 5), Vector2i(2, 1))
	assert_eq(game.score(O), 8)
	game.end_turn()
	game.play(0, Vector2i(0, 4), Vector2i(3, 4))
	assert_eq(game.score(P), 11)
	assert_eq(game.score(O), 11, "own knight exploded")
	assert_eq(game.result()["winner"], P)
	assert_eq(game.result()["reason"], "score")


func test_king_loss_is_checked_before_score() -> void:
	var game := H.make([H.piece("king", Vector2i(1, 4)), H.piece("rook", Vector2i(2, 0))],
		[H.piece("king", Vector2i(5, 0)), H.piece("queen", Vector2i(2, 5)), H.piece("rook", Vector2i(2, 4))],
		H.FIVE_MOVES, H.FIVE_MOVES, {"player_artifacts": ["exploding"]})
	game.play(0, Vector2i(2, 0), Vector2i(2, 4))
	assert_true(game.is_over())
	assert_eq(game.score(P), 13, "rook 5 + exploded queen 8")
	assert_eq(game.result()["winner"], O, "own king exploded")
	assert_eq(game.result()["reason"], "king")


func test_player_pawn_promotes_to_queen_on_the_far_rank() -> void:
	var data := PieceData.new("pawn")
	var roster := [{"piece": data, "square": Vector2i(1, 4)}, H.piece("king", Vector2i(5, 0))]
	var game := H.make(roster, [H.piece("king", Vector2i(5, 3))], ["pawn", "pawn", "move", "move", "move"])
	var events := H.play_type(game, "pawn", Vector2i(1, 4), Vector2i(1, 5))
	var promotion := H.events_of(events, "promotion")
	assert_eq(promotion.size(), 1)
	assert_eq(promotion[0]["piece_type"], "queen")
	var queen := game.piece_at(Vector2i(1, 5))
	assert_eq(queen.type, "queen")
	assert_true(queen.is_promoted)
	assert_eq(game.piece_moves(Vector2i(1, 5)).size(), 15, "moves like a queen")
	assert_eq(game.targets(H.card_index(game, "pawn"), Vector2i(1, 5)), [] as Array[Vector2i], "pawn card no longer moves it")
	assert_gt(game.targets(H.card_index(game, "move"), Vector2i(1, 5)).size(), 0)
	assert_eq(data.type, "pawn", "collection piece untouched")


func test_pawn_promotes_when_capturing_onto_the_far_rank() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("pawn", Vector2i(1, 4))],
		[H.piece("king", Vector2i(5, 3)), H.piece("knight", Vector2i(2, 5))])
	var events := game.play(0, Vector2i(1, 4), Vector2i(2, 5))
	assert_eq(H.events_of(events, "promotion").size(), 1)
	assert_eq(game.piece_at(Vector2i(2, 5)).type, "queen")


func test_opponent_pawn_promotes_on_rank_zero() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(2, 1))])
	game.end_turn()
	game.play(0, Vector2i(2, 1), Vector2i(2, 0))
	assert_eq(game.piece_at(Vector2i(2, 0)).type, "queen")


func test_promoted_pawn_is_worth_queen_points() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("pawn", Vector2i(1, 4))],
		[H.piece("king", Vector2i(5, 3)), H.piece("rook", Vector2i(3, 5))])
	game.play(0, Vector2i(1, 4), Vector2i(1, 5))
	game.end_turn()
	game.play(0, Vector2i(3, 5), Vector2i(1, 5))
	assert_eq(game.score(O), 8)


func test_turn_limit_when_the_opponent_moves_first() -> void:
	GameConfig.data("match")["player_moves_first"] = false
	var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("king", Vector2i(0, 5))])
	assert_eq(game.current_side(), O)
	assert_eq(game.hand(O).size(), 5)
	assert_eq(game.hand(P).size(), 0)
	var max_rounds := game.max_rounds()
	var turns := 0
	var last_events: Array[Dictionary] = []
	while not game.is_over() and turns < 1000:
		last_events = game.end_turn()
		turns += 1
	assert_eq(turns, max_rounds * 2)
	assert_eq(H.events_of(last_events, "turn_end")[0]["side"], P, "the player's turn closes the last round")
	assert_eq(game.result()["reason"], "turn_limit")
	assert_eq(game.result()["rounds"], max_rounds)
	assert_eq(game.result()["winner"], O, "tie goes to the opponent")
