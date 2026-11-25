extends GutTest

const Helper := preload("res://tests/unit/run/run_test_helper.gd")
const Phase := RunSession.Phase

var dir: String


func before_each() -> void:
	dir = Helper.temp_dir("session_flow")


func after_each() -> void:
	Helper.remove_dir(dir)


func _count_types(items: Array) -> Dictionary:
	var counts := {}
	for item in items:
		counts[item.type] = counts.get(item.type, 0) + 1
	return counts


func test_starts_in_set_select_with_fire_locked() -> void:
	var session := Helper.new_session(dir)
	assert_eq(session.phase, Phase.SET_SELECT)
	assert_eq(session.phase_name(), "SET_SELECT")
	var sets := session.available_piece_sets()
	assert_eq(sets.size(), 2)
	for entry in sets:
		assert_eq(entry["locked"], entry["id"] == "fire", entry["id"])


func test_locked_or_unknown_piece_set_is_refused() -> void:
	var session := Helper.new_session(dir)
	assert_false(session.choose_piece_set("fire")["ok"])
	assert_false(session.choose_piece_set("water")["ok"])
	assert_eq(session.phase, Phase.SET_SELECT)


func test_starting_collection_and_deck() -> void:
	var session := Helper.started_session(dir)
	assert_eq(_count_types(session.collection), {"king": 1, "queen": 1, "rook": 2, "bishop": 2, "knight": 2, "pawn": 8})
	assert_eq(_count_types(session.deck), {"queen": 1, "rook": 1, "bishop": 1, "knight": 1, "pawn": 1, "move": 1})
	for piece in session.collection:
		assert_eq(piece.piece_set, "standard")
		assert_eq(piece.upgrade, "")
	assert_eq(session.points, 0)
	assert_eq(session.wins, 0)


func test_fire_collection_uses_the_fire_set() -> void:
	MetaStore.new(dir + "meta.json").unlock_piece_set("fire")
	var session := Helper.new_session(dir)
	assert_true(session.choose_piece_set("fire")["ok"])
	for piece in session.collection:
		assert_eq(piece.piece_set, "fire")


func test_artifact_step_is_skipped_when_none_unlocked() -> void:
	var session := Helper.new_session(dir)
	session.choose_piece_set("standard")
	assert_eq(session.phase, Phase.MAP)
	assert_false(session.choose_artifacts([])["ok"], "artifact step is not active")


func test_artifact_step_when_unlocked() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	var rng := RandomNumberGenerator.new()
	for i in 3:
		meta.unlock_random_artifact(rng)
	var session := Helper.new_session(dir)
	session.choose_piece_set("standard")
	assert_eq(session.phase, Phase.ARTIFACT_SELECT)
	assert_eq(session.available_artifacts().size(), 3)
	var ids: Array[String] = meta.unlocked_artifacts
	assert_false(session.choose_artifacts([ids[0], ids[1], ids[2]])["ok"], "more than max")
	assert_false(session.choose_artifacts([ids[0], ids[0]])["ok"], "duplicate")
	var locked := (GameConfig.value("artifacts", "unlock_pool") as Array).filter(func(a: String) -> bool: return not ids.has(a))
	assert_false(session.choose_artifacts([locked[0]])["ok"], "locked artifact")
	assert_false(session.choose_artifacts([42])["ok"], "not a string")
	assert_eq(session.phase, Phase.ARTIFACT_SELECT)
	assert_true(session.choose_artifacts([ids[0], ids[1]])["ok"])
	assert_eq(session.artifacts, [ids[0], ids[1]] as Array[String])
	assert_eq(session.phase, Phase.MAP)


func test_choosing_no_artifacts_is_allowed() -> void:
	MetaStore.new(dir + "meta.json").unlock_random_artifact(RandomNumberGenerator.new())
	var session := Helper.new_session(dir)
	session.choose_piece_set("standard")
	assert_true(session.choose_artifacts([])["ok"])
	assert_eq(session.artifacts, [] as Array[String])


func test_crystal_ball_can_be_chosen_once_unlocked() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	var rng := RandomNumberGenerator.new()
	for _artifact_id in GameConfig.value("artifacts", "unlock_pool"):
		meta.unlock_random_artifact(rng)
	assert_true(meta.is_artifact_unlocked("foresight"))
	var session := Helper.new_session(dir)
	session.choose_piece_set("standard")
	var offered := session.available_artifacts().filter(func(a: Dictionary) -> bool: return a["id"] == "foresight")
	assert_eq(offered.size(), 1)
	assert_eq(offered[0]["name"], GameConfig.data("artifacts")["artifacts"]["foresight"]["name"])
	assert_true(session.choose_artifacts(["foresight"])["ok"])
	session.choose_node("L1")
	var setup := session.build_match_setup(session.default_roster())
	assert_eq(setup["player"]["artifacts"], ["foresight"] as Array[String])
	var hidden := int(GameConfig.data("opponents")["easy"]["hidden_cards"]) - int(GameConfig.data("artifacts")["artifacts"]["foresight"]["amount"])
	assert_eq(ChessMatch.new(setup).hidden_card_count(), maxi(hidden, 0), "Crystal Ball reaches the match")


