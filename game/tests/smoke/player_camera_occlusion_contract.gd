extends SceneTree
## Real production Player + SpringArm collision; camera transforms/arm length are
## never assigned. Run with --script res://tests/smoke/player_camera_occlusion_contract.gd.
const PlayerScript = preload("res://scripts/player/player.gd")
const InputConfig = preload("res://scripts/core/input_config.gd")
const PlayerVisualsScript = preload("res://scripts/core/player_visuals.gd")
const EmbeddedActions = preload("res://scripts/core/embedded_model_actions.gd")

var failures: Array[String] = []
var checks := 0
var fixture: Node3D
var player: CharacterBody3D
var wall: StaticBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfig.configure_inputs()
	fixture = Node3D.new()
	root.add_child(fixture)
	fixture.add_child(_solid("Floor", Vector3(40, .6, 40), Vector3(0, -.3, 0)))
	fixture.add_child(_solid("Ceiling", Vector3(40, .6, 40), Vector3(0, 6.3, 0)))
	player = PlayerScript.new()
	player.position.y = .1
	fixture.add_child(player)
	await _frames(40)
	_expect(player.is_on_floor(), "Actual default player must stand on physical floor")
	_expect(_camera_distance() > 5., "Unobstructed actual camera starts at full boom")
	await _test_visibility_cycle("default body")

	player.set_traversal_up(Vector3.DOWN)
	player.global_position = Vector3(0, 3, 0)
	player.last_safe_transform = player.global_transform
	await _frames(65)
	_expect(player.is_on_floor() and player.up_direction == Vector3.DOWN,
		"Actual inverted gravity must ground player on ceiling")
	_expect(player.camera_rig.global_basis.y.dot(Vector3.DOWN) > .99,
		"Inverted camera rig uses actual upside-down basis")
	await _test_visibility_cycle("inverted body")
	player.free()
	await process_frame

	# Start this independent fixture as an embedded class, then perform the real
	# class-switch entry point. The default Manny body is covered above separately.
	player = PlayerScript.new()
	player.combat_style = PlayerScript.CombatStyle.TWIN_COLOSSI
	player.position.y = .1
	fixture.add_child(player)
	await _frames(40)
	_expect(EmbeddedActions.available(player.body_mesh), "Class fixture must use its actual embedded animation driver")
	var old_body_ids: Array[int] = []
	for body in _bodies():
		old_body_ids.append(body.get_instance_id())
	wall = _solid("ClassCameraWall", Vector3(4, 4, .2), Vector3.ZERO)
	fixture.add_child(wall)
	await _move_wall_to_camera_distance(.7)
	_expect(_all_bodies_hidden(), "Physical obstruction hides old class body")
	player.set_combat_style(PlayerScript.CombatStyle.CRESCENT_PAIR)
	var new_bodies := _bodies()
	_expect(not new_bodies.is_empty(), "Class switch must create replacement body roots")
	for body in new_bodies:
		_expect(not old_body_ids.has(body.get_instance_id()), "Real class switch replaces the previous root")
		_expect(not body.visible, "Replacement body is hidden immediately before its first rendered frame")
	await _frames(5)
	_expect(_all_bodies_hidden(), "Replacement body stays hidden through actual physics hook")
	await _check_embedded_animation_advances()
	_expect(not player.body_collision.disabled and player.collision_layer == 2 and player.collision_mask == 1,
		"Class camera hiding preserves actual capsule and collision layers")
	var equipment := _equipment_visibility()
	wall.queue_free()
	await _frames(6)
	_expect(_camera_distance() > 5., "Removing class wall restores actual SpringArm distance")
	for body in _bodies():
		_expect(body.visible, "Replacement class body restores when camera retreats")
	_expect(_equipment_visibility() == equipment, "Camera recovery leaves replacement equipment visibility alone")
	fixture.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_PLAYER_CAMERA_OCCLUSION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_visibility_cycle(label: String) -> void:
	var bodies := _bodies()
	_expect(not bodies.is_empty(), label + ": real tagged body roots exist")
	if bodies.is_empty():
		return
	var prior: Dictionary = {}
	for body in bodies:
		prior[body.get_instance_id()] = body.visible
	# Simulate an authored hidden subpart and a separately hidden body root. The
	# camera must preserve their local flags instead of recursively showing meshes.
	var hidden_part := Node3D.new()
	hidden_part.name = "AuthoredHiddenPart"
	hidden_part.visible = false
	bodies[0].add_child(hidden_part)
	var hidden_root := Node3D.new()
	hidden_root.name = "AuthoredHiddenRoot"
	hidden_root.visible = false
	player.body_yaw.add_child(hidden_root)
	hidden_root.add_to_group(PlayerVisualsScript.BODY_GROUP)
	var equipment := _equipment_visibility()
	var collision_id: int = player.body_collision.get_instance_id()
	var animation_tree: AnimationTree = player._anim_bridge.anim_tree
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	wall = _solid("CameraWall", Vector3(4, 4, .2), Vector3.ZERO)
	fixture.add_child(wall)
	await _move_wall_to_camera_distance(.7)
	_expect(_camera_distance() < 1., label + ": real wall compresses Camera3D below one metre")
	_expect(player.spring_arm.get_hit_length() < 1. and player.spring_arm.spring_length > 5.,
		label + ": physical hit shortens camera while requested arm remains long")
	_expect(_all_bodies_hidden(), label + ": physics hook hides every body root")
	_expect(_equipment_visibility() == equipment, label + ": weapon, offhand, shield and trail retain local visibility")
	_expect(player.visual_root.visible and player.body_yaw.visible, label + ": equipment ancestors remain visible")
	_expect(player.body_collision.get_instance_id() == collision_id and not player.body_collision.disabled and player.is_on_floor(),
		label + ": body collision and actual grounding remain active")
	var animation_before := playback.get_current_play_position()
	await _frames(9)
	_expect(animation_tree.active and player._anim_bridge.enabled,
		label + ": animation tree remains active while body hidden")
	_expect(absf(playback.get_current_play_position() - animation_before) > .01,
		label + ": real animation playback advances while body hidden")
	await _move_wall_to_camera_distance(1.12)
	_expect(_camera_distance() > 1. and _camera_distance() < 1.25,
		label + ": real camera enters hysteresis band from below")
	_expect(_all_bodies_hidden(), label + ": body remains hidden inside recovery band")
	await _move_wall_to_camera_distance(1.65)
	_expect(_camera_distance() > 1.25, label + ": real camera crosses restore threshold")
	for body in bodies:
		_expect(body.visible == prior[body.get_instance_id()], label + ": prior root visibility is restored")
	_expect(not hidden_part.visible and not hidden_root.visible,
		label + ": previously hidden roots and child parts remain hidden")
	await _move_wall_to_camera_distance(1.12)
	for body in bodies:
		_expect(body.visible == prior[body.get_instance_id()], label + ": visible body stays visible inside hysteresis band")
	await _move_wall_to_camera_distance(.7)
	_expect(_all_bodies_hidden(), label + ": repeated physical compression hides body again")
	wall.queue_free()
	await _frames(6)
	_expect(_camera_distance() > 5., label + ": wall removal restores full physical camera boom")
	for body in bodies:
		_expect(body.visible == prior[body.get_instance_id()], label + ": wall removal restores saved body state")
	_expect(not hidden_root.visible and not hidden_part.visible, label + ": second recovery preserves authored hidden state")
	_expect(_equipment_visibility() == equipment, label + ": full cycle preserves equipment visibility")
	hidden_root.free()
	hidden_part.free()


