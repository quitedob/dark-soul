extends SceneTree
## W2 真根运动 + 注入校验合约：
## 1) 结构：提交的 mannyquin_lib.tres 的 colossal_leap clip 含 RootMotionSkeleton:Root
##    position 轨（≥2 keys），净 z 位移为负（前向 -Z，游戏约定；源 OAL HeavyJumpAttack
##    Hips z 0.0034→-0.0397 即 -Z 前向，无需翻转）。
## 2) 注入校验负例（合成、确定性）：手造库含 (i) 存活 idle（DEF-head 旋转轨）+
##    (ii) remap 后 0 轨的 colossal_leap（仅非 DEF 骨轨）→ real_layer_active 为真、
##    Idle 节点 = real/idle、ColossalLeap 节点 = combat/colossal_leap，且状态机内
##    没有任何 AnimationNodeAnimation 指向缺失的 real/<clip>（修复 _real_clip_for
##    对"名存实亡"clip 的悬空解析）。
## 3) 合成根运动：手造 colossal_leap 带可用 RootMotionSkeleton:Root 前向根轨 →
##    注入后 consume_root_motion() 非零且前向(-Z)。
##
## 失败 push_error + quit(1)；成功打印 REAL_ROOT_MOTION_CONTRACTS_OK + quit(0)。

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")

const REAL_LIB_PATH := "res://resources/animations/mannyquin_lib.tres"
const LEAP_KEY := "colossal_leap"
const ROOT_TRACK := NodePath("RootMotionSkeleton:Root")

const SUCCESS_MARKER := "REAL_ROOT_MOTION_CONTRACTS_OK"

var _failures: Array[String] = []


## The bridge can evaluate combat method tracks while blending. A bare body
## lacks these callbacks and used to log deferred errors after the success marker.
class MotionProbeBody extends CharacterBody3D:
	var hitbox_events: Array[bool] = []
	var impulses: Array[float] = []

	func anim_event_hitbox_on() -> void:
		hitbox_events.append(true)

	func anim_event_hitbox_off() -> void:
		hitbox_events.append(false)

	func anim_event_push_forward(amount: float = 0.0) -> void:
		impulses.append(amount)


## 测试体要 add_child 节点并读取树内状态/根运动，必须延后到首帧 idle（同 L-19 deferred 模式）。
func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_committed_lib_leap_has_forward_root()
	_test_stripped_leap_falls_back_to_combat()
	_test_real_root_motion_drives_consume()
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## 1) 结构：提交库 colossal_leap 含 RootMotionSkeleton:Root position 轨，净 z 前向。
func _test_committed_lib_leap_has_forward_root() -> void:
	if not ResourceLoader.exists(REAL_LIB_PATH):
		_failures.append("committed lib: missing %s" % REAL_LIB_PATH)
		return
	var lib := load(REAL_LIB_PATH) as AnimationLibrary
	if lib == null:
		_failures.append("committed lib: failed to load %s" % REAL_LIB_PATH)
		return
	if not lib.has_animation(LEAP_KEY):
		_failures.append("committed lib: '%s' clip missing." % LEAP_KEY)
		return
	var clip := lib.get_animation(LEAP_KEY)
	var track := clip.find_track(ROOT_TRACK, Animation.TYPE_POSITION_3D)
	_expect(track >= 0, "committed lib: '%s' must carry %s position track." % [LEAP_KEY, ROOT_TRACK])
	if track < 0:
		return
	var kc := clip.track_get_key_count(track)
	_expect(kc >= 2, "committed lib: root track must have >=2 keys (got %d)." % kc)
	if kc < 2:
		return
	var first: Vector3 = clip.track_get_key_value(track, 0)
	var last: Vector3 = clip.track_get_key_value(track, kc - 1)
	var net_z := last.z - first.z
	_expect(net_z < 0.0, "committed lib: '%s' net z must be negative (forward -Z), got %.4f." % [LEAP_KEY, net_z])
	print("committed lib: %s root net z = %.4f (keys %d)" % [LEAP_KEY, net_z, kc])


## 2) 注入校验负例：被剔除的 colossal_leap 永不指向 real/<clip>。
func _test_stripped_leap_falls_back_to_combat() -> void:
	var body := MotionProbeBody.new()
	root.add_child(body)
	var skel := _make_def_skeleton()
	body.add_child(skel)

	var lib := _make_strip_library()
	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations(lib, skel)
	_expect(ok, "strip: configure_real_animations must succeed (idle survives).")
	_expect(bridge.real_layer_active, "strip: real layer must be active (idle injected).")
	_expect(bridge.has_real_animations(), "strip: has_real_animations must be true (idle resolves).")
	# 被剔除的 colossal_leap：不解析、不注入。
	_expect(bridge.real_clip_for(&"colossal_leap").is_empty(),
		"strip: stripped colossal_leap must not resolve to any real clip.")
	_expect(not bridge.real_root_motion_active(&"colossal_leap"),
		"strip: stripped colossal_leap must not report a real root track.")

	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	if sm != null:
		var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
		if idle_node != null:
			_expect(idle_node.animation == "real/idle",
				"strip: Idle must use 'real/idle', got '%s'." % idle_node.animation)
		var leap_node := sm.get_node("ColossalLeap") as AnimationNodeAnimation
		if leap_node != null:
			_expect(leap_node.animation == "combat/%s" % LEAP_KEY,
				"strip: ColossalLeap must fall back to 'combat/%s', got '%s'." % [LEAP_KEY, leap_node.animation])
	# 状态机内没有任何节点指向缺失的 real/<clip>。
	_expect(not _tree_points_at_missing_real(sm, bridge),
		"strip: no AnimationNodeAnimation may point at a missing real/<clip>.")

	body.queue_free()


