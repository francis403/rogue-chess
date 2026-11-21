class_name PieceData
extends RefCounted
## A piece in the player's collection (persists through the run).
## type: "pawn", "knight", "bishop", "rook", "queen", "king".
## piece_set: "standard" or "fire". upgrade: "", "range", "deploy", "shield".

static var _next_uid: int = 1

var uid: int
var type: String
var piece_set: String = "standard"
var upgrade: String = ""


func _init(piece_type: String = "pawn", set_id: String = "standard", piece_upgrade: String = "", piece_uid: int = 0) -> void:
	type = piece_type
	piece_set = set_id
	upgrade = piece_upgrade
	uid = piece_uid if piece_uid > 0 else _next_uid
	_next_uid = maxi(_next_uid, uid + 1)


## True if this piece follows its set's special rules (e.g. Fire burning).
## The king never does when the set says king_is_fire = false.
func is_set_piece() -> bool:
	if piece_set == "standard":
		return false
	var set_cfg: Dictionary = GameConfig.data("piece_sets")["sets"][piece_set]
	return type != "king" or bool(set_cfg.get("king_is_fire", false))


## Capture points (and base pick cost) including the set modifier. Never below 0.
func value() -> int:
	var v := GameConfig.piece_value(type)
	if is_set_piece():
		v += int(GameConfig.data("piece_sets")["sets"][piece_set]["value_modifier"])
	return maxi(v, 0)


## Cost to include this piece in a match roster. The king is always free.
func deploy_cost() -> int:
	if type == "king":
		return 0
	var c := value()
	if upgrade == "deploy":
		c -= int(GameConfig.data("upgrades")["piece"]["deploy"]["amount"])
	return maxi(c, 0)


func copy() -> PieceData:
	return PieceData.new(type, piece_set, upgrade, uid)


func to_dict() -> Dictionary:
	return {"uid": uid, "type": type, "piece_set": piece_set, "upgrade": upgrade}


static func from_dict(d: Dictionary) -> PieceData:
	return PieceData.new(d["type"], d.get("piece_set", "standard"), d.get("upgrade", ""), int(d.get("uid", 0)))
