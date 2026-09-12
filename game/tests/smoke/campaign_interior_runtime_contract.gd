extends SceneTree
## Ordered investigation callbacks, production player sensor/input, physical
## doors and save serialization. Three-floor fixture uses inspection placement;
## campaign_interior traversal acceptance is a separate locomotion contract.
const Interior = preload("res://scripts/world/campaign_interior_runtime.gd")
const Expansion = preload("res://scripts/world/campaign_expansion_runtime.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const LevelRuntime = preload("res://scripts/world/campaign_level_runtime.gd")
const RunState = preload("res://scripts/core/run_state.gd")
const InputConfig = preload("res://scripts/core/input_config.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	var saved_snapshot: Dictionary = {}
	var save_calls := 0
	var fail_next_save := false
	var navigation_requests := 0
	func _ready() -> void:
		set_process(false)
	func _save_run(_reason: String) -> bool:
		save_calls += 1
		if fail_next_save:
			fail_next_save = false
			return false
		run_state.embers = int(player.embers)
		saved_snapshot = run_state.to_dictionary()
		return true
	func request_navigation_refresh(_level_root: Node3D) -> void:
		navigation_requests += 1

class AuditHud extends Node:
	var messages: Array[String] = []
	var prompt := ""
	func show_message(message: String, _duration: float) -> void:
		messages.append(message)
	func set_prompt(message: String) -> void:
		prompt = message

class AuditAudio extends Node:
	var cue_count := 0
	func play_cue(_cue: String, _volume: float, _pitch: float) -> void:
		cue_count += 1

var world: AuditWorld
var level: Node3D
var interior: Node3D
var expansion: Node3D
var plan: Dictionary
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfig.configure_inputs()
	world = AuditWorld.new()
	world.run_state = RunState.new()
	world.position = Vector3(13, 2, -5)
	world.rotation.y = .2
	root.add_child(world)
	world.hud = AuditHud.new()
	world.audio = AuditAudio.new()
	world.add_child(world.hud)
	world.add_child(world.audio)
	world.player = PlayerScene.instantiate()
	world.add_child(world.player)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world._create_interaction_sensor()
	world.campaign_runtime = LevelRuntime.new()
	world.add_child(world.campaign_runtime)
	plan = _fixture_plan()
	_build_level()
	await _frames(4)
	_expect(interior.stage_doors.size() == 3 and interior.clue_areas.size() == 3 and interior.control_areas.size() == 3, "Three floors each have their own clue, three physical choices and staged door")
	interior.setup(world, level, plan)
	_expect(interior.stage_doors.size() == 3, "Repeated setup cannot duplicate room doors or controls")
	for index in 3:
		_expect(_door_blocks(index), "Unsolved door physically blocks floor " + str(index + 1))
		var expected: Vector3 = level.to_global(plan["stages"][index]["clue_position"])
		_expect(interior.clue_areas[index].global_position.distance_to(expected) < .001, "Clue respects translated/rotated level frame " + str(index + 1))
	var cache: Area3D = expansion.reward_areas["sealed_archive"]
	await _inspect(cache)
	cache.interact(world.player)
	_expect(world.player.embers == 0 and world.save_calls == 0, "Teleporting to the top reward cannot bypass the required completion flag")
	_expect(not cache.get_prompt().contains("Gather"), "Sealed reward exposes investigation progress instead of an unlocked pickup prompt")
	await _inspect(interior.clue_areas[2])
	interior.clue_areas[2].interact(world.player)
	_expect(not _flag(2, "clue") and interior.completed_stage_count() == 0, "Upper-floor clue cannot be read before lower floors are solved")
	await _inspect(_correct(2))
	_correct(2).interact(world.player)
	_expect(not _flag(2, "solved"), "Upper-first choice cannot advance the investigation")
	_correct(0).interact(world.player)
	_expect(interior.completed_stage_count() == 0 and world.save_calls == 0, "Remote correct callback cannot solve a distant lower floor")
	await _inspect(_correct(0))
	var stranger := Node3D.new()
	world.add_child(stranger)
	stranger.global_position = world.player.global_position
	_correct(0).interact(stranger)
	stranger.free()
	_expect(world.save_calls == 0, "Another actor cannot operate the player's investigation controls")
	await _inspect(interior.control_areas[0][0])
	interior.control_areas[0][0].interact(world.player)
	_expect(not _flag(0, "solved") and not _flag(0, "clue"), "An unread incorrect physical choice remains incorrect without forcing a reading flag")
	await _inspect(interior.clue_areas[0])
	world.fail_next_save = true
	interior.clue_areas[0].interact(world.player)
	_expect(not _flag(0, "clue") and not bool(world.run_state.get_choice_flag(interior.started_flag(), false)), "Failed clue save cannot create a half-started investigation")
	await _input(interior.clue_areas[0])
	_expect(_flag(0, "clue") and bool(world.run_state.get_choice_flag(interior.started_flag(), false)), "Production sensor and input read the ground clue and start the side investigation")
	var before_wrong := world.save_calls
	await _inspect(interior.control_areas[0][0])
	interior.control_areas[0][0].interact(world.player)
	_expect(not _flag(0, "solved") and world.save_calls == before_wrong, "A wrong evidence choice leaves the room locked and writes no progress")
	_expect(world.hud.messages.back().contains(String(plan["stages"][0]["clue_text"])), "Wrong choice supplies the room's readable clue as a hint")
	# This nearby position is behind the door plane, within the callback's
	# distance limit, so the explicit approach-side guard is exercised.
	var control_position: Vector3 = plan["stages"][0]["controls_positions"][1]
	world.player.global_position = level.to_global(Vector3(control_position.x, 0, -.4))
	_correct(0).interact(world.player)
	_expect(not _flag(0, "solved"), "Correct control refuses operation from the wrong side of its room gate")
	await _inspect(_correct(0))
	world.fail_next_save = true
	_correct(0).interact(world.player)
	await _frames(3)
	_expect(not _flag(0, "solved") and _door_blocks(0), "Failed stage save retains its real closed door and solved guard")
	await _input(_correct(0))
	await _frames(50)
	_expect(interior.completed_stage_count() == 1 and not _door_blocks(0) and _door_blocks(1), "Solving ground evidence opens only the next-floor gate")
	_expect(world.navigation_requests == 1, "Physical door opening requests one navigation refresh")
	var after_ground := world.save_calls
	_correct(0).interact(world.player)
	_expect(world.save_calls == after_ground and interior.completed_stage_count() == 1, "Repeated solved control cannot advance or save twice")
	await _inspect(interior.clue_areas[1])
	# A nearby clue far to the side of the doorway remains readable from either
	# adjacent room approach; the gate plane must not extend across the gallery.
	world.player.global_position = level.to_global((plan["stages"][1]["clue_position"] as Vector3) + Vector3(0, 0, -1.2))
	await _frames(3)
	await _input(interior.clue_areas[1])
	_expect(_flag(1, "clue"), "Second-floor clue is readable beside the doorway from a nearby opposite-plane approach")
	world.player.health = 0
	await _inspect(_correct(1))
	_correct(1).interact(world.player)
	_expect(not _flag(1, "solved"), "A dead player cannot solve the next room")
	world.player.respawn_at(world.player.global_position)
	_expect(_flag(0, "solved") and _flag(1, "clue"), "Production player respawn preserves solved doors and remembered clues")
	var mid_save: Dictionary = world.saved_snapshot.duplicate(true)
	var obsolete_clue: WeakRef = weakref(interior.clue_areas[1])
	await _reload(mid_save)
	_expect(obsolete_clue.get_ref() == null, "Unload removes obsolete floor interaction callbacks and visuals")
	_expect(interior.completed_stage_count() == 1 and _flag(1, "clue"), "Real save schema restores lower completion and current clue reading")
	_expect(not _door_blocks(0) and _door_blocks(1) and _door_blocks(2), "Reload restores precisely the solved physical gates")
	await _inspect(_correct(2))
	_correct(2).interact(world.player)
	_expect(interior.completed_stage_count() == 1, "Reload does not permit skipping the second floor")
	await _inspect(_correct(1))
	await _input(_correct(1))
	await _frames(50)
	_expect(interior.completed_stage_count() == 2 and not _door_blocks(1), "Persisted second-floor clue supports its correct physical choice after reload")
	await _inspect(_correct(2))
	_correct(2).interact(world.player)
	_expect(_flag(2, "solved") and _complete() and not _flag(2, "clue"), "Scene-based correct choice resolves the top floor without reading its optional inscription")
	await _inspect(interior.clue_areas[2])
	await _input(interior.clue_areas[2])
	await _inspect(_correct(2))
	await _input(_correct(2))
	await _frames(50)
	_expect(interior.completed_stage_count() == 3 and _complete() and not _door_blocks(2), "Third evidence-based choice completes the exact sidequest flag and opens the final gate")
	cache = expansion.reward_areas["sealed_archive"]
	_expect(cache.get_prompt().contains("Gather") or cache.get_prompt().contains("拾取"), "Completion signal immediately changes the cache prompt to claimable")
	await _inspect(cache)
	await _input(cache)
	_expect(world.player.embers == 135 and world.run_state.inventory.is_empty() and world.run_state.collected_loot.is_empty(), "Only completed investigation grants its finite reward without catalog pollution")
	var complete_save: Dictionary = world.saved_snapshot.duplicate(true)
	await _reload(complete_save)
	_expect(_complete() and interior.completed_stage_count() == 3 and expansion.reward_areas.is_empty(), "Full completion and claimed cache persist together through reload")
	for index in 3:
		_expect(not _door_blocks(index), "Completed reload retains physical passage on floor " + str(index + 1))
	world._clear_enemies()
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_INTERIOR_RUNTIME_OK checks=%d floors=3 choices_per_floor=3 save=memory input=production_sensor_and_handler" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build_level() -> void:
	level = Node3D.new()
	level.position = Vector3(-4, 3, -12)
	level.rotation.y = .63
	world.campaign_runtime.current_level_id = &"level_01_02"
	world.campaign_runtime.current_level = level
	world.campaign_runtime.add_child(level)
	for index in 3:
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 1
		floor_body.collision_mask = 0
		floor_body.position = Vector3(0, index * 6 - .25, 0)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(28, .5, 28)
		collision.shape = box
		floor_body.add_child(collision)
		level.add_child(floor_body)
	interior = Interior.new()
	interior.name = "CampaignInteriorRuntime"
	level.add_child(interior)
	interior.setup(world, level, plan)
	expansion = Expansion.new()
	expansion.name = "CampaignExpansionRuntime"
	level.add_child(expansion)
	expansion.setup(world, level, {"district_id": "ordered_rooms", "encounters": [], "rewards": [
		{"id": "sealed_archive", "position": Vector3(8, 12, -8), "embers": 135,
			"lore_text": "遗录的次序终于接续。", "required_flag": plan["completion_flag"]}]})


func _fixture_plan() -> Dictionary:
	var stages: Array[Dictionary] = []
	var clues := ["碑记：潮水逼近，先开启东侧泄水渠。", "残页：失去的字仍是空白，不以猜想补写。", "灯录：最后一盏留给尚未归来的人。"]
	var options := [["封死全部水渠", "开启东侧泄水渠", "点燃北方号火"], ["烧毁残页", "编写缺失史实", "保留原有空白"], ["为未归者留灯", "熄灭所有灯火", "把灯据为己有"]]
	for index in 3:
		var y := float(index * 6)
		stages.append({"id": "room_%d" % index, "index": index, "floor": index,
			"room_name": ["听潮室", "残页室", "留灯室"][index], "clue_position": Vector3(8, y, .5 if index == 1 else 4),
			"clue_text": clues[index], "options": options[index], "correct_index": [1, 2, 0][index],
			"controls_positions": [Vector3(-8, y, 2), Vector3(-4, y, 2), Vector3(0, y, 2)],
			"door": {"position": Vector3(-4, y, 0), "yaw": 0.0, "size": Vector3(3.8, 4, .5)},
			"prop_ids": ["MuralWall"], "to_next_route": []})
	return {"id": "level_01_02/interior/contract", "display_name": "留灯遗录", "story_source": "docs/story/main-story.md",
		"completion_flag": "interior_contract_complete", "floor_heights": [0, 6, 12], "stages": stages}


func _correct(index: int) -> Area3D:
	return interior.control_areas[index][int(plan["stages"][index]["correct_index"])]


func _flag(index: int, fact: String) -> bool:
	return bool(world.run_state.get_choice_flag(interior.stage_flag(index, fact), false))


func _complete() -> bool:
	return bool(world.run_state.get_choice_flag(String(plan["completion_flag"]), false))


func _door_blocks(index: int) -> bool:
	var door: StaticBody3D = interior.stage_doors[index]
	var ray := PhysicsRayQueryParameters3D.create(door.to_global(Vector3(0, 1.5, 1)), door.to_global(Vector3(0, 1.5, -1)), 1)
	return world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == door


func _inspect(area: Area3D) -> void:
	world.player.global_position = area.global_position + Vector3(0, 0, 1.1)
	await _frames(3)


func _input(expected: Area3D) -> void:
	world._update_interaction_target()
	if not _expect(world.player.interaction_target == expected, "Physical sensor selects " + String(expected.name)):
		return
	Input.action_press("interact")
	world.player._handle_action_input()
	Input.action_release("interact")
	await _frames(2)


func _reload(snapshot: Dictionary) -> void:
	world.campaign_runtime.unload_level()
	world.interaction_candidates.clear()
	world.player.set_interaction(null)
	world.run_state = RunState.from_dictionary(snapshot)
	_expect(world.run_state != null, "Persisted investigation passes actual run-state schema validation")
	_build_level()
	await _frames(4)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok
