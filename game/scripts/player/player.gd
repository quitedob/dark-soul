extends CharacterBody3D

signal died(death_position)
signal stats_changed(health, max_health, stamina, max_stamina)
signal focus_changed(current, maximum)
signal poise_changed(current, maximum)
signal lock_target_changed(target)
signal embers_changed(amount)
signal combat_style_changed(style_id, display_name)
signal hands_changed(right_hand_item, left_hand_item, action_labels)
signal healing_started()
signal grip_changed(grip_mode: int, grip_name: String)
signal guard_meter_changed(current, maximum)
signal hit_landed(target, is_heavy)
signal charge_progress_changed(ratio: float, tier: int)
signal execution_started(kind: StringName, target: Node)

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
	CHARGE_HEAVY,
	STAGGER,
	GUARD_BROKEN,
	EXECUTE_WINDUP,
	EXECUTE_ACTIVE,
	EXECUTE_RECOVERY,
	GRABBED,
	DEAD,
}

enum CombatStyle {
	RELIQUARY_GUARD,
	TWIN_COLOSSI,
	CRESCENT_PAIR,
	VEILCRAFT,
	EMBER_RITE,
}

enum GripMode {
	ONE_HANDED,
	TWO_HANDED,
	PAIRED,
}

## D-02：代码位移 / 动画根运动 / 混合
enum MovementMode {
	CODE_DRIVEN,
	ANIMATION_DRIVEN,
	HYBRID,
}

const CombatAreaScript = preload("res://scripts/combat_area.gd")
const SpellProjectileScene = preload("res://scenes/components/spell_projectile.tscn")
const LocalizationScript = preload("res://scripts/core/localization.gd")
const ProceduralUtils = preload("res://scripts/core/procedural_utils.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const GuardResolverScript = preload("res://scripts/combat/guard_resolver.gd")
const PoiseResolverScript = preload("res://scripts/combat/poise_resolver.gd")
const LockOnSolverScript = preload("res://scripts/combat/lock_on_solver.gd")
const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const CombatData = preload("res://scripts/data/player_combat_data.gd")
const PlayerSpellsScript = preload("res://scripts/combat/player_spells.gd")
const PlayerVisualsScript = preload("res://scripts/core/player_visuals.gd")
const SafePlacement = preload("res://scripts/core/safe_placement.gd")
const CompatibilityMovesetFactory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")
const ExecutionSolverScript = preload("res://scripts/combat/execution_solver.gd")
const ExecutionProfileScript = preload("res://scripts/combat/data/execution_profile.gd")
const ExecutionPairedDirectorScript = preload("res://scripts/combat/execution_paired_director.gd")
const PlayerAnimationBridgeScript = preload("res://scripts/combat/player_animation_bridge.gd")
const STYLE_RESOURCES := {
	CombatStyle.RELIQUARY_GUARD: preload("res://resources/combat_styles/reliquary_guard.tres"),
	CombatStyle.TWIN_COLOSSI: preload("res://resources/combat_styles/twin_colossi.tres"),
	CombatStyle.CRESCENT_PAIR: preload("res://resources/combat_styles/crescent_pair.tres"),
	CombatStyle.VEILCRAFT: preload("res://resources/combat_styles/veilcraft.tres"),
	CombatStyle.EMBER_RITE: preload("res://resources/combat_styles/ember_rite.tres"),
}
const STATS_EMIT_INTERVAL := 0.1
const STYLE_NAMES := [
	"RELIQUARY GUARD",
	"TWIN COLOSSI",
	"CRESCENT PAIR",
	"VEILCRAFT",
	"EMBER RITE",
]

# 法术数据权威源：CombatData.SPELL_CONFIG（data/player_combat_data.gd）

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
var base_poise_health := 100.0
var max_poise_health := 100.0
var poise_health := 100.0
var armor_pdr := 0.15
var poise_regen_delay := 3.0
var poise_regen_rate := 25.0
var _poise_delay_timer := 0.0
## 当前阶段动作护甲倍率（AttackData 三阶段，非二值霸体）
var _wam_active := 0.0
var combat_style: CombatStyle = CombatStyle.RELIQUARY_GUARD
var right_hand_item := "guardian_sword"
var left_hand_item := "reliquary_shield"
var guard_active := false
var max_guard_meter := 100.0
var guard_meter := 100.0
var _guard_meter_regen_delay := 0.0
const GUARD_METER_REGEN_PER_SEC := 28.0
const GUARD_BROKEN_DURATION := 1.6
var _execution_target: Node3D = null
var _execution_profile = null
var _execution_damage_applied := false
var _execution_kind: StringName = &""
var _execution_director = null  # ExecutionPairedDirector
var _anim_bridge = null  # PlayerAnimationBridge
var _movement_mode: int = MovementMode.HYBRID
## D-08：动画回调闩锁；有 method track 时接管 hitbox 开闭
var _anim_hitbox_latched := false
var _anim_combo_latched := false
## 本招是否 defer hitbox 到动画轨（轻击/跃击有 timing 轨时）
var _hitbox_anim_deferred := false
var attack_hand := "right"
var attack_action_id := "sword_light"
var _leap_is_curved := false
var _leap_second_hit := false
var _leap_uses_root_motion := false
var _pending_cast := &""
var _cast_resolved := false
var dodge_direction := Vector3.FORWARD
var knockback_velocity := Vector3.ZERO
var lock_target: Node3D
var interaction_target: Node
var configured := false
## K-02：setup/_ready 只初始化子系统一次
var _subsystems_initialized := false
var _buffered_action := ""
var _buffer_timer := 0.0
const INPUT_BUFFER_WINDOW := 0.15
## B-09：多槽动作队列（毫秒到期）
const ACTION_Q_BUFFER_MS := 150
var _action_queue: Dictionary = {}
## B-10：闪避/冲刺同键 tap/hold
const DODGE_SPRINT_THRESHOLD := 0.2
var _ds_timer := 0.0
var _ds_sprinting := false
const MOVE_ACCELERATION := 24.0
## B-12：分状态线/角加速度（动作承诺）
const ATTACK_ACCELERATION := 3.0
const ROLL_ACCELERATION := 2.0
const LOCOMOTION_ANGULAR_ACCELERATION := 10.0
const SPRINT_ANGULAR_ACCELERATION := 8.0
const ROLL_ANGULAR_ACCELERATION := 2.0
const ATTACK_ANGULAR_ACCELERATION := 3.0
const LOCK_ANGULAR_ACCELERATION := 12.0
const DEFAULT_GRAVITY := 24.0
const STAMINA_REGEN_RATE := 30.0
const FOCUS_REGEN_RATE := 4.0
const SPRINT_STAMINA_DRAIN := 18.0
const DODGE_SPEED := 8.4
const DODGE_DURATION := 0.58
const DODGE_INVULN_START := 0.08
const DODGE_INVULN_END := 0.38
const JUMP_VELOCITY := 9.5
const BACKSTEP_DURATION := 0.34
const BACKSTEP_SPEED := 6.2
const CONTEXT_ATTACK_WINDOW := 0.5
const VOID_RECOVER_Y := -36.0
const VOID_DROP_FROM_SAFE := 28.0
const LOCK_ON_MAX_DISTANCE := 18.0
const LOCK_ON_BREAK_DISTANCE := 22.0
# F-03：锁敌镜头四元数 slerp 速度（越大越贴目标）
const LOCK_ON_CAMERA_SLERP := 4.5
# F-05：断锁后镜头回正时长与插值速度
const LOCK_CAMERA_RECOVER_TIME := 0.5
const LOCK_CAMERA_RECOVER_SPEED := 5.0
# F-06：无手动镜头输入后自动回跟
const CAMERA_RECENTER_DELAY := 1.5
const CAMERA_RECENTER_SPEED := 4.0
var _camera_recenter_timer := 0.0
const LOCK_CAMERA_DEFAULT_PITCH := -0.18

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
# F-01：SpringArm 只探测静态世界层（architecture Collision Layers）
# Layer1=静态世界(1) | Layer2=玩家(2) | Layer3=敌人(4) | Layer4=交互物(8)
const SPRING_ARM_WORLD_LAYER := 1
const SPRING_ARM_COLLISION_MASK := SPRING_ARM_WORLD_LAYER  # 值=1；不含玩家/敌人/交互物
var body_collision: CollisionShape3D
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D
var _spells: PlayerSpells
var _visuals: PlayerVisuals
var _weapons: Dictionary = {}  # CombatStyle -> WeaponData
var _movesets: Dictionary = {}  # 兼容：当前 grip 下的 Moveset 缓存
var _current_attack: AttackData
var grip_mode: GripMode = GripMode.ONE_HANDED
var _charge_time := 0.0
var _charge_hand := "right"
var _charge_action_id := ""
var _combat_tip_mode := false  # 设置：战斗提示模式（默认关）
var _grab_pose_lock := false
var _camera_director_override := false
var _visual_frozen := false
var _was_on_floor := true
var _previous_vertical_velocity := 0.0
var last_safe_transform := Transform3D.IDENTITY
var last_landing_speed := 0.0
var _airborne_from_jump := false
var _dodge_is_backstep := false
var _roll_attack_window := 0.0
# F-05：断锁后剩余回正时间（秒）
var _camera_recover_timer := 0.0
var _backstep_attack_window := 0.0
const CHARGE_MAX_HOLD := 2.2
const CHARGE_STAMINA_DRAIN := 6.0


func setup(world, audio, hud) -> void:
	world_node = world
	audio_node = audio
	hud_node = hud
	configured = true
	_ensure_combat_subsystems(world)
	_emit_stats()
	_emit_focus()
	poise_changed.emit(poise_health, max_poise_health)
	embers_changed.emit(embers)
	combat_style_changed.emit(combat_style, _style_display_name())
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())


func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	add_to_group("player")
	# K-02：已由 setup() 初始化则不再重建 _spells/_visuals
	_ensure_combat_subsystems(world_node)
	if _visuals != null:
		_visuals.build_nodes()
	_configure_spring_arm_collision()  # F-01：关卡几何层 mask 校验与固化
	_anim_bridge = PlayerAnimationBridgeScript.new()
	_anim_bridge.setup(self)
	_connect_animation_bridge()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_stats()
	_emit_focus()
	poise_changed.emit(poise_health, max_poise_health)
	embers_changed.emit(embers)
	_update_weapon_visuals()
	combat_style_changed.emit(combat_style, _style_display_name())
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())


