# 烬渊 (Ember Abyss) — Master Task Backlog

**Created:** 2026-07-30
**Status:** `ACTIVE` — comprehensive task breakdown based on full-stack architecture audit
**Source:** 10-dimension technical audit of 5,702-line GDScript codebase + 55 design documents
**Engine:** Godot 4.7.1

---

## Task Organization

Tasks are organized into 10 dimensions (A–J), each representing a major architectural subsystem.
Each task is classified by:

| Field | Meaning |
|-------|---------|
| **ID** | Unique task identifier (e.g., A-01) |
| **Priority** | P0 (blocking) > P1 (critical) > P2 (high) > P3 (medium) > P4 (low) |
| **Status** | ✅ DONE / 🔴 BLOCKED / 🟡 IN PROGRESS / ⬜ PENDING / ⏸️ DEFERRED |
| **Effort** | S (hours) / M (days) / L (week) / XL (weeks) |
| **Depends On** | Task IDs that must complete first |
| **Blocks** | Task IDs that cannot start until this completes |
| **Detail** | Link to detailed task spec in `tasks/` subdirectory |

## Approved Execution Roadmap

The full backlog is executed in dependency-gated milestones. Campaign integration is the critical path; combat, testing, and documentation work may proceed in parallel only after shared runtime contracts are stable.

1. **Campaign contracts and migration safety** — H-01, H-02, I-01, I-02, I-09, J-03, J-08.
2. **Chapter 1 runtime vertical slice** — H-03, Chapter 1 subset of H-04, H-06, H-07, F-01, I-07.
3. **Full campaign topology and content activation** — remaining H-04, H-05, G-03, chapter-scoped G-04/G-05.
4. **Combat contracts and single data ownership** — A-01–A-07, B-01–B-04, E-04–E-06, I-04, J-05, J-07. Freeze compatibility tests before removing legacy dictionaries.
5. **Defense, poise, and human executions** — E-01–E-03, E-07–E-10, I-03, I-05, I-08, then the human-execution milestones in `tasks/combat-expansion-roadmap.md`.
6. **Movesets, grip modes, and authored animation** — B-05–B-08 and D-01–D-07 after `AttackData` parity and an authored-animation proof of concept.
7. **AI architecture and boss depth** — G-01, G-02, remaining G-04–G-06, I-06, J-10.
8. **Test completion, documentation, and release hardening** — remaining I/J tasks, build aggregation, and MCP/export exclusion checks.

**Critical path:** H-01 → H-02 → H-03 → Chapter 1 H-04 → H-07 → H-06/I-07 → remaining campaign integration → release hardening.

**First implementation slice:** canonical level-ID normalization, strict catalog validation, all-28-level compatibility contracts, `level_01_01` runtime metadata, and canonical save/checkpoint verification.

---

## Dimension A: Architecture Decoupling & Data-Driven Refactoring

