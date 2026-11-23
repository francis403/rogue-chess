extends Node
## Autoload "Sfx": every sound effect and music loop.
##
##   Sfx.play("capture")              # SFX bus; ids starting with "ui_" go to the UI bus
##   Sfx.play("victory", false)       # false = no random pitch/volume variation
##   Sfx.play_music("music_match")    # cross-fades to that loop; no-op if it is already playing
##   Sfx.stop_music()
##   Sfx.stinger_time_left()          # seconds until the playing (and queued) stingers end
##   Sfx.stop_stinger()               # fades out the stinger and drops any queued one
##   Sfx.quit()                       # use instead of get_tree().quit(): frees audio first (no leak)
##
## Sound ids, base volume (dB), pitch variation and cooldowns live in config/ux.json "audio".
## The files are synthesized by tools/audio/generate.py into assets/audio/. An unknown id
## warns once and does nothing. Ids with "variants": N have N files (<id>.wav, <id>_2.wav, ...)
## and each play picks one at random, never the same one twice in a row. Voices are limited
## per bus: when the pool is full the oldest voice is stolen, faded out over "steal_fade"
## seconds (never cut, which would click). The same id never plays twice within its cooldown.
## Stingers listed in "duck.ids" dip the music bus a few dB for their length, then restore it.
## Stingers ("stingers.ids") are exclusive: a new one fades out the one still sounding over
## "stingers.fade" seconds, and the music dip follows the new one. Ids in "stingers.wait"
## (unlock_fanfare) don't cut in: they are queued and start when the playing stinger ends.
## Volumes follow Settings (master/music/sfx/ui volume, muted) live.
##
## Automatic button sounds: every BaseButton entering the tree plays "ui_hover" on
## mouse_entered (unless disabled) and "ui_click" on pressed ("ui_toggle" for toggle buttons).
## Override per button with metadata, read when the sound plays (set it any time). "sfx"
## controls only the press, "sfx_hover" only the hover:
##   button.set_meta("sfx", "none")         # no press sound (the screen plays a result sound); hover still ticks
##   button.set_meta("sfx", "ui_confirm")   # another press sound (any id)
##   button.set_meta("sfx_hover", "none")   # no hover sound (or another id)

signal played(id: String)

const MIN_DB := -80.0
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const BUS_SETTINGS := {"Music": "music_volume", "SFX": "sfx_volume", "UI": "ui_volume"}
const HOOKED_META := &"_sfx_hooked"
## Time quit() gives the audio thread to finish fading out stopped playbacks.
const QUIT_RELEASE_SECONDS := 0.06

var _config: Dictionary
var _streams: Dictionary = {}          # id -> AudioStream (sounds and music; a sound's first variant)
var _variants: Dictionary = {}         # sound id -> Array of AudioStream (index 0 = <id>.wav)
var _last_variant: Dictionary = {}     # sound id -> index of the variant played last
var _pools: Dictionary = {}            # bus name -> Array of AudioStreamPlayer (voices + spares)
var _started_at: Dictionary = {}       # AudioStreamPlayer -> msec it started
var _ends_at: Dictionary = {}          # AudioStreamPlayer -> msec its sound ends
var _fades: Dictionary = {}            # AudioStreamPlayer -> Tween fading a stolen voice out
var _last_played: Dictionary = {}      # id -> msec
var _warned: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_id := ""
var _music_tween: Tween
var _duck: AudioEffectAmplify          # on the Music bus; its volume_db is the stinger dip
var _duck_tween: Tween
var _duck_until := 0                   # msec the current dip starts to release
var _is_quitting := false
var _stinger_player: AudioStreamPlayer  # voice of the last stinger started
var _stinger_end := 0                  # msec that stinger ends (its _ends_at entry)
var _stinger_busy_until := 0           # msec the playing and queued stingers have all ended
var _stinger_queue_gen := 0            # bumped to cancel a queued stinger
## Headless runs (tests, tools) do all the bookkeeping but start no playback: nobody listens,
## and the dummy driver never releases playing streams (leak warnings at exit).
var _is_silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = GameConfig.data("ux")["audio"]
	for id: String in _config["sounds"]:
		_load_sound(id, int(_config["sounds"][id].get("variants", 1)))
	for id: String in _config["music"]:
		_load(id, MUSIC_DIR, true)
	for bus: String in _config["voices"]:
		_pools[bus] = []
		for i in int(_config["voices"][bus]) + int(_config.get("steal_spares", 2)):
			_pools[bus].append(_new_player(bus))
	for i in 2:
		_music_players.append(_new_player("Music"))
	_add_duck_effect()
	Settings.changed.connect(func(_key: String) -> void: apply_volumes())
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)
	get_tree().auto_accept_quit = false  # the close request goes through quit() (see below)


