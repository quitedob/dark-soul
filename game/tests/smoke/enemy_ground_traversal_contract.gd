extends SceneTree
## Live campaign physics with in-memory saves; checks bodies, not animated artwork.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()

	func _save_run(_reason: String) -> bool:
		return true

class DrivenEnemy extends "res://scripts/enemy.gd":
	var drive := Vector3.ZERO

	func _update_state(_delta: float) -> void:
		velocity.x = drive.x
		velocity.z = drive.z

var _world: AuditWorld
var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(90102)
	_world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		_world.add_child(child)
	contents.free()
	root.add_child(_world)
	_world.set_process(false)
	await process_frame
	for id: StringName in [&"level_01_02", &"level_04_01"]:
		_world._load_campaign_level(id)
		_world.player.health = 100000.0
		_world.player.set_process_unhandled_input(false)
		var starts: Dictionary = {}
		for enemy in _world.enemies:
			starts[enemy.get_instance_id()] = enemy.global_position
			print("GROUND_INITIAL %s/%s spawn=%s shape_y=%s height=%s radius=%s behavior=%s" % [id, enemy.name, enemy.global_position, enemy.body_collision.position.y, enemy.body_shape.height, enemy.body_shape.radius, enemy._behavior_id])
		for frame in 240:
			await physics_frame
			if frame in [0, 89, 239]:
				for enemy in _world.enemies:
					var foot: Vector3 = enemy.body_collision.global_position - Vector3.UP * enemy.body_shape.height * .5
					var ray := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * .3, foot + Vector3.DOWN * 3., 1)
					var hit := _world.get_world_3d().direct_space_state.intersect_ray(ray)
					print("GROUND_LIVE %s/%s frame=%d pos=%s feet=%s velocity=%s on_floor=%s state=%s support=%s" % [id, enemy.name, frame + 1, enemy.global_position, foot, enemy.velocity, enemy.is_on_floor(), enemy.state, hit.get("position", "NONE")])
					if frame > 0:
						_expect(enemy.is_on_floor() and foot.y > -.1 and not hit.is_empty(), "%s/%s failed to settle on real terrain at frame%d" % [id, enemy.name, frame + 1])
		for enemy in _world.enemies:
			var traveled: Vector3 = enemy.global_position - starts[enemy.get_instance_id()]
			var assignment: Dictionary = enemy.encounter_assignment
			if not assignment.is_empty() and (assignment.get("patrol_points", []) as Array).is_empty():
				_expect(Vector2(traveled.x, traveled.z).length() < .25, "%s/%s authored guard left its post without seeing the player" % [id, enemy.name])
			elif enemy._behavior_id in ["slow_patrol", "float_patrol"] or not (assignment.get("patrol_points", []) as Array).is_empty():
				_expect(Vector2(traveled.x, traveled.z).length() > .25, "%s/%s patrol was immobilized" % [id, enemy.name])
	_world.free()
	await physics_frame
	await _check_ramps_and_edges()
	if _failures.is_empty():
		print("ASHEN_ENEMY_GROUND_TRAVERSAL_CONTRACTS_OK levels=2 live_enemies=8 checks=%d" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_ramps_and_edges() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	_add_floor(stage, Vector3(0., -.25, 3.), Vector3(4., .5, 6.))
	_add_floor(stage, Vector3(0., 1.75, -9.), Vector3(4., .5, 6.))
	var pitch := atan2(2., 6.)
	_add_floor(stage, Vector3(0., 1. - .14 * cos(pitch), -3.), Vector3(4., .28, sqrt(40.)), pitch)
	_add_floor(stage, Vector3(20., -.25, 0.), Vector3(6., .5, 20.))
	var enemy := DrivenEnemy.new()
	enemy.position = Vector3(0., .05, 2.)
	stage.add_child(enemy)
	await physics_frame
	await physics_frame
	enemy.drive = Vector3.FORWARD * 3.
	for frame in 220:
		await physics_frame
	_expect(enemy.global_position.z < -7. and enemy.global_position.y > 1.9 and enemy.is_on_floor(), "Ground guard blocked ramp ascent: " + str(enemy.global_position))
	print("GROUND_RAMP_UP pos=%s on_floor=%s" % [enemy.global_position, enemy.is_on_floor()])
	enemy.drive = Vector3.BACK * 3.
	for frame in 220:
		await physics_frame
	_expect(enemy.global_position.z > 1. and absf(enemy.global_position.y) < .05 and enemy.is_on_floor(), "Ground guard blocked ramp descent: " + str(enemy.global_position))
	print("GROUND_RAMP_DOWN pos=%s on_floor=%s" % [enemy.global_position, enemy.is_on_floor()])
	# Use the same production motor for direct chase, lunge and diagonal return.
	for movement_state: int in [enemy.State.IDLE, enemy.State.CHASE, enemy.State.ACTIVE, enemy.State.RETURN]:
		enemy.position = Vector3(20., .05, 0.)
		enemy.velocity = Vector3.ZERO
		enemy.state = movement_state
		enemy.drive = Vector3(1., 0., -1.).normalized() * 3.
		for frame in 180:
			await physics_frame
		_expect(enemy.global_position.x < 23. and enemy.global_position.z < -3. and enemy.global_position.y > -.05 and enemy.is_on_floor(), "Voluntary diagonal state%d did not slide along supported edge: %s" % [movement_state, enemy.global_position])
		print("GROUND_EDGE state=%d pos=%s on_floor=%s" % [movement_state, enemy.global_position, enemy.is_on_floor()])
	# Forced stagger keeps its existing ability to throw an actor off a platform.
	enemy.state = enemy.State.STAGGER
	enemy.drive = Vector3.RIGHT * 5.
	for frame in 90:
		await physics_frame
	_expect(enemy.global_position.x > 23.5 and enemy.global_position.y < -.5 and not enemy.is_on_floor(), "Ground guard cancelled intentional knockback/falling")
	print("GROUND_KNOCKBACK pos=%s velocity=%s" % [enemy.global_position, enemy.velocity])
	stage.free()
	await process_frame


func _add_floor(parent: Node3D, at: Vector3, size: Vector3, pitch := 0.) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position = at
	floor_body.rotation.x = pitch
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	parent.add_child(floor_body)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
