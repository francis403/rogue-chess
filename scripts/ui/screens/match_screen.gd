extends Control
## The match: board, hand, score race, both sides' panels and the event log.
## Every legality question goes to ChessMatch; this script only selects, plays and animates.
## Card-first: card -> piece -> target. Piece-first: piece -> target (cheapest card is used).

const PLAYER := ChessMatch.PLAYER
const OPPONENT := ChessMatch.OPPONENT
const NO_SQUARE := BoardView.NO_SQUARE
const MAX_OPPONENT_ACTIONS := 60
const MAX_LOG_LINES := 200

var game: ChessMatch

var _names: Array[String] = []
var _opponent_setup: Dictionary
var _ai: MatchAI
var _move_delay: float = 0.45
var _is_busy: bool = false
var _selected_card: int = -1
var _selected_from: Vector2i = NO_SQUARE
var _targets: Array[Vector2i] = []
var _card_views: Array[CardView] = []

var _board: BoardView
var _hand_row: HBoxContainer
var _score: ScoreRace
var _turn_label: Label
var _turn_caption: Label
var _hint: Label
var _energy: PipMeter
var _energy_label: Label
var _piles_label: Label
var _redraw_button: Button
var _end_turn_button: Button
var _opponent_energy: PipMeter
var _opponent_hand: HBoxContainer
var _opponent_hand_count: Label
var _opponent_piles: Label
var _log: VBoxContainer
var _log_scroll: ScrollContainer
var _over_status: Label
var _escape_box: PanelContainer
var _escape_cost_label: Label
var _stay_button: Button
var _penalty_tag: Label
var _opponent_penalty_tag: Label
var _toast: PanelContainer
var _last_checkers: Array[Vector2i] = []
var _is_finishing: bool = false


func _ready() -> void:
	var setup := Game.match_setup
	_opponent_setup = setup["opponent"]
	_names = ["You", String(_opponent_setup.get("name", "Opponent"))]
	game = ChessMatch.new(setup)
	_move_delay = float(GameConfig.value("ai", "move_delay_seconds"))
	_ai = _make_ai(setup)
	_build_layout()
	_sync()
	_start.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var is_right_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if event.is_action_pressed("ui_cancel") or is_right_click:
		get_viewport().set_input_as_handled()
		_cancel()


func is_busy() -> bool:
	return _is_busy


## Card-first selection (also called by the screenshot tool).
func press_card(card_index: int) -> void:
	if not _can_act():
		return
	if card_index == _selected_card:
		_cancel()
		return
	var reason := MatchUiLogic.unplayable_reason(game, card_index)
	if reason != "":
		Ui.shake(_card_views[card_index])
		_set_hint(reason, Palette.OXBLOOD)
		return
	_selected_card = card_index
	var pieces := game.pieces_for_card(card_index)
	if _selected_from == NO_SQUARE or game.targets(card_index, _selected_from).is_empty():
		_selected_from = pieces[0] if pieces.size() == 1 else NO_SQUARE
	_show_selection()


func press_square(square: Vector2i) -> void:
	if _can_answer_escape():
		if game.escape_squares().has(square):
			_escape(square)
		else:
			_set_hint("Your king is in check. Click a highlighted square to escape, or press Stay.", Palette.OXBLOOD)
			Ui.shake(_escape_box)
		return
	if not _can_act():
		return
	if _selected_from != NO_SQUARE and _targets.has(square):
		_play_selected(square)
		return
	var piece := game.piece_at(square)
	if piece == null or piece.side != PLAYER:
		_cancel()
		return
	if square == _selected_from and _selected_card < 0:
		_cancel()
		return
	if _selected_card >= 0 and game.targets(_selected_card, square).is_empty():
		_refuse(square, "%s can't move this piece" % game.hand(PLAYER)[_selected_card].display_name())
		return
	if _selected_card < 0 and MatchUiLogic.targets_for_piece(game, square).is_empty():
		_refuse(square, "No card in your hand can move this piece")
		return
	_selected_from = square
	_show_selection()


func _start() -> void:
	await _run(game.initial_events())


# --- Layout -----------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var row := Ui.hbox(16)
	margin.add_child(row)
	row.add_child(_left_column())
	row.add_child(_centre_column())
	row.add_child(_right_column())


