extends Control
## Pick up to max_starting_artifacts of the unlocked artifacts, or none.
## Keyboard: arrows / Tab move, Enter or 1-9 toggles an artifact.

var _chosen: Array[String] = []
var _tiles: Dictionary = {}
var _marks: Dictionary = {}
var _emblems: Dictionary = {}
var _counter: Label
var _status: Label
var _has_continued: bool = false
var _order: Array[String] = []


func _ready() -> void:
	var run := Game.run
	var body := Ui.frame(self, "New run · step 2", "Choose your artifacts",
		"Artifacts are passive and last the whole run. Pick up to %d, or none." % run.max_starting_artifacts())
	# One wide row per artifact (no half-empty tiles); two columns only past ARTIFACT_LIST_MAX.
	var grid := GridContainer.new()
	grid.columns = 1 if run.available_artifacts().size() <= Metrics.ARTIFACT_LIST_MAX else 2
	grid.add_theme_constant_override("h_separation", Metrics.L)
	grid.add_theme_constant_override("v_separation", Metrics.M)
	for artifact in run.available_artifacts():
		grid.add_child(_artifact_tile(artifact))
	# Tiles, status, the counter and Continue sit together in the middle.
	var block := Ui.centre_block(body)
	block.add_child(Ui.centered(grid))
	_status = Ui.status_label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(_status)
	var actions := Ui.actions(block)
	_counter = Ui.label("", "Body")
	actions.add_child(_counter)
	var go := Ui.button("Continue to the map", "PrimaryButton")
	go.set_meta("sfx", "none")
	go.pressed.connect(_continue)
	actions.add_child(go)
	_refresh()
	A11y.focus_all(self)
	A11y.focus_first([_tiles.get(_order[0]) if not _order.is_empty() else null, go])


func _unhandled_input(event: InputEvent) -> void:
	var index := A11y.number_key(event)
	if index >= 0 and index < _order.size():
		get_viewport().set_input_as_handled()
		_toggle(_order[index])


## Emblem | name, rule | number key. Chosen: tinted face, brass border, filled
## "CHOSEN" chip pinned to the tile's top-right corner (the same place on every
## tile) and a lit emblem (a sunk emblem when not chosen).
func _artifact_tile(artifact: Dictionary) -> SelectTile:
	var index := _order.size()
	var tile := SelectTile.new()
	tile.custom_minimum_size = Metrics.ARTIFACT_TILE
	tile.padding = Metrics.L
	var row := Ui.hbox(Metrics.L)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)
	var emblem := ArtifactEmblem.create(artifact["id"])
	row.add_child(emblem)
	_emblems[artifact["id"]] = emblem
	var column := Ui.vbox(Metrics.XS)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	column.add_child(Ui.label(artifact["name"], "H2"))
	column.add_child(Ui.wrapped(artifact["desc"], "Body", Metrics.ARTIFACT_TILE.x - Metrics.EMBLEM - Metrics.CHIP_COLUMN - Metrics.XXXL - Metrics.L))
	# The right edge: room for the chip (top) and the key cap (bottom).
	var edge := Control.new()
	edge.custom_minimum_size.x = Metrics.CHIP_COLUMN - Metrics.XXXL
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(edge)
	var key := Ui.key_cap(str(index + 1))
	key.size_flags_horizontal = Control.SIZE_SHRINK_END
	key.size_flags_vertical = Control.SIZE_SHRINK_END
	tile.add_child(key)
	# Chosen is said in words too, not only by the brass border. A direct child of
	# the tile, so the container pins it top-right whatever the text length.
	var mark := _chosen_chip()
	mark.size_flags_horizontal = Control.SIZE_SHRINK_END
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.add_child(mark)
	_marks[artifact["id"]] = mark
	tile.tooltip_text = "%s\nPassive for the whole run. Enter, click or %d to choose." % [artifact["desc"], index + 1]
	tile.pressed.connect(_toggle.bind(artifact["id"]))
	_tiles[artifact["id"]] = tile
	_order.append(artifact["id"])
	return tile


func _toggle(artifact_id: String) -> void:
	if _chosen.has(artifact_id):
		_chosen.erase(artifact_id)
		Sfx.play("ui_toggle")
	elif _chosen.size() >= Game.run.max_starting_artifacts():
		Feel.refuse(_tiles[artifact_id], _status, "You can take at most %d artifacts. Deselect one first." % Game.run.max_starting_artifacts())
		return
	else:
		_chosen.append(artifact_id)
		Sfx.play("ui_toggle")
		Feel.pop(_tiles[artifact_id], 1.03)
	_status.text = ""
	_refresh()


## A filled brass chip with dark ink (not the outlined chips used for info).
func _chosen_chip() -> PanelContainer:
	var chip := Ui.panel()
	chip.add_theme_stylebox_override("panel", UiTheme.box(Palette.BRASS, Color.TRANSPARENT, UiTheme.RADIUS_SMALL, 0))
	var style: StyleBoxFlat = chip.get_theme_stylebox("panel")
	style.content_margin_left = Metrics.S
	style.content_margin_right = Metrics.S
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_child(Ui.label("CHOSEN", "Caption", Palette.BRASS_INK))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


func _refresh() -> void:
	for artifact_id in _tiles:
		_tiles[artifact_id].is_selected = _chosen.has(artifact_id)
		_marks[artifact_id].modulate.a = 1.0 if _chosen.has(artifact_id) else 0.0
		_emblems[artifact_id].is_dim = not _chosen.has(artifact_id)
	_counter.text = "%d / %d chosen" % [_chosen.size(), Game.run.max_starting_artifacts()]


func _continue() -> void:
	if _has_continued:
		return
	var result := Game.run.choose_artifacts(_chosen)
	if not result["ok"]:
		Feel.refuse(null, _status, result["error"])
		return
	_has_continued = true
	Sfx.play("ui_confirm")
	Game.show_phase()
