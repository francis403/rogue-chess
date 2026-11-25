extends Control
## The match: board, hand, score race, both sides' panels and the event log.
## Every legality question goes to ChessMatch; this script only selects and plays.
## MatchView builds the widgets and refreshes them from the game; MatchFx animates
## the events; MatchOverPanel is the result modal.
## Card-first: card -> piece -> target. Piece-first: piece -> target (cheapest card is used).

const PLAYER := ChessMatch.PLAYER
const OPPONENT := ChessMatch.OPPONENT
const NO_SQUARE := BoardView.NO_SQUARE
const MAX_OPPONENT_ACTIONS := 60
## Pixels a selected piece floats above its shadow.
const PICKUP_LIFT := 7.0
## The hand's shortcut actions, card 1 first (registered by the Settings autoload).
const CARD_ACTIONS: Array[StringName] = [&"rc_card_1", &"rc_card_2", &"rc_card_3", &"rc_card_4", &"rc_card_5"]
## Seconds between checks while a modal holds the opponent's turn.
const MODAL_POLL := 0.1

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
var _view: MatchView
var _fx: MatchFx
var _lifted: PieceToken
var _over_status: Label
var _is_finishing: bool = false
## True while the opponent's actions are playing (clicks and rc_hurry hurry them).
var _is_opponent_acting: bool = false
## Read by tests (tests/integration/test_ui_check_escape.gd).
var _opponent_penalty_tag: Label:
	get:
		return _view.opponent_penalty_tag


func _ready() -> void:
	var setup := Game.match_setup
	_opponent_setup = setup["opponent"]
	_names = ["You", String(_opponent_setup.get("name", "Opponent"))]
	game = ChessMatch.new(setup)
	_move_delay = float(GameConfig.value("ai", "move_delay_seconds"))
	_ai = _make_ai(setup)
	_view = MatchView.new(game, setup, _names)
	_view.build(self)
	_connect_view()
	_fx = MatchFx.new(_view, _card_views)
	add_child(_fx)
	Settings.bindings_changed.connect(_on_bindings_changed)
	_sync()
	_start.call_deferred()


func _exit_tree() -> void:
	Motion.hurry = false  # left mid-turn (Leave run): never carry the hurry over


func _connect_view() -> void:
	_view.board.square_clicked.connect(press_square)
	_view.board.square_hovered.connect(_on_square_hovered)
	_view.board.cancel_requested.connect(_cancel)
	_view.board.card_dropped.connect(press_square)
	_view.redraw_button.pressed.connect(_on_redraw)
	_view.end_turn_button.pressed.connect(_on_end_turn)
	_view.stay_button.pressed.connect(_on_stay)


## Cancel is read here, before the GUI: Godot's viewport spends an Esc on hiding
## a visible tooltip (and marks it handled), so with the mouse resting on a card
## the first Esc never reached _unhandled_input. The event is left unhandled, so
## the tooltip still closes too. The hurry key is read here as well, so a focused
## control never eats it.
func _input(event: InputEvent) -> void:
	if A11y.is_modal_open(self):
		return
	if A11y.is_action(event, &"rc_cancel"):
		_cancel()
	elif A11y.is_action(event, &"rc_hurry") and _is_opponent_acting:
		_hurry()


## The match's shortcuts are InputMap actions (remappable, bound by physical key
## position, so they sit in the same place on any layout).
func _unhandled_input(event: InputEvent) -> void:
	if A11y.is_modal_open(self):
		return
	var is_right_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	# Esc stays the match's own (never the settings) even when cancel is rebound.
	if A11y.is_action(event, &"rc_cancel") or event.is_action_pressed("ui_cancel") or is_right_click:
		get_viewport().set_input_as_handled()
		if is_right_click:
			_cancel()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return
	for card_index in CARD_ACTIONS.size():
		if A11y.is_action(event, CARD_ACTIONS[card_index]):
			if card_index < _card_views.size():
				press_card(card_index)
				get_viewport().set_input_as_handled()
			return
	if _press_shortcut(event):
		get_viewport().set_input_as_handled()


