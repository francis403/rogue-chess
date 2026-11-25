class_name ChessMatch
extends RefCounted
## One match of card-driven 6x6 chess. Pure logic, deterministic for a seed.
## See docs/API.md "## ChessMatch" for the setup shape, actions and events.

const PLAYER := 0
const OPPONENT := 1

var _rng := RandomNumberGenerator.new()
var _board: MatchBoard
var _sides: Array[MatchSide] = []
var _current: int = PLAYER
var _first_side: int = PLAYER
var _round: int = 1
var _is_over: bool = false
var _result: Dictionary = {}
var _opponent_id: String = ""
var _kings_captured: Array[bool] = [false, false]
var _initial_events: Array[Dictionary] = []
var _shields_consumed: Array[int] = []
var _captured: Array[Dictionary] = []
var _player_pieces_used: Array[int] = []
var _player_pieces_moved: Array[int] = []
var _pending_escape_side: int = -1
var _escape_squares: Array[Vector2i] = []
var _escape_penalty: Array[int] = [0, 0]
var _opponent_hidden_base: int = 0
var _hidden_uids: Array[int] = []


## An empty setup builds a blank match; only clone() uses that.
func _init(setup: Dictionary = {}) -> void:
	if setup.is_empty():
		return
	_rng.seed = int(setup.get("seed", 0))
	_board = MatchBoard.new(int(_config("board_size")))
	_opponent_id = String(setup["opponent"].get("id", ""))
	_opponent_hidden_base = maxi(int(setup["opponent"].get("hidden_cards", _config("opponent_hidden_cards"))), 0)
	_add_side(PLAYER, setup["player"])
	_add_side(OPPONENT, setup["opponent"])
	if setup.has("holes"):
		for square: Vector2i in setup["holes"]:
			_board.add_hole(square)
	else:
		_place_random_holes()
	_first_side = PLAYER if bool(_config("player_moves_first")) else OPPONENT
	_current = _first_side
	# The opponent holds its next hand during the player's turn, so it draws now.
	_initial_events = _draw(OPPONENT)
	_initial_events.append_array(_start_turn())


## Events produced by starting the first turn inside the constructor.
func initial_events() -> Array[Dictionary]:
	return _initial_events.duplicate()


func current_side() -> int:
	return _current


func current_round() -> int:
	return _round


func max_rounds() -> int:
	return int(_config("max_rounds"))


func opponent_id() -> String:
	return _opponent_id


func artifacts(side: int) -> Array[String]:
	return _sides[side].artifacts.duplicate()


func energy(side: int) -> int:
	return _sides[side].energy


func max_energy(side: int) -> int:
	return int(_config("energy_per_turn")) + _sides[side].artifact_amount("extra_energy")


## Cards are shared with the match: read them, never modify them.
## The opponent's hand includes its hidden cards: for display use
## visible_opponent_hand() and hidden_card_count() instead.
func hand(side: int) -> Array[CardData]:
	return _sides[side].hand.duplicate()


## The opponent's cards the player may see, in hand order. Read only.
func visible_opponent_hand() -> Array[CardData]:
	var visible: Array[CardData] = []
	for card in _sides[OPPONENT].hand:
		if not _hidden_uids.has(card.uid):
			visible.append(card)
	return visible


## How many of the opponent's cards in hand are hidden from the player.
func hidden_card_count() -> int:
	return _sides[OPPONENT].hand.size() - visible_opponent_hand().size()


func draw_pile_size(side: int) -> int:
	return _sides[side].draw_pile.size()


func discard_size(side: int) -> int:
	return _sides[side].discard.size()


func deck_size(side: int) -> int:
	return _sides[side].card_count()


func score(side: int) -> int:
	return _sides[side].score


func target_score() -> int:
	return int(_config("target_score"))


func board_size() -> int:
	return _board.size


## Live pieces: read them, never modify them.
func pieces(side: int) -> Array[MatchPiece]:
	return _board.pieces(side)


func piece_at(square: Vector2i) -> MatchPiece:
	return _board.piece_at(square)


func holes() -> Array[Vector2i]:
	return _board.holes()


func is_hole(square: Vector2i) -> bool:
	return _board.is_hole(square)


## Side that may answer a check right now (D57), -1 if none. While it is set,
## only escape() / decline_escape() are accepted.
func pending_escape_side() -> int:
	return _pending_escape_side


## Safe king destinations for the pending escape ([] if none pending).
func escape_squares() -> Array[Vector2i]:
	return _escape_squares.duplicate()


