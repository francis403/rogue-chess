extends Control
## Screen manager: swaps one screen at a time under the run HUD, picks the music,
## and owns the global keys (rc_settings F1, Esc settings outside the match,
## rc_deck D, rc_collection C; remappable, see Settings).

const SCREENS := {
	"TITLE": "res://scenes/screens/title_screen.tscn",
	"SET_SELECT": "res://scenes/screens/set_select_screen.tscn",
	"ARTIFACT_SELECT": "res://scenes/screens/artifact_select_screen.tscn",
	"MAP": "res://scenes/screens/map_screen.tscn",
	"MATCH_SETUP": "res://scenes/screens/roster_screen.tscn",
	"MATCH": "res://scenes/screens/match_screen.tscn",
	"REWARD": "res://scenes/screens/reward_screen.tscn",
	"SHOP": "res://scenes/screens/shop_screen.tscn",
	"COACHING": "res://scenes/screens/coaching_screen.tscn",
	"RUN_END": "res://scenes/screens/run_end_screen.tscn",
}
const HUD_SCREENS := ["MAP", "MATCH_SETUP", "MATCH", "REWARD", "SHOP", "COACHING"]
## The match uses Esc to cancel a selection, so Esc never opens settings there.
const ESC_OWNERS := ["MATCH"]
## Keys that move keyboard focus; a focus change right after one ticks softly.
const NAV_ACTIONS := [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_focus_next", &"ui_focus_prev"]
## A focus change this soon after a navigation key counts as caused by it.
const NAV_WINDOW_MSEC := 120

@onready var _hud: RunHud = %Hud
@onready var _screen_host: Control = %ScreenHost
@onready var _overlay_host: Control = %OverlayHost

var current_screen: Control
var current_screen_name: String = ""
var _entrance: Tween
var _nav_key_msec: int = -100000


func _ready() -> void:
	theme = UiTheme.build(Settings.get_value("large_text"))
	# Large text rebuilds the theme; every screen and overlay inherits it.
	Settings.changed.connect(func(key: String) -> void:
		if key == "large_text":
			theme = UiTheme.build(Settings.get_value("large_text")))
	Game.screen_requested.connect(show_screen)
	Game.run_changed.connect(_hud.refresh)
	Game.settings_requested.connect(open_settings)
	_hud.deck_requested.connect(_show_deck)
	_hud.collection_requested.connect(_show_collection)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	show_screen(Game.TITLE)


func show_screen(screen_name: String) -> void:
	Ui.clear(_overlay_host)
	if current_screen != null:
		current_screen.queue_free()
		Sfx.play("screen_transition")
	_play_music(screen_name)
	current_screen_name = screen_name
	current_screen = load(SCREENS[screen_name]).instantiate()
	_screen_host.add_child(current_screen)
	_hud.visible = HUD_SCREENS.has(screen_name)
	_hud.refresh()
	_play_entrance(current_screen)


## Match music in the match, the lounge loop everywhere else. The run end screen
## silences it for its stinger and brings the lounge loop back itself.
func _play_music(screen_name: String) -> void:
	if screen_name == "RUN_END":
		Sfx.stop_music()
	else:
		Sfx.play_music("music_match" if screen_name == "MATCH" else "music_menu")


## The new screen fades up and settles a few pixels into place (fade only with
## reduced motion). The old screen is already gone, so input is never delayed
## and no stale buttons stay pressable.
func _play_entrance(screen: Control) -> void:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	var duration := Motion.time("screen_transition")
	screen.modulate.a = 0.0
	_entrance = screen.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_entrance.tween_property(screen, "modulate:a", 1.0, duration)
	if not Motion.reduced():
		screen.position.y = Metrics.TRANSITION_SLIDE
		_entrance.tween_property(screen, "position:y", 0.0, duration)


## Notes when a navigation key goes down, before any control handles it.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		for action: StringName in NAV_ACTIONS:
			if event.is_action(action):
				_nav_key_msec = Time.get_ticks_msec()
				return


## Keyboard focus moving between menu controls gets the quiet hover tick (the
## same one the mouse gets on hover). Only when a navigation key moved it, not a
## screen focusing its first control or a click; Sfx's 60 ms cooldown rate-limits
## held keys.
func _on_focus_changed(_control: Control) -> void:
	if Time.get_ticks_msec() - _nav_key_msec <= NAV_WINDOW_MSEC:
		Sfx.play("ui_hover")


## F1 runs before any screen or overlay sees the key, so it works everywhere.
func _shortcut_input(event: InputEvent) -> void:
	if A11y.is_action(event, &"rc_settings"):
		get_viewport().set_input_as_handled()
		toggle_settings()


## Reached only by keys no focused control, overlay or screen used.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not ESC_OWNERS.has(current_screen_name) and not overlay_open():
		get_viewport().set_input_as_handled()
		open_settings()
	elif _hud.visible and not overlay_open() and Game.run != null:
		if A11y.is_action(event, &"rc_deck"):
			get_viewport().set_input_as_handled()
			_show_deck()
		elif A11y.is_action(event, &"rc_collection"):
			get_viewport().set_input_as_handled()
			_show_collection()


## True while the settings panel or a deck / collection overlay is open.
func overlay_open() -> bool:
	return A11y.is_modal_open(self)


func settings_panel() -> SettingsPanel:
	for child in _overlay_host.get_children():
		if child is SettingsPanel and not child.is_queued_for_deletion():
			return child
	return null


func open_settings() -> void:
	if settings_panel() == null:
		_overlay_host.add_child(SettingsPanel.new())


func toggle_settings() -> void:
	var panel := settings_panel()
	if panel != null:
		panel.close()
	else:
		open_settings()


func _show_deck() -> void:
	var overlay := ItemOverlay.new()
	_overlay_host.add_child(overlay)
	overlay.show_cards("Your deck", Game.run.deck)


func _show_collection() -> void:
	var overlay := ItemOverlay.new()
	_overlay_host.add_child(overlay)
	overlay.show_pieces("Your collection", Game.run.collection)
