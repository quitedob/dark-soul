class_name ChapterContentData
extends RefCounted
## Master content definitions for all 5 chapters of 烬渊 (Ember Abyss).
## Every chapter has COMPLETELY UNIQUE enemies, bosses, elite monsters,
## spells, weapons, scene themes, and lighting designs — zero reuse.

# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 1 — 灵墟·觉醒 (Spirit Ruins · Awakening)
# Theme: Abandoned Han Dynasty Guardian Temple
# Palette: moonlit_stone, moss, low_fog
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_1_enemies() -> Array[Dictionary]:
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
	]


static func chapter_1_elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_bronze_mirror_keeper",
			"display_name": "Bronze Mirror Keeper / 铜镜守护者",
			"max_health": 200.0, "move_speed": 3.5, "aggro_range": 15.0,
			"attack_range": 2.5, "poise_limit": 48.0, "reward": 120,
			"special_ability": "mirror_reflect",  # Reflects projectiles
			"appears_in": "level_01_03", "body_color": "5a4830",
			"weapon_shape": "bronze_mirror_shield", "body_type": "armored_heavy",
		},
		{
			"id": "elite_elixir_golem",
			"display_name": "Elixir Golem / 丹药魔像",
			"max_health": 240.0, "move_speed": 1.8, "aggro_range": 13.0,
			"attack_range": 3.0, "poise_limit": 80.0, "reward": 150,
			"special_ability": "toxic_burst",  # Poison AoE on phase change
			"appears_in": "level_01_04", "body_color": "2a5a30",
			"weapon_shape": "stone_fist", "body_type": "massive_golem",
		},
	]


