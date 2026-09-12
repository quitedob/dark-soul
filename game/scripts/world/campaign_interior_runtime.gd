extends Node3D
## Match the room's visible evidence to a physical control. Reading is optional;
## only the first ascent requires resolving the lower rooms in order.

signal progress_changed(interior_id: String, completed_stages: int, total_stages: int)
signal completed(completion_flag: String)
signal puzzle_entered(interior_id: String, stage_id: String, position_world: Vector3)
signal puzzle_resolved(interior_id: String, stage_id: String, read_status: bool, position_world: Vector3)

const Interaction = preload("res://scripts/world/campaign_exit_interact.gd")
const EnvironmentArt = preload("res://scripts/world/campaign_environment_renderer.gd")
const StoryArt = preload("res://scripts/world/campaign_story_prop_renderer.gd")
const Visuals = preload("res://scripts/levels/procedural_level_modules.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")

var world: Node3D
var level_root: Node3D
var interior: Dictionary = {}
var stages: Array[Dictionary] = []
var stage_doors: Array[StaticBody3D] = []
var clue_areas: Array[Area3D] = []
var control_areas: Array[Array] = []
var _configured := false
var _progress_bounds := AABB()
var scene_readables: Dictionary = {}
var _occupied_floor := -1


func setup(owner_world: Node3D, owner_level: Node3D, plan: Dictionary) -> void:
	if _configured or plan.is_empty() or not is_instance_valid(owner_world) or not is_instance_valid(owner_level):
		return
	world = owner_world
	level_root = owner_level
	interior = plan.duplicate(true)
	for stage: Dictionary in interior.get("stages", []):
		stages.append(stage)
	if stages.size() != 3 or String(interior.get("completion_flag", "")).is_empty():
		push_error("An interior investigation requires three ordered stages and a completion flag")
		return
	for index in stages.size():
		var stage: Dictionary = stages[index]
		if int(stage.get("index", -1)) != index or stage.get("options", []).size() != 3 or stage.get("controls_positions", []).size() != 3:
			push_error("Interior stages require ordered indices and three physical choices")
			return
		if int(stage.get("correct_index", -1)) not in range(3) or String(stage.get("clue_text", "")).is_empty():
			push_error("Interior stage is missing its clue or a valid evidence-based answer")
			return
	_configured = true
	set_meta("interior_id", String(interior.get("id", "")))
	set_meta("story_source", String(interior.get("story_source", "docs/story")))
	for index in stages.size():
		_build_stage(index)
	for readable: Dictionary in interior.get("scene_readables", []):
		var area := _interaction("InteriorReadable_" + String(readable.get("id", "")).validate_node_name(), readable["position"], -1, -1)
		area.world_callback = Callable(self, "_read_scene")
		area.prompt_text = Copy.copy("阅读 · ", "Read · ") + String(readable.get("title", "遗留刻字"))
		scene_readables[area] = readable.duplicate(true)
	_refresh_prompts()
	progress_changed.emit(String(interior["id"]), completed_stage_count(), stages.size())


func stage_flag(index: int, fact: String) -> String:
	return "interior:%s:%s:%s" % [String(interior["id"]), fact, String(stages[index]["id"])]


func started_flag() -> String:
	return "interior:%s:started" % String(interior["id"])


func completed_stage_count() -> int:
	var count := 0
	for index in stages.size():
		if not bool(world.run_state.get_choice_flag(stage_flag(index, "solved"), false)):
			break
		count += 1
	return count


func progress_hint() -> String:
	var count := completed_stage_count()
	var title := String(interior.get("display_name", "楼内遗事"))
	if count == stages.size():
		return "%s · %s" % [title, Copy.copy("遗事已厘清：领取余烬，开启归途。", "Investigation complete: claim the embers and open the return route.")]
	var room := String(stages[count].get("room_name", "%d层" % (count + 1)))
	var read := bool(world.run_state.get_choice_flag(stage_flag(count, "clue"), false))
	return "%s · %d/3 · %s：%s" % [title, count, room,
		Copy.copy("核对刻字与场景，选择机关", "Match the inscription and scene to a control") if read else Copy.copy("观察相连的痕迹与印记；碑记可选读", "Follow the connected traces and seals; reading is optional")]


