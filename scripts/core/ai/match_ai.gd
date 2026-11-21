class_name MatchAI
extends RefCounted
## Plays one side of a ChessMatch (D41, D9): its best affordable card play, one
## card at a time. Pure logic; never mutates the match it is given.
## See docs/API.md "## MatchAI".

## Side id of the probe piece in _attack_squares: every real piece is its enemy.
const NO_SIDE := -1

var side: int
var search_depth: int
var random_chance: float

var _rng: RandomNumberGenerator
var _win_score: float
var _score_weight: float
var _material_weight: float
var _shield_bonus: float
var _advance_weight: float
var _energy_weight: float
var _burn_pending_factor: float
var _tie_epsilon: float
var _cheapest_deck_cost: int
var _threat_horizon: int
var _king_threat_penalty: float
var _king_exposure_weight: float
var _follow_up_win_factor: float
var _piece_threat_factor: float
var _threat_targets: Array
var _min_card_cost: int


## `deck` is this side's match deck (setup["opponent"]["deck"]); it tells the AI whether a
## redraw can still pay off. Without it the AI judges by the cards in hand.
func _init(ai_side: int, depth: int, chance: float, rng: RandomNumberGenerator, deck: Array = []) -> void:
	side = ai_side
	search_depth = depth
	random_chance = chance
	_rng = rng
	_cheapest_deck_cost = _cheapest_cost(deck)
	var weights: Dictionary = GameConfig.data("ai")
	_win_score = float(weights["win_score"])
	_score_weight = float(weights["score_weight"])
	_material_weight = float(weights["material_weight"])
	_shield_bonus = float(weights["shield_bonus"])
	_advance_weight = float(weights["advance_weight"])
	_energy_weight = float(weights["energy_weight"])
	_burn_pending_factor = float(weights["burn_pending_factor"])
	_tie_epsilon = float(weights["tie_epsilon"])
	_threat_horizon = int(weights["threat_horizon_moves"])
	_king_threat_penalty = float(weights["king_threat_penalty"])
	_king_exposure_weight = float(weights["king_exposure_weight"])
	_follow_up_win_factor = float(weights["follow_up_win_factor"])
	_piece_threat_factor = float(weights["piece_threat_factor"])
	_threat_targets = weights["threat_targets"]
	var base_costs: Array = GameConfig.data("cards").keys().map(func(card_type: String) -> int: return GameConfig.card_base_cost(card_type))
	_min_card_cost = maxi(base_costs.min(), 1)


## {"kind": "play", "card_index", "from", "to"}, {"kind": "redraw"} or {"kind": "end_turn"}.
## Call it only on this AI's turn of a running match.
func choose_action(game: ChessMatch) -> Dictionary:
	if game.is_over() or game.current_side() != side:
		push_error("MatchAI: choose_action called when it is not this side's turn")
		return {"kind": "end_turn"}
	var plays := game.legal_plays(side)
	if plays.is_empty():
		return {"kind": "redraw"} if _should_redraw(game) else {"kind": "end_turn"}
	if _rng.randf() < random_chance:
		return _play_action(plays[_rng.randi_range(0, plays.size() - 1)])
	return _play_action(_best_play(game, plays))


## Performs an action from choose_action() on the match and returns its events.
static func apply_action(game: ChessMatch, action: Dictionary) -> Array[Dictionary]:
	match action["kind"]:
		"play":
			return game.play(action["card_index"], action["from"], action["to"])
		"redraw":
			return game.redraw()
	return game.end_turn()


## Static score of the position for this AI's side (higher is better).
func evaluate(game: ChessMatch) -> float:
	if game.is_over():
		return _win_score if int(game.result()["winner"]) == side else -_win_score
	var enemy := 1 - side
	var value := _score_weight * (game.score(side) - game.score(enemy))
	return value + _side_worth(game, side) - _side_worth(game, enemy)


## D9, refined: redraw only if the energy left afterwards still pays for the
## cheapest card in the deck (a 0-cost card counts).
func _should_redraw(game: ChessMatch) -> bool:
	if not game.can_redraw():
		return false
	var cheapest := _cheapest_deck_cost if _cheapest_deck_cost >= 0 else _cheapest_cost(game.hand(side))
	if cheapest < 0:
		return false
	return game.energy(side) - int(GameConfig.value("match", "redraw_cost")) >= cheapest


## Lowest card cost in `cards`, -1 if there are none.
func _cheapest_cost(cards: Array) -> int:
	var cheapest := -1
	for card: CardData in cards:
		if cheapest < 0 or card.cost() < cheapest:
			cheapest = card.cost()
	return cheapest


func _play_action(play: Dictionary) -> Dictionary:
	return {"kind": "play", "card_index": play["card_index"], "from": play["from"], "to": play["to"]}


func _best_play(game: ChessMatch, plays: Array[Dictionary]) -> Dictionary:
	var best_value := -INF
	var best: Array[Dictionary] = []
	for play in _cheapest_card_per_move(game, plays):
		var value := _play_value(game, play)
		if value > best_value + _tie_epsilon:
			best_value = value
			best = [play]
		elif value >= best_value - _tie_epsilon:
			best.append(play)
	return best[_rng.randi_range(0, best.size() - 1)]


## The board outcome only depends on (from, to), so simulate each move once,
## with the cheapest card that can make it (a specific card before Move).
func _cheapest_card_per_move(game: ChessMatch, plays: Array[Dictionary]) -> Array[Dictionary]:
	var hand := game.hand(side)
	var by_move := {}
	for play in plays:
		var from: Vector2i = play["from"]
		var to: Vector2i = play["to"]
		var key := Vector4i(from.x, from.y, to.x, to.y)
		if not by_move.has(key) or _is_cheaper(hand[play["card_index"]], hand[by_move[key]["card_index"]]):
			by_move[key] = play
	var result: Array[Dictionary] = []
	result.assign(by_move.values())
	return result


func _is_cheaper(card: CardData, other: CardData) -> bool:
	if card.cost() != other.cost():
		return card.cost() < other.cost()
	return card.type != "move" and other.type == "move"


func _play_value(game: ChessMatch, play: Dictionary) -> float:
	var after := game.clone()
	var events := after.play(play["card_index"], play["from"], play["to"])
	if events[0]["type"] == "error":
		push_error("MatchAI: legal play rejected: %s" % events[0]["reason"])
		return -INF
	var value := evaluate(after) - _energy_weight * game.hand(side)[play["card_index"]].cost()
	if after.is_over():
		return value
	var enemy_moves := _enemy_moves(after)
	value -= _multi_move_threat(after, enemy_moves)
	if search_depth < 2:
		return value
	if _has_winning_follow_up(after):
		return value + _win_score * _follow_up_win_factor
	return value - _worst_reply_loss(after, enemy_moves)


## Still this side's turn: can a card left in hand capture the king or win the
## score race right away? The enemy can't answer in between, so it is a sure win.
func _has_winning_follow_up(game: ChessMatch) -> bool:
	var hand := game.hand(side)
	var energy := game.energy(side)
	var points_needed := game.target_score() - game.score(side)
	for piece in game.pieces(side):
		if not _has_card_for(hand, energy, piece):
			continue
		for to in game.piece_moves(piece.square):
			var victim := game.piece_at(to)
			if victim == null or victim.shield_active:
				continue
			var points := victim.value() + piece.capture_bonus() + _trophy_bonus(game, side)
			if (victim.type == "king" or points >= points_needed) and _wins_after(game, piece, to):
				return true
	return false


## Confirms a candidate winning capture on a copy (e.g. a Powder Keg blast
## could also take our own king, which loses: D13). Only reached for wins.
func _wins_after(game: ChessMatch, piece: MatchPiece, to: Vector2i) -> bool:
	var check := game.clone()
	check.play(_card_index_for(game.hand(side), game.energy(side), piece), piece.square, to)
	return check.is_over() and check.result()["winner"] == side


