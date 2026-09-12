extends SceneTree
## Actual chapter actors must close into their own range and hit a real player.
## No direct attack dispatch or artificial hit receiver; projectiles use real sweeps.
const EnemyScript = preload("res://scripts/enemy.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const ProjectileScript = preload("res://scripts/enemy/enemy_projectile.gd")
const BossProjectileScript = preload("res://scripts/boss/boss_attack_projectile.gd")
const BossExecutor = preload("res://scripts/boss/boss_attack_executor.gd")
const InputConfig = preload("res://scripts/core/input_config.gd")
const Chapter2 = preload("res://scripts/data/chapter_2_content.gd")
const Chapter3 = preload("res://scripts/data/chapter_3_content.gd")
const Chapter4 = preload("res://scripts/data/chapter_4_content.gd")
const Chapter5 = preload("res://scripts/data/chapter_5_content.gd")
const RANGED_IDS := ["echo_spirit", "mirror_flower_spirit", "book_spirit"]
const MELEE_IDS := ["memory_thief", "generals_personal_guard", "war_dog_wraith", "illusion_butterfly", "ember_bat"]

var stage: Node3D
var player
var region: NavigationRegion3D
var failures: Array[String] = []
var checks := 0
var hit_cases := 0
var blocked_cases := 0
var boss_cases := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(91011)
	InputConfig.configure_inputs()
	stage = Node3D.new()
	root.add_child(stage)
	region = NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.cell_size = .5
	mesh.cell_height = .25
	mesh.agent_radius = .5
	mesh.agent_height = 2.
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	region.navigation_mesh = mesh
	stage.add_child(region)
	_add_body(region, Vector3(0, -.25, 0), Vector3(30, .5, 30))
	player = PlayerScene.instantiate()
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	await _frames(3)
	region.bake_navigation_mesh(false)
	await _frames(4)
	_expect(mesh.get_polygon_count() > 0, "Combat court has actual baked floor navigation")
	var case_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case_id = arg.trim_prefix("--case=")
	for id: String in RANGED_IDS + MELEE_IDS:
		if not case_id.is_empty() and case_id != id:
			continue
		await _check_approach_and_hit(id)
	for id: String in RANGED_IDS:
		if not case_id.is_empty() and case_id != id:
			continue
		await _check_projectile_wall(id)
	if case_id.is_empty() or case_id == "boss":
		await _check_boss_projectiles()
	stage.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_AUTHORED_ENEMY_COMBAT_OK checks=%d actual_hit_cases=%d wall_cases=%d boss_projectile_cases=%d" % [checks, hit_cases, blocked_cases, boss_cases])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_approach_and_hit(id: String) -> void:
	var enemy = await _spawn_enemy(id)
	await _frames(2)
	var start: Vector3 = enemy.global_position
	var start_hp: float = player.health
	var initial_range: float = enemy.attack_range
	_expect(_horizontal_distance(start, player.global_position) > initial_range + 1., id + " starts outside its actual attack range")
	var saw_projectile := false
	var saw_active := false
	for frame in 420:
		await _frames(1)
		saw_projectile = saw_projectile or not _projectiles().is_empty()
		saw_active = saw_active or enemy.state == enemy.State.ACTIVE
		if player.health < start_hp:
			break
	var damage: float = start_hp - player.health
	var traveled := _horizontal_distance(start, enemy.global_position)
	print("AUTHORED_HIT id=%s pos=%s traveled=%.2f attack_range=%.2f damage=%.2f projectile=%s active=%s" % [id, enemy.global_position, traveled, initial_range, damage, saw_projectile, saw_active])
	_expect(traveled > 1. and enemy.engaged, id + " actually approaches through its own IDLE/CHASE states")
	_expect(saw_active and damage > 0., id + " releases an actual attack that damages the stationary PlayerScene")
	_expect(saw_projectile == (id in RANGED_IDS), id + " uses the correct ranged or melee damage owner")
	_expect(_horizontal_distance(player.global_position, Vector3.ZERO) < .1, id + " hits a stationary target without moving the target into range")
	if damage > 0.:
		hit_cases += 1
	await _clear_actor(enemy)


func _check_projectile_wall(id: String) -> void:
	var enemy = await _spawn_enemy(id)
	var projectile: Node3D
	for frame in 360:
		await _frames(1)
		var shots := _projectiles()
		if not shots.is_empty():
			projectile = shots.front()
			break
	if not _expect(is_instance_valid(projectile), id + " fires a real projectile for the wall counterexample"):
		await _clear_actor(enemy)
		return
	# The actor already committed its normal shot. Raise cover across its flight
	# path; this isolates projectile collision from the separate LOS decision.
	enemy.set_physics_process(false)
	var shot_start: Vector3 = projectile.global_position
	var wall_z := shot_start.z * .5
	var wall := _add_body(stage, Vector3(0, 2., wall_z), Vector3(8, 4, .5))
	var receipt := {"resolved": false, "position": Vector3.ZERO}
	projectile.tree_exiting.connect(func():
		receipt["resolved"] = projectile._resolved
		receipt["position"] = projectile.global_position
	)
	var start_hp: float = player.health
	for frame in 90:
		await _frames(1)
		if frame in [15, 35, 60] and is_instance_valid(projectile):
			print("PROJECTILE_LIVE id=%s frame=%d pos=%s speed=%s resolved=%s player=%s" % [id, frame, projectile.global_position, projectile.speed, projectile._resolved, player.global_position])
		if not is_instance_valid(projectile):
			break
	var impact: Vector3 = receipt["position"]
	print("AUTHORED_PROJECTILE_WALL id=%s start=%s wall_z=%.2f impact=%s resolved=%s damage=%.2f" % [id, shot_start, wall_z, impact, receipt["resolved"], start_hp - player.health])
	_expect(not is_instance_valid(projectile) and bool(receipt["resolved"]), id + " resolves on physical contact before natural lifetime expiration")
	_expect(absf(impact.z - wall_z) < .8 and impact.y > .5, id + " impacts the actual wall rather than the floor or player")
	_expect(is_equal_approx(player.health, start_hp), id + " projectile cannot damage through World-layer cover")
	if bool(receipt["resolved"]) and is_equal_approx(player.health, start_hp):
		blocked_cases += 1
	wall.free()
	await _clear_actor(enemy)


func _prepare_player() -> void:
	player.respawn_at(Vector3(0, .05, 0))
	player.set_physics_process(true)
	await _frames(30)
	player.set_physics_process(false)
	player.guard_active = false


func _spawn_enemy(id: String):
	await _prepare_player()
	var enemy = EnemyScript.new()
	stage.add_child(enemy)
	var content := _content(id)
	enemy.setup_from_content(stage, player, null, Vector3(0, .05, 7.8), content, false)
	enemy.assign_campaign_encounter({
		"role": "ranged" if id in RANGED_IDS else "guard",
		"activation": "proximity", "guard_radius": float(content.get("aggro_range", 10.)),
		"patrol_points": [], "facing_yaw": 0.,
	})
	return enemy


func _check_boss_projectiles() -> void:
	var boss = EnemyScript.new()
	stage.add_child(boss)
	var content := Chapter3.boss()
	boss.setup_from_content(stage, player, null, Vector3(0, .05, 7), content, true)
	boss.set_physics_process(false)
	var attack: Dictionary = content["phases"]["1"]["attacks"][0]
	var executor := BossExecutor.new()
	# These component cases invoke the real named skill executor, then observe
	# unmodified BossAttackProjectile steering/sweep and real PlayerScene HP.
	for mode: String in ["clear", "wall", "initial_overlap"]:
		await _prepare_player()
		var wall: StaticBody3D
		var wall_z := 3.5 if mode == "wall" else 7.
		if mode != "clear":
			wall = _add_body(stage, Vector3(0, 2, wall_z), Vector3(8, 4, .5))
			await _frames(2)
		var start_hp: float = player.health
		executor.execute_active(boss, player, attack)
		var projectile: Node3D
		for child in stage.get_children():
			if child.get_script() == BossProjectileScript:
				projectile = child
		if not _expect(is_instance_valid(projectile), "Foxfire executor creates the actual boss projectile: " + mode):
			if is_instance_valid(wall): wall.free()
			continue
		var receipt := {"resolved": false, "position": Vector3.ZERO}
		projectile.tree_exiting.connect(func():
			receipt["resolved"] = projectile._resolved
			receipt["position"] = projectile.global_position
		)
		for frame in 120:
			await _frames(1)
			if not is_instance_valid(projectile): break
		var damage: float = start_hp - player.health
		var impact: Vector3 = receipt["position"]
		print("BOSS_PROJECTILE mode=%s impact=%s resolved=%s damage=%.2f" % [mode, impact, receipt["resolved"], damage])
		_expect(not is_instance_valid(projectile) and bool(receipt["resolved"]), "Boss projectile resolves by collision before expiry: " + mode)
		if mode == "clear":
			_expect(is_equal_approx(damage, float(attack["damage"])), "Real Foxfire projectile damages the real player exactly once")
		else:
			_expect(is_zero_approx(damage) and absf(impact.z - wall_z) < .8,
				"Boss projectile cannot cross physical cover: " + mode)
		if bool(receipt["resolved"]): boss_cases += 1
		if is_instance_valid(projectile): projectile.free()
		if is_instance_valid(wall): wall.free()
		await _frames(2)
	boss.free()
	await _frames(2)


func _content(id: String) -> Dictionary:
	for source in [Chapter2, Chapter3, Chapter4, Chapter5]:
		for content: Dictionary in source.enemies():
			if String(content["id"]) == id:
				return content
	_expect(false, "Missing real chapter content " + id)
	return {}


func _projectiles() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in stage.get_children():
		if child.get_script() == ProjectileScript and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _clear_actor(enemy: Node) -> void:
	for projectile in _projectiles():
		projectile.free()
	enemy.free()
	await _frames(3)


func _add_body(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	parent.add_child(body)
	return body


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition
