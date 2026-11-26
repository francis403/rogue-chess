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
## The row was swept out (faded): the next show_hand rebuilds it even if the new
## hand has the same cards in the same order (a reshuffle can deal that).
var _is_swept: bool = false
## The names names_line tells (kept to re-break its lines when the text size changes).
var _names: Array = []


func _init() -> void:
	# Holds its height with no cards, so the panel never jumps as the hand empties.
	custom_minimum_size.y = CardView.MINI.y
	add_theme_constant_override("separation", GAP)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Deferred: the label reads its new text size only after the signal.
	names_line.theme_changed.connect(_break_names, CONNECT_DEFERRED)


## Shows `cards` face up, then `hidden` backs. Returns the faces that were not
## shown before (just revealed). A row that already shows exactly that is left
## alone, so a running flip is never cut short. With `hold_text` the caption and
## names keep telling the old row until refresh_text() (a Scout's flips first).
func show_hand(cards: Array[CardData], hidden: int, hold_text: bool = false) -> Array[CardView]:
	var shown_uids := faces().map(func(face: CardView) -> int: return face.card.uid)
	var fresh: Array[CardView] = []
	if cards.map(func(card: CardData) -> int: return card.uid) == shown_uids and hidden == back_count() and not _is_swept:
		return fresh
	_is_swept = false
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
	_relayout()
	if not hold_text:
		refresh_text()
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
	_relayout()
	refresh_text()


func faces() -> Array[CardView]:
	var found: Array[CardView] = []
	for view in _cards():
		if not view.is_back:
			found.append(view)
	return found


func back_count() -> int:
	return _cards().size() - faces().size()


## The row's cards (any other child, a spacer say, is skipped).
func _cards() -> Array[CardView]:
	var found: Array[CardView] = []
	for child in get_children():
		if child is CardView:
			found.append(child)
	return found


static func caption_text(shown: int, hidden: int) -> String:
	if shown + hidden == 0:
		return "no cards"
	if hidden == 0:
		return "all shown"
	if shown == 0:
		return "all hidden"
	return "%d shown · %d hidden" % [shown, hidden]


## Overlaps the cards only when they would not fit WIDTH. The gap depends only
## on the card count, so a reveal (same count) never moves a card.
func _relayout() -> void:
	var count := _cards().size()
	var gap := GAP
	if count > 1:
		gap = mini(GAP, floori((WIDTH - count * CardView.MINI.x) / (count - 1)))
	add_theme_constant_override("separation", gap)


## The caption and the names line say what the row shows now.
func refresh_text() -> void:
	var shown := faces()
	caption.text = caption_text(shown.size(), back_count())
	_names = shown.map(func(face: CardView) -> String: return face.card.display_name())
	_break_names()


func _break_names() -> void:
	names_line.text = names_text(_names, names_line.get_theme_font("font"), names_line.get_theme_font_size("font_size"))


## "Queen · Move · Pawn", broken into lines of at most WIDTH between names, so
## a wrap never leaves a "·" dangling at a line end. Each name and the space
## before each "·" are non-breaking (NBSP), so the label's own wrap can't split them.
static func names_text(card_names: Array, font: Font, font_size: int) -> String:
	const NBSP := "\u00a0"
	var lines: PackedStringArray = []
	var line := ""
	for card_name: String in card_names:
		var token := card_name.replace(" ", NBSP)
		var longer := token if line == "" else line + NBSP + "· " + token
		if line != "" and font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > WIDTH:
			lines.append(line)
			longer = token
		line = longer
	if line != "":
		lines.append(line)
	return "\n".join(lines)


## The cards drop away and fade (only fade with reduced motion): the opponent
## discarded its hand. The row is rebuilt when the next hand is dealt.
func sweep_out(duration: float) -> void:
	_is_swept = true
	for view in _cards():
		var tween := Motion.tween(view, "in").set_parallel()
		tween.tween_property(view, "modulate:a", 0.0, duration)
		if not Motion.reduced():
			view.pivot_offset = CardView.MINI / 2.0
			tween.tween_property(view, "scale", Vector2.ONE * 0.85, duration)
