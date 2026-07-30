class_name Chapter5Content
extends RefCounted
## Chapter 5 content: 烬座·归墟 (Throne of Ashes · Return to Void)
## Theme: Broken Celestial Furnace Core / Cosmic Void
## Palette: cosmic_void, soul_rivers, dying_stars

static func enemies() -> Array[Dictionary]:
	return [
		{
			"id": "ember_shore_drifter",
			"display_name": "Ember Shore Drifter / 烬岸浮游灵",
			"max_health": 88.0, "move_speed": 3.0, "aggro_range": 12.0,
			"disengage_range": 18.0, "leash_range": 15.0, "attack_range": 2.2,
			"poise_limit": 28.0, "reward": 42, "stagger_duration": 0.48,
			"attack": {"windup": 0.48, "active": 0.18, "recovery": 0.58, "damage": 18.0, "stagger": 22.0, "lunge": 1.3},
			"body_color": "1a1a2a", "weapon_color": "334455", "eye_emission": "4466ff",
			"weapon_shape": "drift_blade", "body_type": "void_wraith",
			"behavior": "slow_drift",
			"chapter": 5,
		},
		{
			"id": "inverted_guardian",
			"display_name": "Inverted Guardian / 倒悬卫士",
			"max_health": 120.0, "move_speed": 2.8, "aggro_range": 13.0,
			"disengage_range": 20.0, "leash_range": 17.0, "attack_range": 2.8,
			"poise_limit": 45.0, "reward": 58, "stagger_duration": 0.38,
			"attack": {"windup": 0.58, "active": 0.24, "recovery": 0.68, "damage": 24.0, "stagger": 30.0, "lunge": 1.8},
			"body_color": "2a2a3a", "weapon_color": "556688", "eye_emission": "6688ff",
			"weapon_shape": "inverted_halberd", "body_type": "gravity_armor",
			"behavior": "inverted_patrol",
			"chapter": 5,
		},
		{
			"id": "ember_bat",
			"display_name": "Ember Bat / 烬蝠",
			"max_health": 38.0, "move_speed": 7.5, "aggro_range": 14.0,
			"disengage_range": 22.0, "leash_range": 18.0, "attack_range": 1.3,
			"poise_limit": 8.0, "reward": 28, "stagger_duration": 0.62,
			"attack": {"windup": 0.15, "active": 0.06, "recovery": 0.20, "damage": 6.0, "stagger": 5.0, "lunge": 0.8},
			"body_color": "1a1010", "weapon_color": "ff4411", "eye_emission": "ff2200",
			"weapon_shape": "ember_wing", "body_type": "flying_small",
			"behavior": "swarm_dive",
			"chapter": 5,
		},
		{
			"id": "forked_path_shade",
			"display_name": "Forked Path Shade / 歧路影",
			"max_health": 65.0, "move_speed": 4.5, "aggro_range": 11.0,
			"disengage_range": 17.0, "leash_range": 14.0, "attack_range": 1.8,
			"poise_limit": 18.0, "reward": 38, "stagger_duration": 0.52,
			"attack": {"windup": 0.28, "active": 0.12, "recovery": 0.35, "damage": 12.0, "stagger": 14.0, "lunge": 1.1},
			"body_color": "111122", "weapon_color": "222244", "eye_emission": "4444ff",
			"weapon_shape": "shadow_blade", "body_type": "shadow_form",
			"behavior": "split_clone",
			"chapter": 5,
		},
		{
			"id": "shadow_of_possibility",
			"display_name": "Shadow of Possibility / 可能性之影",
			"max_health": 55.0, "move_speed": 5.0, "aggro_range": 10.0,
			"disengage_range": 16.0, "leash_range": 13.0, "attack_range": 4.0,
			"poise_limit": 12.0, "reward": 35, "stagger_duration": 0.55,
			"attack": {"windup": 0.45, "active": 0.15, "recovery": 0.42, "damage": 10.0, "stagger": 12.0, "lunge": 0.0},
			"body_color": "222233", "weapon_color": "4444aa", "eye_emission": "6666ff",
			"weapon_shape": "possibility_orb", "body_type": "quantum_shimmer",
			"behavior": "random_form",
			"chapter": 5,
		},
		{
			"id": "soul_forger_remnant",
			"display_name": "Soul-Forger Remnant / 铸魂者残影",
			"max_health": 150.0, "move_speed": 2.5, "aggro_range": 14.0,
			"disengage_range": 22.0, "leash_range": 18.0, "attack_range": 3.2,
			"poise_limit": 58.0, "reward": 80, "stagger_duration": 0.32,
			"attack": {"windup": 0.72, "active": 0.30, "recovery": 0.88, "damage": 28.0, "stagger": 38.0, "lunge": 2.0},
			"body_color": "bbaa66", "weapon_color": "ddcc88", "eye_emission": "ffdd44",
			"weapon_shape": "soul_hammer", "body_type": "ancient_giant",
			"behavior": "soul_drain_aura",
			"chapter": 5,
		},
	]


