extends SceneTree
## Real evidence, physical cage seal, earned dialogue migration and saved reload.
## Isolated in-memory saves; production callbacks are reached through interactables.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const Evidence = preload("res://scripts/world/campaign_story_progression.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(_reason: String) -> bool:
		_snapshot_run_state()
		return true

var world: AuditWorld
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		world.add_child(child)
	contents.free()
	root.add_child(world)
	world.game_settings.reduced_motion = true
	_freeze()
	await _frames(3)
	_expect(world._shrine_npcs.is_empty(), "Opening temple has no corporeal Cloud Wanderer before Giant's defeat")
	await _load("level_01_04")
	await _collect("keeper_rune")
	await _load("level_01_04")
	_expect(_clue("keeper_rune") == null and world.has_story_item("keeper_rune"), "Rune persists and cannot be collected twice after reload")

	await _load("level_02_03")
	var iron := _npc(&"npc_iron_heart")
	_expect(iron != null, "Iron Heart begins in the prison camp")
	var controller := _controller()
	var gate: StaticBody3D = controller.forge_seal
	_expect(gate != null, "Forced-forge seal has a real physical gate")
	world.player.global_position = gate.global_position + Vector3(0, .1, 2.)
	controller.seal_interaction.interact(world.player)
	_expect(not bool(world.run_state.get_choice_flag("iron_forge_seal_broken", false)), "Missing keys cannot release the physical seal")
	world._on_shrine_npc_talk(iron, world.player)
	_finish_dialogue()
	_expect(not bool(world.run_state.get_choice_flag("npc_iron_heart_met", false)), "Talking through a locked cage does not migrate Iron Heart")
	for index in range(1, 4):
		await _collect("cage_key_" + str(index))
	world.player.global_position = gate.global_position + Vector3(0, .1, 2.)
	world._on_shrine_npc_talk(iron, world.player)
	_finish_dialogue()
	_expect(not bool(world.run_state.get_choice_flag("unlock_weapon_forging", false)), "Three collected keys still require releasing the forge seal")
	var ray := PhysicsRayQueryParameters3D.create(gate.global_position + Vector3(0, 1., 1.), gate.global_position + Vector3(0, 1., -1.), 1)
	_expect(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == gate, "Locked cage door blocks a real World collision ray")
	controller.seal_interaction.interact(world.player)
	await _frames(3)
	_expect(bool(world.run_state.get_choice_flag("iron_forge_seal_broken", false)), "Three actual keys release the forge seal")
	_expect(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") != gate, "Released seal removes physical obstruction")
	world.player.global_position = iron.global_position + Vector3(0, .1, 1.)
	world._on_shrine_npc_talk(iron, world.player)
	_finish_dialogue()
	await _frames(2)
	_expect(bool(world.run_state.get_choice_flag("unlock_weapon_forging", false)), "Earned rescue and completed dialogue unlock forging")
	await _load("level_02_01")
	_expect(_npc(&"npc_iron_heart") != null, "Rescued Iron Heart migrates to an earlier chapter shrine")
	await _load("level_02_03")
	_expect(_controller().forge_seal == null, "Saved rescue never recreates its prison lock")

	await _load("level_03_02")
	for index in range(1, 4):
		await _collect("true_memory_" + str(index))
	var lady := _npc(&"npc_lady_of_memories")
	world.player.global_position = lady.global_position + Vector3(0, .1, 1.)
	world._on_shrine_npc_talk(lady, world.player)
	_finish_dialogue()
	_expect(not bool(world.run_state.get_choice_flag("npc_lady_of_memories_met", false)), "Memory evidence without defeating the thief does not free the keeper")
	var thief: Node3D
	for enemy in world.enemies:
		if enemy.content_id == "elite_memory_eater":
			thief = enemy
	_expect(thief != null, "Memory prison has its actual elite keeper")
	if thief != null:
		world.player.global_position = thief.global_position + Vector3(0, 0, 2.)
		thief.receive_hit(float(thief.max_health) * 5., 0., Vector3.ZERO, world.player)
		await _frames(2)
	_expect(bool(world.run_state.get_choice_flag("story_memory_thief_defeated", false)), "Actual elite death records the memory rescue condition")
	world.player.global_position = lady.global_position + Vector3(0, .1, 1.)
	world._on_shrine_npc_talk(lady, world.player)
	_finish_dialogue()
	await _frames(2)
	await _load("level_03_01")
	_expect(_npc(&"npc_lady_of_memories") != null, "Freed memory keeper migrates after both requirements")
	await _load("level_03_05")
	await _collect("true_mirror")
	await _load("level_04_03")
	await _collect("xuanxiao_record")
	var remnant := _npc(&"npc_xuanxiao_remnant")
	world.player.global_position = remnant.global_position + Vector3(0, .1, 1.)
	world._on_shrine_npc_talk(remnant, world.player)
	_finish_dialogue()
	_expect(not bool(world.run_state.get_choice_flag("npc_xuanxiao_remnant_met", false)), "Unaltered record alone does not prematurely resolve the split remnant")
	# This fixture represents completed subboss fights; their lethal and phase
	# contracts independently exercise production combat rather than this test.
	world.run_state.defeated_bosses.append("boss_xuan_xiao_wrath")
	world.run_state.defeated_bosses.append("boss_xuan_xiao_obsession")
	world._on_shrine_npc_talk(remnant, world.player)
	_finish_dialogue()
	await _frames(2)
	await _load("level_04_01")
	_expect(_npc(&"npc_xuanxiao_remnant") != null, "Record and both completed fragment fights allow remnant migration")
	_expect(get_nodes_in_group("campaign_story_evidence").is_empty(), "Unloading evidence rooms removes old interactables")
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_STORY_PROGRESSION_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _load(id: String) -> void:
	_expect(world._load_campaign_level(StringName(id)), "Load " + id)
	_freeze()
	await _frames(4)

func _freeze() -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	for enemy in world.enemies:
		enemy.set_physics_process(false)

func _controller() -> Node:
	return world.campaign_runtime.current_level.get_node("CampaignStoryProgression")

func _clue(key: String) -> Node3D:
	return _controller().get_node_or_null("StoryEvidence_" + key)

func _collect(key: String) -> void:
	var clue := _clue(key)
	if not _expect(clue != null, "Actual evidence exists: " + key):
		return
	var stranger := Node3D.new()
	world.add_child(stranger)
	stranger.global_position = clue.global_position
	clue.interact(stranger)
	_expect(not world.has_story_item(key), "Non-player actor cannot claim " + key)
	stranger.free()
	world.player.global_position = clue.global_position + Vector3(8, 0, 0)
	clue.interact(world.player)
	_expect(not world.has_story_item(key), "Out-of-range call cannot claim " + key)
	world.player.global_position = clue.global_position + Vector3(0, .1, 1.5)
	clue.interact(world.player)
	clue.interact(world.player)
	_expect(int(world.run_state.inventory.get(key, 0)) == 1, "Actual nearby interaction grants one " + key)
	await _frames(2)
	_expect(_clue(key) == null, "Claimed evidence removes its visual and interaction " + key)

func _npc(id: StringName) -> Node3D:
	for npc in world._shrine_npcs:
		if npc.npc_id == id:
			return npc
	return null

func _finish_dialogue() -> void:
	var safety := 0
	while world._dialogue_overlay.is_open() and safety < 20:
		world._dialogue_overlay._advance()
		safety += 1
	_expect(not paused, "Dialogue finishes and resumes the world")

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok
