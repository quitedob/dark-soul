class_name AshenLevelBuilder
extends RefCounted
## Procedural level geometry construction for the Ashen Hollow arena.
## Composition helper — takes world / materials / brazier array references.

const ProcUtils = preload("res://scripts/core/procedural_utils.gd")

var _world: Node3D
var _materials: Dictionary
var _brazier_lights: Array[OmniLight3D]
var _brazier_flicker_phases: Array[float]


func setup(world_node: Node3D, materials: Dictionary, brazier_lights: Array[OmniLight3D], brazier_flicker_phases: Array[float]) -> void:
	_world = world_node
	_materials = materials
	_brazier_lights = brazier_lights
	_brazier_flicker_phases = brazier_flicker_phases


# -- public API ------------------------------------------------------------


func create_level() -> void:
	_create_block(Vector3(0.0, -0.5, -6.5), Vector3(24.0, 1.0, 43.0), "stone_dark")
	_create_block(Vector3(0.0, -0.2, -27.0), Vector3(18.0, 0.6, 14.0), "stone")
	_create_block(Vector3(-9.0, 2.0, -6.5), Vector3(1.0, 5.0, 43.0), "stone")
	_create_block(Vector3(9.0, 2.0, -6.5), Vector3(1.0, 5.0, 43.0), "stone")
	_create_block(Vector3(0.0, 2.0, 15.0), Vector3(19.0, 5.0, 1.0), "stone")
	_create_block(Vector3(-5.5, 1.1, 2.0), Vector3(5.0, 2.7, 1.0), "stone")
	_create_block(Vector3(5.5, 1.1, 2.0), Vector3(5.0, 2.7, 1.0), "stone")
	_create_block(Vector3(-3.6, 1.2, -5.5), Vector3(6.0, 3.0, 1.0), "stone")
	_create_block(Vector3(5.0, 1.2, -5.5), Vector3(5.0, 3.0, 1.0), "stone")
	_create_block(Vector3(-5.25, 1.6, -18.5), Vector3(6.5, 3.8, 1.0), "stone")
	_create_block(Vector3(5.25, 1.6, -18.5), Vector3(6.5, 3.8, 1.0), "stone")
	for z_position in [-2.0, -10.0, -17.0, -28.0]:
		_create_pillar(Vector3(-7.4, 1.7, z_position))
		_create_pillar(Vector3(7.4, 1.7, z_position))
	_create_block(Vector3(-7.0, 0.2, -7.8), Vector3(3.0, 0.5, 2.5), "moss")
	_create_block(Vector3(6.5, 0.2, -14.0), Vector3(2.6, 0.5, 3.5), "moss")
	for brazier_position in [
		Vector3(-6.4, 0.0, 4.0),
		Vector3(6.4, 0.0, -4.0),
		Vector3(-6.4, 0.0, -15.5),
		Vector3(5.4, 0.0, -22.0),
	]:
		_create_ember_brazier(brazier_position)
	_create_landmark()
	_create_boundary_fog()
	_create_ground_detail()
	_create_wall_detail()
	_create_ceiling_beams()
	_create_atmospheric_particles()


# -- landmark ---------------------------------------------------------------


