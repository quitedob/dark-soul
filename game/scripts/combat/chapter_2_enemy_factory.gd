class_name Chapter2EnemyFactory
extends RefCounted
## Chapter 2 enemy body types and weapon shapes: 血铁·战歌

const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const EF = preload("res://scripts/combat/enemy_factory.gd")


static func build_body(parent: Node3D, body_type: String, mat: StandardMaterial3D) -> void:
	match body_type:
		"ragged_soldier":  _build_ragged_soldier(parent, mat)
		"hound_spectral":  _build_hound_spectral(parent, mat)
		"immobile_turret": _build_immobile_turret(parent, mat)
		"elite_armored":   _build_elite_armored(parent, mat)
		"tower_ranged":    _build_tower_ranged(parent, mat)
		_:
			pass


static func _build_ragged_soldier(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.cyl(parent, 0.13, 0.14, 1.72, Vector3(0, 0.78, 0), Vector3.ZERO, mat)
	EF.sph(parent, 0.15, 0.26, Vector3(0, 1.52, 0.05), mat)
	EF.box(parent, Vector3(0.28, 0.06, 0.18), Vector3(-0.18, 1.42, 0), Vector3(0, 0, -0.15), mat)
	EF.box(parent, Vector3(0.22, 0.55, 0.02), Vector3(0, 1.05, 0.16), Vector3(0.08, 0, 0), mat)


static func _build_hound_spectral(parent: Node3D, mat: StandardMaterial3D) -> void:
	var spect_mat := EF.mat_variant(mat, mat.albedo_color, 0.0, 0.9)
	spect_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spect_mat.albedo_color.a = 0.55
	EF.box(parent, Vector3(0.22, 0.28, 0.75), Vector3(0, 0.45, 0), Vector3.ZERO, spect_mat)
	EF.box(parent, Vector3(0.16, 0.18, 0.22), Vector3(0, 0.48, 0.48), Vector3.ZERO, spect_mat)
	for side in [-1.0, 1.0]:
		EF.box(parent, Vector3(0.06, 0.32, 0.06), Vector3(side * 0.1, 0.15, 0.2), Vector3.ZERO, spect_mat)
		EF.box(parent, Vector3(0.06, 0.32, 0.06), Vector3(side * 0.1, 0.15, -0.2), Vector3.ZERO, spect_mat)


static func _build_immobile_turret(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.box(parent, Vector3(0.65, 1.45, 0.05), Vector3(0, 0.72, 0), Vector3.ZERO, mat)
	EF.box(parent, Vector3(0.62, 1.40, 0.05), Vector3(0, 0.72, -0.06), Vector3.ZERO, mat)
	for i in range(5):
		var y := 0.2 + float(i) * 0.28
		EF.box(parent, Vector3(0.02, 0.02, 0.22), Vector3(0, y, 0.08), Vector3.ZERO, mat)


static func _build_elite_armored(parent: Node3D, mat: StandardMaterial3D) -> void:
	CharacterMeshFactory.build_enemy(parent, "cinder_guardian", mat)
	if parent.get_child_count() > 0:
		var root := parent.get_child(0) as Node3D
		if root != null:
			root.scale = Vector3(0.85, 0.85, 0.85)
	var plume_mat := EF.mat_variant(mat, Color(0.8, 0.15, 0.1), 0.0, 0.9)
	EF.box(parent, Vector3(0.04, 0.22, 0.12), Vector3(0, 1.65, -0.12), Vector3(-0.2, 0, 0), plume_mat)


static func _build_tower_ranged(parent: Node3D, mat: StandardMaterial3D) -> void:
	EF.cyl(parent, 0.14, 0.18, 2.2, Vector3(0, 1.1, 0), Vector3.ZERO, mat)
	EF.cyl(parent, 0.28, 0.22, 0.12, Vector3(0, 2.25, 0), Vector3.ZERO, mat)
	var flame_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.6, 0.1), Color(1.0, 0.3, 0.02), 4.5)
	EF.sph(parent, 0.15, 0.28, Vector3(0, 2.38, 0), flame_mat)


# Weapon shapes
static func build_weapon(parent: Node3D, weapon_id: String, mat: StandardMaterial3D) -> void:
	match weapon_id:
		"war_broken_sword":     _w_broken_sword(parent, mat)
		"spectral_fangs":       _w_spectral_fangs(parent, mat)
		"siege_glaive":         _w_siege_glaive(parent, mat)
		"iron_maiden_spikes":   _w_iron_maiden_spikes(parent, mat)
		"guandao":              _w_guandao(parent, mat)
		"beacon_flame":         _w_beacon_flame(parent, mat)
		_:
			pass


static func _w_broken_sword(p: Node3D, m: StandardMaterial3D) -> void:
	EF.box(p, Vector3(0.06, 0.72, 0.04), Vector3(0, 0.6, 0), Vector3(0, 0, -0.15), m)
	EF.box(p, Vector3(0.15, 0.05, 0.08), Vector3(0, 0.22, 0), Vector3.ZERO, m)


static func _w_spectral_fangs(p: Node3D, m: StandardMaterial3D) -> void:
	var spec_mat := EF.mat_variant(m, Color(0.8, 0.8, 0.95), 0.0, 0.9)
	spec_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spec_mat.albedo_color.a = 0.45
	for i in range(4):
		EF.box(p, Vector3(0.03, 0.04, 0.12), Vector3(cos(float(i) * 1.57) * 0.06, 0.08, sin(float(i) * 1.57) * 0.06), Vector3(0.2, 0, float(i) * 1.57), spec_mat)


static func _w_siege_glaive(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.04, 0.05, 1.55, Vector3(0, 0.35, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.04, 0.08, 0.38), Vector3(0, 1.2, 0), Vector3.ZERO, m)


static func _w_iron_maiden_spikes(p: Node3D, m: StandardMaterial3D) -> void:
	for i in range(6):
		var y := float(i) * 0.18
		EF.box(p, Vector3(0.02, 0.02, 0.28), Vector3(0, 0.25 + y, 0.1), Vector3.ZERO, m)


static func _w_guandao(p: Node3D, m: StandardMaterial3D) -> void:
	EF.cyl(p, 0.04, 0.05, 1.65, Vector3(0, 0.4, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.06, 0.05, 0.42), Vector3(0, 1.25, 0), Vector3.ZERO, m)
	EF.box(p, Vector3(0.02, 0.05, 0.35), Vector3(0.04, 1.25, 0), Vector3(0, 0, 0.1), m)


static func _w_beacon_flame(p: Node3D, m: StandardMaterial3D) -> void:
	var flame_mat := EF.mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.55, 0.1), Color(1.0, 0.25, 0.02), 5.0)
	EF.sph(p, 0.18, 0.38, Vector3(0, 0.1, 0), flame_mat)
	EF.sph(p, 0.12, 0.22, Vector3(0, 0.2, 0.02), flame_mat)
