extends CharacterBody3D

signal health_changed(current, maximum)
signal defeated(enemy, reward, is_guardian)
signal engagement_changed(enemy, is_guardian, engaged)
signal execution_break_changed(current, maximum)
signal story_threshold_reached(story_flag: StringName, health_ratio: float)
signal grab_started(target)
signal grab_ended(target)
signal weak_point_exposed(enemy)
signal story_resolution_entered(enemy)

enum State {
	IDLE,
	CHASE,
	WINDUP,
	ACTIVE,
	RECOVERY,
	STAGGER,
	PARRY_VULNERABLE,
	GUARD_BROKEN,
	WEAK_POINT_EXPOSED,
	GRAB_WINDUP,
	GRAB_ACTIVE,
	GRAB_RECOVERY,
	DEAD,
	RETURN,
}

enum EnemyType {
	HOLLOW_SENTINEL,
	ASH_STALKER,
	CINDER_GUARDIAN,
}

const CombatAreaScript = preload("res://scripts/combat_area.gd")
const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const ChapterEnemyFactory = preload("res://scripts/combat/enemy_factory.gd")
const BossCatalog = preload("res://scripts/combat/data/boss_execution_catalog.gd")
const GrabProfileScript = preload("res://scripts/combat/data/grab_profile.gd")
const GrabPairedDirectorScript = preload("res://scripts/combat/grab_paired_director.gd")
const AI_DECISION_INTERVAL := 0.1
const WEAK_POINT_EXPOSE_DEFAULT := 3.2
const GRAB_CHANCE := 0.22

var world_node: Node
var target_node: Node3D
var audio_node: Node
var spawn_origin := Vector3.ZERO
var guardian := false
var enemy_type: EnemyType = EnemyType.HOLLOW_SENTINEL
var chapter_content: Dictionary = {}
var content_id := ""
var configured := false
var _visuals_built_key := ""
var _attack_profile: Dictionary = {}

var max_health := 80.0
var health := 80.0
var move_speed := 3.6
var acceleration := 15.0
var aggro_range := 13.0
var disengage_range := 20.0
var leash_range := 17.0
var attack_range := 2.15
var reward := 35
var poise_limit := 24.0
var poise := 0.0
var poise_reset_time := 0.0
var stagger_duration := 0.48
var supports_backstab := true
var supports_riposte := true
var _execution_claimer: Node = null
var _execution_claim_time := 0.0
const PARRY_VULN_SECONDS := 2.0
const GUARD_BROKEN_SECONDS := 2.2
const HEAVY_GUARD_BREAK_POWER := 40.0
var boss_break_profile = null
var max_execution_break := 100.0
var execution_break := 0.0
var _grab_profile = null
var _grab_area: Area3D = null
var _grab_shape: CollisionShape3D = null
var _grab_target: Node3D = null
var _grab_damage_applied := false
var _grab_director = null
var _story_resolution := false


var state: State = State.IDLE
var state_time := 0.0
var state_duration := 0.0
var engaged := false
var attack_index := 0
var _phase := 1
var _phase_transition_played := false
var _phase_two_played := false
var _heal_speed_id := 0
const PHASE_TWO_THRESHOLD := 0.5
const PHASE_THREE_THRESHOLD := 0.25
# 内容驱动阶段：threshold<0 表示用默认常量；attacks 按阶段索引
var _content_phase_two_threshold := -1.0
var _content_phase_three_threshold := -1.0
var _content_phase_attacks: Dictionary = {}
var attack_windup := 0.55
var attack_active := 0.18
var attack_recovery := 0.70
var attack_damage := 16.0
var attack_stagger := 22.0
var attack_lunge := 1.4
var attack_heavy := false
var attack_is_low_sweep := false
var navigation_refresh := 0.0
var gravity := 24.0
var knockback_velocity := Vector3.ZERO
var _cached_has_target := false
var _cached_target_position := Vector3.ZERO
var _cached_distance_to_target := INF
var _cached_chase_direction := Vector3.ZERO
var _visual_frozen := false

var navigation_agent: NavigationAgent3D
var body_collision: CollisionShape3D
var body_shape: CapsuleShape3D
var visual_root: Node3D
var body_visual_root: Node3D
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var weapon_pivot: Node3D
var weapon_mesh: MeshInstance3D
var telegraph_mesh: MeshInstance3D
var combat_area
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D
var telegraph_material: StandardMaterial3D
var eye_material: StandardMaterial3D


func setup(world, target, audio, spawn_position, is_guardian = false, new_type: EnemyType = EnemyType.HOLLOW_SENTINEL) -> void:
	world_node = world
	target_node = target if target is Node3D else null
	audio_node = audio
	spawn_origin = spawn_position
	guardian = bool(is_guardian)
	if guardian:
		enemy_type = EnemyType.CINDER_GUARDIAN
	else:
		enemy_type = new_type
	configured = true
	_visuals_built_key = ""
	if guardian and boss_break_profile == null:
		content_id = "boss_giant_gate" if content_id.is_empty() else content_id
		_setup_boss_break_profile()
	if is_inside_tree():
		_ensure_nodes()
		_apply_tuning()
		reset_enemy()


## 用章节内容字典配置敌人（数值 + 外观）
func setup_from_content(world, target, audio, spawn_position, content: Dictionary, is_guardian := false) -> void:
	chapter_content = content.duplicate(true)
	content_id = String(content.get("id", ""))
	_attack_profile = Dictionary(content.get("attack", {}))
	_parse_boss_phases(content)
	setup(world, target, audio, spawn_position, is_guardian, EnemyType.HOLLOW_SENTINEL)
	if is_guardian:
		_setup_boss_break_profile()


func _setup_boss_break_profile() -> void:
	boss_break_profile = BossCatalog.profile_for_boss_id(content_id)
	if boss_break_profile == null:
		boss_break_profile = BossCatalog.make_giant_gate()
	max_execution_break = float(boss_break_profile.max_execution_break)
	execution_break = 0.0
	supports_backstab = false
	supports_riposte = false
	_grab_profile = GrabProfileScript.make_boss_default() if bool(boss_break_profile.grab_enabled) else null
	execution_break_changed.emit(execution_break, max_execution_break)


