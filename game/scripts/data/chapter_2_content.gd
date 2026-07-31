class_name Chapter2Content
extends RefCounted
## Chapter 2 content: 血铁·战歌 (Blood & Iron · Warsong)
## Theme: Eternal War Mountain Fortress (Ming Dynasty)
## Palette: blood_sunset, war_smoke, beacon_fire

static func enemies() -> Array[Dictionary]:
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


static func elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_siege_commander",
			"display_name": "Siege Commander / 攻城校尉",
			"max_health": 220.0, "move_speed": 3.8, "aggro_range": 16.0,
			"attack_range": 2.8, "poise_limit": 55.0, "reward": 140,
			"special_ability": "rally_troops",
			"appears_in": "level_02_02", "body_color": "3a2020",
			"weapon_shape": "commander_sword", "body_type": "armored_heavy",
		},
		{
			"id": "elite_torture_master",
			"display_name": "Torture Master / 刑讯官",
			"max_health": 180.0, "move_speed": 4.2, "aggro_range": 13.0,
			"attack_range": 2.2, "poise_limit": 38.0, "reward": 130,
			"special_ability": "bleed_chain",
			"appears_in": "level_02_03", "body_color": "1a1010",
			"weapon_shape": "chain_hook", "body_type": "agile_armored",
		},
		{
			"id": "elite_beacon_lord",
			"display_name": "Beacon Lord / 烽火将",
			"max_health": 260.0, "move_speed": 2.0, "aggro_range": 18.0,
			"attack_range": 10.0, "poise_limit": 65.0, "reward": 160,
			"special_ability": "fire_rain",
			"appears_in": "level_02_04", "body_color": "2a1810",
			"weapon_shape": "beacon_bow", "body_type": "ranged_commander",
		},
	]


static func boss() -> Dictionary:
	return {
		"id": "boss_xing_tian",
		"display_name": "血将军·刑天 / Blood General · Xing Tian",
		"max_health": 580.0, "reward": 600,
		"arena": "mountaintop_colosseum",
		"chapter": 2, "chinese_name": "刑天",
		# 外观：重甲精英体型 + 双斧（工厂未注册 guandao 网格，双斧为其可用近似形状）
		"body_type": "elite_armored", "weapon_shape": "blood_axe",
		"body_color": "2a1515", "weapon_color": "8a2a1a", "eye_emission": "ff3300",
		"phases": {
			"1": {
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
			"2": {
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
			"3": {
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


static func spells() -> Array[Dictionary]:
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


static func weapons() -> Array[Dictionary]:
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


static func scene() -> Dictionary:
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
