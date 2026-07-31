# G-08 — Migrate Enemy Attacks to AttackData Resources

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** A-03 (AttackData schema stable)
**Blocks:** I-12 (enemy FSM tests)
**Source:** Code review full audit 2026-07-30, finding M-1
**Authority:** `docs/systems/attack-moveset-data-schema.md`

---

## Problem

Enemy attack profiles in `enemy.gd:1226-1311` are defined as raw dictionaries with inline floats in `_apply_tuning()`, not as `AttackData` Resources. This means:

1. `AttackData.validate()` is not available for enemy attacks — no schema checking
2. Enemy attacks cannot benefit from the Resource inspector UX
3. Changes to attack timing require code edits rather than `.tres` authoring
4. No parity with player attack pipeline — two code paths to maintain

```gdscript
# enemy.gd — current approach:
func _apply_tuning() -> void:
    _attack_profiles = {
        "light_1": {
            "windup": 0.45, "active": 0.18, "recovery": 0.55,
            "damage": 18.0, "stagger": 22.0, ...
        },
        # ... ~20 more inline dicts
    }
```

## Target

Create `AttackData` `.tres` resources for each enemy type, loaded at `_ready()` time. The enemy FSM resolves attacks from the resource rather than inline dicts:

```gdscript
# enemy.gd — target approach:
@export var attack_resource_dir: String = "res://resources/enemies/ash_stalker/"

func _load_attack_resources() -> void:
    _light_attacks = [
        load(attack_resource_dir + "light_1.tres"),
        load(attack_resource_dir + "light_2.tres"),
    ]
    _heavy_attacks = [
        load(attack_resource_dir + "heavy_1.tres"),
    ]

func _begin_attack(attack: AttackData) -> void:
    # uses attack.windup_seconds, attack.active_seconds, etc.
    # calls attack.to_hit_metadata() for payload
```

### Enemy Attack Resources

```
game/resources/enemies/
├── ash_stalker/
│   ├── light_1.tres
│   ├── light_2.tres
│   ├── heavy_1.tres
│   └── grab.tres
├── hollow_sentinel/
│   ├── light_1.tres
│   ├── light_2.tres
│   ├── heavy_1.tres
│   └── shield_bash.tres
└── cinder_guardian/
    ├── phase1_light_1.tres
    ├── phase1_heavy_1.tres
    ├── phase2_light_1.tres
    ├── phase2_heavy_1.tres
    └── phase2_leap.tres
```

## Acceptance Criteria

- [ ] Each enemy type has its own `AttackData` `.tres` resources
- [ ] `AttackData.validate()` runs on enemy resources at load time
- [ ] Enemy FSM reads timing/costs/damage from Resources, not inline dicts
- [ ] Boss phase attacks use per-phase Resources
- [ ] Existing combat contract tests continue to pass
- [ ] Combat resource schema contract test validates enemy resources
- [ ] Smoke test passes with all 3 enemy types
