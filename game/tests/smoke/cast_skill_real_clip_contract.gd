extends SceneTree
## Finding 2/4 回归：cast/skill 真 clip 解析路径（player_animation_bridge.gd）。
## 1) 真库注入后 travel_skill/travel_cast 解析到 "real/<clip>"（真库优先自动升级）。
## 2) 无匹配真 clip 的 stance 回退程序化 "combat/skill_pose" / "combat/cast"
##    （真层关闭与真层激活两种情形都要验证）。
## 3) 现有 API 不破坏：has_timing_method_tracks、combo/hitbox 信号经 anim_event_* 钩子触发。

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")
const SUCCESS_MARKER := "ASHEN_CAST_SKILL_REAL_CLIP_CONTRACTS_OK"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_procedural_fallback()
	_test_real_clip_upgrade()
	_test_forearm_pose_stamp()
	_test_existing_apis()
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## 裸 body 无真库：真层关闭，cast/skill 回退程序化 pose。
func _test_procedural_fallback() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.enabled, "fallback: bridge must enable on bare body.")
	_expect(not bridge.real_layer_active, "fallback: real layer must be off on bare body.")
	_expect(not bridge.has_real_animations(), "fallback: has_real_animations must be false.")

	bridge.travel_skill(&"curved_spin")
	if bridge._skill_node != null:
		_expect(bridge._skill_node.animation == "combat/skill_pose",
			"fallback: skill must use 'combat/skill_pose', got '%s'." % bridge._skill_node.animation)
	else:
		_expect(false, "fallback: _skill_node must exist after setup.")
	bridge.travel_cast(&"seal_burst")
	if bridge._cast_node != null:
		_expect(bridge._cast_node.animation == "combat/cast",
			"fallback: cast must use 'combat/cast', got '%s'." % bridge._cast_node.animation)
	else:
		_expect(false, "fallback: _cast_node must exist after setup.")
	body.queue_free()


## 裸 body 注入合成真库 + 激活真层：匹配 stance 升级到 "real/<clip>"；
## 未知 stance 即使真层激活也回退程序化。
func _test_real_clip_upgrade() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.enabled, "real-upgrade: bridge must enable on bare body.")

	# 注入合成真库（模拟资产管线提供 cast/skill clip），直接写桥的内部库。
	var lib := AnimationLibrary.new()
	lib.add_animation("hammer_slam", _trivial_anim())
	lib.add_animation("veil_bolt", _trivial_anim())
	lib.add_animation("sword_guard_stance", _trivial_anim())
	bridge._real_library = lib
	bridge.real_layer_active = true
	# AnimationTree 播放 "real/<clip>" 时需在 anim_player 上存在同名库才能解析。
	_install_real_library(bridge, lib)

	bridge.travel_skill(&"hammer_slam")
	if bridge._skill_node != null:
		_expect(bridge._skill_node.animation == "real/hammer_slam",
			"real-upgrade: skill must resolve to 'real/hammer_slam', got '%s'." % bridge._skill_node.animation)
	else:
		_expect(false, "real-upgrade: _skill_node must exist after setup.")
	bridge.travel_cast(&"veil_bolt")
	if bridge._cast_node != null:
		_expect(bridge._cast_node.animation == "real/veil_bolt",
			"real-upgrade: cast must resolve to 'real/veil_bolt', got '%s'." % bridge._cast_node.animation)
	else:
		_expect(false, "real-upgrade: _cast_node must exist after setup.")

	# 真层激活但无匹配 clip 的 stance 仍回退程序化。
	bridge.travel_skill(&"curved_spin")
	if bridge._skill_node != null:
		_expect(bridge._skill_node.animation == "combat/skill_pose",
			"real-upgrade: unknown skill stance must fall back, got '%s'." % bridge._skill_node.animation)
	bridge.travel_cast(&"seal_burst")
	if bridge._cast_node != null:
		_expect(bridge._cast_node.animation == "combat/cast",
			"real-upgrade: unknown cast stance must fall back, got '%s'." % bridge._cast_node.animation)
	body.queue_free()


