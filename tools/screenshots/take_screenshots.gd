extends Node
## Drives three runs through every screen and saves PNGs to docs/screenshots/.
## Uses a temp MetaStore and log folder, never user://meta.json.
## Run (needs a window, not headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/screenshots/take_screenshots.tscn

const OUT_DIR := "res://docs/screenshots/"
const TEMP_DIR := "user://screenshot_tmp/"
const MAIN_SCENE := "res://scenes/main.tscn"

var _main: Control
## Renders the game at exactly 1280x720 whatever size the OS gives the window.
var _viewport: SubViewport


## Opponent stand-in for the escape-prompt shot: one scripted rook move, then end turn.
class ScriptedAI extends MatchAI:
	var rook_move: Array = []

	func choose_action(game: ChessMatch) -> Dictionary:
		if game.pending_escape_side() == side:
			return {"kind": "decline_escape"}
		var hand := game.hand(side)
		for i in hand.size():
			if hand[i].type == "rook" and not rook_move.is_empty():
				var move: Array = rook_move
				rook_move = []
				return {"kind": "play", "card_index": i, "from": move[0], "to": move[1]}
		return {"kind": "end_turn"}

var _count: int = 0


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	# macOS stops drawing an occluded window, which would freeze every later screenshot.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	_remove_dir(TEMP_DIR)
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Game.use_storage(TEMP_DIR + "meta.json", TEMP_DIR + "logs/")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_main = load(MAIN_SCENE).instantiate()
	_viewport.add_child(_main)
	await _first_run()
	await _second_run()
	await _third_run()
	_remove_dir(TEMP_DIR)
	print("Saved %d screenshots to %s" % [_count, ProjectSettings.globalize_path(OUT_DIR)])
	get_tree().quit()


func _first_run() -> void:
	await _shot("title")
	Game.new_run(11)
	await _shot("set_select")
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	await _shot("map_start")
	_go("L1")
	await _shot("roster")
	_screen()._start_match()
	await _wait_idle()
	await _shot("match_start")
	await _select_first_card()
	await _shot("match_card_selected")
	_screen()._cancel()
	await _select_first_piece()
	await _shot("match_piece_first")
	await _capture_scene()
	await _match_over_scene()
	_screen()._finish_match()
	await _shot("reward")
	Game.run.take_reward(0)
	Game.show_phase()
	await _shot("map_progress")
	_go("L2")
	await _shot("shop")
	_screen()._open_removal()
	await _shot("shop_remove_card")
	_close_overlays()
	_buy_affordable_card()
	await _shot("shop_after_buy")
	Game.run.leave_shop()
	_skip_match("L3", false)
	_skip_match("L4", false)
	_go("L5")
	await _shot("coaching")
	_accept_first_coaching()
	await _shot("coaching_accepted")
	_main._show_deck()
	await _shot("deck_view")
	_close_overlays()
	_main._show_collection()
	await _shot("collection_view")
	_close_overlays()
	Game.run.leave_coaching()
	_skip_match("L6", true)
	Game.show_phase()
	await _shot("map_before_boss")
	_go("BOSS")
	await _shot("roster_boss")
	_screen()._start_match()
	await _wait_idle()
	await _shot("match_boss")
	Game.run.finish_match({"winner": 0, "reason": "king", "scores": [6, 2]})
	Game.show_phase()
	await _shot("run_end_victory")


func _second_run() -> void:
	Game.new_run(22)
	await _shot("set_select_fire_unlocked")
	Game.run.choose_piece_set("fire")
	_go("M1")
	await _shot("roster_fire")
	_screen()._start_match()
	await _wait_idle()
	await _select_first_piece()
	await _shot("match_fire_ignite_hint")
	_screen()._cancel()
	await _play_first_legal()
	await _play_first_legal()
	await _shot("match_fire_burning")
	Game.run.finish_match({"winner": 1, "reason": "score", "scores": [3, 10]})
	Game.show_phase()
	await _shot("run_end_defeat")


func _third_run() -> void:
	var meta := Game.unlocks()
	for artifact_id: String in GameConfig.data("artifacts")["unlock_pool"]:
		if not meta.unlocked_artifacts.has(artifact_id):
			meta.unlocked_artifacts.append(artifact_id)
	meta.save()
	Game.show_title()
	await _shot("title_progress")
	Game.new_run(33)
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	_screen()._toggle("holes")
	_screen()._toggle("exploding")
	await _shot("artifact_select")
	_screen()._continue()
	_go("M1")
	_screen()._start_match()
	await _wait_idle()
	await _shot("match_artifacts_holes")
	await _shield_and_explosion_scene()
	await _check_scenes()


