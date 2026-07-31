extends SceneTree
## 第二章垂直切片合约：遭遇表、模块、Boss、出口链、竞技场标记
## Chapter 2 vertical slice contract: encounter table, modules, boss, exit chain, arena markers

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")
const ModuleRuntime = preload("res://scripts/world/campaign_module_runtime.gd")
const Chapter2Content = preload("res://scripts/data/chapter_2_content.gd")
const EnemyFactory = preload("res://scripts/combat/enemy_factory.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_level_chain_and_modules()
	_test_encounters_and_boss()
	_test_boss_phase_parse()
	if _failures.is_empty():
		print("ASHEN_CHAPTER2_SLICE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_level_chain_and_modules() -> void:
	# 校验 02_01 → 02_06 → 03_01 关卡链及各关必带模块
	var registry = ContentRegistryScript.new()
	var chain := [
		[&"level_02_01", &"level_02_02", [&"hazard", &"fragile_floor", &"gate_exit"]],
		[&"level_02_02", &"level_02_03", [&"projectile_lane", &"hazard", &"gate_exit"]],
		[&"level_02_03", &"level_02_04", [&"switch_offering", &"fragile_floor", &"gate_exit"]],
		[&"level_02_04", &"level_02_05", [&"moving_platform", &"switch_offering", &"fragile_floor", &"gate_exit"]],
		[&"level_02_05", &"level_02_06", [&"switch_offering", &"projectile_lane", &"gate_exit"]],
		[&"level_02_06", &"level_03_01", [&"arena_seal"]],
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
	var boss := registry.get_boss_for_level(&"level_02_06")
	_expect(String(boss.get("id", "")) == "boss_xing_tian", "boss_xing_tian not registered for chapter 2.")

	var runtime := Runtime.new()
	root.add_child(runtime)
	var generated := runtime.load_level(&"level_02_01")
	_expect(generated != null, "Failed to generate level_02_01.")
	var module_host := ModuleRuntime.new()
	root.add_child(module_host)
	module_host.activate(generated)
	_expect(generated.find_child("GateExitInteract", true, false) != null, "Gate exit interactable was not wired.")
	_expect(generated.find_child("FragileTrigger", true, false) != null, "level_02_01 fragile floor trigger missing.")
	module_host.clear()
	runtime.unload_level()

	var boss_level := runtime.load_level(&"level_02_06")
	_expect(boss_level != null, "Failed to generate level_02_06.")
	module_host.activate(boss_level)
	_expect(boss_level.find_child("ArenaTrigger", true, false) != null, "Arena seal trigger missing.")
	module_host.spawn_victory_exit(boss_level)
	_expect(boss_level.find_child("VictoryExitInteract", true, false) != null, "Victory exit was not spawned.")
	module_host.clear()
	runtime.unload_level()
	module_host.free()
	runtime.free()


func _test_encounters_and_boss() -> void:
	var enemies := Chapter2Content.enemies()
	_expect(enemies.size() >= 6, "Chapter 2 enemy roster too small.")
	_expect(String(enemies[0].get("id", "")) == "battle_worn_soldier", "First Ch.2 enemy should be battle_worn_soldier.")
	var elites := Chapter2Content.elites()
	_expect(elites.size() >= 3, "Chapter 2 elites missing.")
	_expect(String(elites[0].get("appears_in", "")) == "level_02_02", "Siege Commander elite level mismatch.")
	_expect(String(elites[1].get("appears_in", "")) == "level_02_03", "Torture Master elite level mismatch.")
	_expect(String(elites[2].get("appears_in", "")) == "level_02_04", "Beacon Lord elite level mismatch.")
	var boss := Chapter2Content.boss()
	_expect(String(boss.get("id", "")) == "boss_xing_tian", "Boss id mismatch.")
	_expect(boss.has("phases"), "Boss phases missing.")
	_expect(String(boss.get("body_type", "")) == "elite_armored", "Xing Tian body_type should be elite_armored.")
	var body_root := Node3D.new()
	var weapon_root := Node3D.new()
	EnemyFactory.build_into_slots(body_root, weapon_root, enemies[0], StandardMaterial3D.new(), StandardMaterial3D.new())
	_expect(body_root.get_child_count() > 0, "battle_worn_soldier factory left body empty.")
	body_root.free()
	weapon_root.free()


func _test_boss_phase_parse() -> void:
	# 无场景解析 Boss 三阶段阈值与招式表
	var enemy = EnemyScript.new()
	enemy._parse_boss_phases(Chapter2Content.boss())
	_expect(is_equal_approx(enemy._content_phase_two_threshold, 0.7), "Boss phase-2 threshold should be 0.7.")
	_expect(is_equal_approx(enemy._content_phase_three_threshold, 0.3), "Boss phase-3 threshold should be 0.3.")
	_expect(enemy._content_phase_attacks.has(1), "Boss phase-1 attacks missing.")
	_expect(enemy._content_phase_attacks.has(2), "Boss phase-2 attacks missing.")
	_expect(enemy._content_phase_attacks.has(3), "Boss phase-3 attacks missing.")
	enemy.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