func _left_column() -> VBoxContainer:
	var column := Ui.vbox(12)
	column.custom_minimum_size.x = 280
	var panel := Ui.panel("RaisedPanel")
	var content := Ui.vbox(8)
	panel.add_child(content)
	content.add_child(Ui.label("OPPONENT", "Eyebrow"))
	content.add_child(Ui.label(_names[OPPONENT], "H2"))
	var tags := Ui.hbox(4)
	tags.add_child(Ui.chip(String(_opponent_setup.get("difficulty", "")), Palette.OXBLOOD if Ui.is_boss(String(_opponent_setup.get("id", ""))) else Palette.IVORY_SOFT))
	for artifact_id in game.artifacts(OPPONENT):
		tags.add_child(Ui.chip(Ui.artifact_name(artifact_id), Palette.BRASS, Ui.artifact_desc(artifact_id)))
	content.add_child(tags)
	var hand_line := Ui.hbox(8)
	hand_line.add_child(_fixed_label("Hand", 56))
	_opponent_hand = Ui.hbox(3)
	hand_line.add_child(_opponent_hand)
	_opponent_hand_count = Ui.label("", "Caption")
	_opponent_hand_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hand_line.add_child(_opponent_hand_count)
	content.add_child(hand_line)
	var energy_line := Ui.hbox(8)
	energy_line.add_child(_fixed_label("Energy", 56))
	_opponent_energy = PipMeter.new()
	_opponent_energy.color = Palette.OXBLOOD
	_opponent_energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_line.add_child(_opponent_energy)
	_opponent_penalty_tag = _new_penalty_tag()
	_opponent_penalty_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_line.add_child(_opponent_penalty_tag)
	content.add_child(energy_line)
	_opponent_piles = Ui.label("", "Caption")
	content.add_child(_opponent_piles)
	column.add_child(panel)
	var log_panel := Ui.panel("RaisedPanel")
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_column := Ui.vbox(8)
	log_panel.add_child(log_column)
	log_column.add_child(Ui.label("MATCH LOG", "Eyebrow"))
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log = Ui.vbox(2)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log)
	log_column.add_child(_log_scroll)
	column.add_child(log_panel)
	return column


func _centre_column() -> VBoxContainer:
	var column := Ui.vbox(8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := Ui.hbox(16)
	var turn := Ui.vbox(0)
	turn.custom_minimum_size.x = 190
	_turn_label = Ui.label("", "H2")
	turn.add_child(_turn_label)
	_turn_caption = Ui.label("", "Caption")
	turn.add_child(_turn_caption)
	top.add_child(turn)
	_score = ScoreRace.new()
	_score.names = _names
	_score.target = game.target_score()
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score)
	column.add_child(top)
	_board = BoardView.new()
	_board.board_size = game.board_size()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(380, 380)
	_board.square_clicked.connect(press_square)
	_board.square_hovered.connect(_on_square_hovered)
	_board.cancel_requested.connect(_cancel)
	column.add_child(_board)
	_hand_row = Ui.hbox(10)
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.custom_minimum_size.y = CardView.SIZE.y + 8
	var hand_margin := MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_top", 22)
	hand_margin.add_child(_hand_row)
	column.add_child(hand_margin)
	return column


func _right_column() -> VBoxContainer:
	var column := Ui.vbox(12)
	column.custom_minimum_size.x = 250
	var panel := Ui.panel("RaisedPanel")
	var content := Ui.vbox(10)
	panel.add_child(content)
	content.add_child(Ui.label("YOU", "Eyebrow"))
	var energy_line := Ui.hbox(12)
	_energy = PipMeter.new()
	_energy.pip_size = Vector2(22, 22)
	_energy.gap = 6
	_energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_line.add_child(_energy)
	_energy_label = Ui.label("", "Strong", Palette.BRASS)
	energy_line.add_child(_energy_label)
	content.add_child(energy_line)
	_penalty_tag = _new_penalty_tag()
	content.add_child(_penalty_tag)
	_piles_label = Ui.label("", "Caption")
	content.add_child(_piles_label)
	content.add_child(Ui.artifact_chips(game.artifacts(PLAYER)))
	column.add_child(panel)
	var hint_panel := Ui.panel("InsetPanel")
	_hint = Ui.wrapped("", "Body", 220)
	_hint.custom_minimum_size.y = 64
	hint_panel.add_child(_hint)
	column.add_child(hint_panel)
	column.add_child(_escape_panel())
	column.add_child(Ui.spacer())
	_redraw_button = Ui.button("Redraw")
	_redraw_button.tooltip_text = "Only when no card in hand is playable: discard and draw a new hand"
	_redraw_button.pressed.connect(_on_redraw)
	column.add_child(_redraw_button)
	_end_turn_button = Ui.button("End turn", "PrimaryButton")
	_end_turn_button.custom_minimum_size.y = 44
	_end_turn_button.tooltip_text = "End (or skip) your turn. Unplayed cards without Hold are discarded."
	_end_turn_button.pressed.connect(_on_end_turn)
	column.add_child(_end_turn_button)
	var keys := Ui.label("Esc or right-click cancels a selection", "Caption")
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)
	return column


