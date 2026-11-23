extends GutTest
## Settings autoload: defaults, saving, reloading, bad files, anim_scale.
## Works only on temp files under user://test_tmp/. Restoring the old path only
## loads it (never saves), so the real user://settings.json is never written.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")
## This process's own temp folder (parallel test runs never share files).
var TMP_DIR := TestTmp.root()
var TMP_SETTINGS := TMP_DIR + "settings_test.json"

var _old_path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	DirAccess.remove_absolute(TMP_SETTINGS)
	_old_path = Settings.path
	Settings.use_path(TMP_SETTINGS)


func after_each() -> void:
	Settings.use_path(_old_path)
	DirAccess.remove_absolute(TMP_SETTINGS)


func _config_defaults() -> Dictionary:
	return GameConfig.data("ux")["settings_defaults"]


func _write(text: String) -> void:
	var file := FileAccess.open(TMP_SETTINGS, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _saved() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TMP_SETTINGS))


func test_defaults_come_from_config_when_no_file() -> void:
	assert_false(FileAccess.file_exists(TMP_SETTINGS))
	for key: String in _config_defaults():
		assert_eq(Settings.get_value(key), _config_defaults()[key], key)
	assert_false(FileAccess.file_exists(TMP_SETTINGS), "loading alone writes nothing")


func test_set_value_saves_to_the_file() -> void:
	Settings.set_value("music_volume", 0.25)
	Settings.set_value("muted", true)
	Settings.set_value("anim_speed", "fast")
	var saved := _saved()
	assert_almost_eq(float(saved["music_volume"]), 0.25, 0.0001)
	assert_eq(saved["muted"], true)
	assert_eq(saved["anim_speed"], "fast")


func test_set_value_emits_changed() -> void:
	watch_signals(Settings)
	Settings.set_value("reduced_motion", true)
	assert_signal_emitted_with_parameters(Settings, "changed", ["reduced_motion"])


func test_values_survive_a_restart() -> void:
	Settings.set_value("master_volume", 0.4)
	Settings.set_value("reduced_motion", true)
	Settings.set_value("anim_speed", "instant")
	# A restart: defaults first, then the same file is loaded again.
	Settings.load_from(TMP_DIR + "missing.json")
	assert_eq(Settings.get_value("anim_speed"), _config_defaults()["anim_speed"])
	Settings.load_from(TMP_SETTINGS)
	assert_almost_eq(float(Settings.get_value("master_volume")), 0.4, 0.0001)
	assert_true(Settings.reduced_motion())
	assert_eq(Settings.get_value("anim_speed"), "instant")


func test_corrupt_file_falls_back_to_defaults() -> void:
	for text in ["{ not json", "", "[1, 2, 3]", "42"]:
		_write(text)
		Settings.load_from(TMP_SETTINGS)
		for key: String in _config_defaults():
			assert_eq(Settings.get_value(key), _config_defaults()[key], "%s with file '%s'" % [key, text])
	# The engine logs a JSON parse error for the unparsable files: expected here.
	for error in get_errors():
		error.handled = true


func test_wrong_types_and_unknown_keys_are_ignored() -> void:
	_write(JSON.stringify({"master_volume": "loud", "muted": 1, "anim_speed": 2, "sfx_volume": 0.3, "cheat_mode": true}))
	Settings.load_from(TMP_SETTINGS)
	assert_eq(Settings.get_value("master_volume"), _config_defaults()["master_volume"], "string volume ignored")
	assert_eq(Settings.get_value("muted"), _config_defaults()["muted"], "number for a bool ignored")
	assert_eq(Settings.get_value("anim_speed"), _config_defaults()["anim_speed"], "number for a speed ignored")
	assert_almost_eq(float(Settings.get_value("sfx_volume")), 0.3, 0.0001, "valid values still load")
	assert_false(Settings.defaults().has("cheat_mode"))


func test_anim_scale_for_each_speed() -> void:
	var speeds: Dictionary = GameConfig.data("ux")["anim_speeds"]
	for speed: String in speeds:
		Settings.set_value("anim_speed", speed)
		assert_almost_eq(Settings.anim_scale(), float(speeds[speed]), 0.0001, speed)
		assert_almost_eq(Settings.time(2.0), 2.0 * float(speeds[speed]), 0.0001, speed)
	assert_eq(Settings.anim_scale(), float(speeds["instant"]))
	assert_lt(float(speeds["fast"]), float(speeds["normal"]), "fast is faster than normal")
	assert_lt(float(speeds["instant"]), float(speeds["fast"]), "instant is fastest")


