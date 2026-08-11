extends SceneTree
## D-01 真蒙皮动画管线合约：
## 1) 无真库时 bridge 走纯程序化（回归：enabled + root delta + BS2D 均在）。
## 2) 有真库且身体骨架匹配时，bridge 能加载真库（animation list 非空）、
##    真层激活、Idle 状态切到 "real/<clip>"，且现有 root-motion 合约不破坏。
## 3) 真库 clip 只含整身根运动骨（如 mannyquin 的 "root" 轨）→ 剔除后 0 可用轨，
##    真层保持关闭，纯程序化回退（负例）。

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")

const TMP_HEAD_PATH := "res://tests/smoke/_player_anim_real_lib_head.tmp.tres"
const TMP_ROOT_PATH := "res://tests/smoke/_player_anim_real_lib_root.tmp.tres"

var _failures: Array[String] = []


func _init() -> void:
	_test_no_library_procedural_fallback()
	_test_real_library_loads_and_drives()
	_test_root_only_clip_stays_fallback()
	_test_mannyquin_bind_pose_guarded()
	_cleanup_tmp_files()
	if _failures.is_empty():
		print("PLAYER_ANIMATION_REAL_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## 1) 无真库：setup 全程序化，真层关闭。
func _test_no_library_procedural_fallback() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.enabled, "no-lib: bridge must enable (procedural).")
	_expect(not bridge.real_layer_active, "no-lib: real layer must stay off.")
	_expect(not bridge.has_real_animations(), "no-lib: has_real_animations must be false.")
	_expect(bridge.sample_light_root_delta() >= 0.5, "no-lib: light root delta must still be procedural.")
	_expect(bridge.has_strafe_blendspace(), "no-lib: Strafe BlendSpace2D must still exist.")
	_expect(bridge.skeleton != null and bridge.anim_tree != null and bridge.anim_player != null,
		"no-lib: full procedural pipeline required.")
	body.queue_free()


## 2) 有真库 + 骨架匹配：加载、注入、重建状态机指向真 clip；root 合约不破。
func _test_real_library_loads_and_drives() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	# 模拟真模型身体：Visuals/BodyRoot/Skeleton3D（root 探针骨 + 肢体骨）
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	body.add_child(visuals)
	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	visuals.add_child(body_root)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	skel.add_bone("DEF-head")
	skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)))
	body_root.add_child(skel)

	var lib := _make_head_library()
	var save_err := ResourceSaver.save(lib, TMP_HEAD_PATH)
	_expect(save_err == OK, "real-lib: temp library save failed (err %d)." % save_err)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	_expect(not bridge.real_layer_active, "real-lib: real layer off before configure (default lib absent).")
	var ok := bridge.configure_real_animations(TMP_HEAD_PATH, skel)
	_expect(ok, "real-lib: configure_real_animations must succeed with matching skeleton.")
	_expect(bridge.real_layer_active, "real-lib: real layer must activate after configure.")
	_expect(bridge.has_real_animations(), "real-lib: has_real_animations must be true.")
	var list: Array[String] = bridge.get_real_animation_list()
	_expect(not list.is_empty(), "real-lib: animation list must be non-empty.")
	_expect(list.has("idle"), "real-lib: animation list must contain 'idle'.")
	_expect(not bridge.real_clip_for(&"idle").is_empty(), "real-lib: idle resolves to a real clip.")
	# Idle 状态节点指向真 clip
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	_expect(idle_node != null, "real-lib: Idle node present in state machine.")
	if idle_node != null:
		_expect(idle_node.animation == "real/idle", "real-lib: Idle node must use 'real/idle', got '%s'." % idle_node.animation)
	# Walk 无真 clip → 程序化回退
	var walk_node := sm.get_node("Walk") as AnimationNodeAnimation
	if walk_node != null:
		_expect(walk_node.animation == "combat/walk", "real-lib: Walk must fall back to 'combat/walk'.")
	# root-motion 合约仍由程序化 Root 轨提供
	_expect(bridge.sample_light_root_delta() >= 0.5, "real-lib: light root delta preserved.")
	_expect(bridge.has_strafe_blendspace(), "real-lib: Strafe BlendSpace2D preserved.")
	# 状态切换不崩
	bridge.travel_locomotion(true, true, Vector2(0.5, 0.2))
	bridge.travel_locomotion(false, false)
	bridge.travel_light_attack()
	body.queue_free()


## 3) 真库只含整身根运动骨轨 → 剔除后 0 可用轨 → 真层关闭（程序化回退负例）。
func _test_root_only_clip_stays_fallback() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var skel := Skeleton3D.new()
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	body.add_child(skel)

	var lib := _make_root_only_library()
	var save_err := ResourceSaver.save(lib, TMP_ROOT_PATH)
	_expect(save_err == OK, "root-only: temp library save failed (err %d)." % save_err)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations(TMP_ROOT_PATH, skel)
	_expect(not ok, "root-only: configure must fail when only root-motion bone tracks exist.")
	_expect(not bridge.real_layer_active, "root-only: real layer must stay off.")
	# Idle 仍是程序化
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	if idle_node != null:
		_expect(idle_node.animation == "combat/idle", "root-only: Idle must stay 'combat/idle'.")
	_expect(bridge.sample_light_root_delta() >= 0.5, "root-only: procedural root delta preserved.")
	body.queue_free()


## 4) 真实 mannyquin 绑位姿：REAL_IDLE_FALLBACK 名字已对齐（下划线导入名），
##    但内容太薄（3 轨 0.04s）→ 被守卫 → 不驱动 idle，程序化回退。
func _test_mannyquin_bind_pose_guarded() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	skel.add_bone("DEF-thumb.01.R")
	skel.set_bone_rest(1, Transform3D.IDENTITY)
	body.add_child(skel)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations("res://resources/animations/mannyquin_lib.tres", skel)
	_expect(ok, "bind-pose: configure must succeed (lib loads + skeleton matches).")
	_expect(bridge.real_layer_active, "bind-pose: real layer injected (library present).")
	_expect(bool(bridge._real_library.has_animation(String(bridge.REAL_IDLE_FALLBACK))),
		"bind-pose: REAL_IDLE_FALLBACK must match imported lib key (underscore).")
	_expect(bridge.real_clip_for(&"idle").is_empty(),
		"bind-pose: bind-pose clip must NOT drive idle (guarded).")
	_expect(not bridge.has_real_animations(),
		"bind-pose: has_real_animations must be false (no state driven).")
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	if idle_node != null:
		_expect(idle_node.animation == "combat/idle",
			"bind-pose: Idle must stay 'combat/idle', got '%s'." % idle_node.animation)
	body.queue_free()


func _make_head_library() -> AnimationLibrary:
	var clip := Animation.new()
	clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var t := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(t, NodePath("Skeleton3D:DEF-head"))
	clip.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	clip.rotation_track_insert_key(t, 0.5, Quaternion(Vector3(0, 1, 0), 0.2))
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", clip)
	return lib


func _make_root_only_library() -> AnimationLibrary:
	var clip := Animation.new()
	clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var t := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(t, NodePath("Skeleton3D:root"))
	clip.position_track_insert_key(t, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(t, 0.5, Vector3(0, 0, -0.5))
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", clip)
	return lib


func _cleanup_tmp_files() -> void:
	DirAccess.remove_absolute(TMP_HEAD_PATH)
	DirAccess.remove_absolute(TMP_ROOT_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
