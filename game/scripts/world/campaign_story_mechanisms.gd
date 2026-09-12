class_name CampaignStoryMechanisms
extends Node3D
## Scene-owned field puzzles. Geometry, attempts and actors die with the level;
## only witnessed testimony and successfully completed objectives persist.

const StoryArt = preload("res://scripts/world/campaign_story_prop_renderer.gd")
const KitArt = preload("res://scripts/world/campaign_environment_renderer.gd")
const Interact = preload("res://scripts/world/samsara_fork_interact.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const Chapter3 = preload("res://scripts/data/chapter_3_content.gd")
const Chapter5 = preload("res://scripts/data/chapter_5_content.gd")
const Resolver = preload("res://scripts/core/real_model_resolver.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")
const Builder = preload("res://scripts/world/procedural_campaign_level_builder.gd")
const FORGERS := ["star_forger", "thought_breaker", "dust_returner", "fate_weaver", "gate_keeper", "sin_measurer", "lamp_lighter", "soul_pacifier", "cycle_turner"]
const FORGER_NAMES := ["铸星 / Star-Forger", "断念 / Thought-Breaker", "归尘 / Dust-Returner", "织命 / Fate-Weaver", "守门 / Gate-Keeper", "量罪 / Sin-Measurer", "点灯 / Lamp-Lighter", "安魂 / Soul-Pacifier", "转轮 / Cycle-Turner"]
const MEMORIAL_PARTS := ["MemorialStarForger", "MemorialThoughtBreaker", "MemorialDustReturner", "MemorialFateWeaver", "MemorialGateKeeper", "MemorialSinMeasurer", "MemorialLampLighter", "MemorialSoulPacifier", "MemorialCycleTurner"]
const TESTIMONY := [
	["我们以自身封住裂口，没有把众生献给永恒。", "We sealed the breach with ourselves, not with other souls."],
	["斩断执念，不等于抹去记忆。", "Letting go of obsession does not erase memory."],
	["回归不是消失，是把选择交还后来者。", "Returning leaves a choice for those who follow."],
	["命运可以相连，不该被一人织成牢笼。", "Fates may connect; no one should weave them into a prison."],
	["我守的是门，不是替人作答的权力。", "I guarded a gate, not the right to answer for others."],
	["代价必须由知道真相的人承担。", "Those who bear the cost must know the truth."],
	["火光应当指路，不能逼迫灵魂前行。", "A light should guide a soul, never compel it."],
	["灵魂有权停留，也有权离去。", "A soul has the right to remain and the right to leave."],
	["轮回曾经救人，也曾经伤人。新炉不能忘记任何一边。", "The cycle saved and harmed. A new furnace must remember both."],
]
const RIDDLES := [
	["逝去却不曾死去的是什么？", "What fades but never dies?", ["记忆 / Memory", "石头 / Stone", "火焰 / Flame"], 0],
	["赠予之后，双方都能拥有的是什么？", "What remains with both giver and receiver?", ["烬 / Ember", "信任 / Trust", "王座 / Throne"], 1],
	["路可以重复，谁应当决定下一步？", "When a path repeats, who should choose the next step?", ["守门人 / Keeper", "过去 / The past", "行路者 / The traveller"], 2],
]

class TrialWard extends StaticBody3D:
	var health := 90.0
	var controller: Node
	func receive_hit_payload(payload: Dictionary) -> void:
		if is_instance_valid(controller) and controller.trial_mode == "gate_keeper":
			health = maxf(0.0, health - maxf(0.0, float(payload.get("damage", 0.0))))
	func receive_hit(damage, _stagger, _direction, source) -> void:
		receive_hit_payload({"damage": damage, "source": source})
	func get_lock_point() -> Vector3:
		return global_position + Vector3.UP
	func can_be_targeted() -> bool:
		return health > 0.0

var world: Node
var player: CharacterBody3D
var level: Node3D
var run_state
var level_id := ""
var elapsed := 0.0
var progress := 0
var revision := 0
var attempt := 0
var complete := false
var maze_configuration := 0
var trial_mode := ""
var trial_remaining := 0.0
var trial_center := Vector3.ZERO
var trial_wave := 0
var _actors: Array[Node3D] = []
var _interactions: Dictionary = {}
var _barriers: Array[StaticBody3D] = []
var _maze_walls: Array[Array] = []
var _reflection_tiles: Array[Dictionary] = []
var _reflection_enemies: Array[Node3D] = []
var _reflection_processing: Dictionary = {}
var _reflection_revealed := false
var _reflection_stage := 0
var _reflection_reset_time := 0.0
var _procession: Node3D
var _procession_clock := 0.0
var _procession_cycle := 0
var _procession_seen := false
var _procession_followed := 0.0
var _lanterns: Array[Node3D] = []
var _maze_entered := false
var _anchors: Array[Node3D] = []
var _inverted := false
var _ward: TrialWard
var _trial_walls: Node3D
var _wave_wait := 0.0
var _frozen: Array[Dictionary] = []
var _tiles_suspended: Array[Dictionary] = []
var _silence_npc: Node3D
var _audio_volume := 0.0
var _audio_changed := false
var _ui_colors: Array[Dictionary] = []
var _dead := false
var _silence_cast_wait := 8.0
var _silence_cast_time := 0.0
var _silence_cast_health := 320.0
var _silence_lock_time := 0.0
var _silence_field_time := 0.0
var _silence_field_used := false


static func suppressed_modules(id: String) -> Array[StringName]:
	match id:
		"level_03_03": return [&"projectile_lane", &"illusion_marker", &"stealth_passage"]
		"level_03_04": return [&"moving_platform", &"illusion_marker", &"switch_offering"]
		"level_03_05": return [&"illusion_marker", &"switch_offering", &"riddle_gate"]
		"level_05_02": return [&"gravity_anchor", &"gravity_visual_zone", &"moving_platform", &"switch_offering"]
		"level_05_04": return [&"switch_offering", &"soul_forger_trial"]
	return []


static func final_battle_modifiers(state) -> Dictionary:
	var result := {"damage": 1.0, "stagger": 1.0, "guard": 1.0, "healing": 1.0, "stamina_regen": 1.0,
		"focus_regen": 1.0, "speed": 1.0, "poise_regen": 1.0, "damage_reduction": 1.0}
	var keys := ["damage", "focus_regen", "healing", "speed", "guard", "stagger", "poise_regen", "damage_reduction", "stamina_regen"]
	var values := [1.08, 1.12, 1.12, 1.05, .88, 1.10, 1.12, .92, 1.12]
	if state != null:
		for index in FORGERS.size():
			if bool(state.get_choice_flag("forger_blessing_" + FORGERS[index], false)):
				result[keys[index]] = values[index]
	return result


func setup(owner_world: Node, id: String) -> void:
	world = owner_world
	player = world.get("player") as CharacterBody3D
	run_state = world.get("run_state")
	level = get_parent() as Node3D
	level_id = id
	name = "StoryMechanisms"
	complete = _flag(_completion_key())
	if is_instance_valid(player):
		player.connect("died", _on_player_died)
	match id:
		"level_03_03": _build_procession()
		"level_03_04": _build_reflection()
		"level_03_05": _build_maze()
		"level_05_02": _build_inversion()
		"level_05_04": _build_memorial_trials()
		_: set_physics_process(false)
	_refresh_navigation()


func exit_block_reason() -> String:
	if suppressed_modules(level_id).is_empty() or complete:
		return ""
	match level_id:
		"level_03_03": return Copy.copy("跟随狐嫁队伍，并依序熄灭三盏引路灯。", "Follow the wedding and extinguish its three guiding lanterns in order.")
		"level_03_04": return Copy.copy("借镜中倒影走完湖上的真实道路。", "Use the reflection to traverse the lake's true path.")
		"level_03_05": return Copy.copy("解开三道路口谜题，走出移动迷宫。", "Answer the three riddles and leave the shifting maze.")
		"level_05_02": return Copy.copy("依序触动四个重力锚，使倒悬殿稳定。", "Activate the four gravity anchors in order to stabilize the sanctuary.")
		"level_05_04": return Copy.copy("先完成寂灭的门槛考验，或向他出示九位遗录。", "Pass Silence-Bringer's threshold trial or present the Nine Forgers' Records.")
	return ""


func snapshot() -> Dictionary:
	return {"level_id": level_id, "complete": complete, "progress": progress, "attempt": attempt,
		"revision": revision, "maze_configuration": maze_configuration, "reflection_revealed": _reflection_revealed,
		"reflection_stage": _reflection_stage, "procession_seen": _procession_seen, "followed_seconds": _procession_followed,
		"trial": trial_mode, "trial_remaining": trial_remaining, "trial_wave": trial_wave, "inverted": _inverted}


func _completion_key() -> String:
	return "silence_threshold_resolved" if level_id == "level_05_04" else "field_" + level_id.trim_prefix("level_") + "_complete"


func _flag(key: String) -> bool:
	return run_state != null and bool(run_state.get_choice_flag(key, false))


func _earn(key: String) -> void:
	if _flag(key): return
	run_state.set_choice_flag(key, true)
	if world.has_method("_save_run"): world.call("_save_run", "story_mechanism_" + key)


func _finish_objective() -> void:
	if complete: return
	complete = true
	_earn(_completion_key())
	_say("道路已经回应你的选择。", "The path has answered your choice.")


func _say(zh: String, en: String, duration := 3.0) -> void:
	var hud: Node = world.get("hud") if is_instance_valid(world) else null
	if is_instance_valid(hud) and hud.has_method("show_message"):
		hud.call("show_message", Copy.copy(zh, en), duration)


func _interaction(key: String, at: Vector3, zh: String, en: String) -> Node3D:
	var area = Interact.new()
	area.name = key
	area.position = at
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("interactable")
	area.prompt_text = Copy.copy(zh, en)
	area.world_callback = _on_interact.bind(key)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	collision.shape = sphere
	collision.position.y = .8
	area.add_child(collision)
	add_child(area)
	_interactions[key] = area
	return area


func _on_interact(area: Node, actor: Node, key: String) -> void:
	if actor != player or not is_instance_valid(player) or float(player.get("health")) <= 0.0 or not is_instance_valid(area): return
	if player.global_position.distance_to((area as Node3D).global_position) > 3.8: return
	if key.begins_with("lantern_"): _extinguish_lantern(int(key.trim_prefix("lantern_")))
	elif key == "reflection_mirror":
		_reflection_revealed = not _reflection_revealed
		_set_reflection_visibility()
		_say("倒影显出连通的石径；虚假的岸会沉下去。", "The reflection reveals connected stones; false shores give way.")
	elif key.begins_with("riddle_"):
		var bits := key.split("_")
		_answer_riddle(int(bits[1]), int(bits[2]))
	elif key.begins_with("anchor_"): _activate_anchor(int(key.trim_prefix("anchor_")))
	elif key.begins_with("testimony_"): _hear_forger(key.trim_prefix("testimony_"))
	elif key.begins_with("blessing_"): _select_blessing(key.trim_prefix("blessing_"))
	elif key.begins_with("trial_"): _start_trial(key.trim_prefix("trial_"), (area as Node3D).position)
	elif key == "silence_threshold": interact_silence(actor)


func _prop(part: String, at: Vector3, scale_value := Vector3.ONE) -> Node3D:
	var prop := StoryArt.instantiate_part(part)
	if prop == null:
		push_error("Required field mechanism art is missing: " + part)
		return Node3D.new()
	prop.position = at
	prop.scale = scale_value
	add_child(prop)
	return prop


func _platform(at: Vector3, size: Vector2, theme := "theme_jade_veil", ceiling := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	if ceiling: body.rotation.z = PI
	else:
		body.add_to_group("campaign_navigation_source")
		body.add_to_group("campaign_terrain_navigation_source")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, .6, size.y)
	collision.shape = shape
	collision.position.y = -.3
	body.add_child(collision)
	var visual := KitArt.instantiate_part(StringName(theme), "Floor")
	visual.scale = Vector3(size.x / 6., 1., size.y / 6.)
	body.add_child(visual)
	add_child(body)
	return body


func _wall(at: Vector3, width: float, height := 3.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("campaign_navigation_source")
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, .9)
	collision.shape = box
	collision.position.y = height * .5
	body.add_child(collision)
	var art := StoryArt.instantiate_part("HedgeWall" if level_id.begins_with("level_03") else "MuralWall")
	art.scale = Vector3(width / 6., height / (3. if level_id.begins_with("level_03") else 4.), .6)
	body.add_child(art)
	add_child(body)
	return body


func _enable_body(body: StaticBody3D, enabled: bool) -> void:
	body.visible = enabled
	for child in body.get_children():
		if child is CollisionShape3D: child.set_deferred("disabled", not enabled)
	if enabled: body.add_to_group("campaign_navigation_source")
	else: body.remove_from_group("campaign_navigation_source")


func _refresh_navigation() -> void:
	revision += 1
	if is_instance_valid(world) and world.has_method("request_navigation_refresh"):
		world.call("request_navigation_refresh", level)


func _supported(at: Vector3, radius := .65) -> Vector3:
	var navigation := level.get_node_or_null("NavigationSurface")
	if navigation == null: return at
	return Builder.supported_spawn(navigation.get_meta("walkable_cells", []), at + Vector3.UP * .05, radius, .05)


func _fill_floor(at: Vector3) -> void:
	if _has_floor_cell(at): return
	var floor_body := _platform(at, Vector2(6, 6), "theme_ember_abyss" if level_id.begins_with("level_05") else "theme_jade_veil")
	floor_body.set_meta("story_floor_cell", true)
	# Appending a floor changes an old exterior edge into an interior seam.
	# Open its physical rail and visible batch together only when both full
	# cells have real support; false reflection tiles never enter this helper.
	for direction: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var neighbor := at + direction * 6.
		if _has_floor_cell(neighbor): _open_rails_along(at, neighbor)


func _has_floor_cell(at: Vector3) -> bool:
	var geometry := level.get_node_or_null("Geometry")
	if geometry != null:
		for child in geometry.get_children():
			if child is StaticBody3D and String(child.name).begins_with("Tile_") and (child.position + Vector3.UP * .3).distance_to(at) < .1:
				return true
	for child in get_children():
		if child is StaticBody3D and bool(child.get_meta("story_floor_cell",false)) and child.position.distance_to(at) < .1:
			return true
	return false


func _open_rails_along(from: Vector3, to: Vector3) -> void:
	var modeled := level.get_node_or_null("Geometry/ModeledEnvironment")
	if modeled == null: return
	# Renderer emits one solid per rail in the same insertion order as every
	# rail-material batch. Open geometry and its exact visible instance together.
	var rails: Array[Node3D] = []
	for child in modeled.get_children():
		if child is StaticBody3D and String(child.get_meta("architecture_kind", "")) == "RailSolid": rails.append(child)
	for index in rails.size():
		var rail: Node3D = rails[index]
		if rail.has_meta("story_mechanism_open"): continue
		var nearest := Geometry3D.get_closest_point_to_segment(rail.position, from, to)
		if nearest.distance_to(rail.position) > .65: continue
		rail.set_meta("story_mechanism_open", true)
		_tiles_suspended.append({"body": weakref(rail), "groups": rail.get_groups()})
		rail.remove_from_group("campaign_navigation_source")
		rail.remove_from_group("campaign_terrain_navigation_source")
		for shape in rail.get_children():
			if shape is CollisionShape3D:
				_tiles_suspended.append({"shape": weakref(shape), "disabled": shape.disabled})
				shape.set_deferred("disabled", true)
		for batch in modeled.get_children():
			if batch is MultiMeshInstance3D and String(batch.get_meta("kit_part", "")) == "Rail":
				_tiles_suspended.append({"batch": weakref(batch), "index": index, "transform": rail.transform})
				batch.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), rail.position))