func _has_card_for(hand: Array[CardData], energy: int, piece: MatchPiece) -> bool:
	return _card_index_for(hand, energy, piece) >= 0


func _card_index_for(hand: Array[CardData], energy: int, piece: MatchPiece) -> int:
	for i in hand.size():
		var card := hand[i]
		if card.cost() <= energy and (card.type == "move" or card.type == piece.type):
			return i
	return -1


## Material, shields, advancement and pending burn-outs of one side.
func _side_worth(game: ChessMatch, owner: int) -> float:
	var worth := 0.0
	for piece in game.pieces(owner):
		worth += _material_weight * piece.value()
		if piece.shield_active:
			worth += _shield_bonus
		if piece.type != "king":
			worth += _advance_weight * _advancement(game, piece)
		if piece.is_burning():
			worth -= _burn_pending_factor * (_score_weight + _material_weight) * piece.value()
	return worth


func _advancement(game: ChessMatch, piece: MatchPiece) -> int:
	return piece.square.y if piece.side == ChessMatch.PLAYER else game.board_size() - 1 - piece.square.y


## [[enemy MatchPiece, its raw moves], ...] for the position after this side's play.
func _enemy_moves(game: ChessMatch) -> Array[Array]:
	var result: Array[Array] = []
	for piece in game.pieces(1 - side):
		result.append([piece, game.piece_moves(piece.square)])
	return result


## Depth 2: the enemy's best raw capture reply (it can't see the enemy's hand,
## so any piece move counts). Only captures change the evaluation; 0 if none hurts.
func _worst_reply_loss(game: ChessMatch, enemy_moves: Array[Array]) -> float:
	var worst := 0.0
	for entry in enemy_moves:
		var attacker: MatchPiece = entry[0]
		for to: Vector2i in entry[1]:
			var victim := game.piece_at(to)
			if victim == null:
				continue
			worst = maxf(worst, _reply_loss(game, attacker, victim))
			if worst >= _win_score:
				return worst
	return worst


## Evaluation lost by this side if the enemy `attacker` captures `victim`,
## mirroring ChessMatch.play(): shield, points, Powder Keg blast, D13 win checks.
func _reply_loss(game: ChessMatch, attacker: MatchPiece, victim: MatchPiece) -> float:
	if victim.shield_active:
		return _shield_bonus if victim.side == side else -_shield_bonus
	var enemy := 1 - side
	var victim_points := victim.value() + attacker.capture_bonus() + _trophy_bonus(game, enemy)
	var points: Array[int] = [0, 0]
	points[enemy] = victim_points
	var kings_lost: Array[bool] = [false, false]
	kings_lost[side] = victim.type == "king"
	var loss := _capture_loss(victim, victim_points)
	if attacker.type == "pawn" and victim.square.y == _far_rank(game, enemy):
		loss += _material_weight * (GameConfig.piece_value("queen") - GameConfig.piece_value("pawn"))
	if game.artifacts(enemy).has("exploding"):
		for offset in MoveGenerator.ALL_DIRECTIONS:
			var caught := game.piece_at(victim.square + offset)
			if caught == null or caught == attacker:
				continue
			if caught.shield_active:
				loss += _shield_bonus if caught.side == side else -_shield_bonus
				continue
			var credited := 1 - caught.side
			var caught_points := caught.value() + _trophy_bonus(game, credited)
			points[credited] += caught_points
			loss += _capture_loss(caught, caught_points)
			kings_lost[caught.side] = kings_lost[caught.side] or caught.type == "king"
	if kings_lost[enemy]:
		return -_win_score
	if kings_lost[side] or game.score(enemy) + points[enemy] >= game.target_score():
		return _win_score
	if game.score(side) + points[side] >= game.target_score():
		return -_win_score
	return loss


