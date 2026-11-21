extends Control
## Title: New Game, Quit and what has been unlocked so far.


func _ready() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := Ui.vbox(16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	column.add_child(Ui.centered(_piece_row()))
	var title := Ui.label("RogueChess", "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var size := int(GameConfig.value("match", "board_size"))
	var subtitle := Ui.label("A chess roguelike deckbuilder · %d by %d board · every move needs a card" % [size, size], "Body")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(_gap(16))
	var new_game := Ui.button("New Game", "PrimaryButton")
	new_game.custom_minimum_size = Vector2(260, 48)
	new_game.add_theme_font_size_override("font_size", UiTheme.STRONG)
	Ui.connect_once(new_game, func() -> void: Game.new_run())
	column.add_child(Ui.centered(new_game))
	var quit := Ui.button("Quit", "QuietButton")
	quit.custom_minimum_size = Vector2(260, 40)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(Ui.centered(quit))
	column.add_child(_gap(16))
	column.add_child(Ui.centered(_unlock_panel()))


func _piece_row() -> HBoxContainer:
	var row := Ui.hbox(6)
	for piece_type in ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]:
		var token := PieceToken.create(40, PieceData.new(piece_type), 0 if piece_type != "queen" else 1)
		row.add_child(token)
	return row


func _unlock_panel() -> PanelContainer:
	var meta := Game.unlocks()
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(520, 0)
	var column := Ui.vbox(12)
	panel.add_child(column)
	var sets: Dictionary = GameConfig.data("piece_sets")["sets"]
	var pool: Array = GameConfig.data("artifacts")["unlock_pool"]
	column.add_child(_progress_line("Piece sets", meta.unlocked_piece_sets.size(), sets.size()))
	var set_row := Ui.hbox(6)
	for set_id: String in sets:
		var is_open := meta.is_piece_set_unlocked(set_id)
		set_row.add_child(Ui.chip(Ui.piece_set_name(set_id) if is_open else "%s · locked" % Ui.piece_set_name(set_id),
			Palette.BRASS if is_open else Palette.IVORY_MUTED, sets[set_id]["desc"]))
	column.add_child(set_row)
	column.add_child(_progress_line("Artifacts", meta.unlocked_artifacts.size(), pool.size()))
	var artifact_row := Ui.hbox(6)
	for artifact_id: String in pool:
		var is_open := meta.is_artifact_unlocked(artifact_id)
		artifact_row.add_child(Ui.chip(Ui.artifact_name(artifact_id) if is_open else "?",
			Palette.BRASS if is_open else Palette.IVORY_MUTED, Ui.artifact_desc(artifact_id) if is_open else "Lose a match to unlock a random artifact"))
	column.add_child(artifact_row)
	return panel


func _progress_line(text: String, unlocked: int, total: int) -> HBoxContainer:
	var row := Ui.hbox(8)
	row.add_child(Ui.label(text.to_upper(), "Eyebrow"))
	row.add_child(Ui.spacer())
	row.add_child(Ui.label("%d / %d unlocked" % [unlocked, total], "Caption"))
	return row


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap
