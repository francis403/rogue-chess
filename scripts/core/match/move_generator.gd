class_name MoveGenerator
extends RefCounted
## Raw piece movement on a MatchBoard (cards are ignored). Holes can't be
## landed on and block every piece except knights, which jump.

const STRAIGHT: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const KNIGHT_SHORT_SIDE := 1
const KNIGHT_LONG_SIDE := 2


static func moves(board: MatchBoard, piece: MatchPiece) -> Array[Vector2i]:
	match piece.type:
		"pawn":
			return _pawn_moves(board, piece)
		"knight":
			return _knight_moves(board, piece)
		"bishop":
			return _slide(board, piece, DIAGONAL, board.size)
		"rook":
			return _slide(board, piece, STRAIGHT, board.size)
		"queen":
			return _slide(board, piece, ALL_DIRECTIONS, board.size)
		"king":
			return _slide(board, piece, ALL_DIRECTIONS, 1 + _range_bonus(piece))
	return []


static func forward(side: int) -> int:
	return 1 if side == ChessMatch.PLAYER else -1


static func _range_bonus(piece: MatchPiece) -> int:
	if piece.data.upgrade != "range":
		return 0
	return int(GameConfig.data("upgrades")["piece"]["range"]["amount"])


static func _is_enemy(board: MatchBoard, piece: MatchPiece, square: Vector2i) -> bool:
	var other := board.piece_at(square)
	return other != null and other.side != piece.side


static func _slide(board: MatchBoard, piece: MatchPiece, directions: Array[Vector2i], max_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in directions:
		var square := piece.square + direction
		for _step in max_steps:
			if not board.in_bounds(square) or board.is_hole(square):
				break
			if board.piece_at(square) != null:
				if _is_enemy(board, piece, square):
					result.append(square)
				break
			result.append(square)
			square += direction
	return result


static func _knight_moves(board: MatchBoard, piece: MatchPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for long_side in range(KNIGHT_LONG_SIDE, KNIGHT_LONG_SIDE + _range_bonus(piece) + 1):
		for sign_x in [-1, 1]:
			for sign_y in [-1, 1]:
				for offset in [Vector2i(long_side * sign_x, KNIGHT_SHORT_SIDE * sign_y), Vector2i(KNIGHT_SHORT_SIDE * sign_x, long_side * sign_y)]:
					var square: Vector2i = piece.square + offset
					if board.is_empty(square) or _is_enemy(board, piece, square):
						result.append(square)
	return result


static func _pawn_moves(board: MatchBoard, piece: MatchPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var step := Vector2i(0, forward(piece.side))
	var square := piece.square + step
	for _step in 1 + _range_bonus(piece):
		if not board.is_empty(square):
			break
		result.append(square)
		square += step
	for side_step: int in [-1, 1]:
		var capture_square := piece.square + step + Vector2i(side_step, 0)
		if _is_enemy(board, piece, capture_square):
			result.append(capture_square)
	return result
