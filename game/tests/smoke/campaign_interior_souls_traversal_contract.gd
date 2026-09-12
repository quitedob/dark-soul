extends "res://tests/smoke/campaign_expansion_traversal_contract.gd"
## One documented inspection placement at the occupied house entrance. First
## observe an actual AI attack; then freeze AI for continuous production-input
## route proof. Fixture wallet and injected death are explicitly labelled.
## --fixed-fps 60 -- --levels=01_02 (optionally 04_03 for the foreign archive).

var interior_plan: Dictionary
var souls_plan: Dictionary
var rooms: Node3D
var loop: Node3D
var revisit: Node3D
var live_health_lost := 0.0
var return_seconds := 0.0
var observed_drops: Array[Dictionary] = []
var _wall_deadline := 0
var _live_watch: Node3D
var _live_saw_attack := false


func _run() -> void:
	_wall_deadline = Time.get_ticks_msec() + 30 * 60 * 1000
	_expect(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60, "Production physics uses time scale1 and60 Hz")
	world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		world.add_child(child)
	contents.free()
	root.add_child(world)
	world.set_process(false)
	world.game_settings.reduced_motion = true
	_freeze_ai()
	await _frames(6)
	for id: String in _requested_levels():
		level_id = id
		if not await _check_souls_level():
			break
		completed_levels += 1
	_release_input()
	world._clear_enemies()
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_INTERIOR_SOULS_TRAVERSAL_OK checks=%d levels=%d waypoints=%d distance_m=%.1f physics_frames=%d live_ai_health_lost=%.1f recovery_seconds=%.2f inspection=one_house_entry_per_level route_ai=frozen death=injected_production_payload wallet=40_fixture_embers" % [checks, completed_levels, walked_waypoints, measured_distance, physics_steps, live_health_lost, return_seconds])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_souls_level() -> bool:
	_release_input()
	if not _expect(world._load_campaign_level(StringName(level_id)), "Load actual campaign house " + level_id):
		return false
	_freeze_ai()
	_bind_level()
	if not _expect(not souls_plan.is_empty() and rooms != null and loop != null, "Production house contains the physical souls loop"):
		return false
	await _frames(10)
	var entry: Vector3 = interior_plan["entry"]
	world.player.respawn_at(level.to_global(entry + Vector3.UP * .1))
	world.player.add_embers(40)
	await _frames(24)
	print("INTERIOR_SOULS_SEGMENT level=%s segment=entry inspection_placements=1 position=%s wallet_seed=40_fixture_only" % [level_id, str(world.player.global_position)])
	if not await _resolve_by_scene(0):
		return false
	if not await _visit_revisit_record("ground_relic"):
		return false
	if not await _read_optional_scout():
		return false
	if level_id != "level_05_01" and not await _observe_live_ambush():
		return false
	_freeze_ai()
	print("INTERIOR_SOULS_SEGMENT level=%s segment=route ai=frozen input=production no_position_rescue=true" % level_id)
	var first_ascent: Array = interior_plan["stages"][0]["to_next_route"].duplicate()
	# Walk beside the frozen actor on the six-metre stair, preserving its real
	# body instead of deleting it or resetting its post-attack position.
	for index in first_ascent.size():
		var point: Vector3 = first_ascent[index]
		if is_equal_approx(point.x, (interior_plan["origin"] as Vector3).x - 18.0):
			first_ascent[index] = point + Vector3(1.2, 0, 0)
	if not await _walk_points(first_ascent, "first_ascent_beside_frozen_ambush"):
		return false
	if level_id == "level_04_03" and not await _check_annex():
		return false
	# Stay in the supported east gallery, beside the still-closed second stair.
	if not await _middle_gallery(true):
		return false
	if not await _interact(loop.b2_control, "unlatch_b2_from_room"):
		return false
	await _frames(48)
	if not _expect(loop.refuge_is_available() and rooms.completed_stage_count() == 1, "B2 opens the recovery circuit before the remaining two puzzles"):
		return false
	if not await _b2_ride(false, false):
		return false
	if not await _walk_to(souls_plan["refuge"]["position"], "reach_earned_refuge"):
		return false
	if not await _interact(loop.refuge_control, "rest_at_earned_refuge"):
		return false
	_freeze_ai()
	if not _expect(String(world.run_state.get_choice_flag("active_interior_refuge", "")) == String(souls_plan["refuge"]["id"]), "Actual rest saves the earned local refuge"):
		return false
	# Walk back to B2 before injecting a death, so the real echo remains in the
	# room that the later timed recovery circuit must reach.
	if not await _b2_ride(true, false):
		return false
	var recovery_target: Vector3 = interior_plan["origin"] + Vector3(6, 6, 18)
	if not await _walk_to(recovery_target, "death_fixture_room"):
		return false
	var wallet := int(world.player.embers)
	world.player.receive_hit_payload({"damage": 100000.0, "stagger": 0.0, "poise": 0.0, "direction": Vector3.ZERO, "source": loop, "blockable": false, "parryable": false, "tags": ["contract_death_injection"]})
	_freeze_ai()
	if not _expect(float(world.player.health) <= 0 and world.run_state.lost_echo_amount == wallet and is_instance_valid(world.lost_echo), "Injected production death creates an actual recoverable room echo"):
		return false
	await _frames(150)
	_freeze_ai()
	_report_recovery_state("after_death_respawn", world.saved_snapshot)
	var refuge_spawn: Vector3 = souls_plan["refuge"]["spawn_position"]
	if not _expect(world.player.global_position.distance_to(level.to_global(refuge_spawn)) < 2.0, "Production death coroutine returns the player to the earned refuge"):
		return false
	var saved: Dictionary = world.saved_snapshot.duplicate(true)
	_report_recovery_state("before_reload", saved)
	var restored = RunState.from_dictionary(saved)
	if not _expect(restored != null, "Death snapshot round-trips through the real save schema"):
		return false
	world._apply_run_state(restored)
	_freeze_ai()
	_bind_level()
	await _frames(18)
	_report_recovery_state("after_reload", saved)
	if not _expect(loop.refuge_is_available() and rooms.completed_stage_count() == 1 and world.run_state.lost_echo_amount == wallet, "Actual load restores open B2, ordered progress, refuge and unrecovered echo: " + _recovery_details(saved) + " expected_echo=" + str(wallet)):
		return false
	if not _expect(world.player.global_position.distance_to(level.to_global(refuge_spawn)) < 2.0, "Reload starts physically at the earned refuge without an inspection placement"):
		return false
	var clock_start := physics_steps
	if not await _b2_ride(true, true):
		return false
	if not await _walk_to(recovery_target, "timed_b2_room_recovery"):
		return false
	return_seconds = float(physics_steps - clock_start) / 60.0
	print("INTERIOR_SOULS_RECOVERY level=%s seconds=%.3f budget=20 start=earned_refuge end=b2_room empty_platform_call=included" % [level_id, return_seconds])
	if not _expect(return_seconds <= 20.0, "Actual refuge-to-B2 call/board/ride/walk recovery fits the20 second budget: %.3f" % return_seconds):
		return false
	if not _expect(world.run_state.lost_echo_amount == 0 and int(world.player.embers) == wallet, "Physical return to B2 recovers the production echo once"):
		return false
	if not await _middle_gallery(false):
		return false
	if not await _resolve_by_scene(1):
		return false
	if not await _walk_second_ascent():
		return false
	if bool(interior_plan.get("chamber_violation", false)):
		if not _expect(int(interior_plan["stages"][2]["floor"]) == 0 and absf(level.to_local(world.player.global_position).y - (interior_plan["origin"] as Vector3).y) < .6, "The authored03_02 route physically returns to its ground-floor third investigation"):
			return false
		print("INTERIOR_SOULS_CHAMBER_RETURN level=%s third_stage_floor=1 route=production_input" % level_id)
	if not await _resolve_by_scene(2):
		return false
	if not await _walk_points(interior_plan["stages"][2]["to_next_route"], "top_gate_gallery"):
		return false
	var reward: Dictionary = expansion["rewards"][0]
	var district := level.get_node("CampaignExpansionRuntime")
	if not await _walk_to(reward["position"], "resolved_top_cache"):
		return false
	var before_cache := int(world.player.embers)
	if not await _interact(district.reward_areas[String(reward["id"])], "claim_completed_top_cache"):
		return false
	if not _expect(int(world.player.embers) - before_cache == int(reward["embers"]), "Actual top-cache pickup grants exactly its authored ember amount: %d" % int(reward["embers"])):
		return false
	print("INTERIOR_SOULS_CACHE level=%s authored_embers=%d actual_gain=%d" % [level_id, int(reward["embers"]), int(world.player.embers) - before_cache])
	if not await _visit_revisit_record("scribe_annotation"):
		return false
	if not await _walk_to(reward["position"], "return_from_annotation_to_roof_route"):
		return false
	var roof: Array = souls_plan["roof_route"]
	if not await _walk_points(roof, "physical_roof_ladder_ridge_and_return"):
		return false
	print("INTERIOR_SOULS_ROOF level=%s walked_points=%d endpoint=%s" % [level_id, roof.size(), str(world.player.global_position)])
	var lift_plan: Dictionary = souls_plan["b2_lift"]
	var lift := level.get_node("InteriorRooms/InteriorReturnLift/PhysicalLiftRuntime")
	if absf(lift.platform.position.y - float(lift.upper_y)) > .05:
		if not await _interact(level.get_node("InteriorRooms/InteriorReturnLift/UpperRoofCall"), "roof_call_absent_b2_platform"):
			return false
		if not await _wait_for_lift(lift, float(lift.upper_y), false, "roof_upper_call"):
			return false
	if not await _walk_to(lift_plan["upper_dock"], "cross_roof_return_deck"):
		return false
	if not await _walk_to(lift_plan["upper_landing"], "roof_return_through_saved_b2"):
		return false
	if not await _middle_gallery(false):
		return false
	if not await _walk_points(interior_plan["stair_routes"][1], "reascend_solved_second_stair"):
		return false
	if not await _walk_to(interior_plan["origin"] + Vector3(12, 12, 18), "top_gallery_from_solved_stair"):
		return false
	if not await _walk_to(interior_plan["origin"] + Vector3(0, 12, 18), "top_gallery_toward_drop"):
		return false
	var drop: Dictionary = souls_plan["drop"]
	if not await _walk_to(drop["takeoff"], "walk_to_atrium_drop_lip"):
		return false
	var health_before := float(world.player.health)
	if not await _walk_to(drop["landing_center"], "physical_bookpile_descent"):
		return false
	if not _expect(not observed_drops.is_empty(), "Continuous input produces an observed physical drop landing"):
		return false
	var observed: Dictionary = observed_drops.back()
	var full_damage := float(loop.landing_damage(float(observed["height"]), false))
	if not _expect(bool(observed["cushioned"]) and float(observed["lost"]) > 0 and float(observed["lost"]) < full_damage and float(world.player.health) < health_before, "Actual bookpile descent reduces the landing hit while still hurting the player"):
		return false
	print("INTERIOR_SOULS_DROP level=%s fall_height=%.2f health_lost=%.2f hard_floor_damage=%.2f" % [level_id, float(observed["height"]), float(observed["lost"]), full_damage])
	return failures.is_empty()


