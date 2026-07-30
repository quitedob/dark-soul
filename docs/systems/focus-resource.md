# Focus Resource System

**Status:** CURRENT (2026-07-30)  
**Task:** J-07  
**Authority (runtime):** `game/scripts/player/player.gd`, `game/scripts/data/player_combat_data.gd`, `game/scripts/combat/player_spells.gd`

---

## Role

Focus is the second combat resource beside stamina.

| Resource | Primary spend | Regen |
|----------|---------------|-------|
| Stamina | Melee, dodge, guard | After delay, outside blocked states |
| Focus | Spells, prayers, spell-style melee | Slow regen in `LOCOMOTION` only |

Focus does **not** replace stamina for Reliquary / Twin Colossi / Crescent melee.

---

## Pool & Regen

| Field | Value | Location |
|-------|------:|----------|
| `max_focus` | 80.0 | `player.gd` |
| starting `focus` | 80.0 | `player.gd` / run state default |
| `FOCUS_REGEN_RATE` | 4.0 / sec | `player.gd` |

Rules:

1. Regen runs only while `state == LOCOMOTION` (inside `_update_stamina`).
2. Full restore on shrine rest / `heal_full` / respawn.
3. Successful parry grants **+12** Focus (clamped to max).
4. API: `set_focus(amount)`, signal `focus_changed(current, maximum)`, HUD via `hud.update_focus`.

---

## Spend Paths

### 1. Cast spells / prayers

`PlayerSpells.begin_cast(cast_id, focus_cost, duration)` checks Focus, deducts, then enters `CAST`.

Canonical costs — `PlayerCombatData.SPELL_CONFIG`:

| ID | Focus | Notes |
|----|------:|-------|
| `veil_bolt` | 14 | Veilcraft projectile |
| `seal_burst` | 22 | Close burst, homing |
| `ember_rite` | 25 | Heal + AoE prayer |
| `arcane_barrage` | 20 | Weapon art |
| `divine_smite` | 22 | Weapon art |
| `bow_quick_shot` | 0 | Crescent bow uses stamina economy elsewhere |
| `bow_power_shot` | 0 | Same |

### 2. Spell-style melee (`AttackData.focus_cost`)

`CompatibilityMovesetFactory` for `veilcraft` / `ember_rite`:

| Attack | Focus |
|--------|------:|
| Light (strike / pulse) | 10 |
| Heavy (burst) | 18 |

`_commit_attack` refuses the swing with `NOT ENOUGH FOCUS` when Focus is insufficient. Stamina for these styles may remain 0 — Focus is the committed cost.

---

## Economy Intent

| Play pattern | Design goal |
|--------------|-------------|
| Veilcraft spam bolts | Mid Focus drain; force pauses for regen or parry refund |
| Ember Rite heal | High Focus commit; punish panic heal during chase |
| Spell melee | Cheaper than full cast, still not free |
| Parry | Small Focus refund to reward defensive play |

Do not double-tax the same action with both large stamina and large Focus unless a specific art authorizes it.

---

## HUD

- Label: `FOC`
- Color: blue (`Color(0.16, 0.34, 0.72)`)
- Wired in `game_world.gd`: `player.focus_changed.connect(hud.update_focus)`

---

## Persistence

Run state stores `focus` (schema v2). See [save-persistence.md](save-persistence.md).

---

## Related

- [controls.md](../controls.md) — cast / style bindings  
- [combat-styles.md](combat-styles.md) — loadout fantasy  
- [player_combat_data.gd](../../game/scripts/data/player_combat_data.gd) — spell table authority  
