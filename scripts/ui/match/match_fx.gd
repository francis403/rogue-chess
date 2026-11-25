class_name MatchFx
extends Node
## The match's event feedback: plays a list of ChessMatch events as sounds,
## tweens and texts (in order; apply() returns when the last one has landed),
## plus the played card flying off the hand. A child of the match screen, so
## every tween and await ends with it.

const PLAYER := ChessMatch.PLAYER
const OPPONENT := ChessMatch.OPPONENT
const NO_SQUARE := BoardView.NO_SQUARE
## Text sizes of the board's float texts and toasts (theme sizes, see UiTheme).
const SCORE_FLOAT_SIZE := UiTheme.H1
const BOOM_SIZE := UiTheme.H1 + 4
const EFFECT_FLOAT_SIZE := UiTheme.H2
const SMALL_FLOAT_SIZE := UiTheme.STRONG
const FLOAT_OUTLINE := 6
const TOAST_PADDING := Metrics.M
## Float texts rise this share of a square, so they stay in the square they start on.
const FLOAT_RISE_CELLS := 0.35
## Where a float text goes, in order: the square above the action, the diagonals
## above, the sides, below, then one square further out (board offsets; rank +1
## is up on screen).
const FLOAT_SPOTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, -1),
	Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(1, 2), Vector2i(-1, 2)]
## Captures worth this many points nudge the board.
const HEAVY_CAPTURE_POINTS := 3
## A played card shrinks to this scale on its way to the piece (it fits in a square).
const FLY_SCALE := 0.35

var game: ChessMatch
var names: Array[String] = []
var view: MatchView
## The screen's hand views (the same array; the screen refills it in place).
var card_views: Array[CardView] = []
## Squares of the pieces giving the last check (the screen marks them as threats).
var last_checkers: Array[Vector2i] = []

## Short-lived CardViews (flying cards, the opponent's revealed card); freed before
## the screen goes idle so only the real hand is left.
var _ghosts: Array[Control] = []
var _banner: Control
var _toast: PanelContainer
var _blast_centre: Vector2i = NO_SQUARE
## True from an explosion until its victims have all been knocked away (they
## resolve together, then the blast gets one beat).
var _is_blast_open: bool = false
## The blast victims' "+N" texts, shown with "Boom!" when the blast closes.
var _blast_floats: Array[Array] = []
## Float texts still on the board; a new turn removes them.
var _floats: Array = []  # untyped: it may hold freed labels
## Bursts are drawn in here: a clip over the board's squares, so rings and shards
## never reach the frame.
var _fx_clip: Control
## The same clip under the pieces: knocked-away victims and the check pulse.
var _under_clip: Control
## The rings pulsing off a checked king (stopped when it escapes).
var _check_pulse: Tween
## Runs as long as the turn banner is up (the opponent's first action waits for it).
var _banner_timer: Tween


func _init(match_view: MatchView, hand_views: Array[CardView]) -> void:
	view = match_view
	game = match_view.game
	names = match_view.names
	card_views = hand_views


func apply(events: Array[Dictionary]) -> void:
	# The game is already in its new state: the hand shows it before the first beat.
	refresh_playable()
	var draws := [0, 0]
	for index in events.size():
		var event := events[index]
		if _is_blast_open and not _is_blast_part(event):
			await _close_blast()
		if event["type"] == "turn_start":
			_log_draws(draws)  # draws so far belong to the turn that is ending
		view.log_line(EventText.describe(event, names), event["type"])
		match event["type"]:
			"draw":
				if event["side"] == OPPONENT and draws[OPPONENT] == 0:
					_deal_opponent_hand()  # on its first draw: the row shows the whole new hand
				draws[event["side"]] += 1
			"turn_start":
				_on_turn_start(event)
			"energy":
				_on_energy(event)
			"redraw":
				_on_redraw_event(event)
			"card_played":
				await _on_card_played(event, events, index)
			"reveal":
				await _animate_reveal()
			"discard":
				await _animate_discard(event)
			"check":
				await _animate_check(event)
			"escape":
				Sfx.play("escape")
				_on_escape(event)
			"escape_declined":
				# A held, tense beat (not ui_cancel, which means "you cancelled").
				Sfx.play("check_stay" if Sfx.has_sound("check_stay") else "turn_opponent")
				_show_toast("%s %s in check" % [names[event["side"]], "stay" if event["side"] == PLAYER else "stays"], Palette.IVORY_SOFT)
			"move":
				await _animate_move(event)
			"capture":
				await _animate_capture(event)
			"shield_block":
				await _animate_block(event)
			"explosion":
				await _animate_explosion(event)
			"score":
				Sfx.play("score_tick")
				view.score.set_score(event["side"], event["total"])
				view.score.flare(event["side"])
			"ignite", "burn_tick":
				await _animate_burn(event)
			"burn_out":
				await _animate_burn_out(event)
			"promotion":
				await _animate_promotion(event)
			"shuffle":
				if event["side"] == PLAYER:
					Sfx.play("card_shuffle")
				Feel.pop(view.piles_label if event["side"] == PLAYER else view.opponent_piles, 1.15, "pop")
	if _is_blast_open:
		await _close_blast()
	_log_draws(draws)
	if not events.is_empty():
		view.sync_tokens()