> **Goal:** Eliminate hardcoded combat logic, move all weapon/attack config into custom Resources.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| A-01 | Extract typed `CombatStyleData` resources with Inspector-serializable timing, economy, leap, defense, and presentation fields | P1 | ✅ DONE | M | — | [tasks/a-01-combat-style-data.md](tasks/a-01-combat-style-data.md) |
| A-02 | Finish migration from legacy `STYLE_TIMING`: leap, dodge, and action armor must stop reading compatibility dictionaries | P0 | ✅ DONE | M | A-01 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-1--single-combat-data-owner) |
| A-03 | Implement `AttackData`, `ChargeProfile`, `MovesetData`, `WeaponData`, and schema validation | P1 | ✅ DONE | L | A-02 | [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md) |
| A-04 | Data-driven spell configuration: remove duplicate `SPELL_CONFIG` ownership and retain one authoritative resource path | P2 | ✅ DONE | M | A-02 | — |
| A-05 | Add `class_name` registration and combat Resource schema verification to validation pipeline | P1 | ✅ DONE | S | A-03 | — |
| A-06 | Implement `WeaponArtData`, migrate all five compatibility skills, and remove style `match` dispatch | P2 | ✅ DONE | L | A-03 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-7--weapon-arts) |
| A-07 | Migrate `HandEquipment` dictionaries to `WeaponData` / `GuardProfile` Resource references | P2 | ⬜ PENDING | L | A-03, E-07 | [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md#weapondata) |

---

## Dimension B: Combat Frame Data & Feel Differentiation

> **Goal:** Each combat style and future weapon class must feel physically distinct through authored timing, stamina, movement, stance, and tactical trade-offs. **Current state:** five `CombatStyleData` resources drive light/heavy/leap/dodge/WAM; `CompatibilityMovesetFactory` synthesizes `MovesetData` including dodge-cancel and Focus melee costs.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| B-01 | **Per-style stamina cost differentiation** — Twin Colossi heavy costs 65 stamina and all loadouts use the target economy | P0 | ✅ DONE | S | — | [tasks/b-01-stamina-differentiation.md](tasks/b-01-stamina-differentiation.md) |
| B-02 | Verify and tune differentiated frame data matrix (Windup/Active/Recovery) for all 5 styles against the compatibility baseline | P1 | ✅ DONE | M | B-01 | — |
| B-03 | Input buffering: verify 150ms window works correctly; add buffer queue visualization for debug mode | P2 | ⬜ PENDING | S | — | — |
| B-04 | Implement attack cancel windows — Crescent Pair post-recovery dodge cancel; Twin Colossi zero cancel | P2 | ✅ DONE | M | B-02 | — |
| B-05 | Heavy attack charge mechanic using discrete authored charge tiers | P2 | ✅ DONE | L | A-03, B-02 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-6--grip-modes-and-context-attacks) |
| B-06 | Running, rolling, and backstep attack contexts per supported moveset | P2 | ✅ DONE | L | A-03, B-04 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-6--grip-modes-and-context-attacks) |
| B-07 | Implement one-handed, two-handed, and paired grip modes with distinct movesets and no direct critical-damage doubling | P2 | ✅ DONE | XL | A-03 | [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md#单持双持与成对持握) |
| B-08 | Implement general jump, low-sweep immunity, jump attacks, and falling attacks; keep leap weapon arts separate | P2 | ✅ DONE | XL | A-03, D-01 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-6--grip-modes-and-context-attacks) |

### Compatibility Frame Baseline (originally informed by genre research; retune for 《焰渊》)

| Combat Style | Light Windup | Light Active | Light Recovery | Heavy Windup | Heavy Active | Heavy Recovery | Stamina (Light/Heavy) |
|---|---|---|---|---|---|---|---|
| 护卫之道 (Reliquary Guard) | 0.28s | 0.15s | 0.32s | 0.58s | 0.22s | 0.65s | 22 / 40 |
| 刑天斧法 (Twin Colossi) | 0.48s | 0.22s | 0.52s | 0.82s | 0.28s | 0.90s | 38 / 65 |
| 羿弓术 (Crescent Pair) | 0.20s | 0.12s | 0.20s | 0.38s | 0.16s | 0.38s | 16 / 28 |
| 五行术 (Veilcraft) | 0.25s cast | Instant | 0.20s | — | — | — | 14/22 Focus |
| 天祝术 (Ember Rite) | 0.50s chant | Instant | 0.30s | — | — | — | 20/35 Focus |

**B-02 verification (2026-07-30):** All five `game/resources/combat_styles/*.tres` checked against this table.

| Style | Before → After (W/A/R light · W/A/R heavy · stam L/H) | Result |
|---|---|---|
| Reliquary Guard | `0.28/0.16/0.38 · 0.58/0.22/0.62 · 22/40` → `0.28/0.15/0.32 · 0.58/0.22/0.65 · 22/40` | Aligned |
| Twin Colossi | `0.48/0.20/0.62 · 0.82/0.26/0.92 · 38/65` → `0.48/0.22/0.52 · 0.82/0.28/0.90 · 38/65` | Aligned |
| Crescent Pair | `0.20/0.14/0.28 · 0.38/0.18/0.44 · 16/28` → `0.20/0.12/0.20 · 0.38/0.16/0.38 · 16/28` | Aligned |
| Veilcraft | light `0.30/0.16/0.42` → `0.25/0.0 Instant/0.20`; stam `0/0` (Focus 14/22 via `SPELL_CONFIG`); heavy `—` retained offhand compat `0.52/0.20/0.58` | Light aligned; heavy N/A by design |
| Ember Rite | light `0.34/0.18/0.48` → `0.50/0.0 Instant/0.30`; stam `0/0` (Focus economy via cast path); heavy `—` retained offhand compat `0.56/0.22/0.64` | Light aligned; heavy N/A by design |

