class_name CampaignContent
extends RefCounted


static func chapters() -> Array[Dictionary]:
	return [
		_chapter(&"chapter_01", "灵墟·觉醒 / Spirit Ruins · Awakening", &"theme_spirit_ruins", &"level_01_01", &"level_01_05", [&"boss_giant_gate"]),
		_chapter(&"chapter_02", "血铁·战歌 / Blood & Iron · Warsong", &"theme_blood_iron", &"level_02_01", &"level_02_06", [&"boss_xing_tian"]),
		_chapter(&"chapter_03", "玉障·迷心 / Jade Veil · Lost Mind", &"theme_jade_veil", &"level_03_01", &"level_03_06", [&"boss_nine_tails"]),
		_chapter(&"chapter_04", "天崩·陨落 / Celestial Fall", &"theme_celestial_fall", &"level_04_01", &"level_04_06", [&"boss_xuan_xiao_wrath", &"boss_xuan_xiao_obsession", &"boss_xuan_xiao"]),
		_chapter(&"chapter_05", "烬座·归墟 / Throne of Ashes · Return to Void", &"theme_ember_abyss", &"level_05_01", &"level_05_05", [&"boss_zhu_yin"]),
	]


static func levels() -> Array[Dictionary]:
	var records := [
		_level(&"level_01_01", "苏醒之庭 / Courtyard of Awakening", &"chapter_01", &"courtyard", &"theme_spirit_ruins", &"tutorial", &"movement_and_interaction", &"level_01_02"),
		_level(&"level_01_02", "守门廊 / Gate-Keeper Corridor", &"chapter_01", &"linear_corridor", &"theme_spirit_ruins", &"tutorial", &"dodge_stamina_and_parry", &"level_01_03"),
		_level(&"level_01_03", "明镜殿 / Hall of Mirrored Truth", &"chapter_01", &"multi_angle_hall", &"theme_spirit_ruins", &"tutorial", &"lock_on_spacing_and_styles", &"level_01_04"),
		_level(&"level_01_04", "炼丹房遗迹 / Ruins of the Elixir Hall", &"chapter_01", &"hazard_wing", &"theme_spirit_ruins", &"pre_boss", &"hazards_consumables_and_keys", &"level_01_05"),
		_level(&"level_01_05", "守炉殿·内廷 / Furnace-Keeper Inner Sanctum", &"chapter_01", &"circular_arena", &"theme_spirit_ruins", &"boss", &"chapter_boss", &"level_02_01", &"boss_giant_gate"),
		_level(&"level_02_01", "血染山道 / Blood-Stained Mountain Path", &"chapter_02", &"winding_approach", &"theme_blood_iron", &"combat", &"siege_hazard_introduction", &"level_02_02"),
		_level(&"level_02_02", "铁啸关外墙 / Iron Howl Outer Wall", &"chapter_02", &"layered_ramparts", &"theme_blood_iron", &"combat", &"active_battlefield_traversal", &"level_02_03"),
		_level(&"level_02_03", "俘虏营 / Prisoner Camp", &"chapter_02", &"branching_camp", &"theme_blood_iron", &"rescue", &"unlock_weapon_forging", &"level_02_04"),
		_level(&"level_02_04", "烽火台 / Beacon Tower", &"chapter_02", &"vertical_tower", &"theme_blood_iron", &"choice", &"combat_climb_and_beacon_choice", &"level_02_05"),
		_level(&"level_02_05", "将军营帐 / General Encampment", &"chapter_02", &"fortified_hub", &"theme_blood_iron", &"pre_boss", &"formation_combat_and_banner_puzzle", &"level_02_06"),
		_level(&"level_02_06", "刑天斗场 / Xíng Tiān Arena", &"chapter_02", &"mountaintop_arena", &"theme_blood_iron", &"boss", &"chapter_boss", &"level_03_01", &"boss_xing_tian"),
		_level(&"level_03_01", "翠微林入口 / Jade Forest Entrance", &"chapter_03", &"looping_forest", &"theme_jade_veil", &"exploration", &"illusion_rules_introduction", &"level_03_02"),
		_level(&"level_03_02", "记忆回廊 / Memory Corridor", &"chapter_03", &"memory_canyon", &"theme_jade_veil", &"narrative_puzzle", &"memory_authentication", &"level_03_03"),
		_level(&"level_03_03", "狐嫁道 / Fox Wedding Road", &"chapter_03", &"processional_path", &"theme_jade_veil", &"stealth", &"follow_the_procession", &"level_03_04"),
		_level(&"level_03_04", "镜花水月亭 / Mirror-Flower Water-Moon Pavilion", &"chapter_03", &"reflection_dual_plane", &"theme_jade_veil", &"puzzle", &"reality_reflection_navigation", &"level_03_05"),
		_level(&"level_03_05", "九尾迷宫 / Nine-Tails Maze", &"chapter_03", &"shifting_maze", &"theme_jade_veil", &"pre_boss", &"riddles_and_dynamic_routes", &"level_03_06"),
		_level(&"level_03_06", "月华台 / Moonlit Terrace", &"chapter_03", &"circular_terrace", &"theme_jade_veil", &"boss", &"chapter_boss", &"level_04_01", &"boss_nine_tails"),
		_level(&"level_04_01", "登天梯 / Stairway to Heaven", &"chapter_04", &"vertical_floating_path", &"theme_celestial_fall", &"platforming", &"wind_and_collapsing_footholds", &"level_04_02"),
		_level(&"level_04_02", "炼丹云台 / Cloud Alchemy Platform", &"chapter_04", &"floating_platform_cluster", &"theme_celestial_fall", &"hazard_puzzle", &"alchemy_and_status_hazards", &"level_04_03"),
		_level(&"level_04_03", "藏经阁 / Scripture Depository", &"chapter_04", &"vertical_library", &"theme_celestial_fall", &"exploration_puzzle", &"gravity_and_index_puzzle", &"level_04_04"),
		_level(&"level_04_04", "玄霄·嗔念台 / Xuán Xiāo Wrath Platform", &"chapter_04", &"floating_arena", &"theme_celestial_fall", &"sub_boss", &"wrath_fragment", &"level_04_05", &"boss_xuan_xiao_wrath"),
		_level(&"level_04_05", "玄霄·执念台 / Xuán Xiāo Obsession Platform", &"chapter_04", &"ritual_arena", &"theme_celestial_fall", &"sub_boss", &"obsession_fragment", &"level_04_06", &"boss_xuan_xiao_obsession"),
		_level(&"level_04_06", "玄霄·真身·天顶 / Celestial Zenith — True Form", &"chapter_04", &"collapsing_zenith_arena", &"theme_celestial_fall", &"boss", &"chapter_boss", &"level_05_01", &"boss_xuan_xiao"),
		_level(&"level_05_01", "烬海之岸 / Shore of the Ember Sea", &"chapter_05", &"open_shore", &"theme_ember_abyss", &"narrative", &"final_revelation_and_respite", &"level_05_02"),
		_level(&"level_05_02", "倒悬殿 / Inverted Sanctuary", &"chapter_05", &"inverted_multi_surface", &"theme_ember_abyss", &"gravity_puzzle", &"inversion_locks", &"level_05_03"),
		_level(&"level_05_03", "轮回歧路 / Forked Path of Samsara", &"chapter_05", &"non_euclidean_branches", &"theme_ember_abyss", &"choice", &"validate_past_outcomes", &"level_05_04"),
		_level(&"level_05_04", "十一铸魂者之墓 / Tomb of the Eleven Soul-Forgers", &"chapter_05", &"memorial_ring", &"theme_ember_abyss", &"trial", &"select_final_blessings", &"level_05_05"),
		_level(&"level_05_05", "烬座·烛阴之缚 / Throne of Ashes · The Dragon Binding", &"chapter_05", &"cosmic_multi_phase_arena", &"theme_ember_abyss", &"final_boss", &"final_boss_and_endings", &"", &"boss_zhu_yin"),
	]
	for record in records:
		var level_id := String(record["id"])
		var chapter := int(level_id.substr(6, 2))
		var level := int(level_id.substr(9, 2))
		record["seed"] = chapter * 100 + level
		record["encounter_id"] = StringName("encounter_%02d_%02d" % [chapter, level])
		record["checkpoint_id"] = StringName("shrine_%02d_%02d" % [chapter, level])
		record["modules"] = _modules_for(record)
		# 章节作用域模块行为参数（伤害类型、周期、行程等）
		record["module_configs"] = _module_configs_for(record)
		# 非 Boss 关启用 shortcut 空间折叠（单向门 + 升降梯回祠堂）
		record["shortcut_fold"] = _shortcut_fold_for(record)
	return records


