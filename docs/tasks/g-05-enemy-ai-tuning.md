# G-05 — Per-chapter Enemy AI Parameter Tuning

**Priority:** P3  
**Status:** ✅ DONE  
**Effort:** XL  
**Depends On:** —  
**Completed:** 2026-07-31

---

## Goal

Make all campaign enemy types (design 32 + skirmisher) use explicit **detection / leash / navigation** profiles, and wire every `behavior` tag to a real FSM module family (not dead dictionary labels).

## Architecture

```text
chapter_*_content.enemies()
        ↓
EnemyAiCatalog.normalize()  → aggro/leash/nav/body sizes
        ↓
EnemyBehaviorRegistry.create_module(behavior)
        ↓
enemy.gd IDLE/CHASE/ACTIVE hooks
```

**Do not** expand `EnemyType` to 32 enums. Families:

| Family | Tags (examples) |
|--------|-----------------|
| patrol | slow_patrol, patrol_route, float_patrol, … |
| hold | defensive_hold, shield_wall, … |
| ambush | teleport_ambush, illusion_dash, … |
| skirmish | hit_and_run, pack_hunter, … |
| ranged | ranged_ambush, ranged_artillery, … |
| hazard | area_denial, gravity_zone, … |
| special | dive_bomb, split_clone, soul_drain_aura, … |

## Files

| Path | Role |
|------|------|
| `game/scripts/data/enemy_ai_catalog.gd` | Aggregate + normalize |
| `game/scripts/enemy/enemy_behavior_registry.gd` | Tag → module |
| `game/scripts/enemy/behaviors/*.gd` | Family modules |
| `game/scripts/data/enemy_tuning.gd` | Prototype fallbacks (now used) |
| `game/scripts/enemy.gd` | Wiring |

## Verify

```powershell
& $Godot --headless --path game --script res://tests/smoke/enemy_ai_tuning_contract_test.gd
```

Expected: `ASHEN_ENEMY_AI_TUNING_CONTRACTS_OK`

## Out of scope

- G-06 boss chapter powers
- Full Ch.2–5 level playability (H-04 modules already exist)
- G-08 AttackData `.tres` migration
