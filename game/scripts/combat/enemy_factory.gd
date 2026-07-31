class_name ChapterEnemyFactory
extends RefCounted
## Dispatcher for chapter-exclusive enemy models.
## Delegates body and weapon construction to per-chapter factory classes.
## Per-chapter files: chapter_1_enemy_factory.gd through chapter_5_enemy_factory.gd

const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")

# ── Main dispatch ────────────────────────────────────────────────────────

static func build_enemy_model(parent: Node3D, enemy_data: Dictionary, body_material: StandardMaterial3D, weapon_material: StandardMaterial3D) -> void:
	_clear_children(parent)
	var body_type: String = enemy_data.get("body_type", "humanoid")
	var weapon_shape: String = enemy_data.get("weapon_shape", "club")
	_build_body_for_type(parent, body_type, body_material)
	_build_chapter_weapon(parent, weapon_shape, weapon_material)


## 写入敌人已有的身体/武器槽位（避免再建一层 EnemyWeaponPivot）
static func build_into_slots(
	body_parent: Node3D,
	weapon_parent: Node3D,
	enemy_data: Dictionary,
	body_material: StandardMaterial3D,
	weapon_material: StandardMaterial3D
) -> void:
	_clear_children(body_parent)
	_clear_children(weapon_parent)
	var body_type: String = enemy_data.get("body_type", "humanoid")
	var weapon_shape: String = enemy_data.get("weapon_shape", "club")
	_build_body_for_type(body_parent, body_type, body_material)
	_dispatch_weapon(weapon_parent, weapon_shape, weapon_material)


static func _build_body_for_type(parent: Node3D, body_type: String, body_material: StandardMaterial3D) -> void:
	match body_type:
		"wraith_thin", "armored_medium", "ethereal_flicker", "hulking_molten":
			Chapter1EnemyFactory.build_body(parent, body_type, body_material)
		"ragged_soldier", "hound_spectral", "immobile_turret", "elite_armored", "tower_ranged":
			Chapter2EnemyFactory.build_body(parent, body_type, body_material)
		"floating_small", "ethereal_thin", "floating_orb", "lantern_float", "floating_dress", "reflection_clone", "flower_stationary", "beast_humanoid":
			Chapter3EnemyFactory.build_body(parent, body_type, body_material)
		"celestial_guard", "flying_large", "barrel_heavy", "robed_caster", "floating_book", "shambling_giant":
			Chapter4EnemyFactory.build_body(parent, body_type, body_material)
		"void_wraith", "gravity_armor", "flying_small", "shadow_form", "quantum_shimmer", "ancient_giant":
			Chapter5EnemyFactory.build_body(parent, body_type, body_material)
		"armored_heavy", "massive_golem", "ethereal_elite", "floating_dress_elite", "reflection_knight", "floating_knight", "gravity_mage", "void_knight", "ancient_titan":
			_build_elite_body(parent, body_type, body_material)
		"hanging_bell":
			# 盲钟·听烬：5m 悬垂青铜编钟（吊耳 + 锥形钟身 + 钟口光环 + 双侧钟舌）
			_build_hanging_bell(parent, body_material)
		_:
			_build_default_humanoid(parent, body_material)


# ── Weapon dispatch ──────────────────────────────────────────────────────

static func _build_chapter_weapon(parent: Node3D, weapon_id: String, weapon_material: StandardMaterial3D) -> void:
	var weapon_pivot := Node3D.new()
	weapon_pivot.name = "EnemyWeaponPivot"
	weapon_pivot.position = Vector3(0.68, 0.45, -0.16)
	parent.add_child(weapon_pivot)
	_dispatch_weapon(weapon_pivot, weapon_id, weapon_material)


