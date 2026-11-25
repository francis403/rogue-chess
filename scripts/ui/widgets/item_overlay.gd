class_name ItemOverlay
extends Control
## A modal list of cards or pieces over a dim scrim. Esc, the scrim or Close dismiss it.
## With on_pick, clicking an item calls it and closes (the shop's card removal).
## Keyboard: focus stays inside; arrows move between the items, whose details show
## in the line under the list (the tooltip's text); Enter picks; Esc or Close dismiss.
## Focus is the theme's brass ring around the item, for cards and piece rows alike.
## Identical cards (same type and upgrade) and identical pieces show once with a
## "×N" badge; cards are listed by cost, then name. Picking a group picks one copy.
## The modal hugs its content: as many columns as groups (up to a row's worth) and
## a list that scrolls only past MAX_LIST_HEIGHT. It opens with a scale + fade and
## a short deal of its items, and closes with the reverse (fade only, no deal,
## with reduced motion).

var _panel: PanelContainer
var _body: VBoxContainer
var _focus_targets: Array = []
var _detail: Label
var _release_focus: Callable
var _is_closing: bool = false

const CARD_COLUMNS := 6
const PIECE_COLUMNS := 4
## Tallest the item list grows before it scrolls.
const MAX_LIST_HEIGHT := 380.0
## The panel opens from (and closes to) this scale.
const OPEN_SCALE := 0.94
## Seconds between two items dealt in on open (unscaled, like Feel.reveal).
const DEAL_STAGGER := 0.025


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = Ui.panel("ModalPanel")
	_panel.custom_minimum_size = Vector2(Metrics.OVERLAY_MIN_WIDTH, 0)
	centre.add_child(_panel)
	_body = Ui.vbox(16)
	_panel.add_child(_body)
	_release_focus = A11y.trap_focus(self)
	Sfx.play("ui_open")
	_animate(true)


## Open: the scrim fades in fast while the panel, opaque from the first frame
## (so a faint title never floats over the screen behind), grows from
## OPEN_SCALE to full size. Close: the whole overlay fades and shrinks back.
## Reduced motion keeps only the fades.
func _animate(opening: bool) -> Tween:
	var duration := Motion.time("overlay_fade")
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if opening:
		var scrim: Control = get_child(0)
		scrim.modulate.a = 0.0
		tween.tween_property(scrim, "modulate:a", 1.0, duration * 0.6)
	else:
		tween.tween_property(self, "modulate:a", 0.0, duration)
	if not Motion.reduced():
		if opening:
			_panel.scale = Vector2.ONE * OPEN_SCALE
		# The panel's size is known after layout: centre the pivot then.
		tween.tween_callback(func() -> void: _panel.pivot_offset = _panel.size / 2.0)
		tween.tween_property(_panel, "scale", Vector2.ONE if opening else Vector2.ONE * OPEN_SCALE, duration)
	return tween


func _unhandled_input(event: InputEvent) -> void:
	if _is_closing:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	# Modal: no key reaches the screen underneath.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


## Closes at once for input and focus (and leaves its overlay host, so the game
## sees no open overlay any more), then plays the closing fade and frees itself.
func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	Sfx.play("ui_close")
	_release_focus.call()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	var host := get_parent()
	if host != null and host.get_parent() != null:
		reparent(host.get_parent())
	_animate(false).chain().tween_callback(queue_free)


func show_cards(title: String, cards: Array, on_pick: Callable = Callable(), subtitle: String = "") -> void:
	_header(title, subtitle if subtitle != "" else "%d cards" % cards.size())
	var groups := group_cards(cards)
	var grid := GridContainer.new()
	grid.columns = clampi(groups.size(), 1, CARD_COLUMNS)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 20)
	for group: Array in groups:
		var card: CardData = group[0]
		var view := CardView.create(card)
		view.is_interactive = on_pick.is_valid()
		view.is_inspectable = true
		_make_inspectable(view)
		if on_pick.is_valid():
			var pick := func() -> void:
				if _is_closing:
					return
				close()
				on_pick.call(card)
			view.pressed.connect(pick)
			_make_pickable(view, pick)
		# The holder draws the focus ring (CardView has no focus style of its own).
		var holder := Control.new()
		holder.custom_minimum_size = view.custom_minimum_size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(view)
		A11y.ring_on_focus(holder, view)
		if group.size() > 1:
			view.tooltip_text = "%d copies · %s" % [group.size(), view.tooltip_text]
			var badge := count_badge(group.size())
			holder.add_child(badge)
			ItemOverlay.pin_badge(badge)
		grid.add_child(holder)
	_body.add_child(_scrolling(grid))
	_footer()
	Feel.reveal(grid.get_children(), DEAL_STAGGER)


## Identical cards (same type and upgrade) grouped: an array of arrays of
## CardData, ordered by cost (highest first), then name.
static func group_cards(cards: Array) -> Array:
	var groups := {}
	for card: CardData in cards:
		var key := "%s|%s" % [card.type, card.upgrade]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(card)
	var result := groups.values()
	result.sort_custom(func(a: Array, b: Array) -> bool:
		var first: CardData = a[0]
		var second: CardData = b[0]
		return first.cost() > second.cost() if first.cost() != second.cost() else first.display_name() < second.display_name())
	return result