## "<side> drew N cards" for the draws counted so far, which then reset.
func _log_draws(draws: Array) -> void:
	for side in [PLAYER, OPPONENT]:
		if draws[side] > 0:
			view.log_line("%s drew %d card%s" % [names[side], draws[side], "" if draws[side] == 1 else "s"], "draw")
		draws[side] = 0


## Every hand card looks playable only if it is right now (called as each event
## list starts): energy spent, the turn passing and the check prompt show at once,
## not only when the hand is rebuilt.
func refresh_playable() -> void:
	var hand := game.hand(PLAYER)
	var is_my_turn := view.is_player_turn()
	for card_view in card_views:
		var index := -1
		for i in hand.size():
			if hand[i].uid == card_view.card.uid:
				index = i
		card_view.is_playable = is_my_turn and index >= 0 and game.is_card_playable(index)


func _on_turn_start(event: Dictionary) -> void:
	var side: int = event["side"]
	view.turn_label.text = "Your turn" if side == PLAYER else "%s's turn" % names[OPPONENT]
	view.turn_label.add_theme_color_override("font_color", Palette.IVORY if side == PLAYER else Palette.OXBLOOD_INK)
	view.turn_caption.text = "Round %d of %d" % [event["round"], game.max_rounds()]
	view.sync_opponent_hand()
	view.sync_penalties()
	# No pop on the turn label: the opaque banner covers it, and a scaled label
	# poked out past the banner's left edge (critique 3).
	Sfx.play("turn_player" if side == PLAYER else "turn_opponent")
	_clear_floats()
	_show_turn_banner(side)