func _parse_boss_phases(content: Dictionary) -> void:
	# 解析 ChapterContent.boss().phases 为阈值与招式表
	_content_phase_two_threshold = -1.0
	_content_phase_three_threshold = -1.0
	_content_phase_attacks.clear()
	var phases = content.get("phases", {})
	if not phases is Dictionary or phases.is_empty():
		return
	for key in phases.keys():
		var phase_num := int(key)
		var phase_data: Dictionary = phases[key]
		if phase_data.is_empty():
			continue
		_content_phase_attacks[phase_num] = phase_data.get("attacks", [])
		var threshold := float(phase_data.get("threshold", -1.0))
		if phase_num == 2 and threshold >= 0.0:
			_content_phase_two_threshold = threshold
		elif phase_num == 3 and threshold >= 0.0:
			_content_phase_three_threshold = threshold


func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	_ensure_nodes()
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if not configured:
		spawn_origin = global_position
	_apply_tuning()
	reset_enemy()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _story_resolution:
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
	# HitStop：冻本实体 AI/状态推进，重力与滑动保留
	if _visual_frozen:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = minf(velocity.y, 0.0)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if poise_reset_time > 0.0:
		poise_reset_time -= delta
		if poise_reset_time <= 0.0:
			poise = 0.0
	state_time = maxf(state_time - delta, 0.0)
	if _execution_claim_time > 0.0:
		_execution_claim_time = maxf(_execution_claim_time - delta, 0.0)
		if _execution_claim_time <= 0.0:
			_release_execution_claim()
	navigation_refresh -= delta
	if navigation_refresh <= 0.0:
		_refresh_decision_cache()
	_update_state(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	_update_telegraph()


func reset_enemy() -> void:
	_ensure_nodes()
	_apply_tuning()
	combat_area.end_swing()
	_release_execution_claim()
	_set_engaged(false)
	state = State.IDLE
	state_time = 0.0
	state_duration = 0.0
	health = max_health
	poise = 0.0
	execution_break = 0.0
	execution_break_changed.emit(execution_break, max_execution_break)
	_end_grab()
	poise_reset_time = 0.0
	attack_index = 0
	_phase = 1
	_phase_transition_played = false
	_phase_two_played = false
	_heal_speed_id += 1  # invalidate any pending heal-speed timer
	_story_resolution = false
	navigation_refresh = 0.0
	_cached_has_target = false
	_cached_target_position = global_position
	_cached_distance_to_target = INF
	_cached_chase_direction = Vector3.ZERO
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	global_position = spawn_origin
	rotation = Vector3.ZERO
	visual_root.rotation = Vector3.ZERO
	visual_root.scale = Vector3.ONE * (1.22 if guardian else 1.0)
	visible = true
	body_collision.set_deferred("disabled", false)
	telegraph_mesh.visible = false
	_set_visual_palette()
	set_physics_process(true)
	health_changed.emit(health, max_health)


func receive_hit(damage, stagger, hit_direction, source) -> void:
	receive_hit_payload({
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"direction": hit_direction,
		"source": source,
		"execution_break_damage": maxf(float(stagger), 0.0) * 0.35,
		"tags": [],
		"blockable": true,
		"parryable": true,
	})


func receive_hit_payload(payload: Dictionary) -> void:
	if state == State.DEAD:
		return
	# 处决占用期间不受普通命中打断
	if _execution_claimer != null and is_instance_valid(_execution_claimer):
		return
	if state in [State.GRAB_WINDUP, State.GRAB_ACTIVE]:
		return
	var incoming_damage := maxf(float(payload.get("damage", 0.0)), 0.0)
	var incoming_stagger := maxf(float(payload.get("stagger", payload.get("poise", 0.0))), 0.0)
	var guard_power := incoming_damage + incoming_stagger * 0.35
	var source = payload.get("source")
	health = maxf(health - incoming_damage, 0.0)
	health_changed.emit(health, max_health)
	_play_audio("hurt", -8.0, 0.82 if guardian else 1.0)
	if guardian and not _phase_transition_played and get_health_ratio() <= _phase_two_cut():
		_trigger_phase_transition()
	if guardian and not _phase_two_played and get_health_ratio() <= _phase_three_cut():
		_trigger_phase_transition()
	if health <= 0.0:
		_die()
		return
	if (target_node == null or not is_instance_valid(target_node)) and source is Node3D:
		target_node = source
		navigation_refresh = 0.0
	_set_engaged(true)
	_apply_execution_break_from_payload(payload)
	poise += incoming_stagger
	poise_reset_time = 1.6
	var direction := Vector3.ZERO
	var hit_direction = payload.get("direction", Vector3.ZERO)
	if hit_direction is Vector3:
		direction = hit_direction
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		knockback_velocity = direction.normalized() * (1.8 if guardian else 3.0)
	if state == State.WEAK_POINT_EXPOSED:
		return
	if (
		not guardian
		and supports_riposte
		and poise >= poise_limit
		and guard_power >= HEAVY_GUARD_BREAK_POWER
	):
		poise = 0.0
		_change_state(State.GUARD_BROKEN, GUARD_BROKEN_SECONDS)
		return
	if poise >= poise_limit:
		poise = 0.0
		_change_state(State.STAGGER, stagger_duration)


func _apply_execution_break_from_payload(payload: Dictionary) -> void:
	if not guardian or boss_break_profile == null:
		return
	if state == State.WEAK_POINT_EXPOSED:
		return
	var amount := maxf(float(payload.get("execution_break_damage", 0.0)), 0.0)
	if amount <= 0.0:
		amount = maxf(float(payload.get("stagger", payload.get("poise", 0.0))), 0.0) * 0.3
	var tags = payload.get("tags", [])
	if tags is Array:
		if &"charged" in tags or "charged" in tags:
			amount *= float(boss_break_profile.charged_break_bonus)
		if &"leap" in tags or "leap" in tags:
			amount *= float(boss_break_profile.leap_break_bonus)
		if &"weak_point" in tags or "weak_point" in tags:
			amount *= 1.8
	execution_break = minf(execution_break + amount, max_execution_break)
	execution_break_changed.emit(execution_break, max_execution_break)
	if execution_break >= max_execution_break - 0.001:
		execution_break = 0.0
		execution_break_changed.emit(execution_break, max_execution_break)
		_change_state(State.WEAK_POINT_EXPOSED, float(boss_break_profile.expose_seconds))
		weak_point_exposed.emit(self)


func receive_parry(source: Node = null) -> void:
	if state == State.DEAD:
		return
	if source is Node3D:
		target_node = source
	_set_engaged(true)
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	poise = 0.0
	_release_execution_claim()
	_play_audio("hurt", -5.0, 0.68 if guardian else 0.82)
	if guardian or not supports_riposte:
		_change_state(State.STAGGER, 1.05 if guardian else 1.35)
	else:
		_change_state(State.PARRY_VULNERABLE, PARRY_VULN_SECONDS)


func is_execution_candidate(kind: StringName) -> bool:
	if state == State.DEAD:
		return false
	if _execution_claimer != null and is_instance_valid(_execution_claimer):
		return false
	match kind:
		&"weak_point":
			return guardian and state == State.WEAK_POINT_EXPOSED
		&"parry":
			return (not guardian) and supports_riposte and state == State.PARRY_VULNERABLE
		&"guard_break":
			return (not guardian) and supports_riposte and state == State.GUARD_BROKEN
		&"back":
			return (not guardian) and supports_backstab and state not in [
				State.DEAD, State.WINDUP, State.ACTIVE, State.PARRY_VULNERABLE,
				State.GUARD_BROKEN, State.WEAK_POINT_EXPOSED, State.GRAB_WINDUP, State.GRAB_ACTIVE
			]
	return false


func get_boss_break_profile():
	return boss_break_profile


func try_claim_execution(claimer: Node, duration: float = 2.8) -> bool:
	if claimer == null or not is_instance_valid(claimer):
		return false
	if _execution_claimer != null and is_instance_valid(_execution_claimer) and _execution_claimer != claimer:
		return false
	_execution_claimer = claimer
	_execution_claim_time = duration
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	return true


func release_execution_claim(claimer: Node = null) -> void:
	if claimer != null and _execution_claimer != claimer:
		return
	_release_execution_claim()


func apply_execution_damage(amount: float, allow_lethal: bool = true) -> void:
	if state == State.DEAD or _story_resolution:
		return
	var dmg := maxf(amount, 0.0)
	var floor_ratio := 0.05
	if boss_break_profile != null:
		floor_ratio = float(boss_break_profile.story_floor_ratio)
	var floor_hp := maxf(max_health * floor_ratio, 1.0)
	if not allow_lethal or (guardian and boss_break_profile != null and not bool(boss_break_profile.allow_lethal_on_execution)):
		health = maxf(health - dmg, floor_hp)
		if health <= floor_hp + 0.01:
			story_threshold_reached.emit(
				boss_break_profile.story_flag if boss_break_profile != null else &"story",
				get_health_ratio()
			)
	else:
		health = maxf(health - dmg, 0.0)
	health_changed.emit(health, max_health)
	_play_audio("hurt", -4.0, 0.7)
	if health <= 0.0:
		_die()
	elif state == State.WEAK_POINT_EXPOSED:
		_change_state(State.STAGGER, 0.85)


func get_execution_anchor(anchor: StringName) -> Vector3:
	if boss_break_profile != null and (
		anchor == boss_break_profile.weak_point_anchor
		or anchor in [&"furnace_core", &"chest_eye", &"tail_root", &"fusion_core", &"star_core"]
	):
		var local: Vector3 = boss_break_profile.weak_point_offset
		return global_position + global_transform.basis * local
	match anchor:
		&"back":
			return global_position - (-global_transform.basis.z) * 0.55 + Vector3.UP * 1.05
		_:
			return global_position + (-global_transform.basis.z) * 0.35 + Vector3.UP * 1.15


func _release_execution_claim() -> void:
	_execution_claimer = null
	_execution_claim_time = 0.0


func on_player_healing() -> void:
	if state == State.DEAD or not is_instance_valid(target_node):
		return
	if not engaged:
		_set_engaged(true)
		_change_state(State.CHASE)
		_refresh_decision_cache()
	if guardian and _cached_distance_to_target > 3.0:
		attack_index += 1
		_apply_long_range_attack()
		_change_state(State.WINDUP, attack_windup * 0.7)
	elif not guardian:
		var original_speed := move_speed
		move_speed *= 1.5
		_heal_speed_id += 1
		var current_id := _heal_speed_id
		var restore_timer := get_tree().create_timer(1.8)
		restore_timer.timeout.connect(func():
			if is_instance_valid(self) and _heal_speed_id == current_id:
				move_speed = original_speed
		)


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * (1.6 if guardian else 1.25)


func is_targetable() -> bool:
	return state != State.DEAD and health > 0.0 and visible


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(health / max_health, 0.0, 1.0)


func _update_state(delta: float) -> void:
	var has_target := _cached_has_target
	var target_position := _cached_target_position
	var distance_to_target := _cached_distance_to_target
	match state:
		State.IDLE:
			_slow_horizontal(delta, acceleration)
			if (
				has_target
				and not _target_is_in_sanctuary()
				and distance_to_target <= aggro_range
			):
				_set_engaged(true)
				_change_state(State.CHASE)
		State.CHASE:
			var distance_from_home := _horizontal_distance(global_position, spawn_origin)
			if (
				not has_target
				or _target_is_in_sanctuary()
				or distance_to_target > disengage_range
				or distance_from_home > leash_range
			):
				_set_engaged(false)
				_change_state(State.RETURN)
			elif distance_to_target <= attack_range and absf(target_position.y - global_position.y) < 2.5:
				_start_attack()
			else:
				_chase_target(target_position, delta)
		State.WINDUP:
			_slow_horizontal(delta, acceleration * 1.4)
			if has_target:
				_face_point(target_position, delta * 9.0)
			if state_time <= 0.0:
				_change_state(State.ACTIVE, attack_active)
		State.ACTIVE:
			var forward := -global_transform.basis.z
			velocity.x = forward.x * attack_lunge
			velocity.z = forward.z * attack_lunge
			if state_time <= 0.0:
				_change_state(State.RECOVERY, attack_recovery)
		State.RECOVERY:
			_slow_horizontal(delta, acceleration * 0.8)
			if state_time <= 0.0:
				_change_state(
					State.CHASE
					if has_target and not _target_is_in_sanctuary()
					else State.RETURN
				)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, knockback_velocity.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, knockback_velocity.z, acceleration * delta)
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 8.0 * delta)
			if state_time <= 0.0:
				_change_state(
					State.CHASE
					if has_target and not _target_is_in_sanctuary()
					else State.RETURN
				)
		State.PARRY_VULNERABLE, State.GUARD_BROKEN:
			# 易处决窗：定身等待处决或超时恢复
			_slow_horizontal(delta, acceleration * 2.0)
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
			if state_time <= 0.0:
				_change_state(
					State.CHASE
					if has_target and not _target_is_in_sanctuary()
					else State.RETURN
				)
		State.WEAK_POINT_EXPOSED:
			_slow_horizontal(delta, acceleration * 2.4)
			knockback_velocity = Vector3.ZERO
			if state_time <= 0.0:
				_change_state(State.CHASE if has_target else State.RETURN)
		State.GRAB_WINDUP:
			_slow_horizontal(delta, acceleration * 1.5)
			if has_target:
				_face_point(target_position, delta * 8.0)
			_update_grab_area_pose()
			if state_time <= 0.0:
				if _try_resolve_grab_capture():
					_change_state(State.GRAB_ACTIVE, float(_grab_profile.hold_seconds) if _grab_profile else 1.4)
				else:
					_change_state(State.GRAB_RECOVERY, float(_grab_profile.recovery_on_miss_seconds) if _grab_profile else 1.1)
		State.GRAB_ACTIVE:
			_slow_horizontal(delta, acceleration * 3.0)
			_update_grab_hold(delta)
			var director_done: bool = _grab_director != null and not bool(_grab_director.active)
			if director_done or state_time <= 0.0:
				_end_grab()
				_change_state(State.RECOVERY, 0.55)
		State.GRAB_RECOVERY:
			_slow_horizontal(delta, acceleration)
			if state_time <= 0.0:
				_change_state(State.CHASE if has_target else State.RETURN)
		State.RETURN:
			_set_engaged(false)
			var home_offset := spawn_origin - global_position
			home_offset.y = 0.0
			if home_offset.length_squared() <= 0.16:
				global_position.x = spawn_origin.x
				global_position.z = spawn_origin.z
				_slow_horizontal(delta, acceleration * 2.0)
				_change_state(State.IDLE)
			else:
				var home_direction := home_offset.normalized()
				velocity.x = move_toward(
					velocity.x,
					home_direction.x * move_speed,
					acceleration * delta
				)
				velocity.z = move_toward(
					velocity.z,
					home_direction.z * move_speed,
					acceleration * delta
				)
				_face_direction(home_direction, delta * 8.0)


