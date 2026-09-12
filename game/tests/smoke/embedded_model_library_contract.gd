extends SceneTree
## Actual res:// imports, independent of the staged GLB validator. No gameplay/save state.
## CPU skin probes prove imported bind/pose data, not rendering-server or visual quality.

const Embedded = preload("res://scripts/core/embedded_model_actions.gd")
const Resolver = preload("res://scripts/core/real_model_resolver.gd")
const SUCCESS_MARKER := "ASHEN_EMBEDDED_MODEL_LIBRARY_CONTRACTS_OK"
const EXPECTED_MODELS := 86
const EXPECTED_CLIPS := 761
const FRACTIONS := [0.2, 0.4, 0.6, 0.8]
const PART_CASES := {
	"player/weapon/sword": "sword_slash",
	"player/shield": "shield_bash",
	"player/weapon/axe_left": "left_strike",
	"player/weapon/axe_right": "right_strike",
}

var _failures: Array[String] = []
var _models: Dictionary = {}
var _checked_models := 0
var _checked_clips := 0
var _checked_meshes := 0
var _deformed_clips := 0
var _checked_parts := 0
var _checked_jars := 0
var _isolation_checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Embedded.MANIFEST_PATH))
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("models") is Dictionary:
		_expect(false, "Missing/invalid model_actions.json v1 manifest")
		_finish()
		return
	_models = parsed["models"]
	_expect(_models.size() == EXPECTED_MODELS, "Manifest must contain all %d models" % EXPECTED_MODELS)
	var paths: Array = _models.keys()
	paths.sort()
	for relative: String in paths:
		await _test_model(relative, _models[relative])
	for id: String in PART_CASES:
		await _test_resolver_part(id, PART_CASES[id])
	await _test_jar()
	await _test_instance_isolation()
	_expect(_checked_models == EXPECTED_MODELS, "Imported model coverage: %d/%d" % [_checked_models, EXPECTED_MODELS])
	_expect(_checked_clips == EXPECTED_CLIPS, "Imported clip coverage: %d/%d" % [_checked_clips, EXPECTED_CLIPS])
	_expect(_checked_parts == 4, "All four resolver sub_node entries must pass")
	_expect(_checked_jars == 1, "Production destructible jar selection must pass")
	_finish()


func _test_model(relative: String, entry: Dictionary) -> void:
	var scene := load(Embedded.MODEL_PREFIX + relative) as PackedScene
	if not _expect(scene != null, relative + ": PackedScene import missing"):
		return
	var instance := scene.instantiate() as Node3D
	var wrapper := Node3D.new()
	wrapper.add_child(instance)
	root.add_child(wrapper)
	await process_frame
	var skeleton := _skeleton(instance, relative)
	var meshes := _meshes(instance)
	var records := _inspect_meshes(meshes, skeleton, relative)
	var driver: Node = Embedded.bind(wrapper, instance, relative)
	var player := _player(wrapper)
	if driver == null or player == null or skeleton == null:
		_expect(false, relative + ": imported model must bind EmbeddedModelActions")
		wrapper.free()
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_expect(Embedded.bind(wrapper, instance, relative) == driver, relative + ": binding must be idempotent")
	var actions: Array = entry.get("actions", [])
	var expected: Array[String] = []
	for action: Dictionary in actions:
		expected.append(String(action["name"]))
	var imported: Array[String] = []
	for name in player.get_animation_list():
		if String(name).get_file() != "RESET":
			imported.append(String(name).get_file())
	expected.sort()
	imported.sort()
	_expect(expected == imported, relative + ": imported clip inventory differs from manifest")
	var default_action := String(entry.get("default_action", ""))
	if default_action.is_empty():
		_expect(not player.is_playing(), relative + ": no-default model must remain at rest")
	else:
		_expect(String(player.assigned_animation).get_file() == default_action,
			relative + ": binding must start the manifest default")
	var representative := String(entry.get("special_action", ""))
	if representative.is_empty() and not actions.is_empty():
		representative = String(actions[0]["name"])
	for action: Dictionary in actions:
		var name := String(action["name"])
		var clip := _clip(player, name)
		if not _expect(not clip.is_empty(), relative + ": missing clip " + name):
			continue
		var animation := player.get_animation(clip)
		_expect(absf(animation.length - float(action["duration"])) < 0.0002,
			relative + "/" + name + ": imported duration differs")
		var loop := Animation.LOOP_LINEAR if bool(action["loop"]) else Animation.LOOP_NONE
		_expect(animation.loop_mode == loop, relative + "/" + name + ": loop policy differs")
		var deform := name == default_action or name == representative
		_test_motion(wrapper, player, skeleton, records, action, relative, deform)
		_checked_clips += 1
	if default_action.is_empty() and not actions.is_empty():
		# Mechanical props stay at the completed pose until another interaction;
		# finishing a one-shot must not repeatedly open or activate the prop.
		Embedded.reset(wrapper)
		var action: Dictionary = actions[0]
		Embedded.play_action(wrapper, String(action["name"]), true)
		player.advance(float(action["duration"]) + 0.1)
		_expect(not player.is_playing(), relative + ": completed interaction must not repeat")
		var end_pose := _poses(skeleton)
		player.advance(0.2)
		_expect(end_pose == _poses(skeleton), relative + ": completed interaction must hold its pose")
	_checked_models += 1
	_checked_meshes += meshes.size()
	wrapper.free()


