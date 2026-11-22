extends GutTest
## Check and check escape (D56-D60).

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const ENEMY_KING := Vector2i(5, 5)


func _cost() -> int:
	return int(GameConfig.value("match", "check_escape_cost"))


func _game(player_pieces: Array, opponent_extra: Array = [], options: Dictionary = {}, king_upgrade: String = "") -> ChessMatch:
	var player_roster: Array = [H.piece("king", Vector2i(0, 0))] + player_pieces
	var opponent_roster: Array = [H.piece("king", ENEMY_KING, "standard", king_upgrade)] + opponent_extra
	return H.make(player_roster, opponent_roster, H.FIVE_MOVES, H.FIVE_MOVES, options)


func test_every_piece_type_can_give_check() -> void:
	var cases := [
		["rook", Vector2i(1, 0), Vector2i(1, 5)],
		["bishop", Vector2i(0, 2), Vector2i(1, 1)],
		["queen", Vector2i(2, 0), Vector2i(2, 5)],
		["knight", Vector2i(2, 2), Vector2i(3, 4)],
		["pawn", Vector2i(4, 3), Vector2i(4, 4)],
		["king", Vector2i(3, 3), Vector2i(4, 4)],
	]
	for case in cases:
		var game := _game([H.piece(case[0], case[1])])
		assert_false(game.in_check(O), case[0])
		var events := game.play(0, case[1], case[2])
		var checks := H.events_of(events, "check")
		assert_eq(checks.size(), 1, case[0])
		assert_true(game.in_check(O), case[0])
		assert_eq(checks[0]["side"], O)
		assert_eq(checks[0]["king_square"], ENEMY_KING)
		assert_eq(checks[0]["checkers"], [case[2]], case[0])
		assert_eq(game.pending_escape_side(), O, case[0])
		assert_eq(game.current_side(), P, "the mover keeps the turn")


func test_moves_that_do_not_attack_the_king_give_no_check() -> void:
	var game := _game([H.piece("pawn", Vector2i(5, 3)), H.piece("rook", Vector2i(1, 0))])
	var events := game.play(0, Vector2i(5, 3), Vector2i(5, 4))
	assert_eq(H.events_of(events, "check").size(), 0, "a pawn does not attack straight ahead")
	events = game.play(0, Vector2i(1, 0), Vector2i(1, 2))
	assert_eq(H.events_of(events, "check").size(), 0)
	assert_eq(game.pending_escape_side(), -1)
	assert_false(game.in_check(O))


func test_a_shield_does_not_prevent_check() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))], [], {}, "shield")
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	assert_eq(game.pending_escape_side(), O)


func test_escape_squares_exclude_attacked_squares() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))])
	var events := game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	var expected := [Vector2i(4, 4), Vector2i(5, 4)]
	assert_eq(H.sorted(game.escape_squares()), expected)
	assert_eq(H.sorted(H.events_of(events, "check")[0]["escape_squares"]), expected)
	assert_true(H.events_of(events, "check")[0]["can_escape"])


func test_range_king_escapes_two_squares() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))], [], {}, "range")
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	assert_true(game.escape_squares().has(Vector2i(3, 3)))
	assert_true(game.escape_squares().has(Vector2i(5, 3)))


func test_king_may_capture_an_undefended_checker() -> void:
	var game := _game([H.piece("rook", Vector2i(4, 0))])
	game.play(0, Vector2i(4, 0), Vector2i(4, 5))
	assert_eq(H.sorted(game.escape_squares()), [Vector2i(4, 5), Vector2i(5, 4)])
	var events := game.escape(Vector2i(4, 5))
	assert_eq(events[0]["type"], "escape")
	assert_eq(events[0]["from"], ENEMY_KING)
	assert_eq(events[0]["to"], Vector2i(4, 5))
	assert_eq(H.events_of(events, "capture")[0]["piece_type"], "rook")
	assert_eq(game.score(O), 5, "escape captures score")
	assert_eq(game.piece_at(Vector2i(4, 5)).type, "king")
	assert_eq(game.pending_escape_side(), -1)
	assert_eq(game.current_side(), P, "the checking side continues")


func test_king_may_not_capture_a_defended_checker() -> void:
	var game := _game([H.piece("rook", Vector2i(4, 0)), H.piece("bishop", Vector2i(2, 3))])
	game.play(0, Vector2i(4, 0), Vector2i(4, 5))
	assert_eq(game.escape_squares(), [Vector2i(5, 4)] as Array[Vector2i])


func test_no_safe_square_means_no_escape() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0)), H.piece("rook", Vector2i(0, 4))])
	var events := game.play(H.card_index(game, "move"), Vector2i(1, 0), Vector2i(1, 5))
	var check := H.events_of(events, "check")[0]
	assert_false(check["can_escape"])
	assert_eq(check["escape_squares"], [] as Array[Vector2i])
	assert_eq(game.pending_escape_side(), -1)
	assert_true(game.in_check(O))
	game.play(0, Vector2i(1, 5), ENEMY_KING)
	assert_eq(game.result()["reason"], "king")