static func chapter_1_boss() -> Dictionary:
	return {
		"id": "boss_giant_gate",
		"display_name": "守炉灵·巨阙 / Furnace-Keeper · Giant Gate",
		"max_health": 360.0, "reward": 350,
		"arena": "circular_sanctum_open_sky",
		"chapter": 1, "chinese_name": "巨阙",
		"phases": {
			"1": {  # 100%-60% HP: Mechanical Guardian Pattern
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
			"2": {  # 60%-0% HP: Overload Frenzy
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
		"vfx_unique": {  # Boss-specific VFX (NOT reused by any other boss)
			"intro": "ancient_seal_cracking",
			"death": "furnace_collapse_implosion",
			"hit": "stone_sparks",
			"arena": "moonlight_through_collapsed_dome",
			"ground_effect": "steam_vents",
		},
	}


static func chapter_1_spells() -> Array[Dictionary]:
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


static func chapter_1_weapons() -> Array[Dictionary]:
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


static func chapter_1_scene() -> Dictionary:
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


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 2 — 血铁·战歌 (Blood & Iron · Warsong)
# Theme: Eternal War Mountain Fortress (Ming Dynasty)
# Palette: blood_sunset, war_smoke, beacon_fire
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_2_enemies() -> Array[Dictionary]:
	return [
		{
			"id": "battle_worn_soldier",
			"display_name": "Battle-Worn Soldier / 残兵",
			"max_health": 75.0, "move_speed": 3.5, "aggro_range": 13.0,
			"disengage_range": 20.0, "leash_range": 17.0, "attack_range": 2.0,
			"poise_limit": 22.0, "reward": 35, "stagger_duration": 0.48,
			"attack": {"windup": 0.48, "active": 0.18, "recovery": 0.62, "damage": 16.0, "stagger": 20.0, "lunge": 1.3},
			"body_color": "2a1a15", "weapon_color": "4a3828", "eye_emission": "ff4422",
			"weapon_shape": "war_broken_sword", "body_type": "ragged_soldier",
			"behavior": "formation_fight",
			"chapter": 2,
		},
		{
			"id": "war_dog_wraith",
			"display_name": "War Dog Wraith / 战犬亡灵",
			"max_health": 48.0, "move_speed": 7.2, "aggro_range": 12.0,
			"disengage_range": 18.0, "leash_range": 14.0, "attack_range": 1.45,
			"poise_limit": 10.0, "reward": 25, "stagger_duration": 0.58,
			"attack": {"windup": 0.18, "active": 0.08, "recovery": 0.28, "damage": 9.0, "stagger": 7.0, "lunge": 1.1},
			"body_color": "1a1512", "weapon_color": "ffffff", "eye_emission": "ff4444",
			"weapon_shape": "spectral_fangs", "body_type": "hound_spectral",
			"behavior": "pack_hunter",
			"chapter": 2,
		},
		{
			"id": "camp_guard_wraith",
			"display_name": "Camp Guard Wraith / 营守亡灵",
			"max_health": 90.0, "move_speed": 3.0, "aggro_range": 14.0,
			"disengage_range": 21.0, "leash_range": 18.0, "attack_range": 2.4,
			"poise_limit": 35.0, "reward": 45, "stagger_duration": 0.42,
			"attack": {"windup": 0.58, "active": 0.22, "recovery": 0.72, "damage": 22.0, "stagger": 28.0, "lunge": 1.6},
			"body_color": "2a2020", "weapon_color": "5a4838", "eye_emission": "ff6600",
			"weapon_shape": "siege_glaive", "body_type": "armored_heavy",
			"behavior": "shield_wall",
			"chapter": 2,
		},
		{
			"id": "torture_device_spirit",
			"display_name": "Torture Device Spirit / 刑具精魄",
			"max_health": 110.0, "move_speed": 1.5, "aggro_range": 8.0,
			"disengage_range": 14.0, "leash_range": 10.0, "attack_range": 3.2,
			"poise_limit": 60.0, "reward": 55, "stagger_duration": 0.38,
			"attack": {"windup": 1.05, "active": 0.35, "recovery": 1.2, "damage": 30.0, "stagger": 40.0, "lunge": 1.0},
			"body_color": "3a1818", "weapon_color": "881111", "eye_emission": "ff1111",
			"weapon_shape": "iron_maiden_spikes", "body_type": "immobile_turret",
			"behavior": "area_denial",
			"chapter": 2,
		},
		{
			"id": "generals_personal_guard",
			"display_name": "General's Personal Guard / 将军亲卫",
			"max_health": 120.0, "move_speed": 4.0, "aggro_range": 15.0,
			"disengage_range": 23.0, "leash_range": 20.0, "attack_range": 2.6,
			"poise_limit": 42.0, "reward": 70, "stagger_duration": 0.35,
			"attack": {"windup": 0.42, "active": 0.20, "recovery": 0.55, "damage": 25.0, "stagger": 32.0, "lunge": 1.8},
			"body_color": "2a1515", "weapon_color": "8a3828", "eye_emission": "ff3300",
			"weapon_shape": "guandao", "body_type": "elite_armored",
			"behavior": "aggressive_flank",
			"chapter": 2,
		},
		{
			"id": "beacon_keeper_wraith",
			"display_name": "Beacon Keeper Wraith / 烽火守望者",
			"max_health": 95.0, "move_speed": 2.5, "aggro_range": 16.0,
			"disengage_range": 24.0, "leash_range": 20.0, "attack_range": 8.0,
			"poise_limit": 25.0, "reward": 50, "stagger_duration": 0.52,
			"attack": {"windup": 0.75, "active": 0.25, "recovery": 0.85, "damage": 18.0, "stagger": 22.0, "lunge": 0.0},
			"body_color": "2a2018", "weapon_color": "ff6622", "eye_emission": "ffaa00",
			"weapon_shape": "beacon_flame", "body_type": "tower_ranged",
			"behavior": "ranged_artillery",
			"chapter": 2,
		},
	]


static func chapter_2_elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_siege_commander",
			"display_name": "Siege Commander / 攻城校尉",
			"max_health": 220.0, "move_speed": 3.8, "aggro_range": 16.0,
			"attack_range": 2.8, "poise_limit": 55.0, "reward": 140,
			"special_ability": "rally_troops",  # Buffs nearby enemies
			"appears_in": "level_02_02", "body_color": "3a2020",
			"weapon_shape": "commander_sword", "body_type": "armored_heavy",
		},
		{
			"id": "elite_torture_master",
			"display_name": "Torture Master / 刑讯官",
			"max_health": 180.0, "move_speed": 4.2, "aggro_range": 13.0,
			"attack_range": 2.2, "poise_limit": 38.0, "reward": 130,
			"special_ability": "bleed_chain",  # Inflicts bleed status
			"appears_in": "level_02_03", "body_color": "1a1010",
			"weapon_shape": "chain_hook", "body_type": "agile_armored",
		},
		{
			"id": "elite_beacon_lord",
			"display_name": "Beacon Lord / 烽火将",
			"max_health": 260.0, "move_speed": 2.0, "aggro_range": 18.0,
			"attack_range": 10.0, "poise_limit": 65.0, "reward": 160,
			"special_ability": "fire_rain",  # Calls fire arrows from above
			"appears_in": "level_02_04", "body_color": "2a1810",
			"weapon_shape": "beacon_bow", "body_type": "ranged_commander",
		},
	]


static func chapter_2_boss() -> Dictionary:
	return {
		"id": "boss_xing_tian",
		"display_name": "血将军·刑天 / Blood General · Xing Tian",
		"max_health": 580.0, "reward": 600,
		"arena": "mountaintop_colosseum",
		"chapter": 2, "chinese_name": "刑天",
		"phases": {
			"1": {  # 100%-70%: Shackled Warrior
				"threshold": 1.0,
				"description": "Shackled warrior — broken chains restrict movement, predictable overhead smashes",
				"attacks": [
					{"name": "chain_pull", "windup": 0.72, "active": 0.25, "recovery": 0.68, "damage": 28.0, "stagger": 32.0, "lunge": 2.5, "heavy": false, "type": "pull_toward"},
					{"name": "shackle_slam", "windup": 1.22, "active": 0.35, "recovery": 1.05, "damage": 44.0, "stagger": 52.0, "lunge": 2.2, "heavy": true},
					{"name": "spinning_chain", "windup": 0.88, "active": 0.42, "recovery": 0.75, "damage": 22.0, "stagger": 24.0, "lunge": 0.0, "heavy": false, "type": "radial_aoe", "range": 3.5},
				],
				"vfx": "broken_chain_particles",
				"lighting": "blood_sunset_dim",
			},
			"2": {  # 70%-30%: Chains Broken
				"threshold": 0.7,
				"description": "Chains shattered — dual-wielding wild strikes, increased speed and aggression",
				"attacks": [
					{"name": "dual_slash", "windup": 0.44, "active": 0.24, "recovery": 0.48, "damage": 34.0, "stagger": 38.0, "lunge": 2.2, "heavy": false},
					{"name": "frenzy_flurry", "windup": 0.38, "active": 0.55, "recovery": 0.62, "damage": 8.0, "stagger": 10.0, "lunge": 0.0, "heavy": false, "type": "multi_hit", "hits": 5},
					{"name": "headless_charge", "windup": 0.65, "active": 0.28, "recovery": 0.58, "damage": 38.0, "stagger": 44.0, "lunge": 6.0, "heavy": true},
					{"name": "war_cry_shockwave", "windup": 0.85, "active": 0.30, "recovery": 0.72, "damage": 20.0, "stagger": 30.0, "lunge": 0.0, "heavy": false, "type": "radial_aoe", "range": 6.0},
				],
				"vfx": "blood_mist_aura",
				"lighting": "crimson_rage_glow",
			},
			"3": {  # 30%-0%: Last Stand of the Headless
				"threshold": 0.3,
				"description": "Wounds emit spectral blood — attacks leave lingering damage zones, enrage timer active",
				"attacks": [
					{"name": "blood_slash", "windup": 0.35, "active": 0.20, "recovery": 0.40, "damage": 40.0, "stagger": 46.0, "lunge": 2.5, "heavy": false, "type": "trail_hazard"},
					{"name": "dying_rage_slam", "windup": 0.55, "active": 0.32, "recovery": 0.55, "damage": 55.0, "stagger": 60.0, "lunge": 3.0, "heavy": true},
					{"name": "blood_geyser", "windup": 0.72, "active": 0.38, "recovery": 0.68, "damage": 30.0, "stagger": 35.0, "lunge": 0.0, "heavy": true, "type": "line_aoe", "length": 8.0},
				],
				"vfx": "spectral_blood_geysers",
				"lighting": "deep_crimson_darkness",
			},
		},
		"vfx_unique": {
			"intro": "chains_shattering",
			"death": "standing_death_petrification",
			"hit": "blood_metal_sparks",
			"arena": "burning_beacon_ring",
			"ground_effect": "blood_pools",
		},
	}


static func chapter_2_spells() -> Array[Dictionary]:
	return [
		{
			"id": "war_cry_art", "display_name": "War Cry Art / 战吼术",
			"focus_cost": 15.0, "cast_time": 0.42, "damage": 0.0, "stagger": 0.0,
			"spell_type": "buff", "effect": "damage_boost", "boost_amount": 0.25, "duration": 12.0,
			"chapter": 2,
		},
		{
			"id": "blood_iron_bolt", "display_name": "Blood Iron Bolt / 血铁飞矢",
			"focus_cost": 16.0, "cast_time": 0.52, "damage": 28.0, "stagger": 22.0,
			"proj_speed": 16.0, "proj_lifetime": 2.0, "spell_type": "blood_iron",
			"homing": true, "homing_strength": 2.0, "chapter": 2,
		},
		{
			"id": "siege_flame", "display_name": "Siege Flame / 攻城焰",
			"focus_cost": 24.0, "cast_time": 0.75, "damage": 38.0, "stagger": 30.0,
			"proj_speed": 8.0, "proj_lifetime": 1.5, "spell_type": "siege_flame",
			"homing": false, "aoe_on_hit": true, "aoe_range": 3.0, "chapter": 2,
		},
		{
			"id": "hero_spirit_summon", "display_name": "Hero Spirit Summon / 英魂召唤",
			"focus_cost": 28.0, "cast_time": 1.05, "damage": 0.0, "stagger": 0.0,
			"spell_type": "summon", "effect": "spawn_spirit_ally", "ally_duration": 20.0,
			"chapter": 2,
		},
		{
			"id": "iron_fortress_blessing", "display_name": "Iron Fortress Blessing / 铁壁祝福",
			"focus_cost": 22.0, "cast_time": 0.62, "damage": 0.0, "stagger": 0.0,
			"spell_type": "prayer", "effect": "defense_boost", "boost_amount": 0.3, "duration": 15.0,
			"chapter": 2,
		},
	]


static func chapter_2_weapons() -> Array[Dictionary]:
	return [
		{
			"id": "war_glaive_ch2", "display_name": "War Glaive / 战刀",
			"hand": "right", "primary": "glaive_slash", "secondary": "glaive_cleave",
			"mesh_shape": "ming_glaive", "mesh_color": "5a3a28",
			"damage_bonus": 1.1, "has_hyper_armor": false, "chapter": 2,
		},
		{
			"id": "xingtian_dual_axes", "display_name": "Xing Tian's Twin Axes / 刑天双斧",
			"hand": "right", "primary": "right_axe_strike", "secondary": "colossal_leap",
			"mesh_shape": "blood_axe", "mesh_color": "8a2a1a",
			"damage_bonus": 1.2, "has_hyper_armor": true, "chapter": 2,
		},
		{
			"id": "beacon_greatbow", "display_name": "Beacon Greatbow / 烽火长弓",
			"hand": "right", "primary": "greatbow_shot", "secondary": "fire_arrow",
			"mesh_shape": "war_bow", "mesh_color": "6a3a1a",
			"chapter": 2,
		},
		{
			"id": "iron_tower_shield", "display_name": "Iron Tower Shield / 铁塔盾",
			"hand": "left", "primary": "shield_guard", "secondary": "shield_bash_heavy",
			"mesh_shape": "tower_shield", "mesh_color": "4a3828",
			"guard": {"absorption": 0.90, "stability": 0.82, "front_dot": 0.12},
			"chapter": 2,
		},
		{
			"id": "blood_seal_ch2", "display_name": "Blood Battle Seal / 血战印",
			"hand": "right", "primary": "blood_iron_bolt", "secondary": "siege_flame",
			"mesh_shape": "blood_seal", "mesh_color": "882222",
			"chapter": 2,
		},
		{
			"id": "war_banner_talisman", "display_name": "War Banner Talisman / 战旗符",
			"hand": "left", "primary": "hero_spirit_summon", "secondary": "iron_fortress_blessing",
			"mesh_shape": "war_banner", "mesh_color": "aa3333",
			"chapter": 2,
		},
	]


static func chapter_2_scene() -> Dictionary:
	return {
		"chapter_id": "chapter_02",
		"theme_name": "Blood & Iron / 血铁",
		"ambient_color": Color("3a2a22"),
		"ambient_energy": 0.18,
		"fog_color": Color("2a1a15"),
		"fog_energy": 0.45,
		"fog_density": 0.018,
		"key_light_color": Color("cc6644"),
		"key_light_energy": 0.85,
		"key_light_rotation": Vector3(-35, -45, 0),
		"fill_light_color": Color("884422"),
		"fill_light_energy": 0.5,
		"particles": [
			{"type": "ash_fall", "color": Color("666666"), "amount": 35, "region": "sky"},
			{"type": "ember_sparks", "color": Color("ff6622"), "amount": 25, "region": "scattered"},
			{"type": "war_smoke", "color": Color("443322"), "amount": 15, "region": "ground"},
		],
		"materials": {
			"wall": {"color": "2a2018", "roughness": 0.85, "metallic": 0.08},
			"floor": {"color": "1a1510", "roughness": 0.78, "metallic": 0.12},
			"rampart": {"color": "2a2218", "roughness": 0.82, "metallic": 0.10},
			"blood_stain": {"color": "3a0808", "roughness": 0.90, "metallic": 0.0},
			"beacon_fire": {"color": "ff4400", "roughness": 0.2, "metallic": 0.0, "emission": "ff2200", "emission_energy": 5.0},
			"iron": {"color": "3a3028", "roughness": 0.35, "metallic": 0.82},
		},
	}


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 3 — 玉障·迷心 (Jade Veil · Lost Mind)
# Theme: Illusion-Bound Jade Forest / Classical Garden
# Palette: jade_light, foxfire, unreliable_reflections
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_3_enemies() -> Array[Dictionary]:
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


static func chapter_3_elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_memory_eater",
			"display_name": "Memory Eater / 噬忆者",
			"max_health": 190.0, "move_speed": 4.5, "aggro_range": 14.0,
			"attack_range": 2.4, "poise_limit": 42.0, "reward": 135,
			"special_ability": "memory_steal",  # Temporarily disables one random spell
			"appears_in": "level_03_02", "body_color": "664488",
			"weapon_shape": "memory_scythe", "body_type": "ethereal_elite",
		},
		{
			"id": "elite_fox_bride",
			"display_name": "Fox Bride / 狐嫁娘",
			"max_health": 170.0, "move_speed": 5.2, "aggro_range": 13.0,
			"attack_range": 3.0, "poise_limit": 35.0, "reward": 145,
			"special_ability": "seduction_charm",  # Reverses player controls briefly
			"appears_in": "level_03_03", "body_color": "cc2244",
			"weapon_shape": "bridal_veil", "body_type": "floating_dress_elite",
		},
		{
			"id": "elite_reflection_lord",
			"display_name": "Reflection Lord / 镜像主",
			"max_health": 210.0, "move_speed": 3.8, "aggro_range": 15.0,
			"attack_range": 2.8, "poise_limit": 50.0, "reward": 155,
			"special_ability": "create_clone",  # Spawns mirror clone with 40% stats
			"appears_in": "level_03_04", "body_color": "88aacc",
			"weapon_shape": "mirror_blade", "body_type": "reflection_knight",
		},
	]


