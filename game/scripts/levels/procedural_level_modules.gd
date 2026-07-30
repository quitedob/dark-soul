class_name ProceduralLevelModules
extends RefCounted

const MODULE_IDS: Array[StringName] = [
	&"hazard",
	&"gate_exit",
	&"fragile_floor",
	&"projectile_lane",
	&"poison_fire_zone",
	&"switch_offering",
	&"moving_platform",
	&"illusion_marker",
	&"gravity_visual_zone",
	&"arena_seal",
]


static func has_module(module_id: StringName) -> bool:
	return module_id in MODULE_IDS


static func build(module_id: StringName, config: Dictionary, material: Material) -> Node3D:
	if not has_module(module_id):
		return null
	var root := Node3D.new()
	root.name = _pascal_case(String(module_id))
	root.set_meta("module_id", module_id)
	root.set_meta("module_config", config.duplicate(true))
	match module_id:
		&"hazard":
			_add_area(root, "HazardArea", config.get("size", Vector3(4.0, 0.4, 4.0)), &"hazard", material)
		&"gate_exit":
			_add_body(root, "Gate", config.get("size", Vector3(3.0, 3.0, 0.5)), &"gate", material)
			_add_marker(root, "ExitMarker", config.get("exit_offset", Vector3(0.0, 0.0, -2.0)))
		&"fragile_floor":
			_add_body(root, "FragileFloor", config.get("size", Vector3(4.0, 0.24, 4.0)), &"fragile_floor", material)
			root.set_meta("collapse_delay", float(config.get("collapse_delay", 2.0)))
		&"projectile_lane":
			_add_area(root, "ProjectileLane", config.get("size", Vector3(3.0, 2.0, 12.0)), &"projectile_lane", material)
			_add_marker(root, "ProjectileOrigin", config.get("origin_offset", Vector3(0.0, 1.0, -6.0)))
			root.set_meta("interval", float(config.get("interval", 2.0)))
		&"poison_fire_zone":
			_add_area(root, "DamageZone", config.get("size", Vector3(4.0, 0.3, 4.0)), &"damage_zone", material)
			root.set_meta("damage_type", StringName(config.get("damage_type", &"poison")))
			root.set_meta("damage_per_second", float(config.get("damage_per_second", 8.0)))
		&"switch_offering":
			_add_area(root, "Activator", config.get("size", Vector3(1.0, 1.0, 1.0)), &"switch_offering", material)
			_add_marker(root, "TargetMarker", config.get("target_offset", Vector3(0.0, 0.0, -4.0)))
			root.set_meta("required_count", int(config.get("required_count", 1)))
		&"moving_platform":
			_add_body(root, "Platform", config.get("size", Vector3(4.0, 0.4, 4.0)), &"moving_platform", material, true)
			_add_marker(root, "TravelEnd", config.get("travel", Vector3(0.0, 3.0, 0.0)))
			root.set_meta("travel_time", float(config.get("travel_time", 3.0)))
		&"illusion_marker":
			_add_marker(root, "IllusionMarker", config.get("offset", Vector3.ZERO))
			root.set_meta("illusion_kind", StringName(config.get("illusion_kind", &"false_path")))
		&"gravity_visual_zone":
			_add_area(root, "GravityVisualZone", config.get("size", Vector3(6.0, 4.0, 6.0)), &"gravity_visual", material)
			root.set_meta("visual_direction", config.get("visual_direction", Vector3.UP))
		&"arena_seal":
			_add_area(root, "ArenaTrigger", config.get("size", Vector3(8.0, 3.0, 8.0)), &"arena_trigger", material)
			_add_body(root, "ArenaSeal", config.get("seal_size", Vector3(4.0, 3.0, 0.5)), &"arena_seal", material)
			root.set_meta("encounter_id", StringName(config.get("encounter_id", &"encounter")))
	return root


static func build_level(level_definition: Dictionary, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "LevelModules"
	root.set_meta("level_id", level_definition.get("id", &""))
	root.set_meta("encounter_id", level_definition.get("encounter_id", &""))
	root.set_meta("checkpoint_id", level_definition.get("checkpoint_id", &""))
	var module_ids: Array = level_definition.get("modules", [])
	for index in range(module_ids.size()):
		var module_id := StringName(module_ids[index])
		var config := {}
		if module_id == &"arena_seal":
			config["encounter_id"] = level_definition.get("encounter_id", &"encounter")
		var module := build(module_id, config, material)
		if module != null:
			module.set_meta("module_index", index)
			root.add_child(module)
	return root


static func _add_area(root: Node3D, node_name: String, size: Vector3, module_group: StringName, material: Material) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.add_to_group(module_group)
	_add_shape(area, size)
	_add_visual(area, size, material, 0.28)
	root.add_child(area)


static func _add_body(root: Node3D, node_name: String, size: Vector3, module_group: StringName, material: Material, moving := false) -> void:
	var body: CollisionObject3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.add_to_group(module_group)
	_add_shape(body, size)
	_add_visual(body, size, material, 0.72)
	root.add_child(body)


static func _add_shape(parent: CollisionObject3D, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)


static func _add_visual(parent: Node3D, size: Vector3, material: Material, opacity: float) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	if material is StandardMaterial3D:
		var copy := material.duplicate() as StandardMaterial3D
		copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		copy.albedo_color.a = opacity
		mesh.material = copy
	else:
		mesh.material = material
	visual.mesh = mesh
	parent.add_child(visual)


static func _add_marker(root: Node3D, node_name: String, offset: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = offset
	root.add_child(marker)


static func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_"):
		result += part.capitalize()
	return result