func test_unknown_speed_name_plays_at_normal_speed() -> void:
	_write(JSON.stringify({"anim_speed": "ludicrous"}))
	Settings.load_from(TMP_SETTINGS)
	assert_eq(Settings.anim_scale(), 1.0)


# --- Display and shake ------------------------------------------------------------

func test_ui_scale_and_screen_shake_persist_and_apply() -> void:
	Settings.set_value("ui_scale", 1.15)
	Settings.set_value("screen_shake", false)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.15, 0.001, "applied at once")
	Settings.load_from(TMP_DIR + "missing.json")
	assert_almost_eq(get_tree().root.content_scale_factor, 1.0, 0.001, "defaults in between")
	assert_true(Settings.screen_shake())
	Settings.load_from(TMP_SETTINGS)
	assert_almost_eq(float(Settings.get_value("ui_scale")), 1.15, 0.001)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.15, 0.001, "applied on load")
	assert_false(Settings.screen_shake())


func test_reduced_motion_also_stops_screen_shake() -> void:
	assert_true(Settings.screen_shake())
	Settings.set_value("reduced_motion", true)
	assert_false(Settings.screen_shake())


func test_window_mode_is_saved_but_never_applied_headless() -> void:
	var mode := DisplayServer.window_get_mode()
	Settings.set_value("window_mode", "windowed")
	assert_eq(_saved()["window_mode"], "windowed")
	assert_eq(DisplayServer.window_get_mode(), mode, "headless: the window is left alone")


# --- Key bindings -----------------------------------------------------------------

func _keys(action: StringName) -> Array:
	var codes := []
	for event in InputMap.action_get_events(action):
		codes.append((event as InputEventKey).physical_keycode)
	return codes


func test_every_input_action_is_registered_with_its_default_keys() -> void:
	for action: String in Settings.input_actions():
		assert_true(InputMap.has_action(action), action)
		assert_eq(_keys(action), Settings.default_keys(action) as Array, action)
	assert_eq(_keys(&"rc_end_turn"), [KEY_E, KEY_SPACE])
	assert_eq(A11y.key_label(&"rc_end_turn"), "E")
	assert_eq(A11y.key_label(&"rc_cancel"), "Esc")
	assert_eq(A11y.key_label(&"rc_settings"), "F1")


func test_rebinding_applies_and_survives_a_restart() -> void:
	assert_eq(Settings.bind("rc_redraw", KEY_T), "", "T was free")
	assert_eq(_keys(&"rc_redraw"), [KEY_T])
	assert_eq(A11y.key_label(&"rc_redraw"), "T")
	assert_eq(int(_saved()["bindings"]["rc_redraw"]), KEY_T)
	Settings.load_from(TMP_DIR + "missing.json")
	assert_eq(_keys(&"rc_redraw"), [KEY_R], "defaults in between")
	Settings.load_from(TMP_SETTINGS)
	assert_eq(_keys(&"rc_redraw"), [KEY_T], "the override is back")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_T
	press.pressed = true
	assert_true(press.is_action_pressed(&"rc_redraw"))


func test_binding_a_used_key_swaps_the_two_actions() -> void:
	assert_eq(Settings.bind("rc_deck", KEY_C), "rc_collection")
	assert_eq(_keys(&"rc_deck"), [KEY_C])
	assert_eq(_keys(&"rc_collection"), [KEY_D], "the other action takes the old key")


func test_reset_restores_the_default_keys() -> void:
	Settings.bind("rc_end_turn", KEY_Q)
	Settings.reset_bindings()
	assert_eq(_keys(&"rc_end_turn"), [KEY_E, KEY_SPACE])
	assert_false(_saved()["bindings"].has("rc_end_turn"))


func test_bad_bindings_in_the_file_are_ignored() -> void:
	_write('{"bindings": {"rc_redraw": "T", "not_an_action": 84}}')
	Settings.load_from(TMP_SETTINGS)
	assert_eq(_keys(&"rc_redraw"), [KEY_R])
	assert_false(InputMap.has_action(&"not_an_action"))