## The player's answer to a check: shown only while their escape is pending.
func _escape_panel() -> PanelContainer:
	_escape_box = Ui.panel()
	_escape_box.add_theme_stylebox_override("panel", UiTheme.box(Palette.OXBLOOD.darkened(0.7), Palette.OXBLOOD, UiTheme.RADIUS, 12, 2))
	_escape_box.visible = false
	var column := Ui.vbox(8)
	_escape_box.add_child(column)
	column.add_child(Ui.label("Check!", "H2", Palette.OXBLOOD))
	column.add_child(Ui.wrapped("Move your king to a highlighted square (no card needed), or stay put.", "Body", 210))
	_escape_cost_label = Ui.wrapped("", "Caption", 210)
	_escape_cost_label.add_theme_color_override("font_color", Palette.IVORY_SOFT)
	column.add_child(_escape_cost_label)
	_stay_button = Ui.button("Stay (keep the king in check)")
	_stay_button.tooltip_text = "Decline the escape: your king stays where it is"
	_stay_button.pressed.connect(_on_stay)
	column.add_child(_stay_button)
	return _escape_box


func _new_penalty_tag() -> Label:
	var tag := Ui.label("", "Caption", Palette.OXBLOOD)
	tag.tooltip_text = "Check escapes made this round come off that side's next turn"
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	return tag


func _fixed_label(text: String, width: float) -> Label:
	var node := Ui.label(text, "Caption")
	node.custom_minimum_size.x = width
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


# --- State -> view ----------------------------------------------------------

func _sync() -> void:
	_sync_tokens()
	_sync_hand()
	_sync_panels()
	_show_selection()


func _sync_tokens() -> void:
	_board.holes = game.holes()
	var alive: Array = []
	for side in [PLAYER, OPPONENT]:
		for piece in game.pieces(side):
			alive.append(piece.uid)
			var token := _board.token(piece.uid)
			if token == null:
				token = PieceToken.create(48)
			token.show_match_piece(piece)
			token.is_in_check = piece.type == "king" and game.in_check(side)
			_board.set_token(piece.uid, token, piece.square)
	for key in _board.token_keys():
		if not alive.has(key):
			_board.remove_token(key)
	_board.queue_redraw()


func _sync_hand() -> void:
	Ui.clear(_hand_row)
	_card_views.clear()
	var hand := game.hand(PLAYER)
	var is_my_turn := _is_my_turn()
	for card_index in hand.size():
		var view := CardView.create(hand[card_index])
		view.is_playable = is_my_turn and game.is_card_playable(card_index)
		view.pressed.connect(press_card.bind(card_index))
		_hand_row.add_child(view)
		_card_views.append(view)


