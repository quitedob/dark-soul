class_name PlayerVisuals
extends RefCounted
## Player mesh building, weapon visuals, pose animation, and weapon trail rendering.
## Composition helper — takes a player node reference and delegates visual logic.

const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const ProceduralUtils = preload("res://scripts/core/procedural_utils.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const CombatAreaScript = preload("res://scripts/combat_area.gd")
const WeaponTrailProfileScript = preload("res://scripts/fx/weapon_trail_profile.gd")
const ModelFx = preload("res://scripts/fx/model_fx.gd")
const ModelMotionProfiles = preload("res://scripts/data/model_motion_profiles.gd")
const EmbeddedModelActions = preload("res://scripts/core/embedded_model_actions.gd")

const MAX_TRAIL_POINTS := 12
## 手骨 rest 锚点（mannyquin 骨架 model-space rest 位置，yaw 无关）：武器/盾挂到真实手。
## 注：DEF-hand.R/L 的 model-space rest 是 (-/+)0.739,1.441,-0.065；在 body_yaw(yaw 180) 下
## 手的世界位置才翻成 (+/-)0.739,1.441,0.065。这里存 model-space 值，与 BodyRoot 单位变换对齐。
const HAND_RIGHT_REST := Vector3(-0.739, 1.441, -0.065)
const HAND_LEFT_REST := Vector3(0.739, 1.441, -0.065)
## 统一坐标系：身体 + 武器的单一朝向源（yaw 180 = 背对镜头，用户 F4 关确认）。
const BODY_YAW := PI
## Manny's hand +Y runs wrist-to-fingers; +Z crosses the grip toward the thumb.
## A shaft follows +Z, rather than the palm-normal +X produced by rest-delta alone.
const MANNY_WEAPON_AXES := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)

var _player: Node3D
var _trail_surface_tool: SurfaceTool = null
var _trail_array_mesh: ArrayMesh = null
var _trail_profile: Dictionary = {}
## 当前已构建的职业身体 id（守卫者/无职业 = ""）—— 幂等重建守卫。
var _active_class_id := ""
var _visor_material: StandardMaterial3D = null
## 真模型 BodyRoot 的运动基准高度（apply_movement 需要捕捉一次）。
var _body_model_base_y := 0.0
var _body_model_base_y_set := false
var _equipment_skeleton: Skeleton3D
var _right_hand_bone := -1
var _left_hand_bone := -1
var _right_grip_offset := Basis.IDENTITY
var _left_grip_offset := Basis.IDENTITY
var _shield_grip_offset := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
var _weapon_tip_local := Vector3(0.0, 1.05, 0.0)
## 身体网格分组标记：rebuild_body 借此精确移除旧身体而不误伤 weapon_pivot 等。
const BODY_GROUP := "_player_body_group"
const CAMERA_BODY_HIDE_DISTANCE := 1.0
const CAMERA_BODY_RESTORE_DISTANCE := 1.25
var _camera_body_hidden := false
## Weak references avoid retaining replaced class bodies until the camera retreats.
var _camera_body_visibility: Dictionary = {}


func setup(player_node: Node3D) -> void:
	_player = player_node


# -- public API ------------------------------------------------------------


## Use the collision-resolved Camera3D position, not SpringArm's requested length.
## Hysteresis prevents visibility flicker while scraping a nearby wall. Only body
## roots are changed: authored child visibility, equipment and processing survive.
func update_camera_visibility() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_player.camera) \
			or not is_instance_valid(_player.camera_rig) or not is_instance_valid(_player.body_yaw):
		return
	var distance: float = _player.camera.global_position.distance_to(_player.camera_rig.global_position)
	if distance < CAMERA_BODY_HIDE_DISTANCE:
		_camera_body_hidden = true
	elif distance > CAMERA_BODY_RESTORE_DISTANCE:
		_camera_body_hidden = false
	for id in _camera_body_visibility.keys():
		var saved: Dictionary = _camera_body_visibility[id]
		var body := (saved["root"] as WeakRef).get_ref() as Node3D
		if not is_instance_valid(body):
			_camera_body_visibility.erase(id)
		elif not _camera_body_hidden or body.get_parent() != _player.body_yaw or not body.is_in_group(BODY_GROUP):
			body.visible = bool(saved["visible"])
			_camera_body_visibility.erase(id)
	if not _camera_body_hidden:
		return
	for child in _player.body_yaw.get_children():
		if not child is Node3D or not child.is_in_group(BODY_GROUP):
			continue
		var id: int = child.get_instance_id()
		if not _camera_body_visibility.has(id):
			_camera_body_visibility[id] = {"root": weakref(child), "visible": child.visible}
		child.visible = false