func _test_motion(wrapper: Node3D, player: AnimationPlayer, skeleton: Skeleton3D,
		records: Array[Dictionary], action: Dictionary, label: String, deform: bool) -> void:
	var name := String(action["name"])
	label += "/" + name
	Embedded.reset(wrapper)
	skeleton.reset_bone_poses()
	if not _expect(Embedded.play_action(wrapper, name, true), label + ": exact action request failed"):
		return
	player.advance(0.0)
	player.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	var initial := _poses(skeleton)
	var bone_motion := false
	var vertex_motion := false
	var finite := true
	for sample in FRACTIONS.size():
		var sample_time := float(action["duration"]) * float(FRACTIONS[sample])
		if sample == 0:
			player.advance(sample_time)
		else:
			player.seek(sample_time, true)
		skeleton.force_update_all_bone_transforms()
		var current := _poses(skeleton)
		for bone in skeleton.get_bone_count():
			var pose: Transform3D = current[bone]
			finite = finite and pose.is_finite() and skeleton.get_bone_global_pose(bone).is_finite()
			if skeleton.get_bone_parent(bone) >= 0 and not pose.is_equal_approx(initial[bone]):
				bone_motion = true
		if deform and not vertex_motion and finite:
			var posed := _skin_points(skeleton, records)
			# Freeze only non-root local poses at t=0: root motion cannot
			# masquerade as deformation in this contribution comparison.
			_restore_nonroot(skeleton, initial)
			var frozen := _skin_points(skeleton, records)
			_restore_nonroot(skeleton, current)
			for index in posed.size():
				finite = finite and posed[index].is_finite() and frozen[index].is_finite()
				if posed[index].distance_squared_to(frozen[index]) > 0.000000000001:
					vertex_motion = true
	_expect(finite, label + ": sampled bone/skin positions must stay finite")
	_expect(bone_motion, label + ": seek must change a non-root local bone pose")
	if deform:
		if _expect(vertex_motion, label + ": imported weighted vertices need non-root motion"):
			_deformed_clips += 1


func _inspect_meshes(meshes: Array[MeshInstance3D], skeleton: Skeleton3D, label: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if skeleton == null:
		return records
	_expect(not meshes.is_empty(), label + ": model has no geometry")
	for instance in meshes:
		var skin := instance.skin
		if not _expect(skin != null and instance.get_node_or_null(instance.skeleton) == skeleton,
				label + "/" + String(instance.name) + ": mesh must retain its shared skeleton"):
			continue
		var bind_bones: Array[int] = []
		var valid := true
		for bind in skin.get_bind_count():
			var bind_name := skin.get_bind_name(bind)
			var bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(bind)
			valid = valid and bone >= 0 and bone < skeleton.get_bone_count() and skin.get_bind_pose(bind).is_finite()
			bind_bones.append(bone)
		if not _expect(valid and not bind_bones.is_empty(), label + ": invalid imported Skin bind"):
			continue
		var points: Array[Dictionary] = []
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			if not _expect(arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] != null
					and arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null,
					label + ": imported geometry lacks skin arrays"):
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if not _expect(not vertices.is_empty() and weights.size() == bones.size()
					and bones.size() in [vertices.size() * 4, vertices.size() * 8],
					label + ": inconsistent imported vertex/skin arrays"):
				continue
			var influences: int = bones.size() / vertices.size()
			# Four distributed vertices per surface keep the full-library runtime bounded.
			for sample in mini(4, vertices.size()):
				var vertex := int(round(float(sample) * float(vertices.size() - 1) / float(mini(4, vertices.size()) - 1))) if vertices.size() > 1 else 0
				var slots: Array[int] = []
				var positive: Array[float] = []
				var total := 0.0
				valid = vertices[vertex].is_finite()
				for influence in influences:
					var offset := vertex * influences + influence
					var weight := weights[offset]
					valid = valid and is_finite(weight) and weight >= 0.0 and bones[offset] >= 0 and bones[offset] < bind_bones.size()
					total += weight
					if weight > 0.0:
						slots.append(bones[offset])
						positive.append(weight)
				if _expect(valid and absf(total - 1.0) < 0.0002, label + ": invalid sampled vertex weights"):
					points.append({"position": vertices[vertex], "slots": slots, "weights": positive})
		records.append({"instance": instance, "bones": bind_bones, "points": points})
	return records


