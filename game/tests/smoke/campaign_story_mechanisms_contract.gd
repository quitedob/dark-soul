extends SceneTree
## Actual world loads, physics queries, production damage receivers and local
## trial FSMs. Only save I/O is replaced; no user state is read or written.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const Mechanisms = preload("res://scripts/world/campaign_story_mechanisms.gd")
const Ambush = preload("res://scripts/enemy/behaviors/ambush_behavior.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const CombatData = preload("res://scripts/data/player_combat_data.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	var saves: Array[String] = []
	func _load_initial_state() -> void: _apply_settings()
	func _save_run(reason: String) -> bool:
		saves.append(reason)
		return true

var world: AuditWorld
var controller: Node3D
var failures: Array[String] = []
var checks := 0


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	world = AuditWorld.new()
	var scene := WorldScene.instantiate()
	for child in scene.get_children():
		child.owner = null
		scene.remove_child(child)
		world.add_child(child)
	scene.free()
	root.add_child(world)
	world.set_process(false)
	Engine.time_scale = 4.
	if "--connections-only" in OS.get_cmdline_user_args():
		await _field_route_connections()
		await _load("level_05_02")
		await _inversion()
		world.free()
		await process_frame
		Engine.time_scale = 1.
		if failures.is_empty():
			print("ASHEN_STORY_FIELD_CONNECTIONS_INPUT_OK checks=%d" % checks)
			quit(0)
		else:
			for failure in failures: push_error(failure)
			quit(1)
		return
	if "--maze-only" in OS.get_cmdline_user_args():
		await _load("level_03_05")
		await _maze()
		world.free()
		await process_frame
		Engine.time_scale = 1.
		if failures.is_empty():
			print("ASHEN_STORY_NINE_MAZES_INPUT_OK checks=%d" % checks)
			quit(0)
		else:
			for failure in failures: push_error(failure)
			quit(1)
		return
	if "--inversion-only" in OS.get_cmdline_user_args():
		await _load("level_05_02")
		await _inversion()
		world.free()
		await process_frame
		Engine.time_scale = 1.
		if failures.is_empty():
			print("ASHEN_STORY_FOUR_ANCHORS_INPUT_OK checks=%d" % checks)
			quit(0)
		else:
			for failure in failures: push_error(failure)
			quit(1)
		return
	if "--ambush-only" in OS.get_cmdline_user_args() or "--lake-and-ambush" in OS.get_cmdline_user_args():
		for enemy in world.enemies: enemy.set_physics_process(false)
		world.player.set_physics_process(false)
		if "--lake-and-ambush" in OS.get_cmdline_user_args():
			await _load("level_03_04")
			await _reflection()
		await _ambush()
		world.free()
		await process_frame
		Engine.time_scale = 1.
		if failures.is_empty():
			print("ASHEN_STORY_LAKE_AMBUSH_PHYSICS_OK checks=%d" % checks)
			quit(0)
		else:
			for failure in failures: push_error(failure)
			quit(1)
		return
	var focused := "--focused" in OS.get_cmdline_user_args()
	if not focused:
		await _load("level_03_03")
		await _procession()
		await _load("level_03_04")
		await _reflection()
	await _load("level_03_05")
	await _maze()
	if not focused:
		await _load("level_05_02")
		await _inversion()
	await _load("level_05_04")
	await _trials()
	if not focused: await _field_route_connections()
	await _ambush()
	world.free()
	await process_frame
	Engine.time_scale = 1.
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_STORY_MECHANISMS_OK levels=%d maze_routes=9 checks=%d" % [3 if focused else 5,checks])
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)


func _load(id: String, expect_blocked := true) -> void:
	_expect(world._load_campaign_level(StringName(id)), "Actual world loads " + id)
	controller = world.campaign_runtime.current_level.get_node_or_null("StoryMechanisms")
	_expect(controller != null, id + " activates its scene-owned controller")
	for enemy in world.enemies: enemy.set_physics_process(false)
	world.player.set_physics_process(false)
	await _frames(4)
	_expect(not String(controller.exit_block_reason()).is_empty() if expect_blocked else String(controller.exit_block_reason()).is_empty(), id + " restores the fixture's earned/unearned exit state")
	var navigation: NavigationRegion3D = world.campaign_runtime.current_level.get_node("NavigationSurface")
	for frame in 180:
		if bool(navigation.get_meta("bake_complete", false)): break
		await process_frame


func _interact(key: String) -> void:
	var area: Node3D = controller.get_node(key)
	world.player.global_position = area.global_position + world.player.up_direction * .08
	world.player.velocity = Vector3.ZERO
	area.interact(world.player)
	await _frames(2)


