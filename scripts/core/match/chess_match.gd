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


## An empty setup builds a blank match; only clone() uses that.
func _init(setup: Dictionary = {}) -> void:
	if setup.is_empty():
		return
	_rng.seed = int(setup.get("seed", 0))
	_board = MatchBoard.new(int(_config("board_size")))
	_opponent_id = String(setup["opponent"].get("id", ""))
	_add_side(PLAYER, setup["player"])
	_add_side(OPPONENT, setup["opponent"])
	if setup.has("holes"):
		for square: Vector2i in setup["holes"]:
			_board.add_hole(square)
	else:
		_place_random_holes()
	_first_side = PLAYER if bool(_config("player_moves_first")) else OPPONENT
	_current = _first_side
	_initial_events = _start_turn()


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
func hand(side: int) -> Array[CardData]:
	return _sides[side].hand.duplicate()


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
	if _is_over or side != _current:
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
	return not pieces_for_card(card_index).is_empty()


## Squares of the current side's pieces this card can move now (empty if unaffordable).
func pieces_for_card(card_index: int) -> Array[Vector2i]:
	var result_squares: Array[Vector2i] = []
	for piece in _board.pieces(_current):
		if not targets(card_index, piece.square).is_empty():
			result_squares.append(piece.square)
	return result_squares


## Destinations for playing this card on the piece at `from` (empty if not allowed).
func targets(card_index: int, from: Vector2i) -> Array[Vector2i]:
	if _is_over or card_index < 0 or card_index >= _sides[_current].hand.size():
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
	if _is_over or _sides[_current].energy < int(_config("redraw_cost")):
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
	var mover := _board.piece_at(from)
	var target := _board.piece_at(to)
	if target != null and target.shield_active:
		_consume_shield(target, "capture", mover, events)
		return events
	if target != null:
		_board.remove(to)
	_board.move(from, to)
	_mark_moved(mover)
	events.append({
		"type": "move", "side": _current, "uid": mover.uid, "piece_type": mover.type,
		"from": from, "to": to, "is_capture": target != null,
	})
	if target != null:
		_credit_capture(target, _current, mover.capture_bonus(), "capture", events)
		if side_state.has_artifact("exploding"):
			_explode(to, events)
	_ignite_if_needed(mover, events)
	_promote_if_needed(mover, events)
	_check_winner(_current, events)
	return events


func redraw() -> Array[Dictionary]:
	if not can_redraw():
		return [_error_event("redraw_not_allowed")]
	var side_state := _sides[_current]
	side_state.energy -= int(_config("redraw_cost"))
	var events: Array[Dictionary] = [{"type": "redraw", "side": _current, "energy": side_state.energy}]
	events.append({"type": "discard", "side": _current, "card_uids": side_state.discard_hand(false)})
	events.append_array(side_state.draw_up_to(int(_config("hand_size")), _rng))
	return events


## Ends the current side's turn (also the player's "skip"): burn ticks,
## discard, turn limit, then starts the next side's turn.
func end_turn() -> Array[Dictionary]:
	if _is_over:
		return [_error_event("match_over")]
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
	side_state.energy = max_energy(_current)
	var events: Array[Dictionary] = [
		{"type": "turn_start", "side": _current, "round": _round},
		{"type": "energy", "side": _current, "energy": side_state.energy},
	]
	events.append_array(side_state.draw_up_to(int(_config("hand_size")), _rng))
	if not has_any_piece_move(_current):
		_end_match(1 - _current, "no_moves", events)
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


func _play_error(card_index: int, from: Vector2i, to: Vector2i) -> String:
	if _is_over:
		return "match_over"
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


## Scores a removed piece for `credited_side` (+ both sides' Trophy Case, D27) and records it.
## cause: "capture", "explosion" or "burn_out" (the latter emits a burn_out event).
func _credit_capture(victim: MatchPiece, credited_side: int, extra_points: int, cause: String, events: Array[Dictionary]) -> void:
	var trophy := _sides[credited_side].artifact_amount("capture_bonus") + _sides[victim.side].artifact_amount("capture_bonus")
	var points := victim.value() + extra_points + trophy
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
func _explode(center: Vector2i, events: Array[Dictionary]) -> void:
	var blast: Array[Vector2i] = []
	for offset in MoveGenerator.ALL_DIRECTIONS:
		if _board.in_bounds(center + offset):
			blast.append(center + offset)
	events.append({"type": "explosion", "side": _current, "square": center, "squares": blast})
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
