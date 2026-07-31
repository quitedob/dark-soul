# game/scripts/enemy/ranged_ambush_behavior.gd
class_name RangedAmbushBehavior
extends RefCounted
## G-03：远程/伏击敌人的距离保持与后撤决策（水平面）

const DEFAULT_PREFERRED := 7.0
const DEFAULT_RETREAT := 4.2
const BAND := 1.4


## 从章节内容读取理想射程与后撤触发距
static func preferred_distance(content: Dictionary) -> float:
	return float(content.get("preferred_distance", DEFAULT_PREFERRED))


static func retreat_trigger(content: Dictionary) -> float:
	return float(content.get("retreat_trigger", DEFAULT_RETREAT))


## 计算水平期望速度：过近后撤，过远接近，理想带内静止
static func desired_horizontal_velocity(
		from: Vector3,
		to: Vector3,
		move_speed: float,
		preferred: float = DEFAULT_PREFERRED,
		retreat_at: float = DEFAULT_RETREAT
) -> Vector3:
	var offset := to - from
	offset.y = 0.0
	var dist := offset.length()
	if dist < 0.001:
		return Vector3.ZERO
	var dir := offset.normalized()
	# 贴脸：加速后撤
	if dist < retreat_at:
		return -dir * move_speed * 1.2
	# 超出理想带：拉近到射击位
	if dist > preferred + BAND:
		return dir * move_speed
	# 略近于理想：轻后撤
	if dist < preferred - BAND:
		return -dir * move_speed * 0.9
	return Vector3.ZERO


## 是否应进入射击前摇（在射程内且未贴脸）
static func should_fire(distance: float, attack_range: float, retreat_at: float = DEFAULT_RETREAT) -> bool:
	return distance <= attack_range and distance >= retreat_at * 0.65
