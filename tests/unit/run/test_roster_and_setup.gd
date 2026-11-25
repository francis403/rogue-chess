extends GutTest

const Helper := preload("res://tests/unit/run/run_test_helper.gd")

var dir: String
var session: RunSession
var _saved_easy: Dictionary


func before_each() -> void:
	dir = Helper.temp_dir("roster")
	session = Helper.started_session(dir)
	_saved_easy = GameConfig.data("opponents")["easy"].duplicate()


func after_each() -> void:
	GameConfig.data("opponents")["easy"] = _saved_easy
	Helper.remove_dir(dir)


func _pieces_of(piece_type: String) -> Array[PieceData]:
	var found: Array[PieceData] = []
	for piece in session.collection:
		if piece.type == piece_type:
			found.append(piece)
	return found


func _roster(pieces: Array[PieceData]) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for i in pieces.size():
		roster.append({"piece": pieces[i], "square": Vector2i(i % 6, i / 6)})
	return roster


func _king() -> PieceData:
	return _pieces_of("king")[0]


func test_default_roster_is_valid_and_includes_the_king() -> void:
	var roster := session.default_roster()
	var check := session.validate_roster(roster)
	assert_true(check["ok"], check["error"])
	assert_lte(check["cost"], 12)
	assert_true(roster.any(func(e: Dictionary) -> bool: return e["piece"].type == "king"))
	var pawn_files := roster.filter(func(e: Dictionary) -> bool: return e["piece"].type == "pawn").map(func(e: Dictionary) -> int: return e["square"].x)
	pawn_files.sort()
	assert_eq(pawn_files, [0, 1, 2, 3, 4, 5], "a full pawn wall closes every file (no open-file king snipe)")


func test_default_roster_puts_pawns_in_front() -> void:
	for entry in session.default_roster():
		var expected_row := 1 if entry["piece"].type == "pawn" else 0
		assert_eq(entry["square"].y, expected_row, entry["piece"].type)


func test_default_roster_valid_for_fire_with_free_pawns() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	meta.unlock_piece_set("fire")
	var fire := RunSession.new(5, meta, RunLogger.new(dir + "logs/"))
	fire.choose_piece_set("fire")
	var roster := fire.default_roster()
	var check := fire.validate_roster(roster)
	assert_true(check["ok"], check["error"])
	assert_lte(roster.size(), 12, "fits on the two back ranks")


func test_default_roster_prefers_upgraded_pieces_at_equal_cost() -> void:
	var rooks := _pieces_of("rook")
	rooks[1].upgrade = "shield"
	session.collection.erase(_pieces_of("queen")[0])
	var picked := session.default_roster().map(func(e: Dictionary) -> PieceData: return e["piece"])
	assert_true(picked.has(rooks[1]))


func test_budget_exactly_twelve_is_valid() -> void:
	var pieces: Array[PieceData] = [_king(), _pieces_of("rook")[0], _pieces_of("knight")[0], _pieces_of("bishop")[0], _pieces_of("pawn")[0]]
	assert_true(session.validate_roster(_roster(pieces))["ok"])


func test_over_budget_is_refused() -> void:
	var pieces: Array[PieceData] = [_king(), _pieces_of("queen")[0], _pieces_of("rook")[0]]
	var check := session.validate_roster(_roster(pieces))
	assert_false(check["ok"])
	assert_string_contains(check["error"], "budget")


func test_deploy_upgrade_lowers_the_cost_by_one() -> void:
	var queen := _pieces_of("queen")[0]
	var pieces: Array[PieceData] = [_king(), queen, _pieces_of("bishop")[0], _pieces_of("pawn")[0], _pieces_of("pawn")[1]]
	assert_false(session.validate_roster(_roster(pieces))["ok"], "8 + 3 + 1 + 1 = 13")
	queen.upgrade = "deploy"
	assert_eq(session.validate_roster(_roster(pieces))["cost"], 12)


func test_fire_values_are_one_lower() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	meta.unlock_piece_set("fire")
	var fire := RunSession.new(5, meta, RunLogger.new(dir + "logs/"))
	fire.choose_piece_set("fire")
	var roster: Array[Dictionary] = []
	var types := ["king", "queen", "rook", "pawn", "pawn"]
	for piece in fire.collection:
		if types.has(piece.type):
			types.erase(piece.type)
			roster.append({"piece": piece, "square": Vector2i(roster.size(), 0)})
	assert_eq(fire.validate_roster(roster)["cost"], 7 + 4 + 0 + 0)


func test_king_is_required_and_free() -> void:
	var without_king: Array[PieceData] = [_pieces_of("pawn")[0]]
	assert_false(session.validate_roster(_roster(without_king))["ok"])
	var only_king: Array[PieceData] = [_king()]
	assert_eq(session.validate_roster(_roster(only_king))["cost"], 0)


