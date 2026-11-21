class_name MatchBoard
extends RefCounted
## Square grid holding MatchPieces and holes. Squares are Vector2i(file, rank).

var size: int
var _cells: Array[MatchPiece] = []
var _holes: Dictionary = {}


func _init(board_size: int = 6) -> void:
	size = board_size
	_cells.resize(size * size)


func in_bounds(square: Vector2i) -> bool:
	return square.x >= 0 and square.y >= 0 and square.x < size and square.y < size


func piece_at(square: Vector2i) -> MatchPiece:
	if not in_bounds(square):
		return null
	return _cells[_index(square)]


func is_empty(square: Vector2i) -> bool:
	return in_bounds(square) and not is_hole(square) and piece_at(square) == null


func place(piece: MatchPiece, square: Vector2i) -> void:
	piece.square = square
	_cells[_index(square)] = piece


func remove(square: Vector2i) -> MatchPiece:
	var piece := piece_at(square)
	if piece != null:
		_cells[_index(square)] = null
	return piece


func move(from: Vector2i, to: Vector2i) -> void:
	place(remove(from), to)


func pieces(side: int) -> Array[MatchPiece]:
	var result: Array[MatchPiece] = []
	for piece in _cells:
		if piece != null and piece.side == side:
			result.append(piece)
	return result


func is_hole(square: Vector2i) -> bool:
	return _holes.has(square)


func add_hole(square: Vector2i) -> void:
	_holes[square] = true


func holes() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for square: Vector2i in _holes:
		result.append(square)
	return result


func copy() -> MatchBoard:
	var board := MatchBoard.new(size)
	for i in _cells.size():
		if _cells[i] != null:
			board._cells[i] = _cells[i].copy()
	board._holes = _holes.duplicate()
	return board


func _index(square: Vector2i) -> int:
	return square.y * size + square.x
