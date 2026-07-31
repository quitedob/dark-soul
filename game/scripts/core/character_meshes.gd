class_name CharacterMeshFactory
extends RefCounted
## Procedural character model builder — creates detailed humanoid figures from
## Godot primitive meshes (BoxMesh, CylinderMesh, SphereMesh, PrismMesh, TorusMesh).
## Each character type gets distinct body proportions, armor pieces, and silhouettes.
## All parts are MeshInstance3D children of a parent Node3D.


# -- public API ------------------------------------------------------------

static func build_player(parent: Node3D, body_mat: StandardMaterial3D, visor_mat: StandardMaterial3D) -> void:
	_clear_children(parent)
	# Core body
	_build_humanoid(parent, body_mat, {
		"height": 1.82, "shoulder_width": 0.44, "chest_depth": 0.28,
		"limb_thickness": 0.10, "body_color": body_mat.albedo_color,
	})
	# Armor — knight-style chestplate and pauldrons
	var armor_mat := _mat_variant(body_mat, Color("3a4048"), 0.65, 0.28)
	_build_chest_armor(parent, armor_mat, 0.03)
	# Pauldrons
	_box(parent, Vector3(0.16, 0.08, 0.20), Vector3(0.48, 1.32, 0.0), Vector3(0, 0, 0.08), armor_mat)
	_box(parent, Vector3(0.16, 0.08, 0.20), Vector3(-0.48, 1.32, 0.0), Vector3(0, 0, -0.08), armor_mat)
	# Belt
	var belt_mat := _mat_variant(body_mat, Color("4a3828"), 0.35, 0.72)
	_cylinder(parent, 0.25, 0.25, 0.06, Vector3(0, 0.88, 0.0), Vector3(0, 0, 0), belt_mat)
	# Greaves (shin armor)
	var greave_mat := _mat_variant(body_mat, Color("3a4048"), 0.62, 0.30)
	_cylinder(parent, 0.12, 0.12, 0.28, Vector3(0.16, 0.28, 0.0), Vector3(0, 0, 0), greave_mat)
	_cylinder(parent, 0.12, 0.12, 0.28, Vector3(-0.16, 0.28, 0.0), Vector3(0, 0, 0), greave_mat)
	# Cloak — draped prism behind the character
	var cloak_mat := _mat_variant(body_mat, body_mat.albedo_color.darkened(0.45), 0.95, 0.02)
	_prism(parent, Vector3(0.82, 1.3, 0.38), Vector3(0, 0.95, 0.28), Vector3(0, 0, 0), cloak_mat)
	# Helmet / Visor
	_build_helmet(parent, body_mat, visor_mat)


static func build_enemy(parent: Node3D, enemy_type: String, body_mat: StandardMaterial3D) -> void:
	_clear_children(parent)
	match enemy_type:
		"cinder_guardian": _build_guardian(parent, body_mat)
		"ash_stalker":     _build_stalker(parent, body_mat)
		"ember_skirmisher": _build_skirmisher(parent, body_mat)
		_:                 _build_sentinel(parent, body_mat)


# -- humanoid skeleton ----------------------------------------------------

static func _build_humanoid(parent: Node3D, mat: StandardMaterial3D, cfg: Dictionary) -> void:
	var h := float(cfg.get("height", 1.8))
	var sw := float(cfg.get("shoulder_width", 0.42))
	var cd := float(cfg.get("chest_depth", 0.26))
	var lt := float(cfg.get("limb_thickness", 0.09))
	var base := mat.albedo_color
	var skin_mat := _mat_variant(mat, base, mat.metallic, mat.roughness)
	# Torso — wider box
	_box(parent, Vector3(sw * 2.0, h * 0.22, cd), Vector3(0, h * 0.68, 0), Vector3.ZERO, skin_mat)
	# Pelvis
	_box(parent, Vector3(sw * 1.2, h * 0.10, cd * 0.9), Vector3(0, h * 0.50, 0), Vector3.ZERO, skin_mat)
	# Neck
	_cylinder(parent, lt * 0.55, lt * 0.55, h * 0.07, Vector3(0, h * 0.82, 0), Vector3.ZERO, skin_mat)
	# Head
	_sphere(parent, h * 0.14, h * 0.28, Vector3(0, h * 0.91, 0.03), skin_mat)
	# Eyes
	var eye_mat := _mat_emissive(mat, Color.RED, 2.5)
	for ex: float in [-1.0, 1.0]:
		_sphere(parent, 0.03, 0.06, Vector3(ex * sw * 0.13, h * 0.93, -cd * 0.45), eye_mat)
	# Shoulders
	_sphere(parent, lt * 0.7, lt * 1.3, Vector3(sw * 1.12, h * 0.78, 0), skin_mat)
	_sphere(parent, lt * 0.7, lt * 1.3, Vector3(-sw * 1.12, h * 0.78, 0), skin_mat)
	# Upper arms
	for sign: float in [-1.0, 1.0]:
		var x := sw * 1.12 * sign
		_cylinder(parent, lt * 0.55, lt * 0.55, h * 0.18, Vector3(x, h * 0.73, sign * 0.02), Vector3(sign * -0.15, 0, 0), skin_mat)
		# Lower arms
		_cylinder(parent, lt * 0.45, lt * 0.45, h * 0.16, Vector3(x, h * 0.58, sign * 0.04), Vector3(sign * -0.12, 0, 0), skin_mat)
		# Hands
		_sphere(parent, lt * 0.42, lt * 0.7, Vector3(x, h * 0.48, sign * 0.05), skin_mat)
	# Upper legs
	for sign: float in [-1.0, 1.0]:
		var x := sw * 0.55 * sign
		_cylinder(parent, lt * 0.7, lt * 0.75, h * 0.22, Vector3(x, h * 0.42, 0.02), Vector3(-0.05, 0, 0), skin_mat)
		# Lower legs
		_cylinder(parent, lt * 0.6, lt * 0.65, h * 0.20, Vector3(x, h * 0.22, sign * 0.01), Vector3(0, 0, 0), skin_mat)
		# Feet
		_box(parent, Vector3(lt * 0.9, h * 0.04, h * 0.1), Vector3(x, h * 0.08, h * 0.04), Vector3.ZERO, _mat_variant(mat, base.darkened(0.3), 0.78, 0.08))


