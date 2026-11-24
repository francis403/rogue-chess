extends Control
## Coaching: each offer is one upgrade for one card or piece. Accept (pay) or decline each.
## Feel: accepting plays ui_confirm and the offer glows brass; declining plays
## ui_cancel and the offer sinks (darker face, faint border, the item art dims;
## its text keeps AA contrast); a refusal plays ui_error. Keyboard: Tab / arrows move, Enter presses,
## 1-9 jump to an offer's Accept button.
## Hierarchy: Accept is a standard (outlined) button, Decline a quiet one, and
## "Leave coaching" the one filled primary action. Items show at full card size
## (names ≥ 12 px); a declined card sinks like an unplayable one (hollow coin,
## dim glyph) instead of fading, so its cost stays readable.

var _status: Label
var _grid: GridContainer
var _leave: Button
var _panels: Array[PanelContainer] = []
## First button of each offer (Accept while open), for the 1-9 keys and focus after a rebuild.
var _offer_buttons: Array[Button] = []
var _points_before: int = 0


func _ready() -> void:
	var body := Ui.frame(self, "Floor %d · coaching" % int(Game.run.current_node_info()["floor"]), "Training with the coach",
		"Each offer upgrades one specific card or piece for the rest of the run. One upgrade per item.")
	# Offers, status and Leave sit together in the middle of the screen.
	var block := Ui.centre_block(body, Metrics.L)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", Metrics.L)
	_grid.add_theme_constant_override("v_separation", Metrics.L)
	block.add_child(Ui.centered(_grid))
	_status = Ui.status_label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(_status)
	_leave = Ui.button("Leave coaching", "PrimaryButton")
	_leave.custom_minimum_size.x = Metrics.SET_TILE_WIDTH / 2
	_leave.pressed.connect(func() -> void:
		if Game.run.leave_coaching()["ok"]:
			Game.show_phase())
	Ui.actions(block).add_child(_leave)
	_rebuild()
	_focus_offer(0)


func _unhandled_input(event: InputEvent) -> void:
	var index := A11y.number_key(event)
	if index >= 0 and index < _offer_buttons.size() and _offer_buttons[index] != null:
		get_viewport().set_input_as_handled()
		A11y.focus_first([_offer_buttons[index]])


func _rebuild() -> void:
	_points_before = Game.run.points
	Ui.clear(_grid)
	_panels.clear()
	_offer_buttons.clear()
	var offers := Game.run.coaching_offers()
	if offers.is_empty():
		_grid.add_child(Ui.label("Everything you own is already upgraded. Nothing to train today.", "Body"))
	for index in offers.size():
		var panel := _offer_panel(offers[index], index)
		_grid.add_child(panel)
		_panels.append(panel)
	A11y.focus_all(self)


## Focuses the first open offer from `index` on (then any, then Leave).
func _focus_offer(index: int) -> void:
	var order: Array = []
	order.append_array(_offer_buttons.slice(index))
	order.append_array(_offer_buttons.slice(0, index))
	order.append(_leave)
	A11y.focus_first(order)


func _offer_panel(offer: Dictionary, index: int) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(380, 0)
	var is_declined: bool = offer["state"] == "declined"
	if is_declined:
		panel.add_theme_stylebox_override("panel", UiTheme.box(Palette.WALNUT, Palette.RULE_SOFT, UiTheme.RADIUS, Metrics.L))
	var row := Ui.hbox(Metrics.L)
	panel.add_child(row)
	var art: Control
	if offer["kind"] == "card":
		art = CardView.create(offer["item"], CardView.SIZE)
		art.is_interactive = false
		art.is_playable = not is_declined
	else:
		# Centred in a card-wide slot, so card and piece offers line their text up.
		var token := PieceToken.create(Metrics.COACH_TOKEN, offer["item"])
		# Declined: only the (decorative) token dims; every text keeps its contrast.
		if is_declined:
			token.modulate.a = 0.45
		art = CenterContainer.new()
		art.custom_minimum_size.x = CardView.SIZE.x
		art.add_child(token)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var column := Ui.vbox(Metrics.XS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var item_name: String = offer["item"].display_name() if offer["kind"] == "card" else Ui.piece_name(offer["item"].type)
	var item_tooltip: String = Ui.card_tooltip(offer["item"]) if offer["kind"] == "card" else Ui.piece_tooltip(offer["item"])
	panel.tooltip_text = "%s\nUpgrade: %s · %s" % [item_tooltip, offer["upgrade_name"], Ui.upgrade_desc(offer["kind"], offer["upgrade"])]
	column.add_child(Ui.label("%s %s" % [item_name, offer["kind"]], "Caption"))
	column.add_child(Ui.label(offer["upgrade_name"], "H2", Palette.IVORY_SOFT if is_declined else Palette.BRASS))
	column.add_child(Ui.wrapped(Ui.upgrade_desc(offer["kind"], offer["upgrade"]), "Body", 220))
	var buttons := Ui.hbox(Metrics.S)
	var first_button: Button = null
	match offer["state"]:
		"accepted":
			buttons.add_child(Ui.chip("Accepted · upgraded", Palette.FELT))
		"declined":
			buttons.add_child(Ui.chip("Declined", Palette.IVORY_FAINT))
		_:
			var accept := Ui.button("Accept · %d pt" % offer["price"], "Button")
			accept.set_meta("sfx", "none")
			Ui.fix_width(accept, [accept.text, "%d pt · can't afford" % offer["price"]])
			accept.tooltip_text = "Pay %d training points: %s gets %s for the rest of the run" % [offer["price"], item_name, offer["upgrade_name"]]
			accept.disabled = Game.run.points < offer["price"]
			if accept.disabled:
				accept.text = "%d pt · can't afford" % offer["price"]
				accept.tooltip_text = "Not enough points: you have %d, it costs %d" % [Game.run.points, offer["price"]]
			accept.pressed.connect(func() -> void:
				if _is_locked(accept):
					return
				_apply(Game.run.accept_coaching(index), "%s learned %s" % [item_name, offer["upgrade_name"]], index))
			buttons.add_child(accept)
			var decline := Ui.button("Decline", "QuietButton")
			decline.set_meta("sfx", "none")
			decline.tooltip_text = "Turn this offer down (it can't be taken later this visit)"
			decline.pressed.connect(func() -> void:
				if _is_locked(decline):
					return
				_apply(Game.run.decline_coaching(index), "", index, "ui_cancel"))
			buttons.add_child(decline)
			first_button = decline if accept.disabled else accept
	_offer_buttons.append(first_button)
	column.add_child(buttons)
	return panel


## One press per button: a second press in the same frame is ignored.
func _is_locked(button: Button) -> bool:
	if button.disabled:
		return true
	button.disabled = true
	return false


## Applies an accept / decline result. `index` is the offer (it glows when an
## upgrade was learned); `sound` plays on success.
## Every other offer stays open: the API allows one accept per offer (one
## upgrade per item), not one per visit. Accepting floats "−N pt" up from the
## item's top edge, on the toast's opaque plate, so it never smudges the glyph.
func _apply(result: Dictionary, success_text: String, index: int = -1, sound: String = "ui_confirm") -> void:
	# Measured before the rebuild (the rebuilt offer takes the same place): the
	# points rise from the item's top edge, clear of its glyph and the "Accepted" chip.
	var art: Control = _panels[index].get_child(0).get_child(0) if index >= 0 and index < _panels.size() else null
	var from := Vector2.ZERO
	if is_instance_valid(art):
		from = Feel.centre_in(art, self) - Vector2(0, art.size.y / 2.0)
	var spent := _points_before - Game.run.points
	_rebuild()
	_focus_offer(maxi(index, 0))
	if not result["ok"]:
		Feel.refuse(null, _status, result["error"])
		return
	Sfx.play(sound)
	_status.text = success_text
	_status.add_theme_color_override("font_color", Palette.FELT)
	if sound == "ui_confirm" and index >= 0 and index < _panels.size():
		Feel.glow(_panels[index])
	if spent > 0 and from != Vector2.ZERO:
		Feel.float_text(self, "−%d pt" % spent, from, Palette.BRASS, 0, true)
	Game.notify_changed()
