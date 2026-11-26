extends Control
## Listening aid: plays every sound id of config/ux.json → audio.sounds in order
## (then a short excerpt of each music loop), printing and showing its name and
## mix level, so the mix can be judged by ear on speakers and headphones.
##   Godot --path . res://tools/audio/audition.tscn                   # everything
##   Godot --path . res://tools/audio/audition.tscn -- capture check  # only these ids
## Space replays the current sound, Right skips ahead, Esc quits. Volumes are
## the game's defaults: Settings points at a temp file of this process, so the
## player's user://settings.json is never written.

## Silence after each sound, and how long each music loop plays.
const GAP := 0.6
const MUSIC_EXCERPT := 12.0
const TEMP_DIR := "user://audition_tmp/"

var _ids: Array[String] = []
var _index := -1
var _label: Label
var _wait: SceneTreeTimer
var _temp := "%sp%d/" % [TEMP_DIR, OS.get_process_id()]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_temp)
	Settings.use_path(_temp + "settings.json")
	Sfx.apply_volumes()
	theme = UiTheme.build(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Palette.WALNUT_DEEP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_label = Ui.label("", "H1")
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	var audio: Dictionary = GameConfig.data("ux")["audio"]
	var wanted := OS.get_cmdline_user_args()
	for id: String in audio["sounds"].keys() + audio["music"].keys():
		if wanted.is_empty() or wanted.has(id):
			_ids.append(id)
	_next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_finish()
	elif event.is_action_pressed("ui_right"):
		_next()
	elif event.is_action_pressed("ui_accept") and _index >= 0:
		_index -= 1
		_next()


func _next() -> void:
	_index += 1
	if _index >= _ids.size():
		_finish()
		return
	var id := _ids[_index]
	var audio: Dictionary = GameConfig.data("ux")["audio"]
	var is_music: bool = audio["music"].has(id)
	var spec: Dictionary = audio["music"][id] if is_music else audio["sounds"][id]
	var info := "%d / %d   %s   (%s dB%s)" % [_index + 1, _ids.size(), id, str(spec.get("db", 0.0)),
		", %d variants" % int(spec["variants"]) if spec.has("variants") else ""]
	print(info)
	_label.text = "%s\n%s" % [id, info]
	var seconds := MUSIC_EXCERPT
	if is_music:
		Sfx.play_music(id)
	else:
		Sfx.stop_music()
		Sfx.play(id, false)
		var stream: AudioStream = load(Sfx.SFX_DIR + id + ".wav")
		seconds = (stream.get_length() if stream != null else 1.0) + GAP
	# A newer timer (skip / replay) makes this one stale.
	var wait := get_tree().create_timer(seconds)
	_wait = wait
	await wait.timeout
	if _wait == wait:
		_next()


func _finish() -> void:
	_wait = null
	_label.text = "Done"
	print("Audition done: %d ids" % _ids.size())
	for file_name in DirAccess.get_files_at(_temp):
		DirAccess.remove_absolute(_temp.path_join(file_name))
	DirAccess.remove_absolute(_temp)
	DirAccess.remove_absolute(TEMP_DIR)  # only once empty
	Sfx.quit()
