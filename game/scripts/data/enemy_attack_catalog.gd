# game/scripts/data/enemy_attack_catalog.gd
class_name EnemyAttackCatalog
extends RefCounted
## G-08：从 EnemyTuningData 程序化构建 AttackData；磁盘 .tres 优先

const EnemyTuningData = preload("res://scripts/data/enemy_tuning.gd")

## action_id → AttackData 缓存，避免每帧 new
static var _cache: Dictionary = {}

## 原型敌人磁盘 AttackData（有则覆盖 dict 构建）
const DISK_ATTACK_PATHS := {
	"hollow_sentinel": "res://resources/enemies/hollow_sentinel/basic_strike.tres",
}


## 测试用：清空缓存
static func clear_cache() -> void:
	_cache.clear()


## 原型基础招：哨兵 / 潜行者 / 散兵
static func resolve_prototype(enemy_key: String) -> AttackData:
	# 磁盘 .tres 优先（作者化调参）
	var disk := _try_load_disk(enemy_key)
	if disk != null:
		return disk
	match enemy_key:
		"ash_stalker":
			return _cached(&"enemy_ash_stalker", EnemyTuningData.STALKER_ATTACK)
		"ember_skirmisher":
			return _cached(&"enemy_ember_skirmisher", EnemyTuningData.SKIRMISHER_ATTACK)
		_:
			return _cached(&"enemy_hollow_sentinel", EnemyTuningData.SENTINEL_ATTACK)


## 尝试从 resources/enemies 加载 AttackData
static func _try_load_disk(enemy_key: String) -> AttackData:
	var path := String(DISK_ATTACK_PATHS.get(enemy_key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded := load(path)
	if loaded is AttackData:
		return loaded as AttackData
	return null


## 守护者：距离桶 + 阶段 + 轻重
static func resolve_guardian(range_bucket: StringName, phase: int, heavy: bool) -> AttackData:
	var table: Dictionary = {}
	var id_prefix := ""
	match String(range_bucket):
		"close":
			table = EnemyTuningData.GUARDIAN_CLOSE_HEAVY if heavy else EnemyTuningData.GUARDIAN_CLOSE
			id_prefix = "guardian_close_heavy" if heavy else "guardian_close"
		"mid":
			table = EnemyTuningData.GUARDIAN_MID_HEAVY if heavy else EnemyTuningData.GUARDIAN_MID_LIGHT
			id_prefix = "guardian_mid_heavy" if heavy else "guardian_mid_light"
		"long":
			table = EnemyTuningData.GUARDIAN_LONG
			id_prefix = "guardian_long"
		_:
			table = EnemyTuningData.GUARDIAN_MID_LIGHT
			id_prefix = "guardian_mid_light"
	var clamped_phase := clampi(phase, 1, 3)
	# 近距重击表无 phase1：回退到同阶段轻击
	if not table.has(clamped_phase):
		table = EnemyTuningData.GUARDIAN_CLOSE
		id_prefix = "guardian_close"
	var profile: Dictionary = table.get(clamped_phase, table.get(1, {}))
	var action_id := StringName("%s_p%d" % [id_prefix, clamped_phase])
	return _cached(action_id, profile)


## 章节 dict → AttackData；非法时间轴返回 null（调用方走 dict 回退）
static func try_from_profile_dict(profile: Dictionary, action_id: StringName = &"") -> AttackData:
	if profile.is_empty():
		return null
	var id := action_id
	if id.is_empty():
		var name := String(profile.get("name", profile.get("id", "content_attack")))
		id = StringName(name if not name.is_empty() else "content_attack")
	var attack := build_from_dict(id, profile)
	# active<=0 等特殊 Boss 招式无法通过 schema → 回退 dict
	if not attack.validate().is_empty():
		return null
	return attack


## 无校验构建（供缓存与调参探查）
static func build_from_dict(action_id: StringName, profile: Dictionary) -> AttackData:
	var attack := AttackData.new()
	attack.action_id = action_id
	attack.display_name_key = action_id
	attack.animation_name = action_id
	attack.windup_seconds = float(profile.get("windup", 0.30))
	attack.active_seconds = float(profile.get("active", 0.15))
	attack.recovery_seconds = float(profile.get("recovery", 0.35))
	attack.damage = float(profile.get("damage", 20.0))
	# 敌人 stagger 映射为 poise_damage
	attack.poise_damage = float(profile.get("stagger", 16.0))
	attack.guard_power = attack.damage + attack.poise_damage * 0.35
	# 与玩家工厂一致：lunge 写入 authored_displacement.z
	var lunge := float(profile.get("lunge", 0.0))
	attack.authored_displacement = Vector3(0.0, 0.0, lunge)
	attack.stamina_cost = 0.0
	attack.focus_cost = 0.0
	var heavy := bool(profile.get("heavy", false))
	attack.tags = [&"enemy", &"heavy" if heavy else &"light"]
	# E-02：相位 WAM（重击有霸体乘数）
	attack.poise_modifier_active = 0.85 if heavy else 0.0
	attack.poise_modifier_windup = 0.35 if heavy else 0.0
	attack.poise_modifier_recovery = 0.0
	attack.blockable = true
	attack.parryable = true
	attack.hitbox_radius = 1.35
	attack.hitbox_height = 1.55
	attack.hitbox_offset = Vector3(0.0, 1.0, -0.9)
	attack.maximum_hits_per_target = 1
	return attack


## 把 AttackData 写回敌人运行时字段（保持 FSM 字段契约）
static func apply_to_enemy(enemy: Node, attack: AttackData) -> void:
	if enemy == null or attack == null:
		return
	enemy.set("attack_windup", attack.windup_seconds)
	enemy.set("attack_active", attack.active_seconds)
	enemy.set("attack_recovery", attack.recovery_seconds)
	enemy.set("attack_damage", attack.damage)
	enemy.set("attack_stagger", attack.poise_damage)
	enemy.set("attack_lunge", absf(attack.authored_displacement.z))
	enemy.set("attack_heavy", &"heavy" in attack.tags)


## 兼容旧 dict 写入；优先转 AttackData
static func apply_profile_dict(enemy: Node, profile: Dictionary, action_id: StringName = &"") -> void:
	var attack := try_from_profile_dict(profile, action_id)
	if attack != null:
		apply_to_enemy(enemy, attack)
		return
	# dict 回退：特殊 type / active=0 等
	EnemyTuningData.apply_attack_profile(enemy, profile)


## 全部原型 + 守护者表 AttackData（供 schema 合约）
static func all_built_attacks() -> Array[AttackData]:
	var out: Array[AttackData] = []
	out.append(resolve_prototype("hollow_sentinel"))
	out.append(resolve_prototype("ash_stalker"))
	out.append(resolve_prototype("ember_skirmisher"))
	for phase in [1, 2, 3]:
		out.append(resolve_guardian(&"close", phase, false))
		out.append(resolve_guardian(&"mid", phase, false))
		out.append(resolve_guardian(&"mid", phase, true))
		out.append(resolve_guardian(&"long", phase, true))
	# phase2/3 近距重击
	out.append(resolve_guardian(&"close", 2, true))
	out.append(resolve_guardian(&"close", 3, true))
	return out


static func _cached(action_id: StringName, profile: Dictionary) -> AttackData:
	if _cache.has(action_id):
		return _cache[action_id] as AttackData
	var attack := build_from_dict(action_id, profile)
	_cache[action_id] = attack
	return attack
