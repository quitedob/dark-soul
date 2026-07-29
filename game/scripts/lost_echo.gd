extends Area3D

const LocalizationScript = preload("res://scripts/core/localization.gd")

signal recovered(amount: int, player: Node)

@export var amount := 0

var world: Node
var _claimed := false
var _time := 0.0
var core: MeshInstance3D
var ring: MeshInstance3D
var glow: OmniLight3D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_collision()
	_build_visuals()
	body_entered.connect(_on_body_entered)


func setup(new_amount: int, new_world: Node = null) -> void:
	amount = maxi(new_amount, 0)
	world = new_world


func interact(player: Node) -> void:
	_recover(player)


func get_prompt() -> String:
	if _claimed:
		return ""
	return LocalizationScript.text("Recover lost echo")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or _can_receive_echo(body):
		_recover(body)


func _recover(player: Node) -> void:
	if _claimed or player == null:
		return
	_claimed = true
	monitoring = false
	if get_signal_connection_list(&"recovered").is_empty():
		if player.has_method("recover_embers"):
			player.recover_embers(amount)
	recovered.emit(amount, player)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.8, 0.24).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(core, "transparency", 1.0, 0.24)
	tween.tween_property(ring, "transparency", 1.0, 0.24)
	tween.tween_property(glow, "light_energy", 0.0, 0.24)
	await tween.finished
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	if core == null:
		return
	core.position.y = 0.7 + sin(_time * 2.6) * 0.11
	core.rotation.y = _time * 0.55
	ring.position.y = core.position.y
	ring.rotation.y = -_time * 1.15
	glow.light_energy = 1.25 + sin(_time * 3.8) * 0.2


func _build_collision() -> void:
	if _has_collision_shape():
		return
	var collision := CollisionShape3D.new()
	collision.name = "RecoveryShape"
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	collision.position.y = 0.65
	add_child(collision)


func _build_visuals() -> void:
	core = MeshInstance3D.new()
	core.name = "EchoCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.32
	core_mesh.height = 0.64
	core_mesh.radial_segments = 12
	core_mesh.rings = 7
	core.mesh = core_mesh
	core.position.y = 0.7
	var core_material := _material(Color(0.22, 0.72, 0.58), 0.22, 0.0)
	core_material.emission_enabled = true
	core_material.emission = Color(0.08, 0.7, 0.48)
	core_material.emission_energy_multiplier = 3.4
	core.material_override = core_material
	add_child(core)

	ring = MeshInstance3D.new()
	ring.name = "EchoRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.48
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.position.y = 0.7
	ring.rotation.x = deg_to_rad(72.0)
	var ring_material := _material(Color(0.5, 0.92, 0.7), 0.18, 0.1)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.16, 0.62, 0.44)
	ring_material.emission_energy_multiplier = 2.2
	ring.material_override = ring_material
	add_child(ring)

	glow = OmniLight3D.new()
	glow.name = "EchoGlow"
	glow.position.y = 0.72
	glow.light_color = Color(0.22, 1.0, 0.67)
	glow.light_energy = 1.25
	glow.omni_range = 3.6
	glow.shadow_enabled = false
	add_child(glow)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _can_receive_echo(body: Object) -> bool:
	for method_name in [&"recover_embers", &"add_embers", &"add_souls", &"add_currency"]:
		if body.has_method(method_name):
			return true
	return false
