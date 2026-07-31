# game/scripts/enemy/enemy_projectile.gd
extends Area3D
## G-03：敌人远程投射物。扫掠命中世界(1)或玩家(2)，不伤友军敌人。

const WORLD_LAYER := 1
const PLAYER_LAYER := 2
const QUERY_MASK := WORLD_LAYER | PLAYER_LAYER

var source: Node3D
var direction := Vector3.FORWARD
var speed := 12.0
var damage := 12.0
var stagger := 10.0
var lifetime := 2.8
var hit_payload: Dictionary = {}
var _collision_radius := 0.18
var _resolved := false


## 配置发射源、方向与伤害元数据
func setup(
		new_source: Node3D,
		new_direction: Vector3,
		new_damage: float,
		new_stagger: float,
		metadata: Dictionary = {}
) -> void:
	source = new_source
	direction = new_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	damage = maxf(new_damage, 0.0)
	stagger = maxf(new_stagger, 0.0)
	speed = float(metadata.get("proj_speed", 12.0))
	lifetime = float(metadata.get("proj_lifetime", 2.8))
	_collision_radius = float(metadata.get("collision_radius", 0.18))
	hit_payload = {
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": metadata.get("guard_damage", damage + stagger * 0.2),
		"direction": direction,
		"source": source,
		"action_id": String(metadata.get("action_id", "enemy_projectile")),
		"tags": metadata.get("tags", ["projectile", "enemy"]).duplicate(),
		"blockable": bool(metadata.get("blockable", true)),
		"parryable": bool(metadata.get("parryable", false)),
	}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_build_visual()


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	var motion := direction * speed * delta
	var hit := _sweep_motion(motion)
	if not hit.is_empty():
		global_position = hit.get("position", global_position)
		_resolve_hit(hit.get("collider") as Node)
		return
	global_position += motion
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


## 球形扫掠：世界阻挡或命中玩家
func _sweep_motion(motion: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var shape := SphereShape3D.new()
	shape.radius = _collision_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = global_transform
	params.motion = motion
	params.collision_mask = QUERY_MASK
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var exclude: Array[RID] = []
	if source != null and is_instance_valid(source) and source is CollisionObject3D:
		exclude.append((source as CollisionObject3D).get_rid())
	params.exclude = exclude
	var cast := space.cast_motion(params)
	if cast.size() < 2:
		return {}
	var safe_fraction: float = float(cast[0])
	if safe_fraction >= 1.0:
		return {}
	var travel := motion * safe_fraction
	var rest := PhysicsShapeQueryParameters3D.new()
	rest.shape = shape
	rest.transform = Transform3D(global_transform.basis, global_position + travel)
	rest.collision_mask = QUERY_MASK
	rest.exclude = exclude
	rest.collide_with_areas = false
	rest.collide_with_bodies = true
	var overlaps := space.intersect_shape(rest, 4)
	if overlaps.is_empty():
		var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + motion)
		ray.collision_mask = QUERY_MASK
		ray.exclude = exclude
		return space.intersect_ray(ray)
	var best: Dictionary = overlaps[0]
	best["position"] = global_position + travel
	return best


func _resolve_hit(collider: Node) -> void:
	_resolved = true
	if collider == null or collider == source:
		queue_free()
		return
	# 世界几何：消散
	if collider is CollisionObject3D and ((collider as CollisionObject3D).collision_layer & WORLD_LAYER) != 0:
		if not collider.has_method("receive_hit") and not collider.has_method("receive_hit_payload"):
			queue_free()
			return
	if collider.has_method("receive_hit_payload"):
		var payload := hit_payload.duplicate(true)
		payload["direction"] = direction
		payload["source"] = source
		collider.receive_hit_payload(payload)
	elif collider.has_method("receive_hit"):
		collider.receive_hit(damage, stagger, direction, source)
	queue_free()


## 菱形余烬弹视觉（远程敌人标识色）
func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = _collision_radius
	collision.shape = shape
	add_child(collision)

	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 10
	mesh.rings = 6
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.35, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.2, 0.55)
	mat.emission_energy_multiplier = 3.2
	mat.roughness = 0.15
	visual.material_override = mat
	add_child(visual)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.35, 0.65)
	light.light_energy = 1.2
	light.omni_range = 2.4
	light.shadow_enabled = false
	add_child(light)
