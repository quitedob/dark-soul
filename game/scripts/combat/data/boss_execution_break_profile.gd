extends Resource
class_name BossExecutionBreakProfile
## Boss 独立处决槽：与普通 Poise 分离

@export var boss_id: StringName = &"boss_giant_gate"
@export var display_name_key: StringName = &"巨阙"
@export var story_flag: StringName = &"ch1_guardian_fate"
@export_range(10.0, 500.0, 1.0) var max_execution_break := 100.0
@export_range(0.5, 8.0, 0.05) var expose_seconds := 3.2
@export_range(0.0, 0.5, 0.01) var story_floor_ratio := 0.10  # 处决后 HP 不低于此比例
@export var weak_point_anchor: StringName = &"furnace_core"
@export var weak_point_offset := Vector3(0.0, 1.8, 0.4)
@export_range(1.0, 6.0, 0.05) var interaction_distance := 3.2
@export_range(1.0, 180.0, 1.0) var interaction_angle_degrees := 70.0
@export_range(1.0, 8.0, 0.05) var critical_multiplier := 2.2
@export var allow_lethal_on_execution := false
@export var charged_break_bonus := 1.55  # 蓄力命中倍率
@export var leap_break_bonus := 1.35
@export var grab_enabled := true


func validate() -> Array[String]:
	var errors: Array[String] = []
	if boss_id.is_empty():
		errors.append("BossExecutionBreakProfile missing boss_id.")
	if max_execution_break <= 0.0:
		errors.append("Boss %s invalid max_execution_break." % boss_id)
	return errors
