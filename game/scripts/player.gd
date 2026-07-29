extends CharacterBody3D

signal died(death_position)
signal stats_changed(health, max_health, stamina, max_stamina)
signal focus_changed(current, maximum)
signal lock_target_changed(target)
signal embers_changed(amount)
signal combat_style_changed(style_id, display_name)

enum State {
	LOCOMOTION,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	ATTACK_RECOVERY,
	DODGE,
	PARRY,
	GUARD_THRUST,
	LEAP_WINDUP,
	LEAP_ACTIVE,
	CAST,
	STAGGER,
	DEAD,
}

enum CombatStyle {
	RELIQUARY_GUARD,
	TWIN_COLOSSI,
	CRESCENT_PAIR,
	VEILCRAFT,
	EMBER_RITE,
}

const CombatAreaScript = preload("res://scripts/combat_area.gd")
const SpellProjectileScene = preload("res://scenes/components/spell_projectile.tscn")
const LocalizationScript = preload("res://scripts/core/localization.gd")
const STATS_EMIT_INTERVAL := 0.1
const STYLE_NAMES := [
	"RELIQUARY GUARD",
	"TWIN COLOSSI",
	"CRESCENT PAIR",
	"VEILCRAFT",
	"EMBER RITE",
]

var world_node: Node
var audio_node: Node
var hud_node: Node

var max_health := 100.0
var health := 100.0
var max_stamina := 100.0
var stamina := 100.0
var max_focus := 80.0
var focus := 80.0
var embers := 0

var move_speed := 5.2
var sprint_speed := 7.4
var acceleration := 24.0
var gravity := 24.0
var mouse_sensitivity := 0.0024
var camera_sensitivity_scale := 1.0
var invert_camera_y := false
var stamina_regen := 30.0
var stamina_delay := 0.0
var _stats_dirty := false
var _stats_emit_cooldown := 0.0
var _has_emitted_stats := false
var _last_emitted_health := 0.0
var _last_emitted_max_health := 0.0
var _last_emitted_stamina := 0.0
var _last_emitted_max_stamina := 0.0
var _last_emitted_focus := -1

var state: State = State.LOCOMOTION
var state_time := 0.0
var state_duration := 0.0
var attack_damage := 24.0
var attack_stagger := 16.0
var attack_cost := 20.0
var attack_heavy := false
var combat_style: CombatStyle = CombatStyle.RELIQUARY_GUARD
var _leap_is_curved := false
var _leap_second_hit := false
var _pending_cast := &""
var _cast_resolved := false
var dodge_direction := Vector3.FORWARD
var knockback_velocity := Vector3.ZERO
var lock_target: Node3D
var interaction_target: Node
var configured := false

var visual_root: Node3D
var body_mesh: MeshInstance3D
var cloak_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var weapon_pivot: Node3D
var weapon_mesh: MeshInstance3D
var offhand_weapon_pivot: Node3D
var offhand_weapon_mesh: MeshInstance3D
var shield_mesh: MeshInstance3D
var combat_area
var camera_rig: Node3D
var camera_pitch: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var body_collision: CollisionShape3D
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D


func setup(world, audio, hud) -> void:
	world_node = world
	audio_node = audio
	hud_node = hud
	configured = true
	_emit_stats()
	_emit_focus()
	embers_changed.emit(embers)
	combat_style_changed.emit(combat_style, _style_display_name())


func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	add_to_group("player")
	_build_nodes()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_stats()
	_emit_focus()
	embers_changed.emit(embers)
	_update_combat_style_visuals()
	combat_style_changed.emit(combat_style, _style_display_name())


