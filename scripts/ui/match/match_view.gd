class_name MatchView
extends RefCounted
## The match screen's widgets (built by build()) and the "game state -> widgets"
## refreshes shared by the screen (input, selection) and MatchFx (event animations).

const PLAYER := ChessMatch.PLAYER
const OPPONENT := ChessMatch.OPPONENT
const MAX_LOG_LINES := 200
## End turn's label when no card can be played (it keeps the "End turn" prefix).
const END_TURN_STUCK := "End turn · nothing to play"
## Width of the KEYS list's key column, and the room a button keeps for its key cap.
const KEY_COLUMN := 110.0
const KEY_CAP_ROOM := 34.0
## Spare height the KEYS list needs before it comes back (see _fit_keys).
const KEYS_SLACK := float(Metrics.XL)

var game: ChessMatch
var names: Array[String] = []

var board: BoardView
## The strip above the board (turn label + score race); the turn banner sweeps across it.
var header: HBoxContainer
var hand_row: HBoxContainer
var score: ScoreRace
var turn_label: Label
var turn_caption: Label
var hint: Label
var hint_title: Label
var hint_bar: ColorRect
var hint_box: HBoxContainer
## "Hold Shift or click the board to hurry" under the hint, during the opponent's turn
## (empty otherwise).
var hurry_label: Label
var taken: Array[HFlowContainer] = []
var energy: PipMeter
var energy_label: Label
var piles_label: HBoxContainer
var pile_numbers: Array[Label] = []
var redraw_button: Button
var end_turn_button: Button
var opponent_energy: PipMeter
var opponent_hand: OpponentHand
var opponent_piles: Label
var log_lines: VBoxContainer
var log_scroll: ScrollContainer
var escape_box: PanelContainer
var escape_cost_label: Label
## The prompt's key line: it depends on how many escape squares there are.
var escape_keys_label: Label
## The keyboard reference under the hint (hidden while the check prompt is up).
var keys_box: VBoxContainer
## Holds keys_box; _fit_keys() hides it when the window has no room for it.
var _keys_room: VBoxContainer
var _margin: MarginContainer
var stay_button: Button
var _redraw_cap: Label
var _end_turn_cap: Label
var penalty_tag: Label
var opponent_penalty_tag: Label
## Game-feel layer: played cards fly over everything here.
var fx_layer: Control

var _opponent_setup: Dictionary
var _player_deck: Array = []
var _start_types: Array = [[], []]


func _init(match_game: ChessMatch, setup: Dictionary, side_names: Array[String]) -> void:
	game = match_game
	names = side_names
	_opponent_setup = setup["opponent"]
	_player_deck = setup["player"]["deck"]
	for side in [PLAYER, OPPONENT]:
		for entry: Dictionary in setup["player" if side == PLAYER else "opponent"]["roster"]:
			_start_types[side].append(entry["piece"])


## Builds the whole match layout under `root` (the screen).
func build(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Metrics.L)
	root.add_child(margin)
	_margin = margin
	root.resized.connect(_fit_keys)
	margin.minimum_size_changed.connect(_fit_keys)
	var row := Ui.hbox(Metrics.L)
	margin.add_child(row)
	row.add_child(_left_column())
	row.add_child(_centre_column())
	row.add_child(_right_column())
	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fx_layer)


func _left_column() -> VBoxContainer:
	var column := Ui.vbox(Metrics.M)
	column.custom_minimum_size.x = Metrics.SIDE_COLUMN
	column.add_child(_opponent_panel())
	column.add_child(_log_panel())
	column.add_child(_legend_panel())
	return column


func _opponent_panel() -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	var content := Ui.vbox(Metrics.S)
	panel.add_child(content)
	var header := Ui.vbox(Metrics.XS)
	header.add_child(Ui.label("OPPONENT", "Eyebrow"))
	header.add_child(Ui.label(names[OPPONENT], "H2"))
	content.add_child(header)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", Metrics.XS)
	tags.add_theme_constant_override("v_separation", Metrics.XS)
	tags.add_child(Ui.chip(String(_opponent_setup.get("difficulty", "")), Palette.OXBLOOD_INK if Ui.is_boss(String(_opponent_setup.get("id", ""))) else Palette.IVORY_SOFT))
	for artifact_id in game.artifacts(OPPONENT):
		tags.add_child(Ui.chip(Ui.artifact_name(artifact_id), Palette.BRASS, Ui.artifact_desc(artifact_id)))
	content.add_child(tags)
	content.add_child(Ui.rule(Palette.RULE_SOFT))
	var hand_line := Ui.hbox(Metrics.S)
	hand_line.add_child(_fixed_label("Hand", 56))
	opponent_hand = OpponentHand.new()
	hand_line.add_child(opponent_hand.caption)
	content.add_child(hand_line)
	content.add_child(opponent_hand)
	content.add_child(opponent_hand.names_line)
	var energy_line := Ui.hbox(Metrics.S)
	energy_line.add_child(_fixed_label("Energy", 56))
	opponent_energy = PipMeter.new()
	opponent_energy.color = Palette.OXBLOOD
	opponent_energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_line.add_child(opponent_energy)
	opponent_penalty_tag = _new_penalty_tag()
	opponent_penalty_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_line.add_child(opponent_penalty_tag)
	content.add_child(energy_line)
	content.add_child(_taken_line(OPPONENT))
	opponent_piles = Ui.label("", "Caption")
	content.add_child(opponent_piles)
	return panel


func _log_panel() -> PanelContainer:
	var log_panel := Ui.panel("RaisedPanel")
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_column := Ui.vbox(Metrics.S)
	log_panel.add_child(log_column)
	log_column.add_child(Ui.label("MATCH LOG", "Eyebrow"))
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_lines = Ui.vbox(2)
	log_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_lines)
	# Pinned to the newest line once the new lines are laid out (a deferred scroll
	# ran before their wrapped height was known and stopped a few lines short).
	log_scroll.get_v_scroll_bar().changed.connect(_scroll_log_down)
	log_column.add_child(log_scroll)
	return log_panel


func _legend_panel() -> PanelContainer:
	var legend_panel := Ui.panel("RaisedPanel")
	var legend_column := Ui.vbox(Metrics.S)
	legend_panel.add_child(legend_column)
	legend_column.add_child(Ui.label("READING THE BOARD", "Eyebrow"))
	var legend := BoardLegend.new()
	legend.show_holes = not game.holes().is_empty()
	legend_column.add_child(legend)
	return legend_panel


## "Took" + the enemy pieces this side has captured (filled by _sync_taken).
func _taken_line(side: int) -> HBoxContainer:
	var line := Ui.hbox(Metrics.S)
	line.add_child(_fixed_label("Took", 56))
	var tokens := HFlowContainer.new()
	tokens.add_theme_constant_override("h_separation", 2)
	tokens.add_theme_constant_override("v_separation", 2)
	tokens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tokens.custom_minimum_size.y = 20
	line.add_child(tokens)
	taken.resize(2)
	taken[side] = tokens
	return line


func _centre_column() -> VBoxContainer:
	var column := Ui.vbox(Metrics.S)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := Ui.hbox(Metrics.L)
	header = top
	var turn := Ui.vbox(0)
	turn.custom_minimum_size.x = 190
	turn_label = Ui.label("", "H2")
	turn.add_child(turn_label)
	turn_caption = Ui.label("", "Caption")
	turn.add_child(turn_caption)
	top.add_child(turn)
	score = ScoreRace.new()
	score.names = names
	score.target = game.target_score()
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(score)
	column.add_child(top)
	board = BoardView.new()
	board.board_size = game.board_size()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(380, 380)
	column.add_child(board)
	hand_row = Ui.hbox(Metrics.M)
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.custom_minimum_size.y = CardView.SIZE.y + Metrics.S
	var hand_margin := MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_top", Metrics.XL)
	hand_margin.add_child(hand_row)
	column.add_child(hand_margin)
	return column


