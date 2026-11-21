extends GutTest

var map: MapGraph


func before_each() -> void:
	map = MapGraph.new()


func _all_paths(node_id: String, path: Array[String], paths: Array) -> void:
	var extended := path.duplicate()
	extended.append(node_id)
	var next_ids := map.available_nodes(node_id)
	if next_ids.is_empty():
		paths.append(extended)
		return
	for next_id in next_ids:
		_all_paths(next_id, extended, paths)


func _every_path() -> Array:
	var paths := []
	for start_id in map.start_nodes():
		_all_paths(start_id, [] as Array[String], paths)
	return paths


func test_every_next_id_exists() -> void:
	for id in map.node_ids():
		for next_id in map.node(id)["next"]:
			assert_true(map.has_node(next_id), "%s -> %s exists" % [id, next_id])


func test_start_nodes_are_on_floor_one() -> void:
	assert_eq(map.start_nodes().size(), 3)
	for id in map.start_nodes():
		assert_eq(map.node(id)["floor"], 1)


func test_every_path_has_the_required_node_counts() -> void:
	var paths := _every_path()
	assert_gt(paths.size(), 1, "there are several branches")
	for path in paths:
		var counts := {"match": 0, "shop": 0, "coaching": 0, "boss": 0}
		for id in path:
			counts[map.node(id)["type"]] += 1
		assert_eq(counts, {"match": 4, "shop": 1, "coaching": 1, "boss": 1}, "path %s" % str(path))
		assert_eq(path[-1], "BOSS")
		assert_eq(path.size(), map.floors())


func test_floors_increase_by_one_along_every_path() -> void:
	for path in _every_path():
		for i in range(1, path.size()):
			assert_eq(map.node(path[i])["floor"], map.node(path[i - 1])["floor"] + 1, "path %s" % str(path))


func test_match_nodes_have_known_opponents() -> void:
	var opponents := GameConfig.data("opponents")
	for id in map.node_ids():
		var info := map.node(id)
		if info["type"] in ["match", "boss"]:
			assert_true(opponents.has(info["opponent"]), "%s opponent" % id)
	assert_eq(map.node("BOSS")["opponent"], "boss")


func test_floor_one_and_two_are_easy_and_later_are_medium() -> void:
	for id in map.node_ids():
		var info := map.node(id)
		if info["type"] != "match":
			continue
		var expected := "easy" if info["floor"] <= 2 else "medium"
		assert_eq(info["opponent"], expected, id)


func test_available_nodes() -> void:
	assert_eq(map.available_nodes(""), map.start_nodes())
	assert_eq(map.available_nodes("L1"), ["L2", "M2"] as Array[String])
	assert_eq(map.available_nodes("BOSS"), [] as Array[String])
	assert_eq(map.available_nodes("NOPE"), [] as Array[String])


func test_node_info_is_a_copy() -> void:
	var info := map.node("L1")
	info["type"] = "shop"
	assert_eq(map.node("L1")["type"], "match")
	assert_eq(map.node("NOPE"), {})


func test_nodes_on_floor() -> void:
	assert_eq(map.nodes_on_floor(7), ["BOSS"] as Array[String])
	assert_eq(map.nodes_on_floor(6).size(), 2)