func _create_landmark() -> void:
	var spire := MeshInstance3D.new()
	spire.name = "BrokenSpire"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 1.4
	mesh.height = 13.0
	mesh.radial_segments = 8
	mesh.material = _materials["stone"]
	spire.mesh = mesh
	spire.position = Vector3(0.0, 6.0, -37.0)
	spire.rotation_degrees.z = -7.0
	_world.add_child(spire)
	# Broken top fragment — tilted block on top
	var fragment := MeshInstance3D.new()
	fragment.name = "SpireTopFragment"
	var frag_mesh := BoxMesh.new()
	frag_mesh.size = Vector3(1.1, 1.4, 1.8)
	frag_mesh.material = _materials["stone"]
	fragment.mesh = frag_mesh
	fragment.position = Vector3(0.3, 8.5, -36.2)
	fragment.rotation_degrees = Vector3(-22.0, 18.0, 5.0)
	_world.add_child(fragment)
	# Rubble at base
	for i in range(4):
		var rubble := MeshInstance3D.new()
		var rubble_mesh := BoxMesh.new()
		rubble_mesh.size = Vector3(0.8 + float(i) * 0.3, 0.4, 0.8 + float(i) * 0.2)
		rubble_mesh.material = _materials["stone_dark"]
		rubble.mesh = rubble_mesh
		var angle := float(i) / 4.0 * TAU + 0.3
		var dist := 2.2 + float(i) * 0.6
		rubble.position = Vector3(sin(angle) * dist, 0.15, -37.0 + cos(angle) * dist * 0.4)
		rubble.rotation_degrees = Vector3(randf() * 20.0, randf() * 60.0, randf() * 15.0)
		_world.add_child(rubble)
	# Beacon light
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0.0, 9.5, -37.0)
	beacon.light_color = Color("f14b28")
	beacon.light_energy = 7.0
	beacon.omni_range = 18.0
	_world.add_child(beacon)


# -- boundary / detail / atmosphere ----------------------------------------


func _create_boundary_fog() -> void:
	for side in [-1.0, 1.0]:
		var veil := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(14.0, 5.0)
		plane.material = _material(Color(0.08, 0.14, 0.2, 0.55), 1.0, 0.0, Color("1d3852"), 0.6, true)
		veil.mesh = plane
		veil.position = Vector3(side * 10.0, 2.0, -26.0)
		veil.rotation_degrees.y = 90.0
		_world.add_child(veil)


func _create_ground_detail() -> void:
	# Scattered rubble stones on the floor
	var rubble_positions := [
		Vector3(-5.2, 0.05, 3.5), Vector3(4.8, 0.05, -1.2), Vector3(-3.5, 0.05, -8.0),
		Vector3(6.0, 0.05, -10.5), Vector3(-6.5, 0.05, -20.0), Vector3(3.2, 0.05, -24.0),
		Vector3(-2.0, 0.05, -14.5), Vector3(7.2, 0.05, -18.0), Vector3(-4.8, 0.05, 8.0),
		Vector3(1.5, 0.05, -3.5), Vector3(-7.0, 0.05, -12.0), Vector3(5.5, 0.05, 6.0),
	]
	for pos in rubble_positions:
		var rubble := MeshInstance3D.new()
		var size := Vector3(randf_range(0.2, 0.6), randf_range(0.08, 0.18), randf_range(0.2, 0.55))
		var box := BoxMesh.new()
		box.size = size
		box.material = _materials["rubble"]
		rubble.mesh = box
		rubble.position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		rubble.rotation_degrees = Vector3(randf_range(0, 15), randf_range(0, 60), randf_range(0, 15))
		_world.add_child(rubble)
	# Ember vein cracks on the floor (emissive lines)
	var vein_positions := [
		Vector3(-3.0, 0.02, -12.0),
		Vector3(4.0, 0.02, -20.0),
		Vector3(-5.5, 0.02, -25.0),
		Vector3(2.0, 0.02, 5.0),
	]
	for pos in vein_positions:
		for k in range(3):
			var vein := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(randf_range(0.3, 0.8), 0.015, randf_range(0.03, 0.06))
			box.material = _materials["ember_vein"]
			vein.mesh = box
			vein.position = pos + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-0.5, 0.5))
			vein.rotation_degrees.y = randf_range(0, 90)
			_world.add_child(vein)