func _sync_panels() -> void:
	_energy.total = game.max_energy(PLAYER)
	_energy.value = game.energy(PLAYER)
	_energy_label.text = "%d / %d energy" % [game.energy(PLAYER), game.max_energy(PLAYER)]
	_piles_label.text = "Draw %d · Discard %d · Deck %d" % [game.draw_pile_size(PLAYER), game.discard_size(PLAYER), game.deck_size(PLAYER)]
	_opponent_energy.total = game.max_energy(OPPONENT)
	_opponent_energy.value = game.energy(OPPONENT)
	_opponent_piles.text = "Draw %d · Discard %d · Deck %d" % [game.draw_pile_size(OPPONENT), game.discard_size(OPPONENT), game.deck_size(OPPONENT)]
	_sync_opponent_hand()
	_sync_penalties()
	_score.set_scores(game.score(PLAYER), game.score(OPPONENT))
	var is_my_turn := _is_my_turn()
	_turn_label.text = "Your turn" if game.current_side() == PLAYER else "%s's turn" % _names[OPPONENT]
	_turn_label.add_theme_color_override("font_color", Palette.IVORY if game.current_side() == PLAYER else Palette.OXBLOOD)
	_turn_caption.text = "Round %d of %d" % [game.current_round(), game.max_rounds()]
	if game.pending_escape_side() == PLAYER:
		_turn_label.text = "Check!"
		_turn_label.add_theme_color_override("font_color", Palette.OXBLOOD)
	var redraw_cost := int(GameConfig.value("match", "redraw_cost"))
	_redraw_button.text = "Redraw hand · %d energy" % redraw_cost
	_redraw_button.disabled = not (is_my_turn and game.can_redraw())
	_end_turn_button.disabled = not is_my_turn
	_end_turn_button.text = "End turn" if not game.legal_plays(PLAYER).is_empty() or not is_my_turn else "End turn (nothing playable)"


func _sync_penalties() -> void:
	for side in [PLAYER, OPPONENT]:
		var tag := _penalty_tag if side == PLAYER else _opponent_penalty_tag
		var penalty := game.escape_penalty(side)
		tag.text = "−%d next turn" % penalty if penalty > 0 else ""


func _sync_opponent_hand() -> void:
	Ui.clear(_opponent_hand)
	var hand_size := game.hand(OPPONENT).size()
	for i in hand_size:
		_opponent_hand.add_child(CardView.create_back())
	if hand_size > 0:
		_opponent_hand_count.text = "%d hidden" % hand_size
	else:
		_opponent_hand_count.text = "no cards" if game.current_side() == OPPONENT else "refills on its turn"


func _show_selection() -> void:
	_targets.clear()
	for i in _card_views.size():
		_card_views[i].is_selected = i == _selected_card
		_card_views[i].is_highlighted = false
	var is_prompt := not game.is_over() and game.pending_escape_side() == PLAYER
	_escape_box.visible = is_prompt
	if is_prompt:
		_show_escape_prompt()
		return
	_board.threats.clear()
	if game.pending_escape_side() != -1:
		_board.threats.assign(_last_checkers)
	if not _is_my_turn():
		_board.clear_highlights()
		_set_hint("Match over." if game.is_over() else "%s is thinking…" % _names[OPPONENT], Palette.IVORY_FAINT)
		return
	if _selected_card >= 0:
		var card := game.hand(PLAYER)[_selected_card]
		var pieces := game.pieces_for_card(_selected_card)
		if _selected_from == NO_SQUARE:
			_board.set_highlights(pieces, [], [])
			_set_hint("%s selected. Click a highlighted piece to move it." % card.display_name(), Palette.BRASS)
			return
		_targets = game.targets(_selected_card, _selected_from)
		_highlight_targets(pieces)
		_set_hint("Click a target square. Red squares capture." + _ignite_warning(), Palette.BRASS)
		return
	if _selected_from != NO_SQUARE:
		_targets = MatchUiLogic.targets_for_piece(game, _selected_from)
		_highlight_targets([])
		_set_hint("Click a target. The cheapest card that allows the move is played." + _ignite_warning(), Palette.BRASS)
		return
	_board.set_highlights(MatchUiLogic.movable_pieces(game), [], [])
	if game.legal_plays(PLAYER).is_empty():
		_set_hint(_stuck_hint(), Palette.IVORY_SOFT)
	else:
		_set_hint("Pick a card, or click one of your highlighted pieces.", Palette.IVORY_SOFT)


func _show_escape_prompt() -> void:
	var targets := MatchUiLogic.escape_targets(game)
	var king_square := NO_SQUARE
	for piece in game.pieces(PLAYER):
		if piece.type == "king":
			king_square = piece.square
	_board.threats.assign(_last_checkers)
	_board.set_highlights([], targets["moves"], targets["captures"], king_square)
	_escape_cost_label.text = "Costs %d energy from your next turn · next turn: %d/%d" % [
		MatchUiLogic.escape_cost(), MatchUiLogic.next_turn_energy(game, PLAYER, 1), game.max_energy(PLAYER)]
	_stay_button.disabled = _is_busy
	_set_hint("Check! %s attacks your king." % _names[OPPONENT], Palette.OXBLOOD)