## Quitting while a voice or the music loop is playing leaked its AudioStreamPlayback and
## the music_menu stream ("1 resources still in use at exit"): stop() only marks a playback
## for deletion, and the AudioServer frees it on a later main-loop iteration, which never
## comes when quit() runs in the same frame. So closing the window goes through quit(), and
## code that ends the game should call Sfx.quit() instead of get_tree().quit().
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()
	elif what == NOTIFICATION_EXIT_TREE:
		release_all()  # best effort for quits that skipped Sfx.quit()


## Stops all audio, lets the AudioServer free the playbacks (a few frames, ~0.1 s), then quits.
func quit(exit_code := 0) -> void:
	if _is_quitting:
		return
	_is_quitting = true
	release_all()
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(QUIT_RELEASE_SECONDS, true, false, true).timeout
	get_tree().quit(exit_code)


## Stops every voice and the music, drops all stream references and tweens. Sfx stays usable:
## the next play()/play_music() sets a stream again.
func release_all() -> void:
	for tween: Tween in [_music_tween, _duck_tween] + _fades.values():
		if tween != null:
			tween.kill()
	_fades.clear()
	_ends_at.clear()
	_stinger_player = null
	_stinger_busy_until = 0
	_stinger_queue_gen += 1
	_music_id = ""
	for player: AudioStreamPlayer in _all_players():
		player.stop()
		player.stream = null


func _all_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_music_players)
	for bus: String in _pools:
		for player: AudioStreamPlayer in _pools[bus]:
			players.append(player)
	return players


## Plays a one-shot. Returns true if a voice started, or a waiting stinger was queued
## (false: unknown id or still in cooldown).
func play(id: String, pitch_jitter := true) -> bool:
	if not _config["sounds"].has(id) or not _streams.has(id):
		_warn_unknown(id)
		return false
	var spec: Dictionary = _config["sounds"][id]
	var now := Time.get_ticks_msec()
	if _last_played.has(id) and now - int(_last_played[id]) < int(spec.get("cooldown_ms", _config["cooldown_ms"])):
		return false
	_last_played[id] = now
	if is_stinger(id):
		if id in _stinger_spec().get("wait", []) and _stinger_sounding(now):
			_queue_stinger(id, pitch_jitter, now)
			return true
		_stinger_queue_gen += 1  # a stinger that cuts in replaces any queued one too
		_fade_stinger(now)
	_start(id, spec, pitch_jitter, now)
	return true


## True for the exclusive stinger ids (config/ux.json "audio.stingers.ids").
func is_stinger(id: String) -> bool:
	return id in _stinger_spec().get("ids", [])


## Seconds until the stinger now sounding, and any stinger queued behind it, have ended
## (0 when none is). A fading (replaced) stinger doesn't count.
func stinger_time_left() -> float:
	var now := Time.get_ticks_msec()
	if not _stinger_sounding(now) and _stinger_busy_until <= now:
		return 0.0
	return maxf(0.0, (_stinger_busy_until - now) / 1000.0)


## Fades out the stinger still sounding (over stingers.fade) and drops a queued one.
func stop_stinger() -> void:
	_stinger_queue_gen += 1
	_fade_stinger(Time.get_ticks_msec())
	_stinger_busy_until = 0


func _start(id: String, spec: Dictionary, pitch_jitter: bool, now: int) -> void:
	var player := _voice("UI" if id.begins_with("ui_") else "SFX")
	var pitch := float(spec.get("pitch", _config["pitch_jitter"])) if pitch_jitter else 0.0
	var wobble := float(_config["volume_jitter_db"]) if pitch_jitter else 0.0
	var stream: AudioStream = _variants[id][_pick_variant(id)]
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch, pitch)
	player.volume_db = float(spec.get("db", 0.0)) + randf_range(-wobble, wobble)
	if not _is_silent:
		player.play()
	_started_at[player] = now
	_ends_at[player] = now + int(1000.0 * stream.get_length() / player.pitch_scale)
	if is_stinger(id):
		_stinger_player = player
		_stinger_end = int(_ends_at[player])
		_stinger_busy_until = maxi(_stinger_busy_until, _stinger_end)
	var duck_ids: Array = _config.get("duck", {}).get("ids", [])
	if id in duck_ids:
		duck_music(stream.get_length())
	played.emit(id)


