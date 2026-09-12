extends SceneTree
## Actual production bakes, all district destinations, no disk-save I/O.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void: _apply_settings()
	func _save_run(_reason: String) -> bool: return true
var world: AuditWorld
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	world = AuditWorld.new()
	var scene := WorldScene.instantiate()
	for child in scene.get_children():
		child.owner = null
		scene.remove_child(child)
		world.add_child(child)
	scene.free()
	root.add_child(world)
	world.set_process(false)
	var records: Array = []
	for level: Dictionary in world.campaign_runtime.registry.get_levels():
		var id := String(level["id"])
		var filter := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--levels="): filter = arg.trim_prefix("--levels=")
		if not filter.is_empty() and not (id in filter.split(",")): continue
		var started := Time.get_ticks_usec()
		world._load_campaign_level(StringName(id))
		world.player.set_physics_process(false)
		for enemy in world.enemies: enemy.set_physics_process(false)
		var current: Node3D = world.campaign_runtime.current_level
		var region := current.get_node("NavigationSurface") as NavigationRegion3D
		for frame in 180:
			await physics_frame
			await process_frame
			if int(region.get_meta("geometry_revision", 0)) > 0: break
		# The production publish submits the mesh to NavigationServer; allow the
		# server's following physics synchronization before requesting paths.
		for frame in 3:
			await physics_frame
			await process_frame
		var plan: Dictionary = current.get_meta("expansion", {})
		_expect(not plan.is_empty(), id + ": expansion actually built")
		_expect(int(region.get_meta("geometry_revision", 0)) > 0, id + ": published production navigation")
		var map := region.get_navigation_map()
		var entry: Vector3 = current.to_global(plan["entry"])
		# NavigationServer may publish the old world's empty map after the
		# region revision changes. Observe a real local path before testing
		# distant connectivity; a frame count alone does not prove readiness.
		for frame in 90:
			if NavigationServer3D.map_get_closest_point_owner(map, entry) == region.get_rid() \
				and not NavigationServer3D.map_get_path(map, entry, entry + Vector3(.1, 0, 0), true).is_empty(): break
			await physics_frame
			await process_frame
		_expect(NavigationServer3D.map_get_closest_point_owner(map, entry) == region.get_rid(), id + ": path query observes this level's published region")
		var bake_ms := (Time.get_ticks_usec() - started) / 1000.0
		var rooms := current.get_node_or_null("CampaignInteriorRuntime")
		if rooms != null:
			# This audit inspects each stage to test baked physical connectivity.
			# Continuous forward movement is owned by the separate traversal test.
			var stages: Array = plan["interior"]["stages"]
			for index in stages.size():
				var clue: Vector3 = current.to_global(stages[index]["clue_position"])
				var clue_path := NavigationServer3D.map_get_path(map, entry, clue, true)
				_expect(not clue_path.is_empty() and clue_path[clue_path.size()-1].distance_to(clue) < 1.2,
					id + ": physical navigation reaches floor %d evidence in forward order target=" % (index + 1) + str(clue) + " ended=" + str(clue_path[clue_path.size()-1] if not clue_path.is_empty() else Vector3.INF))
				var next: Vector3 = current.to_global(stages[index + 1]["clue_position"] if index < 2 else plan["reward"])
				var closed_path := NavigationServer3D.map_get_path(map, clue, next, true)
				var returns_downstairs := bool(plan["interior"].get("chamber_violation", false)) and index == 1
				if not returns_downstairs:
					_expect(closed_path.is_empty() or closed_path[closed_path.size()-1].distance_to(next) > 2.0,
						id + ": closed stage %d physically blocks later rooms" % index)
				else:
					_expect(float(stages[index + 1]["clue_position"].y) < float(stages[index]["clue_position"].y),
						id + ": the authored mirror return reuses an already reachable lower room")
				var approach := Vector3(0, .05, -1.2 if index == 1 else 1.2)
				world.player.global_position = clue + approach
				for frame in 3: await physics_frame
				rooms.clue_areas[index].interact(world.player)
				var correct := int(stages[index]["correct_index"])
				# Navigation inspection requires the specified combat gate to have
				# been defeated. This injected fixture is not combat-play evidence.
				if index == 2:
					var loop := current.get_node_or_null("CampaignInteriorLoopRuntime")
					var guard: Node3D = loop.threats.get(id + "/interior/top_shield") if loop != null else null
					if is_instance_valid(guard) and float(guard.health) > 0:
						guard.receive_hit_payload({"damage": 100000.0, "stagger": 0.0, "poise": 0.0,
							"direction": Vector3.ZERO, "source": world.player, "blockable": false, "parryable": false})
				world.player.global_position = current.to_global(stages[index]["controls_positions"][correct]) + approach
				for frame in 3: await physics_frame
				rooms.control_areas[index][correct].interact(world.player)
				_expect(rooms.completed_stage_count() == index + 1, id + ": evidence and correct physical control resolve stage %d" % index)
				var revision := int(region.get_meta("geometry_revision", 0))
				for frame in 150:
					await physics_frame
					await process_frame
					if int(region.get_meta("geometry_revision", 0)) > revision: break
				for frame in 3:
					await physics_frame
					await process_frame
				# Door state changes, region publication and NavigationServer path
				# availability are separate events. Observe the opened route itself.
				var opened_route := false
				for frame in 90:
					var refreshed := NavigationServer3D.map_get_path(map, entry, next, true)
					if not refreshed.is_empty() and refreshed[refreshed.size()-1].distance_to(next) < 1.2:
						opened_route = true
						break
					await physics_frame
					await process_frame
				_expect(opened_route, id + ": opened stage %d publishes a traversable route" % index)
				if not opened_route:
					for p: Vector3 in stages[index]["to_next_route"]:
						var goal := current.to_global(p)
						var partial := NavigationServer3D.map_get_path(map, entry, goal, true)
						print("INTERIOR_NAV_BREAK stage=%d waypoint=%s closest=%s ended=%s" % [index, p, NavigationServer3D.map_get_closest_point(map, goal), partial[partial.size()-1] if not partial.is_empty() else Vector3.INF])
		var destinations: Array[Vector3] = [plan["overlook"], plan["reward"]]
		var gate: Dictionary = plan.get("return_gate", {})
		if not gate.is_empty(): destinations.append(gate["far_side"] - Vector3.UP * .7)
		var lift: Dictionary = plan.get("lift", {})
		if not lift.is_empty(): destinations.append(lift["upper_landing"])
		var path_lengths: Array = []
		for point: Vector3 in destinations:
			var destination := current.to_global(point)
			var nearest := NavigationServer3D.map_get_closest_point(map, destination)
			_expect(nearest.distance_to(destination) < 1.1, id + ": district destination near physical navigation " + str(point))
			var path := NavigationServer3D.map_get_path(map, entry, destination, true)
			_expect(not path.is_empty() and path[path.size()-1].distance_to(destination) < 1.2,
				id + ": complete actual navigation to district " + str(point) + " ended=" + str(path[path.size()-1] if not path.is_empty() else Vector3.INF))
			var length := 0.0
			for index in range(1, path.size()): length += path[index].distance_to(path[index-1])
			path_lengths.append(snappedf(length, .1))
		var record := {"id": id, "load_and_navigation_ms": bake_ms, "cells": current.get_meta("walkable_cell_count"),
			"polygons": region.navigation_mesh.get_polygon_count(), "path_lengths": path_lengths}
		records.append(record)
		print("EXPANSION_NAV ", JSON.stringify(record))
	world.free()
	await process_frame
	var output := FileAccess.open("res://../build/scene-expansion/navigation-metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	output.close()
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_EXPANSION_NAVIGATION_OK levels=%d checks=%d" % [records.size(), checks])
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