## D4: the enemy plays several cards per turn, which one reply can't see. Penalises
## this side's king and threat_targets pieces that some enemy piece can capture
## within the enemy's next-turn move budget (raw moves, board otherwise static),
## plus every open queen-line square around the king.
func _multi_move_threat(game: ChessMatch, enemy_moves: Array[Array]) -> float:
	var board := _board_copy(game)
	var budget := mini(_threat_horizon, game.max_energy(1 - side) / _min_card_cost)
	var penalty := 0.0
	for target in game.pieces(side):
		if target.type == "king":
			penalty += _king_exposure_weight * _open_lines(board, target)
		var weight := _threat_weight(target)
		if budget >= 1 and weight > 0.0 and _capture_distance(game, board, target, enemy_moves, budget) <= budget:
			penalty += weight
	return penalty


## Squares a queen standing on the king's square could move to.
func _open_lines(board: MatchBoard, king: MatchPiece) -> int:
	var probe := MatchPiece.new(0, king.side, king.data)
	probe.type = "queen"
	probe.square = king.square
	return MoveGenerator.moves(board, probe).size()


func _threat_weight(target: MatchPiece) -> float:
	if target.shield_active:
		return 0.0
	if target.type == "king":
		return _king_threat_penalty
	if _threat_targets.has(target.type):
		return _piece_threat_factor * (_score_weight + _material_weight) * target.value()
	return 0.0


## Fewest raw moves (1 or 2, else budget + 1) any enemy piece needs to capture `target`:
## stand on a square it attacks the target from, then take it. A pawn reaching the
## last rank attacks from there as a queen.
func _capture_distance(game: ChessMatch, board: MatchBoard, target: MatchPiece, enemy_moves: Array[Array], budget: int) -> int:
	var cache := {}
	var promotion_rank := _far_rank(game, 1 - side)
	var best := budget + 1
	for entry in enemy_moves:
		var attacker: MatchPiece = entry[0]
		if _attack_squares(cache, board, attacker, attacker.type, target.square).has(attacker.square):
			return 1
		if budget < 2 or best <= 2:
			continue
		for to: Vector2i in entry[1]:
			var type_there := "queen" if attacker.type == "pawn" and to.y == promotion_rank else attacker.type
			if _attack_squares(cache, board, attacker, type_there, target.square).has(to):
				best = 2
				break
	return best


## Squares from which `attacker`, moving as `type`, attacks `square` on this board
## (cached per type and upgrade). Non-pawn movement is symmetric, so it is that
## movement from `square` with every piece counted as capturable.
func _attack_squares(cache: Dictionary, board: MatchBoard, attacker: MatchPiece, type: String, square: Vector2i) -> Array[Vector2i]:
	var key := type + ":" + attacker.data.upgrade
	if cache.has(key):
		return cache[key]
	var squares: Array[Vector2i] = []
	if type == "pawn":
		var behind := -MoveGenerator.forward(attacker.side)
		squares = [square + Vector2i(-1, behind), square + Vector2i(1, behind)]
	else:
		var probe := MatchPiece.new(0, NO_SIDE, attacker.data)
		probe.type = type
		probe.square = square
		squares = MoveGenerator.moves(board, probe)
	cache[key] = squares
	return squares


func _board_copy(game: ChessMatch) -> MatchBoard:
	var board := MatchBoard.new(game.board_size())
	for hole in game.holes():
		board.add_hole(hole)
	for owner in [ChessMatch.PLAYER, ChessMatch.OPPONENT]:
		for piece in game.pieces(owner):
			board.place(piece.copy(), piece.square)
	return board


func _far_rank(game: ChessMatch, owner: int) -> int:
	return game.board_size() - 1 if owner == ChessMatch.PLAYER else 0


## Signed loss for this side when `captured` is removed and `points` go to its opponent.
func _capture_loss(captured: MatchPiece, points: int) -> float:
	var loss := _score_weight * points + _material_weight * captured.value()
	return loss if captured.side == side else -loss


func _trophy_bonus(game: ChessMatch, credited: int) -> int:
	if not game.artifacts(credited).has("capture_bonus"):
		return 0
	return int(GameConfig.data("artifacts")["artifacts"]["capture_bonus"]["amount"])
