# game/scripts/enemy/behaviors/hazard_behavior.gd
extends RefCounted
## G-05：区域危害族 — ACTIVE 时挂短时牵引/伤害标记

var behavior_id := ""
var hazard_radius := 3.5
var pull_strength := 6.0
var last_hazard_pulse := false


func _init(behavior: String = "area_denial") -> void:
	behavior_id = behavior
	match behavior:
		"poison_mist_zone":
			hazard_radius = 4.0
			pull_strength = 2.0
		"gravity_zone":
			hazard_radius = 5.0
			pull_strength = 10.0
		"proximity_explode", "explosive_burst":
			hazard_radius = 2.8
			pull_strength = 0.0
		_:
			hazard_radius = 3.5


func apply_profile_modifiers(_enemy: Node) -> void:
	pass


func update_idle(enemy: Node, delta: float) -> void:
	var accel: float = float(enemy.get("acceleration"))
	var vel: Vector3 = enemy.get("velocity")
	vel.x = move_toward(vel.x, 0.0, accel * delta)
	vel.z = move_toward(vel.z, 0.0, accel * delta)
	enemy.set("velocity", vel)


func on_engage(_enemy: Node, _target: Node3D) -> void:
	pass


func on_attack_active(enemy: Node, target: Node3D) -> void:
	last_hazard_pulse = false
	if target == null or not is_instance_valid(target):
		return
	var body := enemy as Node3D
	if body == null:
		return
	var offset: Vector3 = body.global_position - target.global_position
	offset.y = 0.0
	var dist: float = offset.length()
	if dist > hazard_radius or dist < 0.05:
		return
	last_hazard_pulse = true
	if pull_strength <= 0.0:
		return
	var dir: Vector3 = offset.normalized()
	if target is CharacterBody3D:
		var cb := target as CharacterBody3D
		cb.velocity.x += dir.x * pull_strength
		cb.velocity.z += dir.z * pull_strength
	elif target.get("knockback_velocity") != null:
		target.set("knockback_velocity", target.get("knockback_velocity") + dir * pull_strength)
