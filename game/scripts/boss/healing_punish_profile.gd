# game/scripts/boss/healing_punish_profile.gd
extends Resource
class_name HealingPunishProfile
## Boss 治疗惩罚数据驱动配置：gap-close / ranged-snipe / AoE-burst

## Boss 内容 id（与 chapter boss.id / execution catalog 对齐）
@export var boss_id: StringName = &"boss_giant_gate"
## 冷却（秒），防止连点治疗反复打断
@export_range(0.5, 12.0, 0.1) var cooldown_sec := 2.4
## 前摇倍率（治疗打断通常更快）
@export_range(0.35, 1.0, 0.05) var windup_scale := 0.68
## gap-close 最大距离（含）
@export_range(1.0, 12.0, 0.1) var gap_close_max_dist := 5.5
## ranged-snipe 最小距离
@export_range(2.0, 20.0, 0.1) var ranged_snipe_min_dist := 5.0
## AoE burst 最大距离
@export_range(1.0, 10.0, 0.1) var aoe_burst_max_dist := 4.0
## AoE 最低阶段（相位门控）
@export_range(1, 3, 1) var aoe_min_phase := 2
## 优先变体列表（空则按距离自动选）
@export var prefer_variants: PackedStringArray = PackedStringArray()

## gap-close 招式覆盖（空字段用 catalog 默认）
@export var gap_close: Dictionary = {}
## ranged-snipe 招式覆盖
@export var ranged_snipe: Dictionary = {}
## AoE burst 招式覆盖（含 aoe_radius）
@export var aoe_burst: Dictionary = {}


func validate() -> Array[String]:
	# 校验关键导出字段是否合理
	var errors: Array[String] = []
	if boss_id.is_empty():
		errors.append("HealingPunishProfile missing boss_id.")
	if cooldown_sec <= 0.0:
		errors.append("HealingPunishProfile %s invalid cooldown_sec." % boss_id)
	if windup_scale <= 0.0:
		errors.append("HealingPunishProfile %s invalid windup_scale." % boss_id)
	return errors
