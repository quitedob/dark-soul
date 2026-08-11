extends RefCounted
class_name PlayerAnimationBridge
## 直剑 AnimationTree + 占位 Skeleton：Physics root-motion 管线（D-01~D-05）
## D-08：method-track 回调钩子；无轨时仍由 gameplay 计时权威

signal combo_window_opened
signal combo_window_closed
signal hitbox_activated
signal hitbox_deactivated
signal forward_impulse_requested(amount: float)
signal rotation_locked
signal rotation_unlocked

const ROOT_BONE := "Root"
const LIGHT_ANIM := &"sword_light_1"
const IDLE_ANIM := &"idle"
const WALK_ANIM := &"walk"
const STRAFE_FWD := &"strafe_fwd"
const STRAFE_BACK := &"strafe_back"
const STRAFE_LEFT := &"strafe_left"
const STRAFE_RIGHT := &"strafe_right"
const LEAP_ANIM := &"colossal_leap"
const RIPOSTE_ANIM := &"riposte"
const BACKSTAB_ANIM := &"backstab"

## Twin Colossi leap 根运动总前冲（米，本地 -Z）
const LEAP_ROOT_FORWARD := 2.4

## ── D-01 真蒙皮动画管线：真库优先 + 程序化回退 ──
## 抽库工具把 mannyquin.glb 的 clip 导出到这里（scripts/tools/export_mannyquin_animations.gd）。
const REAL_LIBRARY_PATH := "res://resources/animations/mannyquin_lib.tres"
## 真 clip 注入到 AnimationPlayer 的第二个 library，路径 "real/<clip>"。
const REAL_LIBRARY_NAME := &"real"
## 身体骨架探针骨：找到该骨即认为身体模型是可驱动真骨骼的 Skeleton3D。
const REAL_SKELETON_PROBE_BONE := "root"
## 真库缺 idle 时的 mannyquin rig 绑位 clip 名。
## Godot GLB 导入把 clip 名 "mixamo.com" 消毒为 "mixamo_com"（下划线），const 用导入后名。
const REAL_IDLE_FALLBACK := &"Armature|mixamo_com|Layer0_godot_rig"
## 绑位 clip 兜底只在该 clip 有实质内容时才接管 idle，防止 1 帧绑位姿冻结玩家为 A-pose。
const MIN_FALLBACK_TRACKS := 4
const MIN_FALLBACK_LENGTH := 0.1
## `_clip_path` 用到的全部状态键：真动画层是否驱动以它们为准。
const REAL_STATE_KEYS: Array[StringName] = [
	&"idle", &"walk",
	&"strafe_fwd", &"strafe_back", &"strafe_left", &"strafe_right",
	&"sword_light_1", &"colossal_leap", &"riposte", &"backstab",
]
## 整身根运动骨：从真骨骼层剔除（根位移/旋转仍走现有 RootMotionSkeleton 的
## "Root" 轨，保持 physics root-motion 契约不变；躯干/四肢骨姿态允许驱动）。
const REAL_ROOT_MOTION_BONES := ["root", "Root"]

var _player: CharacterBody3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var enabled := false
var _strafe_active := false
## 当前动画是否声明了命中窗 method track（有则可选驱动状态机）
var has_timing_method_tracks := false

## D-01：真动画层是否激活（库已加载 + 身体骨架匹配 + 至少一个可用 clip）
var real_layer_active := false
var _real_library: AnimationLibrary = null
var _real_skeleton: Skeleton3D = null
var _real_loaded_count := 0


func setup(player_node: CharacterBody3D) -> void:
	_player = player_node
	_build_skeleton()
	_build_animations()
	# D-01：先注入真库，_build_tree 才能把有真 clip 的状态指向 "real/<clip>"。
	_try_load_real_animations()
	_build_tree()
	enabled = anim_tree != null and _playback != null


## AnimationPlayer method track → 开启命中盒
func anim_event_hitbox_on() -> void:
	hitbox_activated.emit()


## AnimationPlayer method track → 关闭命中盒
func anim_event_hitbox_off() -> void:
	hitbox_deactivated.emit()


## AnimationPlayer method track → 前冲冲量
func anim_event_push_forward(amount: float = 0.0) -> void:
	forward_impulse_requested.emit(amount)


