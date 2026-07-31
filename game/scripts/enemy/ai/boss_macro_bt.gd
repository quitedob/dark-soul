# game/scripts/enemy/ai/boss_macro_bt.gd
class_name BossMacroBT
extends RefCounted
## G-01：兼容宏决策层（BT 风格 Selector）
## 无 LimboAI GDExtension 时用纯 GDScript 复刻文档树优先级；
## 微执行仍由 enemy.gd FSM（WINDUP/ACTIVE/RECOVERY）负责。

const INTENT_PATROL := &"patrol"
const INTENT_ENGAGE := &"engage"
const INTENT_DISENGAGE := &"disengage"
const INTENT_PHASE := &"phase"
const INTENT_HEAL_PUNISH := &"heal_punish"
const INTENT_DEAD := &"dead"


## 对黑板执行一轮 Selector；返回最终意图
func tick(bb: BossMacroBlackboard) -> StringName:
	if bb == null:
		return INTENT_PATROL
	# Sequence: Death Check
	if bb.health_ratio <= 0.0:
		return _commit(bb, INTENT_DEAD, "")
	# Sequence: Healing Punish（最高战斗覆盖）
	if _want_heal_punish(bb):
		return _commit(bb, INTENT_HEAL_PUNISH, "HEAL_PUNISH")
	# Sequence: Disengage / Return
	if bb.should_disengage():
		return _commit(bb, INTENT_DISENGAGE, "")
	# Sequence: Phase N Behavior（已交战且有目标）
	if bb.has_valid_target and (bb.engaged or bb.target_distance <= bb.aggro_range) and not bb.target_in_sanctuary:
		bb.current_phase = bb.compute_phase()
		var attack_id := _select_phase_attack(bb)
		if bb.engaged or bb.target_distance <= bb.aggro_range * 0.85:
			return _commit(bb, INTENT_PHASE, attack_id)
		return _commit(bb, INTENT_ENGAGE, attack_id)
	# Sequence: Patrol / Wander
	return _commit(bb, INTENT_PATROL, "")


## 是否满足治疗惩罚序列条件
func _want_heal_punish(bb: BossMacroBlackboard) -> bool:
	if not bb.player_healing:
		return false
	if bb.punish_skill_cooldown > 0.0:
		return false
	if not bb.has_valid_target:
		return false
	if bb.target_in_sanctuary:
		return false
	return bb.target_distance < bb.heal_punish_range


## 按距离档选择 PHASE{n}_CLOSE/MID/LONG
func _select_phase_attack(bb: BossMacroBlackboard) -> String:
	var phase := bb.compute_phase()
	var bracket := "CLOSE"
	if bb.target_distance > bb.mid_bracket:
		bracket = "LONG"
	elif bb.target_distance > bb.close_bracket:
		bracket = "MID"
	return "PHASE%d_%s" % [phase, bracket]


## 写入黑板并返回意图
func _commit(bb: BossMacroBlackboard, intent: StringName, attack: String) -> StringName:
	bb.intent = intent
	bb.selected_attack = attack
	bb.current_phase = bb.compute_phase() if intent != INTENT_DEAD else 0
	return intent


## 合法意图集合（合约用）
static func known_intents() -> Array[StringName]:
	return [
		INTENT_PATROL,
		INTENT_ENGAGE,
		INTENT_DISENGAGE,
		INTENT_PHASE,
		INTENT_HEAL_PUNISH,
		INTENT_DEAD,
	]
