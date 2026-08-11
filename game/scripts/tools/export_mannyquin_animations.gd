extends SceneTree
## D-01 抽库工具：把 mannyquin.glb 导入场景里的 AnimationPlayer clip 导出为
## AnimationLibrary .tres（res://resources/animations/mannyquin_lib.tres）。
##
## 运行方式（headless）：
##   godot --headless --path <project> --script res://scripts/tools/export_mannyquin_animations.gd
##
## 健壮性：
##   - 源 GLB 缺失 / 加载失败 / 无 AnimationPlayer / 无动画 clip 均打印明确错误并 quit(1)；
##   - 成功打印 ASHEN_MANNYQUIN_ANIM_EXPORT_OK 并 quit(0)。
##
## 说明：mannyquin.glb 当前只带一条 rig/Layer0 绑位 clip（root+hips 的 2 帧），
## 导出后 clip 名保留原样（"Armature|mixamo.com|Layer0_godot_rig"）。注意 Godot GLB
## 导入会把 clip 名里的 "." 消毒为 "_"（导入后为 "Armature|mixamo_com|Layer0_godot_rig"）；
## bridge 的 REAL_IDLE_FALLBACK 用导入后名，且绑位姿（3 轨 0.04s）会被守卫不会驱动 idle。
## 未来作者化真 clip 直接用状态键命名（idle/walk/strafe_*）即精确匹配。

const SOURCE_PATH := "res://assets/models/player/mannyquin.glb"
const OUT_DIR := "res://resources/animations"
const OUT_PATH := "res://resources/animations/mannyquin_lib.tres"

const SUCCESS_MARKER := "ASHEN_MANNYQUIN_ANIM_EXPORT_OK"


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
	var errors: Array[String] = []
	if not ResourceLoader.exists(SOURCE_PATH):
		return ["export_mannyquin_animations: source missing: %s" % SOURCE_PATH]
	var scene := load(SOURCE_PATH) as PackedScene
	if scene == null:
		return ["export_mannyquin_animations: failed to load scene: %s" % SOURCE_PATH]
	var inst := scene.instantiate()
	if inst == null:
		return ["export_mannyquin_animations: failed to instantiate: %s" % SOURCE_PATH]

	var ap := _find_animation_player(inst)
	if ap == null:
		inst.free()
		return ["export_mannyquin_animations: no AnimationPlayer found under %s" % SOURCE_PATH]

	var lib := AnimationLibrary.new()
	var count := 0
	for lib_name in ap.get_animation_library_list():
		var src_lib := ap.get_animation_library(lib_name)
		if src_lib == null:
			continue
		for anim_name in src_lib.get_animation_list():
			var anim := src_lib.get_animation(anim_name)
			if anim == null:
				continue
			lib.add_animation(anim_name, anim.duplicate(true) as Animation)
			count += 1
	inst.free()

	if count == 0:
		return ["export_mannyquin_animations: AnimationPlayer found but it holds no animation clips."]

	var err := DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return ["export_mannyquin_animations: cannot create dir %s (err %d)" % [OUT_DIR, err]]
	var save_err := ResourceSaver.save(lib, OUT_PATH)
	if save_err != OK:
		return ["export_mannyquin_animations: save failed (err %d): %s" % [save_err, OUT_PATH]]

	print("export_mannyquin_animations: exported %d clip(s) -> %s" % [count, OUT_PATH])
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		print("  - %s (length %.3fs, tracks %d)" % [String(n), a.length, a.get_track_count()])
	return errors


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var hit := _find_animation_player(c)
		if hit != null:
			return hit
	return null
