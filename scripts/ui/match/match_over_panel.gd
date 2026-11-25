class_name MatchOverPanel
extends Control
## The match-over modal: result, then what decided it (a toppled king for a king
## capture), the final score counting up when the score decided it (otherwise a
## small line, or nothing at 0–0), and the button that leaves the match
## (continue_pressed). `status` shows a refusal.

signal continue_pressed

const PLAYER := ChessMatch.PLAYER
const OPPONENT := ChessMatch.OPPONENT
const PANEL_WIDTH := 480.0
const SCORE_CELL_WIDTH := 150.0
const BUTTON_WIDTH := 240.0
## The captured king's token (px).
const KING_TOKEN := 64.0
## The toppled king's tilt (radians, about 83°: lying on its side, not just tipped).
const TOPPLED := -1.45

var status: Label

var _result: Dictionary
var _names: Array[String] = []


func _init(result: Dictionary, side_names: Array[String]) -> void:
	_result = result
	_names = side_names


func _ready() -> void:
	var player_won := int(_result["winner"]) == PLAYER
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Palette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := Ui.panel("ModalPanel")
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	centre.add_child(panel)
	var column := Ui.vbox(Metrics.M)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	column.add_child(_centred(Ui.label("MATCH OVER · ROUND %d" % int(_result["rounds"]), "Eyebrow")))
	column.add_child(_centred(Ui.label("Victory" if player_won else "Defeat", "Title", Palette.BRASS if player_won else Palette.OXBLOOD)))
	var reason: String = _result["reason"]
	var scores: Array = _result["scores"]
	if reason == "king":
		column.add_child(_toppled_king(OPPONENT if player_won else PLAYER))
	column.add_child(_centred(Ui.label(headline(reason, player_won), "H2", Palette.IVORY)))
	column.add_child(Ui.rule(Palette.RULE_SOFT))
	if is_score_the_story(reason, scores):
		column.add_child(_final_score(scores))
		column.add_child(Ui.rule(Palette.RULE_SOFT))
	elif int(scores[PLAYER]) > 0 or int(scores[OPPONENT]) > 0:
		column.add_child(_centred(Ui.label("Final score: %s %d – %d %s" % [_names[PLAYER], int(scores[PLAYER]), int(scores[OPPONENT]), _names[OPPONENT]], "Caption")))
	var next_text := "Continue"
	if player_won:
		var is_boss: bool = Game.run.current_node_info().get("type", "") == "boss"
		column.add_child(_centred(Ui.label("The boss is beaten." if is_boss else "+%d training points and a new card to choose" % int(GameConfig.value("economy", "win_points")), "Body", Palette.BRASS)))
	else:
		column.add_child(_centred(Ui.label("Your run ends here.", "Body")))
		next_text = "See the run summary"
	var button := Ui.button(next_text, "PrimaryButton")
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, Metrics.BUTTON_HEIGHT_LARGE)
	button.pressed.connect(continue_pressed.emit)
	column.add_child(Ui.centered(button))
	status = Ui.status_label()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	Sfx.play("victory" if player_won else "defeat", false)
	Feel.fade_in(self)
	if Motion.reduced():
		return
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.94
	Motion.tween(panel, "settle").tween_property(panel, "scale", Vector2.ONE, Motion.time("quick") * 2.0)


## What decided the match, in one line ("King captured: you took their king").
## Not "checkmate": here a king in check may escape or stay, and is then captured.
static func headline(reason: String, player_won: bool) -> String:
	if reason == "king":
		return "King captured: you took their king" if player_won else "King captured: you lost your king"
	return EventText.reason_text(reason, player_won).trim_suffix(".")


## The big score only when the score decided it (target reached, or the turn
## limit) and it isn't 0–0; a king capture or "no legal move" makes it noise.
static func is_score_the_story(reason: String, scores: Array) -> bool:
	return reason in ["score", "turn_limit"] and (int(scores[PLAYER]) > 0 or int(scores[OPPONENT]) > 0)


## The losing side's king, tipped over (it settles into place unless motion is reduced).
func _toppled_king(side: int) -> CenterContainer:
	var holder := CenterContainer.new()
	var king := PieceToken.create(KING_TOKEN, null, side)
	king.piece_type = "king"
	holder.add_child(king)
	king.rotation = TOPPLED
	if not Motion.reduced():
		king.rotation = 0.0
		Motion.tween(king, "settle").tween_property(king, "rotation", TOPPLED, Motion.time("count_up")).set_delay(Motion.time("quick") * 2.0)
	return holder


## "YOU 6  –  2 ROOKIE REX" with each side's figure in its own colour.
func _final_score(scores: Array) -> HBoxContainer:
	var row := Ui.hbox(Metrics.L)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for side in [PLAYER, OPPONENT]:
		var cell := Ui.vbox(0)
		cell.custom_minimum_size.x = SCORE_CELL_WIDTH
		var number := _centred(Ui.label("0", "StatLarge", Palette.PIECE_IVORY if side == PLAYER else Palette.OXBLOOD_INK))
		cell.add_child(number)
		_count_up(number, int(scores[side]))
		cell.add_child(_centred(Ui.label(_names[side].to_upper(), "Caption")))
		row.add_child(cell)
		if side == PLAYER:
			# Same font and caption line as the figures, so the dash sits on their centre.
			var dash := Ui.vbox(0)
			dash.add_child(_centred(Ui.label("–", "StatLarge", Palette.IVORY_FAINT)))
			dash.add_child(Ui.label(" ", "Caption"))
			row.add_child(dash)
	return row


## The final score counts up from 0 once the panel has settled.
func _count_up(number: Label, score: int) -> void:
	var tween := Motion.tween(number)
	tween.tween_interval(Motion.time("quick") * 2.0)
	tween.tween_method(func(shown: float) -> void: number.text = str(roundi(shown)), 0.0, float(score), Motion.time("count_up"))


func _centred(node: Label) -> Label:
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node
