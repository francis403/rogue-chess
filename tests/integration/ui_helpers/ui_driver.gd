extends RefCounted
## Drives the real main scene like a player: presses Buttons, clicks tiles, cards,
## map nodes and board squares through the widgets' own input handlers, and waits
## (in real time, with Engine.time_scale raised) for animations and opponent turns.
## Never touches user://meta.json or user://settings.json: storage and settings go
## to a temp folder of this process (tests/hooks/test_tmp.gd), so parallel GUT runs
## never share meta files or run logs. Matches run at DEFAULT_SPEED ("fast": every
## animation step still plays, in about half the time); pass "normal" to start()
## to cover the real timings.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const TIME_SCALE := 40.0
const DEFAULT_TIMEOUT_MSEC := 15000
const DEFAULT_SPEED := "fast"

var main: Control
var temp_dir: String
var brain_rng := RandomNumberGenerator.new()
## Invariant violations seen while driving matches (tests assert this stays empty).
var failures: Array[String] = []

var _tree: SceneTree
var _host: Node
var _old_time_scale: float = 1.0
var _old_settings_path: String = ""
var _saved_random_chance: Dictionary = {}


func _init(host: Node, dir_name: String) -> void:
	_host = host
	_tree = host.get_tree()
	temp_dir = TestTmp.dir("ui/" + dir_name)
	brain_rng.seed = 7


## Fresh temp storage and settings (at `anim_speed`), optional pre-seeded unlocks,
## main scene instanced, faster clock.
func start(unlocked_sets: Array = [], unlocked_artifacts: Array = [], anim_speed: String = DEFAULT_SPEED) -> void:
	remove_dir(temp_dir)
	DirAccess.make_dir_recursive_absolute(temp_dir)
	_old_settings_path = Settings.path
	Settings.use_path(settings_path())
	Settings.set_value("anim_speed", anim_speed)
	if not unlocked_sets.is_empty() or not unlocked_artifacts.is_empty():
		var meta := MetaStore.new(meta_path())
		for set_id: String in unlocked_sets:
			meta.unlock_piece_set(set_id)
		for artifact_id: String in unlocked_artifacts:
			if not meta.unlocked_artifacts.has(artifact_id):
				meta.unlocked_artifacts.append(artifact_id)
		meta.save()
	Game.use_storage(meta_path(), log_dir())
	Game.run = null
	Game.match_setup = {}
	_old_time_scale = Engine.time_scale
	Engine.time_scale = TIME_SCALE
	main = load(MAIN_SCENE).instantiate()
	_host.add_child(main)
	await frames(2)


func stop() -> void:
	Engine.time_scale = _old_time_scale
	restore_opponents()
	if is_instance_valid(main):
		main.queue_free()
	await frames(2)
	Game.run = null
	Game.match_setup = {}
	Game.use_storage(MetaStore.DEFAULT_PATH, RunLogger.DEFAULT_DIR)
	# Back to the suite's temp settings (the GUT pre-run hook); loading never saves.
	if _old_settings_path != "":
		Settings.use_path(_old_settings_path)
	remove_dir(temp_dir)
	DirAccess.remove_absolute(TestTmp.dir("ui"))  # the parent, once empty


## Test seam for "set up an easy win": every opponent plays uniformly random legal
## moves (opponents.json random_chance = `chance`) until stop(). Only the in-memory
## GameConfig cache changes; the UI and the rules are untouched.
func weaken_opponents(chance: float = 1.0) -> void:
	var opponents: Dictionary = GameConfig.data("opponents")
	for opponent_id: String in opponents:
		if not _saved_random_chance.has(opponent_id):
			_saved_random_chance[opponent_id] = opponents[opponent_id]["random_chance"]
		opponents[opponent_id]["random_chance"] = chance


func restore_opponents() -> void:
	var opponents: Dictionary = GameConfig.data("opponents")
	for opponent_id: String in _saved_random_chance:
		opponents[opponent_id]["random_chance"] = _saved_random_chance[opponent_id]
	_saved_random_chance.clear()


func meta_path() -> String:
	return temp_dir + "meta.json"


func settings_path() -> String:
	return temp_dir + "settings.json"


