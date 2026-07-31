extends Node
## G-04：Boss 相变抛光编排——过渡动画混合 / 镜头焦点 / 场地 VFX

signal transition_started(enemy, phase: int)
signal transition_finished(enemy, phase: int)

const PhaseFocusProfileScript = preload("res://scripts/camera/phase_focus_profile.gd")
const ArenaPhaseVfxScript = preload("res://scripts/fx/arena_phase_vfx.gd")

var camera_director = null
var arena_vfx = null  # ArenaPhaseVfx 实例（preload 构造，避免 class_name 时序）
var reduced_motion := false
var _active_anchor: Node3D = null
var _blend_tween: Tween = null


func setup(director = null) -> void:
	camera_director = director
	if arena_vfx == null:
		arena_vfx = ArenaPhaseVfxScript.new()
		arena_vfx.name = "ArenaPhaseVfx"
		add_child(arena_vfx)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


## 入口：在 Boss 进入新阶段时播放完整抛光序列
func play_transition(enemy: Node3D, new_phase: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if new_phase < 2:
		return
	transition_started.emit(enemy, new_phase)
	_play_camera_focus(enemy, new_phase)
	_play_arena_vfx(enemy, new_phase)
	_blend_transition_pose(enemy, new_phase)
	# 动画混合时长后发出完成信号
	var duration := 1.55 if new_phase < 3 else 1.85
	if reduced_motion:
		duration *= 0.55
	var tree := get_tree()
	if tree != null:
		tree.create_timer(duration).timeout.connect(func():
			if is_instance_valid(enemy):
				transition_finished.emit(enemy, new_phase)
			_clear_focus_anchor()
		)


func _play_camera_focus(enemy: Node3D, new_phase: int) -> void:
	if camera_director == null or not camera_director.has_method("play_shot"):
		return
	var profile = PhaseFocusProfileScript.shot_for_phase(new_phase)
	if profile == null:
		return
	if reduced_motion:
		profile.trauma = minf(float(profile.trauma), 0.12)
		profile.duration = minf(float(profile.duration), 0.9)
	_clear_focus_anchor()
	# 临时注视锚点：实现胸口焦点偏移，不改动 CombatCameraDirector 核心
	var anchor := Node3D.new()
	anchor.name = "PhaseFocusAnchor"
	var offset: Vector3 = PhaseFocusProfileScript.focus_offset_for_phase(new_phase)
	var base: Vector3 = enemy.global_position if enemy.is_inside_tree() else enemy.position
	if enemy.has_method("get_target_point") and enemy.is_inside_tree():
		base = enemy.get_target_point()
		offset = Vector3(0.0, maxf(offset.y - 1.4, 0.35), 0.0)
	add_child(anchor)
	if anchor.is_inside_tree():
		anchor.global_position = base + offset
	else:
		anchor.position = base + offset
	_active_anchor = anchor
	camera_director.play_shot(profile, anchor)


func _play_arena_vfx(enemy: Node3D, new_phase: int) -> void:
	if arena_vfx == null:
		return
	var vfx_key := _resolve_phase_vfx_key(enemy, new_phase)
	var parent: Node = get_parent() if get_parent() != null else self
	var origin: Vector3 = enemy.global_position if enemy.is_inside_tree() else enemy.position
	arena_vfx.play_at(origin, new_phase, vfx_key, parent)


func _blend_transition_pose(enemy: Node3D, new_phase: int) -> void:
	# 程序化姿态混合：缩放脉动 + 武器抬升 + 发光渐变（无 2D / 无整文件替换）
	if not ("visual_root" in enemy) or enemy.visual_root == null:
		return
	var visual: Node3D = enemy.visual_root
	var base_scale: Vector3 = visual.scale
	if base_scale.length_squared() < 0.01:
		base_scale = Vector3.ONE * (1.22 if bool(enemy.get("guardian")) else 1.0)
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.kill()
	var peak := 1.12 if new_phase < 3 else 1.22
	var lean := -0.18 if new_phase < 3 else -0.28
	var blend_in := 0.28 if not reduced_motion else 0.12
	var blend_out := 0.45 if not reduced_motion else 0.2
	_blend_tween = create_tween()
	_blend_tween.set_parallel(false)
	_blend_tween.tween_property(visual, "scale", base_scale * peak, blend_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_blend_tween.parallel().tween_property(visual, "rotation:x", lean, blend_in)
	if "weapon_pivot" in enemy and enemy.weapon_pivot != null:
		_blend_tween.parallel().tween_property(enemy.weapon_pivot, "rotation:z", -1.45 if new_phase >= 3 else -1.15, blend_in)
	_ramp_emission(enemy, new_phase, blend_in)
	_blend_tween.tween_property(visual, "scale", base_scale, blend_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_blend_tween.parallel().tween_property(visual, "rotation:x", 0.0, blend_out)
	if "weapon_pivot" in enemy and enemy.weapon_pivot != null:
		_blend_tween.parallel().tween_property(enemy.weapon_pivot, "rotation:z", -0.2, blend_out)


func _ramp_emission(enemy: Node3D, new_phase: int, duration: float) -> void:
	if not ("weapon_material" in enemy) or enemy.weapon_material == null:
		return
	var mat: StandardMaterial3D = enemy.weapon_material
	mat.emission_enabled = true
	var target_energy := 2.5 if new_phase < 3 else 4.5
	var start_energy := mat.emission_energy_multiplier
	var tw := create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mat):
			mat.emission_energy_multiplier = v
	, start_energy, target_energy, duration)
	if new_phase >= 3 and "body_material" in enemy and enemy.body_material != null:
		var body: StandardMaterial3D = enemy.body_material
		body.emission_enabled = true
		var body_tw := create_tween()
		body_tw.tween_method(func(v: float):
			if is_instance_valid(body):
				body.emission_energy_multiplier = v
		, body.emission_energy_multiplier, 1.5, duration)


func _resolve_phase_vfx_key(enemy: Node3D, new_phase: int) -> String:
	if not ("chapter_content" in enemy):
		return ""
	var content: Dictionary = enemy.chapter_content
	if content.is_empty():
		return ""
	var phases = content.get("phases", {})
	if typeof(phases) != TYPE_DICTIONARY:
		return ""
	var key := str(new_phase)
	if not phases.has(key):
		return ""
	var phase_data: Dictionary = phases[key]
	return String(phase_data.get("vfx", ""))


func _clear_focus_anchor() -> void:
	if _active_anchor != null and is_instance_valid(_active_anchor):
		_active_anchor.queue_free()
	_active_anchor = null


func reset() -> void:
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.kill()
	_blend_tween = null
	_clear_focus_anchor()
	if camera_director != null and camera_director.has_method("release"):
		camera_director.release()
