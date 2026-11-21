class_name ScoreRace
extends Control
## Both sides race to the same target: two notched tracks, ivory for you,
## oxblood for the opponent, with the target at the right end.

var names: Array[String] = ["You", "Opponent"]
var target: int = 10
var _shown: Array[float] = [0.0, 0.0]
var _scores: Array[int] = [0, 0]


func _ready() -> void:
	custom_minimum_size = Vector2(360, 52)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "First to the target score wins (or capture the enemy king)."


func set_scores(player: int, opponent: int, animate: bool = true) -> void:
	_scores = [player, opponent]
	if not animate or not is_inside_tree():
		_shown = [float(player), float(opponent)]
		queue_redraw()
		return
	var tween := create_tween().set_parallel()
	for side in 2:
		tween.tween_method(_set_shown.bind(side), _shown[side], float(_scores[side]), Ui.NORMAL).set_ease(Tween.EASE_OUT)


func _set_shown(value: float, side: int) -> void:
	_shown[side] = value
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var number_font := UiFonts.numbers()
	var label_width := 120.0
	var track_left := label_width + 44.0
	var track_width := size.x - track_left - 36.0
	for side in 2:
		var y := 6.0 + side * 24.0
		var color := Palette.PIECE_IVORY if side == 0 else Palette.OXBLOOD
		draw_string(font, Vector2(0, y + 13), names[side], HORIZONTAL_ALIGNMENT_LEFT, label_width, 13, Palette.IVORY_SOFT)
		var number := str(_scores[side])
		draw_string(number_font, Vector2(label_width + 4, y + 15), number, HORIZONTAL_ALIGNMENT_RIGHT, 32, 20, color)
		var track := Rect2(track_left, y + 4, track_width, 12)
		draw_style_box(UiTheme.box(Palette.WALNUT_INSET, Palette.RULE, 3, 0), track)
		var fill_width := track_width * clampf(_shown[side] / target, 0.0, 1.0)
		if fill_width > 0.5:
			draw_style_box(UiTheme.box(color, Color.TRANSPARENT, 3, 0), Rect2(track.position, Vector2(fill_width, track.size.y)))
		for notch in range(1, target):
			var x := track_left + track_width * notch / float(target)
			draw_line(Vector2(x, track.position.y + 2), Vector2(x, track.end.y - 2), Color(Palette.WALNUT_DEEP, 0.6), 1.0)
	draw_string(number_font, Vector2(size.x - 30, 34), str(target), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.BRASS)
	draw_line(Vector2(size.x - 36, 6), Vector2(size.x - 36, 48), Palette.BRASS_DIM, 1.0)