static func themes() -> Array[Dictionary]:
	return [
		_theme(&"theme_spirit_ruins", "Abandoned Guardian Temple", [&"moonlit_stone", &"moss", &"low_fog"], [&"han_temple", &"courtyard", &"alchemy_ruin"], [&"grounded", &"corridor", &"courtyard"], [&"flame_vents", &"fragile_floors", &"toxic_mist"]),
		_theme(&"theme_blood_iron", "Eternal War Fortress", [&"blood_sunset", &"war_smoke", &"beacon_fire"], [&"ming_fortress", &"rampart", &"siege_camp"], [&"mountain_path", &"rampart", &"vertical_tower"], [&"ballista_fire", &"burning_oil", &"collapse"]),
		_theme(&"theme_jade_veil", "Illusion-Bound Jade Forest", [&"jade_light", &"foxfire", &"unreliable_reflections"], [&"bamboo_grove", &"classical_garden", &"moon_pavilion"], [&"loop", &"dual_plane", &"shifting_maze"], [&"false_floors", &"confusion", &"route_reset"]),
		_theme(&"theme_celestial_fall", "Shattered Floating Immortal City", [&"fixed_sunset", &"cloud_sea", &"divine_decay"], [&"tang_celestial_city", &"cloud_platform", &"floating_library"], [&"vertical", &"floating_islands", &"gravity_shift"], [&"falling_debris", &"wind", &"gravity_anomaly"]),
		_theme(&"theme_ember_abyss", "Broken Celestial Furnace Core", [&"cosmic_void", &"soul_rivers", &"dying_stars"], [&"furnace_fragments", &"impossible_geometry", &"ember_light"], [&"inverted", &"non_euclidean", &"zero_gravity"], [&"gravity_swap", &"time_shift", &"ember_geyser"]),
	]