func _procession() -> void:
	var wedding: Node3D = controller.get_node("MovingWedding")
	var original := wedding.position
	world.player.global_position = wedding.global_position + Vector3(0, .05, 5)
	await _frames(50)
	_expect(wedding.position.distance_to(original) > 1., "Imported wedding actually moves along the route")
	_expect(float(controller.snapshot()["followed_seconds"]) > 2., "Following behind accumulates an unseen escort")
	await _interact("lantern_1")
	_expect(int(controller.snapshot()["progress"]) == 0, "Wrong guiding lamp cannot earn progression")
	# Remain behind the moving party while it passes each actual lamp.
	for index in 3:
		var lamp: Node3D = controller.get_node("lantern_%d" % index)
		for frame in 550:
			world.player.global_position = wedding.global_position + Vector3(0,.05,4)
			await _frames(1)
			if wedding.global_position.z < lamp.global_position.z - 2.: break
		await _interact("lantern_%d" % index)
	_expect(controller.complete, "Unseen ordered escort earns the wedding objective")
	_expect(world.run_state.get_choice_flag("field_03_03_complete", false), "Wedding completion persists")
	var saved := world.saves.size()
	await _interact("lantern_2")
	_expect(world.saves.size() == saved, "Completed wedding cannot award duplicate saves/rewards")
	# A fresh attempt detects the front of the procession and spawns a real foe.
	world.run_state.set_choice_flag("field_03_03_complete", false)
	await _load("level_03_03")
	wedding = controller.get_node("MovingWedding")
	world.player.global_position = wedding.global_position + Vector3(0,.05,-2)
	await _frames(2)
	_expect(bool(controller.snapshot()["procession_seen"]), "Walking into the bearers' gaze fails stealth")
	_expect(not controller._actors.is_empty(), "Detected procession produces an actual pursuing enemy")
	_expect(not world.run_state.get_choice_flag("field_03_03_complete", false), "Detection grants no completion")