## 连段窗开
func anim_event_combo_open() -> void:
	combo_window_opened.emit()


## 连段窗关
func anim_event_combo_close() -> void:
	combo_window_closed.emit()


## 锁定面向
func anim_event_rotation_lock() -> void:
	rotation_locked.emit()


## 解锁面向
func anim_event_rotation_unlock() -> void:
	rotation_unlocked.emit()


## G-06：局部时间膨胀驱动 AnimationPlayer 播放速率
func set_speed_scale(scale: float) -> void:
	if anim_player == null:
		return
	anim_player.speed_scale = maxf(scale, 0.01)


func is_physics_callback() -> bool:
	# D-04：必须 Physics，避免帧率漂移
	if anim_tree == null:
		return false
	return anim_tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS


func travel_locomotion(moving: bool, locked_on: bool = false, blend: Vector2 = Vector2.ZERO) -> void:
	if not enabled or _playback == null:
		return
	if locked_on:
		_strafe_active = true
		_playback.travel("Strafe")
		# BlendSpace2D：x=左右，y=前后
		anim_tree.set("parameters/Strafe/blend_position", blend)
	else:
		_strafe_active = false
		_playback.travel("Walk" if moving else "Idle")


func set_strafe_blend(blend: Vector2) -> void:
	if not enabled or anim_tree == null:
		return
	if not _strafe_active:
		return
	anim_tree.set("parameters/Strafe/blend_position", blend)


func travel_light_attack() -> void:
	if not enabled or _playback == null:
		return
	_strafe_active = false
	_playback.travel("LightAttack")


func travel_leap(curved: bool = false) -> void:
	# Twin Colossi 直线 leap 走根运动；曲刃 leap 仍可走同轨占位
	if not enabled or _playback == null:
		return
	_strafe_active = false
	_playback.travel("ColossalLeap" if not curved else "ColossalLeap")


func travel_execution(kind: StringName) -> void:
	if not enabled or _playback == null:
		return
	_strafe_active = false
	if kind == &"back":
		_playback.travel("Backstab")
	else:
		_playback.travel("Riposte")


func consume_root_motion() -> Vector3:
	if not enabled or anim_tree == null:
		return Vector3.ZERO
	return anim_tree.get_root_motion_position()


func consume_root_motion_rotation() -> Quaternion:
	if not enabled or anim_tree == null:
		return Quaternion.IDENTITY
	return anim_tree.get_root_motion_rotation()


func sample_light_root_delta() -> float:
	# 合约：轻击 Root 轨总前移（本地 -Z）
	return _sample_root_z_delta("combat/%s" % String(LIGHT_ANIM))


func sample_leap_root_delta() -> float:
	# 合约：Twin Colossi leap 前冲量
	return _sample_root_z_delta("combat/%s" % String(LEAP_ANIM))


func has_strafe_blendspace() -> bool:
	if anim_tree == null or anim_tree.tree_root == null:
		return false
	var sm := anim_tree.tree_root as AnimationNodeStateMachine
	if sm == null:
		return false
	return sm.has_node("Strafe")


func _sample_root_z_delta(anim_path: String) -> float:
	if anim_player == null:
		return 0.0
	var anim := anim_player.get_animation(anim_path)
	if anim == null:
		return 0.0
	var track := anim.find_track(NodePath("RootMotionSkeleton:Root"), Animation.TYPE_POSITION_3D)
	if track < 0:
		return 0.0
	var key_count := anim.track_get_key_count(track)
	if key_count < 1:
		return 0.0
	var end_pos: Vector3 = anim.track_get_key_value(track, key_count - 1)
	return absf(end_pos.z)


## ── D-01 真动画层：public API ──


## 真动画层是否在驱动：至少一个状态实际解析到真 clip（而非"库非空"）。
func has_real_animations() -> bool:
	if not real_layer_active or _real_library == null:
		return false
	for key in REAL_STATE_KEYS:
		if not _real_clip_for(key).is_empty():
			return true
	return false


## 真库里的 clip 名列表（源库，未注入前）。
func get_real_animation_list() -> Array[String]:
	var out: Array[String] = []
	if _real_library != null:
		for n in _real_library.get_animation_list():
			out.append(String(n))
	return out