static func bosses() -> Array[Dictionary]:
	return [
		_boss(&"boss_giant_gate", "守炉灵·巨阙 / Furnace-Keeper · Giant Gate", &"chapter_01", &"level_01_05", &"chapter_boss"),
		_boss(&"boss_xing_tian", "血将军·刑天 / Blood General · Xíng Tiān", &"chapter_02", &"level_02_06", &"chapter_boss"),
		_boss(&"boss_nine_tails", "玉面狐·九尾 / Jade-Faced Fox · Nine-Tails", &"chapter_03", &"level_03_06", &"chapter_boss"),
		_boss(&"boss_xuan_xiao_wrath", "玄霄·嗔念 / Xuán Xiāo · Wrath", &"chapter_04", &"level_04_04", &"sub_boss"),
		_boss(&"boss_xuan_xiao_obsession", "玄霄·执念 / Xuán Xiāo · Obsession", &"chapter_04", &"level_04_05", &"sub_boss"),
		_boss(&"boss_xuan_xiao", "堕仙·玄霄 / Fallen Immortal · Xuán Xiāo", &"chapter_04", &"level_04_06", &"chapter_boss"),
		_boss(&"boss_zhu_yin", "烬渊之主·烛阴 / Lord of the Ember Abyss · Zhú Yīn", &"chapter_05", &"level_05_05", &"final_boss"),
	]


