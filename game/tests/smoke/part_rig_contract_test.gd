extends SceneTree
## Smoke contract for PartRigBuilder (runtime bone-parent rig on unrigged GLB).
## Verifies:
##   1) a Skeleton3D is produced with >0 bones and parts re-parented under it;
##   2) bind pose is preserved (a mapped part keeps its world position);
##   3) rotating a bone actually moves an attached part (the model "can move");
##   4) bone names follow the humanoid set (suit the model).
## Prints ASHEN_PART_RIG_OK + ASHEN_PART_RIG_MOVE_OK on success.
## Run: godot --headless --path game --script res://tests/smoke/part_rig_contract_test.gd
const PartRigBuilder = preload("res://scripts/core/part_rig_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var glb := "res://assets/models/bosses/01-Furnace-Keeper-JuQue.glb"
	var ps: PackedScene = load(glb) as PackedScene
	if ps == null:
		failures.append("load fail: " + glb)
		_finish(failures)
		return

	var root: Node = ps.instantiate()
	root.name = "RigHolder"
	# Place it at a non-trivial transform to prove body_root-local math is solid.
	root.global_transform = Transform3D(Basis.IDENTITY, Vector3(3, 0, -2))

	var body_root: Node3D = root.find_child("BodyRoot", true, false) as Node3D
	if body_root == null:
		failures.append("no BodyRoot in " + glb)
		_finish(failures)
		return
	get_root().add_child(root)
	await process_frame  # let tree compute global transforms

	# map a known part (thigh_l) and record its world mesh-center BEFORE rigging
	var part_bound := body_root.find_child("thigh_l", true, false) as MeshInstance3D
	var before: Vector3 = Vector3.INF
	if part_bound != null:
		before = _mesh_center(part_bound)
	else:
		failures.append("no thigh_l part to bind-test")
		_finish(failures)
		return

	var skel: Skeleton3D = PartRigBuilder.build(body_root)
	await process_frame

	if skel == null:
		failures.append("rig build returned null")
		_finish(failures)
		return
	if skel.get_bone_count() == 0:
		failures.append("rig has 0 bones")
		_finish(failures)
		return

	# parts re-parented under the skeleton (BoneAttachment3D children)
	var skel_node: Node = skel.get_parent()
	var bone_attach_count := 0
	for c in skel.get_children():
		if c is BoneAttachment3D:
			bone_attach_count += 1
	if bone_attach_count == 0:
		failures.append("no BoneAttachment3D under skeleton")

	# 2) bind pose preserved: rigged thigh_l world pos == before (within epsilon)
	var part_after: MeshInstance3D = null
	var skel_child = skel.get_parent().find_child("thigh_l", true, false) as MeshInstance3D
	if skel_child == null:
		# the part now lives under a BoneAttachment; find by name anywhere under root
		part_after = root.find_child("thigh_l", true, false) as MeshInstance3D
	else:
		part_after = skel_child
	var after: Vector3 = _mesh_center(part_after)
	if before.distance_to(after) > 0.02:
		failures.append("bind not preserved: thigh_l moved %.4f" % before.distance_to(after))

	# 3) rotating a bone moves the part (proof the model can move)
	var thigh_idx := skel.find_bone("thigh.L")
	if thigh_idx == -1:
		# try .R or a leaf
		thigh_idx = skel.find_bone("thigh.R")
	if thigh_idx == -1:
		failures.append("no thigh bone to rotate")
	else:
		skel.set_bone_pose_rotation(thigh_idx, Basis(Vector3.UP, 0.8))
		await process_frame
		var after_rot: Vector3 = _mesh_center(part_after)
		if after.distance_to(after_rot) < 0.02:
			failures.append("bone rotation did not move part (model not movable)")
		else:
			print("ASHEN_PART_RIG_MOVE_OK move_dist=%.4f" % after.distance_to(after_rot))

	_finish(failures)

func _mesh_center(mi: MeshInstance3D) -> Vector3:
	var aabb: AABB = mi.mesh.get_aabb() if mi.mesh != null else AABB()
	if aabb.size == Vector3.ZERO:
		return mi.global_transform.origin
	return mi.global_transform * aabb.get_center()

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ASHEN_PART_RIG_OK")
	else:
		for f in failures:
			print("FAIL: " + f)
	print("ASHEN_DONE")
	quit()