func _skin_points(skeleton: Skeleton3D, records: Array[Dictionary]) -> PackedVector3Array:
	var result := PackedVector3Array()
	for record in records:
		var instance: MeshInstance3D = record["instance"]
		var skin := instance.skin
		var matrices: Array[Transform3D] = []
		# Output is skeleton-local; imported inverse bind matrices already encode
		# each mesh's bind placement. This is the existing verifier's CPU path.
		for bind in skin.get_bind_count():
			matrices.append(skeleton.get_bone_global_pose(record["bones"][bind]) * skin.get_bind_pose(bind))
		for point: Dictionary in record["points"]:
			var position := Vector3.ZERO
			for influence in point["slots"].size():
				position += (matrices[point["slots"][influence]] * (point["position"] as Vector3)) * float(point["weights"][influence])
			result.append(position)
	return result


func _poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(bone))
	return result


func _restore_nonroot(skeleton: Skeleton3D, poses: Array[Transform3D]) -> void:
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone) < 0:
			continue
		var pose := poses[bone]
		skeleton.set_bone_pose_position(bone, pose.origin)
		skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()


func _test_resolver_part(id: String, action_name: String) -> void:
	var host := Node3D.new()
	host.position = Vector3(2.0, 1.0, -3.0)
	host.rotation.y = 0.7
	root.add_child(host)
	if not _expect(Resolver.try_instance(id, host), id + ": production resolver failed"):
		host.free()
		return
	await process_frame
	var entry: Dictionary = Resolver.REGISTRY[id]
	var relative := String(entry["path"]).trim_prefix(Embedded.MODEL_PREFIX)
	var model_entry: Dictionary = _models.get(relative, {})
	var definition: Dictionary = model_entry.get("parts", {}).get(entry["sub_node"], {})
	var skeleton := _skeleton(host, id)
	var selected := _assert_selection(host, skeleton, String(definition.get("bone", "")), id)
	var player := _player(host)
	_expect(Embedded.available(host), id + ": selected weapon must retain embedded driver")
	var origin := host.find_child("PartOrigin", true, false) as Node3D
	var matrix: Array = definition.get("transform", [])
	if _expect(origin != null and matrix.size() == 16, id + ": missing manifest part-origin transform"):
		var anchor := Transform3D(Basis(Vector3(matrix[0], matrix[1], matrix[2]),
			Vector3(matrix[4], matrix[5], matrix[6]), Vector3(matrix[8], matrix[9], matrix[10])),
			Vector3(matrix[12], matrix[13], matrix[14]))
		_expect((origin.transform * anchor).is_equal_approx(Transform3D.IDENTITY), id + ": selection origin must cancel original group anchor")
	if player != null and skeleton != null and not selected.is_empty():
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var action := _action(model_entry, action_name)
		if _expect(not action.is_empty(), id + ": missing selected-part action"):
			var records := _inspect_meshes(selected, skeleton, id)
			_test_motion(host, player, skeleton, records, action, id, true)
			_checked_parts += 1
	host.free()


func _assert_selection(host: Node, skeleton: Skeleton3D, branch: String, label: String) -> Array[MeshInstance3D]:
	var selected: Array[MeshInstance3D] = []
	if skeleton == null:
		return selected
	var branch_index := skeleton.find_bone(branch)
	if not _expect(branch_index >= 0, label + ": selected part bone missing: " + branch):
		return selected
	var hidden := 0
	for instance in _meshes(host):
		if not _expect(instance.skin != null and instance.get_node_or_null(instance.skeleton) == skeleton,
				label + ": selection detached or lost the shared skeleton"):
			continue
		var inside := false
		var outside := false
		var skin := instance.skin
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for offset in weights.size():
				if weights[offset] <= 0.0:
					continue
				var bind := bones[offset]
				if not _expect(bind >= 0 and bind < skin.get_bind_count(), label + ": invalid selection bind"):
					continue
				var bind_name := skin.get_bind_name(bind)
				var bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(bind)
				while bone >= 0 and bone != branch_index:
					bone = skeleton.get_bone_parent(bone)
				inside = inside or bone == branch_index
				outside = outside or bone != branch_index
		_expect(not (inside and outside), label + ": a mesh mixes selected and unselected geometry")
		_expect(instance.is_visible_in_tree() == inside, label + ": visibility differs from weighted branch membership")
		if inside:
			selected.append(instance)
		else:
			hidden += 1
	_expect(not selected.is_empty() and hidden > 0, label + ": selection must retain part and hide other geometry")
	_expect(skeleton.is_visible_in_tree(), label + ": shared skeleton was hidden")
	return selected