func _reflection() -> void:
	var solid := _ray(Vector3(-6, 1, -60), Vector3(-6, -1, -60))
	var false_path := _ray(Vector3(6, 1, -60), Vector3(6, -1, -60))
	_expect(not solid.is_empty() and solid["collider"].get_meta("reflection_solid", false), "True reflection stone has real support")
	_expect(false_path.is_empty(), "False lake tile has no hidden supporting floor")
	var true_columns := [[0],[0,1],[1],[1,2],[2]]
	for row in 5:
		for column in 3:
			var at := Vector3(-6+column*6,0,-60-row*6)
			var support := _ray(at+Vector3.UP*.08,at+Vector3.DOWN*.14)
			_expect(not support.is_empty() if true_columns[row].has(column) else support.is_empty(), "Connecting the far shore preserves true/false stone support at %s" % at)
	for corner: Vector3 in [Vector3(-5.1,0,-77.1),Vector3(5.1,0,-66.9)]:
		_expect(_ray(corner+Vector3.UP*.08,corner-Vector3.UP*.14).is_empty(), "Pavilion column piers preserve false water beneath empty roof corners")
	_expect(controller._reflection_enemies.size() == 3, "Lake has its three actual Water Moon spirits")
	for actor: Node3D in controller._reflection_enemies:
		var support := _ray(actor.global_position+Vector3.UP*.2,actor.global_position+Vector3.DOWN*.3)
		_expect(not support.is_empty() and support["collider"].get_meta("reflection_solid",false), "Authored Water Moon has a true stone at %s (hit %s)" % [actor.global_position,support.get("collider")])
		_expect(String(actor.content_id) == "water_moon_spirit" and actor.has_meta("story_damage_gate"), "Only the actual reflected enemy receives the hit policy")
	for actor in world.enemies:
		if String(actor.content_id) == "elite_reflection_lord":
			_expect(not actor.has_meta("story_damage_gate"), "Shore elite remains damageable outside the reflection course")
	var reflection: Node3D = controller._reflection_enemies[0]
	var hp := float(reflection.get("health"))
	reflection.receive_hit_payload({"damage": 1., "stagger": 0., "source": world.player})
	_expect(is_equal_approx(float(reflection.get("health")), hp), "Unrevealed reflection cannot be damaged")
	await _interact("reflection_mirror")
	# This traversal fixture isolates terrain; enemy damage policy is exercised
	# above/below, while the real imported actors remain present in the scene.
	for actor in world.enemies: actor.set_physics_process(false)
	world.player.global_position = Vector3(-6, .05, -60)
	await _frames(2)
	reflection.receive_hit_payload({"damage": 1., "stagger": 0., "source": world.player})
	_expect(float(reflection.get("health")) < hp, "Standing on the revealed real path admits an actual hit")
	world.player.global_position = Vector3(6, -1, -60)
	await _frames(2)
	_expect(world.player.global_position.distance_to(Vector3(-6,.1,-54)) < .2, "Falling through a false reflection resets to the shore")
	_expect(int(controller.snapshot()["reflection_stage"]) == 0, "False route discards partial progress")
	var previous := Vector3(-6,.05,-54)
	# Turn into the existing court before its gate; the gate's right pillar is
	# close to X=6, while its real center opening is at X=0.
	var route: Array[Vector3] = [Vector3(-6,.05,-60), Vector3(-6,.05,-66), Vector3(0,.05,-66), Vector3(0,.05,-72), Vector3(0,.05,-78), Vector3(6,.05,-78), Vector3(6,.05,-84), Vector3(6,.05,-90), Vector3(6,.05,-96), Vector3(6,.05,-102), Vector3(0,.05,-102), Vector3(0,.05,-108), Vector3(0,.05,-114)]
	for point: Vector3 in route:
		var obstruction := KinematicCollision3D.new()
		var blocked: bool = world.player.test_move(Transform3D(Basis.IDENTITY, previous),point-previous,obstruction)
		if blocked: print("LAKE_ROUTE_OBSTRUCTION ",previous," -> ",point," collider=",obstruction.get_collider().get_path()," at=",obstruction.get_position())
		_expect(not blocked, "Actual player capsule has a clear connected lake segment %s -> %s" % [previous,point])
		for step in 13:
			var sample: Vector3 = previous.lerp(point,float(step)/12.)
			_expect(not _ray(sample+Vector3.UP*.5,sample+Vector3.DOWN*.3).is_empty(), "Lake route continuously supports the capsule at %s" % sample)
		previous = point
	await _walk_reflection_course(route)
	_expect(controller.complete and int(controller.snapshot()["progress"]) == 5, "Real movement across all five rows earns the lake route")
	var far_shore := _ray(world.player.global_position+Vector3.UP*.3,world.player.global_position+Vector3.DOWN*.3)
	_expect(world.player.global_position.z < -112. and not far_shore.is_empty() and String(far_shore["collider"].name).begins_with("Tile_"), "WASD continues beyond completion onto the original opposite shore")
	var level: Node3D = world.campaign_runtime.current_level
	controller.queue_free()
	await _frames(3)
	var restored := _ray(Vector3(6,1,-60), Vector3(6,-1,-60))
	_expect(not restored.is_empty() and String(restored["collider"].name).begins_with("Tile_"), "Removing controller restores suspended terrain")
	_expect(level.get_node_or_null("StoryMechanisms") == null, "Controller fully unloads")
	_expect(not _ray(Vector3(6,1,-85),Vector3(6,1,-89)).is_empty(), "Removing the controller restores the original southern boundary rail")
	_expect(_ray(Vector3(6,.2,-90),Vector3(6,-.2,-90)).is_empty(), "Controller-owned shore connection unloads with the puzzle")


func _walk_reflection_course(route: Array[Vector3]) -> void:
	# Start at the production false-step recovery point. No position or velocity
	# assignment occurs during this run: actual action input drives move_and_slide.
	var player = world.player
	player.set_camera_director_override(true)
	player.camera_rig.rotation = Vector3.ZERO
	player.camera_pitch.rotation.x = -.25
	player.set_physics_process(true)
	await _frames(3)
	var lowest_y: float = player.global_position.y
	var reached := 0
	for target: Vector3 in route:
		var arrived := false
		for frame in 150:
			var offset: Vector3 = target-player.global_position
			if Vector2(offset.x,offset.z).length() < .45:
				arrived = true
				break
			for action: String in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
			if absf(offset.x) > .3: Input.action_press("move_right" if offset.x > 0. else "move_left")
			if absf(offset.z) > .3: Input.action_press("move_back" if offset.z > 0. else "move_forward")
			await _frames(1)
			lowest_y = minf(lowest_y,player.global_position.y)
		for action: String in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
		_expect(arrived, "Production WASD reaches lake/shore waypoint %s; actual=%s" % [target,player.global_position])
		if not arrived: break
		reached += 1
	await _frames(4)
	_expect(reached == route.size() and lowest_y > -.2 and player.is_on_floor(), "Continuous capsule traversal reaches the opposite shore without falling, reset or teleport")
	print("LAKE_WASD_TRAVERSAL reached=",reached,"/",route.size()," final=",player.global_position," lowest_y=",lowest_y)
	player.set_physics_process(false)
	player.set_camera_director_override(false)