func _bind_level() -> void:
	level = world.campaign_runtime.current_level
	expansion = level.get_meta("expansion", {})
	interior_plan = expansion.get("interior", {})
	souls_plan = interior_plan.get("souls", {})
	rooms = level.get_node_or_null("CampaignInteriorRuntime")
	loop = level.get_node_or_null("CampaignInteriorLoopRuntime")
	revisit = level.get_node_or_null("CampaignInteriorRevisitRuntime")
	observed_drops.clear()
	if loop != null:
		loop.drop_landed.connect(func(_at: Vector3, height: float, cushioned: bool, lost: float) -> void:
			observed_drops.append({"height": height, "cushioned": cushioned, "lost": lost})
		)


func _report_recovery_state(label: String, saved: Dictionary) -> void:
	print("INTERIOR_SOULS_RECOVERY_STATE stage=%s %s" % [label, _recovery_details(saved)])


func _recovery_details(saved: Dictionary) -> String:
	return "b2_open=%s stages=%d active_refuge=%s wallet=%d echo_amount=%d echo_node=%s echo_position=%s player_position=%s saved_echo_amount=%s saved_echo_position=%s saved_wallet=%s saved_flags=%s" % [
		str(loop.refuge_is_available()), rooms.completed_stage_count(), str(world.run_state.get_choice_flag("active_interior_refuge", "")), int(world.player.embers), int(world.run_state.lost_echo_amount),
		str(world.lost_echo), str(world.run_state.lost_echo_position), str(world.player.global_position), str((saved.get("lost_echo", {}) as Dictionary).get("amount", "missing")), str((saved.get("lost_echo", {}) as Dictionary).get("position", "missing")), str(saved.get("embers", "missing")), str(saved.get("choice_flags", {}))]


