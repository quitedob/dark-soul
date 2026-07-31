# game/scripts/boss/boss_attack_executor.gd
extends RefCounted
## G-06：Boss content 招式 type 微执行器（禁止改 Engine.time_scale）

## 合约可读状态
var last_type := ""
var teleport_hops := 0
var last_pull_applied := false
var last_dilation := 1.0
var last_rewind := false


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
		_:
			# 未实现 type：保留 timing 近战，不报错
			pass


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
		"confusion", "darkness_blind", "global_slow":
			# 局部减速伪装「慢动作场」
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