func _create_wall_detail() -> void:
	# Moss patches on walls
	var moss_positions := [
		Vector3(-8.95, 0.6, -3.0), Vector3(8.95, 0.8, -8.0),
		Vector3(-8.95, 1.2, -15.0), Vector3(8.95, 0.5, -22.0),
		Vector3(-8.95, 0.7, -25.0), Vector3(8.95, 1.1, -4.0),
	]
	for pos in moss_positions:
		var moss := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, randf_range(0.5, 1.2), randf_range(0.8, 2.0))
		box.material = _materials["moss"]
		moss.mesh = box
		moss.position = pos
		_world.add_child(moss)
	# Wall crack marks (thin dark lines)
	for i in range(8):
		var crack := MeshInstance3D.new()
		var box := BoxMesh.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := float(i) * 5.5 - 15.0
		box.size = Vector3(0.03, randf_range(0.6, 1.6), randf_range(0.02, 0.04))
		box.material = _materials["stone_dark"]
		crack.mesh = box
		crack.position = Vector3(side * 8.5, randf_range(0.4, 2.2), z)
		crack.rotation_degrees.z = randf_range(-15, 15)
		_world.add_child(crack)
	# Ember vein markings on walls
	for i in range(5):
		var vein := MeshInstance3D.new()
		var box := BoxMesh.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		box.size = Vector3(0.015, randf_range(0.4, 0.9), randf_range(0.03, 0.05))
		box.material = _materials["ember_vein"]
		vein.mesh = box
		vein.position = Vector3(side * 8.51, randf_range(0.5, 2.5), float(i) * 7.0 - 18.0)
		_world.add_child(vein)


func _create_ceiling_beams() -> void:
	# Overhead beams crossing the corridor
	for z_pos in [-3.0, -10.0, -18.0, -26.0]:
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(18.5, 0.2, 0.35)
		box.material = _materials["wood"]
		beam.mesh = box
		beam.position = Vector3(0, 4.3, z_pos)
		_world.add_child(beam)
		# Beam end supports
		for side in [-1.0, 1.0]:
			var bracket := MeshInstance3D.new()
			var bracket_mesh := BoxMesh.new()
			bracket_mesh.size = Vector3(0.25, 0.5, 0.35)
			bracket_mesh.material = _materials["metal"]
			bracket.mesh = bracket_mesh
			bracket.position = Vector3(side * 8.6, 4.0, z_pos)
			_world.add_child(bracket)
	# Hanging chain stubs from beams
	for z_pos in [-3.0, -18.0]:
		for x_off in [-3.0, 3.0]:
			var chain := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.03
			cyl.bottom_radius = 0.03
			cyl.height = randf_range(0.5, 1.2)
			cyl.material = _materials["metal"]
			chain.mesh = cyl
			chain.position = Vector3(x_off, 3.7, z_pos + randf_range(-0.3, 0.3))
			_world.add_child(chain)


