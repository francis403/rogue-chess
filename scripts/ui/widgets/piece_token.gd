class_name PieceToken
extends Control
## A round piece token: ivory disc for the player, ebony disc for the opponent,
## with badges for shield, burn countdown, promotion and upgrades.

var piece_type: String = "pawn"
var side: int = 0
var piece_set: String = "standard"
var upgrade: String = ""
var has_shield: bool = false
var burn_left: int = 0
var is_promoted: bool = false
var is_locked: bool = false
## A Fire piece that hasn't moved yet: its first move ignites it.
var can_ignite: bool = false
## A king an enemy piece could capture right now.
var is_in_check: bool = false
var flash_color: Color = Color.TRANSPARENT:
	set(value):
		flash_color = value
		queue_redraw()
## Pixels the piece floats above its shadow (picked up, mid-hop).
var lift: float = 0.0:
	set(value):
		lift = value
		queue_redraw()
## Scale of the burn badge (pops when the timer ticks).
var burn_pop: float = 1.0:
	set(value):
		burn_pop = value
		queue_redraw()

## Reused by every redraw (tokens redraw each frame while they move or flash).
var _shield_points: PackedVector2Array = PackedVector2Array()


static func create(token_size: float, data: PieceData = null, token_side: int = 0) -> PieceToken:
	var token := PieceToken.new()
	token.custom_minimum_size = Vector2.ONE * token_size
	token.size = Vector2.ONE * token_size
	token.side = token_side
	if data != null:
		token.show_piece_data(data)
	return token


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func show_piece_data(data: PieceData) -> void:
	piece_type = data.type
	piece_set = data.piece_set
	upgrade = data.upgrade
	has_shield = data.upgrade == "shield"
	tooltip_text = Ui.piece_tooltip(data)
	queue_redraw()


func show_match_piece(piece: MatchPiece) -> void:
	piece_type = piece.type
	side = piece.side
	piece_set = piece.data.piece_set
	upgrade = piece.data.upgrade
	has_shield = piece.shield_active
	burn_left = piece.burn_turns_left
	is_promoted = piece.is_promoted
	can_ignite = piece.burn_turns() > 0 and not piece.is_burning()
	is_in_check = false
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 * 0.86
	var centre := size / 2.0
	var is_fire := piece_set == "fire" and piece_type != "king"
	var disc := Palette.PIECE_IVORY if side == 0 else Palette.PIECE_EBONY
	var ink := Palette.PIECE_IVORY_INK if side == 0 else Palette.PIECE_EBONY_INK
	# Side is read by lightness first (ivory vs ebony disc), the rim only confirms it.
	var rim := Palette.PIECE_IVORY_INK.lerp(Palette.PIECE_IVORY, 0.45) if side == 0 else Palette.OXBLOOD
	if is_fire:
		rim = Palette.EMBER
	# The shadow stays on the board; everything else rises with `lift`.
	draw_circle(centre + Vector2(0, radius * 0.08 + lift * 0.1), radius - lift * 0.15, Color(0, 0, 0, 0.35 - minf(lift * 0.015, 0.15)))
	draw_set_transform(Vector2(0, -lift))
	draw_circle(centre, radius, disc)
	draw_arc(centre, radius * 0.8, 0, TAU, 48, Color(ink, 0.12), 1.0, true)
	draw_arc(centre, radius - 1.5, 0, TAU, 48, rim, maxf(2.0, radius * 0.08), true)
	if has_shield:
		draw_arc(centre, radius + 2.5, 0, TAU, 48, Palette.STEEL, 2.0, true)
	if can_ignite:
		draw_arc(centre, radius + 3.0, 0, TAU, 48, Color(Palette.EMBER, 0.45), 1.5, true)
	if burn_left > 0:
		_draw_burn_arc(centre, radius + 2.5)
	if is_in_check:
		_draw_check_ring(centre, radius)
	_draw_glyph(centre, radius, ink)
	if flash_color.a > 0.0:
		draw_circle(centre, radius, flash_color)
	_draw_badges(centre, radius)
	if is_in_check:
		_draw_check_tag(centre, radius)
	draw_set_transform(Vector2.ZERO)


func _draw_glyph(centre: Vector2, radius: float, ink: Color) -> void:
	var font := UiFonts.symbols()
	var font_size := int(radius * 1.45)
	var text := UiFonts.glyph(piece_type)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0 + radius * 0.02)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## One dashed segment per burn turn left (a third of the ring each), so the burn
