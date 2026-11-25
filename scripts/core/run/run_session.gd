class_name RunSession
extends RefCounted
## One run of the roguelike: the state machine shared by the UI and the sim bot.
## It never plays a chess match: build_match_setup() hands a setup to ChessMatch
## and finish_match() consumes the result. Every action returns {"ok": bool, "error": String}.
## Public vars are for reading only; change state through the actions.

enum Phase { SET_SELECT, ARTIFACT_SELECT, MAP, MATCH_SETUP, MATCH, REWARD, SHOP, COACHING, RUN_END }

const PLAYER := 0

var run_seed: int
var phase: Phase = Phase.SET_SELECT
var piece_set: String = ""
var artifacts: Array[String] = []
var collection: Array[PieceData] = []
var deck: Array[CardData] = []
var points: int = 0
var current_node: String = ""
var visited: Array[String] = []
var wins: int = 0
var map: MapGraph
var meta: MetaStore
var logger: RunLogger

var _rng := RandomNumberGenerator.new()
var _roster_log: Array[Dictionary] = []
var _reward_offers: Array[CardData] = []
var _shop: Dictionary = {}
var _coaching: Array[Dictionary] = []
var _result: String = ""
var _unlock: Dictionary = {}


func _init(seed_value: int, meta_store: MetaStore = null, run_logger: RunLogger = null) -> void:
	run_seed = seed_value
	_rng.seed = seed_value
	meta = meta_store if meta_store != null else MetaStore.new()
	logger = run_logger if run_logger != null else RunLogger.new()
	map = MapGraph.new()


func phase_name() -> String:
	return Phase.keys()[phase]


func is_over() -> bool:
	return phase == Phase.RUN_END


func available_piece_sets() -> Array[Dictionary]:
	var sets: Array[Dictionary] = []
	var sets_cfg: Dictionary = GameConfig.data("piece_sets")["sets"]
	for set_id in sets_cfg:
		sets.append({
			"id": set_id,
			"name": sets_cfg[set_id]["name"],
			"desc": sets_cfg[set_id]["desc"],
			"locked": not meta.is_piece_set_unlocked(set_id),
		})
	return sets


func choose_piece_set(set_id: String) -> Dictionary:
	var error := _phase_error(Phase.SET_SELECT)
	if not error.is_empty():
		return error
	if not GameConfig.data("piece_sets")["sets"].has(set_id):
		return _fail("Unknown piece set: %s" % set_id)
	if not meta.is_piece_set_unlocked(set_id):
		return _fail("Piece set %s is locked" % set_id)
	piece_set = set_id
	points = int(GameConfig.value("economy", "starting_points"))
	_build_starting_collection()
	_build_starting_deck()
	logger.start_run(run_seed, piece_set, artifacts)
	phase = Phase.MAP if available_artifacts().is_empty() else Phase.ARTIFACT_SELECT
	return _ok()


func available_artifacts() -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	var artifacts_cfg: Dictionary = GameConfig.data("artifacts")["artifacts"]
	for artifact_id in GameConfig.data("artifacts")["unlock_pool"]:
		if meta.is_artifact_unlocked(artifact_id):
			unlocked.append({
				"id": artifact_id,
				"name": artifacts_cfg[artifact_id]["name"],
				"desc": artifacts_cfg[artifact_id]["desc"],
			})
	return unlocked


func max_starting_artifacts() -> int:
	return int(GameConfig.value("artifacts", "max_starting_artifacts"))


func choose_artifacts(artifact_ids: Array) -> Dictionary:
	var error := _phase_error(Phase.ARTIFACT_SELECT)
	if not error.is_empty():
		return error
	if artifact_ids.size() > max_starting_artifacts():
		return _fail("Pick at most %d artifacts" % max_starting_artifacts())
	var chosen: Array[String] = []
	for artifact_id in artifact_ids:
		if not artifact_id is String or not meta.is_artifact_unlocked(artifact_id):
			return _fail("Artifact not unlocked: %s" % str(artifact_id))
		if chosen.has(artifact_id):
			return _fail("Artifact picked twice: %s" % artifact_id)
		chosen.append(artifact_id)
	artifacts = chosen
	logger.set_artifacts(artifacts)
	phase = Phase.MAP
	return _ok()


