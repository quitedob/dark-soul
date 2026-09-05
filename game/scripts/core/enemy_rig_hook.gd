class_name EnemyRigHook
extends RefCounted
## Runtime PartRig hook for enemy bodies. After the enemy visual is built,
## builds a PartRigBuilder skeleton over the body root for a small whitelist of
## riggable enemies, so the enemy can be posed by BONES (not just whole-node
## transforms). Non-listed enemies are untouched (zero blast radius).
##
## Enemy ids are the `enemy/body/by_id/<id>` resolver keys. The proof enemy is
## 01-Lost-Soul-Soldier (early campaign humanoid); a couple more are included
## to make the rig usable where its parts are a good fit.
const PartRigBuilder = preload("res://scripts/core/part_rig_builder.gd")

## Enemy ids that get a runtime rig. Everything else stays static.
const RIGGABLE_ENEMY_IDS := {
	"lost_soul_soldier": true,      # 01-spirit-ruins/01 — proof enemy
	"temple_guardian_warrior": true,
	"camp_guard_wraith": true,
	"generals_personal_guard": true,
	"mind_lost_fox_demon": true,
	"furnace_slag_beast": true,
}

## Build a rig over the enemy's ModelRoot/BodyRoot if the enemy id is riggable.
## Returns the Skeleton3D on success, else null (non-listed or fused). The
## caller should cache the result (e.g. in `_enemy_skeleton_cache`).
static func ensure_rig(body_visual_root: Node3D, enemy_id: String) -> Skeleton3D:
	if body_visual_root == null or not RIGGABLE_ENEMY_IDS.has(enemy_id):
		return null
	# Find the model container the resolver created (ModelRoot for enemies).
	var model_root := body_visual_root.get_node_or_null("ModelRoot") as Node3D
	if model_root == null:
		# Some builds hang the model directly under body_visual_root.
		if body_visual_root.get_child_count() == 0 or _has_skeleton(body_visual_root):
			return null
		model_root = body_visual_root
	# If the GLB already carries a real skeleton, don't stack a second one.
	if _has_skeleton(model_root):
		return _find_skeleton(model_root)
	return PartRigBuilder.build(model_root)


static func _has_skeleton(n: Node) -> bool:
	return _find_skeleton(n) != null


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null