static func chapter_3_boss() -> Dictionary:
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


static func chapter_3_spells() -> Array[Dictionary]:
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


static func chapter_3_weapons() -> Array[Dictionary]:
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


static func chapter_3_scene() -> Dictionary:
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


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 4 — 天崩·陨落 (Celestial Fall)
# Theme: Shattered Floating Immortal City (Tang Dynasty)
# Palette: fixed_sunset, cloud_sea, divine_decay
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_4_enemies() -> Array[Dictionary]:
	return [
		{
			"id": "stairway_guard_wraith",
			"display_name": "Stairway Guard Wraith / 天梯守灵",
			"max_health": 82.0, "move_speed": 3.4, "aggro_range": 13.0,
			"disengage_range": 20.0, "leash_range": 17.0, "attack_range": 2.1,
			"poise_limit": 26.0, "reward": 38, "stagger_duration": 0.46,
			"attack": {"windup": 0.45, "active": 0.18, "recovery": 0.58, "damage": 17.0, "stagger": 22.0, "lunge": 1.4},
			"body_color": "aaaacc", "weapon_color": "ccddff", "eye_emission": "ddddff",
			"weapon_shape": "cloud_glaive", "body_type": "celestial_guard",
			"behavior": "float_patrol",
			"chapter": 4,
		},
		{
			"id": "cloud_sky_eagle",
			"display_name": "Cloud Sky Eagle / 云天鹰",
			"max_health": 55.0, "move_speed": 8.0, "aggro_range": 16.0,
			"disengage_range": 24.0, "leash_range": 20.0, "attack_range": 1.8,
			"poise_limit": 15.0, "reward": 35, "stagger_duration": 0.55,
			"attack": {"windup": 0.28, "active": 0.10, "recovery": 0.35, "damage": 11.0, "stagger": 10.0, "lunge": 2.0},
			"body_color": "ddeeff", "weapon_color": "ffffff", "eye_emission": "ffffff",
			"weapon_shape": "talon", "body_type": "flying_large",
			"behavior": "dive_bomb",
			"chapter": 4,
		},
		{
			"id": "elixir_furnace_spirit",
			"display_name": "Elixir Furnace Spirit / 丹炉精",
			"max_health": 95.0, "move_speed": 2.2, "aggro_range": 10.0,
			"disengage_range": 16.0, "leash_range": 13.0, "attack_range": 3.5,
			"poise_limit": 40.0, "reward": 48, "stagger_duration": 0.40,
			"attack": {"windup": 0.72, "active": 0.28, "recovery": 0.82, "damage": 24.0, "stagger": 30.0, "lunge": 0.0},
			"body_color": "aa6622", "weapon_color": "ff8833", "eye_emission": "ff6600",
			"weapon_shape": "furnace_body", "body_type": "barrel_heavy",
			"behavior": "explosive_burst",
			"chapter": 4,
		},
		{
			"id": "alchemy_fallen_immortal",
			"display_name": "Alchemy Fallen Immortal / 丹堕仙",
			"max_health": 110.0, "move_speed": 3.8, "aggro_range": 14.0,
			"disengage_range": 21.0, "leash_range": 18.0, "attack_range": 2.8,
			"poise_limit": 35.0, "reward": 60, "stagger_duration": 0.42,
			"attack": {"windup": 0.48, "active": 0.22, "recovery": 0.55, "damage": 22.0, "stagger": 28.0, "lunge": 1.8},
			"body_color": "ccaa88", "weapon_color": "ddccaa", "eye_emission": "ffaa44",
			"weapon_shape": "alchemy_sword", "body_type": "robed_caster",
			"behavior": "poison_mist_zone",
			"chapter": 4,
		},
		{
			"id": "book_spirit",
			"display_name": "Book Spirit / 书精",
			"max_health": 42.0, "move_speed": 3.0, "aggro_range": 10.0,
			"disengage_range": 16.0, "leash_range": 13.0, "attack_range": 6.0,
			"poise_limit": 8.0, "reward": 30, "stagger_duration": 0.62,
			"attack": {"windup": 0.55, "active": 0.15, "recovery": 0.48, "damage": 9.0, "stagger": 8.0, "lunge": 0.0},
			"body_color": "ddcc88", "weapon_color": "ffddaa", "eye_emission": "ffcc44",
			"weapon_shape": "floating_pages", "body_type": "floating_book",
			"behavior": "ranged_barrage",
			"chapter": 4,
		},
		{
			"id": "library_guardian_spirit",
			"display_name": "Library Guardian Spirit / 藏书守护灵",
			"max_health": 130.0, "move_speed": 2.5, "aggro_range": 12.0,
			"disengage_range": 19.0, "leash_range": 16.0, "attack_range": 3.0,
			"poise_limit": 50.0, "reward": 65, "stagger_duration": 0.38,
			"attack": {"windup": 0.68, "active": 0.25, "recovery": 0.78, "damage": 26.0, "stagger": 34.0, "lunge": 1.5},
			"body_color": "8a8060", "weapon_color": "aa9977", "eye_emission": "ccaa44",
			"weapon_shape": "scripture_blade", "body_type": "armored_heavy",
			"behavior": "gravity_zone",
			"chapter": 4,
		},
		{
			"id": "broken_immortal_body",
			"display_name": "Broken Immortal Body / 碎仙体",
			"max_health": 160.0, "move_speed": 1.8, "aggro_range": 11.0,
			"disengage_range": 17.0, "leash_range": 14.0, "attack_range": 3.5,
			"poise_limit": 70.0, "reward": 75, "stagger_duration": 0.32,
			"attack": {"windup": 0.88, "active": 0.35, "recovery": 1.05, "damage": 32.0, "stagger": 42.0, "lunge": 1.8},
			"body_color": "bbaa88", "weapon_color": "ddcc99", "eye_emission": "ffdd88",
			"weapon_shape": "broken_limb", "body_type": "shambling_giant",
			"behavior": "slow_berserk",
			"chapter": 4,
		},
	]


