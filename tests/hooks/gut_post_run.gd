extends GutHookScript
## GUT post-run hook: removes this process's temp folder (the settings file the
## pre-run hook set up, plus anything a test left behind), then the shared parent
## folder if no other process still uses it. Settings keeps pointing at the removed
## file until the process exits; it only ever reads it again, never saves.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")


func run() -> void:
	TestTmp.remove_root()
