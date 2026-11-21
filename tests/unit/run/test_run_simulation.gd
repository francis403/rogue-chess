extends GutTest
## Drives many seeded runs with random choices and fake match results to the end,
## mixing in illegal actions, and checks the run invariants after every step.

const Helper := preload("res://tests/unit/run/run_test_helper.gd")
const Phase := RunSession.Phase
const RUNS := 200
const MAX_STEPS := 500

var dir: String
var rng := RandomNumberGenerator.new()
var meta: MetaStore
var logger: RunLogger
var last_setup: Dictionary = {}


func before_all() -> void:
	dir = Helper.temp_dir("simulation")
	meta = MetaStore.new(dir + "meta.json")
	logger = RunLogger.new(dir + "logs/")


func after_all() -> void:
	Helper.remove_dir(dir)


func _pick(items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]


func _check_invariants(session: RunSession) -> String:
	if not Phase.values().has(session.phase):
		return "invalid phase"
	if session.points < 0:
		return "negative points"
	if session.phase != Phase.SET_SELECT and session.deck.size() < int(GameConfig.value("economy", "min_deck_size")):
		return "deck below the minimum"
	var upgrades := {"card": GameConfig.data("upgrades")["card"], "piece": GameConfig.data("upgrades")["piece"]}
	for card in session.deck:
		if card.upgrade != "" and not upgrades["card"].has(card.upgrade):
			return "unknown card upgrade %s" % card.upgrade
	for piece in session.collection:
		if piece.upgrade != "" and not upgrades["piece"].has(piece.upgrade):
			return "unknown piece upgrade %s" % piece.upgrade
		if piece.piece_set != session.piece_set:
			return "piece from another set"
	for offer in session.coaching_offers():
		if offer["state"] == "open" and offer["item"].upgrade != "":
			return "coaching offers an item that already has an upgrade"
	return ""


func _random_roster(session: RunSession) -> Array:
	if rng.randf() < 0.7:
		return session.default_roster()
	var roster := session.default_roster()
	if roster.size() > 1 and rng.randf() < 0.5:
		roster.pop_front()
	else:
		roster.append({"piece": _pick(session.collection), "square": Vector2i(rng.randi_range(-1, 6), rng.randi_range(-1, 3))})
	return roster


func _fake_result(session: RunSession, setup: Dictionary) -> Dictionary:
	var used: Array[int] = []
	var shields: Array[int] = []
	for entry in setup["player"]["roster"]:
		if rng.randf() < 0.6:
			used.append(entry["piece"].uid)
		if entry["piece"].upgrade == "shield" and rng.randf() < 0.5:
			shields.append(entry["piece"].uid)
	var win_chance := 0.9 if session.current_node_info()["type"] == "match" else 0.5
	return {
		"winner": 0 if rng.randf() < win_chance else 1,
		"reason": _pick(["king_captured", "score", "no_moves", "turn_limit"]),
		"scores": [rng.randi_range(0, 12), rng.randi_range(0, 12)],
		"shields_consumed": shields,
		"player_pieces_used": used,
	}


## One random action for the current phase. Illegal attempts must be refused without side effects.
func _step(session: RunSession) -> String:
	if rng.randf() < 0.1:
		var before := [session.phase, session.points, session.deck.size(), session.collection.size()]
		var illegal: Dictionary = _pick([
			func() -> Dictionary: return session.finish_match({"winner": 7}),
			func() -> Dictionary: return session.take_reward(99),
			func() -> Dictionary: return session.buy_card(-1),
			func() -> Dictionary: return session.remove_card(-5),
			func() -> Dictionary: return session.accept_coaching(42),
			func() -> Dictionary: return session.choose_piece_set("water"),
			func() -> Dictionary: return session.choose_node("NOPE"),
		]).call()
		if illegal["ok"]:
			return "illegal action accepted"
		if before != [session.phase, session.points, session.deck.size(), session.collection.size()]:
			return "refused action changed state"
	match session.phase:
		Phase.SET_SELECT:
			var unlocked := session.available_piece_sets().filter(func(s: Dictionary) -> bool: return not s["locked"])
			return _expect_ok(session.choose_piece_set(_pick(unlocked)["id"]))
		Phase.ARTIFACT_SELECT:
			var ids := session.available_artifacts().map(func(a: Dictionary) -> String: return a["id"])
			var chosen := []
			for artifact_id in ids:
				if chosen.size() < session.max_starting_artifacts() and rng.randf() < 0.5:
					chosen.append(artifact_id)
			return _expect_ok(session.choose_artifacts(chosen))
		Phase.MAP:
			return _expect_ok(session.choose_node(_pick(session.available_nodes())))
		Phase.MATCH_SETUP:
			var roster := _random_roster(session)
			var expected_ok: bool = session.validate_roster(roster)["ok"]
			var setup := session.build_match_setup(roster)
			if setup.has("seed"):
				last_setup = setup
			if setup.has("seed") != expected_ok:
				return "build_match_setup disagrees with validate_roster"
			return ""
		Phase.MATCH:
			return _expect_ok(session.finish_match(_fake_result(session, last_setup)))
		Phase.REWARD:
			if rng.randf() < 0.5:
				return _expect_ok(session.skip_reward())
			return _expect_ok(session.take_reward(rng.randi_range(0, session.reward_offers().size() - 1)))
		Phase.SHOP:
			return _shop_step(session)
		Phase.COACHING:
			return _coaching_step(session)
	return "no action for phase %s" % session.phase_name()


