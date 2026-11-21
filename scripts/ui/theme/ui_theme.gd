class_name UiTheme
extends RefCounted
## Builds the one Theme every screen inherits from the main scene.
## Type scale: 12 caption, 14 body, 16 strong, 20 h2, 28 h1, 52 title. Spacing unit 4.

const CAPTION := 12
const BODY := 14
const STRONG := 16
const H2 := 20
const H1 := 28
const TITLE := 52

const RADIUS_SMALL := 4
const RADIUS := 6
const RADIUS_LARGE := 10


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = BODY
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_scroll(theme)
	_tooltip(theme)
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


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.IVORY)
	theme.set_font_size("font_size", "Label", BODY)
	_label_variation(theme, "Title", UiFonts.serif_bold(), TITLE, Palette.IVORY)
	_label_variation(theme, "H1", UiFonts.serif_bold(), H1, Palette.IVORY)
	_label_variation(theme, "H2", UiFonts.serif_bold(), H2, Palette.IVORY)
	_label_variation(theme, "Strong", null, STRONG, Palette.IVORY)
	_label_variation(theme, "Stat", UiFonts.numbers(), H2, Palette.IVORY)
	_label_variation(theme, "Body", null, BODY, Palette.IVORY_SOFT)
	_label_variation(theme, "Caption", null, CAPTION, Palette.IVORY_FAINT)
	_label_variation(theme, "Eyebrow", null, CAPTION, Palette.BRASS)


static func _label_variation(theme: Theme, variation: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	if font != null:
		theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)


static func _buttons(theme: Theme) -> void:
	_button_styles(theme, "Button", Palette.WALNUT_HIGH, Palette.IVORY, Palette.RULE)
	theme.set_type_variation("PrimaryButton", "Button")
	_button_styles(theme, "PrimaryButton", Palette.BRASS, Palette.BRASS_INK, Palette.BRASS)
	theme.set_type_variation("QuietButton", "Button")
	_button_styles(theme, "QuietButton", Palette.WALNUT_RAISED, Palette.IVORY_SOFT, Palette.RULE_SOFT)
	for variation in ["Button", "PrimaryButton", "QuietButton"]:
		theme.set_font_size("font_size", variation, BODY)
		theme.set_constant("h_separation", variation, 8)


static func _button_styles(theme: Theme, variation: String, bg: Color, ink: Color, border: Color) -> void:
	var normal := box(bg, border, RADIUS_SMALL, 0)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08)
	hover.border_color = Palette.BRASS
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15)
	pressed.border_color = Palette.BRASS
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.WALNUT_RAISED
	disabled.border_color = Palette.RULE_SOFT
	var focus := normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = Palette.BRASS_DIM
	focus.set_border_width_all(2)
	theme.set_stylebox("normal", variation, normal)
	theme.set_stylebox("hover", variation, hover)
	theme.set_stylebox("pressed", variation, pressed)
	theme.set_stylebox("hover_pressed", variation, pressed)
	theme.set_stylebox("disabled", variation, disabled)
	theme.set_stylebox("focus", variation, focus)
	theme.set_color("font_color", variation, ink)
	theme.set_color("font_hover_color", variation, ink)
	theme.set_color("font_pressed_color", variation, ink)
	theme.set_color("font_focus_color", variation, ink)
	theme.set_color("font_hover_pressed_color", variation, ink)
	theme.set_color("font_disabled_color", variation, Palette.IVORY_MUTED)


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


static func _tooltip(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(Palette.WALNUT_HIGH, Palette.RULE_STRONG, RADIUS_SMALL, 8))
	theme.set_color("font_color", "TooltipLabel", Palette.IVORY)
	theme.set_font_size("font_size", "TooltipLabel", CAPTION + 1)
