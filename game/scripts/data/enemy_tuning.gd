class_name EnemyTuningData
extends RefCounted
## Centralized enemy stat tuning and boss attack profiles.
## Extracted from enemy.gd to keep the FSM script focused on behavior logic.

# ── Enemy type base stats ───────────────────────────────────────────────

static var TYPE_TUNING := {
	"cinder_guardian": {
		"max_health": 260.0, "move_speed": 3.0, "acceleration": 12.0,
		"aggro_range": 17.0, "disengage_range": 26.0, "leash_range": 30.0,
		"attack_range": 2.65, "reward": 220, "poise_limit": 68.0, "stagger_duration": 0.42,
		"body_radius": 0.58, "body_height": 2.25, "body_y": 1.12,
		"nav_radius": 0.62, "nav_height": 2.3,
	},
	"ash_stalker": {
		"max_health": 45.0, "move_speed": 6.0, "acceleration": 18.0,
		"aggro_range": 10.0, "disengage_range": 17.0, "leash_range": 14.0,
		"attack_range": 1.6, "reward": 25, "poise_limit": 12.0, "stagger_duration": 0.55,
		"body_radius": 0.36, "body_height": 1.6, "body_y": 0.8,
		"nav_radius": 0.40, "nav_height": 1.65,
	},
	"ember_skirmisher": {
		"max_health": 52.0, "move_speed": 4.4, "acceleration": 16.0,
		"aggro_range": 14.0, "disengage_range": 22.0, "leash_range": 16.0,
		"attack_range": 9.0, "reward": 32, "poise_limit": 14.0, "stagger_duration": 0.5,
		"body_radius": 0.38, "body_height": 1.75, "body_y": 0.88,
		"nav_radius": 0.42, "nav_height": 1.8,
		"preferred_distance": 7.0, "retreat_trigger": 4.2,
	},
	"hollow_sentinel": {
		"max_health": 80.0, "move_speed": 3.6, "acceleration": 15.0,
		"aggro_range": 13.0, "disengage_range": 20.0, "leash_range": 17.0,
		"attack_range": 2.15, "reward": 35, "poise_limit": 24.0, "stagger_duration": 0.48,
		"body_radius": 0.45, "body_height": 1.9, "body_y": 0.95,
		"nav_radius": 0.48, "nav_height": 1.9,
	},
}

# ── Hollow Sentinel attack profile (non-guardian) ───────────────────────

static var SENTINEL_ATTACK := {
	"windup": 0.55, "active": 0.18, "recovery": 0.70,
	"damage": 16.0, "stagger": 22.0, "lunge": 1.4,
}

# ── Ash Stalker attack profile ──────────────────────────────────────────

static var STALKER_ATTACK := {
	"windup": 0.22, "active": 0.10, "recovery": 0.18,
	"damage": 8.0, "stagger": 8.0, "lunge": 0.8,
}

# ── Ember Skirmisher ranged attack profile (G-03) ───────────────────────

static var SKIRMISHER_ATTACK := {
	"windup": 0.55, "active": 0.12, "recovery": 0.75,
	"damage": 12.0, "stagger": 10.0, "lunge": 0.9,
}

# ── Guardian boss attack profiles by phase and range ────────────────────
# Structure: GUARDIAN_ATTACKS[range_key][phase] = {windup, active, recovery, damage, stagger, lunge, heavy}

static var GUARDIAN_CLOSE := {
	1: {"windup": 0.48, "active": 0.16, "recovery": 0.52, "damage": 18.0, "stagger": 22.0, "lunge": 1.1, "heavy": false},
	2: {"windup": 0.38, "active": 0.14, "recovery": 0.40, "damage": 22.0, "stagger": 26.0, "lunge": 1.3, "heavy": false},
	3: {"windup": 0.32, "active": 0.12, "recovery": 0.34, "damage": 26.0, "stagger": 30.0, "lunge": 1.4, "heavy": false},
}

static var GUARDIAN_CLOSE_HEAVY := {
	2: {"windup": 0.55, "active": 0.20, "recovery": 0.48, "damage": 24.0, "stagger": 28.0, "lunge": 1.3, "heavy": true},
	3: {"windup": 0.45, "active": 0.18, "recovery": 0.40, "damage": 28.0, "stagger": 34.0, "lunge": 1.5, "heavy": true},
}

static var GUARDIAN_MID_LIGHT := {
	1: {"windup": 0.72, "active": 0.22, "recovery": 0.78, "damage": 24.0, "stagger": 30.0, "lunge": 1.65, "heavy": false},
	2: {"windup": 0.58, "active": 0.18, "recovery": 0.56, "damage": 28.0, "stagger": 34.0, "lunge": 1.9, "heavy": false},
	3: {"windup": 0.48, "active": 0.16, "recovery": 0.46, "damage": 32.0, "stagger": 40.0, "lunge": 2.1, "heavy": false},
}

static var GUARDIAN_MID_HEAVY := {
	1: {"windup": 1.18, "active": 0.34, "recovery": 1.08, "damage": 34.0, "stagger": 42.0, "lunge": 2.1, "heavy": true},
	2: {"windup": 0.95, "active": 0.30, "recovery": 0.82, "damage": 38.0, "stagger": 46.0, "lunge": 2.4, "heavy": true},
	3: {"windup": 0.78, "active": 0.26, "recovery": 0.68, "damage": 44.0, "stagger": 52.0, "lunge": 2.6, "heavy": true},
}

static var GUARDIAN_LONG := {
	1: {"windup": 1.35, "active": 0.38, "recovery": 1.25, "damage": 40.0, "stagger": 48.0, "lunge": 3.2, "heavy": true},
	2: {"windup": 1.08, "active": 0.38, "recovery": 0.95, "damage": 46.0, "stagger": 52.0, "lunge": 3.8, "heavy": true},
	3: {"windup": 0.88, "active": 0.38, "recovery": 0.78, "damage": 54.0, "stagger": 58.0, "lunge": 4.2, "heavy": true},
}


# ── Helper: apply an attack profile dict to an enemy's attack fields ─────

## 将 dict 写入敌人攻击字段（G-08 dict 回退路径；优先请用 EnemyAttackCatalog）
static func apply_attack_profile(enemy: Node, profile: Dictionary) -> void:
	enemy.attack_windup = profile["windup"]
	enemy.attack_active = profile["active"]
	enemy.attack_recovery = profile["recovery"]
	enemy.attack_damage = profile["damage"]
	enemy.attack_stagger = profile["stagger"]
	enemy.attack_lunge = profile.get("lunge", 0.0)
	enemy.attack_heavy = profile.get("heavy", false)