func _shop_step(session: RunSession) -> String:
	var roll := rng.randi_range(0, 3)
	var offers := session.shop_offers()
	match roll:
		0:
			_refused_cleanly(session, session.buy_card(rng.randi_range(0, offers["cards"].size() - 1)))
		1:
			_refused_cleanly(session, session.buy_piece(rng.randi_range(0, offers["pieces"].size() - 1)))
		2:
			_refused_cleanly(session, session.remove_card(_pick(session.deck).uid))
		_:
			return _expect_ok(session.leave_shop())
	return ""


func _coaching_step(session: RunSession) -> String:
	var offers := session.coaching_offers()
	var open_indexes := []
	for i in offers.size():
		if offers[i]["state"] == "open":
			open_indexes.append(i)
	if open_indexes.is_empty() or rng.randf() < 0.2:
		return _expect_ok(session.leave_coaching())
	var index: int = _pick(open_indexes)
	if rng.randf() < 0.6:
		_refused_cleanly(session, session.accept_coaching(index))
	else:
		return _expect_ok(session.decline_coaching(index))
	return ""


func _refused_cleanly(session: RunSession, result: Dictionary) -> void:
	if not result["ok"]:
		assert_ne(result["error"], "", "refusals explain why")


func _expect_ok(result: Dictionary) -> String:
	return "" if result["ok"] else "legal action refused: %s" % result["error"]


func test_random_runs_always_terminate_in_a_valid_state() -> void:
	rng.seed = 20261121
	var failures: Array[String] = []
	var boss_wins := 0
	for run_index in RUNS:
		var session := RunSession.new(rng.randi(), meta, logger)
		var steps := 0
		while not session.is_over() and steps < MAX_STEPS:
			var problem := _step(session)
			if problem == "":
				problem = _check_invariants(session)
			if problem != "":
				failures.append("run %d step %d (%s): %s" % [run_index, steps, session.phase_name(), problem])
				break
			steps += 1
		if not session.is_over():
			failures.append("run %d did not end" % run_index)
		if session.summary()["boss_defeated"]:
			boss_wins += 1
		assert_true(session.unlock_result().has("text"), "run %d has an unlock result" % run_index)
	assert_eq(failures, [] as Array[String])
	assert_gt(boss_wins, 0, "some runs reach and beat the boss")
	assert_true(meta.is_piece_set_unlocked("fire"))
	assert_eq(int(logger.load_stats()["runs"]), RUNS)


func test_coaching_keeps_one_upgrade_per_item() -> void:
	rng.seed = 99
	for run_index in 50:
		var session := RunSession.new(rng.randi(), meta, logger)
		var upgraded_before: Dictionary = {}
		while not session.is_over():
			if session.phase == Phase.COACHING:
				session.points = 100
				for card in session.deck:
					upgraded_before[card] = card.upgrade
				for piece in session.collection:
					upgraded_before[piece] = piece.upgrade
				for i in session.coaching_offers().size():
					session.accept_coaching(i)
				for item in upgraded_before:
					if upgraded_before[item] != "":
						assert_eq(item.upgrade, upgraded_before[item], "an upgrade is never replaced")
				upgraded_before.clear()
			if _step(session) != "":
				break
