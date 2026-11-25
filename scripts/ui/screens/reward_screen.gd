extends Control
## After a win: take one of three cards, or skip for training points.
## The cards deal in one after another (reward_reveal). Keyboard: arrows move
## between cards and Skip, Enter takes the focused card, 1-3 take a card directly.
## Each card wears its number key on a cap under it (the coin on the card is its
## energy cost, not a key); keyboard focus is a brass ring around the card.

var _is_done: bool = false
var _status: Label
var _views: Array[CardView] = []
var _columns: Array = []


func _ready() -> void:
	var run := Game.run
	var win_points := int(GameConfig.value("economy", "win_points"))
	var skip_points := int(GameConfig.value("economy", "reward_skip_points"))
	var body := Ui.frame(self, "Victory · reward", "Add a card to your deck",
		"You earned +%d training points. Pick one card, or skip it for +%d more." % [win_points, skip_points])
	# Cards, status and Skip sit together in the middle of the screen.
	var block := Ui.centre_block(body, Metrics.L)
	var row := Ui.hbox(Metrics.XXXL)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(row)
	var offers := run.reward_offers()
	for index in offers.size():
		var column := _offer(offers[index], index)
		row.add_child(column)
		_columns.append(column)
	_status = Ui.status_label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(_status)
	var actions := Ui.actions(block)
	actions.add_child(Ui.label("Deck: %d cards" % run.deck.size(), "Body"))
	var skip := Ui.button("Skip · +%d point" % skip_points)
	skip.set_meta("sfx", "none")
	skip.tooltip_text = "Take no card and gain +%d training point instead" % skip_points
	skip.pressed.connect(_skip.bind(skip))
	actions.add_child(skip)
	A11y.focus_all(self)
	var focus_order: Array = []
	focus_order.append_array(_views)
	focus_order.append(skip)
	A11y.focus_first(focus_order)
	Sfx.play("reward_reveal")
	Feel.reveal(_columns, 0.09, 0.08)


func _unhandled_input(event: InputEvent) -> void:
	var index := A11y.number_key(event)
	if index >= 0 and index < _views.size():
		get_viewport().set_input_as_handled()
		_take(index, _views[index])


func _offer(card: CardData, index: int) -> VBoxContainer:
	var column := Ui.vbox(Metrics.M)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var view := CardView.create(card, Metrics.REWARD_CARD)
	view.tooltip_text += "\nClick, or press %d, to add it to your deck" % (index + 1)
	view.pressed.connect(_take.bind(index, view))
	_keyboard_card(view, _take.bind(index, view))
	_views.append(view)
	# The holder draws the focus ring around the card (CardView has no focus style).
	var holder := Ui.centered(view)
	A11y.ring_on_focus(holder, view)
	column.add_child(holder)
	# Under the card: its key, then what it does (the card already shows its name).
	var what := "Moves any one piece" if card.type == "move" else "Moves one %s" % card.type
	var key_line := Ui.hbox(Metrics.S)
	key_line.alignment = BoxContainer.ALIGNMENT_CENTER
	key_line.add_child(Ui.key_cap(str(index + 1)))
	key_line.add_child(Ui.label(what, "Body"))
	column.add_child(key_line)
	var rarity := Ui.label("%s · costs %d energy" % ["Rare" if card.is_rare() else "Normal", card.cost()], "Caption", Palette.BRASS if card.is_rare() else Palette.IVORY_FAINT)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rarity)
	return column


func _take(index: int, view: CardView) -> void:
	if _is_done:
		return
	_is_done = true
	var result := Game.run.take_reward(index)
	if not _accepted(result, view):
		return
	Sfx.play("ui_confirm")
	view.is_selected = true
	Feel.pop(view, 1.08)
	create_tween().tween_callback(Game.show_phase).set_delay(Motion.time("taken_pause"))


func _skip(skip: Button = null) -> void:
	if _is_done:
		return
	_is_done = true
	if _accepted(Game.run.skip_reward(), skip):
		Sfx.play("ui_confirm")
		Game.show_phase()


## A card view takes keyboard focus (the holder rings it); Enter or Space takes it.
## Focus doesn't lift the card, so the row stays aligned; the mouse hover still does.
func _keyboard_card(view: CardView, take: Callable) -> void:
	view.focus_mode = Control.FOCUS_ALL
	view.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			view.accept_event()
			take.call())


## On a refusal: show why and let the player choose again.
func _accepted(result: Dictionary, source: Control) -> bool:
	if result["ok"]:
		return true
	_is_done = false
	Feel.refuse(source, _status, result["error"])
	return false
