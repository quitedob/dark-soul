class_name ProceduralCampaignLevelBuilder
extends RefCounted

const ThemeFactory = preload("res://scripts/world/level_theme_factory.gd")
const LevelModules = preload("res://scripts/levels/procedural_level_modules.gd")
const ShortcutFold = preload("res://scripts/world/campaign_shortcut_fold.gd")
const TempleLayout = preload("res://scripts/world/awakening_temple_layout.gd")
const ModeledLayout = preload("res://scripts/world/campaign_modeled_layout.gd")
const EnvironmentRenderer = preload("res://scripts/world/campaign_environment_renderer.gd")
const StoryDressing = preload("res://scripts/data/campaign_scene_dressing.gd")
const StoryRenderer = preload("res://scripts/world/campaign_story_prop_renderer.gd")

const TILE_SIZE := 6.0
const FLOOR_HEIGHT := 0.6
const NAVIGATION_SOURCE_GROUP := &"campaign_navigation_source"
const TERRAIN_NAVIGATION_SOURCE_GROUP := &"campaign_terrain_navigation_source"


static func build(level_data: Dictionary) -> Node3D:
	var is_temple := StringName(level_data["id"]) == TempleLayout.LEVEL_ID
	var authored_layout: Dictionary = {}
	var temple_manifest: Dictionary = {}
	if is_temple:
		temple_manifest = TempleLayout.read_manifest()
		if temple_manifest.is_empty():
			return null
		authored_layout = TempleLayout.expanded_state(temple_manifest, level_data)
	else:
		authored_layout = ModeledLayout.create(level_data)
		if authored_layout.is_empty():
			return null
	var root := Node3D.new()
	root.name = "Level_%s" % String(level_data["id"])
	root.set_meta("level_id", level_data["id"])
	root.set_meta("topology", level_data["topology"])
	root.set_meta("seed", _seed_for(level_data))
	root.set_meta("shortcut_fold", level_data.get("shortcut_fold", {}))
	var theme := ThemeFactory.create(level_data["theme_id"])
	var cells: Array[Vector3i] = []
	cells.assign(authored_layout["cells"])
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	for index in cells.size():
		_add_tile(geometry, cells[index], index)
	if is_temple:
		if not TempleLayout.add_architecture(root, temple_manifest, authored_layout):
			root.free()
			return null
		# The first temple's explicit solids are already a low-detail source.
		var architecture := geometry.get_node("ArchitectureCollision")
		architecture.add_to_group(NAVIGATION_SOURCE_GROUP)
		architecture.add_to_group(TERRAIN_NAVIGATION_SOURCE_GROUP)
		_add_modeled_ramps(geometry, authored_layout)
		var extension_visuals := authored_layout.duplicate()
		var extension_cells: Array[Vector3i] = []
		for cell: Vector3i in cells:
			if not authored_layout["original_cells"].has(cell): extension_cells.append(cell)
		extension_visuals["cells"] = extension_cells
		extension_visuals["scenery_cells"] = cells
		if not EnvironmentRenderer.add_environment(geometry, extension_visuals):
			root.free()
			return null
	else:
		_add_modeled_ramps(geometry, authored_layout)
		if not EnvironmentRenderer.add_environment(geometry, authored_layout):
			root.free()
			return null
	_add_modules(root, level_data, cells, theme)
	_add_shortcut_fold(root, level_data, cells, theme)
	_add_markers(root, cells)
	if is_temple:
		TempleLayout.place_gameplay_nodes(root, temple_manifest)
		_place_expansion_fold(root, authored_layout)
		root.set_meta("modeled_layout", authored_layout)
		root.set_meta("encounter_positions", authored_layout["encounter_positions"])
	else:
		_place_modeled_gameplay(root, authored_layout)
	var story_layout := authored_layout
	if is_temple:
		# JSON coordinates are normalized before placement/encounter planning.
		# Preserve the temple's separate architecture metadata and collision path.
		story_layout["story_props"] = StoryDressing.plan_scene(level_data, story_layout)
		story_layout["story_anchors"] = StoryDressing.story_anchors(String(level_data["id"]))
	root.set_meta("story_layout", story_layout)
	root.set_meta("expansion", authored_layout.get("expansion", {}))
	root.set_meta("story_anchors", story_layout.get("story_anchors", {}))
	if not StoryRenderer.attach_to(root, story_layout.get("story_props", [])):
		root.free()
		return null
	_add_navigation(root, cells)
	root.set_meta("geometry_signature", _cell_signature(cells))
	root.set_meta("walkable_cell_count", cells.size())
	return root


