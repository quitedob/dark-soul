extends SceneTree
## D-01 真动画管线 Step 2 批量重定向合库工具：把 OAL（OpenAnimationLibraries）库的
## SkeletonProfileHumanoid 命名 clip 重定向到 mannyquin 58 骨 DEF-* 骨架，按桥的状态键命名，
## 合并进 res://resources/animations/mannyquin_lib.tres（**保留**绑位 clip + strafe_back）。
##
## 运行方式（headless）：
##   godot --headless --path <project> --script res://scripts/tools/retarget_oal_to_mannyquin.gd
##
## 幂等：重复运行替换同名状态键 clip，绝不重复；绑位 clip + 已存在的状态键 clip 恒保留。
##
## 重定向方法（经 minnyquinn.glb "retreat" 真值校验，≤0.06° 误差）：
##   采用 Godot 4 RetargetModifier3D 的 local 模式公式（含 rest-pose 补偿）：
##     tgt_pose.basis = tgt_parent_global_rest.basis.inv
##                     * src_parent_global_rest.basis
##                     * src_pose.basis
##                     * src_rest.basis.inv
##                     * tgt_parent_global_rest.basis
##                     * tgt_rest.basis
##   源骨架 = SkeletonProfileHumanoid 参考 pose（OAL clip 即按此命名/姿态）；
##   目标骨架 = mannyquin.glb 的 DEF 骨架（rest 用 GLB 导入值）。
##   直接改骨名（name remap）在四肢旋转上偏差 66-180°，必须走该 bake 路径。
##
## 剔除规则（与桥 _remap_real_clip 一致 + 状态键契约）：
##   - 整身根运动骨 root/Root 全部剔除（根位移/旋转仍走 RootMotionSkeleton 的 Root 轨）；
##   - Hips/Root 上的 position_3d 根运动轨剔除（游戏从自己的 RootMotionSkeleton Root 轨取根运动）；
##   - Weapon / Shield / DEF-breast.L/R 残留轨剔除（目标骨架无 Weapon/Shield；breast 按规范剔除）；
##   - 未映射骨剔除（防御性）。
##
## 健壮性：OAL 库 / 现有库缺失、clip 缺失、目标骨缺失、bake 后 track 数为 0、保存失败
## 均 push_error + quit(1)；成功打印 ASHEN_OAL_RETARGET_MERGE_OK + quit(0)。

const OUT_PATH := "res://resources/animations/mannyquin_lib.tres"
const MANNYQUIN_SKEL_PATH := "res://assets/models/player/mannyquin.glb"
const GROUND_TRUTH_PATH := "res://assets/models/enemy/minnyquinn.glb"
const GROUND_TRUTH_CLIP := "retreat"