func _physics_process(_delta: float) -> void:
	if not _configured or not is_instance_valid(world.player) or float(world.player.health) <= 0:
		_occupied_floor = -1
		return
	var local := level_root.to_local(world.player.global_position)
	var occupied := -1
	var nearest := INF
	var origin: Vector3 = interior.get("origin", Vector3.ZERO)
	if absf(local.x - origin.x) <= 21.0 and absf(local.z - origin.z) <= 21.0:
		for index in stages.size():
			var clue_at: Vector3 = stages[index]["clue_position"]
			if absf(local.y - clue_at.y) < 2.0 and local.distance_squared_to(clue_at) < nearest:
				occupied = index
				nearest = local.distance_squared_to(clue_at)
	if occupied != _occupied_floor:
		_occupied_floor = occupied
		if occupied >= 0:
			puzzle_entered.emit(String(interior["id"]), String(stages[occupied]["id"]), world.player.global_position)


func objective_for_player() -> String:
	if not _configured or not is_instance_valid(world.player):
		return ""
	return progress_hint() if _progress_bounds.has_point(level_root.to_local(world.player.global_position)) else ""


func _build_stage(index: int) -> void:
	var stage: Dictionary = stages[index]
	var gate: Dictionary = stage["door"]
	var door := StaticBody3D.new()
	door.name = "InteriorStageGate_%d" % index
	door.collision_layer = 1
	door.collision_mask = 0
	door.add_to_group("campaign_navigation_source")
	door.add_to_group("campaign_terrain_navigation_source")
	door.set_meta("interior_stage", index)
	var size: Vector3 = gate["size"]
	var shape := CollisionShape3D.new()
	shape.name = "GateCollision"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * .5
	door.add_child(shape)
	var visual := Node3D.new()
	visual.name = "GateLeaf"
	visual.position.y = size.y * .5
	door.add_child(visual)
	Visuals.add_solid_visual(visual, size, world._current_visual_theme())
	add_child(door)
	door.global_transform = level_root.global_transform * Transform3D(Basis(Vector3.UP, float(gate.get("yaw", 0.0))), gate["position"])
	stage_doors.append(door)
	var clue := _interaction("InteriorClue_%d" % index, stage["clue_position"], index, -1)
	clue.world_callback = Callable(self, "_read_clue")
	clue_areas.append(clue)
	if not stage.has("visual_clue"):
		_add_clue_visual(clue, stage)
	else:
		_add_label(clue, Copy.copy("碑记 · 可选阅读", "Inscription · Optional reading"), 2.65)
	var controls: Array = []
	for option in 3:
		var area := _interaction("InteriorChoice_%d_%d" % [index, option], stage["controls_positions"][option], index, option)
		area.world_callback = Callable(self, "_choose")
		if not stage.has("option_visuals"):
			_add_lantern(area)
		_add_label(area, "%d · %s" % [option + 1, String(stage["options"][option])], 2.45 if stage.has("option_visuals") else 1.65)
		controls.append(area)
	control_areas.append(controls)
	var room_box := AABB(stage["clue_position"] - Vector3(13, 1, 13), Vector3(26, 6, 26))
	_progress_bounds = room_box if index == 0 else _progress_bounds.merge(room_box)
	if index < completed_stage_count():
		_open_stage_door(index, false)


func _interaction(label: String, position_in_level: Vector3, stage_index: int, option_index: int) -> Area3D:
	var area := Interaction.new()
	area.name = label
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.add_to_group("interactable")
	area.add_to_group("campaign_interior_interaction")
	area.set_meta("stage_index", stage_index)
	area.set_meta("option_index", option_index)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .85
	collision.shape = shape
	collision.position.y = .8
	area.add_child(collision)
	add_child(area)
	area.global_position = level_root.to_global(position_in_level)
	return area


func _add_clue_visual(area: Area3D, stage: Dictionary) -> void:
	var prop_ids: Array = stage.get("prop_ids", [])
	if not prop_ids.is_empty() and StoryArt.get_part_ids().has(String(prop_ids[0])):
		var prop_id := String(prop_ids[0])
		var visual := StoryArt.instantiate_part(prop_id)
		if visual != null:
			var bounds := StoryArt.get_part_aabb(prop_id)
			var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
			visual.scale = Vector3.ONE * minf(1.0, 1.4 / maxf(extent, .1))
			area.add_child(visual)
	else:
		_add_lantern(area)
	_add_label(area, Copy.copy("碑记 · 阅读", "Evidence · Read"), 1.75)


