class_name MatchUiLogic
extends RefCounted
## Pure helpers the match screen uses on top of ChessMatch.legal_plays().
## No rules here: every answer is filtered from what the engine says is legal.


## Every square the piece on `from` can reach with any playable card of the side to move.
static func targets_for_piece(game: ChessMatch, from: Vector2i) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for play in game.legal_plays(game.current_side()):
		if play["from"] == from and not squares.has(play["to"]):
			squares.append(play["to"])
	return squares


## Squares of the side-to-move's pieces that have at least one legal play.
static func movable_pieces(game: ChessMatch) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for play in game.legal_plays(game.current_side()):
		if not squares.has(play["from"]):
			squares.append(play["from"])
	return squares


## Index of the first Scout in the side-to-move's hand that can be played now,
## or -1. A Scout moves no piece, so legal_plays() never lists it.
static func playable_reveal(game: ChessMatch) -> int:
	var hand := game.hand(game.current_side())
	for i in hand.size():
		if hand[i].is_reveal() and game.is_card_playable(i):
			return i
	return -1


## Whether any card in hand can be played now: a move, or a Scout.
static func has_play(game: ChessMatch) -> bool:
	return not game.legal_plays(game.current_side()).is_empty() or playable_reveal(game) != -1


## The play for a piece-first move: the cheapest card that allows from -> to,
## preferring the piece's own card over Move on a tie. {} if none.
static func pick_play(game: ChessMatch, from: Vector2i, to: Vector2i) -> Dictionary:
	var hand := game.hand(game.current_side())
	var best: Dictionary = {}
	for play in game.legal_plays(game.current_side()):
		if play["from"] != from or play["to"] != to:
			continue
		if best.is_empty() or _is_better(hand[play["card_index"]], hand[best["card_index"]]):
			best = play
	return best


## Whether energy left after a redraw still pays for the cheapest card in the deck
## (a redraw that can't lead to a play only burns energy). deck: Array of CardData.
## A Scout only counts while an opponent card is hidden.
static func redraw_leaves_a_play(energy: int, redraw_cost: int, deck: Array, has_hidden: bool) -> bool:
	var cheapest := -1
	for card: CardData in deck:
		if card.is_reveal() and not has_hidden:
			continue
		if cheapest == -1 or card.cost() < cheapest:
			cheapest = card.cost()
	return cheapest != -1 and energy - redraw_cost >= cheapest


static func escape_cost() -> int:
	return int(GameConfig.value("match", "check_escape_cost"))


## Energy `side` will start its next turn with, counting escapes made so far plus
## `extra_escapes` more (D59).
static func next_turn_energy(game: ChessMatch, side: int, extra_escapes: int = 0) -> int:
	return maxi(game.max_energy(side) - game.escape_penalty(side) - extra_escapes * escape_cost(), 0)


## The pending escape's destinations split into plain moves and captures.
static func escape_targets(game: ChessMatch) -> Dictionary:
	var moves: Array[Vector2i] = []
	var captures: Array[Vector2i] = []
	for square in game.escape_squares():
		if game.piece_at(square) != null:
			captures.append(square)
		else:
			moves.append(square)
	return {"moves": moves, "captures": captures}


## Why a card can't be played right now ("" if it can).
static func unplayable_reason(game: ChessMatch, card_index: int) -> String:
	if game.is_card_playable(card_index):
		return ""
	var card: CardData = game.hand(game.current_side())[card_index]
	if card.cost() > game.energy(game.current_side()):
		return "Not enough energy for %s (costs %d)" % [card.display_name(), card.cost()]
	if card.is_reveal():
		return "No hidden cards to reveal"
	if card.type == "move":
		return "No piece can move"
	return "No %s can move right now" % card.type


static func _is_better(candidate: CardData, current: CardData) -> bool:
	if candidate.cost() != current.cost():
		return candidate.cost() < current.cost()
	return candidate.type != "move" and current.type == "move"
