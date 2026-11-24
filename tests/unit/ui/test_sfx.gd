extends GutTest
## Sfx autoload: streams, buses, voice limiting, volumes and automatic button sounds.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")
## This process's own temp folder (parallel test runs never share files).
var TMP_DIR := TestTmp.root()
var TMP_SETTINGS := TMP_DIR + "sfx_settings.json"

var _old_settings_path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_old_settings_path = Settings.path
	Settings.use_path(TMP_SETTINGS)


func after_each() -> void:
	Settings.use_path(_old_settings_path)
	DirAccess.remove_absolute(TMP_SETTINGS)


func _audio() -> Dictionary:
	return GameConfig.data("ux")["audio"]


func test_every_configured_id_is_a_loaded_stream() -> void:
	for section: String in ["sounds", "music"]:
		for id: String in _audio()[section]:
			assert_true(Sfx.has_sound(id), "%s has a stream" % id)


func test_iteration_4_sounds_load() -> void:
	for id: String in ["capture_against", "check_stay"]:
		assert_true(id in _audio()["sounds"], "%s is configured" % id)
		assert_true(Sfx.has_sound(id), "%s has a stream" % id)
	assert_eq(Sfx.variant_count("capture_against"), 3, "capture_against has 3 variants, like capture")
	assert_eq(Sfx.variant_count("check_stay"), 1, "check_stay is a single file")
	assert_eq(float(_audio()["sounds"]["check_stay"].get("pitch", -1)), 0.0, "check_stay is tonal: no pitch jitter")


func test_music_streams_loop() -> void:
	for id: String in _audio()["music"]:
		var stream := load("res://assets/audio/music/%s.wav" % id) as AudioStreamWAV
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, id)
		assert_gt(stream.loop_end, 0, id)


func test_buses_exist_and_send_to_master() -> void:
	for bus: String in ["Music", "SFX", "UI"]:
		var index := AudioServer.get_bus_index(bus)
		assert_gt(index, 0, bus)
		assert_eq(String(AudioServer.get_bus_send(index)), "Master", bus)


func test_unknown_id_does_nothing() -> void:
	assert_false(Sfx.play("no_such_sound"))
	assert_false(Sfx.play("no_such_sound"), "second call is quiet too")
	Sfx.play_music("no_such_music")
	assert_ne(Sfx.current_music(), "no_such_music")


## Waits at least `ms` of wall-clock time (GUT's wait_seconds can return early in headless
## runs, and Sfx cooldowns are measured with Time.get_ticks_msec()).
func _wait_ms(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_cooldown_suppresses_rapid_duplicates() -> void:
	await _wait_ms(80)
	assert_true(Sfx.play("piece_move"))
	assert_false(Sfx.play("piece_move"), "same id inside the cooldown is dropped")
	assert_true(Sfx.play("piece_pickup"), "other ids are not blocked")
	await _wait_ms(80)
	assert_true(Sfx.play("piece_move"), "plays again after the cooldown")


func test_voice_pool_is_bounded() -> void:
	var players := Sfx.get_children().size()
	for id: String in _audio()["sounds"]:
		Sfx.play(id)
	assert_eq(Sfx.get_children().size(), players, "voices are reused, never added")


func test_volume_mapping() -> void:
	assert_eq(Sfx.volume_to_db(0.0), -80.0)
	assert_almost_eq(Sfx.volume_to_db(1.0), 0.0, 0.001)
	assert_lt(Sfx.volume_to_db(0.5), 0.0)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	Settings.set_value("sfx_volume", 0.0)
	assert_eq(AudioServer.get_bus_volume_db(sfx_bus), -80.0)
	Settings.set_value("sfx_volume", 1.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_bus), 0.0, 0.001)
	Settings.set_value("muted", true)
	assert_true(AudioServer.is_bus_mute(0))
	Settings.set_value("muted", false)
	assert_false(AudioServer.is_bus_mute(0))


func test_buttons_get_click_sounds_with_metadata_override() -> void:
	watch_signals(Sfx)
	var plain := Button.new()
	add_child_autofree(plain)
	var silent := Button.new()
	silent.set_meta("sfx", "none")
	add_child_autofree(silent)
	var custom := Button.new()
	custom.set_meta("sfx", "ui_confirm")
	add_child_autofree(custom)
	await wait_seconds(0.08)
	silent.pressed.emit()
	assert_signal_not_emitted(Sfx, "played", "sfx = none is silent")
	plain.pressed.emit()
	assert_signal_emitted_with_parameters(Sfx, "played", ["ui_click"])
	custom.pressed.emit()
	assert_signal_emitted_with_parameters(Sfx, "played", ["ui_confirm"])


