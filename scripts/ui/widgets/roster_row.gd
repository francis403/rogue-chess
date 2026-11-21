class_name RosterRow
extends SelectTile
## One collection piece in the roster list. Draggable onto the board.

var piece: PieceData


func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_locked:
		return null
	var preview := PieceToken.create(56, piece)
	preview.position = -preview.size / 2.0
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	pressed.emit()
	return {"roster_piece": piece}
