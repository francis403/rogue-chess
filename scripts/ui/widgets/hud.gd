class_name RunHud
extends PanelContainer
## The run bar shown on every run screen: floor, training points, deck,
## collection and artifacts. Rebuilt whenever the run changes.

signal deck_requested
signal collection_requested

var _row: HBoxContainer
var _points_label: Label
var _last_points: int = -1


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
	_row.add_child(_vcenter(Ui.label(_floor_text(run), "Body")))
	_row.add_child(_vcenter(Ui.artifact_chips(run.artifacts, "No artifacts")))
	_row.add_child(Ui.spacer())
	_points_label = Ui.label("%d" % run.points, "Stat", Palette.BRASS)
	var points := Ui.hbox(6)
	points.add_child(_vcenter(Ui.label("Training points", "Caption")))
	points.add_child(_vcenter(_points_label))
	points.tooltip_text = "Spend training points in shops and coaching. +%d per win." % int(GameConfig.value("economy", "win_points"))
	_row.add_child(points)
	var deck := Ui.button("Deck  %d" % run.deck.size(), "QuietButton")
	deck.tooltip_text = "View your deck and card upgrades"
	deck.pressed.connect(deck_requested.emit)
	_row.add_child(_vcenter(deck))
	var pieces := Ui.button("Collection  %d" % run.collection.size(), "QuietButton")
	pieces.tooltip_text = "View your pieces and their upgrades"
	pieces.pressed.connect(collection_requested.emit)
	_row.add_child(_vcenter(pieces))
	if _last_points != -1 and _last_points != run.points:
		_pop_points.call_deferred()
	_last_points = run.points


func _floor_text(run: RunSession) -> String:
	var floor_number := int(run.current_node_info().get("floor", 0))
	if floor_number == 0:
		return "Floor 0 of %d" % run.map.floors()
	return "Floor %d of %d" % [floor_number, run.map.floors()]


func _vcenter(node: Control) -> Control:
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


func _pop_points() -> void:
	Ui.pop(_points_label, 1.3)
