extends SceneTree
## 第一章垂直切片合约：遭遇表、模块、Boss、出口链、祠堂 ID

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")
const ModuleRuntime = preload("res://scripts/world/campaign_module_runtime.gd")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")
const EnemyFactory = preload("res://scripts/combat/enemy_factory.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_level_chain_and_modules()
	_test_encounters_and_boss()
	_test_boss_phase_parse()
	if _failures.is_empty():
		print("ASHEN_CHAPTER1_SLICE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_level_chain_and_modules() -> void:
	var registry = ContentRegistryScript.new()
	var chain := [
		[&"level_01_01", &"level_01_02", [&"fragile_floor", &"gate_exit"]],
		[&"level_01_02", &"level_01_03", [&"hazard", &"gate_exit"]],
		[&"level_01_03", &"level_01_04", [&"switch_offering", &"gate_exit"]],
		[&"level_01_04", &"level_01_05", [&"poison_fire_zone", &"switch_offering", &"gate_exit"]],
		[&"level_01_05", &"level_02_01", [&"arena_seal"]],
	]
	for entry in chain:
		var level_id: StringName = entry[0]
		var next_id: StringName = entry[1]
		var required_modules: Array = entry[2]
		var level := registry.get_level(level_id)
		_expect(not level.is_empty(), "%s missing from registry." % level_id)
		var modules: Array = level.get("modules", [])
		for module_id in required_modules:
			_expect(module_id in modules, "%s missing module %s." % [level_id, module_id])
		var next_level := registry.get_next_level(level_id)
		_expect(String(next_level.get("id", "")) == String(next_id), "%s next must be %s." % [level_id, next_id])
	var boss := registry.get_boss_for_level(&"level_01_05")
	_expect(String(boss.get("id", "")) == "boss_giant_gate", "boss_giant_gate not registered for chapter 1.")

	var runtime := Runtime.new()
	root.add_child(runtime)
	var generated := runtime.load_level(&"level_01_01")
	_expect(generated != null, "Failed to generate level_01_01.")
	var module_host := ModuleRuntime.new()
	root.add_child(module_host)
	module_host.activate(generated)
	_expect(generated.find_child("GateExitInteract", true, false) != null, "Gate exit interactable was not wired.")
	_expect(generated.find_child("FragileTrigger", true, false) != null, "Fragile floor trigger was not wired.")
	module_host.clear()
	runtime.unload_level()

	var boss_level := runtime.load_level(&"level_01_05")
	_expect(boss_level != null, "Failed to generate level_01_05.")
	module_host.activate(boss_level)
	_expect(boss_level.find_child("ArenaTrigger", true, false) != null, "Arena seal trigger missing.")
	module_host.spawn_victory_exit(boss_level)
	_expect(boss_level.find_child("VictoryExitInteract", true, false) != null, "Victory exit was not spawned.")
	module_host.clear()
	runtime.unload_level()
	module_host.free()
	runtime.free()


func _test_encounters_and_boss() -> void:
	var enemies := Chapter1Content.enemies()
	_expect(enemies.size() >= 4, "Chapter 1 enemy roster too small.")
	_expect(String(enemies[0].get("body_type", "")) == "wraith_thin", "Lost soul body_type missing.")
	var elites := Chapter1Content.elites()
	_expect(elites.size() >= 2, "Chapter 1 elites missing.")
	_expect(String(elites[0].get("appears_in", "")) == "level_01_03", "Mirror elite level mismatch.")
	_expect(String(elites[1].get("appears_in", "")) == "level_01_04", "Elixir elite level mismatch.")
	var boss := Chapter1Content.boss()
	_expect(String(boss.get("id", "")) == "boss_giant_gate", "Boss id mismatch.")
	_expect(boss.has("phases"), "Boss phases missing.")
	var body_root := Node3D.new()
	var weapon_root := Node3D.new()
	EnemyFactory.build_into_slots(body_root, weapon_root, enemies[0], StandardMaterial3D.new(), StandardMaterial3D.new())
	_expect(body_root.get_child_count() > 0, "ChapterEnemyFactory left body empty.")
	body_root.free()
	weapon_root.free()


func _test_boss_phase_parse() -> void:
	# 无场景解析 Boss 阶段阈值与招式
	var enemy = EnemyScript.new()
	enemy._parse_boss_phases(Chapter1Content.boss())
	_expect(is_equal_approx(enemy._content_phase_two_threshold, 0.6), "Boss phase-2 threshold should be 0.6.")
	_expect(enemy._content_phase_attacks.has(1), "Boss phase-1 attacks missing.")
	_expect(enemy._content_phase_attacks.has(2), "Boss phase-2 attacks missing.")
	_expect(not enemy._content_phase_attacks.has(3), "Boss should be two-phase only.")
	enemy.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
