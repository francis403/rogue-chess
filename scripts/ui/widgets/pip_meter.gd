class_name PipMeter
extends Control
## A row of pips: `value` of `total` filled. Used for energy and the deploy budget.
## Overflow beyond total turns every pip oxblood.
## animate_to() steps one pip at a time (pip_stepped per step); setting `value`
## directly jumps and stops any running step animation.

signal pip_stepped(is_filling: bool)

var total: int = 3:
	set(new_total):
		total = new_total
		_resize()
var value: int = 0:
	set(new_value):
		if _steps != null and _steps.is_valid():
			_steps.kill()
		_pop = 0.0
		_shown = new_value
		value = new_value
		queue_redraw()
var pip_size: Vector2 = Vector2(14, 14)
var gap: float = 4.0
var color: Color = Palette.BRASS
var is_round: bool = true

## The value drawn (lags `value` while stepping), the pip that just changed and its pop.
var _shown: int = 0
var _pop_index: int = -1
var _pop: float = 0.0:
	set(new_pop):
		_pop = new_pop
		queue_redraw()
var _steps: Tween


## Steps the meter to `target` one pip per `step` seconds; the changed pip pops.
func animate_to(target: int, step: float) -> void:
	if target == _shown or not is_inside_tree():
		value = target
		return
	var start := _shown
	value = target
	_shown = start
	var direction := 1 if target > start else -1
	_steps = create_tween()
	for i in absi(target - start):
		_steps.tween_callback(_step.bind(direction))
		_steps.tween_property(self, "_pop", 0.0, step).from(1.0)


func _step(direction: int) -> void:
	_shown += direction
	_pop_index = _shown - 1 if direction > 0 else _shown
	pip_stepped.emit(direction > 0)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(total * pip_size.x + maxi(total - 1, 0) * gap, pip_size.y)
	queue_redraw()


func _draw() -> void:
	var is_over := _shown > total
	for i in total:
		var rect := Rect2(Vector2(i * (pip_size.x + gap), (size.y - pip_size.y) / 2.0), pip_size)
		if i == _pop_index and _pop > 0.0:
			rect = rect.grow(pip_size.x * 0.18 * _pop)
		var is_filled := i < _shown
		var fill := Palette.OXBLOOD if is_over else color
		if is_round:
			var centre := rect.get_center()
			var radius := rect.size.x / 2.0
			if is_filled:
				draw_circle(centre, radius, fill)
			else:
				draw_circle(centre, radius, Palette.WALNUT_INSET)
				draw_arc(centre, radius - 1, 0, TAU, 24, Palette.RULE_STRONG, 1.5, true)
		else:
			draw_style_box(UiTheme.shared_box(fill if is_filled else Palette.WALNUT_INSET, Palette.RULE if not is_filled else Color.TRANSPARENT, 2, 0), rect)
