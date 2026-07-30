extends SceneTree
## 第一章垂直切片合约：内容生成、模块激活、出口元数据

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")
const ModuleRuntime = preload("res://scripts/world/campaign_module_runtime.gd")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")
const EnemyFactory = preload("res://scripts/combat/enemy_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	var registry = ContentRegistryScript.new()
	var level := registry.get_level(&"level_01_01")
	_expect(not level.is_empty(), "level_01_01 missing from registry.")
	_expect(String(level.get("purpose", "")) == "movement_and_interaction", "level_01_01 purpose mismatch.")
	var modules: Array = level.get("modules", [])
	_expect(&"gate_exit" in modules, "level_01_01 missing gate_exit module.")
	_expect(&"fragile_floor" in modules, "level_01_01 missing fragile_floor module.")

	var enemies := Chapter1Content.enemies()
	_expect(enemies.size() >= 2, "Chapter 1 enemy roster too small.")
	_expect(String(enemies[0].get("body_type", "")) == "wraith_thin", "Lost soul body_type missing.")

	var body_root := Node3D.new()
	var weapon_root := Node3D.new()
	var body_mat := StandardMaterial3D.new()
	var weapon_mat := StandardMaterial3D.new()
	EnemyFactory.build_into_slots(body_root, weapon_root, enemies[0], body_mat, weapon_mat)
	_expect(body_root.get_child_count() > 0, "ChapterEnemyFactory left body empty.")
	_expect(weapon_root.get_child_count() > 0, "ChapterEnemyFactory left weapon empty.")
	body_root.free()
	weapon_root.free()

	var runtime := Runtime.new()
	root.add_child(runtime)
	var generated := runtime.load_level(&"level_01_01")
	_expect(generated != null, "Failed to generate level_01_01.")
	_expect(runtime.get_exit_marker() != null, "Exit marker missing.")
	var module_host := ModuleRuntime.new()
	root.add_child(module_host)
	module_host.activate(generated)
	var gate_interact := generated.find_child("GateExitInteract", true, false)
	_expect(gate_interact != null, "Gate exit interactable was not wired.")
	_expect(gate_interact.has_method("interact"), "Gate exit interactable lacks interact().")
	var fragile_trigger := generated.find_child("FragileTrigger", true, false)
	_expect(fragile_trigger != null, "Fragile floor trigger was not wired.")

	var next_level := registry.get_next_level(&"level_01_01")
	_expect(String(next_level.get("id", "")) == "level_01_02", "Next level after 01_01 must be 01_02.")

	module_host.clear()
	runtime.unload_level()
	module_host.free()
	runtime.free()

	if _failures.is_empty():
		print("ASHEN_CHAPTER1_SLICE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
