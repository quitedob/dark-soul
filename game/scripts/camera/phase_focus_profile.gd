extends RefCounted
## G-04：Boss 相变镜头焦点配置（增量扩展 CombatCameraDirector）

const CameraShotProfileScript = preload("res://scripts/combat/data/camera_shot_profile.gd")

## 相变镜头：拉远+抬高注视点，突出 Boss 起身
static func shot_for_phase(phase: int):
	match phase:
		3:
			return _make(
				&"phase_overload",
				1.85,
				4.9,
				-0.32,
				&"boss_chest",
				0.55,
				-8.0,
				0.28,
				Vector3(0.0, 2.35, 0.0)
			)
		2, _:
			return _make(
				&"phase_rise",
				1.55,
				5.4,
				-0.24,
				&"boss_chest",
				0.38,
				-5.0,
				0.32,
				Vector3(0.0, 1.95, 0.0)
			)


## 相变注视偏移（米）：相对 Boss 原点抬高胸口/头冠
static func focus_offset_for_phase(phase: int) -> Vector3:
	match phase:
		3:
			return Vector3(0.0, 2.35, 0.0)
		_:
			return Vector3(0.0, 1.95, 0.0)


static func catalog() -> Dictionary:
	return {
		&"phase_rise": shot_for_phase(2),
		&"phase_overload": shot_for_phase(3),
	}


static func _make(
	shot_id: StringName,
	duration: float,
	spring: float,
	pitch_v: float,
	look: StringName,
	trauma_v: float,
	fov: float,
	blend_in: float,
	_focus_offset: Vector3
):
	var p = CameraShotProfileScript.make(shot_id, duration, spring, pitch_v, look, trauma_v, fov)
	p.blend_in = blend_in
	p.blend_out = 0.4
	return p