func _chase_target(target_position: Vector3, delta: float) -> void:
	var direction := _cached_chase_direction
	velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	if direction.length_squared() > 0.001:
		_face_direction(direction, delta * 8.0)


func _refresh_decision_cache() -> void:
	navigation_refresh = AI_DECISION_INTERVAL
	_cached_has_target = _has_valid_target()
	if not _cached_has_target:
		_cached_target_position = global_position
		_cached_distance_to_target = INF
		_cached_chase_direction = Vector3.ZERO
		return
	_cached_target_position = _get_target_position()
	_cached_distance_to_target = _horizontal_distance(global_position, _cached_target_position)
	navigation_agent.target_position = _cached_target_position
	_cached_chase_direction = _safe_navigation_direction(_cached_target_position)


func _safe_navigation_direction(target_position: Vector3) -> Vector3:
	var direct := target_position - global_position
	direct.y = 0.0
	if direct.length_squared() > 0.001:
		direct = direct.normalized()
	if not navigation_agent.is_inside_tree():
		return direct
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return direct
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return direct
	if navigation_agent.is_navigation_finished():
		return direct
	var next_point := navigation_agent.get_next_path_position()
	var path_direction := next_point - global_position
	path_direction.y = 0.0
	if path_direction.length_squared() < 0.0025:
		return direct
	return path_direction.normalized()


func _start_attack() -> void:
	# Boss 近距概率进入独立抓投前摇（不走 CombatArea）
	if (
		guardian
		and _grab_profile != null
		and _cached_distance_to_target <= 2.4
		and state == State.CHASE
		and randf() < GRAB_CHANCE
	):
		_begin_grab_telegraph()
		return
	_select_attack_profile()
	_change_state(State.WINDUP, attack_windup)


func _begin_grab_telegraph() -> void:
	_ensure_grab_area()
	_grab_damage_applied = false
	_grab_target = null
	if _grab_area != null:
		_grab_area.monitoring = true
	_change_state(State.GRAB_WINDUP, float(_grab_profile.telegraph_seconds))


func _ensure_grab_area() -> void:
	if _grab_area != null:
		return
	_grab_area = Area3D.new()
	_grab_area.name = "GrabCapture"
	_grab_area.collision_layer = 0
	_grab_area.collision_mask = 2  # player layer
	_grab_area.monitoring = false
	_grab_area.monitorable = false
	add_child(_grab_area)
	_grab_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(_grab_profile.capture_radius) if _grab_profile else 1.4
	_grab_shape.shape = sphere
	_grab_area.add_child(_grab_shape)


func _update_grab_area_pose() -> void:
	if _grab_area == null:
		return
	var forward := -global_transform.basis.z
	_grab_area.position = Vector3(0, 1.1, 0) + forward * 1.1


func _try_resolve_grab_capture() -> bool:
	if _grab_area == null or target_node == null or not is_instance_valid(target_node):
		return false
	_update_grab_area_pose()
	var candidate: Node3D = null
	for body in _grab_area.get_overlapping_bodies():
		if body == target_node or (body is Node3D and body.is_in_group("player")):
			candidate = body
			break
	if candidate == null and _horizontal_distance(global_position, target_node.global_position) <= float(_grab_profile.capture_radius) + 0.35:
		candidate = target_node
	if candidate == null:
		return false
	_grab_target = candidate
	if _grab_director == null:
		_grab_director = GrabPairedDirectorScript.new()
	if not _grab_director.begin(self, _grab_target, _grab_profile):
		_grab_target = null
		return false
	grab_started.emit(_grab_target)
	return true


