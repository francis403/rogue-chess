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
	var rim := Palette.PIECE_IVORY_INK.lerp(Palette.PIECE_IVORY, 0.45) if side == 0 else Palette.OXBLOOD
	if is_fire:
		rim = Palette.EMBER
	draw_circle(centre + Vector2(0, radius * 0.08), radius, Color(0, 0, 0, 0.35))
	draw_circle(centre, radius, disc)
	draw_arc(centre, radius - 1.5, 0, TAU, 48, rim, maxf(2.0, radius * 0.08), true)
	if is_in_check:
		draw_arc(centre, radius + 3.5, 0, TAU, 48, Palette.OXBLOOD, 4.0, true)
	if can_ignite:
		draw_arc(centre, radius + 3.0, 0, TAU, 48, Color(Palette.EMBER, 0.45), 1.5, true)
	if burn_left > 0:
		draw_arc(centre, radius + 2.5, -PI / 2, -PI / 2 + TAU * burn_left / 3.0, 32, Palette.EMBER, 3.0, true)
	_draw_glyph(centre, radius, ink)
	if flash_color.a > 0.0:
		draw_circle(centre, radius, flash_color)
	_draw_badges(centre, radius)


func _draw_glyph(centre: Vector2, radius: float, ink: Color) -> void:
	var font := UiFonts.symbols()
	var font_size := int(radius * 1.45)
	var text := UiFonts.glyph(piece_type)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0 + radius * 0.02)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_badges(centre: Vector2, radius: float) -> void:
	var badge := maxf(radius * 0.36, 6.0)
	var offset := radius * 0.72
	if has_shield:
		_badge(centre + Vector2(-offset, -offset), badge, Palette.STEEL, "◆")
	if burn_left > 0:
		_badge(centre + Vector2(offset, -offset), badge, Palette.EMBER, str(burn_left))
	if is_promoted:
		_badge(centre + Vector2(-offset, offset), badge, Palette.BRASS, "♛")
	if upgrade == "range" or upgrade == "deploy":
		_badge(centre + Vector2(offset, offset), badge, Palette.BRASS, "+" if upgrade == "range" else "−")
	if is_locked:
		_badge(centre + Vector2(offset, offset), badge, Palette.IVORY_FAINT, "★")


func _badge(at: Vector2, radius: float, color: Color, text: String) -> void:
	draw_circle(at, radius + 1.5, Palette.WALNUT_DEEP)
	draw_circle(at, radius, color)
	var font := UiFonts.symbols() if text in ["◆", "♛", "★"] else get_theme_default_font()
	var font_size := int(radius * 1.5)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := at + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.WALNUT_DEEP)
