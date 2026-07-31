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

> `SPELL_CONFIG` 已扩展至 **39 条**（原 7 个兼容 cast + 32 新增）；详见下方（L-11）与 [player_combat_data.gd](../../game/scripts/data/player_combat_data.gd)。

### 召唤占位 Focus 与法术 CD (L-11)

- **`SUMMON_CONFIG`（5 灵）**：除即时 `focus_cost` 外，另有 **`reserved_focus` 占位** —— 施放即时扣取一次，灵消失/死亡时返还。护法灵童(16)/金甲力士(24)/往生莲(12)/怨灵(20)/白鹤童子(16)。
- **`resolve_cast` 新增分支**：**buff**（war_cry/iron_skin/furnace_oath/fox_blessing/ascension_prayer 等）、**传送**（void_step/mirror_moon_swap）、**AoE**（furnace_fire_ring/heavenly_thunder/void_rift/soul_release/final_flame）、**召唤**（beacon_signal/hero_spirit/mirror_clone/illusion_phantoms）、**超度/终末**（soul_release/ksitigarbha_vow/final_flame）。
- **`_cooldowns` CD 表**：施法真正释放时记入冷却（`resolve_cast` 先查 `cooldown` 再 `_set_cooldown`）。示例：`torch_dragon_breath` 60s、`great_silence` 15s、`final_flame` 120s、`immortality_mantra` 300s。

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
