class_name Chapter3EnemyFactory
extends RefCounted
## Chapter 3 enemy body types and weapon shapes: 玉障·迷心

const C1EF = preload("res://scripts/combat/chapter_1_enemy_factory.gd")
const EF = preload("res://scripts/combat/enemy_factory.gd")


static func build_body(parent: Node3D, body_type: String, mat: StandardMaterial3D) -> void:
	match body_type:
		"floating_small":    _build_floating_small(parent, mat)
		"ethereal_thin":     _build_ethereal_thin(parent, mat)
		"floating_orb":      _build_floating_orb(parent, mat)
		"lantern_float":     _build_lantern_float(parent, mat)
		"floating_dress":    _build_floating_dress(parent, mat)
		"reflection_clone":  _build_reflection_clone(parent, mat)
		"flower_stationary": _build_flower_stationary(parent, mat)
		"beast_humanoid":    _build_beast_humanoid(parent, mat)
		_:
			pass


static func _build_floating_small(parent: Node3D, mat: StandardMaterial3D) -> void:
	var wing_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.5, 0.8, 1.0), Color(0.3, 0.6, 0.9), 2.5)
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.albedo_color.a = 0.65
	EF.box(parent, Vector3(0.25, 0.02, 0.15), Vector3(0, 0.05, 0), Vector3(0.15, 0, 0), wing_mat)
	EF.box(parent, Vector3(0.25, 0.02, 0.15), Vector3(0, 0.05, 0), Vector3(-0.15, 0, 0), wing_mat)
	EF.cyl(parent, 0.03, 0.03, 0.08, Vector3(0, 0, 0), Vector3.ZERO, mat)


static func _build_ethereal_thin(parent: Node3D, mat: StandardMaterial3D) -> void:
	var eth_mat := EF.mat_variant(mat, mat.albedo_color, 0.0, 0.8)
	eth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eth_mat.albedo_color.a = 0.55
	EF.cyl(parent, 0.08, 0.09, 1.55, Vector3(0, 0.68, 0), Vector3.ZERO, eth_mat)
	EF.sph(parent, 0.11, 0.18, Vector3(0, 1.35, 0.04), eth_mat)


static func _build_floating_orb(parent: Node3D, mat: StandardMaterial3D) -> void:
	var glow_mat := EF.mat_emissive(StandardMaterial3D.new(), mat.albedo_color, Color(0.3, 0.5, 0.8), 3.0)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color.a = 0.6
	EF.sph(parent, 0.18, 0.35, Vector3(0, 0.05, 0), glow_mat)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.20
	torus.outer_radius = 0.24
	torus.rings = 16
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = glow_mat
	parent.add_child(ring)


static func _build_lantern_float(parent: Node3D, mat: StandardMaterial3D) -> void:
	var lantern_mat := EF.mat_variant(mat, Color(0.9, 0.85, 0.7), 0.0, 0.8)
	lantern_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lantern_mat.albedo_color.a = 0.7
	EF.cyl(parent, 0.16, 0.18, 0.35, Vector3(0, 0.15, 0), Vector3.ZERO, lantern_mat)
	var flame := EF.mat_emissive(StandardMaterial3D.new(), Color(0.2, 0.9, 0.8), Color(0.0, 1.0, 0.8), 4.0)
	EF.sph(parent, 0.1, 0.18, Vector3(0, 0.2, 0), flame)


static func _build_floating_dress(parent: Node3D, mat: StandardMaterial3D) -> void:
	var dress_mat := EF.mat_variant(mat, mat.albedo_color, 0.0, 0.9)
	dress_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dress_mat.albedo_color.a = 0.6
	EF.cyl(parent, 0.10, 0.09, 0.55, Vector3(0, 1.05, 0), Vector3.ZERO, dress_mat)
	EF.cyl(parent, 0.08, 0.25, 0.65, Vector3(0, 0.35, 0), Vector3.ZERO, dress_mat)
	EF.sph(parent, 0.12, 0.22, Vector3(0, 1.4, 0.05), dress_mat)


static func _build_reflection_clone(parent: Node3D, mat: StandardMaterial3D) -> void:
	var refl_mat := EF.mat_variant(mat, mat.albedo_color, mat.metallic, 0.05)
	refl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	refl_mat.albedo_color.a = 0.45
	refl_mat.emission_enabled = true
	refl_mat.emission = Color(0.3, 0.5, 0.8)
	refl_mat.emission_energy_multiplier = 1.2
	EF.cyl(parent, 0.12, 0.13, 1.72, Vector3(0, 0.78, 0), Vector3.ZERO, refl_mat)
	EF.sph(parent, 0.14, 0.24, Vector3(0, 1.52, 0.05), refl_mat)


