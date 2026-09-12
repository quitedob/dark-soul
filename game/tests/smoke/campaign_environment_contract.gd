extends SceneTree
## Real game-world level loads with in-memory save handling; no production saves.
## Verifies all 29 chapter palettes, navigation geometry, phase reset, and debug cleanup.
const ThemeFactory = preload("res://scripts/world/level_theme_factory.gd")
const EnvironmentSetup = preload("res://scripts/core/world_environment.gd")
const PhaseEnvironment = preload("res://scripts/fx/phase_environment.gd")
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const LevelBuilder = preload("res://scripts/world/procedural_campaign_level_builder.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	var recorded_saves: Array[String] = []

	func _load_initial_state() -> void:
		# Exercise the real startup with fresh default state and settings in memory.
		_apply_settings()

	func _save_run(reason: String) -> bool:
		_snapshot_run_state()
		recorded_saves.append(reason)
		return true


var _failures: Array[String] = []
var _world: AuditWorld
var _checked_levels := 0
var _polygon_total := 0
var _checked_ramps := 0
var _checked_paths := 0
var _unsupported_enemy_spawns := 0
var _grounded_story_props := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_spawn_projection()
	_world = AuditWorld.new()
	# Preserve actual authored scene children while overriding only disk save I/O.
	var scene_contents := WorldScene.instantiate()
	for child in scene_contents.get_children():
		child.owner = null
		scene_contents.remove_child(child)
		_world.add_child(child)
	scene_contents.free()
	root.add_child(_world)
	_world.set_process(false)
	_freeze_actors()
	await process_frame
	var levels: Array[Dictionary] = _world.campaign_runtime.registry.get_levels()
	_expect(levels.size() == 29, "Expected 29 actual campaign levels")
	var skies: Dictionary = {}
	var grounds: Dictionary = {}
	for level: Dictionary in levels:
		var id := StringName(level["id"])
		var old_level_nodes := _chapter_runtime_nodes()
		# A previous boss look must not become the next level's default snapshot.
		_world._phase_environment.apply_lighting_key("deep_crimson_darkness", 0.0)
		if not _expect(_world._load_campaign_level(id), "Failed actual level load: " + String(id)):
			continue
		_freeze_actors()
		var current: Node3D = _world.campaign_runtime.current_level
		var navigation := current.get_node_or_null("NavigationSurface") as NavigationRegion3D
		if not _expect(navigation != null, String(id) + ": missing current navigation region"):
			continue
		for frame in 90:
			if bool(navigation.get_meta("bake_complete", false)):
				break
			await physics_frame
			await process_frame
		if not bool(navigation.get_meta("bake_complete", false)):
			print("CAMPAIGN_NAV_PENDING %s requested=%s queued=%s dirty=%s baking=%s paused=%s physics=%d" % [id, navigation.get_meta("bake_requested", false), navigation.get_meta("refresh_queued", false), navigation.get_meta("geometry_dirty", false), navigation.is_baking(), paused, Engine.get_physics_frames()])
		for previous: Node in old_level_nodes:
			_expect(not is_instance_valid(previous), String(id) + ": previous chapter prop or arena controller survived unload")
		_check_chapter_runtime(current, id)
		_expect(bool(navigation.get_meta("bake_complete", false)), String(id) + ": navigation bake did not finish")
		var polygon_count := navigation.navigation_mesh.get_polygon_count()
		_expect(polygon_count > 0, String(id) + ": actual navigation mesh is empty")
		_expect(int(navigation.get_meta("baked_polygon_count", -1)) == polygon_count, String(id) + ": stale bake evidence")
		_expect(_world.find_children("*", "NavigationRegion3D", true, false).size() == 1, String(id) + ": stale navigation regions survived")
		_expect(navigation.get_child_count() == 0 and _world.get_node_or_null("NavRegion") == null,
			String(id) + ": navigation helper geometry must not cover the real floor")
		if String(level["topology"]) in ["vertical_tower", "vertical_library", "vertical_floating_path"]:
			var highest := -INF
			for vertex in navigation.navigation_mesh.get_vertices():
				highest = maxf(highest, vertex.y)
			_expect(highest > 3.0, String(id) + ": navigation did not include elevated terrain")
		_check_environment(level)
		var environment := _world.world_environment.environment
		skies[environment.background_color.to_html()] = true
		if id == &"level_01_01":
			# The opening temple now uses authored stone materials; its invisible
			# collision tiles must not restore the old procedural floor over the GLB.
			var temple := current.get_node_or_null("Geometry/AuthoredTemple")
			if _expect(temple != null, "Opening level is missing its authored temple"):
				_expect(not temple.find_children("*", "MeshInstance3D", true, false).is_empty(),
					"Opening temple has no imported material-bearing geometry")
		else:
			_check_modeled_environment(current, level)
			grounds[String(level["theme_id"])] = true
		for obstacle in get_nodes_in_group("camera_passthrough"):
			_expect(obstacle is StaticBody3D and obstacle.collision_layer == 1
				and obstacle.find_children("*", "MeshInstance3D", true, false).is_empty(),
				String(id) + ": camera exclusion includes visible geometry")
		# NavigationServer publishes mesh changes at physics synchronization points.
		await physics_frame
		await physics_frame
		_check_story_prop_grounding(String(id))
		_check_architecture_support(current, String(id))
		await _check_route(current, navigation, String(id))
		_check_ramps(current, String(id))
		await _walk_modeled_ramp(current, String(id))
		_check_hub_jars(id)
		_record_enemy_support(String(id))
		_check_npc_support(String(id))
		_check_shortcut_support(String(id))
		if id == &"level_01_04":
			await physics_frame
			for index in mini(2, _world.enemies.size()):
				var enemy: Node3D = _world.enemies[index]
				var query := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 3.0,
					enemy.global_position + Vector3.DOWN * 6.0, 1)
				_expect(not _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
					"Hazard-wing enemy spawn must stand above real collision geometry")
		_checked_levels += 1
		_polygon_total += polygon_count
		print("CAMPAIGN_ENVIRONMENT_LEVEL %s theme=%s polygons=%d" % [id, level["theme_id"], polygon_count])
	_expect(skies.size() == 6 and grounds.size() == 5,
		"All five chapter palettes and the authored opening vista must remain distinct")
	await _check_transition_warnings()
	# A pending phase tween must be cancelled, not overwrite the next chapter later.
	_world._phase_environment.apply_lighting_key("deep_crimson_darkness", 0.5)
	_world._load_campaign_level(&"level_02_01")
	_freeze_actors()
	await create_timer(0.65).timeout
	_check_environment(_world.campaign_runtime.get_level_data())
	_world.teleport_player_to_blank(_world.player)
	_expect(_world.find_children("*", "DirectionalLight3D", true, false).size() == 1,
		"Debug area must not add global directional illumination")
	_world._load_campaign_level(&"level_01_01")
	_freeze_actors()
	_expect(_world.get_node_or_null("BlankTestArea") == null, "Level change must remove the debug area")
	_world._phase_environment.apply_lighting_key("deep_crimson_darkness", 0.0)
	await _world._on_player_died(_world.player.global_position)
	_check_environment(_world.campaign_runtime.get_level_data())
	_expect(_world.recorded_saves.has("player_death"), "Death reset must exercise in-memory save handling")
	_expect(_checked_levels == 29, "All 29 actual level loads must be checked")
	_expect(_grounded_story_props == 7, "All seven separate story visuals must receive floor checks; named memorials use the imported-art contract")
	_world.free()
	print("CAMPAIGN_STORY_PROP_GROUNDING_COUNT checked=%d" % _grounded_story_props)
	print("CAMPAIGN_ENVIRONMENT_COUNTS levels=%d themes=%d polygons=%d paths=%d ramps=%d unsupported_enemy_spawns=%d" %
		[_checked_levels, skies.size(), _polygon_total, _checked_paths, _checked_ramps, _unsupported_enemy_spawns])
	if _failures.is_empty():
		print("ASHEN_CAMPAIGN_ENVIRONMENT_CONTRACTS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_modeled_environment(current: Node3D, level: Dictionary) -> void:
	var label := String(level["id"])
	var modeled := current.get_node_or_null("Geometry/ModeledEnvironment") as Node3D
	if not _expect(modeled != null and current.has_meta("modeled_layout"), label + ": imported campaign architecture missing"):
		return
	var layout: Dictionary = current.get_meta("modeled_layout")
	var cells: Array = layout["cells"]
	var legacy := LevelBuilder._topology_cells(level["topology"], int(level["seed"]))
	_expect(cells.size() >= legacy.size() * 3, label + ": usable floor area did not grow by at least 3x")
	var counts: Dictionary = modeled.get_meta("part_counts")
	_expect(int(counts.get("Floor", 0)) == cells.size() and int(counts.get("Rail", 0)) > 0
		and int(counts.get("Gate", 0)) > 0,
		label + ": layout is missing modeled floors, boundaries or gates")
	var story := current.get_node_or_null("CampaignStoryProps")
	_expect(story != null and int(story.get_meta("batch_count", 0)) > 0,
		label + ": authored story architecture is missing")
	var floor_materials: Dictionary = {}
	for batch: MultiMeshInstance3D in modeled.find_children("*", "MultiMeshInstance3D", true, false):
		_expect(batch.multimesh != null and batch.multimesh.instance_count > 0 and batch.multimesh.mesh is ArrayMesh,
			label + ": modeled geometry must use imported mesh batches")
		if String(batch.get_meta("kit_part")) == "Floor":
			for surface in batch.multimesh.mesh.get_surface_count():
				var material := batch.multimesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material != null:
					floor_materials[material.albedo_color.to_html()] = true
	_expect(floor_materials.size() >= 2, label + ": authored paving lost its material distinction")
	for tile: Node in current.get_node("Geometry").get_children():
		if String(tile.name).begins_with("Tile_"):
			_expect(tile.find_children("*", "MeshInstance3D", true, false).is_empty(), label + ": placeholder floor covers imported paving")
	var route_length := 0.0
	var route: Array = layout["route"]
	for index in range(1, route.size()):
		var before: Vector3i = route[index - 1]
		var after: Vector3i = route[index]
		route_length += Vector3((after.x - before.x) * 6, (after.y - before.y) * 2, (after.z - before.z) * 6).length()
	if not layout.has("boss_arena_center"):
		_expect(route_length >= 60.0, label + ": primary route remains shorter than 60m")
	else:
		_expect(current.get_meta("boss_arena_radius") == layout["boss_arena_radius"]
			and current.get_meta("boss_spawn") == layout["boss_arena_center"], label + ": boss arena metadata disagrees with geometry")
	var exit: Vector3 = current.get_node("Markers/Exit").global_position
	var gate_marker := current.get_node_or_null("Modules/GateExit/ExitMarker") as Marker3D
	if gate_marker != null:
		var interact := current.get_node("Modules/GateExit/GateExitInteract") as Area3D
		_expect(gate_marker.global_position.is_equal_approx(exit) and interact.global_position.is_equal_approx(exit),
			label + ": real gate interaction is not at the route terminal")
	print("CAMPAIGN_MODELED_LAYOUT %s cells=%d old=%d route_m=%.1f batches=%d" %
		[label, cells.size(), legacy.size(), route_length, int(modeled.get_meta("batch_count"))])


func _walk_modeled_ramp(current: Node3D, label: String) -> void:
	if not current.has_meta("modeled_layout"):
		return
	var layout: Dictionary = current.get_meta("modeled_layout")
	var chosen: StaticBody3D = null
	for body: Node in current.get_node("Geometry").get_children():
		if body.has_meta("modeled_ramp") and layout["route"].has(body.get_meta("lower_cell")) \
				and layout["route"].has(body.get_meta("upper_cell")):
			chosen = body
			break
	if chosen == null:
		return
	var lower: Vector3 = current.to_global(chosen.get_meta("lower_edge"))
	var upper: Vector3 = current.to_global(chosen.get_meta("upper_edge"))
	var direction := (upper - lower) * Vector3(1, 0, 1)
	direction = direction.normalized()
	var saved: Transform3D = _world.player.global_transform
	_world.player.global_position = lower - direction * 0.8 + Vector3.UP * 0.05
	_world.player.velocity = Vector3.ZERO
	await physics_frame
	for frame in 120:
		await physics_frame
		_world.player.velocity = direction * 6.0 + Vector3.DOWN
		_world.player.move_and_slide()
		if (_world.player.global_position - upper).dot(direction) > 0.7:
			break
	var reached: Vector3 = _world.player.global_position
	_expect((reached - upper).dot(direction) > 0.65 and absf(reached.y - upper.y) < 0.12
		and _world.player.is_on_floor(), label + ": real player cannot walk the incline without jumping: " + str(reached))
	_world.player.global_transform = saved
	_world.player.velocity = Vector3.ZERO
	print("CAMPAIGN_MODELED_RAMP_WALK %s reached=%s" % [label, reached])


func _check_environment(level: Dictionary) -> void:
	var theme := StringName(level["theme_id"])
	var environment := _world.world_environment.environment
	var moon := _world.get_node("Moonlight") as DirectionalLight3D
	var profile: Dictionary = PhaseEnvironment.LIGHTING_TABLE[EnvironmentSetup.THEME_LIGHTING_KEYS[theme]]
	var expected_sky: Color = ThemeFactory.THEMES[theme]["sky"]
	var expected_fog: Color = profile["fog"]
	var expected_density := float(profile["fog_density"])
	var expected_ambient_energy := float(profile["amb_energy"])
	var expected_contrast := float(profile["contrast"])
	if StringName(level["id"]) == &"level_01_01":
		# This authored 150m vista has its own readable distance profile; every
		# other level retains the chapter baseline checked below.
		expected_sky = Color("101c25")
		expected_fog = Color("354d58")
		expected_density = 0.0035
		expected_ambient_energy = 0.62
		expected_contrast = 1.05
	_expect(_world.find_children("*", "WorldEnvironment", true, false).size() == 1, "Expected one live world environment")
	_expect(environment.background_color.is_equal_approx(expected_sky), String(level["id"]) + ": wrong chapter sky")
	_expect(environment.fog_light_color.is_equal_approx(expected_fog)
		and is_equal_approx(environment.fog_density, expected_density), String(level["id"]) + ": stale phase fog")
	_expect(environment.ambient_light_color.is_equal_approx(profile["amb"])
		and moon.light_color.is_equal_approx(profile["moon"]), String(level["id"]) + ": wrong chapter lighting")
	_expect(is_equal_approx(environment.ambient_light_energy, expected_ambient_energy)
		and is_equal_approx(environment.adjustment_contrast, expected_contrast), String(level["id"]) + ": stale lighting strength or contrast")
	_expect(String(_world._phase_environment.active_key).is_empty(), String(level["id"]) + ": stale active phase key")


func _chapter_runtime_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for prop: Node in get_nodes_in_group("campaign_level_props"):
		nodes.append(prop)
	var director: Node = _world._arena_director
	if is_instance_valid(director):
		nodes.append(director)
		for entry: Dictionary in director._chunks:
			if is_instance_valid(entry["node"]):
				nodes.append(entry["node"])
		for jar: Node in director._jars:
			if is_instance_valid(jar):
				nodes.append(jar)
	return nodes


func _check_chapter_runtime(current: Node3D, level_id: StringName) -> void:
	var expected := {
		&"level_03_04": ["TeaOffering", "ShrineNpc_bridge_tea_soul", "BellTowerEntrance"],
		&"level_05_01": ["FurnaceMemory_furnace_memory_1"],
		&"level_05_02": ["FurnaceMemory_furnace_memory_2"],
		&"level_05_03": ["FurnaceMemory_furnace_memory_3", "SamsaraReview"],
		&"level_05_04": ["FurnaceMemory_furnace_memory_4", "SoulForgerCommunion"],
	}
	var names: Array = expected.get(level_id, [])
	var props := get_nodes_in_group("campaign_level_props")
	_expect(props.size() == names.size(), String(level_id) + ": wrong active chapter prop count")
	for prop: Node in props:
		_expect(names.has(String(prop.name)) and current.is_ancestor_of(prop)
			and prop.get_meta("level_id") == level_id, String(level_id) + ": stale chapter prop identity or parent")
	var director: Node = _world._arena_director
	var has_boss := is_instance_valid(_world.guardian)
	_expect(is_instance_valid(director) == has_boss, String(level_id) + ": arena controller leaked into non-boss level")
	if is_instance_valid(director):
		_expect(director.get_parent() == current and director.host == current, String(level_id) + ": arena scenery is not level-owned")
		for node: Node in _chapter_runtime_nodes():
			_expect(current.is_ancestor_of(node), String(level_id) + ": chapter scenery is outside the generated root")


func _check_transition_warnings() -> void:
	_world._load_campaign_level(&"level_04_06")
	_freeze_actors()
	await process_frame
	await process_frame
	_expect(not _world._arena_director.story_props.aftermath_active,
		"Xuan Xiao escape countdown must not start before resolving the boss")
	var previous_flow: Node = _world.guardian.get_node("FlowController")
	_world._load_campaign_level(&"level_05_01")
	_freeze_actors()
	await process_frame
	_expect(not is_instance_valid(previous_flow), "Previous boss countdown controller must be freed")
	_expect(_world.hud.message_label.text.is_empty() and not _world.hud.message_panel.visible,
		"Previous chapter countdown warning must clear on level load")
	# Also leave before the old controller's deferred initializer has run.
	_world._load_campaign_level(&"level_04_06")
	_world._load_campaign_level(&"level_05_01")
	_freeze_actors()
	await process_frame
	await process_frame
	_expect(not _world.hud.message_label.text.contains("ZENITH"), "Deferred old boss initializer resurrected its warning")
	_world.hud.show_message("OLD LEVEL WARNING", 0.05)
	_world._load_campaign_level(&"level_01_03")
	_freeze_actors()
	_world.hud.show_message("CURRENT LEVEL", 0.0)
	await create_timer(0.15).timeout
	_expect(_world.hud.message_label.text == "CURRENT LEVEL" and _world.hud.message_panel.visible,
		"Old warning timer must not hide a new level's message")
	_check_chapter_runtime(_world.campaign_runtime.current_level, &"level_01_03")
	print("CAMPAIGN_TRANSITION_CLEANUP_OK")


func _check_route(current: Node3D, navigation: NavigationRegion3D, label: String) -> void:
	var navigation_map := navigation.get_navigation_map()
	print("CAMPAIGN_NAV_MAP %s active=%s iteration=%d regions=%d region_registered=%s" %
		[label, NavigationServer3D.map_is_active(navigation_map), NavigationServer3D.map_get_iteration_id(navigation_map),
		NavigationServer3D.map_get_regions(navigation_map).size(),
		NavigationServer3D.region_get_map(navigation.get_rid()) == navigation_map])
	var spawn: Vector3 = current.get_node("Markers/Spawn").global_position
	var exit: Vector3 = current.get_node("Markers/Exit").global_position
	var ready := await _await_navigation_owner(navigation_map, navigation.get_rid(), spawn)
	_expect(ready, label + ": production navigation did not publish the current region")
	var start := NavigationServer3D.map_get_closest_point(navigation_map, spawn)
	var destination := NavigationServer3D.map_get_closest_point(navigation_map, exit)
	print("CAMPAIGN_NAV_POINTS %s spawn=%s closest=%s exit=%s closest_exit=%s bounds=%s enabled=%s layers=%d" %
		[label, spawn, start, exit, destination, navigation.get_bounds(),
		NavigationServer3D.region_get_enabled(navigation.get_rid()), NavigationServer3D.region_get_navigation_layers(navigation.get_rid())])
	_expect(start.distance_to(spawn) < 1.7 and destination.distance_to(exit) < 1.7,
		label + ": marker is too far from actual navigation geometry")
	var path := NavigationServer3D.map_get_path(navigation_map, start, destination, true)
	_expect(not path.is_empty(), label + ": production navigation cannot find even a partial path")
	print("CAMPAIGN_NAV_ROUTE %s complete=%s points=%d" %
		[label, not path.is_empty() and path[path.size() - 1].distance_to(destination) < 0.2, path.size()])
	# Closed progression modules may intentionally block the production route.
	# Bake only the actual terrain in a separate map to verify geometric connectivity.
	var terrain_mesh := navigation.navigation_mesh.duplicate() as NavigationMesh
	terrain_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	terrain_mesh.geometry_source_group_name = LevelBuilder.TERRAIN_NAVIGATION_SOURCE_GROUP
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(terrain_mesh, source, current.get_node("Geometry"))
	NavigationServer3D.bake_from_source_geometry_data(terrain_mesh, source)
	var terrain_map := NavigationServer3D.map_create()
	# A manually created server map does not inherit the World3D project's voxel
	# settings. Match the baked mesh to avoid test-only edge rasterization errors.
	NavigationServer3D.map_set_cell_size(terrain_map, terrain_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(terrain_map, terrain_mesh.cell_height)
	NavigationServer3D.map_set_active(terrain_map, true)
	var terrain_region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_navigation_mesh(terrain_region, terrain_mesh)
	NavigationServer3D.region_set_map(terrain_region, terrain_map)
	var terrain_ready := await _await_navigation_owner(terrain_map, terrain_region, spawn)
	var terrain_start := NavigationServer3D.map_get_closest_point(terrain_map, spawn)
	var terrain_end := NavigationServer3D.map_get_closest_point(terrain_map, exit)
	var terrain_path := NavigationServer3D.map_get_path(terrain_map, terrain_start, terrain_end, true)
	if _expect(terrain_ready and not terrain_path.is_empty()
			and terrain_path[terrain_path.size() - 1].distance_to(terrain_end) < 0.2,
			label + ": base terrain has no complete spawn-to-exit route"):
		_checked_paths += 1
	elif current.has_meta("modeled_layout"):
		var route: Array = current.get_meta("modeled_layout")["route"]
		for cell: Vector3i in route:
			var at := Vector3(cell.x * 6, cell.y * 2, -cell.z * 6)
			var target := NavigationServer3D.map_get_closest_point(terrain_map, at)
			var partial := NavigationServer3D.map_get_path(terrain_map, terrain_start, target, true)
			if partial.is_empty() or partial[partial.size() - 1].distance_to(target) > 0.2:
				print("CAMPAIGN_TERRAIN_DISCONNECTED %s cell=%s target=%s last=%s" %
					[label, cell, target, partial[partial.size() - 1] if not partial.is_empty() else Vector3.INF])
				break
	NavigationServer3D.free_rid(terrain_region)
	NavigationServer3D.free_rid(terrain_map)


func _await_navigation_owner(map: RID, region: RID, at: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map, at) == region:
			return true
		await create_timer(0.025, true, true).timeout
	return false


func _check_ramps(current: Node3D, label: String) -> void:
	for body in current.get_node("Geometry").get_children():
		if not body.has_meta("lower_cell"):
			continue
		var lower: Vector3i = body.get_meta("lower_cell")
		var upper: Vector3i = body.get_meta("upper_cell")
		var collision: CollisionShape3D = null
		for child in body.get_children():
			if child is CollisionShape3D:
				collision = child
		if not _expect(collision != null and collision.shape is BoxShape3D, label + ": ramp collision missing"):
			continue
		var box := collision.shape as BoxShape3D
		var size := box.size
		var top_lower: Vector3 = collision.global_transform * Vector3(0.0, size.y * 0.5, size.z * 0.5)
		var top_upper: Vector3 = collision.global_transform * Vector3(0.0, size.y * 0.5, -size.z * 0.5)
		_expect(absf(top_lower.y - float(lower.y) * 2.0) < 0.025
			and absf(top_upper.y - float(upper.y) * 2.0) < 0.025, label + ": ramp top endpoints do not meet tile floors")
		var midpoint := (top_lower + top_upper) * 0.5
		for point: Vector3 in [top_lower, midpoint, top_upper]:
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point - Vector3.UP * 0.15, 1)
			var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - point.y) < 0.035,
				label + ": ramp endpoint/center lacks physical floor support")
		_checked_ramps += 1


