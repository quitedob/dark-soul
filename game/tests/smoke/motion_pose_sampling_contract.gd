extends SceneTree

const Sampler = preload("res://scripts/tools/motion_pose_sampler.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_world_sampling()
	_test_cardinal_yaw()
	_test_loop_and_restore()
	_test_validation()
	await _test_real_motion()
	if failures.is_empty():
		print("ASHEN_MOTION_POSE_SAMPLING_OK ", checks, " checks")
		quit(0)
	else:
		for message in failures:
			printerr("ASHEN_MOTION_POSE_SAMPLING_FAILED: ", message)
		quit(1)


func _fixture() -> Dictionary:
	var placement := Node3D.new()
	placement.name = "PoseContractCharacter"
	root.add_child(placement)
	var model := Node3D.new()
	model.name = "Model"
	placement.add_child(model)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	model.add_child(skeleton)
	var names := ["root", "hips", "thigh.L", "thigh.R", "head"]
	var parents := [-1, 0, 1, 1, 1]
	var positions := [Vector3.ZERO, Vector3(.1, .95, 0), Vector3(.1, 0, 0), Vector3(-.1, 0, 0), Vector3(0, .4, 0)]
	for index in names.size():
		skeleton.add_bone(names[index])
		skeleton.set_bone_parent(index, parents[index])
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, positions[index]))
	skeleton.reset_bone_poses()
	var clip := Animation.new()
	clip.length = 1.0
	clip.loop_mode = Animation.LOOP_LINEAR
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Skeleton:root"))
	clip.position_track_insert_key(track, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(track, 1.0, Vector3(.2, 0, 0))
	track = clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Skeleton:hips"))
	clip.position_track_insert_key(track, 0.0, Vector3(.1, .95, 0))
	clip.position_track_insert_key(track, 1.0, Vector3(.1, .95, 2))
	track = clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, NodePath("Skeleton:hips"))
	clip.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
	clip.rotation_track_insert_key(track, 1.0, Quaternion(Vector3.UP, PI / 2))
	return {"root": placement, "model": model, "skeleton": skeleton, "clip": clip}


func _sample(f: Dictionary, lower: float = .25, upper: float = .75, options: Dictionary = {}) -> Dictionary:
	return Sampler.sample_motion(f.root, f.model, f.skeleton, f.clip, lower, upper, {}, options)


func _test_world_sampling() -> void:
	var f := _fixture()
	f.root.position = Vector3(3, 2, -1)
	f.root.rotation.y = PI / 2
	f.model.position = Vector3(.35, .2, -.15)
	f.model.rotation.y = .3
	f.skeleton.force_update_transform()
	var world: Transform3D = f.skeleton.global_transform
	var result := _sample(f)
	_expect(result.ok, "nested world sample succeeds: " + str(result.get("error", "")))
	if result.ok:
		for pair in [["at_zero_time", 0.0], ["at_lower_trim_time", .25], ["at_upper_trim_time", .75]]:
			var state: Dictionary = result.params[pair[0]]
			var time: float = pair[1]
			_near(_v(state.pelvis_world_pos), world * Vector3(.1 + .2 * time, .95, 2 * time), "world pelvis " + pair[0])
			var expected := (world.basis * Basis(Vector3.UP, time * PI / 2)).get_rotation_quaternion()
			var actual := _q(state.pelvis_world_rot)
			_expect(absf(actual.dot(expected)) > .99999, "world quaternion " + pair[0])
			_expect(absf(actual.length() - 1.0) < .00001, "unit quaternion " + pair[0])
			_expect(absf(angle_difference(state.hips_forward_facing_world_yaw, PI / 2 + .3 + time * PI / 2)) < .00001, "world yaw " + pair[0])
		_near(_v(result.params.root_node_world_pos), Vector3(3, 2, -1), "root is placement, not animated bone")
	f.root.free()


func _test_cardinal_yaw() -> void:
	var f := _fixture()
	f.clip.remove_track(2)
	for angle in [0.0, PI / 2, PI, -PI / 2]:
		f.root.rotation.y = angle
		var result := _sample(f)
		_expect(result.ok, "cardinal sample")
		if result.ok:
			var state: Dictionary = result.params.at_zero_time
			_expect(absf(angle_difference(state.hips_forward_facing_world_yaw, angle)) < .00001, "atan2 cardinal sign " + str(angle))
			_near(_v(result.samples.at_zero_time.forward_world), Vector3(sin(angle), 0, cos(angle)), "cardinal forward")
	f.root.free()


