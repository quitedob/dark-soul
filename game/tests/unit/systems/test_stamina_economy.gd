extends "res://addons/gut/test.gd"

const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfigScript = preload("res://scripts/core/input_config.gd")

var player


func before_each() -> void:
	InputConfigScript.configure_inputs()
	player = add_child_autofree(PlayerScene.instantiate())


func after_each() -> void:
	await get_tree().process_frame


func test_stamina_clamps_to_max_and_zero() -> void:
	player.state = player.State.LOCOMOTION
	player.stamina = player.max_stamina
	player.stamina_delay = 0.0
	player._update_stamina(10.0)
	assert_eq(player.stamina, player.max_stamina)
	player._spend_stamina(player.max_stamina * 2.0, 0.5)
	assert_eq(player.stamina, 0.0)


func test_regen_occurs_only_in_locomotion() -> void:
	for blocked_state in [player.State.ATTACK_ACTIVE, player.State.DODGE, player.State.STAGGER, player.State.DEAD]:
		player.state = blocked_state
		player.stamina = 50.0
		player.stamina_delay = 0.0
		player._update_stamina(1.0)
		assert_eq(player.stamina, 50.0, "State %d regenerated stamina." % blocked_state)
	player.state = player.State.LOCOMOTION
	player._update_stamina(0.1)
	assert_gt(player.stamina, 50.0)


func test_spend_delay_counts_down_only_in_locomotion() -> void:
	player.stamina_delay = 1.0
	player.state = player.State.ATTACK_ACTIVE
	player._update_stamina(0.5)
	assert_almost_eq(player.stamina_delay, 1.0, 0.001)
	player.state = player.State.LOCOMOTION
	player._update_stamina(0.5)
	assert_almost_eq(player.stamina_delay, 0.5, 0.001)


## 目标风格精力消耗：中性攻击精力 = 风格资源（blessed `combat_contract_test.gd#_test_stamina_matrix`）。
## 单手握持（grip stamina 倍率 1.0）下攻击实际扣费与资源值一致：TWIN 重击 65、CRESCENT 轻击 16。
func test_target_style_costs_and_insufficient_block() -> void:
	await _stand_player_on_floor()
	player.set_combat_style(player.CombatStyle.TWIN_COLOSSI)
	player.grip_mode = player.GripMode.ONE_HANDED
	player._refresh_moveset_cache()
	player.stamina = 100.0
	player._try_attack(true)
	assert_almost_eq(player.stamina, 35.0, 0.001)  # 100 - blessed stamina_heavy(65)
	player._change_state(player.State.LOCOMOTION)
	player.set_combat_style(player.CombatStyle.CRESCENT_PAIR)
	player.grip_mode = player.GripMode.ONE_HANDED
	player._refresh_moveset_cache()
	player.stamina = 100.0
	player._try_attack(false)
	assert_almost_eq(player.stamina, 84.0, 0.001)  # 100 - blessed stamina_light(16)
	player._change_state(player.State.LOCOMOTION)
	player.set_combat_style(player.CombatStyle.TWIN_COLOSSI)
	player.grip_mode = player.GripMode.ONE_HANDED
	player._refresh_moveset_cache()
	player.stamina = 64.0
	player._try_attack(true)
	assert_eq(player.state, player.State.LOCOMOTION)
	assert_eq(player.stamina, 64.0)


## 单位测试无关卡地板：放置地板并等待物理帧，使 `is_on_floor()` 为真，
## 这样 `_try_attack` 才会解析为中立轻/重击（否则落空时解析为空中跳劈/下落攻击）。
func _stand_player_on_floor() -> void:
	# 玩家 collision_mask=1（仅 Layer1 静态世界），地板必须落在 Layer1 才能被踩到。
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 2.0, 30.0)
	collision.shape = box
	floor_body.add_child(collision)
	floor_body.position = Vector3(0.0, -1.1, 0.0)  # 顶面 y=-0.1，位于玩家脚底
	add_child_autofree(floor_body)
	for i in 24:
		await get_tree().physics_frame


func test_respawn_restores_stamina_and_clears_delay() -> void:
	player.state = player.State.DEAD
	player.stamina = 10.0
	player.stamina_delay = 1.0
	player.respawn_at(Vector3.ZERO)
	assert_eq(player.stamina, player.max_stamina)
	assert_eq(player.stamina_delay, 0.0)


func test_focus_never_exceeds_max() -> void:
	player.focus = player.max_focus
	player.state = player.State.LOCOMOTION
	player._update_stamina(10.0)
	assert_eq(player.focus, player.max_focus)


## I-13：专注仅在 LOCOMOTION 回复
func test_focus_regen_only_in_locomotion() -> void:
	player.focus = 40.0
	player.state = player.State.ATTACK_ACTIVE
	player._update_stamina(1.0)
	assert_eq(player.focus, 40.0, "非站立不应回专注")
	player.state = player.State.LOCOMOTION
	player._update_stamina(1.0)
	assert_almost_eq(player.focus, 40.0 + player.FOCUS_REGEN_RATE, 0.001)


## I-13：Guard Meter 延迟后回复；破防/举盾时不回
func test_guard_meter_regen_delay_and_gates() -> void:
	player.guard_meter = 50.0
	player._guard_meter_regen_delay = 1.0
	player.guard_active = false
	player.state = player.State.LOCOMOTION
	player._update_guard_meter(0.5)
	assert_almost_eq(player.guard_meter, 50.0, 0.001, "延迟中不应回复")
	assert_almost_eq(player._guard_meter_regen_delay, 0.5, 0.001)
	player._update_guard_meter(0.5)
	player._update_guard_meter(0.5)
	assert_gt(player.guard_meter, 50.0, "延迟结束后应回复")
	var after_regen: float = player.guard_meter
	player.guard_active = true
	player._update_guard_meter(1.0)
	assert_almost_eq(player.guard_meter, after_regen, 0.001, "举盾中不回 Meter")
	player.guard_active = false
	player.state = player.State.GUARD_BROKEN
	player._guard_meter_regen_delay = 0.0
	player.guard_meter = 40.0
	player._update_guard_meter(1.0)
	assert_almost_eq(player.guard_meter, 40.0, 0.001, "破防中不回 Meter")


## I-13：专注经济上限夹紧
func test_focus_set_clamps_range() -> void:
	player.set_focus(999.0)
	assert_eq(player.focus, player.max_focus)
	player.set_focus(-5.0)
	assert_eq(player.focus, 0.0)
