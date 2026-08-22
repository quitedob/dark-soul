class_name PartRigBuilder
extends RefCounted
## Runtime bone-parent rig for unrigged GLB models whose body-parts are named
## sibling MeshInstance3D nodes (e.g. thigh_l, shin_l, boot_l, upperarm_r,
## forearm_r, fist_r, head_mask, pelvis, torso — see the boss GLB probe).
##
## The GLB has NO Skeleton3D; this builds one at runtime and re-parents each
## named part under a BoneAttachment3D on the matching bone. Rotating a bone
## then moves its attached part(s) — a rigid (non-skinned) joint rig.
##
## Rest pose: each bone's rest transform is set to the world centroid of the
## parts assigned to it, so at bind pose the model looks unchanged and each
## part pivots about its own group centroid.

## Humanoid bone hierarchy (Godot naming). parent = name or null.
const BONE_TREE := {
	"root": {"parent": "", "sided": false},
	"hips": {"parent": "root", "sided": false},
	"spine": {"parent": "hips", "sided": false},
	"chest": {"parent": "spine", "sided": false},
	"neck": {"parent": "chest", "sided": false},
	"head": {"parent": "neck", "sided": false},
	"upper_arm.L": {"parent": "chest", "sided": true},
	"upper_arm.R": {"parent": "chest", "sided": true},
	"forearm.L": {"parent": "upper_arm.L", "sided": true},
	"forearm.R": {"parent": "upper_arm.R", "sided": true},
	"hand.L": {"parent": "forearm.L", "sided": true},
	"hand.R": {"parent": "forearm.R", "sided": true},
	"thigh.L": {"parent": "hips", "sided": true},
	"thigh.R": {"parent": "hips", "sided": true},
	"shin.L": {"parent": "thigh.L", "sided": true},
	"shin.R": {"parent": "thigh.R", "sided": true},
	"foot.L": {"parent": "shin.L", "sided": true},
	"foot.R": {"parent": "shin.R", "sided": true},
	"tail": {"parent": "root", "sided": false},
	"wing.L": {"parent": "chest", "sided": true},
	"wing.R": {"parent": "chest", "sided": true},
}

## Map a part node name -> bone id. Returns "" when no mapping applies (part is
## left attached to the torso/spine as a static anchor). Heuristic, ordered.
static func bone_for_part(part_name: String) -> String:
	var n: String = part_name.to_lower()
	var side: String = _side(n)
	var sided: bool = side != ""
	# --- legs / feet ---
	if _has(n, ["foot", "boot", "ankle", "toe"]):
		return "foot." + side if sided else "foot.L"
	if _has(n, ["shin", "calf", "knee_lower", "knee_joint", "knee_cap", "boot_upper"]):
		return "shin." + side if sided else "shin.L"
	if _has(n, ["thigh", "upper_leg", "knee_upper"]):
		return "thigh." + side if sided else "thigh.L"
	# --- arms / hands ---
	if _has(n, ["fist", "hand", "palm", "claw", "paw_hand"]):
		return "hand." + side if sided else "hand.L"
	if _has(n, ["forearm", "vambrace", "elbow", "arm_lower"]):
		return "forearm." + side if sided else "forearm.L"
	if _has(n, ["upperarm", "upper_arm", "shoulder_base", "pauldron", "shoulder", "arm"]):
		return "upper_arm." + side if sided else "upper_arm.L"
	# --- head / neck ---
	if _has(n, ["head", "mask", "face", "skull", "muzzle", "helm", "faceplate"]):
		return "head"
	if _has(n, ["neck", "neck_guard", "throat"]):
		return "neck"
	# --- pelvis / torso core ---
	if _has(n, ["pelvis", "hips", "hip", "belt", "waist", "skirt"]):
		return "hips"
	# --- extremities (non-anatomical) ---
	if _has(n, ["tail"]):
		return "tail"
	if _has(n, ["wing"]):
		return "wing." + side if sided else "wing.L"
	# --- torso / chest / everything else stays as torso-core anchor ---
	return ""   # leave under spine (static center) — never flies off

