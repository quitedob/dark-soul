extends SceneTree
## Actual opening world, imported architecture, collision, navigation and exit.
## Save I/O stays in memory; the production level/navigation lifecycle is intact.
const Layout = preload("res://scripts/world/awakening_temple_layout.gd")
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()

	func _save_run(_reason: String) -> bool:
		_snapshot_run_state()
		return true


var _failures: Array[String] = []
var _world: AuditWorld
var _routes_checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := Layout.read_manifest()
	if not _expect(not manifest.is_empty() and ResourceLoader.exists(Layout.MODEL_PATH),
			"Opening temple requires its real layout and imported GLB"):
		_finish()
		return
	_world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		_world.add_child(child)
	contents.free()
	root.add_child(_world)
	_world.set_process(false)
	_freeze_actors()
	await process_frame
	var current: Node3D = _world.campaign_runtime.current_level
	if not _expect(current != null and _world.campaign_runtime.current_level_id == Layout.LEVEL_ID,
			"Fresh gameplay must start in the modeled opening temple"):
		_world.free()
		_finish()
		return
	_expect(_world.campaign_runtime.registry.get_levels().size() == 29, "Temple must retain the 29-level campaign")
	var navigation := current.get_node("NavigationSurface") as NavigationRegion3D
	var spawn: Vector3 = current.get_node("Markers/Spawn").global_position
	var ready := await _await_navigation(navigation, spawn)
	_expect(ready, "Production opening navigation never published its baked region")
	await physics_frame
	await physics_frame
	_freeze_actors()
	_check_architecture(current, manifest)
	_check_anchors(current, manifest)
	if ready:
		_check_routes(current, navigation)
		await _check_pavilion_ramps(current, navigation)
	var imported_model := current.get_node("Geometry/AuthoredTemple")
	var gate := current.get_node("Modules/GateExit/GateExitInteract") as Area3D
	var exit_marker := current.get_node("Modules/GateExit/ExitMarker") as Marker3D
	var interact_shape := gate.get_child(0) as CollisionShape3D
	_expect(interact_shape.global_position.is_equal_approx(exit_marker.global_position),
		"The actual exit interaction collision must be at the terminal exit marker")
	var overlap_query := PhysicsShapeQueryParameters3D.new()
	var overlap_sphere := SphereShape3D.new()
	overlap_sphere.radius = 0.05
	overlap_query.shape = overlap_sphere
	overlap_query.transform.origin = exit_marker.global_position + Vector3.UP * 0.8
	overlap_query.collision_mask = 8
	overlap_query.collide_with_bodies = false
	overlap_query.collide_with_areas = true
	var found_exit := false
	for hit: Dictionary in _world.get_world_3d().direct_space_state.intersect_shape(overlap_query):
		if hit["collider"] == gate:
			found_exit = true
	_expect(found_exit, "A player at the terminal marker must overlap the real exit interaction")
	_world.player.global_position = exit_marker.global_position + Vector3.UP
	# Let the real Area sensor update, then use the actual nearest-target scanner.
	await physics_frame
	await physics_frame
	_world._update_interaction_target()
	_expect(_world.interaction_candidates.has(gate) and _world.player.interaction_target == gate,
		"Normal player interaction scanning must select the terminal gate")
	if _world.player.interaction_target == gate:
		_world.player.interaction_target.interact(_world.player)
	else:
		_world.free()
		_finish()
		return
	await process_frame
	_freeze_actors()
	_expect(_world.campaign_runtime.current_level_id == &"level_01_02",
		"Using the actual terminal exit must advance to level_01_02")
	_expect("level_01_01" in _world.run_state.completed_levels, "Terminal exit must record opening completion")
	_expect(not is_instance_valid(current) and not is_instance_valid(imported_model),
		"Leaving the opening level must free its imported architecture and collision")
	var next: Node3D = _world.campaign_runtime.current_level
	_expect(next.get_node_or_null("Geometry/AuthoredTemple") == null,
		"Authored temple must not leak into the other 28 levels")
	_expect(next.has_node("Geometry/ModeledEnvironment") and next.get_node("Geometry/Tile_001").find_children("*", "MeshInstance3D", true, false).is_empty(),
		"The next level must use its own imported campaign architecture")
	var next_navigation := next.get_node("NavigationSurface") as NavigationRegion3D
	var next_spawn: Vector3 = next.get_node("Markers/Spawn").global_position
	_expect(await _await_navigation(next_navigation, next_spawn), "Next level must publish its own navigation after temple exit")
	print("AWAKENING_TEMPLE_EVIDENCE cells=%d routes=%d collision_boxes=%d" %
		[manifest["walkable_cells"].size(), _routes_checked, manifest["collision_boxes"].size()])
	_world.free()
	await process_frame
	_finish()


func _check_architecture(current: Node3D, manifest: Dictionary) -> void:
	for path: String in ["Geometry", "Modules", "Markers", "NavigationSurface"]:
		_expect(current.has_node(path), "Opening temple lost campaign interface " + path)
	_expect(current.get_meta("authored_environment", "") == Layout.MODEL_PATH, "Model provenance is missing")
	var model := current.get_node("Geometry/AuthoredTemple") as Node3D
	_expect(model.find_child("Cube", true, false) == null, "Default Blender cube leaked into the authored temple")
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	_expect(meshes.size() >= 12, "Opening temple requires modeled architecture and paving, not a single floor primitive")
	var material_ids: Dictionary = {}
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		_expect(mesh.mesh is ArrayMesh, "Authored temple meshes must come from the imported GLB")
		var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			_expect(material != null, "Imported temple surface is missing a material")
			if material != null:
				material_ids[material.get_instance_id()] = true
	_expect(bounds.size.x >= 95.0 and bounds.size.z >= 130.0 and bounds.size.y >= 6.0,
		"Opening model must occupy a large, three-dimensional temple rather than the old small courtyard: " + str(bounds))
	_expect(material_ids.size() >= 4, "Opening architecture needs authored material separation")
	_expect(model.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Imported roof/ornament must not acquire automatic whole-mesh colliders")
	var tiles := 0
	for child in current.get_node("Geometry").get_children():
		if String(child.name).begins_with("Tile_"):
			tiles += 1
			_expect(child is StaticBody3D and child.collision_layer == 1, "A walkable tile lost its physical floor")
			_expect(child.find_children("*", "MeshInstance3D", true, false).is_empty(),
				"Visible procedural tiles must not cover the authored paving")
		_expect(not String(child.name).contains("KitPillar"), "Random kit cylinders must not appear in the authored temple")
	_expect(tiles == manifest["walkable_cells"].size() and tiles >= 200, "Manifest terrain was not fully instantiated")
	var cells: Array = current.get_node("NavigationSurface").get_meta("walkable_cells")
	_expect(cells.size() == tiles and int(current.get_meta("walkable_cell_count")) == tiles,
		"Navigation and supported-placement metadata must use the expanded terrain")
	var min_cell := Vector3i.ZERO
	var max_cell := Vector3i.ZERO
	for cell: Vector3i in cells:
		min_cell = min_cell.min(cell)
		max_cell = max_cell.max(cell)
	_expect((max_cell.x - min_cell.x + 1) * 6 >= 96 and (max_cell.z - min_cell.z + 1) * 6 >= 140,
		"The physical playable footprint, not just distant scenery, must span the enlarged temple")
	var collision_root := current.get_node("Geometry/ArchitectureCollision")
	_expect(collision_root.get_child_count() == manifest["collision_boxes"].size(), "Architecture collision inventory mismatch")
	for index in collision_root.get_child_count():
		var body := collision_root.get_child(index) as StaticBody3D
		var entry: Dictionary = manifest["collision_boxes"][index]
		var shape := body.get_child(0) as CollisionShape3D
		_expect(body.position.is_equal_approx(Layout.vector(entry["position"]))
			and (shape.shape as BoxShape3D).size.is_equal_approx(Layout.vector(entry["size"]))
			and is_equal_approx(body.rotation.x, float(entry.get("rotation_x", 0.0)))
			and is_equal_approx(body.rotation.y, float(entry.get("rotation_y", 0.0))),
			"Architecture collision differs from authored geometry: " + String(entry["name"]))
		_expect(not body.is_in_group("camera_passthrough"), "Visible architecture must continue to block the camera")
	print("AWAKENING_TEMPLE_MODEL meshes=%d materials=%d bounds=%s" % [meshes.size(), material_ids.size(), bounds])


func _check_anchors(current: Node3D, manifest: Dictionary) -> void:
	for key: String in ["spawn", "checkpoint", "exit"]:
		var marker := current.get_node("Markers/" + key.capitalize()) as Marker3D
		_expect(marker.position.is_equal_approx(Layout.vector(manifest["markers"][key])), "Authored " + key + " anchor changed")
		_check_floor(marker.global_position, key)
	for module: Node3D in current.get_node("Modules").get_children():
		var id := String(module.get_meta("module_id", ""))
		_expect(module.position.is_equal_approx(Layout.vector(manifest["modules"][id])), "Module misplaced: " + id)
		_check_floor(module.global_position, id)
	var terminal: Vector3 = current.get_node("Modules/GateExit/ExitMarker").global_position
	_expect(terminal.is_equal_approx(current.get_node("Markers/Exit").global_position),
		"Campaign marker and actual exit must identify the same terminal gate")
	_expect(spawn_to_terminal(current) >= 125.0, "The playable processional route was not enlarged")
	_expect(_world.enemies.size() == manifest["encounters"].size(),
		"Opening encounters must occupy the authored route instead of the old three-enemy cluster")
	for index in manifest["encounters"].size():
		var authored := Layout.vector(manifest["encounters"][index])
		_check_floor(authored, "encounter_%d" % index)
		var occupied := false
		for enemy: Node3D in _world.enemies:
			var origin: Vector3 = enemy.get("spawn_origin")
			if Vector2(origin.x, origin.z).distance_to(Vector2(authored.x, authored.z)) < 0.2:
				occupied = true
		_expect(occupied, "No actual enemy occupies authored encounter_%d" % index)
	for key: String in manifest["landmarks"]:
		_check_floor(Layout.vector(manifest["landmarks"][key]), "landmark_" + key)
	for path: String in ["ShortcutFold/OneWayDoor", "ShortcutFold/OneWayDoor/FarSideMarker",
			"ShortcutFold/ElevatorLift", "ShortcutFold/ElevatorLift/ShrineDock"]:
		_check_floor((current.get_node(path) as Node3D).global_position, path)
	var elevator: Vector3 = current.get_node("ShortcutFold/ElevatorLift").global_position
	var dock: Vector3 = current.get_node("ShortcutFold/ElevatorLift/ShrineDock").global_position
	_expect(elevator.x < -30.0 and elevator.z < -70.0 and dock.z > -30.0 and elevator.distance_to(dock) > 60.0,
		"Opening shortcut must connect the west cloister back to the entry courtyard")


func spawn_to_terminal(current: Node3D) -> float:
	return (current.get_node("Markers/Spawn") as Marker3D).position.distance_to(
		(current.get_node("Markers/Exit") as Marker3D).position)


func _check_floor(at: Vector3, label: String) -> void:
	# Query near the authored ground, not from above roofs, statues or actors.
	var point := Vector3(at.x, 0.04, at.z)
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 0.12, 1)
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y) < 0.025,
		"Opening anchor lacks ground-level collision: " + label + " at " + str(at))


