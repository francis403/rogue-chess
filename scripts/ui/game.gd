extends Node
## Autoload "Game": owns the one RunSession and asks the main scene to show screens.
## Screens change the run through RunSession actions, then call show_phase() or notify_changed().

signal screen_requested(screen_name: String)
signal run_changed

const TITLE := "TITLE"

var meta_path: String = MetaStore.DEFAULT_PATH
var log_dir: String = RunLogger.DEFAULT_DIR
var run: RunSession
var match_setup: Dictionary = {}

var _meta: MetaStore


## Points storage somewhere else (the screenshot tool uses a temp folder).
func use_storage(new_meta_path: String, new_log_dir: String) -> void:
	meta_path = new_meta_path
	log_dir = new_log_dir
	_meta = null


func unlocks() -> MetaStore:
	if _meta == null:
		_meta = MetaStore.new(meta_path)
	return _meta


func new_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = randi()
	run = RunSession.new(seed_value, unlocks(), RunLogger.new(log_dir))
	match_setup = {}
	show_phase()


func show_title() -> void:
	screen_requested.emit(TITLE)


func show_phase() -> void:
	run_changed.emit()
	screen_requested.emit(run.phase_name())


func notify_changed() -> void:
	run_changed.emit()
