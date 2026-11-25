extends GutTest
## SettingsPanel drives Settings: sliders, Mute, Reduced motion and the speed buttons
## change (and save) the values, and a "restart" (reload from the same file) keeps
## them, both in Settings and in a freshly opened panel. Slider saves are debounced
## (written after a rest, on release, on close). Temp file only.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")
## This process's own temp folder (parallel test runs never share files).
var TMP_DIR := TestTmp.root()
var TMP_SETTINGS := TMP_DIR + "settings_panel_test.json"

var _old_path: String
var _host: Control


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	DirAccess.remove_absolute(TMP_SETTINGS)
	_old_path = Settings.path
	Settings.use_path(TMP_SETTINGS)
	_host = Control.new()
	_host.size = Vector2(1280, 720)
	add_child_autofree(_host)


func after_each() -> void:
	Settings.use_path(_old_path)
	DirAccess.remove_absolute(TMP_SETTINGS)


func _open_panel() -> SettingsPanel:
	var panel := SettingsPanel.new()
	_host.add_child(panel)
	await wait_process_frames(2)
	return panel


## The panel's sliders in VOLUMES order (master, music, effects, interface).
func _sliders(panel: SettingsPanel) -> Array:
	return panel.find_children("*", "HSlider", true, false)


func _toggle(panel: SettingsPanel, text: String) -> CheckButton:
	for node: CheckButton in panel.find_children("*", "CheckButton", true, false):
		if node.text == text:
			return node
	return null


func _speed_button(panel: SettingsPanel, text: String) -> Button:
	for node: Button in panel.find_children("*", "Button", true, false):
		if node.toggle_mode and node.text == text:
			return node
	return null


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _saved() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TMP_SETTINGS))


func test_panel_shows_current_values() -> void:
	Settings.set_value("music_volume", 0.35)
	Settings.set_value("muted", true)
	Settings.set_value("anim_speed", "fast")
	var panel: SettingsPanel = await _open_panel()
	var sliders := _sliders(panel)
	assert_eq(sliders.size(), SettingsPanel.VOLUMES.size(), "one slider per volume")
	assert_almost_eq((sliders[1] as HSlider).value, 0.35, 0.001, "music slider")
	assert_true(_toggle(panel, "Mute all sound").button_pressed)
	assert_false(_toggle(panel, "Reduced motion").button_pressed)
	assert_true(_speed_button(panel, "Fast").button_pressed)
	assert_false(_speed_button(panel, "Normal").button_pressed)
	assert_eq(_speed_button(panel, "Fast").theme_type_variation, "PrimaryButton", "chosen speed is filled")
	assert_eq(_speed_button(panel, "Normal").theme_type_variation, "QuietButton")


func test_slider_changes_the_volume_and_saves() -> void:
	var panel: SettingsPanel = await _open_panel()
	var music: HSlider = _sliders(panel)[1]
	music.value = 0.2
	assert_almost_eq(float(Settings.get_value("music_volume")), 0.2, 0.001, "applies at once")
	assert_true(panel.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "20 %"), "the percent label follows")
	await wait_seconds(Settings.SAVE_DELAY + 0.2)
	assert_almost_eq(float(_saved()["music_volume"]), 0.2, 0.001, "saved once the slider rests")


## Slider ticks are not written one by one: the file is written after the slider
## rests for Settings.SAVE_DELAY, or at once when the slider is let go or the panel closes.
func test_slider_ticks_are_debounced_and_saved_on_close() -> void:
	var panel: SettingsPanel = await _open_panel()
	var effects: HSlider = _sliders(panel)[2]
	for value: float in [0.5, 0.45, 0.4, 0.35]:
		effects.value = value
	assert_almost_eq(float(Settings.get_value("sfx_volume")), 0.35, 0.001, "every tick applies")
	assert_false(FileAccess.file_exists(TMP_SETTINGS), "no file write per tick")
	assert_true(Settings.has_unsaved_changes())
	panel.close()
	assert_false(Settings.has_unsaved_changes(), "closing writes the pending change")
	assert_almost_eq(float(_saved()["sfx_volume"]), 0.35, 0.001)