static func chapter_4_elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_celestial_swordsman",
			"display_name": "Celestial Swordsman / 天剑士",
			"max_health": 230.0, "move_speed": 4.5, "aggro_range": 15.0,
			"attack_range": 2.6, "poise_limit": 52.0, "reward": 160,
			"special_ability": "sword_rain",  # Calls down sword projectiles
			"appears_in": "level_04_01", "body_color": "ccddff",
			"weapon_shape": "celestial_sword", "body_type": "floating_knight",
		},
		{
			"id": "elite_alchemy_master",
			"display_name": "Alchemy Master / 炼丹宗师",
			"max_health": 195.0, "move_speed": 3.2, "aggro_range": 14.0,
			"attack_range": 8.0, "poise_limit": 38.0, "reward": 145,
			"special_ability": "elixir_explosion",  # Throws exploding elixir vials
			"appears_in": "level_04_02", "body_color": "cc8844",
			"weapon_shape": "elixir_vial", "body_type": "robed_caster",
		},
		{
			"id": "elite_scripture_keeper",
			"display_name": "Scripture Keeper / 藏经主",
			"max_health": 210.0, "move_speed": 2.8, "aggro_range": 16.0,
			"attack_range": 5.0, "poise_limit": 60.0, "reward": 150,
			"special_ability": "gravity_inversion",  # Inverts gravity in zone
			"appears_in": "level_04_03", "body_color": "8a8060",
			"weapon_shape": "scripture_tome", "body_type": "gravity_mage",
		},
	]