func _right_column() -> VBoxContainer:
	var column := Ui.vbox(Metrics.M)
	column.custom_minimum_size.x = Metrics.SIDE_COLUMN
	var panel := Ui.panel("RaisedPanel")
	var content := Ui.vbox(Metrics.S)
	panel.add_child(content)
	content.add_child(Ui.label("YOU", "Eyebrow"))
	var energy_line := Ui.hbox(Metrics.M)
	energy = PipMeter.new()
	energy.pip_size = Vector2(22, 22)
	energy.gap = 6
	energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy.pip_stepped.connect(func(is_filling: bool) -> void:
		if not is_filling:
			Sfx.play("energy_spend"))
	energy_line.add_child(energy)
	energy_label = Ui.label("", "Strong", Palette.BRASS)
	energy_line.add_child(energy_label)
	content.add_child(energy_line)
	penalty_tag = _new_penalty_tag()
	content.add_child(penalty_tag)
	content.add_child(Ui.rule(Palette.RULE_SOFT))
	content.add_child(_taken_line(PLAYER))
	content.add_child(Ui.artifact_chips(game.artifacts(PLAYER)))
	column.add_child(panel)
	column.add_child(_desk_panel())
	redraw_button = Ui.button("Redraw")
	redraw_button.custom_minimum_size.y = Metrics.BUTTON_HEIGHT
	redraw_button.tooltip_text = "Only when no card in hand is playable: discard and draw a new hand"
	column.add_child(redraw_button)
	_redraw_cap = _key_cap(redraw_button, Palette.IVORY_FAINT)
	end_turn_button = Ui.button("End turn", "PrimaryButton")
	end_turn_button.custom_minimum_size.y = Metrics.BUTTON_HEIGHT_LARGE
	end_turn_button.add_theme_font_size_override("font_size", UiTheme.STRONG)
	end_turn_button.tooltip_text = "End (or skip) your turn. Unplayed cards without Hold are discarded."
	column.add_child(end_turn_button)
	_end_turn_cap = _key_cap(end_turn_button, Color(Palette.BRASS_INK, 0.7))
	refresh_keys()
	return column


## The player's desk: what to do next (or the check prompt) at the top, the
## keyboard reference right under it, the card piles at the bottom.
## It takes the column's spare height, so there is no dead gap above the buttons;
## what is left over sits above the piles, not between the hint and its keys.
func _desk_panel() -> PanelContainer:
	var panel := Ui.panel("InsetPanel")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := Ui.vbox(Metrics.M)
	panel.add_child(column)
	column.add_child(_hint_row())
	# A check replaces the hint and the keys in place, so nothing below it moves.
	column.add_child(_escape_panel())
	_keys_room = Ui.vbox(0)
	_keys_room.add_child(_keys_box())
	column.add_child(_keys_room)
	column.add_child(Ui.spacer())
	column.add_child(Ui.rule(Palette.RULE_SOFT))
	column.add_child(_piles_row())
	return panel


## Draw, discard and deck counts as three figures.
func _piles_row() -> HBoxContainer:
	piles_label = Ui.hbox(Metrics.S)
	pile_numbers.clear()
	for caption in ["Draw", "Discard", "Deck"]:
		var cell := Ui.vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var number := Ui.label("0", "Stat")
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(number)
		var text := Ui.label(caption.to_upper(), "Caption")
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(text)
		piles_label.add_child(cell)
		pile_numbers.append(number)
	return piles_label


## The match's keys, one per line: key caps on the left, what they do on the
## right (filled by refresh_keys from the player's bindings).
func _keys_box() -> VBoxContainer:
	# Tight rows, so the desk still fits 720p with Large text on.
	keys_box = Ui.vbox(2)
	return keys_box


