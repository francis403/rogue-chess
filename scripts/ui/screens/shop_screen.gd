extends Control
## Shop: buy cards and pieces, remove one card. Sold and unaffordable states are shown
## in words on the button, not only by its colour.
## Feel: a purchase plays ui_purchase, pops "Bought …" on a plate over the bought
## item and floats the points spent up from it (inside the offer's panel, clear of
## captions and borders), and the HUD points pop; a refusal
## plays ui_error and shakes the status line under the offers. Keyboard: Tab / arrows move between offers,
## Enter buys, 1-9 jump to an offer's button, Esc closes the card-removal chooser.
## Hierarchy: Buy is a standard (outlined) button; "Leave the shop" is the one
## filled primary action.

var _status: Label
var _content: HBoxContainer
var _leave: Button
## Offer buttons in screen order (cards, pieces, removal): the 1-9 keys and focus after a rebuild.
var _offer_buttons: Array[Button] = []
var _points_before: int = 0
var _removal_column: Control


func _ready() -> void:
	var body := Ui.frame(self, "Floor %d · shop" % int(Game.run.current_node_info()["floor"]), "The Club Shop",
		"Spend training points. Each offer can be bought once.")
	# Offers, status and Leave sit together in the middle; the three panels share one height.
	var block := Ui.centre_block(body, Metrics.L)
	_content = Ui.hbox(Metrics.XL)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(_content)
	_status = Ui.status_label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(_status)
	_leave = Ui.button("Leave the shop", "PrimaryButton")
	_leave.custom_minimum_size.x = Metrics.SET_TILE_WIDTH / 2
	_leave.pressed.connect(func() -> void:
		if Game.run.leave_shop()["ok"]:
			Game.show_phase())
	Ui.actions(block).add_child(_leave)
	_rebuild()
	_focus_offer(0)


func _unhandled_input(event: InputEvent) -> void:
	var index := A11y.number_key(event)
	if index >= 0 and index < _offer_buttons.size():
		get_viewport().set_input_as_handled()
		_offer_buttons[index].grab_focus()


func _rebuild() -> void:
	Ui.clear(_content)
	_offer_buttons.clear()
	_points_before = Game.run.points
	var offers := Game.run.shop_offers()
	_content.add_child(_section("CARDS", _card_offers(offers["cards"])))
	_content.add_child(_section("PIECES", _piece_offers(offers["pieces"])))
	_content.add_child(_section("SERVICES", _removal(offers)))
	A11y.focus_all(self)


## Focuses the first enabled offer button from `index` on (then any, then Leave).
func _focus_offer(index: int) -> void:
	var order: Array = []
	order.append_array(_offer_buttons.slice(index))
	order.append_array(_offer_buttons.slice(0, index))
	order.append(_leave)
	A11y.focus_first(order)


func _section(title: String, content: Control) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.size_flags_vertical = Control.SIZE_FILL
	var column := Ui.vbox(Metrics.L)
	panel.add_child(column)
	column.add_child(Ui.label(title, "Eyebrow"))
	column.add_child(content)
	return panel


func _card_offers(offers: Array) -> HBoxContainer:
	var row := Ui.hbox(Metrics.L)
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var column := Ui.vbox(Metrics.S)
		column.custom_minimum_size.x = 156
		column.tooltip_text = Ui.card_tooltip(offer["card"])
		var view := CardView.create(offer["card"], Vector2(124, 174))
		view.is_interactive = false
		view.is_playable = not offer["sold"]
		column.add_child(view)
		var rarity := Ui.label("Rare" if offer["card"].is_rare() else "Normal", "Caption", Palette.BRASS if offer["card"].is_rare() else Palette.IVORY_FAINT)
		rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(rarity)
		column.add_child(_buy_button(offer, func() -> Dictionary: return Game.run.buy_card(index), view))
		row.add_child(column)
	return row


