# 2026-07-30 — Five-Chapter Campaign & Hand Combat Foundation

### Scope

Built the data-driven foundation for the full 28-level 烬渊 campaign: canonical content registry, save schema v2 migration (Godot + Flutter), independent right/left-hand combat replacing monolithic style presets, five chapter-matched procedural boss definitions, reusable level runtime, and a reference library of five open-source Godot soulslike projects under `example/`.

### Content Foundation

- Created `game/scripts/data/campaign_content.gd` — canonical `CampaignContent` with exactly 5 chapters (5/6/6/6/5 levels), 28 sublevels, 5 procedural themes, and 7 boss entries matching all design documents.
- Created `game/scripts/core/content_registry.gd` — indexed `ContentRegistry` with defensive-copy lookups by chapter/level/theme/boss.
- Created `game/scripts/core/content_validator.gd` — `ContentValidator` enforcing exact chapter/level counts, duplicate detection, boss-to-chapter mapping, cross-reference integrity, and endpoint validation.
- Created `game/tests/smoke/content_registry_contract_test.gd` — headless contract covering default catalog, registry lookups, mutability protection, and broken-catalog rejection.
- **Test:** `EMBER_ABYSS_CONTENT_REGISTRY_OK`

### Save Schema v2 Migration

**Godot side** (`game/scripts/core/run_state.gd`):
- Reads schema v1 and v2; always writes v2.
- Added `chapter_id`, `level_id`, `right_hand`, `left_hand`, `inventory`, `completed_levels`, `defeated_bosses`, `activated_checkpoints`, `completed_puzzles`, `collected_loot`, `choice_flags`, `progression_values`.
- Preserves all legacy `game_world` compatibility fields (`checkpoint_id`, `combat_style`, `guardian_defeated`, `activated_shortcuts`, `upgrade_tier`).
- v1 migration: deterministic style→hand mapping (guardian_sword/reliquary_shield, xingtian_axe_right/xingtian_axe_left, marksman_bow/marksman_dagger, five_elements_seal/spirit_stone, prayer_beads/talisman_papers).
- Guardian defeated migrates to canonical `boss_giant_gate`; legacy shortcuts scoped to `ember_shrine:ancient_gate`.
- `to_bridge_dictionary()` emits canonical nested shape: `location{chapterId,levelId,checkpointId}`, `player{embers,focus,upgradeTier,rightHand,leftHand}`, `progression` with full ID arrays and `choiceFlags`/`values`.
- `upgrade_tier` now serialized (was missing in v1).
- Accepts both flat snake_case local v2 and nested camelCase bridge v2 in `from_dictionary()`.

**Flutter side** (`app/lib/src/model/game_save_v2.dart`):
- Immutable `GameSaveV2` with nested `GameSaveLocationV2`, `GameSavePlayerV2`, `GameSaveProgressionV2`, `GameSaveLostEchoV2`.
- `fromAnyJson()` accepts v1 or v2; `fromV1()` maps canonical equipment IDs and defaults.
- `GameHostController` accepts `GameSaveV1` or `GameSaveV2` constructor argument; canonical v2 internally.
- `save.changed` bridge handler accepts either version.
- **Test:** `ASHEN_CORE_CONTRACTS_OK` (both Godot and Flutter sides, v1 migration, v2 round-trip, hand mappings, upgrade tier, progression, bridge naming, nested bridge parse).

### Independent Hand Combat

Replaced the 5 monolithic `CombatStyle` presets with explicit right/left-hand equipment and semantic hand actions:

- **Equipment registry** (`game/scripts/data/hand_equipment.gd`): 10 canonical items (guardian_sword, reliquary_shield, xingtian_axe_right/left, marksman_bow, marksman_dagger, five_elements_seal, spirit_stone, prayer_beads, talisman_papers). Each defines hand, primary/secondary action IDs, guard profile (absorption/stability/front_dot), and parry window. Five legacy style→loadout maps preserved.
- **Semantic inputs** (`game/scripts/game_world.gd`): `right_primary` (LMB/J/RB), `right_secondary` (RMB/K/RT), `left_primary` (C/LB), `left_secondary` (R/LT). Legacy aliases (`light_attack`, `heavy_attack`, `guard`, `parry`) intact.
- **Hand dispatch** (`game/scripts/player/player.gd`): `_execute_hand_action(hand, slot)` routes per-equipment actions — sword light/heavy, shield guard/parry/bash, axe strikes, bow shots, seal bolt/burst, beads heal, talisman attacks. `set_hand_loadout()` equips by ID; `set_combat_style()` remains as compatibility adapter.
- **Hit payloads** (`game/scripts/combat_area.gd`): `begin_swing()` accepts metadata dict → structured `hit_payload` with `hand`, `item_id`, `action_id`, `guard_damage`, `tags`, `blockable`, `parryable`. Legacy `receive_hit()` wraps into payload.
- **Projectile payloads** (`game/scripts/components/spell_projectile.gd`): `setup()` accepts metadata → `hit_payload` with same fields. Delivers via `receive_hit_payload()` or legacy fallback.
- **Guard resolver** (`game/scripts/combat/guard_resolver.gd`): Deterministic `GuardResolver.resolve()` — directional front arc, absorption/stability from shield profile, stamina check, guard break with forced stagger, unblockable bypass. Shield and spell_stone have distinct profiles.
- **Shield behavior**: guard only active during `LOCOMOTION`; automatically cancelled on state transition; shield bash (18 dmg, 42 stagger) via `_try_shield_bash()`; parry from left item profile; guard reduces damage (82% absorption) and zeroes stagger when sufficient stamina, or guard-breaks with amplified stagger.
- **HUD** (`game/scripts/hud.gd`): `hands_changed` signal → dual-hand labels displayed.
- **Mobile controls** (`game/scripts/ui/mobile_controls.gd`): Four dynamic hand buttons (R1/R2/L1/L2) with context-sensitive labels from equipment definitions.
- **Save integration**: `_apply_run_state()` and `_snapshot_run_state()` use `set_hand_loadout()`/`get_hand_loadout()`.
- **Tests:** `ASHEN_COMBAT_CONTRACTS_OK` (hand mappings, guard frontal/rear/break/unblockable, melee/projectile payloads). `ASHEN_HOLLOW_SMOKE_OK` (full runtime with hand combat).

### Procedural Campaign Runtime (Worktree Prototype)

Implemented in isolated worktrees; integration pending canonical-schema merge:

- **Runtime** (`game/scripts/world/`): `CampaignLevelRuntime` — single-level lifecycle (load/unload), `ProceduralLevelBuilder` — deterministic topology-driven geometry, `LevelThemeFactory` — 5 visually distinct chapter palettes/kits (Spirit Ruins, Blood Iron, Jade Veil, Celestial Fall, Ember Abyss). 28-level generation test passes in isolation.
- **Modules** (`game/scripts/levels/`): `ProceduralLevelModules` — reusable builder registry for hazards, gates/exits, fragile floors, projectile lanes, poison/fire zones, switches/offerings, moving platforms, illusion markers, gravity zones, arena seals. Each of 28 levels has module metadata.
- **Bosses** (`game/scripts/bosses/`, `game/scenes/actors/bosses/`): Profile-driven `BossController` with shared phase handling, deterministic attack selection, procedural primitive silhouettes, arena event/reset callbacks. Five dedicated scenes + definitions: 巨阙 (60% phase), 刑天 (70/30%), 九尾 (70/30%), 玄霄 + wrath/obsession fragments (60/30% with personality rotation), 烛阴 (70/40/10% dragon→humanoid→zero-gravity→non-combat choice).
- **Integration blocker**: Runtime/Modules use non-canonical level IDs (`1-1` vs `level_01_01`); need schema-first merge into canonical `CampaignContent` before composing into `game_world.gd`.

### Reference Examples

Added `example/` (gitignored) containing five open-source Godot soulslike/ARPG reference projects:

| Project | Godot Ver | Key Strengths |
|---------|-----------|---------------|
| `BreadbinEngine-main` | 4.x | CSV AttackTable, 6-element damage, combo queue, team system, left/right weapon slots |
| `Cats-Godot4-Modular-Souls-like-Template-main` | 4.2 | Signal-driven architecture, EquipmentSystem, 3-eye targeting, guard/parry, NavigationAgent3D AI, FollowCam |
| `Third-Person-Controller---Godot-Souls-like-main` | 3.x | Compact controller, AnimationTree combo detection, contextual attacks (sprint/roll), auto-follow camera |
| `adventure-mode-godot-main` | 4.7 | Modular Mobility Resources, ShapeCast3D hitboxes, action queue with ms buffer, dungeon puzzle tools, 4-type AI |
| `godot-ai-builder-main` | — | Claude Code plugin (skills + MCP); not game code but contains curated Godot 4 best-practice docs |

