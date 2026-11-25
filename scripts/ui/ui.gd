class_name Ui
extends RefCounted
## Small builders shared by every screen (feedback tweens are in Feel).

## Share of a taller window's extra height a frame puts above its header.
const FRAME_TOP_SHARE := 0.75
## How much more of a frame body's free height goes above a centred block than below.
const BLOCK_ABOVE_RATIO := 1.5


static func label(text: String, variation: String = "", color: Variant = null) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	if color is Color:
		node.add_theme_color_override("font_color", color)
	return node


static func wrapped(text: String, variation: String = "Body", width: float = 0.0) -> Label:
	var node := label(text, variation)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		node.custom_minimum_size.x = width
	return node


static func button(text: String, variation: String = "Button") -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.focus_mode = Control.FOCUS_NONE
	return node


## Keeps `node` as wide as the widest of `texts` in its current font (all the
## states its label can take), so a state change never reflows the row it sits
## in. Re-measured when the theme changes (Large text).
static func fix_width(node: Button, texts: Array[String]) -> void:
	var fit := func() -> void:
		var font := node.get_theme_font("font")
		var font_size := node.get_theme_font_size("font_size")
		var widest := 0.0
		for text in texts:
			widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		node.custom_minimum_size.x = ceilf(widest + node.get_theme_stylebox("normal").get_minimum_size().x)
	node.ready.connect(fit)
	node.theme_changed.connect(fit)


## Connects a one-shot button: it disables itself on the first press, so a
## double click can't run the action twice.
static func connect_once(node: Button, action: Callable) -> void:
	node.pressed.connect(func() -> void:
		if node.disabled:
			return
		node.disabled = true
		action.call())


static func vbox(separation: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func panel(variation: String = "") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	return node


static func chip(text: String, color: Color = Palette.IVORY_SOFT, tooltip: String = "") -> PanelContainer:
	var node := panel("ChipPanel")
	var text_label := label(text, "Caption", color)
	node.add_child(text_label)
	node.tooltip_text = tooltip
	node.mouse_filter = Control.MOUSE_FILTER_PASS if tooltip != "" else Control.MOUSE_FILTER_IGNORE
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func centered(child: Control) -> CenterContainer:
	var node := CenterContainer.new()
	node.add_child(child)
	return node


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## True if this opponent is the one on the map's boss node (config/map.json).
static func is_boss(opponent_id: String) -> bool:
	for map_node: Dictionary in GameConfig.data("map")["nodes"].values():
		if map_node["type"] == "boss" and map_node.get("opponent", "") == opponent_id:
			return true
	return false


static func piece_name(piece_type: String) -> String:
	return piece_type.capitalize()


static func upgrade_name(kind: String, upgrade_id: String) -> String:
	if upgrade_id == "":
		return ""
	return String(GameConfig.data("upgrades")[kind][upgrade_id]["name"])


static func upgrade_desc(kind: String, upgrade_id: String) -> String:
	if upgrade_id == "":
		return ""
	return String(GameConfig.data("upgrades")[kind][upgrade_id]["desc"])


static func artifact_name(artifact_id: String) -> String:
	return String(GameConfig.data("artifacts")["artifacts"][artifact_id]["name"])


static func artifact_desc(artifact_id: String) -> String:
	return String(GameConfig.data("artifacts")["artifacts"][artifact_id]["desc"])


static func piece_set_name(set_id: String) -> String:
	return String(GameConfig.data("piece_sets")["sets"][set_id]["name"])


static func artifact_chips(artifact_ids: Array, empty_text: String = "No artifacts") -> HBoxContainer:
	var row := hbox(4)
	if artifact_ids.is_empty():
		row.add_child(label(empty_text, "Caption", Palette.IVORY_FAINT))
	for artifact_id: String in artifact_ids:
		row.add_child(chip(artifact_name(artifact_id), Palette.BRASS, artifact_desc(artifact_id)))
	return row


static func piece_tooltip(data: PieceData) -> String:
	var text := "%s · deploy %d · worth %d" % [piece_name(data.type), data.deploy_cost(), data.value()]
	if data.piece_set != "standard":
		text = "%s %s" % [piece_set_name(data.piece_set), text]
	if data.upgrade != "":
		text += "\n%s: %s" % [upgrade_name("piece", data.upgrade), upgrade_desc("piece", data.upgrade)]
	return text


static func card_tooltip(card: CardData) -> String:
	var what := "Move one %s" % card.type
	if card.type == "move":
		what = "Move any one piece (the only way to move your king)"
	elif card.is_reveal():
		what = "%s. Plays at once: no piece moves" % (String(GameConfig.data("cards")[card.type]["desc"]) % card.reveal_amount())
	var text := "%s · cost %d\n%s" % [card.display_name(), card.cost(), what]
	if card.upgrade != "":
		text += "\n%s: %s" % [upgrade_name("card", card.upgrade), upgrade_desc("card", card.upgrade)]
	return text


## The standard screen layout: margins, an eyebrow + title + subtitle header, and
## the returned body box that fills the rest.
static func frame(screen: Control, eyebrow: String, title: String, subtitle: String = "") -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Metrics.SCREEN_X)
	# Most of a taller window's extra height goes above the header: the content
	# block below sits lower, so the bottom doesn't end in a wide empty band.
	centre_tall(margin, FRAME_TOP_SHARE)
	screen.add_child(margin)
	var column := vbox(Metrics.XL)
	margin.add_child(column)
	var header := vbox(Metrics.XS)
	header.add_child(label(eyebrow.to_upper(), "Eyebrow"))
	header.add_child(label(title, "H1"))
	if subtitle != "":
		header.add_child(label(subtitle, "Body"))
	column.add_child(header)
	var body := vbox(Metrics.L)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	return body