const SUCCESS_MARKER := "ASHEN_OAL_RETARGET_MERGE_OK"
## 真值校验：Retreat -> strafe_back 与 minnyquinn "retreat" 比对的代表性骨。
const VALIDATION_BONES := ["DEF-hips", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L", "DEF-thigh.L"]
const VALIDATION_TOLERANCE_DEG := 1.0

## 状态键 -> (OAL 库文件名, OAL clip 名)。
## 所有 clip 名均已 headless 枚举确认存在（MeleeLib 121 / ShooterLib 180）。
const STATE_KEY_MAP := {
	&"idle": ["ShooterLib.res", "idle"],
	&"walk": ["MeleeLib.res", "LightWalking"],
	&"strafe_fwd": ["MeleeLib.res", "LightStrafe45L"],
	&"strafe_back": ["MeleeLib.res", "Retreat"],  # GROUND TRUTH clip
	&"strafe_left": ["MeleeLib.res", "LightStrafeL"],
	&"strafe_right": ["MeleeLib.res", "LightStrafeR"],
	&"sword_light_1": ["MeleeLib.res", "Slash1"],
}

## SkeletonProfileHumanoid -> DEF 骨名映射（58 骨 DEF 骨架）。
const BONE_MAP := {
	"Root": "root",
	"Hips": "DEF-hips",
	"Spine": "DEF-spine.001",
	"Chest": "DEF-spine.002",
	"UpperChest": "DEF-spine.003",
	"Neck": "DEF-neck",
	"Head": "DEF-head",
	"Jaw": "DEF-jaw",
	"LeftEye": "DEF-eye.L",
	"RightEye": "DEF-eye.R",
	"LeftShoulder": "DEF-shoulder.L",
	"RightShoulder": "DEF-shoulder.R",
	"LeftUpperArm": "DEF-upper_arm.L",
	"RightUpperArm": "DEF-upper_arm.R",
	"LeftLowerArm": "DEF-forearm.L",
	"RightLowerArm": "DEF-forearm.R",
	"LeftHand": "DEF-hand.L",
	"RightHand": "DEF-hand.R",
	"LeftThumbMetacarpal": "DEF-thumb.01.L",
	"LeftThumbProximal": "DEF-thumb.02.L",
	"LeftThumbDistal": "DEF-thumb.03.L",
	"RightThumbMetacarpal": "DEF-thumb.01.R",
	"RightThumbProximal": "DEF-thumb.02.R",
	"RightThumbDistal": "DEF-thumb.03.R",
	"LeftIndexProximal": "DEF-f_index.01.L",
	"LeftIndexIntermediate": "DEF-f_index.02.L",
	"LeftIndexDistal": "DEF-f_index.03.L",
	"LeftMiddleProximal": "DEF-f_middle.01.L",
	"LeftMiddleIntermediate": "DEF-f_middle.02.L",
	"LeftMiddleDistal": "DEF-f_middle.03.L",
	"LeftRingProximal": "DEF-f_ring.01.L",
	"LeftRingIntermediate": "DEF-f_ring.02.L",
	"LeftRingDistal": "DEF-f_ring.03.L",
	"LeftLittleProximal": "DEF-f_pinky.01.L",
	"LeftLittleIntermediate": "DEF-f_pinky.02.L",
	"LeftLittleDistal": "DEF-f_pinky.03.L",
	"RightIndexProximal": "DEF-f_index.01.R",
	"RightIndexIntermediate": "DEF-f_index.02.R",
	"RightIndexDistal": "DEF-f_index.03.R",
	"RightMiddleProximal": "DEF-f_middle.01.R",
	"RightMiddleIntermediate": "DEF-f_middle.02.R",
	"RightMiddleDistal": "DEF-f_middle.03.R",
	"RightRingProximal": "DEF-f_ring.01.R",
	"RightRingIntermediate": "DEF-f_ring.02.R",
	"RightRingDistal": "DEF-f_ring.03.R",
	"RightLittleProximal": "DEF-f_pinky.01.R",
	"RightLittleIntermediate": "DEF-f_pinky.02.R",
	"RightLittleDistal": "DEF-f_pinky.03.R",
	"LeftUpperLeg": "DEF-thigh.L",
	"RightUpperLeg": "DEF-thigh.R",
	"LeftLowerLeg": "DEF-shin.L",
	"RightLowerLeg": "DEF-shin.R",
	"LeftFoot": "DEF-foot.L",
	"RightFoot": "DEF-foot.R",
	"LeftToes": "DEF-toe.L",
	"RightToes": "DEF-toe.R",
}

## 整身根运动骨（剔除）与根运动 position 源骨（Hips/Root 上的 position_3d 轨剔除）。
const ROOT_MOTION_BONES := ["root", "Root"]
const ROOT_MOTION_POS_BONES := ["Hips", "Root", "root"]
## 目标骨架不存在的残留骨（剔除）。
const DROP_EXTRA_BONES := ["Weapon", "Shield", "DEF-breast.L", "DEF-breast.R"]


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
	var oal_dir := _oal_dir()
	if oal_dir.is_empty():
		return ["retarget_oal: cannot locate OAL Libraries dir relative to project root."]

	# 1) 目标骨架（mannyquin DEF 58 骨）rest/层级。
	var target := _build_target_skeleton()
	if target.is_empty():
		return ["retarget_oal: failed to build mannyquin target skeleton (missing %s)." % MANNYQUIN_SKEL_PATH]

	# 2) 源骨架（SkeletonProfileHumanoid 参考 pose）。
	var source := _build_source_skeleton()
	if source.is_empty():
		return ["retarget_oal: failed to build SkeletonProfileHumanoid source skeleton."]

	# 3) 现有库必须存在；保留其全部 clip（merge 后逐个替换/新增）。
	if not ResourceLoader.exists(OUT_PATH):
		return ["retarget_oal: existing library missing: %s" % OUT_PATH]
	var lib := load(OUT_PATH) as AnimationLibrary
	if lib == null:
		return ["retarget_oal: failed to load existing library: %s" % OUT_PATH]
	var preserved: Array[StringName] = lib.get_animation_list()

	# 4) 先跑真值校验 gate（Retreat -> strafe_back vs minnyquinn "retreat"）。
	var gt_errors := _validate_ground_truth(oal_dir, source, target)
	if not gt_errors.is_empty():
		return gt_errors

	# 5) 批量 bake。
	var loaded_libs := {}
	var bake_errors: Array[String] = []
	for key in STATE_KEY_MAP.keys():
		var entry: Array = STATE_KEY_MAP[key]
		var lib_name: String = entry[0]
		var clip_name: String = entry[1]
		if not loaded_libs.has(lib_name):
			var lib_path := oal_dir.path_join(lib_name)
			if not FileAccess.file_exists(lib_path):
				bake_errors.append("retarget_oal: OAL library missing: %s" % lib_path)
				continue
			var oal_lib := load(lib_path) as AnimationLibrary
			if oal_lib == null:
				bake_errors.append("retarget_oal: failed to load OAL library: %s" % lib_path)
				continue
			loaded_libs[lib_name] = oal_lib
		var oal_lib: AnimationLibrary = loaded_libs[lib_name]
		if not oal_lib.has_animation(clip_name):
			bake_errors.append("retarget_oal: clip '%s' not found in %s (key %s)." % [clip_name, lib_name, key])
			continue
		var baked := _bake_clip(oal_lib.get_animation(clip_name), String(key), source, target)
		if baked == null:
			bake_errors.append("retarget_oal: bake failed for '%s' -> '%s' (produced no tracks)." % [clip_name, key])
			continue
		# 幂等：移除旧同名 clip 再写入。
		if lib.has_animation(String(key)):
			lib.remove_animation(String(key))
		var add_err := lib.add_animation(String(key), baked)
		if add_err != OK:
			bake_errors.append("retarget_oal: add_animation failed (err %d) for '%s'." % [add_err, key])

	if not bake_errors.is_empty():
		return bake_errors

	# 6) 存回。
	var save_err := ResourceSaver.save(lib, OUT_PATH)
	if save_err != OK:
		return ["retarget_oal: save failed (err %d): %s" % [save_err, OUT_PATH]]

	print("retarget_oal: merged %d state-key clip(s) into %s" % [STATE_KEY_MAP.size(), OUT_PATH])
	print("retarget_oal: preserved %d existing clip(s): %s" % [preserved.size(), preserved])
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		print("  - %s (length %.3fs, tracks %d)" % [String(n), a.length, a.get_track_count()])
	return []


## 真值校验 gate：OAL "Retreat" 经同一 bake 公式 -> DEF，与 minnyquinn "retreat" 逐骨比对。
## 比对共享骨的旋转 key 值，代表骨（VALIDATION_BONES）须 ≤ 1°，任何共享骨 ≤ 2°。
func _validate_ground_truth(oal_dir: String, source: Dictionary, target: Dictionary) -> Array[String]:
	var melee_path := oal_dir.path_join("MeleeLib.res")
	if not FileAccess.file_exists(melee_path):
		return ["retarget_oal: MeleeLib.res missing for ground-truth validation: %s" % melee_path]
	var melee := load(melee_path) as AnimationLibrary
	if melee == null:
		return ["retarget_oal: failed to load MeleeLib.res for validation."]
	if not melee.has_animation("Retreat"):
		return ["retarget_oal: MeleeLib 'Retreat' missing for validation."]
	var baked := _bake_clip(melee.get_animation("Retreat"), "strafe_back", source, target)
	if baked == null:
		return ["retarget_oal: ground-truth bake produced no tracks."]
	if not ResourceLoader.exists(GROUND_TRUTH_PATH):
		return ["retarget_oal: ground-truth source missing: %s" % GROUND_TRUTH_PATH]
	var scene := load(GROUND_TRUTH_PATH) as PackedScene
	if scene == null:
		return ["retarget_oal: failed to load ground truth %s" % GROUND_TRUTH_PATH]
	var inst := scene.instantiate()
	var ap := _find_animation_player(inst)
	var gt := _find_clip(ap, GROUND_TRUTH_CLIP)
	inst.free()
	if gt == null:
		return ["retarget_oal: ground-truth clip '%s' not found." % GROUND_TRUTH_CLIP]

	var baked_map := _rot_by_bone(baked)
	var gt_map := _rot_by_bone(gt)
	var report: Array[String] = []
	var failures := 0
	var shared := 0
	for bone in gt_map.keys():
		if not baked_map.has(bone):
			continue
		shared += 1
		var qb: Array = baked_map[bone]
		var qg: Array = gt_map[bone]
		var n := mini(qb.size(), qg.size())
		if n == 0:
			continue
		var worst := 0.0
		for i in range(n):
			var ang := _quat_angle(qb[i], qg[i])
			if ang > worst:
				worst = ang
		var worst_deg := rad_to_deg(worst)
		var limit := VALIDATION_TOLERANCE_DEG
		if not bone in VALIDATION_BONES:
			limit = 2.0
		if worst_deg > limit:
			failures += 1
			report.append("  GT MISMATCH %s worst=%.3f deg" % [bone, worst_deg])
		else:
			report.append("  %s OK worst=%.3f deg" % [bone, worst_deg])
	print("retarget_oal: ground-truth validation (%d shared bones, %s):" % [shared, GROUND_TRUTH_CLIP])
	for r in report:
		print(r)
	if failures > 0:
		return ["retarget_oal: ground-truth validation FAILED: %d bone(s) exceed tolerance." % failures]
	return []


## 单 clip bake：按 RetargetModifier3D local 公式重映射旋转/缩放，剔除根运动与残留骨。
func _bake_clip(src: Animation, name: String, source: Dictionary, target: Dictionary) -> Animation:
	var out := Animation.new()
	out.length = src.length
	out.loop_mode = src.loop_mode
	out.resource_name = name
	var added := {}
	for t in range(src.get_track_count()):
		var tpath := String(src.track_get_path(t))
		var bone := _bone_from_track_path(tpath)
		var ttype := src.track_get_type(t)
		if bone.is_empty():
			continue
		if bone in ROOT_MOTION_BONES or bone in DROP_EXTRA_BONES:
			continue
		if not BONE_MAP.has(bone):
			continue  # 未映射骨（防御）
		var def_bone: String = BONE_MAP[bone]
		if not (target["rest"] as Dictionary).has(def_bone):
			continue  # 目标骨架无此骨
		# 根运动 position 轨（Hips/Root/root 上的 position_3d）剔除。
		if ttype == Animation.TYPE_POSITION_3D and bone in ROOT_MOTION_POS_BONES:
			continue
		var key := "%s|%d" % [def_bone, ttype]
		var nt: int
		if added.has(key):
			nt = added[key]
		else:
			nt = out.add_track(ttype)
			out.track_set_path(nt, NodePath("godot_rig/Skeleton3D:%s" % def_bone))
			out.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
			added[key] = nt
		for k in range(src.track_get_key_count(t)):
			var val: Variant = src.track_get_key_value(t, k)
			if ttype == Animation.TYPE_ROTATION_3D:
				val = _retarget_basis(bone, def_bone, val, source, target)
			elif ttype == Animation.TYPE_SCALE_3D:
				val = _retarget_scale(bone, def_bone, val, source, target)
			# position_3d 仅剩非根骨（理论上 OAL 无），直接复制；缩放/旋转已重映射。
			out.track_insert_key(nt, src.track_get_key_time(t, k), val)
	if out.get_track_count() < 1:
		return null
	return out


## RetargetModifier3D local 模式 basis 公式（rest-pose 补偿）。
func _retarget_basis(pbone: String, dbone: String, src_q: Quaternion, source: Dictionary, target: Dictionary) -> Quaternion:
	var sp: Basis = source["parent_grest"].get(pbone, Basis.IDENTITY)
	var tp: Basis = target["parent_grest"].get(dbone, Basis.IDENTITY)
	var sr: Basis = source["rest"].get(pbone, Basis.IDENTITY)
	var tr: Basis = target["rest"].get(dbone, Basis.IDENTITY)
	var pre: Basis = tp.inverse() * sp
	var post: Basis = sr.inverse() * sp.inverse() * tp * tr
	return (pre * Basis(src_q) * post).get_rotation_quaternion()


## 缩放按同一 pre/post 基旋转（与 rotation 一致地重映射；OAL 缩放接近 1，影响微小）。
func _retarget_scale(pbone: String, dbone: String, src_s: Vector3, source: Dictionary, target: Dictionary) -> Vector3:
	var sp: Basis = source["parent_grest"].get(pbone, Basis.IDENTITY)
	var tp: Basis = target["parent_grest"].get(dbone, Basis.IDENTITY)
	var sr: Basis = source["rest"].get(pbone, Basis.IDENTITY)
	var tr: Basis = target["rest"].get(dbone, Basis.IDENTITY)
	var pre: Basis = tp.inverse() * sp
	var post: Basis = sr.inverse() * sp.inverse() * tp * tr
	return (pre * Basis.from_scale(src_s) * post).get_scale()


## 源骨架：SkeletonProfileHumanoid 参考 pose 的 rest + 父链 global rest。
func _build_source_skeleton() -> Dictionary:
	var profile := SkeletonProfileHumanoid.new()
	var bone_size: int = profile.get("bone_size")
	var skel := Skeleton3D.new()
	var idx := {}
	for i in range(bone_size):
		var name := String(profile.get_bone_name(i)).strip_edges()
		idx[name] = skel.get_bone_count()
		skel.add_bone(name)
		var rp: Transform3D = profile.get_reference_pose(i)
		skel.set_bone_rest(i, rp)
		var parent := String(profile.get_bone_parent(i)).strip_edges()
		if parent != "" and idx.has(parent):
			skel.set_bone_parent(i, idx[parent])
	var rest := {}
	var pgrest := {}
	for i in range(skel.get_bone_count()):
		var name: String = skel.get_bone_name(i)
		rest[name] = skel.get_bone_rest(i).basis
		var pi := skel.get_bone_parent(i)
		pgrest[name] = skel.get_bone_global_rest(pi if pi >= 0 else -1).basis if pi >= 0 else Basis.IDENTITY
	skel.free()
	return {"rest": rest, "parent_grest": pgrest}


## 目标骨架：mannyquin.glb DEF 骨架的 rest + 父链 global rest。
func _build_target_skeleton() -> Dictionary:
	if not ResourceLoader.exists(MANNYQUIN_SKEL_PATH):
		return {}
	var scene := load(MANNYQUIN_SKEL_PATH) as PackedScene
	if scene == null:
		return {}
	var inst := scene.instantiate()
	var skel := _first_skeleton(inst)
	if skel == null:
		inst.free()
		return {}
	var rest := {}
	var pgrest := {}
	for i in range(skel.get_bone_count()):
		var name: String = skel.get_bone_name(i)
		rest[name] = skel.get_bone_rest(i).basis
		var pi := skel.get_bone_parent(i)
		pgrest[name] = skel.get_bone_global_rest(pi if pi >= 0 else -1).basis if pi >= 0 else Basis.IDENTITY
	inst.free()
	return {"rest": rest, "parent_grest": pgrest}


## 定位 OAL Libraries 目录：res:// 上一级（仓库根）下的 example/Godot4-OpenAnimationLibraries/Libraries/Humanoid。
func _oal_dir() -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	# globalize 返回带尾部 "/"，先去掉再取仓库根（res:// 上一级）。
	var trimmed := project_dir.trim_suffix("/")
	var repo_root := trimmed.get_base_dir()
	var cand := repo_root.path_join("example/Godot4-OpenAnimationLibraries/Libraries/Humanoid")
	if DirAccess.dir_exists_absolute(cand):
		return cand
	return ""


func _rot_by_bone(anim: Animation) -> Dictionary:
	var out := {}
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := _bone_from_track_path(String(anim.track_get_path(t)))
		var vals: Array = []
		for k in range(anim.track_get_key_count(t)):
			vals.append(anim.track_get_key_value(t, k))
		out[bone] = vals
	return out


func _quat_angle(qa: Quaternion, qb: Quaternion) -> float:
	var d := absf(qa.dot(qb))
	d = clampf(d, -1.0, 1.0)
	return 2.0 * acos(d)


func _bone_from_track_path(p: String) -> String:
	var i := p.find(":")
	if i < 0:
		return ""
	return p.substr(i + 1)


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


func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var hit := _first_skeleton(c)
		if hit != null:
			return hit
	return null
