class_name SettingsPanel
extends Control
## The settings overlay, in two columns: Sound and Motion on the left, Display and
## Controls (click a key to rebind it) on the right; the footer offers leaving the
## run (during a run) and Close. Every change applies at once; slider moves are
## saved by the Settings autoload after a short pause, on release and on close
## (user://settings.json). Esc, the scrim, the settings key (F1) or Close dismiss it.
## The body scrolls when the window is too short for it (large UI scale).

const VOLUMES := [["master_volume", "Master"], ["music_volume", "Music"], ["sfx_volume", "Effects"], ["ui_volume", "Interface"]]
## A sound to hear the new level with once a slider rests (music is heard anyway).
const PREVIEW := {"master_volume": "ui_confirm", "sfx_volume": "piece_land_medium", "ui_volume": "ui_click"}
## Seconds a slider must rest (mouse or arrow keys) before its preview plays.
const PREVIEW_DELAY := 0.25
const SPEEDS := [["normal", "Normal"], ["fast", "Fast"], ["instant", "Instant"]]
const WINDOW_MODES := [["windowed", "Windowed"], ["fullscreen", "Fullscreen"]]
## Switch geometry (the whole toggle row is the hit area, at least TOGGLE_HEIGHT tall).
const TOGGLE_HEIGHT := 44
const SWITCH := Vector2(64, 28)
const CAPTURE_TEXT := "Press a key…"
## Everything around the scrolling body (padding, title, footer) plus a margin to the window.
const CHROME_HEIGHT := 220

var _percent: Dictionary = {}
var _first: Control
var _release_focus: Callable
var _is_closing: bool = false
var _preview_timer: Timer
var _preview_id: String = ""
var _scroll: ScrollContainer
var _body: Control
var _leave_row: HBoxContainer
var _leave_confirm: HBoxContainer
var _note: Label
## action -> its key button in the Controls list.
var _key_buttons: Dictionary = {}
## The action waiting for a key press ("" when none).
var _capturing: String = ""
var _controls_status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := Ui.panel("ModalPanel")
	centre.add_child(panel)
	panel.add_child(_content())
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = PREVIEW_DELAY
	_preview_timer.timeout.connect(func() -> void:
		if _preview_id != "":
			Sfx.play(_preview_id))
	add_child(_preview_timer)
	resized.connect(_fit_body)
	_fit_body.call_deferred()
	A11y.focus_all(self)
	_release_focus = A11y.trap_focus(self)
	A11y.focus_first([_first])
	Sfx.play("ui_open")
	Feel.fade_in(self, "overlay_fade")


func _content() -> VBoxContainer:
	var column := Ui.vbox(Metrics.L)
	column.add_child(Ui.label("Settings", "H1"))
	_body = Ui.hbox(Metrics.XXL)
	_body.add_child(_left_column())
	var divider := ColorRect.new()
	divider.color = Palette.RULE
	divider.custom_minimum_size.x = 1
	_body.add_child(divider)
	_body.add_child(_right_column())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.add_child(_body)
	column.add_child(_scroll)
	column.add_child(Ui.rule())
	column.add_child(_footer())
	return column


## The body takes its full height when the window has room, and scrolls otherwise.
func _fit_body() -> void:
	if _scroll == null or _body == null:
		return
	var body := _body.get_combined_minimum_size()
	var room := maxf(Metrics.XXXL * 3, size.y - CHROME_HEIGHT)
	# A scrolling body gets room for its scroll bar.
	var bar := Metrics.M if body.y > room else 0
	_scroll.custom_minimum_size = Vector2(body.x + bar, minf(body.y, room))


