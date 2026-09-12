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
		var bake_ms := (Time.get_ticks_usec() - started) / 1000.0
		var plan: Dictionary = current.get_meta("expansion", {})
		_expect(not plan.is_empty(), id + ": expansion actually built")
		_expect(int(region.get_meta("geometry_revision", 0)) > 0, id + ": published production navigation")
		var map := region.get_navigation_map()
		var entry: Vector3 = current.to_global(plan["entry"])
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