func test_decline_leaves_the_king_in_check() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))])
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	var events := game.decline_escape()
	assert_eq(events, [{"type": "escape_declined", "side": O}] as Array[Dictionary])
	assert_eq(game.pending_escape_side(), -1)
	assert_eq(game.piece_at(ENEMY_KING).type, "king")
	assert_true(game.in_check(O))
	assert_eq(game.escape_penalty(O), 0)
	assert_gt(game.legal_plays(P).size(), 0, "the checking side continues")


func test_every_other_action_is_refused_while_an_escape_is_pending() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))])
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	var before := H.snapshot(game)
	assert_eq(game.play(0, Vector2i(1, 5), Vector2i(1, 4))[0]["reason"], "escape_pending")
	assert_eq(game.redraw()[0]["reason"], "escape_pending")
	assert_eq(game.end_turn()[0]["reason"], "escape_pending")
	assert_eq(game.escape(Vector2i(4, 5))[0]["reason"], "illegal_move", "attacked square")
	assert_eq(game.escape(Vector2i(3, 3))[0]["reason"], "illegal_move")
	assert_eq(game.legal_plays(P), [] as Array[Dictionary])
	assert_eq(game.legal_plays(O), [] as Array[Dictionary])
	assert_eq(game.targets(0, Vector2i(1, 5)), [] as Array[Vector2i])
	assert_false(game.is_card_playable(0))
	assert_false(game.can_redraw())
	assert_eq(H.snapshot(game), before)
	assert_eq(game.pending_escape_side(), O)


func test_escape_and_decline_need_a_pending_check() -> void:
	var game := _game([])
	var before := H.snapshot(game)
	assert_eq(game.escape(Vector2i(4, 4))[0]["reason"], "no_escape_pending")
	assert_eq(game.decline_escape()[0]["reason"], "no_escape_pending")
	assert_eq(H.snapshot(game), before)


func test_escape_penalty_applies_at_next_turn_start_then_resets() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))])
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	var events := game.escape(Vector2i(5, 4))
	assert_eq(events[0]["cost"], _cost())
	assert_eq(events[0]["penalty"], _cost())
	assert_eq(game.escape_penalty(O), _cost())
	assert_eq(game.energy(O), 0, "nothing changes until the opponent's turn")
	events = game.end_turn()
	assert_eq(game.energy(O), game.max_energy(O) - _cost())
	assert_eq(H.events_of(events, "turn_start")[0]["escape_penalty"], _cost())
	assert_eq(H.events_of(events, "energy")[0]["escape_penalty"], _cost())
	assert_eq(game.escape_penalty(O), 0)
	game.end_turn()
	events = game.end_turn()
	assert_eq(game.energy(O), game.max_energy(O))
	assert_eq(H.events_of(events, "turn_start")[0]["escape_penalty"], 0)


## Finds a play that checks the opponent with an escape available (or any check).
func _checking_play(game: ChessMatch, needs_escape: bool) -> Dictionary:
	for play in game.legal_plays(P):
		var copy := game.clone()
		var checks := H.events_of(copy.play(play["card_index"], play["from"], play["to"]), "check")
		if not checks.is_empty() and (checks[0]["can_escape"] or not needs_escape):
			return play
	return {}


func test_escape_budget_limits_escapes_per_turn() -> void:
	var game := _game([H.piece("queen", Vector2i(2, 0)), H.piece("rook", Vector2i(1, 0))], [], {"player_artifacts": ["extra_energy"]})
	var budget := game.max_energy(O)
	for i in budget / _cost():
		var play := _checking_play(game, true)
		assert_false(play.is_empty(), "check %d available" % i)
		if play.is_empty():
			return
		game.play(play["card_index"], play["from"], play["to"])
		game.escape(game.escape_squares()[0])
	assert_eq(game.escape_penalty(O), budget)
	var last := _checking_play(game, false)
	assert_false(last.is_empty())
	if last.is_empty():
		return
	var check := H.events_of(game.play(last["card_index"], last["from"], last["to"]), "check")[0]
	assert_false(check["can_escape"], "budget used up")
	assert_eq(check["budget"], 0)
	assert_eq(game.pending_escape_side(), -1)
	game.end_turn()
	assert_eq(game.energy(O), 0, "next turn starts with no energy")


func test_powder_keg_works_on_an_escape_capture() -> void:
	var game := _game([H.piece("rook", Vector2i(4, 0)), H.piece("knight", Vector2i(3, 5))], [], {"opponent_artifacts": ["exploding"]})
	game.play(0, Vector2i(4, 0), Vector2i(4, 5))
	assert_true(game.escape_squares().has(Vector2i(4, 5)))
	var events := game.escape(Vector2i(4, 5))
	assert_eq(H.events_of(events, "explosion").size(), 1)
	assert_eq(H.events_of(events, "explosion")[0]["side"], O)
	assert_null(game.piece_at(Vector2i(3, 5)), "knight exploded")
	assert_eq(game.score(O), 8, "rook 5 + knight 3")


