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


func test_target_style_costs_and_insufficient_block() -> void:
	player.set_combat_style(player.CombatStyle.TWIN_COLOSSI)
	player.stamina = 100.0
	player._try_attack(true)
	assert_almost_eq(player.stamina, 35.0, 0.001)
	player._change_state(player.State.LOCOMOTION)
	player.set_combat_style(player.CombatStyle.CRESCENT_PAIR)
	player.stamina = 100.0
	player._try_attack(false)
	assert_almost_eq(player.stamina, 84.0, 0.001)
	player._change_state(player.State.LOCOMOTION)
	player.set_combat_style(player.CombatStyle.TWIN_COLOSSI)
	player.stamina = 64.0
	player._try_attack(true)
	assert_eq(player.state, player.State.LOCOMOTION)
	assert_eq(player.stamina, 64.0)


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
