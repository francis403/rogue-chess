class_name MapGraph
extends RefCounted
## The fixed run map from config/map.json. Pure data, no nodes.
## A node is {"id", "floor", "lane", "type", "opponent", "next"}; type is
## "match", "shop", "coaching" or "boss"; opponent is "" for shop/coaching.

var _nodes: Dictionary = {}
var _start_nodes: Array[String] = []
var _floors: int = 0


func _init(map_config: Dictionary = GameConfig.data("map")) -> void:
	_floors = int(map_config["floors"])
	for id in map_config["start_nodes"]:
		_start_nodes.append(String(id))
	var raw_nodes: Dictionary = map_config["nodes"]
	for id in raw_nodes:
		var raw: Dictionary = raw_nodes[id]
		var next_ids: Array[String] = []
		for next_id in raw["next"]:
			next_ids.append(String(next_id))
		_nodes[String(id)] = {
			"id": String(id),
			"floor": int(raw["floor"]),
			"lane": int(raw["lane"]),
			"type": String(raw["type"]),
			"opponent": String(raw.get("opponent", "")),
			"next": next_ids,
		}


func floors() -> int:
	return _floors


func start_nodes() -> Array[String]:
	return _start_nodes.duplicate()


func node_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_nodes.keys())
	return ids


func has_node(id: String) -> bool:
	return _nodes.has(id)


## Returns a copy of the node info, or {} for an unknown id.
func node(id: String) -> Dictionary:
	if not _nodes.has(id):
		return {}
	return _nodes[id].duplicate(true)


## Nodes the player may pick next. "" means the run has not entered the map yet.
func available_nodes(current_node_id: String) -> Array[String]:
	if current_node_id == "":
		return start_nodes()
	if not _nodes.has(current_node_id):
		return []
	var next_ids: Array[String] = _nodes[current_node_id]["next"]
	return next_ids.duplicate()


func nodes_on_floor(floor_number: int) -> Array[String]:
	var ids: Array[String] = []
	for id in _nodes:
		if _nodes[id]["floor"] == floor_number:
			ids.append(id)
	return ids