func _maze() -> void:
	await _walk_connection_fixture(Vector3(0,.05,-24),[Vector3(0,0,-33)],"maze original entrance")
	await _load("level_03_05")
	var routes: Dictionary = {}
	for entry in 9:
		if entry > 0:
			world.run_state.set_choice_flag("field_03_05_complete",false)
			await _load("level_03_05")
		# A fresh entry-facing fixture selects each configuration. Thereafter
		# only actual WASD/E input moves through questions, gates and the shore.
		world.player.global_position = Vector3(0,.05,-33)
		world.player.rotation.y = -PI + (float(entry) + .5) * TAU / 9.
		world.player.body_yaw.rotation.y = 0.
		await _frames(2)
		_expect(int(controller.snapshot()["maze_configuration"]) == entry, "Maze reads actual BodyYaw entry facing %d" % entry)
		world.player.set_camera_director_override(true)
		world.player.camera_rig.rotation = Vector3.ZERO
		world.player.camera_pitch.rotation.x = -.25
		world.player.set_physics_process(true)
		await _frames(4)
		var route: Array[int] = []
		for row in 3:
			await _walk_on_surface(Vector3(-5+row*5,0,-35.6-row*12))
			await _press_story_interaction("riddle_%d_%d" % [row,row])
			_expect(controller.progress == row+1, "Configuration %d accepts actual E answer for row %d" % [entry,row])
			var openings: Array[int] = []
			for column in 3:
				var x := float(-6 + column * 6)
				var z := float(-42 - row * 12)
				var hit := _ray(Vector3(x,1,z+2), Vector3(x,1,z-2))
				if hit.is_empty(): openings.append(column)
			_expect(openings.size() == 1, "Configuration %d row %d has exactly one physically open passage" % [entry,row])
			if openings.size() == 1:
				route.append(openings[0])
				var from := Transform3D(Basis.IDENTITY, Vector3(-6 + openings[0]*6, .06, -40-row*12))
				_expect(not world.player.test_move(from, Vector3(0,0,-4)), "Production capsule fits the solved maze opening")
				await _walk_on_surface(Vector3(-6+openings[0]*6,0,-39-row*12))
				if row == 2: _expect(not controller.complete, "Three answers do not complete configuration %d before its last gate is crossed" % entry)
				await _walk_on_surface(Vector3(-6+openings[0]*6,0,-45-row*12 if row < 2 else -72))
		routes[str(route)] = true
		for point: Vector3 in [Vector3(0,0,-72),Vector3(0,0,-84),Vector3(0,0,-96),Vector3(0,0,-108)]:
			await _walk_on_surface(point)
		var at: Vector3 = world.player.global_position
		var shore := _ray(at+Vector3.UP*.3,at+Vector3.DOWN*.3)
		_expect(controller.complete and at.z < -106. and not shore.is_empty() and String(shore["collider"].name).begins_with("Tile_"), "Configuration %d earns completion and physically walks onto original southern terrain" % entry)
		print("MAZE_WASD_EXIT configuration=",entry," lanes=",route," final=",at," complete=",controller.complete)
		world.player.set_physics_process(false)
		world.player.set_camera_director_override(false)
	_expect(routes.size() == 9, "Nine entry directions produce nine distinct physical routes")
	world.run_state.set_choice_flag("field_03_05_complete",false)
	await _load("level_03_05")
	world.player.global_position = Vector3(0,.05,-33)
	await _frames(2)
	var before := int(controller.snapshot()["maze_configuration"])
	await _interact("riddle_0_2")
	_expect(int(controller.snapshot()["maze_configuration"]) != before and not controller._actors.is_empty(), "Wrong answer shifts geometry and returns a real foe")
	_expect(not controller.complete, "Wrong riddle never earns completion")


