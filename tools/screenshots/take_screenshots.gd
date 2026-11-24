extends Node
## Drives runs through every screen and saves PNGs:
##   docs/screenshots/NN_*.png          every screen at 1280x720 (the base canvas)
##   docs/screenshots/1080p/NN_*.png    a subset as a 1920x1080 window shows it
##   docs/screenshots/16x10/NN_*.png    the same subset in a 1280x800 window (aspect expand)
##   docs/screenshots/frames/*_NN.png   motion frame sequences (capture, explosion, card play,
##                                      turn banner, settings, map travel, coaching accept,
##                                      deck overlay, run-end victory)
## Uses a temp MetaStore, log folder and settings file (normal animation speed) in a
## folder of this process (user://screenshot_tmp/p<pid>/), never user://meta.json or
## user://settings.json, so it can run while GUT or the sim runs.
## Run (needs a window, not headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/screenshots/take_screenshots.tscn
## Add `-- --large-text` for the base pass with Large text on (docs/screenshots/large_text/).

const ShotStage := preload("res://tools/screenshots/shot_stage.gd")
const ShotMoments := preload("res://tools/screenshots/shot_moments.gd")

const OUT_DIR := "res://docs/screenshots/"
const FRAMES_DIR := OUT_DIR + "frames/"
const TEMP_PARENT := "user://screenshot_tmp/"
const BASE_WINDOW := Vector2i(1280, 720)
## The run end plays its payoff (count-up, unlock deal-in) for about 2.5 s at normal speed.
const RUN_END_SETTLE := 3.0
## Extra window sizes: output subfolder -> window size.
const EXTRA_WINDOWS := {"1080p": Vector2i(1920, 1080), "16x10": Vector2i(1280, 800)}

## This process's temp folder.
var _temp_dir := "%sp%d/" % [TEMP_PARENT, OS.get_process_id()]
var _stage: ShotStage
var _moments: ShotMoments
var _saved: int = 0


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(BASE_WINDOW)
	# macOS stops drawing an occluded window, which would freeze every later screenshot.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	_remove_dir(_temp_dir)
	DirAccess.make_dir_recursive_absolute(_temp_dir)
	Settings.use_path(_temp_dir + "settings.json")
	Settings.set_value("anim_speed", "normal")
	if OS.get_cmdline_user_args().has("--large-text"):
		await _large_text_pass()
		return
	_remove_pngs(OUT_DIR)
	_remove_pngs(FRAMES_DIR)
	await _open_stage(BASE_WINDOW, OUT_DIR, "base")
	await _first_run()
	await _second_run()
	await _third_run()
	await _extras_run()
	await _moments.motion_frames()
	await _menu_frames()
	await _close_stage()
	for folder: String in EXTRA_WINDOWS:
		_remove_pngs(OUT_DIR + folder + "/")
		await _open_stage(EXTRA_WINDOWS[folder], OUT_DIR + folder + "/", folder)
		await _subset_run()
		await _close_stage()
	_remove_dir(_temp_dir)
	DirAccess.remove_absolute(TEMP_PARENT)  # only once empty
	print("Saved %d screenshots to %s" % [_saved, ProjectSettings.globalize_path(OUT_DIR)])
	get_tree().quit()


## `-- --large-text`: the base 1280x720 runs only, with the Large text setting
## on, into docs/screenshots/large_text/ (a check for clipping; no frames).
func _large_text_pass() -> void:
	Settings.set_value("large_text", true)
	var dir := OUT_DIR + "large_text/"
	_remove_pngs(dir)
	await _open_stage(BASE_WINDOW, dir, "large_text")
	await _first_run()
	await _second_run()
	await _third_run()
	await _extras_run()
	await _close_stage()
	_remove_dir(_temp_dir)
	DirAccess.remove_absolute(TEMP_PARENT)  # only once empty
	print("Saved %d screenshots to %s" % [_saved, ProjectSettings.globalize_path(dir)])
	get_tree().quit()