func available_nodes() -> Array[String]:
	if phase != Phase.MAP:
		return []
	return map.available_nodes(current_node)


func current_node_info() -> Dictionary:
	return map.node(current_node)


func choose_node(node_id: String) -> Dictionary:
	var error := _phase_error(Phase.MAP)
	if not error.is_empty():
		return error
	if not available_nodes().has(node_id):
		return _fail("Node %s is not reachable" % node_id)
	current_node = node_id
	visited.append(node_id)
	match map.node(node_id)["type"]:
		"shop":
			_generate_shop()
			phase = Phase.SHOP
		"coaching":
			_generate_coaching()
			phase = Phase.COACHING
		_:
			phase = Phase.MATCH_SETUP
	return _ok()


func deploy_budget() -> int:
	return int(GameConfig.value("match", "deploy_budget"))


## King plus as many pawns as configured, then the most valuable pieces that fit.
func default_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	var king := _find_king()
	if king == null:
		return roster
	var budget := deploy_budget()
	var max_pieces := _deploy_squares().size() - 1
	var picked: Array[PieceData] = []
	var pawn_target := int(GameConfig.data("economy")["default_roster"]["pawns"])
	for piece in collection:
		if piece.type == "pawn" and picked.size() < pawn_target and piece.deploy_cost() <= budget:
			picked.append(piece)
			budget -= piece.deploy_cost()
	# Extra pawns are left out: the pawn quota alone decides the pawn wall (D50).
	var others := collection.filter(func(p: PieceData) -> bool: return p.type != "king" and p.type != "pawn")
	others.sort_custom(_is_better_pick)
	for piece: PieceData in others:
		if picked.size() < max_pieces and piece.deploy_cost() <= budget:
			picked.append(piece)
			budget -= piece.deploy_cost()
	return _place(king, picked)


func validate_roster(roster: Array) -> Dictionary:
	var used_uids: Array[int] = []
	var used_squares: Array[Vector2i] = []
	var cost := 0
	var has_king := false
	for entry in roster:
		if not entry is Dictionary or not entry.get("piece") is PieceData or not entry.get("square") is Vector2i:
			return _fail("Each roster entry needs a piece and a square")
		var owned := _collection_piece(entry["piece"].uid)
		if owned == null:
			return _fail("Piece is not in your collection")
		if used_uids.has(owned.uid):
			return _fail("Piece picked twice")
		var square: Vector2i = entry["square"]
		if not _deploy_squares().has(square):
			return _fail("Square %s is outside your back rows" % str(square))
		if used_squares.has(square):
			return _fail("Two pieces on square %s" % str(square))
		used_uids.append(owned.uid)
		used_squares.append(square)
		cost += owned.deploy_cost()
		has_king = has_king or owned.type == "king"
	if not has_king:
		return _fail("The king must be included")
	if cost > deploy_budget():
		return _fail("Roster costs %d, budget is %d" % [cost, deploy_budget()])
	return {"ok": true, "error": "", "cost": cost}


## Returns the setup for ChessMatch.new(), or {"ok": false, "error": ...} on failure.
func build_match_setup(roster: Array) -> Dictionary:
	var error := _phase_error(Phase.MATCH_SETUP)
	if not error.is_empty():
		return error
	var validation := validate_roster(roster)
	if not validation["ok"]:
		return validation
	var player_roster: Array[Dictionary] = []
	_roster_log.clear()
	for entry in roster:
		var piece := _collection_piece(entry["piece"].uid)
		player_roster.append({"piece": piece.copy(), "square": entry["square"]})
		var logged := piece.to_dict()
		logged["square"] = [entry["square"].x, entry["square"].y]
		_roster_log.append(logged)
	var player_deck: Array[CardData] = []
	for card in deck:
		player_deck.append(card.copy())
	phase = Phase.MATCH
	return {
		"seed": _rng.randi(),
		"player": {"roster": player_roster, "deck": player_deck, "artifacts": artifacts.duplicate()},
		"opponent": _opponent_setup(map.node(current_node)["opponent"]),
	}