static func chapter_4_bosses() -> Array[Dictionary]:
	return [
		{  # Sub-boss 1: Wrath Fragment
			"id": "boss_xuan_xiao_wrath",
			"display_name": "玄霄·嗔念 / Xuan Xiao · Wrath Fragment",
			"max_health": 280.0, "reward": 200, "arena": "flaming_wrath_platform",
			"chapter": 4, "chinese_name": "嗔念",
			"phases": {
				"1": {
					"threshold": 1.0,
					"description": "Wrath Fragment — aggressive melee combos, flaming sword strikes",
					"attacks": [
						{"name": "wrath_slash", "windup": 0.38, "active": 0.20, "recovery": 0.42, "damage": 26.0, "stagger": 30.0, "lunge": 2.0, "heavy": false},
						{"name": "flame_combo", "windup": 0.35, "active": 0.55, "recovery": 0.52, "damage": 12.0, "stagger": 14.0, "lunge": 0.0, "type": "multi_hit", "hits": 3},
						{"name": "wrathful_charge", "windup": 0.55, "active": 0.25, "recovery": 0.62, "damage": 30.0, "stagger": 36.0, "lunge": 5.5, "heavy": true},
					],
					"vfx": "red_flame_aura",
					"lighting": "angry_red_glow",
				},
				"2": {
					"threshold": 0.6,
					"description": "Uncontrollable rage — attacks faster, leaves fire pools, self-damaging",
					"attacks": [
						{"name": "rage_flurry", "windup": 0.22, "active": 0.45, "recovery": 0.38, "damage": 18.0, "stagger": 20.0, "lunge": 0.0, "type": "multi_hit", "hits": 5},
						{"name": "self_immolation_burst", "windup": 0.68, "active": 0.35, "recovery": 0.85, "damage": 35.0, "stagger": 42.0, "lunge": 0.0, "type": "radial_aoe", "range": 5.0},
					],
					"vfx": "exploding_fire_pools",
					"lighting": "intense_crimson",
				},
			},
			"vfx_unique": {"intro": "flame_eruption", "death": "rage_dissipates", "arena": "floating_fire_platform", "ground_effect": "lingering_flame_pools"},
		},
		{  # Sub-boss 2: Obsession Fragment
			"id": "boss_xuan_xiao_obsession",
			"display_name": "玄霄·执念 / Xuan Xiao · Obsession Fragment",
			"max_health": 250.0, "reward": 200, "arena": "frozen_ritual_platform",
			"chapter": 4, "chinese_name": "执念",
			"phases": {
				"1": {
					"threshold": 1.0,
					"description": "Obsession Fragment — ice-based attacks, slowing zones, repetitive patterns",
					"attacks": [
						{"name": "ice_lance", "windup": 0.62, "active": 0.20, "recovery": 0.52, "damage": 22.0, "stagger": 16.0, "lunge": 0.0, "type": "projectile"},
						{"name": "frozen_loop", "windup": 0.55, "active": 0.0, "recovery": 0.45, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "status", "effect": "slow"},
						{"name": "obsessive_strike", "windup": 0.42, "active": 0.18, "recovery": 0.38, "damage": 20.0, "stagger": 24.0, "lunge": 1.8, "type": "repeat_3_times"},
					],
					"vfx": "ice_crystal_formation",
					"lighting": "cold_blue_white",
				},
				"2": {
					"threshold": 0.6,
					"description": "Frozen obsession — time-slowing field, crystallized projectiles, arena freeze",
					"attacks": [
						{"name": "time_slow_field", "windup": 0.75, "active": 0.0, "recovery": 0.55, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "type": "arena_modify", "effect": "global_slow"},
						{"name": "crystal_barrage", "windup": 0.58, "active": 0.42, "recovery": 0.62, "damage": 10.0, "stagger": 12.0, "lunge": 0.0, "type": "multi_projectile", "count": 8},
					],
					"vfx": "time_frozen_particles",
					"lighting": "deep_frozen_blue",
				},
			},
			"vfx_unique": {"intro": "ice_shatter_reveal", "death": "shatter_into_crystals", "arena": "frozen_ritual_circle", "ground_effect": "frost_crystals"},
		},
		{  # Chapter Boss: Xuan Xiao True Form
			"id": "boss_xuan_xiao",
			"display_name": "堕仙·玄霄 / Fallen Immortal · Xuan Xiao",
			"max_health": 520.0, "reward": 550, "arena": "collapsing_zenith",
			"chapter": 4, "chinese_name": "玄霄",
			"phases": {
				"1": {
					"threshold": 1.0,
					"description": "Fallen Immortal — transcendent sword techniques, cloud-step dodges, gravity manipulation",
					"attacks": [
						{"name": "celestial_slash", "windup": 0.42, "active": 0.22, "recovery": 0.45, "damage": 28.0, "stagger": 32.0, "lunge": 2.5, "heavy": false},
						{"name": "cloud_step_ambush", "windup": 0.35, "active": 0.18, "recovery": 0.35, "damage": 22.0, "stagger": 24.0, "lunge": 4.0, "type": "teleport_behind"},
						{"name": "gravity_crush", "windup": 0.82, "active": 0.35, "recovery": 0.72, "damage": 32.0, "stagger": 38.0, "lunge": 0.0, "type": "pull_in_aoe", "range": 6.0},
						{"name": "sword_wave", "windup": 0.58, "active": 0.25, "recovery": 0.52, "damage": 24.0, "stagger": 26.0, "lunge": 0.0, "type": "line_projectile", "length": 12.0},
					],
					"vfx": "golden_divine_glow",
					"lighting": "eternal_sunset_gold",
				},
				"2": {
					"threshold": 0.6,
					"description": "Wings unfurled — flight mode, aerial bombardment, wind storms, falling debris",
					"attacks": [
						{"name": "aerial_dive", "windup": 0.48, "active": 0.25, "recovery": 0.55, "damage": 34.0, "stagger": 40.0, "lunge": 6.0, "type": "flying_swoop"},
						{"name": "feather_storm", "windup": 0.62, "active": 0.48, "recovery": 0.68, "damage": 10.0, "stagger": 10.0, "lunge": 0.0, "type": "multi_projectile", "count": 15},
						{"name": "wind_wall", "windup": 0.55, "active": 0.30, "recovery": 0.52, "damage": 20.0, "stagger": 30.0, "lunge": 0.0, "type": "push_back_aoe", "range": 7.0},
					],
					"vfx": "celestial_wing_particles",
					"lighting": "radiant_gold_white",
				},
				"3": {
					"threshold": 0.3,
					"description": "Falling immortal — divine decay, corrupted light, reality-breaking attacks",
					"attacks": [
						{"name": "corrupted_divinity", "windup": 0.72, "active": 0.38, "recovery": 0.68, "damage": 38.0, "stagger": 46.0, "lunge": 3.0, "type": "trail_hazard"},
						{"name": "falling_star_crash", "windup": 0.95, "active": 0.48, "recovery": 1.05, "damage": 48.0, "stagger": 55.0, "lunge": 0.0, "type": "targeted_impact_aoe", "range": 4.5},
						{"name": "zenith_collapse", "windup": 1.15, "active": 0.55, "recovery": 1.25, "damage": 40.0, "stagger": 50.0, "lunge": 0.0, "type": "stage_wide_aoe", "range": 12.0},
					],
					"vfx": "corrupted_divine_light",
					"lighting": "chaotic_gold_darkness",
				},
			},
			"vfx_unique": {"intro": "immortal_descent", "death": "celestial_implosion", "arena": "collapsing_floating_platforms", "ground_effect": "falling_star_debris"},
		},
	]