func _create_atmospheric_particles() -> void:
	# ── Floating ember motes (main atmospheric) ──
	var ember_particles := GPUParticles3D.new()
	ember_particles.name = "EmberParticles"
	ember_particles.emitting = true
	ember_particles.amount = 50
	ember_particles.lifetime = 4.5
	ember_particles.position = Vector3(0, 2.2, -10.0)
	var ember_box := BoxMesh.new()
	ember_box.size = Vector3(16.0, 3.5, 30.0)
	ember_particles.draw_pass_1 = ember_box
	ember_particles.draw_pass_1.material = _materials["ember"]
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.direction = Vector3(0, 0.5, 0)
	ember_mat.spread = 35.0
	ember_mat.initial_velocity_min = 0.2
	ember_mat.initial_velocity_max = 1.2
	ember_mat.gravity = Vector3(0, 0.18, 0)
	ember_mat.scale_min = 0.06
	ember_mat.scale_max = 0.28
	ember_mat.color = Color(1.0, 0.35, 0.06, 0.65)
	ember_particles.process_material = ember_mat
	_world.add_child(ember_particles)

	# ── Shrine ember fall — concentrated near checkpoint ──
	var shrine_particles := GPUParticles3D.new()
	shrine_particles.name = "ShrineEmbers"
	shrine_particles.emitting = true
	shrine_particles.amount = 20
	shrine_particles.lifetime = 3.5
	shrine_particles.position = Vector3(0, 3.0, 6.0)
	var shrine_ember_mesh := SphereMesh.new()
	shrine_ember_mesh.radius = 0.04
	shrine_ember_mesh.height = 0.08
	shrine_ember_mesh.radial_segments = 6
	shrine_ember_mesh.rings = 3
	shrine_ember_mesh.material = _materials["ember_glow"]
	shrine_particles.draw_pass_1 = shrine_ember_mesh
	var shrine_mat := ParticleProcessMaterial.new()
	shrine_mat.direction = Vector3(0, 1.5, 0)
	shrine_mat.spread = 30.0
	shrine_mat.initial_velocity_min = 0.4
	shrine_mat.initial_velocity_max = 1.8
	shrine_mat.gravity = Vector3(0, 0.08, 0)
	shrine_mat.scale_min = 0.05
	shrine_mat.scale_max = 0.18
	shrine_mat.color = Color(1.0, 0.55, 0.15, 0.6)
	shrine_particles.process_material = shrine_mat
	_world.add_child(shrine_particles)

	# ── Ambient dust motes ──
	var dust_particles := GPUParticles3D.new()
	dust_particles.name = "DustParticles"
	dust_particles.emitting = true
	dust_particles.amount = 30
	dust_particles.lifetime = 7.0
	dust_particles.position = Vector3(0, 1.0, -10.0)
	var dust_sphere := SphereMesh.new()
	dust_sphere.radius = 0.02
	dust_sphere.height = 0.04
	var dust_mesh_mat := _material(Color(0.5, 0.55, 0.6, 0.3), 0.0, 0.0)
	dust_sphere.material = dust_mesh_mat
	dust_particles.draw_pass_1 = dust_sphere
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0, 0, 0)
	dust_mat.spread = 180.0
	dust_mat.initial_velocity_min = 0.04
	dust_mat.initial_velocity_max = 0.25
	dust_mat.gravity = Vector3(0, -0.015, 0)
	dust_mat.scale_min = 0.5
	dust_mat.scale_max = 1.8
	dust_mat.color = Color(0.6, 0.65, 0.7, 0.2)
	dust_particles.process_material = dust_mat
	_world.add_child(dust_particles)

	# ── Mist patches near the ground ──
	var mist_particles := GPUParticles3D.new()
	mist_particles.name = "MistParticles"
	mist_particles.emitting = true
	mist_particles.amount = 15
	mist_particles.lifetime = 8.0
	mist_particles.position = Vector3(0, 0.3, -8.0)
	var mist_mesh := QuadMesh.new()
	mist_mesh.size = Vector2(0.6, 0.3)
	mist_mesh.material = _material(Color(0.35, 0.4, 0.5, 0.25), 0.0, 0.0, Color.BLACK, 0.0, true)
	mist_particles.draw_pass_1 = mist_mesh
	var mist_mat := ParticleProcessMaterial.new()
	mist_mat.direction = Vector3(0, 0.05, 0)
	mist_mat.spread = 120.0
	mist_mat.initial_velocity_min = 0.02
	mist_mat.initial_velocity_max = 0.15
	mist_mat.gravity = Vector3(0, -0.02, 0)
	mist_mat.scale_min = 1.0
	mist_mat.scale_max = 3.5
	mist_mat.color = Color(0.5, 0.55, 0.65, 0.12)
	mist_particles.process_material = mist_mat
	_world.add_child(mist_particles)


# -- pillar / brazier / gate / block ---------------------------------------


func _create_pillar(at: Vector3) -> void:
	# Pillar shaft
	_create_block(at, Vector3(1.1, 3.4, 1.1), "stone")
	# Capital (top)
	_create_block(at + Vector3(0.0, 1.9, 0.0), Vector3(1.6, 0.35, 1.6), "stone")
	# Base plinth
	_create_block(at + Vector3(0.0, -1.55, 0.0), Vector3(1.4, 0.25, 1.4), "stone_dark")


