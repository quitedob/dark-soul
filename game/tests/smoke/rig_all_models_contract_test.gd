extends SceneTree
## All registered GLBs now carry imported skins. Keep their original skeleton,
## mesh bindings, resources, and rest pose intact, including the adaptive enemy hook.
## Legacy rigid-part construction is covered by part_rig_contract_test.gd.
## Run: godot --headless --path game --script res://tests/smoke/rig_all_models_contract_test.gd
const Resolver = preload("res://scripts/core/real_model_resolver.gd")
const EnemyRigHook = preload("res://scripts/core/enemy_rig_hook.gd")

var _failures: Array[String] = []
var _checked_models := 0
var _checked_meshes := 0
var _checked_hooks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths: Dictionary = {}
	var hooked_paths: Dictionary = {}
	for key: String in Resolver.REGISTRY:
		var entry: Dictionary = Resolver.REGISTRY[key]
		var path := String(entry.get("path", ""))
		if path.is_empty():
			continue
		paths[path] = true
		var enemy_id := key.trim_prefix("enemy/body/by_id/")
		if key.begins_with("enemy/body/by_id/") and EnemyRigHook.RIGGABLE_ENEMY_IDS.has(enemy_id):
			hooked_paths[path] = enemy_id
	_check(not paths.is_empty(), "Registry must contain models")
	for path: String in paths:
		await _test_one(path, String(hooked_paths.get(path, "")))
	_check(_checked_models == paths.size(), "Every registered model must preserve its imported rig")
	_check(_checked_hooks == EnemyRigHook.RIGGABLE_ENEMY_IDS.size(), "Every whitelisted enemy hook must be covered")
	print("RIG_ALL_SUMMARY skinned=%d meshes=%d enemy_hooks=%d total=%d" %
		[_checked_models, _checked_meshes, _checked_hooks, paths.size()])
	if _failures.is_empty():
		print("ASHEN_RIG_ALL_OK")
	else:
		for failure in _failures:
			push_error(failure)
	print("ASHEN_DONE")
	quit(0 if _failures.is_empty() else 1)


func _test_one(path: String, enemy_id: String) -> void:
	var scene := load(path) as PackedScene
	if not _check(scene != null, "Load failed: " + path):
		return
	var model := scene.instantiate() as Node3D
	if not _check(model != null, "Model is not Node3D: " + path):
		return
	model.transform = Transform3D(Basis(Vector3.UP, 0.37), Vector3(3, 0.5, -2))
	root.add_child(model)
	await process_frame
	var skeletons := _skeletons(model)
	if not _check(skeletons.size() == 1, "Expected exactly one imported skeleton: " + path):
		model.free()
		return
	var original := skeletons[0]
	_check(original.get_bone_count() > 0, "Empty skeleton: " + path)
	var rests: Array[Transform3D] = []
	var poses: Array[Transform3D] = []
	for bone in original.get_bone_count():
		rests.append(original.get_bone_rest(bone))
		poses.append(original.get_bone_pose(bone))
		_check(rests[bone].is_finite() and poses[bone].is_finite(), "Invalid imported bone transform: " + path)
	var meshes := _meshes(model)
	_check(not meshes.is_empty(), "No imported meshes: " + path)
	var bindings: Array[Dictionary] = []
	for mesh in meshes:
		bindings.append({"mesh": mesh.mesh, "skin": mesh.skin, "parent": mesh.get_parent(),
			"skeleton": mesh.skeleton, "transform": mesh.global_transform})
		_check(mesh.mesh != null and mesh.skin != null, "Mesh lost imported mesh/Skin: " + path)
		_check(mesh.get_node_or_null(mesh.skeleton) == original, "Mesh does not resolve imported skeleton: " + path)
		if mesh.skin != null:
			_check(mesh.skin.get_bind_count() > 0, "Empty Skin bindings: " + path)
			for bind in mesh.skin.get_bind_count():
				var bind_name := mesh.skin.get_bind_name(bind)
				var bone := original.find_bone(bind_name) if not bind_name.is_empty() else mesh.skin.get_bind_bone(bind)
				_check(bone >= 0 and bone < original.get_bone_count() and mesh.skin.get_bind_pose(bind).is_finite(),
					"Invalid Skin bone/rest binding: " + path)
	if not enemy_id.is_empty():
		_check(EnemyRigHook.ensure_rig(model, enemy_id) == original, "Hook replaced or lost imported skeleton: " + path)
		_check(EnemyRigHook.ensure_rig(model, enemy_id) == original, "Hook was not idempotent: " + path)
		_checked_hooks += 1
	await process_frame
	_check(_skeletons(model) == skeletons, "Added/replaced imported skeleton: " + path)
	_check(_meshes(model) == meshes, "Replaced imported mesh nodes: " + path)
	for index in meshes.size():
		var mesh := meshes[index]
		var before := bindings[index]
		_check(mesh.mesh == before["mesh"] and mesh.skin == before["skin"], "Changed imported Mesh/Skin identity: " + path)
		_check(mesh.get_parent() == before["parent"] and mesh.skeleton == before["skeleton"], "Reparented/rebound imported mesh: " + path)
		_check(mesh.global_transform.is_equal_approx(before["transform"]), "Changed imported bind transform: " + path)
	_check(original.get_bone_count() == rests.size(), "Changed imported bone count: " + path)
	for bone in mini(original.get_bone_count(), rests.size()):
		_check(original.get_bone_rest(bone).is_equal_approx(rests[bone]), "Changed imported bone rest: " + path)
		_check(original.get_bone_pose(bone).is_equal_approx(poses[bone]), "Changed imported bone pose: " + path)
	_checked_models += 1
	_checked_meshes += meshes.size()
	print("SKINNED %s bones=%d meshes=%d" % [path.get_file(), original.get_bone_count(), meshes.size()])
	model.free()


func _skeletons(node: Node) -> Array[Skeleton3D]:
	var result: Array[Skeleton3D] = []
	if node is Skeleton3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_skeletons(child))
	return result


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result


func _check(condition: bool, label: String) -> bool:
	if not condition:
		_failures.append(label)
	return condition
