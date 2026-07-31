extends SceneTree
## H-04/H-05：十类模块覆盖全部 28 关 + shortcut 空间折叠合约

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const LevelModulesScript = preload("res://scripts/levels/procedural_level_modules.gd")
const BuilderScript = preload("res://scripts/world/procedural_campaign_level_builder.gd")
const ModuleRuntime = preload("res://scripts/world/campaign_module_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	var registry = ContentRegistryScript.new()
	var seen_modules: Dictionary = {}
	var fold_count := 0
	for level in registry.get_levels():
		var level_id := String(level.get("id", ""))
		_expect(level_id.begins_with("level_"), "Non-canonical level ID remains: %s." % level_id)
		_expect(int(level.get("seed", 0)) > 0, "Level %s has no deterministic seed." % level_id)
		var modules: Array = level.get("modules", [])
		_expect(not modules.is_empty(), "Level %s has no module metadata." % level_id)
		for module_id in modules:
			var mid := StringName(module_id)
			_expect(LevelModulesScript.has_module(mid), "Level %s references unknown module %s." % [level_id, module_id])
			seen_modules[String(mid)] = true
		_expect(level.has("module_configs"), "Level %s missing module_configs polish." % level_id)
		_expect(level.has("shortcut_fold"), "Level %s missing shortcut_fold metadata." % level_id)
		_expect(not String(level.get("encounter_id", "")).is_empty(), "Level %s has no encounter ID." % level_id)
		_expect(not String(level.get("checkpoint_id", "")).is_empty(), "Level %s has no checkpoint ID." % level_id)
		var generated := BuilderScript.build(level)
		var module_root := generated.get_node_or_null("Modules")
		_expect(module_root != null, "Level %s did not compose modules." % level_id)
		if module_root != null:
			_expect(module_root.get_child_count() == modules.size(), "Level %s did not build every module." % level_id)
		var fold_meta: Dictionary = level.get("shortcut_fold", {})
		var fold_node := generated.get_node_or_null("ShortcutFold")
		if bool(fold_meta.get("enabled", false)):
			fold_count += 1
			_expect(fold_node != null, "Level %s enabled fold but ShortcutFold missing." % level_id)
			if fold_node != null:
				_expect(fold_node.get_node_or_null("OneWayDoor") != null, "Level %s missing OneWayDoor." % level_id)
				_expect(fold_node.get_node_or_null("ElevatorLift") != null, "Level %s missing ElevatorLift." % level_id)
		else:
			_expect(fold_node == null, "Level %s disabled fold but ShortcutFold present." % level_id)
		generated.free()

	_expect(LevelModulesScript.MODULE_IDS.size() == 10, "Module registry must expose ten families.")
	for module_id in LevelModulesScript.MODULE_IDS:
		_expect(seen_modules.has(String(module_id)), "Module family %s unused across 28 levels." % String(module_id))
	_expect(fold_count >= 18, "Expected most non-boss levels to enable shortcut fold (got %d)." % fold_count)
	_expect(LevelModulesScript.build(&"not_a_module", {}, null) == null, "Unknown module unexpectedly resolved.")

	# 运行时接线：选取含 moving/projectile/illusion/gravity 的关卡
	_verify_runtime_wiring(registry)

	if _failures.is_empty():
		print("ASHEN_LEVEL_MODULE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_runtime_wiring(registry) -> void:
	var runtime_host := ModuleRuntime.new()
	root.add_child(runtime_host)
	var samples := [
		[&"level_02_02", "ProjectileLane"],
		[&"level_02_04", "Platform"],
		[&"level_03_01", "IllusionSense"],
		[&"level_04_03", "GravityVisualZone"],
		[&"level_01_02", "OneWayFarInteract"],
	]
	for sample in samples:
		var level_id: StringName = sample[0]
		var needle: String = sample[1]
		var level: Dictionary = registry.get_level(level_id)
		var generated := BuilderScript.build(level)
		root.add_child(generated)
		runtime_host.activate(generated)
		_expect(generated.find_child(needle, true, false) != null, "%s missing wired node %s." % [String(level_id), needle])
		runtime_host.clear()
		root.remove_child(generated)
		generated.free()
	# Boss 关不应有 ShortcutFold
	var boss_level: Dictionary = registry.get_level(&"level_02_06")
	var boss := BuilderScript.build(boss_level)
	_expect(boss.get_node_or_null("ShortcutFold") == null, "Boss level should not build ShortcutFold.")
	boss.free()
	runtime_host.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