static func chapter_4_spells() -> Array[Dictionary]:
	return [
		{
			"id": "celestial_lightning_call", "display_name": "Celestial Lightning Call / 天雷召来",
			"focus_cost": 26.0, "cast_time": 0.78, "damage": 42.0, "stagger": 35.0,
			"proj_speed": 22.0, "proj_lifetime": 1.8, "spell_type": "lightning",
			"homing": false, "aoe_on_hit": true, "aoe_range": 2.5, "chapter": 4,
		},
		{
			"id": "gravity_well", "display_name": "Gravity Well / 引力阱",
			"focus_cost": 24.0, "cast_time": 0.65, "damage": 18.0, "stagger": 22.0,
			"proj_speed": 8.0, "proj_lifetime": 2.0, "spell_type": "gravity",
			"homing": false, "effect": "pull_enemies_in", "pull_range": 5.0, "chapter": 4,
		},
		{
			"id": "divine_sword_rain", "display_name": "Divine Sword Rain / 天剑雨",
			"focus_cost": 30.0, "cast_time": 0.90, "damage": 18.0, "stagger": 20.0,
			"spell_type": "rain", "effect": "multi_impact_aoe", "hits": 8, "aoe_range": 6.0,
			"chapter": 4,
		},
		{
			"id": "cloud_step", "display_name": "Cloud Step / 云步",
			"focus_cost": 12.0, "cast_time": 0.22, "damage": 0.0, "stagger": 0.0,
			"spell_type": "mobility", "effect": "short_teleport", "teleport_range": 8.0,
			"chapter": 4,
		},
		{
			"id": "immortality_mantra", "display_name": "Immortality Mantra / 不死真言",
			"focus_cost": 32.0, "cast_time": 0.88, "damage": 0.0, "stagger": 0.0,
			"spell_type": "prayer", "effect": "cannot_die", "duration": 8.0,
			"chapter": 4,
		},
		{
			"id": "heavenly_soldier_protection", "display_name": "Heavenly Soldier Protection / 天兵护体",
			"focus_cost": 20.0, "cast_time": 0.55, "damage": 0.0, "stagger": 0.0,
			"spell_type": "prayer", "effect": "auto_parry", "duration": 6.0,
			"chapter": 4,
		},
	]