static func _dispatch_weapon(weapon_pivot: Node3D, weapon_id: String, weapon_material: StandardMaterial3D) -> void:
	match weapon_id:
		"rusted_blade", "temple_halberd", "glass_shard", "slag_fist":
			Chapter1EnemyFactory.build_weapon(weapon_pivot, weapon_id, weapon_material)
		"war_broken_sword", "spectral_fangs", "siege_glaive", "iron_maiden_spikes", "guandao", "beacon_flame":
			Chapter2EnemyFactory.build_weapon(weapon_pivot, weapon_id, weapon_material)
		"wing_blade", "memory_claw", "sound_wave", "fox_fire_orb", "sleeve_blade", "water_orb", "petal_blade", "jade_halberd", "fox_claw":
			Chapter3EnemyFactory.build_weapon(weapon_pivot, weapon_id, weapon_material)
		"cloud_glaive", "talon", "furnace_body", "alchemy_sword", "floating_pages", "scripture_blade", "broken_limb":
			Chapter4EnemyFactory.build_weapon(weapon_pivot, weapon_id, weapon_material)
		"drift_blade", "inverted_halberd", "ember_wing", "shadow_blade", "possibility_orb", "soul_hammer":
			Chapter5EnemyFactory.build_weapon(weapon_pivot, weapon_id, weapon_material)
		"bronze_mirror_shield":
			WeaponMeshFactory.build_shield(weapon_pivot, weapon_material)
		"beacon_bow":
			WeaponMeshFactory.build_into_parent(weapon_pivot, "bow", weapon_material)
		"bell_tongue":
			# 盲钟·听烬：短挂杆 + 钟舌铁球（cast-iron，攻击前摇随 WeaponPivot 摆荡）
			cyl(weapon_pivot, 0.05, 0.05, 0.75, Vector3(0, 0.05, 0), Vector3.ZERO, weapon_material)
			sph(weapon_pivot, 0.24, 0.42, Vector3(0, -0.42, 0), weapon_material)
		"stone_fist", "commander_sword", "chain_hook", "memory_scythe", "bridal_veil", "mirror_blade", "celestial_sword", "elixir_vial", "scripture_tome", "void_blade", "gravity_staff", "soul_forge_hammer":
			_build_elite_weapon(weapon_pivot, weapon_id, weapon_material)
		_:
			box(weapon_pivot, Vector3(0.08, 1.2, 0.12), Vector3(0, -0.3, 0), Vector3.ZERO, weapon_material)


# ═══════════════════════════════════════════════════════════════════════════
# Elite body types (cross-chapter — may delegate to chapter builders)
# ═══════════════════════════════════════════════════════════════════════════

static func _build_elite_body(parent: Node3D, body_type: String, mat: StandardMaterial3D) -> void:
	match body_type:
		"armored_heavy":
			CharacterMeshFactory.build_enemy(parent, "cinder_guardian", mat)
		"massive_golem":
			sph(parent, 0.55, 1.05, Vector3(0, 1.25, 0), mat)
			cyl(parent, 0.28, 0.32, 1.1, Vector3(-0.3, 0.55, 0), Vector3.ZERO, mat)
			cyl(parent, 0.28, 0.32, 1.1, Vector3(0.3, 0.55, 0), Vector3.ZERO, mat)
		"ethereal_elite":
			Chapter3EnemyFactory.build_body(parent, "ethereal_thin", mat)
			if parent.get_child_count() > 0:
				var root := parent.get_child(0) as Node3D
				if root != null:
					root.scale = Vector3(1.25, 1.25, 1.25)
		"floating_dress_elite":
			Chapter3EnemyFactory.build_body(parent, "floating_dress", mat)
			if parent.get_child_count() > 0:
				var root := parent.get_child(0) as Node3D
				if root != null:
					root.scale = Vector3(1.2, 1.2, 1.2)
		"reflection_knight":
			var refl_mat := mat_variant(mat, mat.albedo_color, mat.metallic + 0.2, 0.05)
			refl_mat.emission_enabled = true
			refl_mat.emission = Color(0.5, 0.7, 0.9)
			refl_mat.emission_energy_multiplier = 2.0
			cyl(parent, 0.15, 0.16, 1.85, Vector3(0, 0.85, 0), Vector3.ZERO, refl_mat)
			sph(parent, 0.16, 0.28, Vector3(0, 1.65, 0.05), refl_mat)
		"floating_knight":
			Chapter4EnemyFactory.build_body(parent, "celestial_guard", mat)
			if parent.get_child_count() > 0:
				var root := parent.get_child(0) as Node3D
				if root != null:
					root.scale = Vector3(1.15, 1.15, 1.15)
		"gravity_mage":
			Chapter4EnemyFactory.build_body(parent, "robed_caster", mat)
			var orb_mat := mat_emissive(StandardMaterial3D.new(), Color(0.4, 0.3, 0.8), Color(0.3, 0.2, 0.6), 3.0)
			for i in range(3):
				sph(parent, 0.06, 0.12, Vector3(cos(float(i) * 2.1) * 0.25, 1.0 + float(i) * 0.15, sin(float(i) * 2.1) * 0.25), orb_mat)
		"void_knight":
			Chapter5EnemyFactory.build_body(parent, "void_wraith", mat)
			if parent.get_child_count() > 0:
				var root := parent.get_child(0) as Node3D
				if root != null:
					root.scale = Vector3(1.3, 1.3, 1.3)
		"ancient_titan":
			Chapter5EnemyFactory.build_body(parent, "ancient_giant", mat)
			if parent.get_child_count() > 0:
				var root := parent.get_child(0) as Node3D
				if root != null:
					root.scale = Vector3(1.3, 1.3, 1.3)