## D-08：连接动画桥信号；默认不改 state_time 权威
func _connect_animation_bridge() -> void:
	if _anim_bridge == null:
		return
	if not _anim_bridge.hitbox_activated.is_connected(_on_anim_hitbox_activated):
		_anim_bridge.hitbox_activated.connect(_on_anim_hitbox_activated)
	if not _anim_bridge.hitbox_deactivated.is_connected(_on_anim_hitbox_deactivated):
		_anim_bridge.hitbox_deactivated.connect(_on_anim_hitbox_deactivated)
	if not _anim_bridge.combo_window_opened.is_connected(_on_anim_combo_opened):
		_anim_bridge.combo_window_opened.connect(_on_anim_combo_opened)
	if not _anim_bridge.combo_window_closed.is_connected(_on_anim_combo_closed):
		_anim_bridge.combo_window_closed.connect(_on_anim_combo_closed)
	if not _anim_bridge.forward_impulse_requested.is_connected(_on_anim_forward_impulse):
		_anim_bridge.forward_impulse_requested.connect(_on_anim_forward_impulse)


## AnimationPlayer method track 转发到桥（占位轨路径指向玩家）
func anim_event_hitbox_on() -> void:
	if _anim_bridge != null:
		_anim_bridge.anim_event_hitbox_on()


func anim_event_hitbox_off() -> void:
	if _anim_bridge != null:
		_anim_bridge.anim_event_hitbox_off()


func anim_event_combo_open() -> void:
	if _anim_bridge != null:
		_anim_bridge.anim_event_combo_open()


func anim_event_combo_close() -> void:
	if _anim_bridge != null:
		_anim_bridge.anim_event_combo_close()


func anim_event_push_forward(amount: float = 0.0) -> void:
	if _anim_bridge != null:
		_anim_bridge.anim_event_push_forward(amount)


func _on_anim_hitbox_activated() -> void:
	_anim_hitbox_latched = true
	# 动画轨权威：仅在 defer 模式下由回调开启命中盒
	if _hitbox_anim_deferred and state in [State.ATTACK_ACTIVE, State.LEAP_ACTIVE, State.GUARD_THRUST]:
		_begin_melee_swing()


func _on_anim_hitbox_deactivated() -> void:
	_anim_hitbox_latched = false
	if _hitbox_anim_deferred and combat_area != null:
		combat_area.end_swing()


func _on_anim_combo_opened() -> void:
	_anim_combo_latched = true


func _on_anim_combo_closed() -> void:
	_anim_combo_latched = false


func _on_anim_forward_impulse(amount: float) -> void:
	# method track 前冲：覆盖当帧水平速度（米级冲量 → 瞬时速度）
	var push := amount if amount > 0.001 else 0.45
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	velocity.x = forward.x * push * 10.0
	velocity.z = forward.z * push * 10.0


## K-02：子系统单次初始化（setup 优先，_ready 兜底）
func _ensure_combat_subsystems(world) -> void:
	if _subsystems_initialized and _spells != null and _visuals != null:
		# setup 后补 world 引用（若 _ready 先跑时 world 为空）
		if world != null and world_node == null:
			world_node = world
		return
	if world != null:
		world_node = world
	_spells = PlayerSpellsScript.new()
	_spells.setup(self, world_node)
	_initialize_movesets()
	_visuals = PlayerVisualsScript.new()
	_visuals.setup(self)
	_subsystems_initialized = true


func _physics_process(delta: float) -> void:
	_tick_g06_time_dilation(delta)
	var dilation := _g06_dilation()
	_update_lock_target()
	_update_gamepad_camera(delta)
	_update_camera_rig(delta)
	_process_action_queue()
	_process_dodge_sprint(delta)
	if state != State.DEAD:
		# HitStop：冻本实体输入与状态推进，世界/重力继续
		if not _visual_frozen:
			_handle_action_input()
			_update_state(delta)
			_update_stamina(delta)
			_update_poise(delta)
			_update_context_windows(delta)
		_was_on_floor = is_on_floor()
		_previous_vertical_velocity = velocity.y
		# B-11：下落加倍重力；G-06 局部时间膨胀只乘本实体
		if not is_on_floor():
			var grav_mult := 2.0 if velocity.y < 0.0 else 1.0
			velocity.y -= gravity * grav_mult * dilation * delta
		elif velocity.y <= 0.0:
			velocity.y = 0.0
		# 冻结时清水平意图，避免攻击位移继续滑行
		if _visual_frozen:
			velocity.x = 0.0
			velocity.z = 0.0
		move_and_slide()
		_update_landing_and_safe_transform()
		_check_void_recovery()
	_flush_stats(delta)
	_update_visual_pose()
	# B-03：debug / combat tip 下刷新输入缓冲可视化
	_update_input_buffer_debug()


## G-06：读取局部时间膨胀（默认 1）
func _g06_dilation() -> float:
	return float(get_meta("g06_time_dilation", 1.0))


## G-06：TTL 递减并同步动画播放速率
func _tick_g06_time_dilation(delta: float) -> void:
	if has_meta("g06_time_dilation_ttl"):
		var ttl := float(get_meta("g06_time_dilation_ttl")) - delta
		if ttl <= 0.0:
			if has_meta("g06_time_dilation"):
				remove_meta("g06_time_dilation")
			remove_meta("g06_time_dilation_ttl")
		else:
			set_meta("g06_time_dilation_ttl", ttl)
	var dilation := _g06_dilation()
	if _anim_bridge != null and _anim_bridge.enabled:
		_anim_bridge.set_speed_scale(dilation)


func _update_landing_and_safe_transform() -> void:
	# 落地事件：用落地前垂直速度，避免 move_and_slide 后 velocity.y 被清零
	if not _was_on_floor and is_on_floor():
		last_landing_speed = maxf(0.0, -_previous_vertical_velocity)
		_airborne_from_jump = false
	if is_on_floor() and state != State.DEAD:
		last_safe_transform = global_transform


func _update_context_windows(delta: float) -> void:
	# 翻滚/后撤派生攻击窗口倒计时
	_roll_attack_window = maxf(_roll_attack_window - delta, 0.0)
	_backstep_attack_window = maxf(_backstep_attack_window - delta, 0.0)


func _check_void_recovery() -> void:
	# 掉出关卡：传送回最近安全落点（不走完整死亡）
	if state == State.DEAD:
		return
	var safe_origin := last_safe_transform.origin
	var dropped_far := safe_origin != Vector3.ZERO and global_position.y < safe_origin.y - VOID_DROP_FROM_SAFE
	if global_position.y > VOID_RECOVER_Y and not dropped_far:
		return
	recover_to_last_safe(true)


func recover_to_last_safe(from_void := false) -> void:
	var target := last_safe_transform.origin
	if target == Vector3.ZERO and world_node != null:
		var respawn_variant: Variant = world_node.get("respawn_position")
		if respawn_variant is Vector3:
			target = respawn_variant as Vector3
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		if space != null:
			var exclude: Array[RID] = []
			if body_collision != null:
				exclude.append(get_rid())
			target = SafePlacement.resolve_standing_position(space, target, exclude)
	global_position = target
	velocity = Vector3.ZERO
	if combat_area != null:
		combat_area.end_swing()
	_airborne_from_jump = false
	_change_state(State.LOCOMOTION)
	if from_void:
		# 轻罚：掉落回安全点扣少量生命，避免滥用
		health = maxf(health - 8.0, 1.0)
		_emit_stats()
		_show_message("RECOVERED", 0.7)
		_play_audio("hurt", -6.0, 0.9)


func respawn_at(at: Vector3) -> void:
	var safe := at
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		if space != null:
			var exclude: Array[RID] = []
			if body_collision != null:
				exclude.append(get_rid())
			safe = SafePlacement.resolve_standing_position(space, at, exclude)
	global_position = safe
	velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	focus = max_focus
	stamina_delay = 0.0
	poise_health = max_poise_health
	_poise_delay_timer = 0.0
	visible = true
	body_collision.set_deferred("disabled", false)
	visual_root.rotation = Vector3.ZERO
	_change_state(State.LOCOMOTION)
	last_safe_transform = global_transform
	_emit_stats()
	_emit_focus()


func _unhandled_input(event: InputEvent) -> void:
	# 锁敌期间禁用自由环绕；玩家动手取消断锁回正
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and state != State.DEAD:
		if lock_target == null or not is_instance_valid(lock_target):
			_camera_recover_timer = 0.0
			_camera_recenter_timer = CAMERA_RECENTER_DELAY
			var motion := event as InputEventMouseMotion
			camera_rig.rotation.y -= motion.relative.x * mouse_sensitivity * camera_sensitivity_scale
			var pitch_direction := 1.0 if invert_camera_y else -1.0
			camera_pitch.rotation.x = clampf(
				camera_pitch.rotation.x
				+ motion.relative.y * mouse_sensitivity * camera_sensitivity_scale * pitch_direction,
				-1.05,
				0.45
			)
	# F3：切换命中体积调试可视化
	if event.is_action_pressed("debug_hitbox") and combat_area != null:
		combat_area.debug_draw = not combat_area.debug_draw
		_show_message("HITBOX DEBUG " + ("ON" if combat_area.debug_draw else "OFF"), 0.6)


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
	# 跳跃中：仅下半身对 low_sweep 免疫（高位/全身攻击仍命中）
	if _is_low_sweep_immune() and _payload_has_tag(payload, &"low_sweep"):
		return
	var source: Node = payload.get("source")
	if _is_parry_active() and bool(payload.get("parryable", true)) and source != null and is_instance_valid(source):
		if source.has_method("receive_parry"):
			source.receive_parry(self)
		focus = minf(focus + 12.0, max_focus)
		_emit_focus()
		var feedback := HandEquipmentScript.get_parry_feedback(left_hand_item)
		var cue := String(feedback.get("cue", "parry"))
		var message := String(feedback.get("message", "PARRY"))
		_show_message(LocalizationScript.text(message), 0.8)
		_play_audio(cue, -5.0, 1.35)
		_change_state(State.LOCOMOTION)
		return

	var guard_profile: Dictionary = HandEquipmentScript.get_guard_profile(left_hand_item)
	if not guard_profile.is_empty():
		max_guard_meter = float(guard_profile.get("max_guard_meter", 100.0))
	var guard_result := GuardResolverScript.resolve(
		payload,
		guard_active and state != State.GUARD_BROKEN,
		-global_transform.basis.z,
		stamina,
		guard_profile,
		guard_meter
	)
	var incoming_damage := float(guard_result["damage"])
	var incoming_stagger := float(guard_result["stagger"])
	var guarded := bool(guard_result["guarded"])
	if guarded:
		guard_meter = float(guard_result.get("guard_meter_remaining", guard_meter))
		_guard_meter_regen_delay = 1.4
		guard_meter_changed.emit(guard_meter, max_guard_meter)
		_spend_stamina(float(guard_result["stamina_cost"]), 1.0 if guard_result["guard_broken"] else 0.65)
		if bool(guard_result["guard_broken"]):
			guard_active = false
			_show_message("GUARD BROKEN", 0.8)
			_change_state(State.GUARD_BROKEN, GUARD_BROKEN_DURATION)
			health = maxf(health - incoming_damage, 0.0)
			_emit_stats()
			_play_audio("hurt", -4.0, 1.0)
			if health <= 0.0:
				_die()
			return
	var poise_result := {"holds": true, "reduced_damage": 0.0, "settled_poise": poise_health}
	if not guarded:
		# 传入当前储备；结算结果直接写回，避免二次扣减
		poise_result = PoiseResolverScript.resolve(
			poise_health,
			base_poise_health,
			_wam_active,
			armor_pdr,
			float(payload.get("poise", payload.get("stagger", 0.0)))
		)
		poise_health = maxf(float(poise_result["settled_poise"]), 0.0)
		_poise_delay_timer = poise_regen_delay
		poise_changed.emit(poise_health, max_poise_health)
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
		if bool(poise_result["holds"]):
			_show_message("POISE HOLDS", 0.45)
			return
		# 韧性打空：硬直并清空储备
		_show_message("POISE BROKEN" if _wam_active > 0.0 else "STAGGER", 0.65)
		poise_health = 0.0
		poise_changed.emit(poise_health, max_poise_health)
		_change_state(State.STAGGER, clampf(0.28 + incoming_stagger * 0.006, 0.28, 0.68))


