extends Control
## Coaching: each offer is one upgrade for one card or piece. Accept (pay) or decline each.

var _status: Label
var _grid: GridContainer


func _ready() -> void:
	var body := Ui.frame(self, "Floor %d · coaching" % int(Game.run.current_node_info()["floor"]), "Training with the coach",
		"Each offer upgrades one specific card or piece for the rest of the run. One upgrade per item.")
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	body.add_child(_grid)
	body.add_child(Ui.spacer())
	_status = Ui.status_label()
	body.add_child(_status)
	var leave := Ui.button("Leave coaching", "PrimaryButton")
	leave.pressed.connect(func() -> void:
		if Game.run.leave_coaching()["ok"]:
			Game.show_phase())
	Ui.footer(body).add_child(leave)
	_rebuild()


func _rebuild() -> void:
	Ui.clear(_grid)
	var offers := Game.run.coaching_offers()
	if offers.is_empty():
		_grid.add_child(Ui.label("Everything you own is already upgraded. Nothing to train today.", "Body"))
	for index in offers.size():
		_grid.add_child(_offer_panel(offers[index], index))


func _offer_panel(offer: Dictionary, index: int) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(380, 0)
	var row := Ui.hbox(16)
	panel.add_child(row)
	if offer["kind"] == "card":
		var view := CardView.create(offer["item"], Vector2(72, 100))
		view.is_interactive = false
		row.add_child(view)
	else:
		row.add_child(PieceToken.create(64, offer["item"]))
	var column := Ui.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var item_name: String = offer["item"].display_name() if offer["kind"] == "card" else Ui.piece_name(offer["item"].type)
	column.add_child(Ui.label("%s %s" % [item_name, offer["kind"]], "Caption"))
	column.add_child(Ui.label(offer["upgrade_name"], "H2", Palette.BRASS))
	column.add_child(Ui.wrapped(Ui.upgrade_desc(offer["kind"], offer["upgrade"]), "Body", 220))
	var buttons := Ui.hbox(8)
	match offer["state"]:
		"accepted":
			buttons.add_child(Ui.chip("Accepted · upgraded", Palette.FELT))
		"declined":
			buttons.add_child(Ui.chip("Declined", Palette.IVORY_FAINT))
			panel.modulate.a = 0.6
		_:
			var accept := Ui.button("Accept · %d pt" % offer["price"], "PrimaryButton")
			accept.disabled = Game.run.points < offer["price"]
			if accept.disabled:
				accept.text = "%d pt · can't afford" % offer["price"]
			accept.pressed.connect(func() -> void:
				if _is_locked(accept):
					return
				_apply(Game.run.accept_coaching(index), "%s learned %s" % [item_name, offer["upgrade_name"]]))
			buttons.add_child(accept)
			var decline := Ui.button("Decline", "QuietButton")
			decline.pressed.connect(func() -> void:
				if _is_locked(decline):
					return
				_apply(Game.run.decline_coaching(index), ""))
			buttons.add_child(decline)
	column.add_child(buttons)
	return panel


## One press per button: a second press in the same frame is ignored.
func _is_locked(button: Button) -> bool:
	if button.disabled:
		return true
	button.disabled = true
	return false


func _apply(result: Dictionary, success_text: String) -> void:
	if not result["ok"]:
		_rebuild()
		Ui.flash_status(_status, result["error"])
		return
	_rebuild()
	_status.text = success_text
	_status.add_theme_color_override("font_color", Palette.FELT)
	Game.notify_changed()