func test_letting_go_of_a_slider_saves_at_once() -> void:
	var panel: SettingsPanel = await _open_panel()
	var interface: HSlider = _sliders(panel)[3]
	interface.value = 0.15
	assert_false(FileAccess.file_exists(TMP_SETTINGS))
	interface.drag_ended.emit(true)
	assert_almost_eq(float(_saved()["ui_volume"]), 0.15, 0.001, "saved on release")


## Switching the settings file (a restart, or the tests' temp files) writes a pending change first.
func test_pending_change_is_written_before_switching_files() -> void:
	Settings.set_value("master_volume", 0.3, false)
	assert_false(FileAccess.file_exists(TMP_SETTINGS))
	Settings.load_from(TMP_SETTINGS)
	assert_almost_eq(float(_saved()["master_volume"]), 0.3, 0.001)
	assert_almost_eq(float(Settings.get_value("master_volume")), 0.3, 0.001)


func test_keyboard_change_plays_the_preview_once_it_rests() -> void:
	var panel: SettingsPanel = await _open_panel()
	var heard: Array[String] = []
	var listen := func(id: String) -> void: heard.append(id)
	Sfx.played.connect(listen)
	_press_key(KEY_LEFT)
	_press_key(KEY_LEFT)
	await wait_process_frames(2)
	assert_false(heard.has("ui_confirm"), "not on every tick")
	await wait_seconds(SettingsPanel.PREVIEW_DELAY + 0.2)
	Sfx.played.disconnect(listen)
	assert_eq(heard.count("ui_confirm"), 1, "the master preview plays once after the keys rest")
	assert_true(is_instance_valid(panel))


func test_arrow_keys_move_the_focused_slider() -> void:
	var panel: SettingsPanel = await _open_panel()
	var master: HSlider = _sliders(panel)[0]
	assert_true(master.has_focus(), "the first slider takes focus when the panel opens")
	var before := float(Settings.get_value("master_volume"))
	_press_key(KEY_LEFT)
	await wait_process_frames(1)
	assert_almost_eq(float(Settings.get_value("master_volume")), before - master.step, 0.001, "left lowers it one step")
	_press_key(KEY_RIGHT)
	_press_key(KEY_RIGHT)
	await wait_process_frames(1)
	assert_almost_eq(float(Settings.get_value("master_volume")), before + master.step, 0.001)


func test_toggles_and_speed_buttons_change_settings() -> void:
	var panel: SettingsPanel = await _open_panel()
	_toggle(panel, "Mute all sound").button_pressed = true
	assert_true(Settings.get_value("muted"))
	_toggle(panel, "Reduced motion").button_pressed = true
	assert_true(Settings.reduced_motion())
	_speed_button(panel, "Instant").button_pressed = true
	assert_eq(Settings.get_value("anim_speed"), "instant")
	assert_false(_speed_button(panel, "Normal").button_pressed, "speeds are exclusive")
	assert_eq(_speed_button(panel, "Instant").theme_type_variation, "PrimaryButton")
	_toggle(panel, "Mute all sound").button_pressed = false
	assert_false(Settings.get_value("muted"))


func test_panel_changes_survive_a_restart() -> void:
	var panel: SettingsPanel = await _open_panel()
	(_sliders(panel)[2] as HSlider).value = 0.45
	(_sliders(panel)[3] as HSlider).value = 0.1
	_toggle(panel, "Reduced motion").button_pressed = true
	_speed_button(panel, "Fast").button_pressed = true
	panel.close()
	await wait_process_frames(1)
	# A restart: the autoload starts from defaults, then reads the same file.
	Settings.load_from(TMP_DIR + "missing.json")
	assert_false(Settings.reduced_motion(), "defaults in between")
	Settings.load_from(TMP_SETTINGS)
	assert_almost_eq(float(Settings.get_value("sfx_volume")), 0.45, 0.001)
	assert_almost_eq(float(Settings.get_value("ui_volume")), 0.1, 0.001)
	assert_true(Settings.reduced_motion())
	assert_eq(Settings.get_value("anim_speed"), "fast")
	var reopened: SettingsPanel = await _open_panel()
	assert_almost_eq((_sliders(reopened)[2] as HSlider).value, 0.45, 0.001, "the new panel shows the saved level")
	assert_true(_toggle(reopened, "Reduced motion").button_pressed)
	assert_true(_speed_button(reopened, "Fast").button_pressed)


