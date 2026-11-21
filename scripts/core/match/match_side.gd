class_name MatchSide
extends RefCounted
## One side's cards, energy, score and artifacts during a match.
## Cards are copies owned by the match and never mutated, so copies of this
## object may share them.

var side: int
var artifacts: Array[String] = []
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var energy: int = 0
var score: int = 0


func _init(side_index: int, artifact_ids: Array = []) -> void:
	side = side_index
	for artifact_id in artifact_ids:
		artifacts.append(String(artifact_id))


func has_artifact(artifact_id: String) -> bool:
	return artifacts.has(artifact_id)


func artifact_amount(artifact_id: String) -> int:
	if not has_artifact(artifact_id):
		return 0
	return int(GameConfig.data("artifacts")["artifacts"][artifact_id]["amount"])


func card_count() -> int:
	return draw_pile.size() + hand.size() + discard.size()


## Shuffles the deck into the draw pile and puts Book cards on top (a random
## subset if there are more than fit in the opening hand). The pile's top is its end.
func build_draw_pile(deck: Array, hand_size: int, rng: RandomNumberGenerator) -> void:
	for card: CardData in deck:
		draw_pile.append(card.copy())
	shuffle(draw_pile, rng)
	var books := draw_pile.filter(func(card: CardData) -> bool: return card.upgrade == "book")
	for card: CardData in books.slice(0, hand_size):
		draw_pile.erase(card)
		draw_pile.append(card)


func draw_up_to(hand_size: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while hand.size() < hand_size:
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile = discard.duplicate()
			discard.clear()
			shuffle(draw_pile, rng)
			events.append({"type": "shuffle", "side": side, "count": draw_pile.size()})
		var card: CardData = draw_pile.pop_back()
		hand.append(card)
		events.append({"type": "draw", "side": side, "card_uid": card.uid, "card_type": card.type})
	return events


## Discards the hand, keeping Hold cards when `keep_hold`. Returns the discarded card uids.
func discard_hand(keep_hold: bool = true) -> Array[int]:
	var kept: Array[CardData] = []
	var discarded: Array[int] = []
	for card in hand:
		if keep_hold and card.upgrade == "hold":
			kept.append(card)
		else:
			discard.append(card)
			discarded.append(card.uid)
	hand = kept
	return discarded


func copy() -> MatchSide:
	var result := MatchSide.new(side, artifacts)
	result.draw_pile = draw_pile.duplicate()
	result.hand = hand.duplicate()
	result.discard = discard.duplicate()
	result.energy = energy
	result.score = score
	return result


static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