func _check_routes(current: Node3D, navigation: NavigationRegion3D) -> void:
	var map := navigation.get_navigation_map()
	var spawn: Vector3 = current.get_node("Markers/Spawn").global_position
	var terminal: Vector3 = current.get_node("Modules/GateExit/ExitMarker").global_position
	var destinations: Array[Vector3] = [terminal, Vector3(-42, 0, -48), Vector3(-42, 0, -90),
		Vector3(42, 0, -60), Vector3(42, 0, -108)]
	var start := NavigationServer3D.map_get_closest_point(map, spawn)
	_expect(start.distance_to(spawn) < 1.7, "Opening spawn is not on published navigation")
	for point: Vector3 in destinations:
		_check_floor(point, "route_destination")
		var destination := NavigationServer3D.map_get_closest_point(map, point)
		_expect(destination.distance_to(point) < 1.0, "Authored route anchor is too far from navigation: " + str(point))
		var path := NavigationServer3D.map_get_path(map, start, destination, true)
		if _expect(not path.is_empty() and path[path.size() - 1].distance_to(destination) < 0.2,
				"No complete playable route to temple landmark: " + str(point)):
			_routes_checked += 1
			# Ray-check the whole route at 1m spacing, catching unsupported diagonal
			# navigation shortcuts across the void between courtyards and side loops.
			for index in range(1, path.size()):
				var length := path[index - 1].distance_to(path[index])
				var steps := maxi(ceili(length), 1)
				for step in steps + 1:
					_check_floor(path[index - 1].lerp(path[index], float(step) / float(steps)), "navigation_path")


