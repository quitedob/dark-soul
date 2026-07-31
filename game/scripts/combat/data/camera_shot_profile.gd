extends Resource
class_name CameraShotProfile
## Boss 战斗短镜头：构图参数，不替代日常 orbit

@export var shot_id: StringName = &"weak_point_expose"
@export_range(0.1, 6.0, 0.05) var duration := 1.4
@export_range(1.5, 12.0, 0.05) var spring_length := 3.6
@export_range(-1.2, 0.6, 0.01) var pitch := -0.18
@export var look_at: StringName = &"weak_point"  # weak_point | boss_chest | grab_hold | subject
@export_range(0.0, 1.0, 0.01) var trauma := 0.25
@export_range(-20.0, 20.0, 0.5) var fov_delta := -4.0
@export_range(0.05, 2.0, 0.05) var blend_in := 0.25
@export_range(0.05, 2.0, 0.05) var blend_out := 0.35


static func make(shot_id: StringName, duration: float, spring: float, pitch_v: float, look: StringName, trauma_v: float, fov: float = -4.0) -> Resource:
	var p = load("res://scripts/combat/data/camera_shot_profile.gd").new()
	p.shot_id = shot_id
	p.duration = duration
	p.spring_length = spring
	p.pitch = pitch_v
	p.look_at = look
	p.trauma = trauma_v
	p.fov_delta = fov
	return p


static func catalog() -> Dictionary:
	return {
		&"weak_point_expose": make(&"weak_point_expose", 1.5, 3.4, -0.22, &"weak_point", 0.22, -5.0),
		&"weak_point_exec": make(&"weak_point_exec", 1.8, 2.9, -0.28, &"weak_point", 0.45, -7.0),
		&"grab_hold": make(&"grab_hold", 1.2, 3.8, -0.12, &"grab_hold", 0.55, -3.0),
		&"fate_halfbody": make(&"fate_halfbody", 2.4, 4.6, -0.08, &"boss_chest", 0.08, -2.0),
		# G-04：相变镜头（与 PhaseFocusProfile 对齐）
		&"phase_rise": make(&"phase_rise", 1.55, 5.4, -0.24, &"boss_chest", 0.38, -5.0),
		&"phase_overload": make(&"phase_overload", 1.85, 4.9, -0.32, &"boss_chest", 0.55, -8.0),
	}


func validate() -> Array[String]:
	var errors: Array[String] = []
	if shot_id.is_empty():
		errors.append("CameraShotProfile missing shot_id.")
	if duration <= 0.0 or spring_length <= 0.0:
		errors.append("CameraShotProfile %s invalid ranges." % shot_id)
	return errors
