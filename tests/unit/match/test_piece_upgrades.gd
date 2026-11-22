extends GutTest
## Piece upgrades inside a match: Deploy -1 and Shield (D20). Range +1 is in test_movement.gd.

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT


func test_deploy_upgrade_keeps_full_capture_value() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(2, 0))],
		[H.piece("king", Vector2i(0, 5)), H.piece("knight", Vector2i(2, 4), "standard", "deploy")])
	game.play(0, Vector2i(2, 0), Vector2i(2, 4))
	assert_eq(game.score(P), 3)


func test_shield_blocks_first_capture_and_attacker_stays() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(2, 0))],
		[H.piece("king", Vector2i(0, 5)), H.piece("pawn", Vector2i(2, 4), "standard", "shield")])
	assert_true(game.piece_at(Vector2i(2, 4)).shield_active)
	var events := game.play(0, Vector2i(2, 0), Vector2i(2, 4))
	var block := H.events_of(events, "shield_block")
	assert_eq(block.size(), 1)
	assert_eq(block[0]["square"], Vector2i(2, 4))
	assert_eq(block[0]["attacker_square"], Vector2i(2, 0))
	assert_eq(block[0]["cause"], "capture")
	assert_eq(H.events_of(events, "move").size(), 0)
	assert_eq(game.piece_at(Vector2i(2, 0)).type, "rook", "attacker stays")
	assert_eq(game.piece_at(Vector2i(2, 4)).type, "pawn", "defender survives")
	assert_false(game.piece_at(Vector2i(2, 4)).shield_active)
	assert_eq(game.energy(P), 2, "card is spent")
	assert_eq(game.discard_size(P), 1)
	assert_eq(game.score(P), 0)
	game.play(0, Vector2i(2, 0), Vector2i(2, 4))
	assert_eq(game.piece_at(Vector2i(2, 4)).type, "rook", "second attempt captures")
	assert_eq(game.score(P), 1)


func test_shield_protects_the_king() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(0, 5), "standard", "shield")])
	game.play(0, Vector2i(0, 0), Vector2i(0, 5))
	game.decline_escape()
	assert_false(game.is_over())
	game.play(0, Vector2i(0, 0), Vector2i(0, 5))
	game.decline_escape()
	assert_eq(game.result()["reason"], "king")


func test_consumed_player_shield_is_reported_and_collection_untouched() -> void:
	var shielded := PieceData.new("knight", "standard", "shield")
	var game := H.make([H.piece("king", Vector2i(5, 0)), {"piece": shielded, "square": Vector2i(0, 1)}],
		[H.piece("king", Vector2i(4, 5)), H.piece("rook", Vector2i(0, 5)), H.piece("rook", Vector2i(5, 4))])
	game.end_turn()
	game.play(0, Vector2i(0, 5), Vector2i(0, 1))
	game.decline_escape()
	game.play(0, Vector2i(5, 4), Vector2i(5, 0))
	game.decline_escape()
	assert_true(game.is_over())
	assert_eq(game.result()["shields_consumed"], [shielded.uid])
	assert_eq(shielded.upgrade, "shield", "PieceData is never mutated")


func test_opponent_shield_is_not_reported() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(0, 5)), H.piece("pawn", Vector2i(0, 3), "standard", "shield")])
	game.play(0, Vector2i(0, 0), Vector2i(0, 3))
	game.decline_escape()
	game.play(0, Vector2i(0, 0), Vector2i(0, 3))
	game.decline_escape()
	game.play(0, Vector2i(0, 3), Vector2i(0, 5))
	game.decline_escape()
	assert_eq(game.result()["shields_consumed"], [])
