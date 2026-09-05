extends RefCounted
## G-05：锁敌取景解算器——纯静态数学（偏航/俯仰/臂长/指数权重）。
## Dark Souls-style lock-on framing: the camera stays anchored behind the player,
## slowly tracks the player→target line while strafing, and the boom widens with
## separation so both stay framed. All funcs are scene-free and headless-testable.

const MIDPOINT_BIAS := 0.55
const YAW_TRACK_SPEED := 2.2
const PITCH_SPEED := 3.5
const BOOM_SPEED := 3.0
const PITCH_MIN := -0.65
const PITCH_MAX := 0.30
const BOOM_GAIN := 0.30
const BOOM_BASE := 5.2
const BOOM_MAX := 7.4


## 期望偏航：rig 前向（-Z）对准玩家→目标的水平连线（atan2(-fwd.x, -fwd.z)）。
## 退化情形（目标在正上/正下，水平分量近零）保持当前偏航。
static func desired_yaw(player_pos: Vector3, target_point: Vector3, current_yaw: float) -> float:
	var to_target: Vector3 = target_point - player_pos
	var horizontal: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	if horizontal.length_squared() < 0.0001:
		return current_yaw
	var fwd: Vector3 = horizontal.normalized()
	return atan2(-fwd.x, -fwd.z)


## 期望俯仰：瞄准玩家头顶与目标胸口的加权中点；负值 = 抬镜头（沿用既有 rig
## 约定 rotation.x = -atan2(dy, h)），内部夹紧到 (PITCH_MIN, PITCH_MAX)。
static func desired_pitch(player_pos: Vector3, target_point: Vector3, rig_pos: Vector3) -> float:
	var player_head: Vector3 = player_pos + Vector3.UP * 1.45
	var mid: Vector3 = player_head.lerp(target_point, MIDPOINT_BIAS)
	var offset: Vector3 = mid - rig_pos
	var horizontal: float = Vector2(offset.x, offset.z).length()
	var pitch: float = -atan2(offset.y, maxf(horizontal, 0.01))
	return clampf(pitch, PITCH_MIN, PITCH_MAX)


## 期望臂长：随玩家与目标的分离距离展宽，保证两者同框，夹在 [base, max]。
static func desired_boom(separation: float, base_length := BOOM_BASE, max_length := BOOM_MAX, gain := BOOM_GAIN) -> float:
	return clampf(base_length + separation * gain, base_length, max_length)


## 帧率无关的指数平滑权重：1 - exp(-rate * delta)。
static func exp_weight(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
