class_name MapView
extends Control
## Draws the run map from the bottom (floor 1) up to the boss. Node states:
## next (glowing, clickable), visited (brass, path drawn solid), ahead (still
## reachable later: normal), out of reach (faded, edges ghosted).
## Keyboard: with focus, arrows move between the next stops (each wears a small
## number key cap), Enter travels; the screen maps 1-3 to choices(). Hover or
## keyboard selection get the same brass fill; keyboard focus adds an outer ring.
## travel_to() walks a marker along the edge in small hops, the walked path
## lighting up brass behind it, and rings the node on arrival.
## Drawing: the map redraws only when something changes (hover, focus, travel).
## The breathing halos and the dashed paths to the next stops live on a small
## layer drawn behind it (HaloLayer), the only part redrawn every frame.

signal node_pressed(node_id: String)
signal node_hovered(node_id: String)

const NODE_RADIUS := 22.0
const BOSS_RADIUS := 32.0
const MARKER_RADIUS := 9.0
## Node captions: baseline below the node, and the walnut plate that lifts them
## off the paths running behind.
const CAPTION_DROP := 17.0
const CAPTION_PLATE_PAD := Vector2(6, 3)
## Room the floor numbers take left of the first lane, and a caption's half width
## right of the last one: the map block is centred on both together.
const FLOOR_LABELS := 150.0
const CAPTION_HALF := 60.0
const MAX_LANE_GAP := 230.0
## Space kept under the bottom nodes for their captions (and above the boss).
const BOTTOM_ROOM := 76.0
const TOP_ROOM := 44.0

var map: MapGraph
var visited: Array[String] = []
var current: String = ""
var available: Array[String] = []

const TRAVEL_HOPS := 3
const HOP_HEIGHT := 7.0

var _hovered: String = ""
var _ahead: Dictionary = {}
var _halos: HaloLayer
## The travel: from / to positions and progress 0..1 (-1 = no marker), and how visible.
var _travel_from: Vector2 = Vector2.ZERO
var _travel_to: Vector2 = Vector2.ZERO
var _travel: float = -1.0:
	set(value):
		_travel = value
		queue_redraw()
var _marker_alpha: float = 1.0:
	set(value):
		_marker_alpha = value
		queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(func() -> void: _set_hovered(""))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	_halos = HaloLayer.new()
	_halos.map_view = self
	add_child(_halos)
	# The next stops breathe (an ambient loop: config "map_pulse", not sped up by
	# the animation speed); with reduced motion the glow holds still.
	if Settings.reduced_motion() or available.is_empty():
		_halos.pulse = 0.5
		return
	var period := Feel.ambient("map_pulse")
	var tween := create_tween().set_loops()
	tween.tween_property(_halos, "pulse", 1.0, period).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_halos, "pulse", 0.0, period).set_trans(Tween.TRANS_SINE)


## The next stops, left to right (the order of the 1-3 keys).
func choices() -> Array[String]:
	var sorted := available.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return int(map.node(a)["lane"]) < int(map.node(b)["lane"]))
	return sorted


## Walks the marker from the current node (or from below the map) to `node_id`
## in TRAVEL_HOPS small hops, lighting the path behind it, then rings the node.
## Returns the tween; with reduced motion the marker just fades in at the target.
func travel_to(node_id: String, duration: float) -> Tween:
	var target := node_position(node_id)
	_travel_to = target
	_travel_from = node_position(current) if current != "" else target + Vector2(0, 64)
	_halos.hidden_target = node_id
	_halos.queue_redraw()
	var tween := create_tween()
	if Settings.reduced_motion():
		_travel = 1.0
		_marker_alpha = 0.0
		tween.tween_property(self, "_marker_alpha", 1.0, duration)
		return tween
	_travel = 0.0
	tween.tween_property(self, "_travel", 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		FxBurst.spawn(self, FxBurst.Kind.RING, target, Palette.BRASS, _radius(node_id) + 14.0, Motion.time("burst")))
	tween.tween_interval(Motion.time("quick"))
	return tween


## Where the marker is: along the edge, bobbing up between hops.
func _marker_position() -> Vector2:
	var hop := absf(sin(_travel * PI * TRAVEL_HOPS)) * HOP_HEIGHT
	return _travel_from.lerp(_travel_to, _travel) - Vector2(0, hop)


