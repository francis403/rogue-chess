class_name MapView
extends Control
## Draws the run map from the bottom (floor 1) up to the boss. Reachable nodes
## glow and are clickable; the visited path is drawn in brass.

signal node_pressed(node_id: String)
signal node_hovered(node_id: String)

const NODE_RADIUS := 22.0
const BOSS_RADIUS := 32.0

var map: MapGraph
var visited: Array[String] = []
var current: String = ""
var available: Array[String] = []

var _hovered: String = ""
var _pulse: float = 0.0


func _ready() -> void:
	mouse_exited.connect(func() -> void: _set_hovered(""))
	var tween := create_tween().set_loops()
	tween.tween_property(self, "_pulse", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "_pulse", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	if not available.is_empty():
		queue_redraw()


func node_position(node_id: String) -> Vector2:
	var info := map.node(node_id)
	var floors := map.floors()
	var top := 48.0
	var bottom := size.y - 44.0
	var step := (bottom - top) / maxf(floors - 1, 1)
	return Vector2(_centre_x() + (int(info["lane"]) - 1) * _lane_gap(), bottom - (int(info["floor"]) - 1) * step)


## The middle lane, shifted so the floor labels plus the lanes sit centred together.
func _centre_x() -> float:
	return size.x / 2.0 + 60.0


func _lane_gap() -> float:
	return minf(size.x * 0.24, 190.0)


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
		_set_hovered(_node_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var node_id := _node_at(event.position)
		if available.has(node_id):
			accept_event()
			node_pressed.emit(node_id)


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
	_draw_floor_numbers()
	for node_id in map.node_ids():
		for next_id: String in map.node(node_id)["next"]:
			_draw_edge(node_id, next_id)
	for node_id in map.node_ids():
		_draw_node(node_id)


func _draw_floor_numbers() -> void:
	var font := get_theme_default_font()
	for floor_number in range(1, map.floors() + 1):
		var some_node := map.nodes_on_floor(floor_number)[0]
		var y := node_position(some_node).y
		var left := _centre_x() - _lane_gap() - 150.0
		draw_string(font, Vector2(left, y + 4), "FLOOR %d" % floor_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.IVORY_MUTED)
		draw_line(Vector2(left + 64, y), Vector2(_centre_x() - _lane_gap() - NODE_RADIUS - 12, y), Palette.RULE_SOFT, 1.0)


func _draw_edge(from_id: String, to_id: String) -> void:
	var from := node_position(from_id)
	var to := node_position(to_id)
	var direction := (to - from).normalized()
	var start := from + direction * (_radius(from_id) + 4)
	var end := to - direction * (_radius(to_id) + 4)
	var walked := _was_walked(from_id, to_id)
	if walked:
		draw_line(start, end, Palette.BRASS, 3.0, true)
	elif from_id == current and available.has(to_id):
		draw_dashed_line(start, end, Color(Palette.BRASS, 0.5 + 0.3 * _pulse), 2.0, 8.0, true, true)
	else:
		draw_line(start, end, Palette.RULE, 2.0, true)


func _was_walked(from_id: String, to_id: String) -> bool:
	var index := visited.find(from_id)
	return index != -1 and index + 1 < visited.size() and visited[index + 1] == to_id


func _draw_node(node_id: String) -> void:
	var info := map.node(node_id)
	var centre := node_position(node_id)
	var radius := _radius(node_id)
	var is_available := available.has(node_id)
	var is_visited := visited.has(node_id)
	var is_current := node_id == current
	var is_hovered := node_id == _hovered and is_available
	var fill := Palette.WALNUT_RAISED
	var rim := Palette.RULE_STRONG
	var ink := Palette.IVORY_FAINT
	if is_visited:
		fill = Palette.BRASS.darkened(0.55)
		rim = Palette.BRASS
		ink = Palette.BRASS
	if is_available:
		draw_circle(centre, radius + 6 + 4 * _pulse, Color(Palette.BRASS, 0.12 + 0.1 * _pulse))
		fill = Palette.WALNUT_HIGH
		rim = Palette.BRASS
		ink = Palette.IVORY
	if is_hovered:
		radius += 3
		fill = Palette.BRASS
		ink = Palette.BRASS_INK
	if info["type"] == "boss" and not is_available and not is_visited:
		rim = Palette.OXBLOOD
		ink = Palette.OXBLOOD
	draw_circle(centre + Vector2(0, 2), radius, Color(0, 0, 0, 0.35))
	draw_circle(centre, radius, fill)
	draw_arc(centre, radius, 0, TAU, 40, rim, 2.0, true)
	if is_current:
		draw_arc(centre, radius + 5, 0, TAU, 40, Palette.IVORY, 2.0, true)
	var glyph := node_glyph(info)
	var font: Font = UiFonts.symbols() if info["type"] in ["match", "boss"] else UiFonts.serif_bold()
	var font_size := int(radius * 1.1)
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	var caption := node_label(info).to_upper()
	var caption_font := get_theme_default_font()
	var caption_width := caption_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var caption_color := Palette.IVORY_SOFT if is_available else Palette.IVORY_MUTED
	draw_string(caption_font, centre + Vector2(-caption_width / 2.0, radius + 15), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, caption_color)
