class_name SelectTile
extends PanelContainer
## A clickable panel with hover, selected and locked states. Put any content inside.

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
var _is_hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_is_hovered = true
		_restyle())
	mouse_exited.connect(func() -> void:
		_is_hovered = false
		_restyle())
	_restyle()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _restyle() -> void:
	var border := Palette.RULE
	var bg := Palette.WALNUT_RAISED
	if is_selected:
		border = Palette.BRASS
		bg = Palette.WALNUT_HIGH
	elif _is_hovered and not is_locked:
		border = Palette.BRASS_DIM
		bg = Palette.WALNUT_HIGH
	var style := UiTheme.box(bg, border, UiTheme.RADIUS, padding, 2 if is_selected else 1)
	add_theme_stylebox_override("panel", style)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
	modulate = Color(1, 1, 1, 0.55) if is_locked else Color.WHITE