## 3) 合成根运动：可用真根轨 → consume_root_motion 非零且前向。
func _test_real_root_motion_drives_consume() -> void:
	var body := MotionProbeBody.new()
	root.add_child(body)
	var skel := _make_def_skeleton()
	body.add_child(skel)

	var lib := _make_root_library()
	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations(lib, skel)
	_expect(ok, "root: configure_real_animations must succeed.")
	_expect(bridge.real_layer_active, "root: real layer must be active.")
	_expect(bridge.real_root_motion_active(&"colossal_leap"),
		"root: colossal_leap must carry a real RootMotionSkeleton:Root track.")
	_expect(bridge.real_root_motion_forward(&"colossal_leap") >= 0.5,
		"root: real forward displacement must be usable (>=0.5), got %.3f."
		% bridge.real_root_motion_forward(&"colossal_leap"))

	bridge.travel_leap(false)
	var total := Vector3.ZERO
	for i in 10:
		bridge.anim_tree.advance(0.05)
		total += bridge.consume_root_motion()
	_expect(total.z < -0.05,
		"root: consume_root_motion must be forward (-Z), got %s." % total)
	print("root: synthetic consume total = %s" % total)

	body.queue_free()


## 遍历状态机，收集所有 AnimationNodeAnimation；存在以 "real/" 开头但动画缺失的返回 true。
func _tree_points_at_missing_real(sm: AnimationNodeStateMachine, bridge) -> bool:
	var collected: Array[AnimationNodeAnimation] = []
	_collect_anim_nodes(sm, collected)
	for node in collected:
		var path: String = node.animation
		if path.begins_with("real/"):
			if bridge.anim_player == null or not bridge.anim_player.has_animation(path):
				return true
	return false


func _collect_anim_nodes(node: AnimationNode, out: Array[AnimationNodeAnimation]) -> void:
	if node is AnimationNodeAnimation:
		out.append(node as AnimationNodeAnimation)
		return
	if node is AnimationNodeStateMachine:
		for child_name in (node as AnimationNodeStateMachine).get_node_list():
			_collect_anim_nodes((node as AnimationNodeStateMachine).get_node(child_name), out)
	elif node is AnimationNodeBlendSpace2D:
		for i in (node as AnimationNodeBlendSpace2D).get_blend_point_count():
			var bp := (node as AnimationNodeBlendSpace2D).get_blend_point_node(i)
			_collect_anim_nodes(bp, out)


func _make_def_skeleton() -> Skeleton3D:
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	skel.add_bone("DEF-head")
	skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)))
	return skel


## 存活 idle（DEF-head 旋转）+ 被剔除 colossal_leap（仅非 DEF 骨轨）。
func _make_strip_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 0.5
	idle.loop_mode = Animation.LOOP_LINEAR
	var t := idle.add_track(Animation.TYPE_ROTATION_3D)
	idle.track_set_path(t, NodePath("Skeleton3D:DEF-head"))
	idle.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	idle.rotation_track_insert_key(t, 0.5, Quaternion(Vector3(0, 1, 0), 0.2))
	lib.add_animation("idle", idle)

	var leap := Animation.new()
	leap.length = 0.4
	var tr := leap.add_track(Animation.TYPE_ROTATION_3D)
	leap.track_set_path(tr, NodePath("Skeleton3D:NoSuchBone"))
	leap.rotation_track_insert_key(tr, 0.0, Quaternion.IDENTITY)
	leap.rotation_track_insert_key(tr, 0.4, Quaternion(Vector3(0, 1, 0), 0.1))
	lib.add_animation(LEAP_KEY, leap)
	return lib


## 存活 idle（DEF-head）+ 可用真根 colossal_leap（DEF-head + RootMotionSkeleton:Root 前向根轨）。
func _make_root_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 0.5
	idle.loop_mode = Animation.LOOP_LINEAR
	var t := idle.add_track(Animation.TYPE_ROTATION_3D)
	idle.track_set_path(t, NodePath("Skeleton3D:DEF-head"))
	idle.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	idle.rotation_track_insert_key(t, 0.5, Quaternion(Vector3(0, 1, 0), 0.2))
	lib.add_animation("idle", idle)

	var leap := Animation.new()
	leap.length = 0.3
	var hr := leap.add_track(Animation.TYPE_ROTATION_3D)
	leap.track_set_path(hr, NodePath("Skeleton3D:DEF-head"))
	leap.rotation_track_insert_key(hr, 0.0, Quaternion.IDENTITY)
	leap.rotation_track_insert_key(hr, 0.3, Quaternion(Vector3(0, 1, 0), 0.1))
	var rr := leap.add_track(Animation.TYPE_POSITION_3D)
	leap.track_set_path(rr, ROOT_TRACK)
	leap.position_track_insert_key(rr, 0.0, Vector3.ZERO)
	leap.position_track_insert_key(rr, 0.3, Vector3(0, 0, -0.8))
	lib.add_animation(LEAP_KEY, leap)
	return lib


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