func _build_procession() -> void:
	_procession = Node3D.new()
	_procession.name = "MovingWedding"
	add_child(_procession)
	var carriage := StoryArt.instantiate_part("Palanquin")
	carriage.scale = Vector3.ONE * .7
	_procession.add_child(carriage)
	for index in 4:
		var bearer := StoryArt.instantiate_part("WeddingLantern")
		bearer.position = Vector3(-1.4 if index % 2 == 0 else 1.4, 0, -1.5 + floori(index / 2.) * 3.)
		bearer.scale = Vector3.ONE * .65
		_procession.add_child(bearer)
	for index in 3:
		var at := Vector3(30, 0, -54 - index * 12)
		_lanterns.append(_prop("WeddingLantern", at))
		_interaction("lantern_%d" % index, at + Vector3(0, 0, 1.6), "熄灭引路灯 %d" % (index + 1), "Extinguish guiding lantern %d" % (index + 1))
	_procession.position = Vector3(24, 0, -48)
	_say("跟在花轿后方，避开迎亲者的目光。引路灯从来路依次熄灭。", "Follow behind the palanquin, outside the bearers' gaze. Extinguish the lamps from the approach onward.", 5.)


func _tick_procession(delta: float) -> void:
	_procession_clock += delta
	var cycle_number := floori(_procession_clock / 70.)
	if cycle_number != _procession_cycle:
		_procession_cycle = cycle_number
		_procession_seen = false
		_procession_followed = 0.
		_clear_actors()
		if not complete:
			progress = 0
			for lantern in _lanterns: lantern.show()
	var cycle := fmod(_procession_clock, 70.)
	_procession.position = Vector3(24, 0, -48 - minf(cycle, 48.) * .75)
	if complete: return
	var offset := to_local(player.global_position) - _procession.position
	var in_front := offset.z < 1.5 and offset.z > -8.0 and absf(offset.x) < 3.0
	if in_front and not _procession_seen:
		_procession_seen = true
		progress = 0
		for lantern in _lanterns: lantern.show()
		_say("队伍发现了你。退到路旁，等待下一次迎亲。", "The procession saw you. Wait beside the road for its next passage.")
		_spawn_actor("wedding_gown_ghost", _supported(_procession.position + Vector3(-2, 0, -3)), "wedding", player)
	if offset.z >= 2. and offset.z <= 13. and absf(offset.x) <= 8. and not _procession_seen:
		_procession_followed += delta
	if not _procession_seen and _procession_followed >= 8. and progress == 3:
		_finish_objective()


