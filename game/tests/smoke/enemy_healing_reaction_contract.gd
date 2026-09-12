extends SceneTree
## Actual world healing signal, enemy receivers and physics-driven attack phases.
## Isolated positioning controls range/occlusion; no production saves or fake HP receivers.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const CombatData = preload("res://scripts/data/player_combat_data.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(_reason: String) -> bool:
		_snapshot_run_state()
		return true

var world: AuditWorld
var failures: Array[String] = []
var checks := 0
var healing_signals := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		world.add_child(child)
	contents.free()
	root.add_child(world)
	world.game_settings.reduced_motion = true
	world.set_process(false)
	world.player.healing_started.connect(_count_healing)
	await _check_passive_windup()
	await _check_occluded_guard()
	await _check_chase_boost_refresh()
	await _check_boss_punishment()
	await _check_ember_blessings()
	world.free()
	await process_frame
	if failures.is_empty():
		print("ASHEN_ENEMY_HEALING_REACTION_OK checks=%d healing_signals=%d" % [checks, healing_signals])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _load(id: StringName) -> void:
	_expect(world._load_campaign_level(id), "Actual level loads " + String(id))
	world.player.set_physics_process(false)
	for enemy in world.enemies:
		enemy.set_physics_process(false)
	await _frames(4)


func _check_passive_windup() -> void:
	await _load(&"level_05_01")
	_expect(world.enemies.size() == 4, "Quiet shore uses all four actual passive actors")
	var witness: Node3D = world.enemies.front()
	var player = world.player
	player.respawn_at(witness.global_position + Vector3(0, .05, 8.))
	player.set_physics_process(true)
	for enemy in world.enemies:
		_expect(String(enemy.encounter_assignment.get("activation", "")) == "provoked", "Actual shore actor requires provocation")
		enemy.set_physics_process(true)
	await _frames(3)
	_expect(not witness.engaged and player.global_position.distance_to(witness.global_position) < float(witness.aggro_range),
		"Passive witness is dormant even inside its awareness range")
	_expect(_begin_heal(), "Production healing cast starts on the quiet shore")
	# Inspect the real healing announcement before this mixed spell's offensive
	# release. Its later AoE hit would legitimately count as provocation.
	await _frames(3)
	for enemy in world.enemies:
		_expect(not enemy.engaged and not enemy._encounter_provoked and enemy.state == enemy.State.IDLE,
			"Healing windup does not provoke " + String(enemy.content_id))
	_cancel_cast()


func _check_occluded_guard() -> void:
	await _load(&"level_01_02")
	var guard := _enemy("lost_soul_soldier", "guard")
	if not _expect(guard != null, "Training court has its real authored guard"):
		return
	var player = world.player
	player.respawn_at(guard.global_position + Vector3(0, .05, 6.8))
	player.set_physics_process(true)
	guard.rotation.y = PI # Front-facing: the wall, rather than facing, hides the healer.
	var wall := StaticBody3D.new()
	wall.name = "HealingContractOccluder"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = (guard.global_position + player.global_position) * .5 + Vector3.UP * 2.
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 4, .6)
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	guard.set_physics_process(true)
	await _frames(4)
	var ray := PhysicsRayQueryParameters3D.create(guard.global_position + Vector3.UP * 1.2, player.get_target_point(), 1)
	_expect(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == wall,
		"Real World-layer geometry occludes the front-facing healer")
	var speed: float = guard.move_speed
	_expect(_begin_heal(), "Production heal signal reaches the occluded-guard scene")
	await _frames(3)
	_expect(not guard.engaged and guard.state == guard.State.IDLE and is_equal_approx(guard.move_speed, speed),
		"Unseen ordinary guard neither engages nor receives a heal chase boost")
	_cancel_cast()
	# Positive control keeps the same real guard and distance but removes the wall.
	# Pause its ordinary polling so admission here must come from the heal signal.
	guard.set_physics_process(false)
	wall.queue_free()
	await _frames(2)
	_expect(not guard.engaged, "Positive control begins dormant")
	_expect(_begin_heal(), "Unoccluded healing cast starts")
	_expect(guard.engaged and guard.state == guard.State.CHASE and guard.move_speed > speed,
		"Visible in-range guard reacts through healing_started → world → enemy")
	_cancel_cast()