## 某状态名解析到的真 clip 名；无匹配返回 &""。
func real_clip_for(state_key: StringName) -> StringName:
	return _real_clip_for(state_key)


## 显式注入真库（供 smoke 测试/热加载）。`library` 可以是 res:// 路径或现成
## AnimationLibrary。成功返回 true 并重建状态机使真 clip 生效。
func configure_real_animations(library: Variant, skeleton: Skeleton3D = null) -> bool:
	if anim_player == null or _player == null:
		return false
	var lib := _coerce_library(library)
	if lib == null or lib.get_animation_list().is_empty():
		return false
	var skel := skeleton if skeleton != null else _find_body_skeleton()
	if skel == null or skel.find_bone(REAL_SKELETON_PROBE_BONE) < 0:
		return false
	_real_library = lib
	_real_skeleton = skel
	_ingest_real_library(lib)
	real_layer_active = _real_loaded_count > 0
	if real_layer_active:
		_rebuild_tree_for_real()
	return real_layer_active


## ── D-01 真动画层：private ──


## setup 时尝试加载默认真库并探测身体骨架；任何缺失都静默回退程序化。
func _try_load_real_animations() -> void:
	if not ResourceLoader.exists(REAL_LIBRARY_PATH):
		return
	var lib := load(REAL_LIBRARY_PATH) as AnimationLibrary
	if lib == null or lib.get_animation_list().is_empty():
		return
	var skel := _find_body_skeleton()
	if skel == null or skel.find_bone(REAL_SKELETON_PROBE_BONE) < 0:
		# 身体模型不是 mannyquin 骨架（职业 GLB/程序化身体）→ 真层不可用
		return
	_real_library = lib
	_real_skeleton = skel
	_ingest_real_library(lib)
	real_layer_active = _real_loaded_count > 0


func _coerce_library(library: Variant) -> AnimationLibrary:
	if library is AnimationLibrary:
		return library
	if library is String and ResourceLoader.exists(library):
		return load(library) as AnimationLibrary
	return null


## 从玩家身体下找第一个 Skeleton3D（BodyRoot 真模型实例内的骨架）。
func _find_body_skeleton() -> Skeleton3D:
	if _player == null:
		return null
	var visual_root := _player.get_node_or_null("Visuals") as Node3D
	if visual_root == null:
		return null
	var body_root := visual_root.get_node_or_null("BodyRoot") as Node3D
	if body_root == null:
		return null
	return _first_skeleton(body_root)


func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var hit := _first_skeleton(child)
		if hit != null:
			return hit
	return null


## 把源库 clip 重映射后注入 AnimationPlayer 的 "real" library。
## 每个 clip 只保留能落到目标骨架上的骨骼姿态轨；整身根运动骨剔除。
func _ingest_real_library(lib: AnimationLibrary) -> void:
	if _real_skeleton == null:
		return
	# track 路径相对 AnimationPlayer 的 root_node（".." = 玩家）解析，
	# 因此节点部分用 玩家→骨架 的相对路径。
	var skeleton_path: NodePath = _player.get_path_to(_real_skeleton)
	var out := AnimationLibrary.new()
	_real_loaded_count = 0
	for anim_name in lib.get_animation_list():
		var src := lib.get_animation(anim_name)
		if src == null:
			continue
		var remapped := _remap_real_clip(src, skeleton_path)
		if remapped == null or remapped.get_track_count() < 1:
			continue  # 全被剔除（如 mannyquin 的 root+hips 绑位层）→ 不注入
		out.add_animation(anim_name, remapped)
		_real_loaded_count += 1
		# 轻击/跃击真 clip 无 method 轨 → 补种现有程序化 timing 轨，
		# 保住 D-08 hitbox/combo 计时契约（真 clip 驱动时也能开窗）。
		if String(anim_name) == String(LIGHT_ANIM):
			_stamp_method_tracks_from(remapped, LIGHT_ANIM)
		elif String(anim_name) == String(LEAP_ANIM):
			_stamp_method_tracks_from(remapped, LEAP_ANIM)
	if _real_loaded_count > 0:
		if anim_player.has_animation_library(REAL_LIBRARY_NAME):
			anim_player.remove_animation_library(REAL_LIBRARY_NAME)
		anim_player.add_animation_library(REAL_LIBRARY_NAME, out)