## The KEYS list only repeats the key caps on the hand and the buttons: it steps
## aside while a long hint (or Large text) would push the desk past the window,
## and comes back only once there is room plus KEYS_SLACK to spare (hysteresis:
## a column whose height sits right at the limit never flickers it on and off).
func _fit_keys() -> void:
	(func() -> void:
		if _keys_room == null or not is_instance_valid(_margin) or not _margin.is_inside_tree():
			return
		var needed := _margin.get_combined_minimum_size().y
		# The screen's height (the margin itself grows to fit its content).
		var room := (_margin.get_parent() as Control).size.y
		if _keys_room.visible and needed > room + 0.5:
			_keys_room.visible = false
		elif not _keys_room.visible and needed + _keys_room.get_combined_minimum_size().y + Metrics.M + KEYS_SLACK <= room:
			_keys_room.visible = true).call_deferred()


## The KEYS list and the button key caps, from the current bindings (call again
## after a rebind).
func refresh_keys() -> void:
	_redraw_cap.text = A11y.key_label(&"rc_redraw")
	_end_turn_cap.text = A11y.key_label(&"rc_end_turn")
	Ui.clear(keys_box)
	keys_box.add_child(Ui.label("KEYS", "Eyebrow", Palette.IVORY_FAINT))
	var entries := [[card_keys_text(), "pick a card"], [keys_text(&"rc_end_turn"), "end turn"],
		[keys_text(&"rc_redraw"), "redraw"], [keys_text(&"rc_cancel") + " / right-click", "cancel"],
		[keys_text(&"rc_hurry") + " (hold)", "hurry the opponent"]]
	for entry in entries:
		var line := Ui.hbox(Metrics.S)
		var cap := Ui.label(entry[0], "Caption", Palette.IVORY_SOFT)
		cap.custom_minimum_size.x = KEY_COLUMN
		line.add_child(cap)
		line.add_child(Ui.label(entry[1], "Caption"))
		keys_box.add_child(line)


## Every key bound to `action`, for the KEYS list ("E / Space").
static func keys_text(action: StringName) -> String:
	var names: Array[String] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				names.append(A11y.key_name(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode))
	return " / ".join(names)


## The five card keys: "1–5" while they are the number row, else each key.
static func card_keys_text() -> String:
	var labels: Array[String] = []
	for i in range(1, 6):
		labels.append(A11y.key_label(StringName("rc_card_%d" % i)))
	var text := " ".join(labels)
	return "1–5" if text == "1 2 3 4 5" else text


## What to do next: a coloured bar, a short title and the instruction.
func _hint_row() -> HBoxContainer:
	var row := Ui.hbox(Metrics.M)
	hint_box = row
	hint_bar = ColorRect.new()
	hint_bar.custom_minimum_size.x = 3
	row.add_child(hint_bar)
	var text := Ui.vbox(Metrics.XS)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	hint_title = Ui.label("", "Eyebrow")
	text.add_child(hint_title)
	hint = Ui.wrapped("", "Body", 220)
	hint.custom_minimum_size.y = 52  # two lines, also with Large text
	hint.minimum_size_changed.connect(_fit_keys)
	text.add_child(hint)
	# Always in the layout (empty when not needed), so the keys below never jump.
	# It wraps instead of widening the column (with Large text it is wider than the
	# column, and the board would shift sideways for the opponent's turn).
	hurry_label = Ui.wrapped("", "Caption")
	text.add_child(hurry_label)
	return row


## The player's answer to a check: shown only while their escape is pending.
func _escape_panel() -> PanelContainer:
	escape_box = Ui.panel()
	escape_box.add_theme_stylebox_override("panel", UiTheme.box(Palette.OXBLOOD.darkened(0.7), Palette.OXBLOOD, UiTheme.RADIUS, Metrics.M, 2))
	escape_box.visible = false
	var column := Ui.vbox(Metrics.XS)
	escape_box.add_child(column)
	# An eyebrow title like the hint it replaces (not an H2): the prompt must fit the
	# desk's height, or the whole screen grows and the board jumps.
	column.add_child(Ui.label("CHECK!", "Eyebrow", Palette.OXBLOOD_INK))
	column.add_child(Ui.wrapped("Move your king to a highlighted square (no card needed), or stay put.", "Body", 220))
	escape_cost_label = Ui.wrapped("", "Caption", 220)
	escape_cost_label.add_theme_color_override("font_color", Palette.IVORY_SOFT)
	column.add_child(escape_cost_label)
	stay_button = Ui.button("Stay in check")
	stay_button.custom_minimum_size.y = Metrics.BUTTON_HEIGHT
	# Wraps with Large text rather than widening the column and moving the board.
	stay_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stay_button.tooltip_text = "Decline the escape: your king stays where it is"
	column.add_child(stay_button)
	escape_keys_label = Ui.wrapped("", "Caption", 220)
	column.add_child(escape_keys_label)
	return escape_box