func _physics_process(delta: float) -> void:
	_update_lock_target()
	_update_gamepad_camera(delta)
	_update_camera_rig(delta)
	if state != State.DEAD:
		_handle_action_input()
		_update_state(delta)
		_update_stamina(delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = minf(velocity.y, 0.0)
		move_and_slide()
	_flush_stats(delta)
	_update_visual_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and state != State.DEAD:
		var motion := event as InputEventMouseMotion
		camera_rig.rotation.y -= motion.relative.x * mouse_sensitivity * camera_sensitivity_scale
		var pitch_direction := 1.0 if invert_camera_y else -1.0
		camera_pitch.rotation.x = clampf(
			camera_pitch.rotation.x
			+ motion.relative.y * mouse_sensitivity * camera_sensitivity_scale * pitch_direction,
			-1.05,
			0.45
		)


func receive_hit(damage, stagger, hit_direction, source) -> void:
	if state == State.DEAD or _is_invulnerable():
		return
	if _is_parry_active() and source != null and is_instance_valid(source):
		if source.has_method("receive_parry"):
			source.receive_parry(self)
		focus = minf(focus + 12.0, max_focus)
		_emit_focus()
		_show_message(LocalizationScript.text("PARRY"), 0.8)
		_play_audio("rest", -5.0, 1.35)
		_change_state(State.LOCOMOTION)
		return

	var incoming_damage := maxf(float(damage), 0.0)
	var incoming_stagger := maxf(float(stagger), 0.0)
	if _is_guarding_hit(hit_direction):
		var guard_cost := incoming_damage * 0.9 + incoming_stagger * 0.25
		if stamina >= guard_cost:
			_spend_stamina(guard_cost, 0.65)
			incoming_damage *= 0.18
			incoming_stagger = 0.0
		else:
			_spend_stamina(stamina, 1.0)
			incoming_damage *= 0.65
			incoming_stagger = maxf(incoming_stagger, 30.0)
	health = maxf(health - incoming_damage, 0.0)
	_emit_stats()
	_play_audio("hurt", -4.0, 1.0)
	if health <= 0.0:
		_die()
		return
	var direction := hit_direction as Vector3 if hit_direction is Vector3 else Vector3.ZERO
	direction.y = 0.0
	knockback_velocity = direction.normalized() * 3.5 if direction.length_squared() > 0.001 else Vector3.ZERO
	if incoming_stagger > 0.0:
		_change_state(State.STAGGER, clampf(0.28 + incoming_stagger * 0.006, 0.28, 0.68))


func heal_full() -> void:
	health = max_health
	stamina = max_stamina
	focus = max_focus
	stamina_delay = 0.0
	_emit_stats()
	_emit_focus()


func respawn_at(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	focus = max_focus
	visible = true
	body_collision.set_deferred("disabled", false)
	visual_root.rotation = Vector3.ZERO
	_change_state(State.LOCOMOTION)
	_emit_stats()
	_emit_focus()


func get_lock_target():
	return lock_target


func set_interaction(node) -> void:
	interaction_target = node


func add_embers(amount: int) -> void:
	embers = maxi(embers + amount, 0)
	embers_changed.emit(embers)


func lose_embers() -> int:
	var lost := embers
	embers = 0
	embers_changed.emit(embers)
	return lost


func recover_embers(amount: int) -> void:
	add_embers(amount)


func set_embers(amount: int) -> void:
	embers = maxi(amount, 0)
	embers_changed.emit(embers)


func set_focus(amount: float) -> void:
	focus = clampf(amount, 0.0, max_focus)
	_emit_focus()


func apply_game_settings(settings: Dictionary) -> void:
	camera_sensitivity_scale = clampf(
		float(settings.get("camera_sensitivity", 1.0)),
		0.35,
		2.5
	)
	invert_camera_y = bool(settings.get("invert_camera_y", false))
	combat_style_changed.emit(combat_style, _style_display_name())


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.15


func is_targetable() -> bool:
	return state != State.DEAD and health > 0.0


func _handle_action_input() -> void:
	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock_on()
	if Input.is_action_just_pressed("interact") and interaction_target != null and is_instance_valid(interaction_target) and interaction_target.has_method("interact"):
		interaction_target.interact(self)
	if Input.is_action_just_pressed("cycle_style"):
		set_combat_style((int(combat_style) + 1) % CombatStyle.size())
	for style_index in CombatStyle.size():
		if Input.is_action_just_pressed("style_%d" % (style_index + 1)):
			set_combat_style(style_index)
	if state != State.LOCOMOTION:
		return
	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
	elif Input.is_action_just_pressed("parry"):
		_try_parry()
	elif Input.is_action_just_pressed("special_attack"):
		_try_style_skill()
	elif Input.is_action_just_pressed("cast_spell"):
		_try_cast_for_style()
	elif (
		combat_style == CombatStyle.RELIQUARY_GUARD
		and Input.is_action_pressed("guard")
		and (
			Input.is_action_just_pressed("light_attack")
			or Input.is_action_just_pressed("light_attack_alt")
		)
	):
		_try_guarded_thrust()
	elif Input.is_action_just_pressed("heavy_attack") or Input.is_action_just_pressed("heavy_attack_alt"):
		_try_attack(true)
	elif Input.is_action_just_pressed("light_attack") or Input.is_action_just_pressed("light_attack_alt"):
		_try_attack(false)


func _update_state(delta: float) -> void:
	state_time = maxf(state_time - delta, 0.0)
	match state:
		State.LOCOMOTION:
			_update_locomotion(delta)
		State.ATTACK_WINDUP:
			_slow_horizontal(delta, acceleration * 1.8)
			_face_lock_target(delta)
			if state_time <= 0.0:
				_change_state(State.ATTACK_ACTIVE, 0.22 if attack_heavy else 0.16)
		State.ATTACK_ACTIVE:
			var forward := -global_transform.basis.z
			var lunge := 2.8 if attack_heavy else 2.0
			velocity.x = forward.x * lunge
			velocity.z = forward.z * lunge
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, 0.68 if attack_heavy else 0.42)
		State.ATTACK_RECOVERY:
			_slow_horizontal(delta, acceleration)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.DODGE:
			velocity.x = dodge_direction.x * 8.4
			velocity.z = dodge_direction.z * 8.4
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.PARRY:
			_slow_horizontal(delta, acceleration * 2.2)
			_face_lock_target(delta)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.GUARD_THRUST:
			var thrust_forward := -global_transform.basis.z
			velocity.x = thrust_forward.x * 2.6
			velocity.z = thrust_forward.z * 2.6
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, 0.34)
		State.LEAP_WINDUP:
			_face_lock_target(delta)
			var leap_forward := -global_transform.basis.z
			velocity.x = leap_forward.x * (3.8 if _leap_is_curved else 3.1)
			velocity.z = leap_forward.z * (3.8 if _leap_is_curved else 3.1)
			if state_time <= 0.0:
				_change_state(State.LEAP_ACTIVE, 0.34 if _leap_is_curved else 0.28)
		State.LEAP_ACTIVE:
			var attack_forward := -global_transform.basis.z
			var leap_speed := 5.8 if _leap_is_curved else 4.8
			velocity.x = attack_forward.x * leap_speed
			velocity.z = attack_forward.z * leap_speed
			if _leap_is_curved and not _leap_second_hit and state_time <= 0.16:
				_leap_second_hit = true
				combat_area.end_swing()
				combat_area.begin_swing(18.0, 12.0)
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, 0.34 if _leap_is_curved else 0.62)
		State.CAST:
			_slow_horizontal(delta, acceleration * 2.0)
			_face_lock_target(delta)
			if not _cast_resolved and state_time <= 0.18:
				_cast_resolved = true
				_resolve_cast()
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, 0.32)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, knockback_velocity.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, knockback_velocity.z, acceleration * delta)
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 9.0 * delta)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)


