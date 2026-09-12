extends SceneTree
## Production player, collision, interaction input and moving platform.
## AI is frozen. Each level has one documented inspection placement at the
## district entry; every subsequent route/ramp/deck transition uses real input.
## This is a bounded traversal contract, not a continuous new-game playthrough.
## Run with --fixed-fps 60 and optionally -- --levels=01_01,01_02,04_01.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const RunState = preload("res://scripts/core/run_state.gd")
const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

class AuditWorld extends "res://scripts/game_world.gd":
	var saved_snapshot: Dictionary = {}
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(_reason: String) -> bool:
		saved_snapshot = _snapshot_run_state()
		return true

var world: AuditWorld
var level: Node3D
var expansion: Dictionary
var level_id := ""
var failures: Array[String] = []
var checks := 0
var walked_waypoints := 0
var physics_steps := 0
var completed_levels := 0
var actual_lift_rides := 0
var measured_distance := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Traversal uses production time scale 1.0")
	_expect(Engine.physics_ticks_per_second == 60, "Traversal uses production 60 Hz physics")
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
		if not await _check_level():
			break
		completed_levels += 1
	_release_input()
	world._clear_enemies()
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_EXPANSION_TRAVERSAL_OK checks=%d levels=%d waypoints=%d distance_m=%.1f lift_rides=%d physics_frames=%d ai=frozen entry=inspection input=production_actions time_scale=1" % [checks, completed_levels, walked_waypoints, measured_distance, actual_lift_rides, physics_steps])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_level() -> bool:
	_release_input()
	if not _expect(world._load_campaign_level(StringName(level_id)), "Load production level " + level_id):
		return false
	_freeze_ai()
	level = world.campaign_runtime.current_level
	expansion = level.get_meta("expansion", {})
	if not _expect(not expansion.is_empty(), level_id + " has a playable expansion plan"):
		return false
	await _frames(8)
	var route: Array = expansion["traversal_route"]
	var gate_plan: Dictionary = expansion["return_gate"]
	var lift_plan: Dictionary = expansion["lift"]
	if not _expect(not gate_plan.is_empty() and not lift_plan.is_empty(), level_id + " is a non-boss gate/lift traversal case"):
		return false
	var gate := level.get_node("ShortcutFold/OneWayDoor") as Node3D
	var latch := gate.get_node("OneWayFarInteract") as Area3D
	var gate_index := _nearest_index(route, gate_plan["position"])
	var overlook_index := _nearest_index(route, expansion["overlook"])
	var gate_direction: Vector3 = (gate_plan["far_side"] - gate_plan["position"])
	gate_direction.y = 0
	gate_direction = gate_direction.normalized()
	var near_gate: Vector3 = gate_plan["position"] - gate_direction * 1.7
	var far_gate: Vector3 = gate_plan["position"] + gate_direction * 1.7
	# A remote direct callback probes the execution guard independently of UI.
	latch.interact(world.player)
	_expect(not bool(gate.get_meta("is_open", false)), level_id + " rejects remote latch activation from the shrine")
	# Reach the barred face through its real shrine-side route before the one
	# allowed inspection placement establishes this test's branch-entry start.
	for index in range(route.size() - 1, gate_index, -1):
		if not await _walk_to(route[index], "shrine_to_barred_gate"):
			return false
	if not await _walk_to(near_gate, "closed_near_face"):
		return false
	latch.interact(world.player)
	_expect(not bool(gate.get_meta("is_open", false)), level_id + " rejects wrong-side latch use at actual interaction distance")
	for frame in 150:
		_drive_toward(level.to_global(far_gate))
		await _frames(1)
	_release_input()
	await _frames(10)
	var near_position := level.to_local(world.player.global_position)
	_expect((near_position - gate_plan["position"]).dot(gate_direction) < -.35,
		level_id + " closed gate physically prevents the player crossing from shrine side: " + str(near_position))
	if not failures.is_empty():
		return false
	var entry: Vector3 = expansion["entry"]
	world.player.respawn_at(level.to_global(entry + Vector3.UP * .1))
	await _frames(30)
	if not _expect(world.player.is_on_floor() and _horizontal_distance(world.player.global_position, level.to_global(entry)) < 1.0,
		level_id + " inspection start is grounded at the authored mid-route branch entry"):
		return false
	print("EXPANSION_TRAVERSAL_START level=%s entry=%s ai=frozen inspection_placements=1" % [level_id, str(world.player.global_position)])
	for index in range(overlook_index + 1):
		if not await _walk_to(route[index], "entry_to_overlook"):
			return false
	_expect(absf(world.player.global_position.y - level.to_global(expansion["overlook"]).y) < .6,
		level_id + " production capsule reaches the elevated overlook through physical ramps")
	var spur: Array = expansion["reward_spur"]
	for point: Vector3 in spur:
		if not await _walk_to(point, "reward_spur"):
			return false
	var district := level.get_node("CampaignExpansionRuntime")
	var reward: Dictionary = expansion["rewards"][0]
	var reward_id := String(reward["id"])
	var cache := district.reward_areas.get(reward_id) as Area3D
	if not _expect(cache != null, level_id + " unused cache exists at the risk/reward spur"):
		return false
	var before_embers := int(world.player.embers)
	if not await _interact(cache, "reward_cache"):
		return false
	_expect(int(world.player.embers) == before_embers + int(reward["embers"]), level_id + " actual input acquires its finite branch reward")
	for index in range(spur.size() - 2, -1, -1):
		if not await _walk_to(spur[index], "reward_spur_return"):
			return false
	print("EXPANSION_TRAVERSAL_OVERLOOK level=%s position=%s reward=%d" % [level_id, str(world.player.global_position), int(reward["embers"])])
	var lift_route: Array = expansion["lift_route"]
	for point: Vector3 in lift_route:
		if not await _walk_to(point, "upper_lift_approach"):
			return false
	var elevator := level.get_node("ShortcutFold/ElevatorLift") as Node3D
	var lift := elevator.get_node("PhysicalLift")
	var platform: AnimatableBody3D = lift.platform
	if not await _walk_to(lift_plan["upper_dock"], "board_upper_deck"):
		return false
	if not await _interact(platform.get_node("LiftRideInteract"), "ride_down"):
		return false
	if not await _wait_for_lift(lift, float(lift.lower_y), true, "first_descent"):
		return false
	if not await _walk_to(lift_plan["lower_landing"], "walk_off_lower_deck"):
		return false
	_expect(world.player.is_on_floor(), level_id + " rider walks onto the lower fixed landing")
	# Leave the platform upstairs by riding it back, then take the long stair
	# route down. This sets up a genuinely absent-platform lower-call case.
	if not await _walk_to(lift_plan["lower_dock"], "board_lower_deck"):
		return false
	if not await _interact(platform.get_node("LiftRideInteract"), "ride_up"):
		return false
	if not await _wait_for_lift(lift, float(lift.upper_y), true, "return_ascent"):
		return false
	if not await _walk_to(lift_plan["upper_landing"], "walk_off_upper_deck"):
		return false
	for index in range(lift_route.size() - 2, -1, -1):
		if not await _walk_to(lift_route[index], "return_from_upper_lift"):
			return false
	var lower_branch_index := _nearest_index(route, lift_plan["lower_exit"])
	for index in range(overlook_index + 1, lower_branch_index + 1):
		if not await _walk_to(route[index], "outer_descent_stair"):
			return false
	if not await _walk_to(lift_plan["lower_landing"], "lower_call_approach"):
		return false
	var waiting_position: Vector3 = world.player.global_position
	if not _expect(absf(platform.position.y - float(lift.upper_y)) < .05, level_id + " empty platform remains upstairs while player takes the side stair"):
		return false
	if not await _interact(elevator.get_node("LowerLiftCall"), "call_from_lower_landing"):
		return false
	if not await _wait_for_lift(lift, float(lift.lower_y), false, "lower_landing_call"):
		return false
	_expect(world.player.global_position.distance_to(waiting_position) < .4 and world.player.is_on_floor(),
		level_id + " calling from fixed lower landing moves only the empty platform")
	if not await _walk_to(lift_plan["lower_exit"], "lower_lift_exit"):
		return false
	for index in range(lower_branch_index + 1, gate_index):
		if not await _walk_to(route[index], "return_route_to_far_latch"):
			return false
	if not await _walk_to(far_gate, "far_latch"):
		return false
	if not await _interact(latch, "open_return_gate"):
		return false
	await _frames(90)
	_expect(bool(gate.get_meta("is_open", false)), level_id + " latch opens only after reaching its far side")
	if not await _walk_to(near_gate, "cross_open_gate"):
		return false
	for index in range(gate_index + 1, route.size()):
		if not await _walk_to(route[index], "return_to_shrine"):
			return false
	if not await _walk_to(level.to_local(world.checkpoint.global_position) + Vector3(0, 0, 2), "shrine_after_loop"):
		return false
	world._save_run("expansion_traversal_audit")
	var serialized: Dictionary = world.saved_snapshot.duplicate(true)
	var restored = RunState.from_dictionary(serialized)
	if not _expect(restored != null, level_id + " production save snapshot validates after traversal"):
		return false
	_expect(String(gate_plan["id"]) in restored.activated_shortcuts and String(lift_plan["id"]) in restored.activated_shortcuts,
		level_id + " gate and discovered lift both persist through the actual save schema")
	world._apply_run_state(restored)
	_freeze_ai()
	await _frames(12)
	level = world.campaign_runtime.current_level
	gate = level.get_node("ShortcutFold/OneWayDoor")
	lift = level.get_node("ShortcutFold/ElevatorLift/PhysicalLift")
	_expect(bool(gate.get_meta("is_open", false)) and bool(lift.unlocked), level_id + " real load restores open gate and lower-call access")
	_expect(level.get_node("CampaignExpansionRuntime").reward_areas.is_empty(), level_id + " saved reward cannot respawn after the traversal reload")
	# Revisit and cross the restored gate using locomotion rather than accepting
	# metadata alone as proof that its raised collider restored correctly.
	for index in range(route.size() - 1, gate_index, -1):
		if not await _walk_to(route[index], "reload_shrine_to_gate"):
			return false
	if not await _walk_to(far_gate, "cross_saved_open_gate"):
		return false
	print("EXPANSION_TRAVERSAL_LEVEL_OK level=%s waypoints=%d physics_frames=%d" % [level_id, walked_waypoints, physics_steps])
	return failures.is_empty()


