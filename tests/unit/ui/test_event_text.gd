extends GutTest
## EventText: square names, match-end reasons and one log line per event type.

const H := preload("res://tests/unit/match/match_helper.gd")
const NAMES := ["You", "Rex"]


func test_square_names_cover_the_board_corners() -> void:
	assert_eq(EventText.square_name(Vector2i(0, 0)), "a1")
	assert_eq(EventText.square_name(Vector2i(5, 5)), "f6")
	assert_eq(EventText.square_name(Vector2i(2, 3)), "c4")


func test_reason_text_for_both_sides() -> void:
	for reason in ["king", "score", "no_moves", "turn_limit"]:
		var won := EventText.reason_text(reason, true)
		var lost := EventText.reason_text(reason, false)
		assert_ne(won, reason, "%s has a sentence" % reason)
		assert_ne(won, lost, "%s reads differently for a win and a loss" % reason)
	assert_eq(EventText.reason_text("mystery", true), "mystery", "unknown reasons pass through")


func test_turn_start_and_card_played() -> void:
	assert_eq(EventText.describe({"type": "turn_start", "side": 0, "round": 3}, NAMES), "— Round 3 · Your turn —")
	assert_eq(EventText.describe({"type": "turn_start", "side": 1, "round": 3}, NAMES), "— Round 3 · Rex's turn —")
	assert_eq(EventText.describe({"type": "card_played", "side": 1, "card_type": "rook", "cost": 2}, NAMES), "Rex played Rook (2)")


func test_capture_explosion_and_shield() -> void:
	var capture := {"type": "capture", "side": 0, "piece_type": "bishop", "square": Vector2i(2, 4), "points": 3, "cause": "move"}
	assert_eq(EventText.describe(capture, NAMES), "Bishop captured on c5 (+3)")
	capture["cause"] = "explosion"
	assert_eq(EventText.describe(capture, NAMES), "Bishop exploded on c5 (+3)")
	var king := {"type": "capture", "side": 1, "piece_type": "king", "square": Vector2i(2, 5), "points": 0, "cause": "move"}
	assert_eq(EventText.describe(king, NAMES), "King captured on c6", "no \"(+0)\" on a king capture")
	assert_eq(EventText.describe({"type": "shield_block", "square": Vector2i(1, 1), "cause": "move"}, NAMES), "Shield on b2 blocked the capture")
	assert_eq(EventText.describe({"type": "shield_block", "square": Vector2i(1, 1), "cause": "explosion"}, NAMES), "Shield on b2 blocked the blast")
	assert_eq(EventText.describe({"type": "explosion", "square": Vector2i(5, 4)}, NAMES), "Powder Keg explodes at f5")


func test_fire_promotion_redraw_and_shuffle() -> void:
	assert_eq(EventText.describe({"type": "ignite", "square": Vector2i(0, 2), "turns_left": 2}, NAMES), "Piece on a3 ignites (2 turns)")
	var burn := {"type": "burn_out", "piece_type": "pawn", "square": Vector2i(3, 3), "points": 1, "by_side": 0}
	assert_eq(EventText.describe(burn, NAMES), "Pawn on d4 burned out (+1 to You)")
	assert_eq(EventText.describe({"type": "promotion", "square": Vector2i(4, 5)}, NAMES), "Pawn promoted to Queen on e6")
	assert_eq(EventText.describe({"type": "redraw", "side": 0}, NAMES), "You redrew the hand")
	assert_eq(EventText.describe({"type": "shuffle", "side": 1, "count": 7}, NAMES), "Rex shuffled 7 cards into the draw pile")


func test_check_without_escape_and_own_king() -> void:
	var check := {"type": "check", "side": 0, "king_square": Vector2i(2, 0), "can_escape": false}
	assert_eq(EventText.describe(check, NAMES), "Check! Your king on c1 is attacked (no escape)")


func test_energy_lines_only_with_an_escape_penalty() -> void:
	assert_eq(EventText.describe({"type": "energy", "side": 1, "energy": 3}, NAMES), "")
	var penalised := {"type": "energy", "side": 1, "energy": 2, "escape_penalty": 1}
	assert_eq(EventText.describe(penalised, NAMES), "Rex starts with 2 energy (−1 from escapes)")


func test_match_over_and_unknown_events() -> void:
	assert_eq(EventText.describe({"type": "match_over", "winner": 0}, NAMES), "Match over — you win")
	assert_eq(EventText.describe({"type": "match_over", "winner": 1}, NAMES), "Match over — Rex wins")
	assert_eq(EventText.describe({"type": "something_new"}, NAMES), "", "unknown events are not logged")