func _inversion() -> void:
	# Place the initial fixture on its real floor, then use production movement,
	# sensor-selected E input and gravity for the entire four-anchor traversal.
	# The generic _interact helper places feet at the raised interaction Area,
	# which previously hid capsule penetration when turning from a grounded pose.
	var player = world.player
	player.global_position = Vector3(0,8.05,-96)
	player.velocity = Vector3.ZERO
	player.set_camera_director_override(true)
	player.camera_rig.rotation = Vector3.ZERO
	player.camera_pitch.rotation.x = -.25
	player.set_physics_process(true)
	await _frames(8)
	for at: Vector3 in [Vector3(0,8,-102),Vector3(-12,8,-102),Vector3(-12,8,-106)]:
		await _walk_on_surface(at)
	_expect(player.is_on_floor() and absf(player.global_position.y-8.) < .05, "First anchor is activated from actual grounded feet, not an airborne fixture")
	await _press_anchor(0)
	_expect(world.player.up_direction == Vector3.DOWN, "First anchor reverses actual player gravity")
	await _frames(65)
	_expect(world.player.is_on_floor() and absf(world.player.global_position.y - 16.) < .15, "Player physically lands on authored ceiling from first anchor")
	_expect(world.player.global_basis.y.dot(Vector3.DOWN) > .99, "Inverted body follows the ceiling")
	await _walk_on_surface(Vector3(-12,16,-118))
	await _press_anchor(1)
	await _walk_on_surface(Vector3(12,16,-118))
	await _press_anchor(2)
	_expect(world.player.up_direction == Vector3.UP, "Third anchor restores downward gravity")
	await _frames(65)
	_expect(world.player.is_on_floor() and absf(world.player.global_position.y - 8.) < .15, "Player returns to actual upper-storey floor")
	# Walk around the standing arch's right pillar, using the open center court.
	for at: Vector3 in [Vector3(0,8,-118),Vector3(0,8,-130),Vector3(12,8,-130)]:
		await _walk_on_surface(at)
	await _press_anchor(3)
	_expect(controller.complete, "Four ordered anchors earn the inversion objective")
	for at: Vector3 in [Vector3(0,8,-130),Vector3(0,8,-144)]: await _walk_on_surface(at)
	_expect(player.global_position.z < -142., "Completed inversion walks back onto the original exit court")
	print("FOUR_ANCHORS_INPUT final=",player.global_position," progress=",controller.progress," up=",player.up_direction)
	player.set_physics_process(false)
	player.set_camera_director_override(false)
	# A new unsolved attempt must also restore gravity on death and rearm after respawn.
	world.run_state.set_choice_flag("field_05_02_complete", false)
	await _load("level_05_02")
	await _interact("anchor_0")
	world.player.receive_hit_payload({"damage": 10000., "stagger": 10000., "blockable": false, "parryable": false})
	await _frames(2)
	_expect(world.player.up_direction == Vector3.UP and controller._dead, "Death immediately restores gravity and suspends puzzle ticks")
	await _frames(45)
	_expect(not controller._dead and world.player.health > 0., "Actual world respawn rearms retained controller")
	await _interact("anchor_0")
	_expect(world.player.up_direction == Vector3.DOWN, "Retained controller can start a new attempt after death")
	await _load("level_05_04")
	_expect(world.player.up_direction == Vector3.UP, "Level unload restores upright traversal")


func _press_anchor(index: int) -> void:
	await _press_story_interaction("anchor_%d" % index)
	_expect(controller.progress == index+1, "Actual E input activates ordered gravity anchor %d" % (index+1))


func _press_story_interaction(key: String) -> void:
	await _frames(3)
	world._update_interaction_target()
	var area: Node3D = controller.get_node(key)
	_expect(world.player.interaction_target == area, "Actual interaction sensor selects " + key + " from the walked approach")
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(2)


func _walk_on_surface(target: Vector3) -> bool:
	var player = world.player
	var arrived := false
	var largest_height_error := 0.
	for frame in 220:
		var offset: Vector3 = target-player.global_position
		if Vector2(offset.x,offset.z).length() < .45:
			arrived = true
			break
		var right: Vector3 = player.camera.global_basis.x
		var forward: Vector3 = -player.camera.global_basis.z
		right.y = 0.
		forward.y = 0.
		var side := offset.dot(right.normalized())
		var advance := offset.dot(forward.normalized())
		for action: String in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
		if absf(side) > .3: Input.action_press("move_right" if side > 0. else "move_left")
		if absf(advance) > .3: Input.action_press("move_forward" if advance > 0. else "move_back")
		await _frames(1)
		largest_height_error = maxf(largest_height_error,absf(player.global_position.y-target.y))
	for action: String in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	await _frames(4)
	var success: bool = arrived and largest_height_error < .2 and player.is_on_floor()
	if not success:
		var obstruction := KinematicCollision3D.new()
		var direction: Vector3 = target-player.global_position
		direction.y = 0.
		if player.test_move(player.global_transform,direction.normalized()*2.,obstruction):
			print("FIELD_ROUTE_OBSTRUCTION level=",controller.level_id," collider=",obstruction.get_collider().get_path()," at=",obstruction.get_position())
	_expect(success, "Actual WASD traverses the %sm surface to %s, position=%s height_error=%s" % [target.y,target,player.global_position,largest_height_error])
	return success


