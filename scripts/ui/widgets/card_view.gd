class_name CardView
extends Control
## A card drawn like a notation slip: cost coin, big glyph, name, upgrade ribbon.
## Lifts and grows slightly on hover; sinks (hollow cost coin, dim glyph) when
## unplayable; lifts further with a brass edge and glow when selected.
## Match extras: a key cap ("1".."5"), a deal-in from the deck side, a discard
## sweep, and drag-to-play (set drag_payload). Minis (create_mini) are the
## opponent's shown cards: glyph and cost only, the name is in the tooltip.

signal pressed
signal hovered(is_over: bool)
signal drag_started

const SIZE := Vector2(104, 146)
## The opponent's hand: shown cards (minis) and hidden ones (backs) share this size.
const MINI := Vector2(40, 56)
## Smallest text on a card (px at 1280x720).
const MIN_FONT := 12
## Cost coin, laid out for SIZE (scaled with the card): centre and outer radius.
const COIN_CENTRE := 17.0
const COIN_RADIUS := 12.5
## A mini's cost coin, as a share of the full card's: sized from the MIN_FONT
## figure it holds (outer radius 0.72 of it, about 8.6 px), never from the card.
const MINI_COIN := MIN_FONT * 0.72 / COIN_RADIUS
## Gap between a mini's coin and its card edge, so the coin sits inside the border.
const MINI_COIN_INSET := 2.0
## Upgrade ribbon: text padding on each side and its gap to the card's right edge.
const RIBBON_PAD := 4.0
const RIBBON_EDGE := 4.0

var card: CardData
var is_back: bool = false
var is_mini: bool = false
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
## Not interactive, but still shows its tooltip on hover (read-only lists).
var is_inspectable: bool = false
## Draws the cost coin. Turn it off on mini cards too small for a readable
## figure (the roster's opponent deck): the cost is then in the tooltip only.
var show_cost: bool = true:
	set(value):
		show_cost = value
		queue_redraw()
## Small key cap drawn in the bottom-left corner ("" = none).
var key_hint: String = ""
## Seconds to wait before dealing in from the deck side (-1 = no deal-in).
var deal_delay: float = -1.0
## Data handed to a drop target when the card is dragged (null = not draggable).
var drag_payload: Variant = null

var _is_hovered: bool = false
## Reused by every redraw (the lift tweens redraw each frame): no allocation per frame.
var _face: StyleBoxFlat = UiTheme.box(Palette.WALNUT_HIGH, Palette.RULE_STRONG, UiTheme.RADIUS, 0)
## Polygon points reused by every redraw (arrow heads, the Cheaper arrow, the rare lozenge, the Scout's eye).
var _triangle: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _lozenge: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _eye: PackedVector2Array = PackedVector2Array()
var _lift: float = 0.0:
	set(value):
		_lift = value
		queue_redraw()
## Turning over: 0 shows the back, 1 the face; the card narrows to edge-on at
## 0.5 and swaps sides there. Drawn, not scaled, so a container's layout (which
## resets `scale`) never cuts a flip short.
var flip: float = 1.0:
	set(value):
		flip = value
		queue_redraw()
## Extra draw offset while dealing in or sweeping out.
var _slide: Vector2 = Vector2.ZERO:
	set(value):
		_slide = value
		queue_redraw()


static func create(card_data: CardData, card_size: Vector2 = SIZE) -> CardView:
	var view := CardView.new()
	view.card = card_data
	view.custom_minimum_size = card_size
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.tooltip_text = Ui.card_tooltip(card_data)
	return view


## A read-only mini face (MINI): its name, cost and rules show in the tooltip.
static func create_mini(card_data: CardData) -> CardView:
	var view := create(card_data, MINI)
	view.is_mini = true
	view.is_interactive = false
	view.is_inspectable = true
	return view


static func create_back(card_size: Vector2 = MINI) -> CardView:
	var view := CardView.new()
	view.is_back = true
	view.is_interactive = false
	view.custom_minimum_size = card_size
	return view


func _ready() -> void:
	if deal_delay >= 0.0:
		_deal_in()
	if not is_interactive:
		mouse_filter = Control.MOUSE_FILTER_PASS if is_inspectable else Control.MOUSE_FILTER_IGNORE
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


