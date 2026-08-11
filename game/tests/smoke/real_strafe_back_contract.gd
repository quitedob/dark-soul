extends SceneTree
## D-01 真动画管线 Step 1 合约：mannyquin_lib.tres 已合并 minnyquinn "retreat" 真 clip
## 为状态键 "strafe_back"（保留绑位 fallback）。
##
## 1) (a) 库含 "strafe_back" clip；其轨道经 bridge._remap_real_clip 落到真 mannyquin
##    DEF 骨架后存活（track count > 0）——证明真 clip 能驱动后撤步身体动画。
## 2) (b) 裸 body + configure_real_animations(mannyquin_lib.tres, 真 DEF 骨架)：
##    _real_clip_for(&"strafe_back") == &"strafe_back" 且 has_real_animations() 为真。
## 3) (c) 绑位 fallback clip（Armature|mixamo_com|Layer0_godot_rig）仍存在于库中。
##
## 失败 push_error + quit(1)；成功打印 ASHEN_REAL_STRAFE_BACK_CONTRACTS_OK + quit(0)。

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")

const REAL_LIB_PATH := "res://resources/animations/mannyquin_lib.tres"
const BIND_FALLBACK := "Armature|mixamo_com|Layer0_godot_rig"
const MANNYQUIN_SKEL_PATH := "res://assets/models/player/mannyquin.glb"
const STRAFE_BACK := &"strafe_back"

const SUCCESS_MARKER := "ASHEN_REAL_STRAFE_BACK_CONTRACTS_OK"

var _failures: Array[String] = []


func _init() -> void:
	_test_committed_lib_has_both_clips()
	_test_strafe_back_drives_bridge_on_real_skel()
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## (c) + (a 前件)：提交的 mannyquin_lib.tres 同时含 strafe_back 与绑位 fallback。
func _test_committed_lib_has_both_clips() -> void:
	if not ResourceLoader.exists(REAL_LIB_PATH):
		_failures.append("committed lib: missing %s" % REAL_LIB_PATH)
		return
	var lib := load(REAL_LIB_PATH) as AnimationLibrary
	if lib == null:
		_failures.append("committed lib: failed to load %s" % REAL_LIB_PATH)
		return
	_expect(lib.has_animation(String(STRAFE_BACK)),
		"committed lib: must contain clip 'strafe_back'.")
	_expect(lib.has_animation(BIND_FALLBACK),
		"committed lib: bind-pose fallback clip must still be present.")
	if lib.has_animation(String(STRAFE_BACK)):
		var clip := lib.get_animation(String(STRAFE_BACK))
		_expect(clip != null, "committed lib: 'strafe_back' must be a valid Animation.")
		_expect(clip.length >= 0.9, "committed lib: 'strafe_back' must be the real 0.958s clip.")


## (a) + (b)：真 mannyquin DEF 骨架 + 裸 body → 真层驱动 strafe_back。
func _test_strafe_back_drives_bridge_on_real_skel() -> void:
	if not ResourceLoader.exists(MANNYQUIN_SKEL_PATH):
		_failures.append("bridge: mannyquin.glb missing for DEF skeleton: %s" % MANNYQUIN_SKEL_PATH)
		return
	var skel_scene := load(MANNYQUIN_SKEL_PATH) as PackedScene
	if skel_scene == null:
		_failures.append("bridge: failed to load %s" % MANNYQUIN_SKEL_PATH)
		return
	var skel_inst := skel_scene.instantiate()
	var skel := _first_skeleton(skel_inst)
	if skel == null:
		skel_inst.free()
		_failures.append("bridge: no Skeleton3D under mannyquin.glb.")
		return
	_expect(skel.find_bone("root") >= 0, "bridge: DEF skeleton must expose 'root' probe bone.")
	_expect(skel.find_bone("DEF-hips") >= 0, "bridge: DEF skeleton must expose DEF-* bones.")

	var body := CharacterBody3D.new()
	root.add_child(body)
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	body.add_child(visuals)
	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	visuals.add_child(body_root)
	# 把真 DEF 骨架从 GLB 的 godot_rig 下重挂到身体树（reparent 前先摘除旧父节点）。
	if skel.get_parent() != null:
		skel.get_parent().remove_child(skel)
	skel.owner = null  # 避免 owner('mannyquin') 与新父不一致的 warning
	body_root.add_child(skel)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations(REAL_LIB_PATH, skel)
	_expect(ok, "bridge: configure_real_animations(mannyquin_lib, real DEF skeleton) must succeed.")
	_expect(bridge.real_layer_active, "bridge: real layer must be active.")
	_expect(bridge._real_clip_for(STRAFE_BACK) == STRAFE_BACK,
		"bridge: _real_clip_for(&'strafe_back') must resolve to itself.")
	_expect(bridge.has_real_animations(), "bridge: has_real_animations() must be true.")

	# (a) 直接验证 _remap_real_clip：raw clip 落到真 DEF 骨架后 track count > 0。
	var raw: Animation = bridge._real_library.get_animation(String(STRAFE_BACK))
	_expect(raw != null, "bridge: raw lib must expose 'strafe_back'.")
	if raw != null:
		var skeleton_path: NodePath = body.get_path_to(skel)
		_expect(not skeleton_path.is_empty(),
			"bridge: skeleton must be reachable under the body (path %s)." % skeleton_path)
		var remapped := bridge._remap_real_clip(raw, skeleton_path)
		_expect(remapped != null and remapped.get_track_count() > 0,
			"bridge: _remap_real_clip must retain DEF tracks (track count > 0).")
		if remapped != null and remapped.get_track_count() > 0:
			var first_path := String(remapped.track_get_path(0))
			_expect(first_path.contains("Skeleton3D:DEF-"),
				"bridge: remapped track must point at a DEF bone, got '%s'." % first_path)

	# 注入后的 real/strafe_back 也必须携带已重映射轨道。
	var injected: Animation = bridge.anim_player.get_animation("real/strafe_back") as Animation
	_expect(injected != null and injected.get_track_count() > 0,
		"bridge: injected 'real/strafe_back' must carry remapped tracks.")
	if injected != null and injected.get_track_count() > 0:
		var inj_first := String(injected.track_get_path(0))
		_expect(inj_first.contains("Skeleton3D:DEF-"),
			"bridge: injected track must point at a DEF bone, got '%s'." % inj_first)

	# 状态切换不崩。
	bridge.travel_locomotion(true, true, Vector2(0.0, -1.0))
	body.queue_free()
	skel_inst.free()


func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var hit := _first_skeleton(c)
		if hit != null:
			return hit
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