func heal_full() -> void:
	health = max_health
	stamina = max_stamina
	focus = max_focus
	stamina_delay = 0.0
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
	_combat_tip_mode = bool(settings.get("combat_tip_mode", false))
	if combat_area != null:
		combat_area.debug_draw = bool(settings.get("combat_hitbox_debug", false))
	combat_style_changed.emit(combat_style, _style_display_name())
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.15


func is_targetable() -> bool:
	return state != State.DEAD and health > 0.0


func _handle_action_input() -> void:
	_update_guard_active()
	if state == State.GRABBED:
		return
	# F-04：左右循环锁敌（[ / ]）；Q/中键仍为获取或单向循环
	if Input.is_action_just_pressed("cycle_lock_left"):
		_cycle_lock_by_direction(-1)
	elif Input.is_action_just_pressed("cycle_lock_right"):
		_cycle_lock_by_direction(1)
	elif Input.is_action_just_pressed("lock_on"):
		_toggle_lock_on()
	if Input.is_action_just_pressed("interact") and interaction_target != null and is_instance_valid(interaction_target) and interaction_target.has_method("interact"):
		interaction_target.interact(self)
	if Input.is_action_just_pressed("cycle_style"):
		set_combat_style((int(combat_style) + 1) % CombatStyle.size())
	for style_index in CombatStyle.size():
		if Input.is_action_just_pressed("style_%d" % (style_index + 1)):
			set_combat_style(style_index)
	if Input.is_action_just_pressed("toggle_grip"):
		_try_toggle_grip()
	# 蓄力态：松开重击或超时则释放
	if state == State.CHARGE_HEAVY:
		if not _is_heavy_held() or state_time <= 0.0:
			_release_heavy_charge()
		return
	# recovery 尾段闪避取消窗：立即闪避，不走 buffer（B-10：dodge just_pressed）
	if state == State.ATTACK_RECOVERY and _current_attack != null \
			and _current_attack.dodge_cancel_seconds >= 0.0 \
			and state_time <= _current_attack.dodge_cancel_seconds \
			and Input.is_action_just_pressed("dodge"):
		_try_dodge()
		return
	if state != State.LOCOMOTION:
		if not _can_buffer_in_current_state():
			return
		_try_buffer_action()
		return
	# B-09：优先消费多槽队列；兼容旧单槽
	if _try_consume_action_queue():
		return
	if _buffered_action != "" and _buffer_timer > 0.0:
		_execute_buffered_action()
		return
	_buffer_timer = 0.0
	_buffered_action = ""
	if Input.is_action_just_pressed("jump"):
		_try_jump()
	# B-10：闪避由 _process_dodge_sprint tap 触发；此处仅兼容旧 just_pressed 边缘
	elif _action_just_pressed(&"left_secondary", [&"parry"]):
		_execute_hand_action("left", "secondary")
	elif Input.is_action_just_pressed("special_attack"):
		_try_style_skill()
	elif Input.is_action_just_pressed("cast_spell"):
		_try_cast_for_style()
	elif _action_just_pressed(&"right_secondary", [&"heavy_attack", &"heavy_attack_alt"]):
		_execute_hand_action("right", "secondary")
	elif _action_just_pressed(&"right_primary", [&"light_attack", &"light_attack_alt"]):
		if _try_execution():
			return
		_execute_hand_action("right", "primary")
	elif _action_just_pressed(&"left_primary", [&"guard"]):
		_execute_hand_action("left", "primary")


func _try_jump() -> void:
	# 通用跳跃：仅 LOCOMOTION + 贴地；上升时自动 snap 停用
	if state != State.LOCOMOTION or not is_on_floor():
		return
	velocity.y = JUMP_VELOCITY
	_airborne_from_jump = true
	_play_audio("dodge", -10.0, 1.35)


## B-09：入队（可与其它动作并存，自动过期）
func enqueue_action(action: StringName, duration_ms: int = ACTION_Q_BUFFER_MS) -> void:
	_action_queue[action] = Time.get_ticks_msec() + duration_ms


## B-09：清理过期槽
func _process_action_queue() -> void:
	var now := Time.get_ticks_msec()
	for key in _action_queue.keys():
		if int(_action_queue[key]) <= now:
			_action_queue.erase(key)


## B-09：查询并可选消费
func action_queued(action: StringName, consume: bool = false) -> bool:
	if not _action_queue.has(action):
		return false
	if int(_action_queue[action]) <= Time.get_ticks_msec():
		_action_queue.erase(action)
		return false
	if consume:
		_action_queue.erase(action)
	return true


## B-09：LOCOMOTION 下按优先级消费队列
func _try_consume_action_queue() -> bool:
	const ORDER: Array[StringName] = [
		&"dodge", &"left_secondary", &"right_secondary", &"right_primary",
		&"left_primary", &"special_attack", &"cast_spell",
	]
	for action in ORDER:
		if not action_queued(action, true):
			continue
		_dispatch_queued_action(String(action))
		return true
	return false


func _dispatch_queued_action(action: String) -> void:
	match action:
		"dodge":
			_try_dodge()
		"left_secondary":
			_execute_hand_action("left", "secondary")
		"right_secondary":
			_execute_hand_action("right", "secondary")
		"right_primary":
			if not _try_execution():
				_execute_hand_action("right", "primary")
		"left_primary":
			_execute_hand_action("left", "primary")
		"special_attack":
			_try_style_skill()
		"cast_spell":
			_try_cast_for_style()


## B-10：dodge 短按闪避、长按冲刺；Shift 仍可单独冲刺
func _process_dodge_sprint(delta: float) -> void:
	if state == State.DEAD or _visual_frozen:
		return
	if Input.is_action_pressed("dodge"):
		_ds_timer += delta
		if _ds_timer >= DODGE_SPRINT_THRESHOLD and state == State.LOCOMOTION:
			_ds_sprinting = true
	elif Input.is_action_just_released("dodge"):
		var was_tap := _ds_timer > 0.0 and _ds_timer < DODGE_SPRINT_THRESHOLD and not _ds_sprinting
		_ds_sprinting = false
		_ds_timer = 0.0
		if was_tap:
			if state == State.LOCOMOTION:
				_try_dodge()
			elif _can_buffer_in_current_state():
				enqueue_action(&"dodge")
	elif not Input.is_action_pressed("dodge"):
		_ds_timer = 0.0
		_ds_sprinting = false


func _can_buffer_in_current_state() -> bool:
	return state in [State.ATTACK_RECOVERY, State.ATTACK_WINDUP, State.ATTACK_ACTIVE,
					 State.GUARD_THRUST, State.LEAP_WINDUP, State.LEAP_ACTIVE,
					 State.CAST]


func _try_buffer_action() -> void:
	# B-09：多槽队列 + 兼容单槽 HUD 显示
	if Input.is_action_just_pressed("dodge"):
		enqueue_action(&"dodge")
		_buffered_action = "dodge"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"left_secondary", [&"parry"]):
		enqueue_action(&"left_secondary")
		_buffered_action = "left_secondary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"right_secondary", [&"heavy_attack", &"heavy_attack_alt"]):
		enqueue_action(&"right_secondary")
		_buffered_action = "right_secondary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"right_primary", [&"light_attack", &"light_attack_alt"]):
		enqueue_action(&"right_primary")
		_buffered_action = "right_primary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif _action_just_pressed(&"left_primary", [&"guard"]):
		enqueue_action(&"left_primary")
		_buffered_action = "left_primary"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif Input.is_action_just_pressed("special_attack"):
		enqueue_action(&"special_attack")
		_buffered_action = "special_attack"
		_buffer_timer = INPUT_BUFFER_WINDOW
	elif Input.is_action_just_pressed("cast_spell"):
		enqueue_action(&"cast_spell")
		_buffered_action = "cast_spell"
		_buffer_timer = INPUT_BUFFER_WINDOW


## B-03：供 HUD / 测试读取当前缓冲槽
func get_input_buffer_debug() -> Dictionary:
	return {
		"action": _buffered_action,
		"timer": _buffer_timer,
		"window_ms": int(INPUT_BUFFER_WINDOW * 1000.0),
		"queue_size": _action_queue.size(),
	}


