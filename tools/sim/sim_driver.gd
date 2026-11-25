extends RefCounted
## Headless bot that plays whole runs: random-but-valid run choices, MatchAI on
## both sides of every match. Checks every action for errors, illegal states and
## softlocks, and the run logs at the end. Shared by tools/sim/run_sim.gd and
## tests/integration/test_sim_smoke.gd. Everything is written under `root_dir`.

const MAX_RUN_STEPS := 300
const MAX_MATCH_ACTIONS := 5000
const FIRE_CHANCE := 0.5
const ARTIFACT_CHANCE := 0.75
const RANDOM_ROSTER_CHANCE := 0.4
const ROSTER_PICK_CHANCE := 0.75
const REWARD_SKIP_CHANCE := 0.25
const SHOP_BUY_CHANCE := 0.6
const SHOP_REMOVE_CHANCE := 0.4
const COACHING_ACCEPT_CHANCE := 0.7
const COACHING_DECLINE_CHANCE := 0.5
const PLAYER_SKIP_CHANCE := 0.02
const RANDOM_ESCAPE_CHANCE := 0.15
## Player bot strength cycles per run, so some runs beat the boss and some lose early.
const PLAYER_PROFILES: Array[Dictionary] = [
	{"depth": 2, "random_chance": 0.0},
	{"depth": 2, "random_chance": 0.1},
	{"depth": 1, "random_chance": 0.2},
]
const RUN_LOG_KEYS: Array[String] = ["seed", "started_at", "finished_at", "piece_set", "artifacts", "matches", "events", "summary"]
const MATCH_LOG_KEYS: Array[String] = ["node", "floor", "opponent", "result", "reason", "scores", "deck", "roster", "pieces_used", "shields_consumed", "points_after"]
const FAILURE_KINDS: Array[String] = ["crashes", "action_errors", "illegal_states", "softlocks", "log_errors"]

var root_dir: String
var meta: MetaStore
var failures: Array[String] = []
var stats := {
	"runs": 0, "runs_won": 0, "boss_reached": 0, "fire_runs": 0, "artifact_runs": 0,
	"matches": 0, "match_rounds": 0, "match_actions": 0, "matches_by_opponent": {}, "match_reasons": {},
	"checks": 0, "checks_without_escape": 0, "escapes": 0, "escapes_declined": 0,
	"run_msec": 0, "decisions_by_depth": {}, "decision_usec_by_depth": {}, "max_decision_usec_by_depth": {},
	"crashes": 0, "action_errors": 0, "illegal_states": 0, "softlocks": 0, "log_errors": 0,
}

var _rng := RandomNumberGenerator.new()
var _run_label: String = ""


## Counts engine and script errors (not warnings) while a run is played.
class ErrorCounter extends Logger:
	var count: int = 0
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		_mutex.unlock()


## Wipes `directory` (must be under user://sim/) so meta starts fresh for this sim.
func _init(directory: String, seed_value: int) -> void:
	root_dir = directory if directory.ends_with("/") else directory + "/"
	if not root_dir.begins_with("user://sim/"):
		push_error("SimDriver writes only under user://sim/, got %s" % root_dir)
		root_dir = "user://sim/default/"
	remove_dir(root_dir)
	DirAccess.make_dir_recursive_absolute(root_dir)
	meta = MetaStore.new(root_dir + "meta.json")
	_rng.seed = seed_value


func run_many(count: int) -> void:
	for run_index in count:
		run_once(run_index)


func failure_count() -> int:
	var total := 0
	for kind in FAILURE_KINDS:
		total += int(stats[kind])
	return total


func run_once(run_index: int) -> void:
	var started := Time.get_ticks_msec()
	stats["runs"] += 1
	var session := RunSession.new(_rng.randi(), meta, RunLogger.new(root_dir + "logs/"))
	_run_label = "run %d (seed %d)" % [run_index, session.run_seed]
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var failures_before := failures.size()
	var finished_cleanly: Variant = _play_run(session, PLAYER_PROFILES[run_index % PLAYER_PROFILES.size()])
	OS.remove_logger(errors)
	if errors.count > 0:
		_fail("crashes", "%d engine/script errors logged" % errors.count)
	elif finished_cleanly != true or (not session.is_over() and failures.size() == failures_before):
		_fail("crashes", "run aborted in %s" % session.phase_name())
	stats["run_msec"] += Time.get_ticks_msec() - started