func _stinger_spec() -> Dictionary:
	return _config.get("stingers", {})


## True while the last stinger started is still sounding on its own voice (not fading,
## not stolen and reused by another sound).
func _stinger_sounding(now: int) -> bool:
	return _stinger_player != null and not _fades.has(_stinger_player) \
			and int(_ends_at.get(_stinger_player, -1)) == _stinger_end and is_voice_busy(_stinger_player, now)


## Fades the sounding stinger out; the music dip then follows only the next stinger.
func _fade_stinger(now: int) -> void:
	if not _stinger_sounding(now):
		return
	var seconds := float(_stinger_spec().get("fade", 0.3))
	_release(_stinger_player, seconds)
	_stinger_busy_until = now
	if _duck_until > now:  # release the dip with the fade, unless a new stinger re-ducks it
		_duck_until = now
		duck_music(seconds)


## Starts `id` when the playing stinger ends (stinger_time_left() covers it from now on).
func _queue_stinger(id: String, pitch_jitter: bool, now: int) -> void:
	_stinger_queue_gen += 1
	var gen := _stinger_queue_gen
	var start_at := maxi(_stinger_end, now)
	var length := int(1000.0 * (_streams[id] as AudioStream).get_length())
	_stinger_busy_until = maxi(_stinger_busy_until, start_at + length)
	var timer := get_tree().create_timer((start_at - now) / 1000.0, true, false, true)
	timer.timeout.connect(func() -> void:
		if gen != _stinger_queue_gen:
			return
		var t := Time.get_ticks_msec()
		_last_played[id] = t
		_fade_stinger(t)
		_start(id, _config["sounds"][id], pitch_jitter, t))


## Dips the Music bus by audio.duck.db for `seconds` (plus attack/release), then restores it.
## Overlapping calls extend the dip to the later end. Stingers call this automatically.
func duck_music(seconds: float) -> void:
	if _duck == null:
		return
	var spec: Dictionary = _config.get("duck", {})
	var attack := float(spec.get("attack", 0.12))
	var now := Time.get_ticks_msec()
	_duck_until = maxi(_duck_until, now + int(1000.0 * maxf(seconds, attack)))
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_duck, "volume_db", float(spec.get("db", -5.0)), attack)
	_duck_tween.tween_interval(maxf(0.0, (_duck_until - now) / 1000.0 - attack))
	_duck_tween.tween_property(_duck, "volume_db", 0.0, float(spec.get("release", 0.9)))


## Current stinger dip on the Music bus in dB (0 = not ducked).
func music_duck_db() -> float:
	return _duck.volume_db if _duck != null else 0.0


## Number of files (variants) loaded for a sound id (0 if unknown).
func variant_count(id: String) -> int:
	return _variants.get(id, []).size()


## Index of the variant the last play(id) used (-1 before the first play).
func last_variant(id: String) -> int:
	return int(_last_variant.get(id, -1))


## Cross-fades to a music loop (config/ux.json "audio.music"). No-op if it is already playing.
func play_music(id: String) -> void:
	if id == _music_id:
		return
	if not _config["music"].has(id) or not _streams.has(id):
		_warn_unknown(id)
		return
	_music_id = id
	var old := _music_players[0]
	var player := _music_players[1]
	_music_players.reverse()
	player.stream = _streams[id]
	player.volume_db = MIN_DB / 2.0
	if not _is_silent:
		player.play()
	_fade_music([player], float(_config["music"][id].get("db", 0.0)), [old])


func stop_music() -> void:
	_music_id = ""
	_fade_music([], 0.0, _music_players)


func current_music() -> String:
	return _music_id


func has_sound(id: String) -> bool:
	return _streams.get(id) != null


## Linear slider value (0..1) to bus dB: 0 is silent (-80 dB), 1 is 0 dB.
static func volume_to_db(linear: float) -> float:
	return MIN_DB if linear <= 0.0001 else maxf(linear_to_db(linear), MIN_DB)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, volume_to_db(float(Settings.get_value("master_volume"))))
	AudioServer.set_bus_mute(0, bool(Settings.get_value("muted")))
	for bus: String in BUS_SETTINGS:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, volume_to_db(float(Settings.get_value(BUS_SETTINGS[bus]))))


# --- Internals ------------------------------------------------------------------

## Loads <id>.wav, <id>_2.wav ... <id>_<count>.wav; the id plays only if the first one exists.
func _load_sound(id: String, count: int) -> void:
	var files: Array = []
	for n in range(1, count + 1):
		var stream := _load_file(SFX_DIR + id + ("" if n == 1 else "_%d" % n) + ".wav")
		if stream != null:
			files.append(stream)
	if not files.is_empty():
		_variants[id] = files
		_streams[id] = files[0]