static func elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_void_sentinel",
			"display_name": "Void Sentinel / 虚空守卫",
			"max_health": 250.0, "move_speed": 3.0, "aggro_range": 16.0,
			"attack_range": 3.5, "poise_limit": 70.0, "reward": 170,
			"special_ability": "void_tear",
			"appears_in": "level_05_01", "body_color": "1a1a2a",
			"weapon_shape": "void_blade", "body_type": "void_knight",
		},
		{
			"id": "elite_gravity_twister",
			"display_name": "Gravity Twister / 重力扭曲者",
			"max_health": 200.0, "move_speed": 4.0, "aggro_range": 15.0,
			"attack_range": 5.0, "poise_limit": 42.0, "reward": 155,
			"special_ability": "gravity_reverse",
			"appears_in": "level_05_02", "body_color": "2a2a3a",
			"weapon_shape": "gravity_staff", "body_type": "gravity_mage",
		},
		{
			"id": "elite_soul_forger_echo",
			"display_name": "Soul-Forger Echo / 铸魂者回响",
			"max_health": 280.0, "move_speed": 2.2, "aggro_range": 15.0,
			"attack_range": 4.0, "poise_limit": 85.0, "reward": 200,
			"special_ability": "soul_shatter",
			"appears_in": "level_05_04", "body_color": "ccaa55",
			"weapon_shape": "soul_forge_hammer", "body_type": "ancient_titan",
		},
	]


