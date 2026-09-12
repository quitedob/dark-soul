extends SceneTree
## Actual campaign bosses, ordinary HP damage, production ACTIVE hook, real physics.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const JarScene = preload("res://scenes/props/destructible_jar.tscn")
const ArenaCover = preload("res://scripts/world/boss_arena_cover.gd")
const BossExecutor = preload("res://scripts/boss/boss_attack_executor.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(_reason: String) -> bool:
		_snapshot_run_state()
		return true

var _world: AuditWorld
var _failures: Array[String] = []
var _checks := 0
var _bosses := 0
var _phases := 0
var _skills := 0
var _final_signals := 0
var _final_entered := 0
var _final_phases: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = _create_world()
	_world.set_process(false)
	_world.game_settings.reduced_motion = true
	await process_frame
	await physics_frame
	for id: StringName in [&"level_01_05", &"level_02_06", &"level_03_06", &"level_04_04", &"level_04_05", &"level_04_06", &"level_05_06", &"level_05_05"]:
		_expect(_world._load_campaign_level(id), "Cannot load boss arena " + String(id))
		_freeze_actors()
		await process_frame
		await physics_frame
		await physics_frame
		var boss = _world.guardian
		var director = _world._arena_director
		if not _expect(is_instance_valid(boss) and is_instance_valid(director), "Actual boss/director missing " + String(id)):
			continue
		var content: Dictionary = boss.chapter_content
		_expect(director._arena_radius >= 18., "Actual boss must use enlarged authored arena metadata")
		for entry: Dictionary in director._chunks:
			var cover = entry["node"]
			_expect(cover.has_meta("kit_path") and cover.get_meta("kit_part") == "ArenaCover", "Arena cover must use actual imported chapter architecture")
			_expect(cover.collision.shape.size == Vector3(2., 3., 2.) and is_zero_approx(cover.global_position.y - director._floor_y), "Modeled cover collider and foot anchor must match authored dimensions")
			var bounds := _cover_bounds(cover)
			_expect(absf(bounds.position.y) < .12 and absf(bounds.size.y - 3.) < .2 and absf(bounds.size.x - 2.) < .2 and absf(bounds.size.z - 2.) < .2, "Imported cover mesh bounds must agree with physical 2x3x2 dimensions")
		_expect(director._boss == boss, "World must bind the actual boss to its arena")
		var levels_root: Node3D = _world.campaign_runtime.current_level
		_expect(levels_root.is_ancestor_of(director.get_effect_parent()), "Boss effects must belong to current level")
		var phases: Dictionary = content["phases"]
		var numbers: Array[int] = []
		for key in phases:
			if int(key) > 1:
				numbers.append(int(key))
		numbers.sort()
		for phase in numbers:
			var threshold := float(phases[str(phase)]["threshold"])
			var previous_count: int = director.phase_event_count
			boss.receive_hit(maxf(0., boss.health - boss.max_health * threshold), 0., Vector3.ZERO, _world.player)
			_expect(director.phase_event_count == previous_count + 1, "%s phase%d must fire from ordinary HP damage" % [id, phase])
			var once: int = director.phase_event_count
			boss.health_changed.emit(boss.health, boss.max_health)
			director.on_boss_phase(boss, phase)
			_expect(director.phase_event_count == once, "%s phase%d must be idempotent" % [id, phase])
			paused = false
			if phase == 4:
				await process_frame
				_expect(boss.is_in_story_resolution() and director._combat_stopped, "Final10% must be non-combat")
				_expect(director.get_effect_parent().get_child_count() == 0, "Final choice must clear all live arena dangers/projectiles")
			else:
				var expected: Array = phases[str(phase)].get("arena_effects", [])
				var state: Dictionary = director.get_arena_state()
				if not expected.is_empty():
					_expect(not state.effects.is_empty(), "%s phase%d must create supported physical effects" % [id, phase])
					for effect in director.get_effect_parent().get_children():
						if "active" in effect and not effect.is_queued_for_deletion():
							_expect(not effect.active and not effect._area.monitoring, "Phase warning must not damage before activation")
				await create_timer(1.45).timeout
				for effect in director.get_effect_parent().get_children():
					if "specification" in effect:
						_expect(effect.active, "Phase effect must activate after warning")
						_expect(effect._marker.visible and effect._material.emission_enabled, "Arena warning/active visual missing")
						if bool(effect.specification.get("blocker", false)):
							_expect(not effect._block_shape.disabled, "Arena barrier must have real collision")
				if String(phases[str(phase)].get("arena_event", "")) in ["ring_collapse", "chains_break"]:
					var disabled := 0
					for entry: Dictionary in director._chunks:
						var shape = entry.get("collision")
						if not is_instance_valid(shape) or shape.disabled:
							disabled += 1
					_expect(disabled > 0, "Phase collapse must remove collision after warning")
			_phases += 1
		# Reset must cancel pending timers, all fields and the once-per-threshold ledger.
		boss.reset_enemy()
		_freeze_actors()
		paused = false
		await process_frame
		await physics_frame
		_expect(director.phase_event_count == 0 and not director._combat_stopped, "Boss reset must rearm arena")
		_expect(director.get_arena_state().effects.is_empty(), "Boss reset must remove previous phase effects")
		# A full-health reset must cancel phase1 projectiles before any HP threshold.
		boss.target_node = _world.player
		boss._ensure_boss_attack_executor()
		boss._boss_attack_executor.execute_active(boss, _world.player, {"name": "reset_projectile", "type": "projectile", "damage": 1.})
		var prior_root: Node3D = director.get_effect_parent()
		_expect(prior_root.get_child_count() > 0, "Phase1 projectile must be owned by the arena")
		boss.reset_enemy()
		_freeze_actors()
		await process_frame
		_expect(not is_instance_valid(prior_root) and director.get_effect_parent().get_child_count() == 0, "Full-health reset must cancel phase1 projectile lifetime")
		var skill: Dictionary = {}
		for phase_data: Dictionary in phases.values():
			for attack: Dictionary in phase_data.get("attacks", []):
				if attack.has("arena_effect"):
					skill = attack
					break
		_expect(not skill.is_empty(), "Each of eight bosses needs a named arena skill")
		if not skill.is_empty():
			await _check_skill(boss, director, skill)
		if String(content["id"]) == "boss_zhu_yin":
			await _check_final_ordinary_damage(boss, director)
		director.on_boss_died()
		await process_frame
		_expect(director.get_arena_state().effects.is_empty(), "Boss death must clear arena skill effects")
		var old_root: Node = director.get_effect_parent()
		_world._load_campaign_level(&"level_01_01")
		_freeze_actors()
		await process_frame
		_expect(not is_instance_valid(old_root), "Level teardown must release prior boss effect root")
		_bosses += 1
		print("BOSS_ARENA_CHECKED %s phases=%d skill=%s" % [id, numbers.size(), skill.get("name", "")])
	_world.free()
	for frame in 3:
		await physics_frame
	paused = false
	_expect(_bosses == 8 and _phases == 13 and _skills == 8, "Expected eight actual bosses, thirteen HP transitions and eight skills")
	print("BOSS_ARENA_COUNTS bosses=%d phases=%d skills=%d checks=%d" % [_bosses, _phases, _skills, _checks])
	if _failures.is_empty():
		print("ASHEN_BOSS_ARENA_CONTRACTS_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _create_world() -> AuditWorld:
	var world := AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		world.add_child(child)
	contents.free()
	root.add_child(world)
	return world

func _check_skill(boss, director, skill: Dictionary) -> void:
	var player = _world.player
	player.max_health = 2000.
	player.health = 2000.
	player.state = player.State.LOCOMOTION
	player.global_position = boss.global_position + Vector3(0., .1, -1.3)
	player.velocity = Vector3.ZERO
	player.embers = 100
	player.set_focus(player.max_focus)
	boss.target_node = player
	boss._active_attack_profile = skill.duplicate(true)
	boss._resolve_attack_data_or_dict(skill, StringName(String(skill.name)))
	await physics_frame
	await physics_frame
	# Real FSM ACTIVE entry invokes the production executor, not director directly.
	boss._change_state(boss.State.WINDUP, .1, true)
	boss._change_state(boss.State.ACTIVE, maxf(.1, float(skill.get("active", .1))))
	var immediate_health: float = player.health
	var owns_hit := BossExecutor.owns_active_hit(skill)
	if String(skill.get("type", "")) in ["radial_aoe", "targeted_impact_aoe"]:
		_expect(immediate_health < 2000., "Actual ACTIVE must apply authored primary AoE damage")
	if owns_hit:
		_expect(not boss.combat_area.active, "Executor-owned attack must not start a duplicate melee hit volume")
	await create_timer(.35).timeout
	if owns_hit:
		_expect(is_equal_approx(player.health, immediate_health), "Uninterrupted ACTIVE must not double-hit before arena warning finishes")
	boss._change_state(boss.State.RECOVERY, .6)
	var effect = null
	for child in director.get_effect_parent().get_children():
		if "specification" in child and not child.is_queued_for_deletion():
			effect = child
			break
	if not _expect(is_instance_valid(effect), "Named skill did not create actual arena effect: " + String(skill.name)):
		return
	_expect(director.skill_event_count == 1, "Actual ACTIVE hook must dispatch named skill once")
	player.state = player.State.LOCOMOTION
	var field_health: float = player.health
	var point: Vector3 = effect.global_position
	player.global_position = point + Vector3(.6, .15, 0.)
	player.velocity = Vector3.ZERO
	var near_jar: Node3D
	var far_jar: Node3D
	var near_cover: Node3D
	if bool(effect.specification.get("break_props", false)):
		near_jar = JarScene.instantiate()
		far_jar = JarScene.instantiate()
		director.host.add_child(near_jar)
		director.host.add_child(far_jar)
		near_jar.global_position = point + Vector3(.3, 0., .3)
		far_jar.global_position = point + Vector3(7., 0., 7.)
		near_cover = ArenaCover.new()
		director.host.add_child(near_cover)
		var layout: Dictionary = director.host.get_meta("modeled_layout", {})
		_expect(near_cover.setup(StringName(String(layout.get("theme", "theme_spirit_ruins")))), "Skill fixture must use imported cover")
		near_cover.global_position = point + Vector3(-.8, 0., 0.)
		_world._wire_destructible_rewards()
	var navigation: NavigationRegion3D = director.host.get_node("NavigationSurface")
	var revision := int(navigation.get_meta("geometry_revision", 0))
	if bool(effect.specification.get("blocker", false)):
		player.global_position = point + Vector3(5., .15, 0.)
	_expect(not effect.active and is_equal_approx(player.health, field_health), "Named skill warning must be harmless")
	await create_timer(1.25).timeout
	_expect(effect.active, "Named skill must activate visibly")
	var data: Dictionary = effect.specification
	if float(data.get("damage", 0.)) > 0.:
		_expect(player.health < field_health, "Active field must damage the actual player")
	if float(data.get("pull", 0.)) > 0.:
		_expect(Vector2(player.velocity.x, player.velocity.z).length() > .1, "Void field must physically pull player")
	if float(data.get("slow", 1.)) < 1.:
		Input.action_press("move_forward")
		player.velocity = Vector3.ZERO
		player._update_locomotion(1.)
		var slowed_speed := Vector2(player.velocity.x, player.velocity.z).length()
		effect.queue_free()
		await process_frame
		player.velocity = Vector3.ZERO
		player._update_locomotion(1.)
		var restored_speed := Vector2(player.velocity.x, player.velocity.z).length()
		Input.action_release("move_forward")
		_expect(slowed_speed > 0. and restored_speed > slowed_speed * 1.5, "Frost field must slow actual locomotion and restore it on removal")
	if int(data.get("drain_embers", 0)) > 0:
		_expect(player.embers < 100 and player.focus < player.max_focus, "Resonance field must drain real resources")
	if bool(data.get("break_props", false)):
		_expect(not is_instance_valid(near_jar) or near_jar.is_broken(), "Skill impact must break nearby scene prop")
		_expect(is_instance_valid(far_jar) and not far_jar.is_broken(), "Skill impact must preserve distant scene prop")
		_expect(not is_instance_valid(near_cover) or near_cover.is_broken, "Skill impact must destroy actual modeled cover within its spatial radius")
	if bool(data.get("blocker", false)):
		_expect(not effect._block_shape.disabled, "Illusion wall must enable solid collision")
		var a: Vector3 = effect.global_position + Vector3(0., .8, -2.)
		var b: Vector3 = effect.global_position + Vector3(0., .8, 2.)
		var hit := _world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
		_expect(not hit.is_empty(), "Illusion wall must obstruct a physical world ray")
		await _await_revision(navigation, revision)
		var blocked_path := _wall_path(navigation, effect.global_transform)
		_expect(_path_avoids_wall(blocked_path, effect.global_transform, float(data.get("width", 3.))), "Actual navigation must route around newly solid wall")
		var blocked_length := _path_length(blocked_path)
		var wall_transform: Transform3D = effect.global_transform
		revision = int(navigation.get_meta("geometry_revision", 0))
		effect._blocker.receive_hit_payload({"damage": 100.})
		await process_frame
		_expect(not is_instance_valid(effect), "Actual combat payload must break the illusion wall")
		await _await_revision(navigation, revision)
		var open_path := _wall_path(navigation, wall_transform)
		_expect(open_path.size() >= 2 and _path_length(open_path) < blocked_length - .2, "Removing wall must restore shorter real navigation route")
	_skills += 1

func _check_final_ordinary_damage(boss, director) -> void:
	boss.reset_enemy()
	_freeze_actors()
	await process_frame
	_final_signals = 0
	_final_phases.clear()
	boss.story_threshold_reached.connect(_record_final_story)
	boss.phase_changed.connect(_record_final_phase)
	boss.story_resolution_entered.connect(_record_final_entered)
	var player = _world.player
	player.health = 2000.
	player.state = player.State.LOCOMOTION
	player.global_position = boss.global_position + Vector3(2., .1, 0.)
	var boss_health: float = boss.health
	boss._apply_phase_slam(4.5, 22., 28.)
	_expect(player.health < 2000. and is_equal_approx(boss.health, boss_health), "Phase slam must damage nearby player without self-hit")
	var hurt_health: float = player.health
	player.global_position = boss.global_position + Vector3(20., .1, 0.)
	boss._apply_phase_slam(4.5, 22., 28.)
	_expect(is_equal_approx(player.health, hurt_health), "Phase slam must preserve out-of-range player")
	boss.receive_hit(999999., 0., Vector3.ZERO, _world.player)
	paused = false
	await process_frame
	_expect(is_equal_approx(boss.health, boss.max_health * .1), "Normal lethal hit must stop final boss exactly at10%")
	_expect(boss.is_in_story_resolution() and boss.state != boss.State.DEAD, "Normal lethal hit must enter ending choice, not kill boss")
	_expect(_final_signals == 1 and _final_phases == [2, 3, 4], "Large hit must emit sequential phases and one story choice")
	_expect(_final_entered == 1, "World and enemy final entry must emit story resolution only once")
	_expect(director._combat_stopped and director.get_arena_state().effects.is_empty(), "Final ordinary hit must stop all arena dangers")
	_expect(_world.player.gravity_override < 0., "Final choice must restore gravity after zero-G phase")
	boss.receive_hit(999999., 0., Vector3.ZERO, _world.player)
	_expect(_final_signals == 1 and is_equal_approx(boss.health, boss.max_health * .1), "Repeated hits cannot duplicate final choice")
	boss.reset_enemy()
	_freeze_actors()
	await process_frame
	boss.receive_hit(999999., 0., Vector3.ZERO, _world.player)
	paused = false
	_expect(_final_signals == 2, "Reset must rearm ordinary-hit final choice")
	for status in ["bleed", "poison"]:
		boss.reset_enemy()
		_freeze_actors()
		await process_frame
		boss.health = boss.max_health * .1 + (10. if status == "bleed" else 1.)
		boss.apply_status(StringName(status), 100. if status == "bleed" else 50., player)
		if status == "poison":
			boss._tick_statuses(1.1)
		paused = false
		_expect(is_equal_approx(boss.health, boss.max_health * .1) and boss.is_in_story_resolution(), "Status damage crossing final10% must enter choice: " + status)
	_expect(_final_signals == 4 and _final_entered == 4, "Each reset must rearm exactly one ending, including status damage")

func _record_final_story(_flag: StringName, _ratio: float) -> void:
	_final_signals += 1
func _record_final_phase(_boss: Node, phase: int) -> void:
	_final_phases.append(phase)
func _record_final_entered(_boss: Node) -> void:
	_final_entered += 1

func _await_revision(region: NavigationRegion3D, previous: int) -> void:
	for frame in 240:
		await physics_frame
		if int(region.get_meta("geometry_revision", 0)) > previous:
			await physics_frame
			return
	_expect(false, "Changing arena collision must publish a new navigation revision")

func _wall_path(region: NavigationRegion3D, transform: Transform3D) -> PackedVector3Array:
	var map := region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, transform * Vector3(0., .1, -4.))
	var end := NavigationServer3D.map_get_closest_point(map, transform * Vector3(0., .1, 4.))
	return NavigationServer3D.map_get_path(map, start, end, true)

func _path_length(path: PackedVector3Array) -> float:
	var distance := 0.
	for index in range(1, path.size()):
		distance += path[index - 1].distance_to(path[index])
	return distance

func _path_avoids_wall(path: PackedVector3Array, transform: Transform3D, width: float) -> bool:
	if path.size() < 2:
		return false
	var inverse := transform.affine_inverse()
	for index in range(1, path.size()):
		var steps := maxi(2, ceili(path[index - 1].distance_to(path[index]) / .15))
		for step in steps + 1:
			var point := inverse * path[index - 1].lerp(path[index], float(step) / float(steps))
			if absf(point.x) < width * .5 and absf(point.z) < .35:
				return false
	return true

func _cover_bounds(cover: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for mesh: MeshInstance3D in cover.find_children("*", "MeshInstance3D", true, false):
		var local := cover.global_transform.affine_inverse() * mesh.global_transform
		var transformed := local * mesh.get_aabb()
		bounds = bounds.merge(transformed) if found else transformed
		found = true
	return bounds
func _freeze_actors() -> void:
	_world.player.set_physics_process(false)
	_world.player.set_process_unhandled_input(false)
	for enemy in _world.enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
