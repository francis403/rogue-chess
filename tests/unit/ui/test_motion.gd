extends GutTest
## Motion: named durations from config/ux.json "motion", scaled by Settings.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")
## This process's own temp folder (parallel test runs never share files).
var TMP_DIR := TestTmp.root()
var TMP_SETTINGS := TMP_DIR + "motion_settings.json"

var _old_settings_path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_old_settings_path = Settings.path
	Settings.use_path(TMP_SETTINGS)


func after_each() -> void:
	Settings.use_path(_old_settings_path)
	DirAccess.remove_absolute(TMP_SETTINGS)


func test_every_duration_is_positive_and_short() -> void:
	var durations: Dictionary = GameConfig.data("ux")["motion"]["durations"]
	assert_gt(durations.size(), 0)
	for duration_name: String in durations:
		assert_gt(Motion.seconds(duration_name), 0.0, duration_name)
		assert_lte(Motion.seconds(duration_name), 2.5, "%s stays short" % duration_name)


func test_hit_stop_stays_under_60_ms() -> void:
	assert_lte(Motion.seconds("impact_hold"), 0.06)


func test_time_follows_the_animation_speed() -> void:
	Settings.set_value("anim_speed", "normal")
	assert_almost_eq(Motion.time("move"), Motion.seconds("move"), 0.0001)
	Settings.set_value("anim_speed", "instant")
	var instant := Motion.time("move")
	assert_lt(instant, Motion.seconds("move"))
	assert_almost_eq(instant, Settings.time(Motion.seconds("move")), 0.0001)


func test_every_ease_resolves() -> void:
	for ease_name: String in GameConfig.data("ux")["motion"]["eases"]:
		var tween := Motion.tween(self, ease_name)
		assert_not_null(tween, ease_name)
		tween.kill()


func test_land_weights_by_piece_class() -> void:
	for piece_type in ["pawn", "knight"]:
		assert_eq(Motion.land_weight(piece_type), "light")
	for piece_type in ["bishop", "rook"]:
		assert_eq(Motion.land_weight(piece_type), "medium")
	for piece_type in ["queen", "king"]:
		assert_eq(Motion.land_weight(piece_type), "heavy")
	assert_gt(Motion.land_squash("heavy").x, Motion.land_squash("light").x, "heavier pieces squash more")


func test_land_sounds_exist() -> void:
	for weight in ["light", "medium", "heavy"]:
		assert_true(Sfx.has_sound("piece_land_" + weight))


func test_arc_grows_with_distance_and_knights_jump_higher() -> void:
	var cell := 60.0
	assert_gt(Motion.arc_height(cell * 4, cell, false), Motion.arc_height(cell, cell, false))
	assert_gt(Motion.arc_height(cell * 2, cell, true), Motion.arc_height(cell * 2, cell, false))
	assert_lte(Motion.arc_height(cell * 10, cell, false), cell * 0.3)


func test_every_duration_scales_with_every_speed() -> void:
	var speeds: Dictionary = GameConfig.data("ux")["anim_speeds"]
	for speed: String in speeds:
		Settings.set_value("anim_speed", speed)
		for duration_name: String in GameConfig.data("ux")["motion"]["durations"]:
			var expected := Motion.seconds(duration_name) * float(speeds[speed])
			assert_almost_eq(Motion.time(duration_name), expected, 0.0001, "%s at %s" % [duration_name, speed])
	Settings.set_value("anim_speed", "fast")
	var fast := Motion.time("move")
	Settings.set_value("anim_speed", "normal")
	assert_lt(fast, Motion.time("move"), "fast is shorter than normal")


func test_reduced_follows_the_setting() -> void:
	Settings.set_value("reduced_motion", false)
	assert_false(Motion.reduced())
	Settings.set_value("reduced_motion", true)
	assert_true(Motion.reduced())


func test_unknown_land_weight_is_medium() -> void:
	assert_eq(Motion.land_weight("dragon"), "medium")
	assert_eq(Motion.land_squash("unknown"), Motion.land_squash("medium"))
	assert_gt(Motion.arc_height(0.0, 60.0, false), 0.0, "even a zero-length slide lifts a little")
