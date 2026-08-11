extends SceneTree
## D-01 真动画管线 Step 1 合库工具：把 minnyquinn.glb 的 "retreat" 真 locomotion clip
## （OAL "Retreat" 已重定向到玩家同款 58 骨 DEF-* 骨架的成品）合并进
## res://resources/animations/mannyquin_lib.tres，命名为状态键 "strafe_back"，
## 并**保留**现有绑位 clip（Armature|mixamo_com|Layer0_godot_rig）。
##
## 运行方式（headless）：
##   godot --headless --path <project> --script res://scripts/tools/export_minnyquinn_strafe_back.gd
##
## 幂等：重复运行不会产生重复 strafe_back（先移除旧键再写入），绑位 clip 恒保留。
##
## 健壮性：
##   - 源 GLB / 现有库缺失、无 AnimationPlayer、源 clip 缺失、保存失败均 push_error + quit(1)；
##   - 成功打印 ASHEN_MANNYQUIN_STRAFE_BACK_MERGE_OK 并 quit(0)。
##
## 说明：与 bridge 的 _remap_real_clip 一致，剔除整身根运动骨 root/Root 轨（根位移仍走
## RootMotionSkeleton 的 "Root" 轨），只保留可落到 DEF 骨架的骨骼姿态轨。

const SOURCE_PATH := "res://assets/models/enemy/minnyquinn.glb"
const SOURCE_CLIP := "retreat"
const DEST_CLIP := &"strafe_back"
const OUT_PATH := "res://resources/animations/mannyquin_lib.tres"

## 与 PlayerAnimationBridge.REAL_ROOT_MOTION_BONES 一致的整身根运动骨（剔除）。
const ROOT_MOTION_BONES := ["root", "Root"]

const SUCCESS_MARKER := "ASHEN_MANNYQUIN_STRAFE_BACK_MERGE_OK"


func _init() -> void:
	var errors := _run()
	if errors.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for e in errors:
		push_error(e)
	quit(1)


func _run() -> Array[String]:
	# 1) 现有库必须存在；保留其全部 clip。
	if not ResourceLoader.exists(OUT_PATH):
		return ["export_minnyquinn_strafe_back: existing library missing: %s" % OUT_PATH]
	var lib := load(OUT_PATH) as AnimationLibrary
	if lib == null:
		return ["export_minnyquinn_strafe_back: failed to load existing library: %s" % OUT_PATH]
	var preserved: Array[StringName] = lib.get_animation_list()

	# 2) 源 GLB 的 "retreat" clip。
	if not ResourceLoader.exists(SOURCE_PATH):
		return ["export_minnyquinn_strafe_back: source missing: %s" % SOURCE_PATH]
	var scene := load(SOURCE_PATH) as PackedScene
	if scene == null:
		return ["export_minnyquinn_strafe_back: failed to load scene: %s" % SOURCE_PATH]
	var inst := scene.instantiate()
	if inst == null:
		return ["export_minnyquinn_strafe_back: failed to instantiate: %s" % SOURCE_PATH]

	var ap := _find_animation_player(inst)
	if ap == null:
		inst.free()
		return ["export_minnyquinn_strafe_back: no AnimationPlayer under %s" % SOURCE_PATH]

	var retreat := _find_clip(ap, SOURCE_CLIP)
	if retreat == null:
		var available: Array[String] = _list_clips(ap)
		inst.free()
		return [
			"export_minnyquinn_strafe_back: clip '%s' not found in %s (available: %s)"
			% [SOURCE_CLIP, SOURCE_PATH, available]
		]

	var merged := retreat.duplicate(true) as Animation
	merged.resource_name = String(DEST_CLIP)
	_drop_root_motion_tracks(merged)
	inst.free()

	# 3) 幂等：移除旧 strafe_back 再写入新 clip；绑位 clip 不受影响。
	if lib.has_animation(String(DEST_CLIP)):
		lib.remove_animation(String(DEST_CLIP))
	var add_err := lib.add_animation(String(DEST_CLIP), merged)
	if add_err != OK:
		return ["export_minnyquinn_strafe_back: add_animation failed (err %d) for '%s'" % [add_err, DEST_CLIP]]

	# 4) 存回。
	var save_err := ResourceSaver.save(lib, OUT_PATH)
	if save_err != OK:
		return ["export_minnyquinn_strafe_back: save failed (err %d): %s" % [save_err, OUT_PATH]]

	print("export_minnyquinn_strafe_back: merged '%s' -> '%s' into %s" % [SOURCE_CLIP, DEST_CLIP, OUT_PATH])
	print("export_minnyquinn_strafe_back: preserved %d clip(s): %s" % [preserved.size(), preserved])
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		print("  - %s (length %.3fs, tracks %d)" % [String(n), a.length, a.get_track_count()])
	return []


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var hit := _find_animation_player(c)
		if hit != null:
			return hit
	return null


func _find_clip(ap: AnimationPlayer, name: String) -> Animation:
	for lib_name in ap.get_animation_library_list():
		var src_lib := ap.get_animation_library(lib_name)
		if src_lib == null:
			continue
		for anim_name in src_lib.get_animation_list():
			if String(anim_name) == name:
				var anim := src_lib.get_animation(anim_name)
				if anim != null:
					return anim.duplicate(true) as Animation
	return null


func _list_clips(ap: AnimationPlayer) -> Array[String]:
	var out: Array[String] = []
	for lib_name in ap.get_animation_library_list():
		var src_lib := ap.get_animation_library(lib_name)
		if src_lib == null:
			continue
		for anim_name in src_lib.get_animation_list():
			out.append(String(anim_name))
	return out


## 剔除整身根运动骨轨（root/Root），与 bridge _remap_real_clip 的 REAL_ROOT_MOTION_BONES 一致。
## 从后向前删除，避免索引漂移。
func _drop_root_motion_tracks(anim: Animation) -> void:
	for t in range(anim.get_track_count() - 1, -1, -1):
		var bone := _bone_from_track_path(anim.track_get_path(t))
		if bone in ROOT_MOTION_BONES:
			anim.remove_track(t)


## 从骨骼轨路径提取骨名："<node>:<bone>" → "<bone>"。
func _bone_from_track_path(p: NodePath) -> String:
	var s := String(p)
	var i := s.find(":")
	if i < 0:
		return ""
	return s.substr(i + 1)
