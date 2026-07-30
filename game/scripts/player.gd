extends CharacterBody3D

signal died(death_position)
signal stats_changed(health, max_health, stamina, max_stamina)
signal focus_changed(current, maximum)
signal lock_target_changed(target)
signal embers_changed(amount)
signal combat_style_changed(style_id, display_name)
signal hands_changed(right_hand_item, left_hand_item, action_labels)
signal healing_started()

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
const ProceduralUtils = preload("res://scripts/core/procedural_utils.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const GuardResolverScript = preload("res://scripts/combat/guard_resolver.gd")
const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const CombatData = preload("res://scripts/data/player_combat_data.gd")
const PlayerSpellsScript = preload("res://scripts/combat/player_spells.gd")
const PlayerVisualsScript = preload("res://scripts/core/player_visuals.gd")
const STATS_EMIT_INTERVAL := 0.1
const STYLE_NAMES := [
	"RELIQUARY GUARD",
	"TWIN COLOSSI",
	"CRESCENT PAIR",
	"VEILCRAFT",
	"EMBER RITE",
]

# ── Spell / Incantation tuning ──────────────────────────────────────────
	# NOTE: Canonical data now lives in PlayerCombatData (data/player_combat_data.gd).
	# These const dicts are kept for backward compat; prefer CombatData.SPELL_CONFIG / STYLE_TIMING.
# Balanced for Soulslike feel: basic spells affordable, powerful spells costly.
# Range = speed × lifetime (effective distance before projectile expires).
const SPELL_CONFIG := {
	"veil_bolt": {
		"focus_cost": 14.0, "cast_time": 0.58, "damage": 26.0, "stagger": 16.0,
		"proj_speed": 18.0, "proj_lifetime": 2.0,   # range ≈ 36 units
		"spell_type": "veil_bolt", "homing": false, "homing_strength": 0.0,
	},
	"seal_burst": {
		"focus_cost": 22.0, "cast_time": 0.72, "damage": 36.0, "stagger": 26.0,
		"proj_speed": 10.0, "proj_lifetime": 1.6,   # range ≈ 16 units — close-range burst
		"spell_type": "seal_burst", "homing": true, "homing_strength": 3.5,
	},
	"bow_quick_shot": {
		"focus_cost": 0.0, "cast_time": 0.38, "damage": 18.0, "stagger": 8.0,
		"proj_speed": 20.0, "proj_lifetime": 1.8,   # range ≈ 36 units
		"spell_type": "bow_quick_shot", "homing": false, "homing_strength": 0.0,
	},
	"bow_power_shot": {
		"focus_cost": 0.0, "cast_time": 0.56, "damage": 32.0, "stagger": 22.0,
		"proj_speed": 14.0, "proj_lifetime": 2.4,   # range ≈ 33.6 units
		"spell_type": "bow_power_shot", "homing": false, "homing_strength": 0.0,
	},
	"ember_rite": {
		"focus_cost": 25.0, "cast_time": 0.82, "heal": 28.0, "aoe_damage": 22.0,
		"aoe_stagger": 20.0, "aoe_range": 6.0,
	},
	# Weapon art projectiles
	"arcane_barrage": {
		"focus_cost": 20.0, "cast_time": 0.0, "damage": 12.0, "stagger": 6.0,
		"proj_speed": 16.0, "proj_lifetime": 1.5,   # range ≈ 24 units
		"spell_type": "arcane_barrage", "homing": true, "homing_strength": 2.8,
	},
	"divine_smite": {
		"focus_cost": 22.0, "cast_time": 0.0, "damage": 34.0, "stagger": 24.0,
		"proj_speed": 12.0, "proj_lifetime": 2.0,
		"spell_type": "default", "homing": true, "homing_strength": 1.8,
	},
}

const STYLE_TIMING := {
	CombatStyle.RELIQUARY_GUARD: {
		"windup_light": 0.28, "windup_heavy": 0.58,
		"active_light": 0.16, "active_heavy": 0.22,
		"recovery_light": 0.38, "recovery_heavy": 0.62,
		"lunge_light": 2.0, "lunge_heavy": 2.8,
		"damage_light": 22.0, "damage_heavy": 38.0,
		"stagger_light": 16.0, "stagger_heavy": 34.0,
		"stamina_light": 18.0, "stamina_heavy": 34.0, "stamina_dodge": 24.0,
		"parry_start": 0.06, "parry_end": 0.26,
		"leap_windup": 0.0, "leap_active": 0.0, "leap_recovery": 0.0,
		"leap_damage": 0.0, "leap_stagger": 0.0, "leap_stamina": 0.0,
		"leap_lunge": 0.0, "leap_velocity_y": 0.0,
		"has_hyper_armor": false,
	},
	CombatStyle.TWIN_COLOSSI: {
		"windup_light": 0.48, "windup_heavy": 0.82,
		"active_light": 0.20, "active_heavy": 0.26,
		"recovery_light": 0.62, "recovery_heavy": 0.92,
		"lunge_light": 1.2, "lunge_heavy": 1.8,
		"damage_light": 32.0, "damage_heavy": 56.0,
		"stagger_light": 22.0, "stagger_heavy": 48.0,
		"stamina_light": 28.0, "stamina_heavy": 46.0, "stamina_dodge": 32.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.38, "leap_active": 0.28, "leap_recovery": 0.62,
		"leap_damage": 58.0, "leap_stagger": 48.0, "leap_stamina": 38.0,
		"leap_lunge": 4.8, "leap_velocity_y": 4.2,
		"has_hyper_armor": true,
	},
	CombatStyle.CRESCENT_PAIR: {
		"windup_light": 0.20, "windup_heavy": 0.38,
		"active_light": 0.14, "active_heavy": 0.18,
		"recovery_light": 0.28, "recovery_heavy": 0.44,
		"lunge_light": 1.6, "lunge_heavy": 2.2,
		"damage_light": 16.0, "damage_heavy": 26.0,
		"stagger_light": 10.0, "stagger_heavy": 20.0,
		"stamina_light": 14.0, "stamina_heavy": 24.0, "stamina_dodge": 20.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.22, "leap_active": 0.34, "leap_recovery": 0.34,
		"leap_damage": 18.0, "leap_stagger": 12.0, "leap_stamina": 27.0,
		"leap_lunge": 5.8, "leap_velocity_y": 4.8,
		"has_hyper_armor": false,
	},
	CombatStyle.VEILCRAFT: {
		"windup_light": 0.30, "windup_heavy": 0.52,
		"active_light": 0.16, "active_heavy": 0.20,
		"recovery_light": 0.42, "recovery_heavy": 0.58,
		"lunge_light": 1.8, "lunge_heavy": 2.4,
		"damage_light": 20.0, "damage_heavy": 32.0,
		"stagger_light": 14.0, "stagger_heavy": 26.0,
		"stamina_light": 20.0, "stamina_heavy": 36.0, "stamina_dodge": 26.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.0, "leap_active": 0.0, "leap_recovery": 0.0,
		"leap_damage": 0.0, "leap_stagger": 0.0, "leap_stamina": 0.0,
		"leap_lunge": 0.0, "leap_velocity_y": 0.0,
		"has_hyper_armor": false,
	},
	CombatStyle.EMBER_RITE: {
		"windup_light": 0.34, "windup_heavy": 0.56,
		"active_light": 0.18, "active_heavy": 0.22,
		"recovery_light": 0.48, "recovery_heavy": 0.64,
		"lunge_light": 1.6, "lunge_heavy": 2.0,
		"damage_light": 22.0, "damage_heavy": 34.0,
		"stagger_light": 16.0, "stagger_heavy": 28.0,
		"stamina_light": 22.0, "stamina_heavy": 38.0, "stamina_dodge": 26.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.0, "leap_active": 0.0, "leap_recovery": 0.0,
		"leap_damage": 0.0, "leap_stagger": 0.0, "leap_stamina": 0.0,
		"leap_lunge": 0.0, "leap_velocity_y": 0.0,
		"has_hyper_armor": false,
	},
}

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
var _upgrade_tier := 0
const UPGRADE_COSTS := [50, 120, 250]
const UPGRADE_HP_PER_TIER := 10

var move_speed := 5.2
var sprint_speed := 7.4
var acceleration := MOVE_ACCELERATION
var gravity := DEFAULT_GRAVITY
var mouse_sensitivity := 0.0024
var camera_sensitivity_scale := 1.0
var invert_camera_y := false
var stamina_regen := STAMINA_REGEN_RATE
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
var hyper_armor := false
var combat_style: CombatStyle = CombatStyle.RELIQUARY_GUARD
var right_hand_item := "guardian_sword"
var left_hand_item := "reliquary_shield"
var guard_active := false
var attack_hand := "right"
var attack_action_id := "sword_light"
var _leap_is_curved := false
var _leap_second_hit := false
var _pending_cast := &""
var _cast_resolved := false
var dodge_direction := Vector3.FORWARD
var knockback_velocity := Vector3.ZERO
var lock_target: Node3D
var interaction_target: Node
var configured := false
var _buffered_action := ""
var _buffer_timer := 0.0
const INPUT_BUFFER_WINDOW := 0.15
const MOVE_ACCELERATION := 24.0
const DEFAULT_GRAVITY := 24.0
const STAMINA_REGEN_RATE := 30.0
const FOCUS_REGEN_RATE := 4.0
const SPRINT_STAMINA_DRAIN := 18.0
const DODGE_SPEED := 8.4
const DODGE_DURATION := 0.58
const DODGE_INVULN_START := 0.08
const DODGE_INVULN_END := 0.38
const LOCK_ON_MAX_DISTANCE := 18.0
const LOCK_ON_BREAK_DISTANCE := 22.0

var visual_root: Node3D
var body_mesh: MeshInstance3D
var cloak_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var weapon_pivot: Node3D
var weapon_mesh: MeshInstance3D
var offhand_weapon_pivot: Node3D
var offhand_weapon_mesh: MeshInstance3D
var shield_mesh: MeshInstance3D
var weapon_trail: MeshInstance3D
var _trail_material: StandardMaterial3D
var _trail_active := false
var _trail_points: Array[Vector3] = []
const MAX_TRAIL_POINTS := 12
var combat_area
var camera_rig: Node3D
var camera_pitch: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var body_collision: CollisionShape3D
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D
var _spells: PlayerSpells
var _visuals: PlayerVisuals


func setup(world, audio, hud) -> void:
	world_node = world
	audio_node = audio
	hud_node = hud
	configured = true
	_spells = PlayerSpellsScript.new()
	_spells.setup(self, world)
	_visuals = PlayerVisualsScript.new()
	_visuals.setup(self)
	_emit_stats()
	_emit_focus()
	embers_changed.emit(embers)
	combat_style_changed.emit(combat_style, _style_display_name())
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())


func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	add_to_group("player")
	_spells = PlayerSpellsScript.new()
	_spells.setup(self, world_node)
	_visuals = PlayerVisualsScript.new()
	_visuals.setup(self)
	_visuals.build_nodes()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_stats()
	_emit_focus()
	embers_changed.emit(embers)
	_update_weapon_visuals()
	combat_style_changed.emit(combat_style, _style_display_name())
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())


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
	receive_hit_payload({
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": maxf(float(damage), 0.0) + maxf(float(stagger), 0.0) * 0.25,
		"direction": hit_direction,
		"source": source,
		"hand": "",
		"item_id": "",
		"action_id": "legacy_hit",
		"tags": [],
		"blockable": true,
		"parryable": true,
	})


func receive_hit_payload(payload: Dictionary) -> void:
	if state == State.DEAD or _is_invulnerable():
		return
	var source: Node = payload.get("source")
	if _is_parry_active() and bool(payload.get("parryable", true)) and source != null and is_instance_valid(source):
		if source.has_method("receive_parry"):
			source.receive_parry(self)
		focus = minf(focus + 12.0, max_focus)
		_emit_focus()
		_show_message(LocalizationScript.text("PARRY"), 0.8)
		_play_audio("rest", -5.0, 1.35)
		_change_state(State.LOCOMOTION)
		return

	var guard_profile: Dictionary = HandEquipmentScript.get_item(left_hand_item).get("guard", {})
	var guard_result := GuardResolverScript.resolve(
		payload,
		guard_active,
		-global_transform.basis.z,
		stamina,
		guard_profile
	)
	var incoming_damage := float(guard_result["damage"])
	var incoming_stagger := float(guard_result["stagger"])
	if bool(guard_result["guarded"]):
		_spend_stamina(float(guard_result["stamina_cost"]), 1.0 if guard_result["guard_broken"] else 0.65)
		if bool(guard_result["guard_broken"]):
			guard_active = false
			_show_message("GUARD BROKEN", 0.8)
	health = maxf(health - incoming_damage, 0.0)
	_emit_stats()
	_play_audio("hurt", -4.0, 1.0)
	if health <= 0.0:
		_die()
		return
	var direction: Vector3 = payload.get("direction", Vector3.ZERO)
	direction.y = 0.0
	knockback_velocity = direction.normalized() * 3.5 if direction.length_squared() > 0.001 else Vector3.ZERO
	if incoming_stagger > 0.0:
		if hyper_armor:
			incoming_stagger = 0.0
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