func test_squares_must_be_unique_and_in_the_back_two_rows() -> void:
	var king := _king()
	var pawn := _pieces_of("pawn")[0]
	var bad_squares := [Vector2i(0, 2), Vector2i(6, 0), Vector2i(-1, 1), Vector2i(0, 5)]
	for square in bad_squares:
		var roster: Array[Dictionary] = [{"piece": king, "square": Vector2i(2, 0)}, {"piece": pawn, "square": square}]
		assert_false(session.validate_roster(roster)["ok"], str(square))
	var shared: Array[Dictionary] = [{"piece": king, "square": Vector2i(2, 0)}, {"piece": pawn, "square": Vector2i(2, 0)}]
	assert_false(session.validate_roster(shared)["ok"])
	var corner: Array[Dictionary] = [{"piece": king, "square": Vector2i(5, 1)}, {"piece": pawn, "square": Vector2i(0, 0)}]
	assert_true(session.validate_roster(corner)["ok"])


func test_pieces_must_come_from_the_collection_once() -> void:
	var king := _king()
	var stranger: Array[Dictionary] = [{"piece": king, "square": Vector2i(2, 0)}, {"piece": PieceData.new("pawn"), "square": Vector2i(1, 1)}]
	assert_false(session.validate_roster(stranger)["ok"])
	var twice: Array[Dictionary] = [{"piece": king, "square": Vector2i(2, 0)}, {"piece": king, "square": Vector2i(3, 0)}]
	assert_false(session.validate_roster(twice)["ok"])


func test_malformed_entries_are_refused() -> void:
	assert_false(session.validate_roster([])["ok"])
	assert_false(session.validate_roster([{"piece": _king()}])["ok"])
	assert_false(session.validate_roster([{"piece": "king", "square": Vector2i.ZERO}])["ok"])
	assert_false(session.validate_roster([{"piece": _king(), "square": [0, 0]}])["ok"])
	assert_false(session.validate_roster([42])["ok"])


func test_build_match_setup_shape() -> void:
	session.choose_node("L1")
	var roster := session.default_roster()
	var setup := session.build_match_setup(roster)
	assert_eq(session.phase, RunSession.Phase.MATCH)
	assert_true(setup["seed"] is int)
	var player: Dictionary = setup["player"]
	assert_eq(player["roster"].size(), roster.size())
	for i in roster.size():
		var entry: Dictionary = player["roster"][i]
		assert_true(entry["piece"] is PieceData)
		assert_eq(entry["piece"].uid, roster[i]["piece"].uid)
		assert_ne(entry["piece"], roster[i]["piece"], "a copy, the match can't change the collection")
		assert_eq(entry["square"], roster[i]["square"])
	assert_eq(player["deck"].size(), session.deck.size())
	assert_true(player["deck"][0] is CardData)
	assert_eq(player["artifacts"], [] as Array[String])


func test_build_match_setup_opponent() -> void:
	session.choose_node("L1")
	var opponent: Dictionary = session.build_match_setup(session.default_roster())["opponent"]
	var cfg: Dictionary = GameConfig.data("opponents")["easy"]
	assert_eq(opponent["id"], "easy")
	assert_eq(opponent["name"], cfg["name"])
	assert_eq(opponent["difficulty"], cfg["difficulty"])
	assert_eq(opponent["search_depth"], 1)
	assert_almost_eq(opponent["random_chance"], 0.30, 0.0001)
	assert_eq(opponent["roster"].size(), cfg["pieces"].size())
	for i in cfg["pieces"].size():
		var entry: Dictionary = opponent["roster"][i]
		assert_eq(entry["piece"].type, cfg["pieces"][i]["type"])
		assert_eq(entry["piece"].piece_set, "standard")
		assert_eq(entry["square"], Vector2i(int(cfg["pieces"][i]["square"][0]), int(cfg["pieces"][i]["square"][1])))
		assert_between(entry["square"].y, 4, 5)
	assert_eq(opponent["deck"].map(func(c: CardData) -> String: return c.type), cfg["deck"])
	assert_eq(opponent["artifacts"], [] as Array[String], "easy has no artifacts")


func test_build_match_setup_passes_the_run_artifacts() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	meta.unlock_random_artifact(RandomNumberGenerator.new())
	var with_artifact := RunSession.new(3, meta, RunLogger.new(dir + "logs/"))
	with_artifact.choose_piece_set("standard")
	with_artifact.choose_artifacts([meta.unlocked_artifacts[0]])
	with_artifact.choose_node("M1")
	var setup := with_artifact.build_match_setup(with_artifact.default_roster())
	assert_eq(setup["player"]["artifacts"], [meta.unlocked_artifacts[0]] as Array[String])


func test_invalid_roster_keeps_match_setup_phase() -> void:
	session.choose_node("L1")
	var setup := session.build_match_setup([])
	assert_false(setup["ok"])
	assert_eq(session.phase, RunSession.Phase.MATCH_SETUP)