# --- Crafted match moments ------------------------------------------------------

func _capture_scene() -> void:
	_show_crafted(_crafted(
		[["king", 2, 0], ["knight", 1, 2], ["pawn", 3, 1], ["rook", 0, 0, "shield"], ["bishop", 4, 0, "range"]],
		[["king", 2, 5], ["bishop", 2, 4], ["pawn", 4, 4], ["knight", 1, 5]],
		["knight", "knight:hold", "move", "rook", "pawn:cheaper"], ["pawn", "knight", "move", "bishop", "pawn"]))
	await _wait_idle()
	await _press_play("knight", Vector2i(1, 2), Vector2i(2, 4), 0.22)
	await _shot("match_capture")
	await _wait_idle()
	_screen()._on_end_turn()
	await _settle(0.5)
	await _shot("match_opponent_turn")
	await _wait_idle()
	await _shot("match_after_opponent")


func _match_over_scene() -> void:
	_show_crafted(_crafted([["king", 2, 0], ["queen", 2, 3]], [["king", 2, 5], ["pawn", 0, 4]],
		["queen", "queen", "queen", "move", "move"], ["pawn", "move", "move", "move", "move"]))
	await _wait_idle()
	await _press_play("queen", Vector2i(2, 3), Vector2i(2, 5), 0.0)
	await _wait_idle()
	await _shot("match_over")


func _shield_and_explosion_scene() -> void:
	_show_crafted(_crafted(
		[["king", 2, 0], ["rook", 2, 2], ["knight", 4, 2], ["pawn", 1, 1]],
		[["king", 0, 5], ["bishop", 2, 4, "shield"], ["pawn", 5, 4], ["pawn", 4, 4], ["knight", 4, 5]],
		["rook", "knight", "move", "pawn", "move"], ["pawn", "move", "move", "move", "move"], ["exploding"]))
	await _wait_idle()
	await _press_play("rook", Vector2i(2, 2), Vector2i(2, 4), 0.12)
	await _shot("match_shield_block")
	await _settle(0.4)
	await _press_play("knight", Vector2i(4, 2), Vector2i(5, 4), 0.1)
	await _shot("match_explosion")
	await _wait_idle()


## The opponent answers the player's check, then the player's own escape prompt.
func _check_scenes() -> void:
	_show_crafted(_crafted([["king", 0, 0], ["rook", 3, 1], ["pawn", 1, 1]], [["king", 2, 5], ["pawn", 4, 4], ["knight", 4, 5]],
		["rook", "move", "pawn", "move", "move"], ["move", "move", "move", "move", "move"]))
	await _wait_idle()
	await _press_play("rook", Vector2i(3, 1), Vector2i(2, 1), 0.0)
	await _settle(float(GameConfig.value("ai", "move_delay_seconds")) + 0.45)
	await _shot("match_opponent_escapes")
	await _wait_idle()
	_show_crafted(_crafted([["king", 2, 0], ["pawn", 5, 1], ["pawn", 0, 1], ["knight", 1, 0]], [["king", 5, 5], ["rook", 3, 5], ["pawn", 4, 4]],
		["move", "move", "pawn", "knight", "move"], ["rook", "rook", "rook", "rook", "rook"]))
	await _wait_idle()
	var scripted := ScriptedAI.new(ChessMatch.OPPONENT, 1, 0.0, RandomNumberGenerator.new())
	scripted.rook_move = [Vector2i(3, 5), Vector2i(2, 5)]
	_screen()._ai = scripted
	_screen()._on_end_turn()
	await _wait_idle()
	await _shot("match_escape_prompt")


## A setup in ChessMatch format. Pieces: [type, x, y, upgrade?]; cards: "type:upgrade".
func _crafted(player: Array, opponent: Array, player_deck: Array, opponent_deck: Array, player_artifacts: Array = []) -> Dictionary:
	return {
		"seed": 5,
		"holes": [] as Array[Vector2i],
		"player": {"roster": _roster(player, Game.run.piece_set), "deck": _cards(player_deck), "artifacts": player_artifacts},
		"opponent": {"id": "easy", "name": "Rookie Rex", "difficulty": "Easy", "search_depth": 1, "random_chance": 0.0,
			"roster": _roster(opponent, "standard"), "deck": _cards(opponent_deck), "artifacts": []},
	}


