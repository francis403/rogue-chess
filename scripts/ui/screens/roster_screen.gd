extends Control
## Match setup: pick pieces within the budget and place them on your two back ranks.
## All validity comes from RunSession.validate_roster().
## Sound: picking a piece up (piece_pickup), setting it down (piece_land_* by weight),
## benching (ui_cancel), Auto (card_shuffle). Keyboard: Tab / arrows move through
## the collection; Enter on a benched piece (or the king) picks it up and puts a
## dashed square cursor on the board (SquareCursor, drawn above the BoardView):
## arrows walk the deploy squares, Enter sets the piece down, Esc puts it back.
## Enter on a placed piece benches it; Esc drops the current selection.

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
var _cursor: SquareCursor
var _list_scroll: ScrollContainer

const OPPONENT_CARD := Vector2(56, 78)
## Gap between collection rows, and the room kept around them for the focus ring.
const LIST_GAP := 6
## Board tokens (and the keyboard cursor's ghost).
const ROSTER_TOKEN := 48
const RING_ROOM := 6
const KING_HINT := "★ marks your king: it costs nothing, always plays and can't be benched. Click it on the board, then a square, to move it."


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
	A11y.focus_all(self)
	A11y.focus_first([_start])


## Esc drops the selection; with nothing selected it falls through (main opens settings).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _selected != null:
		get_viewport().set_input_as_handled()
		_selected = null
		Sfx.play("ui_cancel")
		_refresh()


