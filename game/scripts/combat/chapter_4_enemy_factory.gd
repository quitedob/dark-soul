class_name Chapter4EnemyFactory
extends RefCounted
## Chapter 4 enemy body types and weapon shapes: 天崩·陨落

const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const EF = preload("res://scripts/combat/enemy_factory.gd")


static func build_body(parent: Node3D, body_type: String, mat: StandardMaterial3D) -> void:
	match body_type:
		"celestial_guard": _build_celestial_guard(parent, mat)
		"flying_large":    _build_flying_large(parent, mat)
		"barrel_heavy":    _build_barrel_heavy(parent, mat)
		"robed_caster":    _build_robed_caster(parent, mat)
		"floating_book":   _build_floating_book(parent, mat)
		"shambling_giant": _build_shambling_giant(parent, mat)
		_:
			pass


static func _build_celestial_guard(parent: Node3D, mat: StandardMaterial3D) -> void:
	var c_mat := EF.mat_variant(mat, mat.albedo_color, mat.metallic + 0.15, mat.roughness * 0.6)
	c_mat.emission_enabled = true
	c_mat.emission = Color(0.7, 0.7, 0.9)
	c_mat.emission_energy_multiplier = 0.8
	EF.cyl(parent, 0.13, 0.14, 1.78, Vector3(0, 0.8, 0), Vector3.ZERO, c_mat)
	EF.sph(parent, 0.15, 0.26, Vector3(0, 1.58, 0.05), c_mat)
	var wing_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.85, 0.85, 1.0), Color(0.6, 0.6, 0.9), 1.5)
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.albedo_color.a = 0.55
	for side in [-1.0, 1.0]:
		for i in range(3):
			EF.box(parent, Vector3(0.03, 0.08, 0.35), Vector3(side * 0.18, 1.35 + float(i) * 0.12, -0.05), Vector3(0, side * 0.3, 0), wing_mat)


static func _build_flying_large(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.box(parent, Vector3(0.28, 0.22, 0.55), Vector3(0, 0.12, 0), Vector3.ZERO, mat)
	for side in [-1.0, 1.0]:
		EF.box(parent, Vector3(0.04, 0.06, 0.9), Vector3(side * 0.22, 0.15, 0), Vector3(0, 0, side * 0.35), mat)
	EF.sph(parent, 0.1, 0.16, Vector3(0, 0.22, 0.35), mat)


static func _build_barrel_heavy(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.cyl(parent, 0.28, 0.30, 0.88, Vector3(0, 0.45, 0), Vector3.ZERO, mat)
	EF.cyl(parent, 0.08, 0.06, 0.18, Vector3(0, 0.92, 0), Vector3.ZERO, mat)
	var fire_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.5, 0.1), Color(1.0, 0.3, 0.02), 3.5)
	EF.sph(parent, 0.08, 0.15, Vector3(0, 1.02, 0), fire_mat)


static func _build_robed_caster(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.cyl(parent, 0.11, 0.12, 1.65, Vector3(0, 0.72, 0), Vector3.ZERO, mat)
	EF.sph(parent, 0.13, 0.22, Vector3(0, 1.42, 0.05), mat)
	EF.box(parent, Vector3(0.10, 0.08, 0.35), Vector3(-0.22, 1.15, -0.1), Vector3(0.15, 0, 0), mat)
	EF.box(parent, Vector3(0.10, 0.08, 0.35), Vector3(0.22, 1.15, -0.1), Vector3(-0.15, 0, 0), mat)


static func _build_floating_book(parent: Node3D, mat: StandardMaterial3D) -> void:
	var cover_mat := EF.mat_variant(mat, Color(0.75, 0.65, 0.4), 0.0, 0.85)
	EF.box(parent, Vector3(0.28, 0.04, 0.35), Vector3(0, 0.0, 0), Vector3.ZERO, cover_mat)
	EF.box(parent, Vector3(0.28, 0.04, 0.35), Vector3(0, 0.0, -0.18), Vector3(0.35, 0, 0), cover_mat)
	var page_mat := EF.mat_variant(mat, Color(0.9, 0.88, 0.7), 0.0, 0.95)
	for i in range(4):
		EF.box(parent, Vector3(0.12, 0.005, 0.16), Vector3(0, 0.12 + float(i) * 0.06, 0.05), Vector3(float(i) * 0.4, 0, float(i) * 0.5), page_mat)


static func _build_shambling_giant(parent: Node3D, mat: StandardMaterial3D) -> void:
	var crack_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.9, 0.6), Color(1.0, 0.7, 0.3), 2.5)
	EF.sph(parent, 0.38, 0.75, Vector3(0, 1.35, 0), mat)
	EF.cyl(parent, 0.18, 0.22, 0.95, Vector3(-0.2, 0.48, 0), Vector3.ZERO, mat)
	EF.cyl(parent, 0.18, 0.22, 0.95, Vector3(0.2, 0.48, 0), Vector3.ZERO, mat)
	EF.box(parent, Vector3(0.02, 0.35, 0.02), Vector3(0, 1.25, 0.15), Vector3(0.1, 0, 0), crack_mat)
	EF.box(parent, Vector3(0.02, 0.28, 0.02), Vector3(0.08, 1.15, 0.18), Vector3(-0.15, 0, 0), crack_mat)


