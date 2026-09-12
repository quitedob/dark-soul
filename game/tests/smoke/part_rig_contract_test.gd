extends SceneTree
## Legacy unskinned PartRigBuilder behavior, independent of the imported skin library.
## Run: godot --headless --path game --script res://tests/smoke/part_rig_contract_test.gd
const PartRigBuilder = preload("res://scripts/core/part_rig_builder.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, 0.45), Vector3(3.0, 0.7, -2.0))
	var body := Node3D.new()
	body.name = "BodyRoot"
	body.transform = Transform3D(Basis(Vector3.UP, -0.2).scaled(Vector3.ONE * 1.25), Vector3(0.4, 0.2, -0.1))
	holder.add_child(body)
	var parts: Array[MeshInstance3D] = [
		_part(body, "pelvis", Vector3(0, 1.2, 0), Vector3(0.6, 0.4, 0.4)),
		_part(body, "torso", Vector3(0, 1.75, 0), Vector3(0.8, 0.7, 0.4)),
		_part(body, "thigh_l", Vector3(-0.3, 0.7, 0), Vector3(0.3, 0.6, 0.3)),
		_part(body, "shin_l", Vector3(-0.3, 0.22, 0), Vector3(0.23, 0.4, 0.23)),
		_part(body, "boot_l", Vector3(-0.3, -0.05, -0.12), Vector3(0.25, 0.16, 0.4)),
		_part(body, "upperarm_l", Vector3(-0.7, 1.6, 0), Vector3(0.25, 0.6, 0.25)),
		_part(body, "forearm_l", Vector3(-0.7, 1.08, 0), Vector3(0.2, 0.42, 0.2)),
		_part(body, "fist_l", Vector3(-0.7, 0.75, 0), Vector3(0.22, 0.22, 0.22)),
		_part(body, "head_mask", Vector3(0, 2.4, 0), Vector3(0.35, 0.4, 0.35)),
	]
	root.add_child(holder)
	await process_frame
	var transforms: Array[Transform3D] = []
	var centers: Array[Vector3] = []
	for part in parts:
		transforms.append(part.global_transform)
		centers.append(_mesh_center(part))
	var skeleton: Skeleton3D = PartRigBuilder.build(body)
	await process_frame
	if skeleton == null:
		_failures.append("Legacy fixture did not produce a rig")
	else:
		_check(body.find_children("*", "Skeleton3D", true, false).size() == 1, "Expected one rigid skeleton")
		for bone: String in ["hips", "spine", "thigh.L", "shin.L", "foot.L", "upper_arm.L", "forearm.L", "hand.L"]:
			_check(skeleton.find_bone(bone) >= 0, "Missing humanoid bone: " + bone)
		for index in parts.size():
			var part := parts[index]
			_check(part.get_parent() is BoneAttachment3D, String(part.name) + ": missing bone attachment")
			_check(part.skin == null, String(part.name) + ": rigid fixture unexpectedly skinned")
			_check(part.global_transform.is_equal_approx(transforms[index]), String(part.name) + ": bind transform changed")
			_check(_mesh_center(part).distance_to(centers[index]) < 0.00001, String(part.name) + ": bind center changed")
		var thigh := skeleton.find_bone("thigh.L")
		if thigh >= 0:
			# The thigh box's proximal corner toward the pelvis is body-local (-.15, 1, 0).
			_check(skeleton.get_bone_global_rest(thigh).origin.distance_to(Vector3(-0.15, 1.0, 0)) < 0.00001,
				"Thigh rest joint is not the proximal mesh-bound point")
			skeleton.set_bone_pose_rotation(thigh, Quaternion(Vector3.RIGHT, 0.8))
			await process_frame
			var movement := _mesh_center(parts[2]).distance_to(centers[2])
			_check(movement > 0.02, "Rotating thigh did not move its mesh center")
			_check(_mesh_center(parts[4]).distance_to(centers[4]) > 0.02, "Thigh rotation did not propagate to its foot")
			skeleton.reset_bone_poses()
			await process_frame
			for index in parts.size():
				_check(parts[index].global_transform.is_equal_approx(transforms[index]),
					String(parts[index].name) + ": reset did not restore bind transform")
			print("PART_RIG_MOVEMENT distance=%.5f" % movement)
	holder.free()
	_finish()


func _part(parent: Node3D, part_name: String, position: Vector3, size: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Mesh centers deliberately differ from node origins, as in exported GLBs.
	var mesh_offset := Vector3(0.03, 0.04, 0.02)
	for index in vertices.size():
		vertices[index] += mesh_offset
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = position - mesh_offset
	parent.add_child(part)
	return part


func _mesh_center(instance: MeshInstance3D) -> Vector3:
	return instance.global_transform * instance.mesh.get_aabb().get_center()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_PART_RIG_MOVE_OK")
		print("ASHEN_PART_RIG_OK")
	else:
		for failure in _failures:
			push_error(failure)
	print("ASHEN_DONE")
	quit(0 if _failures.is_empty() else 1)
