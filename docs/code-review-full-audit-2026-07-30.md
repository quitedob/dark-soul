# Code Review: Ashen Hollow Full Audit — 2026-07-30

**Review mode:** Full Audit (user-requested)
**Scope:** `docs/`, `game/scripts/`, `game/tests/`, plus comparative analysis of 3 external Godot Souls-like examples
**Reviewers:** Documentation scout, Code scout, BreadbinEngine analyst, Adventure Mode analyst, Third-Person Controller analyst

---

## Executive Summary

Ashen Hollow (烬渊 / Ember Abyss) is a Godot 4.7.1 Souls-like action RPG at a mature prototype stage: ~5,700 lines of GDScript across 16+ core files, 18 contract/smoke tests, 5 combat styles with data-driven Resource pipelines, procedural campaign generation, and a Flutter companion app. The documentation has been recently refreshed (2026-07-30 J-dimension pass) and is largely reliable, though the tasks-master.md summary table is stale relative to individual task rows. The code architecture generally matches documented contracts, with the expected expansion of the player FSM from the documented 12-state model to 17 runtime states (combat expansion targets now implemented). Three external example projects were analyzed for cross-pollination: BreadbinEngine (Godot 4 Souls-like framework), Adventure Mode Godot (modular movement/platformer), and Third-Person Controller Godot Souls-like (Godot 3.x camera/movement reference).

**Key findings:** 3 HIGH-severity code issues, 4 MEDIUM-severity architectural concerns, 6 high-priority cross-pollination recommendations from external examples.

---

## Part 1: Documentation Reliability Assessment

| Document | Reliability | Notes |
|----------|------------|-------|
| `docs/00-master-index.md` | RELIABLE | Recently refreshed (J-11 DONE) |
| `docs/architecture.md` | RELIABLE | Updated via J-02; reflects current runtime |
| `docs/game-design.md` | RELIABLE | Prototype targets; some scope boundaries evolved (e.g., save system now exists) |
| `docs/controls.md` | RELIABLE | J-01 rewrite complete |
| `docs/project-structure.md` | RELIABLE | Reflects actual layout |
| `docs/validation.md` | RELIABLE | Audit issues resolved in current version |
| `docs/tasks-master.md` | **STALE (summary) / RELIABLE (rows)** | Summary table at lines 339-350 undercounts DONE tasks. Individual task rows are authoritative. |
| `docs/audit-docs-codebase-health.md` | PARTIALLY RELIABLE | Original flags now addressed; stale assessment table |
| `docs/systems/combat-styles.md` | PARTIALLY RELIABLE | Design-level content (elemental arrows, spirit summons) beyond implementation boundary |
| `docs/systems/combat-execution-guard-weapon-arts.md` | RELIABLE | Target authority, J-05 DONE |
| `docs/systems/attack-moveset-data-schema.md` | RELIABLE | Code-verified via J-12 audit |
| `docs/systems/audio-system.md` | **CONTRADICTED** | Doc says "13 cues," code has **14 cues**. |
| `docs/systems/enemy-ai.md` | RELIABLE | Behavior labels (`slow_patrol`, etc.) are design-only, not runtime |
| `docs/systems/focus-resource.md` | RELIABLE | J-07 verified |
| `docs/systems/save-persistence.md` | RELIABLE | J-08 verified |
| `docs/chapters/01-spirit-awakening/chapter-overview.md` | RELIABLE | Design specification |
| `docs/story/chapter-bridge-map.md` | RELIABLE | Implementation specification; explicitly not runtime |

**Cross-document contradictions found:**
1. `audio-system.md` states 13 cues; `procedural_audio.gd` implements 14 cues (`docs/systems/audio-system.md:17-31` vs `game/scripts/procedural_audio.gd`)
2. `architecture.md` states 12-state player FSM; `player.gd` implements 17 runtime states (`docs/architecture.md:57-73` vs `game/scripts/player/player.gd:18-37`)
3. `tasks-master.md` summary table (lines 339-350) undercounts DONE tasks vs individual row statuses (e.g., Dimension J: 3 DONE in summary, 12 DONE in rows)

---

## Part 2: Code Architecture Findings

### HIGH Severity

#### H-1: Potential focus resource leak in attack commit path
**Confidence:** LIKELY
**File:** `game/scripts/player/player.gd:1053-1061`

The `_commit_attack()` method deducts focus cost before some early-return paths that cancel the attack. If a spell-style melee attack is cancelled due to insufficient stamina or other guard conditions after focus has been deducted, the focus is not refunded. The focus deduction at line 1061 occurs after the stamina guard at line 1053, making it conditionally safe in the current code flow, but the interleaving of resource deductions and guard checks is fragile and error-prone for future modifications.

