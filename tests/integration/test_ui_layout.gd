extends GutTest
## Layout guarantees of the menu screens through the real main scene, at normal
## size and with Large text: the map fits the window, the roster list shows whole
## rows, a shop purchase keeps the Buy buttons' width, and settings open at the
## top of their body (with no scroll at normal size).

const UiDriver := preload("res://tests/integration/ui_helpers/ui_driver.gd")

## The base canvas the checks are about (the headless window is square).
const WINDOW := Vector2i(1280, 720)

var ui: UiDriver
var _old_size: Vector2i


func before_each() -> void:
	_old_size = get_tree().root.size
	get_tree().root.size = WINDOW
	ui = UiDriver.new(self, "layout")
	await ui.start()
	assert_eq(Vector2i(_window().size), WINDOW, "laid out in a 1280x720 window")


func after_each() -> void:
	Settings.set_value("large_text", false)
	await ui.stop()
	get_tree().root.size = _old_size


## A seed-11 run on its map (three floor-1 stops, the longest side panel).
func _to_map() -> void:
	Game.new_run(11)
	Game.run.choose_piece_set("standard")
	Game.show_phase()
	assert_true(await ui.wait_screen("MAP"))


func _window() -> Rect2:
	return ui.main.get_viewport_rect()


func test_map_fits_the_window_with_large_text() -> void:
	for is_large in [false, true]:
		Settings.set_value("large_text", is_large)
		await _to_map()
		var screen: Control = ui.screen()
		var map_view: MapView = screen._map_view
		var window := _window()
		for node: Control in [map_view, map_view.get_parent()]:
			assert_true(node.get_global_rect().end.y <= window.end.y + 0.5,
				"%s ends inside the window (large text %s)" % [node.get_class(), is_large])
		var panel: Control = map_view.get_parent().get_child(1)
		assert_true(panel.get_global_rect().end.y <= window.end.y + 0.5, "the side panel fits (large text %s)" % is_large)
		for node_id: String in map_view.choices():
			var bottom := map_view.get_global_transform() * map_view.node_position(node_id)
			assert_true(bottom.y + MapView.CAPTION_DROP + 8.0 <= window.end.y, "floor-1 captions are inside the window")
		Game.run = null


func test_roster_list_shows_whole_rows_with_large_text() -> void:
	Settings.set_value("large_text", true)
	await _to_map()
	assert_true(ui.click_map_node(ui.screen()._map_view.choices()[0]))
	assert_true(await ui.wait_screen("MATCH_SETUP"))
	_assert_whole_rows(ui.screen(), true)
	for is_large in [false, true, false]:
		Settings.set_value("large_text", is_large)  # live, on this screen
		await ui.frames(3)
		_assert_whole_rows(ui.screen(), is_large)


func _assert_whole_rows(screen: Control, is_large: bool) -> void:
	var scroll: ScrollContainer = screen._list_scroll
	var rows: Array = screen._list.get_children()
	var row: Control = rows[0]
	var step: float = row.size.y + screen.LIST_GAP
	var shown: float = (scroll.size.y - screen.RING_ROOM * 2 + screen.LIST_GAP) / step
	assert_almost_eq(shown, roundf(shown), 0.05, "the list window holds whole rows (large text %s): %.2f" % [is_large, shown])
	assert_true(scroll.get_global_rect().end.y <= (scroll.get_parent() as Control).get_global_rect().end.y + 0.5, "inside its panel")


func test_shop_purchase_keeps_the_buy_buttons_width() -> void:
	for is_large in [false, true]:
		Settings.set_value("large_text", is_large)
		await _to_map()
		Game.run.choose_node("L1")
		Game.run.build_match_setup(Game.run.default_roster())
		Game.run.finish_match({"winner": 0, "reason": "score", "scores": [10, 4]})
		Game.run.skip_reward()
		Game.run.choose_node("L2")
		Game.show_phase()
		assert_true(await ui.wait_screen("SHOP"))
		var shop: Control = ui.screen()
		var before := _offer_rects(shop)
		var bought := false
		for button: Button in shop._offer_buttons:
			if not button.disabled and button.text.begins_with("Buy"):
				button.pressed.emit()
				bought = true
				break
		assert_true(bought, "an affordable offer")
		await ui.frames(3)
		var after := _offer_rects(shop)
		assert_eq(after.size(), before.size())
		for i in before.size():
			assert_eq(after[i], before[i], "offer %d keeps its place and width (large text %s)" % [i, is_large])
		Game.run = null


func _offer_rects(shop: Control) -> Array:
	return shop._offer_buttons.map(func(button: Button) -> Rect2: return button.get_global_rect())


func test_settings_open_at_the_top_without_a_scroll_at_normal_size() -> void:
	for is_large in [false, true]:
		Settings.set_value("large_text", is_large)
		ui.press_key(KEY_F1)
		await ui.frames(3)
		var panel: SettingsPanel = null
		for overlay: Node in ui.overlays():
			if overlay is SettingsPanel:
				panel = overlay
		assert_not_null(panel)
		var scroll: ScrollContainer = panel._scroll
		assert_eq(scroll.scroll_vertical, 0, "opens at the top (large text %s)" % is_large)
		if not is_large:
			assert_false(scroll.get_v_scroll_bar().visible, "no scroll at 1280x720 with normal text")
		panel.close()
		await ui.frames(10)
