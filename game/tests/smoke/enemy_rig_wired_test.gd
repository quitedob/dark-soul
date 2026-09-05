extends SceneTree
## Smoke contract for EnemyRigHook — the runtime PartRig wiring on an enemy.
## Loads the proof enemy body (Lost-Soul-Soldier), runs the hook, and asserts:
##   1) the hook returns a Skeleton3D for the riggable enemy id;
##   2) it has bones with attached parts (real bones, not empty);
##   3) rotating a bone moves an attached part (the enemy "can move" in-engine);
##   4) a non-listed enemy id yields null (zero blast radius).
## Prints ASHEN_ENEMY_RIG_WIRED_OK + ASHEN_ENEMY_RIG_SKIP_OK on success.
## Run: godot --headless --path game --script res://tests/smoke/enemy_rig_wired_test.gd
const EnemyRigHook = preload("res://scripts/core/enemy_rig_hook.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	# 1) Riggable proof enemy: Lost-Soul-Soldier (enemy id lost_soul_soldier).
	var glb := "res://assets/models/enemies/01-spirit-ruins/01-Lost-Soul-Soldier.glb"
	var ps: PackedScene = load(glb) as PackedScene
	if ps == null:
		failures.append("load fail: " + glb)
		_finish(failures)
		return
	var root: Node = ps.instantiate()
	root.name = "EnemyRigHolder"
	root.global_transform = Transform3D(Basis.IDENTITY, Vector3(3, 0, -2))
	get_root().add_child(root)
	await process_frame

	# The resolver creates a ModelRoot container; mimic a body_visual_root wrapper.
	var wrapper := Node3D.new()
	wrapper.name = "BodyVisuals"
	wrapper.global_transform = Transform3D(Basis.IDENTITY, Vector3(5, 0, 1))
	get_root().add_child(wrapper)
	# move the instantiated model under wrapper as a synthetic ModelRoot
	var body_root := root.find_child("BodyRoot", true, false) as Node3D
	var model_container: Node3D = body_root if body_root != null else root
	model_container.reparent(wrapper, true)
	await process_frame

	var rig: Skeleton3D = EnemyRigHook.ensure_rig(wrapper, "lost_soul_soldier")
	if rig == null:
		failures.append("hook returned null for riggable id")
		_finish(failures)
		return
	if rig.get_bone_count() == 0:
		failures.append("rig has 0 bones")
		_finish(failures)
		return

	# 2) Should have a spine/neck/leg bone from the humanoid tree.
	var spine := rig.find_bone("spine")
	var thigh := rig.find_bone("thigh.L")
	if spine == -1 and thigh == -1:
		failures.append("no spine/thigh bone mapped")
		_finish(failures)
		return

	# 3) Rotating a bone moves an attached part (proof the rig is live).
	var moved := false
	var dist := 0.0
	for c in rig.get_children():
		if not (c is BoneAttachment3D) or c.get_child_count() == 0:
			continue
		var part: MeshInstance3D = c.get_child(0) as MeshInstance3D
		var b := rig.find_bone(c.bone_name)
		if part == null or b == -1:
			continue
		var before := _mesh_center(part)
		rig.set_bone_pose_rotation(b, Basis(Vector3.RIGHT, 0.7))
		await process_frame
		dist = before.distance_to(_mesh_center(part))
		if dist >= 0.02:
			moved = true
			break
	if not moved:
		failures.append("no bone moved an attached part (dist=%.4f)" % dist)
		_finish(failures)
		return

	# 4) Non-listed id -> null (zero blast radius).
	var skip: Skeleton3D = EnemyRigHook.ensure_rig(wrapper, "immobile_turret")
	if skip != null:
		failures.append("non-listed id should return null but got a rig")
		_finish(failures)
		return

	_finish(failures)

func _mesh_center(mi: MeshInstance3D) -> Vector3:
	var aabb: AABB = mi.mesh.get_aabb() if mi.mesh != null else AABB()
	if aabb.size == Vector3.ZERO:
		return mi.global_transform.origin
	return mi.global_transform * aabb.get_center()

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ASHEN_ENEMY_RIG_WIRED_OK")
		print("ASHEN_ENEMY_RIG_SKIP_OK")
	else:
		for f in failures:
			print("FAIL: " + f)
	print("ASHEN_DONE")
	quit()