static func boss() -> Dictionary:
	return {
		"id": "boss_zhu_yin",
		"display_name": "烬渊之主·烛阴 / Lord of the Ember Abyss · Zhu Yin",
		"max_health": 800.0, "reward": 1000,
		"arena": "cosmic_throne_void",
		"chapter": 5, "chinese_name": "烛阴",
		"phases": {
			"1": {
				"threshold": 1.0,
				"description": "Torch Dragon — colossal dragon form, sweeping breath attacks, tail slams, arena-wide light/dark cycle",
				"attacks": [
					{"name": "torch_breath", "windup": 1.35, "active": 1.25, "recovery": 0.85, "damage": 18.0, "stagger": 15.0, "lunge": 0.0, "type": "cone_aoe", "range": 10.0},
					{"name": "dragon_tail_slam", "windup": 0.95, "active": 0.35, "recovery": 0.82, "damage": 42.0, "stagger": 50.0, "lunge": 0.0, "type": "radial_aoe", "range": 5.0},
					{"name": "claw_swipe", "windup": 0.65, "active": 0.28, "recovery": 0.62, "damage": 30.0, "stagger": 36.0, "lunge": 3.0, "heavy": false},
					{"name": "day_night_shift", "windup": 1.05, "active": 0.0, "recovery": 0.55, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "arena_modify", "effect": "darkness_blind"},
				],
				"vfx": "cosmic_dragon_fire",
				"lighting": "shifting_light_dark_cycle",
			},
			"2": {
				"threshold": 0.7,
				"description": "Dragon Lord Humanoid — swift sword techniques, time manipulation, teleport combos",
				"attacks": [
					{"name": "time_slash", "windup": 0.28, "active": 0.15, "recovery": 0.25, "damage": 28.0, "stagger": 30.0, "lunge": 3.5, "type": "speed_boosted"},
					{"name": "temporal_freeze_slash", "windup": 0.68, "active": 0.22, "recovery": 0.48, "damage": 35.0, "stagger": 40.0, "lunge": 2.5, "type": "freeze_then_strike"},
					{"name": "void_step_combo", "windup": 0.18, "active": 0.55, "recovery": 0.42, "damage": 15.0, "stagger": 18.0, "lunge": 0.0, "type": "multi_hit", "hits": 4},
					{"name": "chrono_reversal", "windup": 0.55, "active": 0.0, "recovery": 0.42, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "status", "effect": "rewind_player_position"},
				],
				"vfx": "time_distortion_rings",
				"lighting": "focused_spotlight_tracking",
			},
			"3": {
				"threshold": 0.4,
				"description": "Reality collapse — zero-gravity arena, bullet-hell ember projectiles, fractured space attacks",
				"attacks": [
					{"name": "ember_bullet_hell", "windup": 0.55, "active": 1.2, "recovery": 0.68, "damage": 8.0, "stagger": 8.0, "lunge": 0.0, "type": "multi_projectile", "count": 30},
					{"name": "space_fracture", "windup": 0.82, "active": 0.38, "recovery": 0.72, "damage": 32.0, "stagger": 38.0, "lunge": 0.0, "type": "line_aoe", "length": 15.0},
					{"name": "zero_g_slam", "windup": 0.72, "active": 0.30, "recovery": 0.58, "damage": 36.0, "stagger": 44.0, "lunge": 0.0, "type": "pull_then_explode", "range": 8.0},
					{"name": "reality_tear", "windup": 1.05, "active": 0.45, "recovery": 0.95, "damage": 22.0, "stagger": 28.0, "lunge": 0.0, "type": "random_teleport_aoe", "hits": 4},
				],
				"vfx": "reality_fracture_shards",
				"lighting": "chaotic_multicolor_void",
			},
			"4": {
				"threshold": 0.1,
				"description": "Weakened dragon lord — non-combat choice phase. Player chooses ending.",
				"attacks": [
					{"name": "dying_ember_surge", "windup": 1.55, "active": 0.55, "recovery": 1.5, "damage": 50.0, "stagger": 60.0, "lunge": 0.0, "type": "radial_aoe", "range": 12.0},
				],
				"vfx": "fading_dragon_essence",
				"lighting": "dim_dying_ember_glow",
				"ending_triggers": ["absorb_ember", "sit_throne", "destroy_throne", "repair_furnace"],
			},
		},
		"vfx_unique": {
			"intro": "cosmic_dragon_emergence",
			"death": "universe_rebirth_or_void",
			"hit": "star_shatter_sparks",
			"arena": "cosmic_throne_of_bronze_and_embers",
			"ground_effect": "soul_river_currents",
		},
	}


static func spells() -> Array[Dictionary]:
	return [
		{
			"id": "void_step", "display_name": "Void Step / 虚空步",
			"focus_cost": 15.0, "cast_time": 0.22, "damage": 0.0, "stagger": 0.0,
			"spell_type": "mobility", "effect": "teleport_through_void", "teleport_range": 10.0,
			"chapter": 5,
		},
		{
			"id": "void_rift", "display_name": "Void Rift / 虚空裂隙",
			"focus_cost": 28.0, "cast_time": 0.75, "damage": 35.0, "stagger": 32.0,
			"proj_speed": 6.0, "proj_lifetime": 2.5, "spell_type": "void",
			"homing": false, "effect": "lingering_aoe", "aoe_range": 4.0, "aoe_duration": 3.0,
			"chapter": 5,
		},
		{
			"id": "torch_dragon_breath", "display_name": "Torch Dragon Breath / 烛龙之息",
			"focus_cost": 35.0, "cast_time": 1.05, "damage": 45.0, "stagger": 38.0,
			"proj_speed": 5.0, "proj_lifetime": 2.0, "spell_type": "dragon_breath",
			"homing": false, "type": "cone_aoe", "cone_range": 8.0, "chapter": 5,
		},
		{
			"id": "final_flame", "display_name": "Final Flame / 终末之焰",
			"focus_cost": 42.0, "cast_time": 1.25, "damage": 65.0, "stagger": 55.0,
			"proj_speed": 4.0, "proj_lifetime": 3.0, "spell_type": "final_flame",
			"homing": true, "homing_strength": 1.5, "aoe_on_hit": true, "aoe_range": 5.0,
			"chapter": 5,
		},
		{
			"id": "great_silence_prayer", "display_name": "Great Silence Prayer / 大寂灭祷",
			"focus_cost": 38.0, "cast_time": 1.15, "damage": 40.0, "stagger": 42.0,
			"spell_type": "prayer", "effect": "silence_aoe", "aoe_range": 8.0, "silence_duration": 6.0,
			"chapter": 5,
		},
		{
			"id": "ksitigarbha_vow", "display_name": "Ksitigarbha's Vow / 地藏大愿",
			"focus_cost": 40.0, "cast_time": 1.35, "damage": 0.0, "stagger": 0.0,
			"spell_type": "prayer", "effect": "revive_on_death", "duration": 30.0,
			"chapter": 5,
		},
	]