## A fresh stage (viewport + main scene) with its own temp storage: a true first run.
func _open_stage(window: Vector2i, dir: String, tag: String) -> void:
	var storage := _temp_dir + tag + "/"
	DirAccess.make_dir_recursive_absolute(storage)
	Game.use_storage(storage + "meta.json", storage + "logs/")
	Game.run = null
	Game.match_setup = {}
	_stage = ShotStage.new()
	add_child(_stage)
	_stage.open(window, dir)
	_moments = ShotMoments.new(_stage, FRAMES_DIR)
	await get_tree().process_frame


func _close_stage() -> void:
	_saved += _stage.saved.size()
	_stage.close()
	await get_tree().process_frame
	_stage = null
	_moments = null


func _shot(shot_name: String, settle: float = ShotStage.SETTLE) -> void:
	await _stage.shot(shot_name, settle)


func _screen() -> Control:
	return _stage.screen()


# --- Base pass (1280x720) --------------------------------------------------------

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
	await _stage.wait_idle()
	await _shot("match_start")
	_moments.select_first_card()
	await _shot("match_card_selected")
	_screen()._cancel()
	_moments.select_first_piece()
	await _shot("match_piece_first")
	await _moments.capture_scene()
	await _moments.match_over_scene()
	_screen()._finish_match()
	await _shot("reward")
	Game.run.take_reward(0)
	Game.show_phase()
	await _shot("map_progress")
	_go("L2")
	await _shot("shop")
	_screen()._open_removal()
	await _shot("shop_remove_card")
	await _close_overlays()
	_buy_affordable_card()
	await _shot("shop_after_buy", 0.4)  # the "−N pt" float is still rising
	Game.run.leave_shop()
	_skip_match("L3", false)
	_skip_match("L4", false)
	_go("L5")
	await _shot("coaching")
	_accept_first_coaching()
	await _shot("coaching_accepted")
	await _stage.key(KEY_D)
	await _shot("deck_view")
	await _close_overlays()
	await _stage.key(KEY_C)
	await _shot("collection_view")
	await _close_overlays()
	Game.run.leave_coaching()
	_skip_match("L6", true)
	Game.show_phase()
	await _shot("map_before_boss")
	_go("BOSS")
	await _shot("roster_boss")
	_screen()._start_match()
	await _stage.wait_idle()
	await _shot("match_boss")
	Game.run.finish_match({"winner": 0, "reason": "king", "scores": [6, 2]})
	Game.show_phase()
	await _shot("run_end_victory", RUN_END_SETTLE)


func _second_run() -> void:
	Game.new_run(22)
	await _shot("set_select_fire_unlocked")
	Game.run.choose_piece_set("fire")
	_go("M1")
	await _shot("roster_fire")
	_screen()._start_match()
	await _stage.wait_idle()
	_moments.select_first_piece()
	await _shot("match_fire_ignite_hint")
	_screen()._cancel()
	await _moments.play_first_legal()
	await _moments.play_first_legal()
	await _shot("match_fire_burning")
	Game.run.finish_match({"winner": 1, "reason": "score", "scores": [3, 10]})
	Game.show_phase()
	await _shot("run_end_defeat", RUN_END_SETTLE)


func _third_run() -> void:
	_unlock_all_artifacts()
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
	await _stage.wait_idle()
	await _shot("match_artifacts_holes")
	await _moments.shield_and_explosion_scene()
	await _moments.check_scenes()


## Settings (title and match), keyboard focus on the map and in the deck overlay,
## a hovered card. Reduced motion is not visual, so it has no shot.
func _extras_run() -> void:
	Game.show_title()
	await _stage.wait(ShotStage.SETTLE)
	await _stage.key(KEY_F1)
	await _shot("settings_title", 0.5)
	await _stage.key(KEY_F1)
	Game.new_run(44)
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	if _stage.main.current_screen_name == "ARTIFACT_SELECT":
		_screen()._continue()
	await _stage.wait(ShotStage.SETTLE)
	await _stage.key(KEY_RIGHT)  # keyboard navigation shows the focus ring on a node
	await _shot("map_keyboard_focus", 0.3)
	await _stage.key(KEY_D)
	await _stage.wait(0.4)
	await _stage.key(KEY_RIGHT)
	await _stage.key(KEY_RIGHT)
	await _shot("deck_keyboard_focus", 0.3)
	await _stage.key(KEY_ESCAPE)
	_go(Game.run.available_nodes()[0])
	await _stage.wait(0.3)
	_screen()._start_match()
	await _stage.wait_idle()
	await _hover_card(2)
	await _shot("match_card_hover", 0.4)
	await _stage.key(KEY_F1)
	await _shot("settings_match", 0.5)
	await _stage.key(KEY_F1)


