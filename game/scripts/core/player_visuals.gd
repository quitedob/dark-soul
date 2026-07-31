class_name PlayerVisuals
extends RefCounted
## Player mesh building, weapon visuals, pose animation, and weapon trail rendering.
## Composition helper — takes a player node reference and delegates visual logic.

const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const ProceduralUtils = preload("res://scripts/core/procedural_utils.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const CombatAreaScript = preload("res://scripts/combat_area.gd")
const WeaponTrailProfileScript = preload("res://scripts/fx/weapon_trail_profile.gd")

const MAX_TRAIL_POINTS := 12

var _player: Node3D
var _trail_surface_tool: SurfaceTool = null
var _trail_array_mesh: ArrayMesh = null
var _trail_profile: Dictionary = {}


func setup(player_node: Node3D) -> void:
	_player = player_node


# -- public API ------------------------------------------------------------


func build_nodes() -> void:
	_player.collision_layer = 2
	_player.collision_mask = 1
	# 显式 CharacterBody3D 参数，避免引擎升级改变隐式默认值
	_player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_player.up_direction = Vector3.UP
	_player.floor_stop_on_slope = true
	_player.floor_constant_speed = false
	_player.floor_block_on_wall = true
	_player.floor_max_angle = deg_to_rad(45.0)
	_player.floor_snap_length = 0.35
	_player.safe_margin = 0.001
	_player.max_slides = 6
	_player.wall_min_slide_angle = deg_to_rad(15.0)
	_player.slide_on_ceiling = true

	_player.body_collision = CollisionShape3D.new()
	_player.body_collision.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	_player.body_collision.shape = capsule
	_player.body_collision.position.y = 0.93
	_player.add_child(_player.body_collision)

	_player.visual_root = Node3D.new()
	_player.visual_root.name = "Visuals"
	_player.add_child(_player.visual_root)

	_player.body_material = StandardMaterial3D.new()
	_player.body_material.albedo_color = Color("26384a")
	_player.body_material.roughness = 0.76
	_player.weapon_material = StandardMaterial3D.new()
	_player.weapon_material.albedo_color = Color("9aa3aa")
	_player.weapon_material.metallic = 0.82
	_player.weapon_material.roughness = 0.28

	# Build composite character model (torso + limbs + head + armor + cloak + visor)
	var visor_material := make_material(Color("f36a2f"), 0.25, 0.0)
	visor_material.emission_enabled = true
	visor_material.emission = Color("f13c15")
	visor_material.emission_energy_multiplier = 2.2
	CharacterMeshFactory.build_player(_player.visual_root, _player.body_material, visor_material)
	# Keep references for death / state visuals — find them by node path
	_player.body_mesh = _player.visual_root.get_node_or_null("BodyRoot") as MeshInstance3D
	if _player.body_mesh == null:
		_player.body_mesh = _player.visual_root.find_child("*", true, false) as MeshInstance3D
	if _player.body_mesh == null:
		_player.body_mesh = MeshInstance3D.new()
		_player.body_mesh.name = "BodyRoot"
		_player.visual_root.add_child(_player.body_mesh)
	_player.cloak_mesh = _player.body_mesh
	_player.head_mesh = _player.body_mesh

	_player.weapon_pivot = Node3D.new()
	_player.weapon_pivot.name = "WeaponPivot"
	_player.weapon_pivot.position = Vector3(0.58, 1.25, -0.15)
	_player.visual_root.add_child(_player.weapon_pivot)
	# placeholder mesh — will be replaced by update_weapon_visuals()
	_player.weapon_mesh = MeshInstance3D.new()
	_player.weapon_mesh.name = "WeaponRoot"
	_player.weapon_mesh.position.y = -0.35
	_player.weapon_mesh.material_override = _player.weapon_material
	_player.weapon_pivot.add_child(_player.weapon_mesh)
	WeaponMeshFactory.build_into_parent(_player.weapon_pivot, "sword", _player.weapon_material)

	_player.offhand_weapon_pivot = Node3D.new()
	_player.offhand_weapon_pivot.name = "OffhandPivot"
	_player.offhand_weapon_pivot.position = Vector3(-0.58, 1.25, -0.15)
	_player.visual_root.add_child(_player.offhand_weapon_pivot)
	_player.offhand_weapon_mesh = MeshInstance3D.new()
	_player.offhand_weapon_mesh.name = "OffhandRoot"
	_player.offhand_weapon_mesh.position.y = -0.35
	_player.offhand_weapon_mesh.material_override = _player.weapon_material
	_player.offhand_weapon_pivot.add_child(_player.offhand_weapon_mesh)

	_player.shield_mesh = MeshInstance3D.new()
	_player.shield_mesh.name = "ShieldRoot"
	_player.shield_mesh.position = Vector3(-0.5, 1.22, -0.28)
	_player.shield_mesh.rotation.x = PI * 0.5
	_player.shield_mesh.material_override = make_material(Color("614725"), 0.48, 0.72)
	_player.visual_root.add_child(_player.shield_mesh)

	# Weapon trail mesh（C-05：顶点色驱动色强）
	_player._trail_material = StandardMaterial3D.new()
	_player._trail_material.albedo_color = Color(1.0, 0.85, 0.5, 0.45)
	_player._trail_material.emission_enabled = true
	_player._trail_material.emission = Color(1.0, 0.7, 0.2)
	_player._trail_material.emission_energy_multiplier = 1.2
	_player._trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_player._trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_player._trail_material.no_depth_test = true
	_player._trail_material.vertex_color_use_as_albedo = true
	_player.weapon_trail = MeshInstance3D.new()
	_player.weapon_trail.name = "WeaponTrail"
	_player.weapon_trail.visible = false
	_player.weapon_trail.material_override = _player._trail_material
	_player.visual_root.add_child(_player.weapon_trail)

	_player.combat_area = CombatAreaScript.new()
	_player.combat_area.name = "CombatArea"
	_player.add_child(_player.combat_area)
	_player.combat_area.configure(_player, 1.25, 1.45, Vector3(0.0, 1.0, -1.0))

	_player.camera_rig = Node3D.new()
	_player.camera_rig.name = "CameraRig"
	_player.add_child(_player.camera_rig)
	_player.camera_rig.top_level = true
	_player.camera_rig.global_position = _player.global_position + Vector3.UP * 1.45
	_player.camera_rig.rotation.y = 0.0

	_player.camera_pitch = Node3D.new()
	_player.camera_pitch.name = "Pitch"
	_player.camera_pitch.rotation.x = -0.2
	_player.camera_rig.add_child(_player.camera_pitch)

	_player.spring_arm = SpringArm3D.new()
	_player.spring_arm.name = "SpringArm3D"
	_player.spring_arm.spring_length = 5.2
	_player.spring_arm.margin = 0.25
	_player.spring_arm.collision_mask = 1
	_player.camera_pitch.add_child(_player.spring_arm)

	_player.camera = Camera3D.new()
	_player.camera.name = "Camera3D"
	_player.camera.current = true
	_player.camera.fov = 68.0
	_player.spring_arm.add_child(_player.camera)
	update_weapon_visuals()


func update_weapon_visuals() -> void:
	if _player.weapon_pivot == null or _player.offhand_weapon_pivot == null or _player.shield_mesh == null:
		return
	# Build composite weapon meshes from equipment specs
	var right_shape := HandEquipmentScript.get_mesh_shape(_player.right_hand_item)
	var right_color := HandEquipmentScript.get_mesh_color(_player.right_hand_item)
	var left_shape := HandEquipmentScript.get_mesh_shape(_player.left_hand_item)
	var left_color := HandEquipmentScript.get_mesh_color(_player.left_hand_item)

	var right_mat := make_material(right_color, 0.28, 0.82)
	var left_mat := make_material(left_color, 0.28, 0.82)
	_player.weapon_material.albedo_color = right_color
	_player.weapon_material.metallic = 0.82
	_player.weapon_material.roughness = 0.28

	WeaponMeshFactory.build_into_parent(_player.weapon_pivot, right_shape, right_mat)

	var two_handing: bool = _player.grip_mode == _player.GripMode.TWO_HANDED
	var single_from_pair: bool = (
		_player.grip_mode == _player.GripMode.ONE_HANDED
		and _player.combat_style in [_player.CombatStyle.TWIN_COLOSSI, _player.CombatStyle.CRESCENT_PAIR]
	)
	# 双持：主武器略居中；成对改单持时隐藏副手
	_player.weapon_pivot.position = Vector3(0.18, 1.28, -0.18) if two_handing else Vector3(0.58, 1.25, -0.15)

	# Offhand visibility and mesh
	var offhand_visible: bool = _player.left_hand_item in [
		"xingtian_axe_left",
		"marksman_dagger",
		"talisman_papers",
		"spirit_stone",
	] and not two_handing and not single_from_pair
	_player.offhand_weapon_pivot.visible = offhand_visible
	if offhand_visible:
		WeaponMeshFactory.build_into_parent(_player.offhand_weapon_pivot, left_shape, left_mat)

	# Shield visibility and mesh — 双持失去盾
	var shield_visible: bool = _player.left_hand_item == "reliquary_shield" and not two_handing
	_player.shield_mesh.visible = shield_visible
	if shield_visible:
		var shield_mat := make_material(left_color, 0.48, 0.72)
		WeaponMeshFactory.build_shield(_player.shield_mesh, shield_mat)


func update_visual_pose() -> void:
	if _player.visual_root == null or _player.state == _player.State.DEAD:
		return
	_player.visual_root.rotation.z = 0.0
	_player.visual_root.rotation.y = move_toward(_player.visual_root.rotation.y, 0.0, 0.15)
	_player.weapon_pivot.rotation = Vector3.ZERO
	if _player.offhand_weapon_pivot != null:
		_player.offhand_weapon_pivot.rotation = Vector3.ZERO
	if _player.guard_active and _player.shield_mesh != null and _player.shield_mesh.visible:
		_player.shield_mesh.position = Vector3(-0.28, 1.36, -0.62)
		_player.shield_mesh.rotation = Vector3(PI * 0.5, 0.0, -0.18)
	elif _player.shield_mesh != null:
		_player.shield_mesh.position = Vector3(-0.5, 1.22, -0.28)
		_player.shield_mesh.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	match _player.state:
		_player.State.ATTACK_WINDUP:
			var progress: float = 1.0 - _player.state_time / maxf(_player.state_duration, 0.001)
			_player.weapon_pivot.rotation.z = lerpf(0.0, -1.35 if _player.attack_heavy else -0.9, progress)
		_player.State.ATTACK_ACTIVE:
			var progress: float = 1.0 - _player.state_time / maxf(_player.state_duration, 0.001)
			_player.weapon_pivot.rotation.z = lerpf(-1.1, 1.35, progress)
		_player.State.ATTACK_RECOVERY:
			_player.weapon_pivot.rotation.z = lerpf(0.2, 0.0, 1.0 - _player.state_time / maxf(_player.state_duration, 0.001))
		_player.State.DODGE:
			var progress: float = 1.0 - _player.state_time / maxf(_player.state_duration, 0.001)
			_player.visual_root.rotation.x = sin(progress * PI) * -0.55
		_player.State.PARRY:
			_player.weapon_pivot.rotation.z = -0.45
			_player.visual_root.rotation.y = sin(_player.state_time * 18.0) * 0.05
		_player.State.GUARD_THRUST:
			_player.weapon_pivot.rotation.x = -PI * 0.5
			_player.weapon_pivot.rotation.z = -0.15
		_player.State.LEAP_WINDUP:
			var progress: float = 1.0 - _player.state_time / maxf(_player.state_duration, 0.001)
			_player.weapon_pivot.rotation.z = lerpf(0.0, -1.55, progress)
			if _player.offhand_weapon_pivot != null:
				_player.offhand_weapon_pivot.rotation.z = lerpf(0.0, 1.55, progress)
			_player.visual_root.rotation.x = -0.18
		_player.State.LEAP_ACTIVE:
			var progress: float = 1.0 - _player.state_time / maxf(_player.state_duration, 0.001)
			_player.weapon_pivot.rotation.z = lerpf(-1.5, 1.35, progress)
			if _player.offhand_weapon_pivot != null:
				_player.offhand_weapon_pivot.rotation.z = lerpf(1.5, -1.35, progress)
			_player.visual_root.rotation.x = 0.22
		_player.State.CAST:
			var pulse := sin((_player.state_duration - _player.state_time) * 12.0) * 0.12
			_player.weapon_pivot.rotation.z = -0.7 + pulse
			_player.visual_root.rotation.y = pulse * 0.3
		_player.State.CHARGE_HEAVY:
			# 蓄力架势：武器后引，随时间微颤
			var charge_t: float = clampf(_player._charge_time / 1.4, 0.0, 1.0)
			_player.weapon_pivot.rotation.z = lerpf(-0.35, -1.65, charge_t)
			_player.weapon_pivot.rotation.x = lerpf(0.0, -0.35, charge_t)
			_player.visual_root.rotation.x = -0.08
		_player.State.STAGGER:
			_player.visual_root.rotation.z = sin(_player.state_time * 28.0) * 0.12
		_:
			_player.visual_root.rotation.x = move_toward(_player.visual_root.rotation.x, 0.0, 0.12)
	update_weapon_trail()


func update_weapon_trail() -> void:
	if _player.weapon_trail == null or _player.weapon_pivot == null:
		return
	var should_trail: bool = _player.state in [
		_player.State.ATTACK_WINDUP, _player.State.ATTACK_ACTIVE, _player.State.ATTACK_RECOVERY,
		_player.State.LEAP_WINDUP, _player.State.LEAP_ACTIVE,
		_player.State.GUARD_THRUST,
	]
	if not should_trail:
		_player.weapon_trail.visible = false
		_player._trail_active = false
		_player._trail_points.clear()
		_trail_profile.clear()
		return
	# C-05：按重量档 + 风格 trail_color 刷新材质
	_refresh_trail_profile()
	# Get weapon tip position in global space, then convert to visual_root local
	var tip_local: Vector3 = _player.weapon_pivot.position + Vector3(0, 1.05, 0)
	var tip_global: Vector3 = _player.visual_root.to_global(tip_local)
	var tip_in_visual: Vector3 = _player.visual_root.to_local(tip_global)
	if _player._trail_points.is_empty() or _player._trail_points[_player._trail_points.size() - 1].distance_to(tip_in_visual) > 0.04:
		_player._trail_points.append(tip_in_visual)
	while _player._trail_points.size() > MAX_TRAIL_POINTS:
		_player._trail_points.pop_front()
	_player.weapon_trail.visible = _player._trail_points.size() >= 2
	if _player._trail_points.size() >= 2:
		_build_trail_ribbon(_player._trail_points)


## 解析当前攻击拖尾档位并写回材质 emission
func _refresh_trail_profile() -> void:
	var tags: Array = []
	if _player.get("_current_attack") != null and _player._current_attack != null:
		tags = _player._current_attack.tags
	var weight := WeaponTrailProfileScript.resolve_weight_from_attack(
		bool(_player.attack_heavy),
		tags,
		String(_player.attack_action_id)
	)
	var style_color := Color.WHITE
	if _player.has_method("_style_data"):
		var style = _player._style_data()
		if style != null and "trail_color" in style:
			style_color = style.trail_color
	_trail_profile = WeaponTrailProfileScript.resolve(weight, style_color)
	if _player._trail_material != null:
		var c: Color = _trail_profile["color"]
		_player._trail_material.albedo_color = Color(c.r, c.g, c.b, float(_trail_profile["alpha"]))
		_player._trail_material.emission = c
		_player._trail_material.emission_energy_multiplier = float(_trail_profile["emission"])


func _build_trail_ribbon(points: Array[Vector3]) -> void:
	# Cache SurfaceTool & ArrayMesh to avoid per-frame GPU allocation churn.
	if _trail_surface_tool == null:
		_trail_surface_tool = SurfaceTool.new()
		_trail_array_mesh = ArrayMesh.new()
	_trail_surface_tool.clear()
	_trail_array_mesh.clear_surfaces()
	_trail_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var width := float(_trail_profile.get("width", 0.06))
	var base: Color = _trail_profile.get("color", Color(1.0, 0.85, 0.5))
	var peak_alpha := float(_trail_profile.get("alpha", 0.55))
	for i in range(points.size()):
		var t := float(i) / maxf(float(points.size() - 1), 1.0)
		var p := points[i]
		var right := Vector3.RIGHT if i == points.size() - 1 else (points[i + 1] - points[maxi(i - 1, 0)]).normalized()
		var across := right.cross(Vector3.UP).normalized() * width
		var col := Color(base.r, base.g, base.b, lerpf(peak_alpha, 0.02, t))
		_trail_surface_tool.set_color(col)
		_trail_surface_tool.add_vertex(p + across)
		_trail_surface_tool.set_color(col)
		_trail_surface_tool.add_vertex(p - across)
	_trail_surface_tool.generate_normals()
	_trail_surface_tool.commit(_trail_array_mesh)
	_player.weapon_trail.mesh = _trail_array_mesh


func make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return ProceduralUtils.make_material(color, roughness, metallic)