static func chapter_4_weapons() -> Array[Dictionary]:
	return [
		{
			"id": "celestial_sword", "display_name": "Celestial Sword / 天剑",
			"hand": "right", "primary": "celestial_slash", "secondary": "sword_wave",
			"mesh_shape": "celestial_blade", "mesh_color": "eeddcc",
			"special_skill": "cloud_step_strike", "chapter": 4,
		},
		{
			"id": "immortal_bow", "display_name": "Immortal's Bow / 仙弓",
			"hand": "right", "primary": "star_arrow", "secondary": "gravity_arrow",
			"mesh_shape": "celestial_bow", "mesh_color": "ddccaa",
			"chapter": 4,
		},
		{
			"id": "xuan_xiao_seal", "display_name": "Xuan Xiao's Seal / 玄霄印",
			"hand": "right", "primary": "celestial_lightning_call", "secondary": "gravity_well",
			"mesh_shape": "immortal_seal", "mesh_color": "ccbb88",
			"special_skill": "divine_sword_rain", "chapter": 4,
		},
		{
			"id": "scripture_shield", "display_name": "Scripture Shield / 经书盾",
			"hand": "left", "primary": "scripture_guard", "secondary": "wisdom_counter",
			"mesh_shape": "book_shield", "mesh_color": "aa9977",
			"guard": {"absorption": 0.75, "stability": 0.68, "front_dot": 0.18},
			"special_ability": "spell_parry", "chapter": 4,
		},
		{
			"id": "heavenly_beads", "display_name": "Heavenly Prayer Beads / 天珠",
			"hand": "right", "primary": "immortality_mantra", "secondary": "heavenly_soldier_protection",
			"mesh_shape": "celestial_beads", "mesh_color": "ffdd88",
			"chapter": 4,
		},
		{
			"id": "cloud_talisman", "display_name": "Cloud Talisman / 云符",
			"hand": "left", "primary": "cloud_step", "secondary": "wind_wall",
			"mesh_shape": "cloud_talisman", "mesh_color": "ddeeff",
			"chapter": 4,
		},
	]