## Hovers the player's hand card `index` (the card lifts and its tooltip text shows).
func _hover_card(index: int) -> void:
	var views := _screen().find_children("*", "CardView", true, false).filter(
		func(view: CardView) -> bool: return not view.is_back and view.is_visible_in_tree())
	if index < views.size():
		(views[index] as CardView).mouse_entered.emit()
	await get_tree().process_frame


# --- Subset pass (other window sizes) -------------------------------------------

## Title, settings, map, roster, match, escape prompt, reward, shop, run end, then
## set select, coaching, deck view, artifact select and the roster keyboard cursor.
func _subset_run() -> void:
	await _shot("title")
	await _stage.key(KEY_F1)
	await _shot("settings", 0.5)
	await _stage.key(KEY_F1)
	Game.new_run(11)
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	await _shot("map")
	_go("L1")
	await _shot("roster")
	_screen()._start_match()
	await _stage.wait_idle()
	await _shot("match")
	await _moments.escape_prompt_scene()
	await _shot("match_escape_prompt")
	Game.run.finish_match({"winner": 0, "reason": "score", "scores": [10, 4]})
	Game.show_phase()
	await _shot("reward")
	Game.run.take_reward(0)
	Game.show_phase()
	_go("L2")
	await _shot("shop")
	Game.run.leave_shop()
	Game.run.choose_node("L3")
	Game.run.build_match_setup(Game.run.default_roster())
	Game.run.finish_match({"winner": 1, "reason": "score", "scores": [3, 10]})
	Game.show_phase()
	await _shot("run_end", RUN_END_SETTLE)
	await _subset_menus()


## Set select, coaching, deck view, artifact select and the roster's keyboard square
## cursor (after the older shots, so their numbers stay put).
func _subset_menus() -> void:
	Game.new_run(11)
	await _shot("set_select")
	Game.run.choose_piece_set("standard")
	_skip_artifacts()
	Game.show_phase()
	await _stage.wait(ShotStage.SETTLE)
	await _to_coaching()
	await _shot("coaching")
	await _stage.key(KEY_D)
	await _shot("deck_view")
	await _close_overlays()
	_unlock_all_artifacts()
	Game.new_run(33)
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	_screen()._toggle("holes")
	_screen()._toggle("exploding")
	await _shot("artifact_select")
	_screen()._continue()
	_go("M1")
	await _stage.wait(ShotStage.SETTLE)
	if await _pick_up_with_keyboard():
		await _shot("roster_keyboard_cursor", 0.4)


## On the roster: Enter on a benched collection row (else the king's row) picks the
## piece up and shows the board's square cursor on the first free deploy square.
func _pick_up_with_keyboard() -> bool:
	var rows := _screen().find_children("*", "RosterRow", true, false).filter(
		func(row: Control) -> bool: return row.is_visible_in_tree())
	if rows.is_empty():
		push_warning("Screenshot tool: no roster rows for roster_keyboard_cursor")
		return false
	var picked: Control = rows[0]
	for row: Control in rows:
		if row.piece.type != "king" and _screen()._square_of(row.piece) == BoardView.NO_SQUARE:
			picked = row
			break
	picked.grab_focus()
	await _stage.key(KEY_ENTER)
	return true


# --- Menu motion frames (base pass) ---------------------------------------------

## 6-8 frames each: the settings panel opening, map travel, a coaching Accept, the
## deck overlay opening and the run-end victory reveal (one seed-11 run, start to boss).
func _menu_frames() -> void:
	Game.show_title()
	await _stage.wait(ShotStage.SETTLE)
	await _stage.key(KEY_F1)
	await _stage.frames("settings_open", 7, 0.05, FRAMES_DIR)
	await _stage.wait(0.3)
	await _stage.key(KEY_F1)
	await _stage.wait(0.5)

	# Fresh meta, so the boss win at the end reveals the Fire unlock (not "Nothing new").
	Game.use_storage(_temp_dir + "menu_frames/meta.json", _temp_dir + "menu_frames/logs/")
	Game.new_run(11)
	Game.run.choose_piece_set("standard")
	_skip_artifacts()
	Game.show_phase()
	await _stage.wait(ShotStage.SETTLE)
	_screen()._choose("L1")  # the travel marker walks to L1 (map_travel), then the roster opens
	await _stage.frames("map_travel", 8, 0.09, FRAMES_DIR)
	await _stage.wait(ShotStage.SETTLE)

	await _to_coaching()
	var accept := _first_button("Accept")
	if accept != null:
		accept.pressed.emit()
		await _stage.frames("coaching_accept", 7, 0.06, FRAMES_DIR)
	else:
		push_warning("Screenshot tool: no affordable coaching offer for coaching_accept")
	await _stage.wait(0.5)
	await _stage.key(KEY_D)
	await _stage.frames("deck_open", 7, 0.05, FRAMES_DIR)
	await _stage.wait(0.3)
	await _close_overlays()

	Game.run.leave_coaching()
	_skip_match("L6", true)
	Game.run.choose_node("BOSS")
	Game.run.build_match_setup(Game.run.default_roster())
	Game.run.finish_match({"winner": 0, "reason": "king", "scores": [6, 2]})
	Game.show_phase()
	await _stage.frames("run_end_victory", 8, 0.35, FRAMES_DIR)


# --- Run helpers ---------------------------------------------------------------

## From the map (or L1's roster) of a fresh seed-11 run to the L5 coaching screen:
## L1 won, the L2 shop left, L3 and L4 won (6 points to spend).
func _to_coaching() -> void:
	if Game.run.current_node != "L1":
		Game.run.choose_node("L1")
	Game.run.build_match_setup(Game.run.default_roster())
	Game.run.finish_match({"winner": 0, "reason": "score", "scores": [10, 4]})
	Game.run.skip_reward()
	Game.run.choose_node("L2")
	Game.run.leave_shop()
	_skip_match("L3", false)
	_skip_match("L4", false)
	_go("L5")
	await _stage.wait(ShotStage.SETTLE)


## Answers the artifact step with no artifacts when it shows (a loss can unlock one).
func _skip_artifacts() -> void:
	if Game.run.phase_name() == "ARTIFACT_SELECT":
		Game.run.choose_artifacts([])


func _unlock_all_artifacts() -> void:
	var meta := Game.unlocks()
	for artifact_id: String in GameConfig.data("artifacts")["unlock_pool"]:
		if not meta.unlocked_artifacts.has(artifact_id):
			meta.unlocked_artifacts.append(artifact_id)
	meta.save()


## The first live, enabled Button in the current screen whose text starts with `prefix`.
func _first_button(prefix: String) -> Button:
	for node in _screen().find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(prefix) and not button.disabled and button.is_visible_in_tree():
			return button
	return null


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


## Presses the first affordable card's Buy button, like a click (the card offers
## come first in the shop's offer buttons).
func _buy_affordable_card() -> void:
	var offers: Array = Game.run.shop_offers()["cards"]
	for i in offers.size():
		if offers[i]["price"] <= Game.run.points:
			(_screen()._offer_buttons[i] as Button).pressed.emit()
			return


func _accept_first_coaching() -> void:
	var offers := Game.run.coaching_offers()
	for i in offers.size():
		if offers[i]["price"] <= Game.run.points:
			_screen()._apply(Game.run.accept_coaching(i), "Upgraded")
			_screen()._apply(Game.run.decline_coaching((i + 1) % offers.size()), "")
			return


## Frees the open item overlays and waits a frame, so the next key reaches the screen.
func _close_overlays() -> void:
	for overlay in get_tree().root.find_children("*", "ItemOverlay", true, false):
		overlay.queue_free()
	await get_tree().process_frame


# --- Files ---------------------------------------------------------------------

## Old PNGs of a generated folder go first, so a renamed shot leaves no stale file.
func _remove_pngs(dir_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for file_name in DirAccess.get_files_at(absolute):
		if file_name.ends_with(".png"):
			DirAccess.remove_absolute(absolute.path_join(file_name))


func _remove_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for sub_dir in DirAccess.get_directories_at(dir_path):
		_remove_dir(dir_path.path_join(sub_dir))
	for file_name in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)