## Slides in from the right (where the draw pile sits) and fades up, with a card_draw.
func _deal_in() -> void:
	modulate.a = 0.0
	_slide = Vector2(0, 0) if Motion.reduced() else Vector2(140, 24)
	var tween := Motion.tween(self)
	tween.tween_interval(deal_delay)
	tween.tween_callback(Sfx.play.bind("card_draw"))
	tween.set_parallel()
	tween.chain().tween_property(self, "modulate:a", 1.0, Motion.time("deal") * 0.6)
	tween.tween_property(self, "_slide", Vector2.ZERO, Motion.time("deal"))


## Discarded: drops away and fades (no slide with reduced motion), then leaves the
## layout so the cards still held re-centre in the hand.
func sweep_out() -> void:
	var tween := Motion.tween(self, "in").set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, Motion.time("sweep"))
	if not Motion.reduced():
		tween.tween_property(self, "_slide", Vector2(60, 40), Motion.time("sweep"))
	tween.chain().tween_callback(hide)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload == null or not is_interactive:
		return null
	drag_started.emit()
	var holder := Control.new()
	var ghost := CardView.create(card, size)
	ghost.is_interactive = false
	ghost.is_playable = is_playable
	ghost.position = -size / 2.0
	ghost.modulate.a = 0.85
	holder.add_child(ghost)
	set_drag_preview(holder)
	return drag_payload


func _gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _set_hover(value: bool) -> void:
	if value and not _is_hovered and is_playable:
		Sfx.play("card_hover")
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
	Motion.tween(self).tween_property(self, "_lift", target, Motion.time("quick"))


func _draw() -> void:
	var rect := Rect2(Vector2(0, -_lift), size)
	var turn := absf(2.0 * flip - 1.0)  # the drawn width, around the centre
	if is_back or flip < 0.5:
		_draw_back(Rect2(Vector2.ZERO, size), Transform2D(0.0, Vector2(turn, 1.0), 0.0, Vector2(size.x * (1.0 - turn) / 2.0, 0.0)))
		return
	# Grows a little with the lift (hover 2 %, selected 5 %), around the centre.
	var grow := 1.0 + _lift * 0.0036
	draw_set_transform(_slide + Vector2(size.x * (1.0 - grow * turn), size.y * (1.0 - grow)) / 2.0, 0.0, Vector2(grow * turn, grow))
	draw_style_box(_face_style(), rect)
	draw_rect(rect.grow(-5 * _scale()), Palette.RULE_SOFT, false, 1.0)
	if is_mini:
		# The glyph sits lower and larger: no name below it, the coin above it.
		_draw_glyph(rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.6), rect.size.x * 0.4)
		_draw_cost(rect.position + Vector2.ONE * (COIN_RADIUS * MINI_COIN + MINI_COIN_INSET), MINI_COIN)
		return
	# Same size and place on every card, ribbon or not (the ribbon may overlap its rim).
	_draw_glyph(rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.46), rect.size.x * 0.3)
	_draw_name(rect)
	if show_cost:
		_draw_cost(rect.position + Vector2.ONE * COIN_CENTRE * _scale(), _scale())
	_draw_ribbon(rect)
	if card.is_rare():
		_draw_rare_mark(rect.position + Vector2(rect.size.x / 2.0, rect.size.y - 7 * _scale()))
	if key_hint != "":
		_draw_key_cap(rect)


## A small key cap in the bottom-left corner: the keyboard shortcut for this card.
func _draw_key_cap(rect: Rect2) -> void:
	var font := UiFonts.numbers()
	var font_size := MIN_FONT
	var cap := Rect2(rect.position + Vector2(7, rect.size.y - 48), Vector2(17, 18))
	var ink := Palette.IVORY_SOFT if is_selected else Palette.IVORY_FAINT
	draw_style_box(UiTheme.shared_box(Palette.WALNUT_INSET, Palette.BRASS if is_selected else Palette.RULE_STRONG, 3, 0), cap)
	var text_width := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(cap.get_center().x - text_width / 2.0, cap.get_center().y + font.get_ascent(font_size) * 0.5 - 1.0),
		key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Playable: raised walnut face. Unplayable: sunk, flatter face (plus a hollow cost
## coin and a dimmed glyph), so the state never rests on opacity alone.
func _face_style() -> StyleBoxFlat:
	var border := Palette.RULE_STRONG if is_playable else Palette.RULE
	if is_selected:
		border = Palette.BRASS
	elif _is_hovered or is_highlighted:
		border = Palette.BRASS_DIM if is_playable else Palette.RULE_STRONG
	var style := _face
	style.bg_color = Palette.WALNUT_HIGH if is_playable else Palette.WALNUT_RAISED.darkened(0.1)
	style.border_color = border
	style.set_border_width_all(2 if is_selected else 1)
	style.shadow_color = Color(Palette.BRASS, 0.3) if is_selected else Color(0, 0, 0, 0.35 if _lift > 0.0 else 0.2)
	style.shadow_size = int(4 + _lift * 0.5)
	style.shadow_offset = Vector2(0, 2 + _lift * 0.3)
	return style


## Everything is laid out for SIZE and scaled for smaller or bigger cards.
func _scale() -> float:
	return size.x / SIZE.x


## The piece glyph on its inset disc; Move and Scout are drawn, not set in type.
func _draw_glyph(centre: Vector2, radius: float) -> void:
	var ink := Palette.IVORY_SOFT if is_playable else Palette.IVORY_MUTED
	draw_circle(centre, radius, Palette.WALNUT_INSET)
	draw_arc(centre, radius, 0, TAU, 40, Palette.RULE if is_playable else Palette.RULE_SOFT, 1.0, true)
	if card.type == "move":
		_draw_move_arrows(centre, radius * 0.17 / 0.3, ink)
		return
	if card.is_reveal():
		_draw_eye(centre, radius, ink)
		return
	var font := UiFonts.symbols()
	var font_size := int(radius * 1.4)
	var text := UiFonts.glyph(card.type)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_move_arrows(centre: Vector2, reach: float, color: Color) -> void:
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip := centre + direction * reach
		draw_line(centre, tip, color, 2.5, true)
		var side := direction.orthogonal() * reach * 0.3
		_set_triangle(tip + direction * reach * 0.25, tip + side, tip - side)
		draw_colored_polygon(_triangle, color)
	draw_circle(centre, 3.5, color)


## The Scout's eye: an almond outline, the iris with its pupil and a glint, and
## three lashes rising off the upper lid ("look").
func _draw_eye(centre: Vector2, radius: float, color: Color) -> void:
	var half_width := radius * 0.66
	var lid := radius * 0.4
	var steps := 12
	_eye.resize(steps * 2 + 1)
	for i in steps + 1:
		var t := -1.0 + 2.0 * i / steps
		var bulge := lid * (1.0 - t * t)
		_eye[i] = centre + Vector2(t * half_width, -bulge)
		if i < steps:
			_eye[steps * 2 - i] = centre + Vector2(t * half_width, bulge)
	_eye[steps * 2] = _eye[0]
	var line := maxf(radius * 0.08, 1.5)
	draw_polyline(_eye, color, line, true)
	draw_circle(centre, lid * 0.78, color)
	draw_circle(centre, lid * 0.34, Palette.WALNUT_INSET)
	draw_circle(centre + Vector2(lid * 0.3, -lid * 0.3), lid * 0.14, color)
	for t: float in [-0.55, 0.0, 0.55]:
		var root := centre + Vector2(t * half_width, -lid * (1.0 - t * t) - line)
		draw_line(root, root + Vector2.from_angle(-PI / 2.0 + t * 0.9) * radius * 0.24, color, line, true)


func _draw_name(rect: Rect2) -> void:
	var font := UiFonts.serif_bold()
	var font_size := maxi(int(15 * _scale()), MIN_FONT)
	var text := card.display_name()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, rect.position + Vector2((rect.size.x - width) / 2.0, rect.size.y - 16 * _scale()), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.IVORY if is_playable else Palette.IVORY_FAINT)


## A brass coin centred on `at` (laid out for SIZE, scaled by `scale_factor`) when
## affordable and playable; a hollow coin when not.
func _draw_cost(at: Vector2, scale_factor: float) -> void:
	var coin := Palette.FELT if card.upgrade == "cheaper" else Palette.BRASS
	var ink := Palette.BRASS_INK
	draw_circle(at, COIN_RADIUS * scale_factor, Palette.WALNUT_DEEP)
	if is_playable:
		draw_circle(at, 11 * scale_factor, coin)
	else:
		draw_arc(at, 10 * scale_factor, 0, TAU, 32, Color(coin, 0.6), 2.0 * scale_factor, true)
		ink = Palette.IVORY_FAINT
	var font := UiFonts.numbers()
	var font_size := maxi(int(15 * scale_factor), MIN_FONT)
	var text := str(card.cost())
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if card.upgrade == "cheaper":
		_draw_cheaper_arrow(at + Vector2(10, 10) * scale_factor, 5.0 * maxf(scale_factor, 0.8))