func _update_input_buffer_debug() -> void:
	# combat tip 或 debug 构建下显示「动作 + 剩余 ms」
	if hud_node == null or not is_instance_valid(hud_node) or not hud_node.has_method("set_input_buffer_debug"):
		return
	var show_debug := _combat_tip_mode or OS.is_debug_build()
	if not show_debug or (_buffered_action == "" and _action_queue.is_empty()) or _buffer_timer <= 0.0:
		if show_debug and not _action_queue.is_empty():
			hud_node.set_input_buffer_debug("Q %d" % _action_queue.size())
		else:
			hud_node.set_input_buffer_debug("")
		return
	var remain_ms := int(ceil(_buffer_timer * 1000.0))
	hud_node.set_input_buffer_debug("BUF %s %dms / %dms" % [
		_buffered_action.to_upper(),
		remain_ms,
		int(INPUT_BUFFER_WINDOW * 1000.0),
	])


func _execute_buffered_action() -> void:
	var action := _buffered_action
	_buffered_action = ""
	_buffer_timer = 0.0
	_action_queue.erase(StringName(action))
	_dispatch_queued_action(action)


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
				var active_duration := _current_attack.active_seconds if _current_attack != null else _style_value(&"active", attack_heavy)
				_change_state(State.ATTACK_ACTIVE, active_duration)
		State.ATTACK_ACTIVE:
			_update_attack_active_motion(delta)
			# 下落攻：hitbox 持续到落地或超时
			var falling_done := false
			if _current_attack != null and _current_attack.hitbox_until_land:
				falling_done = is_on_floor() or state_time <= 0.0
			elif state_time <= 0.0:
				falling_done = true
			if falling_done:
				var recovery_duration := _current_attack.recovery_seconds if _current_attack != null else _style_value(&"recovery", attack_heavy)
				_change_state(State.ATTACK_RECOVERY, recovery_duration)
		State.ATTACK_RECOVERY:
			_slow_horizontal(delta, acceleration)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.DODGE:
			var dodge_speed := BACKSTEP_SPEED if _dodge_is_backstep else DODGE_SPEED
			velocity.x = dodge_direction.x * dodge_speed
			velocity.z = dodge_direction.z * dodge_speed
			if state_time <= 0.0:
				if _dodge_is_backstep:
					_backstep_attack_window = CONTEXT_ATTACK_WINDOW
				else:
					_roll_attack_window = CONTEXT_ATTACK_WINDOW
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
			if _leap_uses_root_motion and _apply_anim_root_motion(delta):
				pass
			else:
				var leap_forward := -global_transform.basis.z
				var profile := _style_data()
				var leap_entry_speed: float = profile.leap_lunge * 0.65
				velocity.x = leap_forward.x * leap_entry_speed
				velocity.z = leap_forward.z * leap_entry_speed
			if state_time <= 0.0:
				_change_state(State.LEAP_ACTIVE, _style_data().leap_active)
		State.LEAP_ACTIVE:
			if _leap_uses_root_motion and _apply_anim_root_motion(delta):
				pass
			else:
				var attack_forward := -global_transform.basis.z
				var profile := _style_data()
				var leap_speed: float = profile.leap_lunge
				velocity.x = attack_forward.x * leap_speed
				velocity.z = attack_forward.z * leap_speed
			if _leap_is_curved and not _leap_second_hit and state_time <= _style_data().leap_active * 0.47:
				_leap_second_hit = true
				combat_area.end_swing()
				_begin_melee_swing()
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, _style_data().leap_recovery)
		State.CAST:
			_slow_horizontal(delta, acceleration * 2.0)
			_face_lock_target(delta)
			if not _cast_resolved and state_time <= 0.18:
				_cast_resolved = true
				_spells.resolve_cast(_pending_cast)
			if state_time <= 0.0:
				_change_state(State.ATTACK_RECOVERY, 0.32)
		State.CHARGE_HEAVY:
			_slow_horizontal(delta, acceleration * 1.4)
			_face_lock_target(delta)
			_charge_time += delta
			_spend_stamina(CHARGE_STAMINA_DRAIN * delta, 0.2, false)
			_emit_charge_progress()
			var moveset := _current_moveset()
			var profile: ChargeProfile = moveset.charged_heavy if moveset != null else null
			var max_hold := profile.tier_three_seconds + 0.25 if profile != null else CHARGE_MAX_HOLD
			if _charge_time >= max_hold or stamina <= 1.0 or state_time <= 0.0:
				_release_heavy_charge()
		State.STAGGER:
			velocity.x = move_toward(velocity.x, knockback_velocity.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, knockback_velocity.z, acceleration * delta)
			knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 9.0 * delta)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.GUARD_BROKEN:
			guard_active = false
			_slow_horizontal(delta, acceleration * 1.6)
			if state_time <= 0.0:
				_change_state(State.LOCOMOTION)
		State.EXECUTE_WINDUP:
			_align_execution_pose(delta)
			if state_time <= 0.0 and _execution_profile != null:
				_change_state(State.EXECUTE_ACTIVE, _execution_profile.active_seconds)
		State.EXECUTE_ACTIVE:
			_align_execution_pose(delta)
			_update_execution_damage_event()
			if state_time <= 0.0 and _execution_profile != null:
				_change_state(State.EXECUTE_RECOVERY, _execution_profile.recovery_seconds)
		State.EXECUTE_RECOVERY:
			_slow_horizontal(delta, acceleration * 1.2)
			if state_time <= 0.0:
				_finish_execution()
				_change_state(State.LOCOMOTION)
		State.GRABBED:
			velocity = Vector3.ZERO
			if _grab_pose_lock:
				pass
			if state_time <= 0.0:
				_grab_pose_lock = false
				_change_state(State.STAGGER, 0.35)