func _extinguish_lantern(index: int) -> void:
	if complete: return
	if _procession_seen or _procession_followed < 2.:
		_say("先悄然跟上队伍，灯火才会听你。", "First follow the procession unseen; then the lamps will heed you.")
		return
	if index != progress:
		progress = 0
		for lantern in _lanterns: lantern.show()
		_say("次序错了，三盏灯重新亮起。", "The order was wrong. All three lamps relight.")
		return
	_lanterns[index].hide()
	progress += 1
	_say("引路灯熄灭：%d / 3" % progress, "Guiding lamps extinguished: %d / 3" % progress)


func _suspend_tile(at: Vector3) -> void:
	var geometry := level.get_node_or_null("Geometry")
	if geometry == null: return
	for node in geometry.get_children():
		if not node is StaticBody3D or not String(node.name).begins_with("Tile_"): continue
		if (node.position + Vector3.UP * .3).distance_to(at) > .1: continue
		_tiles_suspended.append({"body": weakref(node), "groups": node.get_groups()})
		for collision in node.get_children():
			if collision is CollisionShape3D:
				_tiles_suspended.append({"shape": weakref(collision), "disabled": collision.disabled})
				collision.set_deferred("disabled", true)
		node.remove_from_group("campaign_navigation_source")
		node.remove_from_group("campaign_terrain_navigation_source")
		var index := int(String(node.name).trim_prefix("Tile_"))
		for batch: Node in geometry.find_children("*", "MultiMeshInstance3D", true, false):
			if String(batch.get_meta("kit_part", "")) == "Floor" and index < batch.multimesh.instance_count:
				# Floor batches are authored in exactly the same cell order. Keep
				# the transform ourselves: headless RenderingServer getters omit it.
				_tiles_suspended.append({"batch": weakref(batch), "index": index, "transform": Transform3D(Basis.IDENTITY, at)})
				batch.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), at))


