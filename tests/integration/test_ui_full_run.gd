extends GutTest
## A full first run through the real UI scenes: title -> set select -> (no artifact step)
## -> map -> matches (moves clicked card/piece/target), reward, shop, coaching -> boss
## -> run end with the Fire unlock -> "Start new run" -> set select with a fresh run.

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")
const REAL_META_PATH := "user://meta.json"
## The opponents are weakened to random play (UiDriver.weaken_opponents) so the
## depth-2 player brain reliably wins the run; the real AI is driven through the UI
## in test_ui_unlocks_and_loss.gd and test_ui_match_input.gd. A run is deterministic
## per seed: every random draw comes from the run's, the match's and the brains' own
## seeded RandomNumberGenerators, never from UI timing or the global RNG (Sfx jitter
## and FX use randf()/randi(), which no game RNG reads). The outcome still changes
## when screens change what the driver clicks (which offer is first, the reward
## order) or config tuning changes, so later seeds are fallbacks. Seed 8 (first
## until iteration 2) now loses the boss; 5 wins it.
const RUN_SEEDS := [5, 8, 1, 7, 2, 3]
const ROUTE := ["L1", "L2", "L3", "L4", "L5", "L6", "BOSS"]

var ui: UiDriver


func before_each() -> void:
	ui = UiDriver.new(self, "full_run")


func after_each() -> void:
	await ui.stop()


func test_first_run_end_to_end_through_the_ui() -> void:
	var started := Time.get_ticks_msec()
	var real_meta_before := UiDriver.read(REAL_META_PATH)
	var seeds: Array = RUN_SEEDS
	if OS.get_environment("UI_RUN_SEED") != "":
		seeds = [int(OS.get_environment("UI_RUN_SEED"))]
	var won := false
	var won_seed := 0
	var carried_failures: Array[String] = []
	for run_seed: int in seeds:
		carried_failures.append_array(ui.failures)
		await ui.stop()
		# Each attempt gets its own temp folder: a lost attempt's run log can never be counted.
		ui = UiDriver.new(self, "full_run_seed%d" % run_seed)
		ui.failures.append_array(carried_failures)
		carried_failures.clear()
		await ui.start()  # fresh temp meta: a true first run every attempt
		ui.weaken_opponents()
		if await _first_run(run_seed):
			won = true
			won_seed = run_seed
			break
		if is_failing():
			# A broken screen, not a lost run: another seed would only repeat the failures.
			return
		gut.p("seed %d lost before beating the boss; trying the next seed" % run_seed)
	if not won:
		fail_test("No seed in %s beat the boss. The UI flow worked; pick new RUN_SEEDS." % [seeds])
		return

	# Run end: boss beaten, Fire unlocked and persisted to the temp meta file.
	assert_eq(ui.screen_name(), "RUN_END")
	var unlock := Game.run.unlock_result()
	assert_eq(unlock.get("kind"), "piece_set")
	assert_eq(unlock.get("id"), "fire")
	assert_true(unlock.get("is_new", false))
	assert_true(_has_label(ui.screen(), "Fire pieces"), "run end shows the Fire unlock")
	assert_true(_has_label(ui.screen(), "The boss has fallen"))
	assert_true(Game.unlocks().is_piece_set_unlocked("fire"))
	assert_true(MetaStore.new(ui.meta_path()).is_piece_set_unlocked("fire"), "unlock saved to the temp meta file")
	assert_eq(_run_logs(), ["seed %d" % won_seed], "exactly one run log, for this attempt's seed, in its temp log folder")

	# Start new run -> set select with a fresh session, Fire now selectable.
	var finished_run: RunSession = Game.run
	assert_true(ui.press(ui.button("Start new run")))
	assert_true(await ui.wait_screen("SET_SELECT"))
	assert_ne(Game.run, finished_run, "a new RunSession")
	assert_eq(Game.run.phase_name(), "SET_SELECT")
	assert_eq(Game.run.wins, 0)
	assert_eq(Game.run.points, 0)
	assert_eq(Game.run.visited, [] as Array[String])
	var tiles := ui.select_tiles()
	assert_false(tiles[1].is_locked, "Fire is unlocked for the next run")

	assert_eq(ui.failures, [] as Array[String], "every click played the expected card; Redraw/End turn states were right")
	assert_eq(UiDriver.read(REAL_META_PATH), real_meta_before, "the real meta.json is never touched")
	gut.p("full run took %d ms" % (Time.get_ticks_msec() - started))


## Title -> New Game -> set select -> map -> every ROUTE node. Returns whether the boss was beaten.
func _first_run(run_seed: int) -> bool:
	assert_eq(ui.screen_name(), "TITLE")
	assert_true(ui.press(ui.button("New Game")), "New Game button pressed")
	assert_true(await ui.wait_screen("SET_SELECT"))
	var unseeded_run: RunSession = Game.run
	Game.new_run(run_seed)  # what New Game does, with a fixed seed so the run is reproducible
	assert_true(await ui.wait_screen("SET_SELECT"))
	assert_ne(Game.run, unseeded_run)

	# Set select: Fire is locked on the first run, Standard starts it; the artifact step is skipped.
	var tiles := ui.select_tiles()
	assert_eq(tiles.size(), 2, "Standard and Fire tiles")
	assert_true(tiles[1].is_locked, "Fire is locked on the first run")
	ui.click(tiles[1])
	assert_eq(Game.run.piece_set, "", "clicking the locked Fire tile does nothing")
	ui.click(tiles[0])
	assert_true(await ui.wait_screen("MAP"), "no artifact is unlocked, so the artifact step is skipped")
	assert_eq(Game.run.piece_set, "standard")
	assert_eq(Game.run.artifacts, [] as Array[String])

	for node_id: String in ROUTE:
		assert_eq(ui.screen_name(), "MAP", "back on the map before %s" % node_id)
		assert_true(ui.click_map_node(node_id), "%s is clickable on the map" % node_id)
		match Game.run.map.node(node_id)["type"]:
			"match", "boss":
				if not await _play_match_node(node_id):
					return false
			"shop":
				await _shop_buy_and_leave()
			"coaching":
				await _coaching_accept_and_leave()
	return true


## Roster -> Start match -> play to the end -> Continue -> reward (or run end). Returns whether the player won.
func _play_match_node(node_id: String) -> bool:
	assert_true(await ui.wait_screen("MATCH_SETUP"), "%s opens the roster screen" % node_id)
	var start := ui.button("Start match")
	assert_false(start.disabled, "the default roster is valid")
	await ui.build_roster(UiDriver.WALL_ROSTER)
	start = ui.button("Start match")
	assert_false(start.disabled, "the hand-built pawn-wall roster is valid")
	assert_true(ui.press(start))
	assert_true(await ui.wait_screen("MATCH"))
	assert_eq(Game.match_setup["player"]["roster"].size(), UiDriver.WALL_ROSTER.size() + 1, "king + the clicked pieces")
	assert_true(await ui.play_match(ui.player_brain()), "%s finished without a softlock" % node_id)
	var result: Dictionary = ui.game().result()
	var won: bool = result["winner"] == ChessMatch.PLAYER
	gut.p("%s: %s by %s, %s in %d rounds" % [node_id, "won" if won else "lost", result["reason"], result["scores"], result["rounds"]])
	var points_before := Game.run.points
	var over_button := ui.match_over_button()
	assert_true(ui.press(over_button), "match-over button")
	ui.force_press(over_button)  # double press: finish_match must apply once
	if not won:
		await ui.wait_screen("RUN_END")
		return false
	if Game.run.map.node(node_id)["type"] == "boss":
		assert_true(await ui.wait_screen("RUN_END"))
		return true
	assert_true(await ui.wait_screen("REWARD"))
	assert_eq(Game.run.points, points_before + 2, "+2 training points per win")
	var deck_size := Game.run.deck.size()
	var offers := ui.find_all(ui.screen(), CardView)
	assert_eq(offers.size(), 3, "three reward cards")
	var picked: CardData = offers[0].card
	ui.click(offers[0])
	ui.click(offers[1])  # a second click while the first pick animates is ignored
	assert_true(await ui.wait_screen("MAP"))
	assert_eq(Game.run.deck.size(), deck_size + 1, "exactly one reward card added")
	assert_eq(Game.run.deck[-1].type, picked.type)
	return true


func _shop_buy_and_leave() -> void:
	assert_true(await ui.wait_screen("SHOP"))
	var points := Game.run.points
	var deck_size := Game.run.deck.size()
	var collection_size := Game.run.collection.size()
	var buy := ui.button("Buy")
	assert_not_null(buy, "something is affordable with %d points" % points)
	assert_true(ui.press(buy))
	ui.force_press(buy)  # double press: the second is refused, nothing is bought twice
	await ui.frames(2)
	var bought := (Game.run.deck.size() - deck_size) + (Game.run.collection.size() - collection_size)
	assert_eq(bought, 1, "exactly one item bought")
	assert_lt(Game.run.points, points, "points spent")
	assert_gt(ui.buttons("Sold").size(), 0, "the bought offer now shows Sold")
	assert_true(ui.press(ui.button("Leave the shop")))
	assert_true(await ui.wait_screen("MAP"))


func _coaching_accept_and_leave() -> void:
	assert_true(await ui.wait_screen("COACHING"))
	var points := Game.run.points
	var accept := ui.button("Accept")
	assert_not_null(accept, "an upgrade is affordable with %d points" % points)
	var offer_index := _offer_index_of(accept)
	var offer: Dictionary = Game.run.coaching_offers()[offer_index]
	assert_true(ui.press(accept))
	ui.force_press(accept)  # double press: refused, paid once
	await ui.frames(2)
	assert_eq(Game.run.points, points - int(offer["price"]), "paid exactly once")
	assert_eq(offer["item"].upgrade, offer["upgrade"], "the upgrade is on the item")
	assert_eq(Game.run.coaching_offers()[offer_index]["state"], "accepted")
	assert_true(ui.press(ui.button("Leave coaching")))
	assert_true(await ui.wait_screen("MAP"))


## Index of the coaching offer whose Accept button this is (offers are built in order).
func _offer_index_of(accept: Button) -> int:
	var all := ui.find_all(ui.screen(), Button).filter(func(node: Button) -> bool: return node.text.begins_with("Accept") or node.text.contains("can't afford"))
	return all.find(accept)


func _has_label(root: Node, text: String) -> bool:
	for node: Label in UiDriver.find_all(root, Label):
		if node.text.contains(text):
			return true
	return false


## "seed N" for every run log in the current attempt's log folder (from the log's own "seed").
func _run_logs() -> Array:
	var logs := []
	for file_name in DirAccess.get_files_at(ui.log_dir()):
		if file_name.begins_with("run_") and file_name.ends_with(".json"):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ui.log_dir() + file_name))
			logs.append("seed %d" % int(data.get("seed", -1)) if data is Dictionary else file_name)
	return logs
