class_name ScoreRace
extends Control
## Both sides race to the same target: two notched tracks, ivory for you,
## oxblood for the opponent, with the target at the right end. Fills animate;
## a track within NEAR_TARGET of the target glows brass; a score flares its track.

const NEAR_TARGET := 0.8
## Layout (px at 1280x720) and text sizes (theme sizes).
const MIN_SIZE := Vector2(360, 52)
const LABEL_WIDTH := 120.0
const NUMBER_GAP := 4.0
const NUMBER_WIDTH := 32.0
const TRACK_LEFT := LABEL_WIDTH + 44.0
const TARGET_WIDTH := 36.0
## The first row's top; each row is ROW_HEIGHT tall.
const TOP := 6.0
const ROW_HEIGHT := 24.0
const TRACK_HEIGHT := 12.0
## Offsets inside a row: the track's top, the name's and the score's baselines.
const TRACK_TOP := 4.0
const NAME_BASELINE := 13.0
const NUMBER_BASELINE := 15.0
## The target figure: its left edge from the right end, and its baseline (between the rows).
const TARGET_TEXT_INSET := 30.0
const TARGET_BASELINE := 34.0
const NAME_SIZE := UiTheme.BODY
const NUMBER_SIZE := UiTheme.H2
const TARGET_SIZE := UiTheme.STRONG

var names: Array[String] = ["You", "Opponent"]
var target: int = 10
var _shown: Array[float] = [0.0, 0.0]
var _scores: Array[int] = [0, 0]
## 1 -> 0 after a score: a bright edge around that side's track.
var _flare: Array[float] = [0.0, 0.0]
## Reused by every redraw (the flare's alpha changes every frame, so it can't be a shared box).
var _flare_box: StyleBoxFlat = UiTheme.box(Color.TRANSPARENT, Color.WHITE, 5, 0, 2)


func _ready() -> void:
	custom_minimum_size = MIN_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "First to the target score wins (or capture the enemy king)."


func set_scores(player: int, opponent: int, animate: bool = true) -> void:
	_scores = [player, opponent]
	if not animate or not is_inside_tree():
		_shown = [float(player), float(opponent)]
		queue_redraw()
		return
	var tween := Motion.tween(self).set_parallel()
	for side in 2:
		tween.tween_method(_set_shown.bind(side), _shown[side], float(_scores[side]), Motion.time("score_fill"))


## One side's score (a score event's running total), animated.
func set_score(side: int, score: int) -> void:
	var scores := _scores.duplicate()
	scores[side] = score
	set_scores(scores[0], scores[1])


## A short bright edge around `side`'s track: "points landed here" (not with reduced motion).
func flare(side: int) -> void:
	if Motion.reduced() or not is_inside_tree():
		return
	Motion.tween(self).tween_method(_set_flare.bind(side), 1.0, 0.0, Motion.time("score_flare"))


func _set_shown(value: float, side: int) -> void:
	_shown[side] = value
	queue_redraw()


func _set_flare(value: float, side: int) -> void:
	_flare[side] = value
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var number_font := UiFonts.numbers()
	var track_width := size.x - TRACK_LEFT - TARGET_WIDTH
	for side in 2:
		var y := TOP + side * ROW_HEIGHT
		var color := Palette.PIECE_IVORY if side == 0 else Palette.OXBLOOD
		# Small text in the opponent's colour uses the lighter ink (contrast).
		var ink := Palette.PIECE_IVORY if side == 0 else Palette.OXBLOOD_INK
		draw_string(font, Vector2(0, y + NAME_BASELINE), names[side], HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH, NAME_SIZE, Palette.IVORY_SOFT)
		draw_string(number_font, Vector2(LABEL_WIDTH + NUMBER_GAP, y + NUMBER_BASELINE), str(_scores[side]), HORIZONTAL_ALIGNMENT_RIGHT, NUMBER_WIDTH, NUMBER_SIZE, ink)
		var track := Rect2(TRACK_LEFT, y + TRACK_TOP, track_width, TRACK_HEIGHT)
		if _shown[side] >= target * NEAR_TARGET:
			draw_style_box(UiTheme.shared_box(Color.TRANSPARENT, Color(Palette.BRASS, 0.55), 5, 0, 2), track.grow(3))
		draw_style_box(UiTheme.shared_box(Palette.WALNUT_INSET, Palette.RULE, 3, 0), track)
		var fill_width := track_width * clampf(_shown[side] / target, 0.0, 1.0)
		if fill_width > 0.5:
			draw_style_box(UiTheme.shared_box(color, Color.TRANSPARENT, 3, 0), Rect2(track.position, Vector2(fill_width, track.size.y)))
		for notch in range(1, target):
			var x := TRACK_LEFT + track_width * notch / float(target)
			draw_line(Vector2(x, track.position.y + 2), Vector2(x, track.end.y - 2), Color(Palette.WALNUT_DEEP, 0.6), 1.0)
		if _flare[side] > 0.0:
			_flare_box.bg_color = Color(ink, 0.18 * _flare[side])
			_flare_box.border_color = Color(ink, 0.9 * _flare[side])
			draw_style_box(_flare_box, track.grow(2.0 + 3.0 * _flare[side]))
	draw_string(number_font, Vector2(size.x - TARGET_TEXT_INSET, TARGET_BASELINE), str(target), HORIZONTAL_ALIGNMENT_LEFT, -1, TARGET_SIZE, Palette.BRASS)
	# The target rule spans both rows.
	draw_line(Vector2(size.x - TARGET_WIDTH, TOP), Vector2(size.x - TARGET_WIDTH, 2.0 * ROW_HEIGHT), Palette.BRASS_DIM, 1.0)