func _left_column() -> VBoxContainer:
	var column := Ui.vbox(Metrics.M)
	column.custom_minimum_size.x = Metrics.SETTINGS_COLUMN
	column.add_child(Ui.label("SOUND", "Eyebrow"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", Metrics.M)
	grid.add_theme_constant_override("v_separation", Metrics.S)
	for entry: Array in VOLUMES:
		_volume_row(grid, entry[0], entry[1])
	column.add_child(grid)
	column.add_child(_toggle("muted", "Mute all sound", "Silences music and effects; the sliders keep their levels."))
	column.add_child(Ui.gap(Metrics.XS))
	column.add_child(Ui.label("MOTION", "Eyebrow"))
	column.add_child(_choice_row("anim_speed", "Animation speed", SPEEDS, "How fast moves, cards and screens animate (%s)"))
	column.add_child(_toggle("reduced_motion", "Reduced motion", "No shaking, flashing, sliding or travel: things fade in place instead."))
	column.add_child(_toggle("screen_shake", "Screen shake", "The board and buttons shake on impacts and refusals. Reduced motion turns it off too."))
	return column


func _right_column() -> VBoxContainer:
	var column := Ui.vbox(Metrics.M)
	column.custom_minimum_size.x = Metrics.SETTINGS_COLUMN
	column.add_child(Ui.label("DISPLAY", "Eyebrow"))
	column.add_child(_choice_row("window_mode", "Window", WINDOW_MODES, "Play %s"))
	var scales := []
	for scale: float in Settings.UI_SCALES:
		scales.append([scale, "%d %%" % roundi(scale * 100.0)])
	column.add_child(_choice_row("ui_scale", "Interface size", scales, "Draw the whole interface at %s"))
	column.add_child(Ui.gap(Metrics.XS))
	var heading := Ui.hbox(Metrics.S)
	heading.add_child(Ui.label("CONTROLS", "Eyebrow"))
	heading.add_child(Ui.spacer())
	var reset := Ui.button("Reset keys", "QuietButton")
	reset.tooltip_text = "Put every key back to its default"
	reset.pressed.connect(_reset_bindings)
	heading.add_child(reset)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", Metrics.S)
	grid.add_theme_constant_override("v_separation", Metrics.XS)
	for action: String in Settings.input_actions():
		var name_label := Ui.label(Settings.action_label(action), "Body")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var key := Ui.button("", "Button")
		key.custom_minimum_size = Vector2(Metrics.SETTINGS_KEY, Metrics.BUTTON_HEIGHT - Metrics.XS)
		key.tooltip_text = "%s · click, then press the new key (Esc cancels)" % Settings.action_label(action)
		key.pressed.connect(_start_capture.bind(action))
		_key_buttons[action] = key
		grid.add_child(key)
	column.add_child(grid)
	_controls_status = Ui.wrapped("Click a key, then press the new one. Esc cancels.", "Caption", Metrics.SETTINGS_COLUMN)
	column.add_child(_controls_status)
	_show_keys()
	return column


## The footer: leaving the run (during a run, with a confirm step), the saving
## note and Close.
func _footer() -> Control:
	var footer := Ui.hbox(Metrics.M)
	if is_run_active():
		_leave_rows(footer)
	_note = Ui.label("Saved automatically · %s opens settings, Esc closes" % A11y.key_label(&"rc_settings"), "Caption")
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_note)
	var close_button := Ui.button("Close", "PrimaryButton")
	close_button.set_meta("sfx", "none")
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	return footer


func _volume_row(grid: GridContainer, key: String, text: String) -> void:
	var name_label := Ui.label(text, "Body")
	name_label.custom_minimum_size.x = Metrics.SETTINGS_LABEL
	grid.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(Metrics.SETTINGS_SLIDER, Metrics.XL)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.tooltip_text = "%s volume · arrow keys change it by 5 %%" % text
	# Sliders draw no focus stylebox of their own: add the theme's ring for keyboard focus.
	slider.draw.connect(func() -> void:
		if slider.has_focus(true):
			slider.draw_style_box(UiTheme.focus_ring(), Rect2(Vector2.ZERO, slider.size)))
	slider.focus_entered.connect(slider.queue_redraw)
	slider.focus_exited.connect(slider.queue_redraw)
	grid.add_child(slider)
	var percent := Ui.label("", "Strong")
	percent.custom_minimum_size.x = Metrics.XXXL
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(percent)
	_percent[key] = percent
	_show_percent(key, slider.value)
	# Every tick applies at once; the file is written once the slider rests or is let go.
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_value(key, value, false)
		_show_percent(key, value)
		_queue_preview(key))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.flush())
	if _first == null:
		_first = slider