func _update_locomotion(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction := (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()
	var sprinting := _wants_sprint() and direction.length_squared() > 0.0 and stamina > 0.0
	var dilation := _g06_dilation()
	var target_speed := (sprint_speed if sprinting else move_speed) * dilation
	# B-12：按状态取加速度
	var accel: float = _get_current_acceleration()
	if sprinting:
		_spend_stamina(18.0 * delta, 0.25, false)
	# HYBRID：速度仍代码驱动；锁敌侧移走 BlendSpace2D
	velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	if lock_target != null:
		_face_lock_target(delta)
	elif direction.length_squared() > 0.001:
		_face_direction(direction, delta * _get_current_angular_acceleration())
	if _anim_bridge != null and _anim_bridge.enabled and state == State.LOCOMOTION:
		var locked := lock_target != null and is_instance_valid(lock_target)
		if locked:
			# 相对面朝：x=右，y=前（输入已是相机空间，再投到角色局部）
			var facing := -global_transform.basis.z
			facing.y = 0.0
			facing = facing.normalized() if facing.length_squared() > 0.001 else camera_forward
			var right := global_transform.basis.x
			right.y = 0.0
			right = right.normalized() if right.length_squared() > 0.001 else camera_right
			var local_x := direction.dot(right) if direction.length_squared() > 0.001 else 0.0
			var local_y := direction.dot(facing) if direction.length_squared() > 0.001 else 0.0
			_anim_bridge.travel_locomotion(true, true, Vector2(local_x, local_y))
		else:
			_anim_bridge.travel_locomotion(direction.length_squared() > 0.01, false)


func _try_execution() -> bool:
	# 处决优先于中立轻击；需地面且可玩武器
	if state != State.LOCOMOTION or not is_on_floor():
		return false
	if world_node == null or not world_node.has_method("get_target_candidates"):
		return false
	var weapon := _current_weapon()
	var prefer_back := weapon != null and weapon.supports_backstab and (
		HandEquipmentScript.get_weapon_type(right_hand_item) == &"dagger"
		or HandEquipmentScript.get_weapon_type(left_hand_item) == &"dagger"
	)
	var found: Dictionary = ExecutionSolverScript.find_candidate(
		self, world_node.get_target_candidates(), prefer_back
	)
	if found.is_empty():
		return false
	var target: Node3D = found.get("target")
	var profile = found.get("profile")
	var kind: StringName = found.get("kind", &"")
	if target == null or profile == null:
		return false
	if weapon != null:
		if kind == &"back" and not weapon.supports_backstab:
			return false
		if kind != &"back" and not weapon.supports_riposte:
			return false
	if not target.has_method("try_claim_execution"):
		return false
	if not target.try_claim_execution(self, profile.claim_seconds):
		return false
	_execution_target = target
	_execution_profile = profile
	_execution_kind = kind
	_execution_damage_applied = false
	guard_active = false
	# D-06：配对导演 + AnimationTree 处决轨
	_execution_director = ExecutionPairedDirectorScript.new()
	_execution_director.begin(self, target, profile, kind, _anim_bridge, true)
	var tip := "BACKSTAB" if kind == &"back" else ("WEAK POINT" if kind == &"weak_point" else "RIPOSTE")
	_show_combat_tip(tip, 0.55)
	_play_audio("heavy", -5.0, 0.85)
	execution_started.emit(kind, target)
	_change_state(State.EXECUTE_WINDUP, profile.windup_seconds)
	return true


func begin_grabbed(grabber: Node, duration: float = 1.4) -> void:
	# 被抓：短时锁定，不可格挡/闪避
	if state == State.DEAD:
		return
	guard_active = false
	_finish_execution()
	_grab_pose_lock = true
	_change_state(State.GRABBED, maxf(duration, 0.4))


func end_grabbed(_grabber: Node = null) -> void:
	_grab_pose_lock = false
	if state == State.GRABBED:
		_change_state(State.STAGGER, 0.4)


func set_grab_pose_lock(locked: bool) -> void:
	_grab_pose_lock = locked
	if locked:
		velocity = Vector3.ZERO


func set_camera_director_override(active: bool) -> void:
	_camera_director_override = active


func _align_execution_pose(delta: float) -> void:
	# D-06：优先配对导演锚点对齐
	if _execution_director != null and _execution_director.active:
		_execution_director.update_pose(delta)
		return
	if _execution_target == null or not is_instance_valid(_execution_target):
		return
	var anchor := Vector3.UP * 1.1
	if _execution_target.has_method("get_execution_anchor") and _execution_profile != null:
		anchor = _execution_target.get_execution_anchor(_execution_profile.required_anchor)
	var desired := anchor
	# 攻击者站在锚点略外侧
	var offset_dir := global_position - _execution_target.global_position
	offset_dir.y = 0.0
	if offset_dir.length_squared() < 0.001:
		offset_dir = -_execution_target.global_transform.basis.z
	desired = anchor + offset_dir.normalized() * 0.15
	global_position = global_position.lerp(desired, clampf(12.0 * delta, 0.0, 1.0))
	var face := _execution_target.global_position - global_position
	face.y = 0.0
	if face.length_squared() > 0.001:
		_face_direction(face.normalized(), delta * _get_current_angular_acceleration())
	velocity = Vector3.ZERO


func _update_execution_damage_event() -> void:
	if _execution_damage_applied or _execution_profile == null:
		return
	if _execution_target == null or not is_instance_valid(_execution_target):
		return
	var elapsed := 0.0
	if state_duration > 0.0:
		elapsed = state_duration - state_time
	# D-06：事件点伤害经配对导演（单次）
	if _execution_director != null and _execution_director.active:
		var weapon := _current_weapon()
		var crit := weapon.critical_multiplier if weapon != null else 1.0
		var base := 28.0
		if _current_moveset() != null and _current_moveset().neutral_light != null:
			base = _current_moveset().neutral_light.damage
		var amount: float = base * float(crit) * float(_execution_profile.critical_multiplier)
		if _execution_director.try_damage_event(elapsed, amount):
			_execution_damage_applied = true
		return
	if elapsed < _execution_profile.damage_event_seconds:
		return
	_execution_damage_applied = true
	var weapon := _current_weapon()
	var crit := weapon.critical_multiplier if weapon != null else 1.0
	var base := 28.0
	if _current_moveset() != null and _current_moveset().neutral_light != null:
		base = _current_moveset().neutral_light.damage
	var amount: float = base * float(crit) * float(_execution_profile.critical_multiplier)
	if _execution_target.has_method("apply_execution_damage"):
		_execution_target.apply_execution_damage(amount, _execution_profile.allow_lethal_damage)
	elif _execution_target.has_method("receive_hit"):
		_execution_target.receive_hit(amount, 0.0, -global_transform.basis.z, self)


func _finish_execution() -> void:
	# D-06：取消/完成均释放 claim，恢复可玩
	if _execution_director != null and _execution_director.active:
		_execution_director.complete(&"finished")
	_execution_director = null
	if _execution_target != null and is_instance_valid(_execution_target) and _execution_target.has_method("release_execution_claim"):
		_execution_target.release_execution_claim(self)
	_execution_target = null
	_execution_profile = null
	_execution_kind = &""
	_execution_damage_applied = false


func _try_attack(heavy: bool, hand := "right", action_id := "") -> void:
	if state == State.DEAD:
		return
	var moveset: MovesetData = _current_moveset()
	if moveset == null:
		return
	# 空中跳劈：要求左右同类型（或双持）
	if not is_on_floor() and not _can_jump_slash():
		_show_combat_tip("JUMP SLASH NEEDS MATCHED WEAPONS", 0.75)
		return
	var resolved := _resolve_context_attack(moveset, heavy)
	if resolved == null:
		return
	_commit_attack(resolved, moveset, heavy, hand, action_id)


func _commit_attack(
	resolved: AttackData,
	moveset: MovesetData,
	heavy: bool,
	hand: String,
	action_id: String
) -> void:
	# K-01：先干跑校验，全部通过后再原子扣 stamina/focus
	var attack := resolved.duplicate() as AttackData
	if resolved == moveset.neutral_light or resolved == moveset.neutral_heavy:
		if not action_id.is_empty():
			attack.action_id = StringName(action_id)
	attack.hand = StringName(hand)
	var cost := attack.stamina_cost
	var focus_cost := attack.focus_cost
	if stamina < cost:
		_show_message("NOT ENOUGH STAMINA", 0.8)
		return
	if focus_cost > 0.0 and focus < focus_cost:
		_show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return
	if state in [State.DEAD, State.STAGGER, State.GRABBED]:
		return
	# 原子扣费（校验已全部通过）
	_current_attack = attack
	attack_cost = cost
	_spend_stamina(cost, 0.85)
	if focus_cost > 0.0:
		focus = maxf(focus - focus_cost, 0.0)
		_emit_focus()
	attack_heavy = heavy or _attack_has_tag(_current_attack, &"heavy")
	attack_hand = hand
	attack_action_id = String(_current_attack.action_id)
	attack_damage = _current_attack.damage
	attack_stagger = _current_attack.poise_damage
	_consume_context_windows(_current_attack)
	if not is_on_floor() and _current_attack.launch_velocity_y < 0.0:
		velocity.y = minf(velocity.y, _current_attack.launch_velocity_y)
	_announce_context_attack(_current_attack)
	if _anim_bridge != null and _anim_bridge.enabled and not attack_heavy and is_on_floor():
		_anim_bridge.travel_light_attack()
	_change_state(State.ATTACK_WINDUP, _current_attack.windup_seconds)


func _wants_immediate_heavy() -> bool:
	# 空中 / 冲刺 / 翻滚·后撤窗口：立即出招，不进入蓄力
	if not is_on_floor():
		return true
	if _is_sprint_context():
		return true
	if _roll_attack_window > 0.0 or _backstep_attack_window > 0.0:
		return true
	return false


func _is_heavy_held() -> bool:
	return _action_pressed(&"right_secondary", [&"heavy_attack", &"heavy_attack_alt"])


func _action_pressed(action: StringName, aliases: Array[StringName]) -> bool:
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true
	for alias in aliases:
		if InputMap.has_action(alias) and Input.is_action_pressed(alias):
			return true
	return false


func _emit_charge_progress() -> void:
	var moveset := _current_moveset()
	var profile: ChargeProfile = moveset.charged_heavy if moveset != null else null
	var max_hold := profile.tier_three_seconds if profile != null else 1.4
	var ratio := clampf(_charge_time / maxf(max_hold, 0.01), 0.0, 1.0)
	var tier := 1
	if profile != null:
		if _charge_time >= profile.tier_three_seconds:
			tier = 3
		elif _charge_time >= profile.tier_two_seconds:
			tier = 2
	charge_progress_changed.emit(ratio, tier)


func _start_heavy_charge(hand := "right", action_id := "") -> void:
	if state != State.LOCOMOTION:
		return
	_charge_time = 0.0
	_charge_hand = hand
	_charge_action_id = action_id
	guard_active = false
	_show_combat_tip("CHARGING", 0.35)
	charge_progress_changed.emit(0.0, 1)
	_change_state(State.CHARGE_HEAVY, CHARGE_MAX_HOLD)


func _release_heavy_charge() -> void:
	if state != State.CHARGE_HEAVY:
		return
	charge_progress_changed.emit(0.0, 0)
	var hold := _charge_time
	var hand := _charge_hand
	var action_id := _charge_action_id
	_charge_time = 0.0
	# 先回到可攻击态，再提交招式
	state = State.LOCOMOTION
	state_time = 0.0
	var moveset := _current_moveset()
	if moveset == null:
		return
	# 释放瞬间仍尊重语境优先级
	var resolved := _resolve_context_attack(moveset, true)
	if resolved == moveset.neutral_heavy or resolved == null:
		resolved = moveset.resolve_charged(hold)
	if resolved == null:
		return
	if _attack_has_tag(resolved, &"charged"):
		var tier := 1
		if moveset.charged_heavy != null:
			if hold >= moveset.charged_heavy.tier_three_seconds:
				tier = 3
			elif hold >= moveset.charged_heavy.tier_two_seconds:
				tier = 2
		_show_combat_tip("CHARGE T%d" % tier, 0.45)
	_commit_attack(resolved, moveset, true, hand, action_id)


func _update_attack_active_motion(delta: float) -> void:
	# 跳攻/下落攻以 hitbox 判定为主；直剑轻击优先 root motion（D-02）
	var forward := -global_transform.basis.z
	var is_jump := _current_attack != null and _attack_has_tag(_current_attack, &"jump")
	var is_falling := _current_attack != null and (
		_current_attack.hitbox_until_land or _attack_has_tag(_current_attack, &"falling")
	)
	if is_falling:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * 1.4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * 1.4 * delta)
		if _current_attack != null:
			velocity.y = minf(velocity.y, _current_attack.launch_velocity_y)
		return
	if _movement_mode == MovementMode.ANIMATION_DRIVEN and _apply_anim_root_motion(delta):
		return
	if _anim_bridge != null and _anim_bridge.enabled and not is_jump and not attack_heavy:
		if _apply_anim_root_motion(delta):
			return
	var lunge := _current_attack.authored_displacement.z if _current_attack != null else _style_value(&"lunge", attack_heavy)
	if is_jump:
		lunge *= 0.55
	velocity.x = forward.x * lunge
	velocity.z = forward.z * lunge


func _apply_anim_root_motion(delta: float) -> bool:
	# D-02：提取 position/rotation 根运动并写入 CharacterBody3D
	if _anim_bridge == null or not _anim_bridge.enabled:
		return false
	var rm: Vector3 = _anim_bridge.consume_root_motion()
	var rr: Quaternion = _anim_bridge.consume_root_motion_rotation()
	var applied := false
	if rm.length_squared() > 0.00001:
		var world_rm := global_transform.basis * rm
		velocity.x = world_rm.x / maxf(delta, 0.0001)
		velocity.z = world_rm.z / maxf(delta, 0.0001)
		applied = true
	if rr != Quaternion.IDENTITY and rr.length_squared() > 0.0:
		var yaw := rr.get_euler().y
		if absf(yaw) > 0.0001:
			rotate_y(yaw)
			applied = true
	return applied


func _resolve_context_attack(moveset: MovesetData, heavy: bool) -> AttackData:
	# 优先级：下落 > 跳跃 > 冲刺 > 翻滚 > 后撤 > 中立
	if not is_on_floor():
		if not _can_jump_slash():
			return null
		if heavy and velocity.y < -0.5 and moveset.falling_attack != null:
			return moveset.falling_attack
		if moveset.jump_attack != null:
			return moveset.jump_attack
		return null
	else:
		if _is_sprint_context() and moveset.sprint_attack != null:
			return moveset.sprint_attack
		if _roll_attack_window > 0.0 and moveset.roll_attack != null:
			return moveset.roll_attack
		if _backstep_attack_window > 0.0 and moveset.backstep_attack != null:
			return moveset.backstep_attack
	return moveset.neutral_heavy if heavy else moveset.neutral_light


func _can_jump_slash() -> bool:
	# 分左右手：双持视作同武器；成对/单持必须左右 weapon_type 相同
	return HandEquipmentScript.can_jump_slash(right_hand_item, left_hand_item, _grip_key())


func _hand_item_id(hand: String) -> String:
	return right_hand_item if hand == "right" else left_hand_item


func _hand_weapon_type(hand: String) -> StringName:
	return HandEquipmentScript.get_weapon_type(_hand_item_id(hand))


func _is_sprint_context() -> bool:
	if not is_on_floor() or stamina <= 0.0:
		return false
	if not _wants_sprint():
		return false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).length()
	return horizontal >= move_speed * 1.05


