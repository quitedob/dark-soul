class_name Chapter1EnemyFactory
extends RefCounted
## Chapter 1 enemy body types and weapon shapes: 灵墟·觉醒

const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const EF = preload("res://scripts/combat/enemy_factory.gd")  # Shared helpers


static func build_body(parent: Node3D, body_type: String, mat: StandardMaterial3D) -> void:
	match body_type:
		"wraith_thin":       _build_wraith_thin(parent, mat)
		"armored_medium":    _build_armored_medium(parent, mat)
		"ethereal_flicker":  _build_ethereal_flicker(parent, mat)
		"hulking_molten":    _build_hulking_molten(parent, mat)
		_:
			pass


static func _build_wraith_thin(parent: Node3D, mat: StandardMaterial3D) -> void:
	var body_mat := EF.mat_variant(mat, mat.albedo_color, mat.metallic, mat.roughness * 0.85)
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.albedo_color.a = 0.72
	EF.cyl(parent, 0.09, 0.10, 1.65, Vector3(0, 0.72, 0), Vector3.ZERO, body_mat)
	EF.sph(parent, 0.13, 0.22, Vector3(0, 1.45, 0.05), body_mat)
	for i in range(3):
		EF.box(parent, Vector3(0.04, 0.35, 0.01), Vector3(sin(float(i)) * 0.12, 0.5 + float(i) * 0.08, 0.08), Vector3(sin(float(i)) * 0.15, 0, 0), body_mat)


static func _build_armored_medium(parent: Node3D, mat: StandardMaterial3D) -> void:
	CharacterMeshFactory.build_enemy(parent, "cinder_guardian", mat)
	if parent.get_child_count() > 0:
		var root := parent.get_child(0) as Node3D
		if root != null:
			root.scale = Vector3(0.78, 0.78, 0.78)


static func _build_ethereal_flicker(parent: Node3D, mat: StandardMaterial3D) -> void:
	var glass_mat := EF.mat_variant(mat, Color(0.85, 0.88, 0.92), 0.0, 0.1)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color.a = 0.38
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.75, 0.78, 0.85)
	glass_mat.emission_energy_multiplier = 1.8
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.22, 1.55, 0.22)
	prism.mesh = pm
	prism.position = Vector3(0, 0.78, 0)
	prism.material_override = glass_mat
	parent.add_child(prism)


static func _build_hulking_molten(parent: Node3D, mat: StandardMaterial3D) -> void:
	var slag_mat := EF.mat_variant(mat, Color(0.35, 0.18, 0.08), 0.0, 0.85)
	slag_mat.emission_enabled = true
	slag_mat.emission = Color(0.8, 0.25, 0.05)
	slag_mat.emission_energy_multiplier = 1.5
	EF.sph(parent, 0.48, 0.95, Vector3(0, 0.95, 0), slag_mat)
	EF.sph(parent, 0.32, 0.55, Vector3(-0.42, 1.52, 0), slag_mat)
	EF.sph(parent, 0.32, 0.55, Vector3(0.42, 1.52, 0), slag_mat)
	EF.cyl(parent, 0.22, 0.25, 0.45, Vector3(-0.18, 0.22, 0), Vector3.ZERO, slag_mat)
	EF.cyl(parent, 0.22, 0.25, 0.45, Vector3(0.18, 0.22, 0), Vector3.ZERO, slag_mat)


# Weapon shapes
static func build_weapon(parent: Node3D, weapon_id: String, mat: StandardMaterial3D) -> void:
	match weapon_id:
		"rusted_blade":   _w_rusted_blade(parent, mat)
		"temple_halberd": _w_ch1_halberd(parent, mat)
		"glass_shard":    _w_glass_shard(parent, mat)
		"slag_fist":      _w_slag_fist(parent, mat)
		_:
			pass


static func _w_rusted_blade(p: Node3D, m: StandardMaterial3D) -> void:
	EF.box(p, Vector3(0.05, 1.15, 0.03), Vector3(0, 0.98, -0.01), Vector3.ZERO, m)
	EF.box(p, Vector3(0.16, 0.04, 0.06), Vector3(0, 0.35, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.02, 0.06, 0.02), Vector3(0, 1.55, -0.01), Vector3.ZERO, m)


static func _w_ch1_halberd(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.03, 0.04, 1.85, Vector3(0, 0.45, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.02, 0.25, 0.04), Vector3(0, 1.45, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.08, 0.04, 0.02), Vector3(0, 1.32, 0.03), Vector3.ZERO, m)


static func _w_glass_shard(p: Node3D, m: StandardMaterial3D) -> void:
	var glass_mat := EF.mat_variant(m, m.albedo_color, 0.0, 0.05)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color.a = 0.5
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.08, 0.95, 0.08)
	prism.mesh = pm
	prism.position = Vector3(0, 0.45, 0)
	prism.material_override = glass_mat
	p.add_child(prism)


static func _w_slag_fist(p: Node3D, m: StandardMaterial3D) -> void:
	var slag_mat := EF.mat_emissive(m, m.albedo_color, Color(0.8, 0.2, 0.05), 2.0)
	EF.sph(p, 0.18, 0.32, Vector3(0, 0.0, 0), slag_mat)
	EF.sph(p, 0.16, 0.28, Vector3(0.05, 0.12, 0.08), slag_mat)
	EF.sph(p, 0.16, 0.28, Vector3(-0.05, 0.08, -0.05), slag_mat)
