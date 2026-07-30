extends RefCounted
class_name PlayerAnimationBridge
## 直剑 AnimationTree + 占位 Skeleton root-motion POC（不替换程序化网格）

const ROOT_BONE := "Root"
const LIGHT_ANIM := &"sword_light_1"
const IDLE_ANIM := &"idle"
const WALK_ANIM := &"walk"

var _player: CharacterBody3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var enabled := false


func setup(player_node: CharacterBody3D) -> void:
	_player = player_node
	_build_skeleton()
	_build_animations()
	_build_tree()
	enabled = anim_tree != null and _playback != null


func travel_locomotion(moving: bool) -> void:
	if not enabled or _playback == null:
		return
	_playback.travel("Walk" if moving else "Idle")


func travel_light_attack() -> void:
	if not enabled or _playback == null:
		return
	_playback.travel("LightAttack")


func consume_root_motion() -> Vector3:
	if not enabled or anim_tree == null:
		return Vector3.ZERO
	return anim_tree.get_root_motion_position()


func sample_light_root_delta() -> float:
	# 合约用：轻击动画 Root 轨总前移量（本地 -Z）
	if anim_player == null:
		return 0.0
	var anim := anim_player.get_animation("combat/%s" % String(LIGHT_ANIM))
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
	lib.add_animation(String(LIGHT_ANIM), _make_light_attack())
	anim_player.add_animation_library("combat", lib)


func _root_track(anim: Animation) -> int:
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("RootMotionSkeleton:Root"))
	return track


func _make_pose_anim(length: float, loop: bool, z_end: float) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var track := _root_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, length, Vector3(0, 0, z_end))
	return anim


func _make_walk() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := _root_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.2, Vector3(0, 0, -0.08))
	anim.position_track_insert_key(track, 0.4, Vector3.ZERO)
	return anim


func _make_light_attack() -> Animation:
	var anim := Animation.new()
	anim.length = 0.55
	anim.loop_mode = Animation.LOOP_NONE
	var track := _root_track(anim)
	anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(track, 0.18, Vector3(0, 0, -0.22))
	anim.position_track_insert_key(track, 0.35, Vector3(0, 0, -0.55))
	anim.position_track_insert_key(track, 0.55, Vector3(0, 0, -0.55))
	return anim


func _build_tree() -> void:
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = _make_state_machine()
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_player.add_child(anim_tree)
	# 相对 AnimationTree：同级 AnimationPlayer / Skeleton
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	anim_tree.root_motion_track = NodePath("../RootMotionSkeleton:Root")
	anim_tree.active = true
	_playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _playback != null:
		_playback.travel("Idle")


func _make_state_machine() -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = "combat/idle"
	var walk := AnimationNodeAnimation.new()
	walk.animation = "combat/walk"
	var light := AnimationNodeAnimation.new()
	light.animation = "combat/sword_light_1"
	sm.add_node("Idle", idle, Vector2(0, 0))
	sm.add_node("Walk", walk, Vector2(200, 0))
	sm.add_node("LightAttack", light, Vector2(100, 120))
	sm.add_transition("Idle", "Walk", _trans())
	sm.add_transition("Walk", "Idle", _trans())
	sm.add_transition("Idle", "LightAttack", _trans())
	sm.add_transition("Walk", "LightAttack", _trans())
	sm.add_transition("LightAttack", "Idle", _trans())
	return sm


func _trans() -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = 0.05
	return t