## B-10：冲刺意图（经典 sprint 键或 dodge 长按）
func _wants_sprint() -> bool:
	if _ds_sprinting:
		return true
	return Input.is_action_pressed("sprint")


## B-12：按状态线加速度（缺省回站立基准）
func _get_current_acceleration() -> float:
	match state:
		State.LOCOMOTION:
			return MOVE_ACCELERATION
		State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY, State.LEAP_WINDUP, State.LEAP_ACTIVE:
			return ATTACK_ACCELERATION
		State.DODGE:
			return ROLL_ACCELERATION
		_:
			return acceleration


## B-12：按状态角速度（翻滚/攻击承诺转向）
func _get_current_angular_acceleration() -> float:
	match state:
		State.DODGE:
			return ROLL_ANGULAR_ACCELERATION
		State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY, State.LEAP_WINDUP, State.LEAP_ACTIVE:
			return ATTACK_ANGULAR_ACCELERATION
		State.LOCOMOTION:
			return SPRINT_ANGULAR_ACCELERATION if _wants_sprint() else LOCOMOTION_ANGULAR_ACCELERATION
		_:
			return LOCOMOTION_ANGULAR_ACCELERATION


func _consume_context_windows(attack: AttackData) -> void:
	if _attack_has_tag(attack, &"roll"):
		_roll_attack_window = 0.0
	if _attack_has_tag(attack, &"backstep"):
		_backstep_attack_window = 0.0


func _announce_context_attack(attack: AttackData) -> void:
	# 语境招式教学提示：全部走战斗提示模式
	if _attack_has_tag(attack, &"falling"):
		_show_combat_tip("FALLING ATTACK", 0.55)
	elif _attack_has_tag(attack, &"jump"):
		_show_combat_tip("JUMP ATTACK", 0.45)
	elif _attack_has_tag(attack, &"sprint"):
		_show_combat_tip("SPRINT ATTACK", 0.45)
	elif _attack_has_tag(attack, &"roll"):
		_show_combat_tip("ROLL ATTACK", 0.45)
	elif _attack_has_tag(attack, &"backstep"):
		_show_combat_tip("BACKSTEP ATTACK", 0.45)
	elif _attack_has_tag(attack, &"charged"):
		pass  # 档位提示已在释放时给出


func _show_combat_tip(text: String, duration: float) -> void:
	# 仅战斗提示模式开启时显示蓄力/语境/跳劈等教学提示
	if not _combat_tip_mode:
		return
	_show_message(text, duration)


func _attack_has_tag(attack: AttackData, tag: StringName) -> bool:
	return attack != null and tag in attack.tags


func _payload_has_tag(payload: Dictionary, tag: StringName) -> bool:
	var tags: Variant = payload.get("tags", [])
	if tags is Array:
		return tag in tags or String(tag) in tags
	return false


func _is_low_sweep_immune() -> bool:
	# 仅通用跳跃腾空期间对 low_sweep 免疫（leap 战技不享受）
	return _airborne_from_jump and not is_on_floor() and state not in [State.LEAP_WINDUP, State.LEAP_ACTIVE]


func set_hand_loadout(right_hand_id: String, left_hand_id: String) -> bool:
	if not HandEquipmentScript.is_valid_for_hand(right_hand_id, "right"):
		return false
	if not HandEquipmentScript.is_valid_for_hand(left_hand_id, "left"):
		return false
	right_hand_item = right_hand_id
	left_hand_item = left_hand_id
	combat_style = HandEquipmentScript.get_style_for_loadout(right_hand_item, left_hand_item) as CombatStyle
	_apply_default_grip_for_style()
	guard_active = false
	_update_weapon_visuals()
	var display_name := _style_display_name()
	combat_style_changed.emit(combat_style, display_name)
	hands_changed.emit(right_hand_item, left_hand_item, get_hand_action_labels())
	grip_changed.emit(int(grip_mode), _grip_display_name())
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


func _initialize_movesets() -> void:
	if not _weapons.is_empty():
		_refresh_moveset_cache()
		return
	for style_id in STYLE_RESOURCES:
		_weapons[style_id] = CompatibilityMovesetFactory.create_weapon(STYLE_RESOURCES[style_id])
	_apply_default_grip_for_style()
	_refresh_moveset_cache()


func _current_weapon() -> WeaponData:
	return _weapons.get(combat_style) as WeaponData


func _current_moveset() -> MovesetData:
	var cached: MovesetData = _movesets.get(combat_style) as MovesetData
	if cached != null:
		return cached
	_refresh_moveset_cache()
	return _movesets.get(combat_style) as MovesetData


func _grip_key() -> StringName:
	match grip_mode:
		GripMode.TWO_HANDED: return &"two_handed"
		GripMode.PAIRED: return &"paired"
	return &"one_handed"


func _grip_display_name() -> String:
	match grip_mode:
		GripMode.TWO_HANDED: return "TWO-HANDED"
		GripMode.PAIRED: return "PAIRED"
	return "ONE-HANDED"


func _grip_mode_from_key(key: StringName) -> GripMode:
	match key:
		&"two_handed": return GripMode.TWO_HANDED
		&"paired": return GripMode.PAIRED
	return GripMode.ONE_HANDED


func _apply_default_grip_for_style() -> void:
	var weapon := _current_weapon()
	if weapon == null:
		grip_mode = GripMode.ONE_HANDED
		return
	grip_mode = _grip_mode_from_key(weapon.default_grip)
	_refresh_moveset_cache()


func _refresh_moveset_cache() -> void:
	var weapon := _current_weapon()
	if weapon == null:
		return
	_movesets[combat_style] = weapon.resolve_moveset(_grip_key())


func _try_toggle_grip() -> void:
	if state != State.LOCOMOTION:
		return
	var weapon := _current_weapon()
	if weapon == null:
		return
	var grips := weapon.supported_grips()
	if grips.size() <= 1:
		_show_combat_tip("GRIP LOCKED", 0.6)
		return
	var next_key := weapon.cycle_grip(_grip_key())
	grip_mode = _grip_mode_from_key(next_key)
	guard_active = false
	_refresh_moveset_cache()
	_update_weapon_visuals()
	_show_combat_tip(_grip_display_name(), 0.7)
	grip_changed.emit(int(grip_mode), _grip_display_name())


func _style_data() -> CombatStyleData:
	return STYLE_RESOURCES[combat_style] as CombatStyleData


func _style_value(key: StringName, heavy: bool) -> float:
	return float(_style_data().value(key, heavy))


func _action_just_pressed(action: StringName, aliases: Array[StringName]) -> bool:
	if InputMap.has_action(action) and Input.is_action_just_pressed(action):
		return true
	for alias in aliases:
		if InputMap.has_action(alias) and Input.is_action_just_pressed(alias):
			return true
	return false


func _update_guard_active() -> void:
	# 双持 / 破防失去副手格挡能力
	if grip_mode == GripMode.TWO_HANDED or state == State.GUARD_BROKEN:
		_set_guard_active(false)
		return
	var left_definition := HandEquipmentScript.get_item(left_hand_item)
	var left_action := String(left_definition.get("primary", ""))
	var semantic_pressed := InputMap.has_action("left_primary") and Input.is_action_pressed("left_primary")
	var legacy_pressed := InputMap.has_action("guard") and Input.is_action_pressed("guard")
	var want_guard := (
		state == State.LOCOMOTION
		and left_action in ["shield_guard", "spell_shield"]
		and (semantic_pressed or legacy_pressed)
	)
	_set_guard_active(want_guard)
	_sync_guard_meter_cap()


func _sync_guard_meter_cap() -> void:
	var guard_profile: Dictionary = HandEquipmentScript.get_guard_profile(left_hand_item)
	if guard_profile.is_empty():
		return
	var next_max := float(guard_profile.get("max_guard_meter", 100.0))
	if not is_equal_approx(next_max, max_guard_meter):
		max_guard_meter = next_max
		guard_meter = minf(guard_meter, max_guard_meter)
		guard_meter_changed.emit(guard_meter, max_guard_meter)


func _update_guard_meter(delta: float) -> void:
	if state == State.GUARD_BROKEN or guard_active:
		return
	if _guard_meter_regen_delay > 0.0:
		_guard_meter_regen_delay = maxf(_guard_meter_regen_delay - delta, 0.0)
		return
	if guard_meter >= max_guard_meter:
		return
	var previous := guard_meter
	guard_meter = minf(guard_meter + GUARD_METER_REGEN_PER_SEC * delta, max_guard_meter)
	if not is_equal_approx(previous, guard_meter):
		guard_meter_changed.emit(guard_meter, max_guard_meter)


## E-11：格挡唯一入口（仅 LOCOMOTION 可开启）
func _set_guard_active(value: bool) -> void:
	var next := value
	if next:
		if state != State.LOCOMOTION or state == State.GUARD_BROKEN:
			next = false
		var guard_profile: Dictionary = HandEquipmentScript.get_guard_profile(left_hand_item)
		if guard_profile.is_empty() or grip_mode == GripMode.TWO_HANDED:
			next = false
	if guard_active == next:
		return
	guard_active = next


func set_guard_active(active: bool) -> void:
	_set_guard_active(active)


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
			elif _wants_immediate_heavy():
				_try_attack(true, "right", action_id)
			else:
				_start_heavy_charge("right", action_id)
		"shield_guard", "spell_shield":
			if grip_mode != GripMode.TWO_HANDED:
				_set_guard_active(true)
		"shield_parry":
			_try_parry()
		"right_axe_strike":
			_try_attack(false, "right", action_id)
		"left_axe_strike":
			_try_attack(false, "left", action_id)
		"left_axe_heavy":
			if _wants_immediate_heavy():
				_try_attack(true, "left", action_id)
			else:
				_start_heavy_charge("left", action_id)
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
	## 兵器诀：优先 WeaponData.default_weapon_art，缺省再按风格回退
	var weapon := _current_weapon()
	if weapon != null and weapon.default_weapon_art != null:
		_execute_weapon_art(weapon.default_weapon_art)
		return
	match combat_style:
		CombatStyle.RELIQUARY_GUARD:
			_try_pierce_thrust()
		CombatStyle.TWIN_COLOSSI:
			_try_leap_attack(false)
		CombatStyle.CRESCENT_PAIR:
			_try_leap_attack(true)
		CombatStyle.VEILCRAFT:
			_try_arcane_barrage()
		CombatStyle.EMBER_RITE:
			_try_divine_smite()


