class_name Chapter1Content
extends RefCounted
## Chapter 1 content: 灵墟·觉醒 (Spirit Ruins · Awakening)
## Theme: Abandoned Han Dynasty Guardian Temple
## Palette: moonlit_stone, moss, low_fog

static func enemies() -> Array[Dictionary]:
	return [
		{
			"id": "lost_soul_soldier",
			"display_name": "Lost Soul Soldier / 失魂士兵",
			"max_health": 65.0, "move_speed": 3.2, "aggro_range": 11.0,
			"disengage_range": 18.0, "leash_range": 15.0, "attack_range": 1.9,
			"poise_limit": 18.0, "reward": 28, "stagger_duration": 0.52,
			"attack": {"windup": 0.62, "active": 0.16, "recovery": 0.72, "damage": 14.0, "stagger": 18.0, "lunge": 1.2},
			"body_color": "1a2a1f", "weapon_color": "3a4038", "eye_emission": "44ff88",
			"weapon_shape": "rusted_blade", "body_type": "wraith_thin",
			"behavior": "slow_patrol",
			"chapter": 1,
		},
		{
			"id": "temple_guardian_warrior",
			"display_name": "Temple Guardian Warrior / 庙宇守护武士",
			"max_health": 95.0, "move_speed": 2.8, "aggro_range": 14.0,
			"disengage_range": 22.0, "leash_range": 18.0, "attack_range": 2.35,
			"poise_limit": 32.0, "reward": 42, "stagger_duration": 0.45,
			"attack": {"windup": 0.52, "active": 0.20, "recovery": 0.68, "damage": 20.0, "stagger": 26.0, "lunge": 1.55},
			"body_color": "2a2820", "weapon_color": "5a5040", "eye_emission": "ffaa22",
			"weapon_shape": "temple_halberd", "body_type": "armored_medium",
			"behavior": "defensive_hold",
			"chapter": 1,
		},
		{
			"id": "mirror_shade",
			"display_name": "Mirror Shade / 镜影",
			"max_health": 38.0, "move_speed": 6.5, "aggro_range": 9.0,
			"disengage_range": 15.0, "leash_range": 12.0, "attack_range": 1.55,
			"poise_limit": 8.0, "reward": 22, "stagger_duration": 0.62,
			"attack": {"windup": 0.16, "active": 0.08, "recovery": 0.22, "damage": 7.0, "stagger": 6.0, "lunge": 0.65},
			"body_color": "8899aa", "weapon_color": "aabbcc", "eye_emission": "ffffff",
			"weapon_shape": "glass_shard", "body_type": "ethereal_flicker",
			"behavior": "teleport_ambush",
			"chapter": 1,
		},
		{
			"id": "furnace_slag_beast",
			"display_name": "Furnace Slag Beast / 炉渣兽",
			"max_health": 140.0, "move_speed": 2.2, "aggro_range": 12.0,
			"disengage_range": 20.0, "leash_range": 16.0, "attack_range": 2.8,
			"poise_limit": 55.0, "reward": 65, "stagger_duration": 0.35,
			"attack": {"windup": 0.82, "active": 0.28, "recovery": 0.95, "damage": 28.0, "stagger": 36.0, "lunge": 1.9},
			"body_color": "2a1810", "weapon_color": "ff5518", "eye_emission": "ff3300",
			"weapon_shape": "slag_fist", "body_type": "hulking_molten",
			"behavior": "slow_crusher",
			"chapter": 1,
		},
		{
			# G-03：第三原型——远程/伏击（投射物 + 后撤）
			"id": "ember_shade_skirmisher",
			"display_name": "Ember Shade Skirmisher / 烬影伏击者",
			"max_health": 48.0, "move_speed": 4.6, "aggro_range": 13.0,
			"disengage_range": 21.0, "leash_range": 15.0, "attack_range": 9.0,
			"preferred_distance": 7.0, "retreat_trigger": 4.0,
			"poise_limit": 12.0, "reward": 30, "stagger_duration": 0.55,
			"attack": {"windup": 0.52, "active": 0.12, "recovery": 0.72, "damage": 11.0, "stagger": 9.0, "lunge": 0.85},
			"body_color": "3a1830", "weapon_color": "cc4488", "eye_emission": "ff66aa",
			"weapon_shape": "glass_shard", "body_type": "ethereal_flicker",
			"behavior": "ranged_ambush",
			"archetype": "ember_skirmisher",
			"proj_speed": 11.5, "proj_lifetime": 2.6,
			"chapter": 1,
		},
	]


