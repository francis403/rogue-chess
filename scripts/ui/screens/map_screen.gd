extends Control
## The run map plus a side panel describing the hovered or next nodes.

var _map_view: MapView
var _detail: VBoxContainer
var _has_chosen: bool = false


func _ready() -> void:
	var run := Game.run
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var row := Ui.hbox(24)
	margin.add_child(row)
	_map_view = MapView.new()
	_map_view.map = run.map
	_map_view.visited = run.visited
	_map_view.current = run.current_node
	_map_view.available = run.available_nodes()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.node_pressed.connect(_choose)
	_map_view.node_hovered.connect(_show_detail)
	row.add_child(_map_view)
	row.add_child(_side_panel())
	_show_detail("")


func _side_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(320, 0)
	var column := Ui.vbox(16)
	panel.add_child(column)
	column.add_child(Ui.label("THE CLIMB", "Eyebrow"))
	column.add_child(Ui.label("Choose your next stop", "H2"))
	column.add_child(Ui.wrapped("Glowing nodes are reachable. Climb %d floors; the boss waits at the top." % Game.run.map.floors(), "Body", 280))
	_detail = Ui.vbox(8)
	column.add_child(_detail)
	column.add_child(Ui.spacer())
	column.add_child(Ui.label("LEGEND", "Eyebrow"))
	var legend := [[UiFonts.glyph("pawn"), true, "Easy match"], [UiFonts.glyph("rook"), true, "Medium match"],
		["$", false, "Shop"], ["↑", false, "Coaching"], [UiFonts.glyph("king"), true, "Boss"]]
	for entry in legend:
		var line := Ui.hbox(12)
		var glyph := Ui.label(entry[0], "Strong", Palette.BRASS)
		glyph.add_theme_font_override("font", UiFonts.symbols() if entry[1] else UiFonts.serif_bold())
		glyph.custom_minimum_size.x = 20
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(glyph)
		line.add_child(Ui.label(entry[2], "Body"))
		column.add_child(line)
	return panel


func _show_detail(node_id: String) -> void:
	Ui.clear(_detail)
	var run := Game.run
	if node_id == "":
		_detail.add_child(Ui.label("Hover a node for details.", "Caption"))
		return
	var info := run.map.node(node_id)
	var panel := Ui.panel("InsetPanel")
	var column := Ui.vbox(4)
	panel.add_child(column)
	column.add_child(Ui.label("FLOOR %d · %s" % [info["floor"], MapView.node_label(info).to_upper()], "Eyebrow"))
	match info["type"]:
		"shop":
			column.add_child(Ui.label("Shop", "Strong"))
			column.add_child(Ui.wrapped("Buy cards and pieces, or remove a card from your deck.", "Body", 260))
		"coaching":
			column.add_child(Ui.label("Coaching", "Strong"))
			column.add_child(Ui.wrapped("Pay to upgrade cards and pieces from your run.", "Body", 260))
		_:
			var opponent: Dictionary = GameConfig.data("opponents")[info["opponent"]]
			column.add_child(Ui.label(opponent["name"], "Strong"))
			var pieces := Ui.hbox(2)
			for entry in opponent["pieces"]:
				pieces.add_child(PieceToken.create(26, PieceData.new(entry["type"]), 1))
			column.add_child(pieces)
			column.add_child(Ui.label("Win: +%d training points and a card" % int(GameConfig.value("economy", "win_points")), "Caption"))
	var state := "Click to travel here" if run.available_nodes().has(node_id) else ("Visited" if run.visited.has(node_id) else "Not reachable from here")
	column.add_child(Ui.label(state, "Caption", Palette.BRASS if run.available_nodes().has(node_id) else Palette.IVORY_FAINT))
	_detail.add_child(panel)


func _choose(node_id: String) -> void:
	if _has_chosen:
		return
	var result := Game.run.choose_node(node_id)
	if result["ok"]:
		_has_chosen = true
		Game.show_phase()