func _update_grab_hold(delta: float) -> void:
	if _grab_director != null and _grab_director.active:
		_grab_director.update(delta)
		_grab_damage_applied = _grab_director.damage_done
		if not _grab_director.active:
			# Director 已自然结束
			_grab_target = null
		return
	# 兼容：无 Director 时退回旧吸附逻辑
	if _grab_target == null or not is_instance_valid(_grab_target):
		return
	var hold_point := global_position + (-global_transform.basis.z) * 1.05 + Vector3.UP * 1.15
	_grab_target.global_position = _grab_target.global_position.lerp(hold_point, 0.35)


func _end_grab() -> void:
	if _grab_area != null:
		_grab_area.monitoring = false
	var ended_target := _grab_target
	if _grab_director != null and _grab_director.active:
		_grab_director.force_cancel(&"state_exit")
		ended_target = ended_target if ended_target != null else null
	elif ended_target != null and is_instance_valid(ended_target):
		if ended_target.has_method("end_grabbed"):
			ended_target.end_grabbed(self)
	if ended_target != null:
		grab_ended.emit(ended_target)
	_grab_target = null
	_grab_damage_applied = false


func enter_story_resolution() -> void:
	# 命运选择：冻结 AI，保持存活
	_story_resolution = true
	_release_execution_claim()
	if _grab_director != null and _grab_director.active:
		_grab_director.force_cancel(&"story")
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	_set_engaged(false)
	_change_state(State.IDLE, 0.0)
	story_resolution_entered.emit(self)


func is_in_story_resolution() -> bool:
	return _story_resolution


func _select_attack_profile() -> void:
	var distance_to_target := _cached_distance_to_target
	attack_is_low_sweep = false
	if enemy_type == EnemyType.ASH_STALKER:
		attack_index += 1
		attack_windup = 0.22
		attack_active = 0.10
		attack_recovery = 0.18
		attack_damage = 8.0
		attack_stagger = 8.0
		attack_lunge = 0.8
		attack_heavy = false
		attack_is_low_sweep = true  # 潜行低扫，可被跳跃豁免
	elif not guardian:
		attack_windup = 0.55
		attack_active = 0.18
		attack_recovery = 0.70
		attack_damage = 16.0
		attack_stagger = 22.0
		attack_lunge = 1.4
		attack_heavy = false
		attack_is_low_sweep = distance_to_target <= attack_range * 0.85
	else:
		attack_index += 1
		# 优先消费章节 Boss 招式表
		if not _content_phase_attacks.is_empty():
			_apply_content_phase_attack()
		elif distance_to_target < 2.0:
			_apply_close_range_attack()
		elif distance_to_target > 3.5:
			_apply_long_range_attack()
		else:
			_apply_mid_range_attack()
		# Boss 近距轻击也标 low_sweep
		if not attack_heavy and distance_to_target < 2.0:
			attack_is_low_sweep = true
	telegraph_material.albedo_color = Color(1.0, 0.22, 0.04, 0.62) if attack_heavy else Color(1.0, 0.08, 0.04, 0.56)
	telegraph_material.emission = Color(1.0, 0.12, 0.02) if attack_heavy else Color(1.0, 0.02, 0.01)


func _phase_two_cut() -> float:
	return _content_phase_two_threshold if _content_phase_two_threshold >= 0.0 else PHASE_TWO_THRESHOLD


func _phase_three_cut() -> float:
	# 仅两阶段 Boss：第三段阈值压到不可达
	if not _content_phase_attacks.is_empty() and not _content_phase_attacks.has(3):
		return -1.0
	return _content_phase_three_threshold if _content_phase_three_threshold >= 0.0 else PHASE_THREE_THRESHOLD


func _current_phase() -> int:
	var three_cut := _phase_three_cut()
	if three_cut >= 0.0 and get_health_ratio() <= three_cut:
		return 3
	if get_health_ratio() <= _phase_two_cut():
		return 2
	return 1


func _apply_content_phase_attack() -> void:
	# 按当前阶段循环 ChapterContent 招式
	var phase := _current_phase()
	var attacks: Array = _content_phase_attacks.get(phase, [])
	if attacks.is_empty():
		attacks = _content_phase_attacks.get(1, [])
	if attacks.is_empty():
		_apply_mid_range_attack()
		return
	var profile: Dictionary = attacks[(attack_index - 1) % attacks.size()]
	attack_windup = float(profile.get("windup", 0.6))
	attack_active = float(profile.get("active", 0.2))
	attack_recovery = float(profile.get("recovery", 0.7))
	attack_damage = float(profile.get("damage", 20.0))
	attack_stagger = float(profile.get("stagger", 24.0))
	attack_lunge = float(profile.get("lunge", 1.4))
	attack_heavy = bool(profile.get("heavy", false))


func _apply_close_range_attack() -> void:
	var phase := _current_phase()
	attack_heavy = false
	if phase >= 2 and attack_index % 3 == 0:
		attack_heavy = true
		if phase == 3:
			attack_windup = 0.45; attack_active = 0.18; attack_recovery = 0.40
			attack_damage = 28.0; attack_stagger = 34.0; attack_lunge = 1.5
		else:
			attack_windup = 0.55; attack_active = 0.20; attack_recovery = 0.48
			attack_damage = 24.0; attack_stagger = 28.0; attack_lunge = 1.3
		return
	if phase == 3:
		attack_windup = 0.32; attack_active = 0.12; attack_recovery = 0.34
		attack_damage = 26.0; attack_stagger = 30.0; attack_lunge = 1.4
	elif phase == 2:
		attack_windup = 0.38; attack_active = 0.14; attack_recovery = 0.40
		attack_damage = 22.0; attack_stagger = 26.0; attack_lunge = 1.3
	else:
		attack_windup = 0.48; attack_active = 0.16; attack_recovery = 0.52
		attack_damage = 18.0; attack_stagger = 22.0; attack_lunge = 1.1