func get_upgrade_tier() -> int:
	return _upgrade_tier


func set_upgrade_tier(tier: int) -> void:
	_upgrade_tier = clampi(tier, 0, UPGRADE_COSTS.size())


func get_upgrade_cost() -> int:
	var next_tier := _upgrade_tier
	if next_tier >= UPGRADE_COSTS.size():
		return -1
	return UPGRADE_COSTS[next_tier]


func try_upgrade_max_health() -> bool:
	var cost := get_upgrade_cost()
	if cost < 0 or embers < cost:
		return false
	embers -= cost
	_upgrade_tier += 1
	max_health += UPGRADE_HP_PER_TIER
	health = minf(health + UPGRADE_HP_PER_TIER, max_health)
	embers_changed.emit(embers)
	_emit_stats()
	return true


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
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.15


func is_targetable() -> bool:
	return state != State.DEAD and health > 0.0


func _handle_action_input() -> void:
	_update_guard_active()
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
		if not _can_buffer_in_current_state():
			return
		_try_buffer_action()
		return
	if _buffered_action != "" and _buffer_timer > 0.0:
		_execute_buffered_action()
		return
	_buffer_timer = 0.0
	_buffered_action = ""
	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
	elif _action_just_pressed(&"left_secondary", [&"parry"]):
		_execute_hand_action("left", "secondary")
	elif Input.is_action_just_pressed("special_attack"):
		_try_style_skill()
	elif Input.is_action_just_pressed("cast_spell"):
		_try_cast_for_style()
	elif _action_just_pressed(&"right_secondary", [&"heavy_attack", &"heavy_attack_alt"]):
		_execute_hand_action("right", "secondary")
	elif _action_just_pressed(&"right_primary", [&"light_attack", &"light_attack_alt"]):
		_execute_hand_action("right", "primary")
	elif _action_just_pressed(&"left_primary", [&"guard"]):
		_execute_hand_action("left", "primary")