func _roster(entries: Array, set_id: String) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for entry: Array in entries:
		var upgrade: String = entry[3] if entry.size() > 3 else ""
		roster.append({"piece": PieceData.new(entry[0], set_id, upgrade), "square": Vector2i(entry[1], entry[2])})
	return roster


func _cards(specs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for spec: String in specs:
		var parts := spec.split(":")
		cards.append(CardData.new(parts[0], parts[1] if parts.size() > 1 else ""))
	return cards


func _show_crafted(setup: Dictionary) -> void:
	Game.match_setup = setup
	_main.show_screen("MATCH")


## Selects the card of `card_type`, then the piece, then the target; shoots after `delay`.
func _press_play(card_type: String, from: Vector2i, to: Vector2i, delay: float) -> void:
	var screen := _screen()
	var hand: Array[CardData] = screen.game.hand(ChessMatch.PLAYER)
	for i in hand.size():
		if hand[i].type == card_type and not screen.game.targets(i, from).is_empty():
			screen.press_card(i)
			break
	await _settle(0.25)
	screen.press_square(from)
	screen.press_square(to)
	await _settle(delay)


func _select_first_card() -> void:
	var screen := _screen()
	var game: ChessMatch = screen.game
	for i in game.hand(ChessMatch.PLAYER).size():
		if game.is_card_playable(i) and game.hand(ChessMatch.PLAYER)[i].type != "move":
			screen.press_card(i)
			var pieces := game.pieces_for_card(i)
			screen.press_square(pieces[pieces.size() / 2])
			return


func _select_first_piece() -> void:
	var squares := MatchUiLogic.movable_pieces(_screen().game)
	_screen().press_square(squares[squares.size() - 1])


func _play_first_legal() -> void:
	var game: ChessMatch = _screen().game
	var plays := game.legal_plays(ChessMatch.PLAYER)
	if plays.is_empty():
		return
	var play: Dictionary = plays[plays.size() - 1]
	_screen().press_square(play["from"])
	_screen().press_square(play["to"])
	await _wait_idle()


# --- Run helpers ---------------------------------------------------------------

func _go(node_id: String) -> void:
	var result := Game.run.choose_node(node_id)
	assert(result["ok"], result["error"])
	Game.show_phase()


## Plays a match node "off screen" by reporting a win, then answers the reward.
func _skip_match(node_id: String, take_card: bool) -> void:
	Game.run.choose_node(node_id)
	Game.run.build_match_setup(Game.run.default_roster())
	Game.run.finish_match({"winner": 0, "reason": "score", "scores": [10, 4]})
	if take_card:
		Game.run.take_reward(0)
	else:
		Game.run.skip_reward()


func _buy_affordable_card() -> void:
	var offers: Array = Game.run.shop_offers()["cards"]
	for i in offers.size():
		if offers[i]["price"] <= Game.run.points:
			_screen()._apply(Game.run.buy_card(i), "Bought %s" % offers[i]["card"].display_name())
			return


func _accept_first_coaching() -> void:
	var offers := Game.run.coaching_offers()
	for i in offers.size():
		if offers[i]["price"] <= Game.run.points:
			_screen()._apply(Game.run.accept_coaching(i), "Upgraded")
			_screen()._apply(Game.run.decline_coaching((i + 1) % offers.size()), "")
			return


func _close_overlays() -> void:
	for overlay in get_tree().root.find_children("*", "ItemOverlay", true, false):
		overlay.queue_free()


# --- Capture ------------------------------------------------------------------

func _screen() -> Control:
	return _main.current_screen


func _shot(screen_name: String) -> void:
	await _settle(0.45)
	if not DisplayServer.window_can_draw():
		# The engine skips drawing a hidden window; draw this frame by hand.
		RenderingServer.force_draw(false)
	_count += 1
	var path := ProjectSettings.globalize_path(OUT_DIR + "%02d_%s.png" % [_count, screen_name])
	var image := _viewport.get_texture().get_image()
	image.save_png(path)
	print("screenshot: ", path)


func _settle(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


func _wait_idle(limit: float = 25.0) -> void:
	await _settle(0.3)
	var waited := 0.0
	while waited < limit:
		var screen := _screen()
		if not screen.has_method("is_busy") or not screen.is_busy():
			return
		await _settle(0.1)
		waited += 0.1
	push_warning("Screen still busy after %.0fs" % limit)


func _remove_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	for sub_dir in dir.get_directories():
		_remove_dir(dir_path.path_join(sub_dir))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)
