class_name EmbeddedModelActions
extends Node

const MANIFEST_PATH := "res://resources/model_actions.json"
const MODEL_PREFIX := "res://assets/models/"
const DRIVER_META := &"embedded_model_actions_driver"
const ALIASES := {
	"idle": ["idle"],
	"walk": ["walk", "move", "fly", "flutter"],
	"run": ["run", "walk", "move", "fly", "flutter"],
	"strafe": ["strafe_left", "strafe_right", "walk", "move"],
	"strafe_left": ["strafe_left", "walk", "move", "fly"],
	"strafe_right": ["strafe_right", "walk", "move", "fly"],
	"dodge": ["dodge"],
	"attack_light": ["attack_light", "attack", "slash", "release"],
	"attack_heavy": ["attack_heavy", "attack", "slash"],
	"attack": ["attack", "attack_light", "attack_heavy", "slash", "release"],
	"hit": ["hit"],
	"death": ["death"],
	"cast": ["cast", "activate"],
	"interact": ["interact", "activate", "open"],
}
const ALIAS_KINDS := {
	"idle": "idle", "walk": "locomotion", "run": "locomotion",
	"strafe": "locomotion", "strafe_left": "locomotion", "strafe_right": "locomotion",
	"dodge": "dodge", "attack_light": "attack", "attack_heavy": "attack",
	"attack": "attack", "hit": "hit", "death": "death", "cast": "cast",
	"special": "special", "interact": "interaction",
}

static var _models: Dictionary = {}
static var _manifest_loaded := false

var _animation_player: AnimationPlayer
var _actions: Dictionary = {}
var _default_action := ""
var _special_action := ""
var _current_action := ""
var _last_requested := ""
var _pending_loop := ""
var _busy := false
var _holding_death := false
var _base_speed := 1.0
var _duration_scale := 1.0


static func available(root: Node) -> bool:
	return _driver(root) != null


static func play_action(root: Node, action: String, restart: bool = false, duration: float = 0.0) -> bool:
	var driver := _driver(root)
	return driver._request(action, restart, duration) if driver != null else false


static func reset(root: Node) -> void:
	var driver := _driver(root)
	if driver == null:
		return
	driver._animation_player.stop()
	driver._busy = false
	driver._holding_death = false
	driver._last_requested = ""
	driver._current_action = ""
	driver._pending_loop = ""
	driver._begin(driver._default_action, 0.0)


static func set_speed(root: Node, speed: float) -> void:
	var driver := _driver(root)
	if driver != null and is_finite(speed):
		driver._base_speed = maxf(speed, 0.0)
		driver._animation_player.speed_scale = driver._base_speed * driver._duration_scale


static func bind(wrapper: Node3D, instance: Node3D, relative_glb: String) -> Node:
	if wrapper == null or instance == null:
		return null
	if wrapper != instance and not wrapper.is_ancestor_of(instance):
		return null
	var existing := _driver(wrapper)
	if existing != null:
		return existing
	var entry := _model_entry(relative_glb, instance)
	if entry.is_empty():
		return null
	var driver := EmbeddedModelActions.new()
	driver.name = "EmbeddedModelActions"
	if not driver._configure(instance, entry):
		driver.free()
		return null
	wrapper.set_meta(DRIVER_META, weakref(driver))
	wrapper.add_child(driver)
	return driver


static func select_part(instance: Node3D, part: String, relative_glb: String = "") -> Dictionary:
	var failure := {"ok": false, "anchor": Transform3D.IDENTITY, "meshes": []}
	if instance == null or part.is_empty():
		return failure
	var all_meshes: Array[MeshInstance3D] = []
	_collect_meshes(instance, all_meshes)
	var has_skin := false
	for mesh_instance in all_meshes:
		if mesh_instance.skin != null:
			has_skin = true
			break
	var selected: Array[MeshInstance3D] = []
	var anchor := Transform3D.IDENTITY
	if has_skin:
		var entry := _model_entry(relative_glb, instance)
		var parts: Dictionary = entry.get("parts", {})
		var definition: Dictionary = parts.get(part, {})
		var matrix: Variant = definition.get("transform", [])
		if not _valid_anchor(matrix):
			return failure
		anchor = _anchor_transform(matrix)
		var bone_name := String(definition.get("bone", ""))
		if bone_name.is_empty():
			return failure
		for mesh_instance in all_meshes:
			var membership := _skin_membership(mesh_instance, bone_name)
			if membership < 0:
				return failure
			if membership == 1:
				selected.append(mesh_instance)
	else:
		var target := _find_named(instance, part)
		if target == null:
			return failure
		_collect_meshes(target, selected)
		anchor = _transform_under(instance.get_parent(), target)
	if selected.is_empty():
		return failure
	# Change visibility only after the complete selection has passed validation.
	for mesh_instance in all_meshes:
		mesh_instance.visible = mesh_instance in selected
	return {"ok": true, "anchor": anchor, "meshes": selected}