func _can_buffer_in_current_state() -> bool:
	return state in [State.ATTACK_RECOVERY, State.ATTACK_WINDUP, State.ATTACK_ACTIVE,
					 State.GUARD_THRUST, State.LEAP_WINDUP, State.LEAP_ACTIVE,
					 State.CAST]


func _try_buffer_action() -> void:
	if Input.is_action_just_pressed("dodge"):
		_buffered_action = "dodge"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"left_secondary", [&"parry"]):
		_buffered_action = "left_secondary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"right_secondary", [&"heavy_attack", &"heavy_attack_alt"]):
		_buffered_action = "right_secondary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"right_primary", [&"light_attack", &"light_attack_alt"]):
		_buffered_action = "right_primary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"left_primary", [&"guard"]):
		_buffered_action = "left_primary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif Input.is_action_just_pressed("special_attack"):
		_buffered_action = "special_attack"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif Input.is_action_just_pressed("cast_spell"):
		_buffered_action = "cast_spell"
		_buffer_timer = INPUT_BUFFER_WINDOW


func _execute_buffered_action() -> void:
	var action := _buffered_action
	_buffered_action = ""
	_buffer_timer = 0.0
	match action:
		"dodge":
			_try_dodge()
		"left_secondary":
			_execute_hand_action("left", "secondary")
		"right_secondary":
			_execute_hand_action("right", "secondary")
		"right_primary":
			_execute_hand_action("right", "primary")
		"left_primary":
			_execute_hand_action("left", "primary")
		"special_attack":
			_try_style_skill()
		"cast_spell":
			_try_cast_for_style()