func build_nodes(class_id := "") -> void:
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

	_player.body_yaw = Node3D.new()
	_player.body_yaw.name = "BodyYaw"
	_player.body_yaw.rotation.y = BODY_YAW
	_player.visual_root.add_child(_player.body_yaw)

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
	_visor_material = visor_material
	_active_class_id = class_id
	CharacterMeshFactory.build_player(_player.body_yaw, _player.body_material, visor_material, class_id)
	_refresh_body_references()
	_tag_body_children()

	_player.weapon_pivot = Node3D.new()
	_player.weapon_pivot.name = "WeaponPivot"
	_player.weapon_pivot.position = HAND_RIGHT_REST
	_player.body_yaw.add_child(_player.weapon_pivot)
	# placeholder mesh — will be replaced by update_weapon_visuals()
	_player.weapon_mesh = MeshInstance3D.new()
	_player.weapon_mesh.name = "WeaponRoot"
	_player.weapon_mesh.position.y = -0.35
	_player.weapon_mesh.material_override = _player.weapon_material
	_player.weapon_pivot.add_child(_player.weapon_mesh)
	WeaponMeshFactory.build_into_parent(_player.weapon_pivot, "sword", _player.weapon_material)

	_player.offhand_weapon_pivot = Node3D.new()
	_player.offhand_weapon_pivot.name = "OffhandPivot"
	_player.offhand_weapon_pivot.position = HAND_LEFT_REST
	_player.body_yaw.add_child(_player.offhand_weapon_pivot)
	_player.offhand_weapon_mesh = MeshInstance3D.new()
	_player.offhand_weapon_mesh.name = "OffhandRoot"
	_player.offhand_weapon_mesh.position.y = -0.35
	_player.offhand_weapon_mesh.material_override = _player.weapon_material
	_player.offhand_weapon_pivot.add_child(_player.offhand_weapon_mesh)

	_player.shield_mesh = MeshInstance3D.new()
	_player.shield_mesh.name = "ShieldRoot"
	_player.shield_mesh.position = HAND_LEFT_REST
	_player.shield_mesh.rotation.x = PI * 0.5
	_player.shield_mesh.material_override = make_material(Color("614725"), 0.48, 0.72)
	_player.body_yaw.add_child(_player.shield_mesh)

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
	_player.body_yaw.add_child(_player.weapon_trail)

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


## 仅替换身体模型（BodyRoot / 程序化身体网格），不触碰 weapon_pivot /
## offhand_pivot / shield / weapon_trail / combat_area / camera。同类调用幂等返回。
## L-18：职业 id 解析优先 run_state 的 body_class_override（混合职业覆盖的存档权威），
## 无覆盖时回落调用方传入的 class_id。见 _resolve_body_class。
func rebuild_body(class_id: String) -> void:
	if _player == null or _player.visual_root == null or _player.body_yaw == null or _visor_material == null:
		return
	var resolved_class := _resolve_body_class(class_id)
	if resolved_class == _active_class_id and _has_body():
		return
	EmbeddedModelActions.reset(_player.body_mesh)
	# 移除旧身体（真模型 BodyRoot 或程序化身体网格），保留其余 body_yaw 子节点
	for child in _player.body_yaw.get_children():
		if child.is_in_group(BODY_GROUP):
			_player.body_yaw.remove_child(child)
			child.queue_free()
	# 清除旧职业的常驻粒子/光环，避免色值残留
	_clear_model_vfx()
	# 新身体构建到临时父节点再移植，避免 build_player 的 _clear_children 清空 pivot/camera
	var temp := Node3D.new()
	CharacterMeshFactory.build_player(temp, _player.body_material, _visor_material, resolved_class)
	var index := 0
	for child in temp.get_children():
		temp.remove_child(child)
		_player.body_yaw.add_child(child)
		_player.body_yaw.move_child(child, index)
		child.add_to_group(BODY_GROUP)
		index += 1
	temp.free()
	_active_class_id = resolved_class
	_body_model_base_y_set = false
	_refresh_body_references()
	update_camera_visibility()


## L-18：解析身体职业 id。若 run_state 存在非空 body_class_override 则优先（混合职业
## 覆盖的存档权威），否则回落调用方传入的 class_id。只读，不修改 player.gd 的
## get_active_class_id —— 玩家侧运行覆盖仍由 get_active_class_id() 提供；此覆盖仅在
## run_state 已持久化 body_class_override 时接管身体外观。
func _resolve_body_class(class_id: String) -> String:
	var state = _current_run_state()
	var override := RunStateScript.static_body_class_override(state)
	if not override.is_empty():
		return override
	return class_id