func _build_reflection() -> void:
	for x in [-24, -18, -12, -6]: _fill_floor(Vector3(x,0,-54))
	_open_rails_along(Vector3(-30,0,-54), Vector3(-6,0,-54))
	_open_rails_along(Vector3(-6,0,-54), Vector3(-6,0,-60))
	# The fifth true stone ends at Z=-87, before the original southern court.
	# Connect its single exit lane to that court, including the old boundary
	# rails on both sides of the gap. No false puzzle cell receives support.
	for z in [-90, -96, -102]: _fill_floor(Vector3(6,0,z))
	_open_rails_along(Vector3(6,0,-84), Vector3(6,0,-102))
	var lanes := [[0], [0, 1], [1], [1, 2], [2]]
	for row in 5:
		for column in 3:
			var at := Vector3(-6 + column * 6, 0, -60 - row * 6)
			_suspend_tile(at)
			var body := _platform(at, Vector2(6, 6))
			var solid: bool = lanes[row].has(column)
			body.set_meta("reflection_tile", row)
			body.set_meta("reflection_solid", solid)
			if not solid:
				for child in body.get_children():
					if child is CollisionShape3D: child.disabled = true
				body.remove_from_group("campaign_navigation_source")
				body.remove_from_group("campaign_terrain_navigation_source")
			_reflection_tiles.append({"body": body, "solid": solid, "row": row})
	_support_reflection_pavilion_feet()
	_prop("MemoryMirror", Vector3(-10, 0, -54), Vector3.ONE * .75)
	_interaction("reflection_mirror", Vector3(-10, 0, -52), "凝视镜中道路", "Read the reflected path")
	_bind_reflection_enemies()
	_set_reflection_visibility()


func _support_reflection_pavilion_feet() -> void:
	var scenery := level.get_node_or_null("CampaignStoryProps")
	if scenery == null: return
	var definition := StoryArt.get_part_definition("LakePavilion")
	for anchor in scenery.get_children():
		if not anchor.has_meta("story_placement") or String(anchor.get_meta("story_part_id", "")) != "LakePavilion": continue
		# These eight column boxes coincide with the imported feet, measured at
		# Y0 in jade_veil.glb. The roof's 10m AABB is deliberately not a deck.
		var columns: Array = definition["navigation_boxes"]
		for index in columns.size():
			var column: Dictionary = columns[index]
			var center: Array = column["center"]
			var size: Array = column["size"]
			var local_foot := Vector3(float(center[0]), 0, float(center[2]))
			var supported := true
			for x in [-1.,1.]:
				for z in [-1.,1.]:
					var corner := local_foot + Vector3(x*float(size[0])*.5,0,z*float(size[2])*.5)
					if not _true_reflection_support(to_local(anchor.to_global(corner))): supported = false
			if supported: continue
			var at := to_local(anchor.to_global(local_foot))
			var pier := _platform(at, Vector2(float(size[0])+.05,float(size[2])+.05))
			pier.name = "PavilionFooting_%d" % index
			pier.basis = global_basis.inverse() * anchor.global_basis
			pier.set_meta("story_structural_footing", "LakePavilion")
			pier.set_meta("column_index", index)


func _true_reflection_support(at: Vector3) -> bool:
	for tile in _reflection_tiles:
		if not bool(tile["solid"]): continue
		var body: Node3D = tile["body"]
		if absf(at.x-body.position.x) <= 3.001 and absf(at.z-body.position.z) <= 3.001:
			return true
	return false


func _bind_reflection_enemies() -> void:
	for enemy: Node in world.get("enemies"):
		if not is_instance_valid(enemy): continue
		if String(enemy.get("content_id")) == "water_moon_spirit":
			enemy.set_meta("story_damage_gate", Callable(self, "_reflection_damage_allowed"))
			_reflection_enemies.append(enemy)
			_reflection_processing[enemy.get_instance_id()] = enemy.is_physics_processing()
	if _reflection_enemies.size() != 3:
		push_error("The reflection course requires its three authored Water Moon spirits")


func _reflection_damage_allowed(_source: Variant = null) -> bool:
	if not is_instance_valid(player) or not _reflection_revealed: return false
	var hit := _floor_under_player()
	return not hit.is_empty() and bool((hit["collider"] as Node).get_meta("reflection_solid", false))


func _floor_under_player() -> Dictionary:
	var at := player.global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .25, at + Vector3.DOWN * .55, 1)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _set_reflection_visibility() -> void:
	for entry in _reflection_tiles:
		var body: Node3D = entry["body"]
		for child in body.get_children():
			if child is Node3D and not child is CollisionShape3D:
				child.visible = not _reflection_revealed or bool(entry["solid"])
	for enemy in _reflection_enemies:
		if is_instance_valid(enemy):
			enemy.visible = _reflection_revealed
			enemy.set_physics_process(_reflection_revealed and bool(_reflection_processing.get(enemy.get_instance_id(), true)))
			if not _reflection_revealed and is_instance_valid(enemy.get("combat_area")): enemy.get("combat_area").end_swing()