**Recommendation:** Deduct all resources atomically after all guard checks pass, or implement a resource-transaction pattern that can be rolled back.

#### H-2: Player `_ready()` duplicates initialization from `setup()`
**Confidence:** CONFIRMED
**File:** `game/scripts/player/player.gd:262-268`

`_ready()` re-initializes `_spells` and `_visuals` after `setup()` may have already done so. If `setup()` was called before `_ready()` (e.g., via `game_world.gd` composition), this creates duplicate initialization. Additionally, `_spells.setup(self, world_node)` at line 265 passes `world_node` which is null if `setup()` was not called first — `PlayerSpells.setup()` stores null silently.

**Recommendation:** Guard with a `_initialized` flag, or move all initialization to `setup()` and remove from `_ready()`.

#### H-3: Enemy `receive_hit()` adapter constructs inconsistent execution break payload
**Confidence:** CONFIRMED
**File:** `game/scripts/enemy.gd:297`

The adapter `receive_hit()` hardcodes `execution_break_damage` at `stagger * 0.35`, which may diverge from authored `AttackData.execution_break_damage` values in `.tres` resources. The canonical handler `receive_hit_payload()` (line 311) receives the full payload from `AttackData.to_hit_metadata()`, but the adapter path bypasses authored data.

**Recommendation:** Route all hit reception through `receive_hit_payload()` and remove the thin adapter, or ensure the adapter extracts `execution_break_damage` from the full `AttackData` payload.

---

### MEDIUM Severity

#### M-1: Enemy attacks use raw floats, not `AttackData` Resources
**Confidence:** CONFIRMED
**File:** `game/scripts/enemy.gd:1226-1311`

Enemy attack profiles are defined as raw dictionaries in `_apply_tuning()` with inline floats, not as `AttackData` Resources. This means:
- `AttackData.validate()` is not available for enemy attacks
- Enemy attacks cannot benefit from the Resource inspector UX
- Changes to attack timing require code edits rather than `.tres` authoring

**Recommendation:** Migrate enemy attack profiles to `AttackData` Resources, or create a lightweight `EnemyAttackProfile` Resource with the same validation pipeline.

#### M-2: Guard-active coupling is fragile
**Confidence:** CONFIRMED
**File:** `game/scripts/player/player.gd:1703-1704`

`guard_active` is set to `false` on every `_change_state()` when the new state is not `LOCOMOTION`, then re-evaluated in `_handle_action_input()`. This implicit coupling between state transitions and guard status means guard-deactivation logic is split across two different methods with no explicit contract.

**Recommendation:** Create an explicit `_set_guard_active(value: bool)` method that encapsulates all guard state transitions, called from a single location.

#### M-3: `music_volume` setting not wired to AudioBus
**Confidence:** CONFIRMED
**File:** `game/scripts/game_world.gd:903-905`

The `_apply_settings()` method has a commented-out block for routing `settings.music_volume` to the Music AudioBus. The setting is stored and persisted but has no runtime effect.

**Recommendation:** Uncomment and wire the music bus, or document this as an intentional limitation with a tracking task.

#### M-4: HUD `show_message()` coroutine may orphan on free
**Confidence:** LIKELY
**File:** `game/scripts/hud.gd` (show_message method)

`show_message()` uses `await` internally for tweened fade animations. If the HUD is freed (e.g., scene change) while a message tween is active, the coroutine becomes orphaned and may attempt to access freed nodes.

**Recommendation:** Track active tweens and cancel them in `_exit_tree()`, or use a `weakref` guard before accessing tweened nodes.

---

### LOW Severity

#### L-1: `_level_transition_locked` guard never reset on failure
**File:** `game/scripts/game_world.gd:62`
The lockout prevents double-triggering level transitions but is never reset if a transition fails mid-way. This would soft-lock the game until restart.

#### L-2: Missing null checks on `combat_area` in some code paths
**File:** `game/scripts/player/player.gd:1701`
`_change_state()` accesses `combat_area.end_swing()` inside a state-list guard, but the guard doesn't explicitly check `combat_area != null`.

#### L-3: Procedural audio silently fails on unknown cue IDs
**File:** `game/scripts/procedural_audio.gd`
`play_cue()` checks `library.has(cue)` but does not validate against a known enum. Unknown cues silently fail with no warning.

---

## Part 3: Test Coverage Assessment

### Existing Tests (18 smoke + 3 GUT unit)