## 定位当前 run_state（只读）。run_state 由 game_world 持有，player.world_node 指向
## game_world；隔离构建/测试无 world 上下文时返回 null → 回落调用方 class_id。
func _current_run_state():
	if _player == null:
		return null
	var world: Variant = _player.get("world_node")
	if not world is Object or world == null:
		return null
	return world.get("run_state")


## 身体引用修复：BodyRoot → 首个 MeshInstance3D → 兜底空 BodyRoot。
func _refresh_body_references() -> void:
	_player.body_mesh = _player.body_yaw.get_node_or_null("BodyRoot") as MeshInstance3D
	if _player.body_mesh == null:
		_player.body_mesh = _player.body_yaw.find_child("*", true, false) as MeshInstance3D
	if _player.body_mesh == null:
		_player.body_mesh = MeshInstance3D.new()
		_player.body_mesh.name = "BodyRoot"
		_player.body_yaw.add_child(_player.body_mesh)
		_player.body_mesh.add_to_group(BODY_GROUP)
	_player.cloak_mesh = _player.body_mesh
	_player.head_mesh = _player.body_mesh
	_player._sync_embedded_body_action()
	_bind_equipment_skeleton()


## Equipment stays under BodyYaw across body swaps. Follow the evaluated skin pose,
## including the final deferred skeleton update, rather than moving the equipment
## into the replaceable BodyRoot or copying a bone's model-local coordinates.
func _bind_equipment_skeleton() -> void:
	if is_instance_valid(_equipment_skeleton):
		if _equipment_skeleton.skeleton_updated.is_connected(_on_equipment_skeleton_updated):
			_equipment_skeleton.skeleton_updated.disconnect(_on_equipment_skeleton_updated)
	_equipment_skeleton = null
	_right_hand_bone = -1
	_left_hand_bone = -1
	_right_grip_offset = Basis.IDENTITY
	_left_grip_offset = Basis.IDENTITY
	_shield_grip_offset = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	_restore_legacy_equipment_pose()
	var hand_prefix := "hand." if EmbeddedModelActions.available(_player.body_mesh) else "DEF-hand."
	for candidate in _player.body_mesh.find_children("*", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		var right := skeleton.find_bone(hand_prefix + "R")
		var left := skeleton.find_bone(hand_prefix + "L")
		if right >= 0 and left >= 0:
			_equipment_skeleton = skeleton
			_right_hand_bone = right
			_left_hand_bone = left
			_equipment_skeleton.skeleton_updated.connect(_on_equipment_skeleton_updated)
			return
	if EmbeddedModelActions.available(_player.body_mesh):
		push_warning("PlayerVisuals: embedded body lacks hand.R/hand.L equipment anchors")


func _on_equipment_skeleton_updated() -> void:
	if _sync_embedded_equipment():
		update_weapon_trail()


func _sync_embedded_equipment() -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_equipment_skeleton):
		return false
	if not _equipment_skeleton.is_inside_tree() or not _player.body_yaw.is_inside_tree():
		return false
	if not _player.body_mesh.is_ancestor_of(_equipment_skeleton):
		return false
	if _player.weapon_pivot == null or _player.offhand_weapon_pivot == null or _player.shield_mesh == null:
		return false
	var to_body: Transform3D = _player.body_yaw.global_transform.affine_inverse() * _equipment_skeleton.global_transform
	var right := _equipment_hand_transform(to_body, _right_hand_bone)
	var left := _equipment_hand_transform(to_body, _left_hand_bone)
	if not right.is_finite() or not left.is_finite():
		return false
	_player.weapon_pivot.transform = right
	_player.offhand_weapon_pivot.transform = left
	# Keep the shield's authored grip-axis correction after the hand's rotation delta.
	_player.shield_mesh.transform = left * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	if not EmbeddedModelActions.available(_player.body_mesh):
		right = _manny_weapon_transform(to_body, _right_hand_bone, true)
		left = _manny_weapon_transform(to_body, _left_hand_bone, false)
		_player.weapon_pivot.transform = right
		_player.offhand_weapon_pivot.transform = left
	if not EmbeddedModelActions.available(_player.body_mesh) and not _legacy_equipment_clip_active():
		# Fallback-only actions retain their grip gesture, relative to the evaluated
		# hand. A real action clip already supplies that movement and must not double it.
		_player.weapon_pivot.basis = right.basis * _right_grip_offset
		_player.offhand_weapon_pivot.basis = left.basis * _left_grip_offset
		_player.shield_mesh.transform = _equipment_hand_transform(to_body, _left_hand_bone) * _shield_grip_offset
	return true


