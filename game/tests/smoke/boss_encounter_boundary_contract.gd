extends SceneTree
## Production worlds and bodies: admission, full radial seal, damage eligibility,
## reset/re-entry, saved victory and reward deduplication. No player save writes.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(_reason: String) -> bool:
		_snapshot_run_state()
		return true

var _world: AuditWorld
var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		_world.add_child(child)
	contents.free()
	root.add_child(_world)
	_world.set_process(false)
	_world.player.set_physics_process(false)
	_world.game_settings.reduced_motion = true
	_world.run_state.inventory["keeper_rune"] = 1
	await process_frame
	for id: StringName in [&"level_01_05", &"level_02_06", &"level_03_06", &"level_04_04", &"level_04_05", &"level_04_06", &"level_05_05", &"level_05_06"]:
		_expect(_world._load_campaign_level(id), "World loads " + String(id))
		_world.player.set_physics_process(false)
		var boss = _world.guardian
		var boundary = _world._boss_boundary
		_expect(is_instance_valid(boundary) and boss.encounter_boundary == boundary, "Actual boss bound " + String(id))
		if not is_instance_valid(boundary):
			continue
		await _frames(5)
		var before: float = boss.health
		var home: Vector3 = boss.global_position
		_expect(not boundary.combat_is_active() and not boss.is_targetable(), "Outside approach is dormant " + String(id))
		boss.receive_hit(200., 10., Vector3.ZERO, _world.player)
		boss.apply_status(&"bleed", 200., _world.player)
		boss.apply_execution_damage(200.)
		_expect(is_equal_approx(before, boss.health), "All damage channels refuse outside encounter " + String(id))
		await _frames(8)
		_expect(Vector2(home.x, home.z).distance_to(Vector2(boss.global_position.x, boss.global_position.z)) < .01, "Boss cannot patrol out before admission")
		_world.player.global_position = boundary.center + Vector3(0, .1, boundary.radius - 3.0)
		await _frames(4)
		_expect(boundary.combat_is_active() and boundary.admission_count == 1, "Actual physics entry admits once " + String(id))
		boss.set_physics_process(false)
		_expect(boss.is_targetable() and boss.engaged, "Admission enables combat and HUD engagement")
		for i in 16:
			var angle := TAU * float(i) / 16.0 + .025
			var radial := Vector3(cos(angle), 0, sin(angle))
			var from: Vector3 = boundary.center + radial * (boundary.radius - 1.1) + Vector3.UP * 2.0
			var to: Vector3 = boundary.center + radial * (boundary.radius + 1.5) + Vector3.UP * 2.0
			var query := PhysicsRayQueryParameters3D.create(from, to, 1)
			var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty() and String(hit.collider.name).begins_with("SealSegment"), "Seal closes every route angle %s/%d" % [id, i])
		var outside := Node3D.new()
		_world.add_child(outside)
		outside.global_position = boundary.center + Vector3(boundary.radius + 6.0, 0, 0)
		boss.receive_hit(20., 0., Vector3.ZERO, outside)
		_expect(is_equal_approx(boss.health, before), "Outside attacker cannot snipe through active arena")
		outside.free()
		boss.receive_hit(1., 0., Vector3.ZERO, _world.player)
		_expect(is_equal_approx(boss.health, before - 1.0), "Inside player can hit boss")
		_world.player.global_position = boundary.center + Vector3(boundary.radius + 5.0, .1, 0)
		await _frames(2)
		_expect(boundary.contains_actor(_world.player), "Fast boundary crossing is contained")
		_world.player.global_position = boundary.center + Vector3(0, .1, boundary.radius + 8.0)
		boss.reset_enemy()
		await _frames(3)
		_expect(not boundary.combat_is_active() and is_equal_approx(boss.health, boss.max_health), "Retry restores fresh dormant encounter")
		for shape in boundary._walls:
			_expect(shape.disabled, "Retry reopens physical seal")
		_world.player.global_position = boundary.center + Vector3(0, .1, boundary.radius - 3.0)
		await _frames(3)
		_expect(boundary.combat_is_active() and boundary.admission_count == 2, "Retry permits a second real admission")
		boss.set_physics_process(false)
		var boss_id: String = boss.content_id
		_world._on_enemy_defeated(boss, boss.reward, true)
		var embers: int = _world.player.embers
		_world._on_enemy_defeated(boss, boss.reward, true)
		_expect(_world.player.embers == embers and not _world._can_reset_enemy(boss), "Cleared guardian cannot revive or pay twice")
		_expect(_world._load_campaign_level(id), "Cleared arena reload succeeds")
		await _frames(3)
		_expect(_world.guardian == null and _world._boss_boundary.state == _world._boss_boundary.EncounterState.CLEARED, "Saved victory leaves encounter open")
		_world.run_state.defeated_bosses.erase(boss_id)
	_world.free()
	await process_frame
	if _failures.is_empty():
		print("BOSS_BOUNDARY_COUNTS bosses=8 checks=%d" % _checks)
		print("ASHEN_BOSS_ENCOUNTER_BOUNDARY_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _expect(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
