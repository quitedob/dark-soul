# game/scripts/boss/boss_attack_clone.gd
extends StaticBody3D
## L-19：Boss 幻影分身（summon）。可被锁定/受击的诱饵，到时自毁。
## 最小实现：项目无敌方 clone/summon 基础设施（spirit_summon.gd 是玩家侧召唤），
## 故提供轻量诱饵节点，复用受击契约（receive_hit / receive_hit_payload）。
## 物理体：StaticBody3D + CapsuleShape3D，仅挂在 Enemies 逻辑层（raw 4），
## 使玩家近战命中盒（mask 4）与法术投射物扫掠（1|4）能命中；自身 mask=0 永不反碰。

signal despawned(clone)

var lifetime := 8.0
var max_health := 40.0
var health := 40.0
var _dead := false


func setup(metadata: Dictionary = {}) -> void:
	lifetime = maxf(float(metadata.get("lifetime", 8.0)), 0.1)
	max_health = maxf(float(metadata.get("health", 40.0)), 1.0)
	health = max_health
	_configure_collision()
	_build_collision()
	_build_visual()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_expire, CONNECT_ONE_SHOT)


func is_targetable() -> bool:
	return not _dead and is_instance_valid(self)


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func receive_hit(damage, stagger, hit_direction, source) -> void:
	if _dead:
		return
	health = maxf(health - float(damage), 0.0)
	if health <= 0.0:
		_despawn()


func receive_hit_payload(payload: Dictionary) -> void:
	receive_hit(
		float(payload.get("damage", 0.0)),
		float(payload.get("stagger", 0.0)),
		payload.get("direction", Vector3.ZERO),
		payload.get("source")
	)


## 物理命中体积：诱饵需可被玩家命中盒（mask 4）与法术扫掠（1|4）命中，
## 但仅挂 Enemies 逻辑层 3（raw 4），自身 mask=0，永不与/攻击任何东西。
func _configure_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CloneHitbox"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	collision.shape = capsule
	collision.position = Vector3(0.0, 1.0, 0.0)
	add_child(collision)


func _build_visual() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "CloneBody"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.6
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.8, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 1.3
	visual.material_override = mat
	visual.position = Vector3(0.0, 1.0, 0.0)
	add_child(visual)


func _expire() -> void:
	_despawn()


func _despawn() -> void:
	if _dead:
		return
	_dead = true
	despawned.emit(self)
	if is_inside_tree():
		queue_free()