func test_map_node_choice() -> void:
	var session := Helper.started_session(dir)
	assert_eq(session.available_nodes(), ["L1", "M1", "R1"] as Array[String])
	assert_false(session.choose_node("L2")["ok"], "not reachable yet")
	assert_false(session.choose_node("NOPE")["ok"])
	assert_true(session.choose_node("L1")["ok"])
	assert_eq(session.phase, Phase.MATCH_SETUP)
	assert_eq(session.current_node, "L1")
	assert_eq(session.visited, ["L1"] as Array[String])
	assert_eq(session.available_nodes(), [] as Array[String], "no nodes outside the map phase")


func test_shop_and_coaching_nodes_open_their_phases() -> void:
	var session := Helper.started_session(dir)
	Helper.win_and_skip(session, "L1")
	session.choose_node("L2")
	assert_eq(session.phase, Phase.SHOP)
	session.leave_shop()
	assert_eq(session.phase, Phase.MAP)
	assert_eq(session.available_nodes(), ["L3"] as Array[String])

	var other := Helper.started_session(dir, 2)
	Helper.win_and_skip(other, "R1")
	Helper.win_and_skip(other, "R2")
	other.choose_node("R3")
	assert_eq(other.phase, Phase.COACHING)
	other.leave_coaching()
	assert_eq(other.phase, Phase.MAP)


func test_win_gives_points_and_reward_phase() -> void:
	var session := Helper.started_session(dir)
	assert_true(Helper.play_node(session, "L1", 0)["ok"])
	assert_eq(session.phase, Phase.REWARD)
	assert_eq(session.points, 2)
	assert_eq(session.wins, 1)


func test_reward_offers_three_distinct_cards() -> void:
	var session := Helper.started_session(dir)
	Helper.play_node(session, "L1", 0)
	var offers := session.reward_offers()
	assert_eq(offers.size(), 3)
	var types := {}
	for card in offers:
		types[card.type] = true
		assert_eq(card.upgrade, "")
		assert_true((GameConfig.value("economy", "reward_card_pool") as Array).has(card.type))
	assert_eq(types.size(), 3)


func test_take_reward_adds_card() -> void:
	var session := Helper.started_session(dir)
	Helper.play_node(session, "L1", 0)
	var offered := session.reward_offers()[1]
	assert_false(session.take_reward(3)["ok"])
	assert_false(session.take_reward(-1)["ok"])
	assert_true(session.take_reward(1)["ok"])
	assert_eq(session.deck.size(), 7)
	assert_true(session.deck.has(offered))
	assert_eq(session.points, 2, "no skip bonus")
	assert_eq(session.phase, Phase.MAP)
	assert_false(session.take_reward(0)["ok"], "reward is gone")
	assert_eq(session.reward_offers(), [] as Array[CardData])


func test_skip_reward_gives_a_point() -> void:
	var session := Helper.started_session(dir)
	Helper.play_node(session, "L1", 0)
	assert_true(session.skip_reward()["ok"])
	assert_eq(session.points, 3)
	assert_eq(session.deck.size(), 6)
	assert_eq(session.phase, Phase.MAP)
	assert_false(session.skip_reward()["ok"], "only once")
	assert_eq(session.points, 3)


func test_loss_ends_the_run_with_an_artifact_unlock() -> void:
	var session := Helper.started_session(dir)
	Helper.win_and_skip(session, "M1")
	Helper.play_node(session, "M2", 1)
	assert_eq(session.phase, Phase.RUN_END)
	assert_true(session.is_over())
	assert_eq(session.points, 3, "no points for a loss")
	var unlock := session.unlock_result()
	assert_eq(unlock["kind"], "artifact")
	assert_true(unlock["is_new"])
	assert_true(MetaStore.new(dir + "meta.json").is_artifact_unlocked(unlock["id"]), "persisted")
	var summary := session.summary()
	assert_eq(summary["result"], "lost")
	assert_false(summary["boss_defeated"])
	assert_eq(summary["floors_cleared"], 1)
	assert_eq(summary["wins"], 1)
	assert_eq(summary["points"], 3)
	assert_eq(summary["deck"].size(), 6)
	assert_eq(summary["collection"].size(), 16)
	assert_eq(summary["unlock"]["text"], unlock["text"])


func test_loss_when_every_artifact_is_unlocked() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	var rng := RandomNumberGenerator.new()
	for artifact_id in GameConfig.value("artifacts", "unlock_pool"):
		meta.unlock_random_artifact(rng)
	var session := Helper.started_session(dir)
	Helper.play_node(session, "L1", 1)
	assert_eq(session.phase, Phase.RUN_END)
	var unlock := session.unlock_result()
	assert_eq(unlock["id"], "")
	assert_false(unlock["is_new"])
	assert_ne(unlock["text"], "")


