extends GutTest
## Reduced motion turns the shake / pop / burst helpers into no-ops; without it
## they move the node and always come back to rest. Temp settings file only.

const TestTmp := preload("res://tests/hooks/test_tmp.gd")
## This process's own temp folder (parallel test runs never share files).
var TMP_DIR := TestTmp.root()
var TMP_SETTINGS := TMP_DIR + "reduced_motion_test.json"

var _old_path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	DirAccess.remove_absolute(TMP_SETTINGS)
	_old_path = Settings.path
	Settings.use_path(TMP_SETTINGS)
	Settings.set_value("anim_speed", "instant")


func after_each() -> void:
	Settings.use_path(_old_path)
	DirAccess.remove_absolute(TMP_SETTINGS)


func _node() -> Control:
	var node := Control.new()
	node.position = Vector2(40, 30)
	node.size = Vector2(20, 20)
	add_child_autofree(node)
	return node


## Positions seen on every frame for `seconds`.
func _positions(node: Control, seconds: float) -> Array:
	var seen: Array = []
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		seen.append(node.position)
		await get_tree().process_frame
	seen.append(node.position)
	return seen


func test_impact_shake_is_a_no_op_with_reduced_motion() -> void:
	Settings.set_value("reduced_motion", true)
	var node := _node()
	Feel.shake(node, 2.0, Vector2.DOWN)
	assert_false(node.has_meta(&"_shake_tween"), "no tween started")
	var seen: Array = await _positions(node, 0.15)
	assert_true(seen.all(func(at: Vector2) -> bool: return at == Vector2(40, 30)), "never moved")


func test_restarted_shake_returns_to_rest() -> void:
	var node := _node()
	Feel.shake(node)
	Feel.shake(node)  # a restart mid-shake still returns to the original rest position
	var seen: Array = await _positions(node, 0.3)
	assert_true(seen.any(func(at: Vector2) -> bool: return at != Vector2(40, 30)), "it moved")
	assert_eq(node.position, Vector2(40, 30), "back at rest")
	assert_false(node.has_meta(&"_shake_origin"))


func test_feel_shake_and_pops_are_no_ops_with_reduced_motion() -> void:
	Settings.set_value("reduced_motion", true)
	var node := _node()
	Feel.shake(node)
	Feel.pop(node)
	Feel.pop(node, 1.12, "pop")  # the match's pop timings
	Feel.glow(node)
	var seen: Array = await _positions(node, 0.15)
	assert_true(seen.all(func(at: Vector2) -> bool: return at == Vector2(40, 30)), "never moved")
	assert_eq(node.scale, Vector2.ONE, "never scaled")
	assert_eq(node.modulate, Color.WHITE, "never tinted")


func test_feel_shake_moves_without_reduced_motion() -> void:
	var node := _node()
	Feel.shake(node)
	var seen: Array = await _positions(node, 0.3)
	assert_true(seen.any(func(at: Vector2) -> bool: return at.x != 40.0), "it moved")
	assert_eq(node.position, Vector2(40, 30), "back at rest")


func test_fx_burst_spawns_only_without_reduced_motion() -> void:
	var parent := _node()
	var burst := FxBurst.spawn(parent, FxBurst.Kind.SHARDS, Vector2(10, 10), Color.WHITE, 30.0, 0.05)
	assert_not_null(burst, "spawned")
	assert_eq(burst.get_parent(), parent)
	await wait_seconds(0.2)
	assert_false(is_instance_valid(burst), "freed when it ends")
	Settings.set_value("reduced_motion", true)
	assert_null(FxBurst.spawn(parent, FxBurst.Kind.RING, Vector2.ZERO, Color.WHITE, 30.0, 0.05), "nothing with reduced motion")
	assert_eq(parent.get_child_count(), 0)


func test_every_burst_kind_draws() -> void:
	var parent := _node()
	for kind: FxBurst.Kind in FxBurst.Kind.values():
		var burst := FxBurst.spawn(parent, kind, Vector2(10, 10), Color.WHITE, 30.0, 0.1)
		assert_not_null(burst, str(kind))
	await wait_process_frames(3)  # _draw runs for every kind without errors
	assert_gt(parent.get_child_count(), 0)
