extends Control
## The end of a run, as a payoff: the result, the player's back rank, the run's
## figures counting up, what was unlocked, and a new run. Everything sits in one
## centred column. A win gets a brass burst behind the title and the pieces drop
## in; a loss is quieter: no burst, the pieces fade in and the king lies down.
## Sound: a run_victory / run_defeat stinger over silence (main.gd stops the music),
## a score_tick as each figure lands, and a new unlock opens with its
## unlock_fanfare in the same moment: after the figures, and never before the run
## stinger has rung out (Sfx.stinger_time_left()); until then its panel shows a
## sealed emblem, so the page is never lopsided. The lounge loop returns when the
## last stinger (run stinger, then fanfare) has ended. Reduced motion: no burst,
## drop or topple motion; figures still count, panels fade.

const ROW_TOKEN := 40.0
## Big enough for a ≥ 12 px name and a readable cost coin; copies show "×N".
const DECK_CARD := Vector2(72, 101)
## Wide enough for a 10-card deck on one row (the unlock panel is 340).
const SUMMARY_WIDTH := 760

var _stats: Array[Label] = []
## The unlock panel's sealed emblem (a new unlock only), until it opens.
var _seal: Seal
var _stat_targets: Array[int] = []
var _title: Label


func _ready() -> void:
	var run := Game.run
	var summary := run.summary()
	var is_win: bool = summary["result"] == "won"
	var piece_set: String = summary["piece_set"] if summary["piece_set"] != "" else "standard"
	var flourish := Flourish.new()
	add_child(flourish)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Metrics.SCREEN_X)
	Ui.centre_tall(margin)
	add_child(margin)
	var column := Ui.vbox(Metrics.L)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)
	var eyebrow := Ui.label("RUN COMPLETE" if is_win else "RUN OVER", "Eyebrow", Palette.BRASS if is_win else Palette.OXBLOOD_INK)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(eyebrow)
	var floor_reached := int(summary["floors_cleared"]) + 1
	_title = Ui.label("The boss has fallen" if is_win else "Defeated on floor %d" % floor_reached, "Title",
		Palette.BRASS if is_win else Palette.IVORY)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var row := PieceRow.create(PieceRow.BACK_RANK, ROW_TOKEN, piece_set)
	column.add_child(Ui.centered(row))
	column.add_child(Ui.gap(Metrics.XS))
	var panels := Ui.hbox(Metrics.XL)
	panels.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(panels)
	var unlock := run.unlock_result()
	var unlock_panel := _unlock_panel(unlock)
	panels.add_child(unlock_panel)
	panels.add_child(_summary_panel(summary))
	column.add_child(Ui.gap(Metrics.XS))
	var actions := Ui.hbox(Metrics.S)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Ui.button("Title screen", "QuietButton")
	Ui.connect_once(title, func() -> void: Game.show_title())
	actions.add_child(title)
	var again := Ui.button("Start new run", "PrimaryButton")
	again.custom_minimum_size = Vector2(220, Metrics.BUTTON_HEIGHT_LARGE)
	again.set_meta("sfx", "ui_confirm")
	Ui.connect_once(again, func() -> void: Game.new_run())
	actions.add_child(again)
	column.add_child(actions)
	A11y.focus_all(self)
	A11y.focus_first([again])
	Sfx.play("run_victory" if is_win else "run_defeat", false)
	var is_new: bool = unlock.get("is_new", false)
	_play(is_win, row, flourish, unlock_panel, is_new)
	if not is_new:
		_music_back_after_stingers()


## The lounge loop comes back once the stingers sounding now (and queued) have
## rung out: real audio seconds, so the animation speed never shortens it.
func _music_back_after_stingers() -> void:
	create_tween().tween_callback(Sfx.play_music.bind("music_menu")).set_delay(Sfx.stinger_time_left())


