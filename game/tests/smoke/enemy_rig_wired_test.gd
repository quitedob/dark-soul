extends SceneTree
## Imported enemy rigs must survive both resolver ModelRoot and direct-wrapper paths.
## CPU skin probes prove weighted bone movement, independently of mesh-node transforms.
## Run: godot --headless --path game --script res://tests/smoke/enemy_rig_wired_test.gd
const EnemyRigHook = preload("res://scripts/core/enemy_rig_hook.gd")
const MODEL := "res://assets/models/enemies/01-spirit-ruins/01-Lost-Soul-Soldier.glb"

var _failures: Array[String] = []
var _checked_layouts := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(MODEL) as PackedScene
	if scene == null:
		_failures.append("Cannot load proof enemy: " + MODEL)
	else:
		await _test_layout(scene, false)
		await _test_layout(scene, true)
	_check(EnemyRigHook.ensure_rig(null, "lost_soul_soldier") == null, "Null visual must return null")
	var empty := Node3D.new()
	_check(EnemyRigHook.ensure_rig(empty, "lost_soul_soldier") == null, "Empty visual must return null")
	empty.free()
	_check(_checked_layouts == 2, "Both ModelRoot and direct-wrapper layouts must pass")
	if _failures.is_empty():
		print("ASHEN_ENEMY_RIG_WIRED_OK")
		print("ASHEN_ENEMY_RIG_SKIP_OK")
	else:
		for failure in _failures:
			push_error(failure)
	print("ASHEN_DONE")
	quit(0 if _failures.is_empty() else 1)


func _test_layout(scene: PackedScene, named_container: bool) -> void:
	var label := "ModelRoot" if named_container else "direct wrapper"
	var wrapper := Node3D.new()
	wrapper.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(5, 0.5, 1))
	var model := scene.instantiate() as Node3D
	model.name = "ImportedEnemy"
	model.position = Vector3(0.3, 0.2, -0.4)
	if named_container:
		var container := Node3D.new()
		container.name = "ModelRoot"
		wrapper.add_child(container)
		container.add_child(model)
	else:
		wrapper.add_child(model)
	root.add_child(wrapper)
	await process_frame
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.stop()
	var skeletons := _skeletons(wrapper)
	if not _check(skeletons.size() == 1, label + ": expected one imported skeleton"):
		wrapper.free()
		return
	var original := skeletons[0]
	var meshes := _meshes(model)
	_check(not meshes.is_empty(), label + ": no imported meshes")
	var bindings: Array[Dictionary] = []
	for mesh in meshes:
		bindings.append({"skin": mesh.skin, "mesh": mesh.mesh, "parent": mesh.get_parent(),
			"skeleton": mesh.skeleton, "transform": mesh.global_transform})
		_check(mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == original,
			label + ": missing imported Skin/skeleton binding")
	var rig: Skeleton3D = EnemyRigHook.ensure_rig(wrapper, "lost_soul_soldier")
	if not _check(rig == original, label + ": hook must return existing imported skeleton"):
		wrapper.free()
		return
	_check(EnemyRigHook.ensure_rig(wrapper, "lost_soul_soldier") == original, label + ": hook must be idempotent")
	_check(EnemyRigHook.ensure_rig(wrapper, "immobile_turret") == null, label + ": non-listed enemy must return null")
	_check(_skeletons(wrapper) == skeletons, label + ": hook added/replaced a skeleton")
	var spine := rig.find_bone("spine")
	if _check(spine >= 0 and rig.get_bone_parent(spine) >= 0, label + ": missing non-root spine bone"):
		rig.reset_bone_poses()
		rig.force_update_all_bone_transforms()
		var before := _skin_points(meshes, rig)
		var rest_rotation := rig.get_bone_pose_rotation(spine)
		var wrapper_before := wrapper.global_transform
		var skeleton_before := rig.global_transform
		rig.set_bone_pose_rotation(spine, rest_rotation * Quaternion(Vector3.RIGHT, 0.7))
		rig.force_update_all_bone_transforms()
		var moved := _skin_points(meshes, rig)
		var distance := 0.0
		_check(not before.is_empty() and moved.size() == before.size(), label + ": no comparable weighted probes")
		for index in mini(before.size(), moved.size()):
			distance = maxf(distance, before[index].distance_to(moved[index]))
		_check(distance > 0.02, label + ": non-root rotation did not deform weighted geometry")
		_check(wrapper.global_transform.is_equal_approx(wrapper_before)
			and rig.global_transform.is_equal_approx(skeleton_before), label + ": skin motion came from whole-node motion")
		rig.reset_bone_poses()
		rig.force_update_all_bone_transforms()
		var restored := _skin_points(meshes, rig)
		_check(restored.size() == before.size(), label + ": reset changed probe count")
		for index in mini(before.size(), restored.size()):
			_check(before[index].distance_to(restored[index]) < 0.00001, label + ": reset failed to restore weighted rest pose")
		print("ENEMY_RIG_CPU_MOVEMENT layout=%s probes=%d distance=%.5f" % [label, before.size(), distance])
	for index in meshes.size():
		var mesh := meshes[index]
		var before := bindings[index]
		_check(mesh.skin == before["skin"] and mesh.mesh == before["mesh"], label + ": imported resource identity changed")
		_check(mesh.get_parent() == before["parent"] and mesh.skeleton == before["skeleton"], label + ": imported mesh was reparented/rebound")
		_check(mesh.global_transform.is_equal_approx(before["transform"]), label + ": mesh node moved instead of skin vertices")
	_checked_layouts += 1
	wrapper.free()


func _skin_points(meshes: Array[MeshInstance3D], skeleton: Skeleton3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh in meshes:
		var skin := mesh.skin
		if skin == null or mesh.mesh == null:
			continue
		var matrices: Array[Transform3D] = []
		for bind in skin.get_bind_count():
			var bind_name := skin.get_bind_name(bind)
			var bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(bind)
			if not _check(bone >= 0 and bone < skeleton.get_bone_count(), "Invalid imported Skin bone index"):
				return PackedVector3Array()
			matrices.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			if not _check(arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] != null
					and arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null, "Missing imported skin arrays"):
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if not _check(not vertices.is_empty() and bones.size() == weights.size()
					and bones.size() in [vertices.size() * 4, vertices.size() * 8], "Inconsistent imported skin arrays"):
				continue
			var influences: int = bones.size() / vertices.size()
			var count := mini(4, vertices.size())
			for sample in count:
				var vertex := int(round(float(sample) * float(vertices.size() - 1) / float(count - 1))) if count > 1 else 0
				var point := Vector3.ZERO
				var total := 0.0
				for influence in influences:
					var offset := vertex * influences + influence
					var weight := weights[offset]
					var slot := bones[offset]
					if not _check(slot >= 0 and slot < matrices.size() and is_finite(weight) and weight >= 0.0, "Invalid vertex influence"):
						return PackedVector3Array()
					point += (matrices[slot] * vertices[vertex]) * weight
					total += weight
				_check(absf(total - 1.0) < 0.0002 and point.is_finite(), "Invalid weighted skin position")
				# Inverse binds include the original mesh placement; result above is skeleton-local.
				result.append(skeleton.global_transform * point)
	return result


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
