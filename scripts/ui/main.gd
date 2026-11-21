extends Control
## Screen manager: swaps one screen at a time under the run HUD.

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

@onready var _hud: RunHud = %Hud
@onready var _screen_host: Control = %ScreenHost
@onready var _overlay_host: Control = %OverlayHost

var current_screen: Control
var current_screen_name: String = ""


func _ready() -> void:
	theme = UiTheme.build()
	Game.screen_requested.connect(show_screen)
	Game.run_changed.connect(_hud.refresh)
	_hud.deck_requested.connect(_show_deck)
	_hud.collection_requested.connect(_show_collection)
	show_screen(Game.TITLE)


func show_screen(screen_name: String) -> void:
	Ui.clear(_overlay_host)
	if current_screen != null:
		current_screen.queue_free()
	current_screen_name = screen_name
	current_screen = load(SCREENS[screen_name]).instantiate()
	_screen_host.add_child(current_screen)
	_hud.visible = HUD_SCREENS.has(screen_name)
	_hud.refresh()
	Ui.fade_in(current_screen, 0.2)


func _show_deck() -> void:
	var overlay := ItemOverlay.new()
	_overlay_host.add_child(overlay)
	overlay.show_cards("Your deck", Game.run.deck)


func _show_collection() -> void:
	var overlay := ItemOverlay.new()
	_overlay_host.add_child(overlay)
	overlay.show_pieces("Your collection", Game.run.collection)
