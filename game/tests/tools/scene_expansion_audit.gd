extends SceneTree
## Reproducible native Compatibility inspection; never loads or writes a save.
const Content = preload("res://scripts/data/campaign_content.gd")
const Builder = preload("res://scripts/world/procedural_campaign_level_builder.gd")
const EnvironmentSetup = preload("res://scripts/core/world_environment.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var label := "before"
	var selected := ["level_01_01", "level_01_02", "level_02_02", "level_03_01", "level_04_03", "level_05_04"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--levels="): selected = Array(arg.trim_prefix("--levels=").split(","))
	var folder := ProjectSettings.globalize_path("res://../build/scene-expansion/" + label)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var records: Array = []
	for level: Dictionary in Content.levels():
		var id := String(level["id"])
		if id not in selected: continue
		var stage := Node3D.new()
		root.add_child(stage)
		var env = EnvironmentSetup.new()
		env.setup(stage)
		env.create_environment()
		env.apply_theme(StringName(level["theme_id"]))
		var started := Time.get_ticks_usec()
		var scene := Builder.build(level)
		var build_ms := (Time.get_ticks_usec() - started) / 1000.0
		if scene == null:
			quit(1)
			return
		stage.add_child(scene)
		var camera := Camera3D.new()
		camera.far = 1200.0
		stage.add_child(camera)
		camera.current = true
		var target := Vector3(0, 0, -65)
		camera.position = Vector3(115, 105, 62)
		camera.look_at(target)
		for frame in 20: await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(id + "-overview.png"))
		var record := {"id": id, "build_ms": build_ms, "cells": scene.get_meta("walkable_cell_count"),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
		camera.position = Vector3(0, 3.2, 9)
		camera.look_at(Vector3(0, 3, -45))
		for frame in 20: await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(id + "-entry.png"))
		records.append(record)
		print("SCENE_INSPECTION ", JSON.stringify(record))
		stage.free()
		for frame in 3: await process_frame
	var output := FileAccess.open(folder.path_join("metrics.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer": "gl_compatibility", "display": DisplayServer.get_name(),
		"viewport": [1280,720], "method": "Builder + production environment; fixed inspection camera; no AI; no save", "levels": records}, "\t"))
	output.close()
	print("ASHEN_SCENE_INSPECTION_OK")
	quit(0)
