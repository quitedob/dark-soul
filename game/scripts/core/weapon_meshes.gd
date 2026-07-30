class_name WeaponMeshFactory
extends RefCounted
## Procedural weapon mesh builder — creates recognizable weapon shapes from
## Godot primitive meshes (BoxMesh, CylinderMesh, SphereMesh, TorusMesh, PrismMesh).
## Each weapon type is a composite of 2-8 MeshInstance3D children attached to a
## parent Node3D, producing distinct silhouettes instead of a single colored box.

const ProceduralUtils = preload("res://scripts/core/procedural_utils.gd")


# -- public API ------------------------------------------------------------

static func build_into_parent(parent: Node3D, shape_id: String, material: StandardMaterial3D) -> void:
	_clear_children(parent)
	match shape_id:
		"sword":        _build_sword(parent, material)
		"axe_right":    _build_axe(parent, material, false)
		"axe_left":     _build_axe(parent, material, true)
		"bow":          _build_bow(parent, material)
		"dagger":       _build_dagger(parent, material)
		"staff_seal":   _build_staff_seal(parent, material)
		"prayer_beads": _build_prayer_beads(parent, material)
		"talisman_papers": _build_talisman_papers(parent, material)
		"spirit_stone": _build_spirit_stone(parent, material)
		_:              _build_default(parent, material)


static func build_shield(parent: Node3D, material: StandardMaterial3D) -> void:
	_clear_children(parent)
	_build_shield_geo(parent, material)


static func build_enemy_weapon(parent: Node3D, enemy_type: String, material: StandardMaterial3D) -> void:
	_clear_children(parent)
	match enemy_type:
		"cinder_guardian": _build_greatsword(parent, material)
		"ash_stalker":     _build_dagger(parent, material)
		_:                 _build_club(parent, material)


# -- internal helpers ------------------------------------------------------

static func _clear_children(parent: Node3D) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


