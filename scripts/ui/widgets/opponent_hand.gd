class_name OpponentHand
extends HBoxContainer
## The opponent's hand in the match's side panel: the cards the player may see
## face up (CardView minis: glyph and cost, the name in the tooltip), then the
## hidden ones as card backs. `caption` counts them ("3 shown · 2 hidden") and
## `names_line` names the shown cards in text ("Queen · Move · Pawn"), so they
## don't hide behind mouse tooltips; the owner places both. Fed only ChessMatch.visible_opponent_hand() and
## hidden_card_count(), so a hidden card's face never reaches the tree.

## The width the cards may take: the side column less its panel's padding. Past
## it the cards overlap instead of widening the column.
const WIDTH := Metrics.SIDE_COLUMN - 2 * Metrics.L
const GAP := Metrics.XS

var caption: Label = Ui.label("", "Caption")
var names_line: Label = Ui.wrapped("", "Caption", WIDTH)


func _init() -> void:
	# Holds its height with no cards, so the panel never jumps as the hand empties.
	custom_minimum_size.y = CardView.MINI.y
	add_theme_constant_override("separation", GAP)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Shows `cards` face up, then `hidden` backs. Returns the faces that were not
## shown before (just revealed). A row that already shows exactly that is left
## alone, so a running flip is never cut short.
func show_hand(cards: Array[CardData], hidden: int) -> Array[CardView]:
	var shown_uids := faces().map(func(face: CardView) -> int: return face.card.uid)
	var fresh: Array[CardView] = []
	if cards.map(func(card: CardData) -> int: return card.uid) == shown_uids and hidden == back_count():
		return fresh
	Ui.clear(self)
	for card in cards:
		var face := CardView.create_mini(card)
		add_child(face)
		if not shown_uids.has(card.uid):
			fresh.append(face)
	for i in hidden:
		var back := CardView.create_back()
		back.is_inspectable = true
		back.tooltip_text = "Hidden card · a Scout reveals it"
		add_child(back)
	_refresh()
	return fresh


## The opponent played the card `uid`: its face goes, or a back if it was hidden.
func remove_card(uid: int) -> void:
	var gone: Node = null
	for face in faces():
		if face.card.uid == uid:
			gone = face
	if gone == null and back_count() > 0:
		gone = get_child(get_child_count() - 1)
	if gone != null:
		remove_child(gone)
		gone.queue_free()
	_refresh()


func faces() -> Array[CardView]:
	var found: Array[CardView] = []
	for view: CardView in get_children():
		if not view.is_back:
			found.append(view)
	return found


func back_count() -> int:
	return get_child_count() - faces().size()


static func caption_text(shown: int, hidden: int) -> String:
	if shown + hidden == 0:
		return "no cards"
	if hidden == 0:
		return "all shown"
	if shown == 0:
		return "all hidden"
	return "%d shown · %d hidden" % [shown, hidden]


## Overlaps the cards only when they would not fit WIDTH; updates the caption.
func _refresh() -> void:
	var count := get_child_count()
	var gap := GAP
	if count > 1:
		gap = mini(GAP, floori((WIDTH - count * CardView.MINI.x) / (count - 1)))
	add_theme_constant_override("separation", gap)
	caption.text = caption_text(faces().size(), back_count())
	names_line.text = " · ".join(faces().map(func(face: CardView) -> String: return face.card.display_name()))


## The cards drop away and fade (only fade with reduced motion): the opponent
## discarded its hand. The row is rebuilt when the next hand is dealt.
func sweep_out(duration: float) -> void:
	for view: CardView in get_children():
		var tween := Motion.tween(view, "in").set_parallel()
		tween.tween_property(view, "modulate:a", 0.0, duration)
		if not Motion.reduced():
			view.pivot_offset = CardView.MINI / 2.0
			tween.tween_property(view, "scale", Vector2.ONE * 0.85, duration)
