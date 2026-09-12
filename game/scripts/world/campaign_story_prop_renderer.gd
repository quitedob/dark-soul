class_name CampaignStoryPropRenderer
extends RefCounted
## Required Blender-authored story architecture, shared by scenery and boss props.
## Placement is owned by the level plan. This renderer never moves a prop onto a
## route, invents gameplay collision, or changes shared imported materials.

const MANIFEST_PATH := "res://assets/environment/story_props/manifest.json"
const NAVIGATION_PROXY_LAYER := 1 << 19
static var _manifest: Dictionary = {}
static var _parts: Dictionary = {}


static func get_part_ids() -> Array[String]:
	var result: Array[String] = []
	if not _load_manifest():
		return result
	for part: String in _manifest["parts"]:
		result.append(part)
	return result


static func get_part_definition(part_id: String) -> Dictionary:
	if not _load_manifest() or not _manifest["parts"].has(part_id):
		return {}
	return (_manifest["parts"][part_id] as Dictionary).duplicate(true)


static func instantiate_part(part_id: String) -> Node3D:
	## Mesh-only instance for a gameplay-owned interactable/destructible body.
	if not _load_part(part_id):
		return null
	var instance := Node3D.new()
	instance.name = part_id
	instance.set_meta("story_part_id", part_id)
	instance.set_meta("story_asset_path", _manifest["parts"][part_id]["resource"])
	for descriptor: Dictionary in _parts[part_id]:
		var visual := MeshInstance3D.new()
		visual.name = String(descriptor["name"])
		visual.mesh = descriptor["mesh"]
		visual.transform = descriptor["transform"]
		# glTF material surfaces remain on the imported Mesh. An actual authored
		# override, when present, must remain distinct from unrelated materials.
		visual.material_override = descriptor["material"]
		instance.add_child(visual)
	return instance


static func get_part_aabb(part_id: String) -> AABB:
	## Measured imported geometry, independent of the generated manifest bounds.
	if not _load_part(part_id):
		return AABB()
	var result := AABB()
	var first := true
	for descriptor: Dictionary in _parts[part_id]:
		var mesh: Mesh = descriptor["mesh"]
		var transform: Transform3D = descriptor["transform"]
		var bounds: AABB = transform * mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result


