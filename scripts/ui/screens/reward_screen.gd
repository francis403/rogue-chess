extends Control
## After a win: take one of three cards, or skip for training points.

var _is_done: bool = false
var _status: Label


func _ready() -> void:
	var run := Game.run
	var win_points := int(GameConfig.value("economy", "win_points"))
	var skip_points := int(GameConfig.value("economy", "reward_skip_points"))
	var body := Ui.frame(self, "Victory · reward", "Add a card to your deck",
		"You earned +%d training points. Pick one card, or skip it for +%d more." % [win_points, skip_points])
	var row := Ui.hbox(32)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var offers := run.reward_offers()
	for index in offers.size():
		row.add_child(_offer(offers[index], index))
	_status = Ui.status_label()
	body.add_child(_status)
	var footer := Ui.footer(body)
	footer.add_child(Ui.label("Deck: %d cards" % run.deck.size(), "Body"))
	var skip := Ui.button("Skip · +%d point" % skip_points)
	skip.pressed.connect(_skip)
	footer.add_child(skip)


func _offer(card: CardData, index: int) -> VBoxContainer:
	var column := Ui.vbox(12)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var view := CardView.create(card, Vector2(150, 210))
	view.pressed.connect(_take.bind(index, view))
	column.add_child(Ui.centered(view))
	var name_label := Ui.label(card.display_name(), "H2")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var what := "Moves any one piece" if card.type == "move" else "Moves one %s" % card.type
	var detail := Ui.label("%s · cost %d · %s" % ["Rare" if card.is_rare() else "Normal", card.cost(), what], "Caption")
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	return column


func _take(index: int, view: CardView) -> void:
	if _is_done:
		return
	_is_done = true
	var result := Game.run.take_reward(index)
	if not _accepted(result):
		Ui.shake(view)
		return
	view.is_selected = true
	Ui.pop(view, 1.08)
	var pause := create_tween()
	pause.tween_interval(0.3)
	await pause.finished
	Game.show_phase()


func _skip() -> void:
	if _is_done:
		return
	_is_done = true
	if _accepted(Game.run.skip_reward()):
		Game.show_phase()


## On a refusal: show why and let the player choose again.
func _accepted(result: Dictionary) -> bool:
	if result["ok"]:
		return true
	_is_done = false
	Ui.flash_status(_status, result["error"])
	return false
