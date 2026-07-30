extends RefCounted
class_name ExecutionSolver
## 处决候选筛选：人型 riposte/背刺 + Boss 弱点

const ExecutionProfileScript = preload("res://scripts/combat/data/execution_profile.gd")


static func find_candidate(
		attacker: Node3D,
		candidates: Array,
		prefer_backstab: bool = false
) -> Dictionary:
	if attacker == null or not is_instance_valid(attacker):
		return {}
	var best := {}
	var best_score := -INF
	for raw in candidates:
		if raw == null or not is_instance_valid(raw) or not (raw is Node3D):
			continue
		var target: Node3D = raw
		if target == attacker:
			continue
		if target.has_method("is_targetable") and not target.is_targetable():
			continue
		var weak := _score_weak_point(attacker, target)
		var front := _score_front(attacker, target)
		var back := _score_back(attacker, target)
		for option in [weak, front, back]:
			if option.is_empty():
				continue
			var score := float(option.get("score", -INF))
			if prefer_backstab and option.get("kind") == &"back":
				score += 15.0
			if score > best_score:
				best = option
				best_score = score
	return best


static func _score_weak_point(attacker: Node3D, target: Node3D) -> Dictionary:
	if not target.has_method("is_execution_candidate"):
		return {}
	if not target.is_execution_candidate(&"weak_point"):
		return {}
	var boss_profile = null
	if target.has_method("get_boss_break_profile"):
		boss_profile = target.get_boss_break_profile()
	var profile = ExecutionProfileScript.make_weak_point(boss_profile)
	if not _in_range_near_anchor(attacker, target, profile):
		return {}
	var dist := attacker.global_position.distance_to(target.global_position)
	return {
		"target": target,
		"kind": &"weak_point",
		"profile": profile,
		"score": 130.0 - dist,
	}


static func _score_front(attacker: Node3D, target: Node3D) -> Dictionary:
	if not target.has_method("is_execution_candidate"):
		return {}
	var kind := &""
	if target.is_execution_candidate(&"parry"):
		kind = &"parry"
	elif target.is_execution_candidate(&"guard_break"):
		kind = &"guard_break"
	else:
		return {}
	var profile = (
		ExecutionProfileScript.make_riposte()
		if kind == &"parry"
		else ExecutionProfileScript.make_guard_break_riposte()
	)
	if not _in_range_and_front_sector(attacker, target, profile):
		return {}
	var dist := attacker.global_position.distance_to(target.global_position)
	return {
		"target": target,
		"kind": kind,
		"profile": profile,
		"score": 100.0 - dist,
	}


static func _score_back(attacker: Node3D, target: Node3D) -> Dictionary:
	if not target.has_method("is_execution_candidate"):
		return {}
	if not target.is_execution_candidate(&"back"):
		return {}
	var profile = ExecutionProfileScript.make_backstab()
	if not _in_range_and_back_sector(attacker, target, profile):
		return {}
	var dist := attacker.global_position.distance_to(target.global_position)
	return {
		"target": target,
		"kind": &"back",
		"profile": profile,
		"score": 90.0 - dist,
	}


static func _in_range_near_anchor(attacker: Node3D, target: Node3D, profile: Resource) -> bool:
	var anchor := target.global_position + Vector3.UP * 1.5
	if target.has_method("get_execution_anchor"):
		anchor = target.get_execution_anchor(profile.required_anchor)
	var dist := attacker.global_position.distance_to(anchor)
	if dist > float(profile.interaction_distance):
		return false
	var to_anchor := anchor - attacker.global_position
	to_anchor.y = 0.0
	var fwd := -attacker.global_transform.basis.z
	fwd.y = 0.0
	if to_anchor.length_squared() < 0.001 or fwd.length_squared() < 0.001:
		return true
	var cos_limit := cos(deg_to_rad(float(profile.interaction_angle_degrees)))
	return fwd.normalized().dot(to_anchor.normalized()) >= cos_limit


static func _in_range_and_front_sector(attacker: Node3D, target: Node3D, profile: Resource) -> bool:
	var to_target := target.global_position - attacker.global_position
	to_target.y = 0.0
	if to_target.length() > float(profile.interaction_distance):
		return false
	var attacker_fwd := -attacker.global_transform.basis.z
	attacker_fwd.y = 0.0
	if attacker_fwd.length_squared() < 0.001 or to_target.length_squared() < 0.001:
		return false
	var cos_limit := cos(deg_to_rad(float(profile.interaction_angle_degrees)))
	if attacker_fwd.normalized().dot(to_target.normalized()) < cos_limit:
		return false
	var target_fwd := -target.global_transform.basis.z
	target_fwd.y = 0.0
	var toward_attacker := attacker.global_position - target.global_position
	toward_attacker.y = 0.0
	if target_fwd.length_squared() > 0.001 and toward_attacker.length_squared() > 0.001:
		if target_fwd.normalized().dot(toward_attacker.normalized()) < 0.15:
			return false
	return true


static func _in_range_and_back_sector(attacker: Node3D, target: Node3D, profile: Resource) -> bool:
	var to_attacker := attacker.global_position - target.global_position
	to_attacker.y = 0.0
	if to_attacker.length() > float(profile.interaction_distance):
		return false
	var target_fwd := -target.global_transform.basis.z
	target_fwd.y = 0.0
	if target_fwd.length_squared() < 0.001 or to_attacker.length_squared() < 0.001:
		return false
	var back_dot := target_fwd.normalized().dot(to_attacker.normalized())
	var cos_back := -cos(deg_to_rad(float(profile.interaction_angle_degrees) * 0.5))
	return back_dot <= cos_back