static func _build_flower_stationary(parent: Node3D, mat: StandardMaterial3D) -> void:
	var petal_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.55, 0.65), Color(1.0, 0.3, 0.5), 2.0)
	EF.cyl(parent, 0.05, 0.06, 0.35, Vector3(0, 0.18, 0), Vector3.ZERO, mat)
	for i in range(5):
		var angle := float(i) / 5.0 * TAU
		EF.box(parent, Vector3(0.06, 0.18, 0.02), Vector3(cos(angle) * 0.10, 0.32, sin(angle) * 0.10), Vector3(0, 0, angle), petal_mat)


static func _build_beast_humanoid(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.cyl(parent, 0.12, 0.13, 1.62, Vector3(0, 0.72, 0), Vector3.ZERO, mat)
	EF.sph(parent, 0.14, 0.24, Vector3(0, 1.42, 0.08), mat)
	var ear_mat := EF.mat_variant(mat, mat.albedo_color.lightened(0.1), mat.metallic, mat.roughness * 0.8)
	EF.box(parent, Vector3(0.06, 0.14, 0.03), Vector3(-0.08, 1.55, -0.02), Vector3(-0.25, 0, 0), ear_mat)
	EF.box(parent, Vector3(0.06, 0.14, 0.03), Vector3(0.08, 1.55, -0.02), Vector3(0.25, 0, 0), ear_mat)
	EF.cyl(parent, 0.04, 0.07, 0.45, Vector3(0, 0.3, 0.18), Vector3(0.5, 0, 0), ear_mat)


# Weapon shapes
static func build_weapon(parent: Node3D, weapon_id: String, mat: StandardMaterial3D) -> void:
	match weapon_id:
		"wing_blade":     _w_wing_blade(parent, mat)
		"memory_claw":    _w_memory_claw(parent, mat)
		"sound_wave":     _w_sound_wave(parent, mat)
		"fox_fire_orb":   _w_fox_fire_orb(parent, mat)
		"sleeve_blade":   _w_sleeve_blade(parent, mat)
		"water_orb":      _w_water_orb(parent, mat)
		"petal_blade":    _w_petal_blade(parent, mat)
		"jade_halberd":   _w_jade_halberd(parent, mat)
		"fox_claw":       _w_fox_claw(parent, mat)
		_:
			pass


static func _w_wing_blade(p: Node3D, m: StandardMaterial3D) -> void:
	for side in [-1.0, 1.0]:
		EF.box(p, Vector3(0.02, 0.06, 0.22), Vector3(side * 0.1, 0.03, 0), Vector3(0, 0, side * 0.2), m)


static func _w_memory_claw(p: Node3D, m: StandardMaterial3D) -> void:
	for i in range(3):
		EF.box(p, Vector3(0.02, 0.03, 0.15), Vector3(0, 0.08, 0.1), Vector3(float(i - 1) * 0.3, 0, 0), m)


static func _w_sound_wave(p: Node3D, m: StandardMaterial3D) -> void:
	var wave_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.3, 0.5, 0.8), Color(0.2, 0.4, 0.7), 3.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.16
	torus.rings = 16
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = wave_mat
	p.add_child(ring)


static func _w_fox_fire_orb(p: Node3D, m: StandardMaterial3D) -> void:
	var ff := EF.mat_emissive(StandardMaterial3D.new(), Color(0.0, 1.0, 0.8), Color(0.0, 0.8, 0.6), 4.5)
	EF.sph(p, 0.14, 0.28, Vector3(0, 0.05, 0), ff)


static func _w_sleeve_blade(p: Node3D, m: StandardMaterial3D) -> void:
	EF.box(p, Vector3(0.02, 0.04, 0.35), Vector3(0, 0, -0.05), Vector3(0, 0, 0), m)


static func _w_water_orb(p: Node3D, m: StandardMaterial3D) -> void:
	var w_mat := EF.mat_variant(m, m.albedo_color, 0.0, 0.05)
	w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w_mat.albedo_color.a = 0.5
	w_mat.emission_enabled = true
	w_mat.emission = Color(0.2, 0.5, 0.9)
	w_mat.emission_energy_multiplier = 1.5
	EF.sph(p, 0.16, 0.3, Vector3(0, 0, 0), w_mat)


static func _w_petal_blade(p: Node3D, m: StandardMaterial3D) -> void:
	for i in range(5):
		EF.box(p, Vector3(0.04, 0.1, 0.01), Vector3(cos(float(i) / 5.0 * TAU) * 0.08, 0.05, sin(float(i) / 5.0 * TAU) * 0.08), Vector3(0, 0, float(i) / 5.0 * TAU), m)


static func _w_jade_halberd(p: Node3D, m: StandardMaterial3D) -> void:
	C1EF._w_ch1_halberd(p, m)


static func _w_fox_claw(p: Node3D, m: StandardMaterial3D) -> void:
	for i in range(3):
		EF.box(p, Vector3(0.03, 0.04, 0.12), Vector3(0.03 * float(i - 1), 0.05, 0.08), Vector3(0.15, 0, 0), m)
