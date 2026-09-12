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
var _seams_checked := 0
var _tiles_checked := 0
var _collisions_checked := 0


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
	_check_connection_seams(current, manifest)
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
	print("AWAKENING_TEMPLE_EVIDENCE original_cells=%d physical_cells=%d routes=%d retained_collision_boxes=%d open_seams=%d" %
		[manifest["walkable_cells"].size(), _tiles_checked, _routes_checked, _collisions_checked, _seams_checked])
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
	var physical_cells: Dictionary = {}
	for child in current.get_node("Geometry").get_children():
		if String(child.name).begins_with("Tile_"):
			tiles += 1
			_expect(child is StaticBody3D and child.collision_layer == 1, "A walkable tile lost its physical floor")
			var cell := Vector3i(roundi(child.position.x / 6.0), roundi((child.position.y + .3) / 2.0), roundi(-child.position.z / 6.0))
			_expect(not physical_cells.has(cell), "Duplicate physical terrain cell " + str(cell))
			physical_cells[cell] = true
			var tile_shape := child.get_child(0) as CollisionShape3D
			_expect(tile_shape != null and tile_shape.shape is BoxShape3D
				and (tile_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(6, .6, 6)),
				"Physical floor must retain the production six-metre cell dimensions")
			_expect(child.find_children("*", "MeshInstance3D", true, false).is_empty(),
				"Visible procedural tiles must not cover the authored paving")
		_expect(not String(child.name).contains("KitPillar"), "Random kit cylinders must not appear in the authored temple")
	for original: Array in manifest["walkable_cells"]:
		var cell := Vector3i(int(original[0]), int(original[1]), int(original[2]))
		_expect(physical_cells.has(cell), "Original temple floor must survive district expansion: " + str(cell))
	_expect(tiles > manifest["walkable_cells"].size() + 100,
		"The playable district must add substantial physical terrain beyond the original temple")
	_tiles_checked = tiles
	var cells: Array = current.get_node("NavigationSurface").get_meta("walkable_cells")
	_expect(cells.size() == tiles and int(current.get_meta("walkable_cell_count")) == tiles,
		"Navigation and supported-placement metadata must use the expanded terrain")
	var min_cell := Vector3i.ZERO
	var max_cell := Vector3i.ZERO
	for cell: Vector3i in cells:
		_expect(physical_cells.has(cell), "Navigation metadata must refer to actual terrain bodies: " + str(cell))
		min_cell = min_cell.min(cell)
		max_cell = max_cell.max(cell)
	_expect((max_cell.x - min_cell.x + 1) * 6 >= 96 and (max_cell.z - min_cell.z + 1) * 6 >= 140,
		"The physical playable footprint, not just distant scenery, must span the enlarged temple")
	_expect(max_cell.y >= 3, "The new temple district must contain a real upper floor at least six metres high")
	var district: Dictionary = current.get_meta("expansion", {})
	_expect(not district.is_empty() and district.has("new_cells"), "Opening temple requires the integrated district plan")
	for cell: Vector3i in district.get("new_cells", []):
		_expect(physical_cells.has(cell), "Planned district floor is not physically instantiated: " + str(cell))
	_check_threejs_architecture(current, tiles - manifest["walkable_cells"].size())
	var collision_root := current.get_node("Geometry/ArchitectureCollision")
	var openings: Array = current.get_meta("temple_connection_openings", [])
	var retained := 0
	var matched: Dictionary = {}
	for entry: Dictionary in manifest["collision_boxes"]:
		var removed_for_connection := String(entry["name"]) == "Retaining_wall" and _inside_openings(Layout.vector(entry["position"]), openings)
		var body := _find_authored_collision(collision_root, entry)
		if removed_for_connection:
			_expect(body == null, "Connection retaining wall still blocks its original position: " + _collision_label(entry))
			continue
		retained += 1
		if not _expect(body != null, "Original architecture collision was removed outside a connection: " + _collision_label(entry)):
			continue
		_expect(not matched.has(body.get_instance_id()), "Two original solids resolved to the same body: " + _collision_label(entry))
		matched[body.get_instance_id()] = true
		var shape := body.get_child(0) as CollisionShape3D
		_expect(shape != null and shape.shape is BoxShape3D and body.collision_layer == 1
			and (shape.shape as BoxShape3D).size.is_equal_approx(Layout.vector(entry["size"]))
			and is_equal_approx(body.rotation.x, float(entry.get("rotation_x", 0.0)))
			and is_equal_approx(body.rotation.y, float(entry.get("rotation_y", 0.0))),
			"Architecture collision differs from authored geometry: " + _collision_label(entry))
		_expect(not body.is_in_group("camera_passthrough"), "Visible architecture must continue to block the camera")
	_expect(collision_root.get_child_count() == retained and matched.size() == retained,
		"Collision inventory must retain every original solid except explicitly opened perimeter railings")
	_collisions_checked = retained
	print("AWAKENING_TEMPLE_MODEL meshes=%d materials=%d bounds=%s" % [meshes.size(), material_ids.size(), bounds])


func _check_threejs_architecture(current: Node3D, additional_cells: int) -> void:
	var modeled := current.get_node_or_null("Geometry/ModeledEnvironment") as Node3D
	if not _expect(modeled != null, "The original temple must be joined by the actual Three.js district"):
		return
	const EXPECTED_KIT := "res://assets/environment/threejs_campaign/spirit_ruins.glb"
	_expect(String(modeled.get_meta("kit_path", "")) == EXPECTED_KIT and ResourceLoader.exists(EXPECTED_KIT),
		"District provenance must identify its imported Three.js spirit-ruins GLB")
	var batches := modeled.find_children("*", "MultiMeshInstance3D", true, false)
	_expect(not batches.is_empty(), "Three.js district must submit imported mesh batches")
	var floor_seen := false
	var bridge_seen := false
	var architecture_seen := false
	for instance: MultiMeshInstance3D in batches:
		_expect(instance.multimesh != null and instance.multimesh.mesh is ArrayMesh
			and instance.multimesh.instance_count > 0, "District batch requires real imported ArrayMesh geometry")
		_expect(String(instance.get_meta("kit_path", "")) == EXPECTED_KIT,
			"District mesh batch lost its actual Three.js asset provenance")
		var part := String(instance.get_meta("kit_part", ""))
		if part == "Floor":
			floor_seen = true
			_expect(instance.multimesh.instance_count == additional_cells,
				"Three.js floors must cover every added cell without replacing or duplicating the original temple paving")
		bridge_seen = bridge_seen or part == "Bridge"
		architecture_seen = architecture_seen or part in ["Arcade", "Watchtower", "Roof"]
	_expect(floor_seen and bridge_seen and architecture_seen,
		"District must contain imported floors, elevation bridges and built architecture")


func _find_authored_collision(collision_root: Node, entry: Dictionary) -> StaticBody3D:
	# Runtime-created duplicate node names may be generated @StaticBody3D@ names.
	# Use the manifest's semantic name and exact spatial identity, never child order.
	var expected_position := Layout.vector(entry["position"])
	var expected_name := String(entry["name"])
	for child: Node in collision_root.get_children():
		if not child is StaticBody3D:
			continue
		var body := child as StaticBody3D
		var body_name := String(body.name)
		if not (body_name.begins_with(expected_name) or body_name.begins_with("@StaticBody3D@")):
			continue
		if body.position.is_equal_approx(expected_position) \
				and is_equal_approx(body.rotation.x, float(entry.get("rotation_x", 0.0))) \
				and is_equal_approx(body.rotation.y, float(entry.get("rotation_y", 0.0))):
			return body
	return null


func _collision_label(entry: Dictionary) -> String:
	return String(entry["name"]) + " at " + str(Layout.vector(entry["position"]))


func _inside_openings(point: Vector3, openings: Array) -> bool:
	for opening: AABB in openings:
		if opening.has_point(point):
			return true
	return false


func _check_connection_seams(current: Node3D, manifest: Dictionary) -> void:
	var original: Dictionary = {}
	for entry: Array in manifest["walkable_cells"]:
		original[Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))] = true
	var all_cells: Dictionary = {}
	for cell: Vector3i in current.get_node("NavigationSurface").get_meta("walkable_cells", []):
		all_cells[cell] = true
	var openings: Array = current.get_meta("temple_connection_openings", [])
	# Derive the required seams from original/new physical adjacency independently
	# of the adapter's reported openings. A metadata opening alone cannot pass.
	for cell: Vector3i in original:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var outside := cell + direction
			if original.has(outside) or not all_cells.has(outside):
				continue
			var inside_floor := Vector3(cell.x * 6.0, cell.y * 2.0, -cell.z * 6.0)
			var outside_floor := Vector3(outside.x * 6.0, outside.y * 2.0, -outside.z * 6.0)
			var midpoint := inside_floor.lerp(outside_floor, .5) + Vector3.UP * .7
			_expect(_inside_openings(midpoint, openings), "New physical district connection lacks an authored masonry opening: " + str(midpoint))
			var across := Vector3(0, 0, 1) if direction.x != 0 else Vector3(1, 0, 0)
			for offset: float in [-1.5, 0.0, 1.5]:
				for height: float in [.25, .7, .95]:
					var from := current.to_global(inside_floor + across * offset + Vector3.UP * height)
					var to := current.to_global(outside_floor + across * offset + Vector3.UP * height)
					var query := PhysicsRayQueryParameters3D.create(from, to, 1)
					query.hit_from_inside = true
					var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
					_expect(hit.is_empty(), "Old railing or new architecture still obstructs the actual temple connection: " + str(midpoint)
						+ " height=" + str(height) + " offset=" + str(offset))
			_seams_checked += 1
	_expect(_seams_checked >= 2 and openings.size() == _seams_checked,
		"Temple district requires both its earned entrance and shrine return to be physically stitched")


func _check_vertical_lift(current: Node3D, lift: Dictionary) -> void:
	if not _expect(not lift.is_empty(), "Opening district requires its physical two-level lift"):
		return
	var elevator := current.get_node("ShortcutFold/ElevatorLift") as Node3D
	var platform := elevator.get_node("LiftPlatform") as AnimatableBody3D
	var upper: Vector3 = elevator.global_position
	var lower: Vector3 = (elevator.get_node("ShrineDock") as Marker3D).global_position
	_expect(bool(elevator.get_meta("physical_lift", false)) and upper.is_equal_approx(current.to_global(lift["upper_dock"]))
		and lower.is_equal_approx(current.to_global(lift["lower_dock"])), "Physical lift must use its actual district shaft docks")
	_expect(absf(upper.x - lower.x) < .01 and absf(upper.z - lower.z) < .01 and upper.y - lower.y >= 6.0,
		"Opening lift must connect vertically aligned docks on distinct floors")
	var deck: BoxShape3D = null
	for child in platform.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			deck = child.shape
	_expect(deck != null and deck.size.is_equal_approx(Vector3(5.9, .35, 5.9)),
		"Lift requires a real 5.9m deck meeting the fixed six-metre landings")
	for key: String in ["upper_landing", "lower_landing", "upper_exit", "lower_exit"]:
		var floor_position: Vector3 = current.to_global(lift[key])
		_check_floor(floor_position, "physical_lift_" + key, floor_position.y)
	for pair: Array in [["upper_landing", upper], ["lower_landing", lower]]:
		var landing: Vector3 = current.to_global(lift[pair[0]])
		var dock: Vector3 = pair[1]
		_expect(absf(landing.y - dock.y) < .01 and is_equal_approx(landing.distance_to(dock), 6.0),
			"Fixed lift landing must adjoin its dock across the five-centimetre deck seam")
	# Initially the platform is at the upper dock. The lower shaft is intentionally
	# empty: a ground-at-shaft assertion would incorrectly demand an obstructing tile.
	var top_query := PhysicsRayQueryParameters3D.create(upper + Vector3.UP * .5, upper + Vector3.DOWN * .5, 1)
	var top_hit := _world.get_world_3d().direct_space_state.intersect_ray(top_query)
	_expect(not top_hit.is_empty() and top_hit["collider"] == platform
		and absf((top_hit["position"] as Vector3).y - upper.y) < .025, "Actual lift deck must initially meet the upper landing height")
	var shaft_query := PhysicsRayQueryParameters3D.create(lower + Vector3.UP * .2, upper - Vector3.UP * .2, 1)
	shaft_query.exclude = [platform.get_rid()]
	_expect(_world.get_world_3d().direct_space_state.intersect_ray(shaft_query).is_empty(),
		"The full physical lift shaft must remain clear of fixed floors and architecture")
	var lower_query := PhysicsRayQueryParameters3D.create(lower + Vector3.UP * .04, lower + Vector3.DOWN * .12, 1)
	_expect(_world.get_world_3d().direct_space_state.intersect_ray(lower_query).is_empty(),
		"The absent lower platform must not be replaced by a fixed tile in the lift shaft")


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
	var district: Dictionary = current.get_meta("expansion", {})
	var additions: Array = district.get("encounters", [])
	var interior: Dictionary = district.get("interior", {})
	var pressure: Array = interior.get("interior_pressure", [])
	_expect(manifest["encounters"].size() == 6 and additions.size() == 2,
		"Opening keeps six story encounters and adds the district patrol and record guard")
	_expect(pressure.size() == 3, "Opening interior adds exactly its ground ambush, middle patrol and top shield guard")
	_expect(_world.enemies.size() == 6 + additions.size() + pressure.size(),
		"Actual opening roster must contain exactly six original, two district and three interior-pressure enemies")
	var original_ids := {"level_01_01/lost_soul_soldier/0": "lost_soul_soldier", "level_01_01/lost_soul_soldier/1": "lost_soul_soldier",
		"level_01_01/lost_soul_soldier/2": "lost_soul_soldier", "level_01_01/ember_shade_skirmisher/0": "ember_shade_skirmisher",
		"level_01_01/ember_shade_skirmisher/1": "ember_shade_skirmisher", "level_01_01/temple_guardian_warrior/0": "temple_guardian_warrior"}
	var original_seen: Dictionary = {}
	var extra_seen: Dictionary = {}
	var guard_ids := {"level_01_01/district/threshold_patrol": "lost_soul_soldier",
		"level_01_01/district/record_guard": "temple_guardian_warrior"}
	var pressure_ids := {"level_01_01/interior/ground_ambush": "lost_soul_soldier",
		"level_01_01/interior/middle_patrol": "lost_soul_soldier", "level_01_01/interior/top_shield": "temple_guardian_warrior"}
	for enemy: Node3D in _world.enemies:
		var assignment: Dictionary = enemy.encounter_assignment
		if enemy.has_meta("expansion_placement_id"):
			var placement_id := String(enemy.get_meta("expansion_placement_id"))
			_expect((guard_ids.has(placement_id) or pressure_ids.has(placement_id)) and not extra_seen.has(placement_id),
				"Opening extra actors must use distinct IDs from the two exact authored addition rosters: " + placement_id)
			extra_seen[placement_id] = true
		else:
			var encounter_id := String(assignment.get("encounter_id", ""))
			_expect(original_ids.has(encounter_id) and original_ids.get(encounter_id) == String(enemy.content_id) and not original_seen.has(encounter_id),
				"Original opening actor retains its distinct authored ID and content: " + encounter_id)
			original_seen[encounter_id] = true
	_expect(original_seen.size() == 6 and extra_seen.size() == 5, "Opening keeps all six original identities and exactly five separately planned additions")
	for index in manifest["encounters"].size():
		var authored := Layout.vector(manifest["encounters"][index])
		_check_floor(authored, "encounter_%d" % index)
		var occupied := false
		for enemy: Node3D in _world.enemies:
			if enemy.has_meta("expansion_placement_id"):
				continue
			var origin: Vector3 = enemy.get("spawn_origin")
			if Vector2(origin.x, origin.z).distance_to(Vector2(authored.x, authored.z)) < 0.2:
				occupied = true
		_expect(occupied, "No actual enemy occupies authored encounter_%d" % index)
	var district_seen: Dictionary = {}
	for plan: Dictionary in additions:
		var placement_id := String(plan["placement_id"])
		_expect(guard_ids.has(placement_id) and guard_ids.get(placement_id) == plan["content_id"] and not district_seen.has(placement_id),
			"Opening district must use its authored soldier patrol and temple record guard")
		district_seen[placement_id] = true
		var matching := 0
		for enemy: Node3D in _world.enemies:
			if String(enemy.get_meta("expansion_placement_id", "")) != placement_id:
				continue
			matching += 1
			var origin: Vector3 = enemy.get("spawn_origin")
			var expected: Vector3 = current.to_global(plan["position"])
			_expect(String(enemy.get("content_id")) == String(plan["content_id"])
				and String(enemy.encounter_assignment.get("encounter_id", "")) == placement_id and enemy.get_meta("expansion_level", null) == current
				and Vector2(origin.x, origin.z).distance_to(Vector2(expected.x, expected.z)) < .05
				and origin.y >= expected.y and origin.y - expected.y < .3,
				"District enemy has wrong content or spatial home: " + placement_id)
			_check_floor(expected, placement_id, expected.y)
		_expect(matching == 1, "Exactly one actual enemy required for " + placement_id)
	_expect(district_seen.size() == guard_ids.size(), "The opening district roster is complete independently of its interior")
	var pressure_seen: Dictionary = {}
	for plan: Dictionary in pressure:
		var placement_id := String(plan["placement_id"])
		_expect(pressure_ids.has(placement_id) and pressure_ids.get(placement_id) == plan["content_id"] and not pressure_seen.has(placement_id),
			"Opening interior must use exactly its independent ambush, patrol and shield identities")
		pressure_seen[placement_id] = true
		var matching := 0
		for enemy: Node3D in _world.enemies:
			if String(enemy.get_meta("expansion_placement_id", "")) != placement_id:
				continue
			matching += 1
			var origin: Vector3 = enemy.spawn_origin
			var expected: Vector3 = current.to_global(plan["position"])
			var assignment: Dictionary = enemy.encounter_assignment
			_expect(String(enemy.content_id) == String(plan["content_id"]) and String(assignment.get("encounter_id", "")) == placement_id
				and String(assignment.get("role", "")) == String(plan["role"]) and enemy.get_meta("expansion_level", null) == current
				and Vector2(origin.x, origin.z).distance_to(Vector2(expected.x, expected.z)) < .05
				and origin.y >= expected.y and origin.y - expected.y < .3,
				"Interior pressure actor has its own content, assignment, level and spatial reset home: " + placement_id)
			_check_floor(expected, placement_id, expected.y)
		_expect(matching == 1, "Exactly one actual interior actor required for " + placement_id)
	_expect(pressure_seen.size() == pressure_ids.size(), "The opening interior-pressure roster is complete independently of its district")
	for key: String in manifest["landmarks"]:
		_check_floor(Layout.vector(manifest["landmarks"][key]), "landmark_" + key)
	for path: String in ["ShortcutFold/OneWayDoor", "ShortcutFold/OneWayDoor/FarSideMarker"]:
		_check_floor((current.get_node(path) as Node3D).global_position, path)
	_check_vertical_lift(current, district.get("lift", {}))


func spawn_to_terminal(current: Node3D) -> float:
	return (current.get_node("Markers/Spawn") as Marker3D).position.distance_to(
		(current.get_node("Markers/Exit") as Marker3D).position)


func _check_floor(at: Vector3, label: String, expected_y := 0.0) -> void:
	# Query near the authored ground, not from above roofs, statues or actors.
	var point := Vector3(at.x, expected_y + 0.04, at.z)
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 0.12, 1)
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - expected_y) < 0.025,
		"Opening anchor lacks collision at the authored floor height: " + label + " at " + str(at))


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
	for entry: Dictionary in manifest["collision_boxes"]:
		var body := _find_authored_collision(collision_root, entry)
		if body == null:
			continue
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
				and NavigationServer3D.map_get_iteration_id(map) > 0 \
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
