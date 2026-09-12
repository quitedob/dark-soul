class_name AwakeningTempleLayout
extends RefCounted
## The opening temple shares its authored Blender layout with gameplay collision.
## Roofs and ornament remain visual; navigation reads the declared static boxes.

const LEVEL_ID := &"level_01_01"
const MODEL_PATH := "res://assets/environment/awakening_temple/temple.glb"
const MANIFEST_PATH := "res://assets/environment/awakening_temple/layout.json"
const Expansion = preload("res://scripts/world/campaign_expansion_layout.gd")
static var _stitched_meshes: Dictionary = {}


static func expanded_state(data: Dictionary, level: Dictionary) -> Dictionary:
	var cells := walkable_cells(data)
	var state := {"id": String(LEVEL_ID), "theme": String(level["theme_id"]),
		"cells": cells, "cell_set": {}, "ramps": [], "open_edges": {}, "features": [],
		"route": [], "modules": {}, "story_props": [], "encounter_positions": []}
	for cell: Vector3i in cells: state["cell_set"][cell] = true
	state["original_cells"] = state["cell_set"].duplicate()
	for z in range(3, 22): state["route"].append(Vector3i(0, 0, z))
	for id: String in data["modules"]: state["modules"][id] = vector(data["modules"][id])
	for key: String in ["spawn", "checkpoint", "exit"]: state[key] = vector(data["markers"][key])
	for point: Array in data["encounters"]: state["encounter_positions"].append(vector(point))
	Expansion.extend(state, level)
	preload("res://scripts/world/campaign_modeled_layout.gd")._clear_stair_gaps(state)
	cells = []
	for cell: Vector3i in state["cell_set"]: cells.append(cell)
	state["cells"] = cells
	return state


static func read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Required opening temple layout is missing: " + MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary or not _valid_manifest(parsed):
		push_error("Required opening temple layout is invalid: " + MANIFEST_PATH)
		return {}
	return parsed


static func _valid_manifest(data: Dictionary) -> bool:
	if not _number_is_valid(data.get("version")) or not _number_is_valid(data.get("cell_size")):
		return false
	if int(data.get("version", 0)) != 1 or not is_equal_approx(float(data.get("cell_size", 0)), 6.0):
		return false
	if not data.get("walkable_cells") is Array or data["walkable_cells"].is_empty():
		return false
	var unique: Dictionary = {}
	for cell: Variant in data["walkable_cells"]:
		if not _vector_is_valid(cell) or float(cell[1]) != 0.0:
			return false
		for coordinate: Variant in cell:
			if float(coordinate) != roundf(float(coordinate)):
				return false
		var key := str(cell)
		if unique.has(key):
			return false
		unique[key] = true
	for section: String in ["markers", "modules", "landmarks", "shortcuts"]:
		if not data.get(section) is Dictionary:
			return false
	for key: String in ["spawn", "checkpoint", "exit"]:
		if not _vector_is_valid(data["markers"].get(key)):
			return false
	for key: String in ["fragile_floor", "gate_exit"]:
		if not _vector_is_valid(data["modules"].get(key)):
			return false
	for key: String in ["one_way_door", "far_side", "elevator", "shrine_dock"]:
		if not _vector_is_valid(data["shortcuts"].get(key)):
			return false
	for point: Variant in data["landmarks"].values():
		if not _vector_is_valid(point):
			return false
	if not data.get("collision_boxes") is Array or data["collision_boxes"].is_empty():
		return false
	for box: Variant in data["collision_boxes"]:
		if not box is Dictionary or String(box.get("name", "")).is_empty():
			return false
		if not _vector_is_valid(box.get("position")) or not _vector_is_valid(box.get("size")):
			return false
		for dimension: Variant in box["size"]:
			if float(dimension) <= 0.0:
				return false
		if not _number_is_valid(box.get("rotation_x", 0.0)) or not _number_is_valid(box.get("rotation_y", 0.0)):
			return false
	if not data.get("encounters") is Array:
		return false
	for point: Variant in data["encounters"]:
		if not _vector_is_valid(point):
			return false
	return true


static func _vector_is_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	return _number_is_valid(value[0]) and _number_is_valid(value[1]) and _number_is_valid(value[2])


static func _number_is_valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func walkable_cells(data: Dictionary) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for cell: Array in data["walkable_cells"]:
		cells.append(Vector3i(int(cell[0]), int(cell[1]), int(cell[2])))
	return cells