## Returns true when it got to the end without a script error aborting it.
func _play_run(session: RunSession, profile: Dictionary) -> bool:
	var matches_played := 0
	var steps := 0
	while not session.is_over():
		if steps >= MAX_RUN_STEPS:
			_fail("softlocks", "run stuck in %s after %d steps" % [session.phase_name(), steps])
			return true
		steps += 1
		var was_match := session.phase == RunSession.Phase.MATCH_SETUP
		if not _step(session, profile):
			return true
		if was_match:
			matches_played += 1
		var run_error := _run_state_error(session)
		if run_error != "":
			_fail("illegal_states", run_error)
			return true
	_record_run_end(session)
	_check_logs(session, matches_played)
	return true


## One run-level decision. False when a failure was recorded and the run must stop.
func _step(session: RunSession, profile: Dictionary) -> bool:
	match session.phase:
		RunSession.Phase.SET_SELECT:
			return _ok(session.choose_piece_set(_pick_piece_set(session)), "choose_piece_set")
		RunSession.Phase.ARTIFACT_SELECT:
			return _ok(session.choose_artifacts(_pick_artifacts(session)), "choose_artifacts")
		RunSession.Phase.MAP:
			var nodes := session.available_nodes()
			if nodes.is_empty():
				_fail("softlocks", "no reachable node on the map")
				return false
			return _ok(session.choose_node(nodes[_rng.randi_range(0, nodes.size() - 1)]), "choose_node")
		RunSession.Phase.MATCH_SETUP:
			return _play_match_node(session, profile)
		RunSession.Phase.REWARD:
			return _take_reward(session)
		RunSession.Phase.SHOP:
			return _shop(session)
		RunSession.Phase.COACHING:
			return _coaching(session)
	_fail("illegal_states", "unexpected phase %s" % session.phase_name())
	return false


func _pick_piece_set(session: RunSession) -> String:
	var unlocked: Array[String] = []
	for entry in session.available_piece_sets():
		if not entry["locked"]:
			unlocked.append(entry["id"])
	var fire_id: String = GameConfig.value("piece_sets", "boss_unlock")
	if unlocked.has(fire_id) and _rng.randf() < FIRE_CHANCE:
		stats["fire_runs"] += 1
		return fire_id
	unlocked.erase(fire_id)
	return unlocked[_rng.randi_range(0, unlocked.size() - 1)]


func _pick_artifacts(session: RunSession) -> Array:
	# The bot can't use hidden-card info, so Crystal Ball would be pure downside (D30).
	var ids: Array = session.available_artifacts().map(func(entry: Dictionary) -> String: return entry["id"])
	ids.erase("foresight")
	if _rng.randf() >= ARTIFACT_CHANCE:
		return []
	_shuffle(ids)
	stats["artifact_runs"] += 1
	return ids.slice(0, _rng.randi_range(1, mini(session.max_starting_artifacts(), ids.size())))


func _play_match_node(session: RunSession, profile: Dictionary) -> bool:
	var roster := session.default_roster() if _rng.randf() >= RANDOM_ROSTER_CHANCE else _random_roster(session)
	var validation := session.validate_roster(roster)
	if not _ok(validation, "validate_roster"):
		return false
	var setup := session.build_match_setup(roster)
	if setup.has("ok"):
		return _ok(setup, "build_match_setup")
	var opponent_id: String = setup["opponent"]["id"]
	if opponent_id == "boss":
		stats["boss_reached"] += 1
	var result := _play_match(setup, profile)
	if result.is_empty():
		return false
	_count_match(opponent_id, result)
	return _ok(session.finish_match(result), "finish_match")