func _observe_live_ambush() -> bool:
	for enemy: Node3D in loop.threats.values():
		enemy.set_physics_process(true)
	var origin: Vector3 = interior_plan["origin"]
	var before := float(world.player.health)
	_live_watch = loop.threats[level_id + "/interior/ground_ambush"]
	_live_saw_attack = false
	if not await _walk_to(origin + Vector3(-18, 0, 18), "opened_door_a_approach"):
		return false
	if not await _walk_to(origin + Vector3(-18, 0, 16), "live_post_door_ambush_approach"):
		return false
	_release_input()
	var ambusher: Node3D = loop.threats[level_id + "/interior/ground_ambush"]
	var observed_attack := _live_saw_attack
	for frame in 480:
		observed_attack = observed_attack or int(ambusher.state) in [ambusher.State.WINDUP, ambusher.State.ACTIVE, ambusher.State.GRAB_WINDUP, ambusher.State.GRAB_ACTIVE]
		await _frames(1)
		if float(world.player.health) < before:
			break
	# Keep a captured pair live until its production release. Freezing the
	# attacker halfway through a grab would manufacture a route-state failure.
	for frame in 240:
		if int(ambusher.state) not in [ambusher.State.GRAB_WINDUP, ambusher.State.GRAB_ACTIVE] and int(world.player.state) != world.player.State.GRABBED:
			break
		await _frames(1)
	if not _expect(int(world.player.state) != world.player.State.GRABBED and int(ambusher.state) != ambusher.State.GRAB_ACTIVE, "Any observed live grab releases through its normal production lifecycle before freezing AI"):
		return false
	live_health_lost += maxf(0.0, before - float(world.player.health))
	_live_watch = null
	print("INTERIOR_SOULS_LIVE_AI level=%s observed_attack=%s health_lost=%.2f enemy_state=%d" % [level_id, str(observed_attack), before - float(world.player.health), int(ambusher.state)])
	_freeze_ai()
	return _expect(observed_attack and float(world.player.health) < before and float(world.player.health) > 0, "Live authored ambush actually attacks and damages the production player before route AI is frozen")