static func _build_chest_armor(parent: Node3D, mat: StandardMaterial3D, inset: float) -> void:
	# Breastplate front
	_box(parent, Vector3(0.78, 0.28, 0.06), Vector3(0, 1.04, -inset - 0.14), Vector3(0, 0, 0), mat)
	# Breastplate back
	_box(parent, Vector3(0.76, 0.26, 0.05), Vector3(0, 1.04, inset + 0.14), Vector3(0, 0, 0), mat)
	# Side straps
	for sign: float in [-1.0, 1.0]:
		_box(parent, Vector3(0.04, 0.22, 0.28), Vector3(sign * 0.42, 1.04, 0), Vector3(0, 0, 0), mat)


static func _build_helmet(parent: Node3D, body_mat: StandardMaterial3D, visor_mat: StandardMaterial3D) -> void:
	# Helmet dome
	var helm_mat := _mat_variant(body_mat, Color("3a4048"), 0.65, 0.28)
	_cylinder(parent, 0.22, 0.26, 0.18, Vector3(0, 1.68, 0), Vector3(0, 0, 0), helm_mat)
	_sphere(parent, 0.21, 0.28, Vector3(0, 1.74, 0), helm_mat)
	# Visor slit — emissive orange
	_box(parent, Vector3(0.38, 0.06, 0.04), Vector3(0, 1.66, -0.24), Vector3(0, 0, 0), visor_mat)


# -- enemy variants -------------------------------------------------------

static func _build_sentinel(parent: Node3D, mat: StandardMaterial3D) -> void:
	var dark := mat.albedo_color.darkened(0.08)
	var sentinel_mat := _mat_variant(mat, dark, mat.metallic, mat.roughness)
	_build_humanoid(parent, sentinel_mat, {
		"height": 1.82, "shoulder_width": 0.42, "chest_depth": 0.26,
		"limb_thickness": 0.10,
	})
	# Tattered shoulder guard
	var scrap_mat := _mat_variant(mat, dark.darkened(0.12), 0.55, 0.42)
	_box(parent, Vector3(0.18, 0.06, 0.18), Vector3(0.44, 1.32, 0.06), Vector3(0.08, 0.0, 0.15), scrap_mat)
	_box(parent, Vector3(0.14, 0.06, 0.16), Vector3(-0.42, 1.28, -0.04), Vector3(-0.05, 0.0, -0.12), scrap_mat)
	# Ragged hood/cowl
	var hood_mat := _mat_variant(mat, dark.darkened(0.18), 0.95, 0.02)
	_cylinder(parent, 0.23, 0.28, 0.22, Vector3(0, 1.72, 0.04), Vector3(0, 0, 0), hood_mat)


