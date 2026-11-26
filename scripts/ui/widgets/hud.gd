class_name RunHud
extends PanelContainer
## The run bar shown on every run screen: floor, training points, deck,
## collection, artifacts and settings. Rebuilt whenever the run changes.
## Its buttons stay out of the keyboard focus chain (Space must reach the match);
## rc_deck, rc_collection and rc_settings (D, C, F1 by default) open them from
## anywhere instead (main.gd).

signal deck_requested
signal collection_requested

var _row: HBoxContainer
var _points_label: Label
var _last_points: int = -1
var _last_run: RunSession
var _bump_tween: Tween


func _ready() -> void:
	theme_type_variation = "BarPanel"
	_row = Ui.hbox(16)
	add_child(_row)


func refresh() -> void:
	if _row == null or Game.run == null:
		return
	Ui.clear(_row)
	var run := Game.run
	var brand := Ui.label("ROGUECHESS", "Eyebrow")
	brand.add_theme_font_override("font", UiFonts.serif_bold())
	_row.add_child(_vcenter(brand))
	var floor_label := Ui.label(_floor_text(run), "Body")
	floor_label.tooltip_text = "Climb the map one floor at a time; the boss waits on floor %d." % run.map.floors()
	floor_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_row.add_child(_vcenter(floor_label))
	_row.add_child(_vcenter(Ui.artifact_chips(run.artifacts, "No artifacts")))
	_row.add_child(Ui.spacer())
	_points_label = Ui.label("%d" % run.points, "Stat", Palette.BRASS)
	var points := Ui.hbox(6)
	points.add_child(_vcenter(Ui.label("Training points", "Caption")))
	points.add_child(_vcenter(_points_label))
	points.tooltip_text = "Spend training points in shops and coaching. +%d per win." % int(GameConfig.value("economy", "win_points"))
	_row.add_child(points)
	var deck := Ui.button("Deck  %d" % run.deck.size(), "QuietButton")
	deck.tooltip_text = "View your deck and card upgrades (%s)" % A11y.key_label(&"rc_deck")
	deck.pressed.connect(deck_requested.emit)
	_row.add_child(_vcenter(deck))
	var pieces := Ui.button("Collection  %d" % run.collection.size(), "QuietButton")
	pieces.tooltip_text = "View your pieces and their upgrades (%s)" % A11y.key_label(&"rc_collection")
	pieces.pressed.connect(collection_requested.emit)
	_row.add_child(_vcenter(pieces))
	var settings := Ui.button("Settings", "QuietButton")
	settings.tooltip_text = "Volume, motion, display and controls (%s)" % A11y.key_label(&"rc_settings")
	settings.pressed.connect(Game.open_settings)
	_row.add_child(_vcenter(settings))
	# Any change of the run's points (reward, skip, shop, coaching) shows and sounds here.
	if run == _last_run and _last_points != -1 and _last_points != run.points:
		bump_points.call_deferred(run.points - _last_points)
	_last_points = run.points
	_last_run = run


## Before the first match the climber stands at the foot of the map: floor 1 is next.
func _floor_text(run: RunSession) -> String:
	var floor_number := int(run.current_node_info().get("floor", 0))
	if floor_number == 0:
		return "Floor 1 of %d · start" % run.map.floors()
	return "Floor %d of %d" % [floor_number, run.map.floors()]


func _vcenter(node: Control) -> Control:
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## The training points changed by `delta`: the figure pops and flashes green
## (gain) or oxblood (spend) back to brass, with score_tick / energy_spend.
## A spend also shows "−N pt" just under the figure (Feel.spend_float).
## With reduced motion only the colour flash and the plate's fade stay.
func bump_points(delta: int) -> void:
	if delta == 0 or not is_instance_valid(_points_label) or not is_visible_in_tree():
		return
	Sfx.play("score_tick" if delta > 0 else "energy_spend")
	Feel.pop(_points_label, 1.3)
	if delta < 0:
		# Next frame: the rebuilt bar has been laid out, so the figure's place is final.
		var place := _float_spend.bind(-delta)
		if not get_tree().process_frame.is_connected(place):
			get_tree().process_frame.connect(place, CONNECT_ONE_SHOT)
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_points_label.add_theme_color_override("font_color", Palette.FELT if delta > 0 else Palette.OXBLOOD_INK)
	var label := _points_label
	_bump_tween = label.create_tween()
	_bump_tween.tween_interval(Motion.time("hud_bump") * 0.5)
	_bump_tween.tween_callback(func() -> void: label.add_theme_color_override("font_color", Palette.BRASS))


func _float_spend(spent: int) -> void:
	if is_instance_valid(_points_label) and is_visible_in_tree():
		Feel.spend_float(self, _points_label, spent)
