# game/tests/unit/combat/test_execution_solver.gd
extends "res://addons/gut/test.gd"
## I-15：ExecutionSolver 背刺 / 反击 / 破防候选筛选

const ExecutionSolver = preload("res://scripts/combat/execution_solver.gd")


## 可配置处决 stub：仅实现 is_execution_candidate
class ExecStub extends Node3D:
	var kinds: Array = []

	func is_targetable() -> bool:
		return true

	func is_execution_candidate(kind: StringName) -> bool:
		return kinds.has(kind)


var attacker: Node3D
var target: ExecStub


func before_each() -> void:
	attacker = add_child_autofree(Node3D.new())
	target = add_child_autofree(ExecStub.new())
	# 攻击者在原点朝 -Z；目标在前方
	attacker.global_position = Vector3.ZERO
	attacker.look_at(Vector3(0, 0, -1), Vector3.UP)
	target.global_position = Vector3(0, 0, -1.2)


func after_each() -> void:
	await get_tree().process_frame


## 背刺：目标背对攻击者
func test_backstab_eligible_from_rear_sector() -> void:
	target.kinds = [&"back"]
	# 目标朝 -Z，攻击者在其身后 (0,0,0) → 相对目标为后方
	target.look_at(Vector3(0, 0, -2), Vector3.UP)
	attacker.global_position = Vector3(0, 0, 0.0)
	target.global_position = Vector3(0, 0, -1.2)
	var found := ExecutionSolver.find_candidate(attacker, [target], true)
	assert_false(found.is_empty(), "后方扇区应命中背刺")
	assert_eq(found.get("kind"), &"back")


## 正面不可背刺
func test_backstab_ineligible_from_front() -> void:
	target.kinds = [&"back"]
	# 目标朝向攻击者（面对）
	target.global_position = Vector3(0, 0, -1.2)
	target.look_at(attacker.global_position, Vector3.UP)
	var found := ExecutionSolver.find_candidate(attacker, [target], true)
	assert_true(found.is_empty() or found.get("kind") != &"back", "正面不应背刺")


## 弹反脆弱：正面 riposte
func test_riposte_eligible_during_parry_vulnerable() -> void:
	target.kinds = [&"parry"]
	target.global_position = Vector3(0, 0, -1.2)
	# 双方相向
	attacker.look_at(target.global_position, Vector3.UP)
	target.look_at(attacker.global_position, Vector3.UP)
	var found := ExecutionSolver.find_candidate(attacker, [target])
	assert_false(found.is_empty(), "弹反脆弱应可反击")
	assert_eq(found.get("kind"), &"parry")


## 破防可处决
func test_guard_broken_eligible_for_critical() -> void:
	target.kinds = [&"guard_break"]
	target.global_position = Vector3(0, 0, -1.2)
	attacker.look_at(target.global_position, Vector3.UP)
	target.look_at(attacker.global_position, Vector3.UP)
	var found := ExecutionSolver.find_candidate(attacker, [target])
	assert_false(found.is_empty(), "破防应可处决")
	assert_eq(found.get("kind"), &"guard_break")


## 空攻击者 / 无候选 → 空结果
func test_null_attacker_yields_empty() -> void:
	assert_true(ExecutionSolver.find_candidate(null, [target]).is_empty())
	assert_true(ExecutionSolver.find_candidate(attacker, []).is_empty())
