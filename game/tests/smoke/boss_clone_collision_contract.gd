extends SceneTree
## A2a 合约（Finding 5 runtime verification）：Boss 诱饵分身（BossAttackClone）在真实物理帧中
## 必须可被玩家近战命中盒与法术投射物实际命中 —— 不再只靠碰撞层数学的静态断言。
##
## (a) 近战：minimal player（CharacterBody3D + group "player"）+ CombatArea3D（configure 1.0），
##     player 与 clone 相距 ~1.2m 面对面；begin_swing 后推进真实物理帧，
##     断言 clone.health 下降 且 hit_landed 触发。
## (b) 投射物：真实 res://scenes/components/spell_projectile.tscn 瞄准 clone 飞行，
##     推进物理帧直到命中，断言 clone.health 下降。
## (c) 负控制：无碰撞体的纯 Node3D（带 receive_hit 方法）即使与命中盒重叠也不应被命中，
##     证明命中依赖真实碰撞形状而非方法存在。

const BossAttackClone = preload("res://scripts/boss/boss_attack_clone.gd")
const CombatAreaScript = preload("res://scripts/combat_area.gd")
const SpellProjectileScene = preload("res://scenes/components/spell_projectile.tscn")

const SUCCESS_MARKER := "ASHEN_CLONE_COLLISION_CONTRACTS_OK"

const CLONE_MAX_HEALTH := 40.0
## 近战：player 与分身水平距离（分身体胶囊中心在 global+UP）
const MELEE_DISTANCE := 1.2
## 投射物：源与分身水平距离
const PROJECTILE_DISTANCE := 4.0
## 投射物速度：取法术投射物默认速度 15（spell_projectile.gd speed 默认值）。
## 旧盲区（Finding 5 实况）：cast_motion 命中点恰在相切边界、intersect_shape 严格重叠
## 判定为空、回退射线只覆盖单帧位移，低速会对小型目标整颗穿透。修复后 _sweep_motion
## 对重叠查询施加小量前推 nudge 进入严格重叠，默认速度下即可可靠命中 0.4 胶囊。
const PROJECTILE_SPEED := 15.0
const MAX_PHYSICS_FRAMES := 150

var _failures: Array[String] = []


class NonColliderTarget:
	extends Node3D
	## 负控制桩：带受击方法但无碰撞体 —— 真实命中必须跳过它
	var hits := 0

	func receive_hit(_damage, _stagger, _hit_direction, _source) -> void:
		hits += 1

	func receive_hit_payload(_payload: Dictionary) -> void:
		hits += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# 先让物理服务器稳定启动（_initialize 阶段形状尚未注册）
	await _physics_frames(2)
	await _test_melee_hitbox_hits_clone()
	await _test_projectile_hits_clone()
	await _test_negative_control_non_collider_not_hit()

	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_melee_hitbox_hits_clone() -> void:
	# minimal player body（真实 hitbox configure 依赖 group "player"）
	var player := CharacterBody3D.new()
	player.name = "PlayerBody"
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector3.ZERO

	var area := CombatAreaScript.new()
	area.name = "MeleeCombatArea"
	player.add_child(area)
	area.configure(player, 1.0)  # 胶囊落在 player 前方 (0,1,-1)，朝 -Z 面对分身

	var clone := BossAttackClone.new()
	clone.name = "MeleeClone"
	root.add_child(clone)
	clone.global_position = Vector3(0.0, 0.0, -MELEE_DISTANCE)
	clone.setup({"lifetime": 8.0, "health": CLONE_MAX_HEALTH})

	# 静态前置：命中盒 mask=4 且 clone 挂 Enemies 逻辑层 3（raw 4）——运行时证明的前提
	_expect(area.collision_mask & 4 != 0, "(a) Player hitbox mask must include Enemies raw 4.")
	_expect(clone.collision_layer & 4 != 0, "(a) Clone must sit on Enemies logical layer 3 (raw 4).")

	# 注册 shape / 让 area 见到重叠体
	await _physics_frames(2)

	var hit_landed_count := [0]
	area.hit_landed.connect(func(_target: Node3D, _is_heavy: bool) -> void:
		hit_landed_count[0] += 1
	)

	var health_before: float = clone.health
	area.begin_swing(15.0, 8.0, {"action_id": "a2a_melee_swing"})
	await _physics_frames(6)

	_expect(
		clone.health < health_before,
		"(a) Melee hitbox must reduce clone health (%.1f -> %.1f)." % [health_before, clone.health]
	)
	_expect(
		hit_landed_count[0] >= 1,
		"(a) Melee hitbox must emit hit_landed on the clone, got %d." % hit_landed_count[0]
	)

	area.end_swing()
	clone.queue_free()
	player.free()