static func add_architecture(root: Node3D, data: Dictionary, expanded: Dictionary = {}) -> bool:
	if not ResourceLoader.exists(MODEL_PATH):
		push_error("Required opening temple model is missing or not imported: " + MODEL_PATH)
		return false
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("Opening temple model must import as a PackedScene: " + MODEL_PATH)
		return false
	var instance := scene.instantiate()
	if not instance is Node3D:
		push_error("Opening temple model requires a Node3D root")
		instance.free()
		return false
	var model := instance as Node3D
	model.name = "AuthoredTemple"
	root.get_node("Geometry").add_child(model)
	var openings := _connection_openings(expanded)
	if not expanded.is_empty():
		var horizon := model.get_node_or_null("Karst_Horizon_Stratified_Cliff")
		if horizon != null:
			model.remove_child(horizon)
			horizon.free()
		_stitch_masonry(model, openings)
	var collision_root := Node3D.new()
	collision_root.name = "ArchitectureCollision"
	root.get_node("Geometry").add_child(collision_root)
	for entry: Dictionary in data["collision_boxes"]:
		if String(entry["name"]) == "Retaining_wall" and _inside_openings(vector(entry["position"]), openings):
			continue
		var body := StaticBody3D.new()
		body.name = String(entry["name"])
		body.collision_layer = 1
		body.position = vector(entry["position"])
		body.rotation = Vector3(float(entry.get("rotation_x", 0.0)), float(entry.get("rotation_y", 0.0)), 0.0)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = vector(entry["size"])
		collision.shape = shape
		body.add_child(collision)
		collision_root.add_child(body)
	root.set_meta("authored_environment", MODEL_PATH)
	root.set_meta("awakening_temple_layout", data.duplicate(true))
	root.set_meta("temple_connection_openings", openings)
	return true


static func _connection_openings(expanded: Dictionary) -> Array[AABB]:
	var result: Array[AABB] = []
	var original: Dictionary = expanded.get("original_cells", {})
	var all_cells: Dictionary = expanded.get("cell_set", {})
	for cell: Vector3i in original:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if original.has(cell + direction) or not all_cells.has(cell + direction): continue
			var center := Vector3(cell.x * 6, 0, -cell.z * 6) + Vector3(direction.x * 3, 1, -direction.z * 3)
			var size := Vector3(1.2, 2.4, 6.1) if direction.x != 0 else Vector3(6.1, 2.4, 1.2)
			result.append(AABB(center - size * .5, size))
	return result


static func _inside_openings(point: Vector3, openings: Array[AABB]) -> bool:
	for box: AABB in openings:
		if box.has_point(point): return true
	return false


static func _stitch_masonry(model: Node3D, openings: Array[AABB]) -> void:
	# The older sanctuary has masonry merged by material. Remove the actual
	# railing triangles at the two new doorways as well as their simple solids.
	# Keep imported normals/materials/UVs and cache the immutable result per layout.
	for node in model.get_children():
		if not node is MeshInstance3D or not String(node.name).begins_with("Masonry_"): continue
		var key := String(node.name) + str(openings)
		if _stitched_meshes.has(key):
			node.mesh = _stitched_meshes[key]
			continue
		var source: Mesh = node.mesh
		var mesh := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in vertices.size(): indices.append(index)
			var kept := PackedInt32Array()
			for index in range(0, indices.size(), 3):
				var center := (vertices[indices[index]] + vertices[indices[index + 1]] + vertices[indices[index + 2]]) / 3.0
				if _inside_openings(node.transform * center, openings): continue
				kept.append(indices[index])
				kept.append(indices[index + 1])
				kept.append(indices[index + 2])
			if kept.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = kept
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, source.surface_get_material(surface))
		_stitched_meshes[key] = mesh
		node.mesh = mesh


static func place_gameplay_nodes(root: Node3D, data: Dictionary) -> void:
	var markers: Dictionary = data["markers"]
	for key: String in ["spawn", "checkpoint", "exit"]:
		var marker := root.get_node("Markers/" + key.capitalize()) as Marker3D
		marker.position = vector(markers[key])
	for module: Node3D in root.get_node("Modules").get_children():
		var id := String(module.get_meta("module_id", ""))
		if data["modules"].has(id):
			module.position = vector(data["modules"][id])
		if id == "gate_exit":
			# The real interaction follows this child, not the campaign exit marker.
			(module.get_node("ExitMarker") as Marker3D).position = vector(markers["exit"]) - module.position
			(module.get_node("Gate") as Node3D).position.y = 1.5
	_place_shortcut_fold(root, data)


static func _place_shortcut_fold(root: Node3D, data: Dictionary) -> void:
	# Return from the west cloister to the entry courtyard. Explicit anchors keep
	# the shortcut stable when the artist adds cells or changes manifest ordering.
	var anchors: Dictionary = data["shortcuts"]
	var door := root.get_node_or_null("ShortcutFold/OneWayDoor") as Node3D
	if door != null:
		door.position = vector(anchors["one_way_door"])
		door.rotation.y = PI * 0.5
		var far: Vector3 = vector(anchors["far_side"])
		(door.get_node("FarSideMarker") as Marker3D).position = door.transform.affine_inverse() * far
	var elevator := root.get_node_or_null("ShortcutFold/ElevatorLift") as Node3D
	if elevator != null:
		elevator.position = vector(anchors["elevator"])
		var dock := vector(anchors["shrine_dock"]) - elevator.position
		elevator.set_meta("shrine_dock_local", dock)
		(elevator.get_node("ShrineDock") as Marker3D).position = dock