## Every node still reachable from the next choices (the "ahead" set).
func _reachable() -> Dictionary:
	var found := {}
	var queue: Array[String] = available.duplicate()
	while not queue.is_empty():
		var node_id: String = queue.pop_back()
		if found.has(node_id):
			continue
		found[node_id] = true
		for next_id: String in map.node(node_id)["next"]:
			queue.append(next_id)
	return found


func node_position(node_id: String) -> Vector2:
	var info := map.node(node_id)
	var floors := map.floors()
	var top := TOP_ROOM
	var bottom := size.y - BOTTOM_ROOM
	var step := (bottom - top) / maxf(floors - 1, 1)
	return Vector2(_centre_x() + (int(info["lane"]) - 1) * _lane_gap(), bottom - (int(info["floor"]) - 1) * step)


## The middle lane, shifted so the floor labels plus the lanes sit centred together.
func _centre_x() -> float:
	return size.x / 2.0 + (FLOOR_LABELS - CAPTION_HALF) / 2.0


func _lane_gap() -> float:
	return minf((size.x - FLOOR_LABELS - CAPTION_HALF * 2.0) / 2.0, MAX_LANE_GAP)


static func node_label(info: Dictionary) -> String:
	match info["type"]:
		"shop":
			return "Shop"
		"coaching":
			return "Coaching"
		"boss":
			return "Boss"
	return String(GameConfig.data("opponents")[info["opponent"]]["difficulty"])


