extends CharacterBody3D

signal health_changed(current, maximum)
signal defeated(enemy, reward, is_guardian)
signal engagement_changed(enemy, is_guardian, engaged)

enum State {
	IDLE,
	CHASE,
	WINDUP,
	ACTIVE,
	RECOVERY,
	STAGGER,
	RETURN,
	DEAD,
}

const CombatAreaScript = preload("res://scripts/combat_area.gd")
const AI_DECISION_INTERVAL := 0.1

var world_node: Node
var target_node: Node3D
var audio_node: Node
var spawn_origin := Vector3.ZERO
var guardian := false
var configured := false

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

var state: State = State.IDLE
var state_time := 0.0
var state_duration := 0.0
var engaged := false
var attack_index := 0
var _phase := 1
var _phase_transition_played := false
const PHASE_TWO_THRESHOLD := 0.5
var attack_windup := 0.55
var attack_active := 0.18
var attack_recovery := 0.70
var attack_damage := 16.0
var attack_stagger := 22.0
var attack_lunge := 1.4
var attack_heavy := false
var navigation_refresh := 0.0
var gravity := 24.0
var knockback_velocity := Vector3.ZERO
var _cached_has_target := false
var _cached_target_position := Vector3.ZERO
var _cached_distance_to_target := INF
var _cached_chase_direction := Vector3.ZERO

var navigation_agent: NavigationAgent3D
var body_collision: CollisionShape3D
var body_shape: CapsuleShape3D
var visual_root: Node3D
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var weapon_mesh: MeshInstance3D
var telegraph_mesh: MeshInstance3D
var combat_area
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D
var telegraph_material: StandardMaterial3D
var eye_material: StandardMaterial3D


func setup(world, target, audio, spawn_position, is_guardian = false) -> void:
	world_node = world
	target_node = target if target is Node3D else null
	audio_node = audio
	spawn_origin = spawn_position
	guardian = bool(is_guardian)
	configured = true
	if is_inside_tree():
		_ensure_nodes()
		_apply_tuning()
		reset_enemy()


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
	if poise_reset_time > 0.0:
		poise_reset_time -= delta
		if poise_reset_time <= 0.0:
			poise = 0.0
	state_time = maxf(state_time - delta, 0.0)
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
	_set_engaged(false)
	state = State.IDLE
	state_time = 0.0
	state_duration = 0.0
	health = max_health
	poise = 0.0
	poise_reset_time = 0.0
	attack_index = 0
	_phase = 1
	_phase_transition_played = false
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
	if state == State.DEAD:
		return
	var incoming_damage := maxf(float(damage), 0.0)
	var incoming_stagger := maxf(float(stagger), 0.0)
	health = maxf(health - incoming_damage, 0.0)
	health_changed.emit(health, max_health)
	_play_audio("hurt", -8.0, 0.82 if guardian else 1.0)
	if guardian and not _phase_transition_played and _current_phase() == 2:
		_trigger_phase_transition()
	if health <= 0.0:
		_die()
		return
	if (target_node == null or not is_instance_valid(target_node)) and source is Node3D:
		target_node = source
		navigation_refresh = 0.0
	_set_engaged(true)
	poise += incoming_stagger
	poise_reset_time = 1.6
	var direction := Vector3.ZERO
	if hit_direction is Vector3:
		direction = hit_direction
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		knockback_velocity = direction.normalized() * (1.8 if guardian else 3.0)
	if poise >= poise_limit:
		poise = 0.0
		_change_state(State.STAGGER, stagger_duration)


func receive_parry(source: Node = null) -> void:
	if state == State.DEAD:
		return
	if source is Node3D:
		target_node = source
	_set_engaged(true)
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	poise = 0.0
	_play_audio("hurt", -5.0, 0.68 if guardian else 0.82)
	_change_state(State.STAGGER, 1.05 if guardian else 1.35)


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
	_select_attack_profile()
	_change_state(State.WINDUP, attack_windup)


func _select_attack_profile() -> void:
	var distance_to_target := _cached_distance_to_target
	if not guardian:
		attack_windup = 0.55
		attack_active = 0.18
		attack_recovery = 0.70
		attack_damage = 16.0
		attack_stagger = 22.0
		attack_lunge = 1.4
		attack_heavy = false
	else:
		attack_index += 1
		if distance_to_target < 2.0:
			_apply_close_range_attack()
		elif distance_to_target > 3.5:
			_apply_long_range_attack()
		else:
			_apply_mid_range_attack()
	telegraph_material.albedo_color = Color(1.0, 0.22, 0.04, 0.62) if attack_heavy else Color(1.0, 0.08, 0.04, 0.56)
	telegraph_material.emission = Color(1.0, 0.12, 0.02) if attack_heavy else Color(1.0, 0.02, 0.01)


func _current_phase() -> int:
	if get_health_ratio() <= PHASE_TWO_THRESHOLD:
		return 2
	return 1


func _apply_close_range_attack() -> void:
	var phase := _current_phase()
	attack_heavy = false
	if phase == 2 and attack_index % 3 == 0:
		attack_heavy = true
		attack_windup = 0.55
		attack_active = 0.20
		attack_recovery = 0.48
		attack_damage = 24.0
		attack_stagger = 28.0
		attack_lunge = 1.3
		return
	attack_windup = 0.48 if phase == 1 else 0.38
	attack_active = 0.16 if phase == 1 else 0.14
	attack_recovery = 0.52 if phase == 1 else 0.40
	attack_damage = 18.0 if phase == 1 else 22.0
	attack_stagger = 22.0 if phase == 1 else 26.0
	attack_lunge = 1.1 if phase == 1 else 1.3