func _update_locomotion(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction := (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()
	var sprinting := Input.is_action_pressed("sprint") and direction.length_squared() > 0.0 and stamina > 0.0
	var target_speed := sprint_speed if sprinting else move_speed
	if sprinting:
		_spend_stamina(18.0 * delta, 0.25, false)
	velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	if lock_target != null:
		_face_lock_target(delta)
	elif direction.length_squared() > 0.001:
		_face_direction(direction, delta * 10.0)


func _try_attack(heavy: bool) -> void:
	attack_cost = 38.0 if heavy else 20.0
	if stamina < attack_cost:
		_show_message("NOT ENOUGH STAMINA", 0.8)
		return
	attack_heavy = heavy
	attack_damage = 42.0 if heavy else 24.0
	attack_stagger = 34.0 if heavy else 16.0
	_spend_stamina(attack_cost, 0.85)
	_change_state(State.ATTACK_WINDUP, 0.62 if heavy else 0.30)


func set_combat_style(style_id: int) -> void:
	var normalized_style := clampi(style_id, 0, CombatStyle.size() - 1)
	if int(combat_style) == normalized_style:
		return
	combat_style = normalized_style as CombatStyle
	_update_combat_style_visuals()
	var display_name := _style_display_name()
	combat_style_changed.emit(combat_style, display_name)
	_show_message(display_name, 1.0)


func _style_display_name() -> String:
	return LocalizationScript.text(STYLE_NAMES[int(combat_style)])


func _try_style_skill() -> void:
	match combat_style:
		CombatStyle.RELIQUARY_GUARD:
			_try_parry()
		CombatStyle.TWIN_COLOSSI:
			_try_leap_attack(false)
		CombatStyle.CRESCENT_PAIR:
			_try_leap_attack(true)
		CombatStyle.VEILCRAFT, CombatStyle.EMBER_RITE:
			_try_cast_for_style()


func _try_parry() -> void:
	if combat_style != CombatStyle.RELIQUARY_GUARD:
		_try_style_skill()
		return
	var cost := 10.0
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	_spend_stamina(cost, 0.45)
	_change_state(State.PARRY, 0.48)


func _try_guarded_thrust() -> void:
	var cost := 18.0
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	attack_damage = 26.0
	attack_stagger = 18.0
	attack_heavy = false
	_spend_stamina(cost, 0.6)
	_show_message(LocalizationScript.text("GUARDED THRUST"), 0.65)
	_change_state(State.GUARD_THRUST, 0.34)


func _try_leap_attack(curved_pair: bool) -> void:
	var cost := 27.0 if curved_pair else 38.0
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	_leap_is_curved = curved_pair
	_leap_second_hit = false
	attack_damage = 18.0 if curved_pair else 58.0
	attack_stagger = 12.0 if curved_pair else 48.0
	attack_heavy = not curved_pair
	_spend_stamina(cost, 0.9)
	if is_on_floor():
		velocity.y = 4.8 if curved_pair else 4.2
	_show_message(
		LocalizationScript.text("CRESCENT LEAP" if curved_pair else "COLOSSAL LEAP"),
		0.65
	)
	_change_state(State.LEAP_WINDUP, 0.22 if curved_pair else 0.38)


func _try_cast_for_style() -> void:
	match combat_style:
		CombatStyle.VEILCRAFT:
			_begin_cast(&"veil_bolt", 18.0, 0.66)
		CombatStyle.EMBER_RITE:
			_begin_cast(&"ember_rite", 30.0, 0.92)
		_:
			_try_style_skill()


func _begin_cast(cast_id: StringName, focus_cost: float, duration: float) -> void:
	if focus < focus_cost:
		_show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return
	focus = maxf(focus - focus_cost, 0.0)
	_emit_focus()
	_pending_cast = cast_id
	_cast_resolved = false
	_change_state(State.CAST, duration)


func _resolve_cast() -> void:
	match _pending_cast:
		&"veil_bolt":
			var projectile = SpellProjectileScene.instantiate()
			var cast_direction := -camera.global_transform.basis.z
			if lock_target != null and is_instance_valid(lock_target):
				var target_point: Vector3 = (
					lock_target.get_target_point()
					if lock_target.has_method("get_target_point")
					else lock_target.global_position
				)
				cast_direction = (
					target_point
					- (global_position + Vector3.UP * 1.25)
				).normalized()
			projectile.setup(self, cast_direction, 28.0, 18.0)
			var projectile_parent: Node = (
				world_node
				if world_node != null and world_node.is_inside_tree()
				else get_tree().current_scene
			)
			projectile_parent.add_child(projectile)
			projectile.global_position = global_position + Vector3.UP * 1.25 + cast_direction * 0.8
			_show_message(LocalizationScript.text("VEIL BOLT"), 0.65)
			_play_audio("recover", -6.0, 1.3)
		&"ember_rite":
			health = minf(health + 24.0, max_health)
			_emit_stats()
			if world_node != null and world_node.has_method("get_target_candidates"):
				for candidate in world_node.get_target_candidates():
					if candidate is Node3D and global_position.distance_to(candidate.global_position) <= 5.5:
						var direction: Vector3 = (
							candidate.global_position - global_position
						).normalized()
						candidate.receive_hit(20.0, 18.0, direction, self)
			_show_message(LocalizationScript.text("EMBER RITE CAST"), 0.75)
			_play_audio("rest", -4.0, 0.82)
	_pending_cast = &""


func _try_dodge() -> void:
	var cost := 26.0
	if stamina < cost:
		_show_message("NOT ENOUGH STAMINA", 0.8)
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	dodge_direction = (right * input_vector.x + forward * -input_vector.y).normalized()
	if dodge_direction.length_squared() < 0.001:
		dodge_direction = -global_transform.basis.z
	dodge_direction.y = 0.0
	dodge_direction = dodge_direction.normalized()
	_spend_stamina(cost, 0.7)
	_play_audio("dodge", -7.0, 1.0)
	_change_state(State.DODGE, 0.58)


func _change_state(new_state: State, duration: float = 0.0) -> void:
	if state in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE] \
			and new_state not in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE]:
		combat_area.end_swing()
	state = new_state
	state_time = duration
	state_duration = duration
	if state == State.ATTACK_ACTIVE:
		combat_area.begin_swing(attack_damage, attack_stagger)
		_play_audio("heavy" if attack_heavy else "swing", -5.0, 1.0)
	elif state == State.GUARD_THRUST:
		combat_area.begin_swing(attack_damage, attack_stagger)
		_play_audio("swing", -7.0, 1.2)
	elif state == State.LEAP_ACTIVE:
		combat_area.begin_swing(attack_damage, attack_stagger)
		_play_audio("heavy" if not _leap_is_curved else "swing", -4.5, 0.9 if not _leap_is_curved else 1.2)
	elif state == State.PARRY:
		_play_audio("swing", -9.0, 1.45)
	elif state == State.STAGGER or state == State.DEAD:
		combat_area.end_swing()