func _check_embedded_animation_advances() -> void:
	var driver := EmbeddedActions._driver(player.body_mesh)
	_expect(driver != null, "Rebuilt body has actual embedded animation driver")
	if driver == null:
		return
	var animation: AnimationPlayer = driver._animation_player
	var before := animation.current_animation_position
	await _frames(9)
	_expect(animation.is_playing() and animation.active, "Rebuilt hidden model animation remains playing")
	_expect(absf(animation.current_animation_position - before) > .01,
		"Rebuilt hidden model advances its actual imported animation")


func _move_wall_to_camera_distance(target: float) -> void:
	# Adjust only the physical obstacle along the real arm axis. Camera position
	# and SpringArm hit length are read after engine physics, never fabricated.
	var arm_transform: Transform3D = player.spring_arm.global_transform
	var was_hidden := _all_bodies_hidden()
	var samples: Array[Dictionary] = []
	_trace_camera("before target=%.2f" % target)
	if wall.has_meta("camera_wall_calibrated"):
		# Move from the measured physical contact. Reinitializing every wall at
		# target + a guessed margin previously overshot 1.25m during a 1.12m
		# test, correctly restoring the body before the test settled back down.
		wall.global_position += arm_transform.basis.z * (target - _camera_distance())
	else:
		wall.global_transform = arm_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, target + .1))
		wall.set_meta("camera_wall_calibrated", true)
	await _wall_frames(5, samples)
	_trace_camera("initial wall target=%.2f" % target)
	for attempt in 2:
		wall.global_position += arm_transform.basis.z * (target - _camera_distance())
		await _wall_frames(5, samples)
	_trace_camera("settled target=%.2f" % target)
	_expect(absf(_camera_distance() - target) < .06,
		"Physical camera-wall fixture reaches %.2fm, actual %.3fm" % [target, _camera_distance()])
	if target > 1. and target < 1.25:
		var stayed_on_expected_side := true
		var kept_visibility := true
		var minimum := INF
		var maximum := -INF
		for sample in samples:
			var distance: float = sample["distance"]
			minimum = minf(minimum, distance)
			maximum = maxf(maximum, distance)
			stayed_on_expected_side = stayed_on_expected_side and (distance <= 1.25 if was_hidden else distance >= 1.)
			kept_visibility = kept_visibility and bool(sample["hidden"]) == was_hidden
		print("CAMERA_HYSTERESIS target=%.2f previous_hidden=%s range=[%.4f,%.4f] samples=%d" % [
			target, was_hidden, minimum, maximum, samples.size()])
		_expect(stayed_on_expected_side, "Every physical frame must stay on the intended side of the opposite visibility threshold")
		_expect(kept_visibility, "Hysteresis preserves prior visibility through every sampled physics frame")


func _wall_frames(count: int, samples: Array[Dictionary]) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		samples.append({"distance": _camera_distance(), "hidden": _all_bodies_hidden()})


func _trace_camera(label: String) -> void:
	print("CAMERA_OCCLUSION %s distance=%.4f hit=%.4f requested=%.2f all_hidden=%s inverted=%s" % [
		label, _camera_distance(), player.spring_arm.get_hit_length(),
		player.spring_arm.spring_length, _all_bodies_hidden(), player.up_direction.y < 0.])


func _camera_distance() -> float:
	return player.camera.global_position.distance_to(player.camera_rig.global_position)


func _bodies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in player.body_yaw.get_children():
		if child is Node3D and child.is_in_group(PlayerVisualsScript.BODY_GROUP):
			result.append(child)
	return result


func _all_bodies_hidden() -> bool:
	var bodies := _bodies()
	if bodies.is_empty():
		return false
	for body in bodies:
		if body.visible:
			return false
	return true


func _equipment_visibility() -> Array[bool]:
	return [player.weapon_pivot.visible, player.offhand_weapon_pivot.visible,
		player.shield_mesh.visible, player.weapon_trail.visible]


func _solid(label: String, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	body.add_child(visual)
	return body


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