static func _build_stalker(parent: Node3D, mat: StandardMaterial3D) -> void:
	var stalker_mat := _mat_variant(mat, mat.albedo_color, mat.metallic, mat.roughness)
	# Taller, leaner build
	_build_humanoid(parent, stalker_mat, {
		"height": 1.92, "shoulder_width": 0.36, "chest_depth": 0.22,
		"limb_thickness": 0.08,
	})
	# Deep hood
	var hood_mat := _mat_variant(mat, mat.albedo_color.darkened(0.25), 0.96, 0.01)
	_cylinder(parent, 0.24, 0.30, 0.28, Vector3(0, 1.75, 0.06), Vector3(0.05, 0, 0), hood_mat)
	# Face wrappings
	var wrap_mat := _mat_variant(mat, Color(0.28, 0.24, 0.20), 0.9, 0.05)
	_box(parent, Vector3(0.22, 0.05, 0.12), Vector3(0, 1.64, -0.10), Vector3(0, 0, 0), wrap_mat)
	# Light leather armor
	var leather_mat := _mat_variant(mat, Color(0.22, 0.18, 0.14), 0.68, 0.20)
	_box(parent, Vector3(0.66, 0.18, 0.05), Vector3(0, 1.0, -0.14), Vector3(0, 0, 0), leather_mat)


## G-03：远程伏击者——瘦高菱影斗篷轮廓
static func _build_skirmisher(parent: Node3D, mat: StandardMaterial3D) -> void:
	var body_mat := _mat_variant(mat, mat.albedo_color, mat.metallic, mat.roughness)
	_build_humanoid(parent, body_mat, {
		"height": 1.78, "shoulder_width": 0.34, "chest_depth": 0.20,
		"limb_thickness": 0.075,
	})
	# 尖顶兜帽
	var hood := _mat_variant(mat, mat.albedo_color.darkened(0.2), 0.92, 0.04)
	_cylinder(parent, 0.08, 0.26, 0.32, Vector3(0, 1.78, 0.02), Vector3.ZERO, hood)
	# 斗篷后摆（远程剪影）
	var cloak := _mat_variant(mat, mat.albedo_color.darkened(0.35), 0.95, 0.02)
	_prism(parent, Vector3(0.7, 1.1, 0.32), Vector3(0, 0.9, 0.26), Vector3.ZERO, cloak)
	# 肩甲菱片
	var gem := _mat_emissive(mat, Color(0.9, 0.25, 0.55), 2.2)
	_sphere(parent, 0.06, 0.1, Vector3(0.28, 1.35, -0.08), gem)
	_sphere(parent, 0.06, 0.1, Vector3(-0.28, 1.35, -0.08), gem)


static func _build_guardian(parent: Node3D, mat: StandardMaterial3D) -> void:
	var guardian_mat := _mat_variant(mat, mat.albedo_color, mat.metallic, mat.roughness)
	# Much larger scale — the guardian's visual_root is already scaled 1.22x
	_build_humanoid(parent, guardian_mat, {
		"height": 2.15, "shoulder_width": 0.55, "chest_depth": 0.34,
		"limb_thickness": 0.14,
	})
	# Heavy plate armor
	var plate_mat := _mat_variant(mat, Color(0.28, 0.22, 0.38), 0.72, 0.22)
	_build_chest_armor(parent, plate_mat, 0.05)
	# Massive pauldrons
	for sign: float in [-1.0, 1.0]:
		_sphere(parent, 0.14, 0.24, Vector3(sign * 0.60, 1.42, 0.0), plate_mat)
		_box(parent, Vector3(0.18, 0.10, 0.22), Vector3(sign * 0.58, 1.38, sign * 0.04), Vector3(0, 0, sign * 0.1), plate_mat)
	# Crown/crest
	var crown_mat := _mat_variant(mat, Color(0.35, 0.28, 0.45), 0.68, 0.25)
	_cylinder(parent, 0.22, 0.26, 0.10, Vector3(0, 1.92, 0), Vector3(0, 0, 0), crown_mat)
	for i in range(3):
		var angle := deg_to_rad(float(i - 1) * 25.0)
		var cx := sin(angle) * 0.24
		var cz := -cos(angle) * 0.22
		_box(parent, Vector3(0.04, 0.14, 0.04), Vector3(cx, 2.02, cz), Vector3(angle * 0.3, 0, 0), crown_mat)
	# Greaves
	var greave_mat := _mat_variant(mat, Color(0.28, 0.22, 0.38), 0.68, 0.25)
	for sign: float in [-1.0, 1.0]:
		_cylinder(parent, 0.18, 0.18, 0.35, Vector3(sign * 0.28, 0.30, 0.0), Vector3(0, 0, 0), greave_mat)
	# Gauntlets
	for sign: float in [-1.0, 1.0]:
		_cylinder(parent, 0.12, 0.12, 0.16, Vector3(sign * 0.62, 0.78, sign * 0.04), Vector3(sign * -0.1, 0, 0), plate_mat)


# -- primitive helpers ----------------------------------------------------

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


static func _cylinder(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = 12
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


static func _prism(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _mat_variant(src: StandardMaterial3D, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


static func _mat_emissive(src: StandardMaterial3D, color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