static func elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_bronze_mirror_keeper",
			"display_name": "Bronze Mirror Keeper / 铜镜守护者",
			"max_health": 200.0, "move_speed": 3.5, "aggro_range": 15.0,
			"disengage_range": 22.0, "leash_range": 18.0, "attack_range": 2.5,
			"poise_limit": 48.0, "reward": 120,
			"special_ability": "mirror_reflect",
			"behavior": "defensive_hold",
			"appears_in": "level_01_03", "body_color": "5a4830",
			"weapon_shape": "bronze_mirror_shield", "body_type": "armored_heavy",
		},
		{
			"id": "elite_elixir_golem",
			"display_name": "Elixir Golem / 丹药魔像",
			"max_health": 240.0, "move_speed": 1.8, "aggro_range": 13.0,
			"disengage_range": 20.0, "leash_range": 16.0, "attack_range": 3.0,
			"poise_limit": 80.0, "reward": 150,
			"special_ability": "toxic_burst",
			"behavior": "area_denial",
			"appears_in": "level_01_04", "body_color": "2a5a30",
			"weapon_shape": "stone_fist", "body_type": "massive_golem",
		},
	]


static func boss() -> Dictionary:
	return {
		"id": "boss_giant_gate",
		"display_name": "守炉灵·巨阙 / Furnace-Keeper · Giant Gate",
		"max_health": 360.0, "reward": 350,
		"arena": "circular_sanctum_open_sky",
		"chapter": 1, "chinese_name": "巨阙",
		"phases": {
			"1": {
				"threshold": 1.0,
				"description": "Mechanical guardian — slow, telegraphed sweeps and overhead slams",
				"attacks": [
					{"name": "horizontal_sweep", "windup": 0.95, "active": 0.28, "recovery": 0.85, "damage": 24.0, "stagger": 28.0, "lunge": 1.4, "heavy": false},
					{"name": "overhead_slam", "windup": 1.35, "active": 0.32, "recovery": 1.15, "damage": 36.0, "stagger": 42.0, "lunge": 2.0, "heavy": true},
					{"name": "furnace_breath", "windup": 1.55, "active": 0.45, "recovery": 1.3, "damage": 20.0, "stagger": 18.0, "lunge": 0.0, "heavy": false, "type": "cone_aoe", "range": 5.0},
				],
				"vfx": "mechanical_steam_puffs",
				"lighting": "cool_blue_moonlight",
			},
			"2": {
				"threshold": 0.6,
				"description": "Furnace overload — faster, fiery attacks, ember trails",
				"attacks": [
					{"name": "flame_sweep", "windup": 0.62, "active": 0.22, "recovery": 0.58, "damage": 28.0, "stagger": 32.0, "lunge": 1.8, "heavy": false},
					{"name": "ember_slam", "windup": 0.88, "active": 0.28, "recovery": 0.78, "damage": 42.0, "stagger": 50.0, "lunge": 2.4, "heavy": true},
					{"name": "furnace_burst", "windup": 1.05, "active": 0.35, "recovery": 0.9, "damage": 32.0, "stagger": 36.0, "lunge": 0.0, "heavy": true, "type": "radial_aoe", "range": 4.0},
					{"name": "charge_rush", "windup": 0.78, "active": 0.30, "recovery": 0.72, "damage": 26.0, "stagger": 30.0, "lunge": 5.5, "heavy": false},
				],
				"vfx": "orange_ember_trails",
				"lighting": "flickering_fire_orange",
			},
		},
		"vfx_unique": {
			"intro": "ancient_seal_cracking",
			"death": "furnace_collapse_implosion",
			"hit": "stone_sparks",
			"arena": "moonlight_through_collapsed_dome",
			"ground_effect": "steam_vents",
		},
		# G-02：章节覆盖治疗惩罚偏好（近距 AoE 优先）
		"healing_punish": {
			"prefer_variants": ["aoe_burst", "gap_close", "ranged_snipe"],
			"windup_scale": 0.55,
		},
	}


