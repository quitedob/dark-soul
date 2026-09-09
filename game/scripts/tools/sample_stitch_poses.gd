extends SceneTree
## godot --headless --path game --script res://scripts/tools/sample_stitch_poses.gd
##     -- --request <pair.json> --output <sampled-poses.json>
## Samples animated GLBs locally. Does not call a remote stitching service.

const Sampler = preload("res://scripts/tools/motion_pose_sampler.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var paths := {}
	for index in range(0, args.size(), 2):
		if index + 1 >= args.size() or args[index] not in ["--request", "--output"] or paths.has(args[index]):
			_fail("Expected --request <JSON> --output <JSON>")
			return
		paths[args[index]] = ProjectSettings.globalize_path(args[index + 1])
	if not paths.has("--request") or not paths.has("--output"):
		_fail("Expected --request <JSON> --output <JSON>")
		return
	var request_path: String = paths["--request"]
	var output_path: String = paths["--output"]
	if request_path.simplify_path() == output_path.simplify_path() or output_path.get_extension().to_lower() != "json":
		_fail("Output must be a separate JSON file")
		return
	var input := FileAccess.open(request_path, FileAccess.READ)
	if input == null:
		_fail("Cannot read request: " + request_path)
		return
	var parser := JSON.new()
	if parser.parse(input.get_as_text()) != OK or not parser.data is Dictionary:
		_fail("Invalid request JSON: " + parser.get_error_message())
		return
	var request: Dictionary = parser.data
	var duration = request.get("stitch_duration")
	if not Sampler._number(duration) or float(duration) <= 0.0:
		_fail("stitch_duration must be a finite positive number of seconds")
		return
	var output := {"schema": "ashen.stitch_pose_inputs.v1", "stitch_duration": duration,
		"poses": {}, "sampling": {},
		"note": "Pose fields only; not a complete Stitch API request or generated transition."}
	for role in ["prefix", "suffix"]:
		if not request.get(role) is Dictionary:
			_fail("Missing motion object: " + role)
			return
		var sampled: Dictionary = await _sample(request[role], role)
		if not sampled.ok:
			_fail(role + ": " + sampled.error)
			return
		output.poses[role] = sampled.params
		sampled.erase("params")
		sampled.erase("ok")
		output.sampling[role] = sampled
	var prefix: Dictionary = output.poses.prefix.at_upper_trim_time.pelvis_world_pos
	var suffix: Dictionary = output.poses.suffix.at_lower_trim_time.pelvis_world_pos
	var distance := Vector3(prefix.x, prefix.y, prefix.z).distance_to(Vector3(suffix.x, suffix.y, suffix.z))
	if not is_finite(distance) or not is_finite(distance / float(duration)):
		_fail("Connection distance or speed cannot be represented as a finite number")
		return
	output.connection = {"pelvis_distance_m": distance, "distance_per_second": distance / float(duration)}
	var directory_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if directory_error != OK:
		_fail("Cannot create output directory: " + error_string(directory_error))
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write output: " + output_path)
		return
	file.store_string(JSON.stringify(output, "\t") + "\n")
	file.close()
	print("ASHEN_STITCH_POSES_OK ", JSON.stringify({"output": output_path, "motions": 2,
		"samples": 6, "pelvis_distance_m": distance, "stitch_duration": duration}))
	quit(0)


func _sample(config: Dictionary, role: String) -> Dictionary:
	if not config.get("scene") is String or not config.get("clip") is String:
		return Sampler._failure("scene and clip are required strings")
	var scene_path := ProjectSettings.globalize_path(String(config.scene))
	if scene_path.get_extension().to_lower() != "glb" or not FileAccess.file_exists(scene_path):
		return Sampler._failure("Expected an existing animated GLB; import/export FBX to GLB first")
	var units = config.get("meters_per_unit", 1.0)
	if not Sampler._number(units) or float(units) <= 0.0:
		return Sampler._failure("Invalid meters_per_unit")
	var position = config.get("root_node_world_pos", {"x": 0, "y": 0, "z": 0})
	var rotation = config.get("root_node_world_rot", {"x": 0, "y": 0, "z": 0, "w": 1})
	if not _components(position, ["x", "y", "z"]) or not _components(rotation, ["x", "y", "z", "w"]):
		return Sampler._failure("Root placement must contain finite numeric position/quaternion components")
	var quaternion := Quaternion(rotation.x, rotation.y, rotation.z, rotation.w)
	var placement_position := Vector3(position.x, position.y, position.z) / float(units)
	if not quaternion.is_finite() or not is_finite(quaternion.length_squared()) or quaternion.length_squared() < Sampler.EPSILON or not placement_position.is_finite():
		return Sampler._failure("Root placement must be representable and its quaternion must not be zero")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	state.use_named_skin_binds = true
	var error := document.append_from_file(scene_path, state)
	if error != OK:
		return Sampler._failure("GLB import failed: " + error_string(error))
	var model := document.generate_scene(state) as Node3D
	if model == null:
		return Sampler._failure("GLB did not generate a Node3D scene")
	var skeletons: Array[Skeleton3D] = []
	var players: Array[AnimationPlayer] = []
	_collect(model, skeletons, players)
	var skeleton := _choose(model, config.get("skeleton_path"), skeletons) as Skeleton3D
	var player := _choose(model, config.get("animation_player_path"), players) as AnimationPlayer
	if skeleton == null or player == null:
		model.free()
		return Sampler._failure("Expected one skeleton and AnimationPlayer, or explicit paths; a static rig has no motion to sample")
	var clip_name := String(config.clip)
	if not player.has_animation(clip_name):
		var available := player.get_animation_list()
		model.free()
		return Sampler._failure("Animation '%s' is missing; available: %s" % [clip_name, available])
	var animation_root := player.get_node_or_null(player.root_node) as Node3D
	var clip := player.get_animation(clip_name)
	var lower = config.get("lower_trim", 0.0)
	var upper = config.get("upper_trim", clip.length - Sampler.PREFIX_END_MARGIN if role == "prefix" else clip.length)
	if not Sampler._number(lower) or not Sampler._number(upper) or not config.get("bones", {}) is Dictionary:
		model.free()
		return Sampler._failure("Invalid trim times or bone-name map")
	var placement := Node3D.new()
	placement.name = "StitchPlacement"
	placement.position = placement_position
	placement.quaternion = quaternion.normalized()
	placement.add_child(model)
	root.add_child(placement)
	await process_frame
	var result: Dictionary = Sampler.sample_motion(placement, animation_root, skeleton, clip,
		float(lower), float(upper), config.get("bones", {}), {"role": role, "meters_per_unit": units})
	if result.ok:
		result.source = scene_path
		result.source_sha256 = FileAccess.get_sha256(scene_path)
		result.clip = clip_name
	placement.free()
	return result


func _collect(node: Node, skeletons: Array[Skeleton3D], players: Array[AnimationPlayer]) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is AnimationPlayer:
		node.active = false
		players.append(node)
	for child in node.get_children():
		_collect(child, skeletons, players)


func _choose(model: Node, path, candidates: Array) -> Node:
	if path == null:
		return candidates[0] if candidates.size() == 1 else null
	if not path is String:
		return null
	var node := model.get_node_or_null(NodePath(path))
	return node if node in candidates else null


func _components(value, fields: Array) -> bool:
	if not value is Dictionary:
		return false
	for field in fields:
		if not value.has(field) or not Sampler._number(value[field]):
			return false
	return true


func _fail(message: String) -> void:
	printerr("ASHEN_STITCH_POSES_FAILED: " + message)
	quit(1)
