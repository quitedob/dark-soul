extends SceneTree
## L-23 合约：存档系统（run_state.gd / checkpoint.gd）。
## 1) run_state v2 JSON 往返 + bridge 字典契约。
## 2) L-18 body_class_override 往返（JSON + bridge），清空覆盖不残留底层键。
## 3) 磁盘存档 user:// 写读往返（独立 l23 临时路径，测后清理）。
## 4) checkpoint.gd 信号契约：interact 触发 activated/rested，reset/activate 状态切换。

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CheckpointScript = preload("res://scripts/checkpoint.gd")

# L-23：独立 user:// 临时目录，避免与 smoke core 的 i09 夹具互相污染
const DISK_FIXTURE_ROOT := "user://l23_save_contract"
const DISK_RUN_PATH := "user://l23_save_contract/run_v2_round_trip.json"

var _failures: Array[String] = []


func _initialize() -> void:
	# L-19 模式：MainLoop._initialize 在树运行后触发；再推迟到首帧 idle 执行全部断言。
	# _init 阶段 root 子树 get_tree() 为空、_ready 不触发，checkpoint.interact() 的
	# get_tree().create_timer 无法求值。
	call_deferred("_run_all")


func _run_all() -> void:
	_test_run_state_round_trip_and_bridge()
	_test_body_class_override_round_trip()
	_test_run_state_disk_persistence()
	_test_checkpoint_signals_and_state()
	_finish()


func _test_checkpoint_signals_and_state() -> void:
	var checkpoint = CheckpointScript.new()
	root.add_child(checkpoint)
	# lambda 对基本类型按值捕获，直接 int 计数不会回写外层；用 Dictionary 按引用共享
	var counts := {"activated": 0, "rested": 0}
	checkpoint.activated.connect(func(_n, _p): counts["activated"] += 1)
	checkpoint.rested.connect(func(_n, _p): counts["rested"] += 1)
	var mock_player := Node3D.new()
	root.add_child(mock_player)
	_expect(not checkpoint.is_activated, "Checkpoint must start unactivated.")
	# interact 是协程：同步段会先 emit activated/rested，随后 await timer
	checkpoint.interact(mock_player)
	_expect(counts["activated"] == 1, "First interact must emit activated once, got %d." % counts["activated"])
	_expect(counts["rested"] == 1, "First interact must emit rested once, got %d." % counts["rested"])
	_expect(checkpoint.is_activated, "Interact must activate the checkpoint.")
	_expect(not checkpoint.get_prompt().is_empty(), "Checkpoint prompt must be localized non-empty.")
	checkpoint.reset()
	_expect(not checkpoint.is_activated, "reset must deactivate the checkpoint.")
	checkpoint.activate()
	_expect(checkpoint.is_activated, "activate must set is_activated.")
	checkpoint.queue_free()
	mock_player.queue_free()


func _test_run_state_round_trip_and_bridge() -> void:
	var state = RunStateScript.new()
	state.checkpoint_id = "ash_courtyard"
	state.embers = 123
	state.focus = 66.0
	state.combat_style = 2
	state.location = "ash_courtyard:north"
	state.right_hand = "marksman_bow"
	state.left_hand = "marksman_dagger"
	state.completed_levels.append("level_01_01")
	state.defeated_bosses.append("boss_giant_gate")
	var restored = RunStateScript.from_json(state.to_json())
	_expect(restored != null, "Save JSON round-trip returned null.")
	if restored != null:
		_expect(restored.checkpoint_id == "ash_courtyard", "Round-trip lost checkpoint.")
		_expect(restored.embers == 123, "Round-trip lost embers.")
		_expect(is_equal_approx(restored.focus, 66.0), "Round-trip lost focus.")
		_expect(restored.location == "ash_courtyard:north", "Round-trip lost location.")
		_expect(restored.right_hand == "marksman_bow", "Round-trip lost right hand.")
		_expect(restored.left_hand == "marksman_dagger", "Round-trip lost left hand.")
		_expect(restored.defeated_bosses.has("boss_giant_gate"), "Round-trip lost defeated boss.")
		_expect(restored.to_dictionary()["schema_version"] == 2, "Round-trip must write schema v2.")
	var bridge: Dictionary = state.to_bridge_dictionary()
	_expect(int(bridge["schemaVersion"]) == 2, "Bridge save must write schema v2.")
	_expect(bridge["player"]["rightHand"] == "marksman_bow", "Bridge save lost right hand.")
	_expect(bridge["progression"]["completedLevelIds"] == ["level_01_01"], "Bridge save lost completed levels.")
	var bridge_restored = RunStateScript.from_dictionary(bridge)
	_expect(bridge_restored != null, "Bridge save must parse.")
	if bridge_restored != null:
		_expect(bridge_restored.checkpoint_id == "ash_courtyard", "Bridge round-trip lost checkpoint.")


