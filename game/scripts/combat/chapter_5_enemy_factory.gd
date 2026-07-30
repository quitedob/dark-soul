class_name Chapter5EnemyFactory
extends RefCounted
## Chapter 5 enemy body types and weapon shapes: 烬座·归墟

const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const EF = preload("res://scripts/combat/enemy_factory.gd")


static func build_body(parent: Node3D, body_type: String, mat: StandardMaterial3D) -> void:
	match body_type:
		"void_wraith":       _build_void_wraith(parent, mat)
		"gravity_armor":     _build_gravity_armor(parent, mat)
		"flying_small":      _build_flying_small(parent, mat)
		"shadow_form":       _build_shadow_form(parent, mat)
		"quantum_shimmer":   _build_quantum_shimmer(parent, mat)
		"ancient_giant":     _build_ancient_giant(parent, mat)
		_:
			pass


static func _build_void_wraith(parent: Node3D, mat: StandardMaterial3D) -> void:
	var void_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.1, 0.1, 0.2), Color(0.2, 0.3, 0.8), 0.8)
	void_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	void_mat.albedo_color.a = 0.65
	EF.cyl(parent, 0.1, 0.12, 1.7, Vector3(0, 0.75, 0), Vector3.ZERO, void_mat)
	EF.sph(parent, 0.14, 0.24, Vector3(0, 1.5, 0.05), void_mat)
	for i in range(4):
		EF.cyl(parent, 0.02, 0.03, 0.35, Vector3(cos(float(i) * 1.57) * 0.15, 0.6, sin(float(i) * 1.57) * 0.15), Vector3(0.4, 0, float(i) * 1.57), void_mat)


static func _build_gravity_armor(parent: Node3D, mat: StandardMaterial3D) -> void:
	CharacterMeshFactory.build_enemy(parent, "cinder_guardian", mat)
	if parent.get_child_count() > 0:
		var root := parent.get_child(0) as Node3D
		if root != null:
			root.scale = Vector3(0.9, 0.9, 0.9)
	var ring_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.3, 0.3, 0.8), Color(0.2, 0.2, 0.6), 2.0)
	for i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28 - float(i) * 0.04
		torus.outer_radius = 0.32 - float(i) * 0.04
		torus.rings = 16
		torus.ring_segments = 12
		ring.mesh = torus
		ring.position = Vector3(0, 0.15 + float(i) * 0.22, 0)
		ring.material_override = ring_mat
		parent.add_child(ring)


static func _build_flying_small(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.box(parent, Vector3(0.12, 0.08, 0.18), Vector3(0, 0.05, 0), Vector3.ZERO, mat)
	var wing_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.8, 0.2, 0.05), Color(1.0, 0.15, 0.02), 3.0)
	for side in [-1.0, 1.0]:
		EF.box(parent, Vector3(0.02, 0.03, 0.25), Vector3(side * 0.1, 0.08, 0), Vector3(0, 0, side * 0.3), wing_mat)


static func _build_shadow_form(parent: Node3D, mat: StandardMaterial3D) -> void:
	var shadow_mat := EF.mat_variant(mat, Color(0.05, 0.05, 0.1), 0.0, 0.95)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color.a = 0.5
	EF.box(parent, Vector3(0.35, 0.02, 0.35), Vector3(0, 0.02, 0), Vector3.ZERO, shadow_mat)
	EF.cyl(parent, 0.05, 0.07, 1.5, Vector3(0, 0.7, 0), Vector3.ZERO, shadow_mat)


static func _build_quantum_shimmer(parent: Node3D, mat: StandardMaterial3D) -> void:
	var shift_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(0.1, 0.1, 0.3), Color(0.2, 0.2, 0.8), 1.5)
	shift_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shift_mat.albedo_color.a = 0.45
	for i in range(3):
		var prism := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.2 + float(i) * 0.04, 1.3 + float(i) * 0.1, 0.2 + float(i) * 0.04)
		prism.mesh = pm
		prism.position = Vector3(sin(float(i)) * 0.08, 0.65, cos(float(i)) * 0.08)
		prism.rotation = Vector3(float(i) * 0.3, float(i) * 0.8, float(i) * 0.5)
		prism.material_override = shift_mat
		parent.add_child(prism)


