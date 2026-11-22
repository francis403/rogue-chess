extends GutTest
## Illegal-action rejection, clone, determinism, setup copying and a random-play fuzz.

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const FUZZ_SEEDS := 200
const MAX_ACTIONS_PER_MATCH := 20000
const ARTIFACT_COMBOS: Array = [[], ["extra_energy"], ["capture_bonus"], ["holes"], ["exploding"], ["exploding", "capture_bonus"]]
const UPGRADES: Array = ["", "range", "deploy", "shield"]
const CARD_TYPES: Array = ["pawn", "knight", "bishop", "rook", "queen", "move"]
const CARD_UPGRADES: Array = ["", "cheaper", "hold", "book"]


func _full_setup(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var piece_set := "fire" if rng.randf() < 0.4 else "standard"
	var back_rank := ["rook", "knight", "bishop", "king", "queen", "bishop"]
	var player_roster := []
	var opponent_roster := []
	for x in 6:
		player_roster.append(H.piece(back_rank[x], Vector2i(x, 0), piece_set, UPGRADES[rng.randi_range(0, UPGRADES.size() - 1)]))
		if rng.randf() < 0.7:
			player_roster.append(H.piece("pawn", Vector2i(x, 1), piece_set, UPGRADES[rng.randi_range(0, UPGRADES.size() - 1)]))
		opponent_roster.append(H.piece("pawn", Vector2i(x, 4)))
	opponent_roster.append(H.piece("king", Vector2i(2, 5)))
	opponent_roster.append(H.piece("queen", Vector2i(3, 5)))
	opponent_roster.append(H.piece("knight", Vector2i(1, 5)))
	var player_deck := []
	for _i in rng.randi_range(4, 12):
		player_deck.append(CARD_TYPES[rng.randi_range(0, CARD_TYPES.size() - 1)] + ":" + CARD_UPGRADES[rng.randi_range(0, CARD_UPGRADES.size() - 1)])
	return H.setup(player_roster, opponent_roster, player_deck, ["pawn", "knight", "queen", "move", "move"], {
		"seed": seed_value,
		"player_artifacts": ARTIFACT_COMBOS[rng.randi_range(0, ARTIFACT_COMBOS.size() - 1)],
		"opponent_artifacts": ARTIFACT_COMBOS[rng.randi_range(0, ARTIFACT_COMBOS.size() - 1)],
	})


func _default_game(seed_value: int = 7) -> ChessMatch:
	return ChessMatch.new(_full_setup(seed_value))


func _random_action(game: ChessMatch, rng: RandomNumberGenerator, play_chance: float = 0.85) -> Array[Dictionary]:
	if game.pending_escape_side() != -1:
		var squares := game.escape_squares()
		if rng.randf() < 0.7:
			return game.escape(squares[rng.randi_range(0, squares.size() - 1)])
		return game.decline_escape()
	var plays := game.legal_plays(game.current_side())
	if not plays.is_empty() and rng.randf() < play_chance:
		var choice: Dictionary = plays[rng.randi_range(0, plays.size() - 1)]
		return game.play(choice["card_index"], choice["from"], choice["to"])
	if game.can_redraw() and rng.randf() < 0.5:
		return game.redraw()
	return game.end_turn()


func test_illegal_actions_are_rejected_without_changes() -> void:
	var game := H.make([H.piece("king", Vector2i(0, 0)), H.piece("rook", Vector2i(3, 0))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(3, 4))], ["rook", "knight", "queen", "move", "move"])
	var before := H.snapshot(game)
	var rook_card := H.card_index(game, "rook")
	var attempts := [
		[-1, Vector2i(3, 0), Vector2i(3, 1), "bad_card_index"],
		[5, Vector2i(3, 0), Vector2i(3, 1), "bad_card_index"],
		[rook_card, Vector2i(2, 2), Vector2i(2, 3), "no_own_piece"],
		[rook_card, Vector2i(3, 4), Vector2i(3, 3), "no_own_piece"],
		[H.card_index(game, "knight"), Vector2i(3, 0), Vector2i(3, 1), "wrong_card"],
		[rook_card, Vector2i(3, 0), Vector2i(4, 1), "illegal_move"],
		[rook_card, Vector2i(3, 0), Vector2i(3, 5), "illegal_move"],
		[rook_card, Vector2i(3, 0), Vector2i(-1, 0), "illegal_move"],
		[H.card_index(game, "move"), Vector2i(0, 0), Vector2i(0, 2), "illegal_move"],
	]
	for attempt in attempts:
		var events := game.play(attempt[0], attempt[1], attempt[2])
		assert_eq(events.size(), 1)
		assert_eq(events[0]["type"], "error")
		assert_eq(events[0]["reason"], attempt[3], str(attempt))
		assert_eq(H.snapshot(game), before, str(attempt))
	assert_eq(game.redraw()[0]["type"], "error")
	assert_eq(H.snapshot(game), before)


