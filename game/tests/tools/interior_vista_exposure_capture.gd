extends "res://tests/tools/scene_expansion_runtime_capture.gd"
## Identical geometry, three supported observation points, three lighting
## inspection conditions. These are captures, not human recognition metrics.
func _run() -> void:
	var selected := ["level_01_02", "level_02_02", "level_03_02", "level_04_03", "level_05_04"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="): selected = Array(arg.trim_prefix("--levels=").split(","))
	root.size = Vector2i(1280, 720)
	var folder := ProjectSettings.globalize_path("res://../build/scene-expansion/vista-exposure")
	DirAccess.make_dir_recursive_absolute(folder)
	world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		world.add_child(child)
	contents.free()
	root.add_child(world)
	world.set_process(false)
	world.hud.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	var failures: Array[String] = []
	var records: Array[Dictionary] = []
	for id: String in selected:
		world._load_campaign_level(StringName(id))
		world.player.set_physics_process(false)
		for enemy in world.enemies: enemy.set_physics_process(false)
		await _frames(10)
		var level: Node3D = world.campaign_runtime.current_level
		var plan: Dictionary = level.get_meta("expansion")["interior"]
		var vistas: Array = plan["souls"].get("vistas", [])
		if vistas.size() != 3:
			failures.append(id + ": requires three authored observation points")
			continue
		var environment: Environment = world.world_environment.environment
		var light := world.get_node("Moonlight") as DirectionalLight3D
		var ambient := environment.ambient_light_energy
		var key_energy := light.light_energy
		var key_color := light.light_color
		var profiles := [{"id": "overcast", "ambient": 1.05, "key": .45, "color": Color("c2d2e0"), "exposure": .9},
			{"id": "noon", "ambient": 1.55, "key": 1.8, "color": Color("fff3dc"), "exposure": 1.25},
			{"id": "dusk", "ambient": .65, "key": .55, "color": Color("ebac83"), "exposure": .72}]
		for vista: Dictionary in vistas:
			camera.global_position = level.to_global(vista["position"])
			var target: Vector3 = level.to_global(vista["look_at"])
			camera.look_at(target)
			camera.current = true
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target + (target - camera.global_position).normalized() * .5, 1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			var door: Node3D = level.get_node("CampaignInteriorRuntime").stage_doors[2]
			var clear: bool = hit.is_empty() or hit.get("collider") == door
			if not clear: failures.append(id + "/" + String(vista["id"]) + ": actual gate sightline blocked by " + str(hit.get("collider")) + " at " + str(hit.get("position")))
			for profile: Dictionary in profiles:
				environment.ambient_light_energy = ambient * float(profile["ambient"])
				environment.tonemap_exposure = float(profile["exposure"])
				light.light_energy = key_energy * float(profile["key"])
				light.light_color = profile["color"]
				await _frames(3)
				var filename := "%s-%s-%s.png" % [id, String(vista["id"]).validate_filename(), profile["id"]]
				await _capture(folder.path_join(filename))
				records.append({"level_id": id, "view": vista["id"], "condition": profile["id"], "image": filename,
					"ray_to_actual_gate_clear": clear, "method": "native Compatibility inspection; supported eye point; no player recognition sample"})
			environment.tonemap_exposure = 1.0
			environment.ambient_light_energy = ambient
			light.light_energy = key_energy
			light.light_color = key_color
		var reward_view: Dictionary = plan["souls"].get("reward_vista", {})
		if not reward_view.is_empty():
			camera.global_position = level.to_global(reward_view["position"])
			var target: Vector3 = level.to_global(reward_view["look_at"])
			camera.look_at(target)
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty(): failures.append(id + ": closed-gate reward sightline blocked by " + str(hit.get("collider")))
			await _frames(3)
			var filename := id + "-reward-before-unlock.png"
			await _capture(folder.path_join(filename))
			records.append({"level_id": id, "view": "reward", "image": filename, "ray_clear": hit.is_empty(), "gate_open": false})
		await _capture_details(level, plan, camera, folder)
		print("INTERIOR_VISTA_CAPTURE level=%s captures=9 visibility_rays=3" % id)
	var output := FileAccess.open(folder.path_join("capture-records.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	output.close()
	world._clear_enemies()
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_INTERIOR_VISTA_CAPTURE_OK images=%d human_recognition=unmeasured" % records.size())
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)


func _capture_details(level: Node3D, plan: Dictionary, camera: Camera3D, folder: String) -> void:
	var id := String(level.get_meta("level_id"))
	var clue: Vector3 = plan["stages"][0]["clue_position"]
	camera.global_position = level.to_global(clue + Vector3(-.6, 2.6, 3.9))
	camera.look_at(level.to_global(clue + Vector3(1.2, .8, -1.5)))
	await _frames(3)
	await _capture(folder.path_join(id + "-owner-and-east-marks.png"))
	# Actual read/choice handlers at explicit inspection placements, used only
	# to capture the live optional light window. The walking contract proves
	# how the same interactions are reached without repositioning.
	var rooms: Node3D = level.get_node("CampaignInteriorRuntime")
	var clue_area: Area3D = rooms.clue_areas[0]
	world.player.respawn_at(clue_area.global_position + Vector3(0, .1, 1.1))
	await _frames(2)
	clue_area.interact(world.player)
	var correct: int = plan["stages"][0]["correct_index"]
	var option: Area3D = rooms.control_areas[0][correct]
	world.player.respawn_at(option.global_position + Vector3(0, .1, 1.1))
	await _frames(2)
	option.interact(world.player)
	var scout: Node3D = level.get_node("CampaignInteriorRevisitRuntime").scout_copy
	if scout != null and scout.visible:
		var copy: Vector3 = plan["stele_scout_reward"]["position"]
		camera.global_position = level.to_global(copy + Vector3(0, 1.0, 4.8))
		camera.look_at(level.to_global(copy))
		await _frames(3)
		await _capture(folder.path_join(id + "-scout-active-production.png"))
	if plan.has("return_mirror"):
		var wall: Vector3 = plan["return_mirror"]["wall_position"]
		camera.global_position = level.to_global(wall + Vector3(-6, 2.1, 1))
		camera.look_at(level.to_global(wall + Vector3(0, 1.5, 0)))
		await _frames(24)
		await _capture(folder.path_join(id + "-ground-return-mirror.png"))
		var empty: Vector3 = plan["return_mirror"]["empty_frame_position"]
		camera.global_position = level.to_global(empty + Vector3(-3, 3, 5))
		camera.look_at(level.to_global(empty + Vector3(0, 1, 0)))
		await _frames(3)
		await _capture(folder.path_join(id + "-top-empty-frame.png"))
	if plan.has("archive_annex"):
		var center: Vector3 = plan["archive_annex"]["position"]
		var entry: Vector3 = plan["archive_annex"]["entry"]
		camera.global_position = level.to_global(entry + (entry - center).normalized() * 4 + Vector3.UP * 2.1)
		camera.look_at(level.to_global(center + Vector3.UP * 1.3))
		await _frames(3)
		await _capture(folder.path_join(id + "-archive-shelf-entry.png"))
