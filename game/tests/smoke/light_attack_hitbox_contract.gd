extends SceneTree
## 命中盒合约（D-08 修复回归）：
## - 轻击/重击进入 ATTACK_ACTIVE 一律用 state 计时开启命中盒（不再 defer 到动画轨），
##   地面与空中皆然 —— 修复"轻击 0 伤害"。
## - root-motion 跃击进入 LEAP_ACTIVE 同样用 state 计时开盒（windup 0.30~0.45 >
##   method-track 0.28，defer 会让命中盒永不开启 → 修复跃击 0 伤害同源 bug）。

const PlayerScript = preload("res://scripts/player/player.gd")
const CombatAreaScript = preload("res://scripts/combat_area.gd")

const SUCCESS_MARKER := "ASHEN_LIGHT_HITBOX_CONTRACTS_OK"
var _failures: Array[String] = []


func _initialize() -> void:
	# SceneTree 启动阶段：_init() 时树尚未 inside，_ready() 不触发；必须延迟到循环内。
	call_deferred("_run")


func _run() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	# 前置：真实动画桥已就绪且含 timing method tracks —— 否则 defer 断言无意义。
	_expect(
		player._anim_bridge != null and player._anim_bridge.enabled \
			and player._anim_bridge.has_timing_method_tracks,
		"bridge must be real+enabled+timing-tracks for the defer contract to be meaningful"
	)
	# 测试专用命中体积：生产 visuals 也会自建一个 CombatArea；以本 area 为准。
	var area = CombatAreaScript.new()
	area.name = "TestCombatArea"
	player.add_child(area)
	area.configure(player, 1.0)
	player.combat_area = area
	# 本合约只做确定性状态调用，不需要物理帧；关掉避免无关副作用。
	player.set_physics_process(false)

	# (a) 轻击 ATTACK_ACTIVE 不再 defer 到动画轨。
	player.attack_heavy = false
	_expect(
		not player._should_defer_hitbox_to_anim(player.State.ATTACK_ACTIVE),
		"ATTACK_ACTIVE light must not defer the hitbox to the animation track"
	)

	# (b) 进入 ATTACK_ACTIVE（轻击，地面语义）→ 命中盒立即打开。
	player._change_state(player.State.ATTACK_ACTIVE, 0.3)
	_expect(
		not player._hitbox_anim_deferred,
		"ATTACK_ACTIVE entry must leave _hitbox_anim_deferred false"
	)
	_expect(player.combat_area.active, "light ATTACK_ACTIVE entry must open the hitbox (0-damage bug)")

	# (c) 重击同样由 state 计时打开。
	player.combat_area.end_swing()
	player.attack_heavy = true
	player._change_state(player.State.ATTACK_ACTIVE, 0.3)
	_expect(player.combat_area.active, "heavy ATTACK_ACTIVE entry must open the hitbox")

	# (d) root-motion 跃击同源 bug 回归：LEAP_ACTIVE 也必须 state 计时开盒
	# （windup 0.30~0.45 > method-track 0.28 → 原 defer 使命中盒永不开启）。
	player.combat_area.end_swing()
	player._leap_uses_root_motion = true
	_expect(
		not player._should_defer_hitbox_to_anim(player.State.LEAP_ACTIVE),
		"LEAP_ACTIVE must not defer the hitbox (root-motion leap 0-damage regression)"
	)
	player._change_state(player.State.LEAP_ACTIVE, 0.3)
	_expect(
		not player._hitbox_anim_deferred,
		"LEAP_ACTIVE entry must leave _hitbox_anim_deferred false"
	)
	_expect(player.combat_area.active, "root-motion LEAP_ACTIVE entry must open the hitbox")
	player._leap_uses_root_motion = false

	player.queue_free()

	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