func _collection_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(280, 0)
	var column := Ui.vbox(12)
	panel.add_child(column)
	column.add_child(Ui.label("COLLECTION", "Eyebrow"))
	column.add_child(_king_legend())
	# The list scrolls, and its window is cut to whole rows (no row cut in half;
	# the scroll bar says there are more).
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	_list_scroll = scroll
	scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = Ui.vbox(LIST_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for the keyboard focus ring, which is drawn outside each row (the scroll clips).
	var ring_room := MarginContainer.new()
	ring_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		ring_room.add_theme_constant_override("margin_" + side, RING_ROOM)
	ring_room.add_child(_list)
	scroll.add_child(ring_room)
	holder.add_child(scroll)
	# Re-cut whenever the room or the rows change size (Large text, a theme
	# rebuild, a new window size): the rows' real height sets the window.
	holder.resized.connect(_fit_list)
	_list.resized.connect(_fit_list)
	column.add_child(holder)
	return panel


## Sizes the list's window to as many whole rows as its room holds, measured
## from a row's laid-out height (its minimum before the first layout).
func _fit_list() -> void:
	var holder := _list_scroll.get_parent() as Control
	var rows := _list.get_children().filter(func(row: Node) -> bool: return not row.is_queued_for_deletion())
	if rows.is_empty():
		_list_scroll.size.y = holder.size.y
		return
	var first := rows[0] as Control
	var step: float = maxf(first.size.y, first.get_combined_minimum_size().y) + LIST_GAP
	var count := clampi(floori((holder.size.y - RING_ROOM * 2 + LIST_GAP) / step), 1, rows.size())
	_list_scroll.offset_bottom = count * step - LIST_GAP + RING_ROOM * 2


## Explains the star badge on the king and the dimmed tokens of placed pieces.
func _king_legend() -> HBoxContainer:
	var line := Ui.hbox(Metrics.S)
	line.tooltip_text = KING_HINT
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var star := Ui.label("★", "Strong", Palette.IVORY_FAINT)
	star.add_theme_font_override("font", UiFonts.symbols())
	star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(star)
	line.add_child(Ui.wrapped("Your king: free and always plays. A dimmed token is already on the board.", "Caption", 210))
	return line


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
	_cursor = SquareCursor.new()
	_cursor.board = _board
	_cursor.rows = _deploy_rows()
	_cursor.can_take = _cursor_can_take
	_cursor.moved.connect(func() -> void: _show_cursor_hint())
	_cursor.confirmed.connect(_on_cursor_confirmed)
	_cursor.cancelled.connect(_on_cursor_cancelled)
	_board.add_child(_cursor)
	_message = Ui.label("", "Body")
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var buttons := Ui.hbox(8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var auto := Ui.button("Auto")
	auto.tooltip_text = "Fill a sensible default roster"
	auto.set_meta("sfx", "card_shuffle")
	auto.pressed.connect(func() -> void:
		_roster = Game.run.default_roster()
		_selected = null
		_refresh())
	buttons.add_child(auto)
	var clear := Ui.button("Bench all")
	clear.tooltip_text = "Take every piece but the king off the board"
	clear.set_meta("sfx", "ui_cancel")
	clear.pressed.connect(_bench_all)
	buttons.add_child(clear)
	_start = Ui.button("Start match", "PrimaryButton")
	_start.set_meta("sfx", "none")
	_start.tooltip_text = "Start the match with the pieces on the board"
	_start.custom_minimum_size.x = 180
	_start.pressed.connect(_start_match)
	buttons.add_child(_start)
	column.add_child(buttons)
	return column


func _opponent_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(280, 0)
	# Tighter than the other columns, so the boss's longer column still fits 720p with Large text.
	var column := Ui.vbox(Metrics.S)
	panel.add_child(column)
	column.add_child(Ui.label("YOUR OPPONENT", "Eyebrow"))
	column.add_child(Ui.label(_opponent["name"], "H2"))
	var difficulty_color := Palette.OXBLOOD_INK if Ui.is_boss(_opponent_id) else Palette.IVORY_SOFT
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
		var token := PieceToken.create(30, PieceData.new(entry["type"]), 1)
		pieces.add_child(token)
		token.mouse_filter = Control.MOUSE_FILTER_PASS  # after _ready, so the tooltip shows
		worth += GameConfig.piece_value(entry["type"])
	column.add_child(pieces)
	var material := Ui.label("%d points of material on the board" % worth, "Caption")
	material.tooltip_text = "Capturing a piece scores its value; first to %d points (or to take the king) wins" % int(GameConfig.value("match", "target_score"))
	material.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(material)
	column.add_child(Ui.label("DECK", "Eyebrow"))
	var deck := HFlowContainer.new()
	deck.add_theme_constant_override("h_separation", Metrics.XS + 2)
	deck.add_theme_constant_override("v_separation", Metrics.XS + 2)
	for card_type: String in _opponent["deck"]:
		var view := CardView.create(CardData.new(card_type), OPPONENT_CARD)
		view.is_interactive = false
		view.is_inspectable = true
		# Too small for a ≥ 12 px cost figure: the cost is in the tooltip.
		view.show_cost = false
		deck.add_child(view)
	column.add_child(deck)
	column.add_child(Ui.label("ARTIFACTS", "Eyebrow"))
	var count := int(_opponent["artifact_count"])
	var artifact_text := "None" if count == 0 else "%d random artifact%s, revealed when the match starts" % [count, "" if count == 1 else "s"]
	column.add_child(Ui.wrapped(artifact_text, "Body" if count == 0 else "Strong", 240))
	# The stakes close the column at the bottom (like the map's legend), so it
	# ends on something you need instead of empty space.
	column.add_child(Ui.spacer())
	var stakes := Ui.wrapped("To win: reach %d points first, or take their king. A win pays +%d training points and a card." % [
		int(GameConfig.value("match", "target_score")), int(GameConfig.value("economy", "win_points"))], "Caption", 240)
	column.add_child(stakes)
	return panel


func _refresh() -> void:
	if _selected == null and _cursor.has_focus():
		_cursor.release_focus()
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
		_message.add_theme_color_override("font_color", Palette.OXBLOOD_INK)
	elif _selected != null and _cursor.has_focus():
		_show_cursor_hint()
	elif _selected != null:
		_message.text = "Place your %s on a highlighted square" % _selected.type
		_message.add_theme_color_override("font_color", Palette.BRASS)
	else:
		_message.text = "%d pieces ready · %d budget left" % [_roster.size(), Game.run.deploy_budget() - cost]
		_message.add_theme_color_override("font_color", Palette.IVORY_SOFT)


func _refresh_list() -> void:
	_fit_list.call_deferred()
	# Rows are rebuilt: keep keyboard focus on the same piece's row.
	var focused := (get_viewport().gui_get_focus_owner() if is_inside_tree() else null) as RosterRow
	var focus_piece: PieceData = focused.piece if focused != null else null
	var focus_visible := focused != null and focused.has_focus(true)
	Ui.clear(_list)
	var pieces := Game.run.collection.duplicate()
	pieces.sort_custom(func(a: PieceData, b: PieceData) -> bool: return a.deploy_cost() > b.deploy_cost())
	for piece: PieceData in pieces:
		var row := _piece_row(piece)
		_list.add_child(row)
		if piece == focus_piece:
			row.grab_focus(not focus_visible)


func _piece_row(piece: PieceData) -> RosterRow:
	var row := RosterRow.new()
	row.padding = 8
	row.piece = piece
	row.is_selected = piece == _selected
	row.tooltip_text = Ui.piece_tooltip(piece) + ("\n" + KING_HINT if piece.type == "king" else "")
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
	# Placed pieces dim their token only; the text keeps full contrast.
	text.add_child(Ui.label(Ui.piece_name(piece.type), "Strong"))
	var detail := "Always plays" if piece.type == "king" else ("On the board" if on_board else "Benched")
	if piece.upgrade != "":
		detail = "%s · %s" % [Ui.upgrade_name("piece", piece.upgrade), detail]
	text.add_child(Ui.label(detail, "Caption", Palette.BRASS if piece.upgrade != "" else Palette.IVORY_FAINT))
	content.add_child(text)
	var cost := Ui.label("free" if piece.type == "king" else str(piece.deploy_cost()), "Strong", Palette.BRASS)
	content.add_child(cost)
	token.modulate.a = 0.5 if on_board and piece != _selected else 1.0
	row.pressed.connect(_on_row_pressed.bind(piece))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			row.accept_event()
			_on_row_key(piece))
	return row


## Enter on a collection row: pick up a benched piece (or the king) and choose
## its square with the board cursor; bench a placed piece.
func _on_row_key(piece: PieceData) -> void:
	if piece.type != "king" and _square_of(piece) != BoardView.NO_SQUARE:
		_bench(piece)
		return
	var square := _square_of(piece) if piece.type == "king" else _first_free_square()
	if square == BoardView.NO_SQUARE:
		Feel.refuse(_message, _message, "No free square left: bench a piece first")
		return
	_selected = piece
	Sfx.play("piece_pickup")
	_cursor.carry(piece, square)
	_cursor.grab_focus()
	_refresh()


## The cursor stops only where Enter can do something: a free square, the
## carried piece's own square, or (for a piece already on the board, like the
## king) a placed piece to swap with. Occupied squares are skipped for a benched piece.
func _cursor_can_take(square: Vector2i) -> bool:
	var occupant := _piece_on(square)
	return occupant == null or occupant == _selected or _square_of(_selected) != BoardView.NO_SQUARE


## The message line says what Enter will do on the cursor's square.
func _show_cursor_hint() -> void:
	if _selected == null:
		return
	var occupant := _piece_on(_cursor.square)
	var carried := Ui.piece_name(_selected.type).to_lower()
	var action := "Enter places your %s" % carried
	if occupant == _selected:
		action = "Enter keeps your %s here" % carried
	elif occupant != null:
		action = "Enter swaps your %s with the %s" % [carried, Ui.piece_name(occupant.type).to_lower()]
	_message.text = "Arrows choose a square · %s · Esc puts it back" % action
	_message.add_theme_color_override("font_color", Palette.BRASS)


func _on_cursor_confirmed(square: Vector2i) -> void:
	var piece := _selected
	if piece == null:
		return
	# Same rules as dropping a dragged piece: place, put back, or swap.
	_on_dropped(square, {"roster_piece": piece})
	_focus_row(piece)


func _on_cursor_cancelled() -> void:
	var piece := _selected
	_selected = null
	Sfx.play("ui_cancel")
	_refresh()
	_focus_row(piece)


## Gives keyboard focus back to `piece`'s collection row.
func _focus_row(piece: PieceData) -> void:
	for row: RosterRow in _list.get_children():
		if row.piece == piece and not row.is_queued_for_deletion():
			row.grab_focus()
			return


## The first free deploy square: back rank first, centre files first.
func _first_free_square() -> Vector2i:
	var centre := (_board.board_size - 1) / 2.0
	var files := range(_board.board_size)
	files.sort_custom(func(a: int, b: int) -> bool: return absf(a - centre) < absf(b - centre))
	for y in _deploy_rows():
		for x: int in files:
			if _piece_on(Vector2i(x, y)) == null:
				return Vector2i(x, y)
	return BoardView.NO_SQUARE


func _refresh_board() -> void:
	_board.clear_tokens()
	var zone: Array[Vector2i] = []
	for y in int(GameConfig.value("match", "deploy_rows")):
		for x in _board.board_size:
			zone.append(Vector2i(x, y))
	_board.zone = zone
	for entry in _opponent["pieces"]:
		var token := PieceToken.create(ROSTER_TOKEN, PieceData.new(entry["type"]), 1)
		token.modulate.a = 0.85
		_board.set_token("opponent_%d_%d" % [entry["square"][0], entry["square"][1]], token, Vector2i(int(entry["square"][0]), int(entry["square"][1])))
	for entry in _roster:
		var piece: PieceData = entry["piece"]
		var token := PieceToken.create(ROSTER_TOKEN, piece)
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
	Sfx.play("piece_pickup" if _selected != null else "ui_cancel")
	_refresh()


func _on_square_clicked(square: Vector2i) -> void:
	var occupant := _piece_on(square)
	if occupant != null:
		if occupant.type == "king" and _selected != occupant:
			_selected = occupant
			Sfx.play("piece_pickup")
			_refresh()
		elif occupant != _selected:
			_bench(occupant)
		return
	if _selected == null:
		Feel.refuse(_message, _message, "Pick a piece from your collection first")
		return
	if square.y >= _deploy_rows():
		Feel.refuse(_message, _message, "Pieces go on your back %d ranks" % _deploy_rows())
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
		Feel.refuse(_message, _message, "Square taken: click that piece to bench it first")
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
	Sfx.play(_land_sound(piece.type))
	Feel.pop(_board.token(piece.uid), 1.2)


## Heavier pieces land with a heavier knock (same mapping as the match).
static func _land_sound(piece_type: String) -> String:
	match piece_type:
		"pawn", "knight":
			return "piece_land_light"
		"bishop", "rook":
			return "piece_land_medium"
	return "piece_land_heavy"


func _bench(piece: PieceData) -> void:
	Sfx.play("ui_cancel")
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
		Feel.refuse(_message, _message, setup["error"])
		return
	Sfx.play("ui_confirm")
	Game.match_setup = setup
	Game.show_phase()


## The keyboard's square cursor over the roster board: a dashed ivory square (the
## same focus shape as the menu tiles) drawn above the BoardView's tokens. Arrows
## walk the deploy squares, Enter confirms, Esc cancels. Visible only while focused.
class SquareCursor extends Control:
	signal moved
	signal confirmed(square: Vector2i)
	signal cancelled

	const GHOST_ALPHA := 0.55

	var board: BoardView
	var rows: int = 2
	## square -> whether the cursor may stop there (set by the roster screen).
	var can_take: Callable = func(_square: Vector2i) -> bool: return true
	var square: Vector2i = BoardView.NO_SQUARE:
		set(value):
			square = value
			_place_ghost()
			queue_redraw()
	var _ghost: PieceToken

	## Starts carrying `piece` (shown as a translucent ghost token) from `start`.
	func carry(piece: PieceData, start: Vector2i) -> void:
		if is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = PieceToken.create(ROSTER_TOKEN, piece)
		_ghost.modulate.a = GHOST_ALPHA
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ghost)
		square = start

	func _place_ghost() -> void:
		if not is_instance_valid(_ghost):
			return
		_ghost.visible = has_focus() and board.contains_square(square)
		if _ghost.visible:
			_ghost.position = board.square_centre(square) - _ghost.size / 2.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_ALL
		z_index = 1
		for update: Signal in [focus_entered, focus_exited, board.resized]:
			update.connect(func() -> void:
				_place_ghost()
				queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		var step := Vector2i.ZERO
		if event.is_action_pressed("ui_left"):
			step = Vector2i.LEFT
		elif event.is_action_pressed("ui_right"):
			step = Vector2i.RIGHT
		elif event.is_action_pressed("ui_up"):
			step = Vector2i(0, 1)  # up the screen is up the board (rank + 1)
		elif event.is_action_pressed("ui_down"):
			step = Vector2i(0, -1)
		elif event.is_action_pressed("ui_accept"):
			accept_event()
			confirmed.emit(square)
			return
		elif event.is_action_pressed("ui_cancel"):
			accept_event()
			cancelled.emit()
			return
		else:
			return
		accept_event()
		# Steps past squares it can't stop on (e.g. taken ones for a benched piece).
		var next := square + step
		while next.x >= 0 and next.x < board.board_size and next.y >= 0 and next.y < rows:
			if can_take.call(next):
				square = next
				Sfx.play("ui_hover")
				moved.emit()
				return
			next += step

	func _draw() -> void:
		if has_focus() and board.contains_square(square):
			# A dark under-stroke keeps the ivory dashes visible on the light squares.
			var rect := board.square_rect(square).grow(-3.0)
			draw_rect(rect, Palette.WALNUT_DEEP, false, 4.0)
			SelectTile.draw_dashed_ring(self, rect)
