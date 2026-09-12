class_name ProceduralLevelModules
extends RefCounted
## 十类可复用关卡模块族：几何构建 + 配置写入 meta（行为由 CampaignModuleRuntime 激活）

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
	# —— L-16/L-17 扩充谜题族 ——
	&"mirror_light",
	&"valve_shutoff",
	&"celestial_dial",
	&"alchemy_ingredients",
	&"gravity_anchor",
	&"gravity_inversion",
	&"riddle_gate",
	&"stealth_passage",
	&"memory_verification",
	&"soul_forger_trial",
]

## H-04 装饰放置表：prop/<slug> 真模型（L-18 注册的 8 个 GLB）按模块族放置。
## 每项 {slug, pos 局部偏移, yaw}。config["props"] 可整体覆盖族默认列表；
## try_instance 对未注册/缺失资源安全回落（不报错）。
const PROP_DECOR := {
	&"gate_exit": [
		{"slug": "bridge_tea", "pos": Vector3(0.0, 0.0, 2.4), "yaw": 0.0},
		{"slug": "ember_shrine", "pos": Vector3(-2.6, 0.0, 0.6), "yaw": 45.0},
	],
	&"hazard": [
		{"slug": "traps", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, -1.2), "yaw": 90.0},
	],
	&"poison_fire_zone": [
		{"slug": "traps", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"fragile_floor": [
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"projectile_lane": [
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, -4.5), "yaw": 0.0},
	],
	&"switch_offering": [
		{"slug": "puzzle_props", "pos": Vector3(0.0, 0.0, -4.0), "yaw": 0.0},
		{"slug": "pickups", "pos": Vector3(0.0, 0.0, 2.2), "yaw": 0.0},
	],
	&"moving_platform": [
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"illusion_marker": [
		{"slug": "lost_echo", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, 1.4), "yaw": 0.0},
	],
	&"gravity_visual_zone": [
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"arena_seal": [
		{"slug": "ember_shrine", "pos": Vector3(0.0, 0.0, -3.2), "yaw": 0.0},
		{"slug": "forge_and_anvil", "pos": Vector3(2.8, 0.0, 0.0), "yaw": 90.0},
	],
	&"mirror_light": [
		{"slug": "puzzle_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"valve_shutoff": [
		{"slug": "forge_and_anvil", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"celestial_dial": [
		{"slug": "puzzle_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"alchemy_ingredients": [
		{"slug": "puzzle_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		{"slug": "pickups", "pos": Vector3(0.0, 0.0, 2.4), "yaw": 0.0},
	],
	&"gravity_anchor": [
		{"slug": "puzzle_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"gravity_inversion": [
		{"slug": "ambient_props", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
	],
	&"riddle_gate": [
		{"slug": "lost_echo", "pos": Vector3(0.0, 0.0, 3.0), "yaw": 0.0},
		{"slug": "puzzle_props", "pos": Vector3(0.0, 0.0, 1.0), "yaw": 0.0},
	],
	&"stealth_passage": [
		{"slug": "traps", "pos": Vector3(0.0, 0.0, -3.0), "yaw": 0.0},
	],
	&"memory_verification": [
		{"slug": "lost_echo", "pos": Vector3(0.0, 0.0, 4.0), "yaw": 0.0},
	],
	&"soul_forger_trial": [
		{"slug": "forge_and_anvil", "pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		{"slug": "ember_shrine", "pos": Vector3(0.0, 0.0, -3.0), "yaw": 0.0},
	],
}


static func has_module(module_id: StringName) -> bool:
	return module_id in MODULE_IDS


static func build(module_id: StringName, config: Dictionary, material: Material) -> Node3D:
	if not has_module(module_id):
		return null
	var root := Node3D.new()
	root.name = _pascal_case(String(module_id))
	root.set_meta("module_id", module_id)
	root.set_meta("module_config", config.duplicate(true))
	root.set_meta("visual_theme", String(config.get("visual_theme", "theme_spirit_ruins")))
	match module_id:
		&"hazard":
			_add_area(root, "HazardArea", config.get("size", Vector3(4.0, 0.4, 4.0)), &"hazard", material)
			# 伤害区参数：章节 polish 可覆盖
			root.set_meta("damage_per_second", float(config.get("damage_per_second", 8.0)))
			root.set_meta("damage_type", StringName(config.get("damage_type", &"ember")))
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
			root.set_meta("damage", float(config.get("damage", 12.0)))
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
			_add_area(root, "IllusionSense", config.get("size", Vector3(3.0, 2.0, 3.0)), &"illusion_sense", material)
			root.set_meta("illusion_kind", StringName(config.get("illusion_kind", &"false_path")))
		&"gravity_visual_zone":
			_add_area(root, "GravityVisualZone", config.get("size", Vector3(6.0, 4.0, 6.0)), &"gravity_visual", material)
			root.set_meta("visual_direction", config.get("visual_direction", Vector3.UP))
		&"arena_seal":
			_add_area(root, "ArenaTrigger", config.get("size", Vector3(8.0, 3.0, 8.0)), &"arena_trigger", material)
			_add_body(root, "ArenaSeal", config.get("seal_size", Vector3(4.0, 3.0, 0.5)), &"arena_seal", material)
			root.set_meta("encounter_id", StringName(config.get("encounter_id", &"encounter")))
		# —— L-17 谜题扩充 ——
		&"mirror_light":
			_add_body(root, "MirrorBody", config.get("size", Vector3(1.2, 2.2, 0.3)), &"mirror_light", material)
			_add_area(root, "LightBeam", config.get("beam_size", Vector3(1.0, 1.2, 6.0)), &"light_beam", material)
			_add_marker(root, "ReceptorMarker", config.get("receptor_offset", Vector3(0.0, 0.0, 6.0)))
			root.set_meta("charge_seconds", float(config.get("charge_seconds", 1.6)))
		&"valve_shutoff":
			_add_body(root, "ValveBody", config.get("size", Vector3(0.8, 1.6, 0.8)), &"valve_shutoff", material)
			_add_area(root, "ValveHazardZone", config.get("zone_size", Vector3(5.0, 0.4, 5.0)), &"damage_zone", material)
			root.set_meta("damage_type", StringName(config.get("damage_type", &"poison")))
			root.set_meta("damage_per_second", float(config.get("damage_per_second", 8.0)))
		&"celestial_dial":
			_add_body(root, "DialBody", config.get("size", Vector3(2.0, 2.0, 0.4)), &"celestial_dial", material)
			_add_body(root, "CelestialGate", config.get("gate_size", Vector3(3.0, 3.0, 0.5)), &"gate", material)
			root.set_meta("required_turns", int(config.get("required_turns", 3)))
			# H-04：对齐后需在星带处充能锁定（机关响应差异，见 runtime _make_charge_zone）
			_add_marker(root, "StarbandCharge", config.get("charge_offset", Vector3.ZERO))
		&"alchemy_ingredients":
			_add_body(root, "IngredientStation", config.get("size", Vector3(1.2, 1.8, 1.2)), &"alchemy_ingredients", material)
			_add_body(root, "AlchemyGate", config.get("gate_size", Vector3(3.0, 3.0, 0.5)), &"gate", material)
			root.set_meta("required_count", int(config.get("required_count", 3)))
			# H-04：房间内原料刷新点（生成配置差异，runtime 在标记处生成采集物）
			_add_ingredient_spawns(root, config)
		&"gravity_anchor":
			_add_body(root, "AnchorBody", config.get("size", Vector3(1.0, 1.4, 1.0)), &"gravity_anchor", material)
			_add_area(root, "AnchorTarget", config.get("zone_size", Vector3(7.0, 6.0, 7.0)), &"gravity_zone", material)
			root.set_meta("invert_direction", config.get("invert_direction", Vector3.DOWN))
		&"gravity_inversion":
			_add_area(root, "InvertZone", config.get("size", Vector3(6.0, 4.0, 6.0)), &"gravity_zone", material)
			root.set_meta("invert_direction", config.get("invert_direction", Vector3.DOWN))
		&"riddle_gate":
			_add_body(root, "RiddleGate", config.get("gate_size", Vector3(3.0, 3.0, 0.5)), &"gate", material)
			root.set_meta("correct_index", int(config.get("correct_index", 0)))
			root.set_meta("riddle_question", String(config.get("riddle_question", "WHICH PATH IS TRUE?")))
			_add_riddle_answers(root, config)
		&"stealth_passage":
			_add_area(root, "AlarmZone", config.get("alarm_size", Vector3(6.0, 3.0, 2.0)), &"stealth_alarm", material)
			_add_body(root, "StealthGate", config.get("gate_size", Vector3(3.0, 3.0, 0.5)), &"gate", material)
			_add_marker(root, "StealthExit", config.get("exit_offset", Vector3(0.0, 0.0, -5.0)))
			root.set_meta("alarm_damage", float(config.get("alarm_damage", 10.0)))
		&"memory_verification":
			_add_body(root, "VerificationGate", config.get("gate_size", Vector3(3.0, 3.0, 0.5)), &"gate", material)
			root.set_meta("correct_choice", String(config.get("correct_choice", "true")))
			_add_marker(root, "TrueMarker", config.get("true_offset", Vector3(-2.0, 0.0, 4.0)))
			_add_marker(root, "FalseMarker", config.get("false_offset", Vector3(2.0, 0.0, 4.0)))
		&"soul_forger_trial":
			_add_area(root, "TrialTrigger", config.get("trigger_size", Vector3(8.0, 3.0, 8.0)), &"soul_forger_trial", material)
			_add_body(root, "TrialSeal", config.get("seal_size", Vector3(4.0, 3.0, 0.5)), &"arena_seal", material)
			_add_area(root, "TrialAura", config.get("aura_size", Vector3(6.0, 3.0, 6.0)), &"trial_aura", material)
			root.set_meta("trial_duration", float(config.get("trial_duration", 12.0)))
			root.set_meta("trial_dps", float(config.get("trial_dps", 6.0)))
	# —— H-04 行为抛光：每族独立行为特征（meta 由 CampaignModuleRuntime 消费）+ prop/ 真模型装饰 ——
	_apply_behavior_traits(root, module_id, config)
	_place_props(root, module_id, config)
	return root


static func build_level(level_definition: Dictionary, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "LevelModules"
	root.set_meta("level_id", level_definition.get("id", &""))
	root.set_meta("encounter_id", level_definition.get("encounter_id", &""))
	root.set_meta("checkpoint_id", level_definition.get("checkpoint_id", &""))
	var module_ids: Array = level_definition.get("modules", [])
	var configs: Dictionary = level_definition.get("module_configs", {})
	for index in range(module_ids.size()):
		var module_id := StringName(module_ids[index])
		var config := _config_for(configs, module_id)
		config["visual_theme"] = level_definition.get("theme_id", &"theme_spirit_ruins")
		if module_id == &"arena_seal":
			config["encounter_id"] = level_definition.get("encounter_id", &"encounter")
		var module := build(module_id, config, material)
		if module != null:
			module.set_meta("module_index", index)
			root.add_child(module)
	return root


static func _config_for(configs: Dictionary, module_id: StringName) -> Dictionary:
	# 同时兼容 String / StringName 键
	if configs.has(module_id):
		return (configs[module_id] as Dictionary).duplicate(true)
	var key := String(module_id)
	if configs.has(key):
		return (configs[key] as Dictionary).duplicate(true)
	return {}


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
	add_solid_visual(body, size, String(root.get_meta("visual_theme")), material)
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


## Visual-only entry for module bodies and runtime-created ceiling slabs. Geometry
## stays inside the existing box envelope; all collision and runtime paths survive.
static func add_solid_visual(parent: Node3D, size: Vector3, theme: String = "theme_spirit_ruins", _legacy_material: Material = null) -> void:
	var palette := _module_palette(theme)
	var label := String(parent.name)
	if label.contains("Gate") or label.contains("Seal") or label == "DoorBody":
		_gate_visual(parent, size, palette, theme)
	elif label == "CeilingSurface" or size.y < minf(size.x, size.z) * 0.35:
		_slab_visual(parent, size, palette, label == "FragileFloor")
	else:
		_device_visual(parent, size, palette, label)
	_merge_visual_materials(parent)


static func _module_palette(theme: String) -> Array[StandardMaterial3D]:
	# Display-space colors follow the five authored campaign kits. Separate dark
	# recesses, stone/wood, metal and restrained emissive inlays read under daylight.
	var colors: Array[Color] = [Color("303936"), Color("4d5144"), Color("8e7144"), Color("76a69b")]
	match theme:
		"theme_blood_iron":
			colors = [Color("291f1c"), Color("503a2e"), Color("8a4b30"), Color("c77b34")]
		"theme_jade_veil":
			colors = [Color("193a32"), Color("355b48"), Color("9c8552"), Color("73c8a2")]
		"theme_celestial_fall":
			colors = [Color("273d42"), Color("536f6c"), Color("ba9551"), Color("a4d7d3")]
		"theme_ember_abyss":
			colors = [Color("1c1924"), Color("38303d"), Color("79533b"), Color("da6731")]
	var result: Array[StandardMaterial3D] = []
	for index in colors.size():
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[index]
		material.roughness = 0.82 if index < 2 else 0.43
		material.metallic = 0.0 if index < 2 else 0.62
		if index == 3:
			material.emission_enabled = true
			material.emission = colors[index]
			material.emission_energy_multiplier = 0.35
		result.append(material)
	return result


static func _gate_visual(parent: Node3D, size: Vector3, p: Array[StandardMaterial3D], theme: String) -> void:
	var half := size * 0.5
	var edge := minf(size.x * 0.075, size.y * 0.09)
	# Two closed leaves preserve the solid barrier silhouette. A deep center seam,
	# raised rails and inset panels communicate an operable door instead of a block.
	for side: float in [-1.0, 1.0]:
		_block(parent, Vector3(side * size.x * 0.25, 0, 0), Vector3(size.x * 0.495, size.y, size.z * 0.64), p[0])
		for face: float in [-1.0, 1.0]:
			var z := face * (half.z - size.z * 0.11)
			for row in 3:
				var y := (float(row) - 1.0) * size.y * 0.29
				_block(parent, Vector3(side * size.x * 0.25, y, z), Vector3(size.x * 0.35, size.y * 0.25, size.z * 0.13), p[1])
			for x: float in [side * (half.x - edge * 0.5), side * edge * 0.45]:
				_block(parent, Vector3(x, 0, z), Vector3(edge * 0.72, size.y, size.z * 0.19), p[2])
			for y: float in [-half.y + edge * 0.5, 0.0, half.y - edge * 0.5]:
				_block(parent, Vector3(side * size.x * 0.25, y, z), Vector3(size.x * 0.48, edge * 0.65, size.z * 0.20), p[2])
			for row in 5:
				var y := -size.y * 0.38 + float(row) * size.y * 0.19
				_cylinder(parent, Vector3(side * (half.x - edge * 0.5), y, face * (half.z - size.z * 0.04)), edge * 0.20, size.z * 0.08, p[2], Vector3(PI * 0.5, 0, 0), 8)
			var ring_radius := minf(size.x, size.y) * 0.085
			_ring(parent, Vector3(side * size.x * 0.10, -size.y * 0.03, face * (half.z - size.z * 0.05)), ring_radius, minf(ring_radius * 0.14, size.z * 0.045), p[2], true)
			# Jade/cloud seals use circular inlays; iron/ember leaves use a riveted
			# diamond sigil, giving each chapter more than a palette swap.
			if theme in ["theme_jade_veil", "theme_celestial_fall"]:
				_ring(parent, Vector3(side * size.x * 0.25, size.y * 0.29, z + face * size.z * 0.07), size.x * 0.11, edge * 0.09, p[3], true)
			else:
				var rune := _block(parent, Vector3(side * size.x * 0.25, size.y * 0.29, z + face * size.z * 0.07), Vector3(edge * 0.8, edge * 0.8, size.z * 0.04), p[3])
				rune.rotation.z = PI * 0.25


static func _slab_visual(parent: Node3D, size: Vector3, p: Array[StandardMaterial3D], cracked: bool) -> void:
	_block(parent, Vector3.ZERO, Vector3(size.x, size.y * 0.78, size.z), p[0])
	var rim := minf(size.x, size.z) * 0.07
	for side: float in [-1.0, 1.0]:
		_block(parent, Vector3(side * (size.x - rim) * 0.5, size.y * 0.40, 0), Vector3(rim, size.y * 0.20, size.z), p[2])
		_block(parent, Vector3(0, size.y * 0.40, side * (size.z - rim) * 0.5), Vector3(size.x - rim * 2.0, size.y * 0.20, rim), p[2])
	var tile := Vector3((size.x - rim * 2.0) / 3.0, size.y * 0.20, (size.z - rim * 2.0) / 3.0)
	for x in 3:
		for z in 3:
			var piece := _block(parent, Vector3((x - 1) * tile.x, size.y * 0.40, (z - 1) * tile.z), Vector3(tile.x * 0.98, tile.y, tile.z * 0.98), p[1])
			if cracked and (x + z) % 2 == 0:
				piece.rotation.y = 0.012 * (x - z)


static func _device_visual(parent: Node3D, size: Vector3, p: Array[StandardMaterial3D], label: String) -> void:
	var width := minf(size.x, size.z)
	var base_y := -size.y * 0.5
	# Solid, chamfered plinth and pedestal stay within the original collision box.
	_block(parent, Vector3(0, base_y + size.y * 0.08, 0), Vector3(size.x, size.y * 0.16, size.z), p[0])
	if label in ["MirrorBody", "DialBody"]:
		_block(parent, Vector3(0, size.y * 0.02, 0), Vector3(size.x * 0.80, size.y * 0.78, size.z * 0.72), p[0])
		for face: float in [-1.0, 1.0]:
			var z := face * size.z * 0.44
			if label == "MirrorBody":
				_block(parent, Vector3(0, size.y * 0.04, z), Vector3(size.x * 0.68, size.y * 0.68, size.z * 0.08), p[3])
				for side: float in [-1.0, 1.0]:
					_block(parent, Vector3(side * size.x * 0.40, size.y * 0.04, z), Vector3(size.x * 0.10, size.y * 0.80, size.z * 0.12), p[2])
					_block(parent, Vector3(0, side * size.y * 0.37 + size.y * 0.04, z), Vector3(size.x * 0.89, size.y * 0.06, size.z * 0.12), p[2])
			else:
				var radius := minf(size.x, size.y) * 0.37
				_ring(parent, Vector3(0, size.y * 0.04, z), radius, minf(radius * 0.10, size.z * 0.055), p[2], true)
				_ring(parent, Vector3(0, size.y * 0.04, z), radius * 0.63, minf(radius * 0.035, size.z * 0.055), p[3], true)
				for index in 8:
					var angle := TAU * index / 8.0
					var tick := _block(parent, Vector3(cos(angle) * radius * 0.83, sin(angle) * radius * 0.83 + size.y * 0.04, z), Vector3(radius * 0.19, radius * 0.04, size.z * 0.04), p[2])
					tick.rotation.z = angle
	else:
		_cylinder(parent, Vector3(0, -size.y * 0.10, 0), width * 0.31, size.y * 0.63, p[1], Vector3.ZERO, 12)
		for y: float in [-size.y * 0.32, size.y * 0.12]:
			_ring(parent, Vector3(0, y, 0), width * 0.34, width * 0.055, p[2])
		if label == "ValveBody":
			var at := Vector3(0, size.y * 0.20, size.z * 0.37)
			_ring(parent, at, width * 0.32, width * 0.045, p[2], true)
			for index in 4:
				var spoke := _block(parent, at, Vector3(width * 0.57, width * 0.055, width * 0.055), p[2])
				spoke.rotation.z = index * PI * 0.25
		elif label == "IngredientStation":
			_cylinder(parent, Vector3(0, size.y * 0.26, 0), width * 0.40, size.y * 0.25, p[2], Vector3.ZERO, 16)
			_cylinder(parent, Vector3(0, size.y * 0.39, 0), width * 0.30, size.y * 0.025, p[3], Vector3.ZERO, 16)
		else:
			var crystal := _block(parent, Vector3(0, size.y * 0.30, 0), Vector3(width * 0.34, size.y * 0.29, width * 0.34), p[3])
			crystal.rotation.y = PI * 0.25


static func _block(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var half := size * 0.5
	var bevel := minf(minf(size.x, size.y), size.z) * 0.13
	var rings: Array[PackedVector3Array] = []
	for index in 4:
		var inset := bevel if index == 0 or index == 3 else 0.0
		var x := half.x - inset
		var z := half.z - inset
		var y: float = [-half.y, -half.y + bevel, half.y - bevel, half.y][index]
		var cut := minf(x, z) * 0.18
		rings.append(PackedVector3Array([Vector3(-x + cut,y,-z), Vector3(x - cut,y,-z), Vector3(x,y,-z + cut), Vector3(x,y,z - cut), Vector3(x - cut,y,z), Vector3(-x + cut,y,z), Vector3(-x,y,z - cut), Vector3(-x,y,-z + cut)]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 3:
		for index in 8:
			var next := (index + 1) % 8
			_face(surface, rings[ring][index], rings[ring + 1][index], rings[ring + 1][next])
			_face(surface, rings[ring][index], rings[ring + 1][next], rings[ring][next])
	for index in 8:
		var next := (index + 1) % 8
		_face(surface, Vector3(0,-half.y,0), rings[0][index], rings[0][next])
		_face(surface, Vector3(0,half.y,0), rings[3][next], rings[3][index])
	return _mesh_piece(parent, surface.commit(), at, material)


static func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot uses clockwise front faces; normals follow the outward face vector.
	var normal := (b - a).cross(c - a).normalized()
	for vertex: Vector3 in [a, c, b]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)


static func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3.ZERO, sides: int = 16) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	_mesh_piece(parent, mesh, at, material).rotation = rotation


static func _ring(parent: Node3D, at: Vector3, radius: float, thickness: float, material: Material, vertical := false) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - thickness, 0.01)
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 6
	var visual := _mesh_piece(parent, mesh, at, material)
	if vertical:
		visual.rotation.x = PI * 0.5


static func _mesh_piece(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
	return visual


static func _merge_visual_materials(parent: Node3D) -> void:
	# Runtime hides/fades direct MeshInstance children. Preserve that contract and
	# batch all framing/panels/rivets into at most four draw calls per device.
	var surfaces: Dictionary = {}
	for child in parent.get_children():
		if child is not MeshInstance3D:
			continue
		var material: Material = child.material_override
		if not surfaces.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[material] = surface
		(surfaces[material] as SurfaceTool).append_from(child.mesh, 0, child.transform)
		child.free()
	for material: Material in surfaces:
		var surface: SurfaceTool = surfaces[material]
		_mesh_piece(parent, surface.commit(), Vector3.ZERO, material).name = "ModuleDetail"


## All story props are grounded at local y=0 and contain meshes only. The host's
## interaction area, callback, save identity and removal lifecycle remain its own.
static func add_story_visual(parent: Node3D, kind: String, theme: String = "theme_ember_abyss") -> Node3D:
	var root := Node3D.new()
	root.name = "StoryVisual"
	parent.add_child(root)
	var p := _module_palette(theme)
	match kind:
		"bell_portal":
			for side: float in [-1.0, 1.0]:
				_block(root, Vector3(side * 0.94, 0.12, 0), Vector3(0.48, 0.24, 0.56), p[0])
				_cylinder(root, Vector3(side * 0.94, 1.27, 0), 0.16, 2.30, p[1], Vector3.ZERO, 12)
				for y: float in [0.27, 0.47, 2.10, 2.30]:
					_ring(root, Vector3(side * 0.94, y, 0), 0.17, 0.032, p[2])
			# Segmented, curved arch and roof ribs leave a clear central opening.
			for index in 16:
				var a := PI * float(index) / 16.0
				var b := PI * float(index + 1) / 16.0
				_beam(root, Vector3(cos(a) * 0.94, 2.18 + sin(a) * 0.70, 0), Vector3(cos(b) * 0.94, 2.18 + sin(b) * 0.70, 0), 0.15, p[2])
			for row in 3:
				for index in 8:
					var x := (float(index) - 3.5) * 0.30
					var y := 3.03 + 0.12 * pow(absf(x), 2.0) - row * 0.10
					_block(root, Vector3(x, y, (row - 1) * 0.19), Vector3(0.33, 0.10, 0.25), p[1])
			# Bell with flared lip, suspension link and a visible hanging clapper.
			_ring(root, Vector3(0, 2.70, 0), 0.09, 0.028, p[2], true)
			var bell := CylinderMesh.new()
			bell.top_radius = 0.14
			bell.bottom_radius = 0.30
			bell.height = 0.43
			bell.radial_segments = 24
			_mesh_piece(root, bell, Vector3(0, 2.43, 0), p[2])
			_ring(root, Vector3(0, 2.21, 0), 0.28, 0.04, p[2])
			_crystal(root, Vector3(0, 2.12, 0), 0.08, 0.25, p[3])
		"crystal_shrine":
			_story_plinth(root, p, 0.57)
			_cylinder(root, Vector3(0, 0.46, 0), 0.26, 0.62, p[1], Vector3.ZERO, 8)
			_ring(root, Vector3(0, 0.72, 0), 0.36, 0.06, p[2])
			_crystal(root, Vector3(0, 1.10, 0), 0.24, 0.83, p[3])
			for index in 3:
				var a := TAU * index / 3.0
				_crystal(root, Vector3(cos(a) * 0.31, 0.86, sin(a) * 0.31), 0.09, 0.34, p[1])
		"memory_rings":
			_story_plinth(root, p, 0.63)
			_cylinder(root, Vector3(0, 0.32, 0), 0.28, 0.37, p[1], Vector3.ZERO, 12)
			for index in 3:
				var mesh := TorusMesh.new()
				mesh.inner_radius = 0.45 + index * 0.045
				mesh.outer_radius = mesh.inner_radius + 0.05
				mesh.rings = 32
				mesh.ring_segments = 8
				_mesh_piece(root, mesh, Vector3(0, 0.99, 0), p[2]).rotation = Vector3(PI * 0.5, index * PI / 3.0, 0.25 * index)
			_crystal(root, Vector3(0, 0.99, 0), 0.16, 0.54, p[3])
		"nine_stone_memorial":
			_story_plinth(root, p, 0.91)
			for index in 9:
				var a := TAU * index / 9.0
				var h := 0.55 + 0.10 * (index % 3)
				var at := Vector3(cos(a) * 0.66, 0.17 + h * 0.5, sin(a) * 0.66)
				var stone := _block(root, at, Vector3(0.23, h, 0.25), p[1])
				stone.rotation.y = -a
				_crystal(root, at + Vector3(0, h * 0.26, 0), 0.06, 0.15, p[3])
			_cylinder(root, Vector3(0, 0.36, 0), 0.21, 0.40, p[2], Vector3.ZERO, 12)
			_ring(root, Vector3(0, 0.55, 0), 0.21, 0.032, p[3])
		"tea_cup":
			_story_plinth(root, p, 0.43)
			_cylinder(root, Vector3(0, 0.39, 0), 0.18, 0.50, p[1], Vector3.ZERO, 12)
			_cylinder(root, Vector3(0, 0.67, 0), 0.40, 0.10, p[1], Vector3.ZERO, 24)
			_cylinder(root, Vector3(0, 0.75, 0), 0.23, 0.045, p[2], Vector3.ZERO, 24)
			var cup := CylinderMesh.new()
			cup.top_radius = 0.16
			cup.bottom_radius = 0.09
			cup.height = 0.19
			cup.radial_segments = 24
			_mesh_piece(root, cup, Vector3(0, 0.86, 0), p[1])
			_ring(root, Vector3(0, 0.96, 0), 0.15, 0.02, p[2])
			_cylinder(root, Vector3(0, 0.963, 0), 0.13, 0.008, p[0], Vector3.ZERO, 24)
			_ring(root, Vector3(0.16, 0.87, 0), 0.065, 0.018, p[2], true)
		_:
			push_error("Unknown story prop visual: " + kind)
	_merge_visual_materials(root)
	return root


static func _story_plinth(parent: Node3D, p: Array[StandardMaterial3D], radius: float) -> void:
	_cylinder(parent, Vector3(0, 0.075, 0), radius, 0.15, p[0], Vector3.ZERO, 12)
	_ring(parent, Vector3(0, 0.14, 0), radius * 0.85, radius * 0.035, p[2])


static func _beam(parent: Node3D, from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var direction := to - from
	var mesh := CylinderMesh.new()
	mesh.top_radius = width * 0.5
	mesh.bottom_radius = width * 0.5
	mesh.height = direction.length()
	mesh.radial_segments = 8
	var visual := _mesh_piece(parent, mesh, (from + to) * 0.5, material)
	visual.quaternion = Quaternion(Vector3.UP, direction.normalized())


static func _crystal(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 6:
		var a := TAU * index / 6.0
		var b := TAU * (index + 1) / 6.0
		var left := Vector3(cos(a) * radius, -height * 0.10, sin(a) * radius)
		var right := Vector3(cos(b) * radius, -height * 0.10, sin(b) * radius)
		_face(surface, left, Vector3.UP * height * 0.5, right)
		_face(surface, left, right, Vector3.DOWN * height * 0.5)
	_mesh_piece(parent, surface.commit(), at, material)


static func _add_marker(root: Node3D, node_name: String, offset: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = offset
	root.add_child(marker)


static func _add_riddle_answers(root: Node3D, config: Dictionary) -> void:
	# 谜语答题石：Answer1..N 标记点（答案文本/下标写入 meta，由运行时接线）
	var answers: Array = config.get("answers", ["STONE OF FIRE", "STONE OF ASH", "STONE OF EMBER"])
	var offsets: Array = config.get(
		"answer_offsets",
		[Vector3(-2.5, 0.0, 3.0), Vector3(0.0, 0.0, 3.0), Vector3(2.5, 0.0, 3.0)]
	)
	for index in range(answers.size()):
		var marker := Marker3D.new()
		marker.name = "Answer%d" % (index + 1)
		marker.position = offsets[index] if index < offsets.size() else Vector3(0.0, 0.0, 3.0)
		marker.set_meta("answer_index", index)
		marker.set_meta("answer_text", String(answers[index]))
		root.add_child(marker)


static func _add_ingredient_spawns(root: Node3D, config: Dictionary) -> void:
	# 炼丹配料族：围绕炉台布置原料刷新点（IngredientSpawnN），runtime 在此生成采集物
	var count := maxi(int(config.get("required_count", 3)), 1)
	var offsets: Array = config.get(
		"ingredient_spawn_offsets",
		[
			Vector3(-2.4, 0.0, 1.6),
			Vector3(2.4, 0.0, 1.6),
			Vector3(0.0, 0.0, 3.2),
			Vector3(2.4, 0.0, 2.4),
		]
	)
	for index in range(count):
		var marker := Marker3D.new()
		marker.name = "IngredientSpawn%d" % (index + 1)
		marker.position = offsets[index] if index < offsets.size() else Vector3(0.0, 0.0, 3.0)
		root.add_child(marker)


static func _apply_behavior_traits(root: Node3D, module_id: StringName, config: Dictionary) -> void:
	# H-04 行为抛光：每族独立行为特征写入 meta（CampaignModuleRuntime 消费）。
	# 默认值保持既有行为可预测；chapter polish（campaign_content module_configs）可覆盖。
	match module_id:
		&"hazard":
			# 恒定灼烧场（Ch.1 已抛光行为不变）：danger_pattern constant、无预兆
			root.set_meta("danger_pattern", StringName(config.get("danger_pattern", &"constant")))
			root.set_meta("telegraph", bool(config.get("telegraph", false)))
		&"poison_fire_zone":
			# 毒雾毒焰：脉冲式危险（active/quiet 交替 + 预兆闪烁），与 hazard 恒定场对照
			root.set_meta("danger_pattern", StringName(config.get("danger_pattern", &"pulse")))
			root.set_meta("pulse_on", float(config.get("pulse_on", 1.0)))
			root.set_meta("pulse_off", float(config.get("pulse_off", 0.7)))
		&"gravity_visual_zone":
			# 软重力漂移：持续上推 + 倒置（drift），与 gravity_inversion 硬翻转对照
			root.set_meta("gravity_mode", StringName(config.get("gravity_mode", &"drift")))
			root.set_meta("drift_push", float(config.get("drift_push", 2.4)))
		&"gravity_inversion":
			# 硬翻转：瞬时取反 + 天花面（倒转后可在天花板站立）
			root.set_meta("gravity_mode", StringName(config.get("gravity_mode", &"hard")))
		&"celestial_dial":
			# 天仪：转盘对齐后需在星带充能锁定（sequence），与 alchemy 采集对照
			root.set_meta("solve_kind", StringName(config.get("solve_kind", &"sequence")))
			root.set_meta("lock_seconds", float(config.get("lock_seconds", 2.0)))
		&"alchemy_ingredients":
			# 炼丹：房间内采集原料（collect），与天仪转盘对照
			root.set_meta("solve_kind", StringName(config.get("solve_kind", &"collect")))
		&"moving_platform":
			# 平台运动型线：auto（按行程自动归类 lift/ferry/arc）→ 不同巡逻路径
			root.set_meta("motion_profile", StringName(config.get("motion_profile", &"auto")))
		&"projectile_lane":
			# 弹道廊：齐射前 0.35s 预兆闪烁（危险模式提示）
			root.set_meta("telegraph", bool(config.get("telegraph", true)))


static func _place_props(root: Node3D, module_id: StringName, config: Dictionary) -> void:
	# 装饰放置：在模块根部挂 Props 容器，按族放置 prop/<slug> 真模型。
	# try_instance 已安全（未注册/缺资源返回 false），失败静默回落，不影响可玩性。
	var placements: Variant = config.get("props", PROP_DECOR.get(module_id, []))
	if placements is not Array or placements.is_empty():
		return
	var decor := Node3D.new()
	decor.name = "Props"
	root.add_child(decor)
	for entry in placements:
		if entry is not Dictionary:
			continue
		var slug := String(entry.get("slug", ""))
		if slug.is_empty():
			continue
		var anchor := Node3D.new()
		anchor.name = "Prop_%s" % slug
		anchor.position = entry.get("pos", Vector3.ZERO)
		anchor.rotation.y = deg_to_rad(float(entry.get("yaw", 0.0)))
		decor.add_child(anchor)
		RealModelResolver.try_instance("prop/%s" % slug, anchor)


static func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_"):
		result += part.capitalize()
	return result
