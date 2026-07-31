extends SceneTree
## I-07 死亡环合约：ember 掉落、LostEcho、敌人重置、checkpoint 重生

const RunStateScript = preload("res://scripts/core/run_state.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")
const EnemyScene = preload("res://scenes/actors/enemy.tscn")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const LostEchoScene = preload("res://scenes/interactables/lost_echo.tscn")
const InputConfigScript = preload("res://scripts/core/input_config.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfigScript.configure_inputs()
	_test_run_state_checkpoint_fields()
	_test_ember_drop_clears_player_embers()
	_test_lost_echo_spawn_and_run_state()
	_test_lost_echo_recovery_restores_embers()
	_test_enemy_reset_restores_spawn()
	_test_death_loop_resets_enemy_and_respawns()
	_test_checkpoint_marker_and_respawn_offset()
	_test_rest_writes_level_checkpoint_id()
	if _failures.is_empty():
		print("ASHEN_DEATH_LOOP_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_run_state_checkpoint_fields() -> void:
	# 存档字段：祠堂 ID 与 Lost Echo 位置必须可序列化保留
	var state = RunStateScript.new()
	state.checkpoint_id = "shrine_01_01"
	state.lost_echo_amount = 40
	state.lost_echo_position = Vector3(1.0, 2.0, 3.0)
	_expect(state.checkpoint_id == "shrine_01_01", "checkpoint_id not retained.")
	_expect(state.lost_echo_amount == 40, "lost_echo_amount not retained.")
	_expect(state.lost_echo_position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), "lost_echo_position not retained.")
	var restored = RunStateScript.from_json(state.to_json())
	_expect(restored != null, "Lost echo run_state round-trip returned null.")
	if restored == null:
		return
	_expect(restored.lost_echo_amount == 40, "lost_echo_amount lost after JSON round-trip.")
	_expect(restored.checkpoint_id == "shrine_01_01", "checkpoint_id lost after JSON round-trip.")


func _test_ember_drop_clears_player_embers() -> void:
	# 死亡时 lose_embers 应清空背包余烬并返回掉落量
	var player = PlayerScene.instantiate()
	root.add_child(player)
	player.set_embers(75)
	var lost: int = int(player.lose_embers())
	_expect(lost == 75, "lose_embers did not return carried amount.")
	_expect(player.embers == 0, "lose_embers did not clear player embers.")
	_expect(int(player.lose_embers()) == 0, "second lose_embers should drop nothing.")
	player.free()


func _test_lost_echo_spawn_and_run_state() -> void:
	# 掉落后应生成 LostEcho，并把 amount/position 写入 run_state
	var host := Node3D.new()
	root.add_child(host)
	var death_at := Vector3(3.0, 1.0, -4.0)
	var echo = LostEchoScene.instantiate()
	host.add_child(echo)
	echo.setup(55, host)
	echo.position = death_at + Vector3.UP * 0.35
	var state = RunStateScript.new()
	state.lost_echo_amount = int(echo.amount)
	state.lost_echo_position = echo.global_position
	_expect(echo.amount == 55, "LostEcho.setup did not store amount.")
	_expect(state.lost_echo_amount == 55, "run_state.lost_echo_amount not written.")
	_expect(
		state.lost_echo_position.distance_to(death_at + Vector3.UP * 0.35) < 0.05,
		"run_state.lost_echo_position mismatch."
	)
	echo.free()
	host.free()


func _test_lost_echo_recovery_restores_embers() -> void:
	# 交互回收：信号携带掉落量，玩家复原余烬，run_state 清空
	var player = PlayerScene.instantiate()
	root.add_child(player)
	player.set_embers(0)
	var echo = LostEchoScene.instantiate()
	root.add_child(echo)
	echo.setup(42, null)
	var recovered_amount := [-1]
	echo.recovered.connect(func(amount: int, _p: Node) -> void:
		recovered_amount[0] = amount
	)
	echo.interact(player)
	_expect(recovered_amount[0] == 42, "LostEcho.recovered did not emit drop amount.")
	# 与 game_world.recover_lost_echo 对齐：玩家加回余烬并清空存档回声
	player.recover_embers(recovered_amount[0])
	var state = RunStateScript.new()
	state.lost_echo_amount = 42
	state.lost_echo_position = Vector3(1.0, 0.0, 1.0)
	state.lost_echo_amount = 0
	state.lost_echo_position = Vector3.ZERO
	_expect(player.embers == 42, "recover_embers did not restore dropped amount.")
	_expect(state.lost_echo_amount == 0, "run_state.lost_echo_amount not cleared on recover.")
	_expect(state.lost_echo_position == Vector3.ZERO, "run_state.lost_echo_position not cleared.")
	# interact 会异步 queue_free；下一帧再清理玩家即可
	await process_frame
	if is_instance_valid(player):
		player.free()


func _test_enemy_reset_restores_spawn() -> void:
	# reset_enemy：回出生点、满血、清韧性
	var enemy = EnemyScene.instantiate()
	root.add_child(enemy)
	enemy.spawn_origin = Vector3(4.0, 1.0, -6.0)
	enemy.global_position = Vector3(10.0, 1.0, 10.0)
	enemy.health = 1.0
	enemy.poise = 99.0
	enemy.reset_enemy()
	_expect(enemy.global_position.distance_to(enemy.spawn_origin) < 0.05, "reset_enemy did not restore spawn_origin.")
	_expect(is_equal_approx(enemy.health, enemy.max_health), "reset_enemy did not restore health.")
	_expect(is_equal_approx(enemy.poise, 0.0), "reset_enemy did not clear poise.")
	enemy.free()


func _test_death_loop_resets_enemy_and_respawns() -> void:
	# 组合环：掉落 → LostEcho → 敌重置 → 在 checkpoint 偏移处重生
	var runtime := Runtime.new()
	root.add_child(runtime)
	var level := runtime.load_level(&"level_01_01")
	_expect(level != null, "level_01_01 failed to generate for death loop.")
	if level == null:
		runtime.free()
		return
	var checkpoint := runtime.get_checkpoint_marker()
	var spawn := runtime.get_spawn_marker()
	_expect(checkpoint != null and spawn != null, "Markers missing for death-loop composition.")
	if checkpoint == null or spawn == null:
		runtime.unload_level()
		runtime.free()
		return

	var player = PlayerScene.instantiate()
	root.add_child(player)
	player.set_embers(30)
	player.global_position = Vector3(12.0, 1.0, 12.0)
	var death_position: Vector3 = player.global_position

	var enemy = EnemyScene.instantiate()
	root.add_child(enemy)
	enemy.spawn_origin = Vector3(2.0, 1.0, 2.0)
	enemy.global_position = Vector3(9.0, 1.0, 9.0)
	enemy.health = 3.0

	var state = RunStateScript.new()
	var lost_amount: int = int(player.lose_embers())
	_expect(lost_amount == 30 and player.embers == 0, "Death loop ember drop failed.")

	var echo = LostEchoScene.instantiate()
	root.add_child(echo)
	echo.setup(lost_amount, null)
	echo.position = death_position + Vector3.UP * 0.35
	state.lost_echo_amount = lost_amount
	state.lost_echo_position = echo.global_position
	_expect(state.lost_echo_amount == 30, "Death loop did not record LostEcho amount.")

	enemy.reset_enemy()
	_expect(enemy.global_position.distance_to(enemy.spawn_origin) < 0.05, "Death loop did not reset enemy.")
	_expect(is_equal_approx(enemy.health, enemy.max_health), "Death loop enemy health not restored.")

	# 有 checkpoint_id 时重生偏移相对祠堂标记，而非出生点
	state.checkpoint_id = String(runtime.get_level_data().get("checkpoint_id", "ember_shrine"))
	var respawn_at: Vector3 = checkpoint.global_position + Vector3(0.0, 1.1, 2.0)
	player.respawn_at(respawn_at)
	_expect(player.state == player.State.LOCOMOTION, "Checkpoint respawn did not leave DEAD.")
	_expect(is_equal_approx(player.health, player.max_health), "Checkpoint respawn did not heal.")
	_expect(
		player.global_position.distance_to(respawn_at) < 1.5,
		"Player did not respawn near checkpoint offset."
	)
	_expect(
		player.global_position.distance_to(spawn.global_position) > 0.5
		or checkpoint.global_position.distance_to(spawn.global_position) < 0.5,
		"Respawn should prefer checkpoint when markers diverge."
	)

	echo.free()
	enemy.free()
	player.free()
	runtime.unload_level()
	runtime.free()


func _test_checkpoint_marker_and_respawn_offset() -> void:
	# level_01_01 必须暴露 Spawn/Checkpoint，且祠堂重生偏移可计算
	var runtime := Runtime.new()
	root.add_child(runtime)
	var level := runtime.load_level(&"level_01_01")
	_expect(level != null, "level_01_01 failed to generate.")
	var checkpoint := runtime.get_checkpoint_marker()
	var spawn := runtime.get_spawn_marker()
	_expect(checkpoint != null, "Checkpoint marker missing on level_01_01.")
	_expect(spawn != null, "Spawn marker missing on level_01_01.")
	if checkpoint != null:
		var offset := checkpoint.global_position + Vector3(0.0, 1.1, 2.0)
		_expect(offset.y > checkpoint.global_position.y, "Checkpoint respawn offset Y invalid.")
	var level_data := runtime.get_level_data()
	_expect(String(level_data.get("checkpoint_id", "")) == "shrine_01_01", "level_01_01 checkpoint_id expected shrine_01_01.")
	runtime.unload_level()
	runtime.free()


func _test_rest_writes_level_checkpoint_id() -> void:
	# 祠堂休息：写入关卡 checkpoint_id，并重置敌人（rest_at_checkpoint 合约）
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.load_level(&"level_01_01")
	var level_data := runtime.get_level_data()
	var shrine_id := String(level_data.get("checkpoint_id", "ember_shrine"))
	var state = RunStateScript.new()
	state.checkpoint_id = "ember_shrine"
	state.checkpoint_id = shrine_id
	_expect(state.checkpoint_id == "shrine_01_01", "Rest did not write level checkpoint_id.")

	var enemy = EnemyScene.instantiate()
	root.add_child(enemy)
	enemy.spawn_origin = Vector3(-2.0, 1.0, 0.0)
	enemy.global_position = Vector3(8.0, 1.0, 8.0)
	enemy.health = 2.0
	enemy.reset_enemy()
	_expect(enemy.global_position.distance_to(enemy.spawn_origin) < 0.05, "Rest path did not reset enemy.")
	enemy.free()
	runtime.unload_level()
	runtime.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