## timer reads by shape next to solid brass marks, not by colour alone.
func _draw_burn_arc(centre: Vector2, radius: float) -> void:
	for turn in burn_left:
		var start := -PI / 2 + TAU * turn / 3.0
		for dash in 3:
			var from := start + (TAU / 3.0) * (dash / 3.0) + 0.06
			# A dark under-stroke keeps the dashes readable on light maple squares.
			draw_arc(centre, radius, from - 0.03, from + TAU / 9.0 - 0.15, 8, Color(Palette.WALNUT_DEEP, 0.7), 5.0, true)
			draw_arc(centre, radius, from, from + TAU / 9.0 - 0.18, 8, Palette.EMBER, 3.0, true)


## Check is never colour alone: a doubled ring plus a "CHECK" tag (see _draw_check_tag).
func _draw_check_ring(centre: Vector2, radius: float) -> void:
	draw_arc(centre, radius + 4.0, 0, TAU, 48, Palette.OXBLOOD, 3.0, true)
	# The outer ring stays inside the board square.
	draw_arc(centre, minf(radius + 8.0, size.x / BoardView.TOKEN_SHARE / 2.0 - 1.0), 0, TAU, 48, Color(Palette.OXBLOOD, 0.55), 1.5, true)


## A pill across the bottom of the token, inside its board square (so on the first
## rank it never reaches the board frame).
func _draw_check_tag(centre: Vector2, radius: float) -> void:
	var font := UiFonts.numbers()
	var font_size := maxi(int(radius * 0.36), 12)
	var text := "CHECK"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var square_bottom := centre.y + size.y / BoardView.TOKEN_SHARE / 2.0
	var height := font_size + 6.0
	var top := minf(centre.y + radius - font_size * 0.3, square_bottom - height - 1.0)
	var pill := Rect2(Vector2(centre.x - text_size.x / 2.0 - 5.0, top), Vector2(text_size.x + 10.0, height))
	draw_style_box(UiTheme.shared_box(Palette.OXBLOOD, Palette.WALNUT_DEEP, 3, 0), pill)
	draw_string(font, Vector2(pill.position.x + 5.0, pill.get_center().y + font.get_ascent(font_size) * 0.5 - 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.IVORY)


func _draw_badges(centre: Vector2, radius: float) -> void:
	var badge := maxf(radius * 0.36, 6.0)
	var offset := radius * 0.72
	if has_shield:
		_shield_badge(centre + Vector2(-offset, -offset), badge)
	if burn_left > 0:
		_badge(centre + Vector2(offset, -offset), badge * burn_pop, Palette.EMBER, str(burn_left))
	if is_promoted:
		_badge(centre + Vector2(-offset, offset), badge, Palette.BRASS, "♛")
	if upgrade == "range" or upgrade == "deploy":
		_badge(centre + Vector2(offset, offset), badge, Palette.BRASS, "+" if upgrade == "range" else "−")
	if is_locked:
		_badge(centre + Vector2(offset, offset), badge, Palette.IVORY_FAINT, "★")


func _badge(at: Vector2, radius: float, color: Color, text: String) -> void:
	draw_circle(at, radius + 1.5, Palette.WALNUT_DEEP)
	draw_circle(at, radius, color)
	var font := UiFonts.symbols() if text in ["♛", "★"] else UiFonts.numbers()
	var font_size := int(radius * 1.5)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := at + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.WALNUT_DEEP)


## A steel coin with a drawn heater-shield in it (no font needed).
func _shield_badge(at: Vector2, radius: float) -> void:
	draw_circle(at, radius + 1.5, Palette.WALNUT_DEEP)
	draw_circle(at, radius, Palette.STEEL)
	var w := radius * 0.55
	_shield_points.resize(5)
	_shield_points[0] = at + Vector2(-w, -w * 0.9)
	_shield_points[1] = at + Vector2(w, -w * 0.9)
	_shield_points[2] = at + Vector2(w, w * 0.1)
	_shield_points[3] = at + Vector2(0, w * 1.1)
	_shield_points[4] = at + Vector2(-w, w * 0.1)
	draw_colored_polygon(_shield_points, Palette.WALNUT_DEEP)