## rc_end_turn ends the turn, rc_redraw redraws, rc_escape_yes escapes (when there
## is exactly one escape square), rc_escape_no stays in check (the card actions are
## read in _unhandled_input). True if the event was used.
func _press_shortcut(event: InputEvent) -> bool:
	if A11y.is_action(event, &"rc_end_turn"):
		return _press_button(_view.end_turn_button)
	if A11y.is_action(event, &"rc_redraw"):
		return _press_button(_view.redraw_button)
	if A11y.is_action(event, &"rc_escape_no"):
		return _press_button(_view.stay_button)
	if A11y.is_action(event, &"rc_escape_yes"):
		return _escape_by_key()
	return false


## A rebind in the settings overlay: key caps and key lines follow at once.
func _on_bindings_changed() -> void:
	_view.refresh_keys()
	for i in _card_views.size():
		_card_views[i].key_hint = _card_key(i)
		_card_views[i].queue_redraw()
	if not _is_busy:
		_show_selection()


## The key cap of the card at `card_index` ("" past the fifth).
static func _card_key(card_index: int) -> String:
	return A11y.key_label(CARD_ACTIONS[card_index]) if card_index < CARD_ACTIONS.size() else ""


## Presses a button as a click would (its sound and handler), if it can be pressed.
func _press_button(button: Button) -> bool:
	if button.disabled or not button.is_visible_in_tree():
		return false
	button.pressed.emit()
	return true


func _escape_by_key() -> bool:
	if not _can_answer_escape():
		return false
	var squares := game.escape_squares()
	if squares.size() == 1:
		_escape(squares[0])
		return true
	Sfx.play("ui_error")
	_view.set_hint("Several escape squares: click one, or press %s to stay." % A11y.key_label(&"rc_escape_no"), Palette.OXBLOOD_INK, "Check")
	return true


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
		Sfx.play("ui_error")
		Feel.shake(_card_views[card_index])
		_view.set_hint(reason, Palette.OXBLOOD_INK, "Not playable")
		return
	Sfx.play("card_select")
	_selected_card = card_index
	var pieces := game.pieces_for_card(card_index)
	if _selected_from == NO_SQUARE or game.targets(card_index, _selected_from).is_empty():
		_selected_from = pieces[0] if pieces.size() == 1 else NO_SQUARE
	_show_selection()


func press_square(square: Vector2i) -> void:
	if _is_opponent_acting:
		_hurry()
		return
	if _can_answer_escape():
		if game.escape_squares().has(square):
			_escape(square)
		else:
			_view.set_hint("Your king is in check. Click a highlighted square to escape, or press Stay.", Palette.OXBLOOD_INK, "Check")
			Sfx.play("ui_error")
			Feel.shake(_view.escape_box)
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
	if square != _selected_from:
		Sfx.play("piece_pickup")
	_selected_from = square
	_show_selection()


func _start() -> void:
	await _run(game.initial_events())


func _sync() -> void:
	_view.sync_tokens()
	_sync_hand()
	_view.sync_panels()
	_show_selection()


## Rebuilds the hand; cards that weren't shown before deal in one after another.
func _sync_hand() -> void:
	var shown_uids: Array[int] = []
	for view in _card_views:
		shown_uids.append(view.card.uid)
	Ui.clear(_view.hand_row)
	_card_views.clear()
	var hand := game.hand(PLAYER)
	var is_my_turn := _view.is_player_turn()
	var dealt := 0
	for card_index in hand.size():
		var view := CardView.create(hand[card_index])
		view.is_playable = is_my_turn and game.is_card_playable(card_index)
		view.key_hint = _card_key(card_index)
		view.drag_payload = {"card_index": card_index}
		view.pressed.connect(press_card.bind(card_index))
		view.drag_started.connect(_on_card_drag_started.bind(card_index))
		if not shown_uids.has(hand[card_index].uid):
			view.deal_delay = Motion.time("deal_stagger") * dealt
			dealt += 1
		_view.hand_row.add_child(view)
		_card_views.append(view)