func test_esc_and_close_dismiss_the_panel() -> void:
	var panel: SettingsPanel = await _open_panel()
	_press_key(KEY_ESCAPE)
	await wait_process_frames(1)
	assert_false(is_instance_valid(panel) and not panel.is_queued_for_deletion(), "Esc closes it")
	var again: SettingsPanel = await _open_panel()
	var close: Button = null
	for node: Button in again.find_children("*", "Button", true, false):
		if node.text == "Close":
			close = node
	close.pressed.emit()
	assert_true(again.is_queued_for_deletion(), "Close closes it")


func _key_button(panel: SettingsPanel, action: String) -> Button:
	return panel._key_buttons[action]


func test_new_toggles_and_display_choices_save() -> void:
	var panel: SettingsPanel = await _open_panel()
	_toggle(panel, "Screen shake").button_pressed = false
	assert_false(Settings.get_value("screen_shake"))
	_toggle(panel, "Large text").button_pressed = true
	assert_true(Settings.get_value("large_text"))
	_speed_button(panel, "Windowed").button_pressed = true
	assert_eq(Settings.get_value("window_mode"), "windowed")
	panel.close()
	await wait_process_frames(1)
	Settings.load_from(TMP_SETTINGS)
	var reopened: SettingsPanel = await _open_panel()
	assert_false(_toggle(reopened, "Screen shake").button_pressed)
	assert_true(_toggle(reopened, "Large text").button_pressed)
	assert_true(_speed_button(reopened, "Windowed").button_pressed)


func test_toggles_are_big_enough_to_hit() -> void:
	var panel: SettingsPanel = await _open_panel()
	assert_gte(_toggle(panel, "Mute all sound").size.y, float(SettingsPanel.TOGGLE_HEIGHT))


func test_click_a_key_then_press_one_to_rebind() -> void:
	var panel: SettingsPanel = await _open_panel()
	var button := _key_button(panel, "rc_redraw")
	assert_eq(button.text, "R")
	button.pressed.emit()
	assert_eq(button.text, SettingsPanel.CAPTURE_TEXT)
	_press_key(KEY_T)
	await wait_process_frames(1)
	assert_eq(button.text, "T")
	assert_eq(A11y.key_label(&"rc_redraw"), "T")
	assert_true(panel.is_inside_tree(), "the key went to the binding, not to the screen")
	# Esc cancels a capture and keeps the key (and the panel stays open).
	button.pressed.emit()
	_press_key(KEY_ESCAPE)
	await wait_process_frames(1)
	assert_eq(button.text, "T")
	assert_false(panel.is_queued_for_deletion(), "Esc only cancelled the capture")
	# Conflicts swap; Reset puts everything back.
	_key_button(panel, "rc_deck").pressed.emit()
	_press_key(KEY_C)
	await wait_process_frames(1)
	assert_eq(_key_button(panel, "rc_collection").text, "D", "swapped")
	for node: Button in panel.find_children("*", "Button", true, false):
		if node.text == "Reset keys":
			node.pressed.emit()
	assert_eq(_key_button(panel, "rc_redraw").text, "R")
	assert_eq(_key_button(panel, "rc_deck").text, "D")


func test_rebinding_survives_a_restart() -> void:
	var panel: SettingsPanel = await _open_panel()
	_key_button(panel, "rc_end_turn").pressed.emit()
	_press_key(KEY_Q)
	await wait_process_frames(1)
	panel.close()
	await wait_process_frames(1)
	Settings.load_from(TMP_DIR + "missing.json")
	assert_eq(A11y.key_label(&"rc_end_turn"), "E")
	Settings.load_from(TMP_SETTINGS)
	assert_eq(A11y.key_label(&"rc_end_turn"), "Q")
	var reopened: SettingsPanel = await _open_panel()
	assert_eq(_key_button(reopened, "rc_end_turn").text, "Q")