func _is_invulnerable() -> bool:
	if state != State.DODGE or state_duration <= 0.0:
		return false
	var elapsed := state_duration - state_time
	return elapsed >= 0.08 and elapsed <= 0.38


func _is_parry_active() -> bool:
	if state != State.PARRY or state_duration <= 0.0:
		return false
	var elapsed := state_duration - state_time
	return elapsed >= 0.08 and elapsed <= 0.24


func _is_guarding_hit(hit_direction: Variant) -> bool:
	if (
		combat_style != CombatStyle.RELIQUARY_GUARD
		or state != State.LOCOMOTION
		or not Input.is_action_pressed("guard")
		or not hit_direction is Vector3
	):
		return false
	var toward_source: Vector3 = -(hit_direction as Vector3)
	toward_source.y = 0.0
	if toward_source.length_squared() <= 0.001:
		return true
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized().dot(toward_source.normalized()) >= 0.15


func _update_stamina(delta: float) -> void:
	if stamina_delay > 0.0:
		stamina_delay -= delta
	elif state == State.LOCOMOTION:
		var previous := stamina
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		if not is_equal_approx(previous, stamina):
			_queue_stats_update()
	if state == State.LOCOMOTION and focus < max_focus:
		var previous_focus_int := floori(focus)
		focus = minf(focus + 4.0 * delta, max_focus)
		if floori(focus) != previous_focus_int:
			_emit_focus()