static func weapons() -> Array[Dictionary]:
	return [
		{
			"id": "void_edge", "display_name": "Void Edge / 虚空刃",
			"hand": "right", "primary": "void_slash", "secondary": "void_cut",
			"mesh_shape": "void_sword", "mesh_color": "334466",
			"special_skill": "void_step_strike", "chapter": 5,
		},
		{
			"id": "zhu_yin_greatsword", "display_name": "Zhu Yin's Greatsword / 烛阴·终末",
			"hand": "right", "primary": "dragon_slash", "secondary": "torch_breath_slash",
			"mesh_shape": "dragon_greatsword", "mesh_color": "553322",
			"has_hyper_armor": true, "special_skill": "dragon_breath_beam",
			"chapter": 5, "is_legendary": true,
		},
		{
			"id": "soul_river_seal", "display_name": "Soul River Seal / 魂河印",
			"hand": "right", "primary": "void_rift", "secondary": "torch_dragon_breath",
			"mesh_shape": "soul_seal", "mesh_color": "3355aa",
			"special_skill": "final_flame", "chapter": 5,
		},
		{
			"id": "void_talisman", "display_name": "Void Talisman / 虚空符",
			"hand": "left", "primary": "void_step", "secondary": "void_barrier",
			"mesh_shape": "void_talisman", "mesh_color": "223344",
			"chapter": 5,
		},
		{
			"id": "cosmic_beads", "display_name": "Cosmic Prayer Beads / 星河念珠",
			"hand": "right", "primary": "great_silence_prayer", "secondary": "ksitigarbha_vow",
			"mesh_shape": "cosmic_beads", "mesh_color": "4466aa",
			"special_skill": "soul_release", "chapter": 5,
		},
		{
			"id": "ember_remnant_shield", "display_name": "Ember Remnant Shield / 余烬残盾",
			"hand": "left", "primary": "remnant_guard", "secondary": "ember_counter",
			"mesh_shape": "ember_shield", "mesh_color": "552211",
			"guard": {"absorption": 0.85, "stability": 0.78, "front_dot": 0.10},
			"chapter": 5,
		},
	]


static func scene() -> Dictionary:
	return {
		"chapter_id": "chapter_05",
		"theme_name": "Throne of Ashes / 烬座",
		"ambient_color": Color("151520"),
		"ambient_energy": 0.12,
		"fog_color": Color("101020"),
		"fog_energy": 0.38,
		"fog_density": 0.006,
		"key_light_color": Color("ff8844"),
		"key_light_energy": 0.7,
		"key_light_rotation": Vector3(-15, -60, 0),
		"fill_light_color": Color("4444aa"),
		"fill_light_energy": 0.3,
		"particles": [
			{"type": "soul_stream", "color": Color("4466ff"), "amount": 35, "region": "scattered"},
			{"type": "ember_float", "color": Color("ff6622"), "amount": 25, "region": "scattered"},
			{"type": "dying_star", "color": Color("ffddaa"), "amount": 8, "region": "sky"},
			{"type": "void_dust", "color": Color("222244"), "amount": 15, "region": "ground"},
		],
		"materials": {
			"wall": {"color": "181828", "roughness": 0.88, "metallic": 0.15},
			"floor": {"color": "0a0a15", "roughness": 0.82, "metallic": 0.20},
			"void": {"color": "050510", "roughness": 1.0, "metallic": 0.0, "emission": "000022", "emission_energy": 0.3},
			"ember_bronze": {"color": "553322", "roughness": 0.35, "metallic": 0.85, "emission": "ff6611", "emission_energy": 3.5},
			"soul_river": {"color": "334488", "roughness": 0.1, "metallic": 0.3, "emission": "2255dd", "emission_energy": 2.5},
			"furnace_core": {"color": "ff4400", "roughness": 0.05, "metallic": 0.5, "emission": "ff2200", "emission_energy": 8.0},
		},
	}
