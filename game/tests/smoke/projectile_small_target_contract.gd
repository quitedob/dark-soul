extends SceneTree
## W-7 合约（投射物扫掠小型目标盲区修复）：真实法术投射物在默认速度(15)下正对
## 小型目标（StaticBody3D + 0.4 半径胶囊）飞行必须命中；负控制：命中错误碰撞层
## （不在 QUERY_MASK 1|4 内）的目标必须穿透而过、绝不被命中。
##
## (a) 正例：spell_projectile（spell_type veil_bolt，proj_speed 15 默认值）从原点
##     正对 3m 外 0.4 半径胶囊目标（挂 Enemies raw 4 层）飞行，推进真实物理帧，
##     断言目标 health 下降且 receive_hit / receive_hit_payload 被调用。
## (b) 负控制：同一投射物正对错误层目标（raw 2，不在 1|4 内）飞行，投射物应穿过
##     目标并按 lifetime 消亡，目标 hits 保持 0、health 不变。

const SpellProjectileScene = preload("res://scenes/components/spell_projectile.tscn")

const SUCCESS_MARKER := "ASHEN_PROJECTILE_SMALL_TARGET_CONTRACTS_OK"

## 默认投射物速度：spell_projectile.gd speed 默认 15.0（setup proj_speed 默认 15.0）
const PROJECTILE_SPEED := 15.0
## 正对命中：源与目标水平距离（~3-4m 区间内）
const HIT_DISTANCE := 3.0
## 负控制寿命：让穿过目标的投射物在有限帧内自然消亡
const NEG_LIFETIME := 1.0
const MAX_PHYSICS_FRAMES := 150
const TARGET_MAX_HEALTH := 30.0
## QUERY_MASK = WORLD_LAYER(1) | ENEMY_LAYER(4)
const PROJECTILE_MASK := 1 | 4

var _failures: Array[String] = []


class SmallTarget:
	extends StaticBody3D
	## 小型受击桩：0.4 半径胶囊，行为与 BossAttackClone 一致的受击契约
	var health := 0.0
	var hits := 0

	func configure(use_queried_layer: bool) -> void:
		health = TARGET_MAX_HEALTH
		collision_layer = 0
		collision_mask = 0
		if use_queried_layer:
			# Enemies 逻辑层 3（raw 4）—— 在 QUERY_MASK(1|4) 内，应被命中
			set_collision_layer_value(3, true)
		else:
			# 错误层：Player projectiles 逻辑层 2（raw 2）—— 不在 1|4 内
			set_collision_layer_value(2, true)
		var collision := CollisionShape3D.new()
		collision.name = "TargetHitbox"
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.6
		collision.shape = capsule
		collision.position = Vector3(0.0, 1.0, 0.0)
		add_child(collision)

	func receive_hit(damage, stagger, hit_direction, source) -> void:
		hits += 1
		health = maxf(health - float(damage), 0.0)

	func receive_hit_payload(payload: Dictionary) -> void:
		receive_hit(
			float(payload.get("damage", 0.0)),
			float(payload.get("stagger", 0.0)),
			payload.get("direction", Vector3.ZERO),
			payload.get("source")
		)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# 先让物理服务器稳定启动（_initialize 阶段形状尚未注册）
	await _physics_frames(2)
	await _test_default_speed_head_on_hits_small_target()
	await _test_wrong_layer_target_not_hit()

	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_default_speed_head_on_hits_small_target() -> void:
	# 默认速度 15 正对 3m 外 0.4 胶囊目标 —— 旧 _sweep_motion 在此速度整颗穿透。
	var source := Node3D.new()
	source.name = "SmallTargetSource"
	root.add_child(source)
	source.global_position = Vector3.ZERO

	var target := SmallTarget.new()
	target.name = "SmallTarget"
	root.add_child(target)
	target.configure(true)
	target.global_position = Vector3(HIT_DISTANCE, 0.0, 0.0)
	await _physics_frames(2)

	# 静态前置：目标须挂在 QUERY_MASK 内，且脚本默认速度为 15
	_expect(
		target.collision_layer & PROJECTILE_MASK != 0,
		"(a) Target must sit on a layer inside projectile mask 1|4 (raw %d)." % target.collision_layer
	)

	# 瞄准分身体胶囊中心（collision shape local (0,1,0)），正对穿透
	var aim: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (aim - source.global_position).normalized()

	var projectile = SpellProjectileScene.instantiate()
	# setup 必须在 add_child（触发 _ready）之前，_ready 才能读到 veil_bolt 碰撞半径
	projectile.setup(source, dir, 24.0, 14.0, {
		"spell_type": "veil_bolt",
		"hand": "right",
		"item_id": "five_elements_seal",
		"action_id": "w7_small_target",
		"proj_speed": PROJECTILE_SPEED,
		"proj_lifetime": 3.0,
	})
	root.add_child(projectile)
	projectile.global_position = source.global_position
	_expect(
		is_equal_approx(projectile.speed, PROJECTILE_SPEED),
		"(a) Projectile speed must be the default %s, got %s." % [PROJECTILE_SPEED, projectile.speed]
	)

	var health_before: float = target.health
	var hit := false
	for i in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		if target.health < health_before or target.hits >= 1:
			hit = true
			break

	var health_now: float = target.health
	_expect(
		hit,
		"(a) Default-speed(15) projectile must hit the 0.4-radius target within %d physics frames (%.1f -> %.1f, hits %d)." \
			% [MAX_PHYSICS_FRAMES, health_before, health_now, target.hits]
	)
	_expect(
		target.hits >= 1,
		"(a) Target must receive receive_hit/receive_hit_payload, got %d hits." % target.hits
	)

	if is_instance_valid(projectile):
		projectile.queue_free()
	target.queue_free()
	source.free()


func _test_wrong_layer_target_not_hit() -> void:
	# 负控制：目标挂在 raw 2 层（不在投射物 mask 1|4 内），投射物应穿过并消亡。
	var source := Node3D.new()
	source.name = "WrongLayerSource"
	root.add_child(source)
	source.global_position = Vector3.ZERO

	var target := SmallTarget.new()
	target.name = "WrongLayerTarget"
	root.add_child(target)
	target.configure(false)
	target.global_position = Vector3(HIT_DISTANCE, 0.0, 0.0)
	await _physics_frames(2)

	# 静态前置：目标必须不在投射物 mask 内，负控制才成立
	_expect(
		target.collision_layer & PROJECTILE_MASK == 0,
		"(b) Wrong-layer target must NOT sit inside projectile mask 1|4 (raw %d)." % target.collision_layer
	)

	var aim: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (aim - source.global_position).normalized()

	var projectile = SpellProjectileScene.instantiate()
	projectile.setup(source, dir, 24.0, 14.0, {
		"spell_type": "veil_bolt",
		"hand": "right",
		"item_id": "five_elements_seal",
		"action_id": "w7_wrong_layer",
		"proj_speed": PROJECTILE_SPEED,
		"proj_lifetime": NEG_LIFETIME,
	})
	root.add_child(projectile)
	projectile.global_position = source.global_position

	# 推进物理帧直到投射物自然消亡（lifetime 结束）或预算耗尽
	for i in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		if not is_instance_valid(projectile):
			break

	_expect(
		target.hits == 0,
		"(b) Wrong-layer target must NOT be hit by the projectile, got %d hits." % target.hits
	)
	_expect(
		is_equal_approx(target.health, TARGET_MAX_HEALTH),
		"(b) Wrong-layer target health must stay %s, got %s." % [TARGET_MAX_HEALTH, target.health]
	)

	if is_instance_valid(projectile):
		projectile.queue_free()
	target.queue_free()
	source.free()


func _physics_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
