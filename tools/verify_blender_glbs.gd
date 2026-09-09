extends SceneTree

# Direct GLB import only: no editor import, resource saves, or game asset copies.
# godot --headless --path game --script <this-file> -- <absolute-glb-directory>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0].is_absolute_path():
		print("ASHEN_BLENDER_GLB_IMPORT_FAILED: expected one absolute GLB directory after --")
		quit(1)
		return
	var method_available := false
	for method in ClassDB.class_get_method_list("MeshInstance3D", true):
		if method.name == "bake_mesh_from_current_skeleton_pose":
			method_available = true
	if not method_available:
		print("ASHEN_BLENDER_GLB_IMPORT_FAILED: this Godot lacks skeletal mesh baking")
		quit(1)
		return
	var files: Array[String] = []
	var directory_errors: Array[String] = []
	_collect_glbs(arguments[0], files, directory_errors)
	files.sort()
	if files.is_empty() or not directory_errors.is_empty():
		print("ASHEN_BLENDER_GLB_IMPORT_FAILED: ", JSON.stringify({"files": files.size(), "directory_errors": directory_errors}))
		quit(1)
		return
	var failed := 0
	var mesh_count := 0
	var skeleton_count := 0
	var vertex_count := 0
	for file in files:
		var result: Dictionary = await _verify_model(file)
		mesh_count += result.meshes
		skeleton_count += result.skeletons
		vertex_count += result.vertices
		if not result.errors.is_empty():
			failed += 1
		print("ASHEN_BLENDER_GLB_MODEL ", JSON.stringify(result))
	var summary := {"count": files.size(), "passed": files.size() - failed, "failed": failed, "mesh_instances": mesh_count, "skeletons": skeleton_count, "vertices": vertex_count}
	print("ASHEN_BLENDER_GLB_IMPORT_OK " if failed == 0 else "ASHEN_BLENDER_GLB_IMPORT_FAILED ", JSON.stringify(summary))
	quit(0 if failed == 0 else 1)


func _collect_glbs(directory: String, files: Array[String], errors: Array[String]) -> void:
	var access := DirAccess.open(directory)
	if access == null:
		errors.append("Cannot open %s: %s" % [directory, error_string(DirAccess.get_open_error())])
		return
	for name in access.get_files():
		if name.to_lower().ends_with(".glb"):
			files.append(directory.path_join(name))
	for name in access.get_directories():
		_collect_glbs(directory.path_join(name), files, errors)


func _collect_nodes(node: Node, skeletons: Array[Skeleton3D], meshes: Array[MeshInstance3D]) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is MeshInstance3D and node.mesh != null:
		meshes.append(node)
	for child in node.get_children():
		_collect_nodes(child, skeletons, meshes)


func _verify_model(file: String) -> Dictionary:
	var result := {"file": file, "meshes": 0, "skeletons": 0, "vertices": 0, "errors": [], "pose_proofs": []}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	# Keep images in memory; explicitly prevent extraction beside the GLB or into game/.
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	state.use_named_skin_binds = true
	var error := document.append_from_file(file, state)
	if error != OK:
		result.errors.append("GLTFDocument.append_from_file: " + error_string(error))
		return result
	var scene := document.generate_scene(state)
	if scene == null:
		result.errors.append("GLTFDocument.generate_scene returned null")
		return result
	root.add_child(scene)
	await process_frame
	var skeletons: Array[Skeleton3D] = []
	var meshes: Array[MeshInstance3D] = []
	_collect_nodes(scene, skeletons, meshes)
	result.meshes = meshes.size()
	result.skeletons = skeletons.size()
	if skeletons.is_empty():
		result.errors.append("Imported scene contains no Skeleton3D")
	if meshes.is_empty():
		result.errors.append("Imported scene contains no mesh instances")
	var records: Array[Dictionary] = []
	for instance in meshes:
		var record := _inspect_mesh(instance)
		if record.has("error"):
			result.errors.append("%s: %s" % [instance.name, record.error])
		else:
			records.append(record)
			result.vertices += record.vertices
	if result.errors.is_empty():
		for skeleton in skeletons:
			var bound: Array[Dictionary] = []
			for record in records:
				if record.skeleton == skeleton:
					bound.append(record)
			var proof: Dictionary = await _prove_pose(skeleton, bound)
			result.pose_proofs.append(proof)
			if proof.has("error"):
				result.errors.append("%s: %s" % [skeleton.name, proof.error])
	root.remove_child(scene)
	scene.free()
	await process_frame
	return result


