extends Node
## Autoload "Settings": player comfort settings (volumes, mute, animation speed,
## reduced motion, screen shake, window mode, UI scale) and key bindings, saved to
## user://settings.json. Defaults live in config/ux.json ("settings_defaults", "input").
## Game actions (rc_*) are registered in the InputMap here at startup; a player's
## rebinding is saved under "bindings" (action -> physical keycode) and replaces
## that action's default keys.
## Usage: Settings.get_value("music_volume"), Settings.set_value("muted", true),
##        Settings.time(0.3) scales a duration by the animation speed.
## A slider being dragged calls set_value(key, value, false): the value applies at
## once but the file is written only after SAVE_DELAY seconds without changes (or
## by flush(), which the settings panel calls on release and close, and this node
## calls before switching files and when the game quits).

signal changed(key: String)

const DEFAULT_PATH := "user://settings.json"
## Seconds without a change before a deferred save is written.
const SAVE_DELAY := 0.3
## UI scale options (root content_scale_factor).
const UI_SCALES: Array[float] = [0.9, 1.0, 1.15, 1.3]
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen"]

signal bindings_changed

var path: String = DEFAULT_PATH
var _values: Dictionary = {}
## Player key overrides: action -> physical keycode.
var _bindings: Dictionary = {}
var _is_dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)
	# Tools and tests can pass `-- --settings=user://x.json` so the real file is never read.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings="):
			path = arg.trim_prefix("--settings=")
	load_from(path)
	# Only at startup and when the player changes it: tools and tests that point
	# Settings at a temp file must not flip the window.
	_apply_window_mode()


## Points storage somewhere else (tests and tools use a temp file) and reloads.
func use_path(new_path: String) -> void:
	load_from(new_path)


func load_from(new_path: String) -> void:
	flush()
	path = new_path
	_values = defaults()
	_bindings = {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if parsed is Dictionary:
		for key: String in _values:
			if parsed.has(key) and typeof(parsed[key]) == typeof(_values[key]):
				_values[key] = parsed[key]
		var saved_bindings = parsed.get("bindings")
		if saved_bindings is Dictionary:
			for action: String in saved_bindings:
				if input_actions().has(action) and saved_bindings[action] is float:
					_bindings[action] = int(saved_bindings[action])
	_register_actions()
	_apply_ui_scale()
	for key: String in _values:
		changed.emit(key)


static func defaults() -> Dictionary:
	return GameConfig.data("ux")["settings_defaults"].duplicate()


func get_value(key: String) -> Variant:
	return _values[key]


## Applies a value. `save_now` false defers the file write (see SAVE_DELAY).
func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	assert(_values.has(key), "Unknown setting: " + key)
	if _values[key] == value:
		return
	_values[key] = value
	if key == "ui_scale":
		_apply_ui_scale()
	elif key == "window_mode":
		_apply_window_mode()
	if save_now:
		save()
	else:
		_is_dirty = true
		if _save_timer != null and _save_timer.is_inside_tree():
			_save_timer.start()
	changed.emit(key)


func save() -> void:
	_is_dirty = false
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.stop()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		var data := _values.duplicate()
		data["bindings"] = _bindings
		file.store_string(JSON.stringify(data, "\t"))


## Writes a deferred change now (nothing to do if every change is saved).
func flush() -> void:
	if _is_dirty:
		save()


func has_unsaved_changes() -> bool:
	return _is_dirty


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		flush()


## Multiplier for every UI animation duration (1.0 = normal).
func anim_scale() -> float:
	return float(GameConfig.data("ux")["anim_speeds"].get(_values["anim_speed"], 1.0))


## A duration scaled by the animation speed.
func time(seconds: float) -> float:
	return seconds * anim_scale()


func reduced_motion() -> bool:
	return bool(_values["reduced_motion"])


func screen_shake() -> bool:
	return bool(_values["screen_shake"]) and not reduced_motion()


func _apply_ui_scale() -> void:
	if is_inside_tree():
		get_tree().root.content_scale_factor = float(_values["ui_scale"])


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _values["window_mode"] == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


# --- Key bindings ---------------------------------------------------------------

## The remappable actions, in config order.
static func input_actions() -> Array:
	return _input_config().keys()


static func action_label(action: String) -> String:
	return String(_input_config()[action]["label"])


static func _input_config() -> Dictionary:
	return GameConfig.data("ux")["input"]["actions"]


## The physical keycodes an action has by default (config).
static func default_keys(action: String) -> Array[int]:
	var codes: Array[int] = []
	for key_name: String in _input_config()[action]["keys"]:
		var code := OS.find_keycode_from_string(key_name)
		assert(code != KEY_NONE, "Unknown key name in config/ux.json input: " + key_name)
		codes.append(code)
	return codes


## The physical keycodes bound to `action` now (override or defaults).
func keys_for(action: String) -> Array[int]:
	if _bindings.has(action):
		var codes: Array[int] = [int(_bindings[action])]
		return codes
	return default_keys(action)


func is_rebound(action: String) -> bool:
	return _bindings.has(action)


## Binds `action` to one physical key (replacing its keys) and saves. If another
## action already used that key, the two swap: the other action gets this
## action's first key. Returns the other action's name, or "" when nothing swapped.
func bind(action: String, physical_keycode: int) -> String:
	assert(input_actions().has(action), "Unknown action: " + action)
	var old_key: int = keys_for(action)[0]
	var swapped := ""
	for other: String in input_actions():
		if other != action and keys_for(other).has(physical_keycode):
			swapped = other
			_bindings[other] = old_key
			break
	_bindings[action] = physical_keycode
	_register_actions()
	save()
	return swapped


## Back to config/ux.json's keys for every action.
func reset_bindings() -> void:
	_bindings = {}
	_register_actions()
	save()


func _register_actions() -> void:
	for action: String in input_actions():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in keys_for(action):
			var event := InputEventKey.new()
			event.physical_keycode = code as Key
			InputMap.action_add_event(action, event)
	bindings_changed.emit()
