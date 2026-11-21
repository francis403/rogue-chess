class_name ItemOverlay
extends Control
## A modal list of cards or pieces over a dim scrim. Esc, the scrim or Close dismiss it.
## With on_pick, clicking an item calls it and closes (the shop's card removal).

var _panel: PanelContainer
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = Ui.panel("ModalPanel")
	_panel.custom_minimum_size = Vector2(760, 0)
	centre.add_child(_panel)
	_body = Ui.vbox(16)
	_panel.add_child(_body)
	Ui.fade_in(self, Ui.FAST)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func show_cards(title: String, cards: Array, on_pick: Callable = Callable(), subtitle: String = "") -> void:
	_header(title, subtitle if subtitle != "" else "%d cards" % cards.size())
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 20)
	for card: CardData in cards:
		var view := CardView.create(card)
		view.is_interactive = on_pick.is_valid()
		if on_pick.is_valid():
			view.pressed.connect(func() -> void:
				on_pick.call(card)
				queue_free())
		grid.add_child(view)
	_body.add_child(_scrolling(grid, 360))
	_footer()


func show_pieces(title: String, pieces: Array) -> void:
	_header(title, "%d pieces · hover for details" % pieces.size())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for piece: PieceData in pieces:
		grid.add_child(piece_row(piece))
	_body.add_child(_scrolling(grid, 380))
	_footer()


## Token + name + upgrade, used here and on the run-end screen.
static func piece_row(piece: PieceData) -> Control:
	var row := Ui.panel("InsetPanel")
	row.custom_minimum_size = Vector2(170, 0)
	row.tooltip_text = Ui.piece_tooltip(piece)
	var content := Ui.hbox(8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	content.add_child(PieceToken.create(36, piece))
	var text := Ui.vbox(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(Ui.label(Ui.piece_name(piece.type), "Strong"))
	var detail := Ui.upgrade_name("piece", piece.upgrade) if piece.upgrade != "" else "deploy %d" % piece.deploy_cost()
	text.add_child(Ui.label(detail, "Caption", Palette.BRASS if piece.upgrade != "" else Palette.IVORY_FAINT))
	content.add_child(text)
	return row


func _header(title: String, subtitle: String) -> void:
	var header := Ui.vbox(2)
	header.add_child(Ui.label(title, "H1"))
	header.add_child(Ui.label(subtitle, "Caption"))
	_body.add_child(header)


func _footer() -> void:
	var row := Ui.hbox(8)
	row.add_child(Ui.spacer())
	var close := Ui.button("Close")
	close.pressed.connect(queue_free)
	row.add_child(close)
	_body.add_child(row)


func _scrolling(content: Control, height: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_child(content)
	scroll.add_child(margin)
	return scroll


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()