func _play_to_boss(session: RunSession) -> void:
	Helper.win_and_skip(session, "L1")
	session.choose_node("L2")
	session.leave_shop()
	Helper.win_and_skip(session, "L3")
	Helper.win_and_skip(session, "L4")
	session.choose_node("L5")
	session.leave_coaching()
	Helper.win_and_skip(session, "L6")


func test_beating_the_boss_unlocks_fire() -> void:
	var session := Helper.started_session(dir)
	_play_to_boss(session)
	assert_eq(session.available_nodes(), ["BOSS"] as Array[String])
	session.choose_node("BOSS")
	assert_eq(session.phase, Phase.MATCH_SETUP)
	var setup := session.build_match_setup(session.default_roster())
	assert_eq(setup["opponent"]["id"], "boss")
	var boss_artifacts: Array = setup["opponent"]["artifacts"]
	assert_eq(boss_artifacts.size(), int(GameConfig.data("opponents")["boss"]["artifact_count"]), "boss gets its configured artifacts")
	for id in boss_artifacts:
		assert_true(GameConfig.data("artifacts")["artifacts"].has(id), "a real artifact id")
	assert_eq(boss_artifacts.size(), _as_set(boss_artifacts).size(), "boss artifacts are distinct")
	session.finish_match(Helper.result(0))
	assert_eq(session.phase, Phase.RUN_END)
	assert_eq(session.wins, 5)
	assert_eq(session.points, 5 * 2 + 4)
	var unlock := session.unlock_result()
	assert_eq(unlock, {"kind": "piece_set", "id": "fire", "is_new": true, "text": unlock["text"]})
	assert_eq(session.summary()["result"], "won")
	assert_eq(session.summary()["floors_cleared"], 7)
	assert_true(MetaStore.new(dir + "meta.json").is_piece_set_unlocked("fire"), "persists to the next run")
	var next_run := Helper.new_session(dir, 99)
	assert_true(next_run.choose_piece_set("fire")["ok"])


func test_beating_the_boss_again_is_not_a_new_unlock() -> void:
	MetaStore.new(dir + "meta.json").unlock_piece_set("fire")
	var session := Helper.started_session(dir)
	_play_to_boss(session)
	Helper.play_node(session, "BOSS", 0)
	assert_false(session.unlock_result()["is_new"])
	assert_eq(session.unlock_result()["id"], "fire")


func test_losing_to_the_boss_ends_the_run() -> void:
	var session := Helper.started_session(dir)
	_play_to_boss(session)
	Helper.play_node(session, "BOSS", 1)
	assert_eq(session.phase, Phase.RUN_END)
	assert_eq(session.summary()["result"], "lost")
	assert_eq(session.summary()["floors_cleared"], 6)
	assert_eq(session.unlock_result()["kind"], "artifact")


func test_actions_in_the_wrong_phase_are_refused() -> void:
	var session := Helper.new_session(dir)
	var refusals := [
		session.choose_node("L1"), session.build_match_setup([]), session.finish_match(Helper.result(0)),
		session.take_reward(0), session.skip_reward(), session.buy_card(0), session.buy_piece(0),
		session.remove_card(1), session.leave_shop(), session.accept_coaching(0),
		session.decline_coaching(0), session.leave_coaching(), session.choose_artifacts([]),
	]
	for refusal in refusals:
		assert_false(refusal["ok"])
		assert_ne(refusal["error"], "")
	assert_eq(session.phase, Phase.SET_SELECT)
	assert_eq(session.shop_offers(), {})
	assert_eq(session.coaching_offers(), [] as Array[Dictionary])


func test_run_end_refuses_everything() -> void:
	var session := Helper.started_session(dir)
	Helper.play_node(session, "L1", 1)
	assert_false(session.choose_node("L2")["ok"])
	assert_false(session.choose_piece_set("standard")["ok"])
	assert_false(session.finish_match(Helper.result(0))["ok"])
	assert_eq(session.phase, Phase.RUN_END)


func test_invalid_match_results_are_refused() -> void:
	var session := Helper.started_session(dir)
	session.choose_node("L1")
	session.build_match_setup(session.default_roster())
	assert_false(session.finish_match({})["ok"])
	assert_false(session.finish_match({"winner": 2})["ok"])
	assert_false(session.finish_match({"winner": "0"})["ok"])
	assert_false(session.finish_match({"winner": 0, "scores": [1]})["ok"])
	assert_false(session.finish_match({"winner": 0, "shields_consumed": 5})["ok"])
	assert_eq(session.phase, Phase.MATCH)
	assert_true(session.finish_match({"winner": 0})["ok"], "optional keys default")


func test_same_seed_gives_the_same_run() -> void:
	var first := Helper.started_session(dir, 1234)
	var second := Helper.started_session(dir, 1234)
	for session in [first, second]:
		Helper.play_node(session, "L1", 0)
	var first_types := first.reward_offers().map(func(c: CardData) -> String: return c.type)
	var second_types := second.reward_offers().map(func(c: CardData) -> String: return c.type)
	assert_eq(first_types, second_types)


func _as_set(items: Array) -> Dictionary:
	var d := {}
	for item in items:
		d[item] = true
	return d