static func attach_to(level_root: Node3D, placements: Array) -> bool:
	## Rows: {id, part_id, position:Vector3, rotation_y:float, scale:Vector3,
	##        story_source:String, collision:bool}. All transforms are root-local.
	## Caller reserves supported placement regions before invoking this method.
	if level_root == null or level_root.has_node("CampaignStoryProps"):
		push_error("Story scenery requires a valid root without existing CampaignStoryProps")
		return false
	# Resolve everything first, leaving the level untouched if required art fails.
	var identifiers: Dictionary = {}
	for value: Variant in placements:
		if not value is Dictionary:
			push_error("Invalid story scenery placement row")
			return false
		var placement: Dictionary = value
		var part_id := String(placement.get("part_id", ""))
		var placement_id := String(placement.get("id", ""))
		var position: Variant = placement.get("position", null)
		var scale_value: Variant = placement.get("scale", Vector3.ONE)
		if placement_id.is_empty() or identifiers.has(placement_id) or not position is Vector3 or not scale_value is Vector3:
			push_error("Invalid or duplicate story scenery placement: " + placement_id)
			return false
		var scale_vector: Vector3 = scale_value
		var at: Vector3 = position
		if not at.is_finite() or not scale_vector.is_finite() or scale_vector.x <= 0.0 or scale_vector.y <= 0.0 or scale_vector.z <= 0.0:
			push_error("Invalid story scenery transform: " + placement_id)
			return false
		if not is_finite(float(placement.get("rotation_y", 0.0))) or not _load_part(part_id):
			return false
		identifiers[placement_id] = true
	var root := Node3D.new()
	root.name = "CampaignStoryProps"
	var batches: Dictionary = {}
	var counts: Dictionary = {}
	var records: Array[Dictionary] = []
	for placement: Dictionary in placements:
		var part_id := String(placement["part_id"])
		var placement_id := String(placement["id"])
		var definition: Dictionary = _manifest["parts"][part_id]
		var scale_value: Vector3 = placement.get("scale", Vector3.ONE)
		var transform := Transform3D(Basis(Vector3.UP, float(placement.get("rotation_y", 0.0))).scaled_local(scale_value), placement["position"])
		counts[part_id] = int(counts.get(part_id, 0)) + 1
		var descriptors: Array = _parts[part_id]
		for index in descriptors.size():
			var descriptor: Dictionary = descriptors[index]
			var key := "%s/%d" % [part_id, index]
			if not batches.has(key):
				batches[key] = {"part_id": part_id, "mesh": descriptor["mesh"], "material": descriptor["material"], "transforms": []}
			batches[key]["transforms"].append(transform * descriptor["transform"])
		var has_collision := bool(placement.get("collision", definition["collision"]))
		var anchor := Node3D.new()
		anchor.name = placement_id.validate_node_name()
		anchor.transform = transform
		anchor.set_meta("story_prop_id", placement_id)
		anchor.set_meta("story_part_id", part_id)
		anchor.set_meta("story_placement", placement.duplicate(true))
		anchor.set_meta("story_mesh_bounds", get_part_aabb(part_id))
		anchor.set_meta("story_asset_path", definition["resource"])
		root.add_child(anchor)
		if has_collision:
			_add_physical_collision(anchor, part_id, placement_id, Transform3D.IDENTITY)
			_add_navigation_proxies(anchor, definition, part_id, placement_id, Transform3D.IDENTITY)
		records.append({"id": placement_id, "part_id": part_id, "transform": transform,
			"story_source": String(placement.get("story_source", definition["source"])), "collision": has_collision})
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var transforms: Array = batch["transforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch["mesh"]
		multi.instance_count = transforms.size()
		for index in transforms.size():
			multi.set_instance_transform(index, transforms[index])
		var visual := MultiMeshInstance3D.new()
		visual.name = "Story_%s_%d" % [batch["part_id"], root.get_child_count()]
		visual.multimesh = multi
		visual.material_override = batch["material"]
		visual.set_meta("story_part_id", batch["part_id"])
		visual.set_meta("story_asset_path", _manifest["parts"][batch["part_id"]]["resource"])
		# Retain authoritative transforms for headless contracts; RenderingServer's
		# dummy backend does not return reliable MultiMesh instance transforms.
		visual.set_meta("placement_transforms", transforms.duplicate())
		root.add_child(visual)
	root.set_meta("part_counts", counts)
	root.set_meta("placements", records)
	root.set_meta("batch_count", batches.size())
	level_root.add_child(root)
	return true


static func _load_manifest() -> bool:
	if not _manifest.is_empty():
		return true
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Required story asset manifest is missing: " + MANIFEST_PATH)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1 or not parsed.get("parts") is Dictionary:
		push_error("Invalid required story asset manifest: " + MANIFEST_PATH)
		return false
	_manifest = parsed
	return true


static func _load_part(part_id: String) -> bool:
	if _parts.has(part_id):
		return true
	if not _load_manifest() or not _manifest["parts"].has(part_id):
		push_error("Unknown required story architecture part: " + part_id)
		return false
	var path := String(_manifest["parts"][part_id]["resource"])
	if not ResourceLoader.exists(path):
		push_error("Required story architecture is unavailable: " + path)
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Required story architecture is not an imported scene: " + path)
		return false
	var source := scene.instantiate() as Node3D
	if source == null:
		push_error("Invalid story architecture scene root: " + path)
		return false
	# Cache all siblings from this library in one import/instantiation.
	for sibling_id: String in _manifest["parts"]:
		if String(_manifest["parts"][sibling_id]["resource"]) != path:
			continue
		var part_root := source.get_node_or_null(NodePath(sibling_id)) as Node3D
		if part_root == null:
			push_error("Required story architecture root missing: %s/%s" % [path, sibling_id])
			source.free()
			return false
		var descriptors: Array[Dictionary] = []
		_collect_meshes(part_root, Transform3D.IDENTITY, descriptors)
		if descriptors.is_empty():
			push_error("Required story architecture root is empty: " + sibling_id)
			source.free()
			return false
		_parts[sibling_id] = descriptors
	source.free()
	return _parts.has(part_id)


static func _collect_meshes(node: Node3D, parent: Transform3D, result: Array[Dictionary]) -> void:
	var transform := parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		result.append({"name": node.name, "mesh": node.mesh, "transform": transform, "material": node.material_override})
	for child in node.get_children():
		if child is Node3D:
			_collect_meshes(child, transform, result)


static func _add_physical_collision(parent: Node3D, part_id: String, placement_id: String, transform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = placement_id.validate_node_name() + "_Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = transform
	body.set_meta("story_part_id", part_id)
	body.set_meta("story_placement_id", placement_id)
	# Exact material mesh triangles preserve arch openings and narrow silhouettes.
	# They are deliberately excluded from navigation source groups: detailed roofs,
	# books, bells and leaves are not extra walkable surfaces or nav islands.
	for descriptor: Dictionary in _parts[part_id]:
		if not descriptor.has("shape"):
			descriptor["shape"] = (descriptor["mesh"] as Mesh).create_trimesh_shape()
		var collision := CollisionShape3D.new()
		collision.shape = descriptor["shape"]
		collision.transform = descriptor["transform"]
		body.add_child(collision)
	parent.add_child(body)


static func _add_navigation_proxies(parent: Node3D, definition: Dictionary, part_id: String, placement_id: String, transform: Transform3D) -> void:
	for box: Dictionary in definition["navigation_boxes"]:
		var body := StaticBody3D.new()
		body.name = placement_id.validate_node_name() + "_Navigation"
		body.collision_layer = NAVIGATION_PROXY_LAYER
		body.collision_mask = 0
		body.transform = transform
		body.add_to_group("campaign_navigation_source")
		body.add_to_group("campaign_terrain_navigation_source")
		body.set_meta("story_part_id", part_id)
		body.set_meta("story_placement_id", placement_id)
		var shape := BoxShape3D.new()
		shape.size = _vector(box["size"])
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = _vector(box["center"])
		body.add_child(collision)
		parent.add_child(body)


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
