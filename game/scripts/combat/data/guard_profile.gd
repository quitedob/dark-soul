class_name GuardProfile
extends Resource
## 防具格挡档案：吸收、稳定性、Guard Meter 与盾重分级

## 盾重：影响稳定性与破防阈值作者化区间
enum WeightClass {
	LIGHT = 0,
	MEDIUM = 1,
	HEAVY = 2,
}

@export var profile_id: StringName = &""
@export var weight_class: WeightClass = WeightClass.MEDIUM
@export_range(1.0, 180.0, 1.0) var guard_angle_degrees := 120.0
@export_range(0.0, 1.0, 0.01) var physical_absorption := 0.80
@export_range(0.0, 0.95, 0.01) var stability := 0.65
@export_range(0.0, 500.0, 1.0) var max_guard_meter := 100.0
@export_range(0.0, 500.0, 1.0) var direct_break_threshold := 75.0
@export_range(0.0, 4.0, 0.05) var guard_meter_damage_multiplier := 1.0
@export_range(0.0, 4.0, 0.05) var stamina_damage_multiplier := 1.0
@export var can_parry := false
@export var parry_start_seconds := 0.10
@export var parry_active_seconds := 0.12
@export var parry_recovery_seconds := 0.42
@export var parry_miss_multiplier := 1.0
@export var parry_stamina_cost := 10.0


## 按盾重返回推荐稳定性区间中点（作者化起点，可再微调）
static func recommended_stability(weight: WeightClass) -> float:
	match weight:
		WeightClass.LIGHT:
			return 0.45
		WeightClass.HEAVY:
			return 0.85
	return 0.72


## 按盾重返回推荐直接击穿阈值
static func recommended_direct_break(weight: WeightClass) -> float:
	match weight:
		WeightClass.LIGHT:
			return 52.0
		WeightClass.HEAVY:
			return 110.0
	return 78.0


## 按盾重返回推荐 Guard Meter 上限
static func recommended_max_meter(weight: WeightClass) -> float:
	match weight:
		WeightClass.LIGHT:
			return 70.0
		WeightClass.HEAVY:
			return 160.0
	return 110.0


## 稳定性系数：重盾更耐打，轻盾更易破防
func stability_coefficient() -> float:
	match weight_class:
		WeightClass.LIGHT:
			return 0.85
		WeightClass.HEAVY:
			return 1.12
	return 1.0


## 生效稳定性（作者值 × 盾重系数，钳制到 0–0.95）
func effective_stability() -> float:
	return clampf(stability * stability_coefficient(), 0.0, 0.95)


## 生效直接击穿阈值（重盾抬高门槛）
func effective_direct_break_threshold() -> float:
	match weight_class:
		WeightClass.LIGHT:
			return direct_break_threshold * 0.92
		WeightClass.HEAVY:
			return direct_break_threshold * 1.15
	return direct_break_threshold
