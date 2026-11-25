class_name CardData
extends RefCounted
## A card in the run deck. type is a piece type ("pawn", "knight", "bishop",
## "rook", "queen"), "move", or "scout" (reveals hidden opponent cards, moves
## nothing). upgrade is "", "cheaper", "hold" or "book".

static var _next_uid: int = 1

var uid: int
var type: String
var upgrade: String = ""


func _init(card_type: String = "move", card_upgrade: String = "", card_uid: int = 0) -> void:
	type = card_type
	upgrade = card_upgrade
	uid = card_uid if card_uid > 0 else _next_uid
	_next_uid = maxi(_next_uid, uid + 1)


func cost() -> int:
	var base := GameConfig.card_base_cost(type)
	if upgrade == "cheaper":
		base -= int(GameConfig.data("upgrades")["card"]["cheaper"]["amount"])
	return maxi(base, 0)


func is_rare() -> bool:
	return GameConfig.data("cards")[type]["rarity"] == "rare"


## Cards that reveal hidden opponent cards instead of moving a piece (Scout).
func reveal_amount() -> int:
	return int(GameConfig.data("cards")[type].get("reveal", 0))


func is_reveal() -> bool:
	return reveal_amount() > 0


func display_name() -> String:
	return GameConfig.data("cards")[type]["name"]


func copy() -> CardData:
	return CardData.new(type, upgrade, uid)


func to_dict() -> Dictionary:
	return {"uid": uid, "type": type, "upgrade": upgrade}


static func from_dict(d: Dictionary) -> CardData:
	return CardData.new(d["type"], d.get("upgrade", ""), int(d.get("uid", 0)))
