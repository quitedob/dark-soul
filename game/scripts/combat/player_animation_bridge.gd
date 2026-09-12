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
## 战技/施法占位 pose：程序化回退（真 body pose 由真 clip 提供）
const CAST_ANIM := &"cast"
const SKILL_ANIM := &"skill_pose"

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
## 真根运动键：这些状态键的真 clip 若源带根位移，remap 时保留为
## RootMotionSkeleton:Root position 轨（字符级位移，非 DEF 骨姿态）。
## 与 retarget_oal_to_mannyquin.gd 的 ROOT_MOTION_KEYS 一致。
const REAL_ROOT_MOTION_KEYS: Array[StringName] = [&"colossal_leap"]
## The bundled OAL sword clip raises the wrist until 0.525 s, then sweeps through
## 0.700 s (length 1.166667 s). Fit those authored phases to gameplay AttackData;
## scaling only the whole clip leaves the hitbox open during the raised windup.
const REAL_LIGHT_CONTACT_PHASE := Vector2(0.45, 0.60)
const TIMED_LIGHT_ANIM := &"light_attack_timed"
const REAL_BODY_POSE_META := &"real_body_pose"

var _player: CharacterBody3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var enabled := false
var _strafe_active := false
## Cast/Skill 状态机节点引用；真库重建状态机后由 _make_state_machine 重新获取
var _cast_node: AnimationNodeAnimation = null
var _skill_node: AnimationNodeAnimation = null
## 当前动画是否声明了命中窗 method track（有则可选驱动状态机）
var has_timing_method_tracks := false

## D-01：真动画层是否激活（库已加载 + 身体骨架匹配 + 至少一个可用 clip）
var real_layer_active := false
var _real_library: AnimationLibrary = null
var _real_skeleton: Skeleton3D = null
var _real_loaded_count := 0
## 注入校验：本次 ingest 实际注入成功的 clip 名（remap 存活者）集合。
## _real_clip_for 只在此集合内解析，杜绝"源库有名但 remap 后 0 轨被剔除"
## 的悬空 real/<clip> —— 名存实亡的 clip 永不驱动任何状态。
var _real_surviving: Dictionary = {}
var _real_light_source: Animation
var _timed_light_cache: Dictionary = {}
var _light_node: AnimationNodeAnimation


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


func travel_light_attack(attack: AttackData = null) -> void:
	if attack != null:
		travel_melee_attack(attack)
		return
	if not enabled or _playback == null:
		return
	_strafe_active = false
	_playback.start("LightAttack", true)


## Ground heavy uses the same authored sword motion at its own AttackData
## cadence. Without a real sword source, retain the existing heavy fallback.
func travel_melee_attack(attack: AttackData, heavy := false) -> bool:
	if not enabled or _playback == null or attack == null:
		return false
	if heavy and _real_light_source == null:
		return false
	_strafe_active = false
	_configure_light_timing(attack)
	# Keep the existing state name for compatibility; it now covers real ground
	# melee. travel() to the current state would not restart a queued swing.
	_playback.start("LightAttack", true)
	return true


func _configure_light_timing(attack: AttackData) -> void:
	var source := _real_light_source if _real_light_source != null else anim_player.get_animation("combat/%s" % LIGHT_ANIM)
	var chain_open := attack.chain_open_seconds if attack.chain_open_seconds > 0.0 else attack.windup_seconds + attack.active_seconds
	var chain_close := attack.chain_close_seconds if attack.chain_close_seconds > 0.0 else attack.windup_seconds + attack.active_seconds + attack.recovery_seconds
	var key := [attack.windup_seconds, attack.active_seconds, attack.recovery_seconds, chain_open, chain_close]
	if not _timed_light_cache.has(key):
		var contact := REAL_LIGHT_CONTACT_PHASE * source.length if _real_light_source != null else Vector2(0.18, 0.42)
		var timed := _retime_light_clip(source, contact, attack, chain_open, chain_close)
		# The runtime copy lives in combat/, but retains its real skeletal pose
		# provenance. A retimed procedural root-only fallback must stay false.
		timed.set_meta(REAL_BODY_POSE_META, _real_light_source != null)
		_timed_light_cache[key] = timed
	var clip: Animation = _timed_light_cache[key]
	var library := anim_player.get_animation_library("combat")
	if not library.has_animation(TIMED_LIGHT_ANIM) or library.get_animation(TIMED_LIGHT_ANIM) != clip:
		if library.has_animation(TIMED_LIGHT_ANIM):
			library.remove_animation(TIMED_LIGHT_ANIM)
		library.add_animation(TIMED_LIGHT_ANIM, clip)
	_light_node.animation = "combat/%s" % TIMED_LIGHT_ANIM