func _tick_reflection(delta: float) -> void:
	_reflection_reset_time = maxf(0.0, _reflection_reset_time - delta)
	var at := to_local(player.global_position)
	if absf(at.x) < 10. and at.z < -56. and at.z > -89. and at.y < -.7 and _reflection_reset_time <= 0.:
		_reflection_stage = 0
		player.global_position = to_global(Vector3(-6, .1, -54))
		player.velocity = Vector3.ZERO
		_reflection_reset_time = 1.0
		_say("假路沉入湖中。回到倒影所示的起点。", "The false path sank. Return to the beginning shown in the reflection.")
		return
	if not _reflection_revealed or complete: return
	var hit := _floor_under_player()
	if hit.is_empty(): return
	var collider: Node = hit["collider"]
	if not bool(collider.get_meta("reflection_solid", false)): return
	var row := int(collider.get_meta("reflection_tile", -1))
	if row == _reflection_stage:
		_reflection_stage += 1
		progress = _reflection_stage
		if _reflection_stage == 5: _finish_objective()


func _build_maze() -> void:
	for z in [-36, -42, -48, -54, -60, -66, -72]:
		for x in [-6, 0, 6]: _fill_floor(Vector3(x, 0, z))
	# All three last-gate lanes meet on the final court. Continue through a
	# single supported exit to the original southern route instead of a void.
	for z in [-78,-84,-90,-96]: _fill_floor(Vector3(0,0,z))
	for z in [-36, -42, -48, -54, -60, -66, -72]:
		for side in [-1, 1]:
			var boundary := _wall(Vector3(side * 9.5, 0, z), 6.)
			boundary.rotation.y = PI * .5
	for row in 3:
		var walls: Array = []
		for column in 3:
			walls.append(_wall(Vector3(-6 + column * 6, 0, -42 - row * 12), 6.0))
			var riddle: Array = RIDDLES[row]
			_interaction("riddle_%d_%d" % [row, column], Vector3(-5 + column * 5, 0, -37 - row * 12),
				String(riddle[0]) + " " + String(riddle[2][column]), String(riddle[1]) + " " + String(riddle[2][column]))
		_maze_walls.append(walls)
	progress = 3 if complete else 0
	_apply_maze_configuration()


func maze_open_lanes(configuration: int) -> Array[int]:
	return [configuration % 3, int(configuration / 3.) % 3, (configuration + 1) % 3]


func _apply_maze_configuration() -> void:
	var lanes := maze_open_lanes(maze_configuration)
	for row in _maze_walls.size():
		for column in 3: _enable_body(_maze_walls[row][column], not (row < progress and column == lanes[row]))
	_refresh_navigation()


func _answer_riddle(row: int, answer: int) -> void:
	if complete or row != progress: return
	if answer == int(RIDDLES[row][3]):
		progress += 1
		_apply_maze_configuration()
		_say("玉藤让开一条路。", "The jade vines part to reveal a route.")
	else:
		attempt += 1
		maze_configuration = (maze_configuration + 1) % 9
		progress = 0
		player.global_position = to_global(Vector3(0, .1, -33))
		player.velocity = Vector3.ZERO
		_apply_maze_configuration()
		_clear_actors()
		_spawn_actor("mind_lost_fox_demon", Vector3(-6, .05, -36), "maze", player)
		_say("错误的答案使玉藤移位。敌影归来；正确的道路仍然连通。", "The wrong answer shifts the vines. A foe returns; a solvable route remains.")


func _tick_maze() -> void:
	var at := to_local(player.global_position)
	if not _maze_entered and absf(at.x) <= 9. and at.z < -31.:
		_maze_entered = true
		var facing := player.get("body_yaw") as Node3D
		var yaw := facing.global_rotation.y if is_instance_valid(facing) else player.global_rotation.y
		maze_configuration = posmod(int(floor((yaw + PI) / (TAU / 9.))), 9)
		_apply_maze_configuration()
	if progress == 3 and at.z < -69. and absf(at.x) < 9.:
		_finish_objective()


func _build_inversion() -> void:
	for x in [-12, -6, 0, 6, 12]:
		for z in [-108, -114, -120, -126, -132]: _platform(Vector3(x, 16, z), Vector2(6, 6), "theme_ember_abyss", true)
	var positions := [Vector3(-12,8,-108), Vector3(-12,16,-120), Vector3(12,16,-120), Vector3(12,8,-132)]
	for index in positions.size():
		var anchor := _prop("Orrery", positions[index], Vector3.ONE * .32)
		if index in [1, 2]: anchor.rotation.z = PI
		_anchors.append(anchor)
		var interact_at: Vector3 = positions[index] + (Vector3.DOWN if index in [1,2] else Vector3.UP) * .7
		_interaction("anchor_%d" % index, interact_at, "触动重力锚 %d" % (index + 1), "Touch gravity anchor %d" % (index + 1))
	_say("四印依序：升、守、归、定。第二、第三印在你的头顶。", "Four seals in order: rise, hold, return, settle. The second and third are above you.", 5.)


func _activate_anchor(index: int) -> void:
	if complete: return
	if index != progress:
		reset_attempt()
		_say("次序不合。重力回归，四印重置。", "The sequence broke. Gravity returns and the four seals reset.")
		return
	progress += 1
	if index == 0: _set_inverted(true)
	elif index == 2: _set_inverted(false)
	elif index == 3:
		_set_inverted(false)
		_finish_objective()
	_say("重力锚：%d / 4" % progress, "Gravity anchors: %d / 4" % progress)


func _set_inverted(value: bool) -> void:
	_inverted = value
	if is_instance_valid(player):
		player.call("set_traversal_up", Vector3.DOWN if value else Vector3.UP)