## result: {"winner": 0|1 (0 = player), "reason", "scores": [p, o], "shields_consumed": [uids],
##          "player_pieces_used": [uids], "player_pieces_moved": [uids]}
func finish_match(result: Dictionary) -> Dictionary:
	var error := _phase_error(Phase.MATCH)
	if not error.is_empty():
		return error
	error = _result_error(result)
	if not error.is_empty():
		return error
	var player_won := int(result["winner"]) == PLAYER
	_remove_used_shields(result.get("shields_consumed", []))
	if player_won:
		points += int(GameConfig.value("economy", "win_points"))
		wins += 1
	_log_match(result, player_won)
	if not player_won:
		_unlock = _artifact_unlock(meta.unlock_random_artifact(_rng))
		_end_run("lost")
		return _ok()
	if map.node(current_node)["type"] == "boss":
		var set_id: String = GameConfig.value("piece_sets", "boss_unlock")
		_unlock = _piece_set_unlock(set_id, meta.unlock_piece_set(set_id))
		_end_run("won")
		return _ok()
	_reward_offers.clear()
	for card_type in _pick_distinct(GameConfig.value("economy", "reward_card_pool"), int(GameConfig.value("economy", "reward_choices"))):
		_reward_offers.append(CardData.new(card_type))
	phase = Phase.REWARD
	return _ok()


func reward_offers() -> Array[CardData]:
	if phase != Phase.REWARD:
		return []
	return _reward_offers.duplicate()


func take_reward(index: int) -> Dictionary:
	var error := _phase_error(Phase.REWARD)
	if not error.is_empty():
		return error
	if index < 0 or index >= _reward_offers.size():
		return _fail("No reward at index %d" % index)
	var card := _reward_offers[index]
	deck.append(card)
	logger.log_event("reward", {"node": current_node, "card": card.to_dict()})
	phase = Phase.MAP
	return _ok()


func skip_reward() -> Dictionary:
	var error := _phase_error(Phase.REWARD)
	if not error.is_empty():
		return error
	var bonus := int(GameConfig.value("economy", "reward_skip_points"))
	points += bonus
	logger.log_event("reward_skip", {"node": current_node, "points": bonus})
	phase = Phase.MAP
	return _ok()


## {"cards": [{"card", "price", "sold"}], "pieces": [{"piece", "price", "sold"}],
##  "remove_price": int, "removes_left": int}. Generated once per visit.
func shop_offers() -> Dictionary:
	return _shop.duplicate(true) if phase == Phase.SHOP else {}


func buy_card(index: int) -> Dictionary:
	var error := _phase_error(Phase.SHOP)
	if not error.is_empty():
		return error
	error = _offer_error(_shop["cards"], index)
	if not error.is_empty():
		return error
	var offer: Dictionary = _shop["cards"][index]
	points -= offer["price"]
	offer["sold"] = true
	deck.append(offer["card"])
	logger.log_event("purchase_card", {"node": current_node, "card": offer["card"].to_dict(), "price": offer["price"]})
	return _ok()


func buy_piece(index: int) -> Dictionary:
	var error := _phase_error(Phase.SHOP)
	if not error.is_empty():
		return error
	error = _offer_error(_shop["pieces"], index)
	if not error.is_empty():
		return error
	var offer: Dictionary = _shop["pieces"][index]
	points -= offer["price"]
	offer["sold"] = true
	collection.append(offer["piece"])
	logger.log_event("purchase_piece", {"node": current_node, "piece": offer["piece"].to_dict(), "price": offer["price"]})
	return _ok()


func remove_card(card_uid: int) -> Dictionary:
	var error := _phase_error(Phase.SHOP)
	if not error.is_empty():
		return error
	if _shop["removes_left"] <= 0:
		return _fail("No card removals left in this shop")
	var min_size := int(GameConfig.value("economy", "min_deck_size"))
	if deck.size() <= min_size:
		return _fail("The deck can't have fewer than %d cards" % min_size)
	var price: int = _shop["remove_price"]
	if points < price:
		return _fail(_not_enough_points(price))
	var card := _deck_card(card_uid)
	if card == null:
		return _fail("Card is not in your deck")
	if card.type == "move" and _count_cards("move") == 1:
		return _fail("You can't remove your last Move card: it is the only way to move the king")
	deck.erase(card)
	points -= price
	_shop["removes_left"] -= 1
	logger.log_event("remove_card", {"node": current_node, "card": card.to_dict(), "price": price})
	return _ok()


func leave_shop() -> Dictionary:
	var error := _phase_error(Phase.SHOP)
	if not error.is_empty():
		return error
	phase = Phase.MAP
	return _ok()


## [{"kind": "card"|"piece", "item": CardData|PieceData, "upgrade", "upgrade_name",
##   "price", "state": "open"|"accepted"|"declined"}]. Generated once per visit.
func coaching_offers() -> Array[Dictionary]:
	if phase != Phase.COACHING:
		return []
	return _coaching.duplicate(true)


func accept_coaching(index: int) -> Dictionary:
	var error := _coaching_offer_error(index)
	if not error.is_empty():
		return error
	var offer := _coaching[index]
	if offer["item"].upgrade != "":
		return _fail("This item already has an upgrade")
	if points < offer["price"]:
		return _fail(_not_enough_points(offer["price"]))
	points -= offer["price"]
	offer["item"].upgrade = offer["upgrade"]
	offer["state"] = "accepted"
	logger.log_event("upgrade", {"node": current_node, offer["kind"]: offer["item"].to_dict(), "price": offer["price"]})
	return _ok()


func decline_coaching(index: int) -> Dictionary:
	var error := _coaching_offer_error(index)
	if not error.is_empty():
		return error
	_coaching[index]["state"] = "declined"
	return _ok()


func leave_coaching() -> Dictionary:
	var error := _phase_error(Phase.COACHING)
	if not error.is_empty():
		return error
	phase = Phase.MAP
	return _ok()


## {"kind": "artifact"|"piece_set"|"", "id", "is_new", "text"}; empty until the run ends.
func unlock_result() -> Dictionary:
	return _unlock.duplicate()


func summary() -> Dictionary:
	var floor_number := int(current_node_info().get("floor", 0))
	var deck_list: Array[Dictionary] = []
	for card in deck:
		deck_list.append(card.to_dict())
	var pieces: Array[Dictionary] = []
	var upgraded: Array[Dictionary] = []
	for piece in collection:
		pieces.append(piece.to_dict())
		if piece.upgrade != "":
			upgraded.append(piece.to_dict())
	return {
		"result": _result,
		"boss_defeated": _result == "won",
		"floors_cleared": floor_number if _result == "won" else maxi(floor_number - 1, 0),
		"floors_total": map.floors(),
		"wins": wins,
		"points": points,
		"piece_set": piece_set,
		"artifacts": artifacts.duplicate(),
		"visited": visited.duplicate(),
		"deck": deck_list,
		"collection": pieces,
		"upgraded_pieces": upgraded,
		"unlock": unlock_result(),
	}


func _build_starting_collection() -> void:
	collection.clear()
	for piece_type in GameConfig.value("economy", "starting_collection"):
		collection.append(PieceData.new(piece_type, piece_set))


func _build_starting_deck() -> void:
	deck.clear()
	var types: Array[String] = []
	for piece in collection:
		if piece.type != "king" and not types.has(piece.type):
			types.append(piece.type)
	for card_type in types:
		deck.append(CardData.new(card_type))
	deck.append(CardData.new("move"))


func _deploy_squares() -> Array[Vector2i]:
	var size := int(GameConfig.value("match", "board_size"))
	var squares: Array[Vector2i] = []
	for y in int(GameConfig.value("match", "deploy_rows")):
		for x in size:
			squares.append(Vector2i(x, y))
	return squares


## Pawns go to the front row centre-out, other pieces to the back row centre-out.
func _place(king: PieceData, pieces: Array[PieceData]) -> Array[Dictionary]:
	var size := int(GameConfig.value("match", "board_size"))
	var front_row := int(GameConfig.value("match", "deploy_rows")) - 1
	var columns: Array[int] = []
	for x in size:
		columns.append(x)
	var centre := (size - 1) / 2.0
	columns.sort_custom(func(a: int, b: int) -> bool: return absf(a - centre) < absf(b - centre) or (absf(a - centre) == absf(b - centre) and a < b))
	var front_squares: Array[Vector2i] = []
	var back_squares: Array[Vector2i] = []
	for x in columns:
		front_squares.append(Vector2i(x, front_row))
	for y in range(front_row - 1, -1, -1):
		for x in columns:
			back_squares.append(Vector2i(x, y))
	var roster: Array[Dictionary] = [{"piece": king, "square": back_squares.pop_front()}]
	for piece in pieces:
		var preferred := front_squares if piece.type == "pawn" else back_squares
		var fallback := back_squares if piece.type == "pawn" else front_squares
		var square: Vector2i = preferred.pop_front() if not preferred.is_empty() else fallback.pop_front()
		roster.append({"piece": piece, "square": square})
	return roster


