class_name Motion
extends RefCounted
## Named game-feel timings and eases (config/ux.json "motion"). Every duration
## goes through speed() (the Settings animation speed), so "fast" and "instant"
## scale everything.
##   Motion.time("move")              # seconds, scaled by the animation speed
##   Motion.tween(node, "settle")     # a Tween whose tweeners default to that ease
##   Motion.reduced()                 # reduced motion: no shake, flashes, particles
##   Motion.hurry = true              # the opponent's turn is hurried: "instant" speed

const TRANSITIONS := {"linear": Tween.TRANS_LINEAR, "sine": Tween.TRANS_SINE, "quad": Tween.TRANS_QUAD,
	"cubic": Tween.TRANS_CUBIC, "back": Tween.TRANS_BACK, "expo": Tween.TRANS_EXPO}
const EASES := {"in": Tween.EASE_IN, "out": Tween.EASE_OUT, "in_out": Tween.EASE_IN_OUT}
const LAND_WEIGHTS := {"pawn": "light", "knight": "light", "bishop": "medium", "rook": "medium",
	"queen": "heavy", "king": "heavy"}


## True while the player hurries the opponent's turn (the match screen sets it and
## clears it when the turn ends): durations run at the "instant" speed, or the
## player's own speed if that is quicker. Never saved.
static var hurry: bool = false


static func _config() -> Dictionary:
	return GameConfig.data("ux")["motion"]


## Unscaled seconds at animation speed 1.0.
static func seconds(duration_name: String) -> float:
	var durations: Dictionary = _config()["durations"]
	assert(durations.has(duration_name), "Unknown motion duration: " + duration_name)
	return float(durations.get(duration_name, 0.0))


static func time(duration_name: String) -> float:
	return seconds(duration_name) * speed()


## The multiplier for unscaled seconds: the animation speed, or "instant" while hurried.
static func speed() -> float:
	if hurry:
		return minf(Settings.anim_scale(), float(GameConfig.data("ux")["anim_speeds"]["instant"]))
	return Settings.anim_scale()


static func reduced() -> bool:
	return Settings.reduced_motion()


static func tween(node: Node, ease_name: String = "out") -> Tween:
	var shape: Array = _config()["eases"][ease_name]
	return node.create_tween().set_trans(TRANSITIONS[shape[0]]).set_ease(EASES[shape[1]])


## "light", "medium" or "heavy": how hard a piece of this type lands.
static func land_weight(piece_type: String) -> String:
	return LAND_WEIGHTS.get(piece_type, "medium")


## Squash for a landing of that weight (x stretches, y squashes).
static func land_squash(weight: String) -> Vector2:
	match weight:
		"light":
			return Vector2(1.08, 0.92)
		"heavy":
			return Vector2(1.16, 0.84)
	return Vector2(1.12, 0.88)


## Hop height (px) of a slide: longer moves arc higher; knights jump.
static func arc_height(distance: float, cell: float, is_knight: bool) -> float:
	var height := clampf(distance * 0.12, cell * 0.08, cell * 0.3)
	return height * 1.6 if is_knight else height
