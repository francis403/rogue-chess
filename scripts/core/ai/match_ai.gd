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
var _escape_energy_weight: float
var _escapable_threat_factor: float
var _escape_cost: int


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
	_escape_energy_weight = float(weights["escape_energy_weight"])
	_escapable_threat_factor = float(weights["escapable_threat_factor"])
	_escape_cost = int(GameConfig.value("match", "check_escape_cost"))
	var base_costs: Array = GameConfig.data("cards").keys().map(func(card_type: String) -> int: return GameConfig.card_base_cost(card_type))
	_min_card_cost = maxi(base_costs.min(), 1)


## {"kind": "play", "card_index", "from", "to"}, {"kind": "redraw"} or {"kind": "end_turn"};
## while this side must answer a check: {"kind": "escape", "to"} or {"kind": "decline_escape"}.
## Call it only when this AI has to act: its turn, or its pending escape (D57).
func choose_action(game: ChessMatch) -> Dictionary:
	if not game.is_over() and game.pending_escape_side() == side:
		return _escape_decision(game)
	if game.is_over() or game.pending_escape_side() != -1 or game.current_side() != side:
		push_error("MatchAI: choose_action called when this side can't act")
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
		"escape":
			return game.escape(action["to"])
		"decline_escape":
			return game.decline_escape()
	return game.end_turn()


## Static score of the position for this AI's side (higher is better).
func evaluate(game: ChessMatch) -> float:
	if game.is_over():
		return _win_score if int(game.result()["winner"]) == side else -_win_score
	var enemy := 1 - side
	var value := _score_weight * (game.score(side) - game.score(enemy))
	value += _escape_energy_weight * (game.escape_penalty(enemy) - game.escape_penalty(side))
	return value + _side_worth(game, side) - _side_worth(game, enemy)


## D57/D58: escape to the best square (ranked with the threat terms), unless staying is
## better: a shielded king only loses its shield. An unshielded king always escapes,
## even from a checker with 0 energy left (Cheaper cards can cost 0).
func _escape_decision(game: ChessMatch) -> Dictionary:
	var best_to := Vector2i.ZERO
	var best_rank := -INF
	var best_value := -INF
	for to in game.escape_squares():
		var after := game.clone()
		after.escape(to)
		var value := evaluate(after)
		var rank := value if after.is_over() else value - _multi_move_threat(after, _board_copy(after), _enemy_moves(after))
		if rank > best_rank + _tie_epsilon:
			best_rank = rank
			best_value = value
			best_to = to
	if best_rank == -INF or _decline_value(game) > best_value + _tie_epsilon:
		return {"kind": "decline_escape"}
	return {"kind": "escape", "to": best_to}


func _decline_value(game: ChessMatch) -> float:
	var king := _king(game, side)
	if king.shield_active:
		return evaluate(game) - _shield_bonus
	return evaluate(game) - _win_score


## Search model of the enemy answering our check (the same rules as
## _escape_decision, kept cheap): stay if shielded, else escape onto the most
## valuable capture (first square on ties). 0 energy is no reason to stay:
## Cheaper cards can cost 0.
func _resolve_enemy_escape(game: ChessMatch) -> void:
	var defender := game.pending_escape_side()
	if _king(game, defender).shield_active:
		game.decline_escape()
		return
	var squares := game.escape_squares()
	var best_to := squares[0]
	var best_gain := -1
	for to in squares:
		var victim := game.piece_at(to)
		var gain := victim.value() if victim != null else 0
		if gain > best_gain:
			best_gain = gain
			best_to = to
	game.escape(best_to)


func _king(game: ChessMatch, owner: int) -> MatchPiece:
	for piece in game.pieces(owner):
		if piece.type == "king":
			return piece
	return null


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
	if after.pending_escape_side() == 1 - side:
		_resolve_enemy_escape(after)
	var value := evaluate(after) - _energy_weight * game.hand(side)[play["card_index"]].cost()
	if after.is_over():
		return value
	var board := _board_copy(after)
	var enemy_moves := _enemy_moves(after)
	value -= _multi_move_threat(after, board, enemy_moves)
	if search_depth < 2:
		return value
	if _has_winning_follow_up(after, board):
		return value + _win_score * _follow_up_win_factor
	return value - _worst_reply_loss(after, enemy_moves)