## The level's preview sound plays once the slider has rested for PREVIEW_DELAY,
## whether it moved by mouse or by arrow keys (a held key plays it once).
func _queue_preview(key: String) -> void:
	_preview_id = PREVIEW.get(key, "")
	if _preview_id != "" and _preview_timer != null:
		_preview_timer.start()


func _show_percent(key: String, value: float) -> void:
	_percent[key].text = "%d %%" % roundi(value * 100.0)


## A full-width row: the label on the left, a drawn ON / OFF switch on the right.
## The switch is a track with a knob and the word, so the state never relies on
## colour alone; OFF has a light outline (≥3:1 on the panel) and an ivory knob.
func _toggle(key: String, text: String, hint: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.tooltip_text = hint
	toggle.button_pressed = bool(Settings.get_value(key))
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.custom_minimum_size.y = TOGGLE_HEIGHT
	# The built-in switch icon is replaced by an empty one of the same footprint.
	var blank := _blank_icon()
	for icon in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
		toggle.add_theme_icon_override(icon, blank)
	toggle.draw.connect(_draw_switch.bind(toggle))
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	return toggle


static var _blank: ImageTexture


static func _blank_icon() -> ImageTexture:
	if _blank == null:
		_blank = ImageTexture.create_from_image(Image.create_empty(int(SWITCH.x), int(SWITCH.y), false, Image.FORMAT_RGBA8))
	return _blank


func _draw_switch(toggle: CheckButton) -> void:
	var on := toggle.button_pressed
	var track := Rect2(Vector2(toggle.size.x - Metrics.L - SWITCH.x, (toggle.size.y - SWITCH.y) * 0.5), SWITCH)
	var radius := int(SWITCH.y * 0.5)
	toggle.draw_style_box(UiTheme.shared_box(Palette.BRASS if on else Palette.WALNUT_INSET, Palette.BRASS if on else Palette.IVORY_FAINT, radius, 0, 2), track)
	var knob_radius := SWITCH.y * 0.5 - 5.0
	var knob_x := track.end.x - radius if on else track.position.x + radius
	toggle.draw_circle(Vector2(knob_x, track.get_center().y), knob_radius, Palette.BRASS_INK if on else Palette.IVORY_SOFT)
	var font := toggle.get_theme_font("font")
	var word := "ON" if on else "OFF"
	var word_size := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.CAPTION)
	# The word sits in the half the knob is not in.
	var half_x: float = track.position.x + (Metrics.S if on else SWITCH.y)
	var half_w: float = SWITCH.x - SWITCH.y - Metrics.S + (0.0 if on else -Metrics.XS)
	var baseline := track.get_center().y + font.get_ascent(UiTheme.CAPTION) * 0.5 - 1.0
	toggle.draw_string(font, Vector2(half_x + (half_w - word_size.x) * 0.5, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.CAPTION, Palette.BRASS_INK if on else Palette.IVORY)


## A row of exclusive choices for one setting (label, then one button per option).
## The chosen one is a filled brass button; the others stay quiet (fill vs
## outline, not colour alone). `hint` gets the option's text.
func _choice_row(key: String, text: String, options: Array, hint: String) -> HBoxContainer:
	var row := Ui.hbox(Metrics.S)
	var name_label := Ui.label(text, "Body")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for entry: Array in options:
		var button := Ui.button(entry[1], "QuietButton")
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.x = Metrics.SPEED_BUTTON if options.size() <= 3 else Metrics.SCALE_BUTTON
		button.tooltip_text = hint % String(entry[1]).to_lower()
		button.set_pressed_no_signal(_same(Settings.get_value(key), entry[0]))
		button.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(key, entry[0])
			_style_choices(buttons))
		buttons.append(button)
		row.add_child(button)
	if not buttons.any(func(button: Button) -> bool: return button.button_pressed):
		buttons[0].set_pressed_no_signal(true)
	_style_choices(buttons)
	return row


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b


static func _style_choices(buttons: Array[Button]) -> void:
	for button in buttons:
		button.theme_type_variation = "PrimaryButton" if button.button_pressed else "QuietButton"


