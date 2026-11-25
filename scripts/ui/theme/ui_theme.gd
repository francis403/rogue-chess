class_name UiTheme
extends RefCounted
## Builds the one Theme every screen inherits from the main scene.
## Type scale: 12 caption, 14 body, 16 strong, 20 h2, 28 h1, 52 title, 76 display.
## Spacing: Metrics (base unit 4). Every control state lives here: normal, hover,
## pressed, disabled and a solid brass focus ring drawn outside the control.

const CAPTION := 12
const BODY := 14
const STRONG := 16
const H2 := 20
const H1 := 28
const TITLE := 52
const DISPLAY := 76

## "Large text" (setting): Body, Caption, Eyebrow, button and tooltip text one
## step (+2 px) larger. Headings, figures and the match board / cards keep their size.
const LARGE_TEXT_STEP := 2

const RADIUS_SMALL := 4
const RADIUS := 6
const RADIUS_LARGE := 10

static var _shared_boxes: Dictionary = {}


static func build(large_text: bool = false) -> Theme:
	var step := LARGE_TEXT_STEP if large_text else 0
	var theme := Theme.new()
	theme.default_font_size = BODY + step
	_labels(theme, step)
	_buttons(theme, step)
	_panels(theme)
	_scroll(theme)
	_tooltip(theme, step)
	_controls(theme)
	return theme


static func box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = RADIUS, padding: int = 16, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style


## The same box as box(), built once per argument set and shared: for _draw code,
## which runs every frame while something animates. Never modify the result.
static func shared_box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = RADIUS, padding: int = 16, border_width: int = 1) -> StyleBoxFlat:
	var key := [bg, border, radius, padding, border_width]
	if not _shared_boxes.has(key):
		_shared_boxes[key] = box(bg, border, radius, padding, border_width)
	return _shared_boxes[key]


static func _labels(theme: Theme, step: int) -> void:
	theme.set_color("font_color", "Label", Palette.IVORY)
	theme.set_font_size("font_size", "Label", BODY + step)
	_label_variation(theme, "Title", UiFonts.serif_bold(), TITLE, Palette.IVORY)
	_label_variation(theme, "H1", UiFonts.serif_bold(), H1, Palette.IVORY)
	_label_variation(theme, "H2", UiFonts.serif_bold(), H2, Palette.IVORY)
	_label_variation(theme, "Strong", null, STRONG, Palette.IVORY)
	_label_variation(theme, "Stat", UiFonts.numbers(), H2, Palette.IVORY)
	_label_variation(theme, "Body", null, BODY + step, Palette.IVORY_SOFT)
	_label_variation(theme, "Caption", null, CAPTION + step, Palette.IVORY_FAINT)
	_label_variation(theme, "Eyebrow", null, CAPTION + step, Palette.BRASS)
	_label_variation(theme, "Display", UiFonts.serif_bold(), DISPLAY, Palette.IVORY)
	_label_variation(theme, "StatLarge", UiFonts.numbers(), H1, Palette.IVORY)


static func _label_variation(theme: Theme, variation: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	if font != null:
		theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)


static func _buttons(theme: Theme, step: int) -> void:
	_button_styles(theme, "Button", Palette.WALNUT_HIGH, Palette.IVORY, Palette.RULE_STRONG)
	theme.set_type_variation("PrimaryButton", "Button")
	_button_styles(theme, "PrimaryButton", Palette.BRASS, Palette.BRASS_INK, Palette.BRASS.lightened(0.2))
	theme.set_type_variation("QuietButton", "Button")
	_button_styles(theme, "QuietButton", Palette.WALNUT_RAISED, Palette.IVORY_SOFT, Palette.RULE)
	for variation in ["Button", "PrimaryButton", "QuietButton"]:
		theme.set_font_size("font_size", variation, BODY + step)
		theme.set_constant("h_separation", variation, Metrics.S)


static func _button_styles(theme: Theme, variation: String, bg: Color, ink: Color, border: Color) -> void:
	var normal := box(bg, border, RADIUS_SMALL, 0)
	normal.content_margin_left = Metrics.L
	normal.content_margin_right = Metrics.L
	normal.content_margin_top = Metrics.S
	normal.content_margin_bottom = Metrics.S
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.1)
	hover.border_color = Palette.BRASS
	# Pressed sinks: darker, and the label drops 1 px.
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.18)
	pressed.border_color = Palette.BRASS
	pressed.content_margin_top = Metrics.S + 1
	pressed.content_margin_bottom = Metrics.S - 1
	# Disabled is flat: no fill colour, a faint rule, muted ink (2.1:1 is allowed for disabled).
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.WALNUT_RAISED.darkened(0.15)
	disabled.border_color = Palette.RULE_SOFT
	theme.set_stylebox("normal", variation, normal)
	theme.set_stylebox("hover", variation, hover)
	theme.set_stylebox("pressed", variation, pressed)
	theme.set_stylebox("hover_pressed", variation, pressed)
	theme.set_stylebox("disabled", variation, disabled)
	theme.set_stylebox("focus", variation, focus_ring(RADIUS_SMALL))
	theme.set_color("font_color", variation, ink)
	theme.set_color("font_hover_color", variation, ink)
	theme.set_color("font_pressed_color", variation, ink)
	theme.set_color("font_focus_color", variation, ink)
	theme.set_color("font_hover_pressed_color", variation, ink)
	theme.set_color("font_disabled_color", variation, Palette.IVORY_MUTED)