func _apply_mid_range_attack() -> void:
	var phase := _current_phase()
	attack_heavy = attack_index % 2 == 1
	if attack_heavy:
		if phase == 3:
			attack_windup = 0.78; attack_active = 0.26; attack_recovery = 0.68
			attack_damage = 44.0; attack_stagger = 52.0; attack_lunge = 2.6
		elif phase == 2:
			attack_windup = 0.95; attack_active = 0.30; attack_recovery = 0.82
			attack_damage = 38.0; attack_stagger = 46.0; attack_lunge = 2.4
		else:
			attack_windup = 1.18; attack_active = 0.34; attack_recovery = 1.08
			attack_damage = 34.0; attack_stagger = 42.0; attack_lunge = 2.1
	else:
		if phase == 3:
			attack_windup = 0.48; attack_active = 0.16; attack_recovery = 0.46
			attack_damage = 32.0; attack_stagger = 40.0; attack_lunge = 2.1
		elif phase == 2:
			attack_windup = 0.58; attack_active = 0.18; attack_recovery = 0.56
			attack_damage = 28.0; attack_stagger = 34.0; attack_lunge = 1.9
		else:
			attack_windup = 0.72; attack_active = 0.22; attack_recovery = 0.78
			attack_damage = 24.0; attack_stagger = 30.0; attack_lunge = 1.65


func _apply_long_range_attack() -> void:
	var phase := _current_phase()
	attack_heavy = true
	if phase == 3:
		attack_windup = 0.88; attack_active = 0.38; attack_recovery = 0.78
		attack_damage = 54.0; attack_stagger = 58.0; attack_lunge = 4.2
	elif phase == 2:
		attack_windup = 1.08; attack_active = 0.38; attack_recovery = 0.95
		attack_damage = 46.0; attack_stagger = 52.0; attack_lunge = 3.8
	else:
		attack_windup = 1.35; attack_active = 0.38; attack_recovery = 1.25
		attack_damage = 40.0; attack_stagger = 48.0; attack_lunge = 3.2


func _trigger_phase_transition() -> void:
	var new_phase := _current_phase()
	# Use `if` (not `elif`) so both phases cascade when a single hit crosses two thresholds.
	if new_phase >= 2 and not _phase_transition_played:
		_phase_transition_played = true
		_phase = 2
		# Phase 2: weapon ignites in fiery orange
		weapon_material.albedo_color = Color(1.0, 0.35, 0.08)
		weapon_material.emission_enabled = true
		weapon_material.emission = Color(1.0, 0.2, 0.04)
		weapon_material.emission_energy_multiplier = 2.5
		_play_audio("heavy", -3.0, 0.55)
		# Ground slam AoE — burst of damage on phase transition
		if world_node != null and world_node.has_method("get_target_candidates"):
			for candidate in world_node.get_target_candidates():
				if candidate is Node3D and _horizontal_distance(global_position, candidate.global_position) <= 4.5:
					var dir: Vector3 = (candidate.global_position - global_position).normalized()
					candidate.receive_hit(22.0, 28.0, dir, self)
	if new_phase >= 3 and not _phase_two_played:
		_phase_two_played = true
		_phase = 3
		# Phase 3: weapon burns white-hot, body glows with ember cracks
		weapon_material.albedo_color = Color(1.0, 0.7, 0.3)
		weapon_material.emission = Color(1.0, 0.5, 0.1)
		weapon_material.emission_energy_multiplier = 4.5
		body_material.emission_enabled = true
		body_material.emission = Color(1.0, 0.25, 0.05)
		body_material.emission_energy_multiplier = 1.5
		_play_audio("death", -2.0, 0.45)
		# Larger ground slam AoE in phase 3 transition
		if world_node != null and world_node.has_method("get_target_candidates"):
			for candidate in world_node.get_target_candidates():
				if candidate is Node3D and _horizontal_distance(global_position, candidate.global_position) <= 6.0:
					var dir: Vector3 = (candidate.global_position - global_position).normalized()
					candidate.receive_hit(30.0, 38.0, dir, self)
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	if state in [State.CHASE, State.WINDUP, State.ACTIVE, State.RECOVERY]:
		combat_area.end_swing()
		_change_state(State.STAGGER, 0.6)


func _change_state(new_state: State, duration: float = 0.0) -> void:
	if combat_area != null and state == State.ACTIVE and new_state != State.ACTIVE:
		combat_area.end_swing()
	state = new_state
	state_time = duration
	state_duration = duration
	if telegraph_mesh != null:
		telegraph_mesh.visible = state == State.WINDUP
	match state:
		State.WINDUP:
			_play_audio("heavy" if attack_heavy else "swing", -6.0, 0.82 if guardian else 1.0)
		State.ACTIVE:
			var tags: Array = ["melee", "heavy" if attack_heavy else "light"]
			if attack_is_low_sweep:
				tags.append("low_sweep")
			if combat_area != null:
				combat_area.begin_swing(attack_damage, attack_stagger, {
					"action_id": "enemy_low_sweep" if attack_is_low_sweep else "enemy_swing",
					"tags": tags,
					"blockable": true,
					"parryable": true,
					"guard_damage": attack_damage + attack_stagger * 0.25,
				})
		State.STAGGER, State.PARRY_VULNERABLE, State.GUARD_BROKEN, State.WEAK_POINT_EXPOSED:
			if combat_area != null:
				combat_area.end_swing()
		State.GRAB_WINDUP, State.GRAB_ACTIVE, State.GRAB_RECOVERY:
			if combat_area != null:
				combat_area.end_swing()
			if state != State.GRAB_ACTIVE:
				_end_grab()
		State.DEAD:
			if combat_area != null:
				combat_area.end_swing()
			_end_grab()
	_update_state_visuals()


func _die() -> void:
	if state == State.DEAD:
		return
	_change_state(State.DEAD)
	_set_engaged(false)
	velocity = Vector3.ZERO
	body_collision.set_deferred("disabled", true)
	visual_root.rotation.z = 1.35
	body_material.albedo_color = Color(0.08, 0.075, 0.08)
	weapon_material.albedo_color = Color(0.12, 0.1, 0.1)
	set_physics_process(false)
	_play_audio("death", -5.0, 0.72 if guardian else 1.0)
	defeated.emit(self, reward, guardian)