func _execute_weapon_art(art: WeaponArtData) -> void:
	if art == null:
		return
	match art.art_kind:
		&"pierce_thrust":
			_try_pierce_thrust()
		&"colossal_leap":
			_try_leap_attack(false)
		&"crescent_leap":
			_try_leap_attack(true)
		&"arcane_barrage":
			_try_arcane_barrage()
		&"divine_smite":
			_try_divine_smite()
		_:
			if art.entry_attack != null and &"leap" in art.entry_attack.tags:
				_try_leap_attack(combat_style == CombatStyle.CRESCENT_PAIR)


func _try_parry() -> void:
	if state == State.DEAD:
		return
	var parry_profile: Dictionary = HandEquipmentScript.get_item(left_hand_item).get("parry", {})
	if parry_profile.is_empty():
		return
	var cost := float(parry_profile.get("cost", 10.0))
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	guard_active = false
	_spend_stamina(cost, 0.45)
	var startup := float(parry_profile.get("startup", 0.266))
	var active := float(parry_profile.get("active", 0.266))
	var recovery := float(parry_profile.get("recovery", 0.50))
	var miss_penalty := float(parry_profile.get("miss_penalty", 1.0))
	_change_state(State.PARRY, startup + active + recovery * miss_penalty)


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
	_show_combat_tip("SHIELD BASH", 0.65)
	_change_state(State.GUARD_THRUST, 0.34)


func _try_guarded_thrust() -> void:
	_try_shield_bash()


func _try_leap_attack(curved_pair: bool) -> void:
	var moveset: MovesetData = _current_moveset()
	if moveset == null:
		return
	# leap 兵器诀与通用 jump_attack 分离
	var leap := moveset.weapon_art_heavy
	if leap == null or not _attack_has_tag(leap, &"leap"):
		return
	_current_attack = leap.duplicate()
	_current_attack.action_id = &"crescent_leap" if curved_pair else &"colossal_leap"
	var cost := _current_attack.stamina_cost
	if stamina < cost:
		_show_message(LocalizationScript.text("NOT ENOUGH STAMINA"), 0.8)
		return
	_leap_is_curved = curved_pair
	_leap_second_hit = false
	attack_damage = _current_attack.damage
	attack_stagger = _current_attack.poise_damage
	attack_heavy = not curved_pair
	attack_hand = "right"
	attack_action_id = "crescent_leap" if curved_pair else "colossal_leap"
	_spend_stamina(cost, 0.9)
	if is_on_floor():
		velocity.y = _current_attack.launch_velocity_y
	# D-05：Twin Colossi 直线 leap 走 AnimationTree 根运动前冲
	_leap_uses_root_motion = not curved_pair and _anim_bridge != null and _anim_bridge.enabled
	if _leap_uses_root_motion:
		_anim_bridge.travel_leap(false)
	_show_combat_tip(
		LocalizationScript.text("CRESCENT LEAP" if curved_pair else "COLOSSAL LEAP"),
		0.65
	)
	_change_state(State.LEAP_WINDUP, _current_attack.windup_seconds)


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
	_show_combat_tip("PIERCE THRUST", 0.65)
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
	if state == State.DEAD:
		return
	var cost := _style_data().stamina_dodge
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
	# 纯后退输入 → 后撤步（无全身无敌）；其余方向 → 翻滚
	_dodge_is_backstep = input_vector.y > 0.55 and absf(input_vector.x) < 0.45
	if _dodge_is_backstep:
		dodge_direction = global_transform.basis.z
		dodge_direction.y = 0.0
		dodge_direction = dodge_direction.normalized()
		_spend_stamina(cost * 0.75, 0.7)
		_play_audio("dodge", -8.0, 1.15)
		_change_state(State.DODGE, BACKSTEP_DURATION)
		return
	dodge_direction = (right * input_vector.x + forward * -input_vector.y).normalized()
	if dodge_direction.length_squared() < 0.001:
		dodge_direction = -global_transform.basis.z
	dodge_direction.y = 0.0
	dodge_direction = dodge_direction.normalized()
	_spend_stamina(cost, 0.7)
	_play_audio("dodge", -7.0, 1.0)
	_change_state(State.DODGE, DODGE_DURATION)


func _change_state(new_state: State, duration: float = 0.0) -> void:
	var was_executing := state in [State.EXECUTE_WINDUP, State.EXECUTE_ACTIVE, State.EXECUTE_RECOVERY]
	var still_executing := new_state in [State.EXECUTE_WINDUP, State.EXECUTE_ACTIVE, State.EXECUTE_RECOVERY]
	if was_executing and not still_executing:
		_finish_execution()
	if state in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE] \
			and new_state not in [State.ATTACK_ACTIVE, State.GUARD_THRUST, State.LEAP_ACTIVE]:
		combat_area.end_swing()
	if new_state != State.LOCOMOTION:
		guard_active = false
	state = new_state
	state_time = duration
	state_duration = duration
	# D-02：按状态切换位移模式（闪避保持代码驱动）
	_movement_mode = _movement_mode_for_state(new_state)
	# 按状态阶段刷新动作护甲（windup/active/recovery）— E-02 相位 WAM
	_wam_active = _action_armor_for_state()
	_hitbox_anim_deferred = _should_defer_hitbox_to_anim(state)
	if state == State.ATTACK_ACTIVE:
		if not _hitbox_anim_deferred:
			_begin_melee_swing()
		_play_audio("heavy" if attack_heavy else "swing", -5.0, 1.0)
	elif state == State.GUARD_THRUST:
		_begin_melee_swing()
		_play_audio("swing", -7.0, 1.2)
	elif state == State.LEAP_ACTIVE:
		if not _hitbox_anim_deferred:
			_begin_melee_swing()
		_play_audio("heavy" if not _leap_is_curved else "swing", -4.5, 0.9 if not _leap_is_curved else 1.2)
	elif state == State.PARRY:
		_play_audio("swing", -9.0, 1.45)
	elif state == State.STAGGER or state == State.GUARD_BROKEN or state == State.DEAD or state == State.GRABBED:
		combat_area.end_swing()
		# 处决中被打断：导演强制取消恢复
		if _execution_director != null and _execution_director.active:
			_execution_director.force_cancel(&"interrupted")
			_execution_director = null
	elif state == State.EXECUTE_WINDUP:
		combat_area.end_swing()


func _movement_mode_for_state(s: State) -> int:
	match s:
		State.DODGE, State.STAGGER, State.GUARD_BROKEN, State.GRABBED, State.DEAD:
			return MovementMode.CODE_DRIVEN
		State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY:
			# 直剑轻击动画驱动；重击暂退回代码 lunge
			if attack_heavy:
				return MovementMode.CODE_DRIVEN
			return MovementMode.ANIMATION_DRIVEN
		State.LEAP_WINDUP, State.LEAP_ACTIVE:
			return MovementMode.ANIMATION_DRIVEN if _leap_uses_root_motion else MovementMode.CODE_DRIVEN
		State.EXECUTE_WINDUP, State.EXECUTE_ACTIVE, State.EXECUTE_RECOVERY:
			return MovementMode.CODE_DRIVEN
		_:
			return MovementMode.HYBRID


## 有 method-track timing 时由动画开闭 hitbox（重击仍用 state 计时）
func _should_defer_hitbox_to_anim(s: State) -> bool:
	if _anim_bridge == null or not _anim_bridge.enabled:
		return false
	if not _anim_bridge.has_timing_method_tracks:
		return false
	if s == State.ATTACK_ACTIVE and not attack_heavy:
		return true
	if s == State.LEAP_ACTIVE and _leap_uses_root_motion:
		return true
	return false


func _begin_melee_swing() -> void:
	# 按招式 socket 决定挂根还是武器 tip，再开启 CombatArea
	if combat_area == null:
		return
	if _current_attack != null and _current_attack.hitbox_socket == &"weapon_tip" and weapon_pivot != null:
		combat_area.set_socket_follow(weapon_pivot, _current_attack.hitbox_offset)
	else:
		combat_area.clear_socket_follow()
	combat_area.begin_swing(attack_damage, attack_stagger, _attack_metadata())


func _attack_metadata() -> Dictionary:
	# 命中元数据按出招手装备分算左右武器
	var item_id := _hand_item_id(attack_hand)
	if _current_attack != null and attack_action_id == String(_current_attack.action_id):
		var meta := _current_attack.to_hit_metadata(item_id)
		meta["weapon_type"] = String(_hand_weapon_type(attack_hand))
		meta["grip_mode"] = String(_grip_key())
		return meta
	var is_unblockable := attack_action_id in ["pierce_thrust", "shield_bash"]
	return {
		"hand": attack_hand,
		"item_id": item_id,
		"action_id": attack_action_id,
		"weapon_type": String(_hand_weapon_type(attack_hand)),
		"grip_mode": String(_grip_key()),
		"guard_damage": attack_damage + attack_stagger * 0.35,
		"tags": ["melee", "heavy" if attack_heavy else "light"] + (["unblockable"] if is_unblockable else []),
		"is_heavy": attack_heavy,
		"blockable": not is_unblockable,
		"parryable": attack_action_id != "shield_bash" and not is_unblockable,
	}


func _is_invulnerable() -> bool:
	# 后撤步无全身无敌帧
	if state != State.DODGE or state_duration <= 0.0 or _dodge_is_backstep:
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
	var startup := float(parry_profile.get("startup", 0.266))
	var active := float(parry_profile.get("active", 0.266))
	return elapsed >= startup and elapsed <= startup + active


func _is_guarding_hit(hit_direction: Variant) -> bool:
	if not hit_direction is Vector3:
		return false
	var result := GuardResolverScript.resolve(
		{"damage": 0.0, "stagger": 0.0, "direction": hit_direction, "blockable": true},
		guard_active,
		-global_transform.basis.z,
		stamina,
		HandEquipmentScript.get_guard_profile(left_hand_item),
		guard_meter
	)
	return bool(result["guarded"])


