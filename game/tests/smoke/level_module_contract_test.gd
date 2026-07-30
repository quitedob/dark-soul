extends SceneTree

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const LevelModulesScript = preload("res://scripts/levels/procedural_level_modules.gd")
const BuilderScript = preload("res://scripts/world/procedural_campaign_level_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	var registry = ContentRegistryScript.new()
	for level in registry.get_levels():
		var level_id := String(level.get("id", ""))
		_expect(level_id.begins_with("level_"), "Non-canonical level ID remains: %s." % level_id)
		_expect(int(level.get("seed", 0)) > 0, "Level %s has no deterministic seed." % level_id)
		var modules: Array = level.get("modules", [])
		_expect(not modules.is_empty(), "Level %s has no module metadata." % level_id)
		for module_id in modules:
			_expect(LevelModulesScript.has_module(StringName(module_id)), "Level %s references unknown module %s." % [level_id, module_id])
		_expect(not String(level.get("encounter_id", "")).is_empty(), "Level %s has no encounter ID." % level_id)
		_expect(not String(level.get("checkpoint_id", "")).is_empty(), "Level %s has no checkpoint ID." % level_id)
		var generated := BuilderScript.build(level)
		var module_root := generated.get_node_or_null("Modules")
		_expect(module_root != null, "Level %s did not compose modules." % level_id)
		if module_root != null:
			_expect(module_root.get_child_count() == modules.size(), "Level %s did not build every module." % level_id)
		generated.free()
	_expect(LevelModulesScript.MODULE_IDS.size() == 10, "Module registry must expose ten families.")
	_expect(LevelModulesScript.build(&"not_a_module", {}, null) == null, "Unknown module unexpectedly resolved.")
	if _failures.is_empty():
		print("ASHEN_LEVEL_MODULE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
