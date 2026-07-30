extends SceneTree
## Guard Meter / 直接击穿 / Execution claim 合约

const GuardResolver = preload("res://scripts/combat/guard_resolver.gd")
const HandEq = preload("res://scripts/data/hand_equipment.gd")
const ExecutionSolver = preload("res://scripts/combat/execution_solver.gd")
const ExecutionProfile = preload("res://scripts/combat/data/execution_profile.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_guard_meter_and_direct_break()
	_test_execution_profiles()
	_test_back_sector_logic()
	if _failures.is_empty():
		print("ASHEN_GUARD_EXECUTION_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_guard_meter_and_direct_break() -> void:
	var profile := HandEq.get_guard_profile("reliquary_shield")
	_expect(not profile.is_empty(), "Shield guard profile missing.")
	_expect(float(profile.get("max_guard_meter", 0.0)) > 0.0, "max_guard_meter missing.")

	var payload := {
		"damage": 20.0,
		"stagger": 10.0,
		"guard_damage": 30.0,
		"direction": Vector3(0, 0, 1),
		"blockable": true,
	}
	var fwd := Vector3(0, 0, -1)
	var held := GuardResolver.resolve(payload, true, fwd, 80.0, profile, 100.0)
	_expect(bool(held["guarded"]), "Frontal guard should succeed.")
	_expect(not bool(held["guard_broken"]), "30 guard_damage should not break meter.")
	_expect(float(held["guard_meter_remaining"]) < 100.0, "Meter should drain.")

	var direct_payload := payload.duplicate()
	direct_payload["guard_damage"] = 90.0
	var direct := GuardResolver.resolve(direct_payload, true, fwd, 80.0, profile, 100.0)
	_expect(bool(direct["guard_broken"]), "Direct break threshold should trip.")
	_expect(String(direct["guard_broken_reason"]) == "direct", "Reason should be direct.")

	var meter_payload := payload.duplicate()
	meter_payload["guard_damage"] = 40.0
	var meter := GuardResolver.resolve(meter_payload, true, fwd, 80.0, profile, 20.0)
	_expect(bool(meter["guard_broken"]), "Low meter should break.")
	_expect(String(meter["guard_broken_reason"]) == "meter", "Reason should be meter.")

	var stam := GuardResolver.resolve(payload, true, fwd, 1.0, profile, 100.0)
	_expect(bool(stam["guard_broken"]), "Low stamina should break.")
	_expect(String(stam["guard_broken_reason"]) == "stamina", "Reason should be stamina.")


func _test_execution_profiles() -> void:
	var riposte := ExecutionProfile.make_riposte()
	var backstab := ExecutionProfile.make_backstab()
	_expect(riposte.validate().is_empty(), "Riposte profile invalid.")
	_expect(backstab.validate().is_empty(), "Backstab profile invalid.")
	_expect(backstab.critical_multiplier > riposte.critical_multiplier, "Backstab should crit harder.")


func _test_back_sector_logic() -> void:
	var empty := ExecutionSolver.find_candidate(null, [])
	_expect(empty.is_empty(), "Null attacker must yield empty candidate.")
	_test_enemy_claim_api()


func _test_enemy_claim_api() -> void:
	var EnemyScript = load("res://scripts/enemy.gd")
	var enemy = EnemyScript.new()
	enemy.guardian = false
	enemy.supports_riposte = true
	enemy.supports_backstab = true
	enemy.state = enemy.State.PARRY_VULNERABLE
	_expect(enemy.is_execution_candidate(&"parry"), "Parry vuln should be riposte candidate.")
	_expect(not enemy.is_execution_candidate(&"back"), "Parry vuln should not be backstab candidate.")
	var claimer_a = Node.new()
	var claimer_b = Node.new()
	_expect(enemy.try_claim_execution(claimer_a, 1.0), "First claim should succeed.")
	_expect(not enemy.try_claim_execution(claimer_b, 1.0), "Second claim must fail.")
	enemy.release_execution_claim(claimer_a)
	enemy.state = enemy.State.IDLE
	_expect(enemy.is_execution_candidate(&"back"), "Idle humanoid may be backstabbed.")
	enemy.guardian = true
	_expect(not enemy.is_execution_candidate(&"back"), "Boss must not allow backstab.")
	claimer_a.free()
	claimer_b.free()
	enemy.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