## King on a random back-row square plus a random affordable subset of the collection.
func _random_roster(session: RunSession) -> Array[Dictionary]:
	var squares: Array = []
	for y in int(GameConfig.value("match", "deploy_rows")):
		for x in int(GameConfig.value("match", "board_size")):
			squares.append(Vector2i(x, y))
	_shuffle(squares)
	var others: Array = []
	var roster: Array[Dictionary] = []
	for piece in session.collection:
		if piece.type == "king":
			roster.append({"piece": piece, "square": squares.pop_back()})
		else:
			others.append(piece)
	_shuffle(others)
	var budget := session.deploy_budget()
	for piece: PieceData in others:
		if squares.is_empty() or piece.deploy_cost() > budget or _rng.randf() >= ROSTER_PICK_CHANCE:
			continue
		budget -= piece.deploy_cost()
		roster.append({"piece": piece, "square": squares.pop_back()})
	return roster


## Plays a match to the end. Returns its result, or {} after recording a failure.
func _play_match(setup: Dictionary, profile: Dictionary) -> Dictionary:
	var game := ChessMatch.new(setup)
	var ais: Array[MatchAI] = [
		MatchAI.new(ChessMatch.PLAYER, int(profile["depth"]), float(profile["random_chance"]), _rng, setup["player"]["deck"]),
		MatchAI.new(ChessMatch.OPPONENT, int(setup["opponent"]["search_depth"]), float(setup["opponent"]["random_chance"]), _rng, setup["opponent"]["deck"]),
	]
	var deck_sizes: Array[int] = [setup["player"]["deck"].size(), setup["opponent"]["deck"].size()]
	var credited: Array[int] = [0, 0]
	var actions := 0
	var broken := state_error(game, deck_sizes, credited)
	while broken == "" and not game.is_over() and actions < MAX_MATCH_ACTIONS:
		var escaping := game.pending_escape_side() != -1
		var side := game.pending_escape_side() if escaping else game.current_side()
		var action := _timed_choice(ais[side], game)
		var contract_error := action_error(game, action)
		if contract_error != "":
			_fail("illegal_states", "AI side %d: %s" % [side, contract_error])
			return {}
		if escaping and _rng.randf() < RANDOM_ESCAPE_CHANCE:
			action = _random_escape_answer(game)
		elif side == ChessMatch.PLAYER and action["kind"] == "play" and _rng.randf() < PLAYER_SKIP_CHANCE:
			action = {"kind": "end_turn"}
		var events := MatchAI.apply_action(game, action)
		if events.is_empty() or events[0]["type"] == "error":
			_fail("action_errors", "%s rejected: %s" % [action, events])
			return {}
		actions += 1
		broken = _scan_events(game, events, credited)
		if broken == "":
			broken = state_error(game, deck_sizes, credited)
	if broken != "":
		_fail("illegal_states", broken)
		return {}
	if not game.is_over():
		_fail("softlocks", "match not over after %d actions" % actions)
		return {}
	var result := game.result()
	if not int(result.get("winner", -1)) in [ChessMatch.PLAYER, ChessMatch.OPPONENT] or int(result["rounds"]) > game.max_rounds():
		_fail("illegal_states", "bad match result %s" % result)
		return {}
	stats["match_actions"] += actions
	return result


func _random_escape_answer(game: ChessMatch) -> Dictionary:
	var squares := game.escape_squares()
	var pick := _rng.randi_range(0, squares.size())
	return {"kind": "decline_escape"} if pick == squares.size() else {"kind": "escape", "to": squares[pick]}


## Credits "score" events, counts checks/escapes and checks the turn-start energy
## (D59: energy = max(max_energy - escape_penalty, 0)). Returns a broken invariant or "".
func _scan_events(game: ChessMatch, events: Array[Dictionary], credited: Array[int]) -> String:
	for event in events:
		match event["type"]:
			"score":
				credited[int(event["side"])] += int(event["points"])
			"check":
				stats["checks"] += 1
				if not event["can_escape"]:
					stats["checks_without_escape"] += 1
			"escape":
				stats["escapes"] += 1
			"escape_declined":
				stats["escapes_declined"] += 1
			"energy":
				var penalty := int(event["escape_penalty"])
				var expected := maxi(game.max_energy(int(event["side"])) - penalty, 0)
				if penalty < 0 or int(event["energy"]) != expected:
					return "turn-start energy %d with escape penalty %d, expected %d" % [event["energy"], penalty, expected]
	return ""