func _inspect_mesh(instance: MeshInstance3D) -> Dictionary:
	var skin := instance.skin
	if skin == null or skin.get_bind_count() < 2:
		return {"error": "Missing Skin or fewer than two binds"}
	if instance.skeleton.is_empty():
		return {"error": "Empty skeleton NodePath"}
	var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() < 2:
		return {"error": "Skeleton NodePath does not resolve to a populated Skeleton3D"}
	var bind_bones: Array[int] = []
	for bind in skin.get_bind_count():
		var bind_name := skin.get_bind_name(bind)
		var bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(bind)
		if bone < 0 or bone >= skeleton.get_bone_count():
			return {"error": "Skin bind %s cannot resolve its skeleton bone" % bind}
		var transform := skin.get_bind_pose(bind)
		if not transform.is_finite() or absf(transform.basis.determinant()) < 1e-20:
			return {"error": "Skin bind %s has invalid inverse bind transform" % bind}
		bind_bones.append(bone)
	var record := {"instance": instance, "skeleton": skeleton, "vertices": 0, "mass": {}, "blended_mass": {}}
	if instance.mesh.get_surface_count() == 0:
		return {"error": "Mesh has no surfaces"}
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			return {"error": "Surface %s lacks vertex, bone, or weight arrays" % surface}
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if positions.is_empty() or bones.size() != weights.size() or bones.size() % positions.size() != 0:
			return {"error": "Surface %s has inconsistent skin array counts" % surface}
		var influences: int = bones.size() / positions.size()
		if influences != 4 and influences != 8:
			return {"error": "Surface %s has %s influences per vertex" % [surface, influences]}
		record.vertices += positions.size()
		for vertex in positions.size():
			if not positions[vertex].is_finite():
				return {"error": "Non-finite vertex position"}
			var total := 0.0
			var positive: Dictionary = {}
			for influence in influences:
				var offset := vertex * influences + influence
				var slot := bones[offset]
				var weight := weights[offset]
				if slot < 0 or slot >= bind_bones.size() or not is_finite(weight) or weight < 0.0 or weight > 1.0:
					return {"error": "Surface %s vertex %s has invalid bone index or weight" % [surface, vertex]}
				total += weight
				if weight > 0.0:
					var bone := bind_bones[slot]
					positive[bone] = float(positive.get(bone, 0.0)) + weight
					record.mass[bone] = float(record.mass.get(bone, 0.0)) + weight
			if absf(total - 1.0) > 0.0001:
				return {"error": "Surface %s vertex %s has weight sum %s" % [surface, vertex, total]}
			if positive.size() > 1:
				for bone in positive:
					record.blended_mass[bone] = float(record.blended_mass.get(bone, 0.0)) + positive[bone]
	return record


