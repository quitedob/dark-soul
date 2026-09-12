extends SceneTree
## Render actual imported runtime models in a lit rest/action comparison.
## Run with a rendering display driver (not --headless), after asset import.

const Embedded = preload("res://scripts/core/embedded_model_actions.gd")
const Player = preload("res://scripts/player/player.gd")
const CASES := [
	["player", "attack_light", 0.38],
	["characters/npcs/01-Cloud-Wanderer.glb", "interact", 0.65],
	["bosses/03-Jade-Faced-Fox-NineTails.glb", "attack", 0.45],
	["enemies/04-celestial-fall/02-Cloud-Sky-Eagle.glb", "fly", 0.4],
	["weapons/01-WindHunter-Bow.glb", "draw", 0.5],
	["props/04-Traps.glb", "gate_open", 0.75],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		printerr("Expected absolute screenshot directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	root.size = Vector2i(1400, 760)
	root.content_scale_size = Vector2i(1400, 760)
	var evidence: Array = []
	for index in CASES.size():
		var row: Array = CASES[index]
		var canvas := Control.new()
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(canvas)
		for side in 2:
			var container := SubViewportContainer.new()
			container.position = Vector2(side * 700, 58)
			container.size = Vector2(700, 650)
			canvas.add_child(container)
			var viewport := SubViewport.new()
			viewport.size = Vector2i(700, 650)
			viewport.own_world_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			container.add_child(viewport)
			var stage := Node3D.new()
			viewport.add_child(stage)
			var model: Node3D
			var body: Node3D
			if row[0] == "player":
				model = Player.new()
				stage.add_child(model)
				model.set_physics_process(false)
				model.set_process_unhandled_input(false)
				model._anim_bridge.anim_tree.active = false
				model.try_switch_class(model.CombatStyle.TWIN_COLOSSI)
				body = model.body_mesh
			else:
				model = load(Embedded.MODEL_PREFIX + row[0]).instantiate()
				stage.add_child(model)
				body = model
				Embedded.bind(model, model, row[0])
			await process_frame
			var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if side == 0:
				player.stop()
				for skeleton in body.find_children("*", "Skeleton3D", true, false):
					skeleton.reset_bone_poses()
			else:
				if not Embedded.play_action(body, row[1], true):
					printerr("Capture action missing: ", row)
					quit(1)
					return
				player.advance(0)
				player.seek(player.current_animation_length * float(row[2]), true)
			await process_frame
			if row[0] == "player":
				model._update_visual_pose()
			var bounds := _bounds(model)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("243041")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color("dde8ff")
			environment.environment.ambient_light_energy = 0.7
			stage.add_child(environment)
			var light := DirectionalLight3D.new()
			light.rotation_degrees = Vector3(-40, -35, 0)
			light.light_energy = 1.6
			stage.add_child(light)
			var camera := Camera3D.new()
			stage.add_child(camera)
			var extent := maxf(bounds.size.length(), 1.0)
			var center := bounds.get_center()
			camera.position = center + Vector3(0.65, 0.35, 1.0).normalized() * extent * 1.9
			camera.look_at(center)
			camera.fov = 42
			camera.make_current()
			var label := Label.new()
			label.text = "REST" if side == 0 else "%s / %.0f%%" % [row[1], float(row[2]) * 100]
			label.position = Vector2(side * 700 + 24, 24)
			label.add_theme_font_size_override("font_size", 23)
			canvas.add_child(label)
		var footer := Label.new()
		footer.text = "%s  |  Godot 4.7.1 imported skin + textures" % row[0]
		footer.position = Vector2(24, 720)
		footer.add_theme_font_size_override("font_size", 20)
		canvas.add_child(footer)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := args[0].path_join("%02d-%s.png" % [index + 1, String(row[0]).get_file().get_basename()])
		var result := root.get_texture().get_image().save_png(path)
		if result != OK:
			quit(1)
			return
		evidence.append({"model": row[0], "action": row[1], "fraction": row[2], "screenshot": path,
			"sha256": FileAccess.get_sha256(path)})
		canvas.free()
		await process_frame
	var file := FileAccess.open(args[0].path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	file.close()
	print("ASHEN_EMBEDDED_ACTION_CAPTURES_OK ", evidence.size())
	quit(0)


func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var box := mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
