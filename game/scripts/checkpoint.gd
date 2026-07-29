extends Area3D

const LocalizationScript = preload("res://scripts/core/localization.gd")
const _ProcUtils = preload("res://scripts/core/procedural_utils.gd")

signal activated(checkpoint: Node, player: Node)
signal rested(checkpoint: Node, player: Node)

@export var checkpoint_name := "Ashen Shrine"

var world: Node
var is_activated := false
var flame: MeshInstance3D
var light: OmniLight3D
var _time := 0.0
var _busy := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 3
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_collision()
	_build_visuals()


func setup(new_world: Node = null, new_name: String = "") -> void:
	world = new_world
	if not new_name.is_empty():
		checkpoint_name = new_name


func interact(player: Node) -> void:
	if _busy or player == null:
		return
	_busy = true
	if not is_activated:
		is_activated = true
		_update_appearance()
		activated.emit(self, player)
	rested.emit(self, player)
	await get_tree().create_timer(0.2).timeout
	_busy = false


func get_prompt() -> String:
	if is_activated:
		return LocalizationScript.text("Rest at %s") % LocalizationScript.text(checkpoint_name)
	return LocalizationScript.text("Kindle %s") % LocalizationScript.text(checkpoint_name)


func activate() -> void:
	if is_activated:
		return
	is_activated = true
	_update_appearance()


func reset() -> void:
	is_activated = false
	_busy = false
	_update_appearance()


func _process(delta: float) -> void:
	_time += delta
	if flame == null:
		return
	var strength := 0.85 if is_activated else 0.25
	flame.scale = Vector3.ONE * (strength + sin(_time * 5.0) * 0.06)
	flame.position.y = 1.12 + sin(_time * 3.7) * 0.035
	light.light_energy = (2.2 if is_activated else 0.45) + sin(_time * 4.3) * (0.18 if is_activated else 0.05)


func _build_collision() -> void:
	if _has_collision_shape():
		return
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := CylinderShape3D.new()
	shape.radius = 1.35
	shape.height = 2.2
	collision.shape = shape
	collision.position.y = 0.8
	add_child(collision)


func _build_visuals() -> void:
	var base := MeshInstance3D.new()
	base.name = "StoneBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.7
	base_mesh.bottom_radius = 0.85
	base_mesh.height = 0.32
	base_mesh.radial_segments = 12
	base.mesh = base_mesh
	base.position.y = 0.16
	base.material_override = _material(Color(0.11, 0.115, 0.12), 0.85, 0.0)
	add_child(base)

	var pillar := MeshInstance3D.new()
	pillar.name = "Brazier"
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.34
	pillar_mesh.bottom_radius = 0.48
	pillar_mesh.height = 1.15
	pillar_mesh.radial_segments = 10
	pillar.mesh = pillar_mesh
	pillar.position.y = 0.72
	pillar.material_override = _material(Color(0.16, 0.145, 0.12), 0.72, 0.15)
	add_child(pillar)

	var bowl := MeshInstance3D.new()
	bowl.name = "Bowl"
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.56
	bowl_mesh.bottom_radius = 0.28
	bowl_mesh.height = 0.22
	bowl_mesh.radial_segments = 12
	bowl.mesh = bowl_mesh
	bowl.position.y = 1.3
	bowl.material_override = _material(Color(0.17, 0.105, 0.045), 0.65, 0.3)
	add_child(bowl)

	flame = MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.24
	flame_mesh.height = 0.65
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 6
	flame.mesh = flame_mesh
	flame.position.y = 1.55
	add_child(flame)

	light = OmniLight3D.new()
	light.name = "Glow"
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position.y = 1.45
	add_child(light)
	_update_appearance()


func _update_appearance() -> void:
	if flame == null or light == null:
		return
	var color := Color(1.0, 0.34, 0.06) if is_activated else Color(0.26, 0.1, 0.035)
	var flame_material := _material(color, 0.3, 0.0)
	flame_material.emission_enabled = true
	flame_material.emission = color
	flame_material.emission_energy_multiplier = 4.0 if is_activated else 0.45
	flame.material_override = flame_material
	light.light_color = Color(1.0, 0.42, 0.12) if is_activated else Color(0.35, 0.13, 0.04)
	light.light_energy = 2.2 if is_activated else 0.45


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return _ProcUtils.make_material(color, roughness, metallic)


func _has_collision_shape() -> bool:
	return _ProcUtils.has_collision_shape(self)
