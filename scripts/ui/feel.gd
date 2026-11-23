class_name Feel
extends RefCounted
## Feedback tweens shared by every screen (match and menus). Timings are named
## durations in config/ux.json "motion", read through Motion.time() (so the
## animation speed scales them). With reduced motion there is no shake, scale
## pop, glow or travel; fades and texts stay.

const FLOAT_RISE := 36.0


## A short scale bump: "this was chosen / changed". `kind` names the pair of
## durations to use: "<kind>_in" and "<kind>_out" (menus "menu_pop", match "pop").
static func pop(node: CanvasItem, amount: float = 1.08, kind: String = "menu_pop") -> void:
	if not is_instance_valid(node) or Motion.reduced():
		return
	if node is Control:
		node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, Motion.time(kind + "_in")).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, Motion.time(kind + "_out")).set_ease(Tween.EASE_IN_OUT)


## A small shake: "not allowed" (horizontal), or an impact along `axis`.
## A new shake on the same node restarts from the original rest position, so
## overlapping shakes never leave it offset.
static func shake(node: Control, strength: float = 1.0, axis: Vector2 = Vector2.RIGHT) -> void:
	if not is_instance_valid(node) or not Settings.screen_shake():
		return
	var origin: Vector2 = node.get_meta(&"_shake_origin") if node.has_meta(&"_shake_origin") else node.position
	if node.has_meta(&"_shake_tween"):
		var running: Tween = node.get_meta(&"_shake_tween")
		if running.is_valid():
			running.kill()
	node.set_meta(&"_shake_origin", origin)
	var tween := node.create_tween()
	node.set_meta(&"_shake_tween", tween)
	for offset: float in [6.0, -5.0, 3.0, 0.0]:
		tween.tween_property(node, "position", origin + axis * offset * strength, Motion.time("shake_step"))
	tween.tween_callback(func() -> void:
		node.position = origin
		node.remove_meta(&"_shake_origin")
		node.remove_meta(&"_shake_tween"))


## A refused action: error sound, shake the thing pressed, explain in the status line.
static func refuse(node: Control, status: Label, text: String) -> void:
	Sfx.play("ui_error")
	if node != status:
		shake(node)
	if status != null:
		flash_status(status, text)


## Puts `text` in a status line in `color` and shakes it.
static func flash_status(status: Label, text: String, color: Color = Palette.OXBLOOD_INK) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)
	shake(status)


static func fade_in(node: CanvasItem, duration_name: String = "fade") -> void:
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, Motion.time(duration_name)).set_ease(Tween.EASE_OUT)


## Text that rises and fades from `at` (local to `parent`, kept inside it
## horizontally); it only fades with reduced motion. `font_size` 0 keeps the H2
## size. Returns the label, which frees itself at the end.
static func float_text(parent: Control, text: String, at: Vector2, color: Color, font_size: int = 0) -> Label:
	var node := Ui.label(text, "H2", color)
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_outline_color", Palette.WALNUT_DEEP)
	node.add_theme_constant_override("outline_size", 6)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 20
	parent.add_child(node)
	node.reset_size()
	node.position = at - node.size / 2.0
	node.position.x = clampf(node.position.x, 0.0, maxf(parent.size.x - node.size.x, 0.0))
	var duration := Motion.time("float")
	var tween := node.create_tween().set_parallel()
	if not Motion.reduced():
		tween.tween_property(node, "position:y", node.position.y - FLOAT_RISE, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(node.queue_free)
	return node


## A short message that appears at `at` (local to `parent`, centred there and
## kept inside it), holds for "status_hold", then fades: feedback placed where
## the player acted (the shop's "Bought Bishop" on the bought item).
## It sits on a small opaque plate (dark face, rim in its colour), so it reads
## cleanly over whatever is under it. Pops in; with reduced motion it only fades.
## Frees itself.
static func toast(parent: Control, text: String, at: Vector2, color: Color = Palette.FELT) -> PanelContainer:
	var node := PanelContainer.new()
	var plate := UiTheme.box(Palette.WALNUT_DEEP, color, UiTheme.RADIUS_SMALL, 0)
	plate.content_margin_left = Metrics.M
	plate.content_margin_right = Metrics.M
	plate.content_margin_top = Metrics.XS
	plate.content_margin_bottom = Metrics.XS
	node.add_theme_stylebox_override("panel", plate)
	node.add_child(Ui.label(text, "Strong", color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 20
	parent.add_child(node)
	node.reset_size()
	node.position = at - node.size / 2.0
	node.position.x = clampf(node.position.x, 0.0, maxf(parent.size.x - node.size.x, 0.0))
	pop(node, 1.12)
	var tween := node.create_tween()
	tween.tween_interval(Motion.time("status_hold"))
	tween.tween_property(node, "modulate:a", 0.0, Motion.time("fade"))
	tween.tween_callback(node.queue_free)
	return node


## A warm brass glow that fades back: "this got upgraded".
static func glow(node: CanvasItem) -> void:
	if not is_instance_valid(node) or Motion.reduced():
		return
	node.modulate = Color(1.35, 1.22, 0.9)
	node.create_tween().tween_property(node, "modulate", Color.WHITE, Motion.time("glow")) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Deals `nodes` in one after another: fade + rise from a slightly smaller scale
## (a plain staggered fade with reduced motion). Containers own the position, so
## only modulate and scale are tweened. `stagger` and `delay` are unscaled seconds.
static func reveal(nodes: Array, stagger: float = 0.08, delay: float = 0.0) -> void:
	for i in nodes.size():
		var node: Control = nodes[i]
		node.modulate.a = 0.0
		var tween := node.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var start := Settings.time(delay + stagger * i)
		tween.tween_property(node, "modulate:a", 1.0, Motion.time("reveal")).set_delay(start)
		if not Motion.reduced():
			node.scale = Vector2.ONE * 0.9
			# Size is known only after layout: centre the pivot on the tween's first step.
			tween.tween_callback(func() -> void: node.pivot_offset = node.size / 2.0)
			tween.tween_property(node, "scale", Vector2.ONE, Motion.time("reveal")).set_delay(start)


## Seconds of an idle loop (config/ux.json "motion" → "ambient"): the map halo,
## the title's light sweep and piece wave. Not scaled by the animation speed, so
## Fast / Instant never turn a slow breath into flicker; callers skip the loop
## entirely with reduced motion.
static func ambient(loop_name: String) -> float:
	var loops: Dictionary = GameConfig.data("ux")["motion"]["ambient"]
	assert(loops.has(loop_name), "Unknown ambient loop: " + loop_name)
	return float(loops.get(loop_name, 1.0))


## Centre of `node` in `parent`'s local coordinates (for float_text).
static func centre_in(node: Control, parent: Control) -> Vector2:
	return parent.get_global_transform().affine_inverse() * node.get_global_rect().get_center()
