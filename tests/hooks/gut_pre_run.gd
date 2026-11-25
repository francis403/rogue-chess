extends GutHookScript
## GUT pre-run hook (.gutconfig.json "pre_run_script"): points the Settings autoload
## at a fresh temp file before any test runs, so no test ever writes (or reads
## again) the player's real user://settings.json. Defaults come from config/ux.json.
## The file lives in this process's own temp folder (tests/hooks/test_tmp.gd), so
## two GUT runs at the same time never share it.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")


static func test_settings_path() -> String:
	return TestTmp.root() + "settings.json"


func run() -> void:
	TestTmp.remove_dir(TestTmp.root())  # a leftover of a crashed run with the same pid
	DirAccess.make_dir_recursive_absolute(TestTmp.root())
	Settings.use_path(test_settings_path())
