class_name BoardView
extends Control
## The 6x6 board: maple and walnut squares, holes, highlights, and PieceToken
## children keyed by an id. Rank 0 is drawn at the bottom (the player's side).
## It only draws what it is told; the screens decide what is legal.

signal square_clicked(square: Vector2i)
signal square_hovered(square: Vector2i)
signal cancel_requested
signal piece_dropped(square: Vector2i, data: Variant)

const NO_SQUARE := Vector2i(-1, -1)
const FILES := "abcdef"
const PADDING := 26.0

var board_size: int = 6
var holes: Array[Vector2i] = []
var zone: Array[Vector2i] = []
var movable: Array[Vector2i] = []
var targets: Array[Vector2i] = []
var captures: Array[Vector2i] = []
var last_move: Array[Vector2i] = []
var selected: Vector2i = NO_SQUARE
var drop_squares: Array[Vector2i] = []
## Pieces giving check: drawn with an oxblood corner frame.
var threats: Array[Vector2i] = []

var _tokens: Dictionary = {}
var _token_squares: Dictionary = {}
var _hover: Vector2i = NO_SQUARE
var _flashes: Array[Dictionary] = []


func _ready() -> void:
	resized.connect(_layout_tokens)
	mouse_exited.connect(func() -> void: _set_hover(NO_SQUARE))


func cell() -> float:
	return floorf((minf(size.x, size.y) - PADDING * 2.0) / board_size)


func origin() -> Vector2:
	return ((size - Vector2.ONE * cell() * board_size) / 2.0).floor()


func square_rect(square: Vector2i) -> Rect2:
	var flipped_y := board_size - 1 - square.y
	return Rect2(origin() + Vector2(square.x, flipped_y) * cell(), Vector2.ONE * cell())


func square_centre(square: Vector2i) -> Vector2:
	return square_rect(square).get_center()


func square_at(local: Vector2) -> Vector2i:
	var relative := (local - origin()) / cell()
	var square := Vector2i(floori(relative.x), board_size - 1 - floori(relative.y))
	if square.x < 0 or square.y < 0 or square.x >= board_size or square.y >= board_size:
		return NO_SQUARE
	return square


func set_highlights(new_movable: Array[Vector2i], new_targets: Array[Vector2i], new_captures: Array[Vector2i], new_selected: Vector2i = NO_SQUARE) -> void:
	movable = new_movable
	targets = new_targets
	captures = new_captures
	selected = new_selected
	queue_redraw()


func clear_highlights() -> void:
	set_highlights([], [], [], NO_SQUARE)


func set_token(key: Variant, token: PieceToken, square: Vector2i) -> void:
	if _tokens.has(key) and _tokens[key] != token:
		_tokens[key].queue_free()
	_tokens[key] = token
	_token_squares[key] = square
	if token.get_parent() == null:
		add_child(token)
	_place(token, square)


func token(key: Variant) -> PieceToken:
	return _tokens.get(key)


func token_keys() -> Array:
	return _tokens.keys()


func token_square(key: Variant) -> Vector2i:
	return _token_squares.get(key, NO_SQUARE)


func remove_token(key: Variant) -> void:
	if _tokens.has(key):
		_tokens[key].queue_free()
		_tokens.erase(key)
		_token_squares.erase(key)


func forget_token(key: Variant) -> PieceToken:
	var removed: PieceToken = _tokens.get(key)
	_tokens.erase(key)
	_token_squares.erase(key)
	return removed


func clear_tokens() -> void:
	for key in _tokens.keys():
		remove_token(key)


func move_token(key: Variant, square: Vector2i, duration: float = 0.22) -> Tween:
	var moving: PieceToken = _tokens.get(key)
	if moving == null:
		return null
	_token_squares[key] = square
	moving.z_index = 5
	var tween := create_tween()
	tween.tween_property(moving, "position", _token_position(moving, square), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: moving.z_index = 0)
	return tween


## A brief coloured wash over squares (explosions, blocks).
func flash_squares(squares: Array, color: Color, duration: float = 0.35) -> void:
	var flash := {"squares": squares, "color": color, "alpha": 1.0}
	_flashes.append(flash)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		flash["alpha"] = value
		queue_redraw(), 1.0, 0.0, duration)
	tween.tween_callback(func() -> void:
		_flashes.erase(flash)
		queue_redraw())


