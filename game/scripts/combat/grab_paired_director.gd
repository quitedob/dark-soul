extends RefCounted
class_name GrabPairedDirector
## 程序化抓投配对：吸附 + 事件点伤害，不走 CombatArea

signal damage_applied(victim: Node, amount: float)
signal cancelled(reason: StringName)
signal finished(victim: Node)

var initiator: Node3D = null
var victim: Node3D = null
var profile = null
var active := false
var damage_done := false
var elapsed := 0.0
var _claim_ok := false


func begin(init: Node3D, vict: Node3D, grab_profile) -> bool:
	force_cancel(&"restart")
	if init == null or vict == null or grab_profile == null:
		return false
	if vict.has_method("is_targetable") and not vict.is_targetable():
		return false
	initiator = init
	victim = vict
	profile = grab_profile
	active = true
	damage_done = false
	elapsed = 0.0
	_claim_ok = true
	if victim.has_method("begin_grabbed"):
		victim.begin_grabbed(initiator, float(profile.hold_seconds))
	if victim.has_method("set_grab_pose_lock"):
		victim.set_grab_pose_lock(true)
	_apply_pose(1.0)
	return true


func update(delta: float) -> void:
	if not active:
		return
	if not _is_pair_valid():
		force_cancel(&"invalid_pair")
		return
	elapsed += delta
	_apply_pose(clampf(delta * 12.0, 0.0, 1.0))
	if not damage_done and elapsed >= float(profile.damage_event_seconds):
		_apply_damage_once()
	if elapsed >= float(profile.hold_seconds):
		_finish_ok()


func force_cancel(reason: StringName = &"cancel") -> void:
	if not active and victim == null:
		return
	var v := victim
	_release_pose_lock()
	if v != null and is_instance_valid(v) and v.has_method("end_grabbed"):
		v.end_grabbed(initiator)
	active = false
	initiator = null
	victim = null
	profile = null
	damage_done = false
	elapsed = 0.0
	_claim_ok = false
	cancelled.emit(reason)


func is_holding(node: Node) -> bool:
	return active and victim == node


func get_hold_point() -> Vector3:
	if initiator == null or profile == null or not is_instance_valid(initiator):
		return Vector3.ZERO
	if not initiator.is_inside_tree():
		return initiator.position + Vector3(profile.hold_socket_offset)
	var local: Vector3 = profile.hold_socket_offset
	return initiator.global_position + initiator.global_transform.basis * local


func _finish_ok() -> void:
	var v := victim
	_release_pose_lock()
	if v != null and is_instance_valid(v) and v.has_method("end_grabbed"):
		v.end_grabbed(initiator)
	active = false
	finished.emit(v)
	initiator = null
	victim = null
	profile = null
	damage_done = false
	elapsed = 0.0
	_claim_ok = false


func _apply_damage_once() -> void:
	if damage_done or victim == null or profile == null:
		return
	damage_done = true
	var amount := float(profile.grab_damage)
	var dir := (victim.global_position - initiator.global_position)
	if dir.length_squared() < 0.001:
		dir = -initiator.global_transform.basis.z
	else:
		dir = dir.normalized()
	if victim.has_method("receive_hit"):
		victim.receive_hit(amount, 28.0, dir, initiator)
	damage_applied.emit(victim, amount)


func _apply_pose(weight: float) -> void:
	if initiator == null or victim == null or profile == null:
		return
	if not initiator.is_inside_tree() or not victim.is_inside_tree():
		return
	var hold := get_hold_point()
	victim.global_position = victim.global_position.lerp(hold, weight)
	var face := initiator.global_position - victim.global_position
	face.y = 0.0
	if face.length_squared() > 0.001 and victim.has_method("_face_direction"):
		victim._face_direction(face.normalized(), weight * 14.0)
	elif face.length_squared() > 0.001 and victim is Node3D:
		var yaw := atan2(-face.x, -face.z)
		victim.rotation.y = lerp_angle(victim.rotation.y, yaw, weight)


func _release_pose_lock() -> void:
	if victim != null and is_instance_valid(victim) and victim.has_method("set_grab_pose_lock"):
		victim.set_grab_pose_lock(false)


func _is_pair_valid() -> bool:
	if initiator == null or victim == null or not is_instance_valid(initiator) or not is_instance_valid(victim):
		return false
	if "health" in initiator and float(initiator.health) <= 0.0:
		return false
	if victim.has_method("is_targetable") and not victim.is_targetable():
		return false
	return _claim_ok
