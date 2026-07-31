# 2026-07-30 — Boss Weak-Point Executions + Grab Framework

### Scope

Ship E-10 Boss Execution Break for all five main bosses, weak-point executions with story HP floors, and a GrabProfile capture path that does not use ordinary CombatArea hits.

### Runtime

- `BossExecutionBreakProfile` + `BossExecutionCatalog` (巨阙/刑天/九尾/玄霄/烛阴)
- Guardian accumulates `execution_break` from hit payloads (charged/leap bonus); full meter → `WEAK_POINT_EXPOSED`
- Player light attack prefers weak-point execution; damage respects `story_floor_ratio` (九尾 30%, others 10%)
- `GrabProfile` + independent grab Area3D; player `GRABBED` state; miss recovery window
- HUD boss tooltip shows Break meter; story threshold HUD message
- Contract: `ASHEN_BOSS_WEAKPOINT_CONTRACTS_OK`

---