func test_disabled_button_has_no_hover_sound() -> void:
	watch_signals(Sfx)
	var button := Button.new()
	button.disabled = true
	add_child_autofree(button)
	await wait_seconds(0.08)
	button.mouse_entered.emit()
	assert_signal_not_emitted(Sfx, "played")


func test_every_bus_volume_follows_settings() -> void:
	var levels := {"master_volume": 0.3, "music_volume": 0.6, "sfx_volume": 0.15, "ui_volume": 0.9}
	for key: String in levels:
		Settings.set_value(key, levels[key])
	assert_almost_eq(AudioServer.get_bus_volume_db(0), Sfx.volume_to_db(0.3), 0.001, "Master")
	for bus: String in Sfx.BUS_SETTINGS:
		var expected := Sfx.volume_to_db(levels[Sfx.BUS_SETTINGS[bus]])
		assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)), expected, 0.001, bus)
	assert_gt(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), "louder slider, louder bus")


func test_bus_volumes_follow_a_reload() -> void:
	Settings.set_value("music_volume", 0.25)
	Settings.set_value("muted", true)
	Settings.load_from(TMP_DIR + "missing_sfx.json")  # restart: defaults first
	var music := AudioServer.get_bus_index("Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(music), Sfx.volume_to_db(float(Settings.defaults()["music_volume"])), 0.001)
	assert_eq(AudioServer.is_bus_mute(0), bool(Settings.defaults()["muted"]))
	Settings.load_from(TMP_SETTINGS)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), Sfx.volume_to_db(0.25), 0.001, "saved level reapplied")
	assert_true(AudioServer.is_bus_mute(0), "saved mute reapplied")
	Settings.set_value("muted", false)


# --- Variants, voice stealing, ducking (iteration 2) -----------------------------

const HIGH_FREQUENCY := ["piece_land_light", "piece_land_medium", "piece_land_heavy", "card_draw", "capture",
		"capture_against", "piece_move", "ui_click"]


func test_every_configured_variant_loads() -> void:
	for id: String in _audio()["sounds"]:
		var count := int(_audio()["sounds"][id].get("variants", 1))
		assert_eq(Sfx.variant_count(id), count, "%s loads all %d variants" % [id, count])
		for n in range(2, count + 1):
			var path := "res://assets/audio/sfx/%s_%d.wav" % [id, n]
			assert_true(load(path) is AudioStreamWAV, path)
	for id: String in HIGH_FREQUENCY:
		assert_gte(Sfx.variant_count(id), 3, "%s has variants" % id)


func test_variants_never_repeat_back_to_back() -> void:
	for id: String in HIGH_FREQUENCY:
		var seen := {}
		var previous := -1
		for i in 40:
			Sfx._last_played.erase(id)  # skip the cooldown: this test is about the pick
			assert_true(Sfx.play(id), id)
			var picked := Sfx.last_variant(id)
			assert_ne(picked, previous, "%s never plays the same variant twice in a row" % id)
			previous = picked
			seen[picked] = true
		assert_eq(seen.size(), Sfx.variant_count(id), "%s uses every variant" % id)
	assert_eq(Sfx.variant_count("victory"), 1, "single-file ids still play")


func test_stolen_voice_fades_out_instead_of_stopping() -> void:
	await wait_seconds(0.1)
	Sfx._ends_at.clear()  # forget sounds earlier tests left "sounding"
	var pool: Array = Sfx._pools["SFX"]
	var limit := int(_audio()["voices"]["SFX"])
	assert_gt(pool.size(), limit, "spare players exist for fading voices")
	var children := Sfx.get_children().size()
	for i in limit:
		Sfx._last_played.erase("explosion")
		assert_true(Sfx.play("explosion"))
	assert_eq(pool.filter(func(p: AudioStreamPlayer) -> bool: return Sfx.is_voice_fading(p)).size(), 0,
			"nothing is stolen while the pool has room")
	Sfx._last_played.erase("explosion")
	assert_true(Sfx.play("explosion"), "a full pool still plays the new sound")
	var fading: Array = pool.filter(func(p: AudioStreamPlayer) -> bool: return Sfx.is_voice_fading(p))
	assert_eq(fading.size(), 1, "exactly one voice is stolen")
	var busy: Array = pool.filter(func(p: AudioStreamPlayer) -> bool:
		return Sfx.is_voice_busy(p) and not Sfx.is_voice_fading(p))
	assert_eq(busy.size(), limit, "the bus keeps its voice limit")
	var stolen: AudioStreamPlayer = fading[0]
	assert_gt(stolen.volume_db, Sfx.MIN_DB + 1.0, "the stolen voice is not cut: it ramps down")
	await wait_seconds(float(_audio()["steal_fade"]) + 0.1)
	assert_false(Sfx.is_voice_fading(stolen), "the fade finished")
	assert_almost_eq(stolen.volume_db, Sfx.MIN_DB, 0.01, "faded all the way out")
	assert_eq(Sfx.get_children().size(), children, "no players were added")
	Sfx._ends_at.clear()


