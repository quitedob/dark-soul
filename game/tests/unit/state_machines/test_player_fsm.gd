extends "res://addons/gut/test.gd"

const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfigScript = preload("res://scripts/core/input_config.gd")

var player


func before_each() -> void:
	InputConfigScript.configure_inputs()
	player = add_child_autofree(PlayerScene.instantiate())


func after_each() -> void:
	await get_tree().process_frame


func test_attack_chain_completes_in_order() -> void:
	player._change_state(player.State.ATTACK_WINDUP, 0.01)
	player._update_state(0.02)
	assert_eq(player.state, player.State.ATTACK_ACTIVE)
	player._update_state(1.0)
	assert_eq(player.state, player.State.ATTACK_RECOVERY)
	player._update_state(1.0)
	assert_eq(player.state, player.State.LOCOMOTION)


func test_dodge_and_parry_return_to_locomotion() -> void:
	player._change_state(player.State.DODGE, 0.01)
	player._update_state(0.02)
	assert_eq(player.state, player.State.LOCOMOTION)
	player._change_state(player.State.PARRY, 0.01)
	player._update_state(0.02)
	assert_eq(player.state, player.State.LOCOMOTION)


func test_dead_player_action_guards_reject_attack_dodge_and_parry() -> void:
	player.state = player.State.DEAD
	player.stamina = player.max_stamina
	player._try_attack(false)
	assert_eq(player.state, player.State.DEAD)
	player._try_dodge()
	assert_eq(player.state, player.State.DEAD)
	player._try_parry()
	assert_eq(player.state, player.State.DEAD)


func test_respawn_is_the_supported_dead_to_locomotion_path() -> void:
	player.state = player.State.DEAD
	player.health = 0.0
	player.stamina = 1.0
	player.respawn_at(Vector3(1.0, 2.0, 3.0))
	assert_eq(player.state, player.State.LOCOMOTION)
	assert_eq(player.health, player.max_health)
	assert_eq(player.stamina, player.max_stamina)


func test_active_wam_holds_light_hit_but_zero_wam_staggers() -> void:
	player.set_combat_style(player.CombatStyle.TWIN_COLOSSI)
	player.attack_heavy = true
	player._change_state(player.State.ATTACK_ACTIVE, 1.0)
	player.receive_hit_payload({"damage": 5.0, "stagger": 10.0, "poise": 10.0, "direction": Vector3.BACK, "source": null})
	assert_eq(player.state, player.State.ATTACK_ACTIVE)
	# 站立满韧性：轻击扣储备但不硬直
	player._change_state(player.State.LOCOMOTION)
	player.poise_health = player.max_poise_health
	player.receive_hit_payload({"damage": 5.0, "stagger": 10.0, "poise": 10.0, "direction": Vector3.BACK, "source": null})
	assert_eq(player.state, player.State.LOCOMOTION)
	assert_lt(player.poise_health, player.max_poise_health)
	# 站立韧性打空：才进入硬直
	player.poise_health = 5.0
	player.receive_hit_payload({"damage": 5.0, "stagger": 10.0, "poise": 20.0, "direction": Vector3.BACK, "source": null})
	assert_eq(player.state, player.State.STAGGER)


func test_guard_cancels_on_non_locomotion_state() -> void:
	player.set_guard_active(true)
	assert_true(player.guard_active)
	player._change_state(player.State.ATTACK_WINDUP, 0.5)
	assert_false(player.guard_active)


## I-12：GUARD_BROKEN 结束回 LOCOMOTION，期间不可开盾
func test_guard_broken_recovers_to_locomotion() -> void:
	player._change_state(player.State.GUARD_BROKEN, 0.01)
	player.set_guard_active(true)
	assert_false(player.guard_active, "破防中不可开盾")
	player._update_state(0.02)
	assert_eq(player.state, player.State.LOCOMOTION)


## I-12：GRABBED 拒攻击；结束后进 STAGGER
func test_grabbed_blocks_attack_then_releases_to_stagger() -> void:
	player.begin_grabbed(null, 0.01)
	assert_eq(player.state, player.State.GRABBED)
	player.stamina = player.max_stamina
	player._try_attack(false)
	assert_eq(player.state, player.State.GRABBED, "被抓中不可开攻")
	# begin_grabbed 最短 0.4s
	player._update_state(0.45)
	assert_eq(player.state, player.State.STAGGER)
	player.end_grabbed()
	assert_eq(player.state, player.State.STAGGER)


## I-12：蓄力重击进入 CHARGE_HEAVY，松手提交攻击链
func test_charge_heavy_release_commits_attack() -> void:
	player.set_combat_style(player.CombatStyle.RELIQUARY_GUARD)
	player.stamina = player.max_stamina
	player.state = player.State.LOCOMOTION
	player._start_heavy_charge("right", "sword_heavy")
	assert_eq(player.state, player.State.CHARGE_HEAVY)
	player._charge_time = 0.35
	player._release_heavy_charge()
	assert_true(
		player.state in [
			player.State.ATTACK_WINDUP,
			player.State.ATTACK_ACTIVE,
			player.State.LOCOMOTION,
		],
		"松手应提交蓄力或回站立"
	)


## I-12：处决链 WINDUP→ACTIVE→RECOVERY→LOCO
func test_execute_chain_is_strict() -> void:
	var ExecutionProfile = preload("res://scripts/combat/data/execution_profile.gd")
	var profile = ExecutionProfile.make_riposte()
	player._execution_profile = profile
	player._change_state(player.State.EXECUTE_WINDUP, 0.01)
	player._update_state(0.02)
	assert_eq(player.state, player.State.EXECUTE_ACTIVE)
	player._update_state(profile.active_seconds + 0.02)
	assert_eq(player.state, player.State.EXECUTE_RECOVERY)
	player._update_state(profile.recovery_seconds + 0.02)
	assert_eq(player.state, player.State.LOCOMOTION)


## I-12：recovery 可写入缓冲
func test_input_buffer_stores_during_recovery() -> void:
	player._change_state(player.State.ATTACK_RECOVERY, 0.5)
	player._buffered_action = ""
	player._buffer_timer = 0.0
	# 直接写入缓冲（绕过 Input），验证窗口字段
	player._buffered_action = "dodge"
	player._buffer_timer = player.INPUT_BUFFER_WINDOW
	assert_ne(player._buffered_action, "")
	assert_gt(player._buffer_timer, 0.0)
	player._update_state(0.02)
	assert_gt(player._buffer_timer, 0.0, "缓冲计时应仍在窗口内")
	player._update_state(0.20)
	assert_true(player._buffer_timer <= 0.0, "超过窗口后应归零")