## Energy that will be taken off `side`'s next turn for escapes made so far (D59).
func escape_penalty(side: int) -> int:
	return _escape_penalty[side]


## True if an enemy piece could capture `side`'s king with its normal movement.
func in_check(side: int) -> bool:
	var king := _find_king(_board, side)
	return king != null and not _checkers(_board, king).is_empty()


func is_over() -> bool:
	return _is_over


func result() -> Dictionary:
	return _result.duplicate(true)


## Raw movement of the piece on `from`, ignoring cards and turn.
func piece_moves(from: Vector2i) -> Array[Vector2i]:
	var piece := _board.piece_at(from)
	if piece == null:
		return []
	return MoveGenerator.moves(_board, piece)


func has_any_piece_move(side: int) -> bool:
	for piece in _board.pieces(side):
		if not MoveGenerator.moves(_board, piece).is_empty():
			return true
	return false


## Every legal, affordable card play for `side` right now:
## [{"card_index": int, "from": Vector2i, "to": Vector2i}, ...].
## Empty when it is not that side's turn or the match is over.
func legal_plays(side: int) -> Array[Dictionary]:
	var plays: Array[Dictionary] = []
	if _is_over or side != _current or _pending_escape_side != -1:
		return plays
	var hand_cards := _sides[side].hand
	var affordable: Array[int] = []
	for card_index in hand_cards.size():
		if hand_cards[card_index].cost() <= _sides[side].energy:
			affordable.append(card_index)
	for piece in _board.pieces(side):
		var moves: Array[Vector2i] = []
		for card_index in affordable:
			if not _card_fits(hand_cards[card_index], piece):
				continue
			if moves.is_empty():
				moves = MoveGenerator.moves(_board, piece)
			for to in moves:
				plays.append({"card_index": card_index, "from": piece.square, "to": to})
	return plays


func is_card_playable(card_index: int) -> bool:
	var hand_cards := _sides[_current].hand
	if card_index >= 0 and card_index < hand_cards.size() and hand_cards[card_index].is_reveal():
		return can_reveal(card_index)
	return not pieces_for_card(card_index).is_empty()


## A Scout card can be played now: the player's turn, affordable, and an
## opponent card is still hidden.
func can_reveal(card_index: int) -> bool:
	return _reveal_error(card_index) == ""


## Squares of the current side's pieces this card can move now (empty if unaffordable).
func pieces_for_card(card_index: int) -> Array[Vector2i]:
	var result_squares: Array[Vector2i] = []
	for piece in _board.pieces(_current):
		if not targets(card_index, piece.square).is_empty():
			result_squares.append(piece.square)
	return result_squares


## Destinations for playing this card on the piece at `from` (empty if not allowed).
func targets(card_index: int, from: Vector2i) -> Array[Vector2i]:
	if _is_over or _pending_escape_side != -1 or card_index < 0 or card_index >= _sides[_current].hand.size():
		return []
	var piece := _board.piece_at(from)
	if piece == null or piece.side != _current:
		return []
	if not _card_can_move(_sides[_current].hand[card_index], piece):
		return []
	return MoveGenerator.moves(_board, piece)


## D8: only when no card in hand is playable and redraw is affordable.
## Redraw discards the whole hand, Hold cards included, so dead Hold cards can't lock it.
func can_redraw() -> bool:
	if _is_over or _pending_escape_side != -1 or _sides[_current].energy < int(_config("redraw_cost")):
		return false
	return legal_plays(_current).is_empty()


func play(card_index: int, from: Vector2i, to: Vector2i) -> Array[Dictionary]:
	var error := _play_error(card_index, from, to)
	if error != "":
		return [_error_event(error)]
	var side_state := _sides[_current]
	var card: CardData = side_state.hand[card_index]
	side_state.hand.remove_at(card_index)
	side_state.discard.append(card)
	side_state.energy -= card.cost()
	var events: Array[Dictionary] = [{
		"type": "card_played", "side": _current, "card_index": card_index, "card_uid": card.uid,
		"card_type": card.type, "cost": card.cost(), "energy": side_state.energy,
	}]
	_resolve_move(from, to, events)
	if not _is_over:
		_offer_escape_if_check(events)
	return events