func _resolve_by_scene(index: int) -> bool:
	var stage: Dictionary = interior_plan["stages"][index]
	var shape := String((stage.get("visual_clue", {}) as Dictionary).get("shape", ""))
	var match_index := -1
	var matches := 0
	for motif: Dictionary in stage.get("option_visuals", []):
		if String(motif.get("shape", "")) == shape and not shape.is_empty():
			match_index = int(motif["option_index"])
			matches += 1
	if not _expect(matches == 1, "One visible option matches the receiver shape in stage " + str(index + 1)):
		return false
	if not await _walk_to(stage["controls_positions"][match_index], "match_visible_seal_floor_%d" % (index + 1)):
		return false
	if index == 2 and loop.top_guard_is_alive():
		if not await _interact(rooms.control_areas[index][match_index], "matched_seal_while_shield_guard_lives"):
			return false
		if not _expect(rooms.completed_stage_count() == 2, "The final matched seal stays closed while its real shield guard lives"):
			return false
		if not _expect(not bool(interior_plan.get("chamber_violation", false)), "The relocated third investigation must have encountered its guard during the earlier physical top-floor visit"):
			return false
		var origin: Vector3 = interior_plan["origin"]
		if not await _walk_to(origin + Vector3(-15, 12, 18), "top_guard_gallery_approach"):
			return false
		if not await _walk_to(origin + Vector3(-15, 12, 8), "top_guard_nearby_geometry_precondition"):
			return false
		if not _defeat_nearby_top_guard():
			return false
		if not await _walk_to(origin + Vector3(-15, 12, 18), "return_from_top_guard_along_gallery"):
			return false
		if not await _walk_to(stage["controls_positions"][match_index], "return_to_matched_top_seal"):
			return false
	if not await _interact(rooms.control_areas[index][match_index], "activate_matched_seal"):
		return false
	await _frames(48)
	print("INTERIOR_SOULS_STAGE level=%s stage=%d physical_floor=%d position=%s" % [level_id, index + 1, int(stage.get("floor", index)) + 1, str(world.player.global_position)])
	return _expect(rooms.completed_stage_count() == index + 1 and not bool(world.run_state.get_choice_flag(rooms.stage_flag(index, "clue"), false)), "Physical environmental answer resolves stage%d without reading the inscription" % (index + 1))