func _add_lantern(area: Area3D) -> void:
	var visual := EnvironmentArt.instantiate_part(StringName(world._current_visual_theme()), "Lantern")
	if visual != null:
		area.add_child(visual)
	var light := OmniLight3D.new()
	light.position.y = .85
	light.omni_range = 2.4
	light.light_energy = .35
	light.light_color = Color("f2bb70")
	light.shadow_enabled = false
	area.add_child(light)


func _add_label(area: Area3D, text: String, height: float) -> void:
	var label := Label3D.new()
	label.name = "Inscription"
	label.text = text
	label.font = Copy.InterfaceFont
	label.font_size = 30
	label.pixel_size = .009
	label.width = 180
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.position.y = height
	area.add_child(label)


func _valid_interaction(area: Node3D, actor: Node) -> bool:
	if not _valid_actor(area, actor):
		return false
	var index := int(area.get_meta("stage_index", -1))
	if index < 0 or index >= stages.size():
		return false
	var stage: Dictionary = stages[index]
	var actor_local := level_root.to_local(actor.global_position)
	if absf(actor_local.y - (stage["clue_position"] as Vector3).y) > 2.0:
		return false
	var door: StaticBody3D = stage_doors[index]
	var clue_side := signf(door.to_local(level_root.to_global(stage["clue_position"])).z)
	var actor_in_door := door.to_local(actor.global_position)
	var door_width: float = stage["door"]["size"].x
	# Constrain the doorway itself, never an infinite plane across the gallery.
	if clue_side != 0 and absf(actor_in_door.x) <= door_width * .5 + .65 and actor_in_door.z * clue_side < -.1:
		_say(Copy.copy("请从本层机关一侧操作。", "Use the control from this room's side."))
		return false
	return true


func _valid_actor(area: Node3D, actor: Node) -> bool:
	if not is_instance_valid(world) or not is_instance_valid(level_root) or not is_instance_valid(area):
		return false
	if not is_inside_tree() or level_root.is_queued_for_deletion() or area.get_parent() != self:
		return false
	if actor != world.player or not actor is Node3D or float(actor.health) <= 0:
		return false
	if world.campaign_runtime.current_level != level_root or actor.global_position.distance_to(area.global_position) > 3.0:
		return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * .8, area.global_position + Vector3.UP * .8, 1)
	return area.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _read_scene(area: Node3D, actor: Node) -> void:
	if not scene_readables.has(area) or not _valid_actor(area, actor):
		return
	var readable: Dictionary = scene_readables[area]
	var required := String(readable.get("required_flag", ""))
	if not required.is_empty() and not bool(world.run_state.get_choice_flag(required, false)):
		_say(Copy.copy("文字被闭合的机关遮住了。", "The closed mechanism covers the inscription."))
		return
	_say(String(readable.get("title", "")) + "\n" + String(readable.get("text", "")), 9.0)


func _read_clue(area: Node3D, actor: Node) -> void:
	if not _valid_interaction(area, actor):
		return
	var index := int(area.get_meta("stage_index"))
	if area != clue_areas[index]:
		return
	if index > completed_stage_count():
		_say(Copy.copy("上层碑记尚未接通。", "The upper record is not connected yet.") + "\n" + progress_hint())
		return
	var clue_key := stage_flag(index, "clue")
	if not bool(world.run_state.get_choice_flag(clue_key, false)):
		var was_started := bool(world.run_state.get_choice_flag(started_flag(), false))
		world.run_state.set_choice_flag(clue_key, true)
		world.run_state.set_choice_flag(started_flag(), true)
		if not bool(world._save_run("interior_clue")):
			world.run_state.choice_flags.erase(clue_key)
			if not was_started:
				world.run_state.choice_flags.erase(started_flag())
			return
		_refresh_prompts()
	# Successful rereading is observable too: optional scouting may be claimed
	# after the door was solved without reading, or retried after a failed save.
	progress_changed.emit(String(interior["id"]), completed_stage_count(), stages.size())
	_say(String(stages[index]["clue_text"]) + "\n" + progress_hint(), 9.0)