func _is_better_pick(a: PieceData, b: PieceData) -> bool:
	if a.deploy_cost() != b.deploy_cost():
		return a.deploy_cost() > b.deploy_cost()
	return a.upgrade != "" and b.upgrade == ""


func _opponent_setup(opponent_id: String) -> Dictionary:
	var cfg: Dictionary = GameConfig.data("opponents")[opponent_id]
	var roster: Array[Dictionary] = []
	for entry in cfg["pieces"]:
		roster.append({"piece": PieceData.new(entry["type"], "standard"), "square": Vector2i(int(entry["square"][0]), int(entry["square"][1]))})
	var opponent_deck: Array[CardData] = []
	for card_type in cfg["deck"]:
		opponent_deck.append(CardData.new(card_type))
	var opponent_artifacts: Array[String] = []
	opponent_artifacts.assign(_pick_distinct(GameConfig.data("artifacts")["opponent_pool"], int(cfg["artifact_count"])))
	return {
		"id": opponent_id,
		"name": cfg["name"],
		"difficulty": cfg["difficulty"],
		"search_depth": int(cfg["search_depth"]),
		"random_chance": float(cfg["random_chance"]),
		"hidden_cards": int(cfg.get("hidden_cards", GameConfig.value("match", "opponent_hidden_cards"))),
		"roster": roster,
		"deck": opponent_deck,
		"artifacts": opponent_artifacts,
	}


func _result_error(result: Dictionary) -> Dictionary:
	var winner: Variant = result.get("winner")
	if not (winner is int or winner is float) or not int(winner) in [0, 1]:
		return _fail("Match result needs winner 0 (player) or 1 (opponent)")
	var scores: Variant = result.get("scores", [0, 0])
	if not scores is Array or scores.size() != 2:
		return _fail("Match result scores must be [player, opponent]")
	for key in ["shields_consumed", "player_pieces_used", "player_pieces_moved"]:
		if not result.get(key, []) is Array:
			return _fail("Match result %s must be an array of piece uids" % key)
	return {}


func _remove_used_shields(uids: Array) -> void:
	for uid in uids:
		var piece := _collection_piece(int(uid))
		if piece != null and piece.upgrade == "shield":
			piece.upgrade = ""


func _log_match(result: Dictionary, player_won: bool) -> void:
	var deck_list: Array[Dictionary] = []
	for card in deck:
		deck_list.append(card.to_dict())
	var node_info := current_node_info()
	logger.log_match({
		"node": current_node,
		"floor": node_info["floor"],
		"opponent": node_info["opponent"],
		"result": "win" if player_won else "loss",
		"reason": String(result.get("reason", "")),
		"scores": result.get("scores", [0, 0]),
		"deck": deck_list,
		"roster": _roster_log.duplicate(true),
		"pieces_used": _logged_roster_pieces(result.get("player_pieces_used", [])),
		"pieces_moved": _logged_roster_pieces(result.get("player_pieces_moved", [])),
		"shields_consumed": result.get("shields_consumed", []),
		"points_after": points,
	})


## Roster entries as they were at match start, so a shield used in the match still shows.
func _logged_roster_pieces(uids: Array) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for entry in _roster_log:
		if uids.has(entry["uid"]) or uids.has(float(entry["uid"])):
			pieces.append(entry.duplicate())
	return pieces


func _end_run(result: String) -> void:
	_result = result
	phase = Phase.RUN_END
	logger.finish_run(summary())


func _artifact_unlock(artifact_id: String) -> Dictionary:
	if artifact_id == "":
		return {"kind": "artifact", "id": "", "is_new": false, "text": "Every artifact is already unlocked."}
	var artifact_name: String = GameConfig.data("artifacts")["artifacts"][artifact_id]["name"]
	return {"kind": "artifact", "id": artifact_id, "is_new": true, "text": "New artifact unlocked: %s" % artifact_name}


func _piece_set_unlock(set_id: String, is_new: bool) -> Dictionary:
	var set_name: String = GameConfig.data("piece_sets")["sets"][set_id]["name"]
	var text := "New piece set unlocked: %s" % set_name if is_new else "%s pieces were already unlocked." % set_name
	return {"kind": "piece_set", "id": set_id, "is_new": is_new, "text": text}


