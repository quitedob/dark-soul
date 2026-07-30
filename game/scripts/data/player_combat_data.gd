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
}