func test_targets_and_pieces_for_card_reject_bad_input() -> void:
	var game := _default_game()
	assert_eq(game.targets(99, Vector2i(0, 0)), [] as Array[Vector2i])
	assert_eq(game.targets(0, Vector2i(3, 4)), [] as Array[Vector2i], "enemy piece")
	assert_eq(game.pieces_for_card(-1), [] as Array[Vector2i])
	assert_false(game.is_card_playable(42))


func test_setup_data_is_copied_not_mutated() -> void:
	var setup := _full_setup(3)
	var piece_data: Array = []
	for entry in setup["player"]["roster"]:
		piece_data.append([entry["piece"], entry["piece"].to_dict()])
	var card_data: Array = []
	for card in setup["player"]["deck"]:
		card_data.append([card, card.to_dict()])
	var game := ChessMatch.new(setup)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	while not game.is_over():
		_random_action(game, rng)
	for pair in piece_data:
		assert_eq(pair[0].to_dict(), pair[1])
	for pair in card_data:
		assert_eq(pair[0].to_dict(), pair[1])
	for card in game.hand(P):
		assert_false(setup["player"]["deck"].has(card), "hand holds copies")


func test_clone_is_independent() -> void:
	var game := _default_game()
	var copy := game.clone()
	var before := H.snapshot(game)
	var plays := copy.legal_plays(P)
	copy.play(plays[0]["card_index"], plays[0]["from"], plays[0]["to"])
	copy.end_turn()
	assert_eq(H.snapshot(game), before)
	assert_ne(H.snapshot(copy), before)


func test_clone_continues_identically() -> void:
	var game := _default_game(11)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _i in 30:
		if not game.is_over():
			_random_action(game, rng)
	var copy := game.clone()
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 9
	rng_b.seed = 9
	while not game.is_over():
		assert_eq(_random_action(copy, rng_b), _random_action(game, rng_a))
	assert_eq(copy.result(), game.result())


func test_same_seed_gives_same_match() -> void:
	var setup := _full_setup(21)
	var first := ChessMatch.new(setup)
	var second := ChessMatch.new(setup)
	assert_eq(first.initial_events(), second.initial_events())
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 1
	rng_b.seed = 1
	while not first.is_over():
		assert_eq(_random_action(second, rng_b), _random_action(first, rng_a))
	assert_eq(first.result(), second.result())


func test_different_seeds_shuffle_differently() -> void:
	var hands := {}
	for seed_value in range(1, 10):
		var setup := H.setup([H.piece("king", Vector2i(0, 0))], [H.piece("king", Vector2i(5, 5))],
			["pawn", "knight", "bishop", "rook", "queen", "move", "move", "pawn"], H.FIVE_MOVES, {"seed": seed_value})
		hands[str(H.hand_types(ChessMatch.new(setup), P))] = true
	assert_gt(hands.size(), 1)


