class_name PieceRow
extends HBoxContainer
## A row of piece tokens (the title's back rank, the run end's line-up). Each token
## sits in a plain holder so it can move without fighting the HBox layout.
##   row.drop_in()   pieces fall in one after another (a fade with reduced motion)
##   row.bob()       a slow idle wave along the row (nothing with reduced motion)
##   row.topple(i)   token i lies down: the resigned king of a lost run

const BACK_RANK := ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]
const DROP := 28.0
const BOB := 2.0

var tokens: Array[PieceToken] = []


## `sides` holds the side of each token (0 ivory, 1 ebony); missing entries are 0.
static func create(types: Array, token_size: float, piece_set: String = "standard", sides: Dictionary = {}) -> PieceRow:
	var row := PieceRow.new()
	row.add_theme_constant_override("separation", Metrics.S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in types.size():
		var token := PieceToken.create(token_size, PieceData.new(types[i], piece_set), int(sides.get(i, 0)))
		var holder := Control.new()
		holder.custom_minimum_size = token.custom_minimum_size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(token)
		row.add_child(holder)
		row.tokens.append(token)
	return row


## Returns the seconds until the last piece has landed (for a sound or the next beat).
func drop_in(delay: float = 0.0) -> float:
	var stagger := Motion.time("title_drop_stagger")
	for i in tokens.size():
		var token := tokens[i]
		token.modulate.a = 0.0
		var tween := token.create_tween().set_parallel().set_ease(Tween.EASE_OUT)
		var start := Settings.time(delay) + Motion.time("title_drop_delay") + stagger * i
		tween.tween_property(token, "modulate:a", 1.0, Motion.time("title_drop") * 0.6).set_delay(start)
		if not Motion.reduced():
			token.position.y = -DROP
			tween.tween_property(token, "position:y", 0.0, Motion.time("title_drop")).set_delay(start).set_trans(Tween.TRANS_BOUNCE)
	return Settings.time(delay) + Motion.time("title_drop_delay") + stagger * tokens.size() + Motion.time("title_drop")


## A slow wave along the row: each token rises BOB px and settles, a little after
## its left neighbour (every loop has the same length, so the wave keeps its shape).
## Ambient, so the period is not sped up by the animation speed. Start it once
## drop_in() has finished (both move position.y).
func bob() -> void:
	if Motion.reduced():
		return
	var period := Feel.ambient("title_bob")
	var lag := period * 0.08
	for i in tokens.size():
		var tween := tokens[i].create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_interval(lag * i + 0.01)
		tween.tween_property(tokens[i], "position:y", -BOB, period / 2.0)
		tween.tween_property(tokens[i], "position:y", 0.0, period / 2.0)
		tween.tween_interval(lag * (tokens.size() - i) + 0.01)


## Token `index` tips over onto its side (a resigned king), after `delay` seconds.
func topple(index: int, delay: float = 0.0) -> void:
	var token := tokens[index]
	token.pivot_offset = token.size / 2.0 if token.size != Vector2.ZERO else token.custom_minimum_size / 2.0
	if Motion.reduced():
		token.rotation = PI / 2.0
		return
	var tween := token.create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(token, "rotation", PI / 2.0, Motion.time("title_drop") * 2.0).set_delay(Settings.time(delay))