func _baked_positions(instance: MeshInstance3D) -> Array[PackedVector3Array]:
	# The dummy rendering server in --headless does not register a SkinReference.
	# Evaluate the engine-imported Skin/Skeleton data explicitly in that mode.
	# This proves import and deformation math, not rendering-server/GPU execution.
	if DisplayServer.get_name() == "headless":
		return _cpu_skin_positions(instance)
	var surfaces: Array[PackedVector3Array] = []
	var baked := instance.bake_mesh_from_current_skeleton_pose()
	if baked == null:
		return surfaces
	for surface in baked.get_surface_count():
		surfaces.append(baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return surfaces


func _cpu_skin_positions(instance: MeshInstance3D) -> Array[PackedVector3Array]:
	var surfaces: Array[PackedVector3Array] = []
	var skeleton := instance.get_node(instance.skeleton) as Skeleton3D
	var skin := instance.skin
	var matrices: Array[Transform3D] = []
	var mesh_from_skeleton := instance.global_transform.affine_inverse() * skeleton.global_transform
	for bind in skin.get_bind_count():
		var bind_name := skin.get_bind_name(bind)
		var bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(bind)
		matrices.append(mesh_from_skeleton * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = weights.size() / vertices.size()
		var posed := PackedVector3Array()
		posed.resize(vertices.size())
		for vertex in vertices.size():
			var position := Vector3.ZERO
			for influence in influences:
				var offset := vertex * influences + influence
				position += (matrices[bones[offset]] * vertices[vertex]) * weights[offset]
			posed[vertex] = position
		surfaces.append(posed)
	return surfaces


func _prove_pose(skeleton: Skeleton3D, records: Array[Dictionary]) -> Dictionary:
	var proof := {"skeleton": str(skeleton.name), "bones": skeleton.get_bone_count(), "bound_meshes": records.size(),
		"pose_method": "cpu_imported_skin" if DisplayServer.get_name() == "headless" else "engine_mesh_bake"}
	var selected := -1
	var best_score := -1.0
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone) < 0:
			continue
		var mass := 0.0
		var blended_mass := 0.0
		for record in records:
			mass += record.mass.get(bone, 0.0)
			blended_mass += record.blended_mass.get(bone, 0.0)
		var score := blended_mass * 1000000.0 + mass
		if mass > 0.0 and score > best_score:
			best_score = score
			selected = bone
	if selected < 0:
		proof.error = "No weighted non-root bone"
		return proof
	skeleton.force_update_all_bone_transforms()
	await process_frame
	var baseline: Array = []
	var scale := 0.000001
	for record in records:
		var instance: MeshInstance3D = record.instance
		var surfaces := _baked_positions(instance)
		if surfaces.size() != instance.mesh.get_surface_count():
			proof.error = "Rest-pose baking returned missing surfaces"
			return proof
		baseline.append(surfaces)
		scale = maxf(scale, instance.get_aabb().size.length())
	var original_rotation := skeleton.get_bone_pose_rotation(selected)
	skeleton.set_bone_pose_rotation(selected, original_rotation * Quaternion(Vector3(1.0, 0.7, 0.3).normalized(), 0.3))
	skeleton.force_update_all_bone_transforms()
	await process_frame
	var max_displacement := 0.0
	var moved_vertices := 0
	for mesh_index in records.size():
		var instance: MeshInstance3D = records[mesh_index].instance
		var posed := _baked_positions(instance)
		var rest: Array = baseline[mesh_index]
		if posed.size() != rest.size():
			proof.error = "Posed baking changed surface counts"
			break
		for surface in posed.size():
			if posed[surface].size() != rest[surface].size():
				proof.error = "Posed baking changed vertex counts"
				break
			for vertex in posed[surface].size():
				if not posed[surface][vertex].is_finite():
					proof.error = "Posed baking produced non-finite vertices"
					break
				var displacement: float = posed[surface][vertex].distance_to(rest[surface][vertex])
				max_displacement = maxf(max_displacement, displacement)
				if displacement > scale * 0.0000001:
					moved_vertices += 1
	skeleton.set_bone_pose_rotation(selected, original_rotation)
	skeleton.force_update_all_bone_transforms()
	proof.bone = str(skeleton.get_bone_name(selected))
	proof.rotation_radians = 0.3
	proof.moved_vertices = moved_vertices
	proof.max_displacement = max_displacement
	proof.displacement_tolerance = scale * 0.000001
	if moved_vertices == 0 or max_displacement <= proof.displacement_tolerance:
		proof.error = "Non-root bone rotation did not move baked vertices"
	return proof
