extends SceneTree
## D-01 真动画管线 Step 2 合约：OAL 批量重定向 clip 已合并进 mannyquin_lib.tres。
##
## 断言：
## 1) (a) 库同时含状态键 clip（idle/walk/strafe_*/sword_light_1）与绑位 fallback +
##    strafe_back；且每个状态键 clip 的轨道经 bridge._remap_real_clip 落到真 mannyquin
##    DEF 骨架后存活（track count > 0）——证明真 clip 能驱动对应状态。
## 2) (b) 裸 body + configure_real_animations(mannyquin_lib.tres, 真 DEF 骨架)：
##    real_layer_active 为真，has_real_animations() 为真，且每个状态键
##    _real_clip_for(key) 解析到自身（精确同名）。
##
## 失败 push_error + quit(1)；成功打印 ASHEN_REAL_OAL_RETARGET_CONTRACTS_OK + quit(0)。

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")

const REAL_LIB_PATH := "res://resources/animations/mannyquin_lib.tres"
const BIND_FALLBACK := "Armature|mixamo_com|Layer0_godot_rig"
const MANNYQUIN_SKEL_PATH := "res://assets/models/player/mannyquin.glb"

## 本批次重定向的状态键（与 retarget_oal_to_mannyquin.gd 的 STATE_KEY_MAP 一致，
## W1 扩展至 19 键）。
const BATCH_KEYS: Array[StringName] = [
	&"idle", &"walk",
	&"strafe_fwd", &"strafe_back", &"strafe_left", &"strafe_right",
	&"sword_light_1",
	&"colossal_leap", &"riposte", &"backstab",
	&"greatsword_leap", &"hammer_slam", &"ultra_slam",
	&"spear_charge_stance", &"sword_guard_stance", &"shield_counter_stance",
	&"fist_deflect_stance", &"curved_spin", &"dagger_backstep_stance",
]

const SUCCESS_MARKER := "ASHEN_REAL_OAL_RETARGET_CONTRACTS_OK"

var _failures: Array[String] = []


func _init() -> void:
	_test_committed_lib_has_batch_and_preserved()
	_test_batch_drives_bridge_on_real_skel()
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## (a 前件)：提交的 mannyquin_lib.tres 含全部批次状态键 clip + 绑位 fallback。
func _test_committed_lib_has_batch_and_preserved() -> void:
	if not ResourceLoader.exists(REAL_LIB_PATH):
		_failures.append("committed lib: missing %s" % REAL_LIB_PATH)
		return
	var lib := load(REAL_LIB_PATH) as AnimationLibrary
	if lib == null:
		_failures.append("committed lib: failed to load %s" % REAL_LIB_PATH)
		return
	_expect(lib.has_animation(BIND_FALLBACK),
		"committed lib: bind-pose fallback clip must still be present.")
	_expect(lib.has_animation(String(&"strafe_back")),
		"committed lib: strafe_back clip must still be present.")
	for key in BATCH_KEYS:
		_expect(lib.has_animation(String(key)),
			"committed lib: batch state-key clip '%s' missing." % key)
		if lib.has_animation(String(key)):
			var clip := lib.get_animation(String(key))
			_expect(clip != null, "committed lib: '%s' must be a valid Animation." % key)
			_expect(clip.get_track_count() >= 4,
				"committed lib: '%s' must carry >=4 tracks (got %d)." % [key, clip.get_track_count()])


## (a) + (b)：真 mannyquin DEF 骨架 + 裸 body → 真层驱动全部批次状态键。
func _test_batch_drives_bridge_on_real_skel() -> void:
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
	skel.owner = null
	body_root.add_child(skel)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations(REAL_LIB_PATH, skel)
	_expect(ok, "bridge: configure_real_animations(mannyquin_lib, real DEF skeleton) must succeed.")
	_expect(bridge.real_layer_active, "bridge: real layer must be active.")
	_expect(bridge.has_real_animations(), "bridge: has_real_animations() must be true.")

	# 每个批次状态键：_real_clip_for 精确解析 + raw clip 落到 DEF 骨架后 track > 0。
	var skeleton_path: NodePath = body.get_path_to(skel)
	for key in BATCH_KEYS:
		var resolved := bridge._real_clip_for(key)
		_expect(resolved == key,
			"bridge: _real_clip_for(&'%s') must resolve to itself (got '%s')." % [key, resolved])
		var raw: Animation = bridge._real_library.get_animation(String(key))
		_expect(raw != null, "bridge: raw lib must expose '%s'." % key)
		if raw != null:
			var remapped := bridge._remap_real_clip(raw, skeleton_path, key)
			_expect(remapped != null and remapped.get_track_count() > 0,
				"bridge: _remap_real_clip must retain DEF tracks for '%s' (tracks>0)." % key)
		var injected: Animation = bridge.anim_player.get_animation("real/%s" % key) as Animation
		_expect(injected != null and injected.get_track_count() > 0,
			"bridge: injected 'real/%s' must carry remapped tracks." % key)

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