static func _side(n: String) -> String:
	# right-first so "_.r_" never mis-read; look for l/r by suffix/short token.
	if n.ends_with(".l") or n.ends_with("_l") or n.ends_with("_la") or n.ends_with("_lb") or n.ends_with("_lt"):
		return "L"
	if n.ends_with(".r") or n.ends_with("_r") or n.ends_with("_ra") or n.ends_with("_rb") or n.ends_with("_rt"):
		return "R"
	# some names put side elsewhere (e.g. boot_upper_l handled by ends_with above)
	return ""

static func _has(n: String, words: Array) -> bool:
	for w in words:
		if n.find(w) != -1:
			return true
	return false


## Build a Skeleton3D rig over `body_root` (e.g. the GLB BodyRoot / model root).
## Re-parents matched part meshes under bone attachments. Returns the Skeleton3D
## on success, or null if no parts could be mapped.
static func build(body_root: Node3D) -> Skeleton3D:
	var parts: Array[MeshInstance3D] = []
	_collect_meshes(body_root, parts)
	if parts.is_empty():
		return null

	# Work in body_root-LOCAL space (rig is correct wherever the body is placed).
	var base_inv: Transform3D = body_root.global_transform.affine_inverse()
	var bind_local: Dictionary = {}   # part -> local transform relative to body_root
	for p in parts:
		bind_local[p] = base_inv * p.global_transform

	# assign each part to a bone id; group bone id -> parts (and collect data)
	var bone_parts: Dictionary = {}   # bone id -> Array[MeshInstance3D]
	var bone_local: Dictionary = {}   # bone id -> Array[Vector3] (local part centroids)
	var bone_box: Dictionary = {}     # bone id -> AABB (body_root-local, union of parts)
	for p in parts:
		var bid: String = bone_for_part(p.name)
		var c: Vector3 = base_inv * _world_center(p)   # body_root-local centroid
		if bid == "":
			# unmapped detail -> anchor to torso core so it stays put
			bid = "spine"
		if not bone_parts.has(bid):
			bone_parts[bid] = []
			bone_local[bid] = []
			bone_box[bid] = AABB()
		bone_parts[bid].append(p)
		bone_local[bid].append(c)
		# union this part's AABB (transformed to body_root-local) into the bone box
		var pb: AABB = _part_box_local(bind_local[p] as Transform3D, p.mesh.get_aabb() if p.mesh != null else AABB())
		if bone_box[bid].size == Vector3.ZERO:
			bone_box[bid] = pb
		else:
			bone_box[bid] = bone_box[bid].merge(pb)

	# --- build Skeleton3D ---
	var skel := Skeleton3D.new()
	skel.name = "PartRig"
	var name_to_idx: Dictionary = {}
	for bone_id in BONE_TREE.keys():
		var bi := skel.get_bone_count()
		skel.add_bone(bone_id)
		name_to_idx[bone_id] = bi
	# wire parents
	for bone_id in BONE_TREE.keys():
		var parent_name: String = BONE_TREE[bone_id].parent
		if parent_name != "" and name_to_idx.has(parent_name):
			skel.set_bone_parent(name_to_idx[bone_id], name_to_idx[parent_name])

	# joint per bone = nearest point on the bone's part-AABB to its parent joint,
	# so pivots land at the PROXIMAL end (hip/knee/shoulder/elbow) and the model
	# "suits itself" for animation.
	var joint: Dictionary = {}
	var order: Array = BONE_TREE.keys()
	var hips_box: AABB = bone_box.get("hips", AABB())
	joint["hips"] = _box_center(hips_box)
	joint["root"] = joint["hips"]
	for bone_id in order:
		if bone_id == "root" or bone_id == "hips":
			continue
		var parent_name: String = BONE_TREE[bone_id].parent
		var pp: Vector3 = joint.get(parent_name, joint["hips"])
		var bx: AABB = bone_box.get(bone_id, AABB())
		if bx.size == Vector3.ZERO:
			joint[bone_id] = pp
		else:
			joint[bone_id] = _nearest_on_box(bx, pp)

	# --- set bone rests parent-relative so each bone's GLOBAL rest lands on its
	#     proximal joint (skeleton-local == body_root-local space). Godot's
	#     set_bone_rest() is relative to the parent bone, so accumulate the chain.
	var global_rest: Dictionary = {}   # bone id -> Transform3D (skeleton-local, absolute)
	for bone_id in order:
		var desired: Transform3D = Transform3D(Basis.IDENTITY, joint.get(bone_id, joint["hips"]))
		var parent_name: String = BONE_TREE[bone_id].parent
		if parent_name == "":
			skel.set_bone_rest(name_to_idx[bone_id], desired)
			global_rest[bone_id] = desired
		else:
			var pgr: Transform3D = global_rest[parent_name]
			skel.set_bone_rest(name_to_idx[bone_id], pgr.affine_inverse() * desired)
			global_rest[bone_id] = desired

	# --- bone attachment per bone (follows the bone's global rest at bind) ---
	var attachment: Dictionary = {}   # bone id -> BoneAttachment3D
	for bone_id in bone_parts.keys():
		if not name_to_idx.has(bone_id):
			continue
		var att := BoneAttachment3D.new()
		att.name = "Attach_" + bone_id
		skel.add_child(att)
		att.bone_name = bone_id
		attachment[bone_id] = att

	# place skeleton where the parts were (same coordinate frame as body_root)
	body_root.add_child(skel)

	# reparent each part under its bone attachment, preserving its body_root-local pose:
	# p.local = bone_global_rest^-1 * bind_local  (BoneAttachment follows global rest)
	for bid in bone_parts.keys():
		var gr_inv: Transform3D = (global_rest.get(bid, Transform3D.IDENTITY) as Transform3D).affine_inverse()
		for p in bone_parts[bid]:
			var att: BoneAttachment3D = attachment[bid]
			p.get_parent().remove_child(p)
			att.add_child(p)
			p.transform = gr_inv * (bind_local[p] as Transform3D)

	skel.reset_bone_poses()   # return to rest (bind pose == original model)
	return skel


