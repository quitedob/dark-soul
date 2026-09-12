extends SceneTree
## Real imported assets + physics queries. No game world, settings or user saves.
const StoryProps = preload("res://scripts/world/campaign_story_prop_renderer.gd")

var _failures: Array[String] = []
var _checks := 0
var _level: Node3D
var _anchors: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids: Array[String] = StoryProps.get_part_ids()
	_expect(ids.size() == 46, "46 actual authored story parts must import")
	var memorials: Array[String] = []
	var living: Array[String] = []
	var placements: Array = []
	for index in ids.size():
		var part_id := ids[index]
		if part_id.begins_with("Memorial"):
			memorials.append(part_id)
		if part_id.begins_with("LivingSeal"):
			living.append(part_id)
		var definition: Dictionary = StoryProps.get_part_definition(part_id)
		var imported := StoryProps.instantiate_part(part_id) as Node3D
		if not _expect(imported != null, part_id + " imports as visible architecture"):
			continue
		var meshes := imported.find_children("*", "MeshInstance3D", true, false)
		_expect(meshes.size() >= 2, part_id + " has separate authored material meshes")
		var triangles := 0
		var actual_bounds := AABB()
		var first := true
		for node: Node in meshes:
			var visual := node as MeshInstance3D
			_expect(visual.mesh is ArrayMesh, part_id + " must use imported mesh geometry")
			var bounds: AABB = visual.transform * visual.mesh.get_aabb()
			actual_bounds = bounds if first else actual_bounds.merge(bounds)
			first = false
			for surface in visual.mesh.get_surface_count():
				_expect(visual.mesh.surface_get_material(surface) != null, part_id + " preserves imported surface material")
				var arrays := visual.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += int(indices.size() / 3.0)
		_expect(triangles > 200, part_id + " must contain modeled detail")
		_expect(absf(actual_bounds.position.y) < 0.001, part_id + " actual mesh foot rests at Y0")
		_expect(actual_bounds.size.is_equal_approx(_vector(definition["bounds"]["size"])), part_id + " manifest agrees with actual imported dimensions")
		_expect(StoryProps.get_part_aabb(part_id).is_equal_approx(actual_bounds), part_id + " runtime bounds derive from imported meshes")
		_expect(imported.find_children("*", "CollisionObject3D", true, false).is_empty(), part_id + " standalone visual does not duplicate gameplay collision")
		imported.free()
		placements.append({"id": "audit_" + part_id, "part_id": part_id,
			"position": Vector3(index % 8 * 30.0, 0, floori(index / 8.0) * 30.0), "rotation_y": 0.37,
			"scale": Vector3.ONE, "story_source": "story-prop-assets-contract"})
	_expect(memorials.size() == 9, "Canon contains exactly nine fallen-forger memorials")
	_expect(living.size() == 3, "The three living forgers have separate seal assets")
	_expect(ids.has("DecoyBellBroken"), "Blind Bell Hearer has a visibly damaged bell asset")
	# The same imported mesh must also survive a rotated, scaled second placement.
	placements.append({"id": "scaled_wall", "part_id": "MuralWall", "position": Vector3(-30, 0, 0),
		"rotation_y": -0.58, "scale": Vector3(1.3, 0.8, 1.1), "collision": true})
	_level = Node3D.new()
	_level.position = Vector3(13, 2, -7)
	_level.rotation.y = 0.19
	root.add_child(_level)
	_expect(StoryProps.attach_to(_level, placements), "All catalog placements batch into a real scene")
	var scenery := _level.get_node_or_null("CampaignStoryProps") as Node3D
	if not _expect(scenery != null, "Story scenery root exists"):
		_finish()
		return
	for node in scenery.get_children():
		if node.has_meta("story_prop_id"):
			_anchors[String(node.get_meta("story_prop_id"))] = node
	_expect(_anchors.size() == 47, "Every batched placement retains a unique physical/story identity")
	var batches := scenery.find_children("*", "MultiMeshInstance3D", true, false)
	_expect(not batches.is_empty(), "Renderer submits actual MultiMesh visuals")
	for node: Node in batches:
		var visual := node as MultiMeshInstance3D
		_expect(visual.multimesh.mesh is ArrayMesh, "Batches retain actual imported meshes")
		_expect(visual.multimesh.instance_count > 0, "Every visual batch has a live instance")
		if String(visual.get_meta("story_part_id")) == "MuralWall":
			_expect(visual.multimesh.instance_count == 2, "Repeated wall instances share material batches")
	for body: Node in scenery.find_children("*", "StaticBody3D", true, false):
		var collision_body := body as StaticBody3D
		if collision_body.collision_layer == 1:
			_expect(not body.is_in_group("campaign_navigation_source"), "Detailed roofs/leaves never become navigation islands")
			for collision: Node in body.get_children():
				_expect((collision as CollisionShape3D).shape is ConcavePolygonShape3D, "Actor and camera collision use actual imported triangle silhouettes")
		else:
			_expect(collision_body.collision_layer == 1 << 19, "Navigation approximations do not collide with actors/camera")
			_expect(body.is_in_group("campaign_navigation_source"), "Navigation solid proxies join explicit bake source group")
	await physics_frame
	await physics_frame
	for part_id in ["PrisonCage", "CommandTent", "LakePavilion", "BellTower"]:
		_expect(_ray(part_id, Vector3(0, 1, -10), Vector3(0, 1, 0), 1).is_empty(), part_id + " actual front entrance remains open")
		_expect(_ray(part_id, Vector3(0, 1, -10), Vector3(0, 1, 0), 1 << 19).is_empty(), part_id + " navigation entrance remains open")
	for part_id in ["PrisonCage", "CommandTent"]:
		_expect(not _ray(part_id, Vector3(-10, 1, 0), Vector3(0, 1, 0), 1).is_empty(), part_id + " real side wall blocks actors")
	for x in [-1.45, 0.0, 1.45]:
		_expect(_ray("LakePavilion", Vector3(x, 1, -8), Vector3(x, 1, 8), 1).is_empty(), "Pavilion leaves a 3m central bridge corridor")
		_expect(_ray("LakePavilion", Vector3(x, 1, -8), Vector3(x, 1, 8), 1 << 19).is_empty(), "Pavilion navigation proxies preserve central bridge")
	_expect(_ray("LakePavilion", Vector3(0, 1, 0), Vector3(0, -0.5, 0), 1).is_empty(), "Pavilion adds no raised slab over authoritative bridge floor")
	_expect(not _ray("LakePavilion", Vector3(0, 9, 0), Vector3(0, 1, 0), 1).is_empty(), "Pavilion roof has exact physical camera collision")
	_expect(_ray("LakePavilion", Vector3(0, 9, 0), Vector3(0, 1, 0), 1 << 19).is_empty(), "Pavilion roof is excluded from navigation")
	for part_id in ["LakeSurface", "AshShore"]:
		var anchor: Node3D = _anchors["audit_" + part_id]
		_expect(anchor.find_children("*", "CollisionObject3D", true, false).is_empty(), part_id + " remains visual-only terrain dressing")
	var wall: Node3D = _anchors["scaled_wall"]
	# Sample the face of a masonry block, not the intentionally recessed center joint.
	var query := PhysicsRayQueryParameters3D.create(wall.to_global(Vector3(0.3, 1.7, -3)), wall.to_global(Vector3(0.3, 1.7, 3)), 1)
	_expect(not wall.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Scaled rotated visual and physical wall stay coincident under a transformed level")
	_level.queue_free()
	await process_frame
	_finish()


func _ray(part_id: String, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var anchor: Node3D = _anchors["audit_" + part_id]
	var query := PhysicsRayQueryParameters3D.create(anchor.to_global(from), anchor.to_global(to), mask)
	return anchor.get_world_3d().direct_space_state.intersect_ray(query)


func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _expect(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(message)
		push_error(message)
	return ok


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_STORY_PROP_ASSETS_CONTRACT_OK parts=46 placements=47 checks=%d" % _checks)
		quit(0)
	else:
		print("ASHEN_STORY_PROP_ASSETS_CONTRACT_FAILED failures=%d checks=%d" % [_failures.size(), _checks])
		quit(1)
