# game/tests/unit/combat/test_animation_callback_bridge.gd
extends "res://addons/gut/test.gd"
## D-08：动画回调桥信号与钩子

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfigScript = preload("res://scripts/core/input_config.gd")

var player


func before_each() -> void:
	# 与 FSM 套件一致：在 before_each 建玩家，BlendSpace 告警不计入学例失败
	InputConfigScript.configure_inputs()
	player = add_child_autofree(PlayerScene.instantiate())


func after_each() -> void:
	await get_tree().process_frame


func test_bridge_hooks_emit_signals() -> void:
	# 仅测钩子/信号，不走 setup→BlendSpace
	var bridge = AnimBridge.new()
	var fired := {"hit": false, "off": false, "combo": false, "close": false}
	bridge.hitbox_activated.connect(func(): fired["hit"] = true)
	bridge.hitbox_deactivated.connect(func(): fired["off"] = true)
	bridge.combo_window_opened.connect(func(): fired["combo"] = true)
	bridge.combo_window_closed.connect(func(): fired["close"] = true)
	bridge.anim_event_hitbox_on()
	bridge.anim_event_hitbox_off()
	bridge.anim_event_combo_open()
	bridge.anim_event_combo_close()
	assert_true(fired["hit"])
	assert_true(fired["off"])
	assert_true(fired["combo"])
	assert_true(fired["close"])
	assert_true(player.has_method("anim_event_hitbox_on"))


func test_player_forwards_anim_events_without_state_change() -> void:
	# D-08 修复后无闩锁；转发契约改为：桥信号被发出、状态机不被改变
	assert_not_null(player._anim_bridge, "player 应已连接动画桥")
	var hit_fired := [false]
	var off_fired := [false]
	player._anim_bridge.hitbox_activated.connect(func(): hit_fired[0] = true)
	player._anim_bridge.hitbox_deactivated.connect(func(): off_fired[0] = true)
	player.state = player.State.ATTACK_WINDUP
	player.state_time = 0.5
	player.anim_event_hitbox_on()
	assert_true(hit_fired[0], "anim_event_hitbox_on 应转发到桥 hitbox_activated 信号")
	assert_eq(player.state, player.State.ATTACK_WINDUP, "无启用时不得改状态机")
	player.anim_event_hitbox_off()
	assert_true(off_fired[0], "anim_event_hitbox_off 应转发到桥 hitbox_deactivated 信号")
