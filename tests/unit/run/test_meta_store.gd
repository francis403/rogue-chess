extends GutTest

const Helper := preload("res://tests/unit/run/run_test_helper.gd")

var dir: String
var path: String


func before_each() -> void:
	dir = Helper.temp_dir("meta_store")
	path = dir + "meta.json"


func after_each() -> void:
	Helper.remove_dir(dir)


func _write(text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_missing_file_gives_defaults() -> void:
	var meta := MetaStore.new(path)
	assert_eq(meta.unlocked_piece_sets, ["standard"] as Array[String])
	assert_eq(meta.unlocked_artifacts, [] as Array[String])
	assert_false(meta.is_piece_set_unlocked("fire"))


func test_corrupt_file_gives_defaults() -> void:
	_write("{not json at all")
	var meta := MetaStore.new(path)
	assert_eq(meta.unlocked_piece_sets, ["standard"] as Array[String])
	assert_eq(meta.unlocked_artifacts, [] as Array[String])


func test_wrong_shapes_and_unknown_ids_are_ignored() -> void:
	_write(JSON.stringify({"unlocked_piece_sets": "fire", "unlocked_artifacts": ["holes", 3, "made_up", "holes"]}))
	var meta := MetaStore.new(path)
	assert_eq(meta.unlocked_piece_sets, ["standard"] as Array[String])
	assert_eq(meta.unlocked_artifacts, ["holes"] as Array[String])


func test_non_dictionary_json_gives_defaults() -> void:
	_write("[1, 2, 3]")
	assert_eq(MetaStore.new(path).unlocked_piece_sets, ["standard"] as Array[String])


func test_unlock_piece_set_persists_and_reports_new() -> void:
	var meta := MetaStore.new(path)
	assert_true(meta.unlock_piece_set("fire"))
	assert_false(meta.unlock_piece_set("fire"), "second unlock is not new")
	assert_false(meta.unlock_piece_set("water"), "unknown set")
	var reloaded := MetaStore.new(path)
	assert_true(reloaded.is_piece_set_unlocked("fire"))
	assert_true(reloaded.is_piece_set_unlocked("standard"))


func test_unlock_random_artifact_until_all_unlocked() -> void:
	var meta := MetaStore.new(path)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pool: Array = GameConfig.value("artifacts", "unlock_pool")
	var unlocked: Array[String] = []
	for i in pool.size():
		var artifact_id := meta.unlock_random_artifact(rng)
		assert_true(pool.has(artifact_id))
		assert_false(unlocked.has(artifact_id), "never the same artifact twice")
		unlocked.append(artifact_id)
	assert_eq(meta.unlock_random_artifact(rng), "", "nothing left to unlock")
	assert_eq(MetaStore.new(path).unlocked_artifacts.size(), pool.size(), "persisted")


func test_save_creates_missing_folders() -> void:
	var nested := dir + "a/b/meta.json"
	var meta := MetaStore.new(nested)
	assert_true(meta.unlock_piece_set("fire"))
	assert_true(FileAccess.file_exists(nested))


func test_default_path_is_user_meta() -> void:
	assert_eq(MetaStore.DEFAULT_PATH, "user://meta.json")