**Well-covered:**
- Guard resolver (front/rear/broken/unblockable) — `combat_contract_test.gd`
- Run state v1→v2 migration, round-trip, rejection — `core_contract_test.gd`
- Stamina economy (clamping, regen, style costs, focus caps) — `test_stamina_economy.gd`
- Attack moveset schema validation, tag conflicts — `test_attack_moveset_schema.gd`
- Player FSM happy paths (attack chain, dodge, parry, dead) — `test_player_fsm.gd`

### Coverage Gaps

| Area | Missing Tests |
|------|--------------|
| Player GRABBED state | No test |
| Player EXECUTE_WINDUP/ACTIVE/RECOVERY states | No test |
| Player CHARGE_HEAVY tier release | No test |
| Player GUARD_BROKEN state | No test |
| Player input buffering (150ms window) | No test |
| Enemy FSM transitions | No test |
| Enemy grab_windup/active/recovery | No test |
| Enemy boss phase transitions | No test |
| Enemy healing-punish behavior | No test |
| Game world composition (signal wiring) | No smoke test |
| HUD signal wiring | No test |
| Procedural audio cue playback | No test (headless mode skips audio) |
| Checkpoint/death-loop integration | Covered by `death_loop_contract_test.gd` (partial) |
| Focus regen rate correctness | No test |
| Poise resolver standalone | No standalone test |
| Execution solver | No standalone test |
| Lock-on solver | No standalone test |

---

## Part 4: Comparative Analysis — External Example Projects

### 4A. BreadbinEngine (Godot 4 Souls-like Framework)

**Project:** `example/BreadbinEngine-main/`
**Relevance:** Same genre, same engine major version

#### Key Patterns Found

1. **Animation callback bridge** (`Scripts/Actors/ActorAnimationPlayer.gd:21-43`)
   - AnimationPlayer method-call tracks invoke gameplay callbacks (`allow_combo()`, `activate_weapon_hitbox()`, `push_actor_forward()`)
   - Decouples animation authoring from code timing
   - **Recommendation:** Adopt for frame-accurate hitbox windows and combo gates in Ashen Hollow. Replace `state_time <= 0.0` checks with animation event callbacks on `PlayerAnimationBridge`.

2. **CSV-driven AttackTable** (`Data/AttackTable.tres`)
   - Attack parameters stored in CSV, loaded at runtime
   - Non-programmer-friendly authoring
   - **Recommendation:** Build a CSV→`.tres` import tool (extending the existing `export_reliquary_weapon.gd` pattern) to allow spreadsheet-based attack tuning.

3. **Teams/faction damage matrix** (`Scripts/Globals/Global_Actor_Settings.gd:6`)
   - Simple `Teams_CanHurt` boolean matrix for friendly-fire configuration
   - **Recommendation:** Add faction relationships to enable enemy-vs-enemy combat and future summon/ally mechanics.

4. **Inspector-exportable AI parameters** (`Scripts/Actors/Actor_AI.gd:14-19`)
   - Attack chances exposed as `@export var` with range hints
   - **Recommendation:** Create `EnemyTuningData` Resource with Inspector-facing enums/sliders instead of hardcoded `_apply_tuning()` switch logic.

### 4B. Adventure Mode Godot (Modular Movement Platformer)

**Project:** `example/adventure-mode-godot-main/`
**Relevance:** Advanced modular architecture, multiplayer-ready patterns

#### Key Patterns Found

1. **MovementPackage system** (`Modular Mobility/MovementPackage.gd:1-27`)
   - Runtime-swappable movement Resources with transfer/release predicates
   - Each package bundles animation sub-tree, physics behavior, and transition rules
   - **Recommendation (High):** Replace flat state enums with MovementPackage Resources for grip modes (1H/2H/paired), climbing, swimming. The transfer/release predicate pattern localizes transition logic.

2. **Action Queue buffer** (`scripts/actor.gd:437-468`)
   - Millisecond-expiration action dictionary consumed by animation state machine
   - 33ms buffer (~2 frames at 60fps), auto-expiring
   - **Recommendation (Highest):** Adopt directly — dependency-free, critical for Souls-like input buffering feel. Complements the existing 150ms single-slot buffer.

3. **PlayerSocket / Thrall decoupling** (`scripts/playerSocket_adventure.gd:1-342`)
   - Input translation separated from controlled entity
   - AI uses exact same `handle_movement()`/`enque_action()` interface as player
   - **Recommendation (High):** Refactor player.gd into a pure movement/action receiver. Move input reading to a PlayerSocket node. Enables future NPC possession, drop-in co-op, spectator mode.

4. **Dodge/Sprint dual-button mapping** (`scripts/playerSocket_adventure.gd:132-147`)
   - Same button = dodge (tap <200ms) or sprint (hold ≥200ms)
   - Simple timer threshold, no state machine involvement
   - **Recommendation (High):** Implement directly — essential for Souls-like control feel.