## Score and effect texts over the board, on the nearest spot beside `square`
## where they cover no piece glyph and no other float, inside the board frame.
## They rise a little and fade (only fade with reduced motion); a new turn clears them.
func _float(text: String, square: Vector2i, color: Color, font_size: int) -> void:
	var board := view.board
	var label := Ui.label(text, "H2", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Palette.WALNUT_DEEP)
	label.add_theme_constant_override("outline_size", FLOAT_OUTLINE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	board.add_child(label)
	label.reset_size()
	var rise := 0.0 if Motion.reduced() else board.cell() * FLOAT_RISE_CELLS
	var area := _float_area(square, label.size, rise)
	label.set_meta(&"area", area)
	_floats.append(label)
	label.position = Vector2(area.position.x, area.end.y - label.size.y)
	var duration := Motion.time("float")
	var tween := label.create_tween().set_parallel()
	if rise > 0.0:
		tween.tween_property(label, "position:y", area.position.y, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(label.queue_free)


## The area a float sweeps (its size plus the rise), centred on the first square
## in FLOAT_SPOTS around `square` where it is clear of glyphs and other floats,
## clamped inside the grid. Falls back to the first spot on the board.
func _float_area(square: Vector2i, text_size: Vector2, rise: float) -> Rect2:
	var fallback := Rect2()
	for offset in FLOAT_SPOTS:
		var spot := square + offset
		if not view.board.contains_square(spot):
			continue
		var area := _area_at(spot, text_size, rise)
		if fallback.size == Vector2.ZERO:
			fallback = area
		if not _covers_glyph(area) and not _covers_float(area):
			return area
	return fallback if fallback.size != Vector2.ZERO else _area_at(square, text_size, rise)


func _area_at(spot: Vector2i, text_size: Vector2, rise: float) -> Rect2:
	var grid := view.board.grid_rect()
	var size := text_size + Vector2(0, rise)
	var at := (view.board.square_centre(spot) - size / 2.0).floor()
	at.x = clampf(at.x, grid.position.x, maxf(grid.end.x - size.x, grid.position.x))
	at.y = clampf(at.y, grid.position.y, maxf(grid.end.y - size.y, grid.position.y))
	return Rect2(at, size)


## True if `area` reaches into a piece's glyph (a circle a bit smaller than its token).
func _covers_glyph(area: Rect2) -> bool:
	var board := view.board
	var radius := board.cell() * 0.34
	for square in board.occupied_squares():
		var centre := board.square_centre(square)
		var nearest := centre.clamp(area.position, area.end)
		if nearest.distance_to(centre) < radius:
			return true
	return false


func _covers_float(area: Rect2) -> bool:
	for label in _floats:
		if is_instance_valid(label) and (label.get_meta(&"area") as Rect2).intersects(area):
			return true
	return false


## A burst clipped to the board's squares (FxBurst; nothing with reduced motion),
## over the pieces or, with `is_under`, under them.
func _burst(kind: FxBurst.Kind, at: Vector2, color: Color, radius: float, duration: float, is_under: bool = false) -> void:
	var clip := _under() if is_under else _over()
	var burst := FxBurst.spawn(clip, kind, at - clip.position, color, radius, duration)
	if burst != null:
		burst.z_index = 0  # drawn at the clip's layer, so the clip holds


## The clip over the pieces (made on first use, fitted to the grid every time).
func _over() -> Control:
	if not is_instance_valid(_fx_clip):
		_fx_clip = _new_clip(15)
	return _fit_to_grid(_fx_clip)


## The clip under the pieces: the board's first child, so every token draws over it.
func _under() -> Control:
	if not is_instance_valid(_under_clip):
		_under_clip = _new_clip(0)
		view.board.move_child(_under_clip, 0)
	return _fit_to_grid(_under_clip)


func _new_clip(layer: int) -> Control:
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.z_index = layer
	view.board.add_child(clip)
	return clip


func _fit_to_grid(clip: Control) -> Control:
	var grid := view.board.grid_rect()
	clip.position = grid.position
	clip.size = grid.size
	return clip


## Last turn's texts go when a new turn starts, so none lingers under its banner.
func _clear_floats() -> void:
	for label in _floats:
		if is_instance_valid(label):
			label.queue_free()
	_floats.clear()


## Energy refills pip by pip at the start of a turn.
func _on_energy(event: Dictionary) -> void:
	view.sync_penalties()
	if event["side"] == OPPONENT:
		view.opponent_energy.animate_to(event["energy"], Motion.time("pip"))
		return
	Sfx.play("energy_refill")
	view.energy.animate_to(event["energy"], Motion.time("pip"))
	view.energy_label.text = "%d / %d energy" % [event["energy"], game.max_energy(PLAYER)]


func _on_redraw_event(event: Dictionary) -> void:
	view.sync_penalties()
	if event["side"] == OPPONENT:
		view.opponent_energy.animate_to(event["energy"], Motion.time("pip"))
		return
	Sfx.play("card_shuffle")
	view.energy.animate_to(event["energy"], Motion.time("pip"))
	view.energy_label.text = "%d / %d energy" % [event["energy"], game.max_energy(PLAYER)]


## Energy drains pip by pip; the opponent's card is revealed before its move.
func _on_card_played(event: Dictionary, events: Array[Dictionary], index: int) -> void:
	view.sync_penalties()
	Sfx.play("card_play")
	if event["side"] == PLAYER:
		view.energy.animate_to(event["energy"], Motion.time("pip"))
		view.energy_label.text = "%d / %d energy" % [event["energy"], game.max_energy(PLAYER)]
		return
	view.turn_caption.text = "%s plays %s" % [names[OPPONENT], Ui.piece_name(event["card_type"])]
	view.set_hint("%s plays %s." % [names[OPPONENT], Ui.piece_name(event["card_type"])], Palette.IVORY_FAINT, "Opponent's turn")
	view.opponent_hand.remove_card(event["card_uid"])
	view.opponent_energy.animate_to(event["energy"], Motion.time("pip"))
	await _reveal_opponent_card(event, events, index)


## The opponent's new hand (its draw comes at the end of its turn, and at the
## start of the match) deals into its row.
func _deal_opponent_hand() -> void:
	view.sync_opponent_hand()
	Feel.reveal(view.opponent_hand.get_children(), Motion.seconds("deal_stagger"))


## A Scout turns the next hidden cards face up: one after another, each opens
## from edge-on and glows brass (with reduced motion they only fade in).
func _animate_reveal() -> void:
	var faces := view.sync_opponent_hand()
	Sfx.play("reward_reveal")
	Feel.pop(view.opponent_hand.caption, 1.15, "pop")
	var stagger := Motion.time("deal_stagger") * 2.0
	for i in faces.size():
		_flip_up(faces[i], stagger * i)
	await wait(Motion.time("reveal") + stagger * faces.size())


func _flip_up(face: CardView, delay: float) -> void:
	if Motion.reduced():
		face.modulate.a = 0.0
		Motion.tween(face).tween_property(face, "modulate:a", 1.0, Motion.time("reveal")).set_delay(delay)
		return
	face.pivot_offset = CardView.MINI / 2.0
	face.scale = Vector2(0.0, 1.0)
	var tween := Motion.tween(face, "settle")
	tween.tween_property(face, "scale:x", 1.0, Motion.time("reveal")).set_delay(delay)
	tween.tween_callback(Feel.glow.bind(face))


## The opponent's card, face up beside the board, with its piece and target marked
## for a beat before the move.
func _reveal_opponent_card(event: Dictionary, events: Array[Dictionary], index: int) -> void:
	var card := CardView.create(CardData.new(event["card_type"]))
	card.is_interactive = false
	card.z_index = 25
	view.board.add_child(card)
	_ghosts.append(card)
	card.size = CardView.SIZE
	# Left of the rank numbers, never over them.
	var card_right := view.board.origin().x - BoardView.COORD_GUTTER - Metrics.S
	var rest := Vector2(maxf(card_right - CardView.SIZE.x, Metrics.XS), (view.board.size.y - CardView.SIZE.y) / 2.0)
	card.position = rest if Motion.reduced() else rest + Vector2(-Metrics.XL, 0)
	card.modulate.a = 0.0
	var tween := Motion.tween(card).set_parallel()
	tween.tween_property(card, "modulate:a", 1.0, Motion.time("quick"))
	tween.tween_property(card, "position", rest, Motion.time("quick") * 1.5)
	_mark_opponent_play(events, index)
	await wait(Motion.time("reveal_hold"))
	if not is_instance_valid(card):
		return
	var out := Motion.tween(card, "in")
	out.tween_property(card, "modulate:a", 0.0, Motion.time("quick") * 1.5)
	out.tween_callback(card.queue_free)


## Marks the source square and the target of the opponent's play.
func _mark_opponent_play(events: Array[Dictionary], index: int) -> void:
	for later in events.slice(index + 1):
		if later["type"] == "move":
			view.board.set_preview(later["from"], later["to"])
			return
		if later["type"] == "shield_block" and later["attacker_uid"] >= 0:
			view.board.set_preview(later["attacker_square"], later["square"])
			return


## Discarded hand cards drop away (end of turn, redraw); the opponent's row
## fades out in a short beat before its new hand deals in.
func _animate_discard(event: Dictionary) -> void:
	if event["card_uids"].is_empty():
		return
	if event["side"] == OPPONENT:
		view.opponent_hand.sweep_out(Motion.time("sweep"))
		await wait(Motion.time("sweep"))
		return
	Sfx.play("card_discard")
	for card in card_views:
		if event["card_uids"].has(card.card.uid):
			card.sweep_out()
	await wait(Motion.time("sweep"))


## "Your turn" / "<Opponent>'s turn" across the header strip above the board
## (never over the pieces) for a moment. The panel is opaque and wipes open and
## shut from the left (it never fades), so the header under it never shows through
## as doubled text. Reduced motion: it appears and goes without the wipe.
func _show_turn_banner(side: int) -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	var color := Palette.BRASS if side == PLAYER else Palette.OXBLOOD
	var panel := Ui.panel()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Palette.WALNUT_DEEP, color.lerp(Palette.WALNUT_DEEP, 0.2), UiTheme.RADIUS, Metrics.S, 1))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Ui.label("Your turn" if side == PLAYER else "%s's turn" % names[OPPONENT], "H1", Palette.IVORY if side == PLAYER else Palette.OXBLOOD_INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(text)
	# The wipe: a clip whose width opens and closes over the panel.
	_banner = Control.new()
	_banner.clip_contents = true
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.z_index = 28
	_banner.add_child(panel)
	view.fx_layer.add_child(_banner)
	# It covers the whole strip (turn label and score race) while it is up.
	var strip := view.header.get_global_rect()
	panel.custom_minimum_size = strip.size
	panel.reset_size()
	var to_layer := view.fx_layer.get_global_transform().affine_inverse()
	_banner.position = (to_layer * strip.get_center() - panel.size / 2.0).floor()
	_banner.size = Vector2(0.0 if not Motion.reduced() else panel.size.x, panel.size.y)
	var total := Motion.time("banner_in") + Motion.time("banner_hold") + Motion.time("banner_out")
	if _banner_timer != null and _banner_timer.is_valid():
		_banner_timer.kill()
	_banner_timer = create_tween()
	_banner_timer.tween_interval(total)
	var tween := Motion.tween(_banner)
	if Motion.reduced():
		tween.tween_interval(total)
	else:
		tween.tween_property(_banner, "size:x", panel.size.x, Motion.time("banner_in"))
		tween.tween_interval(Motion.time("banner_hold"))
		tween.tween_property(_banner, "size:x", 0.0, Motion.time("banner_out")).set_ease(Tween.EASE_IN)
	tween.tween_callback(_banner.queue_free)


## Seconds until the turn banner has gone (0 when none is up).
func banner_time_left() -> float:
	if _banner_timer == null or not _banner_timer.is_running():
		return 0.0
	var total := Motion.time("banner_in") + Motion.time("banner_hold") + Motion.time("banner_out")
	return maxf(total - _banner_timer.get_total_elapsed_time(), 0.0)


func _animate_check(event: Dictionary) -> void:
	last_checkers.assign(event["checkers"])
	view.board.threats.assign(last_checkers)
	Sfx.play("check")
	await _hit_stop()
	var king_square: Vector2i = event["king_square"]
	var king := view.board.token(game.piece_at(king_square).uid) if game.piece_at(king_square) != null else null
	if king != null:
		king.is_in_check = true
		view.flash_token(king, Palette.OXBLOOD)
		_pulse_check(king_square)
	view.board.flash_squares(last_checkers, Palette.OXBLOOD, Motion.time("check") * 1.4)
	_float("Check!", king_square, Palette.OXBLOOD_INK, SCORE_FLOAT_SIZE)
	if not event["can_escape"]:
		var who := "You have" if event["side"] == PLAYER else "%s has" % names[OPPONENT]
		_show_toast("Check! %s no safe square to escape to" % who, Palette.OXBLOOD, king_square)
	await wait(Motion.time("check"))


## Three rings expand off the checked king, from under its token, clipped to the grid.
func _pulse_check(king_square: Vector2i) -> void:
	_kill_check_pulse()
	if Motion.reduced():
		return
	var duration := Motion.time("check_pulse")
	var at := view.board.square_centre(king_square)
	_check_pulse = create_tween().set_loops(3)
	_check_pulse.tween_callback(_burst.bind(FxBurst.Kind.RING, at, Palette.OXBLOOD, view.board.cell() * 0.8, duration, true))
	_check_pulse.tween_interval(duration)


func _kill_check_pulse() -> void:
	if _check_pulse != null and _check_pulse.is_valid():
		_check_pulse.kill()
	_check_pulse = null


## The impact beat (captures, explosions, check only): the event sequence holds
## for impact_hold (50 ms) before the knock-away, so the impact frame reads on
## its own. Deliberately a beat, not a freeze of running effects: the flash and
## ring that just opened keep growing through the hold, so it reads as the hit
## landing rather than as a dropped frame. See UX_DECISIONS "Hit-stop".
func _hit_stop() -> void:
	if not Motion.reduced():
		await wait(Motion.time("impact_hold"))


func _on_escape(event: Dictionary) -> void:
	view.sync_penalties()
	# The king is out of check the moment it escapes: drop the marks now, not
	# at the end of the sequence (the toast stays up for a while).
	last_checkers.clear()
	view.board.threats.clear()
	view.board.queue_redraw()
	_kill_check_pulse()
	var king := view.board.token(event["uid"])
	if king != null:
		king.is_in_check = false
	var to := EventText.square_name(event["to"])
	if event["side"] == PLAYER:
		_show_toast("You escape to %s: %d less energy next turn" % [to, event["cost"]], Palette.BRASS, event["to"])
	else:
		_show_toast("Check! %s escapes to %s: they'll have %d less energy next turn" % [names[OPPONENT], to, event["cost"]], Palette.BRASS, event["to"])


## A short message on the board (check answers); replaces the previous one. It is
## never wider than the board, and it sits on the half of the board away from
## `avoid` (the square where the action happens), or in the middle without one.
func _show_toast(text: String, color: Color, avoid: Vector2i = NO_SQUARE) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	var board := view.board
	var board_width := board.cell() * board.board_size
	var padding := TOAST_PADDING
	_toast = Ui.panel()
	_toast.add_theme_stylebox_override("panel", UiTheme.box(Palette.WALNUT_DEEP, color, UiTheme.RADIUS, padding, 1))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.z_index = 30
	var text_label := Ui.label(text, "Strong", color)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(text_label)
	board.add_child(_toast)
	var max_width := board_width - 2.0 * (padding + Metrics.M)
	if text_label.get_minimum_size().x > max_width:
		# Too wide for the board: wrap at the board's width.
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.custom_minimum_size.x = max_width
		text_label.size.x = max_width
	_toast.reset_size()
	_toast.position = Vector2(board.origin().x + (board_width - _toast.size.x) / 2.0, _toast_y(avoid)).floor()
	var tween := _toast.create_tween()
	_toast.modulate.a = 0.0
	tween.tween_property(_toast, "modulate:a", 1.0, Motion.time("quick"))
	tween.tween_interval(Motion.time("toast_hold"))
	tween.tween_property(_toast, "modulate:a", 0.0, Motion.time("quick") * 2.0)
	tween.tween_callback(_toast.queue_free)


## Half a square in from the board edge on the side away from `avoid`; centred without one.
func _toast_y(avoid: Vector2i) -> float:
	var board := view.board
	var board_height := board.cell() * board.board_size
	if avoid == NO_SQUARE:
		return board.origin().y + (board_height - _toast.size.y) / 2.0
	var is_avoid_on_top := board.square_centre(avoid).y < board.origin().y + board_height / 2.0
	if is_avoid_on_top:
		return board.origin().y + board_height - board.cell() * 0.5 - _toast.size.y
	return board.origin().y + board.cell() * 0.5


## Crouch, hop (knights higher), land with a squash that matches the piece's weight.
func _animate_move(event: Dictionary) -> void:
	view.board.last_move = [event["from"], event["to"]]
	var token := view.board.token(event["uid"])
	if token == null:
		return
	var is_reduced := Motion.reduced()
	if not is_reduced:
		Motion.tween(token, "soft").tween_property(token, "scale", Vector2(1.1, 0.9), Motion.time("anticipation"))
		# Awaits only MatchFx's own timer: a tween owned by the token never finishes if the token is freed.
		await wait(Motion.time("anticipation"))
		if not is_instance_valid(token):
			view.board.clear_preview()
			return
		Motion.tween(token).tween_property(token, "scale", Vector2.ONE, Motion.time("move") * 0.5)
	Sfx.play("piece_move")
	var distance := view.board.square_centre(event["from"]).distance_to(view.board.square_centre(event["to"]))
	var arc := 0.0 if is_reduced else Motion.arc_height(distance, view.board.cell(), event["piece_type"] == "knight")
	if view.board.move_token(event["uid"], event["to"], Motion.time("move"), arc) != null:
		await wait(Motion.time("move"))
	view.board.clear_preview()
	if is_instance_valid(token):
		_land(token, event)


func _land(token: PieceToken, event: Dictionary) -> void:
	var weight := Motion.land_weight(event["piece_type"])
	if not event["is_capture"]:
		Sfx.play("piece_land_" + weight)
	if Motion.reduced():
		return
	token.scale = Motion.land_squash(weight)
	Motion.tween(token, "settle").tween_property(token, "scale", Vector2.ONE, Motion.time("land"))
	if weight == "heavy":
		Feel.shake(view.board, 0.35, Vector2.DOWN)


## A direct capture: the victim flashes bright on the impact frame, a hit-stop,
## then it is knocked away from its attacker and breaks into shards; the "+N"
## lands on a free square beside it and a big capture nudges the board, all in
## one short beat. Explosion victims skip the impact frame and the beat: the
## blast resolves them together (_close_blast). Reduced motion: it only fades.
func _animate_capture(event: Dictionary) -> void:
	var victim := view.board.forget_token(event["uid"])
	var at := view.board.square_centre(event["square"])
	var is_direct: bool = event["cause"] == "capture"
	Sfx.play(capture_sound(event["by_side"]))
	if victim != null:
		victim.reparent(_under())  # under the piece that took it, and clipped to the grid
	if is_direct:
		_impact_frame(victim, at)
		await _hit_stop()
	var direction := _knock_direction(event)
	if is_instance_valid(victim):
		_knock_away(victim, direction)
	_burst(FxBurst.Kind.SHARDS, at, MatchView.side_color(event["side"]), view.board.cell() * 1.1, Motion.time("burst"))
	if event["points"] > 0:
		var args := ["+%d" % event["points"], event["square"], MatchView.side_color(event["by_side"]), SCORE_FLOAT_SIZE]
		if _is_blast_open:
			_blast_floats.append(args)  # after "Boom!", which gets the best spot
		else:
			_float.callv(args)
	if not is_direct:
		return
	if event["points"] >= HEAVY_CAPTURE_POINTS:
		Feel.shake(view.board, 0.3, direction)
	await wait(Motion.time("capture_beat"))


## The opponent's captures sound darker than the player's (when that sound exists).
static func capture_sound(by_side: int) -> String:
	return "capture_against" if by_side == OPPONENT and Sfx.has_sound("capture_against") else "capture"


## The impact frame: the victim lights up and a pale flash opens on its square.
func _impact_frame(victim: PieceToken, at: Vector2) -> void:
	if Motion.reduced():
		return
	if victim != null:
		victim.flash_color = Color(Palette.IVORY, 0.85)
	_burst(FxBurst.Kind.FLASH, at, Palette.BRASS, view.board.cell() * 0.95, Motion.time("impact_flash"))
	_burst(FxBurst.Kind.RING, at, Palette.IVORY, view.board.cell() * 0.75, Motion.time("impact_flash") * 1.5)


func _knock_direction(event: Dictionary) -> Vector2:
	var source: Vector2i = event["square"]
	if event["cause"] == "explosion":
		source = _blast_centre
	elif view.board.last_move.size() == 2:
		source = view.board.last_move[0]
	var direction := view.board.square_centre(event["square"]) - view.board.square_centre(source)
	return direction.normalized() if direction.length() > 0.5 else Vector2.UP


func _knock_away(victim: PieceToken, direction: Vector2) -> void:
	var duration := Motion.time("impact")
	var tween := victim.create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if not Motion.reduced():
		tween.tween_property(victim, "position", victim.position + direction * view.board.cell() * 0.9, duration)
		tween.tween_property(victim, "rotation", 0.9 if direction.x >= 0.0 else -0.9, duration)
		tween.tween_property(victim, "scale", Vector2.ONE * 0.6, duration)
		tween.tween_property(victim, "flash_color", Color(Palette.IVORY, 0.0), duration * 0.5)
	tween.tween_property(victim, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(victim.queue_free)


## A steel ring on the shield; the attacker lunges in and bounces back.
func _animate_block(event: Dictionary) -> void:
	Sfx.play("shield_block")
	var at := view.board.square_centre(event["square"])
	var defender := view.board.token(event["uid"])
	if defender != null:
		defender.has_shield = false
		view.flash_token(defender, Palette.STEEL)
	view.board.flash_squares([event["square"]], Palette.STEEL, Motion.time("burst"))
	_burst(FxBurst.Kind.RING, at, Palette.STEEL, view.board.cell() * 0.75, Motion.time("burst"))
	_float("Blocked!", event["square"], Palette.STEEL, EFFECT_FLOAT_SIZE)
	var attacker := view.board.token(event["attacker_uid"]) if event["attacker_uid"] >= 0 else null
	if attacker == null:
		if event["cause"] != "explosion":  # a blast's blocks share its beat
			await wait(Motion.time("block"))
		return
	var home := attacker.position
	var lunge := home.lerp(home + at - view.board.square_centre(event["attacker_square"]), 0.45)
	attacker.z_index = 5
	var tween := Motion.tween(attacker)
	tween.tween_property(attacker, "position", lunge, Motion.time("block") * 0.4)
	tween.tween_property(attacker, "position", home, Motion.time("block") * 0.6).set_trans(Tween.TRANS_BACK)
	await wait(Motion.time("block"))
	view.board.clear_preview()
	if not is_instance_valid(attacker):
		return
	attacker.z_index = 0
	view.set_lift(attacker, 0.0)


## Radial flash, a shockwave ring and a board shake, then one hit-stop. The
## blast's victims (the capture / shield_block events right after it) then all
## resolve at once, and _close_blast gives the whole blast a single beat.
func _animate_explosion(event: Dictionary) -> void:
	_blast_centre = event["square"]
	var at := view.board.square_centre(event["square"])
	var squares: Array = event["squares"].duplicate()
	squares.append(event["square"])
	Sfx.play("explosion")
	view.board.flash_squares(squares, Palette.EMBER, Motion.time("burst"))
	_burst(FxBurst.Kind.FLASH, at, Palette.EMBER, view.board.cell() * 1.4, Motion.time("burst"))
	_burst(FxBurst.Kind.RING, at, Palette.EMBER.lightened(0.25), view.board.cell() * 1.7, Motion.time("shockwave"))
	Feel.shake(view.board, 1.4, Vector2(1.0, 0.6))
	await _hit_stop()
	_is_blast_open = true


## Events that resolve inside an open blast (no beat of their own).
func _is_blast_part(event: Dictionary) -> bool:
	if event["type"] == "score":
		return true
	return event["type"] in ["capture", "shield_block"] and event.get("cause", "") == "explosion"


## The blast's victims are gone: "Boom!" on a square it cleared, then one beat.
func _close_blast() -> void:
	_is_blast_open = false
	_float("Boom!", _blast_centre, Palette.EMBER, BOOM_SIZE)
	for args in _blast_floats:
		_float.callv(args)
	_blast_floats.clear()
	await wait(Motion.time("explosion_beat"))


## Ignite: an ember flare. Burn tick: the timer badge pops.
func _animate_burn(event: Dictionary) -> void:
	var is_ignite: bool = event["type"] == "ignite"
	Sfx.play("fire_ignite" if is_ignite else "fire_burn")
	var at := view.board.square_centre(event["square"])
	var token := view.board.token(event["uid"])
	if token != null:
		token.burn_left = event["turns_left"]
		token.can_ignite = false
		view.flash_token(token, Palette.EMBER)
		if not is_ignite and not Motion.reduced():
			Motion.tween(token, "settle").tween_property(token, "burn_pop", 1.0, Motion.time("land") * 1.5).from(1.8)
	if is_ignite:
		_burst(FxBurst.Kind.EMBERS, at, Palette.EMBER, view.board.cell() * 0.8, Motion.time("burst") * 1.5)
	var text := "Ignited" if is_ignite else "Burn %d" % event["turns_left"]
	_float(text, event["square"], Palette.EMBER, SMALL_FLOAT_SIZE)
	await wait(Motion.time("burn_beat"))


## The burned piece darkens and fades into smoke.
func _animate_burn_out(event: Dictionary) -> void:
	Sfx.play("fire_burnout")
	var at := view.board.square_centre(event["square"])
	var victim := view.board.forget_token(event["uid"])
	if victim != null:
		var tween := victim.create_tween()
		tween.tween_property(victim, "modulate", Color(0.2, 0.1, 0.05, 0.0), Motion.time("burnout"))
		tween.tween_callback(victim.queue_free)
	_burst(FxBurst.Kind.SMOKE, at, Palette.IVORY_FAINT, view.board.cell() * 0.7, Motion.time("burnout") * 2.0)
	_float("Burned out +%d" % event["points"], event["square"], Palette.EMBER, SMALL_FLOAT_SIZE)
	await wait(Motion.time("burnout") * 0.75)


## A brass glow; the pawn shrinks, turns into a queen and swells back.
func _animate_promotion(event: Dictionary) -> void:
	Sfx.play("promotion", false)
	var at := view.board.square_centre(event["square"])
	var token := view.board.token(event["uid"])
	_burst(FxBurst.Kind.RING, at, Palette.BRASS, view.board.cell() * 0.8, Motion.time("burst"))
	if token != null:
		view.flash_token(token, Palette.BRASS)
		if Motion.reduced():
			_swap_to_promoted(token, event["piece_type"])
		else:
			var step := Motion.time("promotion") / 3.0
			var tween := Motion.tween(token, "in")
			tween.tween_property(token, "scale", Vector2.ONE * 0.55, step)
			tween.tween_callback(_swap_to_promoted.bind(token, event["piece_type"]))
			tween.tween_property(token, "scale", Vector2.ONE * 1.25, step).set_ease(Tween.EASE_OUT)
			tween.tween_property(token, "scale", Vector2.ONE, step).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_float("Promoted!", event["square"], Palette.BRASS, EFFECT_FLOAT_SIZE)
	await wait(Motion.time("promotion"))


func _swap_to_promoted(token: PieceToken, piece_type: String) -> void:
	token.piece_type = piece_type
	token.is_promoted = true
	token.queue_redraw()


## The played card leaves the hand toward `target` (a global point: the piece it
## moves, or the opponent's hand for a Scout), shrinking and fading; it fades in
## place with reduced motion.
func fly_card(card: CardView, target_point: Vector2) -> void:
	var ghost := CardView.create(card.card, card.size)
	ghost.is_interactive = false
	ghost.is_selected = card.is_selected
	view.fx_layer.add_child(ghost)
	_ghosts.append(ghost)
	ghost.size = card.size
	ghost.pivot_offset = card.size / 2.0  # it shrinks around its centre
	var to_layer := view.fx_layer.get_global_transform().affine_inverse()
	ghost.position = to_layer * card.global_position
	var duration := Motion.time("card_fly")
	var tween := Motion.tween(ghost).set_parallel()
	if not Motion.reduced():
		var target := to_layer * target_point - card.size / 2.0
		# It rises out of the hand first, then glides across; it shrinks early and
		# arrives before it has faded, so it settles on the piece, inside its square.
		tween.tween_property(ghost, "position:y", target.y, duration * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "position:x", target.x, duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ghost, "scale", Vector2.ONE * FLY_SCALE, duration * 0.4)
	tween.tween_property(ghost, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ghost.queue_free)


func clear_ghosts() -> void:
	for ghost in _ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghosts.clear()


func wait(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished
