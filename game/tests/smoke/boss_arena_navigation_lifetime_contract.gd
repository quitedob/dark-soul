extends "res://tests/smoke/boss_arena_contract.gd"
## Destroy the actual world while initial and dynamic navigation work is queued.
## The signal callables must disconnect, without draining the pending bake first.
signal fixture_world_destroyed
var _destroyed_world_id := 0

func _run() -> void:
	for mode in ["initial", "dynamic"]:
		_world = _create_world()
		_world.set_process(false)
		await process_frame
		await physics_frame
		_expect(_world._load_campaign_level(&"level_01_05"), "Lifetime fixture must load actual modeled boss arena")
		_freeze_actors()
		var level: Node3D = _world.campaign_runtime.current_level
		var region: NavigationRegion3D = level.get_node("NavigationSurface")
		_world._generate_navigation()
		if mode == "dynamic":
			await _await_revision(region, 0)
			_world.request_navigation_refresh(level)
			_world.request_navigation_refresh(level)
			# Queue directly after the production deferred connection. This catches
			# its registered callback before the next physics signal emits it.
			call_deferred("_destroy_pending_world", mode)
			await fixture_world_destroyed
		else:
			_expect(int(region.get_meta("geometry_revision", 0)) == 0, "Initial lifetime case must destroy before first navigation publish")
			_destroy_pending_world(mode)
		for frame in 5:
			await physics_frame
		_expect(_callbacks_for(_destroyed_world_id) == 0, mode + " teardown must remove every pending world callback")
		print("BOSS_NAVIGATION_LIFETIME_CHECKED " + mode)
	if _failures.is_empty():
		print("ASHEN_BOSS_NAVIGATION_LIFETIME_OK cases=2 checks=%d" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _destroy_pending_world(mode: String) -> void:
	var level: Node3D = _world.campaign_runtime.current_level
	var region: NavigationRegion3D = level.get_node("NavigationSurface")
	_destroyed_world_id = _world.get_instance_id()
	if mode == "dynamic":
		_expect(_callbacks_for(_destroyed_world_id) == 1, "Repeated dynamic requests must share one pending physics step")
	_expect(bool(region.get_meta("refresh_queued", false)), mode + " case must have real pending navigation")
	_world.free()
	_expect(not is_instance_valid(level), mode + " teardown must release the current level")
	_expect(not is_instance_valid(region), mode + " teardown must release its navigation region")
	fixture_world_destroyed.emit()


func _callbacks_for(world_id: int, method: StringName = &"") -> int:
	var count := 0
	for connection: Dictionary in get_signal_connection_list("physics_frame"):
		var callback: Callable = connection["callable"]
		if callback.get_object_id() == world_id and (method == &"" or callback.get_method() == method):
			count += 1
	return count
