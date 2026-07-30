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
	# Stone base — wide platform with ring detail
	var base := MeshInstance3D.new()
	base.name = "StoneBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.72
	base_mesh.bottom_radius = 0.88
	base_mesh.height = 0.22
	base_mesh.radial_segments = 16
	base.mesh = base_mesh
	base.position.y = 0.11
	base.material_override = _material(Color(0.10, 0.105, 0.11), 0.88, 0.02)
	add_child(base)
	# Mid ring
	var mid_ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.78
	ring_mesh.bottom_radius = 0.78
	ring_mesh.height = 0.08
	ring_mesh.radial_segments = 16
	mid_ring.mesh = ring_mesh
	mid_ring.position.y = 0.26
	mid_ring.material_override = _material(Color(0.14, 0.13, 0.10), 0.78, 0.12)
	add_child(mid_ring)

	# Pillar
	var pillar := MeshInstance3D.new()
	pillar.name = "Brazier"
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.34
	pillar_mesh.bottom_radius = 0.48
	pillar_mesh.height = 1.15
	pillar_mesh.radial_segments = 12
	pillar.mesh = pillar_mesh
	pillar.position.y = 0.72
	pillar.material_override = _material(Color(0.16, 0.145, 0.12), 0.72, 0.15)
	add_child(pillar)
	# Pillar collar/band
	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.38
	collar_mesh.bottom_radius = 0.40
	collar_mesh.height = 0.06
	collar_mesh.radial_segments = 12
	collar.mesh = collar_mesh
	collar.position.y = 1.05
	collar.material_override = _material(Color(0.20, 0.16, 0.10), 0.65, 0.28)
	add_child(collar)

	# Bowl
	var bowl := MeshInstance3D.new()
	bowl.name = "Bowl"
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.58
	bowl_mesh.bottom_radius = 0.28
	bowl_mesh.height = 0.22
	bowl_mesh.radial_segments = 14
	bowl.mesh = bowl_mesh
	bowl.position.y = 1.32
	bowl.material_override = _material(Color(0.18, 0.11, 0.05), 0.62, 0.32)
	add_child(bowl)
	# Bowl rim
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.54
	rim_mesh.outer_radius = 0.60
	rim_mesh.rings = 14
	rim_mesh.ring_segments = 6
	rim.mesh = rim_mesh
	rim.position.y = 1.44
	rim.material_override = _material(Color(0.22, 0.14, 0.06), 0.55, 0.38)
	add_child(rim)

	# Ember runes on base — small emissive marks
	for i in range(4):
		var angle := float(i) / 4.0 * TAU
		var rune := MeshInstance3D.new()
		var rune_box := BoxMesh.new()
		rune_box.size = Vector3(0.04, 0.12, 0.01)
		rune.mesh = rune_box
		rune.position = Vector3(sin(angle) * 0.6, 0.16, cos(angle) * 0.6)
		rune.rotation.y = angle + PI * 0.5
		var rune_mat := _material(Color(0.82, 0.35, 0.08), 0.3, 0.0)
		rune_mat.emission_enabled = true
		rune_mat.emission = Color(0.65, 0.18, 0.02)
		rune_mat.emission_energy_multiplier = 0.7
		rune.material_override = rune_mat
		add_child(rune)

	flame = MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.26
	flame_mesh.height = 0.68
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 6
	flame.mesh = flame_mesh
	flame.position.y = 1.58
	add_child(flame)
	# Inner flame core
	var inner_flame := MeshInstance3D.new()
	inner_flame.name = "InnerFlame"
	var inner_mesh := SphereMesh.new()
	inner_mesh.radius = 0.14
	inner_mesh.height = 0.35
	inner_mesh.radial_segments = 8
	inner_mesh.rings = 4
	inner_flame.mesh = inner_mesh
	inner_flame.position.y = 1.55
	add_child(inner_flame)

	light = OmniLight3D.new()
	light.name = "Glow"
	light.omni_range = 5.5
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
	# Inner flame
	var inner := get_node_or_null("InnerFlame") as MeshInstance3D
	if inner != null:
		var inner_color := Color(1.0, 0.82, 0.4) if is_activated else Color(0.15, 0.08, 0.02)
		var inner_mat := _material(inner_color, 0.2, 0.0)
		inner_mat.emission_enabled = true
		inner_mat.emission = inner_color
		inner_mat.emission_energy_multiplier = 5.5 if is_activated else 0.3
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.albedo_color.a = 0.7
		inner.material_override = inner_mat
	light.light_color = Color(1.0, 0.42, 0.12) if is_activated else Color(0.35, 0.13, 0.04)
	light.light_energy = 2.2 if is_activated else 0.45


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return _ProcUtils.make_material(color, roughness, metallic)


func _has_collision_shape() -> bool:
	return _ProcUtils.has_collision_shape(self)
