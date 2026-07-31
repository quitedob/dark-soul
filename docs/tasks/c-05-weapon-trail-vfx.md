# C-05 — Weapon Trail VFX Enhancement

**Priority:** P4  
**Status:** ✅ DONE  
**Effort:** M  
**Depends On:** C-03 (attack weight trauma tiers)  
**Completed:** 2026-07-31

---

## Goal

Tie weapon trail **color / width / emission** to the same attack weight classes used by C-03 (`light` / `heavy` / `explosion`), and tint by `CombatStyleData.trail_color`.

## Runtime

| Piece | Path |
|-------|------|
| Profile resolver | `game/scripts/fx/weapon_trail_profile.gd` |
| Ribbon rendering | `game/scripts/core/player_visuals.gd` |
| Style colors | `game/resources/combat_styles/*.tres` |

### Mapping

| Weight | Width | Peak alpha | Emission |
|--------|------:|-----------:|---------:|
| light | 0.05 | 0.35 | 1.0 |
| heavy | 0.09 | 0.55 | 1.6 |
| explosion | 0.14 | 0.75 | 2.2 |

- Weight via `TraumaShake.resolve_weight(attack_heavy, tags, action_id)`
- Base color = style `trail_color` (fallback warm gold if WHITE)
- Material enables `vertex_color_use_as_albedo`

## Verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game --script res://tests/smoke/weapon_trail_contract_test.gd
```

Expected: `ASHEN_WEAPON_TRAIL_CONTRACTS_OK`
