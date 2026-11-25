class_name TitleBackdrop
extends Control
## The title screen's room: a huge, barely-there chessboard under a warm lamp
## (a radial vignette that falls off to the walnut-deep corners).

const SQUARE := 88.0

var _vignette: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.WALNUT_DEEP, 0.0))
	gradient.set_color(1, Palette.WALNUT_DEEP)
	gradient.add_point(0.45, Color(Palette.WALNUT_DEEP, 0.35))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = gradient
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.42)
	_vignette.fill_to = Vector2(1.05, 1.0)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.WALNUT_DEEP)
	var columns := ceili(size.x / SQUARE) + 1
	var rows := ceili(size.y / SQUARE) + 1
	var offset := Vector2(fmod(size.x / 2.0, SQUARE) - SQUARE, fmod(size.y * 0.42, SQUARE) - SQUARE)
	for x in columns:
		for y in rows:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(offset + Vector2(x, y) * SQUARE, Vector2.ONE * SQUARE), Palette.WALNUT_RAISED)
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