### Files Changed

| File | Change |
|------|--------|
| `.gitignore` | Added `example/` to ignore list |
| `game/scripts/data/campaign_content.gd` | **NEW** — canonical 5-chapter, 28-level, 5-theme, 7-boss definitions |
| `game/scripts/core/content_registry.gd` | **NEW** — indexed registry with defensive-copy lookups |
| `game/scripts/core/content_validator.gd` | **NEW** — cross-reference and count validation |
| `game/scripts/data/hand_equipment.gd` | **NEW** — 10-item equipment/action registry with guard/parry profiles |
| `game/scripts/combat/guard_resolver.gd` | **NEW** — deterministic guard resolution (arc/absorption/stability/break) |
| `game/tests/smoke/content_registry_contract_test.gd` | **NEW** — catalog, lookup, mutability, and broken-catalog coverage |
| `game/tests/smoke/combat_contract_test.gd` | **NEW** — hand mappings, guard matrix, payload builders |
| `game/scripts/core/run_state.gd` | Schema v2: nested location/player/progression/lostEcho; v1→v2 migration; upgrade_tier serialized |
| `game/scripts/game_world.gd` | Semantic inputs; hand save apply/snapshot; hands_changed signal wiring |
| `game/scripts/player/player.gd` | `right_hand_item`/`left_hand_item`; `set_hand_loadout()`; `_execute_hand_action()`; `receive_hit_payload()`; `_update_guard_active()` locomotion lock; shield bash; buffered semantic actions; guard cancel on state transition |
| `game/scripts/combat_area.gd` | Structured `hit_payload` dict; `begin_swing()` metadata parameter |
| `game/scripts/components/spell_projectile.gd` | `hit_payload` dict; metadata parameter on `setup()` |
| `game/scripts/hud.gd` | Dual-hand display via `hands_changed` signal |
| `game/scripts/ui/mobile_controls.gd` | R1/R2/L1/L2 dynamic buttons with context labels |
| `game/tests/smoke/core_contract_test.gd` | v1 migration, v2 round-trip, hand mappings, nested bridge parse |
| `game/tests/smoke/smoke_test.gd` | Extended: hand mapping, guard reduction, rear bypass, shield bash |
| `app/lib/src/model/game_save_v2.dart` | **NEW** — canonical v2 model with nested types and v1 migration |
| `app/lib/src/controller/game_host_controller.dart` | Accepts `GameSaveV1` or `GameSaveV2`; `fromAnyJson()` bridge handler |
| `app/test/model/game_save_v2_test.dart` | **NEW** — migration, round-trip, canonical shape, defensive copies |
| `app/test/controller/game_host_controller_test.dart` | v1/v2 controller and bridge coverage |
| `example/` | **NEW** (gitignored) — 5 reference projects |

### Validation

- All GDScript files parse cleanly with Godot 4.7.1 (`--editor --quit`).
- `ASHEN_CORE_CONTRACTS_OK` — save v1/v2 migration, hand mappings, upgrade tier, bridge parse, rejection.
- `ASHEN_COMBAT_CONTRACTS_OK` — hand mappings, guard frontal/rear/break/unblockable, melee/projectile payloads.
- `EMBER_ABYSS_CONTENT_REGISTRY_OK` — 5 chapters, 28 levels, 5 themes, cross-references, error detection.
- `ASHEN_HOLLOW_SMOKE_OK` — full bounded runtime with independent hand combat and shield behavior.
- Worktree prototypes pass in isolation (pending canonical-schema merge).

### Coordination

- The current playable build retains the original Ashen Hollow corridor + Cinder Guardian; hand combat is live within it.
- Campaign runtime, level modules, and boss architecture exist in worktree branches awaiting integration. Integration order: (1) extend canonical `CampaignContent` with seeds/module metadata, (2) import runtime + modules normalized to canonical IDs, (3) compose modules into builder, (4) import boss controller/scenes with canonical ID mapping, (5) add encounter orchestrator, (6) replace hard-coded level geometry with generated levels.
- Flutter Dart tests could not be executed (no Dart SDK on this machine); model code is source-reviewed.
- The `example/` directory is gitignored and serves as a local reference library; it is not compiled or shipped.

---
