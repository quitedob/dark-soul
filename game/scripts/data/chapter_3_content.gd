class_name Chapter3Content
extends RefCounted
## Chapter 3 content: 玉障·迷心 (Jade Veil · Lost Mind)
## Theme: Illusion-Bound Jade Forest / Classical Garden
## Palette: jade_light, foxfire, unreliable_reflections

static func enemies() -> Array[Dictionary]:
	return [
		{
			"id": "illusion_butterfly",
			"display_name": "Illusion Butterfly / 幻蝶",
			"max_health": 28.0, "move_speed": 5.5, "aggro_range": 8.0,
			"disengage_range": 14.0, "leash_range": 10.0, "attack_range": 1.3,
			"poise_limit": 5.0, "reward": 18, "stagger_duration": 0.65,
			"attack": {"windup": 0.22, "active": 0.06, "recovery": 0.18, "damage": 5.0, "stagger": 4.0, "lunge": 0.5},
			"body_color": "88ccff", "weapon_color": "aaddff", "eye_emission": "ffffff",
			"weapon_shape": "wing_blade", "body_type": "floating_small",
			"behavior": "swarm_flutter",
			"chapter": 3,
		},
		{
			"id": "memory_thief",
			"display_name": "Memory Thief / 窃忆灵",
			"max_health": 55.0, "move_speed": 5.8, "aggro_range": 10.0,
			"disengage_range": 16.0, "leash_range": 13.0, "attack_range": 1.7,
			"poise_limit": 14.0, "reward": 30, "stagger_duration": 0.55,
			"attack": {"windup": 0.20, "active": 0.10, "recovery": 0.25, "damage": 8.0, "stagger": 10.0, "lunge": 0.9},
			"body_color": "664488", "weapon_color": "9966cc", "eye_emission": "cc88ff",
			"weapon_shape": "memory_claw", "body_type": "ethereal_thin",
			"behavior": "hit_and_run",
			"chapter": 3,
		},
		{
			"id": "echo_spirit",
			"display_name": "Echo Spirit / 回声灵",
			"max_health": 42.0, "move_speed": 3.0, "aggro_range": 11.0,
			"disengage_range": 17.0, "leash_range": 14.0, "attack_range": 5.0,
			"poise_limit": 10.0, "reward": 28, "stagger_duration": 0.58,
			"attack": {"windup": 0.55, "active": 0.15, "recovery": 0.45, "damage": 10.0, "stagger": 8.0, "lunge": 0.0},
			"body_color": "5577aa", "weapon_color": "8899cc", "eye_emission": "88aaff",
			"weapon_shape": "sound_wave", "body_type": "floating_orb",
			"behavior": "ranged_homing",
			"chapter": 3,
		},
		{
			"id": "foxfire_lantern",
			"display_name": "Foxfire Lantern / 狐火灯",
			"max_health": 35.0, "move_speed": 2.0, "aggro_range": 9.0,
			"disengage_range": 15.0, "leash_range": 12.0, "attack_range": 4.0,
			"poise_limit": 8.0, "reward": 32, "stagger_duration": 0.60,
			"attack": {"windup": 0.62, "active": 0.22, "recovery": 0.52, "damage": 14.0, "stagger": 12.0, "lunge": 0.0},
			"body_color": "44ccaa", "weapon_color": "66ffcc", "eye_emission": "00ffcc",
			"weapon_shape": "fox_fire_orb", "body_type": "lantern_float",
			"behavior": "proximity_explode",
			"chapter": 3,
		},
		{
			"id": "wedding_gown_ghost",
			"display_name": "Wedding Gown Ghost / 嫁衣女鬼",
			"max_health": 70.0, "move_speed": 4.2, "aggro_range": 12.0,
			"disengage_range": 19.0, "leash_range": 16.0, "attack_range": 2.2,
			"poise_limit": 18.0, "reward": 45, "stagger_duration": 0.50,
			"attack": {"windup": 0.38, "active": 0.18, "recovery": 0.42, "damage": 15.0, "stagger": 18.0, "lunge": 1.5},
			"body_color": "cc2244", "weapon_color": "ff6688", "eye_emission": "ff0000",
			"weapon_shape": "sleeve_blade", "body_type": "floating_dress",
			"behavior": "seduce_and_strike",
			"chapter": 3,
		},
		{
			"id": "water_moon_spirit",
			"display_name": "Water Moon Spirit / 水月灵",
			"max_health": 50.0, "move_speed": 3.8, "aggro_range": 10.0,
			"disengage_range": 16.0, "leash_range": 13.0, "attack_range": 3.5,
			"poise_limit": 12.0, "reward": 35, "stagger_duration": 0.55,
			"attack": {"windup": 0.48, "active": 0.16, "recovery": 0.50, "damage": 12.0, "stagger": 14.0, "lunge": 0.0},
			"body_color": "88aacc", "weapon_color": "aaccee", "eye_emission": "4499ff",
			"weapon_shape": "water_orb", "body_type": "reflection_clone",
			"behavior": "mirror_self",
			"chapter": 3,
		},
		{
			"id": "mirror_flower_spirit",
			"display_name": "Mirror Flower Spirit / 镜花精",
			"max_health": 45.0, "move_speed": 2.5, "aggro_range": 9.0,
			"disengage_range": 15.0, "leash_range": 12.0, "attack_range": 4.5,
			"poise_limit": 10.0, "reward": 30, "stagger_duration": 0.62,
			"attack": {"windup": 0.58, "active": 0.20, "recovery": 0.55, "damage": 11.0, "stagger": 10.0, "lunge": 0.0},
			"body_color": "ff88aa", "weapon_color": "ffaacc", "eye_emission": "ff6688",
			"weapon_shape": "petal_blade", "body_type": "flower_stationary",
			"behavior": "petal_barrage",
			"chapter": 3,
		},
		{
			"id": "maze_guardian",
			"display_name": "Maze Guardian / 迷宫守卫",
			"max_health": 100.0, "move_speed": 3.5, "aggro_range": 12.0,
			"disengage_range": 20.0, "leash_range": 17.0, "attack_range": 2.5,
			"poise_limit": 38.0, "reward": 55, "stagger_duration": 0.42,
			"attack": {"windup": 0.52, "active": 0.22, "recovery": 0.62, "damage": 20.0, "stagger": 26.0, "lunge": 1.6},
			"body_color": "447755", "weapon_color": "669966", "eye_emission": "44ff44",
			"weapon_shape": "jade_halberd", "body_type": "armored_medium",
			"behavior": "patrol_route",
			"chapter": 3,
		},
		{
			"id": "mind_lost_fox_demon",
			"display_name": "Mind-Lost Fox Demon / 迷心狐妖",
			"max_health": 85.0, "move_speed": 5.5, "aggro_range": 13.0,
			"disengage_range": 20.0, "leash_range": 17.0, "attack_range": 1.9,
			"poise_limit": 22.0, "reward": 48, "stagger_duration": 0.48,
			"attack": {"windup": 0.25, "active": 0.12, "recovery": 0.32, "damage": 12.0, "stagger": 14.0, "lunge": 1.2},
			"body_color": "cc8844", "weapon_color": "ffaa55", "eye_emission": "ff8800",
			"weapon_shape": "fox_claw", "body_type": "beast_humanoid",
			"behavior": "illusion_dash",
			"chapter": 3,
		},
	]