func _create_ember_brazier(at: Vector3) -> void:
	var brazier := Node3D.new()
	brazier.name = "EmberBrazier"
	brazier.position = at
	_world.add_child(brazier)

	# Base stone
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.38
	base_mesh.height = 0.15
	base_mesh.radial_segments = 10
	base_mesh.material = _materials["stone"]
	base.mesh = base_mesh
	base.position.y = 0.07
	brazier.add_child(base)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.24
	pedestal_mesh.bottom_radius = 0.34
	pedestal_mesh.height = 1.15
	pedestal_mesh.radial_segments = 10
	pedestal_mesh.material = _materials["metal"]
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.64
	brazier.add_child(pedestal)

	# Metal ring band
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.28
	band_mesh.bottom_radius = 0.28
	band_mesh.height = 0.06
	band_mesh.radial_segments = 10
	band_mesh.material = _materials["metal"]
	band.mesh = band_mesh
	band.position.y = 1.0
	brazier.add_child(band)

	var ember_core := MeshInstance3D.new()
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.22
	ember_mesh.height = 0.42
	ember_mesh.radial_segments = 10
	ember_mesh.rings = 6
	ember_mesh.material = _materials["ember"]
	ember_core.mesh = ember_mesh
	ember_core.position.y = 1.28
	brazier.add_child(ember_core)

	# Inner flame wisp
	var wisp := MeshInstance3D.new()
	var wisp_mesh := SphereMesh.new()
	wisp_mesh.radius = 0.12
	wisp_mesh.height = 0.24
	wisp_mesh.radial_segments = 8
	wisp_mesh.rings = 4
	var wisp_mat := _material(Color(1.0, 0.95, 0.5), 0.15, 0.0, Color(1.0, 0.6, 0.1), 5.0)
	wisp.mesh = wisp_mesh
	wisp.position.y = 1.32
	wisp.material_override = wisp_mat
	brazier.add_child(wisp)

	var light := OmniLight3D.new()
	light.position.y = 1.38
	light.light_color = Color("ff7338")
	light.light_energy = 2.8
	light.omni_range = 7.0
	light.shadow_enabled = false
	brazier.add_child(light)
	_brazier_lights.append(light)
	_brazier_flicker_phases.append(randf() * TAU)


func _create_gate(at: Vector3) -> Node3D:
	var gate := Node3D.new()
	gate.name = "ShortcutGate"
	gate.position = at
	_world.add_child(gate)
	# Vertical bars
	for offset: float in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 3.0, 0.3)
		mesh.material = _materials["metal"]
		bar.mesh = mesh
		bar.position = Vector3(offset, 0.0, 0.0)
		gate.add_child(bar)
	# Top crossbeam
	var beam := MeshInstance3D.new()
	beam.name = "GateBeam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(3.8, 0.22, 0.35)
	beam_mesh.material = _materials["metal"]
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, 1.55, 0.0)
	gate.add_child(beam)
	# Bottom crossbeam
	var bot_beam := MeshInstance3D.new()
	bot_beam.name = "GateBottomBeam"
	var bot_mesh := BoxMesh.new()
	bot_mesh.size = Vector3(3.8, 0.18, 0.3)
	bot_mesh.material = _materials["metal"]
	bot_beam.mesh = bot_mesh
	bot_beam.position = Vector3(0.0, -1.55, 0.0)
	gate.add_child(bot_beam)
	# Rivets on crossbeam
	for rivet_x in [-1.5, -0.5, 0.5, 1.5]:
		var rivet := MeshInstance3D.new()
		var rivet_mesh := SphereMesh.new()
		rivet_mesh.radius = 0.06
		rivet_mesh.height = 0.10
		rivet_mesh.material = _materials["metal"]
		rivet.mesh = rivet_mesh
		rivet.position = Vector3(rivet_x, 1.66, 0.18)
		gate.add_child(rivet)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.5)
	shape.shape = box
	body.add_child(shape)
	gate.add_child(body)
	return gate


func _create_block(at: Vector3, size: Vector3, material_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _materials[material_name]
	visual.mesh = mesh
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	return body


# -- helpers ---------------------------------------------------------------


func _material(color: Color, roughness: float, metallic: float, emission := Color.BLACK, emission_energy := 0.0, transparent := false) -> StandardMaterial3D:
	return ProcUtils.make_material(color, roughness, metallic, emission, emission_energy, transparent)
