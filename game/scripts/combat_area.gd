extends Area3D
## 共享命中体积：按招式 hitbox 配置形变；激活时补扫已重叠目标；ShapeCast 防高速穿透
signal hit_landed(target: Node3D, is_heavy: bool)

@export var debug_draw := false  ## 调试：半透明胶囊可视化
var damage := 10.0
var stagger := 10.0
var source: Node
var active := false
var hit_payload: Dictionary = {}
var already_hit: Dictionary = {}
var uses_motion_cast := false  ## 供测试查询：是否已初始化 motion ShapeCast

var _shape_node: CollisionShape3D
var _capsule: CapsuleShape3D
var _motion_cast: ShapeCast3D
var _cast_capsule: CapsuleShape3D
var _debug_mesh: MeshInstance3D
var _previous_global_position: Vector3
var _default_radius := 1.25
var _default_height := 1.45
var _default_offset := Vector3(0.0, 1.0, -1.0)
var _follow_socket: Node3D = null
var _socket_local_offset := Vector3.ZERO
var _use_socket_follow := false

const _MOTION_CAST_EPSILON := 0.0001


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	_ensure_motion_cast()
	_ensure_debug_mesh()
	if is_inside_tree():
		_previous_global_position = global_position


func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	_sync_socket_follow()
	if active:
		_sample_motion_hits()
	_previous_global_position = global_position


func configure(new_source: Node, radius: float, height: float = 1.2, offset: Vector3 = Vector3(0.0, 1.0, -1.0)) -> void:
	source = new_source
	collision_layer = 0
	if source != null and source.is_in_group("player"):
		collision_mask = 4
	else:
		collision_mask = 2
	_default_radius = radius
	_default_height = maxf(height, radius * 2.0)
	_default_offset = offset
	position = _default_offset
	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		_capsule = CapsuleShape3D.new()
		_shape_node.shape = _capsule
		add_child(_shape_node)
	_apply_capsule(_default_radius, _default_height)
	_ensure_motion_cast()
	_ensure_debug_mesh()
	_sync_motion_cast_mask()
	monitoring = false


func begin_swing(new_damage: float, new_stagger: float, metadata: Dictionary = {}) -> void:
	damage = new_damage
	stagger = new_stagger
	# 按招式覆盖 hitbox；缺省回退到默认前向胶囊
	var radius := float(metadata.get("hitbox_radius", _default_radius))
	var height := float(metadata.get("hitbox_height", _default_height))
	var offset := _default_offset
	if metadata.has("hitbox_offset") and metadata["hitbox_offset"] is Vector3:
		offset = metadata["hitbox_offset"] as Vector3
	apply_hitbox_profile(radius, height, offset)
	var tags: Array = metadata.get("tags", []).duplicate()
	# 优先用标签/显式标记判定重击，伤害阈值仅作回退
	var is_heavy := bool(metadata.get("is_heavy", false)) or (&"heavy" in tags) or ("heavy" in tags)
	hit_payload = {
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": metadata.get("guard_damage", damage + stagger * 0.25),
		"direction": Vector3.ZERO,
		"source": source,
		"hand": String(metadata.get("hand", "right")),
		"item_id": String(metadata.get("item_id", "")),
		"action_id": String(metadata.get("action_id", "legacy_swing")),
		"tags": tags,
		"is_heavy": is_heavy,
		"blockable": bool(metadata.get("blockable", true)),
		"parryable": bool(metadata.get("parryable", true)),
	}
	already_hit.clear()
	active = true
	monitoring = true
	if is_inside_tree():
		_previous_global_position = global_position
	_set_motion_cast_enabled(true)
	_update_debug_mesh_visibility()
	# 已重叠目标不会再触发 body_entered，主动补扫
	call_deferred("_flush_overlapping_hits")


func end_swing() -> void:
	active = false
	monitoring = false
	already_hit.clear()
	_set_motion_cast_enabled(false)
	clear_socket_follow()
	_update_debug_mesh_visibility()
	# 收招复位默认 hitbox，避免下一招残留空中体积
	apply_hitbox_profile(_default_radius, _default_height, _default_offset)


func set_socket_follow(socket: Node3D, local_offset: Vector3) -> void:
	# 将命中体积挂到武器 tip 等挂点；每帧同步全局位置
	_follow_socket = socket
	_socket_local_offset = local_offset
	_use_socket_follow = socket != null and is_instance_valid(socket)
	_sync_socket_follow()


