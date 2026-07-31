class_name MeridianSystem
extends RefCounted
## L-09：经脉系统纯逻辑（无状态）。读写 run_state.progression_values["meridian_<id>"]。
## 等级 0..5（5 级满），幂等累计：compute_bonuses 从等级重算总增益，重复调用安全。
##
## 用法（game_world）：
##   level  = MeridianSystem.level_for(progression_values, id)
##   check  = MeridianSystem.can_upgrade(progression_values, id, embers)
##   level  = MeridianSystem.upgrade(progression_values, id)   # 先扣烬再调用
##   bonus  = MeridianSystem.compute_bonuses(progression_values)

const MeridianDataScript = preload("res://scripts/player/meridian_data.gd")


static func level_for(progression, meridian_id: String) -> int:
	if progression == null:
		return 0
	var value = progression.get("meridian_" + meridian_id, 0)
	if not value is int:
		return 0
	return clampi(int(value), 0, MeridianDataScript.MAX_LEVEL)


## 下一级烬价；已满级返回 -1
static func upgrade_cost(level: int) -> int:
	if level >= MeridianDataScript.MAX_LEVEL:
		return -1
	var entry: Dictionary = MeridianDataScript.MATERIAL_COSTS.get(level, {})
	return int(entry.get("embers", 0))


## 指定当前等级对应的材料风味信息（升级提示用）
static func material_for(level: int) -> Dictionary:
	return (MeridianDataScript.MATERIAL_COSTS.get(level, {}) as Dictionary).duplicate()


## 只读校验；返回 {"ok", "reason", "cost", "next_level"}
static func can_upgrade(progression, meridian_id: String, embers: int) -> Dictionary:
	var level := level_for(progression, meridian_id)
	var cost := upgrade_cost(level)
	if cost < 0:
		return {"ok": false, "reason": "MAXED", "cost": 0, "next_level": level}
	if embers < cost:
		return {"ok": false, "reason": "NO_EMBERS", "cost": cost, "next_level": level + 1}
	return {"ok": true, "reason": "", "cost": cost, "next_level": level + 1}


## 写入升级（调用方应先校验并扣除烬）；返回新等级
static func upgrade(progression, meridian_id: String) -> int:
	var level := level_for(progression, meridian_id)
	if level >= MeridianDataScript.MAX_LEVEL:
		return level
	var next_level := level + 1
	progression["meridian_" + meridian_id] = next_level
	return next_level


## 幂等累计总增益。返回各效果类型的累计增量（乘数类为倍率，flat 类为加值）：
##   {max_health, max_stamina, max_focus, damage_mult, armor_pdr,
##    move_speed, focus_regen, roll_tier}
static func compute_bonuses(progression) -> Dictionary:
	var totals := {
		"max_health": 0.0, "max_stamina": 0.0, "max_focus": 0.0,
		"damage_mult": 1.0, "armor_pdr": 0.0, "move_speed": 1.0,
		"focus_regen": 1.0, "roll_tier": 0.0,
	}
	if progression == null:
		return totals
	for meridian in MeridianDataScript.all():
		var level := level_for(progression, String(meridian["id"]))
		if level <= 0:
			continue
		var effect_type := String(meridian["effect_type"])
		if not totals.has(effect_type):
			continue
		var amount := float(meridian["per_level"]) * float(level)
		# 乘数类以 1.0 为基、flat 类以 0 为基，统一累加即可
		totals[effect_type] = float(totals[effect_type]) + amount
	return totals


## 全部经脉等级合计（背包/提示统计用）
static func total_level(progression) -> int:
	var total := 0
	if progression == null:
		return total
	for meridian in MeridianDataScript.all():
		total += level_for(progression, String(meridian["id"]))
	return total
