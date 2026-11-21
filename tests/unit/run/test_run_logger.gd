extends GutTest

const Helper := preload("res://tests/unit/run/run_test_helper.gd")

var dir: String


func before_each() -> void:
	dir = Helper.temp_dir("logger")


func after_each() -> void:
	Helper.remove_dir(dir)


func _log_files() -> Array[String]:
	var files: Array[String] = []
	for file_name in DirAccess.get_files_at(dir + "logs/"):
		if file_name.begins_with("run_"):
			files.append(dir + "logs/" + file_name)
	return files


## A run: win L1 (take a reward), shop, win L3 with an upgraded knight, lose L4.
func _play_logged_run() -> RunSession:
	var session := Helper.started_session(dir, 4242)
	Helper.play_node(session, "L1", 0)
	session.take_reward(0)
	session.choose_node("L2")
	session.points = 10
	session.buy_card(0)
	session.buy_piece(0)
	session.remove_card(session.deck[0].uid)
	session.leave_shop()
	var king := Helper.find_piece(session, "king")
	var knight := Helper.find_piece(session, "knight")
	var rook := Helper.find_piece(session, "rook")
	var pawn := Helper.find_piece(session, "pawn")
	knight.upgrade = "range"
	rook.upgrade = "shield"
	session.choose_node("L3")
	session.build_match_setup([
		{"piece": king, "square": Vector2i(2, 0)}, {"piece": knight, "square": Vector2i(1, 0)},
		{"piece": rook, "square": Vector2i(3, 0)}, {"piece": pawn, "square": Vector2i(2, 1)},
	])
	session.finish_match(Helper.result(0, [rook.uid], [king.uid, knight.uid, rook.uid, pawn.uid], [knight.uid, rook.uid]))
	session.skip_reward()
	Helper.play_node(session, "L4", 1)
	return session


func test_one_file_per_run_with_seed_set_and_artifacts() -> void:
	_play_logged_run()
	var files := _log_files()
	assert_eq(files.size(), 1)
	assert_string_contains(files[0], "4242")
	var run_log: Dictionary = Helper.read_json(files[0])
	assert_eq(int(run_log["seed"]), 4242)
	assert_eq(run_log["piece_set"], "standard")
	assert_eq(run_log["artifacts"], [])


func test_every_match_is_logged() -> void:
	_play_logged_run()
	var run_log: Dictionary = Helper.read_json(_log_files()[0])
	var matches: Array = run_log["matches"]
	assert_eq(matches.size(), 3)
	assert_eq(matches.map(func(m: Dictionary) -> String: return m["result"]), ["win", "win", "loss"])
	assert_eq(matches.map(func(m: Dictionary) -> String: return m["node"]), ["L1", "L3", "L4"])
	assert_eq(matches[0]["opponent"], "easy")
	assert_eq(matches[2]["opponent"], "medium")
	for match_entry in matches:
		for key in ["floor", "reason", "scores", "deck", "roster", "pieces_used", "pieces_moved", "shields_consumed", "points_after"]:
			assert_true(match_entry.has(key), key)
		assert_gt(match_entry["deck"].size(), 0)
		assert_true(match_entry["deck"][0].has("type"))
		assert_true(match_entry["deck"][0].has("upgrade"))
		assert_true(match_entry["roster"][0].has("square"))
	assert_eq(matches[0]["deck"].size(), 6, "deck at the first win, before the reward")
	assert_eq(matches[1]["deck"].size(), 7, "reward + bought card - removed card")