Note: Veilcraft Focus 14/22 already matches `veil_bolt` / `seal_burst`. Ember Rite baseline Focus 20/35 vs live `ember_rite` cast cost 25 is owned by `SPELL_CONFIG` (outside B-02 `.tres` scope).

---

## Dimension C: Hit-Stop & Audio-Visual Feedback

> **Goal:** Replace global `Engine.time_scale` hit-stop with actor-local freezes; implement trauma-based screen shake; add audio low-pass filtering on heavy impacts. **Current state:** Local HitStop freezes entity state/input/horizontal motion while world/UI continue; trauma shake shipped (C-02/C-03); heavy-hit Master low-pass duck shipped (C-04).

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| C-01 | Replace global time-scale hit-stop with actor-local freezes (entity state/input paused; world physics/UI continue) | P0 | ✅ DONE | M | — | [tasks/c-01-local-hitstop.md](tasks/c-01-local-hitstop.md) |
| C-02 | FastNoiseLite trauma shake with exponential decay, intensity scaling, and reduced-motion disablement | P1 | ✅ DONE | M | C-01 | [tasks/c-02-trauma-shake.md](tasks/c-02-trauma-shake.md) |
| C-03 | Weapon-weight-based trauma injection: light 0.3, heavy 0.8, explosion 1.0 | P1 | ✅ DONE | S | C-02 | — |
| C-04 | Add audio low-pass filter ducking on heavy hit impacts via `procedural_audio.gd` | P3 | ✅ DONE | S | — | Master bus `AudioEffectLowPassFilter` duck via `duck_heavy_impact()`; headless no-op |
| C-05 | Weapon trail VFX enhancement: color/intensity tied to attack weight class | P4 | ⬜ PENDING | M | — | — |

---

## Dimension D: Animation & Root Motion Integration

