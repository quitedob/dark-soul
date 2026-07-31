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

var _player: CharacterBody3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var enabled := false
var _strafe_active := false
## 当前动画是否声明了命中窗 method track（有则可选驱动状态机）
var has_timing_method_tracks := false


func setup(player_node: CharacterBody3D) -> void:
	_player = player_node
	_build_skeleton()
	_build_animations()
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
	sm.add_node("Idle", _anim_node("combat/idle"), Vector2(0, 0))
	sm.add_node("Walk", _anim_node("combat/walk"), Vector2(180, 0))
	sm.add_node("Strafe", _make_strafe_blendspace(), Vector2(360, 0))
	sm.add_node("LightAttack", _anim_node("combat/sword_light_1"), Vector2(90, 140))
	sm.add_node("ColossalLeap", _anim_node("combat/colossal_leap"), Vector2(250, 140))
	sm.add_node("Riposte", _anim_node("combat/riposte"), Vector2(90, 260))
	sm.add_node("Backstab", _anim_node("combat/backstab"), Vector2(250, 260))
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
	# D-03：锁敌侧移 BlendSpace2D（前后左右）；4.7 需显式 name
	var bs := AnimationNodeBlendSpace2D.new()
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	bs.min_space = Vector2(-1, -1)
	bs.max_space = Vector2(1, 1)
	bs.add_blend_point(_anim_node("combat/strafe_fwd", "fwd"), Vector2(0, 1), -1, &"fwd")
	bs.add_blend_point(_anim_node("combat/strafe_back", "back"), Vector2(0, -1), -1, &"back")
	bs.add_blend_point(_anim_node("combat/strafe_left", "left"), Vector2(-1, 0), -1, &"left")
	bs.add_blend_point(_anim_node("combat/strafe_right", "right"), Vector2(1, 0), -1, &"right")
	bs.add_blend_point(_anim_node("combat/idle", "center"), Vector2(0, 0), -1, &"center")
	return bs


func _link(sm: AnimationNodeStateMachine, from_name: String, to_name: String) -> void:
	sm.add_transition(from_name, to_name, _trans())


func _trans() -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = 0.05
	return t