func clip_drives_real_body(path: StringName) -> bool:
	if not real_layer_active or anim_player == null or not anim_player.has_animation(path):
		return false
	return String(path).begins_with("real/") or bool(anim_player.get_animation(path).get_meta(REAL_BODY_POSE_META, false))


func _retime_light_clip(source: Animation, contact: Vector2, attack: AttackData, chain_open: float, chain_close: float) -> Animation:
	var out := Animation.new()
	out.length = attack.windup_seconds + attack.active_seconds + attack.recovery_seconds
	out.loop_mode = Animation.LOOP_NONE
	for track in source.get_track_count():
		var kind := source.track_get_type(track)
		if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var target := out.add_track(kind)
		out.track_set_path(target, source.track_get_path(track))
		out.track_set_interpolation_type(target, source.track_get_interpolation_type(track))
		var times: Array[float] = [0.0, contact.x, contact.y, source.length]
		for index in source.track_get_key_count(track):
			times.append(source.track_get_key_time(track, index))
		times.sort()
		for at: float in times:
			var pose: Variant
			match kind:
				Animation.TYPE_POSITION_3D:
					pose = source.position_track_interpolate(track, at)
				Animation.TYPE_ROTATION_3D:
					pose = source.rotation_track_interpolate(track, at)
				Animation.TYPE_SCALE_3D:
					pose = source.scale_track_interpolate(track, at)
			# Insert the exact boundary poses too: keys crossing a phase boundary
			# must not interpolate across two different playback rates.
			var mapped: float
			if at <= contact.x:
				mapped = at / contact.x * attack.windup_seconds
			elif at <= contact.y:
				mapped = attack.windup_seconds + (at - contact.x) / (contact.y - contact.x) * attack.active_seconds
			else:
				mapped = attack.windup_seconds + attack.active_seconds + (at - contact.y) / (source.length - contact.y) * attack.recovery_seconds
			out.track_insert_key(target, mapped, pose)
	# Separate tracks preserve simultaneous hit-off and combo-open events;
	# Animation replaces an existing key when a second key has the same time.
	for group in [
		[[attack.windup_seconds, "anim_event_hitbox_on", []],
			[attack.windup_seconds + attack.active_seconds, "anim_event_hitbox_off", []]],
		[[chain_open, "anim_event_combo_open", []], [chain_close, "anim_event_combo_close", []]],
		[[attack.windup_seconds + attack.active_seconds / 12.0, "anim_event_push_forward", [0.4]]],
	]:
		var events := out.add_track(Animation.TYPE_METHOD)
		out.track_set_path(events, NodePath("."))
		for event in group:
			out.track_insert_key(events, minf(float(event[0]), out.length), {"method": event[1], "args": event[2]})
	return out


func travel_leap(curved: bool = false) -> void:
	# Twin Colossi 直线 leap 走根运动；curved 仅作兼容入参（无独立程序化占位）
	if not enabled or _playback == null:
		return
	_strafe_active = false
	_playback.travel("ColossalLeap")


func travel_execution(kind: StringName) -> void:
	if not enabled or _playback == null:
		return
	_strafe_active = false
	if kind == &"back":
		_playback.travel("Backstab")
	else:
		_playback.travel("Riposte")


## 施法 body 动画：stance 有真 clip 用真姿态，否则程序化 cast pose。
func travel_cast(stance: StringName = &"") -> void:
	if not enabled or _playback == null or _cast_node == null:
		return
	_strafe_active = false
	_cast_node.animation = _resolve_pose_path(stance, CAST_ANIM)
	_playback.travel("Cast")


