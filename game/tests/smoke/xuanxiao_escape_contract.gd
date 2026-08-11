extends SceneTree
## 玄霄逃出流程合约：90s 倒计时耗尽触发逃出时，必须通知 world 解封竞技场（不软锁），
## 且 ch4_xuanxiao_escaped 旗标落盘；通知恰好一次（幂等）。
##
## 用桩 world + 桩 boss 走 BossFlowController.attach 真实挂载路径，直接 _trigger_escape()
## （绕过 90s 计时），断言逃出通知与旗标。

const FlowHostScript = preload("res://scripts/boss/boss_flow_controller.gd")

const SUCCESS_MARKER := "ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK"
const ESCAPE_FLAG := "ch4_xuanxiao_escaped"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	call_deferred("_test_escape")


func _test_escape() -> void:
	var world := StubWorld.new()
	root.add_child(world)
	var boss := StubBoss.new()
	boss.world_node = world
	boss.visual_root = Node3D.new()
	boss.add_child(boss.visual_root)
	root.add_child(boss)

	var host := FlowHostScript.new()
	boss.add_child(host)
	var attached := host.attach(boss, {
		"flow": {
			"script": "res://scripts/boss/flow/xuanxiao_escape_flow.gd",
			"config": {"escape_after_seconds": 90.0},
		},
	})
	_expect(attached, "escape: BossFlowController must attach the escape flow.")

	var flow: Variant = boss.get_node_or_null("FlowController")
	_expect(flow != null, "escape: flow node must be mounted on the boss.")
	if flow == null:
		_finish()
		return

	flow._trigger_escape()

	_expect(world.escape_notified == 1,
		"escape: world.on_boss_escaped must be notified exactly once, got %d." % world.escape_notified)
	_expect(bool(world.run_state.flags.get(ESCAPE_FLAG, false)) == true,
		"escape: ch4_xuanxiao_escaped flag must be recorded in run_state.choice_flags.")
	_expect(flow._escaped == true, "escape: flow must be in escaped state.")

	# 幂等：第二次触发不得重复通知
	flow._trigger_escape()
	_expect(world.escape_notified == 1,
		"escape: second trigger must NOT re-notify, got %d." % world.escape_notified)

	boss.queue_free()
	world.queue_free()
	_finish()


func _finish() -> void:
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


class StubWorld:
	extends Node
	var run_state := StubRunState.new()
	var hud: Node
	var escape_notified := 0

	func on_boss_escaped() -> void:
		escape_notified += 1

	func _save_run(_reason: String) -> void:
		pass


class StubRunState:
	extends RefCounted
	var flags := {}

	func set_choice_flag(flag: String, value: Variant) -> void:
		flags[flag] = value


class StubBoss:
	extends Node3D
	signal defeated(enemy, reward, is_guardian)
	var world_node: Node
	var velocity := Vector3.ZERO
	var combat_area: Node
	var body_collision: Node3D
	var visual_root: Node3D
	var body_material: StandardMaterial3D
