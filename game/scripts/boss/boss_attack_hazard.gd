# game/scripts/boss/boss_attack_hazard.gd
extends Area3D
## L-19：Boss 持续危害区域（trail_hazard）。检测玩家层(2)，进入即受击，时长后自毁。
## 属于 scripts/boss 下的独立 helper（不影响共享场景/碰撞默认值）。

var source: Node3D
var damage := 20.0
var stagger := 20.0
var _hit_payload: Dictionary = {}
var _already_hit: Dictionary = {}


## 配置伤害与危害元数据
func setup(new_source: Node3D, new_damage: float, new_stagger: float, metadata: Dictionary = {}) -> void:
	source = new_source
	damage = maxf(new_damage, 0.0)
	stagger = maxf(new_stagger, 0.0)
	var lifetime := maxf(float(metadata.get("lifetime", 3.0)), 0.1)
	_build(metadata)
	_hit_payload = {
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": metadata.get("guard_damage", damage + stagger * 0.25),
		"direction": Vector3.ZERO,
		"source": source,
		"action_id": String(metadata.get("action_id", "boss_trail_hazard")),
		"tags": ["hazard", "enemy", "boss"],
		"blockable": true,
		"parryable": false,
	}
	body_entered.connect(_on_body_entered)
	monitoring = true
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_expire, CONNECT_ONE_SHOT)


## 碰撞体 + 视觉：先清默认再启用监测（遵循 Collision 约定）
func _build(metadata: Dictionary) -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)  # 玩家层
	monitorable = false
	monitoring = false
	var radius := float(metadata.get("radius", 1.6))
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.05)
	mat.emission_energy_multiplier = 1.6
	visual.material_override = mat
	add_child(visual)


func _on_body_entered(body: Node3D) -> void:
	if _already_hit.has(body):
		return
	_already_hit[body] = true
	var dir := body.global_position - global_position
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	if body.has_method("receive_hit_payload"):
		var payload := _hit_payload.duplicate(true)
		payload["direction"] = dir
		payload["source"] = source
		body.receive_hit_payload(payload)
	elif body.has_method("receive_hit"):
		body.receive_hit(damage, stagger, dir, source)


func _expire() -> void:
	if is_inside_tree():
		queue_free()
