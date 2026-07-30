extends Area3D
## Differentiated spell projectile — each spell type gets distinct visuals,
## speed, lifetime, collision size, and particle effects.

var source: Node3D
var direction := Vector3.FORWARD
var speed := 15.0
var damage := 24.0
var stagger := 14.0
var lifetime := 2.2
var hit_payload: Dictionary = {}
var _spell_type := "default"
var _homing_target: Node3D = null
var _homing_strength := 0.0


func setup(
		new_source: Node3D,
		new_direction: Vector3,
		new_damage: float,
		new_stagger: float,
		metadata: Dictionary = {}
) -> void:
	source = new_source
	direction = new_direction.normalized()
	damage = maxf(new_damage, 0.0)
	stagger = maxf(new_stagger, 0.0)
	hit_payload = {
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": metadata.get("guard_damage", damage + stagger * 0.25),
		"direction": direction,
		"source": source,
		"hand": String(metadata.get("hand", "right")),
		"item_id": String(metadata.get("item_id", "")),
		"action_id": String(metadata.get("action_id", "legacy_projectile")),
		"tags": metadata.get("tags", ["projectile"]).duplicate(),
		"blockable": bool(metadata.get("blockable", true)),
		"parryable": bool(metadata.get("parryable", false)),
	}

	# Apply per-spell-type configuration from metadata
	_spell_type = String(metadata.get("spell_type", "default"))
	speed = float(metadata.get("proj_speed", 15.0))
	lifetime = float(metadata.get("proj_lifetime", 2.2))
	_homing_target = metadata.get("homing_target", null)
	_homing_strength = float(metadata.get("homing_strength", 0.0))


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

	# Per-spell-type visual configuration
	var spell_config := _get_spell_config(_spell_type)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = spell_config["collision_radius"]
	collision.shape = shape
	add_child(collision)

	# Main visual
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = spell_config["mesh_radius"]
	mesh.height = spell_config["mesh_height"]
	mesh.radial_segments = spell_config["mesh_segments"]
	mesh.rings = spell_config["mesh_rings"]
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = spell_config["color"]
	material.emission_enabled = true
	material.emission = spell_config["emission"]
	material.emission_energy_multiplier = spell_config["emission_energy"]
	material.roughness = spell_config["roughness"]
	visual.material_override = material
	add_child(visual)

	# Inner core glow for spells
	if spell_config["has_inner_glow"]:
		var inner := MeshInstance3D.new()
		var inner_mesh := SphereMesh.new()
		inner_mesh.radius = spell_config["mesh_radius"] * 0.55
		inner_mesh.height = spell_config["mesh_height"] * 0.55
		inner_mesh.radial_segments = 8
		inner_mesh.rings = 4
		inner.mesh = inner_mesh
		var inner_mat := StandardMaterial3D.new()
		inner_mat.albedo_color = Color.WHITE
		inner_mat.emission_enabled = true
		inner_mat.emission = spell_config["emission"]
		inner_mat.emission_energy_multiplier = spell_config["emission_energy"] * 1.5
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.albedo_color.a = 0.45
		inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		inner.material_override = inner_mat
		add_child(inner)

	# Light source
	var light := OmniLight3D.new()
	light.light_color = spell_config["light_color"]
	light.light_energy = spell_config["light_energy"]
	light.omni_range = spell_config["light_range"]
	light.shadow_enabled = false
	add_child(light)

	# Trail particles for certain spell types
	if spell_config["has_trail"]:
		var trail := GPUParticles3D.new()
		trail.emitting = true
		trail.amount = spell_config["trail_particles"]
		trail.lifetime = spell_config["trail_lifetime"]
		trail.one_shot = false
		trail.explosiveness = 1.0
		trail.position = Vector3(0, 0, spell_config["trail_offset"])
		var trail_mesh := SphereMesh.new()
		trail_mesh.radius = 0.04
		trail_mesh.height = 0.08
		trail_mesh.radial_segments = 4
		trail_mesh.rings = 2
		var trail_mat := StandardMaterial3D.new()
		trail_mat.albedo_color = spell_config["emission"]
		trail_mat.emission_enabled = true
		trail_mat.emission = spell_config["emission"]
		trail_mat.emission_energy_multiplier = 2.0
		trail_mesh.material = trail_mat
		trail.draw_pass_1 = trail_mesh
		var trail_proc_mat := ParticleProcessMaterial.new()
		trail_proc_mat.direction = Vector3(0, 0, -1)
		trail_proc_mat.spread = 25.0
		trail_proc_mat.initial_velocity_min = 0.5
		trail_proc_mat.initial_velocity_max = 1.2
		trail_proc_mat.scale_min = 0.3
		trail_proc_mat.scale_max = 1.0
		trail_proc_mat.color = Color(spell_config["emission"].r, spell_config["emission"].g, spell_config["emission"].b, 0.5)
		trail.process_material = trail_proc_mat
		add_child(trail)


func _physics_process(delta: float) -> void:
	# Homing behavior
	if _homing_target != null and is_instance_valid(_homing_target) and _homing_strength > 0.0:
		var target_point: Vector3 = (
			_homing_target.get_target_point()
			if _homing_target.has_method("get_target_point")
			else _homing_target.global_position
		)
		var desired := (target_point - global_position).normalized()
		direction = direction.lerp(desired, _homing_strength * delta).normalized()

	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == source:
		return
	if body.has_method("receive_hit_payload"):
		var payload := hit_payload.duplicate(true)
		payload["direction"] = direction
		payload["source"] = source
		body.receive_hit_payload(payload)
	elif body.has_method("receive_hit"):
		body.receive_hit(damage, stagger, direction, source)
	queue_free()


func _get_spell_config(spell_type: String) -> Dictionary:
	## Returns visual+physics config per spell type.
	## veil_bolt: fast blue mage bolt with trail
	## seal_burst: slow purple burst orb
	## bow_quick_shot: fast compact arrow-like projectile
	## bow_power_shot: larger heavy arrow
	## divine_smite: golden prayer strike (future)
	match spell_type:
		"veil_bolt":
			return {
				"collision_radius": 0.24,
				"mesh_radius": 0.22, "mesh_height": 0.44, "mesh_segments": 12, "mesh_rings": 7,
				"color": Color("6688cc"),
				"emission": Color("4466ff"),
				"emission_energy": 3.8,
				"roughness": 0.12,
				"has_inner_glow": true,
				"light_color": Color("5577ff"), "light_energy": 1.6, "light_range": 3.2,
				"has_trail": true, "trail_particles": 8, "trail_lifetime": 0.25, "trail_offset": 0.3,
			}
		"seal_burst":
			return {
				"collision_radius": 0.35,
				"mesh_radius": 0.32, "mesh_height": 0.64, "mesh_segments": 14, "mesh_rings": 9,
				"color": Color("8855cc"),
				"emission": Color("7733ee"),
				"emission_energy": 4.2,
				"roughness": 0.08,
				"has_inner_glow": true,
				"light_color": Color("9966ff"), "light_energy": 2.0, "light_range": 4.5,
				"has_trail": true, "trail_particles": 12, "trail_lifetime": 0.35, "trail_offset": 0.4,
			}
		"bow_quick_shot":
			return {
				"collision_radius": 0.14,
				"mesh_radius": 0.12, "mesh_height": 0.24, "mesh_segments": 8, "mesh_rings": 5,
				"color": Color("bbbbbb"),
				"emission": Color("888888"),
				"emission_energy": 0.6,
				"roughness": 0.35,
				"has_inner_glow": false,
				"light_color": Color("aaaaaa"), "light_energy": 0.5, "light_range": 1.8,
				"has_trail": false, "trail_particles": 0, "trail_lifetime": 0.0, "trail_offset": 0.0,
			}
		"bow_power_shot":
			return {
				"collision_radius": 0.20,
				"mesh_radius": 0.18, "mesh_height": 0.36, "mesh_segments": 10, "mesh_rings": 6,
				"color": Color("cccccc"),
				"emission": Color("aaaaaa"),
				"emission_energy": 1.0,
				"roughness": 0.28,
				"has_inner_glow": false,
				"light_color": Color("cccccc"), "light_energy": 0.8, "light_range": 2.5,
				"has_trail": false, "trail_particles": 0, "trail_lifetime": 0.0, "trail_offset": 0.0,
			}
		"arcane_barrage":
			return {
				"collision_radius": 0.10,
				"mesh_radius": 0.08, "mesh_height": 0.16, "mesh_segments": 6, "mesh_rings": 4,
				"color": Color("55aacc"),
				"emission": Color("33aaee"),
				"emission_energy": 2.5,
				"roughness": 0.1,
				"has_inner_glow": true,
				"light_color": Color("44bbff"), "light_energy": 1.0, "light_range": 2.2,
				"has_trail": true, "trail_particles": 5, "trail_lifetime": 0.18, "trail_offset": 0.2,
			}
		_:
			return {
				"collision_radius": 0.26,
				"mesh_radius": 0.24, "mesh_height": 0.48, "mesh_segments": 12, "mesh_rings": 7,
				"color": Color("79a9ff"),
				"emission": Color("356dff"),
				"emission_energy": 3.2,
				"roughness": 0.18,
				"has_inner_glow": false,
				"light_color": Color("6f9fff"), "light_energy": 1.4, "light_range": 2.8,
				"has_trail": false, "trail_particles": 0, "trail_lifetime": 0.0, "trail_offset": 0.0,
			}