func _spend_stamina(amount: float, delay: float, emit_immediately := true) -> void:
	stamina = maxf(stamina - amount, 0.0)
	stamina_delay = maxf(stamina_delay, delay)
	if emit_immediately:
		_emit_stats()
	else:
		_queue_stats_update()


func _toggle_lock_on() -> void:
	if lock_target != null:
		_set_lock_target(null)
		return
	if world_node == null or not world_node.has_method("get_target_candidates"):
		return
	var best: Node3D
	var best_score := INF
	var camera_forward := -camera.global_transform.basis.z
	for candidate in world_node.get_target_candidates():
		if not candidate is Node3D:
			continue
		var target := candidate as Node3D
		var offset := target.global_position - global_position
		var distance := offset.length()
		if distance > 18.0 or distance < 0.01:
			continue
		var facing_penalty := 1.0 - camera_forward.normalized().dot(offset.normalized())
		var score := distance + facing_penalty * 12.0
		if score < best_score:
			best = target
			best_score = score
	_set_lock_target(best)


func _set_lock_target(target: Node3D) -> void:
	lock_target = target
	lock_target_changed.emit(lock_target)


func _update_lock_target() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.is_inside_tree():
		_set_lock_target(null)
		return
	if lock_target.has_method("is_targetable") and not lock_target.is_targetable():
		_set_lock_target(null)
		return
	if global_position.distance_to(lock_target.global_position) > 22.0:
		_set_lock_target(null)


func _face_lock_target(delta: float) -> void:
	if lock_target == null or not is_instance_valid(lock_target):
		return
	var point: Vector3 = lock_target.get_target_point() if lock_target.has_method("get_target_point") else lock_target.global_position
	_face_direction(point - global_position, delta * 12.0)