func _test_loop_and_restore() -> void:
	var f := _fixture()
	f.skeleton.set_bone_pose_position(1, Vector3(4, 5, 6))
	f.skeleton.set_bone_pose_rotation(4, Quaternion(Vector3.RIGHT, .5))
	var head_rotation: Quaternion = f.skeleton.get_bone_pose_rotation(4)
	var end := _sample(f, .5, 1.0, {"role": "suffix"})
	_expect(end.ok, "suffix end sampling")
	if end.ok:
		_near(_v(end.params.at_upper_trim_time.pelvis_world_pos), Vector3(.3, .95, 2), "loop does not wrap at duration")
	_near(f.skeleton.get_bone_pose_position(1), Vector3(4, 5, 6), "original pelvis pose restored")
	_expect(f.skeleton.get_bone_pose_rotation(4).is_equal_approx(head_rotation), "untracked pose restored")
	_expect(f.clip.loop_mode == Animation.LOOP_LINEAR, "source clip loop setting unchanged")
	_expect(f.model.get_child_count() == 1, "temporary AnimationPlayer freed")
	var again := _sample(f, .1, .2)
	_expect(again.ok, "backward resampling succeeds")
	if again.ok:
		_near(_v(again.params.at_zero_time.pelvis_world_pos), Vector3(.1, .95, 0), "zero sample resets sparse state")
	for key in f.clip.track_get_key_count(2):
		var value: Quaternion = f.clip.track_get_key_value(2, key)
		f.clip.track_set_key_value(2, key, Quaternion(value.x * 2, value.y * 2, value.z * 2, value.w * 2))
	var normalized := _sample(f, .1, .2)
	_expect(normalized.ok, "finite nonunit quaternion keys normalized on clone")
	if normalized.ok and again.ok:
		_expect(absf(_q(normalized.params.at_upper_trim_time.pelvis_world_rot).dot(_q(again.params.at_upper_trim_time.pelvis_world_rot))) > .99999, "normalized keys interpolate equivalently")
	_expect(is_equal_approx(f.clip.track_get_key_value(2, 0).length(), 2.0), "source quaternion keys unchanged")
	var original_transform: Transform3D = f.model.transform
	var node_track: int = f.clip.add_track(Animation.TYPE_POSITION_3D)
	f.clip.track_set_path(node_track, NodePath("."))
	f.clip.position_track_insert_key(node_track, 0.0, Vector3(0, 0, 3))
	f.clip.position_track_insert_key(node_track, 1.0, Vector3(0, 0, 4))
	var moving_node := _sample(f)
	_expect(moving_node.ok, "animated child root is supported")
	if moving_node.ok:
		_near(_v(moving_node.params.at_zero_time.pelvis_world_pos), Vector3(.1, .95, 3), "animated child transform included")
	_expect(f.model.transform.is_equal_approx(original_transform), "animated node transform restored")
	var method_track: int = f.clip.add_track(Animation.TYPE_METHOD)
	f.clip.track_set_path(method_track, NodePath("."))
	f.clip.track_insert_key(method_track, 0.0, {"method": "set_meta", "args": ["stitch_callback_fired", true]})
	var events := _sample(f)
	_expect(events.ok and events.ignored_non_transform_tracks == 1, "method tracks removed from isolated copy")
	_expect(not f.model.has_meta("stitch_callback_fired") and f.clip.get_track_count() == 5, "no callbacks or source track mutation")
	var units := _sample(f, .25, .75, {"meters_per_unit": .01})
	_expect(units.ok, "unit conversion succeeds")
	if units.ok:
		_near(_v(units.params.at_zero_time.pelvis_world_pos), Vector3(.001, .0095, .03), "positions converted to meters")
	f.root.free()


