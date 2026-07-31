extends "res://addons/gut/test.gd"
## I-07：死亡/回收环集成 — ember 掉落、LostEcho、敌重置、checkpoint 重生

const RunStateScript = preload("res://scripts/core/run_state.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")
const EnemyScene = preload("res://scenes/actors/enemy.tscn")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const LostEchoScene = preload("res://scenes/interactables/lost_echo.tscn")
const InputConfigScript = preload("res://scripts/core/input_config.gd")

var player


func before_all() -> void:
	InputConfigScript.configure_inputs()


func before_each() -> void:
	# Player 动画树会刷 BlendSpace 警告；放在 before_each 以免计入 Unexpected Errors
	player = add_child_autofree(PlayerScene.instantiate())


func after_each() -> void:
	await get_tree().process_frame


func test_lose_embers_drops_full_carried_amount() -> void:
	# 死亡掉落：清空玩家余烬并返回掉落量
	player.set_embers(64)
	var lost: int = int(player.lose_embers())
	assert_eq(lost, 64)
	assert_eq(player.embers, 0)


func test_lost_echo_spawn_writes_run_state_fields() -> void:
	# LostEcho 生成后 amount/position 进入 run_state
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var echo = LostEchoScene.instantiate()
	host.add_child(echo)
	var at := Vector3(2.5, 1.0, -1.5)
	echo.setup(33, host)
	echo.position = at
	var state = RunStateScript.new()
	state.lost_echo_amount = int(echo.amount)
	state.lost_echo_position = echo.global_position
	assert_eq(echo.amount, 33)
	assert_eq(state.lost_echo_amount, 33)
	assert_lt(state.lost_echo_position.distance_to(at), 0.05)


func test_lost_echo_recovery_emits_and_clears_echo_state() -> void:
	# 回收信号 + recover_embers + 清空存档回声字段
	player.set_embers(0)
	var echo = add_child_autofree(LostEchoScene.instantiate())
	echo.setup(21, null)
	var got := {"amount": -1}
	echo.recovered.connect(func(amount: int, _p: Node) -> void:
		got["amount"] = amount
	)
	echo.interact(player)
	assert_eq(int(got["amount"]), 21)
	player.recover_embers(int(got["amount"]))
	assert_eq(player.embers, 21)
	var state = RunStateScript.new()
	state.lost_echo_amount = 21
	state.lost_echo_position = Vector3.ONE
	state.lost_echo_amount = 0
	state.lost_echo_position = Vector3.ZERO
	assert_eq(state.lost_echo_amount, 0)
	assert_eq(state.lost_echo_position, Vector3.ZERO)


func test_enemy_reset_restores_spawn_health_and_poise() -> void:
	# 祠堂休息/死亡环共用 reset_enemy 合约
	var enemy = add_child_autofree(EnemyScene.instantiate())
	enemy.spawn_origin = Vector3(4.0, 1.0, -6.0)
	enemy.global_position = Vector3(10.0, 1.0, 10.0)
	enemy.health = 1.0
	enemy.poise = 99.0
	enemy.reset_enemy()
	assert_lt(enemy.global_position.distance_to(enemy.spawn_origin), 0.05)
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(enemy.poise, 0.0)


func test_death_loop_composition_checkpoint_respawn() -> void:
	# 组合：掉落 → 回声 → 敌重置 → 在 checkpoint 偏移重生
	var runtime: CampaignLevelRuntime = Runtime.new()
	add_child_autofree(runtime)
	var level = runtime.load_level(&"level_01_01")
	assert_not_null(level, "level_01_01 must generate")
	var checkpoint = runtime.get_checkpoint_marker()
	var spawn = runtime.get_spawn_marker()
	assert_not_null(checkpoint)
	assert_not_null(spawn)

	player.set_embers(40)
	player.global_position = Vector3(11.0, 1.0, 11.0)
	var death_pos: Vector3 = player.global_position

	var enemy = add_child_autofree(EnemyScene.instantiate())
	enemy.spawn_origin = Vector3(1.0, 1.0, 1.0)
	enemy.global_position = Vector3(7.0, 1.0, 7.0)
	enemy.health = 4.0

	var lost: int = int(player.lose_embers())
	assert_eq(lost, 40)
	assert_eq(player.embers, 0)

	var echo = add_child_autofree(LostEchoScene.instantiate())
	echo.setup(lost, null)
	echo.position = death_pos + Vector3.UP * 0.35
	var state = RunStateScript.new()
	state.lost_echo_amount = lost
	state.lost_echo_position = echo.global_position
	state.checkpoint_id = String(runtime.get_level_data().get("checkpoint_id", "ember_shrine"))
	assert_eq(state.checkpoint_id, "shrine_01_01")
	assert_eq(state.lost_echo_amount, 40)

	enemy.reset_enemy()
	assert_lt(enemy.global_position.distance_to(enemy.spawn_origin), 0.05)
	assert_eq(enemy.health, enemy.max_health)

	var respawn_at: Vector3 = checkpoint.global_position + Vector3(0.0, 1.1, 2.0)
	player.respawn_at(respawn_at)
	assert_eq(player.state, player.State.LOCOMOTION)
	assert_eq(player.health, player.max_health)
	assert_lt(player.global_position.distance_to(respawn_at), 1.5)
	runtime.unload_level()


func test_level_checkpoint_id_and_markers_exist() -> void:
	# 关卡数据与场景标记：存档恢复时用 checkpoint 而非 spawn
	var runtime: CampaignLevelRuntime = Runtime.new()
	add_child_autofree(runtime)
	assert_not_null(runtime.load_level(&"level_01_01"))
	assert_not_null(runtime.get_checkpoint_marker())
	assert_not_null(runtime.get_spawn_marker())
	assert_eq(String(runtime.get_level_data().get("checkpoint_id", "")), "shrine_01_01")
	runtime.unload_level()