## The keyboard focus ring: 2 px solid brass, 3 px outside the control, no fill.
static func focus_ring(radius: int = RADIUS_SMALL) -> StyleBoxFlat:
	var ring := box(Color.TRANSPARENT, Palette.FOCUS, radius + 3, 0, 2)
	ring.draw_center = false
	ring.set_expand_margin_all(3)
	return ring


static func _panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", box(Palette.WALNUT, Palette.RULE, RADIUS, 16))
	theme.set_type_variation("RaisedPanel", "PanelContainer")
	theme.set_stylebox("panel", "RaisedPanel", box(Palette.WALNUT_RAISED, Palette.RULE, RADIUS, 16))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", box(Palette.WALNUT_INSET, Palette.RULE_SOFT, RADIUS_SMALL, 8))
	theme.set_type_variation("ModalPanel", "PanelContainer")
	theme.set_stylebox("panel", "ModalPanel", box(Palette.WALNUT_RAISED, Palette.RULE_STRONG, RADIUS_LARGE, 24))
	theme.set_type_variation("BarPanel", "PanelContainer")
	var bar := box(Palette.WALNUT_DEEP, Palette.RULE_SOFT, 0, 0)
	bar.border_width_top = 0
	bar.border_width_left = 0
	bar.border_width_right = 0
	bar.border_width_bottom = 1
	bar.content_margin_left = 16
	bar.content_margin_right = 16
	theme.set_stylebox("panel", "BarPanel", bar)
	theme.set_type_variation("ChipPanel", "PanelContainer")
	var chip := box(Palette.WALNUT_HIGH, Palette.RULE, RADIUS_SMALL, 0)
	chip.content_margin_left = 8
	chip.content_margin_right = 8
	chip.content_margin_top = 2
	chip.content_margin_bottom = 2
	theme.set_stylebox("panel", "ChipPanel", chip)


static func _scroll(theme: Theme) -> void:
	var grabber := box(Palette.WALNUT_HIGH.lightened(0.1), Color.TRANSPARENT, 3, 0)
	var grabber_hover := box(Palette.BRASS_DIM, Color.TRANSPARENT, 3, 0)
	var track := box(Color(0, 0, 0, 0.0), Color.TRANSPARENT, 3, 0)
	track.content_margin_left = 3
	track.content_margin_right = 3
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, grabber_hover)
		theme.set_stylebox("grabber_pressed", bar, grabber_hover)


static func _tooltip(theme: Theme, step: int) -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(Palette.WALNUT_HIGH, Palette.RULE_STRONG, RADIUS_SMALL, 8))
	theme.set_color("font_color", "TooltipLabel", Palette.IVORY)
	theme.set_font_size("font_size", "TooltipLabel", CAPTION + 1 + step)


## Sliders, check boxes, option menus: styled now so later settings screens match.
static func _controls(theme: Theme) -> void:
	var track := box(Palette.WALNUT_INSET, Palette.RULE, 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", box(Palette.BRASS_DIM, Color.TRANSPARENT, 3, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.BRASS, Color.TRANSPARENT, 3, 0))
	theme.set_stylebox("focus", "HSlider", focus_ring())
	# Toggle rows: "on" is said by the drawn switch, so the row keeps its normal
	# face when pressed (the Button's brass pressed border would read as focus).
	var row := box(Palette.WALNUT_HIGH, Palette.RULE_STRONG, RADIUS_SMALL, 0)
	row.content_margin_left = Metrics.L
	row.content_margin_right = Metrics.L
	row.content_margin_top = Metrics.S
	row.content_margin_bottom = Metrics.S
	var row_hover := row.duplicate() as StyleBoxFlat
	row_hover.bg_color = Palette.WALNUT_HIGH.lightened(0.1)
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", row)
	for state in ["hover", "hover_pressed"]:
		theme.set_stylebox(state, "CheckButton", row_hover)
	for type in ["CheckBox", "CheckButton", "OptionButton"]:
		theme.set_stylebox("focus", type, focus_ring())
		theme.set_color("font_color", type, Palette.IVORY_SOFT)
		theme.set_color("font_hover_color", type, Palette.IVORY)
		theme.set_color("font_pressed_color", type, Palette.IVORY)
	theme.set_stylebox("panel", "PopupMenu", box(Palette.WALNUT_HIGH, Palette.RULE_STRONG, RADIUS_SMALL, Metrics.S))
	theme.set_stylebox("hover", "PopupMenu", box(Palette.BRASS_DIM, Color.TRANSPARENT, RADIUS_SMALL, 0))
	theme.set_color("font_color", "PopupMenu", Palette.IVORY_SOFT)
	theme.set_color("font_hover_color", "PopupMenu", Palette.IVORY)