func _update_state(delta: float) -> void:
	state_time = maxf(state_time - delta, 0.0)
	if _buffer_timer > 0.0:
		_buffer_timer = maxf(_buffer_timer - delta, 0.0)
	match state:
		State.LOCOMOTION:
			_update_locomotion(delta)
		State.ATTACK_WINDUP:
			_slow_horizontal(delta, acceleration * 1.8)
			_face_lock_target(delta)
			if state_time <= 0.0:
				_change_state(State.ATTACK_ACTIVE, _style_value(&"active", attack_heavy))
		State.ATTACK_ACTIVE:
			var forward := -global_transform.basis.z
			var lunge := _style_value(&"lunge", attack_heavy)
			velocity.x = forward.x * lunge
			velocity.z = forward.z * lunge
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, _style_value(&"recovery", attack_heavy))
		State.ATTACK_RECOVERY:
			_slow_horizontal(delta, acceleration)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.DODGE:
			velocity.x = dodge_direction.x * DODGE_SPEED
			velocity.z = dodge_direction.z * DODGE_SPEED
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
			var profile: Dictionary = STYLE_TIMING[combat_style]
			var leap_entry_speed: float = profile["leap_lunge"] * 0.65
			velocity.x = leap_forward.x * leap_entry_speed
			velocity.z = leap_forward.z * leap_entry_speed
			if state_time <= 0.0:
				_change_state(State.LEAP_ACTIVE, profile["leap_active"])
		State.LEAP_ACTIVE:
			var attack_forward := -global_transform.basis.z
			var profile: Dictionary = STYLE_TIMING[combat_style]
			var leap_speed: float = profile["leap_lunge"]
			velocity.x = attack_forward.x * leap_speed
			velocity.z = attack_forward.z * leap_speed
			if _leap_is_curved and not _leap_second_hit and state_time <= profile["leap_active"] * 0.47:
				_leap_second_hit = true
				combat_area.end_swing()
				combat_area.begin_swing(profile["leap_damage"], profile["leap_stagger"], _attack_metadata())
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, profile["leap_recovery"])
		State.CAST:
			_slow_horizontal(delta, acceleration * 2.0)
			_face_lock_target(delta)
			if not _cast_resolved and state_time <= 0.18:
				_cast_resolved = true
				_spells.resolve_cast(_pending_cast)
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


func _try_attack(heavy: bool, hand := "right", action_id := "") -> void:
	attack_cost = _style_value(&"stamina", heavy)
	if stamina < attack_cost:
		_show_message("NOT ENOUGH STAMINA", 0.8)
		return
	attack_heavy = heavy
	attack_hand = hand
	attack_action_id = action_id if not action_id.is_empty() else ("heavy_attack" if heavy else "light_attack")
	attack_damage = _style_value(&"damage", heavy)
	attack_stagger = _style_value(&"stagger", heavy)
	_spend_stamina(attack_cost, 0.85)
	_change_state(State.ATTACK_WINDUP, _style_value(&"windup", heavy))


func set_hand_loadout(right_hand_id: String, left_hand_id: String) -> bool:
	if not HandEquipmentScript.is_valid_for_hand(right_hand_id, "right"):
		return false
	if not HandEquipmentScript.is_valid_for_hand(left_hand_id, "left"):
		return false
	right_hand_item = right_hand_id
	left_hand_item = left_hand_id
	combat_style = HandEquipmentScript.get_style_for_loadout(right_hand_item, left_hand_item) as CombatStyle
	guard_active = false
	_update_weapon_visuals()
	var display_name := _style_display_name()
	combat_style_changed.emit(combat_style, display_name)
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())
	return true


func get_hand_loadout() -> Dictionary:
	return {"right_hand": right_hand_item, "left_hand": left_hand_item}


func get_hand_action_labels() -> Dictionary:
	return HandEquipmentScript.get_action_labels(right_hand_item, left_hand_item)


func set_combat_style(style_id: int) -> void:
	var normalized_style := clampi(style_id, 0, CombatStyle.size() - 1)
	var loadout: Dictionary = HandEquipmentScript.get_style_loadout(normalized_style)
	var changed := (
		int(combat_style) != normalized_style
		or right_hand_item != String(loadout["right_hand"])
		or left_hand_item != String(loadout["left_hand"])
	)
	if not changed:
		return
	set_hand_loadout(String(loadout["right_hand"]), String(loadout["left_hand"]))
	_show_message(_style_display_name(), 1.0)


func _style_display_name() -> String:
	return LocalizationScript.text(STYLE_NAMES[int(combat_style)])


func _style_value(key: StringName, heavy: bool) -> float:
	var profile: Dictionary = STYLE_TIMING[combat_style]
	var suffix := "_heavy" if heavy else "_light"
	return profile.get(key + suffix, profile.get(key, 0.0))