func _test_body_class_override_round_trip() -> void:
	var state = RunStateScript.new()
	state.checkpoint_id = "ash_courtyard"
	state.set_body_class_override("warrior_heavy")
	_expect(state.get_body_class_override() == "warrior_heavy", "set_body_class_override must store the override.")
	_expect(RunStateScript.static_body_class_override(state) == "warrior_heavy", "Static accessor must read the override.")
	_expect(RunStateScript.static_body_class_override(null) == "", "Static accessor must fall back on null.")
	var restored = RunStateScript.from_json(state.to_json())
	_expect(restored != null, "Override save must round-trip via JSON.")
	if restored != null:
		_expect(restored.get_body_class_override() == "warrior_heavy", "Override lost in JSON round-trip.")
	# 清空覆盖后序列化应擦除底层 progression_values 键
	state.set_body_class_override("")
	_expect(state.get_body_class_override() == "", "Empty override must be accepted.")
	_expect(
		not state.to_dictionary()["progression_values"].has("body_class_override"),
		"Cleared override must not persist a progression key."
	)
	# bridge 往返
	var bridge_state = RunStateScript.new()
	bridge_state.checkpoint_id = "ash_courtyard"
	bridge_state.set_body_class_override("celestial_guard")
	var bridge_restored = RunStateScript.from_dictionary(bridge_state.to_bridge_dictionary())
	_expect(bridge_restored != null, "Bridge override save must parse.")
	if bridge_restored != null:
		_expect(bridge_restored.get_body_class_override() == "celestial_guard", "Override lost in bridge round-trip.")


func _test_run_state_disk_persistence() -> void:
	_cleanup_disk_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DISK_FIXTURE_ROOT))
	var state = RunStateScript.new()
	state.checkpoint_id = "jade_gate"
	state.embers = 777
	state.focus = 52.0
	state.combat_style = 4
	state.location = "jade_gate:west"
	state.right_hand = "prayer_beads"
	state.left_hand = "talisman_papers"
	state.set_body_class_override("priest_light")
	_expect(state.save_to_path(DISK_RUN_PATH), "Run state must write to a user:// path.")
	_expect(FileAccess.file_exists(DISK_RUN_PATH), "Run state file missing after save.")
	var restored = RunStateScript.load_from_path(DISK_RUN_PATH)
	_expect(restored != null, "Disk load returned null.")
	if restored != null:
		_expect(restored.checkpoint_id == "jade_gate", "Disk round-trip lost checkpoint.")
		_expect(restored.embers == 777, "Disk round-trip lost embers.")
		_expect(is_equal_approx(restored.focus, 52.0), "Disk round-trip lost focus.")
		_expect(restored.combat_style == 4, "Disk round-trip lost combat style.")
		_expect(restored.right_hand == "prayer_beads", "Disk round-trip lost right hand.")
		_expect(restored.get_body_class_override() == "priest_light", "Disk round-trip lost body override.")
	_cleanup_disk_fixture()
	_expect(not FileAccess.file_exists(DISK_RUN_PATH), "Disk fixture must be cleaned up.")


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_SAVE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _cleanup_disk_fixture() -> void:
	_remove_tree(DISK_FIXTURE_ROOT)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