> **Goal:** Replace code-driven velocity manipulation with AnimationTree root motion extraction for physically grounded movement. **Current state:** All movement is code-driven via `_physics_process` velocity setting. No root motion extraction exists.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| D-01 | Set up `AnimationTree` with `AnimationNodeStateMachinePlayback` for player — root bone track extraction | P1 | 🟡 PARTIAL | L | — | [tasks/d-01-root-motion-setup.md](tasks/d-01-root-motion-setup.md) |
| D-02 | Implement `get_root_motion_position()` / `get_root_motion_rotation()` integration in `_physics_process` | P1 | ⬜ PENDING | M | D-01 | — |
| D-03 | Lock-on strafe BlendSpace2D — blend walk/run animations with lateral movement during lock-on | P2 | ⬜ PENDING | L | D-01 | — |
| D-04 | Force `Process Callback = Physics` on AnimationTree to prevent frame-rate-dependent root motion drift (Godot issues #53752, #65199) | P1 | ✅ DONE | S | D-01 | — |
| D-05 | Heavy weapon (Twin Colossi) leap attack animation with root motion — forward lunge driven by animation data | P2 | ⬜ PENDING | L | D-02 | — |
| D-06 | Paired execution animation framework: anchor alignment, exclusive claim, event-point damage, cancellation recovery | P1 | ⬜ PENDING | L | A-03, D-01, E-09 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-5--human-executions) |
| D-07 | Grab paired-animation framework using independent capture shapes and `GRAB_INITIATOR` / `GRABBED` states | P3 | ✅ DONE | L | D-06 | [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md#grabprofile) |

---

## Dimension E: Stamina, Poise & Defense Systems

> **Goal:** Implement an 《焰渊》-specific continuous Poise model, equipment-driven parry/guard profiles, independent guard break and vulnerability states, and human/Boss execution contracts. **Current state:** enemy Poise is a simple accumulator, player action armor is binary, and the existing GuardResolver handles angle/absorption/stability/stamina but not Guard Meter or execution vulnerability.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| E-01 | **Implement continuous Poise** — standing reserve + WAM capacity via `PoiseResolver`; per-`AttackData` phase ownership remains | P1 | 🟡 PARTIAL | L | A-03, B-01 | [tasks/e-01-poise-system.md](tasks/e-01-poise-system.md) |
| E-02 | Migrate heavy-action protection from binary `hyper_armor` to authored phase modifiers | P1 | ⬜ PENDING | M | E-01 | — |
| E-03 | Poise break: when reserve reaches zero, force `STAGGER`; otherwise apply HP and impact feedback without interrupting | P1 | ✅ DONE | M | E-01 | — |
| E-04 | **Parry window differentiation by tool** — medium shield, buckler, dagger, and fist profiles | P2 | ✅ DONE | M | — | [tasks/e-04-parry-windows.md](tasks/e-04-parry-windows.md) |
| E-05 | Verify the actual per-action stamina recovery delays and freeze behavior during non-LOCOMOTION states; do not assume one universal 1.5s value | P2 | 🟡 PARTIAL | S | — | — |
| E-06 | Guard stability differentiation by shield weight class | P3 | ⬜ PENDING | M | — | — |
| E-07 | Add `GuardProfile`, Guard Meter, edge-angle stamina factor, and direct impact break threshold | P1 | ✅ DONE | M | A-03 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-3--guard-meter-and-guard-break) |
| E-08 | Add independent `GUARD_BROKEN`, `PARRY_VULNERABLE`, and `WEAK_POINT_EXPOSED` states | P1 | ✅ DONE | M | E-01, E-07 | [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md#目标状态模型) |
| E-09 | Implement human front execution and backstab eligibility, anchors, exclusive claims, and critical damage events | P1 | ✅ DONE | L | E-08, A-03 | [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md#milestone-5--human-executions) |
| E-10 | Implement separate Boss Execution Break meters and five boss-specific weak-point execution contracts | P2 | ✅ DONE | XL | E-09, G-06 | [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md#非人型与-boss-弱点处决) |

---

## Dimension F: Camera Control & Target Lock-On

> **Goal:** SpringArm3D collision avoidance; screen-space dot-product target scoring; quaternion slerp smooth tracking; target cycling. **Current state:** SpringArm mask verified (F-01 DONE); lock-on with distance-based selection and cycling implemented. Dot-product scoring and slerp tracking need verification.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| F-01 | Verify SpringArm3D collision mask is correctly configured for all level geometry layers | P2 | ✅ DONE | S | — | `collision_mask=1`（仅静态世界 Layer1）；排除玩家(2)/敌人(4)/交互物(8)。关卡几何均 layer=1。权威：`player.gd` `_configure_spring_arm_collision()` |
| F-02 | Screen-space/FOV lock-on scoring with deterministic angle cycling and pure solver contracts | P2 | ✅ DONE | M | — | [tasks/f-02-lockon-scoring.md](tasks/f-02-lockon-scoring.md) |
| F-03 | Quaternion slerp smooth tracking: replace any `look_at()` calls with `slerp` interpolation for lock-on rotation | P2 | ⬜ PENDING | S | F-02 | — |
| F-04 | Target cycling: verify clockwise/anticlockwise cycling by screen angle; add input for cycle direction | P3 | 🟡 PARTIAL | S | F-02 | — |
| F-05 | Lock-on break distance verification and camera recovery behavior | P3 | ⬜ PENDING | S | — | — |

---

## Dimension G: Enemy & Boss AI — Deep Behavioral Logic

> **Goal:** Behavior tree + FSM hybrid for boss macro decisions; healing-punish tendency; phase transition polish; ranged/ambush enemy archetypes. **Current state:** Cinder Guardian has 3-phase transitions, distance-bracket attack selection, and healing-punish (speed boost + long-range queue). One additional enemy archetype (Ash Stalker) exists.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| G-01 | Integrate LimboAI behavior tree plugin for boss macro decision layer (patrol, disengage, phase switch, healing-punish override) | P2 | ⬜ PENDING | XL | — | [tasks/g-01-limboai-bt.md](tasks/g-01-limboai-bt.md) |
| G-02 | Healing-punish tendency: verify current implementation; add per-boss punish behavior variants (gap-close, ranged snipe, AoE burst) | P1 | 🟡 PARTIAL | M | — | — |
| G-03 | Add third enemy archetype: ranged/ambush enemy with projectile attack and retreat behavior | P2 | ⬜ PENDING | L | — | — |
| G-04 | Boss phase transition polish: transition animation blending, camera focus shift, arena VFX | P2 | 🟡 PARTIAL | M | — | Combat camera shots for weak-point / grab / fate; phase VFX still open |
| G-05 | Per-chapter enemy AI parameter tuning: detection radii, leash limits, navigation behavior for all 32 enemy types | P3 | ⬜ PENDING | XL | — | — |
| G-06 | Implement chapter-specific boss behaviors (teleport chains for 九尾, gravity manipulation for 玄霄, time manipulation for 烛阴) | P3 | ⬜ PENDING | XL | G-01 | — |

---

## Dimension H: Campaign Level Integration & Schema Conflict Resolution

> **Goal:** Resolve level ID naming conflict (1-1 → level_01_01) blocking campaign integration; integrate ProceduralLevelModules into main game loop; implement shortcut spatial-folding topology. **Current state:** Worktree prototypes exist with non-canonical IDs. Content registry uses canonical `level_01_01` format. Integration is blocked.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| H-01 | **Resolve campaign level ID schema conflict** — define canonical policy and inject a temporary lookup adapter | P0 | ✅ DONE | M | — | [tasks/h-01-schema-conflict.md](tasks/h-01-schema-conflict.md) |
| H-02 | Recursive dry-run-first migration tool plus canonical imported module metadata; zero real legacy IDs remain | P0 | ✅ DONE | M | H-01 | [tasks/h-02-tool-migration.md](tasks/h-02-tool-migration.md) |
| H-03 | Canonical campaign builder consumes deterministic seeds, module metadata, encounter IDs, and checkpoint IDs | P1 | ✅ DONE | L | H-02 | — |
| H-04 | Compose ten reusable module families into all 28 generated levels; behavior polish remains chapter-scoped | P1 | 🟡 PARTIAL | XL | H-03 | — |
| H-05 | Implement shortcut spatial-folding topology: one-way doors,升降梯 activation that connects back to Ember Shrine | P2 | ⬜ PENDING | L | H-04 | — |
| H-06 | Death loop verification: Lost Echo placement accuracy, enemy reset integrity, shrine respawn position | P2 | ✅ DONE | M | — | — |
| H-07 | Chapter 1 tutorial level (1-1) full playable integration as vertical slice demo | P1 | ✅ DONE | XL | H-04 | — |

---

## Dimension I: GUT Automated Testing Coverage

> **Goal:** Deploy GUT 9.x framework; achieve >70% logic-path coverage for FSM, combat, stamina, death loop. **Current state:** ~10-15% coverage (contract tests only). Zero GUT framework deployed. Only manual smoke tests exist.

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| I-01 | Deploy pinned GUT 9.7.1 for Godot 4.7, enable editor plugin, and verify framework health | P0 | ✅ DONE | S | — | [tasks/i-01-gut-deploy.md](tasks/i-01-gut-deploy.md) |
| I-02 | Configure headless recursive unit execution with JUnit XML and portable runners | P0 | ✅ DONE | S | I-01 | — |
| I-03 | Player FSM behavior tests: attack chain, timed states, dead action guards, respawn, WAM, and guard cancel | P0 | ✅ DONE | M | I-01 | [tasks/i-03-fsm-tests.md](tasks/i-03-fsm-tests.md) |
| I-04 | Stamina invariants: clamp/floor, locomotion gating, delay freeze, target style costs, action blocking, and respawn | P0 | ✅ DONE | M | I-01, B-01 | [tasks/i-04-stamina-tests.md](tasks/i-04-stamina-tests.md) |
| I-05 | **Hit deduplication tests** — `double()` enemy doubles; single-swing-per-body verified via `assert_called` spies | P1 | ⬜ PENDING | M | I-01 | — |
| I-06 | Enemy FSM transition validity tests — no illegal transitions; RETURN→IDLE on reaching spawn | P1 | ⬜ PENDING | M | I-01 | — |
| I-07 | Death/recovery loop integration tests — ember drop, LostEcho spawn, enemy reset, checkpoint respawn | P1 | ⬜ PENDING | L | I-01 | — |
| I-08 | Guard/parry resolution matrix tests — frontal guard, rear bypass, guard break, parry window edge cases | P1 | ⬜ PENDING | M | I-01 | — |
| I-09 | Save/load disk persistence round-trip test — extend existing in-memory test to `user://` path | P2 | ✅ DONE | S | — | `tests/smoke/core_contract_test.gd` (`user://i09_save_persistence_contract`) |
| I-10 | External smoke runner with production code reduced to a three-line delegation hook | P1 | ✅ DONE | M | — | [tasks/i-10-extract-smoke.md](tasks/i-10-extract-smoke.md) |
| I-11 | CI integration: GitHub Actions / local CI script running full GUT suite headless with JUnit XML output | P2 | ✅ DONE | M | I-02 | `tools/ci.ps1`, `tools/ci.sh`, `.github/workflows/gut-ci.yml` |

---

## Dimension J: Documentation Governance & Technical Reference

> **Goal:** Rewrite stale docs; create missing technical references; establish documentation as single source of truth. **Current state:** J-01–J-12 complete as of 2026-07-30 (topic refs under `systems/`).

| ID | Task | Priority | Status | Effort | Depends | Detail |
|----|------|----------|--------|--------|---------|--------|
| J-01 | **Rewrite `controls.md`** — verified keyboard/mouse, controller, touch, resource, and five-loadout reference | P0 | ✅ DONE | M | — | [tasks/j-01-controls-rewrite.md](tasks/j-01-controls-rewrite.md) |
| J-02 | **Update `architecture.md`** — add scripts/ subdirectories, data classes, host bridge, title/pause/death/victory UI flow, Focus resource system | P1 | ✅ DONE | M | — | — |
| J-03 | **Fix `validation.md`** — fix script glob (`scripts/**/*.gd`), align project paths, add contract test commands, update controller limitation, add content registry test | P1 | ✅ DONE | S | — | — |
| J-04 | Add banner to `research.md` noting it predates handoff state; point to devlog and post-audit research docs | P3 | ✅ DONE | S | — | — |
| J-05 | **Maintain Combat System Reference** — current compatibility behavior plus the target execution/guard/poise/moveset/weapon-art contract | P1 | ✅ DONE | L | B-02 | [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md) |
| J-06 | Write Build & Export Guide — `tools/build.ps1`, export preset config, per-platform caveats, smoke-test commands, Web CAPABILITIES注意事项 | P2 | ✅ DONE | S | — | [systems/build-export-guide.md](systems/build-export-guide.md) |
| J-07 | Write Focus Resource System reference — max pool, regen rules, per-style costs, Focus economy design | P2 | ✅ DONE | S | — | [systems/focus-resource.md](systems/focus-resource.md) |
| J-08 | Write Save/Persistence Design — save format, schema versioning, migration path, `user://` layout | P2 | ✅ DONE | S | — | [systems/save-persistence.md](systems/save-persistence.md) |
| J-09 | Write Audio System Reference — procedural audio API, 6-voice pool, available cues, headless detection, adding new sounds | P3 | ✅ DONE | S | — | [systems/audio-system.md](systems/audio-system.md) |
| J-10 | Write Enemy AI Specification — detection radii, leash limits, sanctuary disengagement, navigation fallback, per-type tuning table | P3 | ✅ DONE | M | — | [systems/enemy-ai.md](systems/enemy-ai.md) |
| J-11 | Update `00-master-index.md` — add links to all new task files, task specs, and updated references | P2 | ✅ DONE | S | — | [00-master-index.md](00-master-index.md) |
| J-12 | Maintain `attack-moveset-data-schema.md` and validate code/resources against the documented ownership rules | P1 | ✅ DONE | M | A-03 | [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md#runtime-validation-audit-j-12--2026-07-30) |

---

## Quick Reference: Priority-Ordered Execution Plan

### Phase 1 — Blocking Fixes (P0, ~2 weeks)

```
Week 1:
  B-01 ── Per-style stamina cost differentiation
  C-01 ── Local AnimationTree hit-stop (replace Engine.time_scale)
  H-01 ── Campaign level ID schema conflict resolution
  I-01 ── Deploy GUT 9.x framework

Week 2:
  H-02 ── @tool migration script for level IDs
  I-02 ── Headless CLI test execution config
  I-03 ── Player FSM state transition tests
  I-04 ── Stamina economy invariant tests
  J-01 ── Rewrite controls.md
```

### Phase 2 — Combat Contracts, Data, and Defense (P0–P1)

```text
Compatibility freeze:
  A-02 ── Remove remaining gameplay reads from legacy STYLE_TIMING
  I-03/I-04/I-05/I-08 ── FSM, economy, hit, guard, and parry contracts

Data foundation:
  A-03 ── AttackData / MovesetData / WeaponData
  A-05 ── Resource schema validation
  E-07 ── GuardProfile + Guard Meter + direct break

Defense and vulnerability:
  E-01/E-02/E-03 ── Continuous poise and action armor
  E-08 ── Guard-broken / parry-vulnerable / weak-point states
  E-09 + D-06 ── First human front execution and backstab slice
```

### Phase 3 — Integration & Polish (P1–P2, ~6 weeks)

```
Week 7-8:
  H-03 ── ProceduralLevelBuilder integration
  H-04 ── ProceduralLevelModules composition
  H-07 ── Chapter 1 tutorial level vertical slice

Week 9-10:
  G-02 ── Healing-punish per-boss variants
  G-03 ── Third enemy archetype
  J-02 ── Update architecture.md
  J-03 ── Fix validation.md
  J-05 ── Combat Style Reference

Week 11-12:
  D-03 ── Lock-on strafe BlendSpace2D
  E-04 ── Parry window differentiation
  F-02 ── Lock-on dot-product scoring
  F-03 ── Quaternion slerp tracking
```

### Phase 4 — Movesets, Boss Breaks, and Animation (P2–P3)

```text
  B-05/B-06 ── Charge and movement-context attacks
  B-07/B-08 ── Grip modes, jump, and falling attacks
  A-06/A-07 ── Resource-driven weapon arts and equipment
  D-01–D-05 ── AnimationTree and root-motion proof of concept
  E-10 ── Five main-boss weak-point execution contracts
  D-07 ── Grab framework after paired execution animation is stable
  I-11 ── CI integration
```

### Deferred Until Vertical Slice Contracts Pass

```text
  C-05 ── Weapon trail VFX enhancement
  G-05 ── Per-chapter enemy AI tuning (all 32 types)
  G-06 ── Chapter-specific boss behaviors beyond the selected vertical slice
```

---

## Dependency Graph (Blocking Relationships)

```text
A-02 compatibility parity
        ↓
A-03 attack/moveset Resources ──→ A-05 validation
        ↓                         ↓
E-07 guard profiles          B-05–B-08 context/grip actions
        ↓                         ↓
E-08 vulnerability states    A-06/A-07 weapon arts/equipment
        ↓
E-09 + D-06 human executions
        ↓
E-10 boss weak points ──→ D-07 grabs
        ↓
D-01–D-05 authored animation/root motion integration
```

Campaign H-02–H-07 and test I-01–I-11 continue in parallel where their dependencies allow.

---

## Status Summary

| Dimension | Total | Done | In Progress / Partial | Pending | Deferred | Blocked |
|-----------|-------|------|-----------------------|---------|----------|---------|
| A — Architecture | 7 | 1 | 1 | 5 | 0 | 0 |
| B — Frame Data | 8 | 1 | 1 | 6 | 0 | 0 |
| C — Hit-Stop/Feedback | 5 | 0 | 0 | 5 | 0 | 0 |
| D — Root Motion/Paired Animation | 7 | 0 | 0 | 7 | 0 | 0 |
| E — Stamina/Poise/Defense/Execution | 10 | 1 | 1 | 8 | 0 | 0 |
| F — Camera/Lock-On | 5 | 1 | 2 | 2 | 0 | 0 |
| G — Enemy/Boss AI | 6 | 0 | 1 | 5 | 0 | 0 |
| H — Campaign Integration | 7 | 1 | 2 | 4 | 0 | 0 |
| I — GUT Testing | 11 | 6 | 0 | 5 | 0 | 0 |
| J — Documentation | 12 | 3 | 1 | 8 | 0 | 0 |
| **Total** | **78** | **14** | **9** | **55** | **0** | **0** |

---

## Related Documents

- [audit-docs-codebase-health.md](audit-docs-codebase-health.md) — full doc + codebase health assessment
- [devlog.md](devlog.md) — chronological development record with resume order
- [game-design.md](game-design.md) — vertical slice vision, combat pillars, tuning targets
- [research-dark-souls-mechanics-deep.md](research-dark-souls-mechanics-deep.md) — frame data, poise math, Godot patterns
- [research-dark-souls-weapons.md](research-dark-souls-weapons.md) — per-style weapon tuning recommendations
- [research-github-godot-soulslike-ecosystem.md](research-github-godot-soulslike-ecosystem.md) — ecosystem survey, reusable module checklist
- [project-structure.md](project-structure.md) — repository layout, naming rules, safe-change procedures
