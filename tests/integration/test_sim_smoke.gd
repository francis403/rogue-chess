extends GutTest
## A few full simulated runs through the same driver as tools/sim/run_sim.gd.

const SimDriver := preload("res://tools/sim/sim_driver.gd")
const H := preload("res://tests/unit/match/match_helper.gd")
const SMOKE_DIR := "user://sim/smoke/"
const SMOKE_RUNS := 5
const REAL_META_PATH := "user://meta.json"


func after_all() -> void:
	SimDriver.remove_dir(SMOKE_DIR)


func test_sim_runs_finish_without_failures() -> void:
	var real_meta_before := _read(REAL_META_PATH)
	var driver := SimDriver.new(SMOKE_DIR, 1)
	driver.run_many(SMOKE_RUNS)
	for line in driver.summary_lines():
		gut.p(line)
	assert_eq(driver.failures, [] as Array[String])
	assert_eq(driver.failure_count(), 0)
	assert_eq(driver.stats["runs"], SMOKE_RUNS)
	assert_gte(driver.stats["matches"], SMOKE_RUNS, "every run plays at least one match")
	assert_eq(_run_log_count(SMOKE_DIR + "logs/"), SMOKE_RUNS)
	assert_eq(_read(REAL_META_PATH), real_meta_before, "the real meta.json is never touched")


func test_same_seed_gives_the_same_sim() -> void:
	var first := SimDriver.new(SMOKE_DIR, 2)
	first.run_many(2)
	var first_stats := _deterministic_stats(first)
	var second := SimDriver.new(SMOKE_DIR, 2)
	second.run_many(2)
	assert_eq(_deterministic_stats(second), first_stats)


func test_state_error_checks_kings_promotion_and_scores() -> void:
	var sane := H.make([H.piece("king", Vector2i(0, 0))], [H.piece("king", Vector2i(5, 5))])
	var deck_sizes: Array[int] = [5, 5]
	assert_eq(SimDriver.state_error(sane, deck_sizes, [0, 0] as Array[int]), "")
	assert_string_contains(SimDriver.state_error(sane, deck_sizes, [3, 0] as Array[int]), "score events")
	var two_kings := H.make([H.piece("king", Vector2i(0, 0)), H.piece("king", Vector2i(1, 0))], [H.piece("king", Vector2i(5, 5))])
	assert_string_contains(SimDriver.state_error(two_kings, deck_sizes, [0, 0] as Array[int]), "kings")
	var stuck_pawn := H.make([H.piece("king", Vector2i(0, 0)), H.piece("pawn", Vector2i(3, 5))], [H.piece("king", Vector2i(5, 4))])
	assert_string_contains(SimDriver.state_error(stuck_pawn, deck_sizes, [0, 0] as Array[int]), "unpromoted pawn")


func _deterministic_stats(driver: RefCounted) -> Dictionary:
	var stats: Dictionary = driver.stats.duplicate(true)
	for timing_key in ["run_msec", "decision_usec_by_depth", "max_decision_usec_by_depth"]:
		stats.erase(timing_key)
	return stats


func _run_log_count(directory: String) -> int:
	var count := 0
	for file_name in DirAccess.get_files_at(directory):
		if file_name.begins_with("run_") and file_name.ends_with(".json"):
			count += 1
	return count


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