func _field_route_connections() -> void:
	# Geometry access after an earned procession: this fixture does not claim
	# that the escort itself was completed through input (tested separately).
	world.run_state.set_choice_flag("field_03_03_complete",true)
	await _load("level_03_03",false)
	await _walk_connection_fixture(Vector3(0,.05,-24),[
		# The one-way shortcut door at (0,-48) and the lantern at (18,-42)
		# remain solid. The normal 18m-wide road passes both on the X=6 lane.
		Vector3(0,0,-42),Vector3(6,0,-42),Vector3(6,0,-48),Vector3(24,0,-48),Vector3(24,0,-54),Vector3(24,0,-66),
		Vector3(24,0,-78),Vector3(24,0,-84),Vector3(-18,0,-84),Vector3(-18,0,-102)],"procession entry and turned exit")
	world.run_state.set_choice_flag("silence_threshold_resolved",false)
	await _load("level_05_04")
	await _walk_connection_fixture(Vector3(-30,.05,-48),[
		Vector3(-54,0,-48),Vector3(-30,0,-48),Vector3(-24,0,-48),Vector3(-24,0,-66),
		Vector3(-30,0,-66),Vector3(-54,0,-66),Vector3(-54,0,-72),Vector3(-54,0,-66),
		Vector3(-30,0,-66),Vector3(-24,0,-66),Vector3(-24,0,-96),Vector3(-30,0,-96),
		Vector3(-54,0,-96),Vector3(-30,0,-96),Vector3(6,0,-96),
		Vector3(6,0,-114),Vector3(6,0,-120),Vector3(12,0,-120),Vector3(12,0,-132),
		Vector3(6,0,-132),Vector3(0,0,-138)],"three trial courts round trip and expanded Silence court")


func _walk_connection_fixture(start: Vector3, route: Array, label: String) -> void:
	var player = world.player
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.set_camera_director_override(true)
	player.camera_rig.rotation = Vector3.ZERO
	player.camera_pitch.rotation.x = -.25
	player.set_physics_process(true)
	await _frames(5)
	var reached := 0
	for point: Vector3 in route:
		if not (await _walk_on_surface(point)): break
		reached += 1
	_expect(reached == route.size(), label + " remains physically connected without repositioning")
	print("FIELD_CONNECTION_WASD ",controller.level_id," reached=",reached,"/",route.size()," final=",player.global_position," ",label)
	player.set_physics_process(false)
	player.set_camera_director_override(false)