static func node_glyph(info: Dictionary) -> String:
	match info["type"]:
		"shop":
			return "$"
		"coaching":
			return "↑"
		"boss":
			return UiFonts.glyph("king")
	return UiFonts.glyph("pawn" if info["opponent"] == "easy" else "rook")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var node_id := _node_at(event.position)
		# A soft tick when the mouse reaches a node you can travel to.
		if node_id != _hovered and available.has(node_id):
			Sfx.play("ui_hover")
		_set_hovered(node_id)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var node_id := _node_at(event.position)
		if available.has(node_id):
			accept_event()
			node_pressed.emit(node_id)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		accept_event()
		_step_selection(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		accept_event()
		_step_selection(1)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		if available.has(_hovered):
			node_pressed.emit(_hovered)
		else:
			_step_selection(0)


## Moves the keyboard selection along choices() (0 = select the first).
func _step_selection(direction: int) -> void:
	var order := choices()
	if order.is_empty():
		return
	var index := order.find(_hovered)
	index = 0 if index == -1 else wrapi(index + direction, 0, order.size())
	Sfx.play("ui_hover")
	_set_hovered(order[index])


func _get_tooltip(at_position: Vector2) -> String:
	var node_id := _node_at(at_position)
	if node_id == "":
		return ""
	var info := map.node(node_id)
	var text := "Floor %d · %s" % [info["floor"], describe(info)]
	if available.has(node_id):
		text += "\nNext stop: click, or press %d" % (choices().find(node_id) + 1)
	elif visited.has(node_id):
		text += "\nVisited"
	elif _ahead.has(node_id):
		text += "\nAhead: reachable later on this path"
	else:
		text += "\nOut of reach from where you stand"
	return text


## One line on what a node holds (tooltips and the side panel).
static func describe(info: Dictionary) -> String:
	match info["type"]:
		"shop":
			return "Shop: buy cards and pieces, or remove a card"
		"coaching":
			return "Coaching: pay points to upgrade one card or piece per offer"
	var opponent: Dictionary = GameConfig.data("opponents")[info["opponent"]]
	var kind := "Boss match" if info["type"] == "boss" else "%s match" % opponent["difficulty"]
	return "%s against %s. Win: +%d training points and a card" % [kind, opponent["name"], int(GameConfig.value("economy", "win_points"))]


func _set_hovered(node_id: String) -> void:
	if node_id == _hovered:
		return
	_hovered = node_id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available.has(node_id) else Control.CURSOR_ARROW
	node_hovered.emit(node_id)
	queue_redraw()


func _node_at(at: Vector2) -> String:
	for node_id in map.node_ids():
		if at.distance_to(node_position(node_id)) <= _radius(node_id) + 6.0:
			return node_id
	return ""


func _radius(node_id: String) -> float:
	return BOSS_RADIUS if map.node(node_id)["type"] == "boss" else NODE_RADIUS


func _draw() -> void:
	_ahead = _reachable()
	_draw_floor_numbers()
	for node_id in map.node_ids():
		for next_id: String in map.node(node_id)["next"]:
			_draw_edge(node_id, next_id)
	for node_id in map.node_ids():
		_draw_node(node_id)
	_draw_marker()
	# Captions last, on their plates: neither a path nor the travelling marker
	# ever runs across a word.
	for node_id in map.node_ids():
		_draw_caption(node_position(node_id) + Vector2(0, _radius(node_id) + CAPTION_DROP),
			node_label(map.node(node_id)).to_upper(), Palette.IVORY if _is_choice(node_id) else Palette.IVORY_FAINT)


## A next stop still on offer: once travel starts only its target stays one
## (the other choices stop glowing and lose their key caps at once).
func _is_choice(node_id: String) -> bool:
	return available.has(node_id) and (_halos.hidden_target == "" or node_id == _halos.hidden_target)


func _draw_floor_numbers() -> void:
	var font := get_theme_default_font()
	var next_floor := int(map.node(available[0])["floor"]) if not available.is_empty() else -1
	for floor_number in range(1, map.floors() + 1):
		var some_node := map.nodes_on_floor(floor_number)[0]
		var y := node_position(some_node).y
		var left := _centre_x() - _lane_gap() - FLOOR_LABELS
		var is_next := floor_number == next_floor
		var color := Palette.BRASS if is_next else Palette.IVORY_FAINT
		draw_string(font, Vector2(left, y + 4), "FLOOR %d" % floor_number, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.CAPTION, color)
		draw_line(Vector2(left + 64, y), Vector2(_centre_x() - _lane_gap() - NODE_RADIUS - 12, y), Palette.BRASS_DIM if is_next else Palette.RULE_SOFT, 1.0)


func _draw_edge(from_id: String, to_id: String) -> void:
	var from := node_position(from_id)
	var to := node_position(to_id)
	var direction := (to - from).normalized()
	var start := from + direction * (_radius(from_id) + 4)
	var end := to - direction * (_radius(to_id) + 4)
	var walked := _was_walked(from_id, to_id)
	if walked:
		draw_line(start, end, Palette.BRASS, 3.0, true)
	elif from_id == current and _is_choice(to_id):
		pass  # dashed and breathing: drawn by the HaloLayer
	elif _ahead.has(from_id) and _ahead.has(to_id):
		draw_line(start, end, Palette.RULE_STRONG, 2.0, true)
	else:
		draw_line(start, end, Palette.RULE_SOFT, 1.5, true)


func _was_walked(from_id: String, to_id: String) -> bool:
	var index := visited.find(from_id)
	return index != -1 and index + 1 < visited.size() and visited[index + 1] == to_id


func _draw_node(node_id: String) -> void:
	var info := map.node(node_id)
	var centre := node_position(node_id)
	var radius := _radius(node_id)
	var is_available := _is_choice(node_id)
	var is_visited := visited.has(node_id)
	var is_hovered := node_id == _hovered and is_available
	var is_out := not is_available and not is_visited and not _ahead.has(node_id)
	var fill := Palette.WALNUT_RAISED
	var rim := Palette.RULE_STRONG
	var ink := Palette.IVORY_SOFT
	if is_out:
		fill = Palette.WALNUT
		rim = Palette.RULE_SOFT
		ink = Palette.IVORY_MUTED
	if is_visited:
		fill = Palette.BRASS.darkened(0.55)
		rim = Palette.BRASS
		ink = Palette.BRASS
	if is_available:
		fill = Palette.WALNUT_HIGH
		rim = Palette.BRASS
		ink = Palette.IVORY
	if is_hovered:
		radius += 3
		fill = Palette.BRASS
		ink = Palette.BRASS_INK
	if info["type"] == "boss" and not is_available and not is_visited:
		rim = Palette.OXBLOOD
		ink = Palette.OXBLOOD_INK
	draw_circle(centre + Vector2(0, 2), radius, Color(0, 0, 0, 0.35))
	draw_circle(centre, radius, fill)
	draw_arc(centre, radius, 0, TAU, 40, rim, 2.5 if is_available else 2.0, true)
	if is_hovered and has_focus(true):
		draw_arc(centre, radius + 6, 0, TAU, 48, Palette.FOCUS, 2.0, true)
	if node_id == current:
		_draw_you_are_here(centre, radius)
	var glyph := node_glyph(info)
	var font: Font = UiFonts.symbols() if info["type"] in ["match", "boss"] else UiFonts.serif_bold()
	var font_size := int(radius * 1.1)
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if is_available:
		_draw_key_cap(centre + Vector2(radius * 0.72, -radius * 0.72), str(choices().find(node_id) + 1))


## A node's caption on a walnut plate (the screen's own colour), so a path
## running behind never strikes through the word.
func _draw_caption(baseline_centre: Vector2, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.CAPTION)
	var ascent := font.get_ascent(UiTheme.CAPTION)
	var plate := Rect2(baseline_centre + Vector2(-text_size.x / 2.0, -ascent), Vector2(text_size.x, text_size.y)).grow_individual(
		CAPTION_PLATE_PAD.x, CAPTION_PLATE_PAD.y - 1, CAPTION_PLATE_PAD.x, CAPTION_PLATE_PAD.y - 4)
	draw_style_box(UiTheme.shared_box(Palette.WALNUT_DEEP, Color.TRANSPARENT, 3, 0), plate)
	draw_string(font, baseline_centre - Vector2(text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.CAPTION, color)


## A small ivory key cap with the number that picks this node.
func _draw_key_cap(centre: Vector2, text: String) -> void:
	var cap := Rect2(centre - Vector2(9, 9), Vector2(18, 18))
	draw_style_box(UiTheme.shared_box(Palette.WALNUT_DEEP, Palette.IVORY_FAINT, 3, 0), cap)
	draw_string(UiFonts.numbers(), cap.position + Vector2(0, 14), text, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, UiTheme.CAPTION, Palette.IVORY)


## The travelling marker: an ivory disc with a dark rim, like the "YOU" ring,
## its shadow staying on the path while it hops; the path behind it turns brass.
func _draw_marker() -> void:
	if _travel < 0.0:
		return
	var at := _marker_position()
	var on_path := _travel_from.lerp(_travel_to, _travel)
	if _travel_from != _travel_to:
		var direction := (_travel_to - _travel_from).normalized()
		draw_line(_travel_from + direction * NODE_RADIUS, on_path, Color(Palette.BRASS, _marker_alpha), 3.0, true)
	draw_circle(on_path + Vector2(0, 2), MARKER_RADIUS * 0.9, Color(0, 0, 0, 0.4 * _marker_alpha))
	draw_circle(at, MARKER_RADIUS, Color(Palette.IVORY, _marker_alpha))
	draw_arc(at, MARKER_RADIUS, 0, TAU, 24, Color(Palette.WALNUT_DEEP, _marker_alpha), 2.0, true)


## The node the player stands on: an ivory ring and a small "YOU" tab to its left.
func _draw_you_are_here(centre: Vector2, radius: float) -> void:
	draw_arc(centre, radius + 5, 0, TAU, 40, Palette.IVORY, 2.0, true)
	var font := UiFonts.numbers()
	var tab := Rect2(centre + Vector2(-radius - 48, -10), Vector2(36, 20))
	draw_style_box(UiTheme.shared_box(Palette.IVORY, Color.TRANSPARENT, 3, 0), tab)
	draw_string(font, tab.position + Vector2(0, 15), "YOU", HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, UiTheme.CAPTION, Palette.WALNUT_DEEP)


## The only per-frame drawing on the map: the next stops' breathing halos and the
## dashed paths to them. Drawn behind the map (show_behind_parent), so the nodes
## cover the inner part of each halo exactly as before.
class HaloLayer extends Control:
	var map_view: MapView
	## Set when travel starts: every halo and dashed path goes (the walked
	## path and the target's ring burst take over).
	var hidden_target: String = ""
	var pulse: float = 0.0:
		set(value):
			pulse = value
			queue_redraw()

	func _ready() -> void:
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var view := map_view
		if hidden_target != "":
			return
		for node_id: String in view.available:
			var centre := view.node_position(node_id)
			var radius := view._radius(node_id)
			draw_circle(centre, radius + 6 + 4 * pulse, Color(Palette.BRASS, 0.12 + 0.1 * pulse))
			if view.current == "":
				continue
			var from := view.node_position(view.current)
			var direction := (centre - from).normalized()
			draw_dashed_line(from + direction * (view._radius(view.current) + 4), centre - direction * (radius + 4),
				Color(Palette.BRASS, 0.5 + 0.3 * pulse), 2.0, 8.0, true, true)