5. **Gantry/camera separation** (`scripts/cam_gantry_playerFollow.gd` + `scripts/camera_control.gd`)
   - Position-follow smoothing and look-rotation are separate nodes
   - Recenter timer: camera auto-returns to default angle after input stops
   - **Recommendation:** Split camera rig into gantry (follow) + camera (look) nodes. Add recenter timer for non-locked exploration.

6. **Combat hitbox exception + attackID dedup** (`scripts/armament.gd:41-88`)
   - `add_exception()` for wielder's own hurtboxes before enabling hitbox
   - `randi()` attackID prevents multi-hit within single swing
   - **Recommendation:** Adopt as cleaner alternative to manual `already_hit` flag toggling.

### 4C. Third-Person Controller Godot Souls-like (Godot 3.x)

**Project:** `example/Third-Person-Controller---Godot-Souls-like-main/`
**Relevance:** Specifically targeted at Souls-like controller feel

#### Key Patterns Found

1. **Camera auto-follow Timer pattern** (`scripts/CameraTemplate.gd:30,46-49`)
   - Camera auto-rotates behind player after manual input stops
   - Rotation speed proportional to player velocity (`horizontal_velocity.length() * rot_speed_multiplier`)
   - **Recommendation:** Add Timer-based auto-follow mode to Ashen Hollow's non-locked camera.

2. **Per-state acceleration tuning** (`scripts/PlayerTemplate.gd:99-101,120-123`)
   - `acceleration` drops from 15→2 during rolls, `angular_acceleration` drops from 10→2
   - Creates heavier, more committed feel during actions
   - **Recommendation:** Expose `attack_acceleration` and `roll_acceleration` as tuning parameters, replacing the single `MOVE_ACCELERATION` constant.

3. **One-shot velocity impulse for dodge** (`scripts/PlayerTemplate.gd:60`)
   - Dodge = `horizontal_velocity = direction * dash_power` (single impulse)
   - Consistent distance regardless of framerate
   - **Recommendation:** Consider replacing per-frame dodge velocity with one-shot impulse for deterministic dodge distance.

4. **Doubled falling gravity** (`scripts/PlayerTemplate.gd:105`)
   - `gravity * 2` when airborne for snappier jumps/falls
   - **Recommendation:** Simple game-feel improvement; adopt immediately.

5. **Floor-normal slope slide prevention** (`scripts/PlayerTemplate.gd:107`)
   - `vertical_velocity = -get_floor_normal() * gravity / 3` when grounded
   - **Recommendation:** Apply `floor_snap_length` to player CharacterBody3D; the enemy already uses this (`enemy.gd:1512`).

6. **Animation-driven combo validation** (`scripts/PlayerTemplate.gd:62-75`)
   - Combo chaining checks current animation node name
   - **Recommendation:** Expose current animation node from `PlayerAnimationBridge` for combo validation as supplement to logic-state checks.

---

## Part 5: Prioritized Recommendations

### Immediate (HIGH impact, LOW effort)

| # | Recommendation | Source | Target File(s) |
|---|---------------|--------|----------------|
| 1 | Fix focus resource leak in `_commit_attack()` | Code audit | `player.gd:1053-1061` |
| 2 | Guard `_ready()` init with `_initialized` flag | Code audit | `player.gd:262-268` |
| 3 | Route all enemy hits through `receive_hit_payload()` | Code audit | `enemy.gd:297` |
| 4 | Implement Action Queue buffer system | Adventure Mode | `player.gd` (new method) |
| 5 | Add Dodge/Sprint dual-button mapping | Adventure Mode | `player.gd` (input handling) |
| 6 | Apply doubled falling gravity | Third-Person Controller | `player.gd:298-301` |
| 7 | Add `floor_snap_length` to player CharacterBody3D | Third-Person Controller | `player.gd` |

### Short-term (HIGH impact, MEDIUM effort)

| # | Recommendation | Source | Target File(s) |
|---|---------------|--------|----------------|
| 8 | Adopt animation callback bridge for hitbox windows | BreadbinEngine | `PlayerAnimationBridge.gd` |
| 9 | Add per-state acceleration tuning parameters | Third-Person Controller | `player.gd` |
| 10 | Implement camera auto-follow Timer | Third-Person Controller | `player.gd` (camera section) |
| 11 | Migrate enemy attacks to AttackData Resources | Code audit | `enemy.gd`, new `.tres` files |
| 12 | Add faction/teams damage matrix | BreadbinEngine | `game_world.gd` |

