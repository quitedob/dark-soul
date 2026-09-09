extends RefCounted
## Offline transform-clip sampling. Use an isolated character instance, not live gameplay.
## Bone global poses are skeleton-local; multiply by Skeleton3D.global_transform.

const PREFIX_END_MARGIN := 0.051
const EPSILON := 0.000001
const BONE_ALIASES := {
	"pelvis": ["hips", "Hips", "DEF-hips", "mixamorig_Hips", "mixamorig:Hips"],
	"left_hip": ["thigh.L", "LeftUpperLeg", "DEF-thigh.L", "mixamorig_LeftUpLeg", "mixamorig:LeftUpLeg"],
	"right_hip": ["thigh.R", "RightUpperLeg", "DEF-thigh.R", "mixamorig_RightUpLeg", "mixamorig:RightUpLeg"],
}


static func resolve_bones(skeleton: Skeleton3D, names: Dictionary = {}) -> Dictionary:
	var indices := {}
	var resolved := {}
	for role in BONE_ALIASES:
		var candidates: Array = [names[role]] if names.has(role) else BONE_ALIASES[role]
		var matches: Array[String] = []
		for name in candidates:
			if not (name is String or name is StringName):
				return _failure("Bone names must be strings: " + role)
			if skeleton.find_bone(String(name)) >= 0:
				matches.append(String(name))
		if matches.size() != 1:
			return _failure("Expected one %s bone; found %s. Supply an explicit bone map." % [role, matches])
		resolved[role] = matches[0]
		indices[role] = skeleton.find_bone(matches[0])
	if indices.pelvis == indices.left_hip or indices.pelvis == indices.right_hip or indices.left_hip == indices.right_hip:
		return _failure("Pelvis and left/right hip landmarks must be distinct bones")
	return {"ok": true, "indices": indices, "names": resolved}


static func sample_motion(character_root: Node3D, animation_root: Node3D, skeleton: Skeleton3D,
		clip: Animation, lower_trim: float, upper_trim: float, bone_names: Dictionary = {},
		options: Dictionary = {}) -> Dictionary:
	if character_root == null or animation_root == null or skeleton == null or clip == null:
		return _failure("A character root, animation root, skeleton and real animation clip are required")
	if not character_root.is_inside_tree() or not skeleton.is_inside_tree():
		return _failure("Attach the isolated character to the scene tree before sampling")
	if not _inside(character_root, animation_root) or not _inside(character_root, skeleton):
		return _failure("Animation root and skeleton must belong to the same character instance")
	var role := String(options.get("role", "prefix"))
	var units = options.get("meters_per_unit", 1.0)
	var margin = options.get("prefix_end_margin", PREFIX_END_MARGIN)
	if role not in ["prefix", "suffix"] or not _number(units) or float(units) <= 0.0 or not _number(margin) or float(margin) < 0.0:
		return _failure("Invalid role, meters_per_unit or prefix_end_margin")
	if not is_finite(clip.length) or clip.length <= 0.0 or not is_finite(lower_trim) or not is_finite(upper_trim):
		return _failure("Clip duration and trim times must be finite")
	if lower_trim < 0.0 or upper_trim <= lower_trim or upper_trim > clip.length:
		return _failure("Expected 0 <= lower_trim < upper_trim <= motion_duration")
	if role == "prefix" and upper_trim > clip.length - float(margin):
		return _failure("Prefix upper trim must be at least %.6f seconds before clip end" % float(margin))
	for child in skeleton.get_children():
		if child is SkeletonModifier3D and child.active:
			return _failure("Bake or disable skeleton modifiers before deterministic sampling")
	var bones := resolve_bones(skeleton, bone_names)
	if not bones.ok:
		return bones
	var filtered := _transform_clip(character_root, animation_root, skeleton, clip)
	if not filtered.ok:
		return filtered
	var root_transform := character_root.global_transform
	if not _valid_basis(root_transform.basis) or not root_transform.origin.is_finite():
		return _failure("Character root has an invalid or reflected world transform")
	var root_meters := root_transform.origin * float(units)
	if not root_meters.is_finite():
		return _failure("Root position overflows the requested meter conversion")
	var saved_bones: Array[Dictionary] = []
	for index in skeleton.get_bone_count():
		saved_bones.append({"position": skeleton.get_bone_pose_position(index),
			"rotation": skeleton.get_bone_pose_rotation(index), "scale": skeleton.get_bone_pose_scale(index)})
	var transforms: Dictionary = filtered.transforms
	var library := AnimationLibrary.new()
	library.add_animation(&"sample", filtered.clip)
	var player := AnimationPlayer.new()
	player.name = "OfflinePoseSampler"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_root.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(&"", library)
	var result := {"ok": true, "params": {
		"root_node_world_pos": _vector(root_meters),
		"root_node_world_rot": _quaternion(root_transform.basis.orthonormalized().get_rotation_quaternion()),
	}, "samples": {}, "bone_names": bones.names, "motion_duration": clip.length,
		"ignored_non_transform_tracks": filtered.ignored,
		"yaw_convention": "atan2(forward.x, forward.z): 0=+Z, +PI/2=+X, PI=-Z, -PI/2=-X"}
	var times := {"at_zero_time": 0.0, "at_lower_trim_time": lower_trim, "at_upper_trim_time": upper_trim}
	var previous_rotation := Quaternion.IDENTITY
	var first := true
	for key in times:
		# Reset sparse channels so a previous seek cannot contaminate the next sample.
		player.stop()
		for node in transforms:
			node.transform = transforms[node]
		skeleton.reset_bone_poses()
		player.play(&"sample")
		player.seek(float(times[key]), true, true)
		skeleton.force_update_all_bone_transforms()
		skeleton.force_update_transform()
		var pelvis := skeleton.global_transform * skeleton.get_bone_global_pose(bones.indices.pelvis)
		var left := skeleton.global_transform * skeleton.get_bone_global_pose(bones.indices.left_hip)
		var right := skeleton.global_transform * skeleton.get_bone_global_pose(bones.indices.right_hip)
		var axis: Vector3 = left.origin - right.origin
		axis.y = 0.0
		if not pelvis.origin.is_finite() or not _valid_basis(pelvis.basis) or not axis.is_finite() or not is_finite(axis.length()) or axis.length() * float(units) < EPSILON:
			result = _failure("Invalid world pelvis transform or degenerate horizontal hip axis at " + key)
			break
		var pelvis_meters := pelvis.origin * float(units)
		var left_meters := left.origin * float(units)
		var right_meters := right.origin * float(units)
		if not pelvis_meters.is_finite() or not left_meters.is_finite() or not right_meters.is_finite():
			result = _failure("World positions overflow the requested meter conversion at " + key)
			break
		var forward := axis.normalized().cross(Vector3.UP).normalized()
		var rotation := pelvis.basis.orthonormalized().get_rotation_quaternion().normalized()
		if not first and previous_rotation.dot(rotation) < 0.0:
			rotation = -rotation
		previous_rotation = rotation
		first = false
		result.params[key] = {"pelvis_world_pos": _vector(pelvis_meters),
			"pelvis_world_rot": _quaternion(rotation),
			"hips_forward_facing_world_yaw": atan2(forward.x, forward.z)}
		result.samples[key] = {"time": times[key], "left_hip_world_pos": _vector(left_meters),
			"right_hip_world_pos": _vector(right_meters), "forward_world": _vector(forward)}
	player.stop()
	player.free()
	for node in transforms:
		node.transform = transforms[node]
	for index in saved_bones.size():
		skeleton.set_bone_pose_position(index, saved_bones[index].position)
		skeleton.set_bone_pose_rotation(index, saved_bones[index].rotation)
		skeleton.set_bone_pose_scale(index, saved_bones[index].scale)
	skeleton.force_update_all_bone_transforms()
	return result