func _choose(area: Node3D, actor: Node) -> void:
	if not _valid_interaction(area, actor):
		return
	var index := int(area.get_meta("stage_index"))
	var option := int(area.get_meta("option_index", -1))
	if option not in range(3) or area != control_areas[index][option]:
		return
	if index != completed_stage_count():
		_say(Copy.copy("请按楼层顺序厘清遗事。", "Resolve the evidence in floor order.") + "\n" + progress_hint())
		return
	var read_status := bool(world.run_state.get_choice_flag(stage_flag(index, "clue"), false))
	if option != int(stages[index]["correct_index"]):
		_say(Copy.copy("印记没有接通。沿场景中的痕迹核对形状、方向与连接；也可阅读碑记。", "The seal does not connect. Compare the scene's shapes, directions and links; the inscription is optional.") + ("\n" + String(stages[index]["clue_text"]) if read_status else ""), 8.0)
		return
	if index == stages.size() - 1:
		var pressure := level_root.get_node_or_null("CampaignInteriorLoopRuntime")
		if pressure != null and pressure.has_method("top_guard_is_alive") and bool(pressure.top_guard_is_alive()):
			_say(Copy.copy("印记已经对应，但档室盾卫仍在守门。先击败盾卫，再开启封门。", "The seal matches, but the archive's shield guard still holds the door. Defeat the guard, then use this control."), 6.0)
			return
	var key := stage_flag(index, "solved")
	var final_stage := index == stages.size() - 1
	var was_started := bool(world.run_state.get_choice_flag(started_flag(), false))
	world.run_state.set_choice_flag(started_flag(), true)
	world.run_state.set_choice_flag(key, true)
	if final_stage:
		world.run_state.set_choice_flag(String(interior["completion_flag"]), true)
	if not bool(world._save_run("interior_stage_resolved")):
		world.run_state.choice_flags.erase(key)
		if not was_started:
			world.run_state.choice_flags.erase(started_flag())
		if final_stage:
			world.run_state.choice_flags.erase(String(interior["completion_flag"]))
		return
	_open_stage_door(index, true)
	_refresh_prompts()
	_say(progress_hint(), 5.0)
	progress_changed.emit(String(interior["id"]), completed_stage_count(), stages.size())
	puzzle_resolved.emit(String(interior["id"]), String(stages[index]["id"]), read_status, actor.global_position)
	if final_stage:
		completed.emit(String(interior["completion_flag"]))
	if is_instance_valid(world.audio):
		world.audio.play_cue("rest", -6.0, 1.0)


func _open_stage_door(index: int, animate: bool) -> void:
	var door := stage_doors[index]
	if bool(door.get_meta("open", false)):
		return
	door.set_meta("open", true)
	var visual := door.get_node("GateLeaf") as Node3D
	var height: float = stages[index]["door"]["size"].y
	if not animate:
		visual.scale.y = .02
		visual.position.y = height
		door.collision_layer = 0
		(door.get_node("GateCollision") as CollisionShape3D).disabled = true
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale:y", .02, .7)
	tween.tween_property(visual, "position:y", height, .7)
	tween.chain().tween_callback(func() -> void:
		if not is_instance_valid(door) or not is_instance_valid(level_root):
			return
		door.collision_layer = 0
		(door.get_node("GateCollision") as CollisionShape3D).set_deferred("disabled", true)
		if is_instance_valid(world) and world.campaign_runtime.current_level == level_root:
			world.request_navigation_refresh(level_root)
	)


func _refresh_prompts() -> void:
	var count := completed_stage_count()
	for index in clue_areas.size():
		clue_areas[index].prompt_text = Copy.copy("阅读", "Read") + " · " + String(stages[index].get("room_name", "碑记"))
		for option in 3:
			var area: Area3D = control_areas[index][option]
			area.prompt_text = "%s · %s" % [Copy.copy("选择", "Choose"), String(stages[index]["options"][option])]
			if index < count:
				area.prompt_text = Copy.copy("本层遗事已厘清", "This floor's evidence is resolved")
				var label := area.get_node("Inscription") as Label3D
				label.modulate = Color("a9cfaa") if option == int(stages[index]["correct_index"]) else Color("7f8986")


func _say(message: String, seconds: float = 4.5) -> void:
	if is_instance_valid(world.hud):
		world.hud.show_message(message, seconds)
