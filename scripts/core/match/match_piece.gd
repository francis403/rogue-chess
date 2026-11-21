class_name MatchPiece
extends RefCounted
## A piece on the board during one match. Wraps a copy of the collection's
## PieceData, which is never mutated: match-only state lives here.
## Treat instances returned by ChessMatch queries as read-only.

var uid: int
var side: int
var type: String
var square: Vector2i
var data: PieceData
var shield_active: bool
var burn_turns_left: int = 0
var is_promoted: bool = false
var has_moved: bool = false


func _init(piece_uid: int, piece_side: int, piece_data: PieceData) -> void:
	uid = piece_uid
	side = piece_side
	data = piece_data
	type = data.type
	shield_active = data.upgrade == "shield"


func is_burning() -> bool:
	return burn_turns_left > 0


## Burn duration of this piece's set, 0 if it never burns (standard set, Fire king).
func burn_turns() -> int:
	if not data.is_set_piece():
		return 0
	return int(_set_config().get("burn_turns", 0))


## Extra points this piece earns for every capture it makes (Fire: +2).
func capture_bonus() -> int:
	if not data.is_set_piece():
		return 0
	return int(_set_config().get("capture_bonus", 0))


## Capture points for the current type (a promoted pawn is worth a queen).
func value() -> int:
	var points := GameConfig.piece_value(type)
	if data.is_set_piece():
		points += int(_set_config()["value_modifier"])
	return maxi(points, 0)


func copy() -> MatchPiece:
	var piece := MatchPiece.new(uid, side, data)
	piece.type = type
	piece.square = square
	piece.shield_active = shield_active
	piece.burn_turns_left = burn_turns_left
	piece.is_promoted = is_promoted
	piece.has_moved = has_moved
	return piece


func _set_config() -> Dictionary:
	return GameConfig.data("piece_sets")["sets"][data.piece_set]
