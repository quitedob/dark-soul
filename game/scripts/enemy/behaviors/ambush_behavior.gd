# game/scripts/enemy/behaviors/ambush_behavior.gd
extends RefCounted
## G-05：伏击族 — 首次接敌侧/后方短距瞬移

var behavior_id := ""
var ambush_distance := 2.4
var used_ambush := false
var last_teleport_origin := Vector3.ZERO
var last_teleport_dest := Vector3.ZERO


func _init(behavior: String = "teleport_ambush") -> void:
	behavior_id = behavior
	match behavior:
		"illusion_dash":
			ambush_distance = 3.2
		"seduce_and_strike":
			ambush_distance = 2.0
		_:
			ambush_distance = 2.4


func apply_profile_modifiers(_enemy: Node) -> void:
	pass


func update_idle(enemy: Node, delta: float) -> void:
	var accel: float = float(enemy.get("acceleration"))
	var vel: Vector3 = enemy.get("velocity")
	vel.x = move_toward(vel.x, 0.0, accel * delta)
	vel.z = move_toward(vel.z, 0.0, accel * delta)
	enemy.set("velocity", vel)


func on_engage(enemy: Node, target: Node3D) -> void:
	if used_ambush or target == null or not is_instance_valid(target):
		return
	var body := enemy as Node3D
	if body == null:
		return
	used_ambush = true
	last_teleport_origin = _read_pos(body)
	var target_pos := _read_pos(target)
	var forward: Vector3 = -target.transform.basis.z
	if target.is_inside_tree():
		forward = -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var dest: Vector3 = target_pos - forward * ambush_distance + side * 0.6
	dest.y = last_teleport_origin.y
	_write_pos(body, dest)
	last_teleport_dest = dest


func _read_pos(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position


func _write_pos(node: Node3D, pos: Vector3) -> void:
	if node.is_inside_tree():
		node.global_position = pos
	else:
		node.position = pos


func on_attack_active(_enemy: Node, _target: Node3D) -> void:
	pass


func did_teleport() -> bool:
	return used_ambush and last_teleport_origin.distance_to(last_teleport_dest) > 0.5