## Top and bottom margins of a screen: Metrics.SCREEN_Y, plus whatever the canvas
## is taller than the 720 base (16:10 windows), `top_share` of it above and the
## rest below, so menu screens keep their 16:9 layout instead of leaving a band
## of empty space at the bottom.
static func centre_tall(margin: MarginContainer, top_share: float = 0.5) -> void:
	var fit := func() -> void:
		var extra := maxi(int(margin.get_viewport_rect().size.y) - Metrics.BASE_HEIGHT, 0)
		var top := roundi(extra * top_share)
		margin.add_theme_constant_override("margin_top", Metrics.SCREEN_Y + top)
		margin.add_theme_constant_override("margin_bottom", Metrics.SCREEN_Y + extra - top)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Metrics.SCREEN_Y)
	margin.resized.connect(fit)


## A fixed vertical gap (spacing scale only).
static func gap(height: int = Metrics.L) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A thin horizontal rule that fills its row.
static func rule(color: Color = Palette.RULE) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.custom_minimum_size.y = 1
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A block centred vertically in a frame body (a little more space above than
## below, BLOCK_ABOVE_RATIO), so
## menu content sits in the middle of the screen with its actions right under it.
## Add rows with SIZE_SHRINK_CENTER (or Ui.centered) to centre them horizontally.
static func centre_block(body: VBoxContainer, separation: int = Metrics.XL) -> VBoxContainer:
	# A little more room above than below: the header already weighs the top.
	var above := spacer()
	above.size_flags_stretch_ratio = BLOCK_ABOVE_RATIO
	body.add_child(above)
	var block := vbox(separation)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(block)
	body.add_child(spacer())
	return block


## A centred row of actions (status or counter text and buttons) under content.
static func actions(block: VBoxContainer) -> HBoxContainer:
	var row := hbox(Metrics.M)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(row)
	return row


## A keyboard key cap ("1", "Enter"): dark inset face, light rim, lining figures.
## Drawn like the map's and the hand's caps so a key always looks like a key.
static func key_cap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var style := UiTheme.box(Palette.WALNUT_INSET, Palette.IVORY_FAINT, 3, 0)
	style.content_margin_left = Metrics.XS + 2
	style.content_margin_right = Metrics.XS + 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", style)
	cap.custom_minimum_size = Vector2(Metrics.KEY_CAP, Metrics.KEY_CAP)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text_label := label(text, "Caption", Palette.IVORY)
	text_label.add_theme_font_override("font", UiFonts.numbers())
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(text_label)
	return cap


## A right-aligned row of buttons at the bottom of a frame body.
static func footer(body: VBoxContainer) -> HBoxContainer:
	var row := hbox(Metrics.S)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(spacer())
	body.add_child(row)
	return row


## A short status line for refusals ("Not enough points ...").
static func status_label() -> Label:
	var node := label("", "Body", Palette.OXBLOOD_INK)
	node.custom_minimum_size.y = Metrics.L + Metrics.XS
	return node