## Dragging a card selects it (the press that started the drag may have toggled it off).
func _on_card_drag_started(card_index: int) -> void:
	if _selected_card != card_index:
		press_card(card_index)


func _show_selection() -> void:
	_show_marks()
	_update_pickup()


## The selected piece floats above its shadow; the previously lifted one settles.
func _update_pickup() -> void:
	var piece := game.piece_at(_selected_from) if _selected_from != NO_SQUARE and _can_act() else null
	var token := _view.board.token(piece.uid) if piece != null else null
	if token == _lifted:
		return
	_view.set_lift(_lifted, 0.0)
	_lifted = token
	_view.set_lift(token, PICKUP_LIFT)


func _show_marks() -> void:
	_targets.clear()
	for i in _card_views.size():
		_card_views[i].is_selected = i == _selected_card
		_card_views[i].is_highlighted = false
	var is_prompt := not game.is_over() and game.pending_escape_side() == PLAYER
	_view.escape_box.visible = is_prompt
	_view.hint_box.visible = not is_prompt
	_view.keys_box.visible = not is_prompt
	if is_prompt:
		_show_escape_prompt()
		return
	_view.board.threats.clear()
	if game.pending_escape_side() != -1:
		_view.board.threats.assign(_fx.last_checkers)
	if game.pending_escape_side() == OPPONENT:
		# Still the player's turn (the header says so): the opponent answers the check.
		_view.board.clear_highlights()
		_view.set_hint("%s is answering your check…" % _names[OPPONENT], Palette.IVORY_FAINT, "Check")
		return
	if not _view.is_player_turn():
		_view.board.clear_highlights()
		if game.is_over():
			var result := game.result()
			var player_won := int(result["winner"]) == PLAYER
			_view.set_hint(("You win. " if player_won else "You lose. ") + EventText.reason_text(result["reason"], player_won), Palette.IVORY_SOFT, "Match over")
		else:
			_view.set_hint("%s is thinking…" % _names[OPPONENT], Palette.IVORY_FAINT, "Opponent's turn")
		return
	if _selected_card >= 0:
		var card := game.hand(PLAYER)[_selected_card]
		var pieces := game.pieces_for_card(_selected_card)
		if _selected_from == NO_SQUARE:
			_view.board.set_highlights(pieces, [], [])
			_view.set_hint("%s selected. Click a highlighted piece to move it." % card.display_name(), Palette.BRASS, "Card selected")
			return
		_targets = game.targets(_selected_card, _selected_from)
		_highlight_targets(pieces)
		_view.set_hint("Click a target square. A dot moves there; a ring captures." + _ignite_warning(), Palette.BRASS, "Choose a target")
		return
	if _selected_from != NO_SQUARE:
		_targets = MatchUiLogic.targets_for_piece(game, _selected_from)
		_highlight_targets([])
		_view.set_hint("Click a target. The cheapest card that allows the move is played." + _ignite_warning(), Palette.BRASS, "Choose a target")
		return
	_view.board.set_highlights(MatchUiLogic.movable_pieces(game), [], [])
	if game.legal_plays(PLAYER).is_empty():
		_view.set_hint(_stuck_hint(), Palette.IVORY_SOFT, "Nothing to play")
	else:
		_view.set_hint("Pick a card, or click one of your highlighted pieces.", Palette.IVORY_SOFT, "Your turn")


func _show_escape_prompt() -> void:
	var targets := MatchUiLogic.escape_targets(game)
	var king_square := NO_SQUARE
	for piece in game.pieces(PLAYER):
		if piece.type == "king":
			king_square = piece.square
	_view.board.threats.assign(_fx.last_checkers)
	_view.board.set_highlights([], targets["moves"], targets["captures"], king_square)
	var squares := game.escape_squares()
	var stay_key := A11y.key_label(&"rc_escape_no")
	if squares.size() == 1:
		_view.escape_keys_label.text = "%s escape to %s · %s stay" % [MatchView.keys_text(&"rc_escape_yes"), EventText.square_name(squares[0]), stay_key]
	else:
		_view.escape_keys_label.text = "Click a square to escape · %s stay" % stay_key
	_view.escape_cost_label.text = "Costs %d energy from your next turn · next turn: %d/%d" % [
		MatchUiLogic.escape_cost(), MatchUiLogic.next_turn_energy(game, PLAYER, 1), game.max_energy(PLAYER)]
	_view.stay_button.disabled = _is_busy
	_view.set_hint("Check! %s attacks your king." % _names[OPPONENT], Palette.OXBLOOD_INK, "Check")