func _timed_choice(ai: MatchAI, game: ChessMatch) -> Dictionary:
	var started := Time.get_ticks_usec()
	var action := ai.choose_action(game)
	var elapsed := Time.get_ticks_usec() - started
	var depth := str(ai.search_depth)
	stats["decisions_by_depth"][depth] = int(stats["decisions_by_depth"].get(depth, 0)) + 1
	stats["decision_usec_by_depth"][depth] = int(stats["decision_usec_by_depth"].get(depth, 0)) + elapsed
	stats["max_decision_usec_by_depth"][depth] = maxi(int(stats["max_decision_usec_by_depth"].get(depth, 0)), elapsed)
	return action


func _take_reward(session: RunSession) -> bool:
	if _rng.randf() < REWARD_SKIP_CHANCE:
		return _ok(session.skip_reward(), "skip_reward")
	return _ok(session.take_reward(_rng.randi_range(0, session.reward_offers().size() - 1)), "take_reward")


func _shop(session: RunSession) -> bool:
	var offers := session.shop_offers()
	for kind in ["cards", "pieces"]:
		for index in offers[kind].size():
			var offer: Dictionary = offers[kind][index]
			if offer["sold"] or offer["price"] > session.points or _rng.randf() >= SHOP_BUY_CHANCE:
				continue
			# Nor does it play Scouts (D30).
			if kind == "cards" and (offer["card"] as CardData).is_reveal():
				continue
			var result := session.buy_card(index) if kind == "cards" else session.buy_piece(index)
			if not _ok(result, "buy %s" % kind):
				return false
	var can_remove: bool = offers["removes_left"] > 0 and session.points >= offers["remove_price"] \
		and session.deck.size() > int(GameConfig.value("economy", "min_deck_size"))
	if can_remove and _rng.randf() < SHOP_REMOVE_CHANCE:
		var removable := _removable_cards(session.deck)
		var card: CardData = removable[_rng.randi_range(0, removable.size() - 1)]
		if not _ok(session.remove_card(card.uid), "remove_card"):
			return false
	return _ok(session.leave_shop(), "leave_shop")


## D53: the last Move card can't be removed.
func _removable_cards(deck: Array[CardData]) -> Array[CardData]:
	var move_cards := deck.filter(func(card: CardData) -> bool: return card.type == "move")
	if move_cards.size() != 1:
		return deck
	var removable: Array[CardData] = []
	removable.assign(deck.filter(func(card: CardData) -> bool: return card.type != "move"))
	return removable


func _coaching(session: RunSession) -> bool:
	var offers := session.coaching_offers()
	for index in offers.size():
		var offer := offers[index]
		if offer["price"] <= session.points and _rng.randf() < COACHING_ACCEPT_CHANCE:
			if not _ok(session.accept_coaching(index), "accept_coaching"):
				return false
		elif _rng.randf() < COACHING_DECLINE_CHANCE:
			if not _ok(session.decline_coaching(index), "decline_coaching"):
				return false
	return _ok(session.leave_coaching(), "leave_coaching")


func _record_run_end(session: RunSession) -> void:
	var summary := session.summary()
	if summary["boss_defeated"]:
		stats["runs_won"] += 1


func _count_match(opponent_id: String, result: Dictionary) -> void:
	stats["matches"] += 1
	stats["match_rounds"] += int(result["rounds"])
	stats["match_reasons"][result["reason"]] = int(stats["match_reasons"].get(result["reason"], 0)) + 1
	var counts: Dictionary = stats["matches_by_opponent"].get(opponent_id, {"played": 0, "player_won": 0, "rounds": 0, "endings": {}})
	counts["played"] += 1
	counts["rounds"] += int(result["rounds"])
	var player_won := int(result["winner"]) == ChessMatch.PLAYER
	if player_won:
		counts["player_won"] += 1
	var ending := "%s_%s" % ["won" if player_won else "lost", result["reason"]]
	counts["endings"][ending] = int(counts["endings"].get(ending, 0)) + 1
	stats["matches_by_opponent"][opponent_id] = counts