func _check_pavilion_ramps(current: Node3D, navigation: NavigationRegion3D) -> void:
	var manifest: Dictionary = current.get_meta("awakening_temple_layout")
	var collision_root := current.get_node("Geometry/ArchitectureCollision")
	var bases: Array[StaticBody3D] = []
	var inclines: Array[StaticBody3D] = []
	for index in manifest["collision_boxes"].size():
		var entry: Dictionary = manifest["collision_boxes"][index]
		var body := collision_root.get_child(index) as StaticBody3D
		if String(entry["name"]) == "Pavilion_base":
			bases.append(body)
		if absf(body.rotation.x) > 0.01:
			inclines.append(body)
	_expect(bases.size() == 2 and inclines.size() == 2, "Both raised pavilions require a physical entrance incline")
	var saved_transform: Transform3D = _world.player.global_transform
	var saved_velocity: Vector3 = _world.player.velocity
	var map := navigation.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, saved_transform.origin)
	for base: StaticBody3D in bases:
		var shape := (base.get_child(0) as CollisionShape3D).shape as BoxShape3D
		var top_y := base.global_position.y + shape.size.y * 0.5
		var front_z := base.global_position.z + shape.size.z * 0.5
		var incline: StaticBody3D = null
		for candidate: StaticBody3D in inclines:
			if absf(candidate.global_position.x - base.global_position.x) < 0.1:
				incline = candidate
		if not _expect(incline != null, "Missing incline at pavilion " + str(base.global_position.x)):
			continue
		_expect(incline.rotation.x > 0.0 and incline.rotation.x < PI * 0.25,
			"Pavilion incline must rise toward -Z within the player's walkable slope")
		# Sample the full entrance width. The upper end must meet the foundation
		# at its FRONT edge, not end inside it behind a hidden vertical lip.
		for x_offset: float in [-2.0, 0.0, 2.0]:
			for run: float in [0.03, 0.6, 1.2, 1.8, 2.35, 2.48]:
				var at := Vector3(base.global_position.x + x_offset, top_y + 0.4, front_z + run)
				var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * (top_y + 0.8), 1)
				var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
				var expected_y := maxf(top_y * (1.0 - run / 2.4), 0.0)
				_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - expected_y) < 0.045,
					"Pavilion incline has a gap, reversed pitch or vertical lip at " + str(at))
		var destination := NavigationServer3D.map_get_closest_point(map,
			# The back altar now occupies the central destination's bake margin.
			# Verify the clear entrance floor actually traversed by the player.
			Vector3(base.global_position.x, top_y, front_z - 2.0))
		var path := NavigationServer3D.map_get_path(map, start, destination, true)
		print("AWAKENING_PAVILION_NAV destination=%s last=%s" %
			[destination, path[path.size() - 1] if not path.is_empty() else Vector3.INF])
		if _expect(destination.y >= top_y - 0.1 and destination.y <= top_y + 0.6 and not path.is_empty()
				and path[path.size() - 1].distance_to(destination) < 0.2,
				"The raised pavilion interior must be reachable in production navigation"):
			_routes_checked += 1
		# Move the REAL player capsule using the normal physics solver, without
		# jump, teleport recovery or a special stair solver that could hide a lip.
		_world.player.global_position = Vector3(base.global_position.x, 0.05, front_z + 3.4)
		_world.player.velocity = Vector3.ZERO
		await physics_frame
		for frame in 180:
			await physics_frame
			_world.player.velocity = Vector3(0.0, -1.0, -4.0)
			_world.player.move_and_slide()
			if _world.player.global_position.z < front_z - 2.0:
				break
		var reached: Vector3 = _world.player.global_position
		_expect(reached.z < front_z - 2.0 and absf(reached.y - top_y) < 0.12 and _world.player.is_on_floor(),
			"Actual player cannot walk into pavilion without jumping: " + str(reached))
		print("AWAKENING_PAVILION_WALK x=%.1f reached=%s floor=%s" %
			[base.global_position.x, reached, _world.player.is_on_floor()])
	_world.player.global_transform = saved_transform
	_world.player.velocity = saved_velocity


func _await_navigation(navigation: NavigationRegion3D, at: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		var map := navigation.get_navigation_map()
		if bool(navigation.get_meta("bake_complete", false)) and navigation.navigation_mesh.get_polygon_count() > 0 \
				and NavigationServer3D.map_get_closest_point_owner(map, at) == navigation.get_rid():
			return true
		await create_timer(0.025, true, true).timeout
	return false


func _freeze_actors() -> void:
	_world.player.set_process(false)
	_world.player.set_physics_process(false)
	for enemy: Node in _world.enemies:
		if is_instance_valid(enemy):
			enemy.set_process(false)
			enemy.set_physics_process(false)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failures.append(label)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_AWAKENING_TEMPLE_CONTRACT_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
