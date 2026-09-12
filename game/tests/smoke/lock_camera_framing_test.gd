extends SceneTree
## Lock-camera math plus actual Player/Camera3D projection and recovery contracts.
## Verifies:
##   1) desired_yaw: due -Z -> ~0; due +X -> ~-PI/2; degenerate vertical keeps
##      current yaw; lerp_angle steps take the shortest wrap path across ±PI.
##   2) Actual Camera3D projection keeps the intended midpoint centered for
##      elevated/lowered targets and different yaw directions.
##   3) desired_boom: separation 0 -> base; 10 -> clamp to max; monotonic.
##   4) exp_weight: (2.2, 1/60) ~ 0.036; (2.2, 1.0) = 1 - exp(-2.2) ~ 0.889.
## Prints ASHEN_LOCK_FRAMING_OK on success.
## Run: godot --headless --path game --script res://tests/smoke/lock_camera_framing_test.gd
const LockCameraSolverScript = preload("res://scripts/camera/lock_camera_solver.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const InputConfig = preload("res://scripts/core/input_config.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_desired_yaw()
	_test_desired_pitch()
	_test_desired_boom()
	_test_exp_weight()
	await _test_player_camera()
	if _failures.is_empty():
		print("ASHEN_LOCK_FRAMING_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
		print("FAIL: " + failure)
	quit(1)


func _test_desired_yaw() -> void:
	var player := Vector3.ZERO
	# 目标在正 -Z（镜头前方）→ 偏航 ≈ 0
	var yaw_ahead: float = LockCameraSolverScript.desired_yaw(player, Vector3(0.0, 0.0, -10.0), 1.0)
	_expect(absf(yaw_ahead) < 0.0001, "target due -Z should give yaw ~0, got %.4f" % yaw_ahead)
	# 目标在正 +X → 偏航 ≈ -PI/2（atan2(-1, 0)）
	var yaw_right: float = LockCameraSolverScript.desired_yaw(player, Vector3(10.0, 0.0, 0.0), 0.0)
	_expect(absf(angle_difference(yaw_right, -PI / 2.0)) < 0.0001, "target due +X should give yaw ~-PI/2, got %.4f" % yaw_right)
	# 退化：目标在正上方（水平分量近零）→ 保持当前偏航
	var yaw_kept: float = LockCameraSolverScript.desired_yaw(player, Vector3(0.0, 6.0, 0.0), 0.7)
	_expect(is_equal_approx(yaw_kept, 0.7), "degenerate vertical target should keep current yaw, got %.4f" % yaw_kept)
	# 环绕：current = PI-0.1，desired = -PI+0.1 → lerp_angle 跨 ±PI 走最短路径（+0.2 rad）
	var dir_theta: float = -PI + 0.1
	var target_point := Vector3(-sin(dir_theta), 0.0, -cos(dir_theta)) * 10.0
	var desired: float = LockCameraSolverScript.desired_yaw(player, target_point, 0.0)
	_expect(absf(angle_difference(desired, dir_theta)) < 0.0001, "wrap case desired yaw should be -PI+0.1, got %.4f" % desired)
	var current: float = PI - 0.1
	var w: float = LockCameraSolverScript.exp_weight(LockCameraSolverScript.YAW_TRACK_SPEED, 1.0 / 60.0)
	var stepped: float = lerp_angle(current, desired, w)
	var expected: float = current + 0.2 * w
	_expect(absf(angle_difference(stepped, expected)) < 0.001, "lerp_angle should step shortest wrap way (+0.2 rad path), got %.4f want %.4f" % [stepped, expected])
	_expect(stepped > 3.0, "shortest wrap should stay near +PI (not travel long way through 0), got %.4f" % stepped)
	_expect(absf(angle_difference(stepped, desired)) < absf(angle_difference(current, desired)), "wrap step should reduce angular distance")


func _test_desired_pitch() -> void:
	var player := Vector3.ZERO
	var rig := Vector3(0.0, 1.45, 0.0)
	# 目标与镜头同高 → 俯仰 ≈ 0
	var level: float = LockCameraSolverScript.desired_pitch(player, Vector3(0.0, 1.45, -8.0), rig)
	_expect(absf(level) < 0.0001, "level target should give pitch ~0, got %.4f" % level)
	# Camera3D looks along -Z: positive X pitch raises its view direction.
	var above: float = LockCameraSolverScript.desired_pitch(player, Vector3(0.0, 5.0, -8.0), rig)
	_expect(above > 0.01, "target above should tilt camera up, got %.4f" % above)
	# Lower targets require downward pitch.
	var below: float = LockCameraSolverScript.desired_pitch(player, Vector3(0.0, -3.0, -8.0), rig)
	_expect(below < -0.01, "target below should tilt camera down, got %.4f" % below)
	var clamped: float = LockCameraSolverScript.desired_pitch(player, Vector3(0.0, 40.0, -1.0), rig)
	_expect(is_equal_approx(clamped, LockCameraSolverScript.PITCH_MAX), "high target should clamp to PITCH_MAX, got %.4f" % clamped)
	var low_clamped: float = LockCameraSolverScript.desired_pitch(player, Vector3(0.0, -40.0, -1.0), rig)
	_expect(is_equal_approx(low_clamped, LockCameraSolverScript.PITCH_MIN), "low target should clamp to PITCH_MIN")


func _test_desired_boom() -> void:
	var zero: float = LockCameraSolverScript.desired_boom(0.0)
	_expect(is_equal_approx(zero, LockCameraSolverScript.BOOM_BASE), "zero separation should give base boom, got %.4f" % zero)
	var far: float = LockCameraSolverScript.desired_boom(10.0)
	_expect(is_equal_approx(far, LockCameraSolverScript.BOOM_MAX), "10m separation should clamp to max boom, got %.4f" % far)
	# 中间值：5m → base + 5*gain
	var mid: float = LockCameraSolverScript.desired_boom(5.0)
	_expect(absf(mid - (LockCameraSolverScript.BOOM_BASE + 5.0 * LockCameraSolverScript.BOOM_GAIN)) < 0.0001, "5m separation should give base+1.5, got %.4f" % mid)
	# 随分离距离单调不减且始终处于 [base, max]
	var b2: float = LockCameraSolverScript.desired_boom(2.0)
	var b4: float = LockCameraSolverScript.desired_boom(4.0)
	var b6: float = LockCameraSolverScript.desired_boom(6.0)
	var b8: float = LockCameraSolverScript.desired_boom(8.0)
	_expect(zero <= b2 and b2 <= b4 and b4 <= b6 and b6 <= b8, "boom should be monotonic in separation, got %.3f %.3f %.3f %.3f" % [b2, b4, b6, b8])
	_expect(b2 >= LockCameraSolverScript.BOOM_BASE and b8 <= LockCameraSolverScript.BOOM_MAX, "boom must stay within [base, max]")


func _test_exp_weight() -> void:
	var w60: float = LockCameraSolverScript.exp_weight(2.2, 1.0 / 60.0)
	_expect(absf(w60 - 0.036) < 0.0005, "exp_weight(2.2, 1/60) should be ~0.036, got %.5f" % w60)
	var w1: float = LockCameraSolverScript.exp_weight(2.2, 1.0)
	_expect(absf(w1 - (1.0 - exp(-2.2))) < 0.00001, "exp_weight(2.2, 1.0) should equal 1-exp(-2.2), got %.5f" % w1)
	_expect(absf(w1 - 0.8892) < 0.0005, "exp_weight(2.2, 1.0) should be ~0.8892, got %.5f" % w1)
	_expect(w60 < w1, "exp_weight should grow with delta")
	_expect(w1 < 1.0, "exp_weight must stay < 1")


func _test_player_camera() -> void:
	InputConfig.configure_inputs()
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var target := Node3D.new()
	root.add_child(target)
	await process_frame
	var camera: Camera3D = player.camera
	var viewport_rect := root.get_visible_rect()
	var center := viewport_rect.get_center()
	# Exercise the real top-level rig, pitch, spring arm, and Camera3D. A test of
	# the solver's scalar sign alone previously blessed an inverted camera.
	for point: Vector3 in [Vector3(0.0, 3.0, -8.0), Vector3(0.0, -1.0, -8.0), Vector3(8.0, 2.5, 0.0)]:
		target.position = point
		player.lock_target = target
		await process_frame
		player._update_camera_rig(10.0)
		await physics_frame
		await process_frame
		var head: Vector3 = player.global_position + Vector3.UP * 1.45
		var midpoint := head.lerp(target.global_position, LockCameraSolverScript.MIDPOINT_BIAS)
		var projected := camera.unproject_position(midpoint)
		_expect(not camera.is_position_behind(midpoint), "Lock midpoint must be in front of Camera3D")
		_expect(projected.distance_to(center) < 2.0,
			"Actual camera must center lock midpoint for %s; projected=%s center=%s" % [point, projected, center])
		_expect(viewport_rect.has_point(camera.unproject_position(head)), "Player head must remain framed")
		_expect(viewport_rect.has_point(camera.unproject_position(target.global_position)), "Lock target must remain framed")

	player.lock_target = null
	player.spring_arm.spring_length = LockCameraSolverScript.BOOM_MAX
	player._begin_lock_camera_recover()
	# Follow the actual manual-orbit entry point: it cancels yaw/pitch recovery.
	Input.action_press("look_right", 1.0)
	player._update_gamepad_camera(1.0 / 60.0)
	Input.action_release("look_right")
	_expect(is_zero_approx(player._camera_recover_timer), "Manual orbit fixture must cancel angular recovery")
	for _frame in 240:
		player._update_camera_rig(1.0 / 60.0)
	_expect(absf(player.spring_arm.spring_length - LockCameraSolverScript.BOOM_BASE) < 0.002,
		"Unlocked boom must recover fully even after manual orbit cancels angular recovery")
	player.spring_arm.spring_length = LockCameraSolverScript.BOOM_MAX
	player._begin_lock_camera_recover()
	for _frame in 240:
		player._update_camera_rig(1.0 / 60.0)
	_expect(absf(player.spring_arm.spring_length - LockCameraSolverScript.BOOM_BASE) < 0.002,
		"Unlocked boom must keep recovering after the short angular recovery timer expires")
	await _test_camera_obstructions(player)
	target.free()
	player.free()
	await process_frame


func _test_camera_obstructions(player) -> void:
	player.camera_rig.rotation = Vector3.ZERO
	player.camera_pitch.rotation = Vector3.ZERO
	player.spring_arm.spring_length = LockCameraSolverScript.BOOM_BASE
	var boundary := _camera_wall(Vector3(0.0, 1.45, 1.0), true)
	var visible_wall := _camera_wall(Vector3(0.0, 1.45, 3.0), false)
	root.add_child(boundary)
	root.add_child(visible_wall)
	await physics_frame
	await process_frame
	player._configure_spring_arm_collision()
	await physics_frame
	await process_frame
	var blocked_length: float = player.spring_arm.get_hit_length()
	_expect(blocked_length > 1.5 and blocked_length < 3.1,
		"Camera must pass invisible containment but stop at visible wall; hit length=%f" % blocked_length)
	_expect(boundary.collision_layer == 1, "Camera exclusion must preserve actor containment collision")
	visible_wall.free()
	await physics_frame
	await process_frame
	_expect(player.spring_arm.get_hit_length() > 5.0, "Invisible boundary must allow the full camera boom")
	boundary.free()
	var replacement := _camera_wall(Vector3(0.0, 1.45, 0.8), true)
	root.add_child(replacement)
	await physics_frame
	await process_frame
	player._configure_spring_arm_collision()
	await physics_frame
	await process_frame
	_expect(player.spring_arm.get_hit_length() > 5.0, "Exclusion refresh must cover replacement-level boundary RIDs")
	replacement.free()


func _camera_wall(at: Vector3, passthrough: bool) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = at
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 4.0, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	if passthrough:
		wall.add_to_group("camera_passthrough")
	else:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		visual.mesh = mesh
		wall.add_child(visual)
	return wall


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