func _test_validation() -> void:
	var f := _fixture()
	_expect(not _sample(f, -.1, .5).ok, "negative trim rejected")
	_expect(not _sample(f, .5, .5).ok, "empty trim rejected")
	_expect(not _sample(f, .8, .5).ok, "reversed trim rejected")
	_expect(not _sample(f, 0, 1.1, {"role": "suffix"}).ok, "past-end trim rejected")
	_expect(not _sample(f, 0, 1).ok, "prefix end margin enforced")
	_expect(not _sample(f, 0, .95).ok, "prefix 0.051 margin enforced")
	_expect(_sample(f, 0, .949).ok, "prefix margin boundary accepted")
	_expect(not _sample(f, 0, NAN).ok, "nonfinite trim rejected")
	_expect(not _sample(f, .1, .5, {"meters_per_unit": 0}).ok, "zero units rejected")
	_expect(not _sample(f, .25, .75, {"meters_per_unit": 3e38}).ok, "overflowing converted position rejected")
	_expect(f.model.get_child_count() == 1, "sampler freed after conversion overflow")
	_expect(not _sample(f, .1, .5, {"role": "unknown"}).ok, "unknown role rejected")
	_expect(not Sampler.sample_motion(f.root, f.model, f.skeleton, null, 0, .5).ok, "missing clip rejected")
	_expect(not Sampler.sample_motion(f.root, f.model, f.skeleton, f.clip, 0, .5, {"pelvis": "missing"}).ok, "missing bone rejected")
	f.skeleton.add_bone("Hips")
	_expect(not _sample(f).ok, "ambiguous pelvis alias rejected")
	_expect(Sampler.sample_motion(f.root, f.model, f.skeleton, f.clip, 0, .5, {"pelvis": "hips"}).ok, "explicit bone mapping resolves ambiguity")
	f.skeleton.set_bone_name(5, "other")
	f.clip.track_set_path(0, NodePath("Skeleton:missing"))
	_expect(not _sample(f).ok, "missing track target rejected")
	f.clip.track_set_path(0, NodePath(".."))
	_expect(not _sample(f).ok, "placement animation rejected")
	f.clip.track_set_path(0, NodePath("../.."))
	_expect(not _sample(f).ok, "escaped transform rejected")
	f.clip.track_set_path(0, NodePath("Skeleton:root"))
	f.root.scale = Vector3(-1, 1, 1)
	_expect(not _sample(f).ok, "reflection rejected")
	f.root.scale = Vector3.ONE
	f.skeleton.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0, .1, 0)))
	f.skeleton.set_bone_rest(3, Transform3D(Basis.IDENTITY, Vector3(0, -.1, 0)))
	f.skeleton.set_bone_pose_position(1, Vector3(4, 5, 6))
	_expect(not _sample(f).ok, "degenerate horizontal hips rejected")
	_near(f.skeleton.get_bone_pose_position(1), Vector3(4, 5, 6), "state restored after sampling failure")
	_expect(f.model.get_child_count() == 1, "temporary sampler freed after failure")
	f.root.free()


func _test_real_motion() -> void:
	var path := "res://assets/models/enemy/minnyquinn.glb"
	var hash_before := FileAccess.get_sha256(path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	if document.append_from_file(path, state) != OK:
		_expect(false, "real motion imports")
		return
	var model := document.generate_scene(state) as Node3D
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	player.active = false
	var placement := Node3D.new()
	placement.add_child(model)
	root.add_child(placement)
	await process_frame
	var animation_root := player.get_node(player.root_node) as Node3D
	var clip := player.get_animation(&"root-retreat")
	var prefix := Sampler.sample_motion(placement, animation_root, skeleton, clip, 0, .5)
	_expect(prefix.ok, "real root-retreat samples")
	placement.position.z = 1.0
	var suffix := Sampler.sample_motion(placement, animation_root, skeleton, clip, .5, .9, {}, {"role": "suffix"})
	_expect(suffix.ok, "real suffix samples")
	if prefix.ok and suffix.ok:
		var start := _v(prefix.params.at_zero_time.pelvis_world_pos)
		var end := _v(prefix.params.at_upper_trim_time.pelvis_world_pos)
		var following := _v(suffix.params.at_lower_trim_time.pelvis_world_pos)
		_expect(start.distance_to(end) > .1, "original root movement is retained")
		_near(following - end, Vector3(0, 0, 1), "real connection has one-meter placement gap")
		_expect(prefix.bone_names.pelvis == "DEF-hips", "real DEF mapping")
	placement.free()
	_expect(FileAccess.get_sha256(path) == hash_before, "real GLB remains byte-identical")


func _v(value: Dictionary) -> Vector3:
	return Vector3(value.x, value.y, value.z)


func _q(value: Dictionary) -> Quaternion:
	return Quaternion(value.x, value.y, value.z, value.w)


func _near(actual: Vector3, expected: Vector3, description: String) -> void:
	_expect(actual.distance_to(expected) < .00002, "%s: %s versus %s" % [description, actual, expected])


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
