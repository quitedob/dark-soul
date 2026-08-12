# game/scripts/boss/boss_attack_executor.gd
extends RefCounted
## G-06：Boss content 招式 type 微执行器（禁止改 Engine.time_scale）
## L-19：全覆盖内容表 attack type（伤害类不再静默 pass）；未知 type 以 push_warning 上报。

const EnemyProjectileScene = preload("res://scenes/actors/enemy_projectile.tscn")
const BossAttackProjectile = preload("res://scripts/boss/boss_attack_projectile.gd")
const BossAttackHazard = preload("res://scripts/boss/boss_attack_hazard.gd")
const BossAttackClone = preload("res://scripts/boss/boss_attack_clone.gd")

## 合约可读状态
var last_type := ""
var teleport_hops := 0
var last_pull_applied := false
var last_dilation := 1.0
var last_rewind := false
## L-19：新增 type 的可观测状态（合约测试读取）
var last_multi_hits := 0
var last_aoe_hits := 0
var last_projectiles := 0
var last_clones := 0
var last_push_applied := false
var last_hazard := false
var last_swoop := false
var last_speed_boost := false
var last_arena_effect := ""


## ACTIVE 阶段执行（主入口）
func execute_active(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	var atype := String(attack.get("type", "")).to_lower()
	last_type = atype
	if atype.is_empty() or target == null or not is_instance_valid(target):
		return
	match atype:
		"chain_teleport":
			_chain_teleport(attacker, target, int(attack.get("chain_count", 3)))
		"teleport_after", "teleport_behind":
			_teleport_near(attacker, target, atype == "teleport_behind")
		"pull_in_aoe", "gravity_crush":
			_pull_in(attacker, target, float(attack.get("range", 6.0)))
		"freeze_then_strike":
			_local_freeze(target, 0.45)
		"status":
			_status_effect(attacker, target, String(attack.get("effect", "")))
		"random_teleport_aoe":
			_random_teleport_aoe(attacker, target, int(attack.get("hits", 3)))
		"pull_then_explode":
			_pull_in(attacker, target, float(attack.get("range", 8.0)))
		"multi_hit", "repeat_3_times":
			_multi_hit(attacker, target, attack, 3)
		"radial_aoe":
			_radial_aoe(attacker, target, attack, float(attack.get("range", 3.5)))
		"cone_aoe":
			_cone_aoe(attacker, target, attack, float(attack.get("range", 10.0)))
		"stage_wide_aoe":
			_stage_wide_aoe(attacker, target, attack)
		"targeted_impact_aoe":
			_targeted_impact_aoe(attacker, target, attack)
		"line_aoe":
			_line_aoe(attacker, target, attack, float(attack.get("length", 12.0)))
		"projectile":
			_spawn_projectile(attacker, _aim_dir(attacker, target), attack)
		"multi_projectile":
			_multi_projectile(attacker, target, attack, int(attack.get("count", 5)), false)
		"radial_projectile_burst":
			_multi_projectile(attacker, target, attack, int(attack.get("count", 8)), true)
		"line_projectile":
			_line_projectile(attacker, target, attack, float(attack.get("length", 12.0)))
		"homing_projectile":
			_homing_projectile(attacker, target, attack)
		"push_back_aoe":
			_push_back_aoe(attacker, target, attack, float(attack.get("range", 7.0)))
		"trail_hazard":
			_trail_hazard(attacker, target, attack)
		"flying_swoop":
			_flying_swoop(attacker, target, attack)
		"speed_boosted":
			_speed_boosted(attacker, target, attack)
		"summon":
			_summon_clones(attacker, target, attack)
		"arena_modify":
			_arena_modify(attacker, target, attack)
		_:
			# L-19：未知 type 上报（不再静默 pass），便于未来捕获漏网 type
			push_warning("boss_attack_executor: unhandled attack type '%s'" % atype)


## RECOVERY：teleport_after 收招闪
func execute_recovery(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	var atype := String(attack.get("type", "")).to_lower()
	if atype == "teleport_after" and target != null and is_instance_valid(target):
		_teleport_near(attacker, target, false)


## 九尾：链式瞬移
func _chain_teleport(attacker: Node3D, target: Node3D, count: int) -> void:
	teleport_hops = 0
	var hops := maxi(count, 1)
	for i in range(hops):
		_teleport_near(attacker, target, i % 2 == 0)
		teleport_hops += 1


func _teleport_near(attacker: Node3D, target: Node3D, behind: bool) -> void:
	var tpos := _pos(target)
	var forward := -target.global_transform.basis.z if target.is_inside_tree() else -target.transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var dest: Vector3
	if behind:
		dest = tpos - forward * 2.4 + side * (0.4 if teleport_hops % 2 == 0 else -0.4)
	else:
		dest = tpos + side * (2.2 if teleport_hops % 2 == 0 else -2.2) - forward * 0.8
	dest.y = _pos(attacker).y
	_set_pos(attacker, dest)
	# 朝向目标（仅入树时 look_at）
	var look := tpos - dest
	look.y = 0.0
	if look.length_squared() > 0.001 and attacker.is_inside_tree():
		attacker.look_at(attacker.global_position + look.normalized(), Vector3.UP)


## 玄霄：引力拉近
func _pull_in(attacker: Node3D, target: Node3D, radius: float) -> void:
	last_pull_applied = false
	var offset := _pos(attacker) - _pos(target)
	offset.y = 0.0
	var dist := offset.length()
	if dist > radius or dist < 0.05:
		return
	last_pull_applied = true
	var dir := offset.normalized()
	var strength := 14.0
	if target is CharacterBody3D:
		var body := target as CharacterBody3D
		body.velocity.x += dir.x * strength
		body.velocity.z += dir.z * strength
		# 短时加重重力感（局部，非 Engine.time_scale）
		if "gravity" in target:
			target.set_meta("g06_gravity_boost", 1.6)
			target.set_meta("g06_gravity_boost_ttl", 0.8)
	elif target.get("knockback_velocity") != null:
		target.set("knockback_velocity", target.get("knockback_velocity") + dir * strength)


## 烛阴：局部冻结（禁全局 time_scale）
func _local_freeze(target: Node3D, seconds: float) -> void:
	last_dilation = 0.15
	_assert_global_time_untouched()
	target.set_meta("g06_time_dilation", 0.15)
	target.set_meta("g06_time_dilation_ttl", seconds)
	if target is CharacterBody3D:
		(target as CharacterBody3D).velocity = Vector3.ZERO
	if target.has_method("set_visual_frozen"):
		target.set_visual_frozen(true)


func _status_effect(attacker: Node3D, target: Node3D, effect: String) -> void:
	match effect:
		"rewind_player_position":
			last_rewind = true
			_assert_global_time_untouched()
			if target.has_method("recover_to_last_safe"):
				target.recover_to_last_safe(false)
			elif "last_safe_transform" in target:
				var tf: Transform3D = target.get("last_safe_transform")
				_set_pos(target, tf.origin)
		"confusion", "darkness_blind", "global_slow", "slow":
			# 局部减速伪装「慢动作场」（arena_modify 亦复用此路径）
			last_dilation = 0.45
			_assert_global_time_untouched()
			target.set_meta("g06_time_dilation", 0.45)
			target.set_meta("g06_time_dilation_ttl", 1.2)
		_:
			pass
	# 攻击者侧记录
	attacker.set_meta("g06_last_status", effect)


func _random_teleport_aoe(attacker: Node3D, target: Node3D, hits: int) -> void:
	teleport_hops = 0
	for i in range(maxi(hits, 1)):
		_teleport_near(attacker, target, i % 2 == 1)
		teleport_hops += 1


func _assert_global_time_untouched() -> void:
	# 硬约束：任何时间效果不得改全局 time_scale
	assert(is_equal_approx(Engine.time_scale, 1.0), "G-06 must not change Engine.time_scale")


## ============ L-19：伤害 / AoE / 投射物 / 危害 / 冲锋 / 增益 / 召唤 ============


## multi_hit / repeat_3_times：对主目标按 base damage 多段命中（ACTIVE 窗内）
func _multi_hit(attacker: Node3D, target: Node3D, attack: Dictionary, default_hits: int) -> void:
	var hits := maxi(int(attack.get("hits", default_hits)), 1)
	var dmg := _damage(attacker, attack)
	var stg := _stagger(attacker, attack)
	last_multi_hits = 0
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var dir := _pos(target) - _pos(attacker)
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = _forward(attacker)
	else:
		dir = dir.normalized()
	for i in range(hits):
		if target == null or not is_instance_valid(target):
			break
		_call_receive_hit(target, dmg, stg, dir, attacker)
		last_multi_hits += 1


## radial_aoe：以攻击者为圆心径向命中范围内候选
func _radial_aoe(attacker: Node3D, target: Node3D, attack: Dictionary, radius: float) -> void:
	last_aoe_hits = _aoe_damage(attacker, _pos(attacker), radius, attack, false, 0.0, target)


## cone_aoe：以攻击者前向做点积过滤的扇形
func _cone_aoe(attacker: Node3D, target: Node3D, attack: Dictionary, radius: float) -> void:
	var half := float(attack.get("angle", 120.0)) * 0.5
	last_aoe_hits = _aoe_damage(attacker, _pos(attacker), radius, attack, true, half, target)


## stage_wide_aoe：超大半径径向
func _stage_wide_aoe(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	var r := float(attack.get("range", 30.0))
	last_aoe_hits = _aoe_damage(attacker, _pos(attacker), r, attack, false, 0.0, target)


## targeted_impact_aoe：以目标（落点）为中心径向
func _targeted_impact_aoe(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	var r := float(attack.get("range", 4.5))
	var center := _pos(target) if target != null and is_instance_valid(target) else _pos(attacker)
	last_aoe_hits = _aoe_damage(attacker, center, r, attack, false, 0.0, target)


## line_aoe：攻击者前向长度×宽度矩形带
func _line_aoe(attacker: Node3D, target: Node3D, attack: Dictionary, length: float) -> void:
	var len := maxf(float(attack.get("length", length)), 1.0)
	var width := float(attack.get("width", 2.0))
	var center := _pos(attacker)
	var forward := _forward(attacker)
	var dmg := _damage(attacker, attack)
	var stg := _stagger(attacker, attack)
	var hits := 0
	for candidate in _candidates(attacker, target):
		if candidate == null or not (candidate is Node3D):
			continue
		var node := candidate as Node3D
		var rel := _pos(node) - center
		rel.y = 0.0
		var along := rel.dot(forward)
		if along < 0.0 or along > len:
			continue
		if (rel - forward * along).length() > width:
			continue
		_call_receive_hit(node, dmg, stg, forward, attacker)
		hits += 1
	last_aoe_hits = hits


## 通用径向/锥形 AoE：对范围内候选施加 base damage（主目标亦计入候选）
func _aoe_damage(attacker: Node3D, center: Vector3, radius: float, attack: Dictionary, cone: bool, cone_half_deg: float, primary: Node3D = null) -> int:
	var dmg := _damage(attacker, attack)
	var stg := _stagger(attacker, attack)
	var hits := 0
	for candidate in _candidates(attacker, primary):
		if candidate == null or not (candidate is Node3D):
			continue
		var node := candidate as Node3D
		if _horizontal_dist(center, _pos(node)) > radius:
			continue
		if cone and not _in_cone(attacker, node, cone_half_deg):
			continue
		var dir := _pos(node) - center
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			dir = _forward(attacker)
		else:
			dir = dir.normalized()
		_call_receive_hit(node, dmg, stg, dir, attacker)
		hits += 1
	return hits


## 候选列表：world_node.get_target_candidates() + 主目标（去重、排除攻击者自身）
func _candidates(attacker: Node3D, primary: Node3D) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var world := _world_node(attacker)
	if world != null and world.has_method("get_target_candidates"):
		for c in world.get_target_candidates():
			if c == null or not (c is Node3D) or c == attacker or seen.has(c):
				continue
			seen[c] = true
			out.append(c)
	if primary != null and is_instance_valid(primary) and primary != attacker and not seen.has(primary):
		seen[primary] = true
		out.append(primary)
	return out


func _in_cone(attacker: Node3D, node: Node3D, half_angle_deg: float) -> bool:
	var forward := _forward(attacker)
	var to := _pos(node) - _pos(attacker)
	to.y = 0.0
	if to.length_squared() < 0.001:
		return true
	to = to.normalized()
	return forward.dot(to) >= cos(deg_to_rad(half_angle_deg))


## projectile / line_projectile：复用项目 enemy_projectile.tscn 生成投射物
func _spawn_projectile(attacker: Node3D, direction: Vector3, attack: Dictionary, extra: Dictionary = {}) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	var dir := direction
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	var projectile = EnemyProjectileScene.instantiate()
	var parent := _projectile_parent(attacker)
	if parent == null:
		return
	parent.add_child(projectile)
	projectile.global_position = _pos(attacker) + Vector3(0.0, 1.15, 0.0) + dir * 0.6
	projectile.setup(attacker, dir, _damage(attacker, attack), _stagger(attacker, attack), {
		"proj_speed": float(extra.get("proj_speed", 11.5)),
		"proj_lifetime": float(extra.get("proj_lifetime", 2.6)),
		"action_id": String(attack.get("name", "boss_projectile")),
		"tags": ["projectile", "enemy", "boss"],
		"blockable": true,
		"parryable": false,
		"guard_damage": _damage(attacker, attack) + _stagger(attacker, attack) * 0.2,
	})
	last_projectiles += 1


## multi_projectile / radial_projectile_burst：扇形（count<12）或 360° 环形（count>=12 / burst）
func _multi_projectile(attacker: Node3D, target: Node3D, attack: Dictionary, count: int, ring: bool) -> void:
	last_projectiles = 0
	var n := maxi(count, 1)
	if ring or n >= 12:
		for i in range(n):
			var ang := TAU * float(i) / float(n)
			_spawn_projectile(attacker, Vector3(cos(ang), 0.0, sin(ang)), attack)
	else:
		var base_dir := _aim_dir(attacker, target)
		var base_ang := atan2(base_dir.x, base_dir.z)
		var spread := deg_to_rad(70.0)
		for i in range(n):
			var t := (float(i) - float(n - 1) * 0.5) / float(maxi(n - 1, 1))
			var ang := base_ang + t * spread
			_spawn_projectile(attacker, Vector3(sin(ang), 0.0, cos(ang)), attack)


## line_projectile：沿前向发射一道远射程弹丸
func _line_projectile(attacker: Node3D, target: Node3D, attack: Dictionary, length: float) -> void:
	last_projectiles = 0
	var len := maxf(float(attack.get("length", length)), 3.0)
	var speed := float(attack.get("proj_speed", 16.0))
	var lifetime := maxf(len / maxf(speed, 0.1), 0.3)
	_spawn_projectile(attacker, _aim_dir(attacker, target), attack, {
		"proj_speed": speed,
		"proj_lifetime": lifetime,
	})


## homing_projectile：生成导向投射物
func _homing_projectile(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	var parent := _projectile_parent(attacker)
	if parent == null:
		return
	var proj = BossAttackProjectile.new()
	parent.add_child(proj)
	proj.global_position = _pos(attacker) + Vector3(0.0, 1.15, 0.0)
	proj.setup(attacker, _aim_dir(attacker, target), _damage(attacker, attack), _stagger(attacker, attack), {
		"proj_speed": float(attack.get("proj_speed", 9.0)),
		"proj_lifetime": float(attack.get("proj_lifetime", 3.0)),
		"homing_target": target,
		"homing_strength": float(attack.get("homing_strength", 3.0)),
		"action_id": String(attack.get("name", "boss_homing_projectile")),
	})
	last_projectiles += 1


## push_back_aoe：把范围内目标推出
func _push_back_aoe(attacker: Node3D, target: Node3D, attack: Dictionary, radius: float) -> void:
	last_push_applied = false
	var r := float(attack.get("range", radius))
	var strength := float(attack.get("push_strength", 16.0))
	var center := _pos(attacker)
	var applied := 0
	for candidate in _candidates(attacker, target):
		if candidate == null or not (candidate is Node3D):
			continue
		var node := candidate as Node3D
		var off := _pos(node) - center
		off.y = 0.0
		var dist := off.length()
		if dist > r or dist < 0.05:
			continue
		var dir := off.normalized()
		if node is CharacterBody3D:
			var body := node as CharacterBody3D
			body.velocity.x += dir.x * strength
			body.velocity.z += dir.z * strength
		elif node.get("knockback_velocity") != null:
			node.set("knockback_velocity", node.get("knockback_velocity") + dir * strength)
		applied += 1
	last_push_applied = applied > 0


## trail_hazard：在攻击点留下持续危害
func _trail_hazard(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	last_hazard = false
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	var parent := _projectile_parent(attacker)
	if parent == null:
		return
	var hazard = BossAttackHazard.new()
	parent.add_child(hazard)
	hazard.global_position = _pos(attacker)
	hazard.setup(attacker, _damage(attacker, attack), _stagger(attacker, attack), {
		"radius": float(attack.get("radius", 1.6)),
		"lifetime": float(attack.get("hazard_lifetime", 3.0)),
		"action_id": String(attack.get("name", "boss_trail_hazard")),
	})
	last_hazard = true


## flying_swoop：复用位移语义做冲锋（朝目标冲）
func _flying_swoop(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	last_swoop = false
	if attacker == null or not is_instance_valid(attacker):
		return
	var charge := float(attack.get("lunge", 6.0))
	if charge <= 0.0:
		charge = 6.0
	var dir := _aim_dir(attacker, target)
	if attacker is CharacterBody3D:
		var body := attacker as CharacterBody3D
		body.velocity.x = dir.x * charge
		body.velocity.z = dir.z * charge
	else:
		_set_pos(attacker, _pos(attacker) + dir * charge * 0.3)
	last_swoop = true


## speed_boosted：局部提升攻击者移速/攻速（meta 本地，禁全局）
func _speed_boosted(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	last_speed_boost = false
	if attacker == null or not is_instance_valid(attacker):
		return
	var duration := float(attack.get("duration", 2.5))
	if attacker.has_method("set_meta"):
		attacker.set_meta("g06_speed_boost", true)
	_apply_local_speed_boost(attacker, duration)
	last_speed_boost = true


func _apply_local_speed_boost(attacker: Node3D, duration: float) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	var speed_raw: Variant = attacker.get("move_speed")
	var active_raw: Variant = attacker.get("attack_active")
	var has_speed := speed_raw is float or speed_raw is int
	var has_active := active_raw is float or active_raw is int
	if not has_speed and not has_active:
		return
	var base_speed := float(speed_raw) if has_speed else 0.0
	var base_active := float(active_raw) if has_active else 0.0
	var generation := int(attacker.get_meta("g06_speed_gen", 0)) + 1
	attacker.set_meta("g06_speed_gen", generation)
	if has_speed:
		attacker.set("move_speed", base_speed * 1.4)
	if has_active:
		attacker.set("attack_active", base_active * 0.7)
	var timer := attacker.get_tree().create_timer(duration)
	var restore := func() -> void:
		if not is_instance_valid(attacker):
			return
		if int(attacker.get_meta("g06_speed_gen", 0)) != generation:
			return
		if has_speed:
			attacker.set("move_speed", base_speed)
		if has_active:
			attacker.set("attack_active", base_active)
	timer.timeout.connect(restore, CONNECT_ONE_SHOT)


## summon：生成分身（项目无敌方 clone 基础设施，用最小诱饵节点）
func _summon_clones(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	last_clones = 0
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	var parent := _projectile_parent(attacker)
	if parent == null:
		return
	var count := maxi(int(attack.get("clone_count", 2)), 1)
	var center := _pos(attacker)
	if target != null and is_instance_valid(target):
		center = _pos(target)
	var lifetime := float(attack.get("clone_lifetime", 8.0))
	var health := float(attack.get("clone_health", 40.0))
	for i in range(count):
		var clone = BossAttackClone.new()
		parent.add_child(clone)
		var ang := TAU * float(i) / float(count) + 0.3
		clone.global_position = center + Vector3(cos(ang) * 2.2, 0.0, sin(ang) * 2.2)
		clone.setup({"lifetime": lifetime, "health": health})
		last_clones += 1


## arena_modify：global_slow / darkness_blind / confusion —— 复用 _status_effect 的 meta 减速模式
func _arena_modify(attacker: Node3D, target: Node3D, attack: Dictionary) -> void:
	var effect := String(attack.get("effect", ""))
	last_arena_effect = effect
	_status_effect(attacker, target, effect)


## 伤害 / 硬直读取（attack dict 优先，回退敌人字段）
func _damage(attacker: Node3D, attack: Dictionary) -> float:
	var raw: Variant = attack.get("damage")
	if raw is float or raw is int:
		return maxf(float(raw), 0.0)
	if attacker != null:
		var fallback: Variant = attacker.get("attack_damage")
		if fallback is float or fallback is int:
			return maxf(float(fallback), 0.0)
	return 0.0


func _stagger(attacker: Node3D, attack: Dictionary) -> float:
	var raw: Variant = attack.get("stagger")
	if raw is float or raw is int:
		return maxf(float(raw), 0.0)
	if attacker != null:
		var fallback: Variant = attacker.get("attack_stagger")
		if fallback is float or fallback is int:
			return maxf(float(fallback), 0.0)
	return 0.0


## 走项目受击契约（receive_hit_payload 优先）
func _call_receive_hit(target: Node, dmg: float, stg: float, dir: Vector3, source: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	if target.has_method("receive_hit_payload"):
		target.receive_hit_payload({
			"damage": dmg,
			"stagger": stg,
			"poise": stg,
			"direction": dir,
			"source": source,
			"guard_damage": dmg + stg * 0.25,
			"action_id": "boss_type_effect",
			"tags": ["enemy", "boss"],
			"blockable": true,
			"parryable": true,
		})
	elif target.has_method("receive_hit"):
		target.receive_hit(dmg, stg, dir, source)


func _world_node(attacker: Node3D) -> Node:
	if attacker == null:
		return null
	var world: Variant = attacker.get("world_node")
	if world is Node:
		return world
	if attacker.has_meta("g06_world"):
		var meta: Variant = attacker.get_meta("g06_world")
		return meta if meta is Node else null
	return null


func _projectile_parent(attacker: Node3D) -> Node:
	var world := _world_node(attacker)
	if world != null:
		return world
	if attacker.get_tree() != null and attacker.get_tree().current_scene != null:
		return attacker.get_tree().current_scene
	return attacker


func _aim_dir(attacker: Node3D, target: Node3D) -> Vector3:
	var d: Vector3
	if target != null and is_instance_valid(target):
		d = _pos(target) - _pos(attacker)
	else:
		d = _forward(attacker)
	d.y = 0.0
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	else:
		d = d.normalized()
	return d


func _forward(attacker: Node3D) -> Vector3:
	var f := -attacker.global_transform.basis.z if attacker.is_inside_tree() else -attacker.transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.001:
		f = Vector3.FORWARD
	return f.normalized()


func _horizontal_dist(a: Vector3, b: Vector3) -> float:
	var difference := b - a
	difference.y = 0.0
	return difference.length()


func _pos(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position


func _set_pos(node: Node3D, pos: Vector3) -> void:
	if node.is_inside_tree():
		node.global_position = pos
	else:
		node.position = pos


## 静态：解析 type 是否为 G-06 签名能力
static func is_signature_type(atype: String) -> bool:
	match atype.to_lower():
		"chain_teleport", "teleport_after", "teleport_behind", \
		"pull_in_aoe", "gravity_crush", \
		"freeze_then_strike", "random_teleport_aoe":
			return true
		_:
			return String(atype).contains("chrono") or String(atype) == "status"
