class_name Chapter4Content
extends RefCounted
## Chapter 4 content: 天崩·陨落 (Celestial Fall)
## Theme: Shattered Floating Immortal City (Tang Dynasty)
## Palette: fixed_sunset, cloud_sea, divine_decay

static func enemies() -> Array[Dictionary]:
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


static func elites() -> Array[Dictionary]:
	return [
		{
			"id": "elite_celestial_swordsman",
			"display_name": "Celestial Swordsman / 天剑士",
			"max_health": 230.0, "move_speed": 4.5, "aggro_range": 15.0,
			"attack_range": 2.6, "poise_limit": 52.0, "reward": 160,
			"special_ability": "sword_rain",
			"appears_in": "level_04_01", "body_color": "ccddff",
			"weapon_shape": "celestial_sword", "body_type": "floating_knight",
		},
		{
			"id": "elite_alchemy_master",
			"display_name": "Alchemy Master / 炼丹宗师",
			"max_health": 195.0, "move_speed": 3.2, "aggro_range": 14.0,
			"attack_range": 8.0, "poise_limit": 38.0, "reward": 145,
			"special_ability": "elixir_explosion",
			"appears_in": "level_04_02", "body_color": "cc8844",
			"weapon_shape": "elixir_vial", "body_type": "robed_caster",
		},
		{
			"id": "elite_scripture_keeper",
			"display_name": "Scripture Keeper / 藏经主",
			"max_health": 210.0, "move_speed": 2.8, "aggro_range": 16.0,
			"attack_range": 5.0, "poise_limit": 60.0, "reward": 150,
			"special_ability": "gravity_inversion",
			"appears_in": "level_04_03", "body_color": "8a8060",
			"weapon_shape": "scripture_tome", "body_type": "gravity_mage",
		},
	]


static func bosses() -> Array[Dictionary]:
	return [
		{
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
		{
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
		{
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


static func spells() -> Array[Dictionary]:
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


static func weapons() -> Array[Dictionary]:
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


static func scene() -> Dictionary:
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