func _build_memorial_trials() -> void:
	var scenery := level.get_node_or_null("CampaignStoryProps")
	for index in FORGERS.size():
		var at := Vector3(-30, 0, -42 - index * 6)
		if scenery != null:
			for anchor in scenery.get_children():
				if String(anchor.get_meta("story_part_id", "")) == MEMORIAL_PARTS[index]:
					at = anchor.position + (Vector3(0, 0, -72) - anchor.position).normalized() * 3.2
		at = _supported(at)
		_interaction("testimony_" + FORGERS[index], at, "聆听 " + FORGER_NAMES[index], "Hear " + FORGER_NAMES[index])
		_interaction("blessing_" + FORGERS[index], at + Vector3(1.5, 0, 0), "选择祝福 " + FORGER_NAMES[index], "Choose blessing " + FORGER_NAMES[index])
	for index in 3:
		var id: String = ["star_forger", "thought_breaker", "gate_keeper"][index]
		var at := Vector3(-54, 0, -48 - index * 24)
		# Dedicated side courts avoid the nine memorials and the central route.
		for x in [-6, 0, 6]:
			for z in [-6, 0, 6]: _fill_floor(at + Vector3(x, 0, z))
		var entry_z := at.z + (6. if index == 1 else 0.)
		for x in [-42, -36]: _fill_floor(Vector3(x, 0, entry_z))
		_open_rails_along(Vector3(-30,0,entry_z),Vector3(-54,0,entry_z))
		_prop("WatchBrazier", at + Vector3(-2,0,0), Vector3.ONE * .45)
		_interaction("trial_" + id, at, ["铸星：限时击败残影", "断念：禁用治疗的考验", "守门：守住三波来袭"][index],
			["Star-Forger: defeat the remnant before time runs out", "Thought-Breaker: win without healing", "Gate-Keeper: defend against three waves"][index])
	_interaction("silence_threshold", _supported(Vector3(5,0,-125)), "接受寂灭的门槛考验 / 出示九位遗录", "Face Silence-Bringer / Present the Nine Records")
	for x in [-6, 0, 6, 12, 18]:
		for z in [-114, -120, -126, -132, -138]: _fill_floor(Vector3(x, 0, z))


func _hear_forger(id: String) -> void:
	var index := FORGERS.find(id)
	if index < 0: return
	_say(FORGER_NAMES[index] + "：" + TESTIMONY[index][0], FORGER_NAMES[index] + ": " + TESTIMONY[index][1], 6.)
	_earn("forger_testimony_" + id)
	var all_heard := true
	for forger: String in FORGERS: all_heard = all_heard and _flag("forger_testimony_" + forger)
	if all_heard and int(run_state.inventory.get("soul_forger_records", 0)) == 0:
		run_state.inventory["soul_forger_records"] = 1
		_earn("nine_records_complete")
		_say("九位遗录已经完整。寂灭会听你陈述；可携带五份祝福。", "The Nine Records are complete. Silence-Bringer will hear you; five blessings may now accompany you.", 5.)


func _select_blessing(id: String) -> void:
	if not _flag("forger_testimony_" + id):
		_say("先听完这位铸魂者的证词。", "First hear this forger's testimony.")
		return
	if id in ["star_forger", "thought_breaker", "gate_keeper"] and not _flag("trial_" + id):
		_say("这份祝福需要完成对应的试炼。", "This blessing requires its corresponding trial.")
		return
	var chosen := 0
	for forger: String in FORGERS:
		if _flag("forger_blessing_" + forger): chosen += 1
	var key := "forger_blessing_" + id
	if _flag(key):
		run_state.set_choice_flag(key, false)
		world.call("_save_run", "blessing_released")
		_say("暂时放下这份祝福。", "You set this blessing aside.")
	elif chosen < (5 if _flag("nine_records_complete") else 3):
		_earn(key)
		_say("祝福将伴你迎战烛阴。", "This blessing will accompany you against Zhu Yin.")
	else:
		_say("祝福已满；再次触碰已选之印可以放下它。", "Your blessings are full. Touch a selected seal again to release it.")


func interact_silence(actor: Node) -> bool:
	if level_id != "level_05_04" or actor != player: return false
	var threshold: Node3D = _interactions.get("silence_threshold")
	if not is_instance_valid(player) or float(player.get("health")) <= 0. or threshold == null: return true
	var nearby := player.global_position.distance_to(threshold.global_position) <= 3.8
	for npc in get_tree().get_nodes_in_group("interactable"):
		if "npc_id" in npc and String(npc.get("npc_id")) == "npc_silence_bringer":
			nearby = nearby or player.global_position.distance_to(npc.global_position) <= 3.8
	if not nearby: return true
	if complete:
		_earn("npc_silence_bringer_met")
		_say("寂灭：门已经打开。选择的代价由你见证。", "Silence-Bringer: the threshold is open. Witness the cost of your choice.")
		return true
	if not trial_mode.is_empty(): return true
	if int(run_state.inventory.get("soul_forger_records", 0)) > 0:
		run_state.set_choice_flag("silence_threshold_method", "testimony")
		_earn("npc_silence_bringer_met")
		_finish_objective()
		_say("寂灭：九位的声音，你都听见了。去证明第三条路吧。", "Silence-Bringer: you heard all nine. Go prove that a third path is possible.", 5.)
	else:
		_start_trial("silence", _supported(Vector3(5,0,-125)))
	return true


func _spawn_actor(content_id: String, at: Vector3, role: String, target: Node3D) -> Node3D:
	var content: Dictionary = {}
	for item: Dictionary in Chapter3.enemies() + Chapter5.enemies():
		if String(item["id"]) == content_id: content = item.duplicate(true)
	if content.is_empty(): return null
	content["reward"] = 0
	if role in ["star_forger", "thought_breaker", "gate_keeper", "silence"]:
		content["behavior"] = "defensive_hold"
		content["can_grab"] = false
		content["max_health"] = 90. if role == "star_forger" else 120.
		content["attack"] = {"windup": .9, "active": .22, "recovery": .85, "damage": 16., "stagger": 20., "lunge": 1.}
	if role == "gate_keeper":
		content["max_health"] = 36.
		content["attack"]["damage"] = 9.
	if role == "silence":
		content["display_name"] = "寂灭 / Silence-Bringer"
		content["max_health"] = 320.
		content["move_speed"] = 3.8
		content["attack_range"] = 2.1
		content["attack"] = {"windup": 3., "active": .15, "recovery": 1.1, "damage": 38., "stagger": 32., "lunge": .8}
		content["body_radius"] = .5
		content["body_height"] = 2.
		content["body_y"] = 1.
	var enemy = EnemyScript.new()
	enemy.name = "StoryTrial_" + role
	enemy.set_meta("story_trial_owned", true)
	enemy.setup_from_content(world, target, world.get("audio"), to_global(at), content, false)
	add_child(enemy)
	enemy.global_position = to_global(at)
	enemy.spawn_origin = enemy.global_position
	enemy.reward = 0
	enemy.leash_range = 100.
	enemy.disengage_range = 100.
	enemy.aggro_range = 30.
	if role == "silence":
		enemy.set_meta("story_nonlethal_floor", 32.)
		for child in enemy.body_visual_root.get_children():
			enemy.body_visual_root.remove_child(child)
			child.queue_free()
		Resolver.try_instance("npc/npc_silence_bringer", enemy.body_visual_root)
		enemy.weapon_pivot.hide() # The authored NPC carries the long staff.
		enemy.health_changed.connect(_silence_health_changed)
	enemy.defeated.connect(_on_actor_defeated.bind(role))
	_actors.append(enemy)
	var candidates: Array = world.get("enemies")
	candidates.append(enemy)
	return enemy