func _trials() -> void:
	var record_before := int(world.run_state.inventory.get("soul_forger_records", 0))
	_expect(record_before == 0, "Generic dialogue grants no Nine Records")
	await _interact("trial_thought_breaker")
	_expect(world.player.is_story_healing_locked(), "Real Thought-Breaker trial locks healing")
	world.player.health = 30.
	world.player.heal(40.)
	world.player.heal_full()
	for id: String in CombatData.SPELL_CONFIG:
		if float(CombatData.SPELL_CONFIG[id].get("heal", 0.)) > 0.:
			_expect(not world.player._spells.begin_cast(StringName(id),0.,.1), "No-heal trial blocks cast " + id)
			world.player._spells.resolve_cast(StringName(id))
	_expect(is_equal_approx(world.player.health, 30.), "Direct, full and queued spell healing cannot bypass trial")
	controller.reset_attempt()
	await _frames(2)
	_expect(not world.player.is_story_healing_locked() and not world.run_state.get_choice_flag("trial_thought_breaker",false), "Failed trial unlocks healing without awarding progress")
	world.player.heal_full()
	for id in ["star_forger", "thought_breaker"]:
		await _interact("trial_" + id)
		_expect(controller._actors.size() == 1, id + " spawns one real local opponent")
		_defeat_local_actors()
		await _frames(2)
		_expect(world.run_state.get_choice_flag("trial_"+id,false), id + " is earned through actual damage/death receiver")
		_expect(controller.trial_mode.is_empty(), id + " removes isolation on success")
		await _leave_trial_court(-48. if id == "star_forger" else -66.)
	await _interact("trial_gate_keeper")
	var ward = controller._ward
	world.player.global_position = controller.trial_center + Vector3(0,.05,6)
	await _frames(140)
	_expect(is_instance_valid(ward) and ward.health < 90., "Actual attackers navigate and damage the defended flame")
	controller.reset_attempt()
	await _frames(2)
	await _interact("trial_gate_keeper")
	for wave in 3:
		_expect(int(controller.trial_wave) == wave+1, "Gate-Keeper emits ordered wave %d" % (wave+1))
		_defeat_local_actors()
		await _frames(42)
	_expect(world.run_state.get_choice_flag("trial_gate_keeper",false), "Three defended waves earn Gate-Keeper")
	await _leave_trial_court(-96.)
	for id: String in ["star_forger","thought_breaker","dust_returner","fate_weaver"]:
		await _interact("testimony_"+id)
		await _interact("blessing_"+id)
	_expect(_blessing_count() == 3, "Without Nine Records at most three blessings can be selected")
	for id: String in Mechanisms.FORGERS: await _interact("testimony_"+id)
	_expect(int(world.run_state.inventory.get("soul_forger_records",0)) == 1, "Nine actual individual testimonies earn one record")
	await _interact("blessing_fate_weaver")
	await _interact("blessing_gate_keeper")
	await _interact("blessing_sin_measurer")
	_expect(_blessing_count() == 5, "Records raise the cap to five, never six")
	var modifiers := Mechanisms.final_battle_modifiers(world.run_state)
	_expect(float(modifiers["damage"]) > 1. and float(modifiers["focus_regen"]) > 1. and float(modifiers["guard"]) < 1., "Different selected Forgers expose distinct calculation modifiers")
	world.player.global_position = Vector3.ZERO
	controller.interact_silence(world.player)
	_expect(not controller.complete, "Silence cannot resolve from across the map")
	await _interact("silence_threshold")
	_expect(controller.complete and world.run_state.get_choice_flag("silence_threshold_method","") == "testimony", "Nine Records earn actual peaceful threshold passage")
	_expect(world.run_state.get_choice_flag("npc_silence_bringer_met",false), "Earned threshold preserves Silence dialogue progression")
	# Independent fresh combat route: no record, no persistent completion.
	world.run_state.inventory.erase("soul_forger_records")
	world.run_state.set_choice_flag("silence_threshold_resolved", false)
	await _load("level_05_04")
	await _interact("silence_threshold")
	var silence = controller._actors[0]
	_expect(is_equal_approx(silence.max_health,320.) and is_equal_approx(silence.attack_windup,3.), "Silence uses the actual threshold stats and deliberate staff timing")
	_expect(silence.body_visual_root.find_child("ModelRoot",true,false) != null, "Silence has an actual imported NPC body")
	world.player.global_position = silence.global_position + Vector3(0,.05,3)
	var health_before: float = world.player.health
	await _frames(125)
	if world.player.health >= health_before:
		print("SILENCE_STAFF_TRACE state=",silence.state," timing=",silence.attack_windup,"/",silence.attack_active,"/",silence.attack_recovery," position=",silence.global_position," target=",world.player.global_position," range=",silence.attack_range," active=",silence.combat_area.active," targetable=",world.player.is_targetable())
	_expect(world.player.health < health_before, "Silence's real staff FSM can damage the player")
	world.player.heal_full()
	for frame in 240:
		if controller._silence_cast_time > 0.: break
		if frame % 40 == 0: world.player.heal_full()
		await _frames(1)
	_expect(controller._silence_cast_time > 0., "Silence naturally begins its authored interruptible incantation")
	silence.receive_hit_payload({"damage":1.,"stagger":0.,"source":world.player})
	_expect(controller._silence_cast_time == 0. and not world.player.is_story_cast_locked(), "A real hit interrupts the cast before spell lock")
	for frame in 300:
		if world.player.is_story_cast_locked(): break
		if frame % 40 == 0: world.player.heal_full()
		await _frames(1)
	_expect(world.player.is_story_cast_locked(), "An uninterrupted incantation applies the actual cast lock")
	var focus_before: float = world.player.focus
	_expect(not world.player._spells.begin_cast(&"veil_bolt",1.,.1) and is_equal_approx(world.player.focus,focus_before), "Silence refuses spell input before spending focus")
	var summons_before: int = world.player._spells.summon_count()
	_expect(not world.player._spells.try_arcane_barrage(), "Silence also refuses the barrage entry point")
	_expect(not world.player._spells.try_divine_smite(), "Silence also refuses the smite entry point")
	for summon: String in CombatData.SUMMON_CONFIG:
		_expect(not world.player._spells.try_summon(StringName(summon)), "Silence refuses summon entry " + summon)
	await _frames(2)
	_expect(is_equal_approx(world.player.focus,focus_before) and world.player._spells.summon_count() == summons_before, "Rejected alternate cast inputs spend no focus and spawn no summons")
	var sound_before := AudioServer.get_bus_volume_db(0)
	silence.receive_hit_payload({"damage":250.,"stagger":0.,"source":world.player})
	_expect(AudioServer.get_bus_volume_db(0) < sound_before - 20., "Low health starts the actual sound-suppression field")
	# Hit through the production receiver, which must clamp at 10% and never die.
	silence.receive_hit_payload({"damage":10000.,"stagger":0.,"source":world.player})
	_expect(is_equal_approx(silence.health,32.) and silence.state != EnemyScript.State.DEAD, "Lethal hit resolves Silence nonlethally at 32 HP")
	await _frames(2)
	_expect(controller.complete and world.run_state.get_choice_flag("silence_threshold_method","") == "combat", "Actual combat floor earns the alternative threshold route")
	_expect(not world.player.is_story_healing_locked() and not world.player.is_story_cast_locked() and controller._actors.is_empty(), "Threshold success clears temporary locks and local actors")


