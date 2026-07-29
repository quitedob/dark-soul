extends Area3D

const LocalizationScript = preload("res://scripts/core/localization.gd")
const _ProcUtils = preload("res://scripts/core/procedural_utils.gd")

signal opened(shortcut: Node, gate: Node3D, player: Node)

@export var prompt_text := "Open shortcut"
@export var open_offset := Vector3(0.0, 3.5, 0.0)
@export var open_duration := 1.25

var world: Node
var gate: Node3D
var is_open := false
var _opening := false
var _closed_position := Vector3.ZERO
var _time := 0.0
var indicator: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 3
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_collision()
	_build_visuals()


func setup(new_gate: Node3D, new_world: Node = null) -> void:
	gate = new_gate
	world = new_world
	if is_instance_valid(gate):
		_closed_position = gate.position


func interact(player: Node) -> void:
	if is_open or _opening or not is_instance_valid(gate):
		return
	_opening = true
	is_open = true
	monitoring = false
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(gate, "position", _closed_position + open_offset, maxf(open_duration, 0.05))
	opened.emit(self, gate, player)
	await tween.finished
	_opening = false
	visible = false


func get_prompt() -> String:
	if is_open:
		return ""
	if not is_instance_valid(gate):
		return ""
	return LocalizationScript.text(prompt_text)


func open_immediately() -> void:
	if not is_instance_valid(gate):
		return
	is_open = true
	_opening = false
	gate.position = _closed_position + open_offset
	monitoring = false
	visible = false


func reset() -> void:
	if not is_instance_valid(gate):
		return
	is_open = false
	_opening = false
	gate.position = _closed_position
	monitoring = true
	visible = true


func _process(delta: float) -> void:
	_time += delta
	if indicator != null:
		indicator.rotation.y = _time * 0.85
		indicator.position.y = 1.25 + sin(_time * 2.4) * 0.08


func _build_collision() -> void:
	if _has_collision_shape():
		return
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.4, 1.8)
	collision.shape = shape
	collision.position.y = 1.1
	add_child(collision)


func _build_visuals() -> void:
	var pedestal := MeshInstance3D.new()
	pedestal.name = "LeverPedestal"
	var pedestal_mesh := BoxMesh.new()
	pedestal_mesh.size = Vector3(0.7, 1.1, 0.55)
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.55
	pedestal.material_override = _material(Color(0.115, 0.12, 0.125), 0.82, 0.1)
	add_child(pedestal)

	var lever := MeshInstance3D.new()
	lever.name = "Lever"
	var lever_mesh := CylinderMesh.new()
	lever_mesh.top_radius = 0.075
	lever_mesh.bottom_radius = 0.075
	lever_mesh.height = 1.0
	lever_mesh.radial_segments = 8
	lever.mesh = lever_mesh
	lever.position = Vector3(0.0, 1.25, 0.12)
	lever.rotation.x = deg_to_rad(-28.0)
	lever.material_override = _material(Color(0.23, 0.17, 0.095), 0.5, 0.55)
	add_child(lever)

	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := SphereMesh.new()
	handle_mesh.radius = 0.14
	handle_mesh.height = 0.28
	handle_mesh.radial_segments = 8
	handle_mesh.rings = 4
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 1.72, -0.13)
	handle.material_override = _material(Color(0.32, 0.17, 0.055), 0.45, 0.25)
	add_child(handle)

	indicator = MeshInstance3D.new()
	indicator.name = "Rune"
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 0.13
	rune_mesh.outer_radius = 0.22
	rune_mesh.rings = 12
	rune_mesh.ring_segments = 6
	indicator.mesh = rune_mesh
	indicator.position = Vector3(0.0, 1.25, 0.43)
	indicator.rotation.x = PI * 0.5
	var rune_material := _material(Color(0.88, 0.51, 0.13), 0.3, 0.1)
	rune_material.emission_enabled = true
	rune_material.emission = Color(0.72, 0.27, 0.04)
	rune_material.emission_energy_multiplier = 2.0
	indicator.material_override = rune_material
	add_child(indicator)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return _ProcUtils.make_material(color, roughness, metallic)


func _has_collision_shape() -> bool:
	return _ProcUtils.has_collision_shape(self)
