extends Control
## Shop: buy cards and pieces, remove one card. Sold and unaffordable states are shown.

var _status: Label
var _content: HBoxContainer


func _ready() -> void:
	var body := Ui.frame(self, "Floor %d · shop" % int(Game.run.current_node_info()["floor"]), "The Club Shop",
		"Spend training points. Each offer can be bought once.")
	_content = Ui.hbox(24)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	_status = Ui.status_label()
	body.add_child(_status)
	var leave := Ui.button("Leave the shop", "PrimaryButton")
	leave.pressed.connect(func() -> void:
		if Game.run.leave_shop()["ok"]:
			Game.show_phase())
	Ui.footer(body).add_child(leave)
	_rebuild()


func _rebuild() -> void:
	Ui.clear(_content)
	var offers := Game.run.shop_offers()
	_content.add_child(_section("CARDS", _card_offers(offers["cards"]), true))
	_content.add_child(_section("PIECES", _piece_offers(offers["pieces"]), false))
	_content.add_child(_section("SERVICES", _removal(offers), false))


func _section(title: String, content: Control, expand: bool) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	var column := Ui.vbox(16)
	panel.add_child(column)
	column.add_child(Ui.label(title, "Eyebrow"))
	column.add_child(content)
	return panel


func _card_offers(offers: Array) -> HBoxContainer:
	var row := Ui.hbox(16)
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var column := Ui.vbox(8)
		var view := CardView.create(offer["card"], Vector2(124, 174))
		view.is_interactive = false
		view.is_playable = not offer["sold"]
		column.add_child(view)
		column.add_child(Ui.label("Rare" if offer["card"].is_rare() else "Normal", "Caption"))
		column.add_child(_buy_button(offer, func() -> Dictionary: return Game.run.buy_card(index)))
		row.add_child(column)
	return row


func _piece_offers(offers: Array) -> VBoxContainer:
	var column := Ui.vbox(12)
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var piece: PieceData = offer["piece"]
		var row := Ui.hbox(12)
		var token := PieceToken.create(56, piece)
		token.modulate.a = 0.45 if offer["sold"] else 1.0
		row.add_child(token)
		var text := Ui.vbox(2)
		text.custom_minimum_size.x = 130
		text.add_child(Ui.label(Ui.piece_name(piece.type), "Strong"))
		text.add_child(Ui.label("%s · deploy %d" % [Ui.piece_set_name(piece.piece_set), piece.deploy_cost()], "Caption"))
		text.add_child(_buy_button(offer, func() -> Dictionary: return Game.run.buy_piece(index)))
		row.add_child(text)
		column.add_child(row)
	return column


func _removal(offers: Dictionary) -> VBoxContainer:
	var column := Ui.vbox(8)
	column.custom_minimum_size.x = 220
	column.add_child(Ui.label("Remove a card", "Strong"))
	column.add_child(Ui.wrapped("Thin your deck so your best cards come up more often. Minimum %d cards." % int(GameConfig.value("economy", "min_deck_size")), "Body", 220))
	var price: int = offers["remove_price"]
	var button := Ui.button("Choose a card · %d pt" % price)
	if offers["removes_left"] <= 0:
		button.text = "Done for this visit"
		button.disabled = true
	elif Game.run.points < price:
		button.disabled = true
		button.tooltip_text = "Not enough points"
	button.pressed.connect(_open_removal)
	column.add_child(button)
	return column


func _buy_button(offer: Dictionary, buy: Callable) -> Button:
	var button := Ui.button("Buy · %d pt" % offer["price"], "PrimaryButton")
	if offer["sold"]:
		button.text = "Sold"
		button.disabled = true
	elif Game.run.points < offer["price"]:
		button.text = "%d pt · can't afford" % offer["price"]
		button.disabled = true
	button.pressed.connect(func() -> void:
		if button.disabled:
			return
		button.disabled = true
		_apply(buy.call(), "Bought!"))
	return button


func _open_removal() -> void:
	var overlay := ItemOverlay.new()
	add_child(overlay)
	overlay.show_cards("Remove a card", Game.run.deck, func(card: CardData) -> void:
		_apply(Game.run.remove_card(card.uid), "Removed %s" % card.display_name()), "Click the card to remove it from your deck")


func _apply(result: Dictionary, success_text: String) -> void:
	if not result["ok"]:
		_rebuild()
		Ui.flash_status(_status, result["error"])
		return
	_rebuild()
	_status.text = success_text
	_status.add_theme_color_override("font_color", Palette.FELT)
	Ui.pop(_status, 1.1)
	Game.notify_changed()