func log_dir() -> String:
	return temp_dir + "logs/"


# --- Waiting --------------------------------------------------------------------

func frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


## Waits (real time) until `condition` is true. Returns false on timeout.
func until(condition: Callable, timeout_msec: int = DEFAULT_TIMEOUT_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await _tree.process_frame
	return true


func screen_name() -> String:
	return main.current_screen_name


func screen() -> Control:
	return main.current_screen


## Waits for the screen to change to `name` (and its first layout pass).
func wait_screen(name: String) -> bool:
	var ok: bool = await until(func() -> bool: return main.current_screen_name == name and is_instance_valid(main.current_screen) and main.current_screen.is_inside_tree())
	await frames(2)
	return ok


# --- Finding controls -------------------------------------------------------------

## Every live (not queued for deletion), visible node of `type` under `root`, in tree order.
static func find_all(root: Node, type: Variant) -> Array:
	var found: Array = []
	if root == null:
		return found
	for child in root.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is CanvasItem and not child.visible:
			continue
		if is_instance_of(child, type):
			found.append(child)
		found.append_array(find_all(child, type))
	return found


## The live Button whose text starts with `prefix` (in the current screen and overlays).
func button(prefix: String, root: Node = null) -> Button:
	var where: Node = root if root != null else main
	for node: Button in find_all(where, Button):
		if node.text.begins_with(prefix):
			return node
	return null


func buttons(prefix: String, root: Node = null) -> Array:
	var where: Node = root if root != null else main
	return find_all(where, Button).filter(func(node: Button) -> bool: return node.text.begins_with(prefix))


## Presses a Button like a player: only if it exists and is enabled. Returns whether it was pressed.
func press(node: Button) -> bool:
	if node == null or node.disabled or not node.is_visible_in_tree():
		return false
	node.pressed.emit()
	return true


## Emits `pressed` even on a disabled button (to prove the handler itself is guarded).
func force_press(node: Button) -> void:
	node.pressed.emit()


## A left click delivered to the control's own _gui_input at a local position.
func click(control: Control, local: Vector2 = Vector2(-1, -1)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = local if local.x >= 0.0 else control.size / 2.0
	event.global_position = control.get_global_transform() * event.position
	control._gui_input(event)


func right_click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = control.size / 2.0
	control._gui_input(event)


## Presses Esc through the viewport (so _unhandled_input handlers see it).
func press_escape() -> void:
	press_key(KEY_ESCAPE)


## Presses and releases a key through the viewport, like a keyboard: the focused
## control, then shortcut and unhandled-input handlers (overlays first) see it.
func press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	main.get_viewport().push_input(event)
	var release := event.duplicate()
	release.pressed = false
	main.get_viewport().push_input(release)


## Overlays (settings, deck, collection) currently open above the screen.
func overlays() -> Array:
	return main.get_node("%OverlayHost").get_children().filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


# --- Title / set / artifacts / map ------------------------------------------------

func select_tiles() -> Array:
	return find_all(screen(), SelectTile)


func click_map_node(node_id: String) -> bool:
	var map_view: MapView = find_all(screen(), MapView)[0]
	if not map_view.available.has(node_id):
		return false
	click(map_view, map_view.node_position(node_id))
	return true


## Clicks the first available map node in `preferred` order (falls back to the first available).
func travel(preferred: Array = []) -> String:
	var available: Array[String] = Game.run.available_nodes()
	var node_id: String = available[0]
	for wanted: String in preferred:
		if available.has(wanted):
			node_id = wanted
			break
	click_map_node(node_id)
	return node_id


# --- Roster ---------------------------------------------------------------------

## A closed pawn wall (no open file for a rook to reach the back rank): 12 budget points.
const WALL_ROSTER := [["pawn", 0, 1], ["pawn", 1, 1], ["pawn", 2, 1], ["pawn", 3, 1], ["pawn", 4, 1], ["pawn", 5, 1],
	["knight", 1, 0], ["bishop", 3, 0]]


## Builds a roster on the roster screen like a player: "Bench all", then for each
## [type, x, y] click a benched collection row of that type and then the square.
func build_roster(entries: Array) -> void:
	press(button("Bench all", screen()))
	await frames(1)
	for entry: Array in entries:
		var row := _benched_row(entry[0])
		if row == null:
			continue
		click(row)
		await frames(1)
		click_square(Vector2i(entry[1], entry[2]))
		await frames(1)


func _benched_row(piece_type: String) -> RosterRow:
	for row: RosterRow in find_all(screen(), RosterRow):
		if row.piece.type == piece_type and not _on_roster_board(row.piece):
			return row
	return null


func _on_roster_board(piece: PieceData) -> bool:
	return board().token(piece.uid) != null


# --- Match ----------------------------------------------------------------------

func board() -> BoardView:
	var boards := find_all(screen(), BoardView)
	return boards[0] if not boards.is_empty() else null


## The player's hand views in hand order (the opponent's hand row excluded).
func hand_views() -> Array:
	return find_all(screen(), CardView).filter(func(view: CardView) -> bool: return view.is_interactive)


func click_square(square: Vector2i) -> void:
	var board_view := board()
	click(board_view, board_view.square_centre(square))


func click_card(card_index: int) -> void:
	click(hand_views()[card_index])


func game() -> ChessMatch:
	return screen().game


## True once the match screen waits for the player: their turn, their check-escape
## prompt, or the match-over overlay.
func match_idle() -> bool:
	if main.current_screen_name != "MATCH" or not is_instance_valid(main.current_screen):
		return false
	var match_screen: Control = main.current_screen
	if match_screen.game == null or match_screen.is_busy():
		return false
	var match_game: ChessMatch = match_screen.game
	if match_game.is_over():
		return match_over_button() != null
	if match_game.pending_escape_side() != -1:
		return match_game.pending_escape_side() == ChessMatch.PLAYER
	return match_game.current_side() == ChessMatch.PLAYER


## Waits for the player's own turn (or the match end), pressing Stay on every escape prompt.
func wait_player_turn() -> bool:
	for i in 20:
		if not await wait_match_idle():
			return false
		if not escape_prompt_up():
			return true
		press(button("Stay", screen()))
	return false


func escape_prompt_up() -> bool:
	return match_idle() and not game().is_over() and game().pending_escape_side() == ChessMatch.PLAYER


## Answers the player's escape prompt the way `brain` decides: click the escape square or press Stay.
func answer_escape(brain: MatchAI) -> void:
	var action := brain.choose_action(game())
	if action.get("kind", "") == "escape":
		click_square(action["to"])
	else:
		press(button("Stay", screen()))


func wait_match_idle() -> bool:
	await frames(2)
	return await until(match_idle)


func match_over_button() -> Button:
	var found := button("Continue", screen())
	if found == null:
		found = button("See the run summary", screen())
	return found


## Plays one card through the UI. card_first: card -> piece -> target; else piece -> target.
func ui_play(play: Dictionary, card_first: bool = true) -> void:
	if card_first:
		click_card(play["card_index"])
		click_square(play["from"])
	else:
		click_square(play["from"])
	click_square(play["to"])


## Plays the player's whole turn with a MatchAI brain, clicking every action through the UI.
## Alternates card-first and piece-first and checks each click played the expected card.
## Returns false if the screen stops responding.
## Check-escape prompts met on the way (during either turn) are answered by the brain too.
func play_turn_with_brain(brain: MatchAI) -> bool:
	var actions := 0
	while match_idle() and not game().is_over() and actions < 40:
		actions += 1
		if escape_prompt_up():
			answer_escape(brain)
			if not await wait_match_idle():
				return false
			continue
		check_idle_invariants()
		var action := brain.choose_action(game())
		match action["kind"]:
			"play":
				var card_first := actions % 2 == 1
				var expected := action if card_first else MatchUiLogic.pick_play(game(), action["from"], action["to"])
				var card: CardData = game().hand(ChessMatch.PLAYER)[expected["card_index"]]
				var energy_before := game().energy(ChessMatch.PLAYER)
				ui_play(action, card_first)
				if not await wait_match_idle():
					return false
				_check_played(card, energy_before, card_first)
				continue
			"redraw":
				press(button("Redraw", screen()))
			_:
				press(button("End turn", screen()))
				return await wait_match_idle()
		if not await wait_match_idle():
			return false
	return true


## Records a failure when the card the click flow should have played is still in hand.
func _check_played(card: CardData, energy_before: int, card_first: bool) -> void:
	if game().is_over() or game().current_side() != ChessMatch.PLAYER or game().pending_escape_side() != -1:
		return
	var flow := "card-first" if card_first else "piece-first"
	for in_hand: CardData in game().hand(ChessMatch.PLAYER):
		if in_hand.uid == card.uid:
			failures.append("%s: %s (uid %d) is still in hand after its play" % [flow, card.display_name(), card.uid])
	if game().energy(ChessMatch.PLAYER) != energy_before - card.cost():
		failures.append("%s: energy %d -> %d, expected -%d for %s" % [flow, energy_before, game().energy(ChessMatch.PLAYER), card.cost(), card.display_name()])


## What must hold whenever the match waits for the player.
func check_idle_invariants() -> void:
	var redraw := button("Redraw", screen())
	var end_turn := button("End turn", screen())
	if redraw == null or end_turn == null:
		failures.append("Redraw / End turn button missing")
		return
	if redraw.disabled == game().can_redraw():
		failures.append("round %d: Redraw disabled=%s but can_redraw()=%s" % [game().current_round(), redraw.disabled, game().can_redraw()])
	if end_turn.disabled:
		failures.append("round %d: End turn disabled on the player's turn" % game().current_round())


## Plays the current match to its end with `brain` deciding the player's moves.
func play_match(brain: MatchAI) -> bool:
	if not await wait_match_idle():
		return false
	while not game().is_over():
		if not await play_turn_with_brain(brain):
			return false
	return await wait_match_idle()


func player_brain(depth: int = 2) -> MatchAI:
	return MatchAI.new(ChessMatch.PLAYER, depth, 0.0, brain_rng)


# --- Crafted matches -------------------------------------------------------------

## Shows the real match screen with a hand-made ChessMatch setup (needs a run for the HUD).
## Pieces: [type, x, y, upgrade?]; cards: "type" or "type:upgrade". A deck of exactly
## 5 cards is the whole opening hand. `hidden_cards` sets how many opponent cards
## are hidden (-1: the default, config/match.json).
func show_crafted_match(player: Array, opponent: Array, player_deck: Array, opponent_deck: Array, hidden_cards: int = -1) -> bool:
	Game.match_setup = {
		"seed": 5,
		"holes": [] as Array[Vector2i],
		"player": {"roster": _roster(player), "deck": _cards(player_deck), "artifacts": [] as Array[String]},
		"opponent": {"id": "easy", "name": "Rookie Rex", "difficulty": "Easy", "search_depth": 1, "random_chance": 0.0,
			"roster": _roster(opponent), "deck": _cards(opponent_deck), "artifacts": [] as Array[String]},
	}
	if hidden_cards >= 0:
		Game.match_setup["opponent"]["hidden_cards"] = hidden_cards
	main.show_screen("MATCH")
	return await wait_match_idle()


static func _roster(entries: Array) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for entry: Array in entries:
		var upgrade: String = entry[3] if entry.size() > 3 else ""
		roster.append({"piece": PieceData.new(entry[0], "standard", upgrade), "square": Vector2i(entry[1], entry[2])})
	return roster


static func _cards(specs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for spec: String in specs:
		var parts := spec.split(":")
		cards.append(CardData.new(parts[0], parts[1] if parts.size() > 1 else ""))
	return cards


## Index in the player's hand of the first card of `type` (and `upgrade`), or -1.
func hand_index(card_type: String, upgrade: String = "") -> int:
	var hand := game().hand(ChessMatch.PLAYER)
	for i in hand.size():
		if hand[i].type == card_type and hand[i].upgrade == upgrade:
			return i
	return -1


func hand_uids() -> Array:
	return game().hand(ChessMatch.PLAYER).map(func(card: CardData) -> int: return card.uid)


# --- Files -----------------------------------------------------------------------

static func remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		remove_dir(path.path_join(sub))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