static func _add_modeled_ramps(geometry: Node3D, layout: Dictionary) -> void:
	for entry: Dictionary in layout["ramps"]:
		var lower: Vector3i = entry["lower"]
		var upper: Vector3i = entry["upper"]
		var from := ModeledLayout.floor_position(lower)
		var to := ModeledLayout.floor_position(upper)
		var horizontal := to - from
		horizontal.y = 0.0
		var direction := horizontal.normalized()
		# A deliberately empty cell separates the landings. Bridge their edges,
		# so the upper floor never creates a vertical lip halfway up the slope.
		var lower_edge := from + direction * TILE_SIZE * 0.5
		var upper_edge := to - direction * TILE_SIZE * 0.5
		var delta := upper_edge - lower_edge
		var pitch := atan2(delta.y, Vector2(delta.x, delta.z).length())
		var yaw := atan2(-direction.x, -direction.z)
		var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
		var ramp := StaticBody3D.new()
		ramp.name = "HeightRamp"
		ramp.collision_layer = 1
		ramp.add_to_group(NAVIGATION_SOURCE_GROUP)
		ramp.add_to_group(TERRAIN_NAVIGATION_SOURCE_GROUP)
		ramp.transform = Transform3D(basis, (lower_edge + upper_edge) * 0.5 - basis.y * 0.14)
		ramp.set_meta("lower_cell", lower)
		ramp.set_meta("upper_cell", upper)
		ramp.set_meta("modeled_ramp", true)
		ramp.set_meta("lower_edge", lower_edge)
		ramp.set_meta("upper_edge", upper_edge)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(TILE_SIZE, 0.28, delta.length() + 0.05)
		collision.shape = shape
		ramp.add_child(collision)
		geometry.add_child(ramp)


static func _place_modeled_gameplay(root: Node3D, layout: Dictionary) -> void:
	for key: String in ["spawn", "checkpoint", "exit"]:
		(root.get_node("Markers/" + key.capitalize()) as Marker3D).position = layout[key]
	for module: Node3D in root.get_node("Modules").get_children():
		var id := String(module.get_meta("module_id", ""))
		module.position = layout["modules"][id]
		if id == "gate_exit":
			(module.get_node("ExitMarker") as Marker3D).position = layout["exit"] - module.position
			(module.get_node("Gate") as Node3D).position.y = 1.5
		elif id == "arena_seal":
			(module.get_node("ArenaSeal") as Node3D).position.y = 1.5
			(module.get_node("ArenaTrigger") as Node3D).position = Vector3(0, 1.5, -3)
	var door := root.get_node_or_null("ShortcutFold/OneWayDoor") as Node3D
	if door != null:
		door.position = layout["shortcut_door"]
		door.rotation.y = float(layout.get("shortcut_door_yaw", 0.0))
		(door.get_node("FarSideMarker") as Marker3D).position = door.transform.affine_inverse() * layout["shortcut_far_side"]
	var elevator := root.get_node_or_null("ShortcutFold/ElevatorLift") as Node3D
	if elevator != null:
		elevator.position = layout["shortcut_elevator"]
		var dock: Vector3 = layout["shortcut_dock"] - elevator.position
		elevator.set_meta("shrine_dock_local", dock)
		(elevator.get_node("ShrineDock") as Marker3D).position = dock
	_place_expansion_fold(root, layout)
	root.set_meta("modeled_layout", layout)
	root.set_meta("authored_environment", EnvironmentRenderer.KIT_DIRECTORY + String(layout["theme"]).trim_prefix("theme_") + ".glb")
	root.set_meta("encounter_positions", layout["encounter_positions"])
	for key: String in ["boss_arena_center", "boss_arena_radius", "boss_spawn"]:
		if layout.has(key):
			root.set_meta(key, layout[key])


static func _place_expansion_fold(root: Node3D, layout: Dictionary) -> void:
	var expansion: Dictionary = layout.get("expansion", {})
	if expansion.is_empty(): return
	var gate: Dictionary = expansion.get("return_gate", {})
	var door := root.get_node_or_null("ShortcutFold/OneWayDoor") as Node3D
	if door != null and not gate.is_empty():
		door.set_meta("physical_return_gate", true)
		door.position = gate["position"]
		door.rotation.y = float(gate["yaw"])
		(door.get_node("FarSideMarker") as Marker3D).position = door.transform.affine_inverse() * gate["far_side"]
		for wall: Dictionary in gate.get("walls", []):
			var body := StaticBody3D.new()
			body.name = "ShortcutGateMasonry"
			body.position = wall["position"]
			body.rotation.y = float(wall.get("yaw", 0.0))
			body.collision_layer = 1
			body.collision_mask = 0
			body.add_to_group(NAVIGATION_SOURCE_GROUP)
			body.add_to_group(TERRAIN_NAVIGATION_SOURCE_GROUP)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = wall["size"]
			shape.shape = box
			body.add_child(shape)
			LevelModules.add_solid_visual(body, box.size, String(layout["theme"]))
			root.get_node("Geometry").add_child(body)
	var lift: Dictionary = expansion.get("lift", {})
	var elevator := root.get_node_or_null("ShortcutFold/ElevatorLift") as Node3D
	if elevator != null and not lift.is_empty():
		elevator.position = lift["upper_dock"]
		# Six-metre shaft: the deck meets both fixed landing edges with a 5cm
		# seam. The legacy 3.6m plate left a 1.2m jump over empty space.
		var platform := elevator.get_node("LiftPlatform") as AnimatableBody3D
		for child in platform.get_children():
			if child is MeshInstance3D:
				platform.remove_child(child)
				child.free()
		var platform_shape := platform.get_child(0) as CollisionShape3D
		for child in platform.get_children():
			if child is CollisionShape3D: platform_shape = child
		var deck_size := Vector3(5.9, .35, 5.9)
		var deck := BoxShape3D.new()
		deck.size = deck_size
		platform_shape.shape = deck
		LevelModules.add_solid_visual(platform, deck_size, String(layout["theme"]))
		var dock: Vector3 = lift["lower_dock"] - elevator.position
		elevator.set_meta("shrine_dock_local", dock)
		elevator.set_meta("physical_lift", true)
		(elevator.get_node("ShrineDock") as Marker3D).position = dock


static func _seed_for(level_data: Dictionary) -> int:
	if level_data.has("seed"):
		return int(level_data["seed"])
	var level_id := String(level_data.get("id", "level_01_01"))
	return int(level_id.substr(6, 2)) * 100 + int(level_id.substr(9, 2))


static func _topology_cells(topology: StringName, seed: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	match topology:
		&"linear_corridor", &"memory_canyon", &"processional_path":
			for z_position in range(8):
				cells.append(Vector3i(0, 0, z_position))
		&"courtyard", &"multi_angle_hall", &"fortified_hub":
			for z_position in range(5):
				for x_position in range(-1, 2):
					cells.append(Vector3i(x_position, 0, z_position))
		&"hazard_wing", &"branching_camp", &"non_euclidean_branches":
			for z_position in range(7):
				cells.append(Vector3i(0, 0, z_position))
			for x_position in range(-3, 4):
				cells.append(Vector3i(x_position, 0, 3))
		&"vertical_tower", &"vertical_library", &"vertical_floating_path":
			for step in range(9):
				cells.append(Vector3i((step % 3) - 1, step / 3, step))
		&"winding_approach", &"open_shore":
			var x_position := 0
			for z_position in range(9):
				if z_position > 0 and z_position % 2 == 0:
					x_position += 1 if ((seed + z_position) % 4) < 2 else -1
				cells.append(Vector3i(x_position, 0, z_position))
		&"floating_platform_cluster", &"reflection_dual_plane", &"inverted_multi_surface":
			for z_position in range(6):
				cells.append(Vector3i(0, 0, z_position))
				if z_position in [1, 3, 4]:
					cells.append(Vector3i(1 if (seed + z_position) % 2 == 0 else -1, 0, z_position))
		&"looping_forest", &"shifting_maze":
			for z_position in range(7):
				cells.append(Vector3i(0, 0, z_position))
				if z_position in [1, 2, 4, 5]:
					var side := 1 if (seed + z_position) % 2 == 0 else -1
					cells.append(Vector3i(side, 0, z_position))
					cells.append(Vector3i(side * 2, 0, z_position))
		&"memorial_ring":
			cells.append(Vector3i.ZERO)
			for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				for distance in range(1, 4):
					cells.append(direction * distance)
		_:
			for z_position in range(5):
				for x_position in range(-2, 3):
					cells.append(Vector3i(x_position, 0, z_position))
	return cells


static func _add_tile(parent: Node3D, cell: Vector3i, index: int) -> void:
	# All visible paving comes from imported architecture. These simple hidden
	# solids give both actors and the navigation bake a continuous floor.
	var tile := StaticBody3D.new()
	tile.name = "Tile_%03d" % index
	tile.position = _cell_position(cell)
	tile.collision_layer = 1
	tile.add_to_group(NAVIGATION_SOURCE_GROUP)
	tile.add_to_group(TERRAIN_NAVIGATION_SOURCE_GROUP)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE, FLOOR_HEIGHT, TILE_SIZE)
	collision.shape = shape
	tile.add_child(collision)
	parent.add_child(tile)


static func _add_modules(root: Node3D, level_data: Dictionary, cells: Array[Vector3i], theme: Dictionary) -> void:
	var modules := LevelModules.build_level(level_data, theme["detail"])
	modules.name = "Modules"
	modules.add_to_group(NAVIGATION_SOURCE_GROUP)
	var module_children := modules.get_children()
	for index in range(module_children.size()):
		var module := module_children[index] as Node3D
		var ratio := float(index + 1) / float(module_children.size() + 1)
		var cell_index := clampi(roundi(ratio * float(cells.size() - 1)), 1, maxi(cells.size() - 2, 1))
		module.position = _cell_position(cells[cell_index]) + Vector3(0.0, FLOOR_HEIGHT * 0.5, 0.0)
	root.add_child(modules)