static func _transform_clip(character_root: Node3D, animation_root: Node3D,
		skeleton: Skeleton3D, source: Animation) -> Dictionary:
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_NONE
	var transforms := {}
	var ignored := 0
	for index in range(clip.get_track_count() - 1, -1, -1):
		if not clip.track_is_enabled(index) or clip.track_get_type(index) not in [
			Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			clip.remove_track(index)
			ignored += 1
			continue
		var path := clip.track_get_path(index)
		var target := animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) as Node3D
		if target == null or target == character_root or not _inside(character_root, target):
			return _failure("Unresolved or out-of-character transform track: " + String(path))
		if path.get_subname_count() > 0:
			if target != skeleton or path.get_subname_count() != 1 or skeleton.find_bone(path.get_subname(0)) < 0:
				return _failure("Track must address an existing bone on the selected skeleton: " + String(path))
		else:
			transforms[target] = target.transform
		for key in clip.track_get_key_count(index):
			var value = clip.track_get_key_value(index, key)
			if not is_finite(clip.track_get_key_time(index, key)) or (value is Vector3 and not value.is_finite()) or (value is Quaternion and (not value.is_finite() or not is_finite(value.length_squared()) or value.length_squared() < EPSILON)):
				return _failure("Invalid transform key in " + String(path))
			if value is Quaternion:
				clip.track_set_key_value(index, key, value.normalized())
	if clip.get_track_count() == 0:
		return _failure("Animation has no enabled transform tracks")
	return {"ok": true, "clip": clip, "transforms": transforms, "ignored": ignored}


static func _inside(root: Node, node: Node) -> bool:
	return root == node or root.is_ancestor_of(node)


static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _valid_basis(basis: Basis) -> bool:
	return basis.is_finite() and is_finite(basis.determinant()) and basis.determinant() > 1e-18


static func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _quaternion(value: Quaternion) -> Dictionary:
	value = value.normalized()
	return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
