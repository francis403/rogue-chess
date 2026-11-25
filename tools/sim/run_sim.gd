extends SceneTree
## Headless simulation bot (SPEC "Done": 100 runs, no crashes/illegal states/softlocks).
## Godot --headless -s tools/sim/run_sim.gd -- --runs=100 --seed=1
## Exit code 0 only when nothing failed.

const SimDriver := preload("res://tools/sim/sim_driver.gd")
const DEFAULT_RUNS := 100
const DEFAULT_SEED := 1
const MAX_PRINTED_FAILURES := 20
const PROGRESS_EVERY := 10

## This process's own folder (meta, run logs, settings), so two sims, or a sim and a
## GUT run, never share files. Removed again at the end of _initialize.
var sim_dir := "user://sim/cli_p%d/" % OS.get_process_id()


func _initialize() -> void:
	var args := _parse_args()
	var runs := int(args.get("runs", DEFAULT_RUNS))
	var seed_value := int(args.get("seed", DEFAULT_SEED))
	print("rogue-chess sim: %d runs, seed %d" % [runs, seed_value])
	_use_temp_settings()
	var driver := SimDriver.new(sim_dir, seed_value)
	for run_index in runs:
		driver.run_once(run_index)
		if (run_index + 1) % PROGRESS_EVERY == 0:
			print("  %d/%d runs, %d failures" % [run_index + 1, runs, driver.failure_count()])
	print("---- summary ----")
	for line in driver.summary_lines():
		print(line)
	for failure in driver.failures.slice(0, MAX_PRINTED_FAILURES):
		print("FAIL " + failure)
	print("RESULT: %s" % ("PASS" if driver.failure_count() == 0 else "FAIL"))
	SimDriver.remove_dir(sim_dir)
	DirAccess.remove_absolute("user://sim/")  # only once empty
	quit(0 if driver.failure_count() == 0 else 1)


## The sim plays no UI, but nothing it loads may save to the player's settings:
## point the Settings autoload at a temp file in sim_dir (removed at the end of _initialize).
func _use_temp_settings() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		DirAccess.make_dir_recursive_absolute(sim_dir)
		settings.use_path(sim_dir + "settings.json")


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			args[parts[0]] = parts[1]
	return args