func _check_hub_jars(level_id: StringName) -> void:
	var jars := get_nodes_in_group("hub_props")
	_expect(jars.size() == 3, "Authored world must contain three hub jars")
	for jar: StaticBody3D in jars:
		if level_id != &"level_01_01":
			_expect(not jar.visible and jar.collision_layer == 0, "Hidden hub jars must not block later chapters")
			continue
		_expect(jar.visible and jar.collision_layer == 1, "Opening courtyard must show collidable hub jars")
		var query := PhysicsRayQueryParameters3D.create(jar.global_position + Vector3.UP * 0.5,
			jar.global_position + Vector3.DOWN * 0.5, 1)
		query.exclude = [jar.get_rid()]
		var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
		_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - jar.global_position.y) < 0.05,
			String(jar.name) + ": jar is not supported by the real courtyard floor")


func _record_enemy_support(label: String) -> void:
	var unsupported: Array[String] = []
	var modeled := _world.campaign_runtime.current_level.get_node_or_null("Geometry/ModeledEnvironment")
	for enemy: Node3D in _world.enemies:
		var at: Vector3 = enemy.get("spawn_origin")
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 8.0, 1)
		if _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			unsupported.append("%s@%s" % [enemy.name, at])
		if modeled != null:
			for collision: CollisionShape3D in enemy.find_children("*", "CollisionShape3D", true, false):
				if collision.disabled or not collision.get_parent() is CharacterBody3D:
					continue
				var overlap := PhysicsShapeQueryParameters3D.new()
				overlap.shape = collision.shape
				overlap.transform = collision.global_transform
				overlap.collision_mask = 1
				overlap.margin = 0.0
				for hit: Dictionary in _world.get_world_3d().direct_space_state.intersect_shape(overlap):
					_expect(not modeled.is_ancestor_of(hit["collider"]), label + ": actual enemy capsule starts inside modeled architecture: " + String(enemy.name))
	_unsupported_enemy_spawns += unsupported.size()
	_expect(unsupported.is_empty(), label + ": enemy spawns lack physical terrain support: " + str(unsupported))
	print("CAMPAIGN_ENEMY_SUPPORT %s checked=%d unsupported=%s" % [label, _world.enemies.size(), unsupported])


