# 2026-07-30 — Chapter 1 Vertical Slice: Content Spawn, Module Behaviors, Level Exit

### Scope

Wired the first playable Chapter 1 slice into runtime (`H-04` Ch.1 subset + `H-07` start). `level_01_01` now spawns from `Chapter1Content` via `ChapterEnemyFactory`, activates interactive `fragile_floor` / `gate_exit` modules, and advances to `level_01_02` through the campaign exit interactable. Enemy mesh rebuild churn on every state change was also eliminated.

### Runtime Integration

- `game_world.gd` binds spawn/checkpoint/exit markers, spawns Ch.1 roster relative to the spawn marker (tutorial courtyard: 2× lost soul + 1× temple guardian; boss only on `level_01_05`).
- Checkpoint IDs now write `shrine_XX_YY` from campaign metadata instead of hardcoding `ember_shrine`.
- `CampaignModuleRuntime` activates module shells after each level load: fragile collapse, gate exit interact, hazard DPS tick, arena seal hint.
- Exit interact calls `ContentRegistry.get_next_level()`, records `completed_levels`, reloads geometry/encounters, and saves.

### Enemy Content Path

- `enemy.setup_from_content()` applies chapter dictionaries (stats + attack profile + colors).
- `ChapterEnemyFactory.build_into_slots()` fills existing body/weapon pivots without nesting a second weapon root.
- Visual rebuild is keyed (`_visuals_built_key`) so state flashes only recolor materials.

### Validation

- `ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`
- Existing `ASHEN_LEVEL_MODULE_CONTRACTS_OK` / `CAMPAIGN_GENERATION_OK` remain green
- Parser check-only clean for `enemy_factory.gd`, `enemy.gd`, `game_world.gd`, `campaign_module_runtime.gd`

### Files Changed

| File | Change |
|------|--------|
| `game/scripts/game_world.gd` | Chapter spawn, module activate, exit advance, marker-relative layout |
| `game/scripts/enemy.gd` | `setup_from_content`, visual rebuild guard, content tuning |
| `game/scripts/combat/enemy_factory.gd` | `build_into_slots` + body/weapon dispatch helpers |
| `game/scripts/world/campaign_module_runtime.gd` | **NEW** module behavior activator |
| `game/scripts/world/campaign_exit_interact.gd` | **NEW** exit interactable |
| `game/tests/smoke/chapter1_slice_contract_test.gd` | **NEW** slice contracts |
| `game/scripts/core/localization.gd` | New ZH strings for exit/floor/seal prompts |
| `tools/build.ps1` | Include chapter1 slice contract |

### Coordination

- Next: broaden module polish across remaining Chapter 1 levels (`H-04`), death-loop verification against campaign markers (`H-06`), and boss factory path for `boss_giant_gate` on `level_01_05`.

---
