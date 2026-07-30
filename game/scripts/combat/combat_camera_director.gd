extends Node
class_name CombatCameraDirector
## Boss 专属镜头：短暂接管 spring/pitch/look，尊重 reduced_motion

signal shot_started(shot_id: StringName)
signal shot_finished(shot_id: StringName)

const ShotCatalog = preload("res://scripts/combat/data/camera_shot_profile.gd")

var player: Node3D = null
var trauma_shake = null
var reduced_motion := false
var active := false
var _profile = null
var _subject: Node3D = null
var _elapsed := 0.0
var _saved_spring := 5.2
var _saved_pitch := 0.0
var _saved_fov := 75.0
var _base_fov := 75.0


func setup(p: Node3D, shake = null) -> void:
	player = p
	trauma_shake = shake
	if player != null and "camera" in player and player.camera != null:
		_base_fov = player.camera.fov
		_saved_fov = _base_fov


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled and active:
		release()


func play_shot_id(shot_id: StringName, subject: Node3D = null) -> bool:
	var catalog: Dictionary = ShotCatalog.catalog()
	if not catalog.has(shot_id):
		return false
	return play_shot(catalog[shot_id], subject)


func play_shot(profile, subject: Node3D = null) -> bool:
	if profile == null or player == null:
		return false
	if reduced_motion and float(profile.trauma) > 0.15:
		# 仍做极短构图，跳过强震动
		pass
	_capture_baseline()
	_profile = profile
	_subject = subject
	_elapsed = 0.0
	active = true
	if player.has_method("set_camera_director_override"):
		player.set_camera_director_override(true)
	var trauma_amt := float(profile.trauma)
	if reduced_motion:
		trauma_amt *= 0.15
	if trauma_shake != null and trauma_amt > 0.01 and trauma_shake.has_method("inject"):
		trauma_shake.inject(trauma_amt)
	shot_started.emit(profile.shot_id)
	return true


func release() -> void:
	if not active and _profile == null:
		_restore_baseline()
		return
	var finished_id: StringName = _profile.shot_id if _profile != null else &""
	active = false
	_profile = null
	_subject = null
	_elapsed = 0.0
	_restore_baseline()
	if player != null and player.has_method("set_camera_director_override"):
		player.set_camera_director_override(false)
	if finished_id != &"":
		shot_finished.emit(finished_id)


func _physics_process(delta: float) -> void:
	if not active or _profile == null or player == null:
		return
	_elapsed += delta
	var t := clampf(_elapsed / maxf(float(_profile.blend_in), 0.05), 0.0, 1.0)
	_apply_framing(t)
	var hold_end := float(_profile.duration)
	if _elapsed >= hold_end:
		release()


func _capture_baseline() -> void:
	if player == null:
		return
	if "spring_arm" in player and player.spring_arm != null:
		_saved_spring = player.spring_arm.spring_length
	if "camera_pitch" in player and player.camera_pitch != null:
		_saved_pitch = player.camera_pitch.rotation.x
	if "camera" in player and player.camera != null:
		_saved_fov = player.camera.fov


func _restore_baseline() -> void:
	if player == null:
		return
	if "spring_arm" in player and player.spring_arm != null:
		player.spring_arm.spring_length = _saved_spring
	if "camera_pitch" in player and player.camera_pitch != null:
		player.camera_pitch.rotation.x = _saved_pitch
	if "camera" in player and player.camera != null:
		player.camera.fov = _saved_fov


func _apply_framing(blend: float) -> void:
	if player == null or _profile == null or not player.is_inside_tree():
		return
	var look_point := _resolve_look_point()
	if "spring_arm" in player and player.spring_arm != null:
		player.spring_arm.spring_length = lerpf(_saved_spring, float(_profile.spring_length), blend)
	if "camera_pitch" in player and player.camera_pitch != null:
		player.camera_pitch.rotation.x = lerp_angle(_saved_pitch, float(_profile.pitch), blend)
	if "camera" in player and player.camera != null:
		player.camera.fov = lerpf(_saved_fov, _base_fov + float(_profile.fov_delta), blend)
	if look_point != Vector3.ZERO and "camera_rig" in player and player.camera_rig != null and player.camera_rig.is_inside_tree():
		var direction: Vector3 = look_point - player.camera_rig.global_position
		var horizontal := Vector3(direction.x, 0.0, direction.z)
		if horizontal.length_squared() > 0.001:
			var target_basis := Basis.looking_at(horizontal.normalized(), Vector3.UP)
			var current_q: Quaternion = player.camera_rig.global_basis.get_rotation_quaternion()
			var target_q: Quaternion = target_basis.get_rotation_quaternion()
			player.camera_rig.global_basis = Basis(current_q.slerp(target_q, blend * 0.85))


func _resolve_look_point() -> Vector3:
	if _subject == null or not is_instance_valid(_subject) or not _subject.is_inside_tree():
		return Vector3.ZERO
	var mode: StringName = _profile.look_at if _profile != null else &"boss_chest"
	match mode:
		&"weak_point":
			if _subject.has_method("get_execution_anchor"):
				return _subject.get_execution_anchor(&"furnace_core")
			return _subject.global_position + Vector3.UP * 1.8
		&"grab_hold":
			if _subject.has_method("get_target_point"):
				return _subject.get_target_point()
			return _subject.global_position + Vector3.UP * 1.2
		&"boss_chest", _:
			if _subject.has_method("get_target_point"):
				return _subject.get_target_point()
			return _subject.global_position + Vector3.UP * 1.4