static func spells() -> Array[Dictionary]:
	return [
		{
			"id": "spirit_fire_bolt", "display_name": "Spirit Fire Bolt / 灵火弹",
			"focus_cost": 12.0, "cast_time": 0.55, "damage": 24.0, "stagger": 14.0,
			"proj_speed": 17.0, "proj_lifetime": 2.2, "spell_type": "spirit_fire",
			"homing": false, "chapter": 1,
		},
		{
			"id": "temple_seal_shockwave", "display_name": "Temple Seal Shockwave / 庙印冲击波",
			"focus_cost": 20.0, "cast_time": 0.68, "damage": 32.0, "stagger": 28.0,
			"proj_speed": 9.0, "proj_lifetime": 1.4, "spell_type": "seal_shockwave",
			"homing": true, "homing_strength": 2.5, "chapter": 1,
		},
		{
			"id": "guardian_wall", "display_name": "Guardian Wall / 护法障壁",
			"focus_cost": 18.0, "cast_time": 0.45, "damage": 0.0, "stagger": 0.0,
			"aoe_range": 4.0, "spell_type": "barrier",
			"effect": "temporary_damage_reduction", "duration": 8.0, "reduction": 0.35,
			"chapter": 1,
		},
	]


static func weapons() -> Array[Dictionary]:
	return [
		{
			"id": "guardian_sword_ch1", "display_name": "Guardian's Straight Sword / 守炉直剑",
			"hand": "right", "primary": "sword_light", "secondary": "sword_heavy",
			"mesh_shape": "guardian_sword_ch1", "mesh_color": "a9a18c",
			"damage_bonus": 1.0, "chapter": 1,
		},
		{
			"id": "reliquary_shield_ch1", "display_name": "Reliquary Shield / 圣匣盾",
			"hand": "left", "primary": "shield_guard", "secondary": "shield_parry",
			"mesh_shape": "temple_shield", "mesh_color": "614725",
			"guard": {"absorption": 0.82, "stability": 0.72, "front_dot": 0.15},
			"chapter": 1,
		},
		{
			"id": "bronze_mirror_blade", "display_name": "Bronze Mirror Blade / 铜镜刃",
			"hand": "right", "primary": "mirror_light", "secondary": "mirror_reflect",
			"mesh_shape": "bronze_blade", "mesh_color": "b8975a",
			"special_skill": "reflect_projectile", "chapter": 1,
		},
		{
			"id": "temple_guardian_halberd", "display_name": "Temple Guardian Halberd / 庙宇戟",
			"hand": "right", "primary": "halberd_thrust", "secondary": "halberd_sweep",
			"mesh_shape": "temple_halberd", "mesh_color": "5a5040",
			"has_hyper_armor": true, "chapter": 1,
		},
		{
			"id": "spirit_seal_ch1", "display_name": "Spirit Seal / 灵墟法印",
			"hand": "right", "primary": "spirit_fire_bolt", "secondary": "temple_seal_shockwave",
			"mesh_shape": "spirit_seal", "mesh_color": "448866",
			"chapter": 1,
		},
		{
			"id": "prayer_bell_ch1", "display_name": "Temple Prayer Bell / 庙铃",
			"hand": "right", "primary": "bell_heal", "secondary": "bell_ward",
			"mesh_shape": "temple_bell", "mesh_color": "c8a050",
			"chapter": 1,
		},
	]


static func scene() -> Dictionary:
	return {
		"chapter_id": "chapter_01",
		"theme_name": "Spirit Ruins / 灵墟",
		"ambient_color": Color("4a6078"),
		"ambient_energy": 0.22,
		"fog_color": Color("1a3040"),
		"fog_energy": 0.30,
		"fog_density": 0.014,
		"key_light_color": Color("8aaccc"),
		"key_light_energy": 0.9,
		"key_light_rotation": Vector3(-48, -22, 0),
		"fill_light_color": Color("558888"),
		"fill_light_energy": 0.4,
		"particles": [
			{"type": "mist_low", "color": Color("6688aa"), "amount": 20, "region": "ground"},
			{"type": "spirit_motes", "color": Color("88ffcc"), "amount": 15, "region": "scattered"},
			{"type": "moon_dust", "color": Color("aaaacc"), "amount": 10, "region": "ceiling_beams"},
		],
		"materials": {
			"wall": {"color": "1a2822", "roughness": 0.92, "metallic": 0.03},
			"floor": {"color": "1e2628", "roughness": 0.88, "metallic": 0.05},
			"pillar": {"color": "222c28", "roughness": 0.85, "metallic": 0.08},
			"moss": {"color": "1a3a28", "roughness": 0.95, "metallic": 0.0},
			"bronze": {"color": "5a4828", "roughness": 0.4, "metallic": 0.75},
			"jade_lichen": {"color": "33cc88", "roughness": 0.6, "metallic": 0.0, "emission": "22ff66", "emission_energy": 1.2},
		},
	}