func clear_socket_follow() -> void:
	_use_socket_follow = false
	_follow_socket = null


func apply_hitbox_profile(radius: float, height: float, offset: Vector3) -> void:
	if not _use_socket_follow:
		position = offset
	_apply_capsule(radius, maxf(height, radius * 2.0))


func _sync_socket_follow() -> void:
	if not _use_socket_follow or _follow_socket == null or not is_instance_valid(_follow_socket):
		return
	global_position = _follow_socket.to_global(_socket_local_offset)


func _apply_capsule(radius: float, height: float) -> void:
	if _capsule == null:
		return
	_capsule.radius = radius
	_capsule.height = height
	_sync_motion_cast_shape()
	_update_debug_mesh()


func _ensure_motion_cast() -> void:
	if _motion_cast != null:
		return
	_motion_cast = ShapeCast3D.new()
	_motion_cast.name = "MotionHitCast"
	_cast_capsule = CapsuleShape3D.new()
	_motion_cast.shape = _cast_capsule
	_motion_cast.enabled = false
	add_child(_motion_cast)
	uses_motion_cast = true


func _ensure_debug_mesh() -> void:
	if _debug_mesh != null:
		return
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugHitboxMesh"
	var capsule_mesh := CapsuleMesh.new()
	_debug_mesh.mesh = capsule_mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh.material_override = mat
	_debug_mesh.visible = false
	add_child(_debug_mesh)


func _sync_motion_cast_mask() -> void:
	if _motion_cast == null:
		return
	_motion_cast.collision_mask = collision_mask


func _sync_motion_cast_shape() -> void:
	if _cast_capsule == null or _capsule == null:
		return
	_cast_capsule.radius = _capsule.radius
	_cast_capsule.height = _capsule.height


func _set_motion_cast_enabled(enabled: bool) -> void:
	if _motion_cast != null:
		_motion_cast.enabled = enabled


func _sample_motion_hits() -> void:
	if _motion_cast == null or not _motion_cast.enabled:
		return
	var motion := global_position - _previous_global_position
	if motion.length_squared() < _MOTION_CAST_EPSILON * _MOTION_CAST_EPSILON:
		# 位移极小时做静止重叠采样；常规命中仍由 Area3D + begin 补扫负责
		_motion_cast.position = Vector3.ZERO
		_motion_cast.target_position = Vector3.ZERO
		_motion_cast.force_shapecast_update()
		_apply_cast_collisions()
		return
	# 将 cast 起点回退到上一帧位置，沿位移扫掠胶囊
	var local_motion := global_transform.basis.inverse() * motion
	_motion_cast.position = -local_motion
	_motion_cast.target_position = local_motion
	_motion_cast.force_shapecast_update()
	_apply_cast_collisions()


func _apply_cast_collisions() -> void:
	for i in range(_motion_cast.get_collision_count()):
		var collider := _motion_cast.get_collider(i)
		if collider is Node3D:
			_on_body_entered(collider as Node3D)


func _update_debug_mesh() -> void:
	if _debug_mesh == null or _capsule == null:
		return
	var mesh := _debug_mesh.mesh as CapsuleMesh
	if mesh != null:
		mesh.radius = _capsule.radius
		mesh.height = _capsule.height


func _update_debug_mesh_visibility() -> void:
	if _debug_mesh != null:
		_debug_mesh.visible = debug_draw and active


func _flush_overlapping_hits() -> void:
	if not active or not monitoring:
		return
	for body in get_overlapping_bodies():
		if body is Node3D:
			_on_body_entered(body as Node3D)


func _on_body_entered(body: Node3D) -> void:
	if not active or body == source or already_hit.has(body):
		return
	if not body.has_method("receive_hit"):
		return
	already_hit[body] = true
	var hit_direction := Vector3.ZERO
	if source is Node3D:
		hit_direction = (body.global_position - source.global_position).normalized()
	var payload := hit_payload.duplicate(true)
	payload["direction"] = hit_direction
	payload["source"] = source
	if body.has_method("receive_hit_payload"):
		body.receive_hit_payload(payload)
	else:
		body.receive_hit(
			float(payload["damage"]),
			float(payload["stagger"]),
			hit_direction,
			source
		)
	var is_heavy := bool(payload.get("is_heavy", false))
	if not is_heavy:
		is_heavy = float(payload["damage"]) >= 30.0
	hit_landed.emit(body, is_heavy)
