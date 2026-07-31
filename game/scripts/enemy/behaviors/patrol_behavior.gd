# game/scripts/enemy/behaviors/patrol_behavior.gd
extends RefCounted
## G-05：巡逻族 — IDLE 绕出生点走动

var behavior_id := ""
var patrol_radius := 3.5
var aggro_scale := 1.0
var _angle := 0.0
var _initialized := false


func _init(behavior: String = "slow_patrol") -> void:
	behavior_id = behavior
	match behavior:
		"slow_patrol", "slow_drift":
			patrol_radius = 2.8
			aggro_scale = 0.9
		"patrol_route":
			patrol_radius = 4.5
			aggro_scale = 1.0
		"float_patrol":
			patrol_radius = 5.0
			aggro_scale = 1.05
		"inverted_patrol":
			patrol_radius = 3.0
			aggro_scale = 0.85
		"slow_crusher":
			patrol_radius = 2.0
			aggro_scale = 0.8
		_:
			patrol_radius = 3.5


func apply_profile_modifiers(enemy: Node) -> void:
	enemy.set("aggro_range", float(enemy.get("aggro_range")) * aggro_scale)


func update_idle(enemy: Node, delta: float) -> void:
	var body := enemy as Node3D
	if body == null:
		return
	if not _initialized:
		_angle = randf() * TAU
		_initialized = true
	_angle += delta * 0.55
	var origin_val = enemy.get("spawn_origin")
	var origin: Vector3 = origin_val if origin_val is Vector3 else Vector3.ZERO
	if enemy.has_meta("g05_spawn_origin"):
		origin = enemy.get_meta("g05_spawn_origin") as Vector3
	var target: Vector3 = origin + Vector3(cos(_angle), 0.0, sin(_angle)) * patrol_radius
	var current: Vector3 = body.global_position if body.is_inside_tree() else body.position
	var offset: Vector3 = target - current
	offset.y = 0.0
	var accel_val = enemy.get("acceleration")
	var accel: float = float(accel_val) if accel_val != null else 15.0
	var speed_val = enemy.get("move_speed")
	var move_speed: float = float(speed_val) if speed_val != null else 3.5
	if offset.length_squared() < 0.04:
		var v: Vector3 = enemy.velocity if enemy is CharacterBody3D else Vector3.ZERO
		v.x = move_toward(v.x, 0.0, accel * delta)
		v.z = move_toward(v.z, 0.0, accel * delta)
		if enemy is CharacterBody3D:
			(enemy as CharacterBody3D).velocity = v
		else:
			enemy.set("velocity", v)
		return
	var dir: Vector3 = offset.normalized()
	var speed: float = move_speed * 0.45
	var vel: Vector3 = enemy.velocity if enemy is CharacterBody3D else Vector3.ZERO
	vel.x = move_toward(vel.x, dir.x * speed, accel * delta)
	vel.z = move_toward(vel.z, dir.z * speed, accel * delta)
	if enemy is CharacterBody3D:
		(enemy as CharacterBody3D).velocity = vel
	else:
		enemy.set("velocity", vel)


func on_engage(_enemy: Node, _target: Node3D) -> void:
	pass


func on_attack_active(_enemy: Node, _target: Node3D) -> void:
	pass
