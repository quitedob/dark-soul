extends Resource
class_name ExecutionProfile
## 人型处决配置：正面反击 / 背刺；Boss 弱点另案

enum ExecutionType {
	FRONT_RIPOSTE,
	BACKSTAB,
	WEAK_POINT,
}

@export var profile_id: StringName = &"front_riposte"
@export var execution_type: int = ExecutionType.FRONT_RIPOSTE
@export var allowed_vulnerability: StringName = &"parry"
@export_range(0.1, 5.0, 0.05) var interaction_distance := 2.15
@export_range(1.0, 180.0, 1.0) var interaction_angle_degrees := 55.0
@export_range(0.1, 10.0, 0.05) var vulnerability_seconds := 2.0
@export_range(0.1, 10.0, 0.05) var critical_multiplier := 2.5
@export_range(0.05, 3.0, 0.01) var windup_seconds := 0.22
@export_range(0.05, 3.0, 0.01) var active_seconds := 0.18
@export_range(0.05, 3.0, 0.01) var recovery_seconds := 0.55
@export_range(0.0, 2.0, 0.01) var damage_event_seconds := 0.12
@export var initiator_animation: StringName = &"riposte"
@export var victim_animation: StringName = &"executed"
@export var required_anchor: StringName = &"chest"
@export var damage_event_name: StringName = &"critical_damage"
@export var allow_lethal_damage := true
@export_range(0.1, 5.0, 0.05) var claim_seconds := 2.8


static func make_riposte() -> Resource:
	# 弹反正面处决
	var p = load("res://scripts/combat/data/execution_profile.gd").new()
	p.profile_id = &"front_riposte"
	p.execution_type = ExecutionType.FRONT_RIPOSTE
	p.allowed_vulnerability = &"parry"
	p.critical_multiplier = 2.6
	p.required_anchor = &"chest"
	return p


static func make_guard_break_riposte() -> Resource:
	var p = make_riposte()
	p.profile_id = &"guard_break_riposte"
	p.allowed_vulnerability = &"guard_break"
	p.critical_multiplier = 2.4
	return p


static func make_backstab() -> Resource:
	var p = load("res://scripts/combat/data/execution_profile.gd").new()
	p.profile_id = &"backstab"
	p.execution_type = ExecutionType.BACKSTAB
	p.allowed_vulnerability = &"back"
	p.interaction_distance = 1.85
	p.interaction_angle_degrees = 70.0
	p.critical_multiplier = 3.0
	p.required_anchor = &"back"
	p.initiator_animation = &"backstab"
	return p


static func make_weak_point(boss_profile: Resource = null) -> Resource:
	# Boss 弱点处决：默认非致死，由 BossExecutionBreakProfile 覆盖
	var p = load("res://scripts/combat/data/execution_profile.gd").new()
	p.profile_id = &"weak_point"
	p.execution_type = ExecutionType.WEAK_POINT
	p.allowed_vulnerability = &"weak_point"
	p.interaction_distance = 3.2
	p.interaction_angle_degrees = 75.0
	p.critical_multiplier = 2.3
	p.windup_seconds = 0.28
	p.active_seconds = 0.35
	p.recovery_seconds = 0.7
	p.damage_event_seconds = 0.16
	p.required_anchor = &"furnace_core"
	p.initiator_animation = &"weak_point_strike"
	p.allow_lethal_damage = false
	p.claim_seconds = 3.4
	if boss_profile != null:
		p.interaction_distance = float(boss_profile.interaction_distance)
		p.interaction_angle_degrees = float(boss_profile.interaction_angle_degrees)
		p.critical_multiplier = float(boss_profile.critical_multiplier)
		p.required_anchor = boss_profile.weak_point_anchor
		p.allow_lethal_damage = bool(boss_profile.allow_lethal_on_execution)
		p.claim_seconds = float(boss_profile.expose_seconds) + 0.4
	return p


func validate() -> Array[String]:
	var errors: Array[String] = []
	if profile_id.is_empty():
		errors.append("ExecutionProfile profile_id is empty.")
	if interaction_distance <= 0.0 or critical_multiplier <= 0.0:
		errors.append("ExecutionProfile %s has invalid ranges." % profile_id)
	if damage_event_seconds > active_seconds:
		errors.append("ExecutionProfile %s damage event outside active." % profile_id)
	return errors