func _walk_to(local_target: Vector3, label: String) -> bool:
	var target := level.to_global(local_target)
	var initial_distance: float = world.player.global_position.distance_to(target)
	var best_distance := initial_distance
	var no_progress_frames := 0
	var budget := maxi(900, int(ceil(initial_distance * 90.0)))
	for frame in budget:
		var at: Vector3 = world.player.global_position
		var distance := at.distance_to(target)
		if _horizontal_distance(at, target) < .48 and absf(at.y - target.y) < .55:
			_release_input()
			await _frames(6)
			walked_waypoints += 1
			return _expect(world.player.is_on_floor(), "%s %s ends on a real floor at %s" % [level_id, label, str(world.player.global_position)])
		if float(world.player.health) <= 0 or at.y < target.y - 5.0:
			return _movement_failure(label, target, "fell or died", frame)
		if distance < best_distance - .2:
			best_distance = distance
			no_progress_frames = 0
		else:
			no_progress_frames += 1
		if no_progress_frames > 360:
			return _movement_failure(label, target, "stuck", frame)
		_drive_toward(target)
		await _frames(1)
	return _movement_failure(label, target, "waypoint timeout", budget)


func _drive_toward(target: Vector3) -> void:
	var direction: Vector3 = target - world.player.global_position
	direction.y = 0
	direction = direction.normalized()
	var forward: Vector3 = -world.player.camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right: Vector3 = world.player.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	var x := direction.dot(right)
	var y := direction.dot(forward)
	_set_action("move_left", maxf(-x, 0))
	_set_action("move_right", maxf(x, 0))
	_set_action("move_forward", maxf(y, 0))
	_set_action("move_back", maxf(-y, 0))