func _action_just_pressed(action: StringName, aliases: Array[StringName]) -> bool:
	if InputMap.has_action(action) and Input.is_action_just_pressed(action):
		return true
	for alias in aliases:
		if InputMap.has_action(alias) and Input.is_action_just_pressed(alias):
			return true
	return false


func _update_guard_active() -> void:
	var left_definition := HandEquipmentScript.get_item(left_hand_item)
	var left_action := String(left_definition.get("primary", ""))
	var semantic_pressed := InputMap.has_action("left_primary") and Input.is_action_pressed("left_primary")
	var legacy_pressed := InputMap.has_action("guard") and Input.is_action_pressed("guard")
	guard_active = (
		state == State.LOCOMOTION
		and left_action in ["shield_guard", "spell_shield"]
		and (semantic_pressed or legacy_pressed)
	)


func set_guard_active(active: bool) -> void:
	var guard_profile: Dictionary = HandEquipmentScript.get_item(left_hand_item).get("guard", {})
	guard_active = active and not guard_profile.is_empty()


func _execute_hand_action(hand: String, slot: String) -> void:
	var item_id := right_hand_item if hand == "right" else left_hand_item
	var definition := HandEquipmentScript.get_item(item_id)
	var action_id := String(definition.get(slot, ""))
	match action_id:
		"sword_light":
			_try_attack(false, "right", action_id)
		"sword_heavy":
			if guard_active:
				_try_shield_bash()
			else:
				_try_attack(true, "right", action_id)
		"shield_guard", "spell_shield":
			guard_active = true
		"shield_parry":
			_try_parry()
		"right_axe_strike":
			_try_attack(false, "right", action_id)
		"left_axe_strike":
			_try_attack(false, "left", action_id)
		"left_axe_heavy":
			_try_attack(true, "left", action_id)
		"colossal_leap":
			_try_leap_attack(false)
		"bow_quick_shot":
			_begin_cast(&"bow_quick_shot", CombatData.SPELL_CONFIG["bow_quick_shot"]["focus_cost"], CombatData.SPELL_CONFIG["bow_quick_shot"]["cast_time"])
		"bow_power_shot":
			_begin_cast(&"bow_power_shot", CombatData.SPELL_CONFIG["bow_power_shot"]["focus_cost"], CombatData.SPELL_CONFIG["bow_power_shot"]["cast_time"])
		"dagger_slash":
			_try_attack(false, "left", action_id)
		"seal_bolt":
			_begin_cast(&"veil_bolt", CombatData.SPELL_CONFIG["veil_bolt"]["focus_cost"], CombatData.SPELL_CONFIG["veil_bolt"]["cast_time"])
		"seal_burst":
			_begin_cast(&"seal_burst", CombatData.SPELL_CONFIG["seal_burst"]["focus_cost"], CombatData.SPELL_CONFIG["seal_burst"]["cast_time"])
		"beads_heal", "ember_rite":
			_begin_cast(&"ember_rite", CombatData.SPELL_CONFIG["ember_rite"]["focus_cost"], CombatData.SPELL_CONFIG["ember_rite"]["cast_time"])
		"talisman_strike":
			_try_attack(false, "left", action_id)
		"talisman_burst", "stone_pulse":
			_try_attack(true, "left", action_id)


func _try_style_skill() -> void:
	## Weapon arts (战技) — unique per combat style.
	match combat_style:
		CombatStyle.RELIQUARY_GUARD:
			_try_pierce_thrust()             # 破甲突刺 — armor-piercing lunge
		CombatStyle.TWIN_COLOSSI:
			_try_leap_attack(false)          # Colossal Leap (unchanged)
		CombatStyle.CRESCENT_PAIR:
			_try_leap_attack(true)           # Crescent Leap (unchanged)
		CombatStyle.VEILCRAFT:
			_try_arcane_barrage()            # 秘法弹幕 — 5 seeking bolts
		CombatStyle.EMBER_RITE:
			_try_divine_smite()              # 神圣惩戒 — seeking holy bolt


func _try_parry() -> void:
	var parry_profile: Dictionary = HandEquipmentScript.get_item(left_hand_item).get("parry", {})
	if parry_profile.is_empty():
		return
	var cost := float(parry_profile.get("cost", 10.0))
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	guard_active = false
	_spend_stamina(cost, 0.45)
	_change_state(State.PARRY, 0.48)