func _stuck_hint() -> String:
	if not game.can_redraw():
		return "No playable cards left. End your turn."
	var deck: Array = Game.match_setup["player"]["deck"]
	if not MatchUiLogic.redraw_leaves_a_play(game.energy(PLAYER), int(GameConfig.value("match", "redraw_cost")), deck):
		return "Nothing in your hand can move, and a redraw wouldn't leave enough energy to play any card in your deck. End your turn."
	return "Nothing in your hand can move. Redraw for a new hand, or end your turn."


## Fire pieces ignite on their first move (D24): say so before it happens.
func _ignite_warning() -> String:
	var piece := game.piece_at(_selected_from)
	if piece == null or piece.is_burning() or piece.burn_turns() <= 0:
		return ""
	return "\nMoving this Fire piece ignites it: %d turns left." % piece.burn_turns()


func _highlight_targets(movable: Array[Vector2i]) -> void:
	var moves: Array[Vector2i] = []
	var captures: Array[Vector2i] = []
	for square in _targets:
		var occupant := game.piece_at(square)
		if occupant != null and occupant.side == OPPONENT:
			captures.append(square)
		else:
			moves.append(square)
	_board.set_highlights(movable, moves, captures, _selected_from)


func _set_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)


func _on_square_hovered(square: Vector2i) -> void:
	if not _can_act() or _selected_card >= 0 or _selected_from == NO_SQUARE:
		return
	var play := MatchUiLogic.pick_play(game, _selected_from, square) if _targets.has(square) else {}
	for i in _card_views.size():
		_card_views[i].is_highlighted = not play.is_empty() and play["card_index"] == i


# --- Actions ----------------------------------------------------------------

func _can_act() -> bool:
	return not _is_busy and _is_my_turn()


## The player's own turn with nothing pending: cards, Redraw and End turn work.
func _is_my_turn() -> bool:
	return not game.is_over() and game.pending_escape_side() == -1 and game.current_side() == PLAYER


func _can_answer_escape() -> bool:
	return not _is_busy and not game.is_over() and game.pending_escape_side() == PLAYER


## Esc / right-click: drop the selection. During an escape prompt it only keeps the prompt.
func _cancel() -> void:
	_selected_card = -1
	_selected_from = NO_SQUARE
	if _can_act() or _can_answer_escape():
		_show_selection()


func _escape(to: Vector2i) -> void:
	if not _can_answer_escape():
		return
	await _run(game.escape(to))


func _on_stay() -> void:
	if not _can_answer_escape():
		return
	await _run(game.decline_escape())


func _refuse(square: Vector2i, reason: String) -> void:
	var token := _board.token(game.piece_at(square).uid)
	if token != null:
		_flash_token(token, Palette.OXBLOOD)
	_set_hint(reason, Palette.OXBLOOD)


func _play_selected(to: Vector2i) -> void:
	var play := {"card_index": _selected_card, "from": _selected_from, "to": to}
	if _selected_card < 0:
		play = MatchUiLogic.pick_play(game, _selected_from, to)
	if play.is_empty():
		return
	var view := _card_views[play["card_index"]]
	view.create_tween().tween_property(view, "modulate:a", 0.0, Ui.FAST)
	_selected_card = -1
	_selected_from = NO_SQUARE
	await _run(game.play(play["card_index"], play["from"], play["to"]))


func _on_redraw() -> void:
	if _can_act() and game.can_redraw():
		_cancel()
		await _run(game.redraw())


func _on_end_turn() -> void:
	if not _can_act():
		return
	_selected_card = -1
	_selected_from = NO_SQUARE
	await _run(game.end_turn())


## Animates the events, then lets the opponent act (its turn, or its answer to
## a check) until the player has to decide something or the match is over.
func _run(events: Array[Dictionary]) -> void:
	_is_busy = true
	_board.clear_highlights()
	await _apply(events)
	await _opponent_turn()
	_is_busy = false
	_sync()
	if game.is_over():
		_show_match_over()


