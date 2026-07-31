# game/tests/smoke/g01_macro_bt_contract_test.gd
extends SceneTree
## G-01 合约：Boss 宏决策层可切换意图（兼容 BT / LimboAI 落地路径）

const BlackboardScript = preload("res://scripts/enemy/ai/boss_macro_blackboard.gd")
const MacroBTScript = preload("res://scripts/enemy/ai/boss_macro_bt.gd")
const LimboPathScript = preload("res://scripts/enemy/ai/limboai_plugin_path.gd")
const ControllerScript = preload("res://scripts/boss/boss_macro_controller.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_limbo_path_docs()
	_test_intent_switching()
	_test_phase_brackets()
	_test_controller_and_enemy_hook()
	if _failures.is_empty():
		print("G01_MACRO_BT_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _test_limbo_path_docs() -> void:
	# 无插件时应走兼容宏层
	_expect(not LimboPathScript.is_installed(), "LimboAI not expected in addons yet.")
	_expect(LimboPathScript.backend_id() == &"compat_macro", "Backend should be compat_macro.")
	var notes := LimboPathScript.install_instructions()
	_expect(notes.contains("game/addons/limboai"), "Install notes must name addon path.")
	_expect(notes.contains("github.com/limbonaut/limboai"), "Install notes must cite repo.")


func _test_intent_switching() -> void:
	var bb = BlackboardScript.new()
	var bt = MacroBTScript.new()
	# 默认 → patrol
	_expect(bt.tick(bb) == MacroBTScript.INTENT_PATROL, "Idle blackboard should patrol.")
	# 进仇恨 → engage/phase
	bb.has_valid_target = true
	bb.target_distance = 10.0
	bb.aggro_range = 17.0
	bb.engaged = false
	var engage_intent := bt.tick(bb)
	_expect(
		engage_intent == MacroBTScript.INTENT_ENGAGE or engage_intent == MacroBTScript.INTENT_PHASE,
		"In-aggro target should engage/phase, got %s" % String(engage_intent)
	)
	# 交战近战 → phase + CLOSE
	bb.engaged = true
	bb.target_distance = 1.5
	bb.health_ratio = 1.0
	_expect(bt.tick(bb) == MacroBTScript.INTENT_PHASE, "Engaged close should phase.")
	_expect(bb.selected_attack == "PHASE1_CLOSE", "P1 close bracket mismatch: %s" % bb.selected_attack)
	# 脱战：圣地
	bb.target_in_sanctuary = true
	_expect(bt.tick(bb) == MacroBTScript.INTENT_DISENGAGE, "Sanctuary should disengage.")
	bb.target_in_sanctuary = false
	# 脱战：超距
	bb.target_distance = 40.0
	bb.disengage_range = 26.0
	_expect(bt.tick(bb) == MacroBTScript.INTENT_DISENGAGE, "Far target should disengage.")
	# 治疗惩罚覆盖
	bb.target_distance = 5.0
	bb.player_healing = true
	bb.punish_skill_cooldown = 0.0
	_expect(bt.tick(bb) == MacroBTScript.INTENT_HEAL_PUNISH, "Healing should force heal_punish.")
	_expect(bb.selected_attack == "HEAL_PUNISH", "Heal punish attack tag missing.")
	# 冷却中不抢占
	bb.punish_skill_cooldown = 2.0
	_expect(bt.tick(bb) != MacroBTScript.INTENT_HEAL_PUNISH, "Cooldown must block heal_punish.")
	bb.player_healing = false
	bb.punish_skill_cooldown = 0.0
	# 死亡
	bb.health_ratio = 0.0
	_expect(bt.tick(bb) == MacroBTScript.INTENT_DEAD, "Zero HP should dead intent.")


func _test_phase_brackets() -> void:
	var bb = BlackboardScript.new()
	var bt = MacroBTScript.new()
	bb.has_valid_target = true
	bb.engaged = true
	bb.target_in_sanctuary = false
	bb.aggro_range = 20.0
	bb.disengage_range = 30.0
	bb.leash_range = 40.0
	# Phase 2 mid
	bb.health_ratio = 0.4
	bb.target_distance = 2.8
	_expect(bt.tick(bb) == MacroBTScript.INTENT_PHASE, "P2 mid should stay phase.")
	_expect(bb.current_phase == 2, "Phase should be 2.")
	_expect(bb.selected_attack == "PHASE2_MID", "Expected PHASE2_MID got %s" % bb.selected_attack)
	# Phase 3 long
	bb.health_ratio = 0.2
	bb.target_distance = 5.0
	bt.tick(bb)
	_expect(bb.current_phase == 3, "Phase should be 3.")
	_expect(bb.selected_attack == "PHASE3_LONG", "Expected PHASE3_LONG got %s" % bb.selected_attack)


func _test_controller_and_enemy_hook() -> void:
	var ctrl = ControllerScript.new()
	_expect(ctrl.backend == &"compat_macro", "Controller backend mismatch.")
	ctrl.blackboard.has_valid_target = true
	ctrl.blackboard.engaged = true
	ctrl.blackboard.target_distance = 2.0
	ctrl.blackboard.health_ratio = 0.8
	_expect(ctrl.tick_blackboard() == MacroBTScript.INTENT_PHASE, "Controller tick should phase.")
	ctrl.set_player_healing(true)
	ctrl.blackboard.target_distance = 4.0
	_expect(ctrl.tick_blackboard() == MacroBTScript.INTENT_HEAL_PUNISH, "Controller heal flag failed.")
	# 敌人体钩子：guardian 挂载宏层并可读意图
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup(null, null, null, Vector3.ZERO, true)
	_expect(enemy._macro_ai != null, "Guardian must mount macro AI.")
	_expect(enemy.get_macro_intent() == MacroBTScript.INTENT_PATROL, "Reset guardian should patrol.")
	# 模拟交战感知写缓存后刷新
	enemy._cached_has_target = true
	enemy._cached_distance_to_target = 2.2
	enemy.engaged = true
	enemy.health = enemy.max_health
	enemy._tick_macro_decision()
	_expect(enemy.get_macro_intent() == MacroBTScript.INTENT_PHASE, "Enemy hook should publish phase.")
	_expect(enemy.get_macro_selected_attack().begins_with("PHASE"), "Selected attack should be phase bracket.")
	enemy.queue_free()