static func _driver(root: Node) -> EmbeddedModelActions:
	if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
		return null
	if root is EmbeddedModelActions:
		return root if is_instance_valid(root._animation_player) else null
	var cached := root.get_meta(DRIVER_META, null) as WeakRef
	if cached != null:
		var driver := cached.get_ref() as EmbeddedModelActions
		if is_instance_valid(driver) and root.is_ancestor_of(driver) and not driver.is_queued_for_deletion():
			if is_instance_valid(driver._animation_player):
				return driver
	for child in root.get_children():
		var driver := _driver(child)
		if driver != null:
			root.set_meta(DRIVER_META, weakref(driver))
			return driver
	return null


static func _model_entry(relative_glb: String, instance: Node3D) -> Dictionary:
	if not _manifest_loaded:
		if not FileAccess.file_exists(MANIFEST_PATH):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if not parsed is Dictionary or parsed.get("version", 0) != 1 or not parsed.get("models") is Dictionary:
			return {}
		_models = parsed["models"]
		_manifest_loaded = true
	var path := relative_glb if not relative_glb.is_empty() else instance.scene_file_path
	path = path.replace("\\", "/").trim_prefix(MODEL_PREFIX)
	var entry: Variant = _models.get(path, {})
	return entry if entry is Dictionary else {}


static func _valid_anchor(matrix: Variant) -> bool:
	if not matrix is Array or matrix.size() != 16:
		return false
	for value in matrix:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	if absf(float(matrix[3])) > 0.00001 or absf(float(matrix[7])) > 0.00001 or absf(float(matrix[11])) > 0.00001:
		return false
	return absf(float(matrix[15]) - 1.0) < 0.00001 and absf(_anchor_transform(matrix).basis.determinant()) > 0.000001


static func _anchor_transform(matrix: Array) -> Transform3D:
	return Transform3D(Basis(
		Vector3(matrix[0], matrix[1], matrix[2]),
		Vector3(matrix[4], matrix[5], matrix[6]),
		Vector3(matrix[8], matrix[9], matrix[10])
	), Vector3(matrix[12], matrix[13], matrix[14]))


# ARRAY_BONES indexes Skin binds, which may differ from Skeleton3D bone indexes.
# Return -1 for invalid or mixed geometry; hiding a whole mixed mesh loses parts.
static func _skin_membership(mesh_instance: MeshInstance3D, branch: String) -> int:
	if mesh_instance.skin == null:
		return 0
	var skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
	if skeleton == null:
		return -1
	var branch_index := skeleton.find_bone(branch)
	if branch_index < 0:
		return 0
	var skin := mesh_instance.skin
	var belongs: Array[bool] = []
	for index in range(skin.get_bind_count()):
		var bind_name := skin.get_bind_name(index)
		var bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else skin.get_bind_bone(index)
		if bone < 0 or bone >= skeleton.get_bone_count():
			return -1
		var selected := false
		while bone >= 0:
			if bone == branch_index:
				selected = true
				break
			bone = skeleton.get_bone_parent(bone)
		belongs.append(selected)
	var inside := false
	var outside := false
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX:
			return -1
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or bones.size() == 0 or bones.size() != weights.size():
			return -1
		for index in range(bones.size()):
			var weight := float(weights[index])
			if not is_finite(weight) or weight < 0.0:
				return -1
			if weight == 0.0:
				continue
			var bind_index := int(bones[index])
			if bind_index < 0 or bind_index >= belongs.size():
				return -1
			if belongs[bind_index]:
				inside = true
			else:
				outside = true
	if inside and outside:
		return -1
	return 1 if inside else 0