func test_roster_can_change_between_matches_and_upgrades_stay() -> void:
	var knight := _pieces_of("knight")[0]
	knight.upgrade = "range"
	session.choose_node("L1")
	var first: Array[PieceData] = [_king(), knight]
	var setup := session.build_match_setup(_roster(first))
	assert_eq(setup["player"]["roster"][1]["piece"].upgrade, "range")
	session.finish_match(Helper.result(0))
	session.skip_reward()
	session.choose_node("M2")
	var second: Array[PieceData] = [_king(), _pieces_of("rook")[0]]
	assert_eq(session.build_match_setup(_roster(second))["player"]["roster"].size(), 2)
	assert_eq(knight.upgrade, "range")


func test_used_shield_is_removed_after_the_match() -> void:
	var rook := _pieces_of("rook")[0]
	var bishop := _pieces_of("bishop")[0]
	rook.upgrade = "shield"
	bishop.upgrade = "shield"
	session.choose_node("L1")
	session.build_match_setup(session.default_roster())
	session.finish_match(Helper.result(0, [rook.uid]))
	assert_eq(rook.upgrade, "", "used shield is gone for good")
	assert_eq(bishop.upgrade, "shield", "unused shield stays")


func test_shield_list_never_removes_other_upgrades() -> void:
	var knight := _pieces_of("knight")[0]
	knight.upgrade = "range"
	session.choose_node("L1")
	session.build_match_setup(session.default_roster())
	session.finish_match(Helper.result(0, [knight.uid, 999999]))
	assert_eq(knight.upgrade, "range")


func test_shield_removed_on_a_loss_too() -> void:
	var rook := _pieces_of("rook")[0]
	rook.upgrade = "shield"
	session.choose_node("L1")
	session.build_match_setup(session.default_roster())
	session.finish_match(Helper.result(1, [rook.uid]))
	assert_eq(rook.upgrade, "")
	assert_eq(session.summary()["upgraded_pieces"], [])


func test_medium_opponent_has_no_artifacts() -> void:
	Helper.win_and_skip(session, "R1")
	Helper.win_and_skip(session, "R2")
	session.choose_node("R3")
	session.leave_coaching()
	session.choose_node("R4")
	var opponent: Dictionary = session.build_match_setup(session.default_roster())["opponent"]
	assert_eq(opponent["id"], "medium")
	assert_eq(opponent["search_depth"], 2)
	assert_eq(opponent["artifacts"], [] as Array[String])


func test_every_opponent_passes_its_hidden_cards() -> void:
	for opponent_id: String in GameConfig.data("opponents"):
		var cfg: Dictionary = GameConfig.data("opponents")[opponent_id]
		assert_eq(session._opponent_setup(opponent_id)["hidden_cards"], int(cfg["hidden_cards"]), opponent_id)


func test_hidden_cards_reach_the_match_and_default_when_missing() -> void:
	GameConfig.data("opponents")["easy"]["hidden_cards"] = 3
	session.choose_node("L1")
	var setup := session.build_match_setup(session.default_roster())
	assert_eq(setup["opponent"]["hidden_cards"], 3)
	assert_eq(ChessMatch.new(setup).hidden_card_count(), 3)
	GameConfig.data("opponents")["easy"].erase("hidden_cards")
	assert_eq(session._opponent_setup("easy")["hidden_cards"], int(GameConfig.value("match", "opponent_hidden_cards")))


func test_opponent_artifacts_never_include_foresight() -> void:
	var artifacts_cfg: Dictionary = GameConfig.data("artifacts")
	var pool: Array = artifacts_cfg["opponent_pool"]
	var expected: Array = artifacts_cfg["artifacts"].keys().filter(func(id: String) -> bool: return id != "foresight")
	assert_eq(_sorted(pool), _sorted(expected), "every artifact except foresight")
	var count := int(GameConfig.data("opponents")["boss"]["artifact_count"])
	var seen := {}
	for _i in 50:
		var picked: Array = session._opponent_setup("boss")["artifacts"]
		assert_eq(picked.size(), count)
		assert_false(picked.has("foresight"))
		for id in picked:
			assert_true(pool.has(id))
			seen[id] = true
	assert_eq(_sorted(seen.keys()), _sorted(pool), "the whole pool is still used")


func _sorted(items: Array) -> Array:
	var copy := items.duplicate()
	copy.sort()
	return copy


func test_finish_match_restores_the_collection_except_used_shields() -> void:
	var rook := _pieces_of("rook")[0]
	var knight := _pieces_of("knight")[0]
	rook.upgrade = "shield"
	knight.upgrade = "range"
	var before := session.collection.map(func(p: PieceData) -> Dictionary: return p.to_dict())
	session.choose_node("L1")
	var setup := session.build_match_setup(session.default_roster())
	for entry in setup["player"]["roster"]:
		entry["piece"].upgrade = "deploy"
		entry["piece"].type = "queen"
	session.finish_match(Helper.result(0, [rook.uid], [], []))
	var after := session.collection.map(func(p: PieceData) -> Dictionary: return p.to_dict())
	assert_eq(after.size(), before.size(), "captured pieces are back")
	for i in before.size():
		var expected: Dictionary = before[i]
		if expected["uid"] == rook.uid:
			expected["upgrade"] = ""
		assert_eq(after[i], expected)