func _check_story_prop_grounding(label: String) -> void:
	var expected := {"level_03_04": 2, "level_05_01": 1, "level_05_02": 1,
		"level_05_03": 2, "level_05_04": 1}
	var checked := 0
	for prop: Node3D in get_nodes_in_group("campaign_level_props"):
		if prop.name == &"ShrineNpc_bridge_tea_soul":
			var query := PhysicsRayQueryParameters3D.create(prop.global_position + Vector3.UP * 0.08,
				prop.global_position + Vector3.DOWN * 0.14, 1)
			var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - prop.global_position.y) < 0.025,
				label + ": bridge tea NPC floats above its floor")
		var visual := prop.get_node_or_null("StoryVisual") as Node3D
		if visual == null:
			continue
		checked += 1
		_grounded_story_props += 1
		var meshes := visual.find_children("*", "MeshInstance3D", true, false)
		if not _expect(not meshes.is_empty(), label + ": story prop has no visible model: " + String(prop.name)):
			continue
		# Aggregate the complete visual through every imported/procedural child
		# transform. A grounded Area root alone does not prove its plinth is grounded.
		var bounds := _mesh_bounds(visual)
		_expect(absf(bounds.position.y - prop.global_position.y) < 0.025,
			label + ": story visual base floats above or sinks below its root: " + String(prop.name))
		var probes: Array[Vector3] = [prop.global_position]
		for x in [bounds.position.x, bounds.end.x]:
			for z in [bounds.position.z, bounds.end.z]:
				probes.append(Vector3(x, bounds.position.y, z))
		for point: Vector3 in probes:
			# Short World-only rays reject the former authored +1.1m offset; a
			# long ray would still see the floor below a visibly floating plinth.
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.08,
				point + Vector3.DOWN * 0.14, 1)
			query.collide_with_areas = false
			var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - point.y) < 0.025,
				label + ": story root/base footprint lacks ground contact: " + String(prop.name) + "@" + str(point))
	_expect(checked == int(expected.get(label, 0)), label + ": actual story visual grounding coverage is incomplete")
	if checked > 0:
		print("CAMPAIGN_STORY_PROP_GROUNDING %s checked=%d" % [label, checked])


func _check_architecture_support(current: Node3D, label: String) -> void:
	var modeled := current.get_node_or_null("Geometry/ModeledEnvironment")
	if modeled == null:
		return
	var gate_pillars := 0
	var columns := 0
	for body: StaticBody3D in modeled.find_children("*", "StaticBody3D", true, false):
		var points: Array[Vector3] = []
		var kind := String(body.get_meta("architecture_kind", ""))
		if kind == "GatePillarSolid":
			gate_pillars += 1
			var collision := body.get_child(0) as CollisionShape3D
			var size := (collision.shape as BoxShape3D).size
			for x in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					points.append(collision.global_transform * Vector3(size.x * x, -size.y * 0.5, size.z * z))
		elif kind == "ColumnSolid":
			columns += 1
			var seen: Dictionary = {}
			for collision: CollisionShape3D in body.get_children():
				for vertex: Vector3 in (collision.shape as ConcavePolygonShape3D).get_faces():
					var local: Vector3 = collision.transform * vertex
					if absf(local.y) < 0.02 and not seen.has(local):
						seen[local] = true
						points.append(body.to_global(local))
		for point: Vector3 in points:
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.06, point - Vector3.UP * 0.1, 1)
			query.exclude = [body.get_rid()]
			var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty() and absf((hit["position"] as Vector3).y - point.y) < 0.04,
				label + ": modeled gate/column foot is unsupported: " + String(body.name) + "@" + str(point))
	var counts: Dictionary = modeled.get_meta("part_counts")
	_expect(gate_pillars == int(counts.get("Gate", 0)) * 2 and columns == int(counts.get("Column", 0)),
		label + ": footprint contract did not visit every gate pillar and column")


func _check_npc_support(label: String) -> void:
	# A fresh run meets these characters at their actual story locations. Hub
	# migration belongs to the earned rescue/first-boss progression contract.
	var initial_npcs := {"level_02_03": &"npc_iron_heart", "level_03_02": &"npc_lady_of_memories",
		"level_04_03": &"npc_xuanxiao_remnant", "level_05_04": &"npc_silence_bringer"}
	_expect(_world._shrine_npcs.size() == (1 if initial_npcs.has(label) else 0),
		label + ": fresh-run NPC placement contradicts story introduction")
	var npc_ids: Dictionary = {}
	for npc: Node3D in _world._shrine_npcs:
		npc_ids[npc.npc_id] = true
		_expect(npc.npc_id == initial_npcs.get(label, &""), label + ": incorrect story character at introduction")
		var bounds := _mesh_bounds(npc)
		var probes: Array[Vector3] = [npc.global_position]
		for x in [bounds.position.x, bounds.end.x]:
			for z in [bounds.position.z, bounds.end.z]:
				probes.append(Vector3(x, npc.global_position.y, z))
		for at: Vector3 in probes:
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1, at + Vector3.DOWN * 0.2, 1)
			_expect(not _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
				label + ": shrine NPC footprint lacks ground support: " + String(npc.name))
		for other: Node3D in _world._shrine_npcs:
			if other != npc:
				_expect(npc.position.distance_to(other.position) >= 2.2,
					label + ": projected shrine NPC positions overlap")
				var other_bounds := _mesh_bounds(other)
				var overlaps := bounds.position.x < other_bounds.end.x and bounds.end.x > other_bounds.position.x \
					and bounds.position.z < other_bounds.end.z and bounds.end.z > other_bounds.position.z
				_expect(not overlaps, label + ": shrine NPC model footprints overlap")
	_expect(npc_ids.size() == _world._shrine_npcs.size(), label + ": duplicate shrine NPC identity")