## Plays opponent actions one at a time. Stops when the player must act: their
## turn, or their escape prompt (the opponent's turn resumes after the answer).
func _opponent_turn() -> void:
	var actions := 0
	while not game.is_over() and _opponent_must_act():
		_sync_panels()
		_show_selection()
		await _wait(_move_delay)
		var is_escape := game.pending_escape_side() == OPPONENT
		var action := _ai.choose_action(game)
		actions += 1
		if actions > MAX_OPPONENT_ACTIONS:
			action = {"kind": "decline_escape" if is_escape else "end_turn"}
		var events := MatchAI.apply_action(game, action)
		if events.size() == 1 and events[0]["type"] == "error":
			push_error("Opponent action %s refused (%s)" % [action, events[0]["reason"]])
			events = game.decline_escape() if is_escape else game.end_turn()
		await _apply(events)


func _opponent_must_act() -> bool:
	var pending := game.pending_escape_side()
	if pending != -1:
		return pending == OPPONENT
	return game.current_side() == OPPONENT


func _make_ai(setup: Dictionary) -> MatchAI:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(setup.get("seed", 0)) + 1
	return MatchAI.new(OPPONENT, int(_opponent_setup.get("search_depth", 1)), float(_opponent_setup.get("random_chance", 0.0)), rng, _opponent_setup.get("deck", []))