func _set_action(action: String, strength: float) -> void:
	if strength > .001:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _interact(expected: Node, label: String) -> bool:
	_release_input()
	await _frames(8)
	world._update_interaction_target()
	if not _expect(world.player.interaction_target == expected,
		"%s %s actual scanner target=%s expected=%s player=%s" % [level_id, label, str(world.player.interaction_target), str(expected), str(world.player.global_position)]):
		return false
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	return true


func _wait_for_lift(lift: Node, expected_y: float, riding: bool, label: String) -> bool:
	_release_input()
	if not _expect(bool(lift.moving), level_id + " " + label + " production interaction starts platform motion"):
		return false
	var platform: AnimatableBody3D = lift.platform
	var start_y := platform.global_position.y
	var worst_rider_offset := 0.0
	for frame in 1800:
		await _frames(1)
		if riding:
			var feet_offset: float = absf(world.player.global_position.y - (platform.global_position.y + .175))
			worst_rider_offset = maxf(worst_rider_offset, feet_offset)
			if feet_offset > .8:
				return _movement_failure(label, platform.global_position + Vector3.UP * .175, "player lost moving platform", frame)
		if not bool(lift.moving):
			await _frames(8)
			_expect(absf(platform.position.y - expected_y) < .03, level_id + " " + label + " reaches the physical target landing")
			_expect(absf(platform.global_position.y - start_y) > 2, level_id + " " + label + " actually travels between separate elevations")
			if riding:
				actual_lift_rides += 1
				_expect(world.player.is_on_floor() and worst_rider_offset < .8, level_id + " " + label + " carries the real production capsule without teleportation")
			return failures.is_empty()
	return _movement_failure(label, platform.global_position, "lift motion timeout", 1800)