func _test_projectile_hits_clone() -> void:
	# 真实法术投射物（res://scenes/components/spell_projectile.tscn）正对分身碰撞中心飞行。
	# 默认速度 15。旧盲区（Finding 5）已修复：_sweep_motion 在 cast_motion 相切命中点对
	# 重叠查询加前推 nudge 进入严格重叠，intersect_shape 现在能取回第一个接触的碰撞体，
	# 默认速度下对 0.4 胶囊分身即可可靠命中（见 _sweep_motion 内注释）。
	var source := Node3D.new()
	source.name = "ProjectileSource"
	root.add_child(source)
	source.global_position = Vector3.ZERO

	var clone := BossAttackClone.new()
	clone.name = "ProjectileClone"
	root.add_child(clone)
	clone.global_position = Vector3(PROJECTILE_DISTANCE, 0.0, 0.0)
	clone.setup({"lifetime": 8.0, "health": CLONE_MAX_HEALTH})
	await _physics_frames(2)

	# 瞄准分身体胶囊中心（collision shape local (0,1,0)），正对穿透
	var aim: Vector3 = clone.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (aim - source.global_position).normalized()

	var projectile = SpellProjectileScene.instantiate()
	# setup 必须在 add_child（触发 _ready）之前，_ready 才能读到 veil_bolt 碰撞半径
	projectile.setup(source, dir, 24.0, 14.0, {
		"spell_type": "veil_bolt",
		"hand": "right",
		"item_id": "five_elements_seal",
		"action_id": "a2a_projectile",
		"proj_speed": PROJECTILE_SPEED,
		"proj_lifetime": 3.0,
	})
	root.add_child(projectile)
	projectile.global_position = source.global_position

	var health_before: float = clone.health
	var hit := false
	for i in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		if not is_instance_valid(clone):
			hit = true  # 分身被伤害至 0 已自毁 —— 同样是命中证据
			break
		if clone.health < health_before:
			hit = true
			break

	var health_now: float = clone.health if is_instance_valid(clone) else -1.0
	_expect(
		hit,
		"(b) Spell projectile must reach and damage the clone within %d physics frames (%.1f -> %.1f)." \
			% [MAX_PHYSICS_FRAMES, health_before, health_now]
	)

	if is_instance_valid(projectile):
		projectile.queue_free()
	if is_instance_valid(clone):
		clone.queue_free()
	source.free()


func _test_negative_control_non_collider_not_hit() -> void:
	var player := CharacterBody3D.new()
	player.name = "NegPlayerBody"
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector3.ZERO

	var area := CombatAreaScript.new()
	area.name = "NegCombatArea"
	player.add_child(area)
	area.configure(player, 1.0)

	# 无碰撞体的普通节点（带 receive_hit 方法），重叠于命中盒所在位置
	var decoy := NonColliderTarget.new()
	decoy.name = "NegNonCollider"
	root.add_child(decoy)
	decoy.global_position = Vector3(0.0, 0.0, -MELEE_DISTANCE)
	await _physics_frames(2)

	area.begin_swing(15.0, 8.0, {"action_id": "a2a_negative"})
	await _physics_frames(6)

	_expect(
		decoy.hits == 0,
		"(c) Negative control: non-collider Node3D must NOT be hit by the melee hitbox, got %d hits." % decoy.hits
	)

	area.end_swing()
	decoy.free()
	player.free()


func _physics_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
