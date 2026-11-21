extends GutTest
## Fire piece set (D22-D25).

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const FIRE := "fire"


func _burn_turns() -> int:
	return int(GameConfig.data("piece_sets")["sets"]["fire"]["burn_turns"])


func _fire_game(player_extra: Array, opponent_extra: Array = [], options: Dictionary = {}) -> ChessMatch:
	var player_roster: Array = [H.piece("king", Vector2i(5, 0), FIRE)] + player_extra
	var opponent_roster: Array = [H.piece("king", Vector2i(5, 5))] + opponent_extra
	return H.make(player_roster, opponent_roster, H.FIVE_MOVES, H.FIVE_MOVES, options)


func test_fire_piece_ignites_the_first_time_it_moves() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE)])
	assert_false(game.piece_at(Vector2i(0, 0)).is_burning())
	var events := game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	var ignite := H.events_of(events, "ignite")
	assert_eq(ignite.size(), 1)
	assert_eq(ignite[0]["turns_left"], _burn_turns())
	assert_eq(game.piece_at(Vector2i(0, 2)).burn_turns_left, _burn_turns())
	events = game.play(0, Vector2i(0, 2), Vector2i(0, 3))
	assert_eq(H.events_of(events, "ignite").size(), 0, "moving again does not reset")


func test_burn_ticks_at_end_of_owner_turn_and_burns_out() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE)])
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	var events := game.end_turn()
	assert_eq(H.events_of(events, "burn_tick")[0]["turns_left"], _burn_turns() - 1, "ignition turn counts")
	game.end_turn()
	assert_eq(game.piece_at(Vector2i(0, 2)).burn_turns_left, _burn_turns() - 1, "opponent turn does not tick")
	game.end_turn()
	game.end_turn()
	assert_eq(game.piece_at(Vector2i(0, 2)).burn_turns_left, 1)
	events = game.end_turn()
	assert_null(game.piece_at(Vector2i(0, 2)), "burned out")
	var burn_out := H.events_of(events, "burn_out")
	assert_eq(burn_out.size(), 1)
	assert_eq(burn_out[0]["by_side"], O)
	assert_eq(burn_out[0]["points"], 4, "fire rook worth 5 - 1")
	assert_eq(game.score(O), 4)
	assert_eq(game.result(), {})


func test_unmoved_fire_piece_never_burns() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE)])
	for _i in 10:
		game.end_turn()
	assert_eq(game.piece_at(Vector2i(0, 0)).type, "rook")


func test_fire_king_does_not_burn_or_get_capture_bonus() -> void:
	var game := _fire_game([], [H.piece("pawn", Vector2i(4, 1))])
	var events := game.play(0, Vector2i(5, 0), Vector2i(4, 1))
	assert_eq(H.events_of(events, "ignite").size(), 0)
	assert_eq(game.score(P), 1, "no +2 for the king")


func test_fire_capture_bonus() -> void:
	var game := _fire_game([H.piece("knight", Vector2i(0, 0), FIRE)], [H.piece("pawn", Vector2i(1, 2))])
	var events := game.play(0, Vector2i(0, 0), Vector2i(1, 2))
	assert_eq(game.score(P), 3, "pawn 1 + fire bonus 2")
	assert_eq(H.events_of(events, "capture")[0]["points"], 3)


func test_fire_capture_bonus_while_already_burning() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE)], [H.piece("knight", Vector2i(3, 2))])
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	game.play(0, Vector2i(0, 2), Vector2i(3, 2))
	assert_eq(game.score(P), 5)


func test_fire_bonus_stacks_with_trophy_case() -> void:
	var game := _fire_game([H.piece("knight", Vector2i(0, 0), FIRE)], [H.piece("pawn", Vector2i(1, 2))], {"player_artifacts": ["capture_bonus"]})
	game.play(0, Vector2i(0, 0), Vector2i(1, 2))
	assert_eq(game.score(P), 4, "1 + 2 + 1")


func test_fire_pieces_are_worth_one_less_and_fire_pawns_zero() -> void:
	var game := _fire_game([H.piece("pawn", Vector2i(0, 1), FIRE), H.piece("rook", Vector2i(1, 1), FIRE)],
		[H.piece("rook", Vector2i(0, 5)), H.piece("bishop", Vector2i(3, 3))])
	game.end_turn()
	game.play(0, Vector2i(0, 5), Vector2i(0, 1))
	assert_eq(game.score(O), 0, "fire pawn worth 0")
	game.play(0, Vector2i(3, 3), Vector2i(1, 1))
	assert_eq(game.score(O), 4, "fire rook worth 4")