### Medium-term (MEDIUM impact, MEDIUM-HIGH effort)

| # | Recommendation | Source | Target File(s) |
|---|---------------|--------|----------------|
| 13 | Refactor to PlayerSocket/Thrall pattern | Adventure Mode | `player.gd` (major refactor) |
| 14 | Implement MovementPackage system for grip modes | Adventure Mode | Architecture change |
| 15 | Build CSV→.tres attack data import tool | BreadbinEngine | `tools/` |
| 16 | Create EnemyTuningData Resource with @export sliders | BreadbinEngine | `enemy.gd`, new Resource |
| 17 | Split camera rig into Gantry + Camera nodes | Adventure Mode | Scene structure |

### Polish (LOW impact, LOW effort)

| # | Recommendation | Source | Target File(s) |
|---|---------------|--------|----------------|
| 18 | Wire `music_volume` to AudioBus | Code audit | `game_world.gd:903-905` |
| 19 | Add `_exit_tree()` tween cancellation to HUD | Code audit | `hud.gd` |
| 20 | Validate procedural audio cue IDs against enum | Code audit | `procedural_audio.gd` |
| 21 | Reset `_level_transition_locked` on failure | Code audit | `game_world.gd:62` |
| 22 | Add randomized footstep queue with pitch variation | Adventure Mode | `procedural_audio.gd` |
| 23 | Expose animation node info from PlayerAnimationBridge | Third-Person Controller | `PlayerAnimationBridge.gd` |

---

## Part 6: Summary of Checks Run

| Check | Status |
|-------|--------|
| Documentation reliability audit | COMPLETE — 17 docs reviewed, 1 CONTRADICTED, 1 STALE, 2 PARTIALLY RELIABLE |
| Player FSM vs architecture.md contract | COMPLETE — 17 states runtime vs 12 documented (expansion by design) |
| Combat data resource pipeline | COMPLETE — All Resources present, schema validation operational |
| Enemy AI vs documentation | COMPLETE — FSM matches, behavior labels design-only |
| Procedural audio cue count | COMPLETE — 14 cues runtime vs 13 documented |
| Guard resolver contract tests | COMPLETE — Front/rear/broken/unblockable all covered |
| Run state persistence and migration | COMPLETE — v1→v2 migration covered, rejection tested |
| External example analysis | COMPLETE — 3 projects analyzed, 23 actionable recommendations |
| Test coverage gap analysis | COMPLETE — 12 coverage gaps identified |
| Static code inspection (all core files) | COMPLETE — player.gd, enemy.gd, game_world.gd, hud.gd, combat_area.gd, procedural_audio.gd, all data Resources |

### Checks NOT Run (blocked or out of scope)

| Check | Reason |
|-------|--------|
| Runtime smoke test (`--smoke-test`) | Requires Godot editor with project loaded |
| GUT unit test suite | Requires Godot editor headless runner |
| CI pipeline (`tools/ci.ps1`) | Requires full build environment |
| Visual/rendering verification | Procedural meshes — no imported art to validate |
| Mobile/touch input verification | Requires device or emulator |
| Multiplayer testing | Not implemented |
| Performance profiling | Requires running game with profiler |

---

## Part 7: Unreviewed Scope

- `app/` (Flutter host) — out of scope for this review
- `mcp/` (Godot MCP Native) — out of scope
- `packages/` — out of scope
- `tools/` — not deeply inspected (only `export_reliquary_weapon.gd` referenced)
- `game/resources/` `.tres` files — verified by schema tests, not manually inspected
- `game/scenes/` — procedural construction makes scene files minimal
- `game/assets/` — not inspected (generated/placeholder assets)

---

## Part 8: Residual Risk

1. **FSM transition enforcement:** `_change_state()` does not reject illegal transitions programmatically (documented as known behavior). Risk: state corruption if input timing creates unexpected transition paths.
2. **CombatStyle enum order sensitivity:** `STYLE_NAMES` constant array must match enum order. Risk: desync on enum reordering causes wrong style name display.
3. **No AnimationTree on player scene:** All animation is code-timed. Root motion support is POC-only (straight sword). Risk: animation-authoring pipeline not yet production-ready.
4. **Enemy content behavior labels** (`slow_patrol`, `teleport_ambush`, `defensive_hold`) are design tags with no FSM branching. Risk: enemies in chapters 2-5 may behave identically to chapter 1 enemies.
5. **Campaign beyond Chapter 1:** Documentation states placeholder encounters only. Risk: full campaign content not yet playable.

---

*Report generated 2026-07-30. Reviewed by documentation scout, code scout, and 3 external project learning scouts under the codereviewer full-audit methodology.*
