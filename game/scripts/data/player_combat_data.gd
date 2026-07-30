class_name PlayerCombatData
extends RefCounted
## Centralized combat tuning data for the player.
## SPELL_CONFIG — spell/incantation focus costs, cast times, damage, projectile params.
## STYLE_TIMING — per-combat-style attack timing, damage, stamina costs.
## Keys for STYLE_TIMING are CombatStyle enum int values (0=RELIQUARY_GUARD, 1=TWIN_COLOSSI, etc.)

# ── Spell / Incantation tuning ──────────────────────────────────────────
# Balanced for Soulslike feel: basic spells affordable, powerful spells costly.
# Range = speed × lifetime (effective distance before projectile expires).
static var SPELL_CONFIG := {
	"veil_bolt": {
		"focus_cost": 14.0, "cast_time": 0.58, "damage": 26.0, "stagger": 16.0,
		"proj_speed": 18.0, "proj_lifetime": 2.0,   # range ≈ 36 units
		"spell_type": "veil_bolt", "homing": false, "homing_strength": 0.0,
	},
	"seal_burst": {
		"focus_cost": 22.0, "cast_time": 0.72, "damage": 36.0, "stagger": 26.0,
		"proj_speed": 10.0, "proj_lifetime": 1.6,   # range ≈ 16 units — close-range burst
		"spell_type": "seal_burst", "homing": true, "homing_strength": 3.5,
	},
	"bow_quick_shot": {
		"focus_cost": 0.0, "cast_time": 0.38, "damage": 18.0, "stagger": 8.0,
		"proj_speed": 20.0, "proj_lifetime": 1.8,   # range ≈ 36 units
		"spell_type": "bow_quick_shot", "homing": false, "homing_strength": 0.0,
	},
	"bow_power_shot": {
		"focus_cost": 0.0, "cast_time": 0.56, "damage": 32.0, "stagger": 22.0,
		"proj_speed": 14.0, "proj_lifetime": 2.4,   # range ≈ 33.6 units
		"spell_type": "bow_power_shot", "homing": false, "homing_strength": 0.0,
	},
	"ember_rite": {
		"focus_cost": 25.0, "cast_time": 0.82, "heal": 28.0, "aoe_damage": 22.0,
		"aoe_stagger": 20.0, "aoe_range": 6.0,
	},
	# Weapon art projectiles
	"arcane_barrage": {
		"focus_cost": 20.0, "cast_time": 0.0, "damage": 12.0, "stagger": 6.0,
		"proj_speed": 16.0, "proj_lifetime": 1.5,   # range ≈ 24 units
		"spell_type": "arcane_barrage", "homing": true, "homing_strength": 2.8,
	},
	"divine_smite": {
		"focus_cost": 22.0, "cast_time": 0.0, "damage": 34.0, "stagger": 24.0,
		"proj_speed": 12.0, "proj_lifetime": 2.0,
		"spell_type": "default", "homing": true, "homing_strength": 1.8,
	},
}


# ── Per-combat-style attack timing ──────────────────────────────────────
# Keys are CombatStyle enum int values:
#   0 = RELIQUARY_GUARD, 1 = TWIN_COLOSSI, 2 = CRESCENT_PAIR,
#   3 = VEILCRAFT, 4 = EMBER_RITE
static var STYLE_TIMING := {
	0: {  # RELIQUARY_GUARD
		"windup_light": 0.28, "windup_heavy": 0.58,
		"active_light": 0.16, "active_heavy": 0.22,
		"recovery_light": 0.38, "recovery_heavy": 0.62,
		"lunge_light": 2.0, "lunge_heavy": 2.8,
		"damage_light": 22.0, "damage_heavy": 38.0,
		"stagger_light": 16.0, "stagger_heavy": 34.0,
		"stamina_light": 18.0, "stamina_heavy": 34.0, "stamina_dodge": 24.0,
		"parry_start": 0.06, "parry_end": 0.26,
		"leap_windup": 0.0, "leap_active": 0.0, "leap_recovery": 0.0,
		"leap_damage": 0.0, "leap_stagger": 0.0, "leap_stamina": 0.0,
		"leap_lunge": 0.0, "leap_velocity_y": 0.0,
		"has_hyper_armor": false,
	},
	1: {  # TWIN_COLOSSI
		"windup_light": 0.48, "windup_heavy": 0.82,
		"active_light": 0.20, "active_heavy": 0.26,
		"recovery_light": 0.62, "recovery_heavy": 0.92,
		"lunge_light": 1.2, "lunge_heavy": 1.8,
		"damage_light": 32.0, "damage_heavy": 56.0,
		"stagger_light": 22.0, "stagger_heavy": 48.0,
		"stamina_light": 28.0, "stamina_heavy": 46.0, "stamina_dodge": 32.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.38, "leap_active": 0.28, "leap_recovery": 0.62,
		"leap_damage": 58.0, "leap_stagger": 48.0, "leap_stamina": 38.0,
		"leap_lunge": 4.8, "leap_velocity_y": 4.2,
		"has_hyper_armor": true,
	},
	2: {  # CRESCENT_PAIR
		"windup_light": 0.20, "windup_heavy": 0.38,
		"active_light": 0.14, "active_heavy": 0.18,
		"recovery_light": 0.28, "recovery_heavy": 0.44,
		"lunge_light": 1.6, "lunge_heavy": 2.2,
		"damage_light": 16.0, "damage_heavy": 26.0,
		"stagger_light": 10.0, "stagger_heavy": 20.0,
		"stamina_light": 14.0, "stamina_heavy": 24.0, "stamina_dodge": 20.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.22, "leap_active": 0.34, "leap_recovery": 0.34,
		"leap_damage": 18.0, "leap_stagger": 12.0, "leap_stamina": 27.0,
		"leap_lunge": 5.8, "leap_velocity_y": 4.8,
		"has_hyper_armor": false,
	},
	3: {  # VEILCRAFT
		"windup_light": 0.30, "windup_heavy": 0.52,
		"active_light": 0.16, "active_heavy": 0.20,
		"recovery_light": 0.42, "recovery_heavy": 0.58,
		"lunge_light": 1.8, "lunge_heavy": 2.4,
		"damage_light": 20.0, "damage_heavy": 32.0,
		"stagger_light": 14.0, "stagger_heavy": 26.0,
		"stamina_light": 20.0, "stamina_heavy": 36.0, "stamina_dodge": 26.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.0, "leap_active": 0.0, "leap_recovery": 0.0,
		"leap_damage": 0.0, "leap_stagger": 0.0, "leap_stamina": 0.0,
		"leap_lunge": 0.0, "leap_velocity_y": 0.0,
		"has_hyper_armor": false,
	},
	4: {  # EMBER_RITE
		"windup_light": 0.34, "windup_heavy": 0.56,
		"active_light": 0.18, "active_heavy": 0.22,
		"recovery_light": 0.48, "recovery_heavy": 0.64,
		"lunge_light": 1.6, "lunge_heavy": 2.0,
		"damage_light": 22.0, "damage_heavy": 34.0,
		"stagger_light": 16.0, "stagger_heavy": 28.0,
		"stamina_light": 22.0, "stamina_heavy": 38.0, "stamina_dodge": 26.0,
		"parry_start": 0.0, "parry_end": 0.0,
		"leap_windup": 0.0, "leap_active": 0.0, "leap_recovery": 0.0,
		"leap_damage": 0.0, "leap_stagger": 0.0, "leap_stamina": 0.0,
		"leap_lunge": 0.0, "leap_velocity_y": 0.0,
		"has_hyper_armor": false,
	},
}
