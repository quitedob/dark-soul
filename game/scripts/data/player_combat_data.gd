class_name PlayerCombatData
extends RefCounted

static var SPELL_CONFIG := {
	"veil_bolt": {
		"focus_cost": 14.0, "cast_time": 0.58, "damage": 26.0, "stagger": 16.0,
		"proj_speed": 18.0, "proj_lifetime": 2.0,
		"spell_type": "veil_bolt", "homing": false, "homing_strength": 0.0,
	},
	"seal_burst": {
		"focus_cost": 22.0, "cast_time": 0.72, "damage": 36.0, "stagger": 26.0,
		"proj_speed": 10.0, "proj_lifetime": 1.6,
		"spell_type": "seal_burst", "homing": true, "homing_strength": 3.5,
	},
	"bow_quick_shot": {
		"focus_cost": 0.0, "cast_time": 0.38, "damage": 18.0, "stagger": 8.0,
		"proj_speed": 20.0, "proj_lifetime": 1.8,
		"spell_type": "bow_quick_shot", "homing": false, "homing_strength": 0.0,
	},
	"bow_power_shot": {
		"focus_cost": 0.0, "cast_time": 0.56, "damage": 32.0, "stagger": 22.0,
		"proj_speed": 14.0, "proj_lifetime": 2.4,
		"spell_type": "bow_power_shot", "homing": false, "homing_strength": 0.0,
	},
	"ember_rite": {
		"focus_cost": 25.0, "cast_time": 0.82, "heal": 28.0, "aoe_damage": 22.0,
		"aoe_stagger": 20.0, "aoe_range": 6.0,
	},
	"arcane_barrage": {
		"focus_cost": 20.0, "cast_time": 0.0, "damage": 12.0, "stagger": 6.0,
		"proj_speed": 16.0, "proj_lifetime": 1.5,
		"spell_type": "arcane_barrage", "homing": true, "homing_strength": 2.8,
	},
	"divine_smite": {
		"focus_cost": 22.0, "cast_time": 0.0, "damage": 34.0, "stagger": 24.0,
		"proj_speed": 12.0, "proj_lifetime": 2.0,
		"spell_type": "default", "homing": true, "homing_strength": 1.8,
	},
	## --- L-11 法术扩充 7→32（法术 18 + 祷告 14）---
	# -- 法术 --
	"spirit_fire_bolt": {
		"focus_cost": 12.0, "cast_time": 0.5, "damage": 24.0, "stagger": 14.0,
		"proj_speed": 18.0, "proj_lifetime": 2.2,
		"spell_type": "projectile", "homing": false, "homing_strength": 0.0,
	},
	"mirror_clone": {
		"focus_cost": 18.0, "cast_time": 0.6, "clone_count": 1, "clone_lifetime": 3.0,
		"spell_type": "clone",
	},
	"furnace_fire_ring": {
		"focus_cost": 20.0, "cast_time": 0.7, "damage": 26.0, "stagger": 30.0,
		"aoe_range": 5.0, "spell_type": "aoe_ring",
	},
	"war_cry": {
		"focus_cost": 18.0, "cast_time": 0.5, "damage_multiplier": 1.15,
		"buff_duration": 45.0, "spell_type": "buff",
	},
	"iron_skin": {
		"focus_cost": 16.0, "cast_time": 0.5, "pdr_boost": 0.2,
		"buff_duration": 30.0, "spell_type": "buff_armor",
	},
	"beacon_signal": {
		"focus_cost": 24.0, "cast_time": 0.8, "kind": "dharma_child",
		"lifetime": 45.0, "reserved_focus": 10.0, "spell_type": "summon_ally",
	},
	"illusion_phantoms": {
		"focus_cost": 22.0, "cast_time": 0.7, "clone_count": 2, "clone_lifetime": 8.0,
		"spell_type": "clone",
	},
	"mirror_moon_swap": {
		"focus_cost": 24.0, "cast_time": 0.55, "teleport_range": 15.0,
		"spell_type": "teleport_swap",
	},
	"foxfire": {
		"focus_cost": 22.0, "cast_time": 0.6, "damage": 15.0, "stagger": 10.0,
		"proj_speed": 15.0, "proj_lifetime": 3.0, "homing": true, "homing_strength": 3.2,
		"orb_count": 3, "spell_type": "projectile",
	},
	"mind_confusion": {
		"focus_cost": 18.0, "cast_time": 0.6, "damage": 8.0, "stagger": 26.0,
		"aoe_range": 6.0, "spell_type": "aoe_ring",
	},
	"heavenly_thunder": {
		"focus_cost": 30.0, "cast_time": 0.8, "damage": 48.0, "stagger": 34.0,
		"aoe_range": 8.0, "delay": 2.0, "spell_type": "aoe_delayed",
	},
	"void_step": {
		"focus_cost": 14.0, "cast_time": 0.4, "teleport_range": 8.0,
		"spell_type": "teleport",
	},
	"rot_touch": {
		"focus_cost": 16.0, "cast_time": 0.5, "damage": 12.0, "stagger": 8.0,
		"aoe_range": 2.5, "dot_ticks": 4, "dot_damage": 5.0, "spell_type": "aoe_burst",
	},
	"scripture_scroll": {
		"focus_cost": 20.0, "cast_time": 0.7, "heal": 30.0,
		"spell_type": "random_scroll",
	},
	"void_rift": {
		"focus_cost": 28.0, "cast_time": 0.7, "damage": 38.0, "stagger": 30.0,
		"aoe_range": 7.0, "pull_strength": 12.0, "explode_delay": 0.6,
		"spell_type": "void_rift",
	},
	"torch_dragon_breath": {
		"focus_cost": 35.0, "cast_time": 0.9, "damage": 14.0, "stagger": 12.0,
		"proj_speed": 22.0, "proj_lifetime": 1.2, "homing": false, "homing_strength": 0.0,
		"cooldown": 60.0, "spell_type": "projectile",
	},
	"soul_forger_memory": {
		"focus_cost": 24.0, "cast_time": 0.6, "buff_duration": 20.0,
		"spell_type": "random_buff",
	},
	"final_flame": {
		"focus_cost": 50.0, "cast_time": 1.2, "damage": 65.0, "stagger": 40.0,
		"aoe_range": 12.0, "self_hp_cost": 0.3, "cooldown": 120.0,
		"spell_type": "aoe_burst",
	},
	# -- 祷告 --
	"restful_prayer": {
		"focus_cost": 20.0, "cast_time": 0.7, "heal": 40.0, "spell_type": "heal",
	},
	"furnace_oath": {
		"focus_cost": 16.0, "cast_time": 0.5, "pdr_boost": 0.15,
		"buff_duration": 60.0, "spell_type": "buff_armor",
	},
	"hero_spirit": {
		"focus_cost": 30.0, "cast_time": 0.9, "kind": "dharma_child",
		"lifetime": 60.0, "reserved_focus": 14.0, "spell_type": "summon_ally",
	},
	"stop_bleed": {
		"focus_cost": 12.0, "cast_time": 0.5, "heal": 15.0, "spell_type": "cure",
	},
	"battle_spirit": {
		"focus_cost": 16.0, "cast_time": 0.6, "summon_damage_mult": 1.3,
		"spell_type": "summon_buff",
	},
	"mind_clearing": {
		"focus_cost": 12.0, "cast_time": 0.5, "heal": 15.0, "spell_type": "cure",
	},
	"soul_release": {
		"focus_cost": 26.0, "cast_time": 0.8, "release_threshold": 0.3,
		"release_damage": 999.0, "aoe_range": 10.0, "spell_type": "soul_release",
	},
	"fox_blessing": {
		"focus_cost": 16.0, "cast_time": 0.6, "speed_multiplier": 1.15,
		"buff_duration": 40.0, "spell_type": "buff_speed",
	},
	"divine_soldier": {
		"focus_cost": 20.0, "cast_time": 0.6, "pdr_boost": 0.5,
		"buff_duration": 25.0, "spell_type": "buff_armor",
	},
	"ascension_prayer": {
		"focus_cost": 14.0, "cast_time": 0.6, "gravity_factor": 0.4,
		"buff_duration": 30.0, "spell_type": "buff_gravity",
	},
	"immortality_mantra": {
		"focus_cost": 40.0, "cast_time": 0.9, "heal": 50.0, "pdr_boost": 0.5,
		"buff_duration": 8.0, "cooldown": 300.0, "spell_type": "buff_armor",
	},
	"great_silence": {
		"focus_cost": 26.0, "cast_time": 0.8, "damage": 40.0, "stagger": 30.0,
		"aoe_range": 15.0, "cooldown": 15.0, "spell_type": "aoe_burst",
	},
	"ksitigarbha_vow": {
		"focus_cost": 20.0, "cast_time": 0.8, "heal": 25.0, "spell_type": "revive",
	},
	"torch_contract": {
		"focus_cost": 18.0, "cast_time": 0.6, "damage_multiplier": 1.25,
		"pdr_penalty": 0.25, "buff_duration": 20.0, "spell_type": "buff_contract",
	},
}