func _manny_weapon_transform(to_body: Transform3D, bone: int, right_hand: bool) -> Transform3D:
	var pose := to_body * _equipment_skeleton.get_bone_global_pose(bone)
	# The grip lies between wrist and finger bases, inside the palm. Manny's
	# middle-finger base is at hand-local Y=.1216; the thumb base is at Y=.0273.
	var grip := Vector3(-0.012 if right_hand else 0.012, 0.075, 0.0)
	return Transform3D(pose.basis.orthonormalized() * MANNY_WEAPON_AXES, pose * grip)


func _legacy_equipment_clip_active() -> bool:
	var bridge = _player._anim_bridge
	if bridge == null or not bridge.enabled or not bridge.has_real_animations():
		return false
	if not bridge.anim_tree.active:
		return bridge.anim_player.is_playing() and bridge.clip_drives_real_body(bridge.anim_player.assigned_animation)
	var playback := bridge.anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var machine := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	if playback == null or machine == null:
		return false
	var current := playback.get_current_node()
	# Heavy/jump attacks and other fallback gestures can leave the locomotion
	# animation running; that does not make their procedural gesture redundant.
	match _player.state:
		_player.State.LOCOMOTION:
			if current not in [&"Idle", &"Walk", &"Strafe"]:
				return false
		_player.State.ATTACK_WINDUP, _player.State.ATTACK_ACTIVE:
			if current != &"LightAttack":
				return false
		_player.State.ATTACK_RECOVERY:
			var expected := &"LightAttack"
			if _player.attack_action_id in ["pierce_thrust", "crescent_leap"]:
				expected = &"Skill"
			elif _player.attack_action_id == "colossal_leap":
				expected = &"ColossalLeap"
			if current != expected:
				return false
		_player.State.GUARD_THRUST:
			if current != &"Skill":
				return false
		_player.State.LEAP_WINDUP, _player.State.LEAP_ACTIVE:
			if current != (&"Skill" if _player._leap_is_curved else &"ColossalLeap"):
				return false
		_player.State.CAST:
			if current not in [&"Cast", &"Skill"]:
				return false
		_:
			return false
	if not machine.has_node(current):
		return false
	var clip := machine.get_node(current) as AnimationNodeAnimation
	# Strafe has no procedural weapon gesture; its blend space drives the hands.
	return current == &"Strafe" or (clip != null and bridge.clip_drives_real_body(clip.animation))


func _equipment_hand_transform(to_body: Transform3D, bone: int) -> Transform3D:
	var pose := to_body * _equipment_skeleton.get_bone_global_pose(bone)
	var rest := to_body * _equipment_skeleton.get_bone_global_rest(bone)
	# Identity at rest preserves the existing weapon axes. Bone rest axes differ
	# between classes, so copying the absolute bone basis would rotate the grips.
	var delta := pose.basis.orthonormalized() * rest.basis.orthonormalized().inverse()
	return Transform3D(delta, pose.origin)


func _restore_legacy_equipment_pose() -> void:
	if _player.weapon_pivot != null:
		var two_handing: bool = _player.grip_mode == _player.GripMode.TWO_HANDED
		_player.weapon_pivot.transform = Transform3D(Basis.IDENTITY, HAND_RIGHT_REST * 0.5 if two_handing else HAND_RIGHT_REST)
	if _player.offhand_weapon_pivot != null:
		_player.offhand_weapon_pivot.transform = Transform3D(Basis.IDENTITY, HAND_LEFT_REST)
	if _player.shield_mesh != null:
		_player.shield_mesh.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), HAND_LEFT_REST)


func _has_body() -> bool:
	for child in _player.body_yaw.get_children():
		if child.is_in_group(BODY_GROUP):
			return true
	return false


## 记录当前 visual_root 的直接身体子节点（调用点：build_player 之后、pivot 之前）。
func _tag_body_children() -> void:
	for child in _player.body_yaw.get_children():
		child.add_to_group(BODY_GROUP)


## 清除职业常驻 VFX（ModelAmbient / ModelAura），供重建身体时替换色值。
func _clear_model_vfx() -> void:
	for name in ["ModelAmbient", "ModelAura"]:
		var fx: Node = _player.body_yaw.get_node_or_null(name)
		if fx != null:
			_player.body_yaw.remove_child(fx)
			fx.free()


