extends SceneTree
## 死亡环合约：祠堂 checkpoint_id、Lost Echo 字段、敌人 reset 入口

const RunStateScript = preload("res://scripts/core/run_state.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")
const EnemyScene = preload("res://scenes/actors/enemy.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_run_state_checkpoint_fields()
	_test_enemy_reset_restores_spawn()
	_test_checkpoint_marker_exists()
	if _failures.is_empty():
		print("ASHEN_DEATH_LOOP_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_run_state_checkpoint_fields() -> void:
	var state = RunStateScript.new()
	state.checkpoint_id = "shrine_01_01"
	state.lost_echo_amount = 40
	state.lost_echo_position = Vector3(1.0, 2.0, 3.0)
	_expect(state.checkpoint_id == "shrine_01_01", "checkpoint_id not retained.")
	_expect(state.lost_echo_amount == 40, "lost_echo_amount not retained.")
	_expect(state.lost_echo_position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), "lost_echo_position not retained.")


func _test_enemy_reset_restores_spawn() -> void:
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


func _test_checkpoint_marker_exists() -> void:
	var runtime := Runtime.new()
	root.add_child(runtime)
	var level := runtime.load_level(&"level_01_01")
	_expect(level != null, "level_01_01 failed to generate.")
	_expect(runtime.get_checkpoint_marker() != null, "Checkpoint marker missing on level_01_01.")
	_expect(runtime.get_spawn_marker() != null, "Spawn marker missing on level_01_01.")
	runtime.unload_level()
	runtime.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