static func _add_shortcut_fold(root: Node3D, level_data: Dictionary, cells: Array[Vector3i], theme: Dictionary) -> void:
	# H-05：单向门 + 升降梯空间折叠
	var fold := ShortcutFold.build(level_data, cells, theme["structure"])
	if fold != null:
		fold.add_to_group(NAVIGATION_SOURCE_GROUP)
		root.add_child(fold)


static func _add_markers(root: Node3D, cells: Array[Vector3i]) -> void:
	var markers := Node3D.new()
	markers.name = "Markers"
	root.add_child(markers)
	var spawn_cell := _closest_cell(cells, Vector3i(0, 0, 0))
	var checkpoint_cell := _closest_cell(cells, Vector3i(0, 0, 1))
	_add_marker(markers, "Spawn", &"level_spawn", _cell_position(spawn_cell) + Vector3(0.0, 1.4, 2.0))
	_add_marker(markers, "Checkpoint", &"level_checkpoint", _cell_position(checkpoint_cell) + Vector3(0.0, FLOOR_HEIGHT * 0.5, 0.0))
	_add_marker(markers, "Exit", &"level_exit", _cell_position(cells.back()) + Vector3.UP)


static func _closest_cell(cells: Array[Vector3i], target: Vector3i) -> Vector3i:
	var closest: Vector3i = cells.front()
	var closest_distance: int = closest.distance_squared_to(target)
	for cell in cells:
		var distance: int = cell.distance_squared_to(target)
		if distance < closest_distance:
			closest = cell
			closest_distance = distance
	return closest


static func _add_marker(parent: Node3D, marker_name: String, group: StringName, position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = position
	marker.add_to_group(group)
	parent.add_child(marker)


static func _add_navigation(root: Node3D, cells: Array[Vector3i]) -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationSurface"
	var navigation_mesh := NavigationMesh.new()
	if root.has_meta("modeled_layout"):
		# Half-metre voxels match the actor radius and omit tiny ornamental
		# ledges; height matches the production World3D navigation map.
		navigation_mesh.cell_size = 0.5
		navigation_mesh.cell_height = 0.25
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_height = 2.0
	navigation_mesh.agent_max_climb = 1.0
	navigation_mesh.agent_max_slope = 45.0
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_collision_mask = 1 | EnvironmentRenderer.NAVIGATION_PROXY_LAYER
	navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_mesh.geometry_source_group_name = NAVIGATION_SOURCE_GROUP
	region.navigation_mesh = navigation_mesh
	region.set_meta("walkable_cells", cells.duplicate())
	root.add_child(region)


static func _cell_position(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, cell.y * 2.0 - FLOOR_HEIGHT * 0.5, -cell.z * TILE_SIZE)


## Synchronous placement uses generated terrain, before the new physics space syncs.
## Keep supported authored positions; project exposed footprints onto the nearest tile.
static func supported_spawn(cells: Array, candidate: Vector3, radius := 0.6, clearance := 0.05) -> Vector3:
	if cells.is_empty():
		return candidate
	var floor_y := _tile_floor_at(cells, candidate)
	var supported := is_finite(floor_y)
	for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var edge_floor := _tile_floor_at(cells, candidate + direction * radius)
		if not is_finite(edge_floor) or not is_equal_approx(edge_floor, floor_y):
			supported = false
	if supported and candidate.y >= floor_y + clearance - 0.001:
		return candidate
	var margin := maxf(TILE_SIZE * 0.5 - radius - 0.1, 0.1)
	var nearest := candidate
	var distance := INF
	for cell: Vector3i in cells:
		var center := _cell_position(cell)
		var point := Vector3(clampf(candidate.x, center.x - margin, center.x + margin),
			float(cell.y) * 2.0 + clearance, clampf(candidate.z, center.z - margin, center.z + margin))
		var candidate_distance := point.distance_squared_to(candidate)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = point
	return nearest


static func _tile_floor_at(cells: Array, point: Vector3) -> float:
	var floor_y := -INF
	for cell: Vector3i in cells:
		var center := _cell_position(cell)
		var top := float(cell.y) * 2.0
		if absf(point.x - center.x) <= TILE_SIZE * 0.5 and absf(point.z - center.z) <= TILE_SIZE * 0.5:
			if top <= point.y + 0.001:
				floor_y = maxf(floor_y, top)
	return floor_y


static func _cell_signature(cells: Array[Vector3i]) -> String:
	var values: PackedStringArray = []
	for cell in cells:
		values.append("%d,%d,%d" % [cell.x, cell.y, cell.z])
	return ";".join(values)
