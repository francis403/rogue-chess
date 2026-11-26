extends Control
## The run map plus a side panel describing the hovered or next nodes.
## Keyboard: the map has focus; arrows pick a next stop, Enter travels, 1-3 travel directly.
## Choosing walks a marker to the node (map_travel), then the next screen opens.

var _map_view: MapView
var _detail: VBoxContainer
var _stops_scroll: ScrollContainer
var _has_chosen: bool = false


func _ready() -> void:
	var run := Game.run
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Metrics.XL)
	add_child(margin)
	var row := Ui.hbox(Metrics.XL)
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
	A11y.focus_first([_map_view])


func _unhandled_input(event: InputEvent) -> void:
	var index := A11y.number_key(event)
	var order := _map_view.choices()
	if index >= 0 and index < order.size():
		get_viewport().set_input_as_handled()
		_choose(order[index])


func _side_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(320, 0)
	var column := Ui.vbox(Metrics.L)
	panel.add_child(column)
	var header := Ui.vbox(Metrics.XS)
	header.add_child(Ui.label("THE CLIMB", "Eyebrow"))
	header.add_child(Ui.label("Choose your next stop", "H2"))
	header.add_child(Ui.wrapped("Climb %d floors; the boss waits at the top. Glowing nodes are your next stops: click one, or press its number key." % Game.run.map.floors(), "Body", 280))
	column.add_child(header)
	# The stop cards scroll in the room left between the header and the legend,
	# so the side panel never grows taller than the window (Large text, three
	# stops) and never sets the map's height: that comes from the window alone.
	# The scroll window is cut to whole cards (_fit_stops).
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stops_scroll = ScrollContainer.new()
	_stops_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_stops_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stops_scroll.focus_mode = Control.FOCUS_NONE
	_detail = Ui.vbox(Metrics.S)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stops_scroll.add_child(_detail)
	holder.add_child(_stops_scroll)
	holder.resized.connect(_fit_stops)
	_detail.minimum_size_changed.connect(_fit_stops)
	column.add_child(holder)
	column.add_child(_legend())
	return panel


## The stops' window shows as many whole cards (and the eyebrow) as its room
## holds; the scroll bar says there are more. Measured from the cards' minimum
## heights, not their laid-out rects: right after _show_detail() rebuilds the
## list those are not sorted yet (a stale rect cut the first card in half).
func _fit_stops() -> void:
	var holder := _stops_scroll.get_parent() as Control
	var room := holder.size.y
	var separation := _detail.get_theme_constant("separation")
	var top := 0.0
	var bottom := 0.0
	for child: Control in _detail.get_children():
		var end := top + child.get_combined_minimum_size().y
		if end > room + 0.5:
			break
		bottom = end
		top = end + separation
	_stops_scroll.offset_bottom = bottom if bottom > 0.0 else room