func test_artifact_points_in_a_capture_are_named() -> void:
	# The player's Trophy Case on its capture; Deep Vision's penalty when the
	# opponent takes a player piece (and the opponent's own Trophy Case with it).
	var mine := {"type": "capture", "side": 1, "piece_type": "pawn", "square": Vector2i(2, 4), "by_side": 0, "points": 2, "cause": "capture"}
	var artifacts := [["capture_bonus", "foresight"], ["capture_bonus"]]
	assert_eq(EventText.bonuses(mine, artifacts), [{"id": "capture_bonus", "points": 1}] as Array[Dictionary])
	assert_eq(EventText.describe(mine, NAMES, artifacts), "Pawn captured on c5 (+2, incl. +1 Trophy Case)")
	var theirs := {"type": "capture", "side": 0, "piece_type": "pawn", "square": Vector2i(2, 1), "by_side": 1, "points": 3, "cause": "capture"}
	assert_eq(EventText.describe(theirs, NAMES, artifacts), "Pawn captured on c2 (+3, incl. +1 Trophy Case, +1 Deep Vision)")
	var burn := {"type": "burn_out", "side": 0, "piece_type": "pawn", "square": Vector2i(3, 3), "points": 2, "by_side": 1}
	assert_eq(EventText.describe(burn, NAMES, [["foresight"], []]), "Pawn on d4 burned out (+2 to Rex, incl. +1 Deep Vision)")
	assert_eq(EventText.describe(mine, NAMES, [["foresight"], []]), "Pawn captured on c5 (+2)", "Deep Vision costs only on the player's pieces")
	assert_eq(EventText.bonuses({"type": "move"}, artifacts), [] as Array[Dictionary])


# --- EventText.bonuses against the engine's scoring (ChessMatch._credit_capture) ---
# The float and log split a capture's points into the piece's value and its
# artifact points. If the engine's rule changes, these fail instead of the UI
# silently showing a wrong split.

func test_bonuses_match_the_engine_for_captures() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("pawn", Vector2i(3, 1))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(0, 4)), H.piece("bishop", Vector2i(1, 3))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["capture_bonus", "foresight"], "opponent_artifacts": ["capture_bonus"]})
	assert_eq(_check_credits(game, func() -> Array[Dictionary]: return game.play(0, Vector2i(0, 0), Vector2i(0, 4))), 1, "the player's rook takes a pawn")
	game.end_turn()
	assert_eq(_check_credits(game, func() -> Array[Dictionary]: return game.play(0, Vector2i(1, 3), Vector2i(3, 1))), 1, "the opponent's bishop takes a player pawn")


func test_bonuses_match_the_engine_for_explosions() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(2, 0)), H.piece("knight", Vector2i(1, 3))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(2, 3)), H.piece("bishop", Vector2i(3, 4)), H.piece("pawn", Vector2i(1, 2))],
		H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["capture_bonus", "exploding", "foresight"], "opponent_artifacts": ["capture_bonus"]})
	assert_eq(_check_credits(game, func() -> Array[Dictionary]: return game.play(0, Vector2i(2, 0), Vector2i(2, 3))), 4,
		"the capture and three blast victims, one of them the player's own knight")


func test_bonuses_match_the_engine_for_a_burn_out() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0), "fire"), H.piece("rook", Vector2i(0, 0), "fire")],
		[H.piece("king", Vector2i(5, 5))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["foresight"], "opponent_artifacts": ["capture_bonus"]})
	game.play(0, Vector2i(0, 0), Vector2i(0, 2))
	var checked := 0
	for _i in 10:
		checked += _check_credits(game, func() -> Array[Dictionary]: return game.end_turn())
	assert_eq(checked, 1, "the fire rook burns out")


## Runs `action` and checks each credited capture in its events: the victim's
## value + EventText.bonuses equals the event's points, and the points add up to
## each side's score change. Returns how many captures it checked.
func _check_credits(game: ChessMatch, action: Callable) -> int:
	var values := {}
	for side in [ChessMatch.PLAYER, ChessMatch.OPPONENT]:
		for piece: MatchPiece in game.pieces(side):
			values[piece.uid] = piece.value()
	var before := [game.score(ChessMatch.PLAYER), game.score(ChessMatch.OPPONENT)]
	var artifacts := [game.artifacts(ChessMatch.PLAYER), game.artifacts(ChessMatch.OPPONENT)]
	var events: Array[Dictionary] = action.call()
	var credited := [0, 0]
	var checked := 0
	for event in events:
		if not event["type"] in ["capture", "burn_out"]:
			continue
		var bonus := 0
		for part in EventText.bonuses(event, artifacts):
			bonus += int(part["points"])
		assert_eq(int(values[event["uid"]]) + bonus, int(event["points"]), "value + bonuses for %s (%s)" % [event["piece_type"], event["cause"]])
		credited[int(event["by_side"])] += int(event["points"])
		checked += 1
	assert_eq([game.score(ChessMatch.PLAYER) - before[0], game.score(ChessMatch.OPPONENT) - before[1]], credited, "points add up to the score change")
	return checked