func _generate_shop() -> void:
	var shop_cfg: Dictionary = GameConfig.data("economy")["shop"]
	var cards: Array[Dictionary] = []
	for card_type in _pick_distinct(shop_cfg["card_pool"], int(shop_cfg["card_offers"])):
		var card := CardData.new(card_type)
		var rarity: String = "rare" if card.is_rare() else "normal"
		cards.append({"card": card, "price": int(shop_cfg["card_prices"][rarity]), "sold": false})
	var pieces: Array[Dictionary] = []
	for piece_type in _pick_distinct(shop_cfg["piece_pool"], int(shop_cfg["piece_offers"])):
		pieces.append({"piece": PieceData.new(piece_type, piece_set), "price": int(shop_cfg["piece_prices"][piece_type]), "sold": false})
	_shop = {
		"cards": cards,
		"pieces": pieces,
		"remove_price": int(shop_cfg["remove_price"]),
		"removes_left": int(shop_cfg["removes_per_visit"]),
	}


func _offer_error(offers: Array, index: int) -> Dictionary:
	if index < 0 or index >= offers.size():
		return _fail("No offer at index %d" % index)
	if offers[index]["sold"]:
		return _fail("Already bought")
	if points < offers[index]["price"]:
		return _fail(_not_enough_points(offers[index]["price"]))
	return {}


func _generate_coaching() -> void:
	_coaching.clear()
	var coaching_cfg: Dictionary = GameConfig.data("economy")["coaching"]
	var cards := deck.filter(func(c: CardData) -> bool: return c.upgrade == "")
	var pieces := collection.filter(func(p: PieceData) -> bool: return p.upgrade == "")
	for card in _pick_distinct(cards, int(coaching_cfg["card_offers"])):
		_coaching.append(_coaching_offer("card", card))
	for piece in _pick_distinct(pieces, int(coaching_cfg["piece_offers"])):
		_coaching.append(_coaching_offer("piece", piece))


func _coaching_offer(kind: String, item: RefCounted) -> Dictionary:
	var upgrades_cfg: Dictionary = GameConfig.data("upgrades")[kind]
	var upgrade_ids: Array = upgrades_cfg.keys()
	var upgrade_id: String = upgrade_ids[_rng.randi_range(0, upgrade_ids.size() - 1)]
	return {
		"kind": kind,
		"item": item,
		"upgrade": upgrade_id,
		"upgrade_name": upgrades_cfg[upgrade_id]["name"],
		"price": int(upgrades_cfg[upgrade_id]["price"]),
		"state": "open",
	}


func _coaching_offer_error(index: int) -> Dictionary:
	var error := _phase_error(Phase.COACHING)
	if not error.is_empty():
		return error
	if index < 0 or index >= _coaching.size():
		return _fail("No coaching offer at index %d" % index)
	if _coaching[index]["state"] != "open":
		return _fail("This offer was already %s" % _coaching[index]["state"])
	return {}


## Up to count distinct entries of pool in random order, using the run's RNG.
func _pick_distinct(pool: Array, count: int) -> Array:
	var remaining := pool.duplicate()
	var picked := []
	while picked.size() < count and not remaining.is_empty():
		picked.append(remaining.pop_at(_rng.randi_range(0, remaining.size() - 1)))
	return picked


func _count_cards(card_type: String) -> int:
	return deck.filter(func(c: CardData) -> bool: return c.type == card_type).size()


func _find_king() -> PieceData:
	for piece in collection:
		if piece.type == "king":
			return piece
	return null


func _collection_piece(uid: int) -> PieceData:
	for piece in collection:
		if piece.uid == uid:
			return piece
	return null


func _deck_card(uid: int) -> CardData:
	for card in deck:
		if card.uid == uid:
			return card
	return null


func _phase_error(expected: Phase) -> Dictionary:
	if phase == expected:
		return {}
	return _fail("Not allowed now: the run is in %s, this needs %s" % [phase_name(), Phase.keys()[expected]])


func _not_enough_points(price: int) -> String:
	return "Not enough points (costs %d, you have %d)" % [price, points]


func _ok() -> Dictionary:
	return {"ok": true, "error": ""}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