func _check_chase_boost_refresh() -> void:
	await _load(&"level_01_02")
	var guard := _enemy("lost_soul_soldier", "guard")
	if not _expect(guard != null, "Actual guard exists for repeated-healing speed measurement"):
		return
	var player = world.player
	player.respawn_at(guard.global_position + Vector3(0, .05, 6.8))
	player.set_physics_process(true)
	guard.rotation.y = PI
	# Keep the real guard in place while the real player finishes each cast;
	# 6.8m is inside guard awareness but outside Ember Rite's offensive release.
	var base_speed: float = guard.move_speed
	var hp: float = guard.health
	await _frames(3)
	_expect(_begin_heal(), "First repeated-healing cast begins")
	_expect(is_equal_approx(guard.move_speed, base_speed * 1.5), "First heal applies exactly one chase boost")
	await create_timer(.95).timeout
	_expect(player._cast_resolved, "First real cast resolves before the repeated heal")
	_expect(_begin_heal(), "Second real healing signal refreshes the active boost")
	_expect(is_equal_approx(guard.move_speed, base_speed * 1.5), "Repeated heal never compounds chase speed to 2.25x")
	# The first timer expires during this interval, while the refreshed timer
	# still has .8 seconds left. It must not shorten the new boost.
	await create_timer(1.0).timeout
	_expect(is_equal_approx(guard.move_speed, base_speed * 1.5), "Older timer cannot expire the refreshed boost")
	await create_timer(.95).timeout
	_expect(is_equal_approx(guard.move_speed, base_speed), "Latest boost expiry restores the original base speed")
	_expect(not guard.has_meta("heal_react_base_speed"), "Expired boost leaves no cached base speed")
	_expect(is_equal_approx(guard.health, hp), "Repeated casts did not strike the out-of-AoE guard")
	_expect(_begin_heal(), "A third healing signal starts the reset scenario")
	_expect(is_equal_approx(guard.move_speed, base_speed * 1.5), "Reset scenario begins with an active chase boost")
	# A reset rereads authored tuning. The cached pre-boost speed must not
	# overwrite a new base supplied by that production tuning path.
	var reset_base := base_speed * .9
	guard.chapter_content["move_speed"] = reset_base
	guard.reset_enemy()
	guard.set_physics_process(false)
	_expect(is_equal_approx(guard.move_speed, reset_base) and not guard.has_meta("heal_react_base_speed"),
		"Actual enemy reset restores current authored tuning and clears the boost")
	# Model a subsequent movement-tuning change, then send another real heal.
	# Both the reset timer and the new boost timer remain alive in SceneTree.
	var fresh_speed := base_speed * .8
	guard.move_speed = fresh_speed
	guard.rotation.y = PI
	await create_timer(.95).timeout
	_expect(_begin_heal(), "Healing after reset uses the newly tuned movement speed")
	_expect(is_equal_approx(guard.move_speed, fresh_speed * 1.5), "New boost captures the fresh base exactly once")
	await create_timer(1.0).timeout
	_expect(is_equal_approx(guard.move_speed, fresh_speed * 1.5), "Reset-invalidated timer cannot overwrite a fresh active boost")
	await create_timer(.95).timeout
	_expect(is_equal_approx(guard.move_speed, fresh_speed), "Only the newest timer restores the fresh base speed")
	_expect(not guard.has_meta("heal_react_base_speed"), "Fresh boost expiry also removes its cached base")
	_cancel_cast()