func _visit_revisit_record(kind: String) -> bool:
	if not _expect(revisit != null, "The production level owns its optional revisit interactions"):
		return false
	var record: Dictionary = {}
	for candidate: Dictionary in interior_plan.get("revisit_interactions", []):
		if String(candidate.get("kind", "")) == kind:
			record = candidate
			break
	if not _expect(not record.is_empty(), "Authored revisit data contains " + kind):
		return false
	var id := String(record["id"])
	if not _expect(revisit.interaction_areas.has(id), "Authored revisit record has a real sensor: " + id):
		return false
	if not await _walk_to(record["position"], "walk_to_" + kind):
		return false
	if not await _interact(revisit.interaction_areas[id], "examine_" + kind):
		return false
	var flag := String(record["flag"])
	if not _expect(flag.begins_with(level_id + "/") and bool(world.run_state.get_choice_flag(flag, false)), "Physical revisit input persists its scoped record: " + flag):
		return false
	print("INTERIOR_SOULS_REVISIT level=%s kind=%s flag=%s position=%s input=production" % [level_id, kind, flag, str(world.player.global_position)])
	return true


func _read_optional_scout() -> bool:
	var spec: Dictionary = interior_plan.get("stele_scout_reward", {})
	if not _expect(not spec.is_empty() and revisit != null and is_instance_valid(revisit.scout_copy), "The production scene contains the authored scout copy"):
		return false
	var copy_node: Node3D = revisit.scout_copy
	if not _expect(rooms.completed_stage_count() == 1 and not copy_node.visible, "Door A has opened without reading, before the optional scout window"):
		return false
	var stage: Dictionary = interior_plan["stages"][0]
	if not await _walk_to((stage["clue_position"] as Vector3) + Vector3(0, 0, 1.2), "return_to_optional_ground_inscription"):
		return false
	if not await _interact(rooms.clue_areas[0], "read_optional_inscription_after_opening_a"):
		return false
	var light := copy_node.get_node_or_null("WarmLight") as OmniLight3D
	if not _expect(copy_node.is_visible_in_tree() and light != null and light.is_visible_in_tree() and light.light_energy > 0 and copy_node.global_position.distance_to(level.to_global(spec["position"])) < .05, "The actual authored shelf copy and its warm light become visible at the authored position"):
		return false
	if not _expect(rooms.completed_stage_count() == 1 and bool(world.run_state.get_choice_flag(String(spec["flag"]), false)) and bool(world.run_state.get_choice_flag(String(spec["consumed_flag"]), false)), "Optional late reading records the single scout window without advancing another puzzle"):
		return false
	print("INTERIOR_SOULS_SCOUT level=%s actual_copy_visible=true warm_light=true duration_seconds=%.1f input=production position=%s" % [level_id, float(spec["duration_seconds"]), str(world.player.global_position)])
	return true


func _walk_second_ascent() -> bool:
	var route: Array = interior_plan["stages"][1]["to_next_route"]
	if not bool(interior_plan.get("chamber_violation", false)):
		return await _walk_points(route, "second_ascent")
	var memory: Dictionary = interior_plan.get("memory_return", {})
	if not _expect(memory.has("guard_approach"), "The relocated third investigation authors a physical first-visit guard approach"):
		return false
	var approach: Vector3 = memory["guard_approach"]
	var visited_guard := false
	for point: Vector3 in route:
		if not await _walk_to(point, "second_ascent_and_ground_return"):
			return false
		if point.distance_to(approach) < .05 and not visited_guard:
			if not _defeat_nearby_top_guard():
				return false
			visited_guard = true
	return _expect(visited_guard and not loop.top_guard_is_alive(), "The first top-floor visit actually reaches the guard before returning to the ground-floor investigation")


func _defeat_nearby_top_guard() -> bool:
	var guard: Node3D = loop.top_guard()
	if not _expect(is_instance_valid(guard) and loop.top_guard_is_alive(), "The geometry precondition uses the living production shield guard"):
		return false
	var guard_position: Vector3 = guard.global_position
	var distance: float = world.player.global_position.distance_to(guard_position)
	if not _expect(distance <= 4.0 and absf(world.player.global_position.y - guard.global_position.y) < .6 and world.player.is_on_floor(), "The real player reaches the guard's floor within4m before the labelled fatal payload: %.3fm" % distance):
		return false
	if not _expect(rooms.completed_stage_count() == 2 and int(rooms.stage_doors[2].collision_layer) == 1, "The final door is still physically closed at the first guard encounter"):
		return false
	guard.receive_hit_payload({"damage": 100000.0, "stagger": 0.0, "poise": 0.0, "direction": Vector3.ZERO, "source": world.player, "blockable": false, "parryable": false, "tags": ["contract_geometry_precondition"]})
	if not _expect(not loop.top_guard_is_alive() and rooms.completed_stage_count() == 2, "The explicit nearby fatal payload removes the guard without automatically solving the final investigation"):
		return false
	print("INTERIOR_SOULS_GEOMETRY_PRECONDITION level=%s top_guard=production_fatal_payload player_combat_victory=false ai=frozen distance_m=%.3f player_position=%s guard_position=%s" % [level_id, distance, str(world.player.global_position), str(guard_position)])
	return true


func _middle_gallery(to_south: bool) -> bool:
	var origin: Vector3 = interior_plan["origin"]
	var z_values := [-18, -12, 0, 12, 18] if to_south else [18, 12, 0, -12, -18]
	for z: int in z_values:
		if not await _walk_to(origin + Vector3(12, 6, z), "middle_east_gallery"):
			return false
	return true


func _b2_ride(up: bool, require_empty_call: bool) -> bool:
	var spec: Dictionary = souls_plan["b2_lift"]
	var owner_lift := level.get_node("InteriorRooms/InteriorReturnLift")
	var lift := owner_lift.get_node("PhysicalLiftRuntime")
	var landing: Vector3 = spec["lower_landing" if up else "upper_landing"]
	var dock: Vector3 = spec["lower_dock" if up else "upper_dock"]
	var origin_y := float(lift.lower_y if up else lift.upper_y)
	var destination := float(lift.upper_y if up else lift.lower_y)
	if not await _walk_to(landing, "b2_fixed_landing"):
		return false
	var absent := absf(lift.platform.position.y - origin_y) > .05
	if require_empty_call and not _expect(absent, "Reloaded B2 platform is absent and must be called from the lower landing"):
		return false
	if absent:
		if not await _interact(owner_lift.get_node("LowerLiftCall" if up else "UpperLiftCall"), "call_absent_b2_lift"):
			return false
		if not await _wait_for_lift(lift, origin_y, false, "b2_empty_platform_call"):
			return false
	if not await _walk_to(dock, "board_b2_platform"):
		return false
	if not await _interact(lift.platform.get_node("LiftRideInteract"), "ride_b2_platform"):
		return false
	if not await _wait_for_lift(lift, destination, true, "b2_platform_ride"):
		return false
	return await _walk_to(spec["upper_landing" if up else "lower_landing"], "leave_b2_platform")


func _check_annex() -> bool:
	var annex: Dictionary = souls_plan.get("annex", {})
	if not _expect(not annex.is_empty(), "04_03 reserves a supported foreign archive annex"):
		return false
	var origin: Vector3 = interior_plan["origin"]
	var center: Vector3 = annex["origin"]
	var side := signf(center.x - origin.x)
	var mouth := origin + Vector3(side * 18, 6, -18)
	if not await _walk_to(mouth, "archive_gallery_to_annex") or not await _walk_to(annex["entry"], "archive_annex_entry"):
		return false
	if not await _walk_to(center + Vector3(0, 0, 2.4), "foreign_archive_table_approach"):
		return false
	var letter: Area3D
	for area: Area3D in rooms.scene_readables:
		if String(rooms.scene_readables[area].get("kind", "")) == "foreign_letter":
			letter = area
	if not _expect(letter != null, "Foreign archive contains the physical contradictory letter"):
		return false
	if not await _interact(letter, "read_foreign_archive_letter"):
		return false
	if not await _walk_to(annex["entry"], "leave_foreign_archive") or not await _walk_to(mouth, "return_from_annex"):
		return false
	print("INTERIOR_SOULS_ANNEX_OK level=level_04_03 input=production physical_letter=true")
	return true


func _walk_points(points: Array, label: String) -> bool:
	for point: Vector3 in points:
		if not await _walk_to(point, label):
			return false
	return true


func _frames(count: int) -> void:
	await super._frames(count)
	if is_instance_valid(_live_watch):
		_live_saw_attack = _live_saw_attack or int(_live_watch.state) in [_live_watch.State.WINDUP, _live_watch.State.ACTIVE, _live_watch.State.GRAB_WINDUP, _live_watch.State.GRAB_ACTIVE]
	if _wall_deadline > 0 and Time.get_ticks_msec() > _wall_deadline:
		_release_input()
		push_error("Interior souls traversal exceeded its30 minute wall-clock budget")
		quit(1)


func _requested_levels() -> Array[String]:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--levels"):
			return super._requested_levels()
	return ["level_01_02"]