func _movement_failure(label: String, target: Vector3, reason: String, frames: int) -> bool:
	_release_input()
	var colliders: Array[String] = []
	for index in world.player.get_slide_collision_count():
		var collision: KinematicCollision3D = world.player.get_slide_collision(index)
		colliders.append(str(collision.get_collider()))
	return _expect(false, "%s %s %s frames=%d position=%s target=%s velocity=%s floor=%s colliders=%s" %
		[level_id, label, reason, frames, str(world.player.global_position), str(target), str(world.player.velocity), str(world.player.is_on_floor()), str(colliders)])


func _nearest_index(points: Array, target: Vector3) -> int:
	var best := 0
	var distance := INF
	for index in points.size():
		var candidate: float = points[index].distance_to(target)
		if candidate < distance:
			best = index
			distance = candidate
	return best


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _freeze_ai() -> void:
	for enemy in world.enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
	world.player.set_physics_process(true)


func _release_input() -> void:
	for action: String in MOVE_ACTIONS:
		Input.action_release(action)
	Input.action_release("interact")


func _frames(count: int) -> void:
	for index in count:
		var before: Vector3 = world.player.global_position if is_instance_valid(world) and is_instance_valid(world.player) else Vector3.ZERO
		await physics_frame
		await process_frame
		physics_steps += 1
		if is_instance_valid(world) and is_instance_valid(world.player):
			measured_distance += world.player.global_position.distance_to(before)


func _requested_levels() -> Array[String]:
	var result: Array[String] = ["level_01_01", "level_01_02", "level_04_01"]
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		var raw := ""
		if arguments[index].begins_with("--levels="):
			raw = arguments[index].trim_prefix("--levels=")
		elif arguments[index] == "--levels" and index + 1 < arguments.size():
			raw = arguments[index + 1]
		if not raw.is_empty():
			result.clear()
			for value: String in raw.split(",", false):
				var id := value.strip_edges()
				result.append(id if id.begins_with("level_") else "level_" + id)
	return result


func _expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok
