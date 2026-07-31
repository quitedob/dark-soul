extends RefCounted
class_name ExecutionPairedDirector
## 处决配对框架（D-06）：锚点对齐、独占 claim、事件点伤害、取消恢复
## 由玩家 EXECUTE_* FSM 驱动；不自持总时长，避免与 state_time 双时钟

signal damage_applied(victim: Node, amount: float)
signal cancelled(reason: StringName)
signal finished(victim: Node)

var initiator: Node3D = null
var victim: Node3D = null
var profile = null
var kind: StringName = &""
var active := false
var damage_done := false
var _claim_held := false
var _anim_bridge = null


func begin(
		init: Node3D,
		vict: Node3D,
		exec_profile,
		exec_kind: StringName = &"parry",
		anim_bridge = null,
		already_claimed: bool = false
) -> bool:
	force_cancel(&"restart")
	if init == null or vict == null or exec_profile == null:
		return false
	if vict.has_method("is_targetable") and not vict.is_targetable():
		return false
	if already_claimed:
		_claim_held = true
	elif vict.has_method("try_claim_execution"):
		if not vict.try_claim_execution(init, float(exec_profile.claim_seconds)):
			if not _is_claimed_by(vict, init):
				return false
		_claim_held = true
	else:
		_claim_held = true
	initiator = init
	victim = vict
	profile = exec_profile
	kind = exec_kind
	active = true
	damage_done = false
	_anim_bridge = anim_bridge
	if _anim_bridge != null and _anim_bridge.has_method("travel_execution"):
		_anim_bridge.travel_execution(kind)
	update_pose(1.0)
	return true


func update_pose(delta_or_weight: float) -> void:
	# delta 时按 12*dt 插值；传入 >=1 视为瞬时贴齐
	if not active:
		return
	if not _is_pair_valid():
		force_cancel(&"invalid_pair")
		return
	var weight := delta_or_weight if delta_or_weight >= 1.0 else clampf(delta_or_weight * 12.0, 0.0, 1.0)
	_apply_pose(weight)


func try_damage_event(active_elapsed: float, damage_override: float = -1.0) -> bool:
	# 仅在 EXECUTE_ACTIVE 调用；active_elapsed 相对 active 阶段
	if not active or damage_done or profile == null:
		return false
	if active_elapsed < float(profile.damage_event_seconds):
		return false
	_apply_damage_once(damage_override)
	return damage_done


func complete(reason: StringName = &"finished") -> void:
	if not active:
		return
	var v := victim
	_release_claim()
	active = false
	finished.emit(v)
	_clear_refs()
	if reason != &"finished":
		cancelled.emit(reason)


func force_cancel(reason: StringName = &"cancel") -> void:
	if not active and victim == null:
		return
	var was_active := active
	_release_claim()
	active = false
	_clear_refs()
	if was_active:
		cancelled.emit(reason)


func is_holding(node: Node) -> bool:
	return active and victim == node


func get_anchor_world() -> Vector3:
	if victim == null or profile == null or not is_instance_valid(victim):
		return Vector3.ZERO
	if victim.has_method("get_execution_anchor"):
		return victim.get_execution_anchor(profile.required_anchor)
	return victim.global_position + Vector3.UP * 1.1


func _apply_damage_once(damage_override: float = -1.0) -> void:
	if damage_done or victim == null or profile == null or initiator == null:
		return
	damage_done = true
	var amount := damage_override
	if amount < 0.0:
		var base := 28.0
		var crit := 1.0
		if initiator.has_method("_current_moveset"):
			var moveset = initiator._current_moveset()
			if moveset != null and moveset.neutral_light != null:
				base = float(moveset.neutral_light.damage)
		if initiator.has_method("_current_weapon"):
			var weapon = initiator._current_weapon()
			if weapon != null and "critical_multiplier" in weapon:
				crit = float(weapon.critical_multiplier)
		amount = base * crit * float(profile.critical_multiplier)
	if victim.has_method("apply_execution_damage"):
		victim.apply_execution_damage(amount, bool(profile.allow_lethal_damage))
	elif victim.has_method("receive_hit"):
		victim.receive_hit(amount, 0.0, -initiator.global_transform.basis.z, initiator)
	damage_applied.emit(victim, amount)


func _apply_pose(weight: float) -> void:
	if initiator == null or victim == null or profile == null:
		return
	if not initiator.is_inside_tree() or not victim.is_inside_tree():
		return
	var anchor := get_anchor_world()
	var offset_dir := initiator.global_position - victim.global_position
	offset_dir.y = 0.0
	if offset_dir.length_squared() < 0.001:
		offset_dir = -victim.global_transform.basis.z
	var desired := anchor + offset_dir.normalized() * 0.15
	initiator.global_position = initiator.global_position.lerp(desired, weight)
	var face := victim.global_position - initiator.global_position
	face.y = 0.0
	if face.length_squared() > 0.001:
		var yaw := atan2(-face.x, -face.z)
		initiator.rotation.y = lerp_angle(initiator.rotation.y, yaw, weight)
	if "velocity" in initiator:
		initiator.velocity = Vector3.ZERO


func _release_claim() -> void:
	if not _claim_held:
		return
	_claim_held = false
	if victim != null and is_instance_valid(victim) and victim.has_method("release_execution_claim"):
		victim.release_execution_claim(initiator)


func _clear_refs() -> void:
	initiator = null
	victim = null
	profile = null
	kind = &""
	damage_done = false
	_anim_bridge = null
	_claim_held = false


func _is_claimed_by(target: Node, claimer: Node) -> bool:
	if target == null or claimer == null:
		return false
	if "_execution_claimer" in target:
		return target._execution_claimer == claimer
	return false


func _is_pair_valid() -> bool:
	if initiator == null or victim == null:
		return false
	if not is_instance_valid(initiator) or not is_instance_valid(victim):
		return false
	if "health" in initiator and float(initiator.health) <= 0.0:
		return false
	if victim.has_method("is_targetable") and not victim.is_targetable():
		return false
	return _claim_held