## Plays a Scout: no piece moves; the next hidden opponent cards (hand order)
## are shown, never more than are hidden.
func reveal(card_index: int) -> Array[Dictionary]:
	var error := _reveal_error(card_index)
	if error != "":
		return [_error_event(error)]
	var side_state := _sides[_current]
	var card: CardData = side_state.hand[card_index]
	side_state.hand.remove_at(card_index)
	side_state.discard.append(card)
	side_state.energy -= card.cost()
	var amount := card.reveal_amount()
	var revealed := 0
	for hand_card in _sides[OPPONENT].hand:
		if revealed < amount and _hidden_uids.has(hand_card.uid):
			_hidden_uids.erase(hand_card.uid)
			revealed += 1
	return [
		{
			"type": "card_played", "side": _current, "card_index": card_index, "card_uid": card.uid,
			"card_type": card.type, "cost": card.cost(), "energy": side_state.energy,
		},
		{"type": "reveal", "side": _current, "count": revealed, "hidden": hidden_card_count()},
	]


## D57: the checked king moves to one of escape_squares(), out of turn and
## without a card. Its cost comes off the escaping side's next turn (D59).
func escape(to: Vector2i) -> Array[Dictionary]:
	if _is_over or _pending_escape_side == -1:
		return [_error_event("no_escape_pending")]
	if not _escape_squares.has(to):
		return [_error_event("illegal_move")]
	var side := _pending_escape_side
	var king := _find_king(_board, side)
	_clear_pending_escape()
	_escape_penalty[side] += int(_config("check_escape_cost"))
	var events: Array[Dictionary] = [{
		"type": "escape", "side": side, "uid": king.uid, "from": king.square, "to": to,
		"cost": int(_config("check_escape_cost")), "penalty": _escape_penalty[side],
	}]
	_resolve_move(king.square, to, events)
	return events


## D58: leave the king in check; the checking side continues its turn.
func decline_escape() -> Array[Dictionary]:
	if _is_over or _pending_escape_side == -1:
		return [_error_event("no_escape_pending")]
	var side := _pending_escape_side
	_clear_pending_escape()
	return [{"type": "escape_declined", "side": side}]


func redraw() -> Array[Dictionary]:
	if _pending_escape_side != -1:
		return [_error_event("escape_pending")]
	if not can_redraw():
		return [_error_event("redraw_not_allowed")]
	var side_state := _sides[_current]
	side_state.energy -= int(_config("redraw_cost"))
	var events: Array[Dictionary] = [{"type": "redraw", "side": _current, "energy": side_state.energy}]
	events.append({"type": "discard", "side": _current, "card_uids": side_state.discard_hand(false)})
	events.append_array(_draw(_current))
	return events


## Ends the current side's turn (also the player's "skip"): burn ticks,
## discard, turn limit, then starts the next side's turn.
func end_turn() -> Array[Dictionary]:
	if _is_over:
		return [_error_event("match_over")]
	if _pending_escape_side != -1:
		return [_error_event("escape_pending")]
	var events: Array[Dictionary] = []
	var side := _current
	_tick_burns(side, events)
	if _is_over:
		return events
	events.append({"type": "discard", "side": side, "card_uids": _sides[side].discard_hand()})
	events.append({"type": "turn_end", "side": side, "round": _round})
	if side != _first_side and _round >= max_rounds():
		_end_by_turn_limit(events)
		return events
	if side == OPPONENT:
		events.append_array(_draw(OPPONENT))
	_current = 1 - side
	if _current == _first_side:
		_round += 1
	events.append_array(_start_turn())
	return events


## Deep copy for AI search. Cards and PieceData are shared (both read-only here).
func clone() -> ChessMatch:
	var copy := ChessMatch.new()
	copy._rng.seed = _rng.seed
	copy._rng.state = _rng.state
	copy._board = _board.copy()
	for side_state in _sides:
		copy._sides.append(side_state.copy())
	copy._current = _current
	copy._first_side = _first_side
	copy._round = _round
	copy._is_over = _is_over
	copy._result = _result.duplicate(true)
	copy._opponent_id = _opponent_id
	copy._kings_captured = _kings_captured.duplicate()
	copy._shields_consumed = _shields_consumed.duplicate()
	copy._captured = _captured.duplicate(true)
	copy._player_pieces_used = _player_pieces_used.duplicate()
	copy._player_pieces_moved = _player_pieces_moved.duplicate()
	copy._pending_escape_side = _pending_escape_side
	copy._escape_squares = _escape_squares.duplicate()
	copy._escape_penalty = _escape_penalty.duplicate()
	copy._opponent_hidden_base = _opponent_hidden_base
	copy._hidden_uids = _hidden_uids.duplicate()
	return copy


