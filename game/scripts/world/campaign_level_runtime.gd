class_name CampaignLevelRuntime
extends Node3D

signal level_loaded(level_id: StringName, level_root: Node3D)
signal level_unloaded(level_id: StringName)

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const Builder = preload("res://scripts/world/procedural_campaign_level_builder.gd")

var registry = ContentRegistryScript.new()
var current_level_id: StringName = &""
var current_level: Node3D


func load_level(level_id: StringName) -> Node3D:
	var canonical_id := ContentRegistryScript.normalize_level_id(level_id)
	var level_data := registry.get_level(canonical_id)
	if level_data.is_empty():
		push_error("Unknown campaign level: %s" % level_id)
		return null
	unload_level()
	current_level = Builder.build(level_data)
	current_level_id = canonical_id
	add_child(current_level)
	level_loaded.emit(current_level_id, current_level)
	return current_level


func unload_level() -> void:
	if current_level == null:
		current_level_id = &""
		return
	var unloaded_id := current_level_id
	remove_child(current_level)
	current_level.free()
	current_level = null
	current_level_id = &""
	level_unloaded.emit(unloaded_id)


func get_spawn_marker() -> Marker3D:
	return _get_marker("Markers/Spawn")


func get_checkpoint_marker() -> Marker3D:
	return _get_marker("Markers/Checkpoint")


func get_exit_marker() -> Marker3D:
	return _get_marker("Markers/Exit")


func get_level_data() -> Dictionary:
	return registry.get_level(current_level_id)


func _get_marker(path: NodePath) -> Marker3D:
	if current_level == null:
		return null
	return current_level.get_node_or_null(path) as Marker3D
