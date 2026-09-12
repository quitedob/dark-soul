class_name CampaignEnvironmentRenderer
extends RefCounted
## Imported artist-built parts share meshes/materials and are submitted in batches.
## Native floor/ramp shapes remain authoritative for walking and navigation.

const Layout = preload("res://scripts/world/campaign_modeled_layout.gd")
const KIT_DIRECTORY := "res://assets/environment/threejs_campaign/"
const NAVIGATION_PROXY_LAYER := 1 << 19
const PARTS := ["Floor", "Bridge", "Rail", "Column", "Gate", "Landmark", "Rock", "ArenaCover", "Wall", "Arcade", "Watchtower", "Lantern", "Roof"]
static var _kits: Dictionary = {}


static func instantiate_part(theme: StringName, part: String) -> Node3D:
	var kit := String(theme).trim_prefix("theme_")
	if not PARTS.has(part) or not _load_kit(kit):
		push_error("Required modeled campaign part is unavailable: %s/%s" % [kit, part])
		return null
	var root := Node3D.new()
	root.name = part
	root.set_meta("kit_path", KIT_DIRECTORY + kit + ".glb")
	for descriptor: Dictionary in _kits[kit][part]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = descriptor["mesh"]
		mesh.transform = descriptor["transform"]
		mesh.material_override = descriptor["material"]
		root.add_child(mesh)
	return root


