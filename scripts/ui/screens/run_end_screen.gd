extends Control
## The end of a run: result, what was unlocked, a summary, and a new run.


func _ready() -> void:
	var run := Game.run
	var summary := run.summary()
	var is_win: bool = summary["result"] == "won"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := Ui.vbox(20)
	margin.add_child(column)
	column.add_child(Ui.label("RUN COMPLETE" if is_win else "RUN OVER", "Eyebrow"))
	column.add_child(Ui.label("The boss has fallen" if is_win else "Defeated on floor %d" % (int(summary["floors_cleared"]) + 1), "Title",
		Palette.BRASS if is_win else Palette.OXBLOOD))
	var row := Ui.hbox(24)
	column.add_child(row)
	row.add_child(_unlock_panel(run.unlock_result()))
	row.add_child(_summary_panel(summary))
	column.add_child(Ui.spacer())
	var footer := Ui.hbox(8)
	footer.add_child(Ui.spacer())
	var title := Ui.button("Title screen", "QuietButton")
	Ui.connect_once(title, func() -> void: Game.show_title())
	footer.add_child(title)
	var again := Ui.button("Start new run", "PrimaryButton")
	again.custom_minimum_size = Vector2(220, 44)
	Ui.connect_once(again, func() -> void: Game.new_run())
	footer.add_child(again)
	column.add_child(footer)


func _unlock_panel(unlock: Dictionary) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(340, 0)
	var column := Ui.vbox(12)
	panel.add_child(column)
	column.add_child(Ui.label("UNLOCK", "Eyebrow"))
	var is_new: bool = unlock.get("is_new", false)
	if is_new and unlock["kind"] == "piece_set":
		var tokens := Ui.hbox(4)
		for piece_type in ["pawn", "knight", "bishop", "rook", "queen"]:
			tokens.add_child(PieceToken.create(44, PieceData.new(piece_type, unlock["id"])))
		column.add_child(tokens)
		column.add_child(Ui.label("%s pieces" % Ui.piece_set_name(unlock["id"]), "H1", Palette.EMBER))
		column.add_child(Ui.wrapped(String(GameConfig.data("piece_sets")["sets"][unlock["id"]]["desc"]), "Body", 300))
	elif is_new:
		column.add_child(Ui.label(Ui.artifact_name(unlock["id"]), "H1", Palette.BRASS))
		column.add_child(Ui.wrapped(Ui.artifact_desc(unlock["id"]), "Body", 300))
		column.add_child(Ui.wrapped("Choose it at the start of your next run.", "Caption", 300))
	else:
		column.add_child(Ui.label("Nothing new", "H1", Palette.IVORY_FAINT))
	column.add_child(Ui.wrapped(String(unlock.get("text", "")), "Strong" if is_new else "Body", 300))
	return panel


func _summary_panel(summary: Dictionary) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := Ui.vbox(12)
	panel.add_child(column)
	column.add_child(Ui.label("RUN SUMMARY", "Eyebrow"))
	var stats := Ui.hbox(32)
	stats.add_child(_stat("Floors", "%d / %d" % [summary["floors_cleared"], summary["floors_total"]]))
	stats.add_child(_stat("Wins", str(summary["wins"])))
	stats.add_child(_stat("Points left", str(summary["points"])))
	stats.add_child(_stat("Piece set", Ui.piece_set_name(summary["piece_set"]) if summary["piece_set"] != "" else "-"))
	column.add_child(stats)
	column.add_child(Ui.artifact_chips(summary["artifacts"]))
	column.add_child(Ui.label("DECK · %d CARDS" % summary["deck"].size(), "Eyebrow"))
	var deck := HFlowContainer.new()
	deck.add_theme_constant_override("h_separation", 6)
	deck.add_theme_constant_override("v_separation", 6)
	for card_dict: Dictionary in summary["deck"]:
		var view := CardView.create(CardData.from_dict(card_dict), Vector2(72, 101))
		view.is_interactive = false
		view.mouse_filter = Control.MOUSE_FILTER_PASS
		deck.add_child(view)
	column.add_child(deck)
	column.add_child(Ui.label("COLLECTION · %d PIECES" % summary["collection"].size(), "Eyebrow"))
	var pieces := HFlowContainer.new()
	pieces.add_theme_constant_override("h_separation", 2)
	pieces.add_theme_constant_override("v_separation", 2)
	for piece_dict: Dictionary in summary["collection"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(34, 34)
		var data := PieceData.from_dict(piece_dict)
		holder.tooltip_text = Ui.piece_tooltip(data)
		holder.add_child(PieceToken.create(34, data))
		pieces.add_child(holder)
	column.add_child(pieces)
	var upgraded: Array = summary["upgraded_pieces"]
	if not upgraded.is_empty():
		var names: Array[String] = []
		for piece_dict: Dictionary in upgraded:
			names.append("%s (%s)" % [Ui.piece_name(piece_dict["type"]), Ui.upgrade_name("piece", piece_dict["upgrade"])])
		column.add_child(Ui.wrapped("Upgraded: " + ", ".join(names), "Body"))
	return panel


func _stat(caption: String, value: String) -> VBoxContainer:
	var column := Ui.vbox(0)
	column.add_child(Ui.label(caption, "Caption"))
	column.add_child(Ui.label(value, "Stat"))
	return column
