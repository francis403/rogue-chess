class_name CardView
extends Control
## A card drawn like a notation slip: cost coin, big glyph, name, upgrade ribbon.
## Lifts on hover; dims when unplayable; lifts further when selected.

signal pressed
signal hovered(is_over: bool)

const SIZE := Vector2(104, 146)
const SMALL_BACK := Vector2(22, 31)

var card: CardData
var is_back: bool = false
var is_playable: bool = true:
	set(value):
		is_playable = value
		queue_redraw()
var is_selected: bool = false:
	set(value):
		is_selected = value
		_update_lift()
var is_highlighted: bool = false:
	set(value):
		is_highlighted = value
		_update_lift()
var is_interactive: bool = true

var _is_hovered: bool = false
var _lift: float = 0.0:
	set(value):
		_lift = value
		queue_redraw()


static func create(card_data: CardData, card_size: Vector2 = SIZE) -> CardView:
	var view := CardView.new()
	view.card = card_data
	view.custom_minimum_size = card_size
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.tooltip_text = Ui.card_tooltip(card_data)
	return view


static func create_back(card_size: Vector2 = SMALL_BACK) -> CardView:
	var view := CardView.new()
	view.is_back = true
	view.is_interactive = false
	view.custom_minimum_size = card_size
	return view


func _ready() -> void:
	if not is_interactive:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _set_hover(value: bool) -> void:
	_is_hovered = value
	_update_lift()
	hovered.emit(value)


func _update_lift() -> void:
	var target := 0.0
	if is_selected:
		target = 14.0
	elif _is_hovered or is_highlighted:
		target = 6.0
	if not is_inside_tree():
		_lift = target
		return
	create_tween().tween_property(self, "_lift", target, Ui.FAST).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var rect := Rect2(Vector2(0, -_lift), size)
	if is_back:
		_draw_back(Rect2(Vector2.ZERO, size))
		return
	var alpha := 1.0 if is_playable else 0.42
	var border := Palette.RULE_STRONG
	if is_selected:
		border = Palette.BRASS
	elif _is_hovered or is_highlighted:
		border = Palette.BRASS_DIM
	var style := UiTheme.box(Palette.WALNUT_HIGH, border, UiTheme.RADIUS, 0, 2 if is_selected else 1)
	style.shadow_color = Color(0, 0, 0, 0.35 if _lift > 0.0 else 0.2)
	style.shadow_size = int(4 + _lift * 0.5)
	style.shadow_offset = Vector2(0, 2 + _lift * 0.3)
	draw_set_transform(Vector2.ZERO)
	draw_style_box(style, rect)
	var ink := Palette.IVORY
	ink.a = alpha
	_draw_glyph(rect, alpha)
	_draw_name(rect, ink)
	_draw_cost(rect, alpha)
	_draw_ribbon(rect, alpha)
	if card.is_rare():
		draw_circle(rect.position + Vector2(rect.size.x / 2.0, rect.size.y - 7 * _scale()), 2.5 * _scale(), Color(Palette.BRASS, alpha))


## Everything is laid out for SIZE and scaled for smaller or bigger cards.
func _scale() -> float:
	return size.x / SIZE.x


func _draw_glyph(rect: Rect2, alpha: float) -> void:
	var centre := rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.46)
	draw_circle(centre, rect.size.x * 0.3, Color(Palette.WALNUT_INSET, alpha))
	if card.type == "move":
		_draw_move_arrows(centre, rect.size.x * 0.17, Color(Palette.IVORY_SOFT, alpha))
		return
	var font := UiFonts.symbols()
	var font_size := int(rect.size.x * 0.42)
	var text := UiFonts.glyph(card.type)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.IVORY_SOFT, alpha))


func _draw_move_arrows(centre: Vector2, reach: float, color: Color) -> void:
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip := centre + direction * reach
		draw_line(centre, tip, color, 2.5, true)
		var side := direction.orthogonal() * reach * 0.3
		draw_colored_polygon(PackedVector2Array([tip + direction * reach * 0.25, tip + side, tip - side]), color)
	draw_circle(centre, 3.5, color)


func _draw_name(rect: Rect2, ink: Color) -> void:
	var font := UiFonts.serif_bold()
	var font_size := maxi(int(15 * _scale()), 11)
	var text := card.display_name()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, rect.position + Vector2((rect.size.x - width) / 2.0, rect.size.y - 16 * _scale()), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_cost(rect: Rect2, alpha: float) -> void:
	var scale_factor := _scale()
	var at := rect.position + Vector2(17, 17) * scale_factor
	var is_cheaper := card.upgrade == "cheaper"
	draw_circle(at, 12.5 * scale_factor, Color(Palette.WALNUT_DEEP, alpha))
	draw_circle(at, 11 * scale_factor, Color(Palette.FELT if is_cheaper else Palette.BRASS, alpha))
	var font := UiFonts.numbers()
	var font_size := int(15 * scale_factor)
	var text := str(card.cost())
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.BRASS_INK, alpha))


func _draw_ribbon(rect: Rect2, alpha: float) -> void:
	if card.upgrade == "":
		return
	var text := Ui.upgrade_name("card", card.upgrade).to_upper()
	var font := get_theme_default_font()
	var scale_factor := _scale()
	var font_size := maxi(int(10 * scale_factor), 7)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10 * scale_factor
	var ribbon := Rect2(rect.position + Vector2(rect.size.x - width - 6 * scale_factor, 8 * scale_factor), Vector2(width, 16 * scale_factor))
	draw_style_box(UiTheme.box(Color(Palette.BRASS, alpha), Color.TRANSPARENT, 3, 0), ribbon)
	draw_string(font, ribbon.position + Vector2(5 * scale_factor, 12 * scale_factor), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.BRASS_INK, alpha))


func _draw_back(rect: Rect2) -> void:
	draw_style_box(UiTheme.box(Palette.OXBLOOD.darkened(0.45), Palette.OXBLOOD.darkened(0.1), 3, 0), rect)
	draw_rect(rect.grow(-4), Color(Palette.OXBLOOD, 0.35), false, 1.0)