func _set_engaged(value: bool) -> void:
	if engaged == value:
		return
	engaged = value
	engagement_changed.emit(self, guardian, engaged)


func _has_valid_target() -> bool:
	if target_node == null or not is_instance_valid(target_node) or not target_node.is_inside_tree():
		return false
	if target_node.has_method("is_targetable") and not bool(target_node.call("is_targetable")):
		return false
	return true


func _target_is_in_sanctuary() -> bool:
	if not _has_valid_target():
		return false
	if world_node != null and world_node.has_method("is_position_in_sanctuary"):
		return bool(world_node.call(
			"is_position_in_sanctuary",
			target_node.global_position
		))
	return false


func _get_target_position() -> Vector3:
	if not _has_valid_target():
		return global_position
	if target_node.has_method("get_target_point"):
		var point = target_node.call("get_target_point")
		if point is Vector3:
			return point
	return target_node.global_position + Vector3.UP


func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	var difference := to - from
	difference.y = 0.0
	return difference.length()


func _face_point(point: Vector3, weight: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	_face_direction(direction, weight)


func _face_direction(direction: Vector3, weight: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(weight, 0.0, 1.0))


func _slow_horizontal(delta: float, amount: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, amount * delta)
	velocity.z = move_toward(velocity.z, 0.0, amount * delta)


func _update_telegraph() -> void:
	if _visual_frozen:
		return
	if state != State.WINDUP or state_duration <= 0.0:
		return
	var progress := clampf(1.0 - state_time / state_duration, 0.0, 1.0)
	var pulse := 1.0 + sin(progress * PI * 8.0) * 0.06
	var base_scale := lerpf(0.62, 1.08, progress) * pulse
	telegraph_mesh.scale = Vector3(base_scale, 1.0, base_scale)
	telegraph_material.emission_energy_multiplier = lerpf(1.2, 4.5, progress)
	weapon_pivot.rotation.z = lerpf(-0.2, -1.35 if attack_heavy else -0.95, progress)


func _update_state_visuals() -> void:
	if _visual_frozen or state == State.DEAD:
		return
	if body_material == null or weapon_material == null:
		return
	# 仅刷新材质色，避免每状态重建网格
	_ensure_visual_palette()
	match state:
		State.WINDUP:
			weapon_material.albedo_color = Color(1.0, 0.24, 0.08)
		State.ACTIVE:
			weapon_material.albedo_color = Color(1.0, 0.72, 0.25)
			weapon_pivot.rotation.z = 0.9
		State.STAGGER:
			body_material.albedo_color = Color(0.9, 0.84, 0.7)
		State.PARRY_VULNERABLE:
			body_material.albedo_color = Color(0.95, 0.55, 0.35)
			weapon_material.albedo_color = Color(1.0, 0.85, 0.4)
		State.GUARD_BROKEN:
			body_material.albedo_color = Color(0.75, 0.55, 0.85)
			weapon_material.albedo_color = Color(0.9, 0.5, 1.0)
		State.WEAK_POINT_EXPOSED:
			body_material.albedo_color = Color(1.0, 0.45, 0.15)
			weapon_material.albedo_color = Color(1.0, 0.85, 0.25)
			weapon_material.emission_enabled = true
			weapon_material.emission = Color(1.0, 0.55, 0.1)
			weapon_material.emission_energy_multiplier = 3.5
		State.GRAB_WINDUP, State.GRAB_ACTIVE:
			weapon_material.albedo_color = Color(0.95, 0.2, 0.35)


func set_visual_frozen(frozen: bool) -> void:
	_visual_frozen = frozen


func _set_visual_palette() -> void:
	_visuals_built_key = ""
	_ensure_visual_palette()


func _ensure_visual_palette() -> void:
	var build_key := _visual_identity_key()
	if build_key == _visuals_built_key and body_visual_root.get_child_count() > 0:
		_apply_palette_colors()
		return
	_visuals_built_key = build_key
	_apply_palette_colors()
	if not chapter_content.is_empty() and chapter_content.has("body_type"):
		ChapterEnemyFactory.build_into_slots(
			body_visual_root,
			weapon_pivot,
			chapter_content,
			body_material,
			weapon_material
		)
	else:
		var type_key := _legacy_type_key()
		CharacterMeshFactory.build_enemy(body_visual_root, type_key, body_material)
		WeaponMeshFactory.build_enemy_weapon(weapon_pivot, type_key, weapon_material)
	weapon_pivot.rotation = Vector3(0.0, 0.0, -0.2)


func _visual_identity_key() -> String:
	if not chapter_content.is_empty():
		return "content:%s" % String(chapter_content.get("id", content_id))
	if guardian:
		return "legacy:guardian"
	return "legacy:%d" % int(enemy_type)


func _legacy_type_key() -> String:
	if guardian:
		return "cinder_guardian"
	if enemy_type == EnemyType.ASH_STALKER:
		return "ash_stalker"
	return "hollow_sentinel"


func _apply_palette_colors() -> void:
	if not chapter_content.is_empty():
		body_material.albedo_color = _color_from_hex(String(chapter_content.get("body_color", "382820")))
		weapon_material.albedo_color = _color_from_hex(String(chapter_content.get("weapon_color", "5a5040")))
		eye_material.emission = _color_from_hex(String(chapter_content.get("eye_emission", "ffaa22")))
		return
	if guardian:
		body_material.albedo_color = Color(0.17, 0.11, 0.25)
		weapon_material.albedo_color = Color(0.34, 0.3, 0.42)
		eye_material.emission = Color(1.0, 0.3, 0.04)
	elif enemy_type == EnemyType.ASH_STALKER:
		body_material.albedo_color = Color(0.18, 0.17, 0.19)
		weapon_material.albedo_color = Color(0.38, 0.28, 0.22)
		eye_material.emission = Color(1.0, 0.45, 0.08)
	else:
		body_material.albedo_color = Color(0.22, 0.075, 0.065)
		weapon_material.albedo_color = Color(0.28, 0.27, 0.29)
		eye_material.emission = Color(1.0, 0.06, 0.02)


func _color_from_hex(hex: String) -> Color:
	# 兼容有无 # 前缀的十六进制颜色
	var value := hex.strip_edges()
	if value.is_empty():
		return Color.WHITE
	if not value.begins_with("#"):
		value = "#" + value
	return Color(value)


func _apply_tuning() -> void:
	if not chapter_content.is_empty():
		_apply_content_tuning()
		return
	if guardian:
		max_health = 260.0
		move_speed = 3.0
		acceleration = 12.0
		aggro_range = 17.0
		disengage_range = 26.0
		leash_range = 30.0
		attack_range = 2.65
		reward = 220
		poise_limit = 68.0
		stagger_duration = 0.42
		body_shape.radius = 0.58
		body_shape.height = 2.25
		body_collision.position.y = 1.12
		navigation_agent.radius = 0.62
		navigation_agent.height = 2.3
	elif enemy_type == EnemyType.ASH_STALKER:
		max_health = 45.0
		move_speed = 6.0
		acceleration = 18.0
		aggro_range = 10.0
		disengage_range = 17.0
		leash_range = 14.0
		attack_range = 1.6
		reward = 25
		poise_limit = 12.0
		stagger_duration = 0.55
		body_shape.radius = 0.36
		body_shape.height = 1.6
		body_collision.position.y = 0.8
		navigation_agent.radius = 0.40
		navigation_agent.height = 1.65
	else:
		max_health = 80.0
		move_speed = 3.6
		acceleration = 15.0
		aggro_range = 13.0
		disengage_range = 20.0
		leash_range = 17.0
		attack_range = 2.15
		reward = 35
		poise_limit = 24.0
		stagger_duration = 0.48
		body_shape.radius = 0.45
		body_shape.height = 1.9
		body_collision.position.y = 0.95
		navigation_agent.radius = 0.48
		navigation_agent.height = 1.9


func _apply_content_tuning() -> void:
	# 从章节内容字典灌入战斗数值
	max_health = float(chapter_content.get("max_health", 80.0))
	move_speed = float(chapter_content.get("move_speed", 3.6))
	acceleration = 15.0
	aggro_range = float(chapter_content.get("aggro_range", 13.0))
	disengage_range = float(chapter_content.get("disengage_range", 20.0))
	leash_range = float(chapter_content.get("leash_range", 17.0))
	attack_range = float(chapter_content.get("attack_range", 2.15))
	reward = int(chapter_content.get("reward", 35))
	poise_limit = float(chapter_content.get("poise_limit", 24.0))
	stagger_duration = float(chapter_content.get("stagger_duration", 0.48))
	if guardian:
		body_shape.radius = 0.58
		body_shape.height = 2.25
		body_collision.position.y = 1.12
		navigation_agent.radius = 0.62
		navigation_agent.height = 2.3
	else:
		body_shape.radius = 0.42
		body_shape.height = 1.85
		body_collision.position.y = 0.92
		navigation_agent.radius = 0.46
		navigation_agent.height = 1.85
	if not _attack_profile.is_empty():
		attack_windup = float(_attack_profile.get("windup", attack_windup))
		attack_active = float(_attack_profile.get("active", attack_active))
		attack_recovery = float(_attack_profile.get("recovery", attack_recovery))
		attack_damage = float(_attack_profile.get("damage", attack_damage))
		attack_stagger = float(_attack_profile.get("stagger", attack_stagger))
		attack_lunge = float(_attack_profile.get("lunge", attack_lunge))


func _play_audio(cue: String, volume_db: float, pitch: float) -> void:
	if audio_node != null and is_instance_valid(audio_node) and audio_node.has_method("play_cue"):
		audio_node.call("play_cue", cue, volume_db, pitch)


func _ensure_nodes() -> void:
	if navigation_agent != null:
		return
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.35

	body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	body_shape = CapsuleShape3D.new()
	body_collision.shape = body_shape
	add_child(body_collision)

	navigation_agent = NavigationAgent3D.new()
	navigation_agent.name = "NavigationAgent3D"
	navigation_agent.path_desired_distance = 0.35
	navigation_agent.target_desired_distance = 1.5
	navigation_agent.path_height_offset = 0.0
	navigation_agent.avoidance_enabled = false
	add_child(navigation_agent)

	visual_root = Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)

	body_visual_root = Node3D.new()
	body_visual_root.name = "BodyVisuals"
	visual_root.add_child(body_visual_root)

	body_material = StandardMaterial3D.new()
	body_material.roughness = 0.82
	weapon_material = StandardMaterial3D.new()
	weapon_material.metallic = 0.72
	weapon_material.roughness = 0.34
	eye_material = StandardMaterial3D.new()
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.emission_enabled = true
	eye_material.emission_energy_multiplier = 3.2

	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyRoot"
	body_mesh.material_override = body_material
	body_visual_root.add_child(body_mesh)
	# Composite character model built by _set_visual_palette() below
	head_mesh = body_mesh  # legacy ref — composite model has no single head node

	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = Vector3(0.68, 1.2, -0.16)
	visual_root.add_child(weapon_pivot)
	# placeholder reference — composite meshes built by _set_visual_palette()
	weapon_mesh = MeshInstance3D.new()
	weapon_mesh.name = "WeaponRoot"
	weapon_mesh.material_override = weapon_material
	weapon_pivot.add_child(weapon_mesh)

	telegraph_material = StandardMaterial3D.new()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.emission_enabled = true
	telegraph_material.no_depth_test = true
	telegraph_mesh = MeshInstance3D.new()
	telegraph_mesh.name = "AttackTelegraph"
	var telegraph_shape := CylinderMesh.new()
	telegraph_shape.top_radius = 1.32
	telegraph_shape.bottom_radius = 1.32
	telegraph_shape.height = 0.025
	telegraph_mesh.mesh = telegraph_shape
	telegraph_mesh.position.y = 0.035
	telegraph_mesh.material_override = telegraph_material
	telegraph_mesh.visible = false
	add_child(telegraph_mesh)

	combat_area = CombatAreaScript.new()
	combat_area.name = "CombatArea"
	add_child(combat_area)
	combat_area.configure(self, 1.35, 1.55, Vector3(0.0, 1.0, -0.9))