func _run_state_error(session: RunSession) -> String:
	if session.points < 0:
		return "negative points"
	if session.piece_set != "" and session.deck.size() < int(GameConfig.value("economy", "min_deck_size")):
		return "deck below the minimum size"
	if session.piece_set != "" and not session.collection.any(func(piece: PieceData) -> bool: return piece.type == "king"):
		return "collection lost its king"
	return ""


func _check_logs(session: RunSession, matches_played: int) -> void:
	var run_log: Variant = _read_json(session.logger.run_file_path)
	if not run_log is Dictionary:
		_fail("log_errors", "run log missing or unparseable: %s" % session.logger.run_file_path)
		return
	for key in RUN_LOG_KEYS:
		if not run_log.has(key):
			_fail("log_errors", "run log lacks %s" % key)
			return
	if run_log["matches"].size() != matches_played:
		_fail("log_errors", "run log has %d matches, played %d" % [run_log["matches"].size(), matches_played])
		return
	for entry: Dictionary in run_log["matches"]:
		for key in MATCH_LOG_KEYS:
			if not entry.has(key):
				_fail("log_errors", "match log lacks %s" % key)
				return
	if not run_log["summary"].get("result", "") in ["won", "lost"]:
		_fail("log_errors", "run log summary has no result")
	if not _read_json(session.logger.stats_path()) is Dictionary:
		_fail("log_errors", "stats.json missing or unparseable")


func _ok(result: Dictionary, what: String) -> bool:
	if result.get("ok", false):
		return true
	_fail("action_errors", "%s refused: %s" % [what, result.get("error", "")])
	return false


func _fail(kind: String, message: String) -> void:
	stats[kind] += 1
	failures.append("[%s] %s: %s" % [kind, _run_label, message])


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap


func summary_lines() -> Array[String]:
	var runs := maxi(int(stats["runs"]), 1)
	var matches := maxi(int(stats["matches"]), 1)
	var lines: Array[String] = [
		"runs: %d" % stats["runs"],
		"failures: %d (crashes %d, action errors %d, illegal states %d, softlocks %d, log errors %d)" % [
			failure_count(), stats["crashes"], stats["action_errors"], stats["illegal_states"], stats["softlocks"], stats["log_errors"]],
		"run win rate (boss beaten): %d/%d = %.1f%%" % [stats["runs_won"], stats["runs"], 100.0 * stats["runs_won"] / runs],
		"boss reached: %d, boss beaten: %d" % [stats["boss_reached"], stats["runs_won"]],
		"fire runs: %d, runs with artifacts: %d, unlocked at the end: sets %s, artifacts %s" % [
			stats["fire_runs"], stats["artifact_runs"], meta.unlocked_piece_sets, meta.unlocked_artifacts],
		"matches: %d, avg rounds %.1f, avg actions %.1f" % [stats["matches"], float(stats["match_rounds"]) / matches, float(stats["match_actions"]) / matches],
	]
	lines.append("match end reasons: %s" % stats["match_reasons"])
	lines.append("checks: %d (no escape possible %d), escapes %d, declined %d" % [
		stats["checks"], stats["checks_without_escape"], stats["escapes"], stats["escapes_declined"]])
	for opponent_id in stats["matches_by_opponent"]:
		var counts: Dictionary = stats["matches_by_opponent"][opponent_id]
		lines.append("  vs %s: %d played, player won %d (%.0f%%), avg rounds %.1f, player endings %s" % [
			opponent_id, counts["played"], counts["player_won"], 100.0 * counts["player_won"] / counts["played"],
			float(counts["rounds"]) / counts["played"], counts["endings"]])
	for depth in stats["decisions_by_depth"]:
		var decisions: int = stats["decisions_by_depth"][depth]
		lines.append("AI depth %s: %d decisions, avg %.2f ms, max %.2f ms" % [
			depth, decisions, stats["decision_usec_by_depth"][depth] / 1000.0 / decisions, stats["max_decision_usec_by_depth"][depth] / 1000.0])
	lines.append("avg time per run: %.0f ms" % (float(stats["run_msec"]) / runs))
	return lines


## Empty if the AI's action is legal right now (D9 contract), else the reason.
## While an escape is pending only escape (to a safe square) or decline_escape is legal.
static func action_error(game: ChessMatch, action: Dictionary) -> String:
	var kind: String = action.get("kind", "")
	if game.pending_escape_side() != -1:
		if kind == "escape":
			return "" if game.escape_squares().has(action["to"]) else "escape to a square that is not offered: %s" % action
		return "" if kind == "decline_escape" else "%s while an escape is pending" % kind
	var plays := game.legal_plays(game.current_side())
	match kind:
		"play":
			var play := {"card_index": action["card_index"], "from": action["from"], "to": action["to"]}
			return "" if plays.has(play) else "play not in legal_plays: %s" % action
		"redraw":
			return "" if game.can_redraw() else "redraw while not allowed"
		"end_turn":
			return "end_turn with a playable card" if not plays.is_empty() else ""
	return "unknown action %s" % action


## Empty if the match state is sane, else the broken invariant (as in test_match_integrity,
## plus one king per side, promotion and scores matching the score events).
static func state_error(game: ChessMatch, deck_sizes: Array[int], credited: Array[int]) -> String:
	var occupied := {}
	var hand_size := int(GameConfig.value("match", "hand_size"))
	for side in [ChessMatch.PLAYER, ChessMatch.OPPONENT]:
		var far_rank := game.board_size() - 1 if side == ChessMatch.PLAYER else 0
		var kings := 0
		for piece in game.pieces(side):
			if piece.type == "king":
				kings += 1
			if piece.type == "pawn" and piece.square.y == far_rank:
				return "unpromoted pawn on the far rank at %s" % piece.square
			if occupied.has(piece.square):
				return "two pieces on %s" % piece.square
			occupied[piece.square] = true
			if game.is_hole(piece.square):
				return "piece on a hole at %s" % piece.square
			if game.piece_at(piece.square) != piece:
				return "piece square out of sync at %s" % piece.square
		if kings > 1 or (kings == 0 and not game.is_over()):
			return "side %d has %d kings" % [side, kings]
		if game.escape_penalty(side) < 0:
			return "side %d has a negative escape penalty" % side
		if game.score(side) != credited[side]:
			return "side %d score %d but score events credit %d" % [side, game.score(side), credited[side]]
		if game.score(side) < 0 or game.energy(side) < 0 or game.energy(side) > game.max_energy(side):
			return "bad score/energy for side %d" % side
		if game.deck_size(side) != deck_sizes[side]:
			return "side %d has %d cards, expected %d" % [side, game.deck_size(side), deck_sizes[side]]
		if game.hand(side).size() > hand_size:
			return "side %d hand too big" % side
	if game.current_round() > game.max_rounds():
		return "past the turn limit"
	return escape_error(game)


## Independent check of a pending escape (D57, D62): the match is running, there is
## at least one square, and each square really is safe on a clone — unless that escape
## wins, or its capture set off the escaping side's Powder Keg (D62 ignores blasts,
## which can open a line by removing a blocker).
static func escape_error(game: ChessMatch) -> String:
	var defender := game.pending_escape_side()
	if defender == -1:
		return ""
	if game.is_over():
		return "escape pending after the match ended"
	var squares := game.escape_squares()
	if squares.is_empty():
		return "escape pending with no escape square"
	for to in squares:
		var after := game.clone()
		var events := after.escape(to)
		if events[0]["type"] == "error":
			return "offered escape square %s rejected: %s" % [to, events[0]["reason"]]
		if after.is_over() and int(after.result()["winner"]) == defender:
			continue
		if events.any(func(event: Dictionary) -> bool: return event["type"] == "explosion"):
			continue
		var king: MatchPiece = null
		for piece in after.pieces(defender):
			if piece.type == "king":
				king = piece
		if king == null:
			return "escape to %s lost the king" % to
		for attacker in after.pieces(1 - defender):
			if after.piece_moves(attacker.square).has(king.square):
				return "escape square %s is attacked by the piece on %s (escape events %s)" % [
					to, attacker.square, events.map(func(event: Dictionary) -> String: return event["type"])]
	return ""


static func remove_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	for sub_dir in dir.get_directories():
		remove_dir(dir_path.path_join(sub_dir))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)


static func _read_json(file_path: String) -> Variant:
	if file_path == "" or not FileAccess.file_exists(file_path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(file_path))