static func _build_ancient_giant(parent: Node3D, mat: StandardMaterial3D) -> void:
	var ancient_mat := EF.mat_variant(mat, mat.albedo_color, mat.metallic + 0.2, mat.roughness * 0.6)
	ancient_mat.emission_enabled = true
	ancient_mat.emission = Color(0.8, 0.7, 0.3)
	ancient_mat.emission_energy_multiplier = 1.2
	EF.sph(parent, 0.45, 0.9, Vector3(0, 1.65, 0), ancient_mat)
	EF.cyl(parent, 0.22, 0.28, 1.2, Vector3(-0.25, 0.60, 0), Vector3.ZERO, ancient_mat)
	EF.cyl(parent, 0.22, 0.28, 1.2, Vector3(0.25, 0.60, 0), Vector3.ZERO, ancient_mat)
	for i in range(3):
		EF.box(parent, Vector3(0.02, 0.08, 0.02), Vector3(0, 1.4 + float(i) * 0.22, 0.22), Vector3.ZERO, mat)


# Weapon shapes
static func build_weapon(parent: Node3D, weapon_id: String, mat: StandardMaterial3D) -> void:
	match weapon_id:
		"drift_blade":      _w_drift_blade(parent, mat)
		"inverted_halberd": _w_inverted_halberd(parent, mat)
		"ember_wing":       _w_ember_wing(parent, mat)
		"shadow_blade":     _w_shadow_blade(parent, mat)
		"possibility_orb":  _w_possibility_orb(parent, mat)
		"soul_hammer":      _w_soul_hammer(parent, mat)
		_:
			pass


static func _w_drift_blade(p: Node3D, m: StandardMaterial3D) -> void:
	var void_mat := EF.mat_variant(m, m.albedo_color, m.metallic, m.roughness * 0.6)
	void_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	void_mat.albedo_color.a = 0.65
	EF.box(p, Vector3(0.04, 1.25, 0.03), Vector3(0, 0.95, -0.01), Vector3.ZERO, void_mat)


static func _w_inverted_halberd(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.04, 0.05, 1.75, Vector3(0, 0.35, 0), Vector3(PI, 0, 0), m)
	EF.box(p, Vector3(0.03, 0.07, 0.32), Vector3(0, -0.38, 0), Vector3.ZERO, m)


static func _w_ember_wing(p: Node3D, m: StandardMaterial3D) -> void:
	var ew := EF.mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.15, 0.02), Color(0.9, 0.1, 0.01), 4.0)
	for side in [-1.0, 1.0]:
		EF.box(p, Vector3(0.01, 0.02, 0.18), Vector3(side * 0.05, 0.02, 0), Vector3(0, 0, side * 0.25), ew)


static func _w_shadow_blade(p: Node3D, m: StandardMaterial3D) -> void:
	var sb := EF.mat_variant(m, Color(0.02, 0.02, 0.04), 0.0, 0.95)
	sb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sb.albedo_color.a = 0.55
	EF.box(p, Vector3(0.05, 1.2, 0.01), Vector3(0, 0.9, 0), Vector3.ZERO, sb)


static func _w_possibility_orb(p: Node3D, m: StandardMaterial3D) -> void:
	var po := EF.mat_emissive(StandardMaterial3D.new(), Color(0.15, 0.15, 0.4), Color(0.1, 0.1, 0.3), 2.0)
	EF.sph(p, 0.15, 0.28, Vector3.ZERO, po)


static func _w_soul_hammer(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.05, 0.06, 1.3, Vector3(0, 0.25, 0), Vector3.ZERO, m)
	var hm := EF.mat_emissive(StandardMaterial3D.new(), m.albedo_color, Color(0.8, 0.7, 0.2), 3.0)
	EF.box(p, Vector3(0.18, 0.22, 0.18), Vector3(0, 0.98, 0), Vector3.ZERO, hm)