func _face_direction(direction: Vector3, weight: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(weight, 0.0, 1.0))


func _update_camera_rig(delta: float) -> void:
	camera_rig.global_position = global_position + Vector3.UP * 1.45
	if lock_target != null and is_instance_valid(lock_target):
		var point: Vector3 = lock_target.get_target_point() if lock_target.has_method("get_target_point") else lock_target.global_position
		var direction: Vector3 = point - camera_rig.global_position
		var desired_yaw := atan2(-direction.x, -direction.z)
		camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, desired_yaw, clampf(delta * 4.5, 0.0, 1.0))
		var horizontal := Vector2(direction.x, direction.z).length()
		var desired_pitch := -atan2(direction.y, maxf(horizontal, 0.01)) - 0.08
		camera_pitch.rotation.x = lerp_angle(camera_pitch.rotation.x, clampf(desired_pitch, -0.65, 0.25), clampf(delta * 3.5, 0.0, 1.0))


func _update_gamepad_camera(delta: float) -> void:
	if state == State.DEAD or camera_rig == null or camera_pitch == null:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.18)
	if look.length_squared() <= 0.0001:
		return
	var angular_speed := 2.4 * camera_sensitivity_scale
	camera_rig.rotation.y -= look.x * angular_speed * delta
	var pitch_direction := 1.0 if invert_camera_y else -1.0
	camera_pitch.rotation.x = clampf(
		camera_pitch.rotation.x + look.y * angular_speed * delta * pitch_direction,
		-1.05,
		0.45
	)


func _slow_horizontal(delta: float, amount: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, amount * delta)
	velocity.z = move_toward(velocity.z, 0.0, amount * delta)


func _die() -> void:
	_change_state(State.DEAD)
	velocity = Vector3.ZERO
	_set_lock_target(null)
	body_collision.set_deferred("disabled", true)
	visual_root.rotation.z = 1.35
	_play_audio("death", -3.0, 1.0)
	died.emit(global_position)


func _emit_stats() -> void:
	if _has_emitted_stats \
			and is_equal_approx(health, _last_emitted_health) \
			and is_equal_approx(max_health, _last_emitted_max_health) \
			and is_equal_approx(stamina, _last_emitted_stamina) \
			and is_equal_approx(max_stamina, _last_emitted_max_stamina):
		_stats_dirty = false
		return
	_has_emitted_stats = true
	_last_emitted_health = health
	_last_emitted_max_health = max_health
	_last_emitted_stamina = stamina
	_last_emitted_max_stamina = max_stamina
	_stats_dirty = false
	_stats_emit_cooldown = STATS_EMIT_INTERVAL
	stats_changed.emit(health, max_health, stamina, max_stamina)


func _emit_focus() -> void:
	var rounded_focus := roundi(focus)
	if rounded_focus == _last_emitted_focus:
		return
	_last_emitted_focus = rounded_focus
	focus_changed.emit(focus, max_focus)


func _queue_stats_update() -> void:
	_stats_dirty = true


func _flush_stats(delta: float) -> void:
	_stats_emit_cooldown = maxf(_stats_emit_cooldown - delta, 0.0)
	if _stats_dirty and _stats_emit_cooldown <= 0.0:
		_emit_stats()


func _show_message(text: String, duration: float) -> void:
	if hud_node != null and is_instance_valid(hud_node) and hud_node.has_method("show_message"):
		hud_node.show_message(text, duration)


func _play_audio(cue: String, volume_db: float, pitch: float) -> void:
	if audio_node != null and is_instance_valid(audio_node) and audio_node.has_method("play_cue"):
		audio_node.play_cue(cue, volume_db, pitch)