func _start_trial(id: String, at: Vector3) -> void:
	if not trial_mode.is_empty() or _flag("trial_" + id): return
	trial_mode = id
	trial_center = at
	trial_remaining = 45. if id == "star_forger" else 90.
	trial_wave = 0
	_clear_actors()
	player.call("set_story_healing_locked", id == "thought_breaker")
	_trial_walls = Node3D.new()
	_trial_walls.name = "TrialBoundary"
	add_child(_trial_walls)
	for index in 16:
		var angle := TAU * index / 16.
		var barrier := _wall(at + Vector3(cos(angle)*8.5, 0, sin(angle)*8.5), 3.6, 3.)
		barrier.rotation.y = -angle - PI*.5
		barrier.reparent(_trial_walls, true)
	_freeze_outside_enemies()
	if id == "gate_keeper":
		_ward = TrialWard.new()
		_ward.controller = self
		_ward.position = at
		_ward.collision_layer = 2
		_ward.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = .65
		cylinder.height = 1.8
		shape.shape = cylinder
		shape.position.y = .9
		_ward.add_child(shape)
		var visual := StoryArt.instantiate_part("WatchBrazier")
		visual.scale = Vector3.ONE * .5
		_ward.add_child(visual)
		add_child(_ward)
		_next_wave()
	else:
		_spawn_actor("soul_forger_remnant", at + Vector3(0,.05,-5), id, player)
	if id == "silence":
		_silence_cast_wait = 8.
		_silence_field_used = false
		for npc in get_tree().get_nodes_in_group("interactable"):
			if "npc_id" in npc and String(npc.get("npc_id")) == "npc_silence_bringer":
				_silence_npc = npc
				npc.hide()
		_audio_volume = AudioServer.get_bus_volume_db(0)
		_audio_changed = true
		AudioServer.set_bus_volume_db(0, _audio_volume - 12.)
	_say("试炼开始。离开试炼场或倒下会重置本次挑战。", "The trial begins. Leaving the field or falling resets this attempt.")
	_refresh_navigation()


func _next_wave() -> void:
	trial_wave += 1
	for side in [-1, 1]:
		_spawn_actor("soul_forger_remnant", trial_center + Vector3(side*5,.05,-3), "gate_keeper", _ward)
	_say("守门：第 %d / 3 波。守住炉火。" % trial_wave, "Gate-Keeper: wave %d / 3. Protect the flame." % trial_wave)


func _on_actor_defeated(enemy: Node3D, _reward: int, _guardian: bool, role: String) -> void:
	_actors.erase(enemy)
	var candidates: Array = world.get("enemies")
	candidates.erase(enemy)
	enemy.queue_free()
	if role != trial_mode: return
	if role == "gate_keeper":
		if _actors.is_empty():
			if trial_wave == 3 and is_instance_valid(_ward) and _ward.health > 0.: _win_trial()
			else: _wave_wait = 2.5
	elif role in ["star_forger", "thought_breaker"]: _win_trial()


func _silence_health_changed(current: float, maximum: float) -> void:
	if trial_mode != "silence": return
	if _silence_cast_time > 0. and current < _silence_cast_health:
		_silence_cast_time = 0.
		for actor in _actors:
			if is_instance_valid(actor):
				actor.set_physics_process(true)
				actor.call("_change_state", EnemyScript.State.RECOVERY, .6)
		_say("寂灭的吟唱被打断。", "Silence-Bringer's incantation was interrupted.")
	if current <= maximum * .1 + .001:
		run_state.set_choice_flag("silence_threshold_method", "combat")
		_earn("npc_silence_bringer_met")
		_finish_objective()
		_cleanup_trial()
		_say("寂灭收起长杖：你已经证明了决心。最后一步，由你选择。", "Silence-Bringer lowers his staff: you have proved your resolve. Choose your final step.", 5.)
	elif current <= maximum * .25 and not _silence_field_used:
		_silence_field_used = true
		_silence_field_time = 20.
		AudioServer.set_bus_volume_db(0, _audio_volume - 40.)
		var hud: Node = world.get("hud")
		if is_instance_valid(hud):
			for control in hud.get_children():
				if control is Control:
					_ui_colors.append({"node": weakref(control), "color": control.modulate})
					control.modulate = control.modulate * Color(.3, .3, .4, 1.)