func _add_side(side: int, side_setup: Dictionary) -> void:
	var side_state := MatchSide.new(side, side_setup.get("artifacts", []))
	side_state.build_draw_pile(side_setup.get("deck", []), int(_config("hand_size")), _rng)
	_sides.append(side_state)
	for entry: Dictionary in side_setup.get("roster", []):
		var square: Vector2i = entry["square"]
		var is_free := _board.in_bounds(square) and _board.piece_at(square) == null
		assert(is_free, "ChessMatch: invalid roster square %s" % square)
		if not is_free:
			continue
		var data: PieceData = entry["piece"]
		var uid := _board.pieces(PLAYER).size() + _board.pieces(OPPONENT).size() + 1
		_board.place(MatchPiece.new(uid, side, data.copy()), square)
		if side == PLAYER:
			_player_pieces_used.append(data.uid)


## D28: if either side has Sinkholes, place min..max holes on empty middle squares.
func _place_random_holes() -> void:
	if not (_sides[PLAYER].has_artifact("holes") or _sides[OPPONENT].has_artifact("holes")):
		return
	var hole_config: Dictionary = GameConfig.data("artifacts")["artifacts"]["holes"]
	var count := _rng.randi_range(int(hole_config["min"]), int(hole_config["max"]))
	var deploy_rows := int(_config("deploy_rows"))
	var candidates: Array[Vector2i] = []
	for y in range(deploy_rows, _board.size - deploy_rows):
		for x in _board.size:
			if _board.is_empty(Vector2i(x, y)):
				candidates.append(Vector2i(x, y))
	for _i in mini(count, candidates.size()):
		_board.add_hole(candidates.pop_at(_rng.randi_range(0, candidates.size() - 1)))


func _start_turn() -> Array[Dictionary]:
	var side_state := _sides[_current]
	var penalty := _escape_penalty[_current]
	_escape_penalty[_current] = 0
	side_state.energy = maxi(max_energy(_current) - penalty, 0)
	var events: Array[Dictionary] = [
		{"type": "turn_start", "side": _current, "round": _round, "escape_penalty": penalty},
		{"type": "energy", "side": _current, "energy": side_state.energy, "escape_penalty": penalty},
	]
	events.append_array(_draw(_current))
	if not has_any_piece_move(_current):
		_end_match(1 - _current, "no_moves", events)
	return events


## Draws `side` up to the hand size. When the opponent draws, its new hand
## gets its hidden cards: the last ones drawn, `hidden_cards` minus foresight.
## The opponent's draw events don't say which card was drawn.
func _draw(side: int) -> Array[Dictionary]:
	var events := _sides[side].draw_up_to(int(_config("hand_size")), _rng)
	if side != OPPONENT or events.is_empty():
		return events
	var hand_cards := _sides[OPPONENT].hand
	var count := clampi(_opponent_hidden_base - _sides[PLAYER].artifact_amount("foresight"), 0, hand_cards.size())
	_hidden_uids.clear()
	for card in hand_cards.slice(hand_cards.size() - count):
		_hidden_uids.append(card.uid)
	for event in events:
		event.erase("card_type")
	return events


## D24: burning pieces of `side` lose one turn; at 0 they are removed and
## credited to the opponent as a capture.
func _tick_burns(side: int, events: Array[Dictionary]) -> void:
	for piece in _board.pieces(side):
		if not piece.is_burning():
			continue
		piece.burn_turns_left -= 1
		events.append({"type": "burn_tick", "side": side, "uid": piece.uid, "square": piece.square, "turns_left": piece.burn_turns_left})
		if piece.is_burning():
			continue
		_board.remove(piece.square)
		_credit_capture(piece, 1 - side, 0, "burn_out", events)
	_check_winner(side, events)


func _end_by_turn_limit(events: Array[Dictionary]) -> void:
	var winner := PLAYER if score(PLAYER) > score(OPPONENT) else OPPONENT
	_end_match(winner, "turn_limit", events)


## Moves the piece on `from` (a card play or an escape) and resolves shield,
## capture, explosion, ignite, promotion and the win check for its side.
func _resolve_move(from: Vector2i, to: Vector2i, events: Array[Dictionary]) -> void:
	var mover := _board.piece_at(from)
	var side := mover.side
	var target := _board.piece_at(to)
	if target != null and target.shield_active:
		_consume_shield(target, "capture", mover, events)
		return
	if target != null:
		_board.remove(to)
	_board.move(from, to)
	_mark_moved(mover)
	events.append({
		"type": "move", "side": side, "uid": mover.uid, "piece_type": mover.type,
		"from": from, "to": to, "is_capture": target != null,
	})
	if target != null:
		_credit_capture(target, side, mover.capture_bonus(), "capture", events)
		if _sides[side].has_artifact("exploding"):
			_explode(to, side, events)
	_ignite_if_needed(mover, events)
	_promote_if_needed(mover, events)
	_check_winner(side, events)