func _update_visual_pose() -> void:
	if visual_root == null or state == State.DEAD:
		return
	visual_root.rotation.z = 0.0
	visual_root.rotation.y = move_toward(visual_root.rotation.y, 0.0, 0.15)
	weapon_pivot.rotation = Vector3.ZERO
	if offhand_weapon_pivot != null:
		offhand_weapon_pivot.rotation = Vector3.ZERO
	match state:
		State.ATTACK_WINDUP:
			var progress := 1.0 - state_time / maxf(state_duration, 0.001)
			weapon_pivot.rotation.z = lerpf(0.0, -1.35 if attack_heavy else -0.9, progress)
		State.ATTACK_ACTIVE:
			var progress := 1.0 - state_time / maxf(state_duration, 0.001)
			weapon_pivot.rotation.z = lerpf(-1.1, 1.35, progress)
		State.ATTACK_RECOVERY:
			weapon_pivot.rotation.z = lerpf(0.2, 0.0, 1.0 - state_time / maxf(state_duration, 0.001))
		State.DODGE:
			var progress := 1.0 - state_time / maxf(state_duration, 0.001)
			visual_root.rotation.x = sin(progress * PI) * -0.55
		State.PARRY:
			weapon_pivot.rotation.z = -0.45
			visual_root.rotation.y = sin(state_time * 18.0) * 0.05
		State.GUARD_THRUST:
			weapon_pivot.rotation.x = -PI * 0.5
			weapon_pivot.rotation.z = -0.15
		State.LEAP_WINDUP:
			var progress := 1.0 - state_time / maxf(state_duration, 0.001)
			weapon_pivot.rotation.z = lerpf(0.0, -1.55, progress)
			if offhand_weapon_pivot != null:
				offhand_weapon_pivot.rotation.z = lerpf(0.0, 1.55, progress)
			visual_root.rotation.x = -0.18
		State.LEAP_ACTIVE:
			var progress := 1.0 - state_time / maxf(state_duration, 0.001)
			weapon_pivot.rotation.z = lerpf(-1.5, 1.35, progress)
			if offhand_weapon_pivot != null:
				offhand_weapon_pivot.rotation.z = lerpf(1.5, -1.35, progress)
			visual_root.rotation.x = 0.22
		State.CAST:
			var pulse := sin((state_duration - state_time) * 12.0) * 0.12
			weapon_pivot.rotation.z = -0.7 + pulse
			visual_root.rotation.y = pulse * 0.3
		State.STAGGER:
			visual_root.rotation.z = sin(state_time * 28.0) * 0.12
		_:
			visual_root.rotation.x = move_toward(visual_root.rotation.x, 0.0, 0.12)


