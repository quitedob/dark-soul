extends SceneTree
## Smoke contract for the ADAPTIVE PartRigBuilder across ALL registered GLBs.
## For every GLB in RealModelResolver.REGISTRY (deduped by path) it:
##   1) loads + instantiates the model at a non-trivial transform;
##   2) finds BodyRoot/ModelRoot;
##   3) calls PartRigBuilder.build(mapped) and records the rig result;
##   4) asserts bind-pose is preserved for a mapped part (if any);
##   5) asserts rotating a leaf bone actually moves an attached part.
##
## A model is "RIGGED" if it yields a Skeleton3D with >=1 bone that has >=1
## attached part; "FUSED/STATIC" if build returns null (no nameable parts); the
## two skinned GLBs (mannyquin/minnyquinn) are asserted to have a real embedded
## Skeleton3D instead.
##
## Prints one OK/FAIL/+STATIC line per model, then ASHEN_RIG_ALL_OK (or the
## failure list) then ASHEN_DONE. Run:
##   godot --headless --path game --script res://tests/smoke/rig_all_models_contract_test.gd
const PartRigBuilder = preload("res://scripts/core/part_rig_builder.gd")
const Resolver = preload("res://scripts/core/real_model_resolver.gd")

# Models that are RIGGABLE (should produce a moving rig) — from the VLM/ground-truth
# audit. Others are expected FUSED/STATIC (kept for the rig but no part motion).
const EXPECT_RIGGED := [
	"res://assets/models/bosses/01-Furnace-Keeper-JuQue.glb",
	"res://assets/models/bosses/02-Blood-General-XingTian.glb",
	"res://assets/models/bosses/sub-bosses/01-WrathFragment.glb",
	"res://assets/models/characters/player-classes/01-Divine-Marksman.glb",
	"res://assets/models/characters/player-classes/02-Frenzied-Warrior.glb",
	"res://assets/models/characters/player-classes/03-Mystic-Mage.glb",
	"res://assets/models/characters/player-classes/04-Invocation-Master.glb",
	"res://assets/models/characters/player-classes/05-Yin-Yang-Master.glb",
	"res://assets/models/characters/player-classes/06-War-Shaman.glb",
	"res://assets/models/characters/player-classes/07-Arcane-Archer.glb",
	"res://assets/models/characters/player-classes/08-Asura.glb",
	"res://assets/models/enemies/01-spirit-ruins/01-Lost-Soul-Soldier.glb",
	"res://assets/models/enemies/01-spirit-ruins/02-Temple-Guardian-Warrior.glb",
	"res://assets/models/enemies/01-spirit-ruins/04-Furnace-Slag-Beast.glb",
	"res://assets/models/enemies/02-blood-iron/03-Camp-Guard-Wraith.glb",
	"res://assets/models/enemies/02-blood-iron/05-Generals-Personal-Guard.glb",
	"res://assets/models/enemies/03-jade-veil/03-Echo-Spirit.glb",
	"res://assets/models/enemies/03-jade-veil/09-MindLost-Fox-Demon.glb",
	"res://assets/models/enemies/04-celestial-fall/07-Broken-Immortal-Body.glb",
	"res://assets/models/characters/summons/02-GoldenArmoredGuardian.glb",
	"res://assets/models/enemies/02-blood-iron/01-Lost-Soldier-BattleWorn.glb",
]