func test_stingers_duck_the_music_then_restore_it() -> void:
	var duck: Dictionary = _audio()["duck"]
	var music_bus := AudioServer.get_bus_index("Music")
	Settings.set_value("music_volume", 0.8)
	Sfx._duck_until = 0
	Sfx._last_played.erase("victory")
	assert_true(Sfx.play("victory"))
	await wait_seconds(float(duck["attack"]) + 0.15)
	assert_almost_eq(Sfx.music_duck_db(), float(duck["db"]), 0.25, "music dips under the stinger")
	assert_almost_eq(AudioServer.get_bus_volume_db(music_bus), Sfx.volume_to_db(0.8), 0.001,
			"the bus volume still equals the slider (the dip is a bus effect)")
	var length := (load("res://assets/audio/sfx/victory.wav") as AudioStream).get_length()
	await wait_seconds(length + float(duck["release"]) + 0.2 - float(duck["attack"]) - 0.15)
	assert_almost_eq(Sfx.music_duck_db(), 0.0, 0.01, "music comes back after the stinger")
	Sfx._last_played.erase("capture")
	Sfx.play("capture")
	await wait_seconds(0.15)
	assert_almost_eq(Sfx.music_duck_db(), 0.0, 0.01, "ordinary sounds never duck")
	for id: String in duck["ids"]:
		assert_true(_audio()["sounds"].has(id), "duck id %s is a sound" % id)


func test_release_all_drops_every_stream_so_quitting_leaks_nothing() -> void:
	Sfx.play_music("music_menu")
	Sfx._last_played.erase("capture")
	assert_true(Sfx.play("capture"))
	var holding := Sfx.get_children().filter(func(p: Node) -> bool: return p is AudioStreamPlayer and p.stream != null)
	assert_gt(holding.size(), 0, "players hold streams while sounding")
	Sfx.release_all()
	for player: Node in Sfx.get_children():
		if player is AudioStreamPlayer:
			assert_null((player as AudioStreamPlayer).stream, "%s let go of its stream" % player.name)
			assert_false((player as AudioStreamPlayer).playing)
	assert_eq(Sfx.current_music(), "", "music is stopped")
	assert_false(get_tree().auto_accept_quit, "closing the window goes through Sfx.quit() (audio freed first)")
	Sfx._last_played.erase("capture")
	assert_true(Sfx.play("capture"), "Sfx still works after a release")


# --- Stinger exclusivity, hover decoupling (iteration 3) --------------------------

func _fresh_stingers() -> void:
	Sfx.release_all()
	Sfx._duck_until = 0
	for id: String in _audio()["stingers"]["ids"]:
		Sfx._last_played.erase(id)


var _heard: Array[String] = []


func _record(id: String) -> void:
	_heard.append(id)


func _listen() -> void:
	_heard.clear()
	if not Sfx.played.is_connected(_record):
		Sfx.played.connect(_record)


func after_all() -> void:
	if Sfx.played.is_connected(_record):
		Sfx.played.disconnect(_record)


func _length(id: String) -> float:
	return (load("res://assets/audio/sfx/%s.wav" % id) as AudioStream).get_length()


func test_stinger_ids_are_sounds_and_ducked() -> void:
	var spec: Dictionary = _audio()["stingers"]
	for id: String in spec["ids"]:
		assert_true(_audio()["sounds"].has(id), "stinger %s is a sound" % id)
		assert_true(id in _audio()["duck"]["ids"], "stinger %s ducks the music" % id)
		assert_true(Sfx.is_stinger(id))
	assert_false(Sfx.is_stinger("capture"))
	assert_true("unlock_fanfare" in spec["wait"])


