class_name PipMeter
extends Control
## A row of pips: `value` of `total` filled. Used for energy and the deploy budget.
## Overflow beyond total turns every pip oxblood.

var total: int = 3:
	set(new_total):
		total = new_total
		_resize()
var value: int = 0:
	set(new_value):
		value = new_value
		queue_redraw()
var pip_size: Vector2 = Vector2(14, 14)
var gap: float = 4.0
var color: Color = Palette.BRASS
var is_round: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(total * pip_size.x + maxi(total - 1, 0) * gap, pip_size.y)
	queue_redraw()


func _draw() -> void:
	var is_over := value > total
	for i in total:
		var rect := Rect2(Vector2(i * (pip_size.x + gap), (size.y - pip_size.y) / 2.0), pip_size)
		var is_filled := i < value
		var fill := Palette.OXBLOOD if is_over else color
		if is_round:
			var centre := rect.get_center()
			var radius := pip_size.x / 2.0
			if is_filled:
				draw_circle(centre, radius, fill)
			else:
				draw_circle(centre, radius, Palette.WALNUT_INSET)
				draw_arc(centre, radius - 1, 0, TAU, 24, Palette.RULE_STRONG, 1.5, true)
		else:
			draw_style_box(UiTheme.box(fill if is_filled else Palette.WALNUT_INSET, Palette.RULE if not is_filled else Color.TRANSPARENT, 2, 0), rect)
