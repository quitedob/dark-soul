extends CharacterBody3D

signal died(death_position)
signal stats_changed(health, max_health, stamina, max_stamina)
signal lock_target_changed(target)
signal embers_changed(amount)

enum State {
	LOCOMOTION,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	ATTACK_RECOVERY,
	DODGE,
	STAGGER,
	DEAD,
}

const CombatAreaScript = preload("res://scripts/combat_area.gd")

var world_node: Node
var audio_node: Node
var hud_node: Node

var max_health := 100.0
var health := 100.0
var max_stamina := 100.0
var stamina := 100.0
var embers := 0

var move_speed := 5.2
var sprint_speed := 7.4
var acceleration := 24.0
var gravity := 24.0
var mouse_sensitivity := 0.0024
var stamina_regen := 30.0
var stamina_delay := 0.0

var state: State = State.LOCOMOTION
var state_time := 0.0
var state_duration := 0.0
var attack_damage := 24.0
var attack_stagger := 16.0
var attack_cost := 20.0
var attack_heavy := false
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
	embers_changed.emit(embers)


func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	add_to_group("player")
	_build_nodes()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_stats()
	embers_changed.emit(embers)


func _physics_process(delta: float) -> void:
	_update_lock_target()
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
	_update_visual_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and state != State.DEAD:
		var motion := event as InputEventMouseMotion
		camera_rig.rotation.y -= motion.relative.x * mouse_sensitivity
		camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - motion.relative.y * mouse_sensitivity, -1.05, 0.45)


func receive_hit(damage, stagger, hit_direction, _source) -> void:
	if state == State.DEAD or _is_invulnerable():
		return
	health = maxf(health - maxf(float(damage), 0.0), 0.0)
	_emit_stats()
	_play_audio("hurt", -4.0, 1.0)
	if health <= 0.0:
		_die()
		return
	var direction := hit_direction as Vector3 if hit_direction is Vector3 else Vector3.ZERO
	direction.y = 0.0
	knockback_velocity = direction.normalized() * 3.5 if direction.length_squared() > 0.001 else Vector3.ZERO
	if float(stagger) > 0.0:
		_change_state(State.STAGGER, clampf(0.28 + float(stagger) * 0.006, 0.28, 0.58))


func heal_full() -> void:
	health = max_health
	stamina = max_stamina
	stamina_delay = 0.0
	_emit_stats()


func respawn_at(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	visible = true
	body_collision.set_deferred("disabled", false)
	visual_root.rotation = Vector3.ZERO
	_change_state(State.LOCOMOTION)
	_emit_stats()


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


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.15


func is_targetable() -> bool:
	return state != State.DEAD and health > 0.0


func _handle_action_input() -> void:
	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock_on()
	if Input.is_action_just_pressed("interact") and interaction_target != null and is_instance_valid(interaction_target) and interaction_target.has_method("interact"):
		interaction_target.interact(self)
	if state != State.LOCOMOTION:
		return
	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
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
		_spend_stamina(18.0 * delta, 0.25)
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
	if state == State.ATTACK_ACTIVE and new_state != State.ATTACK_ACTIVE:
		combat_area.end_swing()
	state = new_state
	state_time = duration
	state_duration = duration
	if state == State.ATTACK_ACTIVE:
		combat_area.begin_swing(attack_damage, attack_stagger)
		_play_audio("heavy" if attack_heavy else "swing", -5.0, 1.0)
	elif state == State.STAGGER or state == State.DEAD:
		combat_area.end_swing()


func _is_invulnerable() -> bool:
	if state != State.DODGE or state_duration <= 0.0:
		return false
	var elapsed := state_duration - state_time
	return elapsed >= 0.08 and elapsed <= 0.38


func _update_stamina(delta: float) -> void:
	if stamina_delay > 0.0:
		stamina_delay -= delta
	elif state == State.LOCOMOTION:
		var previous := stamina
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		if not is_equal_approx(previous, stamina):
			_emit_stats()


func _spend_stamina(amount: float, delay: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	stamina_delay = maxf(stamina_delay, delay)
	_emit_stats()


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
	stats_changed.emit(health, max_health, stamina, max_stamina)


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
	weapon_pivot.rotation = Vector3.ZERO
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


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