# Weapon shapes
static func build_weapon(parent: Node3D, weapon_id: String, mat: StandardMaterial3D) -> void:
	match weapon_id:
		"cloud_glaive":    _w_cloud_glaive(parent, mat)
		"talon":           _w_talon(parent, mat)
		"furnace_body":    _w_furnace_body(parent, mat)
		"alchemy_sword":   _w_alchemy_sword(parent, mat)
		"floating_pages":  _w_floating_pages(parent, mat)
		"scripture_blade": _w_scripture_blade(parent, mat)
		"broken_limb":     _w_broken_limb(parent, mat)
		_:
			pass


static func _w_cloud_glaive(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.04, 0.05, 1.6, Vector3(0, 0.35, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.03, 0.06, 0.32), Vector3(0, 1.15, 0.02), Vector3(0.15, 0, 0), m)


static func _w_talon(p: Node3D, m: StandardMaterial3D) -> void:
	for i in range(3):
		EF.box(p, Vector3(0.02, 0.03, 0.12), Vector3(float(i - 1) * 0.04, 0.02, 0.05), Vector3(0.25, 0, 0), m)


static func _w_furnace_body(p: Node3D, m: StandardMaterial3D) -> void:
	var f_mat := EF.mat_emissive(StandardMaterial3D.new(), m.albedo_color, Color(1.0, 0.4, 0.1), 3.0)
	EF.cyl(p, 0.18, 0.20, 0.45, Vector3(0, 0.22, 0), Vector3.ZERO, f_mat)


static func _w_alchemy_sword(p: Node3D, m: StandardMaterial3D) -> void:
	EF.box(p, Vector3(0.05, 1.2, 0.03), Vector3(0, 1.0, 0), Vector3.ZERO, m)
	var poi_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.2, 0.8, 0.2), Color(0.1, 0.6, 0.1), 2.0)
	EF.sph(p, 0.05, 0.08, Vector3(0, 0.28, 0.04), poi_mat)


static func _w_floating_pages(p: Node3D, m: StandardMaterial3D) -> void:
	for i in range(5):
		EF.box(p, Vector3(0.08, 0.003, 0.12), Vector3(0, float(i) * 0.06, float(i) * 0.03), Vector3(float(i) * 0.5, 0, float(i) * 0.4), m)


static func _w_scripture_blade(p: Node3D, m: StandardMaterial3D) -> void:
	EF.box(p, Vector3(0.06, 1.35, 0.05), Vector3(0, 1.05, 0), Vector3.ZERO, m)
	var text_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.9, 0.8, 0.4), Color(0.8, 0.7, 0.3), 2.5)
	EF.box(p, Vector3(0.02, 0.8, 0.005), Vector3(0, 1.0, 0.03), Vector3.ZERO, text_mat)


static func _w_broken_limb(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.08, 0.12, 1.2, Vector3(0, 0.6, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.10, 0.08, 0.15), Vector3(0.05, 1.25, 0.02), Vector3(0.2, 0, 0.15), m)