static func chapter_4_scene() -> Dictionary:
	return {
		"chapter_id": "chapter_04",
		"theme_name": "Celestial Fall / 天崩",
		"ambient_color": Color("4a3a2a"),
		"ambient_energy": 0.15,
		"fog_color": Color("3a2a1a"),
		"fog_energy": 0.28,
		"fog_density": 0.008,
		"key_light_color": Color("eecc88"),
		"key_light_energy": 1.1,
		"key_light_rotation": Vector3(-28, -55, 0),
		"fill_light_color": Color("cc8844"),
		"fill_light_energy": 0.45,
		"particles": [
			{"type": "golden_dust", "color": Color("ffdd88"), "amount": 25, "region": "scattered"},
			{"type": "cloud_vapor", "color": Color("ffffff"), "amount": 20, "region": "ground"},
			{"type": "falling_debris", "color": Color("ccbb99"), "amount": 10, "region": "sky"},
		],
		"materials": {
			"wall": {"color": "ccbb99", "roughness": 0.7, "metallic": 0.12},
			"floor": {"color": "ddaa88", "roughness": 0.65, "metallic": 0.15},
			"cloud_platform": {"color": "ffffff", "roughness": 0.05, "metallic": 0.0, "emission": "eeeedd", "emission_energy": 0.8},
			"gold_trim": {"color": "ddcc66", "roughness": 0.3, "metallic": 0.9, "emission": "ffdd44", "emission_energy": 2.0},
			"fallen_star": {"color": "ff8844", "roughness": 0.15, "metallic": 0.6, "emission": "ff6622", "emission_energy": 4.0},
			"celestial_marble": {"color": "eeddcc", "roughness": 0.5, "metallic": 0.2},
		},
	}


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 5 — 烬座·归墟 (Throne of Ashes · Return to Void)
# Theme: Broken Celestial Furnace Core / Cosmic Void
# Palette: cosmic_void, soul_rivers, dying_stars
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_5_enemies() -> Array[Dictionary]:
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
			"behavior": "random_form",  # Randomly mimics one enemy from earlier chapters
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


static func chapter_5_elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_void_sentinel",
			"display_name": "Void Sentinel / 虚空守卫",
			"max_health": 250.0, "move_speed": 3.0, "aggro_range": 16.0,
			"attack_range": 3.5, "poise_limit": 70.0, "reward": 170,
			"special_ability": "void_tear",  # Opens void rifts that pull player toward them
			"appears_in": "level_05_01", "body_color": "1a1a2a",
			"weapon_shape": "void_blade", "body_type": "void_knight",
		},
		{
			"id": "elite_gravity_twister",
			"display_name": "Gravity Twister / 重力扭曲者",
			"max_health": 200.0, "move_speed": 4.0, "aggro_range": 15.0,
			"attack_range": 5.0, "poise_limit": 42.0, "reward": 155,
			"special_ability": "gravity_reverse",  # Reverses gravity in arena zone
			"appears_in": "level_05_02", "body_color": "2a2a3a",
			"weapon_shape": "gravity_staff", "body_type": "gravity_mage",
		},
		{
			"id": "elite_soul_forger_echo",
			"display_name": "Soul-Forger Echo / 铸魂者回响",
			"max_health": 280.0, "move_speed": 2.2, "aggro_range": 15.0,
			"attack_range": 4.0, "poise_limit": 85.0, "reward": 200,
			"special_ability": "soul_shatter",  # AoE that damages and reduces max stamina temporarily
			"appears_in": "level_05_04", "body_color": "ccaa55",
			"weapon_shape": "soul_forge_hammer", "body_type": "ancient_titan",
		},
	]


static func chapter_5_boss() -> Dictionary:
	return {
		"id": "boss_zhu_yin",
		"display_name": "烬渊之主·烛阴 / Lord of the Ember Abyss · Zhu Yin",
		"max_health": 800.0, "reward": 1000,
		"arena": "cosmic_throne_void",
		"chapter": 5, "chinese_name": "烛阴",
		"phases": {
			"1": {  # 100%-70%: Torch Dragon Form
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
			"2": {  # 70%-40%: Humanoid Form
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
			"3": {  # 40%-10%: Zero-Gravity Chaos
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
			"4": {  # 10%-0%: Final Choice
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


static func chapter_5_spells() -> Array[Dictionary]:
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


static func chapter_5_weapons() -> Array[Dictionary]:
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


static func chapter_5_scene() -> Dictionary:
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
