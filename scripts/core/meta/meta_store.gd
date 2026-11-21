class_name MetaStore
extends RefCounted
## Unlocks that persist between runs (D38). Loads on creation; every unlock saves.
## A missing or corrupt file falls back to the defaults and never crashes.

const DEFAULT_PATH := "user://meta.json"

var path: String
var unlocked_piece_sets: Array[String] = []
var unlocked_artifacts: Array[String] = []


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	load_from_disk()


func is_piece_set_unlocked(set_id: String) -> bool:
	return unlocked_piece_sets.has(set_id)


func is_artifact_unlocked(artifact_id: String) -> bool:
	return unlocked_artifacts.has(artifact_id)


## Returns true if the set was newly unlocked.
func unlock_piece_set(set_id: String) -> bool:
	if not _known_piece_sets().has(set_id) or unlocked_piece_sets.has(set_id):
		return false
	unlocked_piece_sets.append(set_id)
	save()
	return true


## Unlocks one random locked artifact from the pool and returns its id ("" if none left).
func unlock_random_artifact(rng: RandomNumberGenerator) -> String:
	var locked: Array[String] = []
	for artifact_id in _artifact_pool():
		if not unlocked_artifacts.has(artifact_id):
			locked.append(artifact_id)
	if locked.is_empty():
		return ""
	var picked := locked[rng.randi_range(0, locked.size() - 1)]
	unlocked_artifacts.append(picked)
	save()
	return picked


func reset_to_defaults() -> void:
	unlocked_piece_sets.clear()
	for set_id in GameConfig.data("piece_sets")["default_unlocked"]:
		unlocked_piece_sets.append(String(set_id))
	unlocked_artifacts.clear()


func load_from_disk() -> void:
	reset_to_defaults()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return
	var saved: Dictionary = json.data
	_merge_known(unlocked_piece_sets, saved.get("unlocked_piece_sets", []), _known_piece_sets())
	_merge_known(unlocked_artifacts, saved.get("unlocked_artifacts", []), _artifact_pool())


func save() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"unlocked_piece_sets": unlocked_piece_sets,
		"unlocked_artifacts": unlocked_artifacts,
	}, "  "))
	file.close()
	return true


func _merge_known(target: Array[String], saved_ids: Variant, known_ids: Array[String]) -> void:
	if not saved_ids is Array:
		return
	for saved_id in saved_ids:
		if saved_id is String and known_ids.has(saved_id) and not target.has(saved_id):
			target.append(saved_id)


func _known_piece_sets() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(GameConfig.data("piece_sets")["sets"].keys())
	return ids


func _artifact_pool() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(GameConfig.data("artifacts")["unlock_pool"])
	return ids