# ═══════════════════════════════════════════════════════════════════════════
# Elite weapon shapes
# ═══════════════════════════════════════════════════════════════════════════

static func _build_elite_weapon(p: Node3D, weapon_id: String, m: StandardMaterial3D) -> void:
	match weapon_id:
		"stone_fist":
			for i in range(3):
				sph(p, 0.12 + float(i) * 0.02, 0.2 + float(i) * 0.04, Vector3(float(i - 1) * 0.06, float(i) * 0.02, 0), m)
		"commander_sword":
			WeaponMeshFactory.build_into_parent(p, "sword", m)
		"chain_hook":
			cyl(p, 0.02, 0.02, 0.55, Vector3(0, 0.25, 0), Vector3(PI * 0.5, 0, 0), m)
			box(p, Vector3(0.03, 0.04, 0.12), Vector3(0, 0.0, 0.35), Vector3.ZERO, m)
		"memory_scythe":
			cyl(p, 0.04, 0.05, 1.5, Vector3(0, 0.3, 0), Vector3.ZERO, m)
			box(p, Vector3(0.03, 0.06, 0.35), Vector3(0, 1.15, 0), Vector3(0, 0, 0.2), m)
		"bridal_veil":
			var bv := mat_variant(m, m.albedo_color, 0.0, 0.95)
			bv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bv.albedo_color.a = 0.4
			box(p, Vector3(0.45, 0.01, 0.35), Vector3(0, 0.15, -0.05), Vector3(-0.15, 0, 0), bv)
		"mirror_blade":
			var mb := mat_variant(m, m.albedo_color, 0.0, 0.02)
			mb.emission_enabled = true
			mb.emission = Color(0.7, 0.85, 1.0)
			mb.emission_energy_multiplier = 1.5
			box(p, Vector3(0.06, 1.3, 0.02), Vector3(0, 0.98, 0), Vector3.ZERO, mb)
		"celestial_sword":
			var cs := mat_emissive(StandardMaterial3D.new(), m.albedo_color, Color(0.85, 0.85, 1.0), 2.0)
			box(p, Vector3(0.07, 1.45, 0.04), Vector3(0, 1.1, -0.02), Vector3.ZERO, cs)
			box(p, Vector3(0.22, 0.06, 0.1), Vector3(0, 0.32, 0), Vector3.ZERO, m)
		"elixir_vial":
			var ev := mat_emissive(StandardMaterial3D.new(), Color(0.3, 0.9, 0.3), Color(0.1, 0.7, 0.1), 3.0)
			cyl(p, 0.08, 0.06, 0.25, Vector3(0, 0.12, 0), Vector3.ZERO, ev)
			cyl(p, 0.06, 0.08, 0.06, Vector3(0, 0.22, 0), Vector3.ZERO, m)
		"scripture_tome":
			box(p, Vector3(0.22, 0.05, 0.3), Vector3(0, 0, 0), Vector3.ZERO, m)
			var gl := mat_emissive(StandardMaterial3D.new(), Color(0.9, 0.8, 0.4), Color(0.8, 0.7, 0.3), 2.5)
			for i in range(3):
				box(p, Vector3(0.02, 0.005, 0.15), Vector3(0, 0.04 + float(i) * 0.015, 0.02), Vector3.ZERO, gl)
		"void_blade":
			Chapter5EnemyFactory.build_weapon(p, "drift_blade", m)
		"gravity_staff":
			cyl(p, 0.05, 0.06, 1.6, Vector3(0, 0.8, 0), Vector3.ZERO, m)
			var gs := mat_emissive(StandardMaterial3D.new(), Color(0.4, 0.2, 0.8), Color(0.3, 0.1, 0.6), 3.5)
			sph(p, 0.12, 0.22, Vector3(0, 1.65, 0), gs)
		"soul_forge_hammer":
			cyl(p, 0.06, 0.08, 1.4, Vector3(0, 0.3, 0), Vector3.ZERO, m)
			var sf := mat_emissive(StandardMaterial3D.new(), Color(1.0, 0.8, 0.3), Color(1.0, 0.6, 0.1), 5.0)
			box(p, Vector3(0.22, 0.28, 0.22), Vector3(0, 1.05, 0), Vector3.ZERO, sf)


