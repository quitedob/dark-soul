extends SceneTree
## Production capsule locomotion and camera under real opposite floor gravity.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void: _apply_settings()
	func _save_run(_reason: String) -> bool: return true
var world: AuditWorld
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
	for enemy in world.enemies: enemy.set_physics_process(false)
	var player = world.player
	for y in [-.3, 6.3]:
		var body := StaticBody3D.new()
		body.position = Vector3(1000, y, 0)
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(30, .6, 30)
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
	await _frames(3)
	player.respawn_at(Vector3(1000, .1, 0))
	await _frames(45)
	_expect(player.is_on_floor(), "Production capsule stands on normal floor")
	var grounded_center: Vector3 = player.body_collision.global_position
	player.set_traversal_up(Vector3.DOWN)
	_expect(player.body_collision.global_position.distance_to(grounded_center) < .001, "Grounded flip preserves capsule centre without teleporting into the floor")
	await _frames(65)
	_expect(player.is_on_floor() and player.up_direction == Vector3.DOWN, "Opposite gravity actually lands on ceiling")
	_expect(absf(player.global_position.y - 6.) < .12, "Feet contact the ceiling without capsule penetration")
	_expect(player.global_basis.y.dot(Vector3.DOWN) > .99, "Body and weapon hierarchy share actual inverted up")
	_expect(player.camera_rig.global_basis.y.dot(Vector3.DOWN) > .99, "Camera orientation follows inverted traversal")
	_expect(absf(player.camera_rig.global_position.y - (player.global_position.y - 1.45)) < .1, "Camera pivot stays on the character's head side")
	var before: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _frames(32)
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(before) > 1.5 and player.is_on_floor(), "Real forward input moves along ceiling")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(player.velocity.y < -1., "Jump impulse leaves ceiling in the correct direction")
	await _frames(100)
	_expect(player.is_on_floor() and absf(player.global_position.y - 6.) < .12, "Jump returns to ceiling through production gravity")
	player.set_traversal_up(Vector3.UP)
	await _frames(70)
	_expect(player.is_on_floor() and absf(player.global_position.y) < .12, "Ceiling flip returns to the original floor without a position fixture")
	player.set_story_healing_locked(true)
	player.health = 30.
	var focus: float = player.focus
	player.heal(40.)
	player.heal_full()
	_expect(is_equal_approx(player.health, 30.), "Trial blocks external and full healing")
	_expect(not player._spells.begin_cast(&"ember_rite", 12., .3) and is_equal_approx(player.focus, focus), "Healing input refuses before spending focus")
	player._spells.resolve_cast(&"restful_prayer")
	_expect(is_equal_approx(player.health, 30.), "Already queued healing spell cannot bypass trial lock")
	player.set_story_healing_locked(false)
	player.set_story_blessing_modifiers({"healing": 1.2})
	player.heal(10.)
	_expect(is_equal_approx(player.health, 42.), "Earned healing modifier is used by actual heal receiver")
	player.set_story_blessing_modifiers({})
	player.respawn_at(Vector3(1000, .1, 0))
	await _frames(45)
	_expect(player.up_direction == Vector3.UP and player.is_on_floor(), "Respawn restores normal grounded movement")
	_expect(player.camera_rig.global_basis.y.dot(Vector3.UP) > .99 and not player.is_story_healing_locked(), "Respawn clears camera inversion and trial healing lock")
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_PLAYER_STORY_TRAVERSAL_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
