extends SceneTree
## L-19 合约：Boss attack type 全覆盖（伤害类 type 不再静默 pass）。
## 构造最小 Node3D attacker/target（attacker 带 world_node mock 提供 get_target_candidates），
## 对 multi_hit / radial_aoe / multi_projectile / stage_wide_aoe / cone_aoe / line_aoe
## 断言 executor 运行无错且可观察状态（last_type / 命中计数）符合预期。

const Executor = preload("res://scripts/boss/boss_attack_executor.gd")

const SUCCESS_MARKER := "ASHEN_BOSS_ATTACK_TYPES_OK"
var _failures: Array[String] = []


class MockWorld:
	extends Node3D
	var candidates: Array = []
	func get_target_candidates() -> Array:
		return candidates


class RecordingTarget:
	extends Node3D
	var hits := 0
	var last_damage := 0.0
	func is_targetable() -> bool:
		return true
	func receive_hit(damage, stagger, hit_direction, source) -> void:
		hits += 1
		last_damage = float(damage)
	func receive_hit_payload(payload: Dictionary) -> void:
		receive_hit(
			float(payload.get("damage", 0.0)),
			float(payload.get("stagger", 0.0)),
			payload.get("direction", Vector3.ZERO),
			payload.get("source")
		)


## 全部节点需在树内执行（executor 对未入树节点按防御约定跳过），故延后到首帧 idle。
func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_global_time()
	_test_multi_hit()
	_test_radial_aoe()
	_test_stage_wide_aoe()
	_test_cone_aoe()
	_test_line_aoe()
	_test_multi_projectile()
	_test_unknown_type_records()
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_global_time() -> void:
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale must start at 1.0.")


