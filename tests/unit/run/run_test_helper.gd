extends RefCounted
## Shared helpers for run tests. Everything is written under a temp folder in
## user:// so tests never touch the real meta.json or logs. The folder belongs to
## this process (tests/hooks/test_tmp.gd), so parallel test runs never collide.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")


static func temp_root() -> String:
	return TestTmp.dir("run")


static func temp_dir(test_name: String) -> String:
	var dir := temp_root() + test_name + "/"
	remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


static func remove_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	for sub_dir in dir.get_directories():
		remove_dir(dir_path.path_join(sub_dir))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)
	DirAccess.remove_absolute(temp_root())  # only once empty


static func new_session(dir: String, seed_value: int = 1) -> RunSession:
	return RunSession.new(seed_value, MetaStore.new(dir + "meta.json"), RunLogger.new(dir + "logs/"))


## A session on the map with the standard set chosen (artifact step skipped or answered).
static func started_session(dir: String, seed_value: int = 1) -> RunSession:
	var session := new_session(dir, seed_value)
	session.choose_piece_set("standard")
	if session.phase == RunSession.Phase.ARTIFACT_SELECT:
		session.choose_artifacts([])
	return session


static func result(winner: int, shields: Array = [], used: Array = [], moved: Array = []) -> Dictionary:
	return {"winner": winner, "reason": "king_captured", "scores": [10, 3], "shields_consumed": shields,
		"player_pieces_used": used, "player_pieces_moved": moved}


## Enters a match node, plays it with the default roster and reports the result.
static func play_node(session: RunSession, node_id: String, winner: int) -> Dictionary:
	session.choose_node(node_id)
	session.build_match_setup(session.default_roster())
	return session.finish_match(result(winner))


## Wins the match node and skips the reward, back on the map.
static func win_and_skip(session: RunSession, node_id: String) -> void:
	play_node(session, node_id, 0)
	session.skip_reward()


static func find_piece(session: RunSession, piece_type: String) -> PieceData:
	for piece in session.collection:
		if piece.type == piece_type:
			return piece
	return null


static func read_json(file_path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(file_path))
