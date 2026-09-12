extends SceneTree
## Real enemy FSM + CharacterBody movement on a collider-baked navigation map.
## The stationary player remains a valid target; patrol must choose its own route.
const EnemyScript = preload("res://scripts/enemy.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const Chapter1 = preload("res://scripts/data/chapter_1_content.gd")

var stage: Node3D
var player: Node3D
var region: NavigationRegion3D
var failures: Array[String] = []
var checks := 0
var physics_steps := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(91010)
	stage = Node3D.new()
	root.add_child(stage)
	region = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.cell_size = .5
	mesh.cell_height = .25
	mesh.agent_radius = .5
	mesh.agent_height = 2.
	mesh.agent_max_climb = 1.
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	region.navigation_mesh = mesh
	stage.add_child(region)
	_add_body(Vector3(0, -.25, 0), Vector3(60, .5, 30))
	var wall := _add_body(Vector3(0, 1.5, 0), Vector3(2, 3, 8))
	wall.name = "PatrolRouteOccluder"
	player = PlayerScene.instantiate()
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.position = Vector3(25, .05, 10)
	await _frames(3)
	region.bake_navigation_mesh(false)
	await _frames(4)
	var map := region.get_navigation_map()
	_expect(mesh.get_polygon_count() > 0 and NavigationServer3D.map_get_iteration_id(map) > 0,
		"Physical floor and obstacle produce a synchronized navigation map")
	var route := NavigationServer3D.map_get_path(map, Vector3(-5, 0, 0), Vector3(5, 0, 0), true)
	var route_detour := 0.
	for point: Vector3 in route:
		route_detour = maxf(route_detour, absf(point.z))
	_expect(route.size() >= 3 and route_detour > 4., "Baked route actually goes around the eight-metre wall")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-5, 1, 0), Vector3(5, 1, 0), 1)
	_expect(stage.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == wall,
		"A direct patrol/return path is physically blocked")
	if "--guard-only" not in OS.get_cmdline_user_args():
		await _check_patrol()
	await _check_guard_and_return()
	stage.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_AUTHORED_ENEMY_NAVIGATION_OK checks=%d physics_steps=%d" % [checks, physics_steps])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_patrol() -> void:
	var enemy = _spawn_enemy(Chapter1.enemies()[0], {
		"role": "patrol", "activation": "proximity", "guard_radius": 7.,
		"patrol_points": [Vector3(5, 0, 0), Vector3(-5, 0, 0)], "facing_yaw": 0.,
	})
	await _frames(3)
	_expect(enemy.navigation_agent.path_desired_distance >= .69,
		"Authored actor retains tolerance above the baked path's vertical offset")
	var reached_far := false
	var returned := false
	var max_detour := 0.
	var ever_engaged := false
	var stayed_supported := true
	for frame in 1800:
		await _frames(1)
		max_detour = maxf(max_detour, absf(enemy.position.z))
		ever_engaged = ever_engaged or enemy.engaged
		stayed_supported = stayed_supported and enemy.position.y > -.1
		if _horizontal_distance(enemy.position, Vector3(5, 0, 0)) < .8:
			reached_far = true
		if reached_far and _horizontal_distance(enemy.position, Vector3(-5, 0, 0)) < .8:
			returned = true
			break
	print("AUTHORED_PATROL pos=%s reached_far=%s returned=%s detour=%.2f" % [enemy.position, reached_far, returned, max_detour])
	_expect(not ever_engaged and enemy.state == enemy.State.IDLE,
		"Distant valid player does not turn an authored patrol into pursuit")
	_expect(reached_far and returned, "Actual idle patrol reaches both authored waypoints around the obstacle")
	_expect(max_detour > 4. and stayed_supported and enemy.is_on_floor(),
		"Patrol physically detours, remains supported, and finishes on the real floor")
	enemy.free()
	await _frames(2)


func _check_guard_and_return() -> void:
	var enemy = _spawn_enemy(Chapter1.enemies()[1], {
		"role": "guard", "activation": "proximity", "guard_radius": 12.,
		"patrol_points": [], "facing_yaw": 0.,
	})
	await _frames(90)
	_expect(_horizontal_distance(enemy.position, enemy.spawn_origin) < .1 and not enemy.engaged,
		"Authored guard without waypoints holds its post with a distant player")
	# Front-facing visible player activates the real IDLE→CHASE path.
	player.position = Vector3(-5, .05, -5)
	for frame in 45:
		await _frames(1)
		if enemy.engaged:
			break
	_expect(enemy.engaged, "Guard engages a visible player inside its assigned awareness radius")
	player.position = Vector3(5, .05, 0)
	var crossed := false
	var chase_detour := 0.
	for frame in 600:
		await _frames(1)
		chase_detour = maxf(chase_detour, absf(enemy.position.z))
		if enemy.position.x > 3. and absf(enemy.position.z) < 2.:
			crossed = true
			break
	_expect(crossed and chase_detour > 4., "Actual guard chase navigates around the column before disengagement")
	# No state injection or actor teleport: leaving awareness must trigger RETURN.
	player.position = Vector3(25, .05, 10)
	var saw_return := false
	var returned := false
	var return_detour := 0.
	for frame in 720:
		await _frames(1)
		saw_return = saw_return or enemy.state == enemy.State.RETURN
		return_detour = maxf(return_detour, absf(enemy.position.z))
		if saw_return and enemy.state == enemy.State.IDLE and _horizontal_distance(enemy.position, enemy.spawn_origin) < .1:
			returned = true
			break
	print("AUTHORED_GUARD pos=%s crossed=%s return_state=%s returned=%s detour=%.2f" % [enemy.position, crossed, saw_return, returned, return_detour])
	_expect(saw_return and returned and not enemy.engaged, "Real disengagement returns the guard to its own post")
	_expect(return_detour > 4. and enemy.is_on_floor(), "RETURN follows a supported detour instead of pushing into the wall")
	var settled: Vector3 = enemy.position
	await _frames(60)
	print("AUTHORED_GUARD_HOLD start=%s final=%s velocity=%s state=%s engaged=%s" % [settled, enemy.position, enemy.velocity, enemy.state, enemy.engaged])
	_expect(_horizontal_distance(enemy.position, settled) < .1, "Returned guard remains at its post")
	enemy.free()
	await _frames(2)


func _spawn_enemy(content: Dictionary, plan: Dictionary):
	var enemy = EnemyScript.new()
	stage.add_child(enemy)
	enemy.setup_from_content(stage, player, null, Vector3(-5, .05, 0), content, false)
	enemy.assign_campaign_encounter(plan)
	return enemy


func _add_body(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	region.add_child(body)
	return body


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		physics_steps += 1


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
