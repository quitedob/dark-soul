extends SceneTree
## Live normal-speed native scene inspections using real world, AI and player.
## Only save I/O is suppressed. Level/overlook selection is inspection, not playthrough.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void: _apply_settings()
	func _save_run(_reason: String) -> bool: return true
var world: AuditWorld

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var selected := ["level_01_01", "level_01_02", "level_02_02", "level_03_01", "level_04_03", "level_05_04"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="): selected = Array(arg.trim_prefix("--levels=").split(","))
	root.size = Vector2i(1280, 720)
	var folder := ProjectSettings.globalize_path("res://../build/scene-expansion/runtime")
	DirAccess.make_dir_recursive_absolute(folder)
	world = AuditWorld.new()
	var scene := WorldScene.instantiate()
	for child in scene.get_children():
		child.owner = null
		scene.remove_child(child)
		world.add_child(child)
	scene.free()
	root.add_child(world)
	var metrics: Array = []
	for id: String in selected:
		world._load_campaign_level(StringName(id))
		await _frames(60)
		await _capture(folder.path_join(id + "-entry.png"))
		Input.action_press("move_forward")
		var start: Vector3 = world.player.global_position
		var frame_ms: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 90:
			await process_frame
			var now := Time.get_ticks_usec()
			frame_ms.append((now - previous) / 1000.0)
			previous = now
		Input.action_release("move_forward")
		var displacement := start.distance_to(world.player.global_position)
		await _capture(folder.path_join(id + "-walk.png"))
		var current: Node3D = world.campaign_runtime.current_level
		var plan: Dictionary = current.get_meta("expansion")
		world.player.respawn_at(current.to_global(plan["overlook"] + Vector3.UP * .1))
		var look_at: Vector3 = plan["vista"]["look_at"]
		var direction: Vector3 = current.to_global(look_at) - world.player.global_position
		world.player.camera_rig.rotation.y = atan2(-direction.x, -direction.z)
		await _frames(36)
		await _capture(folder.path_join(id + "-overlook-inspection.png"))
		frame_ms.sort()
		var record := {"id": id, "frame_p50_ms": frame_ms[45], "frame_p95_ms": frame_ms[85],
			"forward_displacement_m": displacement, "input_frames": 90, "time_scale": Engine.time_scale,
			"ai_active": true, "method": "normal-speed native input at entry; direct level and overlook selection; memory-only save"}
		print("EXPANSION_RUNTIME_CAPTURE ", JSON.stringify(record))
		metrics.append(record)
	world.free()
	await process_frame
	var output := FileAccess.open(folder.path_join("metrics.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	output.close()
	print("ASHEN_EXPANSION_RUNTIME_CAPTURE_OK")
	quit(0)

func _frames(count: int) -> void:
	for frame in count: await process_frame

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