static func _box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _cylinder(parent: Node3D, top_r: float, bot_r: float, height: float, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = height
	m.radial_segments = 16
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, radius: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 6
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 12
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# -- weapon builders -------------------------------------------------------

static func _build_sword(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Blade — long thin tapered box
	var blade_mat := _material_variant(mat, mat.albedo_color.lightened(0.08), mat.metallic + 0.1, mat.roughness * 0.6)
	_box(parent, Vector3(0.06, 1.35, 0.04),  Vector3(0, 1.05, -0.02),  Vector3.ZERO, blade_mat)
	# Crossguard
	var guard_mat := _material_variant(mat, mat.albedo_color.darkened(0.15), mat.metallic + 0.05, mat.roughness)
	_box(parent, Vector3(0.28, 0.07, 0.12),  Vector3(0, 0.32, 0.0),   Vector3.ZERO, guard_mat)
	# Grip
	var grip_mat := _material_variant(mat, mat.albedo_color.darkened(0.2), 0.0, 0.92)
	_cylinder(parent, 0.04, 0.04, 0.38,  Vector3(0, 0.08, 0.0),  Vector3(0, 0, 0), grip_mat)
	# Pommel
	_sphere(parent, 0.055, 0.11,  Vector3(0, -0.12, 0.0),  guard_mat)
	# Blade tip accent — small box at the tip
	_box(parent, Vector3(0.02, 0.08, 0.02),  Vector3(0, 1.76, -0.02),  Vector3.ZERO, blade_mat)


static func _build_axe(parent: Node3D, mat: StandardMaterial3D, mirrored: bool) -> void:
	var sign := -1.0 if mirrored else 1.0
	# Handle
	var handle_mat := _material_variant(mat, mat.albedo_color.darkened(0.25), 0.0, 0.9)
	_cylinder(parent, 0.045, 0.055, 1.45,  Vector3(0, 0.3, 0.0),  Vector3(0, 0, 0), handle_mat)
	# Axe head — back wedge
	_box(parent, Vector3(0.08, 0.14, 0.22),  Vector3(sign * 0.14, 1.08, 0.0),  Vector3(0, 0, 0), mat)
	# Axe head — forward blade (wider, thinner)
	var blade_mat := _material_variant(mat, mat.albedo_color.lightened(0.12), mat.metallic + 0.1, mat.roughness * 0.5)
	_box(parent, Vector3(0.05, 0.2, 0.38),  Vector3(sign * 0.08, 1.08, 0.12),  Vector3(0, 0, 0), blade_mat)
	# Top spike
	_box(parent, Vector3(0.04, 0.1, 0.04),  Vector3(sign * 0.12, 1.22, 0.0),  Vector3(0, 0, 0), mat)
	# Handle cap
	_cylinder(parent, 0.06, 0.05, 0.06,  Vector3(0, -0.44, 0.0),  Vector3(0, 0, 0), mat)


static func _build_bow(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Bow is trickier — we build an arc from multiple rotated cylinders
	var wood_mat := _material_variant(mat, mat.albedo_color, 0.0, 0.88)
	# Main bow limbs — angled cylinders forming the arc
	var segments := 8
	var arc_radius := 0.62
	var arc_span := deg_to_rad(130.0)
	var start_angle := -arc_span * 0.5 + PI * 0.5
	for i in range(segments):
		var t := float(i) / float(segments - 1)
		var angle := start_angle + arc_span * t
		var x := cos(angle) * arc_radius
		var y := sin(angle) * arc_radius
		var seg_height := (arc_radius * arc_span / float(segments)) * 1.35
		_cylinder(parent, 0.025, 0.025, seg_height,  Vector3(0, y, x),  Vector3(angle - PI * 0.5, 0, 0), wood_mat)
	# Bowstring — very thin cylinder
	var string_mat := _material_variant(mat, Color(0.72, 0.68, 0.62), 0.0, 0.95)
	var top_angle := start_angle
	var bot_angle := start_angle + arc_span
	var top_pos := Vector3(0, cos(top_angle) * arc_radius * 0.82, sin(top_angle) * arc_radius * 0.82)
	var bot_pos := Vector3(0, cos(bot_angle) * arc_radius * 0.82, sin(bot_angle) * arc_radius * 0.82)
	var string_center := (top_pos + bot_pos) * 0.5
	var string_len := top_pos.distance_to(bot_pos)
	_cylinder(parent, 0.008, 0.008, string_len,  string_center,  Vector3(PI * 0.5, 0, 0), string_mat)
	# Grip
	var grip_mat := _material_variant(mat, mat.albedo_color.darkened(0.2), 0.0, 0.92)
	_cylinder(parent, 0.035, 0.035, 0.28,  Vector3(0, 0.0, 0.0),  Vector3(0, 0, 0), grip_mat)


static func _build_dagger(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Blade
	var blade_mat := _material_variant(mat, mat.albedo_color.lightened(0.1), mat.metallic + 0.12, mat.roughness * 0.55)
	_box(parent, Vector3(0.04, 0.65, 0.025),  Vector3(0, 0.45, -0.01),  Vector3.ZERO, blade_mat)
	# Crossguard — small
	_box(parent, Vector3(0.14, 0.04, 0.06),  Vector3(0, 0.1, 0.0),  Vector3.ZERO, mat)
	# Grip
	var grip_mat := _material_variant(mat, mat.albedo_color.darkened(0.22), 0.0, 0.93)
	_cylinder(parent, 0.025, 0.025, 0.22,  Vector3(0, -0.03, 0.0),  Vector3(0, 0, 0), grip_mat)
	# Pommel
	_sphere(parent, 0.035, 0.07,  Vector3(0, -0.15, 0.0),  mat)


static func _build_staff_seal(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Staff rod
	var rod_mat := _material_variant(mat, mat.albedo_color.darkened(0.15), 0.0, 0.85)
	_cylinder(parent, 0.04, 0.05, 1.5,  Vector3(0, 0.3, 0.0),  Vector3(0, 0, 0), rod_mat)
	# Seal head — flattened box with emblem
	_box(parent, Vector3(0.14, 0.18, 0.05),  Vector3(0, 1.1, 0.0),  Vector3(0, 0, 0), mat)
	# Emblem on seal — small bright accent box
	var accent_mat := _material_variant(mat, mat.albedo_color.lightened(0.25), mat.metallic + 0.08, mat.roughness * 0.4)
	accent_mat.emission_enabled = true
	accent_mat.emission = mat.albedo_color.lightened(0.4)
	accent_mat.emission_energy_multiplier = 0.8
	_box(parent, Vector3(0.08, 0.1, 0.02),  Vector3(0, 1.1, 0.035),  Vector3.ZERO, accent_mat)
	# Staff tip (bottom)
	_cylinder(parent, 0.03, 0.04, 0.08,  Vector3(0, -0.46, 0.0),  Vector3(0, 0, 0), mat)
	# Staff tip (top)
	_sphere(parent, 0.04, 0.08,  Vector3(0, 1.22, 0.0),  mat)


static func _build_prayer_beads(parent: Node3D, mat: StandardMaterial3D) -> void:
	# String of beads — multiple spheres arranged vertically
	var bead_count := 7
	var bead_spacing := 0.14
	var start_y := 0.82
	var bead_radius := 0.06
	for i in range(bead_count):
		var t := float(i) / float(bead_count - 1)
		var y := start_y - t * bead_spacing * float(bead_count - 1)
		var color_variant := mat.albedo_color.lerp(Color.ORANGE, t * 0.4)
		var bead_mat := _material_variant(mat, color_variant, mat.metallic, mat.roughness)
		_sphere(parent, bead_radius, bead_radius * 2.0,  Vector3(sin(t * 4.0) * 0.025, y, 0.0),  bead_mat)
	# Cross/cruciform pendant at bottom
	var pendant_mat := _material_variant(mat, mat.albedo_color.lightened(0.15), mat.metallic + 0.1, mat.roughness * 0.5)
	_box(parent, Vector3(0.03, 0.16, 0.03),  Vector3(0, start_y - bead_spacing * float(bead_count) - 0.12, 0.0),  Vector3.ZERO, pendant_mat)
	_box(parent, Vector3(0.1, 0.03, 0.03),  Vector3(0, start_y - bead_spacing * float(bead_count) - 0.08, 0.0),  Vector3.ZERO, pendant_mat)
	# String/cord — very thin cylinder
	var cord_mat := _material_variant(mat, Color(0.55, 0.45, 0.35), 0.0, 0.95)
	_cylinder(parent, 0.012, 0.012, start_y - (start_y - bead_spacing * float(bead_count) - 0.18) + 0.05,  Vector3(0, 0.2, 0.0),  Vector3(0, 0, 0), cord_mat)


static func _build_talisman_papers(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Rectangular paper strips hanging/waving
	var paper_mat := _material_variant(mat, mat.albedo_color, 0.0, 0.96)
	var strips := 4
	for i in range(strips):
		var x := (float(i) - float(strips - 1) * 0.5) * 0.08
		var z := sin(float(i) * 1.2) * 0.03
		_box(parent, Vector3(0.06, 0.55, 0.01),  Vector3(x, -0.12, z),  Vector3(sin(float(i)) * 0.08, 0, 0), paper_mat)
	# Binding at top
	var bind_mat := _material_variant(mat, mat.albedo_color.darkened(0.2), 0.15, 0.8)
	_box(parent, Vector3(0.18, 0.04, 0.04),  Vector3(0, 0.18, 0.0),  Vector3.ZERO, bind_mat)


static func _build_spirit_stone(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Floating crystal — uses PrismMesh for faceted look
	var crystal_mat := _material_variant(mat, mat.albedo_color, 0.15, 0.25)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = mat.albedo_color.lightened(0.3)
	crystal_mat.emission_energy_multiplier = 1.8
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.albedo_color.a = 0.78
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.14, 0.35, 0.14)
	prism.mesh = pm
	prism.position = Vector3(0, 0.05, 0.0)
	prism.material_override = crystal_mat
	parent.add_child(prism)
	# Inner glow sphere
	var glow_mat := _material_variant(mat, Color.WHITE, 0.0, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = mat.albedo_color
	glow_mat.emission_energy_multiplier = 3.5
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color.a = 0.35
	_sphere(parent, 0.1, 0.2,  Vector3(0, 0.05, 0.0),  glow_mat)
	# Orbit ring
	var ring_mat := _material_variant(mat, mat.albedo_color.lightened(0.2), mat.metallic + 0.2, mat.roughness * 0.3)
	_torus(parent, 0.16, 0.18,  Vector3(0, 0.05, 0.0),  Vector3(PI * 0.5, 0, 0), ring_mat)


static func _build_shield_geo(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Main shield body — thicker disc
	var body_mat := _material_variant(mat, mat.albedo_color, mat.metallic, mat.roughness)
	_cylinder(parent, 0.48, 0.48, 0.10,  Vector3.ZERO,  Vector3(PI * 0.5, 0, 0), body_mat)
	# Rim ring
	var rim_mat := _material_variant(mat, mat.albedo_color.lightened(0.1), mat.metallic + 0.1, mat.roughness * 0.7)
	_torus(parent, 0.44, 0.50,  Vector3.ZERO,  Vector3(PI * 0.5, 0, 0), rim_mat)
	# Center boss — small raised sphere
	var boss_mat := _material_variant(mat, mat.albedo_color.lightened(0.18), mat.metallic + 0.15, mat.roughness * 0.5)
	_sphere(parent, 0.09, 0.12,  Vector3(0, 0.0, 0.08),  boss_mat)
	# Cross emblem on shield face
	var emblem_mat := _material_variant(mat, mat.albedo_color.lightened(0.3), mat.metallic + 0.1, mat.roughness * 0.35)
	_box(parent, Vector3(0.05, 0.28, 0.015),  Vector3(0, 0.0, 0.07),  Vector3.ZERO, emblem_mat)
	_box(parent, Vector3(0.18, 0.05, 0.015),  Vector3(0, 0.0, 0.07),  Vector3.ZERO, emblem_mat)
	# Edge rivets — small spheres around rim
	var rivet_mat := _material_variant(mat, mat.albedo_color.lightened(0.3), mat.metallic + 0.2, mat.roughness * 0.3)
	var rivet_count := 6
	for i in range(rivet_count):
		var angle := float(i) / float(rivet_count) * TAU
		_sphere(parent, 0.025, 0.04,  Vector3(cos(angle) * 0.46, sin(angle) * 0.46, 0.05),  rivet_mat)


static func _build_greatsword(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Large imposing blade for boss/guardian
	var blade_mat := _material_variant(mat, mat.albedo_color, mat.metallic + 0.1, mat.roughness * 0.55)
	_box(parent, Vector3(0.12, 1.9, 0.06),  Vector3(0, 1.15, -0.02),  Vector3.ZERO, blade_mat)
	# Fuller groove accent
	var accent_mat := _material_variant(mat, mat.albedo_color.darkened(0.1), mat.metallic, mat.roughness)
	_box(parent, Vector3(0.03, 1.5, 0.01),  Vector3(0, 1.1, 0.02),  Vector3.ZERO, accent_mat)
	# Crossguard
	_box(parent, Vector3(0.36, 0.1, 0.16),  Vector3(0, 0.15, 0.0),  Vector3.ZERO, mat)
	# Grip
	var grip_mat := _material_variant(mat, mat.albedo_color.darkened(0.25), 0.0, 0.9)
	_cylinder(parent, 0.06, 0.06, 0.5,  Vector3(0, -0.18, 0.0),  Vector3(0, 0, 0), grip_mat)
	# Pommel
	_sphere(parent, 0.07, 0.14,  Vector3(0, -0.45, 0.0),  mat)


static func _build_club(parent: Node3D, mat: StandardMaterial3D) -> void:
	# Crude club for basic enemies
	var handle_mat := _material_variant(mat, mat.albedo_color.darkened(0.2), 0.0, 0.92)
	_cylinder(parent, 0.04, 0.055, 1.1,  Vector3(0, 0.15, 0.0),  Vector3(0, 0, 0), handle_mat)
	# Club head — thick cylinder
	_cylinder(parent, 0.08, 0.1, 0.45,  Vector3(0, 0.82, 0.0),  Vector3(0, 0, 0), mat)
	# Spikes on club head
	var spike_mat := _material_variant(mat, mat.albedo_color.lightened(0.08), mat.metallic + 0.1, mat.roughness * 0.5)
	for i in range(4):
		var angle := float(i) / 4.0 * TAU
		_box(parent, Vector3(0.02, 0.06, 0.02),  Vector3(cos(angle) * 0.09, 0.82, sin(angle) * 0.09),  Vector3.ZERO, spike_mat)


static func _build_default(parent: Node3D, mat: StandardMaterial3D) -> void:
	_box(parent, Vector3(0.12, 1.55, 0.18),  Vector3(0, -0.35, 0.0),  Vector3.ZERO, mat)


# -- material utility ------------------------------------------------------

static func _material_variant(base: StandardMaterial3D, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m