func test_result_reports_used_and_moved_pieces() -> void:
	var king := PieceData.new("king")
	var rook := PieceData.new("rook")
	var idle := PieceData.new("knight")
	var game := H.make([{"piece": king, "square": Vector2i(5, 0)}, {"piece": rook, "square": Vector2i(0, 0)}, {"piece": idle, "square": Vector2i(1, 0)}],
		[H.piece("king", Vector2i(0, 5)), H.piece("pawn", Vector2i(3, 4))])
	game.play(0, Vector2i(0, 0), Vector2i(0, 4))
	game.decline_escape()
	game.play(0, Vector2i(0, 4), Vector2i(3, 4))
	game.decline_escape()
	game.play(0, Vector2i(3, 4), Vector2i(3, 5))
	game.decline_escape()
	game.end_turn()
	game.end_turn()
	game.play(0, Vector2i(3, 5), Vector2i(0, 5))
	game.decline_escape()
	var result := game.result()
	assert_eq(H.sorted(result["player_pieces_used"]), H.sorted([king.uid, rook.uid, idle.uid]))
	assert_eq(result["player_pieces_moved"], [rook.uid])
	assert_eq(result["captured"].size(), 2)
	assert_eq(result["captured"][0]["type"], "pawn")
	assert_eq(result["captured"][0]["by_side"], P)
	assert_eq(result["opponent_id"], "test")


func test_random_play_keeps_invariants_and_always_terminates() -> void:
	var total_plays := 0
	var escape_actions := {"escape": 0, "escape_declined": 0}
	var reasons := {}
	for seed_value in range(1, FUZZ_SEEDS + 1):
		var setup := _full_setup(seed_value)
		var game := ChessMatch.new(setup)
		var deck_sizes := [setup["player"]["deck"].size(), setup["opponent"]["deck"].size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 7919
		var play_chance := 0.85 if seed_value % 3 != 0 else 0.15
		var actions := 0
		_assert_invariants(game, deck_sizes, seed_value)
		while not game.is_over() and actions < MAX_ACTIONS_PER_MATCH:
			var events := _random_action(game, rng, play_chance)
			assert_ne(events[0]["type"], "error", "random legal action rejected, seed %d" % seed_value)
			if events[0]["type"] == "card_played":
				total_plays += 1
			if escape_actions.has(events[0]["type"]):
				escape_actions[events[0]["type"]] += 1
			actions += 1
			_assert_invariants(game, deck_sizes, seed_value)
		assert_true(game.is_over(), "seed %d terminates" % seed_value)
		assert_lte(game.current_round(), game.max_rounds())
		var result := game.result()
		reasons[result["reason"]] = true
		assert_true(result["winner"] == P or result["winner"] == O)
	assert_gt(total_plays, 2000, "thousands of random plays")
	assert_gt(escape_actions["escape"], 0, "escapes exercised")
	assert_gt(escape_actions["escape_declined"], 0, "declines exercised")
	gut.p("fuzz: %d plays, reasons %s, %s" % [total_plays, reasons.keys(), escape_actions])


func _assert_invariants(game: ChessMatch, deck_sizes: Array, seed_value: int) -> void:
	var occupied := {}
	var context := "seed %d round %d" % [seed_value, game.current_round()]
	for side in [P, O]:
		for match_piece in game.pieces(side):
			if occupied.has(match_piece.square):
				fail_test("two pieces on %s, %s" % [match_piece.square, context])
			occupied[match_piece.square] = true
			if game.is_hole(match_piece.square):
				fail_test("piece on a hole, %s" % context)
			if game.piece_at(match_piece.square) != match_piece:
				fail_test("piece square out of sync, %s" % context)
		if game.score(side) < 0 or game.energy(side) < 0 or game.escape_penalty(side) < 0:
			fail_test("negative score/energy, %s" % context)
		var cards := game.hand(side).size() + game.draw_pile_size(side) + game.discard_size(side)
		if cards != deck_sizes[side]:
			fail_test("card count %d != %d, %s" % [cards, deck_sizes[side], context])
		if game.hand(side).size() > int(GameConfig.value("match", "hand_size")):
			fail_test("hand too big, %s" % context)
	if game.current_round() > game.max_rounds():
		fail_test("past the turn limit, %s" % context)
