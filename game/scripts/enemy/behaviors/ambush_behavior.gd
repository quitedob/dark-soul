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
	last_teleport_dest = last_teleport_origin
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
	var desired: Vector3 = target_pos - forward * ambush_distance + side * 0.6
	# Out-of-tree fixtures can evaluate the direction without a physics world.
	if not body.is_inside_tree():
		desired.y = last_teleport_origin.y
		_write_pos(body, desired)
		last_teleport_dest = desired
		return
	# An ambush may cross the target, but cannot materialize in a wall, over a
	# void, on a different storey, or outside its encounter leash.
	for angle in [0., -.65, .65, -1.3, 1.3]:
		var offset := (desired - target_pos).rotated(Vector3.UP, angle)
		var result := _supported_destination(enemy, target_pos + offset, target_pos.y)
		if result.is_empty(): continue
		var dest: Vector3 = result["position"]
		_write_pos(body, dest)
		if body is CharacterBody3D: body.velocity = Vector3.ZERO
		if "navigation_refresh" in enemy: enemy.set("navigation_refresh", 0.0)
		last_teleport_dest = dest
		return


func _supported_destination(enemy: Node3D, candidate: Vector3, target_height: float) -> Dictionary:
	var space := enemy.get_world_3d().direct_space_state
	var radius := .45
	var height := 1.9
	var center_y := .95
	if "body_shape" in enemy and enemy.get("body_shape") is CapsuleShape3D:
		var original: CapsuleShape3D = enemy.get("body_shape")
		radius = original.radius
		height = original.height
		center_y = (enemy.get("body_collision") as CollisionShape3D).position.y
	var excluded: Array[RID] = []
	if enemy is CollisionObject3D: excluded.append(enemy.get_rid())
	var floor_y := 0.
	for offset: Vector3 in [Vector3.ZERO, Vector3.LEFT * radius, Vector3.RIGHT * radius, Vector3.FORWARD * radius, Vector3.BACK * radius]:
		var at := Vector3(candidate.x, target_height, candidate.z) + offset
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2., at + Vector3.DOWN * 3., 1)
		ray.exclude = excluded
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit["normal"] as Vector3).y < .75: return {}
		var hit_y: float = hit["position"].y
		if offset == Vector3.ZERO: floor_y = hit_y
		elif absf(hit_y - floor_y) > .35: return {}
	if absf(floor_y - target_height) > .75: return {}
	var dest := Vector3(candidate.x, floor_y + height * .5 - center_y + .06, candidate.z)
	if "spawn_origin" in enemy and "leash_range" in enemy:
		var home_offset: Vector3 = dest - (enemy.get("spawn_origin") as Vector3)
		if Vector2(home_offset.x, home_offset.z).length() > float(enemy.get("leash_range")): return {}
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius + .03
	capsule.height = maxf(height, capsule.radius * 2.)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, dest + Vector3.UP * center_y)
	query.collision_mask = 1 | 2 | 4
	query.exclude = excluded
	if not space.intersect_shape(query, 1).is_empty(): return {}
	return {"position": dest}


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