## Still this side's turn: can a card left in hand capture the king or win the
## score race right away? The enemy can't answer in between, so it is a sure win.
## (A check the enemy could escape was already resolved on `game`.)
func _has_winning_follow_up(game: ChessMatch, board: MatchBoard) -> bool:
	var hand := game.hand(side)
	var energy := game.energy(side)
	if _cheapest_cost(hand) < 0 or _cheapest_cost(hand) > energy:
		return false
	var most_points := 0
	for piece in game.pieces(side):
		most_points = maxi(most_points, piece.capture_bonus())
	most_points += _trophy_bonus(game, side)
	var points_needed := game.target_score() - game.score(side)
	for victim in game.pieces(1 - side):
		if victim.shield_active or (victim.type != "king" and victim.value() + most_points + _penalty(game, victim) < points_needed):
			continue
		var cache := {}
		for piece in game.pieces(side):
			if not _has_card_for(hand, energy, piece):
				continue
			if not _attack_squares(cache, board, piece, piece.type, victim.square).has(piece.square):
				continue
			var points := victim.value() + piece.capture_bonus() + _trophy_bonus(game, side) + _penalty(game, victim)
			if (victim.type == "king" or points >= points_needed) and _wins_after(game, piece, victim.square):
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
	var victim_points := victim.value() + attacker.capture_bonus() + _trophy_bonus(game, enemy) + _penalty(game, victim)
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
			var caught_points := caught.value() + _trophy_bonus(game, credited) + _penalty(game, caught)
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
## this side's threat_targets pieces (queen, rook) the enemy can take right now and its
## king if some enemy piece can take it within the enemy's next-turn move budget (raw
## moves on a static board, up to 2), plus every open queen-line square around the king.
## A 2-move king threat goes through a check, which this side may escape (D57), so it
## counts less then.
func _multi_move_threat(game: ChessMatch, board: MatchBoard, enemy_moves: Array[Array]) -> float:
	var attacked := {}
	for entry in enemy_moves:
		for to: Vector2i in entry[1]:
			attacked[to] = true
	var budget := mini(_threat_horizon, game.max_energy(1 - side) / _min_card_cost)
	var penalty := 0.0
	for target in game.pieces(side):
		var weight := _threat_weight(target)
		if target.type == "king":
			penalty += _king_exposure_weight * _open_lines(board, target)
		if budget < 1 or weight <= 0.0:
			continue
		if attacked.has(target.square):
			penalty += weight
		elif target.type == "king" and budget >= 2 and _capture_distance(game, board, target, enemy_moves, budget) <= budget:
			penalty += weight * (_escapable_threat_factor if _can_escape(game) else 1.0)
	return penalty


## D59: this side's next-turn budget still covers an escape if the enemy checks it.
func _can_escape(game: ChessMatch) -> bool:
	return game.max_energy(side) - game.escape_penalty(side) >= _escape_cost


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


## Scratch board for MoveGenerator probes. Only ever built from this AI's own search
## clones, so it can hold their pieces directly (place() rewrites the same square).
func _board_copy(game: ChessMatch) -> MatchBoard:
	var board := MatchBoard.new(game.board_size())
	for hole in game.holes():
		board.add_hole(hole)
	for owner in [ChessMatch.PLAYER, ChessMatch.OPPONENT]:
		for piece in game.pieces(owner):
			board.place(piece, piece.square)
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


## foresight's cost, mirroring ChessMatch: a captured player piece gives its
## captor extra points while the player owns it.
func _penalty(game: ChessMatch, victim: MatchPiece) -> int:
	if victim.side != ChessMatch.PLAYER or not game.artifacts(ChessMatch.PLAYER).has("foresight"):
		return 0
	return int(GameConfig.data("artifacts")["artifacts"]["foresight"]["penalty"])
