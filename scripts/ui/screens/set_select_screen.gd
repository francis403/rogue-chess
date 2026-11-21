extends Control
## Pick the starting piece set. Locked sets show how to unlock them.

var _status: Label
var _has_chosen: bool = false


func _ready() -> void:
	var body := Ui.frame(self, "New run · step 1", "Choose your piece set", "The set applies to every piece you own this run, including pieces you buy.")
	var row := Ui.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for piece_set in Game.run.available_piece_sets():
		row.add_child(_set_tile(piece_set))
	_status = Ui.status_label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	var back := Ui.button("Back to title", "QuietButton")
	back.pressed.connect(func() -> void: Game.show_title())
	Ui.footer(body).add_child(back)


func _set_tile(piece_set: Dictionary) -> SelectTile:
	var tile := SelectTile.new()
	tile.custom_minimum_size = Vector2(420, 340)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.is_locked = piece_set["locked"]
	var column := Ui.vbox(16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var tokens := Ui.hbox(4)
	tokens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for piece_type in ["pawn", "knight", "bishop", "rook", "queen", "king"]:
		tokens.add_child(PieceToken.create(52, PieceData.new(piece_type, piece_set["id"])))
	column.add_child(tokens)
	column.add_child(Ui.label(piece_set["name"], "H1"))
	column.add_child(Ui.wrapped(piece_set["desc"], "Body", 380))
	var values: Array[String] = []
	for piece_type in ["pawn", "knight", "bishop", "rook", "queen"]:
		values.append("%s %d" % [Ui.piece_name(piece_type), PieceData.new(piece_type, piece_set["id"]).value()])
	column.add_child(Ui.label("Worth: " + " · ".join(values), "Caption"))
	column.add_child(Ui.spacer())
	if piece_set["locked"]:
		column.add_child(Ui.label("Locked · Beat the boss to unlock", "Strong", Palette.OXBLOOD))
	else:
		column.add_child(Ui.label("Click to start with %s pieces" % piece_set["name"], "Caption", Palette.BRASS))
	tile.pressed.connect(_choose.bind(piece_set["id"], tile))
	return tile


func _choose(set_id: String, tile: SelectTile) -> void:
	if _has_chosen:
		return
	var result := Game.run.choose_piece_set(set_id)
	if not result["ok"]:
		Ui.shake(tile)
		Ui.flash_status(_status, result["error"])
		return
	_has_chosen = true
	Game.show_phase()