func _piece_offers(offers: Array) -> VBoxContainer:
	var column := Ui.vbox(Metrics.M)
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var piece: PieceData = offer["piece"]
		var row := Ui.hbox(Metrics.M)
		row.tooltip_text = Ui.piece_tooltip(piece)
		var token := PieceToken.create(56, piece)
		token.modulate.a = 0.45 if offer["sold"] else 1.0
		row.add_child(token)
		var text := Ui.vbox(Metrics.XS)
		text.custom_minimum_size.x = 156
		text.add_child(Ui.label(Ui.piece_name(piece.type), "Strong"))
		text.add_child(Ui.label("%s · deploy %d" % [Ui.piece_set_name(piece.piece_set), piece.deploy_cost()], "Caption"))
		text.add_child(_buy_button(offer, func() -> Dictionary: return Game.run.buy_piece(index), row))
		row.add_child(text)
		column.add_child(row)
	return column


func _removal(offers: Dictionary) -> VBoxContainer:
	var column := Ui.vbox(Metrics.S)
	column.custom_minimum_size.x = 220
	column.add_child(Ui.label("Remove a card", "Strong"))
	column.add_child(Ui.wrapped("Thin your deck so your best cards come up more often. Minimum %d cards." % int(GameConfig.value("economy", "min_deck_size")), "Body", 220))
	var price: int = offers["remove_price"]
	var button := Ui.button("Choose a card · %d pt" % price)
	button.tooltip_text = "Pick one card to remove from your deck for good (%d pt). Esc cancels." % price
	if offers["removes_left"] <= 0:
		button.text = "Done for this visit"
		button.disabled = true
	elif Game.run.points < price:
		button.disabled = true
		button.tooltip_text = "Not enough points: you have %d, it costs %d" % [Game.run.points, price]
	button.pressed.connect(_open_removal)
	column.add_child(button)
	_offer_buttons.append(button)
	_removal_column = column
	return column


## `item` is the offer's card or piece row: the purchase feedback appears on it.
func _buy_button(offer: Dictionary, buy: Callable, item: Control) -> Button:
	var button := Ui.button("Buy · %d pt" % offer["price"], "Button")
	button.set_meta("sfx", "none")
	var details := Ui.card_tooltip(offer["card"]) if offer.has("card") else Ui.piece_tooltip(offer["piece"])
	button.tooltip_text = "%s\nBuy for %d training points" % [details, offer["price"]]
	if offer["sold"]:
		button.text = "Sold"
		button.disabled = true
	elif Game.run.points < offer["price"]:
		button.text = "%d pt · can't afford" % offer["price"]
		button.disabled = true
		button.tooltip_text = "%s\nNot enough points: you have %d" % [details, Game.run.points]
	button.pressed.connect(func() -> void:
		if button.disabled:
			return
		button.disabled = true
		_apply(buy.call(), "Bought %s" % _item_name(offer), button, item))
	_offer_buttons.append(button)
	return button


func _item_name(offer: Dictionary) -> String:
	return offer["card"].display_name() if offer.has("card") else Ui.piece_name(offer["piece"].type)


func _open_removal() -> void:
	var overlay := ItemOverlay.new()
	add_child(overlay)
	var removal_button: Button = _offer_buttons[-1] if not _offer_buttons.is_empty() else null
	overlay.show_cards("Remove a card", Game.run.deck, func(card: CardData) -> void:
		_apply(Game.run.remove_card(card.uid), "Removed %s" % card.display_name(), removal_button, _removal_column),
		"Click a card (or pick it with the arrows and Enter) to remove it from your deck · Esc cancels")


## Applies a buy / removal result. `source` is the pressed button (focus stays on
## that slot); `item` the bought card or piece row: "Bought …" pops on its centre
## and the spent points float up from just above that plate (the status line
## without one).
func _apply(result: Dictionary, success_text: String, source: Control = null, item: Control = null) -> void:
	var focus_index := _offer_buttons.find(source)
	# Measured before the rebuild: the rebuilt offer takes the same place.
	var anchor: Control = item if is_instance_valid(item) else _status
	var at := Feel.centre_in(anchor, self)
	var spent := _points_before - Game.run.points
	_rebuild()
	_focus_offer(maxi(focus_index, 0))
	if not result["ok"]:
		Feel.refuse(null, _status, result["error"])
		return
	Sfx.play("ui_purchase")
	_status.text = ""
	var toast := Feel.toast(self, success_text, at)
	if spent > 0:
		Feel.float_text(self, "−%d pt" % spent, at - Vector2(0, toast.size.y * 0.5 + Metrics.L), Palette.BRASS)
	Game.notify_changed()