func test_burn_out_gives_opponent_its_trophy_bonus() -> void:
	var game := _fire_game([H.piece("pawn", Vector2i(0, 1), FIRE)], [], {"opponent_artifacts": ["capture_bonus"]})
	game.play(0, Vector2i(0, 1), Vector2i(0, 2))
	for _i in _burn_turns() * 2 - 1:
		game.end_turn()
	assert_null(game.piece_at(Vector2i(0, 2)))
	assert_eq(game.score(O), 1, "fire pawn 0 + trophy 1")


func test_burn_out_can_reach_the_target_score() -> void:
	var game := _fire_game([H.piece("queen", Vector2i(0, 0), FIRE), H.piece("rook", Vector2i(2, 1), FIRE)], [H.piece("rook", Vector2i(2, 5))])
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	game.end_turn()
	game.play(0, Vector2i(2, 5), Vector2i(2, 1))
	assert_eq(game.score(O), 4)
	for _i in _burn_turns() * 2 - 2:
		game.end_turn()
	assert_eq(game.score(O), 11, "rook 4 + burned queen 7")
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["reason"], "score")


func test_fire_attack_blocked_by_shield_does_not_ignite() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE)], [H.piece("pawn", Vector2i(0, 3), "standard", "shield")])
	var events := game.play(0, Vector2i(0, 0), Vector2i(0, 3))
	assert_eq(H.events_of(events, "ignite").size(), 0)
	assert_false(game.piece_at(Vector2i(0, 0)).is_burning())


func test_promoted_fire_pawn_is_a_fire_queen() -> void:
	var game := _fire_game([H.piece("pawn", Vector2i(0, 4), FIRE)], [H.piece("rook", Vector2i(3, 5))])
	game.play(0, Vector2i(0, 4), Vector2i(0, 5))
	assert_eq(game.piece_at(Vector2i(0, 5)).value(), 7)
	assert_true(game.piece_at(Vector2i(0, 5)).is_burning())


func test_opponent_standard_pieces_never_burn() -> void:
	var game := _fire_game([], [H.piece("rook", Vector2i(0, 5))])
	game.end_turn()
	var events := game.play(0, Vector2i(0, 5), Vector2i(0, 3))
	assert_eq(H.events_of(events, "ignite").size(), 0)


func test_burn_out_ignores_a_shield() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE, "shield")])
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	var events: Array[Dictionary] = []
	for _i in _burn_turns() * 2 - 1:
		events.append_array(game.end_turn())
	assert_null(game.piece_at(Vector2i(0, 2)))
	assert_eq(H.events_of(events, "burn_out").size(), 1)
	assert_eq(H.events_of(events, "shield_block").size(), 0)
	assert_eq(game.score(O), 4)
	assert_false(game.is_over())


func test_burning_piece_that_is_captured_stops_burning() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE)], [H.piece("rook", Vector2i(5, 2))])
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	game.end_turn()
	game.play(0, Vector2i(5, 2), Vector2i(0, 2))
	assert_eq(game.score(O), 4)
	var events: Array[Dictionary] = []
	for _i in _burn_turns() * 2:
		events.append_array(game.end_turn())
	assert_eq(H.events_of(events, "burn_tick").size(), 0)
	assert_eq(H.events_of(events, "burn_out").size(), 0)
	assert_eq(game.score(O), 4, "credited once")


func test_burning_piece_caught_in_an_explosion() -> void:
	var game := _fire_game([H.piece("rook", Vector2i(0, 0), FIRE), H.piece("pawn", Vector2i(1, 1))],
		[H.piece("bishop", Vector2i(3, 3))], {"opponent_artifacts": ["exploding"]})
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	game.end_turn()
	game.play(0, Vector2i(3, 3), Vector2i(1, 1))
	assert_null(game.piece_at(Vector2i(0, 2)), "exploded")
	assert_eq(game.score(O), 5, "standard pawn 1 + fire rook 4")
	var events: Array[Dictionary] = []
	for _i in _burn_turns() * 2:
		events.append_array(game.end_turn())
	assert_eq(H.events_of(events, "burn_out").size(), 0)
	assert_eq(game.score(O), 5)


func test_fire_capture_that_triggers_an_explosion() -> void:
	var game := _fire_game([H.piece("knight", Vector2i(0, 0), FIRE)],
		[H.piece("pawn", Vector2i(1, 2)), H.piece("pawn", Vector2i(2, 3))], {"player_artifacts": ["exploding"]})
	var events := game.play(0, Vector2i(0, 0), Vector2i(1, 2))
	var captures := H.events_of(events, "capture")
	assert_eq(captures.size(), 2)
	assert_eq(captures[0]["points"], 3, "direct capture: 1 + fire 2")
	assert_eq(captures[1]["points"], 1, "explosion: no fire bonus")
	assert_eq(game.score(P), 4)
	assert_true(game.piece_at(Vector2i(1, 2)).is_burning(), "the attacker still ignites")
	var types := events.map(func(event: Dictionary) -> String: return event["type"])
	assert_lt(types.find("explosion"), types.find("ignite"))
