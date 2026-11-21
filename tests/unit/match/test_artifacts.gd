extends GutTest
## Artifacts: Espresso, Trophy Case (D27), Sinkholes (D28), Powder Keg (D29).

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT


func _artifact_config(artifact_id: String) -> Dictionary:
	return GameConfig.data("artifacts")["artifacts"][artifact_id]


func _standard_rosters() -> Array:
	var player := [H.piece("king", Vector2i(2, 0))]
	var opponent := [H.piece("king", Vector2i(2, 5))]
	for x in 6:
		player.append(H.piece("pawn", Vector2i(x, 1)))
		opponent.append(H.piece("pawn", Vector2i(x, 4)))
	return [player, opponent]


func test_extra_energy_gives_one_more_energy_every_turn() -> void:
	var game := H.make([H.piece("king", Vector2i(0, 0))], [H.piece("king", Vector2i(5, 5))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["extra_energy"]})
	var expected := int(GameConfig.value("match", "energy_per_turn")) + int(_artifact_config("extra_energy")["amount"])
	assert_eq(game.max_energy(P), expected)
	assert_eq(game.energy(P), expected)
	game.end_turn()
	assert_eq(game.energy(O), 3, "only the owner")
	game.end_turn()
	assert_eq(game.energy(P), expected)


func test_capture_bonus_only_for_the_owner() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("pawn", Vector2i(3, 1))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(0, 4)), H.piece("bishop", Vector2i(1, 3))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["capture_bonus"]})
	game.play(0, Vector2i(0, 0), Vector2i(0, 4))
	assert_eq(game.score(P), 2, "pawn 1 + trophy 1")
	game.end_turn()
	game.play(0, Vector2i(1, 3), Vector2i(3, 1))
	assert_eq(game.score(O), 1, "no bonus for the opponent")


func test_capture_bonus_applies_to_explosion_credits() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(0, 4)), H.piece("pawn", Vector2i(1, 4))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"player_artifacts": ["capture_bonus", "exploding"]})
	game.play(0, Vector2i(0, 0), Vector2i(0, 4))
	assert_eq(game.score(P), 4, "(1 + 1) + exploded (1 + 1)")


func test_no_holes_without_the_artifact() -> void:
	var rosters := _standard_rosters()
	var game := H.make(rosters[0], rosters[1])
	assert_eq(game.holes(), [] as Array[Vector2i])


func test_holes_are_placed_in_the_middle_rows_only() -> void:
	var hole_config := _artifact_config("holes")
	var deploy_rows := int(GameConfig.value("match", "deploy_rows"))
	var counts := {}
	for seed_value in range(1, 80):
		var rosters := _standard_rosters()
		var owner_key := "player_artifacts" if seed_value % 2 == 0 else "opponent_artifacts"
		var game := H.make(rosters[0], rosters[1], H.FIVE_MOVES, H.FIVE_MOVES, {"seed": seed_value, owner_key: ["holes"]})
		var holes := game.holes()
		counts[holes.size()] = true
		assert_between(holes.size(), int(hole_config["min"]), int(hole_config["max"]))
		for hole in holes:
			assert_between(hole.y, deploy_rows, game.board_size() - deploy_rows - 1, "seed %d" % seed_value)
			assert_null(game.piece_at(hole))
			assert_true(game.is_hole(hole))
	assert_eq(counts.size(), int(hole_config["max"]) - int(hole_config["min"]) + 1, "every count happens")


func test_holes_are_deterministic_by_seed() -> void:
	var rosters := _standard_rosters()
	var first := H.make(rosters[0], rosters[1], H.FIVE_MOVES, H.FIVE_MOVES, {"seed": 42, "player_artifacts": ["holes"]})
	rosters = _standard_rosters()
	var second := H.make(rosters[0], rosters[1], H.FIVE_MOVES, H.FIVE_MOVES, {"seed": 42, "player_artifacts": ["holes"]})
	assert_eq(H.sorted(first.holes()), H.sorted(second.holes()))


func test_no_legal_play_lands_on_a_hole() -> void:
	var holes: Array[Vector2i] = [Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 3)]
	var rosters := _standard_rosters()
	rosters[0].append(H.piece("knight", Vector2i(1, 0)))
	var game := H.make(rosters[0], rosters[1], H.FIVE_MOVES, H.FIVE_MOVES, {"holes": holes})
	for play in game.legal_plays(P):
		assert_false(holes.has(play["to"]))


func _exploding_game(player_extra: Array, opponent_extra: Array, player_king := Vector2i(5, 0), opponent_king := Vector2i(5, 5)) -> ChessMatch:
	return H.make([H.piece("king", player_king), H.piece("rook", Vector2i(2, 0))] + player_extra,
		[H.piece("king", opponent_king)] + opponent_extra, H.FIVE_MOVES, H.FIVE_MOVES, {"player_artifacts": ["exploding"]})