func _mesh_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var at: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = at if first else bounds.merge(at)
		first = false
	return bounds


func _check_shortcut_support(label: String) -> void:
	var closed: Vector3 = _world.shortcut._closed_position
	_expect(closed.is_equal_approx(_world.shortcut_gate.position), label + ": shortcut retained old level's closed position")
	var excluded: Array[RID] = []
	for body: StaticBody3D in _world.shortcut_gate.find_children("*", "StaticBody3D", true, false):
		excluded.append(body.get_rid())
	for point: Vector3 in [_world.shortcut.global_position, closed - Vector3.UP * 1.5]:
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point + Vector3.DOWN * 0.2, 1)
		query.exclude = excluded
		_expect(not _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			label + ": shortcut lever or closed gate floats off the floor")


func _check_spawn_projection() -> void:
	var cells: Array = [Vector3i.ZERO, Vector3i(1, 0, 0)]
	var seam := Vector3(3.0, 0.05, 0.0)
	_expect(LevelBuilder.supported_spawn(cells, seam, 0.6).is_equal_approx(seam),
		"Supported spawn across adjacent tile seam must remain unchanged")
	var projected := LevelBuilder.supported_spawn([Vector3i.ZERO], Vector3(3.5, 2.05, -4.0), 0.6)
	_expect(projected.is_equal_approx(Vector3(2.3, 0.05, -2.3)), "Exposed spawn must project onto safe tile footprint")
	var elevated := LevelBuilder.supported_spawn([Vector3i(0, 2, 0)], Vector3(0.0, 0.05, 0.0), 0.6)
	_expect(elevated.is_equal_approx(Vector3(0.0, 4.05, 0.0)), "Spawn projection must respect elevated floor height")


func _freeze_actors() -> void:
	_world.player.set_process(false)
	_world.player.set_physics_process(false)
	for enemy: Node in _world.enemies:
		if is_instance_valid(enemy):
			enemy.set_process(false)
			enemy.set_physics_process(false)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
