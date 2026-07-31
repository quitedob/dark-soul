class_name RealModelResolver
extends RefCounted
## Real-model swap resolver — replaces procedural placeholder geometry with GLB
## models when a model exists for a category/key, falling back to the procedural
## builders otherwise.
##
## Contract (consumed by character_meshes.gd / weapon_meshes.gd / enemy_factory.gd):
##   _clear_children(parent)
##   if RealModelResolver.try_instance(<id>, parent):
##       return
##   ...procedural build...
##
## Registry schema:
##   id -> {
##       path:      res:// path to the GLB (required)
##       sub_node:  node name to extract from the GLB and re-parent to the pivot
##                  origin (weapons/shields); whole model used when absent
##       root_name: name of the container node added to `parent`
##                  (default "ModelRoot"; "BodyRoot" satisfies the player lookup)
##       scale:     uniform scale
##       scale_x:   extra X scale (negative mirrors for left-hand)
##       y_offset:  vertical offset in metres
##       yaw_deg:   rotation around Y in degrees
##       position:  additional position offset (weapon-grip compensation)
##   }
## Dropping a GLB into game/assets/models/<category>/<key>.glb and registering it
## here makes that entity real with zero changes to the consumers.

const REGISTRY := {
	"player/body": {
		"path": "res://assets/models/player/mannyquin.glb",
		"root_name": "BodyRoot",
		"scale": 1.0,
		"y_offset": 0.0,
	},
	"player/weapon/sword": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Sword",
		"scale": 0.8,
		"yaw_deg": 180.0,
	},
	"player/weapon/axe_right": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Ax",
		"scale": 0.8,
	},
	"player/weapon/axe_left": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Ax",
		"scale": 0.8,
		"scale_x": -1.0,
	},
	"player/shield": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Shield",
		"scale": 1.0,
	},
	"enemy/body/armored_medium": {
		"path": "res://assets/models/player/mannyquin.glb",
		"scale": 0.9,
	},
	"enemy/body/hulking_molten": {
		"path": "res://assets/models/enemy/minnyquinn.glb",
		"scale": 1.1,
	},
	"enemy/weapon/rusted_blade": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Sword",
		"scale": 0.9,
	},
}

## path -> PackedScene (or null on failed load). Process-lifetime cache.
static var _scene_cache: Dictionary = {}
## paths already warned about — avoid spam on every missing asset.
static var _warned: Dictionary = {}


## Try to instance the real model registered for `id` under `parent`.
## Returns true on success; the caller must clear `parent`'s children first.
## Never throws: a missing/unloadable model degrades to the procedural path.
static func try_instance(id: String, parent: Node3D) -> bool:
	var entry: Dictionary = REGISTRY.get(id, {})
	if entry.is_empty():
		return false
	var path := String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = _scene_cache.get(path, null)
	if scene == null:
		scene = load(path) as PackedScene
		_scene_cache[path] = scene
		if scene == null:
			if not _warned.has(path):
				_warned[path] = true
				push_warning("RealModelResolver: cannot load model: %s" % path)
			return false

	var instance: Node3D = scene.instantiate()
	_neutralize_animation_players(instance)

	# Null-mesh MeshInstance3D is a legal transform/visibility anchor — satisfies
	# the player's BodyRoot cast and gives the enemy palette gate a single marker.
	var root := MeshInstance3D.new()
	root.name = String(entry.get("root_name", "ModelRoot"))
	var s := float(entry.get("scale", 1.0))
	root.scale = Vector3(s * float(entry.get("scale_x", 1.0)), s, s)
	root.position = Vector3(0.0, float(entry.get("y_offset", 0.0)), 0.0)
	if entry.has("position"):
		root.position += entry["position"] as Vector3
	root.rotation.y = deg_to_rad(float(entry.get("yaw_deg", 0.0)))

	if entry.has("sub_node"):
		var sub_name := String(entry["sub_node"])
		if _attach_sub_node(instance, sub_name, root):
			instance.free()
		else:
			root.add_child(instance)
	else:
		root.add_child(instance)

	parent.add_child(root)
	return true


## True when a real model is registered for `id` and its GLB path resolves.
static func has_model(id: String) -> bool:
	var entry: Dictionary = REGISTRY.get(id, {})
	if entry.is_empty():
		return false
	var path := String(entry.get("path", ""))
	return not path.is_empty() and ResourceLoader.exists(path)


## Disable any animation players/trees embedded in the GLB so the model stays in
## its rest pose. The game poses models by rotating their PARENT (visual_root /
## weapon_pivot), so embedded skeletal clips would otherwise fight that.
static func _neutralize_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		node.autoplay = ""
		node.active = false
		node.stop()
	elif node is AnimationTree:
		node.active = false
	for child in node.get_children():
		_neutralize_animation_players(child)


## Extract the named sub-node from the instanced scene and re-parent it to the
## container with a zeroed transform, so the weapon/shield grip sits at the
## pivot origin. Returns false (caller falls back to the whole model) if absent.
static func _attach_sub_node(instance: Node3D, sub_name: String, container: Node3D) -> bool:
	var target := _find_named(instance, sub_name)
	if target == null:
		return false
	target.get_parent().remove_child(target)
	target.owner = null  # detach scene ownership so re-parenting doesn't warn
	target.position = Vector3.ZERO
	target.rotation = Vector3.ZERO
	target.scale = Vector3.ONE
	container.add_child(target)
	return true


static func _find_named(node: Node, name: String) -> Node3D:
	if node.name == name and node is Node3D:
		return node
	for child in node.get_children():
		var hit := _find_named(child, name)
		if hit != null:
			return hit
	return null
