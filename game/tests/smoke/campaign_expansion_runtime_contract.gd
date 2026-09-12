extends SceneTree
## Bounded fixture: real world enemy factory, player interaction handler and
## physics sensor; actors are frozen and saves serialize only in memory.
const Runtime = preload("res://scripts/world/campaign_expansion_runtime.gd")
const RunState = preload("res://scripts/core/run_state.gd")
const LevelRuntime = preload("res://scripts/world/campaign_level_runtime.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfig = preload("res://scripts/core/input_config.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	var saved_snapshot: Dictionary = {}
	var save_calls := 0
	var fail_next_save := false
	func _ready() -> void:
		# This fixture deliberately does not build the campaign or read settings.
		set_process(false)
	func _save_run(_reason: String) -> bool:
		save_calls += 1
		if fail_next_save:
			fail_next_save = false
			return false
		run_state.embers = int(player.embers)
		saved_snapshot = run_state.to_dictionary()
		return true

class AuditHud extends Node:
	var messages: Array[String] = []
	var prompt := ""
	func show_message(message: String, _seconds: float) -> void:
		messages.append(message)
	func set_prompt(message: String) -> void:
		prompt = message

class AuditAudio extends Node:
	var cue_count := 0
	func play_cue(_cue: String, _volume: float, _pitch: float) -> void:
		cue_count += 1

var world: AuditWorld
var level: Node3D
var runtime: Node3D
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfig.configure_inputs()
	world = AuditWorld.new()
	world.run_state = RunState.new()
	world.position = Vector3(23, 2, -11)
	world.rotation.y = .31
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
	var expansion := _fixture_plan()
	_build_level(expansion)
	await _frames(3)
	_expect(world.enemies.size() == 2, "Two authored guards spawn through the production world factory")
	var expected_origin := level.to_global(Vector3(-8, .05, -8))
	var first = world.enemies[0]
	_expect(first.global_position.distance_to(expected_origin) < .001, "Translated and rotated level/world roots place the guard exactly once")
	_expect(first.spawn_origin.distance_to(expected_origin) < .001, "Enemy home position uses the same world-space point as its physical body")
	_expect(first.encounter_assignment["placement_id"] == "level_01_02/district/patrol", "Assignment preserves the authored stable placement ID")
	_expect(first.encounter_assignment["encounter_id"] == "level_01_02/district/patrol", "Production encounter identity is stable across runtime loads")
	var expected_facing := (level.global_basis * Vector3.RIGHT).normalized()
	_expect((-first.global_basis.z).normalized().distance_to(expected_facing) < .001, "Actual guard facing follows the rotated level direction")
	var patrol: Array = first.encounter_assignment["patrol_points"]
	_expect(patrol.size() == 2 and patrol[0].distance_to(level.to_global(Vector3(-8, 0, -4))) < .001, "AI patrol points are transformed from level-local to world exactly once")
	_expect(expansion["encounters"][0]["patrol_points"][0] == Vector3(-8, 0, -4), "Runtime assignment never mutates authored local patrol data")
	runtime.setup(world, level, expansion)
	_expect(world.enemies.size() == 2 and runtime.reward_areas.size() == 1, "Repeated setup duplicates neither enemies nor caches")
	var cache: Area3D = runtime.reward_areas["watch_cache"]
	_expect(cache.global_position.distance_to(level.to_global(Vector3(8, 0, -9))) < .001, "Cache uses the same transformed level frame")
	_expect(cache.collision_layer == 8 and cache.collision_mask == 0 and cache.monitorable, "Cache is a physical production interactable, without blocking traversal")
	_expect(cache.get_child_count() >= 3, "Cache includes collision, visible reward and light")
	var stranger := Node3D.new()
	world.add_child(stranger)
	stranger.global_position = cache.global_position
	cache.interact(stranger)
	_expect(world.player.embers == 0 and world.save_calls == 0, "Another actor cannot claim the player's reward")
	stranger.free()
	world.player.global_position = cache.global_position + Vector3(12, 0, 0)
	await _frames(3)
	world._update_interaction_target()
	_expect(world.player.interaction_target == null, "Real interaction sensor excludes a distant cache")
	cache.interact(world.player)
	_expect(world.player.embers == 0, "Direct out-of-range interaction is rejected")
	world.player.global_position = cache.global_position + Vector3(0, 0, 1.5)
	world.player.health = 0
	cache.interact(world.player)
	_expect(world.player.embers == 0, "A dead player cannot collect the cache")
	world.player.health = world.player.max_health
	var wall := _solid(world, world.to_local(cache.global_position + Vector3(0, .8, .75)), Vector3(2, 2, .3))
	wall.global_rotation = Vector3.ZERO
	await _frames(3)
	cache.interact(world.player)
	_expect(world.player.embers == 0, "A real World collider prevents collecting through a wall")
	wall.free()
	await _frames(3)
	world._update_interaction_target()
	_expect(world.player.interaction_target == cache, "Production Area3D sensor discovers the nearby cache")
	_expect(not world.hud.prompt.is_empty(), "Production target selection exposes an understandable pickup prompt")
	world.fail_next_save = true
	cache.interact(world.player)
	_expect(world.player.embers == 0 and not world.run_state.choice_flags.has(runtime.reward_flag("watch_cache")), "Failed persistence restores currency and leaves the cache claimable")
	# The patrol/guard remain alive: exploration loot can be snatched under
	# pressure rather than requiring an arbitrary enemy-death completion flag.
	world.player.state = world.player.State.ATTACK_RECOVERY
	Input.action_press("interact")
	world.player._handle_action_input()
	Input.action_release("interact")
	cache.interact(world.player)
	_expect(world.player.embers == 75 and world.save_calls == 2, "Production interact input grants one finite cache even during combat recovery")
	_expect(world.enemies.all(func(enemy): return enemy.health > 0), "Collecting treasure does not require killing its guards")
	_expect(world.run_state.inventory.is_empty() and world.run_state.collected_loot.is_empty(), "Environmental rewards do not invent catalog item IDs")
	_expect(world.hud.messages.size() == 1 and world.hud.messages[0].contains("守灯人"), "One successful claim presents its short environmental lore")
	_expect(world.audio.cue_count == 1, "Repeated interaction cannot replay reward feedback")
	var saved: Dictionary = world.saved_snapshot.duplicate(true)
	await _frames(3)
	_expect(get_nodes_in_group("campaign_expansion_cache").is_empty(), "Claim removes the physical interaction and its visible cache")
	var old_enemy: WeakRef = weakref(first)
	world.campaign_runtime.unload_level()
	await _frames(3)
	_expect(world.enemies.is_empty() and old_enemy.get_ref() == null, "Direct level unload cleans up its world-owned source enemies")
	world.run_state = RunState.from_dictionary(saved)
	_expect(world.run_state != null, "Cache persistence survives the real run-state schema round trip")
	if world.run_state != null:
		world.player.embers = world.run_state.embers
		_build_level(expansion)
		await _frames(3)
		_expect(runtime.reward_areas.is_empty() and world.player.embers == 75, "Reload restores currency and never respawns the claimed reward")
		_expect(world.enemies.size() == 2, "Reload creates one fresh encounter roster without old-level duplicates")
		_expect(world.enemies[0].encounter_assignment["placement_id"] == "level_01_02/district/patrol", "Reload preserves encounter placement identity")
		world._clear_enemies()
		world.campaign_runtime.unload_level()
		await _frames(3)
		_expect(world.enemies.is_empty(), "Normal world enemy clear and runtime unload cooperate safely")
		_build_level({"district_id": "silent_shore", "encounters": [], "rewards": []}, &"level_05_01")
		_expect(world.enemies.is_empty(), "An empty peaceful shore plan introduces no hostiles")
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_EXPANSION_RUNTIME_OK checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build_level(expansion: Dictionary, id: StringName = &"level_01_02") -> void:
	level = Node3D.new()
	level.name = "ExpansionFixture"
	level.position = Vector3(-7, 3, -9)
	level.rotation.y = .73
	world.campaign_runtime.current_level_id = id
	world.campaign_runtime.current_level = level
	world.campaign_runtime.add_child(level)
	_solid(level, Vector3(0, -.25, -6), Vector3(36, .5, 36))
	runtime = Runtime.new()
	level.add_child(runtime)
	runtime.setup(world, level, expansion)
	for enemy in world.enemies:
		enemy.set_physics_process(false)


func _fixture_plan() -> Dictionary:
	return {"schema_version": 1, "district_id": "outer_watch", "encounters": [
		{"placement_id": "level_01_02/district/patrol", "content_id": "lost_soul_soldier", "role": "patrol", "position": Vector3(-8, 0, -8), "facing": Vector3.RIGHT, "patrol_points": [Vector3(-8, 0, -4), Vector3(-8, 0, -12)]},
		{"placement_id": "level_01_02/district/treasure_guard", "content_id": "temple_guardian_warrior", "role": "guard", "position": Vector3(8, 0, -12), "facing": Vector3.BACK, "patrol_points": []},
	], "rewards": [{"id": "watch_cache", "embers": 75, "position": Vector3(8, 0, -9), "lore_text": "守灯人没有等到归来的同伴。"}]}


func _solid(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
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
	for index in count:
		await physics_frame
		await process_frame


func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