func _build_nodes() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35

	body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	body_collision.shape = capsule
	body_collision.position.y = 0.93
	add_child(body_collision)

	visual_root = Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)

	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color("26384a")
	body_material.roughness = 0.76
	weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color("9aa3aa")
	weapon_material.metallic = 0.82
	weapon_material.roughness = 0.28

	body_mesh = MeshInstance3D.new()
	var body_shape := CapsuleMesh.new()
	body_shape.radius = 0.4
	body_shape.height = 1.45
	body_mesh.mesh = body_shape
	body_mesh.position.y = 0.95
	body_mesh.material_override = body_material
	visual_root.add_child(body_mesh)

	cloak_mesh = MeshInstance3D.new()
	var cloak_shape := PrismMesh.new()
	cloak_shape.size = Vector3(0.9, 1.3, 0.45)
	cloak_mesh.mesh = cloak_shape
	cloak_mesh.position = Vector3(0.0, 0.95, 0.25)
	cloak_mesh.material_override = _make_material(Color("141b28"), 0.95, 0.0)
	visual_root.add_child(cloak_mesh)

	head_mesh = MeshInstance3D.new()
	var head_shape := SphereMesh.new()
	head_shape.radius = 0.29
	head_shape.height = 0.58
	head_mesh.mesh = head_shape
	head_mesh.position.y = 1.78
	head_mesh.material_override = _make_material(Color("313944"), 0.62, 0.35)
	visual_root.add_child(head_mesh)

	var visor := MeshInstance3D.new()
	var visor_shape := BoxMesh.new()
	visor_shape.size = Vector3(0.42, 0.1, 0.05)
	visor.mesh = visor_shape
	visor.position = Vector3(0.0, 1.8, -0.27)
	var visor_material := _make_material(Color("f36a2f"), 0.25, 0.0)
	visor_material.emission_enabled = true
	visor_material.emission = Color("f13c15")
	visor_material.emission_energy_multiplier = 2.2
	visor.material_override = visor_material
	visual_root.add_child(visor)

	weapon_pivot = Node3D.new()
	weapon_pivot.position = Vector3(0.58, 1.25, -0.15)
	visual_root.add_child(weapon_pivot)
	weapon_mesh = MeshInstance3D.new()
	var weapon_shape := BoxMesh.new()
	weapon_shape.size = Vector3(0.12, 1.55, 0.18)
	weapon_mesh.mesh = weapon_shape
	weapon_mesh.position.y = -0.35
	weapon_mesh.material_override = weapon_material
	weapon_pivot.add_child(weapon_mesh)

	offhand_weapon_pivot = Node3D.new()
	offhand_weapon_pivot.position = Vector3(-0.58, 1.25, -0.15)
	visual_root.add_child(offhand_weapon_pivot)
	offhand_weapon_mesh = MeshInstance3D.new()
	var offhand_shape := BoxMesh.new()
	offhand_shape.size = Vector3(0.12, 1.55, 0.18)
	offhand_weapon_mesh.mesh = offhand_shape
	offhand_weapon_mesh.position.y = -0.35
	offhand_weapon_mesh.material_override = weapon_material
	offhand_weapon_pivot.add_child(offhand_weapon_mesh)

	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "ReliquaryShield"
	var shield_shape := CylinderMesh.new()
	shield_shape.top_radius = 0.52
	shield_shape.bottom_radius = 0.52
	shield_shape.height = 0.12
	shield_shape.radial_segments = 10
	shield_mesh.mesh = shield_shape
	shield_mesh.position = Vector3(-0.5, 1.22, -0.28)
	shield_mesh.rotation.x = PI * 0.5
	shield_mesh.material_override = _make_material(Color("614725"), 0.48, 0.72)
	visual_root.add_child(shield_mesh)

	combat_area = CombatAreaScript.new()
	combat_area.name = "CombatArea"
	combat_area.position = Vector3(0.0, 1.0, -1.0)
	add_child(combat_area)
	combat_area.configure(self, 1.25, 1.45)

	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3.UP * 1.45
	camera_rig.rotation.y = 0.0

	camera_pitch = Node3D.new()
	camera_pitch.name = "Pitch"
	camera_pitch.rotation.x = -0.2
	camera_rig.add_child(camera_pitch)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 5.2
	spring_arm.margin = 0.25
	spring_arm.collision_mask = 1
	camera_pitch.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 68.0
	spring_arm.add_child(camera)
	_update_combat_style_visuals()


func _update_combat_style_visuals() -> void:
	if weapon_mesh == null or offhand_weapon_mesh == null or shield_mesh == null:
		return
	var main_shape := weapon_mesh.mesh as BoxMesh
	var offhand_shape := offhand_weapon_mesh.mesh as BoxMesh
	shield_mesh.visible = combat_style == CombatStyle.RELIQUARY_GUARD
	offhand_weapon_mesh.visible = combat_style in [
		CombatStyle.TWIN_COLOSSI,
		CombatStyle.CRESCENT_PAIR,
	]
	match combat_style:
		CombatStyle.RELIQUARY_GUARD:
			main_shape.size = Vector3(0.08, 1.8, 0.08)
			weapon_mesh.position = Vector3(0.0, -0.25, -0.35)
			weapon_material.albedo_color = Color("a9a18c")
		CombatStyle.TWIN_COLOSSI:
			main_shape.size = Vector3(0.22, 1.75, 0.32)
			offhand_shape.size = main_shape.size
			weapon_mesh.position = Vector3(0.0, -0.3, 0.0)
			offhand_weapon_mesh.position = weapon_mesh.position
			weapon_material.albedo_color = Color("858b91")
		CombatStyle.CRESCENT_PAIR:
			main_shape.size = Vector3(0.1, 1.05, 0.2)
			offhand_shape.size = main_shape.size
			weapon_mesh.position = Vector3(0.0, -0.12, -0.12)
			offhand_weapon_mesh.position = weapon_mesh.position
			weapon_material.albedo_color = Color("b1a88d")
		CombatStyle.VEILCRAFT:
			main_shape.size = Vector3(0.09, 1.65, 0.09)
			weapon_mesh.position = Vector3(0.0, -0.28, 0.0)
			weapon_material.albedo_color = Color("668ee0")
		CombatStyle.EMBER_RITE:
			main_shape.size = Vector3(0.16, 0.85, 0.16)
			weapon_mesh.position = Vector3(0.0, -0.05, 0.0)
			weapon_material.albedo_color = Color("d07a32")


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
