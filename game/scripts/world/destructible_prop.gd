extends StaticBody3D
## L-25：可破坏场景物件 —— three.js GLB（07-Pickups/pillJar 药罐）包装场景驱动。
## Boss AoE 冲击（apply_boss_impact）或直接 smash() 击碎：碎片刚体 + 一次性粒子 + 余烬奖励信号。
## 属于 scripts/world 下的独立 helper：不改共享场景 / 碰撞默认值。

signal broken(source_position: Vector3)

@export var part_group := "pillJar"
@export var model_scale := 1.5
@export var health := 1
@export var ember_reward := 6
@export var shard_count := 4
@export var impact_radius_bonus := 0.4

var _model: Node3D = null
var _group_node: Node3D = null
var _collision: CollisionShape3D = null
var _broken := false
var _bounds := AABB()


func _ready() -> void:
	add_to_group("destructibles")
	_prepare_model()


## Boss AoE / 地砸落点查询入口：距冲击点半径内即受击破碎
func apply_boss_impact(impact_position: Vector3, radius: float) -> void:
	if _broken:
		return
	var center := global_position + Vector3.UP * _bounds.size.y * 0.5
	if center.distance_to(impact_position) <= radius + impact_radius_bonus:
		take_hit(1.0, impact_position)


## 通用受击入口（脚本 / 测试 / 后续玩家攻击接线均可调用）
func take_hit(amount: float, source_position: Vector3) -> void:
	if _broken:
		return
	health -= amount
	if health <= 0.0:
		smash(source_position)


func is_broken() -> bool:
	return _broken


## 击碎：信号 → 碎片刚体 + 一次性粒子 → 停用碰撞并自毁
func smash(source_position: Vector3) -> void:
	if _broken:
		return
	_broken = true
	broken.emit(source_position)
	var host: Node = get_parent() if get_parent() != null else self
	_spawn_debris(host, source_position)
	_spawn_shards(host, source_position)
	if _model != null:
		_model.visible = false
	if _collision != null:
		_collision.set_deferred("disabled", true)
	queue_free()


# -- 内部 -------------------------------------------------------------------


## 只保留 part_group 分组：隐藏 GLB 其余分组，缩放、落地对齐并构建盒碰撞
func _prepare_model() -> void:
	for child in get_children():
		if child is Node3D and child.name == "Model":
			_model = child as Node3D
			break
	if _model == null:
		_fallback_bounds()
		return
	var found: Array = _model.find_children(part_group, "Node3D", true, false)
	if found.is_empty():
		push_warning("DestructibleProp: GLB 里找不到分组 %s" % part_group)
		_fallback_bounds()
		return
	_group_node = found[0] as Node3D
	for sibling in _group_node.get_parent().get_children():
		if sibling is Node3D and sibling != _group_node:
			sibling.visible = false
	_model.scale = Vector3.ONE * model_scale
	_bounds = _subtree_bounds(_group_node, Transform3D(_model.global_transform.basis, Vector3.ZERO))
	if _bounds.size.length_squared() > 0.001:
		# 落地对齐：分组最低点贴到本地原点
		var offset := -_bounds.position.y
		_model.position.y += offset
		_bounds.position.y += offset
	var shape := BoxShape3D.new()
	shape.size = _bounds.size * Vector3(1.15, 1.0, 1.15)
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position = _bounds.get_center()
	add_child(_collision)


## 找不到分组时兜底：小盒碰撞（保持可破坏、不出错）
func _fallback_bounds() -> void:
	_bounds = AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 0.6, 0.5))
	var shape := BoxShape3D.new()
	shape.size = _bounds.size
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position = _bounds.get_center()
	add_child(_collision)


## 一次性碎屑粒子（CPUParticles3D：compat 渲染器零风险），播完自毁
func _spawn_debris(host: Node, source_position: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "PropDebris"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 22
	p.lifetime = 0.7
	p.spread = 55.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.14
	p.color = _debris_color()
	host.add_child(p)
	p.global_position = global_position + Vector3.UP * _bounds.size.y * 0.5
	p.finished.connect(p.queue_free)


## 少量刚体碎片：外抛落地、约 4s 后自动清理（上限 shard_count，避免物理膨胀）
func _spawn_shards(host: Node, source_position: Vector3) -> void:
	if host is not Node3D:
		return
	var away := global_position - source_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	else:
		away = away.normalized()
	var shard_color := _debris_color()
	for i in range(maxi(shard_count, 0)):
		var shard := RigidBody3D.new()
		shard.collision_layer = 1
		shard.collision_mask = 1
		var mesh := BoxMesh.new()
		var edge := randf_range(0.06, 0.12)
		mesh.size = Vector3(edge, edge * 0.8, edge)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = shard_color
		mat.roughness = 0.9
		mesh.material = mat
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		shard.add_child(visual)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		shard.add_child(shape)
		(host as Node3D).add_child(shard)
		shard.global_position = global_position + Vector3.UP * _bounds.size.y * 0.6
		var impulse := away * randf_range(1.8, 3.4) + Vector3.UP * randf_range(2.2, 3.6)
		shard.apply_central_impulse(impulse)
		var timer := get_tree().create_timer(4.0)
		timer.timeout.connect(shard.queue_free)


## 取药罐首个表面材质作碎屑颜色；取不到回退陶土色
func _debris_color() -> Color:
	if _group_node != null:
		var meshes: Array = _group_node.find_children("*", "MeshInstance3D", true, false)
		for node in meshes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() < 1:
				continue
			var mat := mesh_instance.get_active_material(0)
			if mat is StandardMaterial3D:
				return (mat as StandardMaterial3D).albedo_color
	return Color(0.72, 0.5, 0.34)


## 递归累计分组子树世界无关包围盒（相对本物件原点）
func _subtree_bounds(node: Node3D, accumulated: Transform3D) -> AABB:
	var result := AABB()
	var node_transform := accumulated * node.transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			result = node_transform * mesh_instance.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_aabb := _subtree_bounds(child as Node3D, node_transform)
			if child_aabb.size.length_squared() > 0.001:
				result = result if result.size.length_squared() > 0.001 else child_aabb
				result = result.merge(child_aabb)
	return result
