extends Node
## One stage for the screenshot tool: a SubViewport that shows the real main scene
## the way a window of `window` pixels shows it, plus capture and wait helpers.
##
## project.godot uses stretch mode canvas_items + aspect expand on a 1280x720 base:
## the canvas keeps the base width or height (whichever fits tighter), grows along
## the other axis, and is then scaled to the window. A SubViewport of the window's
## size with size_2d_override = that canvas and size_2d_override_stretch reproduces
## it (1920x1080 -> a 1280x720 canvas at 1.5x; 1280x800 -> a 1280x800 canvas at 1x).

const MAIN_SCENE := "res://scenes/main.tscn"
const BASE_SIZE := Vector2i(1280, 720)
## Long enough for screen entrances, the title piece drop (~0.6 s) and the run-end
## unlock reveal (~0.5 s) to finish at normal speed.
const SETTLE := 0.8

var main: Control
var viewport: SubViewport
var out_dir: String
var count: int = 0
var saved: Array[String] = []


## The canvas size a window of `window` pixels gets with canvas_items + expand.
static func canvas_size(window: Vector2i) -> Vector2i:
	var scale := minf(float(window.x) / BASE_SIZE.x, float(window.y) / BASE_SIZE.y)
	return Vector2i(roundi(window.x / scale), roundi(window.y / scale))


## Builds the viewport and the main scene. `dir` is a res:// folder (trailing slash).
func open(window: Vector2i, dir: String) -> void:
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	viewport = SubViewport.new()
	viewport.size = window
	var canvas := canvas_size(window)
	if canvas != window:
		viewport.size_2d_override = canvas
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	main = load(MAIN_SCENE).instantiate()
	viewport.add_child(main)


## Frees the stage. The caller waits a frame (a coroutine of a freed node never resumes).
func close() -> void:
	queue_free()


func screen() -> Control:
	return main.current_screen


# --- Capture --------------------------------------------------------------------

## Waits `settle` seconds, then saves NN_name.png into out_dir.
func shot(shot_name: String, settle: float = SETTLE) -> void:
	await wait(settle)
	_save(await grab(), "%02d_%s.png" % [count + 1, shot_name])
	count += 1


## The next drawn frame of the stage.
func grab() -> Image:
	if not DisplayServer.window_can_draw():
		# The engine skips drawing a hidden window; draw this frame by hand.
		RenderingServer.force_draw(false)
	else:
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


## `frame_count` frames `interval` seconds apart into <dir>/<seq_name>_NN.png. The PNGs
## are encoded after the last frame so the encoding doesn't stretch the timing.
func frames(seq_name: String, frame_count: int, interval: float, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var images: Array[Image] = []
	var start := Time.get_ticks_msec()
	for i in frame_count:
		# Aim at fixed times from the start (a grab itself takes a few ms).
		var due := start + int(i * interval * 1000.0)
		while Time.get_ticks_msec() < due:
			await get_tree().process_frame
		images.append(await grab())
	var old_dir := out_dir
	out_dir = dir
	for i in images.size():
		_save(images[i], "%s_%02d.png" % [seq_name, i + 1])
	out_dir = old_dir


func _save(image: Image, file_name: String) -> void:
	var path := ProjectSettings.globalize_path(out_dir + file_name)
	image.save_png(path)
	saved.append(path)
	print("screenshot: ", path)


# --- Waiting --------------------------------------------------------------------

func wait(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


## Waits until the current screen is no longer busy animating (match screen).
func wait_idle(limit: float = 25.0) -> void:
	await wait(0.3)
	var waited := 0.0
	while waited < limit:
		var current := screen()
		if not current.has_method("is_busy") or not current.is_busy():
			return
		await wait(0.1)
		waited += 0.1
	push_warning("Screen still busy after %.0fs" % limit)


## Starts listening for Sfx sound `id`; pass the result to heard() after the action.
## The sounds mark the exact beat of an effect (the blast, the capture, a banner).
func listen(id: String) -> Dictionary:
	var ear := {"id": id, "hit": false}
	ear["callable"] = func(played_id: String) -> void:
		if played_id == ear["id"]:
			ear["hit"] = true
	Sfx.played.connect(ear["callable"])
	return ear


## Waits until the sound of `ear` played (true) or `timeout` seconds passed (false).
func heard(ear: Dictionary, timeout: float = 6.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not ear["hit"] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	Sfx.played.disconnect(ear["callable"])
	ear.erase("callable")  # the lambda captures `ear`: break the cycle
	if not ear["hit"]:
		push_warning("Screenshot tool: sound '%s' never played" % ear["id"])
	return ear["hit"]


# --- Input ----------------------------------------------------------------------

## A key press and release delivered to the stage like a keyboard would.
func key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		viewport.push_input(event)
	await get_tree().process_frame
