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
signal phase_changed(enemy, new_phase: int)  # G-04：相变抛光入口
signal status_changed(status_id: StringName, stacks: float)  # L-10：状态变化（0 表示结束/清空）

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
	EMBER_SKIRMISHER,  # G-03：远程/伏击第三原型
}

const CombatAreaScript = preload("res://scripts/combat_area.gd")
const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const ChapterEnemyFactory = preload("res://scripts/combat/enemy_factory.gd")
const BossCatalog = preload("res://scripts/combat/data/boss_execution_catalog.gd")
const GrabProfileScript = preload("res://scripts/combat/data/grab_profile.gd")
const GrabPairedDirectorScript = preload("res://scripts/combat/grab_paired_director.gd")
const RangedAmbushBehavior = preload("res://scripts/enemy/ranged_ambush_behavior.gd")
const EnemyProjectileScene = preload("res://scenes/actors/enemy_projectile.tscn")
const HealingPunishCatalog = preload("res://scripts/boss/healing_punish_catalog.gd")
const EnemyHealReact = preload("res://scripts/enemy/heal_react.gd")
const BossMacroControllerScript = preload("res://scripts/boss/boss_macro_controller.gd")
const EnemyAiCatalog = preload("res://scripts/data/enemy_ai_catalog.gd")
const PoiseResolverScript = preload("res://scripts/combat/poise_resolver.gd")
const EnemyBehaviorRegistry = preload("res://scripts/enemy/enemy_behavior_registry.gd")
const EnemyTuningData = preload("res://scripts/data/enemy_tuning.gd")
const EnemyAttackCatalog = preload("res://scripts/data/enemy_attack_catalog.gd")
const BossAttackExecutorScript = preload("res://scripts/boss/boss_attack_executor.gd")
const StatusEffectScript = preload("res://scripts/combat/data/status_effect.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const AI_DECISION_INTERVAL := 0.1
const WEAK_POINT_EXPOSE_DEFAULT := 3.2
const GRAB_CHANCE := 0.22
## L-14：非守护人型敌抓投概率（比 Boss 低，Boss 前摇也更长）
const HUMAN_GRAB_CHANCE := 0.10
## L-10：状态 tick 累积间隔
const STATUS_TICK_INTERVAL := 0.5
## L-10：按 body_type 推断敌方自带的攻击状态（狐火/出血/迷心/中毒）
const STATUS_INFLICT_BY_BODY := {
	"hound_spectral": {"bleed": {"stacks": 18.0, "chance": 0.8}},
	"beast_humanoid": {"bleed": {"stacks": 22.0, "chance": 0.8}},
	"fox_claw": {"bleed": {"stacks": 20.0, "chance": 0.8}},
	"lantern_float": {"foxfire": {"stacks": 15.0, "chance": 0.8}},
	"robed_caster": {"confusion": {"stacks": 1.0, "chance": 0.5}},
	"gravity_mage": {"confusion": {"stacks": 1.0, "chance": 0.5}},
	"reflection_clone": {"poison": {"stacks": 20.0, "chance": 0.6}},
	"shadow_form": {"poison": {"stacks": 22.0, "chance": 0.6}},
}

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
## L-14：是否尝试抓投（守护默认 true；人型按 content can_grab / body_type 推断）
var can_grab := false
## L-14：抓投概率（守护 GRAB_CHANCE；人型 HUMAN_GRAB_CHANCE）
var grab_chance := 0.0
## L-10：本敌自带的状态效果（攻击命中目标时施加）
var status_inflict: Dictionary = {}
## L-10：状态叠层（status_id → {"stacks", "elapsed", "tick_accum"}）
var status_bar: Dictionary = {}
var _status_accum := 0.0


var state: State = State.IDLE
var state_time := 0.0
var state_duration := 0.0
var engaged := false
var attack_index := 0
var _phase := 1
var _phase_transition_played := false
var _phase_two_played := false
var _heal_speed_id := 0
## Boss 治疗惩罚 Profile（数据驱动，可章节覆盖）
var _heal_punish_profile = null
## 治疗惩罚冷却剩余秒
var _heal_punish_cooldown := 0.0
## 当前治疗惩罚变体名（gap_close / ranged_snipe / aoe_burst）
var _active_heal_punish_variant: StringName = &""
## AoE burst 半径；>0 时 ACTIVE 帧结算径向伤害
var _heal_punish_aoe_radius := 0.0
## G-01：Boss 宏决策控制器（兼容 BT；微执行仍走本 FSM）
var _macro_ai = null
const PHASE_TWO_THRESHOLD := 0.5
const PHASE_THREE_THRESHOLD := 0.25
# 内容驱动阶段：threshold<0 表示用默认常量；attacks 按阶段索引
var _content_phase_two_threshold := -1.0
var _content_phase_three_threshold := -1.0
var _content_phase_attacks: Dictionary = {}
## G-05：behavior 模块（巡逻/守点/伏击等）
var _behavior_module: RefCounted = null
var _behavior_id := ""
## G-06：当前招式 dict + type 执行器
var _active_attack_profile: Dictionary = {}
var _boss_attack_executor = null
## G-08：当前 AttackData（无则走 dict 回退）
var _current_attack_data: AttackData = null
var _content_phase_four_threshold := -1.0
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
	# L-14：守护默认可抓投；非守护由 content / body_type 在 setup_from_content 决定
	can_grab = guardian
	grab_chance = GRAB_CHANCE if guardian else 0.0
	_visuals_built_key = ""
	if guardian and boss_break_profile == null:
		content_id = "boss_giant_gate" if content_id.is_empty() else content_id
		_setup_boss_break_profile()
	# G-01：仅 Boss/守护者挂载宏决策层
	if guardian:
		_ensure_macro_ai()
	else:
		_macro_ai = null
	if is_inside_tree():
		_ensure_nodes()
		_apply_tuning()
		reset_enemy()
	else:
		# SceneTree._init 阶段 is_inside_tree 可能仍为 false；先灌数值，入树 _ready 再完整初始化
		_apply_tuning()


## 用章节内容字典配置敌人（数值 + 外观）
func setup_from_content(world, target, audio, spawn_position, content: Dictionary, is_guardian := false) -> void:
	chapter_content = content.duplicate(true)
	content_id = String(content.get("id", ""))
	_attack_profile = Dictionary(content.get("attack", {}))
	_parse_boss_phases(content)
	# G-03：按 archetype / behavior 映射远程伏击原型
	var content_type := _content_enemy_type(content)
	setup(world, target, audio, spawn_position, is_guardian, content_type)
	if is_guardian:
		_setup_boss_break_profile()
		# G-02：加载治疗惩罚 Profile（支持 healing_punish 覆盖）
		_heal_punish_profile = HealingPunishCatalog.profile_for(content_id, chapter_content)
	# L-14：人型敌抓投资格（content can_grab > 守护默认 > body_type 推断）
	var explicit_can_grab: Variant = content.get("can_grab")
	if explicit_can_grab is bool:
		can_grab = explicit_can_grab
	elif is_guardian:
		can_grab = true
	else:
		can_grab = _body_type_can_grab(String(content.get("body_type", "")))
	grab_chance = GRAB_CHANCE if (is_guardian and can_grab) else (HUMAN_GRAB_CHANCE if can_grab else 0.0)
	if can_grab and not is_guardian and _grab_profile == null:
		_ensure_human_grab_profile()
	# L-10：敌方自带状态效果（content 显式 > body_type 推断）
	status_inflict = _derive_status_inflict(content)


## 章节字典 → EnemyType（默认近战哨兵）
func _content_enemy_type(content: Dictionary) -> EnemyType:
	var archetype := String(content.get("archetype", "")).to_lower()
	var behavior := String(content.get("behavior", "")).to_lower()
	if archetype == "ember_skirmisher" or behavior == "ranged_ambush" or behavior == "ranged_artillery":
		return EnemyType.EMBER_SKIRMISHER
	return EnemyType.HOLLOW_SENTINEL


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
	_content_phase_four_threshold = -1.0
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
		elif phase_num == 4 and threshold >= 0.0:
			_content_phase_four_threshold = threshold


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
	# 治疗惩罚冷却递减
	if _heal_punish_cooldown > 0.0:
		_heal_punish_cooldown = maxf(_heal_punish_cooldown - delta, 0.0)
	state_time = maxf(state_time - delta, 0.0)
	if _execution_claim_time > 0.0:
		_execution_claim_time = maxf(_execution_claim_time - delta, 0.0)
		if _execution_claim_time <= 0.0:
			_release_execution_claim()
	navigation_refresh -= delta
	if navigation_refresh <= 0.0:
		_refresh_decision_cache()
	_update_state(delta)
	_tick_statuses(delta)
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
	# L-10：重置时清空状态与累积器
	status_bar.clear()
	_status_accum = 0.0
	poise_reset_time = 0.0
	attack_index = 0
	_phase = 1
	_phase_transition_played = false
	_phase_two_played = false
	_heal_speed_id += 1  # invalidate any pending heal-speed timer
	_heal_punish_cooldown = 0.0
	_active_heal_punish_variant = &""
	_heal_punish_aoe_radius = 0.0
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
	# G-01：重置宏层意图为巡逻
	if guardian:
		_ensure_macro_ai()
		_macro_ai.reset()
		_tick_macro_decision()


func receive_hit(damage, stagger, hit_direction, source) -> void:
	# G-07：薄适配器；execution_break 由 AttackData payload 权威提供，不硬编码
	receive_hit_payload({
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"direction": hit_direction,
		"source": source,
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
	# L-10：命中附带状态（武器 status_inflict / status:* 标签）→ 叠层/爆发
	_apply_status_from_payload(payload)
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
	# E-01：与玩家共用 PoiseResolver；外部仍用累加字段 poise（0→limit）以兼容重置契约
	var remaining := maxf(poise_limit - poise, 0.0)
	var wam := _enemy_wam_for_state()
	var poise_result: Dictionary = PoiseResolverScript.resolve(
		remaining,
		poise_limit,
		wam,
		0.0,
		incoming_stagger
	)
	var settled := maxf(float(poise_result.get("settled_poise", 0.0)), 0.0)
	poise = clampf(poise_limit - settled, 0.0, poise_limit)
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
	var broken := not bool(poise_result.get("holds", true))
	if (
		broken
		and not guardian
		and supports_riposte
		and guard_power >= HEAVY_GUARD_BREAK_POWER
	):
		poise = 0.0
		_change_state(State.GUARD_BROKEN, GUARD_BROKEN_SECONDS)
		return
	if broken:
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


## E-02：攻击相位 WAM（重击 active 有护甲；无 AttackData 时重装默认）
func _enemy_wam_for_state() -> float:
	if _current_attack_data != null:
		match state:
			State.WINDUP:
				return _current_attack_data.poise_modifier_for_phase(&"windup")
			State.ACTIVE:
				return _current_attack_data.poise_modifier_for_phase(&"active")
			State.RECOVERY:
				return _current_attack_data.poise_modifier_for_phase(&"recovery")
	# 无 AttackData 时：ACTIVE 给轻量霸体（兼容旧路径）
	if state == State.ACTIVE and bool(_active_attack_profile.get("heavy", false)):
		return 0.85
	return 0.0


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


## L-14：body_type → 是否人型可抓投（armored / beast_humanoid / guard / knight / soldier / rebel 族）
func _body_type_can_grab(body_type: String) -> bool:
	if body_type.is_empty():
		return false
	for marker in ["armored", "armor", "beast_humanoid", "guard", "knight", "soldier", "rebel"]:
		if body_type.contains(marker):
			return true
	return false


## L-10：content 显式 status_inflict > body_type 推断；返回合并 dict
func _derive_status_inflict(content: Dictionary) -> Dictionary:
	var derived := Dictionary(STATUS_INFLICT_BY_BODY.get(String(content.get("body_type", "")), {}))
	var explicit = content.get("status_inflict", {})
	if explicit is Dictionary:
		for key in explicit:
			derived[key] = explicit[key]
	return derived


## L-14：非守护人型抓投 Profile（短前摇 0.9–1.2s 区间，独立抓取体积，不走 CombatArea）
func _ensure_human_grab_profile() -> void:
	if _grab_profile != null:
		return
	var profile = GrabProfileScript.new()
	profile.grab_id = &"human_grab"
	profile.telegraph_seconds = 1.05
	profile.recovery_on_miss_seconds = 1.0
	profile.hold_seconds = 1.3
	profile.damage_event_seconds = 0.4
	profile.grab_damage = 22.0
	profile.capture_radius = 1.25
	profile.hold_socket_offset = Vector3(0.0, 1.1, -1.0)
	_grab_profile = profile


## L-10：施加状态（bleed 阈值爆发即时结算）
func apply_status(status_id: StringName, stacks: float, source: Node = null) -> void:
	if state == State.DEAD or stacks <= 0.0:
		return
	var event := StatusEffectScript.apply(status_bar, status_id, stacks)
	status_changed.emit(status_id, StatusEffectScript.get_stacks(status_bar, status_id))
	var burst_damage := float(event.get("burst_damage", 0.0))
	if burst_damage > 0.0:
		health = maxf(health - burst_damage, 0.0)
		health_changed.emit(health, max_health)
		_play_audio("hurt", -5.0, 0.9 if guardian else 1.0)
		if health <= 0.0:
			_die()


## L-10：每 STATUS_TICK_INTERVAL 推进一次状态（DoT / 衰减 / 过期）
func _tick_statuses(delta: float) -> void:
	if status_bar.is_empty():
		_status_accum = 0.0
		return
	_status_accum += delta
	if _status_accum < STATUS_TICK_INTERVAL:
		return
	var elapsed := _status_accum
	_status_accum = 0.0
	var events := StatusEffectScript.tick(status_bar, elapsed)
	for event in events:
		var status_id := StringName(String(event.get("status", "")))
		if bool(event.get("ended", false)):
			status_changed.emit(status_id, 0.0)
			continue
		var damage := float(event.get("damage", 0.0))
		if damage <= 0.0:
			continue
		health = maxf(health - damage, 0.0)
		health_changed.emit(health, max_health)
		_play_audio("hurt", -6.0, 0.9 if guardian else 1.0)
		if health <= 0.0:
			_die()
			return
		status_changed.emit(status_id, StatusEffectScript.get_stacks(status_bar, status_id))


func has_status(status_id: StringName) -> bool:
	return StatusEffectScript.has_status(status_bar, status_id)


func get_status_stacks(status_id: StringName) -> float:
	return StatusEffectScript.get_stacks(status_bar, status_id)


func clear_status(status_id: StringName) -> void:
	StatusEffectScript.clear_status(status_bar, status_id)
	status_changed.emit(status_id, 0.0)


## L-10：命中 payload → 状态施加。来源：payload.status_inflict、出招手 item_id 的武器状态、status:* 标签。
func _apply_status_from_payload(payload: Dictionary) -> void:
	var inflict: Dictionary = {}
	var raw: Variant = payload.get("status_inflict")
	if raw is Dictionary:
		for key in raw:
			inflict[key] = raw[key]
	var item_id := String(payload.get("item_id", ""))
	if not item_id.is_empty():
		var item_inflict: Dictionary = HandEquipmentScript.get_status_inflict(item_id)
		for key in item_inflict:
			if not inflict.has(key):
				inflict[key] = item_inflict[key]
	var tags: Variant = payload.get("tags", [])
	if tags is Array:
		for tag in tags:
			var tag_str := String(tag)
			if tag_str.begins_with("status:"):
				var sid := tag_str.substr(7)
				if not inflict.has(sid):
					inflict[sid] = 1.0
	if inflict.is_empty():
		return
	for key in inflict:
		var norm := StatusEffectScript.normalize_inflict_entry(inflict[key])
		if float(norm["chance"]) <= 0.0 or randf() > float(norm["chance"]):
			continue
		apply_status(StringName(String(key)), float(norm["stacks"]), payload.get("source"))


## L-14：玩家抓投目标资格（非守护、硬直态、未被处决占用）
func can_be_grabbed() -> bool:
	if state == State.DEAD or guardian:
		return false
	if _execution_claimer != null and is_instance_valid(_execution_claimer):
		return false
	if state != State.STAGGER:
		return false
	if not chapter_content.is_empty():
		return _body_type_can_grab(String(chapter_content.get("body_type", "")))
	return true  # 旧版非守护均为近战人型哨兵


func on_player_healing() -> void:
	# 玩家开奶：Boss 走数据驱动 punish 变体；小怪短时加速追击
	if state == State.DEAD or not is_instance_valid(target_node):
		return
	if state in [State.WEAK_POINT_EXPOSED, State.GRAB_ACTIVE, State.GRAB_WINDUP]:
		return
	if not engaged:
		_set_engaged(true)
		_change_state(State.CHASE)
		_refresh_decision_cache()
	else:
		_refresh_decision_cache()
	if guardian:
		# G-01：先写黑板开奶标志，宏层发 heal_punish 意图后再微执行
		_ensure_macro_ai()
		_macro_ai.set_player_healing(true)
		_tick_macro_decision()
		_try_boss_heal_punish()
		_macro_ai.set_player_healing(false)
	else:
		_heal_speed_id = EnemyHealReact.apply_chase_boost(self, _heal_speed_id)


## Boss 治疗惩罚：按距离/阶段选 gap_close / ranged_snipe / aoe_burst
func _try_boss_heal_punish() -> void:
	if _heal_punish_cooldown > 0.0:
		return
	if _heal_punish_profile == null:
		_heal_punish_profile = HealingPunishCatalog.profile_for(content_id, chapter_content)
	var resolved: Dictionary = HealingPunishCatalog.resolve(
		_heal_punish_profile,
		_cached_distance_to_target,
		_current_phase()
	)
	attack_index += 1
	attack_is_low_sweep = false
	attack_windup = float(resolved.get("windup", 0.5))
	attack_active = float(resolved.get("active", 0.2))
	attack_recovery = float(resolved.get("recovery", 0.7))
	attack_damage = float(resolved.get("damage", 28.0))
	attack_stagger = float(resolved.get("stagger", 34.0))
	attack_lunge = float(resolved.get("lunge", 0.0))
	attack_heavy = bool(resolved.get("heavy", true))
	_active_heal_punish_variant = StringName(String(resolved.get("variant", "gap_close")))
	_heal_punish_aoe_radius = float(resolved.get("aoe_radius", 0.0))
	_heal_punish_cooldown = float(_heal_punish_profile.cooldown_sec)
	var scale := float(resolved.get("windup_scale", 0.7))
	if telegraph_material != null:
		telegraph_material.albedo_color = Color(1.0, 0.22, 0.04, 0.62) if attack_heavy else Color(1.0, 0.08, 0.04, 0.56)
		telegraph_material.emission = Color(1.0, 0.12, 0.02) if attack_heavy else Color(1.0, 0.02, 0.01)
	_change_state(State.WINDUP, attack_windup * scale)


## 治疗 AoE burst：对半径内目标瞬时结算
func _apply_heal_punish_aoe() -> void:
	var radius := _heal_punish_aoe_radius
	_heal_punish_aoe_radius = 0.0
	if radius <= 0.0 or world_node == null or not world_node.has_method("get_target_candidates"):
		return
	for candidate in world_node.get_target_candidates():
		if candidate is Node3D and _horizontal_distance(global_position, candidate.global_position) <= radius:
			if candidate.has_method("receive_hit"):
				var dir: Vector3 = (candidate.global_position - global_position)
				dir.y = 0.0
				if dir.length_squared() < 0.0001:
					dir = -global_transform.basis.z
				else:
					dir = dir.normalized()
				candidate.receive_hit(attack_damage, attack_stagger, dir, self)


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * (1.6 if guardian else 1.25)


func is_targetable() -> bool:
	return state != State.DEAD and health > 0.0 and visible


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(health / max_health, 0.0, 1.0)


func _update_state(delta: float) -> void:
	# L-14：处决/抓投占用期间冻结 FSM 推进（受害者保持受控态，避免中途起身）
	if _execution_claimer != null and is_instance_valid(_execution_claimer):
		_slow_horizontal(delta, acceleration * 3.0)
		velocity.y = minf(velocity.y, 0.0)
		return
	var has_target := _cached_has_target
	var target_position := _cached_target_position
	var distance_to_target := _cached_distance_to_target
	match state:
		State.IDLE:
			# G-05：behavior 模块驱动 IDLE（巡逻/守点等）
			if _behavior_module != null and _behavior_module.has_method("update_idle"):
				_behavior_module.update_idle(self, delta)
			else:
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
			elif enemy_type == EnemyType.EMBER_SKIRMISHER:
				# G-03：保持射程、过近后撤、到位射击
				_update_ranged_ambush_chase(target_position, distance_to_target, delta)
			elif _behavior_module != null and _behavior_module.has_method("desired_chase_velocity"):
				# G-05：游走/侧翼距离带
				_update_skirmish_chase(target_position, distance_to_target, delta)
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
			# 远程：射击时轻微后撤；近战：前冲 lunge
			var lunge_sign := -0.55 if enemy_type == EnemyType.EMBER_SKIRMISHER else 1.0
			velocity.x = forward.x * attack_lunge * lunge_sign
			velocity.z = forward.z * attack_lunge * lunge_sign
			# G-05：危害/特殊 ACTIVE 钩子
			if _behavior_module != null and _behavior_module.has_method("on_attack_active"):
				_behavior_module.on_attack_active(self, target_node)
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


## G-03：远程伏击追击——到位开火，过近后撤
func _update_ranged_ambush_chase(target_position: Vector3, distance_to_target: float, delta: float) -> void:
	var preferred := RangedAmbushBehavior.preferred_distance(chapter_content)
	var retreat_at := RangedAmbushBehavior.retreat_trigger(chapter_content)
	if (
		RangedAmbushBehavior.should_fire(distance_to_target, attack_range, retreat_at)
		and absf(target_position.y - global_position.y) < 3.5
	):
		_start_attack()
		return
	var desired := RangedAmbushBehavior.desired_horizontal_velocity(
		global_position, target_position, move_speed, preferred, retreat_at
	)
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	var face := target_position - global_position
	face.y = 0.0
	if face.length_squared() > 0.001:
		_face_direction(face.normalized(), delta * 8.0)


## G-05：游走族追击（理想距离带 + 侧向）
func _update_skirmish_chase(target_position: Vector3, distance_to_target: float, delta: float) -> void:
	if distance_to_target <= attack_range and absf(target_position.y - global_position.y) < 2.5:
		_start_attack()
		return
	var desired: Vector3 = _behavior_module.desired_chase_velocity(global_position, target_position, move_speed)
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	var face := target_position - global_position
	face.y = 0.0
	if face.length_squared() > 0.001:
		_face_direction(face.normalized(), delta * 8.0)


## G-03：生成朝向目标的敌人投射物
func _spawn_enemy_projectile() -> void:
	if not is_inside_tree():
		return
	var aim := _cached_target_position - global_position
	aim.y = 0.0
	if aim.length_squared() < 0.001:
		aim = -global_transform.basis.z
	else:
		aim = aim.normalized()
	# 略抬仰角，避免贴地扫掠漏检
	aim = (aim + Vector3.UP * 0.08).normalized()
	var projectile = EnemyProjectileScene.instantiate()
	var spawn_pos := global_position + Vector3(0.0, 1.15, 0.0) + aim * 0.55
	var parent_node: Node = world_node if world_node != null else get_tree().current_scene
	if parent_node == null:
		parent_node = self
	parent_node.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.setup(self, aim, attack_damage, attack_stagger, {
		"proj_speed": float(chapter_content.get("proj_speed", 11.5)),
		"proj_lifetime": float(chapter_content.get("proj_lifetime", 2.6)),
		"action_id": "ember_shade_bolt",
		"tags": ["projectile", "enemy", "ranged"],
		"blockable": true,
		"parryable": false,
		"guard_damage": attack_damage + attack_stagger * 0.2,
	})
	_play_audio("swing", -8.0, 1.15)


func _refresh_decision_cache() -> void:
	navigation_refresh = AI_DECISION_INTERVAL
	_cached_has_target = _has_valid_target()
	if not _cached_has_target:
		_cached_target_position = global_position
		_cached_distance_to_target = INF
		_cached_chase_direction = Vector3.ZERO
		# G-01：无目标时仍刷新宏意图（脱战/巡逻）
		if guardian:
			_tick_macro_decision()
		return
	_cached_target_position = _get_target_position()
	_cached_distance_to_target = _horizontal_distance(global_position, _cached_target_position)
	navigation_agent.target_position = _cached_target_position
	_cached_chase_direction = _safe_navigation_direction(_cached_target_position)
	# G-01：Boss 宏观决策 tick（意图写黑板；FSM 继续微执行）
	if guardian:
		_tick_macro_decision()


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
	# L-14：Boss 与可抓投人型敌均可概率进入独立抓投前摇（不走 CombatArea）
	if (
		can_grab
		and _grab_profile != null
		and _cached_distance_to_target <= (2.4 if guardian else 2.0)
		and state == State.CHASE
		and randf() < grab_chance
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
	# 剧情冻结强制回 IDLE，绕过常规转移表
	_change_state(State.IDLE, 0.0, true)
	story_resolution_entered.emit(self)


## L-01：命运抉择落定 —— 以非致死方式终结 Boss。
## 不再播放死亡处决；直接发 defeated 信号让 game_world 结算奖励 / 打开出口。
func conclude_story_fate() -> void:
	if state == State.DEAD or not _story_resolution:
		return
	_story_resolution = false
	_release_execution_claim()
	if _grab_director != null and _grab_director.active:
		_grab_director.force_cancel(&"fate")
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	_set_engaged(false)
	body_collision.set_deferred("disabled", true)
	set_physics_process(false)
	# 非致死收尾：发 defeat 信号，再淡出移除
	defeated.emit(self, reward, guardian)
	var tween := create_tween()
	tween.tween_property(body_material, "albedo_color:a", 0.0, 0.9)
	tween.tween_callback(queue_free)


func is_in_story_resolution() -> bool:
	return _story_resolution


func _select_attack_profile() -> void:
	var distance_to_target := _cached_distance_to_target
	attack_is_low_sweep = false
	_current_attack_data = null
	if enemy_type == EnemyType.EMBER_SKIRMISHER:
		# G-03：远程弹道；章节 dict 优先，否则原型 AttackData
		if not _attack_profile.is_empty():
			_resolve_attack_data_or_dict(_attack_profile, &"content_skirmisher")
		else:
			_apply_attack_data(EnemyAttackCatalog.resolve_prototype("ember_skirmisher"))
		attack_heavy = false
		attack_is_low_sweep = false
	elif enemy_type == EnemyType.ASH_STALKER:
		attack_index += 1
		_apply_attack_data(EnemyAttackCatalog.resolve_prototype("ash_stalker"))
		attack_is_low_sweep = true  # 潜行低扫，可被跳跃豁免
	elif not guardian:
		# 章节普攻 dict → AttackData；无则哨兵原型
		if not _attack_profile.is_empty():
			_resolve_attack_data_or_dict(_attack_profile, &"content_melee")
		else:
			_apply_attack_data(EnemyAttackCatalog.resolve_prototype("hollow_sentinel"))
		attack_is_low_sweep = distance_to_target <= attack_range * 0.85
	else:
		attack_index += 1
		# 优先消费章节 Boss 招式表（G-06 type 依赖 dict）
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


## G-08：写入 AttackData 并缓存引用
func _apply_attack_data(attack: AttackData) -> void:
	_current_attack_data = attack
	EnemyAttackCatalog.apply_to_enemy(self, attack)


## G-08：能建合法 AttackData 则用之，否则 dict 回退
func _resolve_attack_data_or_dict(profile: Dictionary, action_id: StringName) -> void:
	var attack := EnemyAttackCatalog.try_from_profile_dict(profile, action_id)
	if attack != null:
		_apply_attack_data(attack)
		return
	_current_attack_data = null
	EnemyTuningData.apply_attack_profile(self, profile)


func _phase_two_cut() -> float:
	return _content_phase_two_threshold if _content_phase_two_threshold >= 0.0 else PHASE_TWO_THRESHOLD


func _phase_three_cut() -> float:
	# 仅两阶段 Boss：第三段阈值压到不可达
	if not _content_phase_attacks.is_empty() and not _content_phase_attacks.has(3):
		return -1.0
	return _content_phase_three_threshold if _content_phase_three_threshold >= 0.0 else PHASE_THREE_THRESHOLD


func _current_phase() -> int:
	# G-06：支持第 4 相（烛阴结局阈值）
	if _content_phase_four_threshold >= 0.0 and get_health_ratio() <= _content_phase_four_threshold:
		return 4
	var three_cut := _phase_three_cut()
	if three_cut >= 0.0 and get_health_ratio() <= three_cut:
		return 3
	if get_health_ratio() <= _phase_two_cut():
		return 2
	return 1


func _apply_content_phase_attack() -> void:
	# 按当前阶段循环 ChapterContent 招式（保留 type 供 G-06 执行）
	var phase := _current_phase()
	var attacks: Array = _content_phase_attacks.get(phase, [])
	if attacks.is_empty():
		attacks = _content_phase_attacks.get(1, [])
	if attacks.is_empty():
		_apply_mid_range_attack()
		_active_attack_profile.clear()
		return
	var profile: Dictionary = attacks[(attack_index - 1) % attacks.size()]
	# G-06：dict 始终保留（cone_aoe / multi_hit 等 type 钩子）
	_active_attack_profile = profile.duplicate(true)
	var action_id := StringName(String(profile.get("name", "boss_phase_attack")))
	# G-08：合法招式走 AttackData；active=0 等特殊招走 dict
	_resolve_attack_data_or_dict(profile, action_id)


## G-06：确保招式执行器
func _ensure_boss_attack_executor() -> void:
	if _boss_attack_executor == null:
		_boss_attack_executor = BossAttackExecutorScript.new()


## G-06：在 ACTIVE/RECOVERY 钩子跑 type
func _run_boss_attack_hook(phase_name: String) -> void:
	if _active_attack_profile.is_empty():
		return
	if String(_active_attack_profile.get("type", "")).is_empty():
		return
	_ensure_boss_attack_executor()
	if phase_name == "active":
		_boss_attack_executor.execute_active(self, target_node, _active_attack_profile)
	elif phase_name == "recovery":
		_boss_attack_executor.execute_recovery(self, target_node, _active_attack_profile)


func _apply_close_range_attack() -> void:
	# G-08：近距表走 AttackData 目录（数值同 EnemyTuningData）
	var phase := _current_phase()
	var heavy := phase >= 2 and attack_index % 3 == 0
	_apply_attack_data(EnemyAttackCatalog.resolve_guardian(&"close", phase, heavy))


func _apply_mid_range_attack() -> void:
	var phase := _current_phase()
	var heavy := attack_index % 2 == 1
	_apply_attack_data(EnemyAttackCatalog.resolve_guardian(&"mid", phase, heavy))


func _apply_long_range_attack() -> void:
	var phase := _current_phase()
	_apply_attack_data(EnemyAttackCatalog.resolve_guardian(&"long", phase, true))


func _trigger_phase_transition() -> void:
	var new_phase := _current_phase()
	var phases_fired: Array[int] = []
	# Use `if` (not `elif`) so both phases cascade when a single hit crosses two thresholds.
	if new_phase >= 2 and not _phase_transition_played:
		_phase_transition_played = true
		_phase = 2
		phases_fired.append(2)
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
		phases_fired.append(3)
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
	# G-04：通知抛光层（镜头 / 场地 VFX / 姿态混合）
	for fired_phase in phases_fired:
		phase_changed.emit(self, fired_phase)


## I-06：FSM 转移合法性；同态允许刷新时长
func can_transition_to(from_state: State, to_state: State) -> bool:
	if from_state == to_state:
		return true
	# 死亡终态：仅 reset_enemy 直写 IDLE，禁止 _change_state 复活
	if from_state == State.DEAD:
		return false
	# 受击/处决/死亡打断：任意存活态可进
	if to_state in [
		State.STAGGER,
		State.PARRY_VULNERABLE,
		State.GUARD_BROKEN,
		State.WEAK_POINT_EXPOSED,
		State.DEAD,
	]:
		return true
	match from_state:
		State.IDLE:
			# 仇恨开战；治疗惩罚可从空闲直接前摇
			return to_state in [State.CHASE, State.WINDUP]
		State.CHASE:
			return to_state in [State.RETURN, State.WINDUP, State.GRAB_WINDUP]
		State.WINDUP:
			return to_state == State.ACTIVE
		State.ACTIVE:
			return to_state == State.RECOVERY
		State.RECOVERY:
			# 收招回追/回家；Boss 开奶惩罚可插前摇
			return to_state in [State.CHASE, State.RETURN, State.WINDUP]
		State.STAGGER, State.PARRY_VULNERABLE, State.GUARD_BROKEN:
			return to_state in [State.CHASE, State.RETURN, State.WINDUP]
		State.WEAK_POINT_EXPOSED:
			return to_state in [State.CHASE, State.RETURN]
		State.GRAB_WINDUP:
			return to_state in [State.GRAB_ACTIVE, State.GRAB_RECOVERY]
		State.GRAB_ACTIVE:
			return to_state == State.RECOVERY
		State.GRAB_RECOVERY:
			return to_state in [State.CHASE, State.RETURN]
		State.RETURN:
			# 到家回 IDLE；治疗反应可重新开战
			return to_state in [State.IDLE, State.CHASE, State.WINDUP]
		_:
			return false


## force：剧情冻结等绕过合法性（reset 仍直写 state）
func _change_state(new_state: State, duration: float = 0.0, force: bool = false) -> void:
	# 非法转移拒绝，保持原态（I-06）
	if not force and not can_transition_to(state, new_state):
		return
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
			_run_boss_attack_hook("active")
			if enemy_type == EnemyType.EMBER_SKIRMISHER:
				# G-03：释放投射物，不走近战 CombatArea
				_spawn_enemy_projectile()
			elif _heal_punish_aoe_radius > 0.0 and _active_heal_punish_variant == &"aoe_burst":
				# G-02：治疗 AoE burst 径向结算
				_apply_heal_punish_aoe()
				_play_audio("heavy", -4.0, 0.7)
			else:
				var tags: Array = ["melee", "heavy" if attack_heavy else "light"]
				if attack_is_low_sweep:
					tags.append("low_sweep")
				# L-10：敌方自带状态（bleed/foxfire/confusion/poison）随攻击标签下发
				for sid in status_inflict:
					tags.append("status:%s" % sid)
				if combat_area != null:
					combat_area.begin_swing(attack_damage, attack_stagger, {
						"action_id": "enemy_low_sweep" if attack_is_low_sweep else "enemy_swing",
						"tags": tags,
						"blockable": true,
						"parryable": true,
						"guard_damage": attack_damage + attack_stagger * 0.25,
					})
		State.RECOVERY:
			_run_boss_attack_hook("recovery")
		State.STAGGER, State.PARRY_VULNERABLE, State.GUARD_BROKEN, State.WEAK_POINT_EXPOSED:
			if combat_area != null:
				combat_area.end_swing()
		State.GRAB_WINDUP:
			# 前摇需保持捕获区开启；勿调用 _end_grab
			if combat_area != null:
				combat_area.end_swing()
			if _grab_area != null:
				_grab_area.monitoring = true
		State.GRAB_ACTIVE:
			if combat_area != null:
				combat_area.end_swing()
		State.GRAB_RECOVERY:
			if combat_area != null:
				combat_area.end_swing()
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
	# G-05：首次接敌触发伏击/特殊钩子
	if engaged and _behavior_module != null and _behavior_module.has_method("on_engage"):
		_behavior_module.on_engage(self, target_node)
	engagement_changed.emit(self, guardian, engaged)


## G-01：确保 Boss 宏决策控制器存在
func _ensure_macro_ai() -> void:
	if _macro_ai == null:
		_macro_ai = BossMacroControllerScript.new()


## G-01：同步黑板并刷新宏意图
func _tick_macro_decision() -> void:
	if not guardian:
		return
	_ensure_macro_ai()
	_macro_ai.tick_from_enemy(self)


## G-01：对外读取当前宏意图（合约 / 调试）
func get_macro_intent() -> StringName:
	if _macro_ai == null:
		return &"patrol"
	return _macro_ai.current_intent()


## G-01：宏层选中的攻击标签（如 PHASE2_MID）
func get_macro_selected_attack() -> String:
	if _macro_ai == null or _macro_ai.blackboard == null:
		return ""
	return String(_macro_ai.blackboard.selected_attack)


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
	if enemy_type == EnemyType.EMBER_SKIRMISHER:
		return "ember_skirmisher"
	return "hollow_sentinel"


func _apply_palette_colors() -> void:
	var vis := body_visual_root
	if vis != null and vis.get_node_or_null("ModelRoot") != null:
		return
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
	elif enemy_type == EnemyType.EMBER_SKIRMISHER:
		# 紫红菱影：远程伏击标识色
		body_material.albedo_color = Color(0.28, 0.12, 0.22)
		weapon_material.albedo_color = Color(0.75, 0.28, 0.48)
		eye_material.emission = Color(1.0, 0.35, 0.7)
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
	_ensure_nodes()
	if not chapter_content.is_empty():
		_apply_content_tuning()
		return
	# 无 content：走 EnemyTuningData 原型表
	var key := "hollow_sentinel"
	if guardian:
		key = "cinder_guardian"
	elif enemy_type == EnemyType.ASH_STALKER:
		key = "ash_stalker"
	elif enemy_type == EnemyType.EMBER_SKIRMISHER:
		key = "ember_skirmisher"
	var row: Dictionary = EnemyTuningData.TYPE_TUNING.get(key, EnemyTuningData.TYPE_TUNING["hollow_sentinel"])
	max_health = float(row["max_health"])
	move_speed = float(row["move_speed"])
	acceleration = float(row["acceleration"])
	aggro_range = float(row["aggro_range"])
	disengage_range = float(row["disengage_range"])
	leash_range = float(row["leash_range"])
	attack_range = float(row["attack_range"])
	reward = int(row["reward"])
	poise_limit = float(row["poise_limit"])
	stagger_duration = float(row["stagger_duration"])
	_apply_body_nav_sizes(
		float(row["body_radius"]), float(row["body_height"]), float(row["body_y"]),
		float(row["nav_radius"]), float(row["nav_height"])
	)


## 安全写入碰撞体与导航尺寸（节点未就绪时跳过）
func _apply_body_nav_sizes(radius: float, height: float, body_y: float, nav_r: float, nav_h: float) -> void:
	if body_shape != null:
		body_shape.radius = radius
		body_shape.height = height
	if body_collision != null:
		body_collision.position.y = body_y
	if navigation_agent != null:
		navigation_agent.radius = nav_r
		navigation_agent.height = nav_h


func _apply_content_tuning() -> void:
	# 从章节内容字典灌入战斗数值（经 G-05 catalog 标准化）
	var profile := EnemyAiCatalog.normalize(chapter_content)
	chapter_content = profile
	max_health = float(profile.get("max_health", 80.0))
	move_speed = float(profile.get("move_speed", 3.6))
	acceleration = 15.0
	aggro_range = float(profile.get("aggro_range", 13.0))
	disengage_range = float(profile.get("disengage_range", 20.0))
	leash_range = float(profile.get("leash_range", 17.0))
	attack_range = float(profile.get("attack_range", 2.15))
	reward = int(profile.get("reward", 35))
	poise_limit = float(profile.get("poise_limit", 24.0))
	stagger_duration = float(profile.get("stagger_duration", 0.48))
	_apply_body_nav_sizes(
		float(profile.get("body_radius", 0.45)),
		float(profile.get("body_height", 1.9)),
		float(profile.get("body_y", 0.95)),
		float(profile.get("nav_radius", 0.48)),
		float(profile.get("nav_height", 1.9))
	)
	if navigation_agent != null:
		navigation_agent.path_desired_distance = float(profile.get("path_desired_distance", 0.35))
		navigation_agent.target_desired_distance = float(profile.get("target_desired_distance", 1.5))
	# G-05：挂接 behavior 模块并应用修饰
	_behavior_id = String(profile.get("behavior", ""))
	_behavior_module = EnemyBehaviorRegistry.create_module(_behavior_id)
	if _behavior_module != null and _behavior_module.has_method("apply_profile_modifiers"):
		_behavior_module.apply_profile_modifiers(self)
	# G-08：章节 attack 块灌入 AttackData（非法则 dict 回退）
	if not _attack_profile.is_empty():
		_resolve_attack_data_or_dict(_attack_profile, StringName(content_id if not content_id.is_empty() else "content_attack"))


func _play_audio(cue: String, volume_db: float, pitch: float) -> void:
	if audio_node != null and is_instance_valid(audio_node) and audio_node.has_method("play_cue"):
		audio_node.call("play_cue", cue, volume_db, pitch)


func _ensure_nodes() -> void:
	# 已初始化但 shape 引用丢失时补绑
	if navigation_agent != null:
		if body_shape == null and body_collision != null and body_collision.shape is CapsuleShape3D:
			body_shape = body_collision.shape
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