func _stuck_hint() -> String:
	if not game.can_redraw():
		return "No playable cards left. End your turn."
	if not _view.redraw_helps():
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
	_view.board.set_highlights(movable, moves, captures, _selected_from)


func _on_square_hovered(square: Vector2i) -> void:
	if not _can_act() or _selected_card >= 0 or _selected_from == NO_SQUARE:
		return
	var play := MatchUiLogic.pick_play(game, _selected_from, square) if _targets.has(square) else {}
	for i in _card_views.size():
		_card_views[i].is_highlighted = not play.is_empty() and play["card_index"] == i


func _can_act() -> bool:
	return not _is_busy and _view.is_player_turn()


func _can_answer_escape() -> bool:
	return not _is_busy and not game.is_over() and game.pending_escape_side() == PLAYER


## Esc / right-click: drop the selection. During an escape prompt it only keeps the prompt.
func _cancel() -> void:
	if _selected_card >= 0 or _selected_from != NO_SQUARE:
		Sfx.play("ui_cancel")
	_selected_card = -1
	_selected_from = NO_SQUARE
	if _can_act() or _can_answer_escape():
		_show_selection()


func _escape(to: Vector2i) -> void:
	if not _can_answer_escape():
		return
	_show_busy("Check", "Your king escapes to %s…" % EventText.square_name(to))
	await _run(game.escape(to))


func _on_stay() -> void:
	if not _can_answer_escape():
		return
	_show_busy("Check", "Your king stays in check…")
	await _run(game.decline_escape())


func _refuse(square: Vector2i, reason: String) -> void:
	Sfx.play("ui_error")
	var token := _view.board.token(game.piece_at(square).uid)
	if token != null:
		_view.flash_token(token, Palette.OXBLOOD)
		Feel.shake(token, 0.6)
	_view.set_hint(reason, Palette.OXBLOOD_INK, "Not allowed")


func _play_selected(to: Vector2i) -> void:
	var play := {"card_index": _selected_card, "from": _selected_from, "to": to}
	if _selected_card < 0:
		play = MatchUiLogic.pick_play(game, _selected_from, to)
	if play.is_empty():
		return
	var view := _card_views[play["card_index"]]
	_fx.fly_card(view, _view.board.square_centre(play["from"]))
	_take_from_hand(view)
	_selected_card = -1
	_selected_from = NO_SQUARE
	_lifted = null  # the move animation takes this piece's lift over
	_show_busy("Playing", "Playing %s…" % view.card.display_name())
	await _run(game.play(play["card_index"], play["from"], play["to"]))


## The played card leaves the hand at once (its ghost flies to the piece) and the
## key caps renumber before the move plays. A gap holds its place while the ghost
## leaves, then closes, so the neighbours slide in instead of jumping under it.
func _take_from_hand(view: CardView) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.x = view.size.x
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.hand_row.add_child(gap)
	_view.hand_row.move_child(gap, view.get_index())
	_card_views.erase(view)
	_view.hand_row.remove_child(view)
	view.queue_free()
	var close := Motion.tween(gap, "in")
	close.tween_property(gap, "custom_minimum_size:x", 0.0, Motion.time("card_fly"))
	close.tween_callback(gap.queue_free)
	for i in _card_views.size():
		_card_views[i].key_hint = _card_key(i)
		_card_views[i].queue_redraw()


func _on_redraw() -> void:
	if _can_act() and game.can_redraw():
		_cancel()
		_show_busy("Redrawing", "Discarding your hand and drawing a new one…")
		await _run(game.redraw())