## "Cost lowered" as a shape, not only the felt colour: a down arrow on a dark tab.
func _draw_cheaper_arrow(at: Vector2, half: float) -> void:
	draw_circle(at, half + 2.0, Palette.WALNUT_DEEP)
	_set_triangle(at + Vector2(-half * 0.8, -half * 0.35), at + Vector2(half * 0.8, -half * 0.35), at + Vector2(0, half * 0.75))
	draw_colored_polygon(_triangle, Palette.IVORY if is_playable else Palette.IVORY_FAINT)
	draw_line(at + Vector2(0, -half * 0.9), at + Vector2(0, -half * 0.2), Palette.IVORY if is_playable else Palette.IVORY_FAINT, maxf(half * 0.35, 1.5))


func _draw_ribbon(rect: Rect2) -> void:
	var ribbon := _ribbon_rect(rect)
	if not ribbon.has_area():
		return
	var font := UiFonts.numbers()
	var font_size := _ribbon_font_size()
	draw_style_box(UiTheme.shared_box(Palette.BRASS if is_playable else Color(Palette.BRASS, 0.45), Color.TRANSPARENT, 3, 0), ribbon)
	draw_string(font, Vector2(ribbon.position.x + RIBBON_PAD, ribbon.get_center().y + font.get_ascent(font_size) * 0.4), _ribbon_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.BRASS_INK)


## Where the upgrade ribbon goes (an empty rect without an upgrade): top right,
## beside the cost coin; on a card too narrow for that, under the coin (left
## aligned with it, over the glyph circle's rim). The glyph never shrinks for it.
func _ribbon_rect(rect: Rect2) -> Rect2:
	if card.upgrade == "":
		return Rect2()
	var scale_factor := _scale()
	var font_size := _ribbon_font_size()
	var width := UiFonts.numbers().get_string_size(_ribbon_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + RIBBON_PAD * 2.0
	var ribbon := Rect2(rect.position + Vector2(rect.size.x - width - RIBBON_EDGE * scale_factor, 9 * scale_factor), Vector2(width, font_size + 5))
	var coin_right := (COIN_CENTRE + COIN_RADIUS + 1.0) * scale_factor if show_cost else 0.0
	if ribbon.position.x < rect.position.x + coin_right:
		ribbon.position = rect.position + Vector2(RIBBON_EDGE, COIN_CENTRE + COIN_RADIUS + 2.0) * scale_factor
	return ribbon


func _ribbon_text() -> String:
	return Ui.upgrade_name("card", card.upgrade).to_upper()


func _ribbon_font_size() -> int:
	return maxi(int(10 * _scale()), MIN_FONT)


## Rare cards carry a small brass lozenge under the name.
func _draw_rare_mark(at: Vector2) -> void:
	var r := 3.5 * _scale()
	var color := Palette.BRASS if is_playable else Color(Palette.BRASS, 0.45)
	_lozenge[0] = at + Vector2(0, -r)
	_lozenge[1] = at + Vector2(r, 0)
	_lozenge[2] = at + Vector2(0, r)
	_lozenge[3] = at + Vector2(-r, 0)
	draw_colored_polygon(_lozenge, color)


func _set_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	_triangle[0] = a
	_triangle[1] = b
	_triangle[2] = c


## The opponent's hidden cards: the same walnut face and rule as a card front,
## with an oxblood field, a brass inner rule and a brass lozenge (the back's crest).
## `base` places it (narrowed while a face turns over).
func _draw_back(rect: Rect2, base: Transform2D) -> void:
	draw_set_transform_matrix(base)
	draw_style_box(UiTheme.shared_box(Palette.WALNUT_HIGH, Palette.RULE_STRONG, 3, 0), rect)
	var field := rect.grow(-2.0)
	draw_style_box(UiTheme.shared_box(Palette.OXBLOOD.darkened(0.45), Color.TRANSPARENT, 2, 0), field)
	draw_rect(field.grow(-2.0), Palette.BRASS_DIM, false, 1.0)
	var crest := minf(field.size.x, field.size.y) * 0.16
	draw_set_transform_matrix(base * Transform2D(PI / 4.0, field.get_center()))
	draw_rect(Rect2(-crest, -crest, crest * 2.0, crest * 2.0), Palette.BRASS)
	draw_set_transform(Vector2.ZERO)