## 重映射 clip：骨骼姿态轨路径改指向目标骨架；根运动骨轨剔除。
func _remap_real_clip(src: Animation, skeleton_path: NodePath) -> Animation:
	var out := Animation.new()
	out.length = src.length
	out.loop_mode = src.loop_mode
	var real_bones := {}
	for i in _real_skeleton.get_bone_count():
		real_bones[_real_skeleton.get_bone_name(i)] = true
	for t in range(src.get_track_count()):
		var tpath := src.track_get_path(t)
		var ttype := src.track_get_type(t)
		if ttype == Animation.TYPE_METHOD:
			continue  # method 轨由 _stamp_method_tracks_from 按需重种
		var bone := _bone_from_track_path(tpath)
		if bone.is_empty() or not real_bones.has(bone):
			continue
		if bone in REAL_ROOT_MOTION_BONES:
			continue  # 整身根位移/旋转留在 RootMotionSkeleton，避免双重位移
		var nt := out.add_track(ttype)
		out.track_set_path(nt, NodePath("%s:%s" % [skeleton_path, bone]))
		# Godot 4.7 的 Animation 无 track_set_update_mode / track_get_update_mode
		# （4.0-4.3 曾有 update-mode API，4.7 已移除）。只复制插值类型；新轨默认
		# 即线性插值，不依赖不存在的 API。
		out.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
		for k in range(src.track_get_key_count(t)):
			out.track_insert_key(
				nt,
				src.track_get_key_time(t, k),
				src.track_get_key_value(t, k)
			)
	return out


## 从骨骼轨路径提取骨名："<node>:<bone>" → "<bone>"。
func _bone_from_track_path(p: NodePath) -> String:
	var s := String(p)
	var i := s.find(":")
	if i < 0:
		return ""
	return s.substr(i + 1)


## 把程序化 clip 的 method 轨复制到真 clip（路径相对 AnimationPlayer 根 = 玩家）。
func _stamp_method_tracks_from(out: Animation, kind: StringName) -> void:
	if anim_player == null:
		return
	var src := anim_player.get_animation("combat/%s" % kind)
	if src == null:
		return
	for t in range(src.get_track_count()):
		if src.track_get_type(t) != Animation.TYPE_METHOD:
			continue
		var nt := out.add_track(Animation.TYPE_METHOD)
		out.track_set_path(nt, src.track_get_path(t))
		for k in range(src.track_get_key_count(t)):
			out.track_insert_key(
				nt,
				src.track_get_key_time(t, k),
				src.track_get_key_value(t, k)
			)


## 状态 → 播放路径：有真 clip 用 "real/<clip>"，否则 "combat/<clip>"（程序化回退）。
func _clip_path(state_key: StringName) -> String:
	if real_layer_active:
		var real := _real_clip_for(state_key)
		if not real.is_empty():
			return "real/%s" % real
	return "combat/%s" % state_key


## 状态 → 真 clip 名：优先精确同名；idle 缺省时回退 mannyquin rig 绑位层
## （仅当该 clip 有实质内容，避免 1 帧绑位姿冻结玩家）。
func _real_clip_for(state_key: StringName) -> StringName:
	if _real_library == null:
		return &""
	if _real_library.has_animation(String(state_key)):
		return state_key
	if state_key == IDLE_ANIM and _real_library.has_animation(String(REAL_IDLE_FALLBACK)):
		var fb := _real_library.get_animation(String(REAL_IDLE_FALLBACK))
		if fb != null and fb.get_track_count() >= MIN_FALLBACK_TRACKS \
				and fb.length >= MIN_FALLBACK_LENGTH:
			return REAL_IDLE_FALLBACK
	return &""


## configure_real_animations 命中后重建状态机，让节点指向真 clip。
func _rebuild_tree_for_real() -> void:
	if anim_tree != null and is_instance_valid(anim_tree):
		_player.remove_child(anim_tree)
		anim_tree.free()
	anim_tree = null
	_build_tree()
	enabled = anim_tree != null and _playback != null


func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "RootMotionSkeleton"
	_player.add_child(skeleton)
	skeleton.add_bone(ROOT_BONE)
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	skeleton.add_bone("Hips")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)))