static func elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_memory_eater",
			"display_name": "Memory Eater / 噬忆者",
			"max_health": 190.0, "move_speed": 4.5, "aggro_range": 14.0,
			"attack_range": 2.4, "poise_limit": 42.0, "reward": 135,
			"special_ability": "memory_steal",
			"appears_in": "level_03_02", "body_color": "664488",
			"weapon_shape": "memory_scythe", "body_type": "ethereal_elite",
		},
		{
			"id": "elite_fox_bride",
			"display_name": "Fox Bride / 狐嫁娘",
			"max_health": 170.0, "move_speed": 5.2, "aggro_range": 13.0,
			"attack_range": 3.0, "poise_limit": 35.0, "reward": 145,
			"special_ability": "seduction_charm",
			"appears_in": "level_03_03", "body_color": "cc2244",
			"weapon_shape": "bridal_veil", "body_type": "floating_dress_elite",
		},
		{
			"id": "elite_reflection_lord",
			"display_name": "Reflection Lord / 镜像主",
			"max_health": 210.0, "move_speed": 3.8, "aggro_range": 15.0,
			"attack_range": 2.8, "poise_limit": 50.0, "reward": 155,
			"special_ability": "create_clone",
			"appears_in": "level_03_04", "body_color": "88aacc",
			"weapon_shape": "mirror_blade", "body_type": "reflection_knight",
		},
		{
			"id": "elite_ember_greed_ghost",
			"display_name": "Ember-Greedy Ghost / 贪烬鬼",
			"max_health": 210.0, "move_speed": 4.8, "aggro_range": 15.0,
			"attack_range": 2.2, "poise_limit": 46.0, "reward": 160,
			"special_ability": "love_bait",
			"appears_in": "level_03_04", "body_color": "4A1A3A",
			"weapon_shape": "memory_scythe", "body_type": "ethereal_elite",
		},
	]