# ═══════════════════════════════════════════════════════════════════════════
# Optional boss body: hanging bronze bell (盲钟·听烬)
# ═══════════════════════════════════════════════════════════════════════════

static func _build_hanging_bell(parent: Node3D, mat: StandardMaterial3D) -> void:
	# 青铜钟身（7a6a4a，金属 ~0.85）：顶部吊耳 + 锥形钟身 + 钟口光环 + 双侧钟舌
	var bronze := mat_variant(mat, Color("7a6a4a"), 0.85, 0.32)
	# 顶部吊耳（挂链）
	cyl(parent, 0.12, 0.14, 0.5, Vector3(0, 3.15, 0), Vector3.ZERO, mat)
	# 锥形钟身：钟口朝下，底部最宽（编钟形）
	cyl(parent, 0.42, 0.95, 2.4, Vector3(0, 1.75, 0), Vector3.ZERO, bronze)
	# 钟口音孔光环（烬色 emissive，弱点在钟口）
	var mouth_mat := mat_emissive(StandardMaterial3D.new(), Color("7a6a4a"), Color("ffcc44"), 3.0)
	cyl(parent, 0.9, 0.98, 0.28, Vector3(0, 0.45, 0), Vector3.ZERO, mouth_mat)
	# 双侧悬垂钟舌：细杆 + 铁球（既是"手臂"也是武器）
	for side in [-1.0, 1.0]:
		cyl(parent, 0.045, 0.045, 0.9, Vector3(side * 0.55, 1.6, 0), Vector3(0.0, 0.0, side * PI * 0.5), mat)
		sph(parent, 0.16, 0.3, Vector3(side * 1.0, 1.15, 0), bronze)


# ═══════════════════════════════════════════════════════════════════════════
# Shared helpers (public — called by per-chapter factories)
# ═══════════════════════════════════════════════════════════════════════════

static func _clear_children(parent: Node3D) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, top_r: float, bot_r: float, height: float, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = height
	m.radial_segments = 12
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func sph(parent: Node3D, radius: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 6
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func mat_variant(base: StandardMaterial3D, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

static func mat_emissive(base: StandardMaterial3D, color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.roughness = 0.15
	m.metallic = 0.0
	return m

static func _build_default_humanoid(parent: Node3D, mat: StandardMaterial3D) -> void:
	cyl(parent, 0.12, 0.13, 1.72, Vector3(0, 0.78, 0), Vector3.ZERO, mat)
	sph(parent, 0.15, 0.26, Vector3(0, 1.52, 0.05), mat)