func _test_multi_hit() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var target := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(target)
	attacker.global_position = Vector3.ZERO
	target.global_position = Vector3(2.0, 0.0, 0.0)
	ex.execute_active(attacker, target, {"type": "multi_hit", "hits": 3, "damage": 10.0, "stagger": 5.0})
	_expect(ex.last_type == "multi_hit", "multi_hit should record last_type.")
	_expect(ex.last_multi_hits == 3, "multi_hit should strike 3 times, got %d." % ex.last_multi_hits)
	_expect(target.hits >= 3, "multi_hit should hit the main target 3 times, got %d." % target.hits)
	_expect(is_equal_approx(target.last_damage, 10.0), "multi_hit should pass attack damage.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "multi_hit must not touch time_scale.")
	attacker.free()
	target.free()


func _test_radial_aoe() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var world := MockWorld.new()
	var close_a := RecordingTarget.new()
	var close_b := RecordingTarget.new()
	var far := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(world)
	root.add_child(close_a)
	root.add_child(close_b)
	root.add_child(far)
	attacker.global_position = Vector3.ZERO
	close_a.global_position = Vector3(2.0, 0.0, 0.0)
	close_b.global_position = Vector3(0.0, 0.0, 3.0)
	far.global_position = Vector3(0.0, 0.0, 9.0)
	world.candidates = [close_a, close_b, far]
	attacker.set_meta("g06_world", world)
	ex.execute_active(attacker, close_a, {"type": "radial_aoe", "range": 5.0, "damage": 12.0, "stagger": 6.0})
	_expect(ex.last_type == "radial_aoe", "radial_aoe should record last_type.")
	_expect(ex.last_aoe_hits == 2, "radial_aoe should hit 2 candidates in range, got %d." % ex.last_aoe_hits)
	_expect(close_a.hits >= 1 and close_b.hits >= 1, "radial_aoe should damage in-range candidates.")
	_expect(far.hits == 0, "radial_aoe should skip out-of-range candidate.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "radial_aoe must not touch time_scale.")
	attacker.free()
	world.free()
	close_a.free()
	close_b.free()
	far.free()


func _test_stage_wide_aoe() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var world := MockWorld.new()
	var a := RecordingTarget.new()
	var b := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(world)
	root.add_child(a)
	root.add_child(b)
	attacker.global_position = Vector3.ZERO
	a.global_position = Vector3(6.0, 0.0, 0.0)
	b.global_position = Vector3(-7.0, 0.0, 0.0)
	world.candidates = [a, b]
	attacker.set_meta("g06_world", world)
	ex.execute_active(attacker, a, {"type": "stage_wide_aoe", "range": 30.0, "damage": 20.0, "stagger": 22.0})
	_expect(ex.last_type == "stage_wide_aoe", "stage_wide_aoe should record last_type.")
	_expect(ex.last_aoe_hits == 2, "stage_wide_aoe should cover all arena candidates, got %d." % ex.last_aoe_hits)
	_expect(a.hits >= 1 and b.hits >= 1, "stage_wide_aoe should damage both candidates.")
	attacker.free()
	world.free()
	a.free()
	b.free()


func _test_cone_aoe() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var world := MockWorld.new()
	var front := RecordingTarget.new()
	var diagonal := RecordingTarget.new()
	var behind := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(world)
	root.add_child(front)
	root.add_child(diagonal)
	root.add_child(behind)
	attacker.global_position = Vector3.ZERO
	front.global_position = Vector3(0.0, 0.0, -4.0)
	diagonal.global_position = Vector3(3.0, 0.0, -3.0)
	behind.global_position = Vector3(0.0, 0.0, 4.0)
	world.candidates = [front, diagonal, behind]
	attacker.set_meta("g06_world", world)
	ex.execute_active(attacker, front, {"type": "cone_aoe", "range": 6.0, "damage": 15.0, "stagger": 8.0})
	_expect(ex.last_type == "cone_aoe", "cone_aoe should record last_type.")
	_expect(ex.last_aoe_hits == 2, "cone_aoe should hit front+diagonal, got %d." % ex.last_aoe_hits)
	_expect(front.hits >= 1 and diagonal.hits >= 1, "cone_aoe should hit front candidates.")
	_expect(behind.hits == 0, "cone_aoe should exclude behind-candidate via forward dot.")
	attacker.free()
	world.free()
	front.free()
	diagonal.free()
	behind.free()


func _test_line_aoe() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var world := MockWorld.new()
	var front := RecordingTarget.new()
	var lateral := RecordingTarget.new()
	var behind := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(world)
	root.add_child(front)
	root.add_child(lateral)
	root.add_child(behind)
	attacker.global_position = Vector3.ZERO
	front.global_position = Vector3(0.0, 0.0, -5.0)
	lateral.global_position = Vector3(4.0, 0.0, -5.0)
	behind.global_position = Vector3(0.0, 0.0, 2.0)
	world.candidates = [front, lateral, behind]
	attacker.set_meta("g06_world", world)
	ex.execute_active(attacker, front, {"type": "line_aoe", "length": 10.0, "width": 2.0, "damage": 18.0, "stagger": 12.0})
	_expect(ex.last_type == "line_aoe", "line_aoe should record last_type.")
	_expect(ex.last_aoe_hits == 1, "line_aoe should hit only the on-line target, got %d." % ex.last_aoe_hits)
	_expect(front.hits >= 1, "line_aoe should damage the in-front target.")
	_expect(lateral.hits == 0 and behind.hits == 0, "line_aoe should skip lateral/behind targets.")
	attacker.free()
	world.free()
	front.free()
	lateral.free()
	behind.free()


func _test_multi_projectile() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var world := MockWorld.new()
	var target := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(world)
	root.add_child(target)
	attacker.global_position = Vector3.ZERO
	target.global_position = Vector3(0.0, 0.0, -5.0)
	world.candidates = [target]
	attacker.set_meta("g06_world", world)
	ex.execute_active(attacker, target, {"type": "multi_projectile", "count": 4, "damage": 8.0, "stagger": 8.0})
	_expect(ex.last_type == "multi_projectile", "multi_projectile should record last_type.")
	_expect(ex.last_projectiles == 4, "multi_projectile should spawn 4 projectiles, got %d." % ex.last_projectiles)
	_expect(world.get_child_count() >= 4, "Projectiles should be parented under the mock world.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "multi_projectile must not touch time_scale.")
	attacker.free()
	world.free()
	target.free()


func _test_unknown_type_records() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var target := RecordingTarget.new()
	root.add_child(attacker)
	root.add_child(target)
	attacker.global_position = Vector3.ZERO
	target.global_position = Vector3(1.0, 0.0, 0.0)
	ex.execute_active(attacker, target, {"type": "totally_unknown_type", "damage": 5.0})
	_expect(ex.last_type == "totally_unknown_type", "Unknown type should still record last_type.")
	_expect(target.hits == 0, "Unknown type should not apply damage.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Unknown type must not touch time_scale.")
	attacker.free()
	target.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