static func add_environment(geometry: Node3D, layout: Dictionary) -> bool:
	var kit_name := String(layout["theme"]).trim_prefix("theme_")
	if not _load_kit(kit_name):
		return false
	var modeled := Node3D.new()
	modeled.name = "ModeledEnvironment"
	modeled.set_meta("kit_path", KIT_DIRECTORY + kit_name + ".glb")
	geometry.add_child(modeled)
	var batches: Dictionary = {}
	var counts: Dictionary = {}
	var cell_set: Dictionary = layout["cell_set"]
	for cell: Vector3i in layout["cells"]:
		var at := Layout.floor_position(cell)
		_queue(batches, kit_name, "Floor", Transform3D(Basis.IDENTITY, at), counts)
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if cell_set.has(cell + direction) or layout["open_edges"].has(Layout.edge_key(cell, direction)):
				continue
			var world_direction := Vector3(direction.x, 0, -direction.z)
			var yaw := PI * 0.5 if direction.x != 0 else 0.0
			var transform := Transform3D(Basis(Vector3.UP, yaw), at + world_direction * 2.88)
			_queue(batches, kit_name, "Rail", transform, counts)
			_box(modeled, "RailSolid", transform, Vector3(0, 0.7, 0), Vector3(6, 1.4, 0.48))
	for body: Node in geometry.get_children():
		if body is StaticBody3D and body.has_meta("modeled_ramp"):
			var shape := (body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
			var size := shape.size
			var transform: Transform3D = body.transform
			transform.basis = transform.basis.scaled_local(Vector3(size.x / 6.0, size.y / 0.28, size.z / 6.0))
			_queue(batches, kit_name, "Bridge", transform, counts)
	for feature: Dictionary in layout["features"]:
		var transform := Transform3D(Basis(Vector3.UP, float(feature["yaw"])).scaled_local(feature["scale"]), feature["position"])
		var part := String(feature["part"])
		_queue(batches, kit_name, part, transform, counts)
		_feature_collision(modeled, kit_name, part, transform)
	# The route is a built place: retaining masonry below, broken walls and
	# covered galleries above. Chapter-specific omissions frame distant goals.
	var architecture: Array = _boundary_architecture(layout)
	architecture.append_array(layout.get("expansion", {}).get("architecture", []))
	for feature: Dictionary in architecture:
		var transform := Transform3D(Basis(Vector3.UP, float(feature.get("yaw", 0.0))).scaled_local(feature.get("scale", Vector3.ONE)), feature["position"])
		var part := String(feature["part"])
		_queue(batches, kit_name, part, transform, counts)
		if bool(feature.get("collision", true)):
			_feature_collision(modeled, kit_name, part, transform)
	# Two irregular depths of silhouettes frame the whole vista. Unlike the old
	# sparse cell filter, this also frames high routes and their terminal courts.
	# The actual transformed mesh bounds remain outside the complete floor plan.
	var horizon := _horizon_transforms(layout, kit_name)
	for transform: Transform3D in horizon:
		_queue(batches, kit_name, "Rock", transform, counts)
		_triangle_collision(modeled, kit_name, "Rock", transform)
	modeled.set_meta("scenery_rock_count", horizon.size())
	modeled.set_meta("scenery_minimum_clearance", 8.0)
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var transforms: Array = batch["transforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch["mesh"]
		multi.instance_count = transforms.size()
		for index in transforms.size():
			multi.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Kit_%s_%d" % [batch["part"], modeled.get_child_count()]
		instance.multimesh = multi
		instance.material_override = batch["material"]
		instance.set_meta("kit_part", batch["part"])
		instance.set_meta("kit_path", KIT_DIRECTORY + batch["kit"] + ".glb")
		modeled.add_child(instance)
	modeled.set_meta("part_counts", counts)
	modeled.set_meta("batch_count", batches.size())
	return true


static func _load_kit(kit: String) -> bool:
	if _kits.has(kit):
		return true
	var path := KIT_DIRECTORY + kit + ".glb"
	if not ResourceLoader.exists(path):
		push_error("Required campaign architecture is missing: " + path)
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Invalid campaign architecture scene: " + path)
		return false
	var root := scene.instantiate() as Node3D
	var parts: Dictionary = {}
	for part: String in PARTS:
		var part_root := root.get_node_or_null(NodePath(part)) as Node3D
		if part_root == null:
			push_error(path + " is missing required part " + part)
			root.free()
			return false
		var descriptors: Array[Dictionary] = []
		_collect_meshes(part_root, Transform3D.IDENTITY, descriptors)
		if descriptors.is_empty():
			push_error(path + " has an empty required part " + part)
			root.free()
			return false
		parts[part] = descriptors
	root.free()
	_kits[kit] = parts
	return true


static func _collect_meshes(node: Node3D, parent: Transform3D, result: Array[Dictionary]) -> void:
	var transform := parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		result.append({"mesh": node.mesh, "transform": transform, "material": node.material_override})
	for child in node.get_children():
		if child is Node3D:
			_collect_meshes(child, transform, result)


static func _queue(batches: Dictionary, kit: String, part: String, transform: Transform3D, counts: Dictionary) -> void:
	counts[part] = int(counts.get(part, 0)) + 1
	var descriptors: Array = _kits[kit][part]
	for index in descriptors.size():
		var descriptor: Dictionary = descriptors[index]
		var key := "%s/%s/%d" % [kit, part, index]
		if not batches.has(key):
			batches[key] = {"kit": kit, "part": part, "mesh": descriptor["mesh"], "material": descriptor["material"], "transforms": []}
		batches[key]["transforms"].append(transform * descriptor["transform"])


static func _box(parent: Node3D, label: String, transform: Transform3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.set_meta("architecture_kind", label)
	# Approximate landmark solids guide navigation only. Their imported triangle
	# shapes handle actual contact, preserving open arches and tapering spires.
	body.collision_layer = NAVIGATION_PROXY_LAYER if label.begins_with("Landmark") else 1
	body.collision_mask = 0
	body.add_to_group("campaign_navigation_source")
	body.add_to_group("campaign_terrain_navigation_source")
	body.transform = transform
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	body.add_child(collision)
	parent.add_child(body)


static func _feature_collision(parent: Node3D, kit: String, part: String, transform: Transform3D) -> void:
	match part:
		"Wall":
			_triangle_collision(parent, kit, part, transform)
		"Arcade":
			_triangle_collision(parent, kit, part, transform)
		"Roof", "Watchtower":
			_triangle_collision(parent, kit, part, transform)
		"Gate":
			var size := Vector3(1.9, 6, 1.9)
			if kit == "blood_iron":
				size = Vector3(1.7, 6, 1.7)
			elif kit == "ember_abyss":
				size = Vector3(2.12, 6.3, 2.18)
			for side in [-1, 1]:
				_box(parent, "GatePillarSolid", transform, Vector3(side * 4.8, size.y * 0.5, 0), size)
		"Column", "ArenaCover":
			_triangle_collision(parent, kit, part, transform)
		"Landmark":
			# Actual arches, columns and masonry block actors/cameras, including
			# details which cannot be represented by one enclosing box.
			_triangle_collision(parent, kit, part, transform)
			match kit:
				"spirit_ruins", "celestial_fall":
					_box(parent, "LandmarkPlinth", transform, Vector3(0, 0.25, 0), Vector3(11.5, 0.5, 10.5))
					_box(parent, "LandmarkUpperPlinth", transform, Vector3(0, 0.67, 0), Vector3(10.4, 0.34, 9.4))
					for x_side in [-1, 1]:
						for z_side in [-1, 1]:
							_box(parent, "LandmarkColumn", transform, Vector3(x_side * 3.55, 3.01, z_side * 2.7), Vector3(1.4, 4.38, 1.4))
					if kit == "spirit_ruins":
						_box(parent, "LandmarkStatue", transform, Vector3(0, 2.5, 0), Vector3(2.5, 3.4, 2.5))
						for x: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
							_box(parent, "LandmarkMasonry", transform, Vector3(x, 1.63, 2.7), Vector3(1.4, 1.39, 0.6))
				"jade_veil":
					_box(parent, "LandmarkPlinth", transform, Vector3(0, 0.22, 0), Vector3(10.8, 0.44, 8.8))
					for side in [-1, 1]:
						_box(parent, "LandmarkArchSide", transform, Vector3(side * 2.5, 2.9, 0), Vector3(0.9, 3.0, 0.8))
				"blood_iron":
					_box(parent, "LandmarkPlinth", transform, Vector3(0, 0.25, 0), Vector3(10.5, 0.5, 9.5))
					_box(parent, "LandmarkCore", transform, Vector3(0, 2.5, 0), Vector3(2.5, 5, 2.5))
					for side in [-1, 1]:
						_box(parent, "LandmarkWall", transform, Vector3(side * 3.3, 2.7, 0), Vector3(0.65, 5.2, 6.4))
						_box(parent, "LandmarkFrontWall", transform, Vector3(side * 2.48, 2.69, -3.2), Vector3(2.4, 5.15, 0.7))
					_box(parent, "LandmarkBackWall", transform, Vector3(0, 2.69, 3.2), Vector3(7.36, 5.15, 0.7))
					_box(parent, "LandmarkLintel", transform, Vector3(0, 4.25, -3.2), Vector3(2.4, 2.03, 0.7))
				"ember_abyss":
					_box(parent, "LandmarkPlinth", transform, Vector3(0, 0.5, 0), Vector3(4.6, 1, 4.6))
					_box(parent, "LandmarkCore", transform, Vector3(0, 4, 0), Vector3(3, 8, 3))
					for index in 7:
						var angle := TAU * index / 7.0
						_box(parent, "LandmarkSpire", transform, Vector3(cos(angle) * 3.2, 5, sin(angle) * 3.2), Vector3(1.8, 10, 1.8))


static func _triangle_collision(parent: Node3D, kit: String, part: String, transform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = part + "Solid"
	body.set_meta("architecture_kind", part + "Solid")
	body.transform = transform
	body.collision_layer = 1
	# Distant rock triangles remain physical camera blockers, but are not walkable
	# terrain. Tiny decorative facets otherwise create spurious nav edge islands.
	if part not in ["Rock", "Landmark", "Watchtower", "Roof"]:
		body.add_to_group("campaign_navigation_source")
		body.add_to_group("campaign_terrain_navigation_source")
	for descriptor: Dictionary in _kits[kit][part]:
		var collision := CollisionShape3D.new()
		if not descriptor.has("collision"):
			descriptor["collision"] = (descriptor["mesh"] as Mesh).create_trimesh_shape()
		collision.shape = descriptor["collision"]
		collision.transform = descriptor["transform"]
		body.add_child(collision)
	parent.add_child(body)


static func _boundary_architecture(layout: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cells: Dictionary = layout["cell_set"]
	var chapter := int(String(layout["id"]).substr(6, 2))
	for cell: Vector3i in layout["cells"]:
		var at := Layout.floor_position(cell)
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if cells.has(cell + direction) or layout["open_edges"].has(Layout.edge_key(cell, direction)):
				continue
			var edge := at + Vector3(direction.x, 0, -direction.z) * 3.05
			var yaw := PI * .5 if direction.x != 0 else 0.0
			var serial := absi(cell.x * 13 + cell.z * 7 + cell.y * 3 + direction.x + chapter)
			# Cell edges get a believable foundation rather than a paper-thin tile.
			# In the falling city, only intermittent buttresses survive below it.
			if chapter != 4 or serial % 3 == 0:
				result.append({"part": "Wall", "position": edge - Vector3.UP * 10.0,
					"yaw": yaw, "scale": Vector3.ONE, "collision": false})
			if at.z > -22.0 or serial % 4 == 0 or _story_footprint_near(layout, edge, 2.2):
				continue
			# Never close a high/low route crossing with a ten-metre wall.
			var headroom := true
			for height in range(1, 6):
				for offset in [Vector3i.ZERO, direction]:
					if cells.has(cell + offset + Vector3i(0, height, 0)):
						headroom = false
			if not headroom: continue
			if chapter == 3 and serial % 3 != 0: continue
			if chapter == 4 and serial % 4 != 1: continue
			var part := "Wall" if chapter == 2 or serial % 3 == 0 else "Arcade"
			result.append({"part": part, "position": edge, "yaw": yaw, "scale": Vector3.ONE})
	return result


static func _story_footprint_near(layout: Dictionary, point: Vector3, margin: float) -> bool:
	for prop: Dictionary in layout.get("story_props", []):
		var at: Vector3 = prop["position"]
		if absf(point.y - at.y) > 8.0: continue
		var footprint: Vector2 = preload("res://scripts/data/campaign_scene_dressing.gd").footprint(prop)
		var radius := footprint.length() * .5 + margin
		if Vector2(point.x - at.x, point.z - at.z).length() < radius: return true
	for marker: Vector3 in layout.get("modules", {}).values():
		if point.distance_to(marker) < margin + 5.0: return true
	return false


static func _horizon_transforms(layout: Dictionary, kit: String) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var floor_min := Vector3(INF, INF, INF)
	var floor_max := Vector3(-INF, -INF, -INF)
	for cell: Vector3i in layout.get("scenery_cells", layout["cells"]):
		var at := Layout.floor_position(cell)
		floor_min = floor_min.min(at - Vector3(3, 0, 3))
		floor_max = floor_max.max(at + Vector3(3, 0, 3))
	var rock_bounds := _part_bounds(kit, "Rock")
	var seed_offset := posmod(String(layout["id"]).hash(), 97)
	# All heights contribute to the same projected exclusion envelope. Large
	# formations cannot intrude into an upper gallery merely because ground is low.
	for along_z in [true, false]:
		var from := floor_min.z if along_z else floor_min.x
		var to := floor_max.z if along_z else floor_max.x
		var intervals := maxi(ceili((to - from) / 14.0), 1)
		for index in intervals + 1:
			var along := lerpf(from, to, float(index) / float(intervals))
			for side in [-1, 1]:
				var serial := seed_offset + index * 7 + (0 if side < 0 else 3) + (0 if along_z else 31)
				result.append(_horizon_formation(rock_bounds, floor_min, floor_max, along_z, along, side, serial, false))
				if index % 2 == 0:
					result.append(_horizon_formation(rock_bounds, floor_min, floor_max, along_z, along + 6.0, side, serial + 43, true))
	return result


static func _horizon_formation(rock_bounds: AABB, floor_min: Vector3, floor_max: Vector3,
		along_z: bool, along: float, side: int, serial: int, distant: bool) -> Transform3D:
	var variation := fposmod(sin(float(serial) * 12.9898) * 43758.5453, 1.0)
	var width := lerpf(1.15, 1.85, variation) if not distant else lerpf(1.8, 2.65, variation)
	var height := lerpf(1.35, 2.1, variation) if not distant else lerpf(2.15, 3.0, variation)
	# High libraries and towers still have peaks above their topmost route.
	height = maxf(height, (floor_max.y + 28.0) / maxf(rock_bounds.size.y, 1.0))
	var basis := Basis(Vector3.UP, float(serial) * 1.618).scaled_local(Vector3(width, height, width))
	var rotated_bounds := Transform3D(basis, Vector3.ZERO) * rock_bounds
	var clearance := 8.0 + variation * 5.0 + (25.0 if distant else 0.0)
	var at := Vector3(0, -8.0 if not distant else -15.0, 0)
	if along_z:
		at.z = along + sin(float(serial)) * 2.5
		at.x = floor_min.x - clearance - rotated_bounds.end.x if side < 0 \
			else floor_max.x + clearance - rotated_bounds.position.x
	else:
		at.x = along + sin(float(serial)) * 2.5
		at.z = floor_min.z - clearance - rotated_bounds.end.z if side < 0 \
			else floor_max.z + clearance - rotated_bounds.position.z
	return Transform3D(basis, at)


static func _part_bounds(kit: String, part: String) -> AABB:
	var bounds := AABB()
	var first := true
	for descriptor: Dictionary in _kits[kit][part]:
		var mesh_bounds: AABB = descriptor["transform"] * (descriptor["mesh"] as Mesh).get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
	return bounds
