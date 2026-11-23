extends GutTest
## EventText: square names, match-end reasons and one log line per event type.

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
