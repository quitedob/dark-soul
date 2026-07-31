class_name ProceduralCampaignLevelBuilder
extends RefCounted

const ThemeFactory = preload("res://scripts/world/level_theme_factory.gd")
const LevelModules = preload("res://scripts/levels/procedural_level_modules.gd")
const ShortcutFold = preload("res://scripts/world/campaign_shortcut_fold.gd")

const TILE_SIZE := 6.0
const FLOOR_HEIGHT := 0.6


static func build(level_data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Level_%s" % String(level_data["id"])
	root.set_meta("level_id", level_data["id"])
	root.set_meta("topology", level_data["topology"])
	root.set_meta("seed", _seed_for(level_data))
	root.set_meta("shortcut_fold", level_data.get("shortcut_fold", {}))
	var theme := ThemeFactory.create(level_data["theme_id"])
	var cells := _topology_cells(level_data["topology"], _seed_for(level_data))
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	for index in cells.size():
		_add_tile(geometry, cells[index], theme, index, _seed_for(level_data))
	_add_height_ramps(geometry, cells, theme)
	_add_modules(root, level_data, cells, theme)
	_add_shortcut_fold(root, level_data, cells, theme)
	_add_markers(root, cells)
	_add_navigation(root, cells)
	root.set_meta("geometry_signature", _cell_signature(cells))
	root.set_meta("walkable_cell_count", cells.size())
	return root


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


static func _add_tile(parent: Node3D, cell: Vector3i, theme: Dictionary, index: int, seed: int) -> void:
	var tile := StaticBody3D.new()
	tile.name = "Tile_%03d" % index
	tile.position = _cell_position(cell)
	tile.collision_layer = 1
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TILE_SIZE, FLOOR_HEIGHT, TILE_SIZE)
	mesh.material = theme["ground"] if index % 3 else theme["detail"]
	mesh_instance.mesh = mesh
	tile.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	tile.add_child(collision)
	parent.add_child(tile)
	if (index * 7 + seed) % 5 == 0:
		_add_pillar(parent, tile.position + Vector3(TILE_SIZE * 0.38, 1.8, 0.0), theme)


static func _add_pillar(parent: Node3D, position: Vector3, theme: Dictionary) -> void:
	# 柱子需可碰撞，避免只有视觉无阻挡
	var pillar := StaticBody3D.new()
	pillar.name = "KitPillar"
	pillar.collision_layer = 1
	pillar.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.55
	mesh.height = 3.6
	mesh.radial_segments = 6
	mesh.material = theme["structure"]
	mesh_instance.mesh = mesh
	pillar.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.48
	shape.height = 3.6
	collision.shape = shape
	pillar.add_child(collision)
	parent.add_child(pillar)


static func _add_height_ramps(parent: Node3D, cells: Array[Vector3i], theme: Dictionary) -> void:
	# 高度差为 1 的邻近格，以及路径上连续台阶，铺坡道保证垂直拓扑可达
	var added: Dictionary = {}
	for i in range(cells.size()):
		for j in range(i + 1, cells.size()):
			var a: Vector3i = cells[i]
			var b: Vector3i = cells[j]
			if absi(a.y - b.y) != 1:
				continue
			var dx := absi(a.x - b.x)
			var dz := absi(a.z - b.z)
			# 允许对角一步（dx=1,dz=1）连接螺旋塔
			if maxi(dx, dz) > 1:
				continue
			var lower := a if a.y < b.y else b
			var upper := b if a.y < b.y else a
			var ramp_key := "%d,%d,%d>%d,%d,%d" % [lower.x, lower.y, lower.z, upper.x, upper.y, upper.z]
			if added.has(ramp_key):
				continue
			added[ramp_key] = true
			_add_ramp(parent, lower, upper, theme)
	# 路径顺序兜底：连续格子高度变化时强制连坡
	for index in range(cells.size() - 1):
		var a2: Vector3i = cells[index]
		var b2: Vector3i = cells[index + 1]
		if absi(a2.y - b2.y) != 1:
			continue
		var lower2 := a2 if a2.y < b2.y else b2
		var upper2 := b2 if a2.y < b2.y else a2
		var key2 := "%d,%d,%d>%d,%d,%d" % [lower2.x, lower2.y, lower2.z, upper2.x, upper2.y, upper2.z]
		if added.has(key2):
			continue
		added[key2] = true
		_add_ramp(parent, lower2, upper2, theme)


static func _add_ramp(parent: Node3D, lower: Vector3i, upper: Vector3i, theme: Dictionary) -> void:
	var from_pos := _cell_position(lower)
	var to_pos := _cell_position(upper)
	var mid := (from_pos + to_pos) * 0.5
	mid.y = (from_pos.y + to_pos.y) * 0.5 + FLOOR_HEIGHT * 0.25
	var delta := to_pos - from_pos
	delta.y = 0.0
	var horizontal := delta.length()
	if horizontal < 0.01:
		horizontal = TILE_SIZE
	var rise := absf(to_pos.y - from_pos.y)
	var ramp_length := sqrt(horizontal * horizontal + rise * rise)
	var ramp := StaticBody3D.new()
	ramp.name = "HeightRamp"
	ramp.collision_layer = 1
	ramp.position = mid
	# 朝向上层格子
	var yaw := atan2(-delta.x, -delta.z)
	var pitch := -atan2(rise, horizontal)
	ramp.rotation = Vector3(pitch, yaw, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TILE_SIZE * 0.9, 0.28, ramp_length)
	mesh.material = theme["detail"]
	mesh_instance.mesh = mesh
	ramp.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	ramp.add_child(collision)
	parent.add_child(ramp)


static func _add_modules(root: Node3D, level_data: Dictionary, cells: Array[Vector3i], theme: Dictionary) -> void:
	var modules := LevelModules.build_level(level_data, theme["detail"])
	modules.name = "Modules"
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
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_height = 2.0
	navigation_mesh.agent_max_climb = 1.0
	navigation_mesh.agent_max_slope = 45.0
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh = navigation_mesh
	region.set_meta("walkable_cells", cells.duplicate())
	root.add_child(region)


static func _add_environment(root: Node3D, theme: Dictionary) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ThemeEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = theme["sky"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = theme["accent_color"]
	environment.ambient_light_energy = 0.25
	world_environment.environment = environment
	root.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	light.light_color = theme["accent_color"]
	light.light_energy = 0.9
	root.add_child(light)


static func _cell_position(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, cell.y * 2.0 - FLOOR_HEIGHT * 0.5, -cell.z * TILE_SIZE)


static func _cell_signature(cells: Array[Vector3i]) -> String:
	var values: PackedStringArray = []
	for cell in cells:
		values.append("%d,%d,%d" % [cell.x, cell.y, cell.z])
	return ";".join(values)