func test_new_stinger_fades_out_the_previous_one() -> void:
	_fresh_stingers()
	assert_eq(Sfx.stinger_time_left(), 0.0, "no stinger yet")
	assert_true(Sfx.play("victory", false))
	var first: AudioStreamPlayer = Sfx._stinger_player
	assert_almost_eq(Sfx.stinger_time_left(), _length("victory"), 0.1)
	assert_true(Sfx.play("run_victory", false), "a different stinger cuts in")
	assert_true(Sfx.is_voice_fading(first), "the previous stinger fades out")
	assert_ne(Sfx._stinger_player, first, "the new one plays on another voice")
	assert_almost_eq(Sfx.stinger_time_left(), _length("run_victory"), 0.1, "only the new stinger counts")
	assert_gt(first.volume_db, Sfx.MIN_DB + 1.0, "faded, not cut")
	await _wait_ms(int(1000.0 * float(_audio()["stingers"]["fade"])) + 100)
	assert_false(Sfx.is_voice_fading(first), "the fade finished")
	assert_almost_eq(first.volume_db, Sfx.MIN_DB, 0.01)
	assert_almost_eq(Sfx.music_duck_db(), float(_audio()["duck"]["db"]), 0.25, "music stays ducked under the new stinger")
	Sfx.release_all()


func test_duck_follows_a_shorter_replacing_stinger() -> void:
	_fresh_stingers()
	assert_true(Sfx.play("run_victory", false))
	assert_true(Sfx.play("defeat", false))
	var expected := Time.get_ticks_msec() + int(1000.0 * _length("defeat"))
	assert_almost_eq(float(Sfx._duck_until), float(expected), 60.0,
			"the dip ends with the new stinger, not the replaced longer one")
	Sfx.stop_stinger()
	assert_eq(Sfx.stinger_time_left(), 0.0, "stop_stinger leaves nothing sounding")
	assert_lte(Sfx._duck_until, Time.get_ticks_msec() + int(1000.0 * float(_audio()["stingers"]["fade"])) + 20,
			"the dip releases with the fade")
	Sfx.release_all()


func test_unlock_fanfare_waits_for_the_run_stinger() -> void:
	_fresh_stingers()
	_listen()
	assert_true(Sfx.play("run_defeat", false))
	var run: AudioStreamPlayer = Sfx._stinger_player
	# Pretend the run stinger has 0.25 s left, so the test needn't wait 3.8 s.
	var ends := Time.get_ticks_msec() + 250
	Sfx._ends_at[run] = ends
	Sfx._stinger_end = ends
	Sfx._stinger_busy_until = ends
	assert_true(Sfx.play("unlock_fanfare", false), "accepted (queued)")
	assert_false("unlock_fanfare" in _heard, "not started yet")
	assert_false(Sfx.is_voice_fading(run), "the run stinger is not cut")
	assert_almost_eq(Sfx.stinger_time_left(), 0.25 + _length("unlock_fanfare"), 0.1, "time left covers the queue")
	await _wait_ms(400)
	assert_true("unlock_fanfare" in _heard, "starts when the run stinger ends")
	assert_between(Sfx.stinger_time_left(), _length("unlock_fanfare") - 0.6, _length("unlock_fanfare") - 0.05,
			"time left is now the fanfare's")
	Sfx.release_all()


func test_a_cutting_stinger_drops_the_queued_fanfare() -> void:
	_fresh_stingers()
	_listen()
	assert_true(Sfx.play("victory", false))
	var ends := Time.get_ticks_msec() + 200
	Sfx._ends_at[Sfx._stinger_player] = ends
	Sfx._stinger_end = ends
	assert_true(Sfx.play("unlock_fanfare", false))
	Sfx.stop_stinger()
	await _wait_ms(350)
	assert_false("unlock_fanfare" in _heard, "stop_stinger cancels the queue")
	Sfx.release_all()


func test_hover_is_independent_of_the_press_override() -> void:
	watch_signals(Sfx)
	var silent_press := Button.new()
	silent_press.set_meta("sfx", "none")
	add_child_autofree(silent_press)
	var silent_hover := Button.new()
	silent_hover.set_meta("sfx_hover", "none")
	add_child_autofree(silent_hover)
	await wait_seconds(0.08)
	Sfx._last_played.erase("ui_hover")
	silent_hover.mouse_entered.emit()
	assert_signal_not_emitted(Sfx, "played", "sfx_hover = none silences the hover")
	silent_press.mouse_entered.emit()
	assert_signal_emitted_with_parameters(Sfx, "played", ["ui_hover"])  # sfx = none still ticks on hover
	Sfx._last_played.erase("ui_click")
	silent_hover.pressed.emit()
	assert_signal_emitted_with_parameters(Sfx, "played", ["ui_click"])  # sfx_hover = none keeps the press