func test_explosion_captures_adjacent_pieces_of_both_sides() -> void:
	var game := _exploding_game([H.piece("knight", Vector2i(1, 3))],
		[H.piece("pawn", Vector2i(2, 3)), H.piece("bishop", Vector2i(3, 4)), H.piece("pawn", Vector2i(1, 2))])
	var events := game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	var explosion := H.events_of(events, "explosion")
	assert_eq(explosion.size(), 1)
	assert_eq(explosion[0]["square"], Vector2i(2, 3))
	assert_eq(explosion[0]["squares"].size(), 8)
	assert_eq(game.piece_at(Vector2i(2, 3)).type, "rook", "attacker survives on the centre")
	for square in [Vector2i(1, 3), Vector2i(3, 4), Vector2i(1, 2)]:
		assert_null(game.piece_at(square), str(square))
	assert_eq(game.score(P), 1 + 3 + 1)
	assert_eq(game.score(O), 3, "own exploded knight scores for the opponent")
	var causes := H.events_of(events, "capture").map(func(event: Dictionary) -> String: return event["cause"])
	assert_eq(causes, ["capture", "explosion", "explosion", "explosion"])


func test_explosion_at_the_edge_uses_only_board_squares() -> void:
	var game := _exploding_game([], [H.piece("pawn", Vector2i(2, 5)), H.piece("pawn", Vector2i(1, 5))], Vector2i(5, 0), Vector2i(5, 3))
	var events := game.play(0, Vector2i(2, 0), Vector2i(2, 5))
	assert_eq(H.events_of(events, "explosion")[0]["squares"].size(), 5)
	assert_null(game.piece_at(Vector2i(1, 5)))


func test_no_chain_reactions() -> void:
	var game := _exploding_game([], [H.piece("pawn", Vector2i(2, 3)), H.piece("pawn", Vector2i(3, 4)), H.piece("pawn", Vector2i(4, 5))])
	game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	assert_null(game.piece_at(Vector2i(3, 4)))
	assert_not_null(game.piece_at(Vector2i(4, 5)), "two squares away survives")


func test_explosion_eats_shields_instead_of_pieces() -> void:
	var shielded := PieceData.new("bishop", "standard", "shield")
	var game := _exploding_game([{"piece": shielded, "square": Vector2i(1, 3)}],
		[H.piece("pawn", Vector2i(2, 3)), H.piece("knight", Vector2i(3, 3), "standard", "shield")])
	var events := game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	var blocks := H.events_of(events, "shield_block")
	assert_eq(blocks.size(), 2)
	assert_eq(blocks[0]["cause"], "explosion")
	assert_false(game.piece_at(Vector2i(1, 3)).shield_active)
	assert_false(game.piece_at(Vector2i(3, 3)).shield_active)
	assert_eq(game.score(P), 1)
	game.play(0, Vector2i(2, 3), Vector2i(2, 4))
	game.end_turn()
	game.end_turn()
	game.play(0, Vector2i(2, 4), Vector2i(5, 4))
	assert_false(game.is_over())
	game.play(0, Vector2i(5, 4), Vector2i(5, 5))
	assert_eq(game.result()["shields_consumed"], [shielded.uid])


func test_opponent_king_in_blast_wins() -> void:
	var game := _exploding_game([], [H.piece("pawn", Vector2i(2, 3))], Vector2i(5, 0), Vector2i(3, 4))
	game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	assert_eq(game.result()["winner"], P)
	assert_eq(game.result()["reason"], "king")


func test_own_king_in_blast_loses() -> void:
	var game := _exploding_game([], [H.piece("pawn", Vector2i(2, 3))], Vector2i(1, 2), Vector2i(5, 5))
	game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	assert_eq(game.result()["winner"], O)
	assert_eq(game.result()["reason"], "king")


func test_explosion_only_for_the_artifact_owner() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(2, 0))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(2, 3)), H.piece("pawn", Vector2i(3, 4))], H.FIVE_MOVES, H.FIVE_MOVES,
		{"opponent_artifacts": ["exploding"]})
	var events := game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	assert_eq(H.events_of(events, "explosion").size(), 0)
	assert_not_null(game.piece_at(Vector2i(3, 4)))


func test_no_explosion_without_a_capture() -> void:
	var game := _exploding_game([], [H.piece("pawn", Vector2i(3, 4))])
	var events := game.play(0, Vector2i(2, 0), Vector2i(2, 3))
	assert_eq(H.events_of(events, "explosion").size(), 0)
	assert_not_null(game.piece_at(Vector2i(3, 4)))
