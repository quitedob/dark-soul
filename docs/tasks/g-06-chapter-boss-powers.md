# G-06 — Chapter-Specific Boss Powers

**Priority:** P3  
**Status:** ✅ DONE  
**Effort:** XL  
**Depends On:** G-01 ✅  
**Completed:** 2026-07-31

---

## Goal

Execute chapter boss content `type` fields for signature powers:

| Boss | Power | Types |
|------|-------|-------|
| 九尾 | Teleport chains | `chain_teleport`, `teleport_after`, `teleport_behind` |
| 玄霄 | Gravity pull | `pull_in_aoe`, `gravity_crush` |
| 烛阴 | Local time | `freeze_then_strike`, `status:rewind_player_position`, `random_teleport_aoe` |

**Hard rule:** never change `Engine.time_scale` (C-01 / game_world assertion).

## Runtime

| Path | Role |
|------|------|
| `game/scripts/boss/boss_attack_executor.gd` | Type micro-executor |
| `game/scripts/enemy.gd` | Stores `_active_attack_profile`; ACTIVE/RECOVERY hooks; phase ≥ 4 |

Macro BT (G-01) still selects intents; this layer executes authored attack types.

## Verify

```powershell
& $Godot --headless --path game --script res://tests/smoke/boss_chapter_powers_contract_test.gd
```

Expected: `ASHEN_BOSS_CHAPTER_POWERS_OK`

## Note on E-10

E-10 (Boss Execution Break) is orthogonal — narrative HP floors / weak points. Task table “Depends G-06” was planning residue; both ship independently.
