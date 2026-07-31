class_name WeaponArtData
extends Resource

@export var art_id: StringName
## 分发键：pierce_thrust / colossal_leap / crescent_leap / arcane_barrage / divine_smite / guard_counter
## guard_counter 为数据驱动反制类（伏火偏转 / 推盾反制），player 兜底仅认 entry_attack 的 &"leap" tag
@export var art_kind: StringName = &""
@export var stance_animation: StringName
@export var entry_attack: AttackData
@export var light_branch: AttackData
@export var heavy_branch: AttackData
@export var guard_success_branch: AttackData
@export var requires_guard_success := false
@export_range(0.0, 60.0, 0.5) var cooldown_seconds := 0.0
@export var uses_per_rest := 0
@export_group("Costs")
@export_range(0.0, 200.0, 0.5) var focus_cost := 0.0
@export_range(0.0, 200.0, 0.5) var stamina_cost := 0.0
@export_group("Timeline")
@export_range(0.0, 5.0, 0.01) var windup_seconds := 0.0
@export_range(0.0, 5.0, 0.01) var recovery_seconds := 0.0
## 是否可被普通攻击打断（L-13 成本规则：纯进攻型多为不可打断，反制型承担失败恢复）
@export var interruptible := true
@export_group("Preconditions")
## 位置/姿态前置：guard_success / back / line / airborne ...
@export var positional_precondition: StringName = &""
@export var art_tags: Array[StringName] = []


## L-13 成本规则：每个兵器诀至少承担以下成本中的两项
## （Focus / 精力 / 前摇·后摇 / 可打断 / 冷却·休息次数 / 位置·格挡前置）
func cost_signal_count() -> int:
	var count := 0
	if focus_cost > 0.0:
		count += 1
	if stamina_cost > 0.0:
		count += 1
	if windup_seconds > 0.0 or recovery_seconds > 0.0:
		count += 1
	if not interruptible:
		count += 1
	if cooldown_seconds > 0.0 or uses_per_rest > 0:
		count += 1
	if requires_guard_success or not positional_precondition.is_empty():
		count += 1
	return count


func validate() -> Array[String]:
	var errors: Array[String] = []
	if art_id.is_empty():
		errors.append("WeaponArtData art_id is empty.")
	if cost_signal_count() < 2:
		errors.append("WeaponArtData %s must carry at least 2 cost/precondition signals (L-13)." % art_id)
	for attack in [entry_attack, light_branch, heavy_branch, guard_success_branch]:
		if attack != null:
			errors.append_array(attack.validate())
	return errors


static func make(kind: StringName, art_id: StringName = &"") -> Resource:
	var art = load("res://scripts/combat/data/weapon_art_data.gd").new()
	art.art_kind = kind
	art.art_id = art_id if not art_id.is_empty() else kind
	return art