static func boss() -> Dictionary:
	return {
		"id": "boss_nine_tails",
		"display_name": "玉面狐·九尾 / Jade-Faced Fox · Nine-Tails",
		"max_health": 450.0, "reward": 550,
		"arena": "moonlit_terrace_garden",
		"chapter": 3, "chinese_name": "九尾",
		"phases": {
			"1": {
				"threshold": 1.0,
				"description": "Elegant fox spirit — ranged foxfire projectiles, teleport dodges, illusion clones",
				"attacks": [
					{"name": "foxfire_bolt", "windup": 0.52, "active": 0.18, "recovery": 0.48, "damage": 20.0, "stagger": 16.0, "lunge": 0.0, "type": "homing_projectile"},
					{"name": "tail_sweep", "windup": 0.65, "active": 0.28, "recovery": 0.58, "damage": 24.0, "stagger": 28.0, "lunge": 0.0, "type": "radial_aoe", "range": 3.5},
					{"name": "illusion_dash_strike", "windup": 0.35, "active": 0.15, "recovery": 0.35, "damage": 18.0, "stagger": 20.0, "lunge": 4.5, "type": "teleport_after"},
					{"name": "clone_spawn", "windup": 0.72, "active": 0.0, "recovery": 0.48, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "summon", "clone_count": 2},
				],
				"vfx": "ethereal_foxfire_cyan",
				"lighting": "silver_moonlight_soft",
			},
			"2": {
				"threshold": 0.7,
				"description": "Nine Tails revealed — all tails active, arena floods with illusions, confusing mist",
				"attacks": [
					{"name": "nine_tail_barrage", "windup": 0.72, "active": 0.55, "recovery": 0.65, "damage": 8.0, "stagger": 8.0, "lunge": 0.0, "type": "multi_projectile", "count": 9},
					{"name": "foxfire_storm", "windup": 0.95, "active": 0.48, "recovery": 0.85, "damage": 16.0, "stagger": 18.0, "lunge": 0.0, "type": "radial_projectile_burst", "count": 12},
					{"name": "moon_gaze_charm", "windup": 0.85, "active": 0.0, "recovery": 0.72, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "status", "effect": "confusion"},
					{"name": "petal_blade_dance", "windup": 0.42, "active": 0.62, "recovery": 0.48, "damage": 22.0, "stagger": 24.0, "lunge": 3.0, "type": "multi_hit", "hits": 4},
				],
				"vfx": "jade_mist_swirl",
				"lighting": "shifting_foxfire_colors",
			},
			"3": {
				"threshold": 0.3,
				"description": "Wounded fox — desperate, rapid teleport chains, arena becomes maze of illusions",
				"attacks": [
					{"name": "desperate_teleport_flurry", "windup": 0.22, "active": 0.12, "recovery": 0.22, "damage": 25.0, "stagger": 28.0, "lunge": 3.5, "type": "chain_teleport", "chain_count": 4},
					{"name": "final_foxfire_nova", "windup": 1.05, "active": 0.55, "recovery": 1.2, "damage": 35.0, "stagger": 42.0, "lunge": 0.0, "type": "stage_wide_aoe", "range": 10.0},
					{"name": "illusion_wall", "windup": 0.55, "active": 0.0, "recovery": 0.42, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "arena_modify"},
				],
				"vfx": "desperate_flickering_form",
				"lighting": "dim_cyan_desperation",
			},
		},
		"vfx_unique": {
			"intro": "nine_tails_unfurling",
			"death": "dissolve_into_foxfire_petals",
			"hit": "jade_sparkles",
			"arena": "reflection_pool_ripples",
			"ground_effect": "cherry_blossom_petals",
		},
	}


static func spells() -> Array[Dictionary]:
	return [
		{
			"id": "foxfire_bolt", "display_name": "Foxfire Bolt / 狐火弹",
			"focus_cost": 13.0, "cast_time": 0.48, "damage": 22.0, "stagger": 12.0,
			"proj_speed": 14.0, "proj_lifetime": 2.5, "spell_type": "foxfire",
			"homing": true, "homing_strength": 3.0, "chapter": 3,
		},
		{
			"id": "illusion_clone_art", "display_name": "Illusion Clone Art / 幻身术",
			"focus_cost": 22.0, "cast_time": 0.65, "damage": 0.0, "stagger": 0.0,
			"spell_type": "clone", "effect": "spawn_decoy", "clone_duration": 8.0,
			"chapter": 3,
		},
		{
			"id": "moon_reflection_wave", "display_name": "Moon Reflection Wave / 月映波",
			"focus_cost": 18.0, "cast_time": 0.58, "damage": 26.0, "stagger": 20.0,
			"proj_speed": 12.0, "proj_lifetime": 1.8, "spell_type": "reflection",
			"homing": false, "passes_through_enemies": true, "chapter": 3,
		},
		{
			"id": "jade_veil_barrier", "display_name": "Jade Veil Barrier / 玉障壁",
			"focus_cost": 20.0, "cast_time": 0.52, "damage": 0.0, "stagger": 0.0,
			"spell_type": "barrier", "effect": "confuse_attackers", "duration": 10.0,
			"chapter": 3,
		},
		{
			"id": "mind_clearing_mantra", "display_name": "Mind-Clearing Mantra / 清心咒",
			"focus_cost": 15.0, "cast_time": 0.55, "damage": 0.0, "stagger": 0.0,
			"spell_type": "prayer", "effect": "cure_status", "cures": ["confusion", "charm"],
			"chapter": 3,
		},
	]


