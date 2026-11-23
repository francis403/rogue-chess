class_name FxBurst
extends Control
## One short-lived effect drawn in code at a point, then freed: an expanding ring,
## a radial flash, flying shards, rising embers or smoke. Never shown with
## reduced motion (spawn returns null).
##   FxBurst.spawn(board, FxBurst.Kind.RING, centre, Palette.STEEL, radius, Motion.time("burst"))

enum Kind { RING, FLASH, SHARDS, EMBERS, SMOKE }

const BITS := 7

var kind: Kind = Kind.RING
var color: Color = Color.WHITE
var radius: float = 30.0
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()

## Per bit: x = angle, y = speed factor (shards, embers, smoke).
var _bits: PackedVector2Array = PackedVector2Array()
var _points: PackedVector2Array = PackedVector2Array()


static func spawn(parent: Control, burst_kind: Kind, at: Vector2, burst_color: Color, burst_radius: float, duration: float) -> FxBurst:
	if Motion.reduced() or not is_instance_valid(parent):
		return null
	var burst := FxBurst.new()
	burst.kind = burst_kind
	burst.color = burst_color
	burst.radius = burst_radius
	burst.position = at
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.z_index = 15
	for i in BITS:
		burst._bits.append(Vector2(TAU * (i + randf_range(-0.3, 0.3)) / BITS, randf_range(0.6, 1.0)))
	burst._points.resize(3)
	parent.add_child(burst)
	var tween := burst.create_tween()
	tween.tween_property(burst, "progress", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(burst.queue_free)
	return burst


func _draw() -> void:
	var fade := 1.0 - progress
	match kind:
		Kind.RING:
			draw_arc(Vector2.ZERO, radius * (0.35 + 0.65 * progress), 0, TAU, 48, Color(color, fade), maxf(1.0, 5.0 * fade), true)
		Kind.FLASH:
			draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * progress), Color(color, 0.55 * fade * fade))
		Kind.SHARDS:
			_draw_shards(fade)
		Kind.EMBERS:
			for bit in _bits:
				var at := Vector2(cos(bit.x) * radius * 0.5 * progress, -radius * bit.y * progress * 1.4)
				draw_circle(at, 2.5 * fade + 0.5, Color(color, fade))
		Kind.SMOKE:
			for i in 4:
				var bit := _bits[i]
				var at := Vector2(cos(bit.x) * radius * 0.3, -radius * (0.2 + 0.8 * progress) * bit.y)
				draw_circle(at, radius * (0.25 + 0.35 * progress), Color(color, 0.35 * fade))


## Triangles knocked outward, falling a little and spinning as they fade.
func _draw_shards(fade: float) -> void:
	var size_px := radius * 0.16
	for bit in _bits:
		var direction := Vector2.from_angle(bit.x)
		var at := direction * radius * bit.y * progress + Vector2(0, radius * 0.4 * progress * progress)
		var spin := bit.x + progress * 6.0
		for corner in 3:
			_points[corner] = at + Vector2.from_angle(spin + TAU * corner / 3.0) * size_px * (0.6 + 0.4 * fade)
		draw_colored_polygon(_points, Color(color, fade))
