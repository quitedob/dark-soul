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