func _on_end_turn() -> void:
	if not _can_act():
		return
	_selected_card = -1
	_selected_from = NO_SQUARE
	_show_busy("Ending turn", "Your unheld cards go to the discard pile…")
	await _run(game.end_turn())


## The hint says what is happening the moment an action starts (it plays out
## over several animated beats before the next decision).
func _show_busy(title: String, text: String) -> void:
	_view.escape_box.visible = false
	_view.hint_box.visible = true
	_view.set_hint(text, Palette.IVORY_SOFT, title)


## Animates the events, then lets the opponent act (its turn, or its answer to
## a check) until the player has to decide something or the match is over.
func _run(events: Array[Dictionary]) -> void:
	_is_busy = true
	_view.end_turn_button.disabled = true
	_view.redraw_button.disabled = true
	_view.board.clear_highlights()
	_update_pickup()
	await _fx.apply(events)
	await _opponent_turn()
	_fx.clear_ghosts()
	_is_busy = false
	_sync()
	if game.is_over():
		# A beat on the final board before the result (anticipation).
		_is_busy = true
		await _fx.wait(Motion.time("over_delay"))
		_is_busy = false
		_show_match_over()


## Plays opponent actions one at a time. Stops when the player must act: their
## turn, or their escape prompt (the opponent's turn resumes after the answer).
## Holding rc_hurry or clicking the board plays the rest of it at "instant" speed;
## an open modal (settings, deck) holds it until it closes.
func _opponent_turn() -> void:
	var actions := 0
	while not game.is_over() and _opponent_must_act():
		_is_opponent_acting = true
		_view.sync_panels()
		_show_selection()
		if Input.is_action_pressed(&"rc_hurry"):
			_hurry()
		_show_hurry_hint()
		# The first action also waits for the turn banner to go.
		await _fx.wait(maxf(_move_delay * Motion.speed(), _fx.banner_time_left()))
		while A11y.is_modal_open(self):
			await _fx.wait(MODAL_POLL)
		var is_escape := game.pending_escape_side() == OPPONENT
		var action := _ai.choose_action(game)
		actions += 1
		if actions > MAX_OPPONENT_ACTIONS:
			action = {"kind": "decline_escape" if is_escape else "end_turn"}
		var events := MatchAI.apply_action(game, action)
		if events.size() == 1 and events[0]["type"] == "error":
			push_error("Opponent action %s refused (%s)" % [action, events[0]["reason"]])
			events = game.decline_escape() if is_escape else game.end_turn()
		await _fx.apply(events)
	_is_opponent_acting = false
	Motion.hurry = false
	_show_hurry_hint()


## The rest of the opponent's turn plays at "instant" speed (the saved animation
## speed is untouched).
func _hurry() -> void:
	if Motion.hurry:
		return
	Motion.hurry = true
	_show_hurry_hint()


func _show_hurry_hint() -> void:
	if not _is_opponent_acting:
		_view.hurry_label.text = ""
	elif Motion.hurry:
		_view.hurry_label.text = "Hurrying…"
	else:
		_view.hurry_label.text = "Hold %s or click the board to hurry" % A11y.key_label(&"rc_hurry")


func _opponent_must_act() -> bool:
	var pending := game.pending_escape_side()
	if pending != -1:
		return pending == OPPONENT
	return game.current_side() == OPPONENT


func _make_ai(setup: Dictionary) -> MatchAI:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(setup.get("seed", 0)) + 1
	return MatchAI.new(OPPONENT, int(_opponent_setup.get("search_depth", 1)), float(_opponent_setup.get("random_chance", 0.0)), rng, _opponent_setup.get("deck", []))


func _show_match_over() -> void:
	var panel := MatchOverPanel.new(game.result(), _names)
	panel.continue_pressed.connect(_finish_match)
	add_child(panel)
	_over_status = panel.status


func _finish_match() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	var result := Game.run.finish_match(game.result())
	if not result["ok"]:
		_is_finishing = false
		push_warning("finish_match refused: %s" % result["error"])
		if _over_status != null:
			Feel.flash_status(_over_status, result["error"])
		return
	Game.show_phase()