func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	_player.add_child(anim_player)
	var lib := AnimationLibrary.new()
	lib.add_animation(String(IDLE_ANIM), _make_pose_anim(0.5, true, 0.0))
	lib.add_animation(String(WALK_ANIM), _make_walk())
	lib.add_animation(String(STRAFE_FWD), _make_strafe(Vector3(0, 0, -0.1)))
	lib.add_animation(String(STRAFE_BACK), _make_strafe(Vector3(0, 0, 0.08)))
	lib.add_animation(String(STRAFE_LEFT), _make_strafe(Vector3(-0.09, 0, 0)))
	lib.add_animation(String(STRAFE_RIGHT), _make_strafe(Vector3(0.09, 0, 0)))
	lib.add_animation(String(LIGHT_ANIM), _make_light_attack())
	lib.add_animation(String(LEAP_ANIM), _make_colossal_leap())
	lib.add_animation(String(RIPOSTE_ANIM), _make_execution_pose(0.95, -0.12))
	lib.add_animation(String(BACKSTAB_ANIM), _make_execution_pose(1.05, -0.18))
	anim_player.add_animation_library("combat", lib)


func _root_pos_track(anim: Animation) -> int:
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("RootMotionSkeleton:Root"))
	return track


func _root_rot_track(anim: Animation) -> int:
	# 可选 yaw 根旋转轨（D-02）
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath("RootMotionSkeleton:Root"))
	return track


func _make_pose_anim(length: float, loop: bool, z_end: float) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, length, Vector3(0, 0, z_end))
	return anim


func _make_walk() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.2, Vector3(0, 0, -0.08))
	anim.position_track_insert_key(track, 0.4, Vector3.ZERO)
	return anim


func _make_strafe(peak: Vector3) -> Animation:
	# 锁敌侧移占位：循环小幅根位移，供 BlendSpace2D 混合
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.2, peak)
	anim.position_track_insert_key(track, 0.4, Vector3.ZERO)
	return anim


func _make_light_attack() -> Animation:
	var anim := Animation.new()
	anim.length = 0.55
	anim.loop_mode = Animation.LOOP_NONE
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.18, Vector3(0, 0, -0.22))
	anim.position_track_insert_key(track, 0.35, Vector3(0, 0, -0.55))
	anim.position_track_insert_key(track, 0.55, Vector3(0, 0, -0.55))
	# D-08：method track 驱动 hitbox / combo / 前冲
	_stamp_callback_tracks(anim)
	return anim


## 为动画写入 method-call 轨（路径相对 AnimationPlayer 根=玩家）
func _stamp_callback_tracks(anim: Animation) -> void:
	var mt := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(mt, NodePath("."))
	anim.track_insert_key(mt, 0.18, {"method": "anim_event_hitbox_on", "args": []})
	anim.track_insert_key(mt, 0.42, {"method": "anim_event_hitbox_off", "args": []})
	anim.track_insert_key(mt, 0.28, {"method": "anim_event_combo_open", "args": []})
	anim.track_insert_key(mt, 0.50, {"method": "anim_event_combo_close", "args": []})
	anim.track_insert_key(mt, 0.20, {"method": "anim_event_push_forward", "args": [0.4]})
	has_timing_method_tracks = true


func _make_colossal_leap() -> Animation:
	# Twin Colossi leap：windup 蓄力 + active 前冲，总位移 ~LEAP_ROOT_FORWARD
	var anim := Animation.new()
	anim.length = 0.66
	anim.loop_mode = Animation.LOOP_NONE
	var pos := _root_pos_track(anim)
	anim.position_track_insert_key(pos, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(pos, 0.18, Vector3(0, 0, -0.35))
	anim.position_track_insert_key(pos, 0.38, Vector3(0, 0, -1.15))
	anim.position_track_insert_key(pos, 0.55, Vector3(0, 0, -LEAP_ROOT_FORWARD))
	anim.position_track_insert_key(pos, 0.66, Vector3(0, 0, -LEAP_ROOT_FORWARD))
	var rot := _root_rot_track(anim)
	anim.rotation_track_insert_key(rot, 0.0, Quaternion.IDENTITY)
	anim.rotation_track_insert_key(rot, 0.66, Quaternion.IDENTITY)
	# 跃击命中窗与前冲由 method track 驱动
	var mt := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(mt, NodePath("."))
	anim.track_insert_key(mt, 0.28, {"method": "anim_event_hitbox_on", "args": []})
	anim.track_insert_key(mt, 0.52, {"method": "anim_event_hitbox_off", "args": []})
	anim.track_insert_key(mt, 0.30, {"method": "anim_event_push_forward", "args": [0.55]})
	has_timing_method_tracks = true
	return anim


func _make_execution_pose(length: float, z_nudge: float) -> Animation:
	# 处决配对占位：微幅靠近，位移主要由锚点对齐驱动
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, length * 0.35, Vector3(0, 0, z_nudge))
	anim.position_track_insert_key(track, length, Vector3(0, 0, z_nudge * 0.5))
	return anim


func _build_tree() -> void:
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = _make_state_machine()
	# D-04：强制 Physics 回调
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_player.add_child(anim_tree)
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	anim_tree.root_motion_track = NodePath("../RootMotionSkeleton:Root")
	anim_tree.active = true
	_playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _playback != null:
		_playback.travel("Idle")


func _make_state_machine() -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	# D-01：_clip_path 有真 clip 时指向 "real/<clip>"，否则程序化 "combat/<clip>"。
	sm.add_node("Idle", _anim_node(_clip_path(IDLE_ANIM)), Vector2(0, 0))
	sm.add_node("Walk", _anim_node(_clip_path(WALK_ANIM)), Vector2(180, 0))
	sm.add_node("Strafe", _make_strafe_blendspace(), Vector2(360, 0))
	sm.add_node("LightAttack", _anim_node(_clip_path(LIGHT_ANIM)), Vector2(90, 140))
	sm.add_node("ColossalLeap", _anim_node(_clip_path(LEAP_ANIM)), Vector2(250, 140))
	sm.add_node("Riposte", _anim_node(_clip_path(RIPOSTE_ANIM)), Vector2(90, 260))
	sm.add_node("Backstab", _anim_node(_clip_path(BACKSTAB_ANIM)), Vector2(250, 260))
	# 移动互转
	_link(sm, "Idle", "Walk")
	_link(sm, "Walk", "Idle")
	_link(sm, "Idle", "Strafe")
	_link(sm, "Walk", "Strafe")
	_link(sm, "Strafe", "Idle")
	_link(sm, "Strafe", "Walk")
	# 攻击 / leap / 处决
	for from_name in ["Idle", "Walk", "Strafe"]:
		_link(sm, from_name, "LightAttack")
		_link(sm, from_name, "ColossalLeap")
		_link(sm, from_name, "Riposte")
		_link(sm, from_name, "Backstab")
	_link(sm, "LightAttack", "Idle")
	_link(sm, "ColossalLeap", "Idle")
	_link(sm, "Riposte", "Idle")
	_link(sm, "Backstab", "Idle")
	return sm


func _anim_node(path: String, node_name: String = "") -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = path
	if not node_name.is_empty():
		node.resource_name = node_name
	return node


func _make_strafe_blendspace() -> AnimationNodeBlendSpace2D:
	# D-03：锁敌侧移 BlendSpace2D（前后左右）；4.7 需显式 name。
	# D-01：真 strafe clip 可用时 blend 点指向 "real/strafe_*"，否则程序化回退。
	var bs := AnimationNodeBlendSpace2D.new()
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	bs.min_space = Vector2(-1, -1)
	bs.max_space = Vector2(1, 1)
	bs.add_blend_point(_anim_node(_clip_path(STRAFE_FWD), "fwd"), Vector2(0, 1), -1, &"fwd")
	bs.add_blend_point(_anim_node(_clip_path(STRAFE_BACK), "back"), Vector2(0, -1), -1, &"back")
	bs.add_blend_point(_anim_node(_clip_path(STRAFE_LEFT), "left"), Vector2(-1, 0), -1, &"left")
	bs.add_blend_point(_anim_node(_clip_path(STRAFE_RIGHT), "right"), Vector2(1, 0), -1, &"right")
	bs.add_blend_point(_anim_node(_clip_path(IDLE_ANIM), "center"), Vector2(0, 0), -1, &"center")
	return bs


func _link(sm: AnimationNodeStateMachine, from_name: String, to_name: String) -> void:
	sm.add_transition(from_name, to_name, _trans())


func _trans() -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = 0.05
	return t