## 真骨架存在时，cast/skill 程序化 pose 补种前臂抬起轨（_stamp_pose_arm_tracks），且幂等。
func _test_forearm_pose_stamp() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
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
	skel.add_bone("DEF-forearm.R")
	skel.set_bone_rest(1, Transform3D.IDENTITY)
	body_root.add_child(skel)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	# 库含一条可注入的臂骨轨，让 configure 成功并触发 _ingest_real_library 补种。
	var lib := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 0.4
	var rt := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(rt, NodePath("Skeleton3D:DEF-forearm.R"))
	clip.rotation_track_insert_key(rt, 0.0, Quaternion.IDENTITY)
	clip.rotation_track_insert_key(rt, 0.4, Quaternion(Vector3(0, 1, 0), 0.1))
	lib.add_animation("idle_extra", clip)

	var ok := bridge.configure_real_animations(lib, skel)
	_expect(ok, "forearm: configure_real_animations must succeed with matching skeleton.")
	_expect(bridge.real_layer_active, "forearm: real layer must activate.")

	var arm_path := NodePath("Visuals/BodyRoot/Skeleton3D:DEF-forearm.R")
	var cast_anim: Animation = bridge.anim_player.get_animation("combat/cast")
	_expect(cast_anim != null, "forearm: combat/cast clip must exist.")
	if cast_anim != null:
		var arm_track := -1
		for t in range(cast_anim.get_track_count()):
			if cast_anim.track_get_path(t) == arm_path:
				arm_track = t
		_expect(arm_track >= 0, "forearm: cast pose must carry a forearm raise track.")
		if arm_track >= 0:
			_expect(cast_anim.track_get_type(arm_track) == Animation.TYPE_ROTATION_3D,
				"forearm: forearm track must be rotation_3d.")

	# 幂等：再次 ingest 不应重复补种。
	var ok2 := bridge.configure_real_animations(lib, skel)
	_expect(ok2, "forearm: second configure must still succeed.")
	if cast_anim != null:
		var count := 0
		for t in range(cast_anim.get_track_count()):
			if cast_anim.track_get_path(t) == arm_path:
				count += 1
		_expect(count == 1, "forearm: pose stamp must be idempotent (got %d arm tracks)." % count)
	body.queue_free()


## 现有 API 回归：has_timing_method_tracks 为真，combo/hitbox 信号经 anim_event_* 钩子触发。
func _test_existing_apis() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.has_timing_method_tracks,
		"apis: light attack must stamp method tracks (has_timing_method_tracks true).")
	var hit_on := [false]
	var combo_on := [false]
	bridge.hitbox_activated.connect(func(): hit_on[0] = true)
	bridge.combo_window_opened.connect(func(): combo_on[0] = true)
	bridge.anim_event_hitbox_on()
	bridge.anim_event_combo_open()
	_expect(hit_on[0], "apis: hitbox_activated signal must fire via anim_event_hitbox_on.")
	_expect(combo_on[0], "apis: combo_window_opened signal must fire via anim_event_combo_open.")
	body.queue_free()


## 把合成库挂到 anim_player 的 "real" library，使 "real/<clip>" 可被 AnimationTree 解析。
func _install_real_library(bridge: Object, lib: AnimationLibrary) -> void:
	if bridge.anim_player == null:
		return
	if bridge.anim_player.has_animation_library("real"):
		bridge.anim_player.remove_animation_library("real")
	bridge.anim_player.add_animation_library("real", lib)


## 平凡 Animation：解析路径只关心 clip 是否存在于库中；内容给一条根位移轨即可。
func _trivial_anim() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_NONE
	var t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, NodePath("RootMotionSkeleton:Root"))
	anim.position_track_insert_key(t, 0.0, Vector3.ZERO)
	anim.position_track_insert_key(t, 0.4, Vector3(0, 0, -0.1))
	return anim


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