## L-06：祝祷师灵符召唤物（5 灵）。spell_type="summon"，kind 对应 SpiritSummon。
## reserved_focus：占用量在灵消失时返还（召唤即时扣取一次）。
static var SUMMON_CONFIG := {
	"summon_dharma_child": {
		"focus_cost": 30.0, "cast_time": 0.7, "kind": "dharma_child",
		"reserved_focus": 16.0, "lifetime": 20.0, "spell_type": "summon",
	},
	"summon_golden_guardian": {
		"focus_cost": 42.0, "cast_time": 0.85, "kind": "golden_guardian",
		"reserved_focus": 24.0, "lifetime": 25.0, "spell_type": "summon",
	},
	"summon_rebirth_lotus": {
		"focus_cost": 24.0, "cast_time": 0.6, "kind": "rebirth_lotus",
		"reserved_focus": 12.0, "lifetime": 30.0, "spell_type": "summon",
	},
	"summon_resentful_spirit": {
		"focus_cost": 36.0, "cast_time": 0.7, "kind": "resentful_spirit",
		"reserved_focus": 20.0, "lifetime": 18.0, "spell_type": "summon",
	},
	"summon_white_crane": {
		"focus_cost": 30.0, "cast_time": 0.7, "kind": "white_crane",
		"reserved_focus": 16.0, "lifetime": 22.0, "spell_type": "summon",
	},
}
