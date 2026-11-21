extends RefCounted
## Builders and lookups shared by the ChessMatch tests.

const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const FIVE_MOVES: Array = ["move", "move", "move", "move", "move"]


static func piece(type: String, square: Vector2i, set_id: String = "standard", upgrade: String = "") -> Dictionary:
	return {"piece": PieceData.new(type, set_id, upgrade), "square": square}


## "queen:cheaper" -> CardData("queen", "cheaper").
static func cards(specs: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for spec: String in specs:
		var parts := spec.split(":")
		result.append(CardData.new(parts[0], parts[1] if parts.size() > 1 else ""))
	return result


## options: seed, player_artifacts, opponent_artifacts, holes (Array[Vector2i]).
static func setup(player_roster: Array, opponent_roster: Array, player_deck: Array = FIVE_MOVES,
		opponent_deck: Array = FIVE_MOVES, options: Dictionary = {}) -> Dictionary:
	var result := {
		"seed": options.get("seed", 1),
		"player": {"roster": player_roster, "deck": cards(player_deck), "artifacts": options.get("player_artifacts", [])},
		"opponent": {"id": "test", "roster": opponent_roster, "deck": cards(opponent_deck), "artifacts": options.get("opponent_artifacts", [])},
	}
	if options.has("holes"):
		result["holes"] = options["holes"]
	return result


static func make(player_roster: Array, opponent_roster: Array, player_deck: Array = FIVE_MOVES,
		opponent_deck: Array = FIVE_MOVES, options: Dictionary = {}) -> ChessMatch:
	return ChessMatch.new(setup(player_roster, opponent_roster, player_deck, opponent_deck, options))


static func card_index(game: ChessMatch, type: String, upgrade: String = "") -> int:
	var hand := game.hand(game.current_side())
	for i in hand.size():
		if hand[i].type == type and (upgrade == "" or hand[i].upgrade == upgrade):
			return i
	return -1


static func play_type(game: ChessMatch, type: String, from: Vector2i, to: Vector2i) -> Array[Dictionary]:
	return game.play(card_index(game, type), from, to)


static func events_of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(event: Dictionary) -> bool: return event["type"] == type)


static func sorted(squares: Array) -> Array:
	var copy := squares.duplicate()
	copy.sort()
	return copy


static func hand_types(game: ChessMatch, side: int) -> Array[String]:
	var result: Array[String] = []
	for card in game.hand(side):
		result.append(card.type)
	return result


## Everything an illegal action must leave unchanged.
static func snapshot(game: ChessMatch) -> Dictionary:
	var squares := []
	for side in [P, O]:
		for match_piece in game.pieces(side):
			squares.append([match_piece.uid, match_piece.square, match_piece.type, match_piece.shield_active])
	var hand_uids := []
	for side in [P, O]:
		for card in game.hand(side):
			hand_uids.append(card.uid)
	return {
		"side": game.current_side(), "round": game.current_round(), "pieces": squares, "hands": hand_uids,
		"energy": [game.energy(P), game.energy(O)], "scores": [game.score(P), game.score(O)],
		"discard": [game.discard_size(P), game.discard_size(O)], "draw": [game.draw_pile_size(P), game.draw_pile_size(O)],
		"over": game.is_over(),
	}