static func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)

static func _world_center(mi: MeshInstance3D) -> Vector3:
	var aabb: AABB = mi.mesh.get_aabb() if mi.mesh != null else AABB()
	if aabb.size == Vector3.ZERO:
		return mi.global_transform.origin
	return mi.global_transform * aabb.get_center()

static func _centroid(pts: Array) -> Vector3:
	if pts.is_empty():
		return Vector3.ZERO
	var s := Vector3.ZERO
	for v in pts:
		s += v
	return s / float(pts.size())

## Transform a mesh-AABB into body_root-local space via a part's bind transform.
static func _part_box_local(bind: Transform3D, aabb: AABB) -> AABB:
	var mn := Vector3.INF
	var mx := Vector3(-INF, -INF, -INF)
	for s in 8:
		var corner := Vector3(
			aabb.position.x if (s & 1) == 0 else aabb.end.x,
			aabb.position.y if (s & 2) == 0 else aabb.end.y,
			aabb.position.z if (s & 4) == 0 else aabb.end.z
		)
		var w: Vector3 = bind * corner
		mn = mn.min(w)
		mx = mx.max(w)
	if mn == Vector3.INF:
		return AABB()
	return AABB(mn, mx - mn)

## Closest point on the AABB to p (gives the proximal face toward the parent joint).
static func _nearest_on_box(box: AABB, p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))

static func _box_center(box: AABB) -> Vector3:
	if box.size == Vector3.ZERO:
		return Vector3.ZERO
	return (box.position + box.end) * 0.5