func _wait(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished


# --- Event feedback -----------------------------------------------------------

func _apply(events: Array[Dictionary]) -> void:
	var draws := [0, 0]
	for event in events:
		_log_line(EventText.describe(event, _names), event["type"])
		match event["type"]:
			"draw":
				draws[event["side"]] += 1
			"turn_start", "energy", "redraw", "card_played":
				_on_side_change(event)
				_sync_penalties()
			"check":
				await _animate_check(event)
			"escape":
				_on_escape(event)
			"escape_declined":
				_show_toast("%s %s in check" % [_names[event["side"]], "stay" if event["side"] == PLAYER else "stays"], Palette.IVORY_SOFT)
			"move":
				await _animate_move(event)
			"capture":
				await _animate_capture(event)
			"shield_block":
				await _animate_block(event)
			"explosion":
				await _animate_explosion(event)
			"score":
				_score.set_scores(game.score(PLAYER), game.score(OPPONENT))
			"ignite", "burn_tick":
				await _animate_burn(event)
			"burn_out":
				await _animate_burn_out(event)
			"promotion":
				await _animate_promotion(event)
			"shuffle":
				Ui.pop(_piles_label if event["side"] == PLAYER else _opponent_piles, 1.15)
	for side in [PLAYER, OPPONENT]:
		if draws[side] > 0:
			_log_line("%s drew %d card%s" % [_names[side], draws[side], "" if draws[side] == 1 else "s"], "draw")
	if not events.is_empty():
		_sync_tokens()


func _on_side_change(event: Dictionary) -> void:
	if event["type"] == "card_played" and event["side"] == OPPONENT:
		_turn_caption.text = "%s plays %s" % [_names[OPPONENT], Ui.piece_name(event["card_type"])]
		if _opponent_hand.get_child_count() > 0:
			_opponent_hand.get_child(0).queue_free()
		_opponent_energy.value = event["energy"]
		return
	if event["type"] == "card_played":
		_energy.value = event["energy"]
		_energy_label.text = "%d / %d energy" % [event["energy"], game.max_energy(PLAYER)]
		return
	if event["type"] == "turn_start":
		_turn_label.text = "Your turn" if event["side"] == PLAYER else "%s's turn" % _names[OPPONENT]
		_turn_label.add_theme_color_override("font_color", Palette.IVORY if event["side"] == PLAYER else Palette.OXBLOOD)
		_turn_caption.text = "Round %d of %d" % [event["round"], game.max_rounds()]
		_sync_opponent_hand()
		Ui.pop(_turn_label, 1.08)


func _animate_check(event: Dictionary) -> void:
	_last_checkers.assign(event["checkers"])
	_board.threats.assign(_last_checkers)
	var king_square: Vector2i = event["king_square"]
	var king := _board.token(game.piece_at(king_square).uid) if game.piece_at(king_square) != null else null
	if king != null:
		king.is_in_check = true
		_flash_token(king, Palette.OXBLOOD)
	_board.flash_squares(_last_checkers, Palette.OXBLOOD, 0.5)
	Ui.float_text(_board, "Check!", _board.square_centre(king_square), Palette.OXBLOOD, 26)
	if not event["can_escape"]:
		var who := "You have" if event["side"] == PLAYER else "%s has" % _names[OPPONENT]
		_show_toast("Check! %s no safe square to escape to" % who, Palette.OXBLOOD)
	await _wait(0.35)


func _on_escape(event: Dictionary) -> void:
	_sync_penalties()
	var to := EventText.square_name(event["to"])
	if event["side"] == PLAYER:
		_show_toast("You escape to %s: %d less energy next turn" % [to, event["cost"]], Palette.BRASS)
	else:
		_show_toast("Check! %s escapes to %s: they'll have %d less energy next turn" % [_names[OPPONENT], to, event["cost"]], Palette.BRASS)


## A short message over the top of the board (check answers); replaces the previous one.
func _show_toast(text: String, color: Color) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Ui.panel()
	_toast.add_theme_stylebox_override("panel", UiTheme.box(Palette.WALNUT_DEEP, color, UiTheme.RADIUS, 10, 1))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.z_index = 30
	var text_label := Ui.label(text, "Strong", color)
	_toast.add_child(text_label)
	_board.add_child(_toast)
	_toast.reset_size()
	# Centred on the board's middle ranks, away from the back ranks where kings stand.
	_toast.position = ((_board.size - _toast.size) / 2.0).floor()
	var tween := _toast.create_tween()
	_toast.modulate.a = 0.0
	tween.tween_property(_toast, "modulate:a", 1.0, Ui.FAST)
	tween.tween_interval(2.4)
	tween.tween_property(_toast, "modulate:a", 0.0, Ui.NORMAL)
	tween.tween_callback(_toast.queue_free)


func _animate_move(event: Dictionary) -> void:
	_board.last_move = [event["from"], event["to"]]
	var tween := _board.move_token(event["uid"], event["to"])
	if tween != null:
		await tween.finished


func _animate_capture(event: Dictionary) -> void:
	var victim := _board.forget_token(event["uid"])
	var at := _board.square_centre(event["square"])
	if victim != null:
		_board.move_child(victim, 0)
		var tween := victim.create_tween().set_parallel()
		tween.tween_property(victim, "scale", Vector2.ONE * 1.35, 0.22).set_ease(Tween.EASE_OUT)
		tween.tween_property(victim, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(victim.queue_free)
	if event["points"] > 0:
		Ui.float_text(_board, "+%d" % event["points"], at, _side_color(event["by_side"]), 26)
	await _wait(0.18)


func _animate_block(event: Dictionary) -> void:
	var defender := _board.token(event["uid"])
	if defender != null:
		defender.has_shield = false
		_flash_token(defender, Palette.STEEL)
	_board.flash_squares([event["square"]], Palette.STEEL)
	Ui.float_text(_board, "Blocked!", _board.square_centre(event["square"]), Palette.STEEL, 20)
	var attacker := _board.token(event["attacker_uid"]) if event["attacker_uid"] >= 0 else null
	if attacker == null:
		await _wait(0.2)
		return
	var home := attacker.position
	var lunge := home.lerp(home + _board.square_centre(event["square"]) - _board.square_centre(event["attacker_square"]), 0.45)
	attacker.z_index = 5
	var tween := attacker.create_tween()
	tween.tween_property(attacker, "position", lunge, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker, "position", home, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	attacker.z_index = 0


func _animate_explosion(event: Dictionary) -> void:
	var squares: Array = event["squares"].duplicate()
	squares.append(event["square"])
	_board.flash_squares(squares, Palette.EMBER, 0.45)
	Ui.float_text(_board, "Boom!", _board.square_centre(event["square"]), Palette.EMBER, 28)
	Ui.shake(_board)
	await _wait(0.15)


func _animate_burn(event: Dictionary) -> void:
	var token := _board.token(event["uid"])
	if token != null:
		token.burn_left = event["turns_left"]
		token.queue_redraw()
		_flash_token(token, Palette.EMBER)
	var text := "Ignited" if event["type"] == "ignite" else "Burn %d" % event["turns_left"]
	Ui.float_text(_board, text, _board.square_centre(event["square"]) + Vector2(0, -20), Palette.EMBER, 16)
	await _wait(0.12)


func _animate_burn_out(event: Dictionary) -> void:
	var victim := _board.forget_token(event["uid"])
	if victim != null:
		var tween := victim.create_tween()
		tween.tween_property(victim, "modulate", Color(0.2, 0.1, 0.05, 0.0), 0.3)
		tween.tween_callback(victim.queue_free)
	Ui.float_text(_board, "Burned out +%d" % event["points"], _board.square_centre(event["square"]), Palette.EMBER, 18)
	await _wait(0.25)


func _animate_promotion(event: Dictionary) -> void:
	var token := _board.token(event["uid"])
	if token != null:
		token.piece_type = event["piece_type"]
		token.is_promoted = true
		token.queue_redraw()
		Ui.pop(token, 1.3)
	Ui.float_text(_board, "Promoted!", _board.square_centre(event["square"]), Palette.BRASS, 20)
	await _wait(0.2)


func _flash_token(token: PieceToken, color: Color) -> void:
	var tween := token.create_tween()
	tween.tween_property(token, "flash_color", Color(color, 0.7), 0.06)
	tween.tween_property(token, "flash_color", Color(color, 0.0), 0.25)


func _side_color(side: int) -> Color:
	return Palette.PIECE_IVORY if side == PLAYER else Palette.OXBLOOD


func _log_line(text: String, event_type: String) -> void:
	if text == "":
		return
	var line := Ui.wrapped(text, "Caption", 230)
	if event_type == "turn_start":
		line.theme_type_variation = "Eyebrow"
	elif event_type in ["capture", "burn_out", "explosion", "match_over"]:
		line.add_theme_color_override("font_color", Palette.IVORY)
	_log.add_child(line)
	while _log.get_child_count() > MAX_LOG_LINES:
		var oldest := _log.get_child(0)
		_log.remove_child(oldest)
		oldest.queue_free()
	_scroll_log_down.call_deferred()


func _scroll_log_down() -> void:
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# --- Match over ---------------------------------------------------------------

func _show_match_over() -> void:
	var result := game.result()
	var player_won := int(result["winner"]) == PLAYER
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	var panel := Ui.panel("ModalPanel")
	panel.custom_minimum_size = Vector2(460, 0)
	centre.add_child(panel)
	var column := Ui.vbox(12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	column.add_child(_centred(Ui.label("MATCH OVER · ROUND %d" % int(result["rounds"]), "Eyebrow")))
	column.add_child(_centred(Ui.label("Victory" if player_won else "Defeat", "Title", Palette.BRASS if player_won else Palette.OXBLOOD)))
	column.add_child(_centred(Ui.label(EventText.reason_text(result["reason"], player_won), "Strong")))
	var scores: Array = result["scores"]
	column.add_child(_centred(Ui.label("You %d  —  %d %s" % [scores[0], scores[1], _names[OPPONENT]], "Stat")))
	var next_text := "Continue"
	if player_won:
		var is_boss: bool = Game.run.current_node_info().get("type", "") == "boss"
		column.add_child(_centred(Ui.label("The boss is beaten." if is_boss else "+%d training points and a new card to choose" % int(GameConfig.value("economy", "win_points")), "Body", Palette.BRASS)))
	else:
		column.add_child(_centred(Ui.label("Your run ends here.", "Body")))
		next_text = "See the run summary"
	var button := Ui.button(next_text, "PrimaryButton")
	button.custom_minimum_size = Vector2(240, 44)
	button.pressed.connect(_finish_match)
	column.add_child(Ui.centered(button))
	_over_status = Ui.status_label()
	_over_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_over_status)
	Ui.fade_in(overlay)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.94
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, Ui.NORMAL).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _centred(node: Label) -> Label:
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


func _finish_match() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	var result := Game.run.finish_match(game.result())
	if not result["ok"]:
		_is_finishing = false
		push_warning("finish_match refused: %s" % result["error"])
		if _over_status != null:
			Ui.flash_status(_over_status, result["error"])
		return
	Game.show_phase()