## D56-D60: after a card play, a checked enemy king may escape if it has a
## safe square and its next-turn budget still covers the cost.
func _offer_escape_if_check(events: Array[Dictionary]) -> void:
	var defender := 1 - _current
	var king := _find_king(_board, defender)
	if king == null:
		return
	var checkers := _checkers(_board, king)
	if checkers.is_empty():
		return
	var budget := max_energy(defender) - _escape_penalty[defender]
	var squares: Array[Vector2i] = []
	if budget >= int(_config("check_escape_cost")):
		squares = _safe_king_squares(king)
	events.append({
		"type": "check", "side": defender, "king_square": king.square, "checkers": checkers,
		"escape_squares": squares, "can_escape": not squares.is_empty(),
		"cost": int(_config("check_escape_cost")), "budget": budget,
	})
	if not squares.is_empty():
		_pending_escape_side = defender
		_escape_squares = squares


## King destinations that actually move the king (no shielded piece there)
## and where no enemy piece could capture it afterwards.
func _safe_king_squares(king: MatchPiece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for to in MoveGenerator.moves(_board, king):
		var target := _board.piece_at(to)
		if target != null and target.shield_active:
			continue
		var board := _board.copy()
		board.remove(to)
		board.move(king.square, to)
		if _checkers(board, board.piece_at(to)).is_empty():
			squares.append(to)
	return squares


func _checkers(board: MatchBoard, king: MatchPiece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for piece in board.pieces(1 - king.side):
		if MoveGenerator.moves(board, piece).has(king.square):
			squares.append(piece.square)
	return squares


func _find_king(board: MatchBoard, side: int) -> MatchPiece:
	for piece in board.pieces(side):
		if piece.type == "king":
			return piece
	return null


func _clear_pending_escape() -> void:
	_pending_escape_side = -1
	_escape_squares.clear()


func _reveal_error(card_index: int) -> String:
	if _is_over:
		return "match_over"
	if _pending_escape_side != -1:
		return "escape_pending"
	if _current != PLAYER:
		return "player_only"
	var side_state := _sides[_current]
	if card_index < 0 or card_index >= side_state.hand.size():
		return "bad_card_index"
	var card: CardData = side_state.hand[card_index]
	if not card.is_reveal():
		return "wrong_card"
	if card.cost() > side_state.energy:
		return "not_enough_energy"
	if hidden_card_count() == 0:
		return "nothing_hidden"
	return ""


func _play_error(card_index: int, from: Vector2i, to: Vector2i) -> String:
	if _is_over:
		return "match_over"
	if _pending_escape_side != -1:
		return "escape_pending"
	var side_state := _sides[_current]
	if card_index < 0 or card_index >= side_state.hand.size():
		return "bad_card_index"
	var card: CardData = side_state.hand[card_index]
	var piece := _board.piece_at(from)
	if piece == null or piece.side != _current:
		return "no_own_piece"
	if not _card_fits(card, piece):
		return "wrong_card"
	if card.cost() > side_state.energy:
		return "not_enough_energy"
	if not MoveGenerator.moves(_board, piece).has(to):
		return "illegal_move"
	return ""


## A card moves a piece of its type; Move moves any piece (the king only this way).
func _card_fits(card: CardData, piece: MatchPiece) -> bool:
	return card.type == "move" or card.type == piece.type


func _card_can_move(card: CardData, piece: MatchPiece) -> bool:
	return _card_fits(card, piece) and card.cost() <= _sides[piece.side].energy


## Scores a removed piece for `credited_side` (+ Trophy Case, D27) and records it.
## cause: "capture", "explosion" or "burn_out" (the latter emits a burn_out event).
func _credit_capture(victim: MatchPiece, credited_side: int, extra_points: int, cause: String, events: Array[Dictionary]) -> void:
	var points := victim.value() + extra_points + _sides[credited_side].artifact_amount("capture_bonus")
	# foresight's cost: a captured player piece is worth more to the opponent.
	if victim.side == PLAYER:
		points += _sides[PLAYER].artifact_amount("foresight", "penalty")
	_sides[credited_side].score += points
	if victim.type == "king":
		_kings_captured[victim.side] = true
	_captured.append({
		"uid": victim.data.uid, "side": victim.side, "type": victim.type,
		"by_side": credited_side, "points": points, "cause": cause,
	})
	events.append({
		"type": "burn_out" if cause == "burn_out" else "capture", "cause": cause,
		"side": victim.side, "uid": victim.uid, "piece_type": victim.type,
		"square": victim.square, "by_side": credited_side, "points": points,
	})
	if points > 0:
		events.append({"type": "score", "side": credited_side, "points": points, "total": _sides[credited_side].score})


## D29: the 8 squares around `center` explode; no chain reactions.
func _explode(center: Vector2i, side: int, events: Array[Dictionary]) -> void:
	var blast: Array[Vector2i] = []
	for offset in MoveGenerator.ALL_DIRECTIONS:
		if _board.in_bounds(center + offset):
			blast.append(center + offset)
	events.append({"type": "explosion", "side": side, "square": center, "squares": blast})
	for square in blast:
		var victim := _board.piece_at(square)
		if victim == null:
			continue
		if victim.shield_active:
			_consume_shield(victim, "explosion", null, events)
			continue
		_board.remove(square)
		_credit_capture(victim, 1 - victim.side, 0, "explosion", events)


## D20: the shield is used up; the attacker (if any) stays where it was.
func _consume_shield(piece: MatchPiece, cause: String, attacker: MatchPiece, events: Array[Dictionary]) -> void:
	piece.shield_active = false
	if piece.side == PLAYER:
		_shields_consumed.append(piece.data.uid)
	events.append({
		"type": "shield_block", "cause": cause, "side": piece.side, "uid": piece.uid, "square": piece.square,
		"attacker_uid": attacker.uid if attacker != null else -1,
		"attacker_square": attacker.square if attacker != null else piece.square,
	})


func _mark_moved(piece: MatchPiece) -> void:
	piece.has_moved = true
	if piece.side == PLAYER and not _player_pieces_moved.has(piece.data.uid):
		_player_pieces_moved.append(piece.data.uid)


## D24: a Fire piece ignites the first time it moves; moving again keeps the timer.
func _ignite_if_needed(piece: MatchPiece, events: Array[Dictionary]) -> void:
	if piece.is_burning() or piece.burn_turns() <= 0:
		return
	piece.burn_turns_left = piece.burn_turns()
	events.append({"type": "ignite", "side": piece.side, "uid": piece.uid, "square": piece.square, "turns_left": piece.burn_turns_left})


## D12: a pawn on the far rank becomes a queen for the rest of the match.
func _promote_if_needed(piece: MatchPiece, events: Array[Dictionary]) -> void:
	var far_rank := _board.size - 1 if piece.side == PLAYER else 0
	if piece.type != "pawn" or piece.square.y != far_rank:
		return
	piece.type = "queen"
	piece.is_promoted = true
	events.append({"type": "promotion", "side": piece.side, "uid": piece.uid, "square": piece.square, "piece_type": piece.type})


## D13 order: kings first (both dead -> the acting side loses), then score
## (both at target -> the acting side wins).
func _check_winner(acting_side: int, events: Array[Dictionary]) -> void:
	if _is_over:
		return
	var other := 1 - acting_side
	if _kings_captured[acting_side]:
		_end_match(other, "king", events)
	elif _kings_captured[other]:
		_end_match(acting_side, "king", events)
	elif score(acting_side) >= target_score():
		_end_match(acting_side, "score", events)
	elif score(other) >= target_score():
		_end_match(other, "score", events)


func _end_match(winner: int, reason: String, events: Array[Dictionary]) -> void:
	_is_over = true
	_result = {
		"winner": winner,
		"reason": reason,
		"scores": [score(PLAYER), score(OPPONENT)],
		"rounds": _round,
		"opponent_id": _opponent_id,
		"shields_consumed": _shields_consumed.duplicate(),
		"player_pieces_used": _player_pieces_used.duplicate(),
		"player_pieces_moved": _player_pieces_moved.duplicate(),
		"captured": _captured.duplicate(true),
	}
	events.append({"type": "match_over", "winner": winner, "reason": reason, "scores": [score(PLAYER), score(OPPONENT)], "rounds": _round})


func _error_event(reason: String) -> Dictionary:
	return {"type": "error", "reason": reason}


func _config(key: String) -> Variant:
	return GameConfig.data("match")[key]