func _load(id: String, dir: String, loop: bool) -> void:
	var stream := _load_file(dir + id + ".wav")
	if stream == null:
		return
	var wav := stream as AudioStreamWAV
	if loop and wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	_streams[id] = stream


func _load_file(path: String) -> AudioStream:
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Sfx: missing sound file " + path)
	return stream


## A random variant index, never the one played last (unless there is only one).
func _pick_variant(id: String) -> int:
	var count: int = _variants[id].size()
	var pick := 0
	if count > 1:
		var last := int(_last_variant.get(id, -1))
		if last < 0:
			pick = randi() % count
		else:
			pick = randi() % (count - 1)
			if pick >= last:
				pick += 1
	_last_variant[id] = pick
	return pick


## An AudioEffectAmplify appended to the Music bus: ducking moves it, so the bus volume
## itself always equals the player's music slider.
func _add_duck_effect() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	_duck = AudioEffectAmplify.new()
	_duck.resource_name = "StingerDuck"
	AudioServer.add_bus_effect(bus, _duck)


func _new_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	add_child(player)
	return player


## A free player of the bus. When the bus already has its "voices" sounding, the oldest one
## is stolen: it fades out over steal_fade seconds (a hard stop() mid-sample clicks) while
## the new sound starts on one of the spare players.
func _voice(bus: String) -> AudioStreamPlayer:
	var now := Time.get_ticks_msec()
	var sounding := 0
	var oldest: AudioStreamPlayer = null
	var free: AudioStreamPlayer = null
	for player: AudioStreamPlayer in _pools[bus]:
		if _fades.has(player):
			continue
		if is_voice_busy(player, now):
			sounding += 1
			if oldest == null or int(_started_at.get(player, 0)) < int(_started_at.get(oldest, 0)):
				oldest = player
		elif free == null:
			free = player
	if oldest != null and sounding >= int(_config["voices"][bus]):
		_release(oldest, float(_config.get("steal_fade", 0.015)))
	if free == null:  # every spare is still fading: reuse the one that started fading first
		free = _fades.keys()[0] as AudioStreamPlayer
		_fades[free].kill()
		_fades.erase(free)
		free.stop()
	return free


## True while the player's sound is still sounding (by its length; headless runs never play).
func is_voice_busy(player: AudioStreamPlayer, now := Time.get_ticks_msec()) -> bool:
	return now < int(_ends_at.get(player, 0)) and (_is_silent or player.playing)


## True while a stolen voice is fading out.
func is_voice_fading(player: AudioStreamPlayer) -> bool:
	return _fades.has(player)


## Fades a voice out over `seconds`, then stops it (a hard stop() mid-sample clicks).
func _release(player: AudioStreamPlayer, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", MIN_DB, seconds)
	tween.tween_callback(func() -> void:
		player.stop()
		_fades.erase(player)
		_ends_at.erase(player))
	_fades[player] = tween


func _fade_music(fade_in: Array, target_db: float, fade_out: Array) -> void:
	if _music_tween != null:
		_music_tween.kill()
	var seconds := float(_config["music_fade"])
	_music_tween = create_tween().set_parallel()
	for player: AudioStreamPlayer in fade_in:
		_music_tween.tween_property(player, "volume_db", target_db, seconds)
	for player: AudioStreamPlayer in fade_out:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", MIN_DB / 2.0, seconds)
	_music_tween.chain().tween_callback(func() -> void:
		for player: AudioStreamPlayer in fade_out:
			player.stop())


func _warn_unknown(id: String) -> void:
	if not _warned.has(id):
		_warned[id] = true
		push_warning("Sfx: unknown sound id '%s'" % id)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(HOOKED_META):
		return
	button.set_meta(HOOKED_META, true)
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


## Only "sfx_hover" can silence the hover: "sfx" = "none" mutes the press alone, so
## result-driven buttons (Buy, Accept, Skip, Close ...) still tick like every other one.
func _on_button_hovered(button: BaseButton) -> void:
	if button.disabled:
		return
	var id: String = button.get_meta("sfx_hover", "ui_hover")
	if id != "none":
		play(id)


func _on_button_pressed(button: BaseButton) -> void:
	var id: String = button.get_meta("sfx", "ui_toggle" if button.toggle_mode else "ui_click")
	if id != "none":
		play(id)
