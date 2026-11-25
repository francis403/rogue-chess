class_name ArtifactEmblem
extends Control
## An artifact's medallion, drawn in code like the piece tokens: a brass coin with
## a dark rim and a simple ink drawing (Espresso a cup, Trophy Case a trophy,
## Sinkholes a board with holes, Powder Keg a bomb, Crystal Ball a glass ball on
## its stand). Unknown ids get a "?".
## `is_dim` draws it unlit (not chosen): a dark coin with brass ink.

var artifact_id: String = ""
var is_dim: bool = false:
	set(value):
		is_dim = value
		queue_redraw()

var _points := PackedVector2Array()


static func create(id: String, emblem_size: float = Metrics.EMBLEM) -> ArtifactEmblem:
	var emblem := ArtifactEmblem.new()
	emblem.artifact_id = id
	emblem.custom_minimum_size = Vector2.ONE * emblem_size
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return emblem


func _draw() -> void:
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 2.0
	var face := Palette.WALNUT_INSET if is_dim else Palette.BRASS
	var ink := Palette.BRASS if is_dim else Palette.BRASS_INK
	draw_circle(centre + Vector2(0, 2), radius, Color(0, 0, 0, 0.35))
	draw_circle(centre, radius, face)
	draw_arc(centre, radius - 1.0, 0, TAU, 48, Palette.BRASS_DIM if is_dim else Palette.BRASS.lightened(0.25), 2.0, true)
	draw_arc(centre, radius * 0.86, 0, TAU, 48, Color(ink, 0.25), 1.0, true)
	var unit := radius * 0.5
	match artifact_id:
		"extra_energy":
			_cup(centre, unit, ink, face)
		"capture_bonus":
			_trophy(centre, unit, ink)
		"holes":
			_holes(centre, unit, ink, face)
		"exploding":
			_bomb(centre, unit, ink)
		"foresight":
			_crystal_ball(centre, unit, ink, face)
		_:
			var font := UiFonts.serif_bold()
			var font_size := int(radius)
			var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## A cup with a handle and two wisps of steam.
func _cup(c: Vector2, u: float, ink: Color, face: Color) -> void:
	var top := c.y - u * 0.2
	_quad(Vector2(c.x - u * 0.85, top), Vector2(c.x + u * 0.65, top), Vector2(c.x + u * 0.45, c.y + u * 0.9), Vector2(c.x - u * 0.65, c.y + u * 0.9), ink)
	draw_arc(Vector2(c.x + u * 0.7, c.y + u * 0.3), u * 0.32, -PI / 2, PI / 2, 12, ink, maxf(u * 0.16, 1.5), true)
	draw_line(Vector2(c.x - u * 1.05, c.y + u * 1.05), Vector2(c.x + u * 0.85, c.y + u * 1.05), ink, maxf(u * 0.14, 1.5), true)
	draw_line(Vector2(c.x - u * 0.6, top + u * 0.18), Vector2(c.x + u * 0.4, top + u * 0.18), face, maxf(u * 0.08, 1.0), true)
	for x: float in [-0.35, 0.15]:
		var base := Vector2(c.x + u * x, top - u * 0.2)
		draw_arc(base + Vector2(0, -u * 0.3), u * 0.2, PI / 2, PI * 1.5, 8, ink, maxf(u * 0.1, 1.2), true)
		draw_arc(base + Vector2(0, -u * 0.7), u * 0.2, -PI / 2, PI / 2, 8, ink, maxf(u * 0.1, 1.2), true)


## A two-handled cup on a stem and a plinth.
func _trophy(c: Vector2, u: float, ink: Color) -> void:
	var top := c.y - u * 0.95
	_quad(Vector2(c.x - u * 0.75, top), Vector2(c.x + u * 0.75, top), Vector2(c.x + u * 0.3, c.y + u * 0.2), Vector2(c.x - u * 0.3, c.y + u * 0.2), ink)
	draw_circle(Vector2(c.x, c.y + u * 0.05), u * 0.32, ink)
	for side: float in [-1.0, 1.0]:
		draw_arc(Vector2(c.x + side * u * 0.72, top + u * 0.42), u * 0.3, PI / 2 - side * PI / 2, PI * 1.5 - side * PI / 2, 10, ink, maxf(u * 0.13, 1.5), true)
	draw_line(Vector2(c.x, c.y + u * 0.2), Vector2(c.x, c.y + u * 0.7), ink, maxf(u * 0.2, 2.0), true)
	draw_rect(Rect2(c.x - u * 0.55, c.y + u * 0.7, u * 1.1, u * 0.3), ink)


