extends Control
## Title: the lockup (piece row, title, tagline), New Game / Settings / Quit, and
## what has been unlocked so far, over the TitleBackdrop. The piece row drops in
## one piece at a time with a soft wood knock as it lands (a plain fade with
## reduced motion). Idle: a slow light sweep crosses the title and the row
## breathes in a gentle wave (both off with reduced motion).

## A soft band of light that moves across the title: brightens ink, leaves the
## shadow (black) black. `sweep` is the band's x in the label's local pixels.
const SWEEP_SHADER := """
shader_type canvas_item;
uniform float sweep = -400.0;
uniform float width = 90.0;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	float band = 1.0 - smoothstep(0.0, width, abs(local.x + local.y * 0.35 - sweep));
	COLOR.rgb *= 1.0 + band * 0.32;
}
"""

var _piece_row: PieceRow
var _title: Label


func _ready() -> void:
	add_child(TitleBackdrop.new())
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := Ui.vbox(Metrics.L)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	column.add_child(_lockup())
	column.add_child(Ui.gap(Metrics.S))
	var new_game := Ui.button("New Game", "PrimaryButton")
	new_game.custom_minimum_size = Vector2(280, Metrics.BUTTON_HEIGHT_LARGE)
	new_game.add_theme_font_size_override("font_size", UiTheme.STRONG)
	new_game.set_meta("sfx", "ui_confirm")
	Ui.connect_once(new_game, func() -> void: Game.new_run())
	column.add_child(Ui.centered(new_game))
	var settings := Ui.button("Settings", "QuietButton")
	settings.custom_minimum_size = Vector2(280, Metrics.BUTTON_HEIGHT)
	settings.tooltip_text = "Volume, motion, display and controls (%s)" % A11y.key_label(&"rc_settings")
	settings.pressed.connect(Game.open_settings)
	column.add_child(Ui.centered(settings))
	var quit := Ui.button("Quit", "QuietButton")
	quit.custom_minimum_size = Vector2(280, Metrics.BUTTON_HEIGHT)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(Ui.centered(quit))
	column.add_child(Ui.gap(Metrics.XL))
	column.add_child(Ui.centered(_unlock_panel()))
	A11y.focus_all(self)
	A11y.focus_first([new_game])
	var landed := _piece_row.drop_in()
	# The title opening: one soft knock as the row settles on the board.
	var idle := create_tween()
	idle.tween_callback(Sfx.play.bind("piece_land_light")).set_delay(maxf(landed - Motion.time("title_drop") * 0.5, 0.0))
	idle.tween_callback(_start_idle).set_delay(Motion.time("title_drop") * 0.5)


func _lockup() -> VBoxContainer:
	var lockup := Ui.vbox(Metrics.S)
	# The back rank, with the opponent's ebony queen in the player's ivory line.
	_piece_row = PieceRow.create(PieceRow.BACK_RANK, 44, "standard", {3: 1})
	lockup.add_child(Ui.centered(_piece_row))
	lockup.add_child(Ui.gap(Metrics.XS))
	lockup.add_child(_flanked(Ui.label("A CHESS ROGUELIKE DECKBUILDER", "Eyebrow")))
	_title = Ui.label("RogueChess", "Display")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	lockup.add_child(_title)
	var size := int(GameConfig.value("match", "board_size"))
	var subtitle := Ui.label("%d by %d board · every move needs a card · upgrade pieces and cards as you climb" % [size, size], "Body")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lockup.add_child(subtitle)
	return lockup


## The eyebrow between two short brass rules.
func _flanked(text: Label) -> HBoxContainer:
	var row := Ui.hbox(Metrics.M)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 2:
		var line := Ui.rule(Palette.BRASS_DIM)
		line.size_flags_horizontal = Control.SIZE_FILL
		line.custom_minimum_size.x = 56
		row.add_child(line)
		if i == 0:
			row.add_child(text)
	return row


## The idle life of the title: the light sweep and the row's wave. Both are
## ambient (unscaled seconds) and stay off with reduced motion.
func _start_idle() -> void:
	if Motion.reduced():
		return
	_piece_row.bob()
	var shader := Shader.new()
	shader.code = SWEEP_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_title.material = material
	var reach := _title.size.x + 300.0
	material.set_shader_parameter("sweep", -300.0)
	var sweep := create_tween().set_loops()
	sweep.tween_property(material, "shader_parameter/sweep", reach, Feel.ambient("title_sweep")) \
		.from(-300.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_interval(Feel.ambient("title_sweep_rest"))


func _unlock_panel() -> PanelContainer:
	var meta := Game.unlocks()
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(560, 0)
	var column := Ui.vbox(Metrics.M)
	panel.add_child(column)
	var sets: Dictionary = GameConfig.data("piece_sets")["sets"]
	var pool: Array = GameConfig.data("artifacts")["unlock_pool"]
	column.add_child(_progress_line("Piece sets", meta.unlocked_piece_sets.size(), sets.size()))
	var set_row := Ui.hbox(Metrics.XS + 2)
	for set_id: String in sets:
		var is_open := meta.is_piece_set_unlocked(set_id)
		set_row.add_child(Ui.chip(Ui.piece_set_name(set_id) if is_open else "%s · locked" % Ui.piece_set_name(set_id),
			Palette.BRASS if is_open else Palette.IVORY_FAINT, sets[set_id]["desc"]))
	column.add_child(set_row)
	column.add_child(Ui.rule(Palette.RULE_SOFT))
	column.add_child(_progress_line("Artifacts", meta.unlocked_artifacts.size(), pool.size()))
	var artifact_row := Ui.hbox(Metrics.XS + 2)
	for artifact_id: String in pool:
		var is_open := meta.is_artifact_unlocked(artifact_id)
		artifact_row.add_child(Ui.chip(Ui.artifact_name(artifact_id) if is_open else "?",
			Palette.BRASS if is_open else Palette.IVORY_FAINT, Ui.artifact_desc(artifact_id) if is_open else "Lose a match to unlock a random artifact"))
	column.add_child(artifact_row)
	return panel


## "PIECE SETS ······ ▮▯ 1 / 2 unlocked"
func _progress_line(text: String, unlocked: int, total: int) -> HBoxContainer:
	var row := Ui.hbox(Metrics.S)
	row.add_child(Ui.label(text.to_upper(), "Eyebrow"))
	row.add_child(Ui.spacer())
	var meter := PipMeter.new()
	meter.is_round = false
	meter.pip_size = Vector2(14, 6)
	meter.gap = 3
	meter.total = total
	meter.value = unlocked
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	row.add_child(Ui.label("%d / %d unlocked" % [unlocked, total], "Caption"))
	return row