func _try_shield_bash() -> void:
	if left_hand_item != "reliquary_shield":
		return
	var cost := 18.0
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	attack_damage = 18.0
	attack_stagger = 42.0
	attack_heavy = true
	attack_hand = "left"
	attack_action_id = "shield_bash"
	_spend_stamina(cost, 0.7)
	_show_message("SHIELD BASH", 0.65)
	_change_state(State.GUARD_THRUST, 0.34)


func _try_guarded_thrust() -> void:
	_try_shield_bash()


func _try_leap_attack(curved_pair: bool) -> void:
	var profile: Dictionary = STYLE_TIMING[combat_style]
	var cost: float = profile["leap_stamina"]
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	_leap_is_curved = curved_pair
	_leap_second_hit = false
	attack_damage = profile["leap_damage"]
	attack_stagger = profile["leap_stagger"]
	attack_heavy = not curved_pair
	attack_hand = "right"
	attack_action_id = "crescent_leap" if curved_pair else "colossal_leap"
	_spend_stamina(cost, 0.9)
	if is_on_floor():
		velocity.y = profile["leap_velocity_y"]
	_show_message(
		LocalizationScript.text("CRESCENT LEAP" if curved_pair else "COLOSSAL LEAP"),
		0.65
	)
	_change_state(State.LEAP_WINDUP, profile["leap_windup"])


func _try_pierce_thrust() -> void:
	## 破甲突刺 — Reliquary Guard weapon art.
	## A powerful forward lunge that pierces armor (unblockable, high stagger).
	var cost := 26.0
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	attack_damage = 36.0
	attack_stagger = 48.0
	attack_heavy = true
	attack_hand = "right"
	attack_action_id = "pierce_thrust"
	_spend_stamina(cost, 0.9)
	_show_message("PIERCE THRUST", 0.65)
	_change_state(State.GUARD_THRUST, 0.42)


func _try_arcane_barrage() -> void:
	_spells.try_arcane_barrage()


func _try_divine_smite() -> void:
	_spells.try_divine_smite()


func _try_cast_for_style() -> void:
	if _spells.try_cast_for_style(int(combat_style)) == "":
		_try_style_skill()


func _begin_cast(cast_id: StringName, focus_cost: float, duration: float) -> void:
	_spells.begin_cast(cast_id, focus_cost, duration)


func _resolve_cast() -> void:
	_spells.resolve_cast(_pending_cast)
	_pending_cast = &""


func _spawn_spell_projectile(config: Dictionary, action_id: String, override_direction: Vector3 = Vector3.ZERO) -> void:
	_spells.spawn_spell_projectile(config, action_id, override_direction)


func _try_dodge() -> void:
	var cost: float = STYLE_TIMING[combat_style]["stamina_dodge"]
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
	_change_state(State.DODGE, DODGE_DURATION)


func _change_state(new_state: State, duration: float = 0.0) -> void:
	if state in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE] \
			and new_state not in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE]:
		combat_area.end_swing()
		hyper_armor = false
	if new_state != State.LOCOMOTION:
		guard_active = false
	state = new_state
	state_time = duration
	state_duration = duration
	if state == State.ATTACK_ACTIVE:
		combat_area.begin_swing(attack_damage, attack_stagger, _attack_metadata())
		_play_audio("heavy" if attack_heavy else "swing", -5.0, 1.0)
		hyper_armor = STYLE_TIMING[combat_style].get("has_hyper_armor", false) and attack_heavy
	elif state == State.GUARD_THRUST:
		combat_area.begin_swing(attack_damage, attack_stagger, _attack_metadata())
		_play_audio("swing", -7.0, 1.2)
		hyper_armor = false
	elif state == State.LEAP_ACTIVE:
		combat_area.begin_swing(attack_damage, attack_stagger, _attack_metadata())
		_play_audio("heavy" if not _leap_is_curved else "swing", -4.5, 0.9 if not _leap_is_curved else 1.2)
		hyper_armor = STYLE_TIMING[combat_style].get("has_hyper_armor", false)
	elif state == State.PARRY:
		_play_audio("swing", -9.0, 1.45)
		hyper_armor = false
	elif state == State.STAGGER or state == State.DEAD:
		combat_area.end_swing()
		hyper_armor = false
	elif new_state not in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE]:
		hyper_armor = false


