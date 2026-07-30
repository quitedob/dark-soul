class_name HitStopManager
extends Node

var _remaining_frames: Dictionary = {}


func trigger(source: Node, target: Node, duration_seconds: float, physics_fps := 60.0) -> void:
	var frames := maxi(1, ceili(duration_seconds * physics_fps))
	_freeze(source, frames)
	_freeze(target, frames)


func is_frozen(node: Node) -> bool:
	return is_instance_valid(node) and _remaining_frames.has(node.get_instance_id())


func _physics_process(_delta: float) -> void:
	for instance_id in _remaining_frames.keys():
		var entry: Dictionary = _remaining_frames[instance_id]
		entry["frames"] = int(entry["frames"]) - 1
		if int(entry["frames"]) > 0:
			_remaining_frames[instance_id] = entry
			continue
		var node: Node = entry["node"]
		if is_instance_valid(node) and node.has_method("set_visual_frozen"):
			node.call("set_visual_frozen", false)
		_remaining_frames.erase(instance_id)


func clear() -> void:
	for entry in _remaining_frames.values():
		var node: Node = entry["node"]
		if is_instance_valid(node) and node.has_method("set_visual_frozen"):
			node.call("set_visual_frozen", false)
	_remaining_frames.clear()


func _exit_tree() -> void:
	clear()


func _freeze(node: Node, frames: int) -> void:
	if not is_instance_valid(node) or not node.has_method("set_visual_frozen"):
		return
	var instance_id := node.get_instance_id()
	var current_frames := int(_remaining_frames.get(instance_id, {}).get("frames", 0))
	_remaining_frames[instance_id] = {"node": node, "frames": maxi(frames, current_frames)}
	node.call("set_visual_frozen", true)
