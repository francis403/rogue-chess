class_name SelectTile
extends PanelContainer
## A clickable panel with hover, selected, locked and focus states. Put any content inside.
## Locked tiles sink (darker face, faint border) instead of fading, so their text
## (often the unlock condition) keeps its contrast. Selected ("chosen") is a
## brass-tinted face with a 2 px solid brass border; keyboard focus is a dashed
## ivory ring outside the tile (a different colour AND shape), so the two never
## look alike, even on a chosen tile that also has focus.
## Keyboard: takes focus (Tab / arrows), Enter or Space presses it. The focus ring
## shows only for keyboard focus, not after a mouse click.

signal pressed

var is_locked: bool = false:
	set(value):
		is_locked = value
		_restyle()
var is_selected: bool = false:
	set(value):
		is_selected = value
		_restyle()

var padding: int = 20

## The chosen face: walnut with a little brass in it (IVORY_FAINT 4.6:1, OXBLOOD_INK 4.5:1 on it).
const SELECTED_FACE := Color("342818")
## The focus ring sits this far outside the tile, in dashes this long.
const FOCUS_GAP := 5.0
const FOCUS_DASH := 6.0
var _is_hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func() -> void:
		_is_hovered = true
		if not is_locked:
			Sfx.play("ui_hover")
		_restyle())
	mouse_exited.connect(func() -> void:
		_is_hovered = false
		_restyle())
	focus_entered.connect(_restyle)
	focus_exited.connect(_restyle)
	_restyle()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		pressed.emit()


func _restyle() -> void:
	var border := Palette.RULE
	var bg := Palette.WALNUT_RAISED
	if is_selected:
		border = Palette.BRASS
		bg = SELECTED_FACE
	elif _is_hovered and not is_locked:
		border = Palette.BRASS_DIM
		bg = Palette.WALNUT_HIGH
	if is_locked:
		border = Palette.RULE_SOFT
		bg = Palette.WALNUT
	var style := UiTheme.box(bg, border, UiTheme.RADIUS, padding, 2 if is_selected else 1)
	add_theme_stylebox_override("panel", style)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
	queue_redraw()


## Keyboard focus: a dashed ivory ring FOCUS_GAP px outside the tile, so it never
## looks like the solid brass "chosen" border.
func _draw() -> void:
	if has_focus(true):
		draw_dashed_ring(self, Rect2(Vector2.ZERO, size).grow(FOCUS_GAP))


## A dashed rectangle in ivory, 2 px: the focus mark for tiles and the roster's
## board cursor (shape, not only colour, tells it from a chosen state).
static func draw_dashed_ring(canvas: CanvasItem, rect: Rect2, color: Color = Palette.IVORY) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in corners.size():
		canvas.draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, 2.0, FOCUS_DASH)