## Node types on the left, node states on the right.
func _legend() -> VBoxContainer:
	var column := Ui.vbox(Metrics.S)
	column.add_child(Ui.rule())
	column.add_child(Ui.label("LEGEND", "Eyebrow"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Metrics.XL)
	grid.add_theme_constant_override("v_separation", Metrics.XS)
	var types := [[UiFonts.glyph("pawn"), true, "Easy match", "A match against an easy opponent: +%d points and a card if you win" % _win_points()],
		[UiFonts.glyph("rook"), true, "Medium match", "A match against a stronger opponent: +%d points and a card if you win" % _win_points()],
		["$", false, "Shop", "Buy cards and pieces, or remove a card from your deck"],
		["↑", false, "Coaching", "Pay points to upgrade one specific card or piece per offer"],
		[UiFonts.glyph("king"), true, "Boss", "The last match. Beat it to finish the run and unlock the Fire set"]]
	# Same fill, rim and glyph ink MapView draws for each node state (the ink is
	# what tells "ahead" from "out of reach" at a glance, as on the map).
	var states := [[Palette.WALNUT_HIGH, Palette.BRASS, Palette.IVORY, "Next stop", "Glowing, with a number key cap and a dashed path from you"],
		[Palette.BRASS.darkened(0.55), Palette.BRASS, Palette.BRASS, "Visited", "Brass fill; the path you walked is a solid brass line"],
		[Palette.WALNUT_RAISED, Palette.RULE_STRONG, Palette.IVORY_SOFT, "Ahead", "Still reachable later from your next stops"],
		[Palette.WALNUT, Palette.RULE_SOFT, Palette.IVORY_MUTED, "Out of reach", "Darker, with a dim glyph and faint edges: no path leads there any more"],
		[Palette.WALNUT_RAISED, Palette.IVORY, Palette.IVORY_SOFT, "You are here", "Ivory ring and a YOU tab"]]
	for i in types.size():
		grid.add_child(_legend_type(types[i]))
		grid.add_child(_legend_state(states[i]))
	column.add_child(grid)
	return column


func _legend_type(entry: Array) -> HBoxContainer:
	var line := Ui.hbox(Metrics.S)
	var glyph := Ui.label(entry[0], "Strong", Palette.BRASS)
	glyph.add_theme_font_override("font", UiFonts.symbols() if entry[1] else UiFonts.serif_bold())
	glyph.custom_minimum_size.x = 20
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_child(glyph)
	line.add_child(Ui.label(entry[2], "Body"))
	line.tooltip_text = entry[3]
	return line


## [fill, rim, ink, text, hint]: a small node (disc, rim, a dot of glyph ink).
func _legend_state(entry: Array) -> HBoxContainer:
	var line := Ui.hbox(Metrics.S)
	line.tooltip_text = entry[4]
	var node := Control.new()
	node.custom_minimum_size = Vector2(18, 18)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.draw.connect(func() -> void:
		var centre := node.size / 2.0
		node.draw_circle(centre, 8.0, entry[0])
		node.draw_arc(centre, 8.0, 0, TAU, 24, entry[1], 2.0, true)
		node.draw_circle(centre, 3.0, entry[2]))
	line.add_child(node)
	line.add_child(Ui.label(entry[3], "Body"))
	return line


func _show_detail(node_id: String) -> void:
	Ui.clear(_detail)
	if node_id == "":
		_show_next_stops()
	else:
		_detail.add_child(_node_card(node_id, true))


## With nothing hovered: a compact card for each reachable node.
func _show_next_stops() -> void:
	_detail.add_child(Ui.label("NEXT STOPS · HOVER A NODE FOR MORE", "Eyebrow"))
	for node_id in _map_view.choices():
		_detail.add_child(_node_card(node_id, false))


func _node_card(node_id: String, is_full: bool) -> PanelContainer:
	var run := Game.run
	var info := run.map.node(node_id)
	var panel := Ui.panel("InsetPanel")
	var column := Ui.vbox(Metrics.XS)
	panel.add_child(column)
	var heading := Ui.hbox(Metrics.S)
	heading.add_child(Ui.label("FLOOR %d · %s" % [info["floor"], MapView.node_label(info).to_upper()], "Eyebrow"))
	var key := _map_view.choices().find(node_id)
	if not is_full and key != -1:
		heading.add_child(Ui.spacer())
		heading.add_child(Ui.key_cap(str(key + 1)))
	column.add_child(heading)
	match info["type"]:
		"shop":
			column.add_child(Ui.label("Shop", "Strong"))
			if is_full:
				column.add_child(Ui.wrapped("Buy cards and pieces, or remove a card from your deck.", "Body", 260))
		"coaching":
			column.add_child(Ui.label("Coaching", "Strong"))
			if is_full:
				column.add_child(Ui.wrapped("Pay to upgrade cards and pieces from your run.", "Body", 260))
		_:
			var opponent: Dictionary = GameConfig.data("opponents")[info["opponent"]]
			column.add_child(Ui.label(opponent["name"], "Strong"))
			if is_full:
				var pieces := Ui.hbox(2)
				for entry in opponent["pieces"]:
					pieces.add_child(PieceToken.create(26, PieceData.new(entry["type"]), 1))
				column.add_child(pieces)
				column.add_child(Ui.label("Win: +%d training points and a card" % _win_points(), "Caption"))
	# Where this path goes next, so stops that look alike can still be told apart.
	if not is_full and not info["next"].is_empty():
		column.add_child(Ui.label("Then: " + _next_kinds(info), "Caption"))
	if is_full:
		var is_next := run.available_nodes().has(node_id)
		var state := "Click or press %d to travel here" % (_map_view.choices().find(node_id) + 1) if is_next else ("Visited" if run.visited.has(node_id) else "Not reachable from here")
		column.add_child(Ui.label(state, "Caption", Palette.BRASS if is_next else Palette.IVORY_FAINT))
	return panel


## "Shop or Easy match": the kinds of node one step further along this path.
func _next_kinds(info: Dictionary) -> String:
	var kinds: Array[String] = []
	for next_id: String in info["next"]:
		var next_info := Game.run.map.node(next_id)
		var kind := MapView.node_label(next_info)
		if next_info["type"] in ["match", "boss"] and kind != "Boss":
			kind += " match"
		if not kinds.has(kind):
			kinds.append(kind)
	return " or ".join(kinds)


func _choose(node_id: String) -> void:
	if _has_chosen:
		return
	var result := Game.run.choose_node(node_id)
	if not result["ok"]:
		Sfx.play("ui_error")
		return
	_has_chosen = true
	Sfx.play("map_travel")
	_map_view.travel_to(node_id, Motion.time("map_travel")).finished.connect(Game.show_phase)


func _win_points() -> int:
	return int(GameConfig.value("economy", "win_points"))
