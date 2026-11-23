extends Control
## Pick the starting piece set. Locked sets show how to unlock them.
## Keyboard: arrows / Tab move between sets, Enter picks, 1-9 picks directly.

var _status: Label
var _has_chosen: bool = false
var _tiles: Array[SelectTile] = []
var _set_ids: Array[String] = []


func _ready() -> void:
	var body := Ui.frame(self, "New run · step 1", "Choose your piece set", "The set applies to every piece you own this run, including pieces you buy.")
	# Tiles, status and Back sit together in the middle of the screen.
	var block := Ui.centre_block(body)
	var row := Ui.hbox(Metrics.XL)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(row)
	var sets := Game.run.available_piece_sets()
	for index in sets.size():
		var tile := _set_tile(sets[index], index)
		row.add_child(tile)
		_tiles.append(tile)
		_set_ids.append(sets[index]["id"])
	_status = Ui.status_label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(_status)
	var actions := Ui.actions(block)
	actions.add_child(Ui.label("Enter or a number key picks a set", "Caption"))
	var back := Ui.button("Back to title", "QuietButton")
	back.pressed.connect(func() -> void: Game.show_title())
	actions.add_child(back)
	A11y.focus_all(self)
	A11y.focus_first(_tiles.filter(func(tile: SelectTile) -> bool: return not tile.is_locked))


func _unhandled_input(event: InputEvent) -> void:
	var index := A11y.number_key(event)
	if index >= 0 and index < _tiles.size():
		get_viewport().set_input_as_handled()
		_choose(_set_ids[index], _tiles[index])


## A set tile: name and number key, the pieces with what each is worth under it
## (a small table, not a sentence), the set's rules as short lines (one per rule,
## read from its config, so both tiles carry a similar amount), and the call to
## action. Both tiles stretch to the taller one, so the row stays even.
func _set_tile(piece_set: Dictionary, index: int) -> SelectTile:
	var tile := SelectTile.new()
	tile.custom_minimum_size.x = Metrics.SET_TILE_WIDTH
	tile.size_flags_vertical = Control.SIZE_FILL
	tile.is_locked = piece_set["locked"]
	tile.tooltip_text = "%s\n%s" % [piece_set["desc"], "Locked: beat the boss to unlock" if piece_set["locked"] else "Press Enter or %d to start with this set" % (index + 1)]
	var column := Ui.vbox(Metrics.L)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var title := Ui.hbox(Metrics.S)
	title.add_child(Ui.label(piece_set["name"], "H1"))
	title.add_child(Ui.spacer())
	title.add_child(Ui.key_cap(str(index + 1)))
	column.add_child(title)
	column.add_child(_worth_table(piece_set))
	column.add_child(_rule_lines(piece_set["id"]))
	column.add_child(Ui.spacer())
	column.add_child(Ui.rule(Palette.RULE_SOFT))
	if piece_set["locked"]:
		column.add_child(Ui.label("Locked · Beat the boss to unlock", "Strong", Palette.OXBLOOD_INK))
	else:
		column.add_child(Ui.label("Start with %s pieces  →" % piece_set["name"], "Strong", Palette.BRASS))
	tile.pressed.connect(_choose.bind(piece_set["id"], tile))
	return tile


## The set's rules, one short line each, from config/piece_sets.json.
func _rule_lines(set_id: String) -> VBoxContainer:
	var data: Dictionary = GameConfig.data("piece_sets")["sets"][set_id]
	var lines: Array[String] = []
	var modifier := int(data.get("value_modifier", 0))
	if modifier == 0:
		lines.append("Classic worth: the pick cost and the points for capturing it.")
	else:
		lines.append("Each piece is worth %d less: cheaper to field, fewer points when taken." % -modifier)
	if data.has("burn_turns"):
		lines.append("Once moved, a piece burns for %d turns, then is lost (it counts as captured)." % int(data["burn_turns"]))
	else:
		lines.append("Nothing burns: a piece stays until it is captured.")
	if data.has("capture_bonus"):
		lines.append("Captures by a burning piece give +%d points." % int(data["capture_bonus"]))
	else:
		lines.append("The steady set: a good first run.")
	var column := Ui.vbox(Metrics.S)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line in lines:
		var row := Ui.hbox(Metrics.S)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bullet := Ui.label("·", "Strong", Palette.BRASS)
		bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(bullet)
		row.add_child(Ui.wrapped(line, "Body", Metrics.SET_TILE_WIDTH - Metrics.XXXL - Metrics.L))
		column.add_child(row)
	return column


## Each piece of the set with its capture worth under it (only the tokens dim when locked).
func _worth_table(piece_set: Dictionary) -> HBoxContainer:
	var row := Ui.hbox(Metrics.XS)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for piece_type in ["pawn", "knight", "bishop", "rook", "queen", "king"]:
		var cell := Ui.vbox(Metrics.XS)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var token := PieceToken.create(Metrics.SET_TOKEN, PieceData.new(piece_type, piece_set["id"]))
		token.modulate.a = 0.45 if piece_set["locked"] else 1.0
		cell.add_child(token)
		var worth := "king" if piece_type == "king" else "worth %d" % PieceData.new(piece_type, piece_set["id"]).value()
		var caption := Ui.label(worth, "Caption")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(caption)
		row.add_child(cell)
	return row


func _choose(set_id: String, tile: SelectTile) -> void:
	if _has_chosen:
		return
	var result := Game.run.choose_piece_set(set_id)
	if not result["ok"]:
		Feel.refuse(tile, _status, result["error"])
		return
	_has_chosen = true
	Sfx.play("ui_confirm")
	tile.is_selected = true
	Feel.pop(tile, 1.03)
	create_tween().tween_callback(Game.show_phase).set_delay(Motion.time("chosen_pause"))