func _leave_trial_court(entry_z: float) -> void:
	# Start where actual trial completion left the player. This specifically
	# catches isolation/old-rail remnants after success, with no repositioning.
	var player = world.player
	player.set_camera_director_override(true)
	player.camera_rig.rotation = Vector3.ZERO
	player.camera_pitch.rotation.x = -.25
	player.set_physics_process(true)
	await _frames(4)
	await _walk_on_surface(Vector3(-54,0,entry_z))
	await _walk_on_surface(Vector3(-30,0,entry_z))
	var at: Vector3 = player.global_position
	var hit := _ray(at+Vector3.UP*.3,at+Vector3.DOWN*.3)
	_expect(at.x > -32. and not hit.is_empty() and String(hit["collider"].name).begins_with("Tile_"), "Winning trial at Z=%s permits an actual walk back to the original memorial ring" % entry_z)
	player.set_physics_process(false)
	player.set_camera_director_override(false)


func _ambush() -> void:
	var platform := StaticBody3D.new()
	platform.position = Vector3(1000,-.3,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12,.6,12)
	shape.shape = box
	platform.add_child(shape)
	world.add_child(platform)
	var enemy = EnemyScript.new()
	enemy.position = Vector3(1000,.06,0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.spawn_origin = enemy.position
	world.player.global_position = Vector3(1000,.05,-4)
	world.player.rotation = Vector3.ZERO
	await _frames(3)
	var behavior = Ambush.new()
	behavior.on_engage(enemy,world.player)
	_expect(behavior.did_teleport(), "Ambush can use actual supported ground")
	_expect(absf(enemy.global_position.y - .06) < .1, "Ambush snaps its real capsule feet to terrain")
	world.player.global_position = Vector3(1030,.05,0)
	var before: Vector3 = enemy.global_position
	var blocked = Ambush.new()
	blocked.on_engage(enemy,world.player)
	_expect(enemy.global_position.is_equal_approx(before), "Ambush rejects a destination over void/outside leash")
	world.player.global_position = Vector3(1000,.05,-2)
	var cage := Node3D.new()
	world.add_child(cage)
	for index in 8:
		var obstacle := StaticBody3D.new()
		obstacle.position = world.player.global_position + Vector3(cos(TAU*index/8.)*3.,1.5,sin(TAU*index/8.)*3.)
		var collision := CollisionShape3D.new()
		var block := BoxShape3D.new()
		block.size = Vector3(2.5,3.,2.5)
		collision.shape = block
		obstacle.add_child(collision)
		cage.add_child(obstacle)
	await _frames(2)
	var enclosed = Ambush.new()
	enclosed.on_engage(enemy,world.player)
	_expect(enemy.global_position.is_equal_approx(before), "Ambush refuses supported destinations when its actual capsule would overlap solid walls")
	cage.queue_free()
	await _frames(2)
	var upper := StaticBody3D.new()
	upper.position = Vector3(1000,1.7,1)
	var upper_shape := CollisionShape3D.new()
	var upper_box := BoxShape3D.new()
	upper_box.size = Vector3(12,.6,4)
	upper_shape.shape = upper_box
	upper.add_child(upper_shape)
	world.add_child(upper)
	await _frames(2)
	var stacked = Ambush.new()
	stacked.on_engage(enemy,world.player)
	_expect(enemy.global_position.y < .5, "Ambush does not pick the roof of an adjacent storey above its target")
	upper.queue_free()
	enemy.queue_free()
	platform.queue_free()
	await _frames(2)


func _defeat_local_actors() -> void:
	for actor in controller._actors.duplicate():
		actor.receive_hit_payload({"damage":10000.,"stagger":0.,"source":world.player})


func _blessing_count() -> int:
	var count := 0
	for id: String in Mechanisms.FORGERS:
		if world.run_state.get_choice_flag("forger_blessing_"+id,false): count += 1
	return count


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