static func weapons() -> Array[Dictionary]:
	return [
		{
			"id": "jade_leaf_blade", "display_name": "Jade Leaf Blade / 翠叶剑",
			"hand": "right", "primary": "leaf_slash", "secondary": "vine_whip",
			"mesh_shape": "jade_sword", "mesh_color": "44aa66",
			"chapter": 3,
		},
		{
			"id": "fox_spirit_bow", "display_name": "Fox Spirit Bow / 灵狐弓",
			"hand": "right", "primary": "foxfire_shot", "secondary": "spirit_arrow",
			"mesh_shape": "fox_bow", "mesh_color": "66cc88",
			"chapter": 3,
		},
		{
			"id": "nine_tail_fan", "display_name": "Nine-Tail Fan / 九尾扇",
			"hand": "right", "primary": "foxfire_bolt", "secondary": "illusion_clone_art",
			"mesh_shape": "fox_fan", "mesh_color": "88cccc",
			"special_skill": "clone_dance", "chapter": 3,
		},
		{
			"id": "mirror_blossom_shield", "display_name": "Mirror Blossom Shield / 镜花盾",
			"hand": "left", "primary": "reflect_guard", "secondary": "petal_counter",
			"mesh_shape": "blossom_shield", "mesh_color": "ff88aa",
			"guard": {"absorption": 0.70, "stability": 0.60, "front_dot": 0.2},
			"special_ability": "projectile_reflect", "chapter": 3,
		},
		{
			"id": "garden_seal", "display_name": "Garden Seal / 园林印",
			"hand": "right", "primary": "moon_reflection_wave", "secondary": "jade_veil_barrier",
			"mesh_shape": "jade_seal", "mesh_color": "44aa88",
			"chapter": 3,
		},
		{
			"id": "prayer_beads_ch3", "display_name": "Jade Prayer Beads / 翠玉念珠",
			"hand": "right", "primary": "mind_clearing_mantra", "secondary": "foxfire_blessing",
			"mesh_shape": "jade_beads", "mesh_color": "33aa77",
			"chapter": 3,
		},
	]


static func scene() -> Dictionary:
	return {
		"chapter_id": "chapter_03",
		"theme_name": "Jade Veil / 玉障",
		"ambient_color": Color("3a4a4a"),
		"ambient_energy": 0.20,
		"fog_color": Color("225544"),
		"fog_energy": 0.35,
		"fog_density": 0.016,
		"key_light_color": Color("aaccee"),
		"key_light_energy": 0.8,
		"key_light_rotation": Vector3(-42, -18, 0),
		"fill_light_color": Color("66aa88"),
		"fill_light_energy": 0.35,
		"particles": [
			{"type": "petal_fall", "color": Color("ff88aa"), "amount": 30, "region": "scattered"},
			{"type": "foxfire_float", "color": Color("44ffcc"), "amount": 20, "region": "scattered"},
			{"type": "mist_swirl", "color": Color("88ccbb"), "amount": 15, "region": "ground"},
		],
		"materials": {
			"wall": {"color": "2a3a30", "roughness": 0.88, "metallic": 0.05},
			"floor": {"color": "1a2a22", "roughness": 0.90, "metallic": 0.03},
			"bamboo": {"color": "2a4a28", "roughness": 0.82, "metallic": 0.02},
			"jade": {"color": "33aa66", "roughness": 0.3, "metallic": 0.15, "emission": "22cc66", "emission_energy": 1.5},
			"water_surface": {"color": "4488aa", "roughness": 0.1, "metallic": 0.4, "emission": "2266aa", "emission_energy": 1.8},
			"cherry_blossom": {"color": "ff88aa", "roughness": 0.7, "metallic": 0.0},
		},
	}