func _tick_silence(delta: float) -> void:
	if _silence_lock_time > 0.:
		_silence_lock_time = maxf(0., _silence_lock_time - delta)
		if _silence_lock_time == 0. and player.has_method("set_story_cast_locked"): player.call("set_story_cast_locked", false)
	if _silence_field_time > 0.:
		_silence_field_time = maxf(0., _silence_field_time - delta)
		if _silence_field_time == 0.:
			_restore_ui_colors()
			AudioServer.set_bus_volume_db(0, _audio_volume - 12.)
	if _actors.is_empty() or not is_instance_valid(_actors[0]): return
	var actor = _actors[0]
	if _silence_cast_time > 0.:
		_silence_cast_time = maxf(0., _silence_cast_time - delta)
		if _silence_cast_time == 0.:
			actor.set_physics_process(true)
			actor.call("_change_state", EnemyScript.State.RECOVERY, .6)
			if actor.global_position.distance_to(player.global_position) <= 8. and player.has_method("set_story_cast_locked"):
				_silence_lock_time = 10.
				player.call("set_story_cast_locked", true)
				_say("寂灭封住术法十息；刀剑仍能作答。", "Silence seals spells for ten seconds; your weapon can still answer.")
		return
	_silence_cast_wait -= delta
	if _silence_cast_wait <= 0. and int(actor.get("state")) in [EnemyScript.State.IDLE, EnemyScript.State.CHASE, EnemyScript.State.RECOVERY]:
		_silence_cast_wait = 12.
		_silence_cast_time = 1.2
		_silence_cast_health = float(actor.get("health"))
		actor.get("combat_area").end_swing()
		actor.call("_change_state", EnemyScript.State.WINDUP, 1.2)
		actor.set_physics_process(false)
		_say("寂灭正在结印——攻击可打断，退到远处可避开。", "Silence-Bringer prepares a seal—strike to interrupt, or retreat beyond it.", 1.3)


func _restore_ui_colors() -> void:
	for entry in _ui_colors:
		var control: Control = entry["node"].get_ref()
		if is_instance_valid(control): control.modulate = entry["color"]
	_ui_colors.clear()


func _win_trial() -> void:
	var id := trial_mode
	_cleanup_trial()
	_earn("trial_" + id)
	_say("试炼完成。对应的铸魂者祝福已经可选。", "Trial complete. This forger's blessing can now be chosen.")


func _freeze_outside_enemies() -> void:
	for enemy: Node in world.get("enemies"):
		if not is_instance_valid(enemy) or enemy in _actors: continue
		_frozen.append({"node": weakref(enemy), "processing": enemy.is_physics_processing()})
		enemy.set_physics_process(false)
		if is_instance_valid(enemy.get("combat_area")): enemy.get("combat_area").end_swing()


func _clear_actors() -> void:
	for enemy in _actors:
		if not is_instance_valid(enemy): continue
		if is_instance_valid(world):
			var candidates: Array = world.get("enemies")
			candidates.erase(enemy)
		enemy.queue_free()
	_actors.clear()


func _cleanup_trial() -> void:
	trial_mode = ""
	_wave_wait = 0.
	if level_id != "level_03_04": _clear_actors()
	if is_instance_valid(_ward): _ward.queue_free()
	_ward = null
	if is_instance_valid(_trial_walls): _trial_walls.queue_free()
	_trial_walls = null
	if is_instance_valid(player): player.call("set_story_healing_locked", false)
	if is_instance_valid(player) and player.has_method("set_story_cast_locked"): player.call("set_story_cast_locked", false)
	_silence_cast_time = 0.
	_silence_lock_time = 0.
	_silence_field_time = 0.
	_restore_ui_colors()
	for entry in _frozen:
		var enemy: Node = entry["node"].get_ref()
		if is_instance_valid(enemy): enemy.set_physics_process(bool(entry["processing"]))
	_frozen.clear()
	if is_instance_valid(_silence_npc): _silence_npc.show()
	if _audio_changed:
		AudioServer.set_bus_volume_db(0, _audio_volume)
		_audio_changed = false
	_refresh_navigation()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	if _dead:
		if float(player.get("health")) <= 0.: return
		_dead = false
	elapsed += delta
	match level_id:
		"level_03_03": _tick_procession(delta)
		"level_03_04": _tick_reflection(delta)
		"level_03_05": _tick_maze()
		"level_05_02":
			var at := to_local(player.global_position)
			if _inverted and (at.x < -16. or at.x > 16. or at.z > -104. or at.z < -136.): reset_attempt()
	if not trial_mode.is_empty():
		if trial_mode == "silence": _tick_silence(delta)
		trial_remaining -= delta
		var at := to_local(player.global_position) - trial_center
		if trial_remaining <= 0. or Vector2(at.x, at.z).length() > 10.5 or (is_instance_valid(_ward) and _ward.health <= 0.):
			reset_attempt()
			_say("这次试炼没有完成。整理行装后可以重试。", "This attempt was not completed. Prepare and try again.")
		elif _wave_wait > 0.:
			_wave_wait -= delta
			if _wave_wait <= 0.: _next_wave()


func reset_attempt() -> void:
	attempt += 1
	_cleanup_trial()
	if level_id == "level_05_02":
		_set_inverted(false)
		if not complete: progress = 0
		if is_instance_valid(player) and float(player.get("health")) > 0.:
			player.global_position = to_global(Vector3(-12,8.05,-108))
			player.velocity = Vector3.ZERO
	elif level_id == "level_03_03":
		_procession_seen = false
		_procession_followed = 0.
		_procession_clock = 0.
		_procession_cycle = 0
		for lantern in _lanterns: lantern.show()
		if not complete: progress = 0
	elif level_id == "level_03_04": _reflection_stage = 0
	elif level_id == "level_03_05" and not complete:
		progress = 0
		_maze_entered = false
		_apply_maze_configuration()


func _on_player_died(_position: Vector3) -> void:
	_dead = true
	reset_attempt()


func _exit_tree() -> void:
	_cleanup_trial()
	_clear_actors()
	if is_instance_valid(player):
		if _inverted: player.call("clear_traversal_up")
		if player.is_connected("died", _on_player_died): player.disconnect("died", _on_player_died)
	for entry in _tiles_suspended:
		if entry.has("shape"):
			var shape: CollisionShape3D = entry["shape"].get_ref()
			if is_instance_valid(shape): shape.set_deferred("disabled", entry["disabled"])
		elif entry.has("body"):
			var body: Node = entry["body"].get_ref()
			if is_instance_valid(body):
				if body.has_meta("story_mechanism_open"): body.remove_meta("story_mechanism_open")
				for group: StringName in entry["groups"]: body.add_to_group(group)
		elif entry.has("batch"):
			var batch: MultiMeshInstance3D = entry["batch"].get_ref()
			if is_instance_valid(batch): batch.multimesh.set_instance_transform(entry["index"], entry["transform"])
	for enemy in _reflection_enemies:
		if is_instance_valid(enemy):
			enemy.remove_meta("story_damage_gate")
			enemy.show()
			enemy.set_physics_process(bool(_reflection_processing.get(enemy.get_instance_id(), true)))