## A small board (3 x 3) with two dark holes in it.
func _holes(c: Vector2, u: float, ink: Color, face: Color) -> void:
	var cell := u * 0.62
	var origin := c - Vector2.ONE * cell * 1.5
	for x in 3:
		for y in 3:
			var square := Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * cell)
			if (x + y) % 2 == 0:
				draw_rect(square, Color(ink, 0.35))
	draw_rect(Rect2(origin, Vector2.ONE * cell * 3), ink, false, maxf(u * 0.08, 1.0))
	for at: Vector2 in [Vector2(1.5, 0.5), Vector2(0.5, 1.5), Vector2(2.5, 2.5)]:
		var centre := origin + at * cell
		draw_circle(centre, cell * 0.36, ink)
		draw_arc(centre, cell * 0.36, PI * 1.1, PI * 1.9, 8, face, 1.0, true)


## A round bomb with a fuse and a spark.
func _bomb(c: Vector2, u: float, ink: Color) -> void:
	var body := c + Vector2(-u * 0.12, u * 0.22)
	draw_circle(body, u * 0.8, ink)
	draw_rect(Rect2(body + Vector2(u * 0.25, -u * 1.0), Vector2(u * 0.42, u * 0.3)).abs(), ink)
	draw_arc(body + Vector2(u * 0.95, -u * 0.85), u * 0.5, PI, PI * 1.5, 8, ink, maxf(u * 0.1, 1.2), true)
	var spark := body + Vector2(u * 0.95, -u * 1.35)
	for i in 4:
		var angle := TAU * i / 8.0
		var reach := Vector2.from_angle(angle) * u * 0.32
		draw_line(spark - reach, spark + reach, ink, maxf(u * 0.09, 1.2), true)


## A glass ball on a low stand, a shine on the glass and a sparkle beside it.
func _crystal_ball(c: Vector2, u: float, ink: Color, face: Color) -> void:
	var ball := c + Vector2(-u * 0.05, -u * 0.22)
	var ball_radius := u * 0.78
	_quad(Vector2(c.x - u * 0.45, c.y + u * 0.5), Vector2(c.x + u * 0.35, c.y + u * 0.5),
		Vector2(c.x + u * 0.7, c.y + u * 0.95), Vector2(c.x - u * 0.8, c.y + u * 0.95), ink)
	draw_line(Vector2(c.x - u * 1.0, c.y + u * 1.05), Vector2(c.x + u * 0.9, c.y + u * 1.05), ink, maxf(u * 0.14, 1.5), true)
	draw_circle(ball, ball_radius, ink)
	# A thin gap where the ball rests in the stand, so it doesn't read as a pawn.
	draw_line(Vector2(c.x - u * 0.62, c.y + u * 0.44), Vector2(c.x + u * 0.52, c.y + u * 0.44), face, maxf(u * 0.1, 1.2), true)
	draw_arc(ball, ball_radius * 0.66, PI * 1.08, PI * 1.42, 10, face, maxf(u * 0.13, 1.5), true)
	draw_circle(ball + Vector2.from_angle(PI * 1.25) * ball_radius * 0.3, u * 0.07, face)
	var spark := c + Vector2(u * 0.95, -u * 0.95)
	for i in 4:
		var reach := Vector2.from_angle(TAU * i / 8.0) * u * (0.28 if i % 2 == 0 else 0.16)
		draw_line(spark - reach, spark + reach, ink, maxf(u * 0.09, 1.2), true)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_points.resize(4)
	_points[0] = a
	_points[1] = b
	_points[2] = c
	_points[3] = d
	draw_colored_polygon(_points, color)
