extends SceneTree
## Real production factory/damage/death/save schema in a bounded physics fixture.
## AI is frozen except its authored ambush trigger. One drop is a real freefall;
## this is not evidence of a continuous campaign route or player success rates.
const Loop = preload("res://scripts/world/campaign_interior_loop_runtime.gd")
const Rooms = preload("res://scripts/world/campaign_interior_runtime.gd")
const Revisit = preload("res://scripts/world/campaign_interior_revisit_runtime.gd")
const RunState = preload("res://scripts/core/run_state.gd")
const LevelRuntime = preload("res://scripts/world/campaign_level_runtime.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfig = preload("res://scripts/core/input_config.gd")
const Enemy = preload("res://scripts/enemy.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	var saved_snapshot: Dictionary = {}
	var save_calls := 0
	var fail_next_save := false
	var fail_save_reason := ""
	var navigation_requests := 0
	func _ready() -> void:
		set_process(false)
	func _save_run(_reason: String) -> bool:
		save_calls += 1
		if fail_next_save or _reason == fail_save_reason:
			fail_next_save = false
			fail_save_reason = ""
			return false
		run_state.embers = int(player.embers)
		saved_snapshot = run_state.to_dictionary()
		return true
	func request_navigation_refresh(_level_root: Node3D) -> void:
		navigation_requests += 1

class AuditHud extends Node:
	var messages: Array[String] = []
	func show_message(message: String, _seconds: float) -> void:
		messages.append(message)
	func set_prompt(_message: String) -> void:
		pass
	func show_death() -> void:
		pass
	func clear_death() -> void:
		pass

class AuditAudio extends Node:
	func play_cue(_cue: String, _volume: float = 0.0, _pitch: float = 1.0) -> void:
		pass

var world: AuditWorld
var level: Node3D
var runtime: Node3D
var rooms: Node3D
var revisit: Node3D
var plan: Dictionary
var checks := 0
var failures: Array[String] = []
var refuge_events := 0
var resolved_reads: Array[bool] = []
var drop_events: Array[Dictionary] = []
var threat_events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfig.configure_inputs()
	world = AuditWorld.new()
	world.run_state = RunState.new()
	world.position = Vector3(13, 2, -8)
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
	world.player.died.connect(world._on_player_died)
	world._create_interaction_sensor()
	world.campaign_runtime = LevelRuntime.new()
	world.add_child(world.campaign_runtime)
	plan = _fixture()
	_build()
	await _frames(4)
	_expect(world.enemies.size() == 3, "All three floor threats are real production world-owned actors")
	_expect(not runtime.refuge_control.get_node("RefugeFlame").visible and is_zero_approx(float(runtime.refuge_control.get_node("RefugeWarmLight").light_energy)), "Unreleased B2 leaves the refuge's separate fire core hidden and light extinguished")
	runtime.setup(world, level, plan)
	_expect(world.enemies.size() == 3, "Repeated setup cannot duplicate the three threats")
	var ambush: Node3D = runtime.threats["level_01_02/interior/ground_ambush"]
	var patrol: Node3D = runtime.threats["level_01_02/interior/middle_patrol"]
	var guard: Node3D = runtime.threats["level_01_02/interior/top_shield"]
	_expect(ambush.spawn_origin.distance_to(level.to_global(plan["interior_pressure"][0]["position"] + Vector3.UP * .05)) < .001, "Named pressure data applies both rotated roots exactly once")
	_expect(ambush.attack_windup >= .7 and ambush.encounter_assignment["activation"] == "provoked", "Ground ambush has a real delayed activation and readable attack windup")
	_expect(patrol.encounter_assignment["patrol_points"][1].distance_to(level.to_global(Vector3(12, 6, -18))) < .001, "Middle enemy consumes real transformed patrol waypoints")
	_expect(ambush.spawn_origin.distance_to(runtime.refuge_control.global_position) > 20, "The ground threat starts away from the earned refuge")
	world.player.global_position = ambush.global_position + level.global_basis * Vector3(0, 0, 4)
	await _frames(2)
	_expect(runtime._ambush_state == "dormant" and not ambush._encounter_provoked, "Proximity cannot release the post-door ambush before door A is solved")
	world.player.global_position = guard.global_position - guard.global_basis.z * 2.0
	var hp := float(guard.health)
	guard.receive_hit_payload(_hit(20.0, true))
	_expect(is_equal_approx(hp - float(guard.health), 3.0), "Production top-guard incoming hit is reduced only while facing its shield")
	guard.reset_enemy()
	guard.set_physics_process(false)
	world.player.global_position = guard.global_position + guard.global_basis.z * 2.0
	hp = float(guard.health)
	guard.receive_hit_payload(_hit(20.0, true))
	_expect(is_equal_approx(hp - float(guard.health), 20.0), "A real rear hit bypasses the shield")
	guard.reset_enemy()
	guard.set_physics_process(false)
	world.player.global_position = guard.global_position - guard.global_basis.z * 2.0
	hp = float(guard.health)
	guard.receive_hit_payload(_hit(20.0, false))
	_expect(is_equal_approx(hp - float(guard.health), 20.0), "Unblockable production payload bypasses front defense")
	guard.state = Enemy.State.RECOVERY
	hp = float(guard.health)
	guard.receive_hit_payload(_hit(20.0, true))
	_expect(is_equal_approx(hp - float(guard.health), 20.0), "Shield guard exposes a punishable attack-recovery window")
	var latch: Area3D = runtime.b2_control
	world.player.global_position = level.to_global(Vector3(12, 6, 22))
	latch.interact(world.player)
	_expect(not runtime.refuge_is_available() and _door_blocks(), "Closed B2 rejects outside-side remote activation and remains a real collider")
	world.player.global_position = level.to_global(Vector3(12, 6, 18.6))
	await _frames(3)
	world.fail_next_save = true
	latch.interact(world.player)
	_expect(not runtime.refuge_is_available() and _door_blocks(), "Failed B2 save leaves the latch closed and refuge unavailable")
	await _input(latch)
	await _frames(48)
	_expect(runtime.refuge_is_available() and not _door_blocks() and refuge_events == 1, "Inside production input opens B2 and activates the refuge")
	_expect(runtime.refuge_control.get_node("RefugeFlame").visible and float(runtime.refuge_control.get_node("RefugeWarmLight").light_energy) > 0, "Opening B2 visibly kindles the warm refuge fire")
	_expect(rooms.completed_stage_count() == 0 and not bool(world.run_state.get_choice_flag(plan["completion_flag"], false)), "B2 recovery route is earned before any puzzle completion")
	var after_latch := world.save_calls
	latch.interact(world.player)
	_expect(world.save_calls == after_latch and refuge_events == 1, "Repeated B2 callbacks do not resave or reactivate the latch")
	world.player.global_position = runtime.refuge_control.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(runtime.refuge_control)
	_expect(refuge_events == 2, "The earned refuge remains an explicit repeatable rest interaction")
	world.player.global_position = rooms.control_areas[2][0].global_position + Vector3(0, 0, 1)
	rooms.control_areas[2][0].interact(world.player)
	_expect(rooms.completed_stage_count() == 0, "First ascent still rejects a top-first answer")
	world.player.global_position = rooms.control_areas[0][0].global_position + Vector3(0, 0, 1)
	await _frames(3)
	await _input(rooms.control_areas[0][0])
	_expect(rooms.completed_stage_count() == 1 and not bool(world.run_state.get_choice_flag(rooms.stage_flag(0, "clue"), false)), "Environmental matching solves an unread room without fabricating a reading flag")
	_expect(resolved_reads == [false], "Puzzle telemetry records the actual unread resolution")
	await _frames(48)
	world.player.global_position = ambush.global_position + level.global_basis * Vector3(0, 0, 4)
	await _frames(2)
	_expect(runtime._ambush_state == "telegraph" and not ambush._encounter_provoked, "After door A opens, proximity starts a warning before combat")
	await _frames(55)
	_expect(runtime._ambush_state == "active" and ambush._encounter_provoked and threat_events.has("ambush_released"), "The post-door warning releases the real encounter after its bounded delay")
	await _check_revisit_before_completion()
	var currency_before := int(world.player.embers)
	patrol.receive_hit_payload(_hit(10000.0, false))
	_expect(float(patrol.health) <= 0 and int(world.player.embers) > currency_before, "Defeating a floor threat grants embers through the production reward signal")
	var dropped := int(world.player.embers)
	# Death is in B2; the legitimate respawn is at the lower refuge. This also
	# recreates a queued body-enter event whose actor has moved after respawn.
	world.player.global_position = level.to_global(Vector3(12, 6, 18))
	world.respawn_position = level.to_global(plan["souls"]["refuge"]["spawn_position"])
	world.player.receive_hit_payload(_hit(10000.0, false))
	var death_echo: Area3D = world.lost_echo
	if is_instance_valid(death_echo):
		death_echo.interact(world.player)
	_expect(is_instance_valid(death_echo) and not bool(death_echo._claimed) and world.run_state.lost_echo_amount == dropped and world.player.embers == 0, "The dead player's direct echo callback cannot reclaim the newly dropped embers")
	# Production death resets actors synchronously; immediately freeze AI again
	# so this bounded persistence fixture does not imply a player combat trial.
	for enemy: Node3D in world.enemies:
		enemy.set_physics_process(false)
	await _frames(150)
	_expect(world.run_state.lost_echo_amount == dropped and world.player.embers == 0 and is_instance_valid(world.lost_echo), "Real death drops the earned embers into the production recoverable echo")
	if is_instance_valid(death_echo):
		death_echo._on_body_entered(world.player)
		death_echo.interact(world.player)
	_expect(is_instance_valid(death_echo) and world.player.global_position.distance_to(death_echo.global_position) > 3.0 and not bool(death_echo._claimed) and world.player.embers == 0 and world.run_state.lost_echo_amount == dropped, "A stale body-enter event and remote callback after respawn cannot recover the distant room echo")
	_expect(world.enemies.all(func(enemy): return float(enemy.health) > 0) and runtime._ambush_state == "dormant", "Production death restores floor threats and rearms the telegraphed ambush")
	_expect(runtime.refuge_is_available() and not _door_blocks() and rooms.completed_stage_count() == 1, "Death preserves B2 and first-ascent solved doors")
	_expect(runtime.landing_damage(12.0, true) > 0 and runtime.landing_damage(12.0, true) < runtime.landing_damage(12.0, false), "Books reduce authored atrium damage without eliminating it")
	world.player._weight_class = "mid"
	world.player._dodge_is_backstep = false
	world.player.state = world.player.State.DODGE
	world.player.state_duration = .6
	world.player.state_time = .4
	_expect(world.player._is_invulnerable(), "Dodge regression fixture is inside the production invulnerability window")
	var dodge_health := float(world.player.health)
	world.player.receive_hit_payload(_hit(11.0, false))
	_expect(is_equal_approx(float(world.player.health), dodge_health), "Ordinary combat damage remains blocked during production dodge invulnerability")
	var fall_payload := _hit(10.8, false)
	fall_payload["tags"] = ["environmental_fall"]
	world.player.receive_hit_payload(fall_payload)
	_expect(float(world.player.health) < dodge_health and is_equal_approx(dodge_health - float(world.player.health), 10.8), "The same dodge cannot erase the authored environmental landing cost")
	world.player.global_position = level.to_global(Vector3(0, 12.1, 6))
	world.player.velocity = Vector3.ZERO
	world.player.state = world.player.State.LOCOMOTION
	world.player.state_time = 0.0
	world.player.set_physics_process(true)
	await _frames(140)
	world.player.set_physics_process(false)
	_expect(not drop_events.is_empty() and bool(drop_events.back()["cushioned"]) and float(drop_events.back()["health_lost"]) > 0, "Real production freefall lands on the authored book zone and causes positive reduced damage")
	var saved: Dictionary = world.run_state.to_dictionary()
	var old_threat: WeakRef = weakref(guard)
	world.campaign_runtime.unload_level()
	await _frames(4)
	_expect(world.enemies.is_empty() and old_threat.get_ref() == null, "Level unload removes all world-owned interior source enemies")
	world.run_state = RunState.from_dictionary(saved)
	_build()
	await _frames(4)
	_expect(runtime.refuge_is_available() and not _door_blocks() and rooms.completed_stage_count() == 1 and world.enemies.size() == 3, "Serialized reload restores B2 and solved floor while creating exactly one fresh threat roster")
	_expect(runtime.refuge_control.get_node("RefugeFlame").visible and runtime.refuge_control.get_node("RefugeWarmLight").visible, "The saved B2 flag restores the refuge's fire and warm light without another persistent key")
	_expect(not revisit.scout_copy.visible and bool(world.run_state.get_choice_flag(plan["stele_scout_reward"]["consumed_flag"], false)), "Reload preserves the consumed scout window without replaying its visual reward")
	await _check_top_gate_and_annotations()
	world.campaign_runtime.unload_level()
	await _frames(3)
	world.run_state = RunState.new()
	_build()
	await _frames(3)
	var early_clue: Area3D = rooms.clue_areas[0]
	world.player.global_position = early_clue.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(early_clue)
	_expect(bool(world.run_state.get_choice_flag("level_01_02/stele_scouted", false)) and rooms.completed_stage_count() == 0 and not revisit.scout_copy.visible, "Reading before door A reserves scouting without opening the door or revealing the copy early")
	world.player.global_position = rooms.control_areas[0][0].global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(rooms.control_areas[0][0])
	_expect(revisit.scout_copy.visible and bool(world.run_state.get_choice_flag("level_01_02/stele_scout_window_used", false)), "Opening A after an earlier read starts the same single scout reward")
	var active_copy: WeakRef = weakref(revisit.scout_copy)
	world.campaign_runtime.unload_level()
	await _frames(3)
	_expect(active_copy.get_ref() == null, "Unloading during an active scout window removes its copy and cancels the level-owned timer")
	_build(&"level_05_01")
	_expect(world.enemies.is_empty(), "Quiet shore remains peaceful with no interior hostiles")
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_INTERIOR_LOOP_RUNTIME_OK checks=%d save=memory ai=frozen_with_live_ambush_trigger drop=production_physics" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build(id: StringName = &"level_01_02") -> void:
	level = Node3D.new()
	level.position = Vector3(-4, 3, -12)
	level.rotation.y = .63
	world.campaign_runtime.current_level_id = id
	world.campaign_runtime.current_level = level
	world.campaign_runtime.add_child(level)
	_solid(Vector3(0, -.25, 0), Vector3(60, .5, 60))
	_solid(Vector3(0, 5.75, -18), Vector3(36, .5, 6))
	_solid(Vector3(0, 5.75, 18), Vector3(30, .5, 6))
	_solid(Vector3(12, 5.75, 20), Vector3(8, .5, 8))
	_solid(Vector3(0, 11.75, 16), Vector3(36, .5, 10))
	_solid(Vector3(-15, 11.75, 0), Vector3(6, .5, 36))
	_solid(Vector3(0, 11.75, -18), Vector3(36, .5, 6))
	rooms = Rooms.new()
	rooms.name = "CampaignInteriorRuntime"
	level.add_child(rooms)
	rooms.puzzle_resolved.connect(func(_id: String, _stage: String, read_status: bool, _at: Vector3) -> void: resolved_reads.append(read_status))
	rooms.setup(world, level, plan)
	var scout_copy := Node3D.new()
	scout_copy.name = "SteleScoutCopy"
	scout_copy.position = plan["stele_scout_reward"]["position"]
	scout_copy.set_meta("interior_stele_scout_id", plan["id"])
	var warm := OmniLight3D.new()
	warm.name = "WarmLight"
	scout_copy.add_child(warm)
	level.add_child(scout_copy)
	revisit = Revisit.new()
	revisit.name = "CampaignInteriorRevisitRuntime"
	level.add_child(revisit)
	# The peaceful reload fixture carries different world identity; its local
	# scout/revisit records are intentionally omitted, just like no pressure.
	var revisit_plan := plan.duplicate(true)
	if id != &"level_01_02":
		revisit_plan.erase("stele_scout_reward")
		revisit_plan.erase("revisit_interactions")
	revisit.setup(world, level, revisit_plan, rooms)
	runtime = Loop.new()
	runtime.name = "CampaignInteriorLoopRuntime"
	level.add_child(runtime)
	runtime.refuge_activated.connect(func(_id: String, _at: Vector3) -> void: refuge_events += 1)
	runtime.threat_state_changed.connect(func(_id: String, state: String, _at: Vector3) -> void: threat_events.append(state))
	runtime.drop_landed.connect(func(_at: Vector3, height: float, cushioned: bool, lost: float) -> void: drop_events.append({"height": height, "cushioned": cushioned, "health_lost": lost}))
	runtime.setup(world, level, plan)
	for enemy: Node3D in world.enemies:
		enemy.set_physics_process(false)


func _fixture() -> Dictionary:
	var stages: Array[Dictionary] = []
	for index in 3:
		var y := float(index * 6)
		stages.append({"id": "floor_%d" % index, "index": index, "floor": index, "room_name": "痕迹室", "clue_position": Vector3(8, y, 16), "clue_text": "相连的石槽通向完整圆印。", "options": ["完整圆印", "断裂方印", "逆向三角"], "correct_index": 0, "controls_positions": [Vector3(-4, y, 18), Vector3(0, y, 18), Vector3(4, y, 18)], "door": {"position": Vector3(-18, y, 15), "yaw": 0.0, "size": Vector3(3.8, 6, .5)}, "prop_ids": [], "to_next_route": []})
	return {"id": "level_01_02/interior", "origin": Vector3.ZERO, "completion_flag": "interior_complete:level_01_02/interior", "stages": stages,
		"interior_pressure": [
			{"placement_id": "level_01_02/interior/ground_ambush", "content_id": "lost_soul_soldier", "role": "ambush", "combat_role": "door_ambush", "position": Vector3(-18, 0, 12), "facing": Vector3.BACK, "guard_radius": 5.0, "activation": "provoked", "patrol_points": []},
			{"placement_id": "level_01_02/interior/middle_patrol", "content_id": "lost_soul_soldier", "role": "patrol", "position": Vector3(-6, 6, -18), "facing": Vector3.RIGHT, "guard_radius": 7.0, "patrol_points": [Vector3(-10, 6, -18), Vector3(12, 6, -18)]},
			{"placement_id": "level_01_02/interior/top_shield", "content_id": "temple_guardian_warrior", "role": "guard", "combat_role": "front_shield", "position": Vector3(-15, 12, 5), "facing": Vector3.BACK, "guard_radius": 7.0, "patrol_points": []}],
		"stele_scout_reward": {"flag": "level_01_02/stele_scouted", "consumed_flag": "level_01_02/stele_scout_window_used", "duration_seconds": 10.0, "position": Vector3(12, 0, 8), "node_name": "SteleScoutCopy"},
		"scene_readables": [{"id": "plain_page", "title": "残页", "text": "副本未决，批注需另行核对。", "position": Vector3(8, 12, -18)}],
		"revisit_interactions": [
			{"id": "relic", "position": Vector3(2, 0, 8), "kind": "ground_relic", "text": "翻检后发现值守人留下的修补痕迹。", "flag": "level_01_02/ground_relic_examined"},
			{"id": "annotation", "position": Vector3(-8, 12, -18), "kind": "scribe_annotation", "text": "把副本中相反的说法并列，留待查证。", "flag": "level_01_02/scribe_annotation", "required_stage": 2, "prerequisite_flags": ["interior_complete:level_01_02/interior"]},
			{"id": "recall", "position": Vector3(2, 0, -8), "kind": "memory_return", "text": "回头核对已经留下的批注，并不替任何人定论。", "flag": "level_01_02/annotation_recalled", "any_prerequisite_flags": ["level_04_03/scribe_annotation", "level_01_02/scribe_annotation"]}],
		"souls": {
		"b2_latch": {"id": "level_01_02/door_b2_latch", "flag": "level_01_02/door_b2_latch", "position": Vector3(12, 6, 21), "far_side": Vector3(12, 6, 19.5), "yaw": 0.0, "size": Vector3(3.8, 6, .5)},
		"refuge": {"id": "level_01_02/ash_refuge", "position": Vector3(12, 0, 12), "spawn_position": Vector3(12, 0, 16)},
		"drop": {"takeoff": Vector3(0, 12, 10), "landing_center": Vector3(0, 0, 6), "size": Vector3(6, 1, 6), "damage_scale": .3, "minimum_damage": 3}, "roof_route": [Vector3(0, 18, 0)]}}


func _check_revisit_before_completion() -> void:
	var clue: Area3D = rooms.clue_areas[0]
	world.player.global_position = clue.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	world.fail_save_reason = "interior_stele_scout_window"
	await _input(clue)
	_expect(bool(world.run_state.get_choice_flag("level_01_02/stele_scouted", false)) and not bool(world.run_state.get_choice_flag("level_01_02/stele_scout_window_used", false)) and not revisit.scout_copy.visible, "Late optional reading records scouting but failed window persistence grants no visual reward")
	await _input(clue)
	_expect(revisit.scout_copy.visible and bool(world.run_state.get_choice_flag("level_01_02/stele_scout_window_used", false)), "Successful rereading after door A opens grants the one reserved scout window")
	await _frames(300)
	_expect(revisit.scout_copy.visible, "The authored scout copy remains visible during its first five seconds")
	await _frames(310)
	_expect(not revisit.scout_copy.visible and not revisit.scout_copy.get_node("WarmLight").visible, "The10 second scout window extinguishes its actual copy and warm light")
	var saved_calls := world.save_calls
	await _input(clue)
	_expect(world.save_calls == saved_calls and not revisit.scout_copy.visible, "Rereading cannot restart or resave the consumed scout window")
	var relic: Area3D = revisit.interaction_areas["relic"]
	relic.interact(world.player)
	_expect(not bool(world.run_state.get_choice_flag("level_01_02/ground_relic_examined", false)), "A remote callback cannot examine the first-floor relic")
	world.player.global_position = relic.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	world.fail_save_reason = "interior_revisit_ground_relic"
	await _input(relic)
	_expect(not bool(world.run_state.get_choice_flag("level_01_02/ground_relic_examined", false)), "Failed relic persistence leaves the object unexamined")
	await _input(relic)
	_expect(bool(world.run_state.get_choice_flag("level_01_02/ground_relic_examined", false)), "Physical relic input leaves a durable local examination record")
	saved_calls = world.save_calls
	await _input(relic)
	_expect(world.save_calls == saved_calls, "Already examined relics remain readable without another reward or save")
	var annotation: Area3D = revisit.interaction_areas["annotation"]
	world.player.global_position = annotation.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(annotation)
	_expect(not bool(world.run_state.get_choice_flag("level_01_02/scribe_annotation", false)), "The annotation cannot be recorded before its required solved stage")
	var recall: Area3D = revisit.interaction_areas["recall"]
	world.player.global_position = recall.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(recall)
	_expect(not bool(world.run_state.get_choice_flag("level_01_02/annotation_recalled", false)), "A later comparison needs at least one actual earlier annotation")


func _check_top_gate_and_annotations() -> void:
	world.player.global_position = rooms.control_areas[1][0].global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(rooms.control_areas[1][0])
	await _frames(48)
	world.player.global_position = rooms.control_areas[2][0].global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	var saved_calls := world.save_calls
	await _input(rooms.control_areas[2][0])
	_expect(runtime.top_guard_is_alive() and rooms.completed_stage_count() == 2 and world.save_calls == saved_calls, "Matching the final seal cannot open or persist the door while its shield guard lives")
	var guard: Node3D = runtime.top_guard()
	guard.receive_hit_payload(_hit(10000.0, false))
	await _input(rooms.control_areas[2][0])
	await _frames(48)
	_expect(not runtime.top_guard_is_alive() and rooms.completed_stage_count() == 3 and rooms.stage_doors[2].collision_layer == 0, "A real defeated guard allows the final matched control to open its physical door")
	guard.reset_enemy()
	guard.set_physics_process(false)
	_expect(runtime.top_guard_is_alive() and rooms.completed_stage_count() == 3 and rooms.stage_doors[2].collision_layer == 0, "Resetting the ordinary shield enemy never relocks an already completed door")
	var ordinary_page: Area3D = rooms.scene_readables.keys()[0]
	world.player.global_position = ordinary_page.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(ordinary_page)
	_expect(not bool(world.run_state.get_choice_flag("level_01_02/scribe_annotation", false)), "Reading the original page does not silently write its separate annotation")
	var annotation: Area3D = revisit.interaction_areas["annotation"]
	world.player.global_position = annotation.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(annotation)
	_expect(bool(world.run_state.get_choice_flag("level_01_02/scribe_annotation", false)), "Explicit annotation input records the comparison after its prerequisite is satisfied")
	var recall: Area3D = revisit.interaction_areas["recall"]
	world.player.global_position = recall.global_position + level.global_basis * Vector3(0, 0, 1.2)
	await _frames(3)
	await _input(recall)
	_expect(bool(world.run_state.get_choice_flag("level_01_02/annotation_recalled", false)), "A valid local annotation enables the separate recall through its OR prerequisite")
	_expect(world.run_state.inventory.is_empty() and world.run_state.defeated_bosses.is_empty(), "Relic, scout and annotation records never fabricate inventory or canonical boss outcomes")
	world._save_run("completed_door_reset_audit")
	var saved: Dictionary = world.saved_snapshot.duplicate(true)
	world.campaign_runtime.unload_level()
	await _frames(3)
	world.run_state = RunState.from_dictionary(saved)
	_build()
	await _frames(4)
	_expect(runtime.top_guard_is_alive() and rooms.completed_stage_count() == 3 and rooms.stage_doors[2].collision_layer == 0, "Reloaded living threats coexist with the permanently opened final door")
	_expect(bool(world.run_state.get_choice_flag("level_01_02/ground_relic_examined", false)) and bool(world.run_state.get_choice_flag("level_01_02/scribe_annotation", false)) and bool(world.run_state.get_choice_flag("level_01_02/annotation_recalled", false)) and not revisit.scout_copy.visible, "All revisit facts serialize together while the one-time scout copy remains consumed")


func _hit(damage: float, blockable: bool) -> Dictionary:
	return {"damage": damage, "stagger": 0.0, "poise": 0.0, "direction": Vector3.ZERO, "source": world.player, "blockable": blockable, "parryable": false, "tags": []}


func _solid(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	level.add_child(body)


func _door_blocks() -> bool:
	var door: StaticBody3D = runtime.b2_door
	var ray := PhysicsRayQueryParameters3D.create(door.to_global(Vector3(0, 1.5, 1)), door.to_global(Vector3(0, 1.5, -1)), 1)
	return world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == door


func _input(area: Area3D) -> void:
	world._update_interaction_target()
	_expect(world.player.interaction_target == area, "Production sensor selects " + String(area.name))
	Input.action_press("interact")
	world.player._handle_action_input()
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
