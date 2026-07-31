extends SceneTree

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const Builder = preload("res://scripts/world/procedural_campaign_level_builder.gd")
const Runtime = preload("res://scripts/world/campaign_level_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	var registry = ContentRegistryScript.new()
	var runtime := Runtime.new()
	root.add_child(runtime)
	var levels := registry.get_levels()
	_expect(levels.size() == 29, "Campaign registry must contain 29 levels.")
	var themes: Dictionary = {}
	var signatures: Dictionary = {}
	for level_data in levels:
		var level_id: StringName = level_data["id"]
		themes[level_data["theme_id"]] = true
		var generated := runtime.load_level(level_id)
		_expect(generated != null, "Level %s did not generate." % level_id)
		if generated == null:
			continue
		_expect(runtime.current_level_id == level_id, "Runtime canonical ID mismatch for %s." % level_id)
		_expect(runtime.get_level_data()["id"] == level_id, "Runtime data mismatch for %s." % level_id)
		_expect(runtime.get_spawn_marker() != null, "Level %s has no spawn marker." % level_id)
		_expect(runtime.get_checkpoint_marker() != null, "Level %s has no checkpoint marker." % level_id)
		_expect(runtime.get_exit_marker() != null, "Level %s has no exit marker." % level_id)
		var navigation := generated.get_node_or_null("NavigationSurface") as NavigationRegion3D
		_expect(navigation != null, "Level %s has no navigation surface." % level_id)
		if navigation != null:
			_expect(navigation.navigation_mesh != null, "Level %s has no navigation mesh." % level_id)
			_expect(not navigation.get_meta("walkable_cells", []).is_empty(), "Level %s navigation is empty." % level_id)
		_expect(int(generated.get_meta("walkable_cell_count", 0)) > 0, "Level %s has no geometry." % level_id)
		var signature: String = generated.get_meta("geometry_signature", "")
		var duplicate := Builder.build(level_data)
		_expect(signature == duplicate.get_meta("geometry_signature", "mismatch"), "Level %s is not deterministic." % level_id)
		duplicate.free()
		signatures[level_id] = signature
		runtime.unload_level()
		_expect(runtime.current_level == null, "Level %s did not unload." % level_id)
		_expect(runtime.get_child_count() == 0, "Level %s left runtime children behind." % level_id)
	var legacy_level := runtime.load_level(&"1-1")
	_expect(legacy_level != null, "Legacy runtime lookup failed.")
	_expect(runtime.current_level_id == &"level_01_01", "Legacy runtime lookup did not retain the canonical ID.")
	runtime.unload_level()
	_expect(themes.size() == 5, "Campaign must expose five visual themes.")
	_expect(signatures.size() == 29, "Not every level produced a signature.")
	runtime.free()
	if _failures.is_empty():
		print("CAMPAIGN_GENERATION_OK: 29 levels, 5 themes")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
