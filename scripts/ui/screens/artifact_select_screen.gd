extends Control
## Pick up to max_starting_artifacts of the unlocked artifacts, or none.

var _chosen: Array[String] = []
var _tiles: Dictionary = {}
var _counter: Label
var _status: Label
var _has_continued: bool = false


func _ready() -> void:
	var run := Game.run
	var body := Ui.frame(self, "New run · step 2", "Choose your artifacts",
		"Artifacts are passive and last the whole run. Pick up to %d, or none." % run.max_starting_artifacts())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for artifact in run.available_artifacts():
		grid.add_child(_artifact_tile(artifact))
	body.add_child(Ui.spacer())
	body.add_child(Ui.centered(grid))
	body.add_child(Ui.spacer())
	_status = Ui.status_label()
	body.add_child(_status)
	var footer := Ui.footer(body)
	_counter = Ui.label("", "Body")
	footer.add_child(_counter)
	var go := Ui.button("Continue to the map", "PrimaryButton")
	go.pressed.connect(_continue)
	footer.add_child(go)
	_refresh()


func _artifact_tile(artifact: Dictionary) -> SelectTile:
	var tile := SelectTile.new()
	tile.custom_minimum_size = Vector2(460, 120)
	var column := Ui.vbox(6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	column.add_child(Ui.label(artifact["name"], "H2"))
	column.add_child(Ui.wrapped(artifact["desc"], "Body", 420))
	tile.pressed.connect(_toggle.bind(artifact["id"]))
	_tiles[artifact["id"]] = tile
	return tile


func _toggle(artifact_id: String) -> void:
	if _chosen.has(artifact_id):
		_chosen.erase(artifact_id)
	elif _chosen.size() >= Game.run.max_starting_artifacts():
		Ui.shake(_tiles[artifact_id])
		Ui.flash_status(_status, "You can take at most %d artifacts. Deselect one first." % Game.run.max_starting_artifacts())
		return
	else:
		_chosen.append(artifact_id)
		Ui.pop(_tiles[artifact_id], 1.03)
	_status.text = ""
	_refresh()


func _refresh() -> void:
	for artifact_id in _tiles:
		_tiles[artifact_id].is_selected = _chosen.has(artifact_id)
	_counter.text = "%d / %d chosen" % [_chosen.size(), Game.run.max_starting_artifacts()]


func _continue() -> void:
	if _has_continued:
		return
	var result := Game.run.choose_artifacts(_chosen)
	if not result["ok"]:
		Ui.flash_status(_status, result["error"])
		return
	_has_continued = true
	Game.show_phase()