func _place(token_node: PieceToken, square: Vector2i) -> void:
	var token_size := cell() * 0.84
	token_node.size = Vector2.ONE * token_size
	token_node.custom_minimum_size = token_node.size
	token_node.position = _token_position(token_node, square)


func _token_position(token_node: PieceToken, square: Vector2i) -> Vector2:
	return square_centre(square) - token_node.size / 2.0


func _layout_tokens() -> void:
	for key in _tokens:
		_place(_tokens[key], _token_squares[key])
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(square_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			cancel_requested.emit()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var square := square_at(event.position)
			if square != NO_SQUARE:
				accept_event()
				square_clicked.emit(square)


func _set_hover(square: Vector2i) -> void:
	if square == _hover:
		return
	_hover = square
	var is_clickable := square != NO_SQUARE and (movable.has(square) or targets.has(square) or captures.has(square) or drop_squares.has(square))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_clickable else Control.CURSOR_ARROW
	square_hovered.emit(square)
	queue_redraw()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var square := square_at(at_position)
	_set_hover(square)
	return data is Dictionary and data.has("roster_piece") and drop_squares.has(square)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	piece_dropped.emit(square_at(at_position), data)


func _draw() -> void:
	var board_rect := Rect2(origin(), Vector2.ONE * cell() * board_size)
	draw_style_box(UiTheme.box(Palette.WALNUT_DEEP, Palette.BRASS_DIM, UiTheme.RADIUS, 0), board_rect.grow(8))
	for x in board_size:
		for y in board_size:
			_draw_square(Vector2i(x, y))
	_draw_coordinates(board_rect)
	for flash in _flashes:
		for square: Vector2i in flash["squares"]:
			draw_rect(square_rect(square), Color(flash["color"], 0.55 * flash["alpha"]))


func _draw_square(square: Vector2i) -> void:
	var rect := square_rect(square)
	var is_light := (square.x + square.y) % 2 == 1
	draw_rect(rect, Palette.MAPLE if is_light else Palette.BOARD_WALNUT)
	if zone.has(square):
		draw_rect(rect, Color(Palette.BRASS, 0.16))
	if last_move.has(square):
		draw_rect(rect, Color(Palette.BRASS, 0.28))
	if holes.has(square):
		_draw_hole(rect)
	if square == selected:
		draw_rect(rect, Color(Palette.BRASS, 0.45))
	if movable.has(square) and square != selected:
		draw_rect(rect.grow(-2), Palette.BRASS, false, 3.0)
	if _hover == square and (movable.has(square) or targets.has(square) or captures.has(square) or drop_squares.has(square)):
		draw_rect(rect, Color(1, 1, 1, 0.14))
	if targets.has(square):
		draw_circle(rect.get_center(), rect.size.x * 0.15, Color(Palette.WALNUT_DEEP, 0.45))
		draw_circle(rect.get_center(), rect.size.x * 0.11, Color(Palette.BRASS, 0.9))
	if threats.has(square):
		_draw_corners(rect.grow(-3), Palette.OXBLOOD)
	if captures.has(square):
		draw_rect(rect, Color(Palette.OXBLOOD, 0.35))
		draw_rect(rect.grow(-2), Palette.OXBLOOD, false, 4.0)


func _draw_corners(rect: Rect2, color: Color) -> void:
	var arm := rect.size.x * 0.28
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := (rect.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(inward.x * arm, 0), color, 4.0)
		draw_line(corner, corner + Vector2(0, inward.y * arm), color, 4.0)


func _draw_hole(rect: Rect2) -> void:
	var centre := rect.get_center()
	var radius := rect.size.x * 0.4
	draw_circle(centre, radius + 3, Color(0, 0, 0, 0.25))
	draw_circle(centre, radius, Palette.HOLE)
	draw_circle(centre + Vector2(0, radius * 0.15), radius * 0.75, Color("050403"))
	draw_arc(centre, radius, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.08), 2.0, true)


func _draw_coordinates(board_rect: Rect2) -> void:
	var font := get_theme_default_font()
	var color := Color(Palette.IVORY_FAINT, 0.9)
	for x in board_size:
		var at := Vector2(board_rect.position.x + (x + 0.5) * cell() - 3, board_rect.end.y + 21)
		draw_string(font, at, FILES[x], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	for y in board_size:
		var at := Vector2(board_rect.position.x - 21, square_centre(Vector2i(0, y)).y + 4)
		draw_string(font, at, str(y + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
