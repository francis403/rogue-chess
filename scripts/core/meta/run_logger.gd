class_name RunLogger
extends RefCounted
## Writes one JSON file per run plus an aggregate stats.json (D39).
## The run file is rewritten after every entry, so a crash still leaves a log.

const DEFAULT_DIR := "user://logs/"
const STATS_FILE := "stats.json"

var directory: String
var run_file_path: String = ""
var _run: Dictionary = {}


func _init(log_directory: String = DEFAULT_DIR) -> void:
	directory = log_directory if log_directory.ends_with("/") else log_directory + "/"


func start_run(run_seed: int, piece_set: String, artifacts: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	run_file_path = _unique_path("run_%s_%d" % [stamp, run_seed])
	_run = {
		"seed": run_seed,
		"started_at": Time.get_datetime_string_from_system(),
		"piece_set": piece_set,
		"artifacts": artifacts.duplicate(),
		"matches": [],
		"events": [],
		"summary": {},
	}
	_write_run()


## Artifacts are chosen after the piece set, so the session reports them once picked.
func set_artifacts(artifacts: Array[String]) -> void:
	if _run.is_empty():
		return
	_run["artifacts"] = artifacts.duplicate()
	_write_run()


func log_match(entry: Dictionary) -> void:
	if _run.is_empty():
		return
	_run["matches"].append(entry)
	_write_run()


## kind: "purchase_card", "purchase_piece", "remove_card", "upgrade", "reward", "reward_skip".
func log_event(kind: String, data: Dictionary) -> void:
	if _run.is_empty():
		return
	var event := data.duplicate(true)
	event["kind"] = kind
	_run["events"].append(event)
	_write_run()


func finish_run(summary: Dictionary) -> void:
	if _run.is_empty():
		return
	_run["summary"] = summary
	_run["finished_at"] = Time.get_datetime_string_from_system()
	_write_run()
	_update_stats()


func run_data() -> Dictionary:
	return _run.duplicate(true)


func stats_path() -> String:
	return directory + STATS_FILE


func load_stats() -> Dictionary:
	var stats := {
		"runs": 0,
		"boss_wins": 0,
		"runs_per_piece_set": {},
		"boss_wins_per_piece_set": {},
		"match_wins_per_piece_set": {},
		"match_losses_per_piece_set": {},
		"match_wins_per_deck_size": {},
	}
	if not FileAccess.file_exists(stats_path()):
		return stats
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(stats_path())) != OK or not json.data is Dictionary:
		return stats
	for key in stats:
		var saved: Variant = json.data.get(key)
		if stats[key] is int and (saved is float or saved is int):
			stats[key] = int(saved)
		elif stats[key] is Dictionary and saved is Dictionary:
			for sub_key in saved:
				stats[key][sub_key] = int(saved[sub_key])
	return stats


func _update_stats() -> void:
	var stats := load_stats()
	var set_id: String = _run["piece_set"]
	stats["runs"] = int(stats["runs"]) + 1
	_increment(stats["runs_per_piece_set"], set_id)
	if _run["summary"].get("boss_defeated", false):
		stats["boss_wins"] = int(stats["boss_wins"]) + 1
		_increment(stats["boss_wins_per_piece_set"], set_id)
	for match_entry in _run["matches"]:
		if match_entry["result"] == "win":
			_increment(stats["match_wins_per_piece_set"], set_id)
			_increment(stats["match_wins_per_deck_size"], str(match_entry["deck"].size()))
		else:
			_increment(stats["match_losses_per_piece_set"], set_id)
	_write_json(stats_path(), stats)


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _unique_path(base_name: String) -> String:
	var candidate := directory + base_name + ".json"
	var suffix := 2
	while FileAccess.file_exists(candidate):
		candidate = directory + "%s_%d.json" % [base_name, suffix]
		suffix += 1
	return candidate


func _write_run() -> void:
	_write_json(run_file_path, _run)


func _write_json(file_path: String, content: Dictionary) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(content, "  "))
	file.close()