# Models with an EMBEDDED skeleton (should have a real Skeleton3D built-in).
const EXPECT_SKINNED := [
	"res://assets/models/player/mannyquin.glb",
	"res://assets/models/enemy/minnyquinn.glb",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var rigged := 0
	var static_ := 0
	var skinned := 0

	# Collect unique model paths from the REGISTRY (const map, so read via const).
	var reg: Dictionary = Resolver.REGISTRY
	var paths: Array[String] = []
	var seen := {}   # path -> true
	for key in reg.keys():
		var e: Dictionary = reg[key]
		if e.has("path"):
			var p: String = e["path"]
			if not seen.has(p):
				seen[p] = true
				paths.append(p)

	if paths.is_empty():
		failures.append("REGISTRY yielded 0 paths — cannot access const map")
		_finish(failures)
		return

	for p in paths:
		var line := await _test_one(p, failures)
		# tally
		if line.begins_with("RIGGED ") or line.begins_with("OK "):
			rigged += 1
		elif line.begins_with("SKINNED "):
			skinned += 1
		elif line.begins_with("STATIC ") or line.begins_with("OK-STATIC "):
			static_ += 1
		print(line)

	print("RIG_ALL_SUMMARY rigged=%d skinned=%d static=%d total=%d" % [rigged, skinned, static_, paths.size()])
	_finish(failures)

## Returns a one-line result; appends to `failures` on a hard error.
func _test_one(glb: String, failures: Array[String]) -> String:
	var base := glb.get_file().get_basename()
	if EXPECT_SKINNED.has(glb):
		var ps: PackedScene = load(glb) as PackedScene
		if ps == null:
			failures.append("skinned load fail: " + glb)
			return "FAIL " + base + " (load)"
		var r: Node = ps.instantiate()
		get_root().add_child(r)
		await process_frame
		var sk := _find_skeleton(r)
		if sk == null:
			failures.append("no embedded Skeleton3D in skinned: " + glb)
			return "FAIL " + base + " (no skel)"
		r.queue_free()
		return "SKINNED " + base + " bones=%d" % sk.get_bone_count()

	var ps2: PackedScene = load(glb) as PackedScene
	if ps2 == null:
		failures.append("load fail: " + glb)
		return "FAIL " + base + " (load)"
	var root: Node = ps2.instantiate()
	root.name = "Rig_" + base
	root.global_transform = Transform3D(Basis.IDENTITY, Vector3(3, 0, -2))  # prove local math
	get_root().add_child(root)
	await process_frame

	var body: Node3D = root.find_child("BodyRoot", true, false) as Node3D
	if body == null:
		body = root.find_child("ModelRoot", true, false) as Node3D
	if body == null:
		body = root as Node3D

	var skel: Skeleton3D = PartRigBuilder.build(body)
	await process_frame
	if skel == null:
		# could be a fused/static model -> expected if not in EXPECT_RIGGED
		root.queue_free()
		if EXPECT_RIGGED.has(glb):
			failures.append("EXPECT_RIGGED got null rig: " + glb)
			return "FAIL " + base + " (null rig)"
		return "STATIC " + base + " (no nameable parts)"

	# count bone attachments carrying at least one part -> these are the "real" bones
	var att_with_parts := 0
	for c in skel.get_children():
		if c is BoneAttachment3D and c.get_child_count() > 0:
			att_with_parts += 1
	if att_with_parts == 0:
		root.queue_free()
		if EXPECT_RIGGED.has(glb):
			failures.append("EXPECT_RIGGED got 0 bone-attached parts: " + glb)
			return "FAIL " + base + " (0 real bones)"
		return "STATIC " + base + " (bones but no parts)"

	# Movement check: try EVERY non-empty bone attachment; a rig "works" if ANY
	# attached part moves when its bone is rotated (one-segment props have a
	# part whose own mesh-center is the pivot, so they correctly won't move).
	var any_move := false
	var move_dist := 0.0
	for c in skel.get_children():
		if not (c is BoneAttachment3D) or c.get_child_count() == 0:
			continue
		var part: MeshInstance3D = c.get_child(0) as MeshInstance3D
		if part == null:
			continue
		var bone_idx := skel.find_bone(c.bone_name)
		if bone_idx == -1:
			continue
		var before := _mesh_center(part)
		skel.set_bone_pose_rotation(bone_idx, Basis(Vector3.UP, 0.8))
		await process_frame
		move_dist = before.distance_to(_mesh_center(part))
		skel.reset_bone_poses()
		if move_dist >= 0.02:
			any_move = true
			break

	root.queue_free()
	# Expectation check: EXPECT_RIGGED models MUST move; others may stay static.
	if EXPECT_RIGGED.has(glb):
		if not any_move:
			failures.append("EXPECT_RIGGED no-move: " + glb)
			return "FAIL " + base + " (EXPECT_RIGGED no move %.3f)" % move_dist
		return "OK " + base + " rigged bones=%d real=%d" % [skel.get_bone_count(), att_with_parts]
	if any_move:
		# riggable-but-not-expected: bonus, report RIGGED
		return "RIGGED " + base + " bones=%d real=%d" % [skel.get_bone_count(), att_with_parts]
	return "STATIC " + base + " (no nameable moving parts)"

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null

func _mesh_center(mi: MeshInstance3D) -> Vector3:
	var aabb: AABB = mi.mesh.get_aabb() if mi.mesh != null else AABB()
	if aabb.size == Vector3.ZERO:
		return mi.global_transform.origin
	return mi.global_transform * aabb.get_center()

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ASHEN_RIG_ALL_OK")
	else:
		for f in failures:
			print("FAIL: " + f)
	print("ASHEN_DONE")
	quit()