static func _modules_for(level: Dictionary) -> Array[StringName]:
	# 全 28 关显式组合十类可复用模块族（章节作用域）
	var level_id := StringName(level.get("id", &""))
	match level_id:
		# —— Ch.1 灵墟 ——
		&"level_01_01":
			return [&"fragile_floor", &"gate_exit"]
		&"level_01_02":
			return [&"hazard", &"gate_exit"]
		&"level_01_03":
			return [&"switch_offering", &"gate_exit"]
		&"level_01_04":
			return [&"hazard", &"poison_fire_zone", &"fragile_floor", &"switch_offering", &"gate_exit"]
		&"level_01_05":
			return [&"arena_seal"]
		# —— Ch.2 血铁（攻城危害 / 阵型）——
		&"level_02_01":
			return [&"hazard", &"fragile_floor", &"gate_exit"]
		&"level_02_02":
			return [&"projectile_lane", &"hazard", &"gate_exit"]
		&"level_02_03":
			return [&"switch_offering", &"fragile_floor", &"gate_exit"]
		&"level_02_04":
			return [&"moving_platform", &"switch_offering", &"fragile_floor", &"gate_exit"]
		&"level_02_05":
			return [&"switch_offering", &"projectile_lane", &"gate_exit"]
		&"level_02_06":
			return [&"arena_seal"]
		# —— Ch.3 玉障（幻象 / 双面）——
		&"level_03_01":
			return [&"illusion_marker", &"fragile_floor", &"gate_exit"]
		&"level_03_02":
			return [&"illusion_marker", &"switch_offering", &"hazard", &"gate_exit"]
		&"level_03_03":
			return [&"projectile_lane", &"illusion_marker", &"gate_exit"]
		&"level_03_04":
			return [&"moving_platform", &"illusion_marker", &"switch_offering", &"gate_exit"]
		&"level_03_05":
			return [&"illusion_marker", &"switch_offering", &"gate_exit"]
		&"level_03_06":
			return [&"arena_seal"]
		# —— Ch.4 天崩（垂直 / 炼丹 / 重力）——
		&"level_04_01":
			return [&"moving_platform", &"fragile_floor", &"gate_exit"]
		&"level_04_02":
			return [&"moving_platform", &"poison_fire_zone", &"switch_offering", &"gate_exit"]
		&"level_04_03":
			return [&"gravity_visual_zone", &"hazard", &"switch_offering", &"gate_exit"]
		&"level_04_04":
			return [&"arena_seal"]
		&"level_04_05":
			return [&"arena_seal"]
		&"level_04_06":
			return [&"arena_seal"]
		# —— Ch.5 烬座（倒悬 / 非欧）——
		&"level_05_01":
			return [&"gate_exit"]
		&"level_05_02":
			return [&"gravity_visual_zone", &"moving_platform", &"switch_offering", &"gate_exit"]
		&"level_05_03":
			return [&"illusion_marker", &"switch_offering", &"gravity_visual_zone", &"gate_exit"]
		&"level_05_04":
			return [&"switch_offering", &"gate_exit"]
		&"level_05_05":
			return [&"arena_seal"]
	# 兜底：拓扑启发式（不应触达若表完整）
	return [&"gate_exit"]


static func _module_configs_for(level: Dictionary) -> Dictionary:
	# 按章节打磨模块数值；完整美术非本任务范围
	var chapter_id := StringName(level.get("chapter_id", &""))
	var configs := {}
	match chapter_id:
		&"chapter_01":
			configs["hazard"] = {"damage_per_second": 7.0, "damage_type": &"ember"}
			configs["poison_fire_zone"] = {"damage_type": &"poison", "damage_per_second": 8.0}
			configs["fragile_floor"] = {"collapse_delay": 2.0}
			configs["switch_offering"] = {"required_count": 1}
		&"chapter_02":
			configs["hazard"] = {"damage_per_second": 11.0, "damage_type": &"fire", "size": Vector3(5.0, 0.45, 5.0)}
			configs["projectile_lane"] = {"interval": 1.55, "size": Vector3(3.2, 2.2, 14.0), "damage": 14.0}
			configs["fragile_floor"] = {"collapse_delay": 1.35}
			configs["moving_platform"] = {"travel": Vector3(0.0, 4.2, 0.0), "travel_time": 2.6}
			configs["switch_offering"] = {"required_count": 2}
		&"chapter_03":
			configs["illusion_marker"] = {"illusion_kind": &"false_path"}
			configs["fragile_floor"] = {"collapse_delay": 1.1}
			configs["hazard"] = {"damage_per_second": 6.0, "damage_type": &"confusion"}
			configs["projectile_lane"] = {"interval": 2.2, "damage": 10.0}
			configs["moving_platform"] = {"travel": Vector3(3.5, 0.0, 0.0), "travel_time": 3.4}
			configs["switch_offering"] = {"required_count": 1}
		&"chapter_04":
			configs["moving_platform"] = {"travel": Vector3(0.0, 5.0, 2.0), "travel_time": 2.2}
			configs["fragile_floor"] = {"collapse_delay": 0.85}
			configs["poison_fire_zone"] = {"damage_type": &"alchemy_vapor", "damage_per_second": 13.0}
			configs["gravity_visual_zone"] = {"visual_direction": Vector3.DOWN, "size": Vector3(7.0, 5.0, 7.0)}
			configs["hazard"] = {"damage_per_second": 9.0, "damage_type": &"debris"}
			configs["switch_offering"] = {"required_count": 2}
		&"chapter_05":
			configs["gravity_visual_zone"] = {"visual_direction": Vector3(0.0, -1.0, 0.0), "size": Vector3(8.0, 6.0, 8.0)}
			configs["moving_platform"] = {"travel": Vector3(0.0, -3.5, 0.0), "travel_time": 2.8}
			configs["illusion_marker"] = {"illusion_kind": &"samsara_fork"}
			configs["switch_offering"] = {"required_count": 3}
		_:
			pass
	return configs


static func _shortcut_fold_for(level: Dictionary) -> Dictionary:
	# H-05：Boss / 纯叙事岸边不塞折叠，其余关生成单向门+升降梯
	var kind := StringName(level.get("kind", &""))
	if kind in [&"boss", &"sub_boss", &"final_boss", &"narrative"]:
		return {"enabled": false}
	var checkpoint_id := String(level.get("checkpoint_id", "ember_shrine"))
	return {
		"enabled": true,
		"one_way_door": true,
		"elevator": true,
		"shortcut_ids": {
			"one_way": "%s:one_way_door" % checkpoint_id,
			"elevator": "%s:elevator" % checkpoint_id,
		},
	}


static func _chapter(id: StringName, display_name: String, theme_id: StringName, start_level_id: StringName, exit_level_id: StringName, boss_ids: Array[StringName]) -> Dictionary:
	return {"id": id, "display_name": display_name, "theme_id": theme_id, "start_level_id": start_level_id, "exit_level_id": exit_level_id, "boss_ids": boss_ids}


static func _level(id: StringName, display_name: String, chapter_id: StringName, topology: StringName, theme_id: StringName, kind: StringName, purpose: StringName, next_level_id: StringName, boss_id: StringName = &"") -> Dictionary:
	return {"id": id, "display_name": display_name, "chapter_id": chapter_id, "topology": topology, "theme_id": theme_id, "kind": kind, "purpose": purpose, "boss_id": boss_id, "next_level_id": next_level_id}


static func _theme(id: StringName, display_name: String, palette: Array[StringName], architecture: Array[StringName], traversal: Array[StringName], hazards: Array[StringName]) -> Dictionary:
	return {"id": id, "display_name": display_name, "palette": palette, "architecture": architecture, "traversal": traversal, "hazards": hazards}


static func _boss(id: StringName, display_name: String, chapter_id: StringName, level_id: StringName, kind: StringName) -> Dictionary:
	return {"id": id, "display_name": display_name, "chapter_id": chapter_id, "level_id": level_id, "kind": kind}