# --- Controls -------------------------------------------------------------------

func _show_keys() -> void:
	for action: String in _key_buttons:
		var button: Button = _key_buttons[action]
		var names: Array[String] = []
		for code in Settings.keys_for(action):
			names.append(A11y.key_name(code))
		# Keypad twins of the number keys are not worth the room.
		button.text = names[0] if action.begins_with("rc_card_") else " / ".join(names)
		button.theme_type_variation = "Button"


func _start_capture(action: String) -> void:
	_show_keys()
	_capturing = action
	var button: Button = _key_buttons[action]
	button.text = CAPTURE_TEXT
	button.theme_type_variation = "PrimaryButton"
	_controls_status.text = "Press the new key for %s. Esc cancels." % Settings.action_label(action)


## While a key button waits, the next key press binds it (Esc cancels). Runs
## before the settings shortcut and every screen, so F1 or Esc can't leak out.
func _input(event: InputEvent) -> void:
	if _capturing == "" or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	var action := _capturing
	_capturing = ""
	var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_ESCAPE:
		_show_keys()
		_controls_status.text = "Kept %s for %s." % [A11y.key_label(action), Settings.action_label(action)]
		Sfx.play("ui_cancel")
		return
	var swapped := Settings.bind(action, code)
	_show_keys()
	if swapped != "":
		_controls_status.text = "%s is now %s; %s moved to %s." % [Settings.action_label(action), A11y.key_name(code), Settings.action_label(swapped), A11y.key_label(swapped)]
	else:
		_controls_status.text = "%s is now %s." % [Settings.action_label(action), A11y.key_name(code)]
	Sfx.play("ui_confirm")
	Feel.pop(_key_buttons[action])


func _reset_bindings() -> void:
	_capturing = ""
	Settings.reset_bindings()
	_show_keys()
	_controls_status.text = "Every key is back to its default."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
	# Modal: no key reaches the screen underneath.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


## True during a run that hasn't ended, away from the title: leaving it is offered.
static func is_run_active() -> bool:
	return Game.run != null and not Game.run.is_over()


## "Leave run…" with a confirm step: the first press shows what it costs and a
## second, explicit button; Stay puts the first one back.
func _leave_rows(footer: HBoxContainer) -> void:
	_leave_row = Ui.hbox(Metrics.S)
	var leave := Ui.button("Leave run…", "QuietButton")
	leave.tooltip_text = "Give up this run and go back to the title (asks first). Unlocks you already earned are kept."
	leave.set_meta("sfx", "ui_open")
	leave.pressed.connect(_ask_leave)
	_leave_row.add_child(leave)
	footer.add_child(_leave_row)
	_leave_confirm = Ui.hbox(Metrics.S)
	_leave_confirm.visible = false
	var warning := Ui.label("Leave this run? Its deck, pieces and points are lost.", "Strong", Palette.OXBLOOD_INK)
	warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leave_confirm.add_child(warning)
	var stay := Ui.button("Stay", "QuietButton")
	stay.set_meta("sfx", "ui_cancel")
	stay.pressed.connect(_cancel_leave)
	_leave_confirm.add_child(stay)
	var confirm := Ui.button("Leave run", "Button")
	confirm.tooltip_text = "Abandon this run now"
	confirm.set_meta("sfx", "ui_confirm")
	Ui.connect_once(confirm, _leave_run)
	_leave_confirm.add_child(confirm)
	footer.add_child(_leave_confirm)


func _ask_leave() -> void:
	_leave_row.visible = false
	_leave_confirm.visible = true
	_note.self_modulate.a = 0.0
	A11y.focus_all(_leave_confirm)
	A11y.focus_first([_leave_confirm.get_child(1)])


func _cancel_leave() -> void:
	_leave_confirm.visible = false
	_leave_row.visible = true
	_note.self_modulate.a = 1.0
	A11y.focus_first([_leave_row.get_child(0)])


func _leave_run() -> void:
	close()
	Game.abandon_run()


func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	Settings.flush()
	Sfx.play("ui_close")
	_release_focus.call()
	queue_free()