func _check_boss_punishment() -> void:
	await _load(&"level_04_06")
	var player = world.player
	var boss = world.guardian
	var boundary = world._boss_boundary
	if not _expect(is_instance_valid(boss) and is_instance_valid(boundary), "Real Xuan Xiao and boundary exist"):
		return
	boss.set_physics_process(true)
	player.set_physics_process(true)
	var initial_attack: int = boss.attack_index
	_expect(_begin_heal(), "Heal starts at the actual dormant boss approach")
	await _frames(3)
	_expect(boundary.state == boundary.EncounterState.WAITING and not boss.engaged,
		"Healing outside admission leaves the actual boundary waiting")
	_expect(boss.state == boss.State.IDLE and boss.attack_index == initial_attack and boss._active_heal_punish_variant == &"",
		"Dormant boss does not queue a punishment for later entry")
	_cancel_cast()
	# Real physics admission; no direct call to the boundary's start method.
	boss.set_physics_process(false)
	player.respawn_at(boundary.center + Vector3(0, .05, 3.8))
	await _frames(3)
	_expect(boundary.combat_is_active() and boss.engaged, "Inside player is admitted by the actual boundary")
	var bystander = world._spawn_enemy(boundary.center + Vector3(-3.5, .1, 0), false)
	bystander.set_physics_process(false)
	await _frames(2)
	var previous_attack: Dictionary = {}
	for attack: Dictionary in boss.chapter_content["phases"]["1"]["attacks"]:
		if String(attack.get("name", "")) == "sword_wave":
			previous_attack = attack.duplicate(true)
	_expect(not previous_attack.is_empty(), "Prior profile is an actual authored Xuan Xiao projectile")
	# Controlled prior-attack recovery models the stale-profile trigger. The next
	# WINDUP and ACTIVE are advanced by the real enemy physics loop below.
	boss._active_attack_profile = previous_attack
	boss._resolve_attack_data_or_dict(previous_attack, &"sword_wave")
	boss._change_state(boss.State.RECOVERY, 1., true)
	boss._ensure_boss_attack_executor()
	var before_executor: String = boss._boss_attack_executor.last_type
	var boss_hp: float = boss.health
	var bystander_hp: float = bystander.health
	player.health = player.max_health
	player.guard_active = false
	var player_hp: float = player.health
	var effects: Node = world._arena_director.get_effect_parent()
	var old_projectiles := _projectiles_named(effects, "sword_wave")
	_expect(_begin_heal(), "Active close-range healing cast starts through production signal")
	_expect(boss.state == boss.State.WINDUP and boss._active_heal_punish_variant == &"aoe_burst",
		"Actual boss selects its close-range healing punishment")
	boss.set_physics_process(true)
	var reached_active := false
	for frame in 90:
		await _frames(1)
		if boss.state == boss.State.ACTIVE:
			reached_active = true
			break
	_expect(reached_active, "Production WINDUP advances into ACTIVE")
	boss.set_physics_process(false)
	_expect(player.health < player_hp, "Punishment damages the actual player HP receiver")
	_expect(is_equal_approx(boss.health, boss_hp), "Punishment never damages its caster")
	_expect(is_equal_approx(bystander.health, bystander_hp), "Punishment never damages nearby allied enemies")
	_expect(boss._boss_attack_executor.last_type == before_executor and _projectiles_named(effects, "sword_wave") == old_projectiles,
		"Healing ACTIVE never dispatches the stale authored sword-wave executor/projectile")
	_cancel_cast()


func _check_ember_blessings() -> void:
	await _load(&"level_01_02")
	# This authored warrior can absorb 22 poise damage without the break reset
	# that would erase the accumulated value on the lighter soldier.
	var enemy := _enemy("temple_guardian_warrior", "guard")
	if not _expect(enemy != null, "Real enemy exists for offensive blessing measurement"):
		return
	var player = world.player
	player.respawn_at(enemy.global_position + Vector3(0, .05, 3.2))
	player.set_physics_process(true)
	# Component fixture supplies the two earned modifiers; field contracts own
	# acquiring their memorial flags. This test measures the real spell damage.
	player.set_story_blessing_modifiers({"damage": 1.08, "stagger": 1.10})
	var hp: float = enemy.health
	var poise: float = enemy.poise
	var config: Dictionary = CombatData.SPELL_CONFIG["ember_rite"]
	_expect(_begin_heal(), "Blessed Ember Rite begins through production casting")
	for frame in 90:
		await _frames(1)
		if player._cast_resolved:
			break
	_expect(player._cast_resolved, "Actual player CAST state releases Ember Rite")
	_expect(is_equal_approx(hp - float(enemy.health), float(config["aoe_damage"]) * 1.08),
		"Ember Rite offensive damage receives its blessing exactly once")
	_expect(is_equal_approx(float(enemy.poise) - poise, float(config["aoe_stagger"]) * 1.10),
		"Ember Rite offensive stagger receives its blessing exactly once")
	player.set_story_blessing_modifiers({})
	_cancel_cast()


func _begin_heal() -> bool:
	var player = world.player
	player._change_state(player.State.LOCOMOTION, 0.)
	player.focus = player.max_focus
	var config: Dictionary = CombatData.SPELL_CONFIG["ember_rite"]
	var before := healing_signals
	var accepted: bool = player._spells.begin_cast(&"ember_rite", float(config["focus_cost"]), float(config["cast_time"]))
	_expect(healing_signals == before + 1, "Casting emits the actual healing_started signal once")
	return accepted


func _cancel_cast() -> void:
	world.player._change_state(world.player.State.LOCOMOTION, 0.)
	world.player.combat_area.end_swing()


func _enemy(id: String, role: String = "") -> Node3D:
	for enemy in world.enemies:
		if String(enemy.content_id) == id and (role.is_empty() or String(enemy.encounter_assignment.get("role", "")) == role):
			return enemy
	return null


func _projectiles_named(node: Node, action: String) -> int:
	var count := 0
	if "hit_payload" in node and String(node.hit_payload.get("action_id", "")) == action:
		count += 1
	for child in node.get_children():
		count += _projectiles_named(child, action)
	return count


func _count_healing() -> void:
	healing_signals += 1


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok
