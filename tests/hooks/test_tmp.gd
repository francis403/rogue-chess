extends RefCounted
## Per-process temp folders for tests and tools. Every Godot process gets its own
## folder (named after its process id) under a shared parent, so two GUT runs, the
## sim and the screenshot tool can run at the same time without deleting or reading
## each other's settings, meta files or run logs.

const PARENT := "user://test_tmp/"


## This process's temp root, e.g. user://test_tmp/p4242/ (trailing slash).
static func root() -> String:
	return "%sp%d/" % [PARENT, OS.get_process_id()]


## A folder under this process's root (trailing slash), e.g. dir("full_run").
static func dir(sub: String) -> String:
	return root() + sub.trim_suffix("/") + "/"


## Removes `path` and everything below it.
static func remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		remove_dir(path.path_join(sub))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


## Removes this process's root, then the shared parent if no other process still uses it.
static func remove_root() -> void:
	remove_dir(root())
	DirAccess.remove_absolute(PARENT)  # only succeeds once empty