## The beats: (win) burst; the row drops in (a loss: fades in, then the king
## topples); the figures count up one after another; the unlock deals in last.
func _play(is_win: bool, row: PieceRow, flourish: Flourish, unlock_panel: PanelContainer, is_new: bool) -> void:
	if is_win:
		# After layout, so the burst centres on the title.
		# After layout (so it centres on the title) and after the screen's own
		# entrance fade, so it never shows over a half-faded title.
		create_tween().tween_callback(func() -> void:
			flourish.burst(Feel.centre_in(_title, self), Motion.time("run_burst"))).set_delay(Motion.time("screen_transition"))
		row.drop_in(Motion.seconds("unlock_delay"))
	else:
		for token in row.tokens:
			token.modulate.a = 0.0
			token.create_tween().tween_property(token, "modulate:a", 1.0, Motion.time("reveal")).set_delay(Motion.time("unlock_delay"))
		row.topple(PieceRow.BACK_RANK.find("king"), Motion.seconds("reveal") + Motion.seconds("unlock_delay"))
	# Unscaled seconds at speed 1.0 (Settings.time() scales them where they're used).
	var start := Motion.seconds("reveal") + Motion.seconds("unlock_delay")
	var stagger := Motion.seconds("run_count_stagger")
	for i in _stats.size():
		_count_up(_stats[i], _stat_targets[i], Settings.time(start + stagger * i))
	var content: Control = unlock_panel.get_child(0)
	# The eyebrow shows from the start (the panel keeps the page balanced); the
	# rest of the unlock deals in when it opens.
	var items: Array = content.get_children().slice(1)
	for item: Control in items:
		item.modulate.a = 0.0
	if not is_new:
		Feel.reveal(items, 0.06, start)
		return
	# Real seconds, both: the figures' end (scaled by the animation speed) and the
	# run stinger's end (audio time). The reveal, its fanfare and its glow all
	# happen at the later one, together.
	var figures_done := Settings.time(start + stagger * _stats.size() + Motion.seconds("run_count_up"))
	var open_at := maxf(figures_done, Sfx.stinger_time_left())
	create_tween().tween_callback(func() -> void:
		_seal.open()
		Feel.reveal(items, 0.06)
		Sfx.play("unlock_fanfare", false)
		Feel.glow(unlock_panel)
		_music_back_after_stingers()).set_delay(open_at)


## The label's "%d" (or "%d / N") figure counts from 0 to `target`, then pops with a tick.
func _count_up(label: Label, target: int, delay: float) -> void:
	var format: String = label.get_meta("format")
	label.text = format % 0
	var tween := label.create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(value: float) -> void: label.text = format % roundi(value), 0.0, float(target), Motion.time("run_count_up")) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		Sfx.play("score_tick")
		Feel.pop(label, 1.12))


func _unlock_panel(unlock: Dictionary) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_vertical = Control.SIZE_FILL
	# Top-aligned, so its eyebrow lines up with "THE RUN" next to it.
	var column := Ui.vbox(Metrics.M)
	panel.add_child(column)
	var is_new: bool = unlock.get("is_new", false)
	column.add_child(Ui.label("UNLOCKED FOR YOUR NEXT RUN" if is_new else "UNLOCK", "Eyebrow"))
	if is_new:
		_seal = Seal.new()
		panel.add_child(_seal)
	if is_new and unlock["kind"] == "piece_set":
		var tokens := Ui.hbox(Metrics.XS)
		for piece_type in ["pawn", "knight", "bishop", "rook", "queen"]:
			tokens.add_child(PieceToken.create(44, PieceData.new(piece_type, unlock["id"])))
		column.add_child(tokens)
		column.add_child(Ui.label("%s pieces" % Ui.piece_set_name(unlock["id"]), "H1", Palette.EMBER))
		column.add_child(Ui.wrapped(String(GameConfig.data("piece_sets")["sets"][unlock["id"]]["desc"]), "Body", 300))
		column.add_child(Ui.wrapped("Pick the set when you start a run.", "Caption", 300))
	elif is_new:
		var emblem := ArtifactEmblem.create(unlock["id"])
		emblem.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(emblem)
		# The unlock text names the artifact ("New artifact unlocked: …"): it is the headline.
		column.add_child(Ui.wrapped(String(unlock.get("text", "")), "H2", 300))
		column.add_child(Ui.wrapped(Ui.artifact_desc(unlock["id"]), "Body", 300))
		column.add_child(Ui.wrapped("Choose it at the start of your next run.", "Caption", 300))
	else:
		column.add_child(Ui.label("Nothing new", "H2", Palette.IVORY_SOFT))
		column.add_child(Ui.wrapped(String(unlock.get("text", "")), "Body", 300))
	return panel