static func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() > 0:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


static func _find_named(node: Node, part: String) -> Node3D:
	if node is Node3D and String(node.name) == part:
		return node
	for child in node.get_children():
		var found := _find_named(child, part)
		if found != null:
			return found
	return null


static func _transform_under(parent: Node, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != parent:
		if current is Node3D:
			transform = current.transform * transform
		current = current.get_parent()
	return transform


func _configure(instance: Node3D, entry: Dictionary) -> bool:
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	for candidate in players:
		var resolved: Dictionary = {}
		for action: Dictionary in entry.get("actions", []):
			var action_name := String(action.get("name", ""))
			var clip := _find_clip(candidate, action_name)
			if not clip.is_empty():
				var data := action.duplicate(true)
				data["clip"] = clip
				resolved[action_name] = data
		var default_action := String(entry.get("default_action", ""))
		if not resolved.has(default_action):
			continue
		_animation_player = candidate
		_actions = resolved
		_default_action = default_action
		_special_action = String(entry.get("special_action", ""))
		break
	if _animation_player == null:
		return false
	_animation_player.autoplay = ""
	_animation_player.stop()
	# Imported AnimationLibrary resources are shared by PackedScene instances.
	for library_name in _animation_player.get_animation_library_list():
		var library := _animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, library)
	for action: Dictionary in _actions.values():
		var animation := _animation_player.get_animation(action["clip"])
		animation.loop_mode = Animation.LOOP_LINEAR if bool(action.get("loop", false)) else Animation.LOOP_NONE
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_animation_player.animation_finished.connect(_on_animation_finished)
	return true


static func _find_clip(player: AnimationPlayer, action: String) -> String:
	if action.is_empty():
		return ""
	if player.has_animation(action):
		return action
	var result := ""
	for clip in player.get_animation_list():
		if String(clip).get_file() == action:
			if not result.is_empty():
				return ""
			result = String(clip)
	return result


func _ready() -> void:
	if _current_action.is_empty():
		_begin(_default_action, 0.0)


func _resolve(action: String) -> String:
	if _actions.has(action):
		return action
	if action == "special" and _actions.has(_special_action):
		return _special_action
	for name in ALIASES.get(action, []):
		if _actions.has(name):
			return name
	var kind := String(ALIAS_KINDS.get(action, ""))
	if not kind.is_empty():
		for name: String in _actions:
			if String(_actions[name].get("kind", "")) == kind:
				return name
	if action == "idle":
		return _default_action
	if action in ["cast", "interact"] and _actions.has(_special_action):
		return _special_action
	return ""


func _request(action: String, restart: bool, duration: float) -> bool:
	var resolved := _resolve(action)
	if resolved.is_empty() or not is_finite(duration) or duration < 0.0:
		return false
	if _holding_death:
		return resolved == _current_action
	if resolved == _last_requested and not restart:
		return true
	_last_requested = resolved
	if _busy and bool(_actions[resolved].get("loop", false)):
		_pending_loop = resolved
		return true
	if resolved == _current_action and not restart:
		return true
	_begin(resolved, duration)
	return true


func _begin(action: String, duration: float) -> void:
	if not is_instance_valid(_animation_player) or not _actions.has(action):
		return
	var data: Dictionary = _actions[action]
	var clip := String(data["clip"])
	var animation := _animation_player.get_animation(clip)
	_current_action = action
	_busy = not bool(data.get("loop", false))
	_holding_death = action == "death" or String(data.get("kind", "")) == "death"
	if not _busy:
		_pending_loop = ""
	_duration_scale = animation.length / duration if duration > 0.0 else 1.0
	_animation_player.active = true
	_animation_player.speed_scale = _base_speed * _duration_scale
	_animation_player.stop()
	_animation_player.play(clip)


func _on_animation_finished(clip: StringName) -> void:
	if not _actions.has(_current_action) or String(_actions[_current_action]["clip"]) != String(clip):
		return
	_busy = false
	if _holding_death:
		return
	var next := _pending_loop if not _pending_loop.is_empty() else _default_action
	_begin(next, 0.0)
