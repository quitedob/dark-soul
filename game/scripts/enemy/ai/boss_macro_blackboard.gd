# game/scripts/enemy/ai/boss_macro_blackboard.gd
class_name BossMacroBlackboard
extends RefCounted
## G-01：Boss 宏决策黑板（BT ↔ FSM 共享状态）
## LimboAI 落地后可将同名字段映射到 BTBlackboard；见 limboai_plugin_path.gd

## 宏意图：patrol / engage / disengage / phase / heal_punish
var intent: StringName = &"patrol"
## 当前仇恨目标（可选引用，测试可留空）
var target: Node3D = null
## 到目标的水平距离
var target_distance: float = INF
## 目标是否在圣地泡内（脱战触发）
var target_in_sanctuary: bool = false
## 是否持有有效目标
var has_valid_target: bool = false
## 是否已进入交战
var engaged: bool = false
## 生命比例 0–1
var health_ratio: float = 1.0
## 当前阶段 1/2/3
var current_phase: int = 1
## 玩家是否正在治疗（由 enemy 钩子写入）
var player_healing: bool = false
## 治疗惩罚冷却剩余秒
var punish_skill_cooldown: float = 0.0
## 传给 FSM 的招式/距离档标签
var selected_attack: String = ""
## 仇恨半径
var aggro_range: float = 17.0
## 脱战半径
var disengage_range: float = 26.0
## 拴绳半径（相对出生点）
var leash_range: float = 30.0
## 距出生点水平距离
var distance_from_home: float = 0.0
## 治疗惩罚最大触发距离（米）
var heal_punish_range: float = 8.0
## 阶段阈值（可内容覆盖）
var phase_two_cut: float = 0.5
var phase_three_cut: float = 0.25
## 近/中距离分界
var close_bracket: float = 2.0
var mid_bracket: float = 3.5


## 重置为巡逻默认态
func reset() -> void:
	intent = &"patrol"
	target = null
	target_distance = INF
	target_in_sanctuary = false
	has_valid_target = false
	engaged = false
	health_ratio = 1.0
	current_phase = 1
	player_healing = false
	punish_skill_cooldown = 0.0
	selected_attack = ""
	distance_from_home = 0.0


## 从敌人体同步感知字段（不改写 intent）
func sync_from_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	has_valid_target = bool(enemy.get("_cached_has_target"))
	target_distance = float(enemy.get("_cached_distance_to_target"))
	engaged = bool(enemy.get("engaged"))
	health_ratio = float(enemy.call("get_health_ratio")) if enemy.has_method("get_health_ratio") else 1.0
	aggro_range = float(enemy.get("aggro_range"))
	disengage_range = float(enemy.get("disengage_range"))
	leash_range = float(enemy.get("leash_range"))
	punish_skill_cooldown = float(enemy.get("_heal_punish_cooldown"))
	var spawn: Vector3 = enemy.get("spawn_origin")
	# 未入树时避免 Node3D.global_position 报错，回退本地 position
	var pos: Vector3 = enemy.position if enemy is Node3D else Vector3.ZERO
	if enemy is Node3D and enemy.is_inside_tree():
		pos = (enemy as Node3D).global_position
	var dx := pos.x - spawn.x
	var dz := pos.z - spawn.z
	distance_from_home = sqrt(dx * dx + dz * dz)
	if enemy.has_method("_target_is_in_sanctuary"):
		target_in_sanctuary = bool(enemy.call("_target_is_in_sanctuary"))
	if enemy.has_method("_phase_two_cut"):
		phase_two_cut = float(enemy.call("_phase_two_cut"))
	if enemy.has_method("_phase_three_cut"):
		var three := float(enemy.call("_phase_three_cut"))
		phase_three_cut = three if three >= 0.0 else -1.0
	current_phase = compute_phase()
	var t = enemy.get("target_node")
	target = t as Node3D if t is Node3D else null


## 按生命比例计算阶段
func compute_phase() -> int:
	if phase_three_cut >= 0.0 and health_ratio <= phase_three_cut:
		return 3
	if health_ratio <= phase_two_cut:
		return 2
	return 1


## 是否应脱战回巢
func should_disengage() -> bool:
	if not has_valid_target:
		return engaged or intent == &"phase" or intent == &"engage"
	if target_in_sanctuary:
		return true
	if target_distance > disengage_range:
		return true
	if distance_from_home > leash_range:
		return true
	return false


## 导出字典（调试 / 合约 / 未来 LimboAI 同步）
func to_dict() -> Dictionary:
	return {
		"intent": String(intent),
		"target_distance": target_distance,
		"target_in_sanctuary": target_in_sanctuary,
		"has_valid_target": has_valid_target,
		"engaged": engaged,
		"health_ratio": health_ratio,
		"current_phase": current_phase,
		"player_healing": player_healing,
		"punish_skill_cooldown": punish_skill_cooldown,
		"selected_attack": selected_attack,
		"distance_from_home": distance_from_home,
	}