## 战技 body 动画：stance 有真 clip 用真姿态，否则程序化 skill pose。
func travel_skill(stance: StringName = &"") -> void:
	if not enabled or _playback == null or _skill_node == null:
		return
	_strafe_active = false
	_skill_node.animation = _resolve_pose_path(stance, SKILL_ANIM)
	_playback.travel("Skill")


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


## 真 clip 是否携带 RootMotionSkeleton:Root position 轨（真根运动键专用）。
## 只查注入后的 real/<clip>（在存活集合内），退化/剔除返回 false。
func real_root_motion_active(state_key: StringName) -> bool:
	if not real_layer_active or anim_player == null:
		return false
	var real := _real_clip_for(state_key)
	if real.is_empty():
		return false
	var anim := anim_player.get_animation("real/%s" % real)
	if anim == null:
		return false
	return anim.find_track(NodePath("RootMotionSkeleton:Root"), Animation.TYPE_POSITION_3D) >= 0


## 真 clip 根轨的净前向位移（本地 -Z，正=向前）。用末键-首键，而非绝对末值：
## 源 Hips 绝对位置带站立高度偏移，只有相对位移才是字符级前进量。
## 无轨 / 缺失返回 0。
func real_root_motion_forward(state_key: StringName) -> float:
	if not real_root_motion_active(state_key):
		return 0.0
	var real := _real_clip_for(state_key)
	var anim := anim_player.get_animation("real/%s" % real)
	var track := anim.find_track(NodePath("RootMotionSkeleton:Root"), Animation.TYPE_POSITION_3D)
	if track < 0:
		return 0.0
	var key_count := anim.track_get_key_count(track)
	if key_count < 1:
		return 0.0
	var start: Vector3 = anim.track_get_key_value(track, 0)
	var end: Vector3 = anim.track_get_key_value(track, key_count - 1)
	return -(end.z - start.z)


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
	# BodyRoot 现在挂在 Visuals/BodyYaw 下（统一坐标系），用递归查找而非直接子节点。
	var body_root := visual_root.find_child("BodyRoot", true, false) as Node3D
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
	# 重建时清空存活集合，避免累积陈旧名字（多次 ingest/热加载）。
	_real_surviving.clear()
	_real_light_source = null
	_timed_light_cache.clear()
	# track 路径相对 AnimationPlayer 的 root_node（".." = 玩家）解析，
	# 因此节点部分用 玩家→骨架 的相对路径。
	var skeleton_path: NodePath = _player.get_path_to(_real_skeleton)
	var out := AnimationLibrary.new()
	_real_loaded_count = 0
	for anim_name in lib.get_animation_list():
		var src := lib.get_animation(anim_name)
		if src == null:
			continue
		var remapped := _remap_real_clip(src, skeleton_path, anim_name)
		if remapped == null or remapped.get_track_count() < 1:
			continue  # 全被剔除（如 mannyquin 的 root+hips 绑位层）→ 不注入
		out.add_animation(anim_name, remapped)
		_real_surviving[anim_name] = true
		_real_loaded_count += 1
		# 轻击/跃击真 clip 无 method 轨 → 补种现有程序化 timing 轨，
		# 保住 D-08 hitbox/combo 计时契约（真 clip 驱动时也能开窗）。
		if String(anim_name) == String(LIGHT_ANIM):
			_real_light_source = remapped.duplicate()
			_stamp_method_tracks_from(remapped, LIGHT_ANIM)
		elif String(anim_name) == String(LEAP_ANIM):
			_stamp_method_tracks_from(remapped, LEAP_ANIM)
	if _real_loaded_count > 0:
		if anim_player.has_animation_library(REAL_LIBRARY_NAME):
			anim_player.remove_animation_library(REAL_LIBRARY_NAME)
		anim_player.add_animation_library(REAL_LIBRARY_NAME, out)
	# 真骨架存在时，给 cast/skill 程序化 pose 补种前臂抬起轨（幂等）。
	# combat 库在 setup 阶段已建立（_build_animations），此处直接重取并修改 pose 动画对象，
	# 使真骨架下回退占位也带前臂姿态，而非纯根位移。
	if anim_player != null and anim_player.has_animation_library("combat"):
		_stamp_pose_arm_tracks(anim_player.get_animation("combat/%s" % CAST_ANIM))
		_stamp_pose_arm_tracks(anim_player.get_animation("combat/%s" % SKILL_ANIM))