## A small key hint inside a button's right edge. The button's text keeps clear of
## it: both sides of every state's style get room for the cap (the text stays centred).
func _key_cap(button: Button, ink: Color) -> Label:
	var cap := Ui.label("", "Caption", ink)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cap)
	cap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, Metrics.M)
	cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# The theme's styles are only reachable once the button is in the tree.
	button.ready.connect(_make_room_for_cap.bind(button), CONNECT_ONE_SHOT)
	return cap


static func _make_room_for_cap(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = maxf(style.content_margin_left, KEY_CAP_ROOM)
		style.content_margin_right = maxf(style.content_margin_right, KEY_CAP_ROOM)
		button.add_theme_stylebox_override(state, style)


func _new_penalty_tag() -> Label:
	var tag := Ui.label("", "Caption", Palette.OXBLOOD_INK)
	tag.tooltip_text = "Check escapes made this round come off that side's next turn"
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	return tag


func _fixed_label(text: String, width: float) -> Label:
	var node := Ui.label(text, "Caption")
	node.custom_minimum_size.x = width
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## The player's own turn with nothing pending: cards, Redraw and End turn work.
func is_player_turn() -> bool:
	return not game.is_over() and game.pending_escape_side() == -1 and game.current_side() == PLAYER


func sync_tokens() -> void:
	board.holes = game.holes()
	var alive: Array = []
	for side in [PLAYER, OPPONENT]:
		for piece in game.pieces(side):
			alive.append(piece.uid)
			var token := board.token(piece.uid)
			if token == null:
				token = PieceToken.create(48)
			token.show_match_piece(piece)
			token.is_in_check = piece.type == "king" and game.in_check(side)
			board.set_token(piece.uid, token, piece.square)
	for key in board.token_keys():
		if not alive.has(key):
			board.remove_token(key)
	board.queue_redraw()


func sync_panels() -> void:
	energy.total = game.max_energy(PLAYER)
	energy.value = game.energy(PLAYER)
	energy_label.text = "%d / %d energy" % [game.energy(PLAYER), game.max_energy(PLAYER)]
	var piles := [game.draw_pile_size(PLAYER), game.discard_size(PLAYER), game.deck_size(PLAYER)]
	for i in piles.size():
		pile_numbers[i].text = str(piles[i])
	opponent_energy.total = game.max_energy(OPPONENT)
	opponent_energy.value = game.energy(OPPONENT)
	opponent_piles.text = "Draw %d · Discard %d · Deck %d" % [game.draw_pile_size(OPPONENT), game.discard_size(OPPONENT), game.deck_size(OPPONENT)]
	sync_opponent_hand()
	sync_penalties()
	_sync_taken()
	score.set_scores(game.score(PLAYER), game.score(OPPONENT))
	var is_my_turn := is_player_turn()
	turn_label.text = "Your turn" if game.current_side() == PLAYER else "%s's turn" % names[OPPONENT]
	turn_label.add_theme_color_override("font_color", Palette.IVORY if game.current_side() == PLAYER else Palette.OXBLOOD_INK)
	turn_caption.text = "Round %d of %d" % [game.current_round(), game.max_rounds()]
	if game.pending_escape_side() == PLAYER:
		turn_label.text = "Check!"
		turn_label.add_theme_color_override("font_color", Palette.OXBLOOD_INK)
	var redraw_cost := int(GameConfig.value("match", "redraw_cost"))
	redraw_button.disabled = not (is_my_turn and game.can_redraw())
	# Still allowed when it can't lead to a play (D8), but shown as not useful.
	var is_useless := not redraw_button.disabled and not redraw_helps()
	redraw_button.text = "Redraw · won't help" if is_useless else "Redraw hand · %d energy" % redraw_cost
	if is_useless:
		redraw_button.add_theme_color_override("font_color", Palette.IVORY_FAINT)
		redraw_button.add_theme_color_override("font_hover_color", Palette.IVORY_SOFT)
	else:
		redraw_button.remove_theme_color_override("font_color")
		redraw_button.remove_theme_color_override("font_hover_color")
	end_turn_button.disabled = not is_my_turn
	end_turn_button.text = "End turn" if MatchUiLogic.has_play(game) or not is_my_turn else END_TURN_STUCK


## Each side's "Took" row: the enemy's starting pieces that are no longer on the
## board (a promoted pawn still counts as a pawn).
func _sync_taken() -> void:
	for side in [PLAYER, OPPONENT]:
		var enemy := OPPONENT if side == PLAYER else PLAYER
		var lost: Array = _start_types[enemy].duplicate()
		for piece in game.pieces(enemy):
			var type := "pawn" if piece.is_promoted else piece.type
			for i in lost.size():
				if (lost[i] as PieceData).type == type:
					lost.remove_at(i)
					break
		Ui.clear(taken[side])
		if lost.is_empty():
			taken[side].add_child(Ui.label("nothing yet", "Caption"))
		for data: PieceData in lost:
			taken[side].add_child(PieceToken.create(20, data, enemy))


## Whether the energy left after a redraw still pays for a card in the deck.
func redraw_helps() -> bool:
	return MatchUiLogic.redraw_leaves_a_play(game.energy(PLAYER), int(GameConfig.value("match", "redraw_cost")), _player_deck, game.hidden_card_count() > 0)


func sync_penalties() -> void:
	for side in [PLAYER, OPPONENT]:
		var tag := penalty_tag if side == PLAYER else opponent_penalty_tag
		var penalty := game.escape_penalty(side)
		tag.text = "−%d next turn" % penalty if penalty > 0 else ""


## The opponent's hand as the player may see it. Returns the faces just revealed.
func sync_opponent_hand() -> Array[CardView]:
	return opponent_hand.show_hand(game.visible_opponent_hand(), game.hidden_card_count())


func set_hint(text: String, color: Color, title: String) -> void:
	hint.text = text
	hint.add_theme_color_override("font_color", color)
	hint_title.text = title.to_upper()
	hint_bar.color = Palette.BRASS if color == Palette.IVORY_SOFT else color
	hint_title.add_theme_color_override("font_color", hint_bar.color)


func set_lift(token: PieceToken, height: float) -> void:
	if is_instance_valid(token):
		Motion.tween(token).tween_property(token, "lift", height, Motion.time("pickup"))


## A tint over the piece (skipped with reduced motion; the float text still says what happened).
func flash_token(token: PieceToken, color: Color) -> void:
	if Motion.reduced():
		return
	var tween := token.create_tween()
	tween.tween_property(token, "flash_color", Color(color, 0.7), Motion.time("quick") * 0.5)
	tween.tween_property(token, "flash_color", Color(color, 0.0), Motion.time("quick") * 2.0)


static func side_color(side: int) -> Color:
	return Palette.PIECE_IVORY if side == PLAYER else Palette.OXBLOOD


func log_line(text: String, event_type: String) -> void:
	if text == "":
		return
	var line := Ui.wrapped(text, "Caption", 230)
	if event_type == "turn_start":
		line.theme_type_variation = "Eyebrow"
	elif event_type in ["capture", "burn_out", "explosion", "match_over"]:
		line.add_theme_color_override("font_color", Palette.IVORY)
	log_lines.add_child(line)
	while log_lines.get_child_count() > MAX_LOG_LINES:
		var oldest := log_lines.get_child(0)
		log_lines.remove_child(oldest)
		oldest.queue_free()


func _scroll_log_down() -> void:
	if not is_instance_valid(log_scroll):
		return
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)
