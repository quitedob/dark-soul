extends SceneTree
## Host Continue must not carry a prior run's echo into a zero-echo snapshot.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const RunState = preload("res://scripts/core/run_state.gd")
class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void: _apply_settings()
	func _save_run(_reason: String) -> bool: return true
var world: AuditWorld
var failures: Array[String] = []
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
	world._load_campaign_level(&"level_01_02")
	_freeze()
	await _frames(8)
	var level: Node3D = world.campaign_runtime.current_level
	var plan: Dictionary = level.get_meta("expansion")["interior"]
	world._spawn_lost_echo(73, level.to_global(plan["origin"] + Vector3(6, 6, 18)))
	var previous: WeakRef = weakref(world.lost_echo)
	var state = RunState.new()
	state.level_id = "level_01_02"
	state.embers = 9
	state.checkpoint_id = "shrine_01_02"
	# Merely having an active-refuge ID cannot forge the physical B2 unlock.
	state.set_choice_flag("active_interior_refuge", String(plan["souls"]["refuge"]["id"]))
	world._apply_run_state(state)
	_freeze()
	await _frames(10)
	_expect(previous.get_ref() == null and not is_instance_valid(world.lost_echo), "Zero-echo Continue removes previous live echo")
	var snapshot: Dictionary = world._snapshot_run_state()
	_expect(int(snapshot["lost_echo"]["amount"]) == 0 and world.player.embers == 9, "Snapshot cannot reintroduce old currency")
	level = world.campaign_runtime.current_level
	_expect(world.player.global_position.distance_to(level.to_global(plan["souls"]["refuge"]["spawn_position"])) > 20,
		"Unreleased B2 cannot forge a local respawn from an active-refuge ID")
	world._clear_enemies()
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_CAMPAIGN_INTERIOR_RESTORE_OK checks=3 save=memory prior_echo=discarded forged_refuge=rejected")
		quit(0)
	else:
		for message in failures: push_error(message)
		quit(1)
func _freeze() -> void:
	world.player.set_physics_process(false)
	for enemy in world.enemies: enemy.set_physics_process(false)
func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