## 真模型身体运动层：按职业档案施加 bob + 环境粒子 + 光环。无 BodyRoot（程序化
## 身体）时为安全 no-op。调用方已按状态门控（attack/leap/dodge/冻结/死亡跳过）。
func update_real_body_motion(delta: float, class_id: String) -> void:
	if _player == null or _player.body_yaw == null:
		return
	var model_root := _player.body_yaw.get_node_or_null("BodyRoot") as Node3D
	if model_root == null:
		return
	if not _body_model_base_y_set:
		_body_model_base_y = model_root.position.y
		_body_model_base_y_set = true
	var resolver_id := "player/body/class_%s" % class_id if not class_id.is_empty() else "player/body"
	var profile := ModelMotionProfiles.profile_for(resolver_id)
	var vfx: Dictionary = profile.get("vfx", {})
	if not EmbeddedModelActions.available(_player.body_mesh):
		ModelFx.apply_movement(model_root, _body_model_base_y, profile.get("movement", {}), delta)
	ModelFx.ensure_ambient(_player.body_yaw, vfx.get("ambient", {}))
	if vfx.has("aura"):
		ModelFx.ensure_aura(_player.body_yaw, vfx["aura"])


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
	_cache_weapon_tip()

	var two_handing: bool = _player.grip_mode == _player.GripMode.TWO_HANDED
	var single_from_pair: bool = (
		_player.grip_mode == _player.GripMode.ONE_HANDED
		and _player.combat_style in [_player.CombatStyle.TWIN_COLOSSI, _player.CombatStyle.CRESCENT_PAIR]
	)
	# 双持：主武器略居中；成对改单持时隐藏副手
	_player.weapon_pivot.position = HAND_RIGHT_REST * 0.5 if two_handing else HAND_RIGHT_REST

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
	_sync_embedded_equipment()


func _cache_weapon_tip() -> void:
	var samples: Array[Vector3] = []
	_collect_weapon_vertices(_player.weapon_pivot, Transform3D.IDENTITY, samples)
	_weapon_tip_local = Vector3(0.0, 1.05, 0.0)
	var furthest := -INF
	for point in samples:
		if point.y > furthest:
			furthest = point.y
			_weapon_tip_local = point


func _collect_weapon_vertices(node: Node3D, to_pivot: Transform3D, samples: Array[Vector3]) -> void:
	if not node.visible:
		return
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				samples.append(to_pivot * point)
	for child in node.get_children():
		if child is Node3D:
			_collect_weapon_vertices(child, to_pivot * child.transform, samples)


func update_visual_pose() -> void:
	if _player.visual_root == null:
		return
	if EmbeddedModelActions.available(_player.body_mesh):
		_player.visual_root.rotation = Vector3.ZERO
		var flip := PI if _player.get("_debug_flip_body") else 0.0
		_player.body_yaw.rotation.y = BODY_YAW + flip
		_sync_embedded_equipment()
		update_weapon_trail()
		return
	if _player.state == _player.State.DEAD:
		return
	_restore_legacy_equipment_pose()
	_player.visual_root.rotation.z = 0.0
	# F4 调试翻转：翻转整个 body_yaw（身体+武器一起），默认 BODY_YAW；翻转时 +PI。
	if _player.body_yaw != null:
		var flip := PI if _player.get("_debug_flip_body") else 0.0
		_player.body_yaw.rotation.y = BODY_YAW + flip
	_player.weapon_pivot.rotation = Vector3.ZERO
	if _player.offhand_weapon_pivot != null:
		_player.offhand_weapon_pivot.rotation = Vector3.ZERO
	if _player.guard_active and _player.shield_mesh != null and _player.shield_mesh.visible:
		_player.shield_mesh.position = HAND_LEFT_REST + Vector3(0.0, 0.05, -0.25)
		_player.shield_mesh.rotation = Vector3(PI * 0.5, 0.0, -0.18)
	elif _player.shield_mesh != null:
		_player.shield_mesh.position = HAND_LEFT_REST
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
	_right_grip_offset = _player.weapon_pivot.basis
	_left_grip_offset = _player.offhand_weapon_pivot.basis
	_shield_grip_offset = Transform3D(_player.shield_mesh.basis, _player.shield_mesh.position - HAND_LEFT_REST)
	_sync_embedded_equipment()
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
	# Get weapon tip position in global space, then convert to body_yaw local
	var tip_global: Vector3 = _player.weapon_pivot.to_global(_weapon_tip_local)
	var tip_in_visual: Vector3 = _player.body_yaw.to_local(tip_global)
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
	# This vertex-colored ribbon is unshaded. SurfaceTool.generate_normals()
	# supports separate triangles only, not the triangle strip used here.
	_trail_surface_tool.commit(_trail_array_mesh)
	_player.weapon_trail.mesh = _trail_array_mesh


func make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return ProceduralUtils.make_material(color, roughness, metallic)