## 从当前 AttackData 阶段读取 ActionArmorModifier；无招式时回退风格 leap/guard
func _action_armor_for_state() -> float:
	if _current_attack != null:
		match state:
			State.ATTACK_WINDUP, State.LEAP_WINDUP:
				return _current_attack.poise_modifier_for_phase(&"windup")
			State.ATTACK_ACTIVE, State.LEAP_ACTIVE:
				return _current_attack.poise_modifier_for_phase(&"active")
			State.ATTACK_RECOVERY:
				return _current_attack.poise_modifier_for_phase(&"recovery")
			State.GUARD_THRUST:
				return maxf(_current_attack.poise_modifier_for_phase(&"active"), _style_data().wam_guard)
	match state:
		State.LEAP_WINDUP:
			return _style_data().wam_leap * 0.45
		State.LEAP_ACTIVE:
			return _style_data().wam_leap
		State.GUARD_THRUST:
			return _style_data().wam_guard
		State.ATTACK_ACTIVE:
			return _style_data().wam_heavy if attack_heavy else _style_data().wam_light
	return 0.0


func _update_poise(delta: float) -> void:
	if _poise_delay_timer > 0.0:
		_poise_delay_timer = maxf(_poise_delay_timer - delta, 0.0)
		return
	if state != State.LOCOMOTION or poise_health >= max_poise_health:
		return
	poise_health = minf(poise_health + poise_regen_rate * delta, max_poise_health)
	poise_changed.emit(poise_health, max_poise_health)


func _update_stamina(delta: float) -> void:
	_update_guard_meter(delta)
	var dilation := _g06_dilation()
	if state == State.LOCOMOTION:
		if stamina_delay > 0.0:
			stamina_delay -= delta
		else:
			var previous := stamina
			stamina = minf(stamina + stamina_regen * dilation * delta, max_stamina)
			if not is_equal_approx(previous, stamina):
				_queue_stats_update()
		if focus < max_focus:
			var previous_focus_int := floori(focus)
			focus = minf(focus + FOCUS_REGEN_RATE * dilation * delta, max_focus)
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
		# Q / 中键：顺时针（屏幕角递增）循环
		var next_target := _cycle_lock_target(candidates, 1)
		if next_target != null:
			_set_lock_target(next_target)
		else:
			_set_lock_target(null)
		return
	if candidates.is_empty():
		return
	_set_lock_target(candidates[0])


## F-04：按屏幕角方向循环；未锁时先获取最高分目标
func _cycle_lock_by_direction(direction: int) -> void:
	var candidates := _collect_lock_candidates()
	if candidates.is_empty():
		return
	if lock_target == null or not is_instance_valid(lock_target):
		_set_lock_target(candidates[0])
		return
	var next_target := _cycle_lock_target(candidates, direction)
	if next_target != null:
		_set_lock_target(next_target)


func _collect_lock_candidates() -> Array[Node3D]:
	if world_node == null or not world_node.has_method("get_target_candidates"):
		return []
	var scored: Array[Dictionary] = []
	var camera_position := camera.global_position
	var camera_forward := -camera.global_transform.basis.z
	for candidate in world_node.get_target_candidates():
		if not candidate is Node3D:
			continue
		var target := candidate as Node3D
		var target_point: Vector3 = target.get_target_point() if target.has_method("get_target_point") else target.global_position
		var entry := LockOnSolverScript.score_candidate(
			camera_position,
			camera_forward,
			target_point,
			LOCK_ON_MAX_DISTANCE,
			deg_to_rad(40.0)
		)
		if entry.is_empty() or float(entry["score"]) < 0.2:
			continue
		entry["node"] = target
		entry["screen_angle"] = LockOnSolverScript.screen_angle(camera, target_point)
		scored.append(entry)
	scored.sort_custom(LockOnSolverScript.sort_by_score_descending)
	var result: Array[Node3D] = []
	for entry in scored:
		result.append(entry["node"])
	return result


func _cycle_lock_target(candidates: Array[Node3D], direction: int = 1) -> Node3D:
	if lock_target == null or not is_instance_valid(lock_target):
		return null
	var ordered: Array[Dictionary] = []
	for candidate in candidates:
		var target_point: Vector3 = candidate.get_target_point() if candidate.has_method("get_target_point") else candidate.global_position
		ordered.append({
			"node": candidate,
			"screen_angle": LockOnSolverScript.screen_angle(camera, target_point),
		})
	ordered.sort_custom(LockOnSolverScript.sort_by_screen_angle)
	var current_idx := -1
	for index in range(ordered.size()):
		if ordered[index]["node"] == lock_target:
			current_idx = index
			break
	if current_idx < 0:
		return ordered[0]["node"] if not ordered.is_empty() else null
	var step := 1 if direction >= 0 else -1
	var next_idx := (current_idx + step + ordered.size()) % ordered.size()
	return ordered[next_idx]["node"]


func _set_lock_target(target: Node3D) -> void:
	var clearing := lock_target != null and target == null
	lock_target = target
	# F-05：断锁时启动镜头回正
	if clearing:
		_begin_lock_camera_recover()
	else:
		_camera_recover_timer = 0.0
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
	# F-05：断锁距离用常量（> LOCK_ON_MAX_DISTANCE，留滞回缓冲）
	if global_position.distance_to(lock_target.global_position) > LOCK_ON_BREAK_DISTANCE:
		_set_lock_target(null)


func _face_lock_target(delta: float) -> void:
	if lock_target == null or not is_instance_valid(lock_target):
		return
	var point: Vector3 = lock_target.get_target_point() if lock_target.has_method("get_target_point") else lock_target.global_position
	# 锁敌转向受分状态角速度约束（攻击中更钝）
	var ang := minf(_get_current_angular_acceleration(), LOCK_ANGULAR_ACCELERATION)
	_face_direction(point - global_position, delta * ang)


func _face_direction(direction: Vector3, weight: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(weight, 0.0, 1.0))


## F-05：把当前全局朝向写回本地欧拉，再进入回正插值
func _begin_lock_camera_recover() -> void:
	if camera_rig == null:
		return
	var euler := camera_rig.global_basis.get_euler()
	camera_rig.rotation = Vector3(0.0, euler.y, 0.0)
	_camera_recover_timer = LOCK_CAMERA_RECOVER_TIME


func _update_camera_rig(delta: float) -> void:
	camera_rig.global_position = global_position + Vector3.UP * 1.45
	if _camera_director_override:
		return
	# F-03：锁敌用 Quaternion slerp，禁止 look_at 瞬转
	if lock_target != null and is_instance_valid(lock_target):
		_camera_recover_timer = 0.0
		_camera_recenter_timer = CAMERA_RECENTER_DELAY
		var point: Vector3 = lock_target.get_target_point() if lock_target.has_method("get_target_point") else lock_target.global_position
		var direction: Vector3 = point - camera_rig.global_position
		var horizontal_direction := Vector3(direction.x, 0.0, direction.z)
		if horizontal_direction.length_squared() > 0.001:
			var target_basis := Basis.looking_at(horizontal_direction.normalized(), Vector3.UP)
			var current_quaternion := camera_rig.global_basis.get_rotation_quaternion()
			var target_quaternion := target_basis.get_rotation_quaternion()
			var blended := current_quaternion.slerp(target_quaternion, clampf(delta * LOCK_ON_CAMERA_SLERP, 0.0, 1.0))
			camera_rig.global_basis = Basis(blended)
		var horizontal := Vector2(direction.x, direction.z).length()
		var desired_pitch := -atan2(direction.y, maxf(horizontal, 0.01)) - 0.08
		camera_pitch.rotation.x = lerp_angle(camera_pitch.rotation.x, clampf(desired_pitch, -0.65, 0.25), clampf(delta * 3.5, 0.0, 1.0))
		return
	# F-05：断锁后偏航对齐角色，俯仰回默认轻度俯视
	if _camera_recover_timer > 0.0:
		_camera_recover_timer = maxf(_camera_recover_timer - delta, 0.0)
		var weight := clampf(delta * LOCK_CAMERA_RECOVER_SPEED, 0.0, 1.0)
		camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, rotation.y, weight)
		camera_pitch.rotation.x = lerp_angle(camera_pitch.rotation.x, LOCK_CAMERA_DEFAULT_PITCH, weight)
		return
	# F-06：无手动输入一段时间后，镜头回跟角色朝向（速度越快越贴）
	_camera_recenter_timer = maxf(_camera_recenter_timer - delta, 0.0)
	if _camera_recenter_timer <= 0.0 and state != State.DEAD:
		var h_speed := Vector2(velocity.x, velocity.z).length()
		var dynamic_speed := maxf(CAMERA_RECENTER_SPEED * (h_speed / maxf(sprint_speed, 0.01)), 1.0)
		var w := clampf(delta * dynamic_speed, 0.0, 1.0)
		camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, rotation.y, w)


func _update_gamepad_camera(delta: float) -> void:
	if state == State.DEAD or camera_rig == null or camera_pitch == null or _camera_director_override:
		return
	# 锁敌时右摇杆不抢镜头
	if lock_target != null and is_instance_valid(lock_target):
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.18)
	if look.length_squared() <= 0.0001:
		return
	_camera_recover_timer = 0.0
	_camera_recenter_timer = CAMERA_RECENTER_DELAY
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
	if _visual_frozen:
		return
	_visuals.update_visual_pose()


func set_visual_frozen(frozen: bool) -> void:
	_visual_frozen = frozen


func _update_weapon_trail() -> void:
	_visuals.update_weapon_trail()


func _build_trail_ribbon(points: Array[Vector3]) -> void:
	_visuals._build_trail_ribbon(points)


func _build_nodes() -> void:
	_visuals.build_nodes()
	_configure_spring_arm_collision()


## F-01：SpringArm3D 碰撞 mask —— 仅静态世界层，避开角色与交互物
func _configure_spring_arm_collision() -> void:
	if spring_arm == null:
		return
	# 直接写 mask 位图；勿用 set_collision_mask_value（部分环境无此 API）
	spring_arm.collision_mask = SPRING_ARM_COLLISION_MASK  # = 1，仅 Layer1 静态世界


func _update_weapon_visuals() -> void:
	_visuals.update_weapon_visuals()


func _update_combat_style_visuals() -> void:
	# Legacy function — kept for backward compatibility.
	# No-op: actual visuals are handled by _update_weapon_visuals().
	pass


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	return _visuals.make_material(color, roughness, metallic)
