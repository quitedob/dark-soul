# Enemy AI Specification

**Status:** CURRENT (2026-07-31)  
**Task:** J-10 / G-01 / G-05  
**Authority:** `enemy.gd`, `enemy_tuning.gd`, `EnemyAiCatalog`, `EnemyBehaviorRegistry`, chapter `*_content.gd`

---

## Scope

Documents the **shipping** chase FSM plus the G-01 boss **macro decision** layer.

```text
IDLE -> CHASE -> WINDUP -> ACTIVE -> RECOVERY -> CHASE
CHASE -> RETURN -> IDLE
ANY -> STAGGER / PARRY_VULNERABLE / GUARD_BROKEN -> CHASE|RETURN
ANY -> DEAD -> reset_enemy -> IDLE
```

Decision refresh interval: `AI_DECISION_INTERVAL = 0.1s`.

### Boss macro layer (G-01)

Guardians mount `BossMacroController` (`scripts/boss/boss_macro_controller.gd`):

- **Macro:** BT-style selector (`BossMacroBT`) writes blackboard intents: `patrol` / `engage` / `disengage` / `phase` / `heal_punish`.
- **Micro:** Existing FSM still runs windup/active/recovery and physics.
- **Backend:** `LimboAIPluginPath.backend_id()` → `compat_macro` until `game/addons/limboai/` is installed; then swap to LimboAI BTPlayer keeping the same blackboard keys.
- **Probe:** `get_macro_intent()` / `get_macro_selected_attack()` on `enemy.gd`.

---

## Enemy Types (legacy enum)

| `EnemyType` | Role |
|-------------|------|
| `HOLLOW_SENTINEL` | Standard melee husk |
| `ASH_STALKER` | Fast low-sweep skirmisher |
| `CINDER_GUARDIAN` | Boss / guardian branch |

Chapter content enemies usually spawn as sentinel + `setup_from_content`, with stats from dictionaries.

---

## Detection / Leash / Sanctuary

### Default legacy ranges (`enemy_tuning.gd` / `_apply_tuning`)

| Type | Aggro | Disengage | Leash | Attack range |
|------|------:|----------:|------:|-------------:|
| Hollow Sentinel | 13 | 20 | 17 | 2.15 |
| Ash Stalker | 10 | 17 | 14 | 1.6 |
| Cinder Guardian | 17 | 26 | 30 | 2.65 |

### Content overrides

Chapter dictionaries supply `aggro_range` / `disengage_range` / `leash_range` (example Ch.1):

| Enemy | Aggro | Disengage | Leash |
|-------|------:|----------:|------:|
| Lost Soul Soldier | 11 | 18 | 15 |
| Temple Guardian Warrior | 14 | 22 | 18 |
| Mirror Shade | 9 | 15 | 12 |
| Furnace Slag Beast | 12 | 20 | 16 |

### Rules

1. **Engage:** valid target, not in sanctuary, distance ≤ `aggro_range`.
2. **Disengage → RETURN:** lost target, target in sanctuary, distance > `disengage_range`, or distance from `spawn_origin` > `leash_range`.
3. **Sanctuary:** `game_world.is_position_in_sanctuary` → within **5.0** of `respawn_position` (shrine bubble).

---

## Navigation Fallback

`NavigationAgent3D` settings (approx): `path_desired_distance=0.35`, `target_desired_distance=1.5`, avoidance off.

`_safe_navigation_direction()`:

- If map invalid / iteration id 0 / finished / next step too short → **direct horizontal chase**.
- Otherwise use next path point.

This keeps enemies mobile on freshly loaded procedural levels before nav bake settles.

---

## Per-Type Combat Behavior

### Ash Stalker

- Fast attack window (~0.22 / 0.10 / 0.18), low damage (~8).
- Marks `attack_is_low_sweep` — player jump can immune.

### Hollow / content melee

- Uses content `attack` dict when present; otherwise sentinel defaults.
- May mark low-sweep when close.

### Guardian / Boss

- Phase thresholds: legacy **0.5 / 0.25**, or content `phases` (Ch.1 giant gate phase 2 at **0.6**).
- Selects close / mid / long profiles by distance, **or** cycles authored phase attack lists when `Chapter1Content.boss().phases` is parsed.
- HUD uses content `display_name` (e.g. 守炉灵·巨阙).

### Healing punish

`on_player_healing()`:

- Force chase.
- Non-boss: temporary `move_speed *= 1.5` for **1.8s**.
- Boss: may insert a long-range interrupt when far.

---

## Content `behavior` Labels

Fields like `slow_patrol`, `teleport_ambush`, `defensive_hold` map through **`EnemyBehaviorRegistry`** (G-05) to family modules under `scripts/enemy/behaviors/`. `setup_from_content` normalizes via `EnemyAiCatalog` (aggro/leash/nav) then mounts `_behavior_module` for IDLE / engage / CHASE / ACTIVE hooks.

| Family | Runtime effect |
|--------|----------------|
| patrol | IDLE orbit around `spawn_origin` |
| hold | Tighter leash, lower chase accel |
| ambush | First engage short teleport |
| skirmish / ranged | Preferred-distance band |
| hazard | ACTIVE pull / zone pulse |
| special | Dive / clone meta / aura ticks |

Boss chapter powers (teleport chains / gravity / time) remain **G-06**, not G-05.

---

## Reset Contract

`reset_enemy()`:

- Restore HP, clear poise, return to `spawn_origin`, phase 1, disengage.
- Called on shrine rest and death-loop recovery.

Covered by `tests/smoke/death_loop_contract_test.gd` and GUT `tests/unit/systems/test_death_loop.gd` (I-07).

---

## 召唤物与敌 FSM 互认 (L-16)

`spirit_summon.gd` 召唤物实现敌 FSM 的通用目标接口，敌方会主动锁定、追击并结算伤害：

| 接口 | 行为 |
|------|------|
| `receive_hit(damage, stagger, hit_direction, source)` | 敌方命中入口：直接扣血，血尽走 `_die()` |
| `is_targetable()` | 存活且实例有效时才可被锁定 |
| `get_target_point()` | 返回 `global_position + UP*1.2`，供弹道/近战瞄准 |

- **5 灵行为差异**（`KIND_DATA`）：护法灵童近战坦/嘲讽、金甲力士重坦、往生莲原地治疗图腾（不攻击）、怨灵高伤快攻、白鹤童子浮空。
- 白鹤童子场时 **`player.focus_regen_multiplier = 1.5`**；离场/消失经 `_restore_boons()` 还原为 1.0。
- 召唤为临时盟友：无独立 AI 状态机，靠 `taunt_radius` / 攻击间隔 / 生命周期（`lifetime`）驱动。

---

## 人型抓投 (L-14)

`enemy.gd` 的 `can_grab` 决定是否尝试抓投：

- **content 显式键**：`content.can_grab` 为 bool 时直接采用。
- **体型启发式**：守护默认 `can_grab = true`；人型按 `body_type` 子串推断（`armored`/`armor`/`beast_humanoid`/`guard`/`knight`/`soldier`/`rebel`）。
- **人型短前摇**：非守护人型走 `_ensure_human_grab_profile()`（telegraph 1.05s，短前摇区间 0.9–1.2s；独立抓取体积，不走 CombatArea）。
- **Boss 路径保留**：守护者抓投仍走 Boss `_grab_profile` 分支，抓取判定不退化。

---

## 敌端状态效果 (L-10)

`enemy.gd` 拥有自己的状态面板（与玩家状态系统共用 `StatusEffectScript`）：

- `status_bar: Dictionary`：叠层容器。
- `apply_status(status_id, stacks, source)`：叠加并 emit `status_changed`；`bleed` 阈值爆发即时结算伤害。
- `status_changed(status_id, stacks)`：`0` 表示结束/清空；`StatusEffectScript.tick` 周期结算。
- 敌方自带状态按 `body_type` 推断（`STATUS_INFLICT_BY_BODY`）：出血/狐火/迷心/中毒（如 `hound_spectral`→bleed、`lantern_float`→foxfire、`shadow_form`→poison）。
- **附加到玩家**：敌方攻击载荷携带 `status:*` 标签，命中玩家后同样叠层（出血/狐火/迷心/中毒）；玩家命中敌人时，武器的 `status_inflict` / `status:*` 标签经 `_apply_status_from_payload` 叠到敌方 `status_bar`。

---

## Related

- [combat-execution-guard-weapon-arts.md](combat-execution-guard-weapon-arts.md) — 脆弱窗 / 处决  
- [devlog/index.md](../devlog/index.md) — G-01…G-08 交付摘要  
- [bestiary/enemies-master.md](../bestiary/enemies-master.md) — 设计名册  
