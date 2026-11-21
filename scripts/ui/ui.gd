class_name Ui
extends RefCounted
## Small builders and feedback tweens shared by every screen.

const FAST := 0.15
const NORMAL := 0.25


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


## A short scale bump: "this changed".
static func pop(node: CanvasItem, amount: float = 1.12) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, FAST * 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, FAST).set_ease(Tween.EASE_IN_OUT)


## A small horizontal shake: "not allowed".
static func shake(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var origin := node.position
	var tween := node.create_tween()
	for offset in [6.0, -5.0, 3.0, 0.0]:
		tween.tween_property(node, "position:x", origin.x + offset, 0.04)


static func fade_in(node: CanvasItem, duration: float = NORMAL) -> void:
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)


## Text that rises and fades from `at` (local to `parent`).
static func float_text(parent: Control, text: String, at: Vector2, color: Color, size: int = 22) -> void:
	var node := label(text, "H2", color)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_outline_color", Palette.WALNUT_DEEP)
	node.add_theme_constant_override("outline_size", 6)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 20
	parent.add_child(node)
	node.reset_size()
	node.position = at - node.size / 2.0
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "position:y", node.position.y - 36.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tween.chain().tween_callback(node.queue_free)


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
		row.add_child(label(empty_text, "Caption", Palette.IVORY_MUTED))
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
	var what := "Move any one piece (the only way to move your king)" if card.type == "move" else "Move one %s" % card.type
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
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	screen.add_child(margin)
	var column := vbox(24)
	margin.add_child(column)
	var header := vbox(4)
	header.add_child(label(eyebrow.to_upper(), "Eyebrow"))
	header.add_child(label(title, "H1"))
	if subtitle != "":
		header.add_child(label(subtitle, "Body"))
	column.add_child(header)
	var body := vbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	return body


## A right-aligned row of buttons at the bottom of a frame body.
static func footer(body: VBoxContainer) -> HBoxContainer:
	var row := hbox(8)
	row.add_child(spacer())
	body.add_child(row)
	return row


## A short status line for refusals ("Not enough points ...").
static func status_label() -> Label:
	var node := label("", "Body", Palette.OXBLOOD)
	node.custom_minimum_size.y = 20
	return node


static func flash_status(node: Label, text: String, color: Color = Palette.OXBLOOD) -> void:
	node.text = text
	node.add_theme_color_override("font_color", color)
	shake(node)
