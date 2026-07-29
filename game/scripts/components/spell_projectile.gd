extends Area3D

var source: Node3D
var direction := Vector3.FORWARD
var speed := 15.0
var damage := 24.0
var stagger := 14.0
var lifetime := 2.2


func setup(
		new_source: Node3D,
		new_direction: Vector3,
		new_damage: float,
		new_stagger: float
) -> void:
	source = new_source
	direction = new_direction.normalized()
	damage = maxf(new_damage, 0.0)
	stagger = maxf(new_stagger, 0.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.26
	collision.shape = shape
	add_child(collision)

	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.48
	mesh.radial_segments = 12
	mesh.rings = 7
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("79a9ff")
	material.emission_enabled = true
	material.emission = Color("356dff")
	material.emission_energy_multiplier = 3.2
	material.roughness = 0.18
	visual.material_override = material
	add_child(visual)

	var light := OmniLight3D.new()
	light.light_color = Color("6f9fff")
	light.light_energy = 1.4
	light.omni_range = 2.8
	light.shadow_enabled = false
	add_child(light)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == source:
		return
	if body.has_method("receive_hit"):
		var hit_direction := direction
		body.receive_hit(damage, stagger, hit_direction, source)
	queue_free()