## Pins a count badge as a tab centred on its holder's bottom edge, hanging
## mostly below the card (anchored, so it centres once its text is laid out).
static func pin_badge(badge: Control) -> void:
	badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_END
	badge.offset_top = -Metrics.S
	badge.offset_bottom = -Metrics.S


## A small "×N" chip: copies of the same card or piece.
static func count_badge(count: int) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := UiTheme.box(Palette.WALNUT_DEEP, Palette.BRASS, UiTheme.RADIUS_SMALL, 0)
	style.content_margin_left = Metrics.S
	style.content_margin_right = Metrics.S
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", style)
	var text := Ui.label("×%d" % count, "Strong", Palette.BRASS)
	text.add_theme_font_override("font", UiFonts.numbers())
	badge.add_child(text)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge


func show_pieces(title: String, pieces: Array) -> void:
	_header(title, "%d pieces · hover for details" % pieces.size())
	var groups := {}
	for piece: PieceData in pieces:
		var key := "%s|%s|%s" % [piece.type, piece.piece_set, piece.upgrade]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(piece)
	var grid := GridContainer.new()
	grid.columns = clampi(groups.size(), 1, PIECE_COLUMNS)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for group: Array in groups.values():
		var row := piece_row(group[0], group.size())
		_make_inspectable(row)
		grid.add_child(row)
	_body.add_child(_scrolling(grid))
	_footer()
	Feel.reveal(grid.get_children(), DEAL_STAGGER)


## Token + name + upgrade (+ "×N" when `count` > 1), used here and on the run-end screen.
static func piece_row(piece: PieceData, count: int = 1) -> Control:
	var row := Ui.panel("InsetPanel")
	row.custom_minimum_size = Vector2(170, 0)
	row.tooltip_text = Ui.piece_tooltip(piece)
	var content := Ui.hbox(8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	content.add_child(PieceToken.create(36, piece))
	var text := Ui.vbox(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(Ui.label(Ui.piece_name(piece.type), "Strong"))
	var detail := Ui.upgrade_name("piece", piece.upgrade) if piece.upgrade != "" else "deploy %d" % piece.deploy_cost()
	text.add_child(Ui.label(detail, "Caption", Palette.BRASS if piece.upgrade != "" else Palette.IVORY_FAINT))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text)
	if count > 1:
		var copies := Ui.label("×%d" % count, "Strong", Palette.BRASS)
		copies.add_theme_font_override("font", UiFonts.numbers())
		copies.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(copies)
		row.tooltip_text = "%d copies · %s" % [count, row.tooltip_text]
	return row


func _header(title: String, subtitle: String) -> void:
	var header := Ui.vbox(2)
	header.add_child(Ui.label(title, "H1"))
	header.add_child(Ui.label(subtitle, "Caption"))
	_body.add_child(header)


func _footer() -> void:
	var row := Ui.hbox(8)
	_detail = Ui.wrapped("", "Caption", Metrics.OVERLAY_MIN_WIDTH - Metrics.XXXL * 2)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_detail)
	var close_button := Ui.button("Close")
	close_button.set_meta("sfx", "none")
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.tooltip_text = "Close (Esc)"
	close_button.pressed.connect(close)
	row.add_child(close_button)
	_body.add_child(row)
	_focus_targets.append(close_button)
	A11y.focus_first(_focus_targets)


## Every item takes keyboard focus; focusing it (or hovering it) shows its tooltip
## text in the detail line, so keyboard players can read it too.
func _make_inspectable(item: Control) -> void:
	item.focus_mode = Control.FOCUS_ALL
	var show_detail := func() -> void:
		if is_instance_valid(_detail):
			_detail.text = item.tooltip_text.replace("\n", " · ")
	item.focus_entered.connect(show_detail)
	item.mouse_entered.connect(show_detail)
	if not item is CardView:
		A11y.ring_on_focus(item, item, UiTheme.RADIUS_SMALL)
	_focus_targets.append(item)


## Enter / Space on a focused pickable card picks it.
func _make_pickable(view: CardView, pick: Callable) -> void:
	view.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			view.accept_event()
			pick.call())


## The item list: as tall as its content, scrolling only past MAX_LIST_HEIGHT.
func _scrolling(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	# Room for the focus ring, drawn outside each item (the scroll clips).
	margin.add_theme_constant_override("margin_top", Metrics.L)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Metrics.S)
	margin.add_child(content)
	scroll.add_child(margin)
	var fit := func() -> void:
		var wanted := margin.get_combined_minimum_size()
		var bar := Metrics.M if wanted.y > MAX_LIST_HEIGHT else 0
		scroll.custom_minimum_size = Vector2(wanted.x + bar, minf(wanted.y, MAX_LIST_HEIGHT))
	fit.call()
	margin.minimum_size_changed.connect(fit)
	return scroll


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