func _test_jar() -> void:
	var scene := load("res://scenes/props/destructible_jar.tscn") as PackedScene
	if not _expect(scene != null, "Production destructible jar scene missing"):
		return
	var jar := scene.instantiate() as Node3D
	root.add_child(jar)
	await process_frame
	var model := jar.get_node_or_null("Model") as Node3D
	var skeleton := _skeleton(jar, "destructible jar")
	var entry: Dictionary = _models.get("props/07-Pickups.glb", {})
	var part := String(jar.get("part_group"))
	var definition: Dictionary = entry.get("parts", {}).get(part, {})
	var selected := _assert_selection(jar, skeleton, String(definition.get("bone", "")), "destructible jar")
	_expect(part == "pillJar", "Production jar must select its actual pillJar part")
	_expect(model != null and Embedded.available(model), "Production jar must bind its imported model")
	var collisions := jar.find_children("*", "CollisionShape3D", true, false)
	_expect(collisions.size() == 1 and (collisions[0] as CollisionShape3D).shape is BoxShape3D,
		"Production jar must build one box from selected geometry")
	var player := _player(jar)
	if player != null and skeleton != null and not selected.is_empty():
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var action := _action(entry, "cork_open")
		if _expect(not action.is_empty(), "Jar cork_open action missing"):
			_test_motion(model, player, skeleton, _inspect_meshes(selected, skeleton, "jar"), action, "jar", true)
			_checked_jars += 1
	jar.free()


func _test_instance_isolation() -> void:
	var relative := "weapons/templateweapons.glb"
	var scene := load(Embedded.MODEL_PREFIX + relative) as PackedScene
	if not _expect(scene != null, "Isolation fixture import missing"):
		return
	var first := scene.instantiate() as Node3D
	var second := scene.instantiate() as Node3D
	root.add_child(first)
	root.add_child(second)
	await process_frame
	Embedded.bind(first, first, relative)
	Embedded.bind(second, second, relative)
	var a := _player(first)
	var b := _player(second)
	if a == null or b == null:
		_expect(false, "Both imported instances must bind for resource isolation")
		first.free()
		second.free()
		return
	a.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	b.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip := _clip(a, "idle")
	var animation_a := a.get_animation(clip)
	var animation_b := b.get_animation(_clip(b, "idle"))
	_expect(animation_a != animation_b, "Imported Animation resources must be private per bound instance")
	animation_a.loop_mode = Animation.LOOP_NONE
	_expect(animation_b.loop_mode == Animation.LOOP_LINEAR, "One instance's loop change leaked")
	b.seek(0.17, true)
	var cursor := b.current_animation_position
	var bone := _skeleton(second, "isolation second")
	var before := _poses(bone) if bone != null else []
	Embedded.play_action(first, "sword_slash", true)
	a.advance(0.31)
	Embedded.set_speed(first, 0.25)
	Embedded.reset(first)
	_expect(is_equal_approx(b.current_animation_position, cursor) and is_equal_approx(b.speed_scale, 1.0),
		"Playback/reset/speed leaked across imported instances")
	if bone != null:
		var after := _poses(bone)
		_expect(before == after, "Skeleton poses leaked across imported instances")
	_isolation_checks += 1
	first.free()
	second.free()


func _skeleton(node: Node, label: String) -> Skeleton3D:
	var found := node.find_children("*", "Skeleton3D", true, false)
	if not _expect(found.size() == 1, label + ": expected exactly one retained Skeleton3D"):
		return null
	var skeleton := found[0] as Skeleton3D
	_expect(skeleton.get_bone_count() > 1, label + ": empty skeleton")
	return skeleton


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() > 0:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result


func _player(node: Node) -> AnimationPlayer:
	var found := node.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if found.size() == 1 else null


func _clip(player: AnimationPlayer, name: String) -> String:
	var result := ""
	for candidate in player.get_animation_list():
		if String(candidate).get_file() == name:
			if not result.is_empty():
				return ""
			result = String(candidate)
	return result


func _action(entry: Dictionary, name: String) -> Dictionary:
	for action: Dictionary in entry.get("actions", []):
		if String(action.get("name", "")) == name:
			return action
	return {}


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failures.append(label)
	return condition


func _finish() -> void:
	print("EMBEDDED_MODEL_LIBRARY_COUNTS models=%d clips=%d meshes=%d deformed_clips=%d parts=%d jars=%d isolation=%d" %
		[_checked_models, _checked_clips, _checked_meshes, _deformed_clips, _checked_parts, _checked_jars, _isolation_checks])
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