func _apply_mid_range_attack() -> void:
	var phase := _current_phase()
	attack_heavy = attack_index % 2 == 1
	if attack_heavy:
		attack_windup = 1.18 if phase == 1 else 0.95
		attack_active = 0.34 if phase == 1 else 0.30
		attack_recovery = 1.08 if phase == 1 else 0.82
		attack_damage = 34.0 if phase == 1 else 38.0
		attack_stagger = 42.0 if phase == 1 else 46.0
		attack_lunge = 2.1 if phase == 1 else 2.4
	else:
		attack_windup = 0.72 if phase == 1 else 0.58
		attack_active = 0.22 if phase == 1 else 0.18
		attack_recovery = 0.78 if phase == 1 else 0.56
		attack_damage = 24.0 if phase == 1 else 28.0
		attack_stagger = 30.0 if phase == 1 else 34.0
		attack_lunge = 1.65 if phase == 1 else 1.9


func _apply_long_range_attack() -> void:
	var phase := _current_phase()
	attack_heavy = true
	attack_windup = 1.35 if phase == 1 else 1.08
	attack_active = 0.38
	attack_recovery = 1.25 if phase == 1 else 0.95
	attack_damage = 40.0 if phase == 1 else 46.0
	attack_stagger = 48.0 if phase == 1 else 52.0
	attack_lunge = 3.2 if phase == 1 else 3.8


func _trigger_phase_transition() -> void:
	_phase_transition_played = true
	_phase = 2
	weapon_material.albedo_color = Color(1.0, 0.35, 0.08)
	weapon_material.emission_enabled = true
	weapon_material.emission = Color(1.0, 0.2, 0.04)
	weapon_material.emission_energy_multiplier = 2.5
	_play_audio("heavy", -3.0, 0.55)
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	if state in [State.CHASE, State.WINDUP, State.ACTIVE, State.RECOVERY]:
		combat_area.end_swing()
		_change_state(State.STAGGER, 0.6)


func _change_state(new_state: State, duration: float = 0.0) -> void:
	if state == State.ACTIVE and new_state != State.ACTIVE:
		combat_area.end_swing()
	state = new_state
	state_time = duration
	state_duration = duration
	telegraph_mesh.visible = state == State.WINDUP
	match state:
		State.WINDUP:
			_play_audio("heavy" if attack_heavy else "swing", -6.0, 0.82 if guardian else 1.0)
		State.ACTIVE:
			combat_area.begin_swing(attack_damage, attack_stagger)
		State.STAGGER:
			combat_area.end_swing()
		State.DEAD:
			combat_area.end_swing()
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
	if state != State.WINDUP or state_duration <= 0.0:
		return
	var progress := clampf(1.0 - state_time / state_duration, 0.0, 1.0)
	var pulse := 1.0 + sin(progress * PI * 8.0) * 0.06
	var base_scale := lerpf(0.62, 1.08, progress) * pulse
	telegraph_mesh.scale = Vector3(base_scale, 1.0, base_scale)
	telegraph_material.emission_energy_multiplier = lerpf(1.2, 4.5, progress)
	weapon_mesh.rotation.z = lerpf(-0.2, -1.35 if attack_heavy else -0.95, progress)


func _update_state_visuals() -> void:
	if state == State.DEAD:
		return
	_set_visual_palette()
	match state:
		State.WINDUP:
			weapon_material.albedo_color = Color(1.0, 0.24, 0.08)
		State.ACTIVE:
			weapon_material.albedo_color = Color(1.0, 0.72, 0.25)
			weapon_mesh.rotation.z = 0.9
		State.STAGGER:
			body_material.albedo_color = Color(0.9, 0.84, 0.7)


func _set_visual_palette() -> void:
	if guardian:
		body_material.albedo_color = Color(0.17, 0.11, 0.25)
		weapon_material.albedo_color = Color(0.34, 0.3, 0.42)
		eye_material.emission = Color(1.0, 0.3, 0.04)
	else:
		body_material.albedo_color = Color(0.22, 0.075, 0.065)
		weapon_material.albedo_color = Color(0.28, 0.27, 0.29)
		eye_material.emission = Color(1.0, 0.06, 0.02)
	weapon_mesh.rotation = Vector3(0.0, 0.0, -0.2)


func _apply_tuning() -> void:
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
	body_mesh.name = "Body"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.43
	capsule_mesh.height = 1.55
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = 0.95
	body_mesh.material_override = body_material
	visual_root.add_child(body_mesh)

	head_mesh = MeshInstance3D.new()
	head_mesh.name = "Head"
	var head_shape := SphereMesh.new()
	head_shape.radius = 0.31
	head_shape.height = 0.62
	head_mesh.mesh = head_shape
	head_mesh.position.y = 1.82
	head_mesh.material_override = body_material
	visual_root.add_child(head_mesh)

	for eye_x in [-0.13, 0.13]:
		var eye := MeshInstance3D.new()
		var eye_shape := SphereMesh.new()
		eye_shape.radius = 0.045
		eye_shape.height = 0.09
		eye.mesh = eye_shape
		eye.position = Vector3(eye_x, 1.86, -0.285)
		eye.material_override = eye_material
		visual_root.add_child(eye)

	weapon_mesh = MeshInstance3D.new()
	weapon_mesh.name = "Weapon"
	var weapon_shape := BoxMesh.new()
	weapon_shape.size = Vector3(0.13, 1.45, 0.16)
	weapon_mesh.mesh = weapon_shape
	weapon_mesh.position = Vector3(0.68, 1.2, -0.16)
	weapon_mesh.material_override = weapon_material
	visual_root.add_child(weapon_mesh)

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
	combat_area.position = Vector3(0.0, 1.0, -0.9)
	add_child(combat_area)
	combat_area.configure(self, 1.35, 1.55)