## 重映射 clip：骨骼姿态轨路径改指向目标骨架；根运动骨轨剔除。
## state_key 用于真根运动白名单：REAL_ROOT_MOTION_KEYS 内保留 RootMotionSkeleton 轨。
## 默认 &""（非白名单）保持既有剔除行为；旧 2 参调用方（如 real_strafe_back_contract）
## 不传状态键时行为不变。
func _remap_real_clip(src: Animation, skeleton_path: NodePath, state_key: StringName = &"") -> Animation:
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
		var node := _node_from_track_path(tpath)
		# 真根运动轨：仅白名单状态键保留。路径保持 RootMotionSkeleton:Root 原样（字符级
		# 位移，非 DEF 骨姿态）；骨名 "Root" 不能走常规剔除路径——它既在
		# REAL_ROOT_MOTION_BONES 中也不是 DEF 骨。非白名单仍照旧剔除。
		if state_key in REAL_ROOT_MOTION_KEYS and node == "RootMotionSkeleton" \
				and ttype == Animation.TYPE_POSITION_3D:
			var rt := out.add_track(ttype)
			out.track_set_path(rt, NodePath("RootMotionSkeleton:Root"))
			out.track_set_interpolation_type(rt, src.track_get_interpolation_type(t))
			for k in range(src.track_get_key_count(t)):
				out.track_insert_key(
					rt,
					src.track_get_key_time(t, k),
					src.track_get_key_value(t, k)
				)
			continue
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


## 从轨路径提取节点名："<node>:<bone>" → "<node>"（无冒号返回整体）。
func _node_from_track_path(p: NodePath) -> String:
	var s := String(p)
	var i := s.find(":")
	if i < 0:
		return s
	return s.substr(0, i)


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


## 状态 → 真 clip 名：优先精确同名；idle 缺省时回退 mannyquin rig 绑位层。
## 解析只指向"实际可播放"的 real clip —— 存活集合（ingest 注入的）或 anim_player
## "real" 库中确实存在的同名 clip。绝不回退源库 _real_library：那里可能有 remap 后
## 0 轨被剔除的 clip（remap 存活者才会注入 anim_player 的 real 库），杜绝 _clip_path
## 指向不存在的 real/<clip>（注入时校验）。
## idle 绑位回退守卫施加在注入后的 clip（real/<name>）上（避免 1 帧绑位姿冻结玩家）。
func _real_clip_for(state_key: StringName) -> StringName:
	if not real_layer_active or anim_player == null:
		return &""
	if state_key in _real_surviving or anim_player.has_animation("real/%s" % state_key):
		return state_key
	if state_key == IDLE_ANIM and (REAL_IDLE_FALLBACK in _real_surviving \
			or anim_player.has_animation("real/%s" % REAL_IDLE_FALLBACK)):
		var fb := anim_player.get_animation("real/%s" % REAL_IDLE_FALLBACK)
		if fb != null and fb.get_track_count() >= MIN_FALLBACK_TRACKS \
				and fb.length >= MIN_FALLBACK_LENGTH:
			return REAL_IDLE_FALLBACK
	return &""


## 任意 stance 键 → 播放路径：有真 clip 用 "real/<clip>"，否则回退程序化占位。
## 不用 _clip_path(stance)：任意 stance 键没有对应的 "combat/<stance>" 程序化 clip。
func _resolve_pose_path(stance: StringName, fallback_anim: StringName) -> String:
	if real_layer_active:
		var real := _real_clip_for(stance)
		if not real.is_empty():
			return "real/%s" % real
	return "combat/%s" % fallback_anim


## 寻找可驱动的前臂骨（Mixamo DEF-* 风格优先，通用 Forearm 名回退）。
## 找不到任何臂骨返回 ""——调用方保持仅根位移占位，不做任何骨架假定。
func _find_pose_arm_bone() -> String:
	if _real_skeleton == null:
		return ""
	for name in [
		"DEF-forearm.R", "DEF-forearm.L",
		"Forearm.R", "Forearm.L",
		"mixamorig:RightForeArm", "mixamorig:LeftForeArm",
		"RightForeArm", "LeftForeArm",
	]:
		if _real_skeleton.find_bone(name) >= 0:
			return name
	return ""


## 真骨架存在时给 cast/skill 程序化 pose 补种前臂抬起轨。
## 轨路径与 _remap_real_clip 一致（<玩家→骨架相对路径>:<骨名>，相对 AnimationPlayer 根=玩家）。
## 幂等：同一轨路径已存在则跳过（configure 可能多次 ingest）。找不到臂骨 / 未配置真骨架
## 则保持仅根位移——只对 find_bone 确认存在的骨写轨，绝不假定任意骨架。
func _stamp_pose_arm_tracks(anim: Animation) -> void:
	if anim == null or _real_skeleton == null or _player == null:
		return
	var arm := _find_pose_arm_bone()
	if arm.is_empty():
		return
	var skeleton_path: NodePath = _player.get_path_to(_real_skeleton)
	var target := NodePath("%s:%s" % [skeleton_path, arm])
	for t in range(anim.get_track_count()):
		if anim.track_get_path(t) == target:
			return  # 已补种过
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, target)
	anim.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
	anim.rotation_track_insert_key(track, anim.length * 0.35, Quaternion(Vector3(0, 0, 1), -0.55))
	anim.rotation_track_insert_key(track, anim.length, Quaternion.IDENTITY)


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
	lib.add_animation(String(CAST_ANIM), _make_cast_pose())
	lib.add_animation(String(SKILL_ANIM), _make_skill_pose())
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


## 施法占位：短促前倾后回位，仅根位移（真 body pose 由真 clip 提供）
func _make_cast_pose() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.22, Vector3(0, 0, -0.12))
	anim.position_track_insert_key(track, 0.5, Vector3.ZERO)
	return anim


## 战技占位：略长，前+下 "commit" 后恢复，仅根位移
func _make_skill_pose() -> Animation:
	var anim := Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_NONE
	var track := _root_pos_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.25, Vector3(0, -0.05, -0.18))
	anim.position_track_insert_key(track, 0.6, Vector3.ZERO)
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
	# D-02 根运动：root_motion_track 必须与动画轨路径精确一致（Godot 用 NodePath 字符串比较）。
	# 程序化/真 clip 的根位移轨均为 "RootMotionSkeleton:Root"（相对 AnimationPlayer 根=玩家）；
	# 写成 "../RootMotionSkeleton:Root"（相对 AnimationTree 子节点）是两条不同 NodePath →
	# consume_root_motion() 恒 0，根运动从未流过树（leap/轻击一直静默回退代码驱动）。
	anim_tree.root_motion_track = NodePath("RootMotionSkeleton:Root")
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
	_light_node = _anim_node(_clip_path(LIGHT_ANIM))
	sm.add_node("LightAttack", _light_node, Vector2(90, 140))
	sm.add_node("ColossalLeap", _anim_node(_clip_path(LEAP_ANIM)), Vector2(250, 140))
	sm.add_node("Riposte", _anim_node(_clip_path(RIPOSTE_ANIM)), Vector2(90, 260))
	sm.add_node("Backstab", _anim_node(_clip_path(BACKSTAB_ANIM)), Vector2(250, 260))
	# Cast / Skill body 动画状态（真库重建后此处重取节点引用）
	_cast_node = _anim_node(_clip_path(CAST_ANIM))
	sm.add_node("Cast", _cast_node, Vector2(90, 380))
	_skill_node = _anim_node(_clip_path(SKILL_ANIM))
	sm.add_node("Skill", _skill_node, Vector2(250, 380))
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
	# Cast / Skill：从全部状态可达，且可回 Idle
	for from_name in ["Idle", "Walk", "Strafe", "LightAttack", "ColossalLeap", "Riposte", "Backstab"]:
		_link(sm, from_name, "Cast")
		_link(sm, from_name, "Skill")
	_link(sm, "Cast", "Idle")
	_link(sm, "Skill", "Idle")
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
