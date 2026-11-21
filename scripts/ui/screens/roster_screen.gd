extends Control
## Match setup: pick pieces within the budget and place them on your two back ranks.
## All validity comes from RunSession.validate_roster().

var _roster: Array[Dictionary] = []
var _selected: PieceData
var _board: BoardView
var _list: VBoxContainer
var _meter: PipMeter
var _cost_label: Label
var _message: Label
var _start: Button
var _opponent: Dictionary
var _opponent_id: String = ""
var _is_starting: bool = false


func _ready() -> void:
	var run := Game.run
	var info := run.current_node_info()
	_opponent_id = info["opponent"]
	_opponent = GameConfig.data("opponents")[_opponent_id]
	var body := Ui.frame(self, "Floor %d · match setup" % info["floor"], "Deploy your pieces",
		"The king is free and always plays. Place pieces on your back %d ranks: click a piece, then a highlighted square, or drag it. Click a placed piece to bench it." % _deploy_rows())
	var row := Ui.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(_collection_panel())
	row.add_child(_board_column())
	row.add_child(_opponent_panel())
	_roster = run.default_roster()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_selected = null
		_refresh()


func _collection_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(280, 0)
	var column := Ui.vbox(12)
	panel.add_child(column)
	column.add_child(Ui.label("COLLECTION", "Eyebrow"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = Ui.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	column.add_child(scroll)
	return panel


func _board_column() -> VBoxContainer:
	var column := Ui.vbox(12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var budget := Ui.hbox(12)
	budget.alignment = BoxContainer.ALIGNMENT_CENTER
	budget.add_child(Ui.label("BUDGET", "Eyebrow"))
	_meter = PipMeter.new()
	_meter.total = Game.run.deploy_budget()
	_meter.is_round = false
	_meter.pip_size = Vector2(18, 12)
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	budget.add_child(_meter)
	_cost_label = Ui.label("", "Strong")
	_cost_label.custom_minimum_size.x = 64
	budget.add_child(_cost_label)
	column.add_child(budget)
	_board = BoardView.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(360, 360)
	_board.square_clicked.connect(_on_square_clicked)
	_board.piece_dropped.connect(_on_dropped)
	column.add_child(_board)
	_message = Ui.label("", "Body")
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var buttons := Ui.hbox(8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var auto := Ui.button("Auto")
	auto.tooltip_text = "Fill a sensible default roster"
	auto.pressed.connect(func() -> void:
		_roster = Game.run.default_roster()
		_selected = null
		_refresh())
	buttons.add_child(auto)
	var clear := Ui.button("Bench all")
	clear.pressed.connect(_bench_all)
	buttons.add_child(clear)
	_start = Ui.button("Start match", "PrimaryButton")
	_start.custom_minimum_size.x = 180
	_start.pressed.connect(_start_match)
	buttons.add_child(_start)
	column.add_child(buttons)
	return column


func _opponent_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(280, 0)
	var column := Ui.vbox(12)
	panel.add_child(column)
	column.add_child(Ui.label("YOUR OPPONENT", "Eyebrow"))
	column.add_child(Ui.label(_opponent["name"], "H2"))
	var difficulty_color := Palette.OXBLOOD if Ui.is_boss(_opponent_id) else Palette.IVORY_SOFT
	var tags := Ui.hbox(4)
	tags.add_child(Ui.chip(_opponent["difficulty"], difficulty_color))
	tags.add_child(Ui.chip("Looks %d ahead" % int(_opponent["search_depth"]), Palette.IVORY_SOFT, "Search depth of the opponent's move planning"))
	column.add_child(tags)
	column.add_child(Ui.label("PIECES", "Eyebrow"))
	var pieces := HFlowContainer.new()
	pieces.add_theme_constant_override("h_separation", 4)
	pieces.add_theme_constant_override("v_separation", 4)
	var worth := 0
	for entry in _opponent["pieces"]:
		pieces.add_child(PieceToken.create(30, PieceData.new(entry["type"]), 1))
		worth += GameConfig.piece_value(entry["type"])
	column.add_child(pieces)
	column.add_child(Ui.label("%d points of material on the board" % worth, "Caption"))
	column.add_child(Ui.label("DECK", "Eyebrow"))
	var deck_names: Array[String] = []
	for card_type: String in _opponent["deck"]:
		deck_names.append(GameConfig.data("cards")[card_type]["name"])
	column.add_child(Ui.wrapped(", ".join(deck_names), "Body", 240))
	column.add_child(Ui.label("ARTIFACTS", "Eyebrow"))
	var count := int(_opponent["artifact_count"])
	var artifact_text := "None" if count == 0 else "%d random artifact%s, revealed when the match starts" % [count, "" if count == 1 else "s"]
	column.add_child(Ui.wrapped(artifact_text, "Body" if count == 0 else "Strong", 240))
	return panel


func _refresh() -> void:
	_refresh_list()
	_refresh_board()
	var cost := 0
	for entry in _roster:
		cost += (entry["piece"] as PieceData).deploy_cost()
	_meter.value = cost
	_cost_label.text = "%d / %d" % [cost, Game.run.deploy_budget()]
	var validation := Game.run.validate_roster(_roster)
	_start.disabled = not validation["ok"]
	if not validation["ok"]:
		_message.text = validation["error"]
		_message.add_theme_color_override("font_color", Palette.OXBLOOD)
	elif _selected != null:
		_message.text = "Place your %s on a highlighted square" % _selected.type
		_message.add_theme_color_override("font_color", Palette.BRASS)
	else:
		_message.text = "%d pieces ready · %d budget left" % [_roster.size(), Game.run.deploy_budget() - cost]
		_message.add_theme_color_override("font_color", Palette.IVORY_SOFT)


func _refresh_list() -> void:
	Ui.clear(_list)
	var pieces := Game.run.collection.duplicate()
	pieces.sort_custom(func(a: PieceData, b: PieceData) -> bool: return a.deploy_cost() > b.deploy_cost())
	for piece: PieceData in pieces:
		_list.add_child(_piece_row(piece))


func _piece_row(piece: PieceData) -> RosterRow:
	var row := RosterRow.new()
	row.padding = 8
	row.piece = piece
	row.is_selected = piece == _selected
	row.tooltip_text = Ui.piece_tooltip(piece)
	var on_board := _square_of(piece) != BoardView.NO_SQUARE
	var content := Ui.hbox(8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var token := PieceToken.create(30, piece)
	token.is_locked = piece.type == "king"
	content.add_child(token)
	var text := Ui.vbox(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Ui.label(Ui.piece_name(piece.type), "Strong", Palette.IVORY if not on_board else Palette.IVORY_FAINT))
	var detail := "Always plays" if piece.type == "king" else ("On the board" if on_board else "Benched")
	if piece.upgrade != "":
		detail = "%s · %s" % [Ui.upgrade_name("piece", piece.upgrade), detail]
	text.add_child(Ui.label(detail, "Caption", Palette.BRASS if piece.upgrade != "" else Palette.IVORY_FAINT))
	content.add_child(text)
	var cost := Ui.label("free" if piece.type == "king" else str(piece.deploy_cost()), "Strong", Palette.BRASS)
	content.add_child(cost)
	row.modulate = Color(1, 1, 1, 0.6) if on_board and piece != _selected else Color.WHITE
	row.pressed.connect(_on_row_pressed.bind(piece))
	return row


func _refresh_board() -> void:
	_board.clear_tokens()
	var zone: Array[Vector2i] = []
	for y in int(GameConfig.value("match", "deploy_rows")):
		for x in _board.board_size:
			zone.append(Vector2i(x, y))
	_board.zone = zone
	for entry in _opponent["pieces"]:
		var token := PieceToken.create(48, PieceData.new(entry["type"]), 1)
		token.modulate.a = 0.75
		_board.set_token("opponent_%d_%d" % [entry["square"][0], entry["square"][1]], token, Vector2i(int(entry["square"][0]), int(entry["square"][1])))
	for entry in _roster:
		var piece: PieceData = entry["piece"]
		var token := PieceToken.create(48, piece)
		token.is_locked = piece.type == "king"
		if piece == _selected:
			token.modulate.a = 0.5
		_board.set_token(piece.uid, token, entry["square"])
	var free: Array[Vector2i] = []
	if _selected != null:
		for square in zone:
			if _piece_on(square) == null:
				free.append(square)
	_board.drop_squares = zone
	_board.set_highlights([], free, [], _square_of(_selected) if _selected != null else BoardView.NO_SQUARE)


func _on_row_pressed(piece: PieceData) -> void:
	if piece != _selected and piece.type != "king" and _square_of(piece) != BoardView.NO_SQUARE:
		_bench(piece)
		return
	_selected = null if piece == _selected else piece
	_refresh()


func _on_square_clicked(square: Vector2i) -> void:
	var occupant := _piece_on(square)
	if occupant != null:
		if occupant.type == "king" and _selected != occupant:
			_selected = occupant
			_refresh()
		elif occupant != _selected:
			_bench(occupant)
		return
	if _selected == null:
		_message.text = "Pick a piece from your collection first"
		Ui.shake(_message)
		return
	if square.y >= _deploy_rows():
		_message.text = "Pieces go on your back %d ranks" % _deploy_rows()
		Ui.shake(_message)
		return
	_place(_selected, square)


## Dropping onto a placed piece swaps the two if the dragged piece was on the board.
func _on_dropped(square: Vector2i, data: Variant) -> void:
	var piece: PieceData = data["roster_piece"]
	var occupant := _piece_on(square)
	if occupant == piece:
		_selected = null
		_refresh()
		return
	if occupant == null:
		_place(piece, square)
		return
	var origin := _square_of(piece)
	if origin == BoardView.NO_SQUARE:
		_selected = null
		_refresh()
		_message.text = "Square taken: click that piece to bench it first"
		_message.add_theme_color_override("font_color", Palette.OXBLOOD)
		Ui.shake(_message)
		return
	_remove(occupant)
	_roster.append({"piece": occupant, "square": origin})
	_place(piece, square)


func _deploy_rows() -> int:
	return int(GameConfig.value("match", "deploy_rows"))


func _place(piece: PieceData, square: Vector2i) -> void:
	_remove(piece)
	_roster.append({"piece": piece, "square": square})
	_selected = null
	_refresh()
	Ui.pop(_board.token(piece.uid), 1.2)


func _bench(piece: PieceData) -> void:
	_remove(piece)
	if _selected == piece:
		_selected = null
	_refresh()


func _bench_all() -> void:
	_roster.assign(_roster.filter(func(entry: Dictionary) -> bool: return entry["piece"].type == "king"))
	_selected = null
	_refresh()


func _remove(piece: PieceData) -> void:
	_roster.assign(_roster.filter(func(entry: Dictionary) -> bool: return entry["piece"] != piece))


func _square_of(piece: PieceData) -> Vector2i:
	for entry in _roster:
		if entry["piece"] == piece:
			return entry["square"]
	return BoardView.NO_SQUARE


func _piece_on(square: Vector2i) -> PieceData:
	for entry in _roster:
		if entry["square"] == square:
			return entry["piece"]
	return null


func _start_match() -> void:
	if _is_starting:
		return
	_is_starting = true
	var setup := Game.run.build_match_setup(_roster)
	if setup.has("ok"):
		_is_starting = false
		_message.text = setup["error"]
		_message.add_theme_color_override("font_color", Palette.OXBLOOD)
		Ui.shake(_message)
		return
	Game.match_setup = setup
	Game.show_phase()