func test_clone_keeps_the_pending_escape() -> void:
	var game := _game([H.piece("rook", Vector2i(1, 0))])
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	var copy := game.clone()
	assert_eq(copy.pending_escape_side(), O)
	assert_eq(copy.escape_squares(), game.escape_squares())
	copy.escape(Vector2i(5, 4))
	assert_eq(copy.escape_penalty(O), _cost())
	assert_eq(game.pending_escape_side(), O, "original untouched")
	assert_eq(game.escape_penalty(O), 0)
	assert_eq(game.piece_at(ENEMY_KING).type, "king")


func test_no_check_is_looked_for_after_an_escape() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(5, 4)), H.piece("rook", Vector2i(5, 5))])
	game.play(0, Vector2i(0, 0), Vector2i(0, 4))
	assert_true(game.escape_squares().has(Vector2i(4, 3)))
	var events := game.escape(Vector2i(4, 3))
	assert_true(game.in_check(P), "the escape uncovered the opponent's rook")
	assert_eq(H.events_of(events, "check").size(), 0, "D56: checks only follow card plays")
	assert_eq(game.pending_escape_side(), -1)


func test_a_shielded_enemy_piece_square_is_never_an_escape_square() -> void:
	var plain := _game([H.piece("rook", Vector2i(1, 0)), H.piece("knight", Vector2i(5, 4))])
	plain.play(0, Vector2i(1, 0), Vector2i(1, 5))
	assert_true(plain.escape_squares().has(Vector2i(5, 4)), "unshielded checker-free capture is safe")
	var shielded := _game([H.piece("rook", Vector2i(1, 0)), H.piece("knight", Vector2i(5, 4), "standard", "shield")])
	shielded.play(0, Vector2i(1, 0), Vector2i(1, 5))
	assert_eq(shielded.escape_squares(), [Vector2i(4, 4)] as Array[Vector2i], "D61")
	assert_eq(shielded.escape(Vector2i(5, 4))[0]["reason"], "illegal_move")


func test_holes_are_never_escape_squares() -> void:
	var holes: Array[Vector2i] = [Vector2i(4, 4)]
	var game := _game([H.piece("rook", Vector2i(1, 0))], [], {"holes": holes})
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	assert_eq(game.escape_squares(), [Vector2i(5, 4)] as Array[Vector2i])
	assert_eq(game.escape(Vector2i(4, 4))[0]["reason"], "illegal_move")


func _assert_finished_by_escape(game: ChessMatch, reason: String) -> void:
	assert_true(game.is_over())
	assert_eq(game.result()["winner"], O, "the escaping side wins")
	assert_eq(game.result()["reason"], reason)
	assert_eq(game.pending_escape_side(), -1)
	assert_eq(game.escape_squares(), [] as Array[Vector2i])
	var before := H.snapshot(game)
	assert_eq(game.escape(Vector2i(4, 4))[0]["type"], "error")
	assert_eq(game.decline_escape()[0]["type"], "error")
	assert_eq(game.play(0, Vector2i(1, 5), Vector2i(1, 4))[0]["reason"], "match_over")
	assert_eq(game.end_turn()[0]["reason"], "match_over")
	assert_eq(game.redraw()[0]["type"], "error")
	assert_eq(game.legal_plays(P), [] as Array[Dictionary])
	assert_eq(H.snapshot(game), before)


func test_escape_that_captures_the_enemy_king_wins() -> void:
	var game := H.make([H.piece("king", Vector2i(4, 4)), H.piece("rook", Vector2i(1, 0))], [H.piece("king", ENEMY_KING)])
	game.play(0, Vector2i(1, 0), Vector2i(1, 5))
	assert_eq(game.escape_squares(), [Vector2i(4, 4)] as Array[Vector2i])
	var events := game.escape(Vector2i(4, 4))
	assert_eq(H.events_of(events, "match_over").size(), 1)
	_assert_finished_by_escape(game, "king")


func test_escape_capture_reaching_the_target_score_wins() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("queen", Vector2i(0, 1)), H.piece("rook", Vector2i(4, 0))],
		[H.piece("king", ENEMY_KING), H.piece("rook", Vector2i(0, 5))])
	game.end_turn()
	game.play(0, Vector2i(0, 5), Vector2i(0, 1))
	assert_eq(game.pending_escape_side(), -1)
	assert_eq(game.score(O), 8)
	game.end_turn()
	game.play(0, Vector2i(4, 0), Vector2i(4, 5))
	assert_true(game.escape_squares().has(Vector2i(4, 5)))
	game.escape(Vector2i(4, 5))
	assert_eq(game.score(O), 13)
	_assert_finished_by_escape(game, "score")