func _attack_metadata() -> Dictionary:
	var item_id := right_hand_item if attack_hand == "right" else left_hand_item
	var is_unblockable := attack_action_id in ["pierce_thrust", "shield_bash"]
	return {
		"hand": attack_hand,
		"item_id": item_id,
		"action_id": attack_action_id,
		"guard_damage": attack_damage + attack_stagger * 0.35,
		"tags": ["melee", "heavy" if attack_heavy else "light"] + (["unblockable"] if is_unblockable else []),
		"blockable": not is_unblockable,
		"parryable": attack_action_id != "shield_bash" and not is_unblockable,
	}


func _is_invulnerable() -> bool:
	if state != State.DODGE or state_duration <= 0.0:
		return false
	var elapsed := state_duration - state_time
	return elapsed >= DODGE_INVULN_START and elapsed <= DODGE_INVULN_END


func _is_parry_active() -> bool:
	if state != State.PARRY or state_duration <= 0.0:
		return false
	var parry_profile: Dictionary = HandEquipmentScript.get_item(left_hand_item).get("parry", {})
	if parry_profile.is_empty():
		return false
	var elapsed := state_duration - state_time
	return elapsed >= float(parry_profile.get("start", 0.06)) and elapsed <= float(parry_profile.get("end", 0.26))


func _is_guarding_hit(hit_direction: Variant) -> bool:
	if not hit_direction is Vector3:
		return false
	var result := GuardResolverScript.resolve(
		{"damage": 0.0, "stagger": 0.0, "direction": hit_direction, "blockable": true},
		guard_active,
		-global_transform.basis.z,
		stamina,
		HandEquipmentScript.get_item(left_hand_item).get("guard", {})
	)
	return bool(result["guarded"])


func _update_stamina(delta: float) -> void:
	if state == State.LOCOMOTION:
		if stamina_delay > 0.0:
			stamina_delay -= delta
		else:
			var previous := stamina
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
			if not is_equal_approx(previous, stamina):
				_queue_stats_update()
		if focus < max_focus:
			var previous_focus_int := floori(focus)
			focus = minf(focus + FOCUS_REGEN_RATE * delta, max_focus)
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
	var candidates := _collect_lock_candidates()
	if lock_target != null:
		if candidates.size() <= 1:
			_set_lock_target(null)
			return
		var next_target := _cycle_lock_target(candidates)
		if next_target != null:
			_set_lock_target(next_target)
		else:
			_set_lock_target(null)
		return
	if candidates.is_empty():
		return
	_set_lock_target(candidates[0])


func _collect_lock_candidates() -> Array[Node3D]:
	if world_node == null or not world_node.has_method("get_target_candidates"):
		return []
	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var scored: Array[Dictionary] = []
	for candidate in world_node.get_target_candidates():
		if not candidate is Node3D:
			continue
		var target := candidate as Node3D
		var offset := target.global_position - global_position
		var distance := offset.length()
		if distance > 18.0 or distance < 0.01:
			continue
		var offset_flat := offset
		offset_flat.y = 0.0
		var facing_penalty := 1.0 - camera_forward.dot(offset_flat.normalized())
		var score := distance + facing_penalty * 12.0
		scored.append({"node": target, "score": score})
	scored.sort_custom(func(a, b): return a["score"] < b["score"])
	var result: Array[Node3D] = []
	for entry in scored:
		result.append(entry["node"])
	return result


func _cycle_lock_target(candidates: Array[Node3D]) -> Node3D:
	if lock_target == null or not is_instance_valid(lock_target):
		return null
	var current_idx := candidates.find(lock_target)
	if current_idx < 0:
		return candidates[0] if candidates.size() > 0 else null
	var next_idx := (current_idx + 1) % candidates.size()
	return candidates[next_idx]


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
	_visuals.update_visual_pose()


func _update_weapon_trail() -> void:
	_visuals.update_weapon_trail()


func _build_trail_ribbon(points: Array[Vector3]) -> void:
	_visuals._build_trail_ribbon(points)


func _build_nodes() -> void:
	_visuals.build_nodes()


func _update_weapon_visuals() -> void:
	_visuals.update_weapon_visuals()


func _update_combat_style_visuals() -> void:
	# Legacy function — kept for backward compatibility.
	# No-op: actual visuals are handled by _update_weapon_visuals().
	pass


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return _visuals.make_material(color, roughness, metallic)