func test_pieces_used_and_upgrades_are_logged() -> void:
	_play_logged_run()
	var run_log: Dictionary = Helper.read_json(_log_files()[0])
	var used: Array = run_log["matches"][1]["pieces_used"]
	assert_eq(used.map(func(p: Dictionary) -> String: return p["type"]), ["king", "knight", "rook", "pawn"])
	var moved: Array = run_log["matches"][1]["pieces_moved"]
	assert_eq(moved.map(func(p: Dictionary) -> String: return p["type"]), ["knight", "rook"])
	assert_eq(moved[0]["upgrade"], "range")
	assert_eq(moved[1]["upgrade"], "shield", "logged with its pre-match upgrade even though the shield was used")
	assert_eq(used[2]["upgrade"], "shield")
	assert_eq(run_log["matches"][1]["shields_consumed"].size(), 1)
	var upgraded: Array = run_log["summary"]["upgraded_pieces"]
	assert_eq(upgraded.map(func(p: Dictionary) -> String: return p["type"]), ["knight"], "the used shield is gone")


func test_events_are_logged() -> void:
	_play_logged_run()
	var run_log: Dictionary = Helper.read_json(_log_files()[0])
	var kinds: Array = run_log["events"].map(func(e: Dictionary) -> String: return e["kind"])
	assert_eq(kinds, ["reward", "purchase_card", "purchase_piece", "remove_card", "reward_skip"])
	assert_true(run_log["events"][1].has("price"))
	assert_true(run_log["events"][1].has("card"))
	assert_true(run_log["events"][2].has("piece"))


func test_summary_is_logged() -> void:
	_play_logged_run()
	var summary: Dictionary = Helper.read_json(_log_files()[0])["summary"]
	assert_eq(summary["result"], "lost")
	assert_eq(int(summary["wins"]), 2)
	assert_eq(int(summary["floors_cleared"]), 3)
	assert_eq(summary["unlock"]["kind"], "artifact")
	for key in ["points", "deck", "collection", "piece_set", "visited"]:
		assert_true(summary.has(key), key)


func test_stats_aggregate_across_runs() -> void:
	_play_logged_run()
	_play_logged_run()
	var stats: Dictionary = Helper.read_json(dir + "logs/stats.json")
	assert_eq(int(stats["runs"]), 2)
	assert_eq(int(stats["boss_wins"]), 0)
	assert_eq(int(stats["runs_per_piece_set"]["standard"]), 2)
	assert_eq(int(stats["match_wins_per_piece_set"]["standard"]), 4)
	assert_eq(int(stats["match_losses_per_piece_set"]["standard"]), 2)
	assert_eq(int(stats["match_wins_per_deck_size"]["6"]), 2)
	assert_eq(int(stats["match_wins_per_deck_size"]["7"]), 2)
	assert_eq(_log_files().size(), 2, "same seed in the same second still gets its own file")


func test_boss_win_is_counted() -> void:
	var session := Helper.started_session(dir)
	for node_id in ["L1", "L3", "L4", "L6"]:
		if node_id == "L3":
			session.choose_node("L2")
			session.leave_shop()
		if node_id == "L6":
			session.choose_node("L5")
			session.leave_coaching()
		Helper.win_and_skip(session, node_id)
	Helper.play_node(session, "BOSS", 0)
	var stats: Dictionary = Helper.read_json(dir + "logs/stats.json")
	assert_eq(int(stats["boss_wins"]), 1)
	assert_eq(int(stats["boss_wins_per_piece_set"]["standard"]), 1)


func test_corrupt_stats_file_is_replaced() -> void:
	DirAccess.make_dir_recursive_absolute(dir + "logs/")
	var file := FileAccess.open(dir + "logs/stats.json", FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	Helper.play_node(Helper.started_session(dir), "L1", 1)
	assert_eq(int(Helper.read_json(dir + "logs/stats.json")["runs"]), 1)


func test_log_calls_before_start_do_nothing() -> void:
	var logger := RunLogger.new(dir + "logs")
	logger.log_match({"result": "win"})
	logger.log_event("reward", {})
	logger.finish_run({})
	assert_eq(logger.run_data(), {})
	assert_false(FileAccess.file_exists(logger.stats_path()))
	assert_eq(RunLogger.DEFAULT_DIR, "user://logs/")