func _summary_panel(summary: Dictionary) -> PanelContainer:
	var panel := Ui.panel("RaisedPanel")
	panel.custom_minimum_size.x = SUMMARY_WIDTH
	panel.size_flags_vertical = Control.SIZE_FILL
	var column := Ui.vbox(Metrics.M)
	panel.add_child(column)
	column.add_child(Ui.label("THE RUN", "Eyebrow"))
	var stats := Ui.hbox(Metrics.XXL)
	stats.add_child(_stat("Floors climbed", "%d / " + str(summary["floors_total"]), int(summary["floors_cleared"])))
	stats.add_child(_stat("Matches won", "%d", int(summary["wins"])))
	stats.add_child(_stat("Cards in deck", "%d", summary["deck"].size()))
	stats.add_child(_stat("Pieces owned", "%d", summary["collection"].size()))
	stats.add_child(_stat("Points left", "%d", int(summary["points"]), "Training points do not carry over to the next run"))
	column.add_child(stats)
	var tags := Ui.hbox(Metrics.XS)
	if summary["piece_set"] != "":
		tags.add_child(Ui.chip("%s set" % Ui.piece_set_name(summary["piece_set"]), Palette.IVORY_SOFT))
	tags.add_child(Ui.artifact_chips(summary["artifacts"]))
	column.add_child(tags)
	column.add_child(Ui.rule(Palette.RULE_SOFT))
	var deck := HFlowContainer.new()
	deck.add_theme_constant_override("h_separation", Metrics.XS + 2)
	deck.add_theme_constant_override("v_separation", Metrics.L)
	var cards: Array = summary["deck"].map(func(card_dict: Dictionary) -> CardData: return CardData.from_dict(card_dict))
	for group: Array in ItemOverlay.group_cards(cards):
		var view := CardView.create(group[0], DECK_CARD)
		view.is_interactive = false
		view.mouse_filter = Control.MOUSE_FILTER_PASS
		if group.size() == 1:
			deck.add_child(view)
			continue
		var holder := Control.new()
		holder.custom_minimum_size = DECK_CARD
		holder.add_child(view)
		var badge := ItemOverlay.count_badge(group.size())
		holder.add_child(badge)
		ItemOverlay.pin_badge(badge)
		deck.add_child(holder)
	column.add_child(deck)
	var pieces := HFlowContainer.new()
	pieces.add_theme_constant_override("h_separation", 2)
	pieces.add_theme_constant_override("v_separation", 2)
	for piece_dict: Dictionary in summary["collection"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(30, 30)
		var data := PieceData.from_dict(piece_dict)
		holder.tooltip_text = Ui.piece_tooltip(data)
		holder.add_child(PieceToken.create(30, data))
		pieces.add_child(holder)
	column.add_child(pieces)
	var upgraded: Array = summary["upgraded_pieces"]
	if not upgraded.is_empty():
		var names: Array[String] = []
		for piece_dict: Dictionary in upgraded:
			names.append("%s (%s)" % [Ui.piece_name(piece_dict["type"]), Ui.upgrade_name("piece", piece_dict["upgrade"])])
		column.add_child(Ui.wrapped("Upgraded: " + ", ".join(names), "Caption", 640))
	return panel


## A caption over a large figure that counts up to `target` (format "%d" or "%d / N").
func _stat(caption: String, format: String, target: int, hint: String = "") -> VBoxContainer:
	var column := Ui.vbox(0)
	column.tooltip_text = hint
	column.mouse_filter = Control.MOUSE_FILTER_PASS if hint != "" else Control.MOUSE_FILTER_IGNORE
	column.add_child(Ui.label(caption, "Caption"))
	var figure := Ui.label(format % target, "StatLarge")
	figure.set_meta("format", format)
	column.add_child(figure)
	_stats.append(figure)
	_stat_targets.append(target)
	return column


## The win's flourish: brass rays and a ring burst out from behind the title and fade.
## Draws only while it plays; nothing with reduced motion.
class Flourish extends Control:
	const RAYS := 18
	var centre := Vector2.ZERO
	var progress := 1.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func burst(at: Vector2, duration: float) -> void:
		if Motion.reduced():
			return
		centre = at
		progress = 0.0
		create_tween().tween_property(self, "progress", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Rays and a ring only, drawn behind the page (this layer is the screen's
		# first child): no shards or glow ever sit on the title, eyebrow or panels.

	func _draw() -> void:
		if progress >= 1.0:
			return
		var fade := 1.0 - progress
		var reach := 120.0 + 420.0 * progress
		for i in RAYS:
			var direction := Vector2.from_angle(TAU * i / RAYS + progress * 0.25)
			var inner := 70.0 + 160.0 * progress
			draw_line(centre + direction * inner, centre + direction * reach, Color(Palette.BRASS, 0.35 * fade), 3.0 if i % 2 == 0 else 1.5, true)
		draw_arc(centre, 60.0 + 360.0 * progress, 0, TAU, 64, Color(Palette.BRASS, 0.5 * fade), 2.0, true)


## A new unlock's sealed emblem: a brass-rimmed disc with a "?" in the middle of
## the unlock panel until the unlock opens; then it grows a little and fades.
class Seal extends Control:
	const RADIUS := 36.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func open() -> void:
		pivot_offset = size / 2.0
		var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, Motion.time("reveal"))
		if not Motion.reduced():
			tween.tween_property(self, "scale", Vector2.ONE * 1.25, Motion.time("reveal"))
		tween.chain().tween_callback(queue_free)

	func _draw() -> void:
		var centre := size / 2.0
		draw_circle(centre, RADIUS, Palette.WALNUT_DEEP)
		draw_arc(centre, RADIUS, 0, TAU, 48, Palette.BRASS, 2.0, true)
		draw_arc(centre, RADIUS - 6.0, 0, TAU, 48, Color(Palette.BRASS, 0.35), 1.0, true)
		var font := UiFonts.serif_bold()
		var font_size := 34
		var glyph_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, centre + Vector2(-glyph_size.x / 2.0, font.get_ascent(font_size) / 2.0 - 2.0), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.BRASS)
