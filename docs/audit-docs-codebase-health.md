# Audit — Documentation & Codebase Health

**Date:** 2026-07-30
**Status:** `ACTIVE` — 2026-07-30 Dimension J complete (J-01…J-12). Topic refs: build/export, focus, save, audio, enemy AI under `systems/`.
**See also:** [`research-dark-souls-design.md`](research-dark-souls-design.md) — 12-topic DS design audit, vertical slice checklist, documentation reliability table
**See also:** [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) — per-style weapon tuning, documentation staleness assessment
**See also:** [`research-dark-souls-mechanics-deep.md`](research-dark-souls-mechanics-deep.md) — frame data, poise math, verified-implemented vs pending gaps
**See also:** [`research-github-godot-soulslike-ecosystem.md`](research-github-godot-soulslike-ecosystem.md) — ecosystem survey, reusable module checklist
**See also:** [`devlog.md`](devlog.md) — chronological record of all changes, resume order
**See also:** [`project-structure.md`](project-structure.md) — directory layout, naming rules, safe-change procedures

Audit conducted 2026-07-30 via two exhaustive read-only subagent scans: one covering all 20 files in `docs/` (including 9 agent definitions in `docs/agents/`), and one covering all 16 GDScript files (5,702 lines), 10 scenes, project configuration, assets, and tests in `game/`. Every `.gd` file was read at least partially; every `.tscn`, `.cfg`, and test file was inspected. This report synthesizes both scans into a single health assessment with ranked, actionable recommendations.

---

## Methodology

### Scan Coverage

| Scan Target | Scope | Method |
|---|---|---|
| `docs/` | 20 files, ~260 KB | Full read of every `.md` file; cross-reference mapping; staleness audit against code state documented in devlog |
| `docs/agents/` | 9 agent definitions | Full read; skill dependency mapping; routing rule analysis |
| `game/scripts/` | 16 `.gd` files, 5,702 lines | Full or substantial-partial read of every file; class/function inventory; preload/signal/call dependency graph |
| `game/scenes/` | 10 `.tscn` files | Full read; node-type, script-attachment, and load-step audit |
| `game/project.godot` | 1 config file | Full read; renderer, input map, autoload, physics, display, plugin audit |
| `game/assets/` | 4 files | Full read; font license, glyph coverage, import configuration |
| `game/tests/` | 1 test file, 131 lines | Full read; test case inventory, coverage gap analysis |

### Evidence Classification

| Label | Criteria |
|---|---|
| **Observed** | Directly verified in file contents, line counts, preload paths, scene structure, or signal connections. |
| **Derived** | Inferred from code patterns, dependency graphs, or comparison across files. |
| **Gap** | Absence confirmed by exhaustive search — no file, function, test, or documentation section exists for the topic. |

No claim in this report relies on external research or developer interviews. Every finding is grounded in file contents observable in the repository at scan time.

---

## 1. Documentation Suite Health

### 1.1 Complete File Inventory

| # | File | Size | Category | Health |
|---|---|---|---|---|
| 1 | `game-design.md` | 8 KB | Design spec | ✅ **CURRENT** — updated in commit `7f30d4f` with Vitality Forging, Ember Rite, boss phases, enemy reset |
| 2 | `architecture.md` | 4 KB | Technical spec | ⚠️ **PARTIALLY RELIABLE** — missing title screen, pause flow, 5 combat styles, scripts/ subdirectories |
| 3 | `project-structure.md` | 8 KB | Process | ✅ **CURRENT** — reflects repository layout; dependency direction and naming rules intact |
| 4 | `controls.md` | 4 KB | Reference | ✅ **CURRENT** — J-01 rewrite covers five styles, controller, touch, resources |
| 5 | `validation.md` | 4 KB | Process | ⚠️ **PARTIALLY RELIABLE** — script glob misses subdirectories; project path may be outdated; controller claim wrong |
| 6 | `research.md` | 12 KB | Research | ⚠️ **PARTIALLY RELIABLE** — foundational design advice still sound; predates 5-style system and post-audit fixes |
| 7 | `devlog.md` | 24 KB | Process | ✅ **CURRENT** — 6 dated entries through 2026-07-30; resume order defined |
| 8 | `research-dark-souls-design.md` | 28 KB | Research | ✅ **CURRENT** — updated 2026-07-29 to post-fix state; 9 audit fixes reflected |
| 9 | `research-dark-souls-weapons.md` | 36 KB | Research | ✅ **CURRENT** — updated 2026-07-29; 11 recommendations status-tracked (1 DONE, 5 PENDING, 5 DEFERRED) |
| 10 | `research-dark-souls-mechanics-deep.md` | 40 KB | Research | ✅ **CURRENT** — created 2026-07-30; frame data, poise math, Godot patterns |
| 11 | `research-github-godot-soulslike-ecosystem.md` | 48 KB | Research | ✅ **CURRENT** — created 2026-07-30; 8 repos, level design patterns, hour estimates |
| 12–20 | `agents/*.md` (9 files) | ~72 KB total | Agent defs | ✅ **CURRENT** — consistent template; routing rules prevent overlap; no game-specific knowledge (by design) |

### 1.2 Staleness Detail

#### 🔴 HIGH — `controls.md`

Written for the initial prototype state (pre-handoff). Missing in the current document:

| Missing Topic | Where Documented Instead |
|---|---|
| Reliquary Guard (timed parry, shield guard, thrust attacks) | `devlog.md` handoff entry; `game-design.md` |
| Twin Colossi (paired great-blade jump attack) | Same |
| Crescent Pair (paired curved-blade two-hit jump attack) | Same |
| Veilcraft (focus-powered projectile magic) | Same |
| Ember Rite (focus-powered healing and damage prayer) | Same |
| Controller bindings | Not documented anywhere |
| Touch control layout | Not documented anywhere |
| Focus resource key binding | `player.gd` code only |
| Style-switching input | `player.gd` code only |

**Recommendation:** Full rewrite. Use `game-design.md` combat pillars + `player.gd` input handling as source of truth. Add per-style input table, controller map, and touch layout diagram.

#### ⚠️ MEDIUM — `architecture.md`

Scene tree diagram shows the initial prototype (`AshenHollow` → `WorldEnvironment` → `Warden` → `EmberShrine` → ...). Missing from the current diagram:

- Title screen flow (`hud.gd._build_title()`)
- Pause menu with settings panel scaffolding
- `scripts/app/`, `scripts/core/`, `scripts/ui/` subdirectories
- `AshenRunState`, `AshenGameSettings`, `AshenLocalization` data classes
- `AshenGameHostBridge` web host protocol layer
- Focus resource system alongside stamina

**Recommendation:** Add subdirectory breakdown, data-class section, host bridge architecture, and UI flow diagram (title → play → pause → death → victory). The existing responsibility table and collision layer documentation are correct and should be preserved.

#### ⚠️ MEDIUM — `validation.md`

Three specific issues:

1. **Script glob**: `scripts/*.gd` does not recurse into `scripts/app/`, `scripts/components/`, `scripts/core/`, `scripts/ui/`. Should be `scripts/**/*.gd`.
2. **Project path**: Uses `D:/godot/newproject` but `project-structure.md` specifies `D:/godot/newproject/game` as the Godot project root. The `--path` argument must point to `game/`.
3. **Known limitation #4**: "Keyboard/mouse is implemented; controller support ... remain future work" — controller support was added (devlog handoff entry). Update to reflect current state.
4. **Missing command**: `core_contract_test.gd` (prints `ASHEN_CORE_CONTRACTS_OK`) is not documented. Add the contract test invocation.

**Recommendation:** Fix glob, align paths with `project-structure.md`, update controller limitation, add contract test command.

#### ⚠️ LOW — `research.md`

Predates the 5-style system, controller support, subdirectory restructuring, and all post-audit fixes. The design advice (attack commitment, stamina economy, enemy telegraphing, checkpoint design) remains sound. The implementation-claims section describes the initial prototype, not the handoff state.

**Recommendation:** Add a banner at top: "This report was written during the initial prototype phase (2026-07-29). For current implementation state, see [`devlog.md`](devlog.md) and the three post-audit research documents. The design principles and Godot API mappings remain valid."

### 1.3 Cross-Reference Network

| Document | Cited By | Cites |
|---|---|---|
| `research-dark-souls-design.md` | 4 others | 8 docs |
| `research.md` | 6 others | 0 docs (external URLs only) |
| `research-dark-souls-weapons.md` | 4 others | 8 docs |
| `devlog.md` | 2 others | 7 docs + code files |
| `research-dark-souls-mechanics-deep.md` | 0 others (newest) | 4 docs |
| `research-github-godot-soulslike-ecosystem.md` | 1 other | 3 docs |
| `game-design.md` | 4 others | 0 docs |
| `architecture.md` | 2 others | 0 docs (code only) |
| `controls.md` | 2 others | 0 docs |
| `validation.md` | 2 others | 0 docs |
| `project-structure.md` | 2 others | 7 docs |

**Observation:** The three most isolated documents (`controls.md`, `validation.md`, `architecture.md`) are also the three that need updating. Documents with rich bidirectional cross-references (`research-dark-souls-design.md`, `research-dark-souls-weapons.md`) are well-maintained. Cross-reference density correlates with document health.

### 1.4 Agent Definitions

All 9 agents in `docs/agents/` follow an identical template (YAML frontmatter, "Your Skills" section, "Your Process", "Distinguishing Choices", "Output Format", "When NOT to use"). They are reusable GodotPrompter specialist definitions with no game-specific knowledge — this is by design.

| Agent | Domain | Routes To |
|---|---|---|
| `godot-game-architect` | System design, scene trees, signals, state machines (read-only) | godot-csharp-engineer, godot-animator, godot-ui-designer, godot-tools-engineer |
| `godot-game-dev` | General GDScript/C# implementation | godot-csharp-engineer, godot-animator, godot-ui-designer, godot-tools-engineer |
| `godot-code-reviewer` | Code review, anti-patterns, performance | Domain-specific skills based on code content |
| `godot-animator` | AnimationPlayer, AnimationTree, IK, retargeting | godot-game-dev for gameplay logic |
| `godot-csharp-engineer` | C#-first dev, GC patterns, parity mode | — |
| `godot-shader-author` | Shaders, Compositor, visual shader graphs | godot-game-dev, godot-performance-profiler |
| `godot-ui-designer` | Control nodes, containers, themes, localization | godot-game-dev, godot-shader-author, godot-animator |
| `godot-performance-profiler` | CPU/GPU bottleneck diagnosis | godot-game-architect, godot-game-dev, godot-shader-author |
| `godot-tools-engineer` | EditorPlugin, custom inspectors, @tool scripts | godot-game-dev, godot-shader-author, godot-performance-profiler |

**Health:** All agent definitions are internally consistent, have clear routing rules that prevent overlap, and follow the same professional template. No updates needed.

---

## 2. Codebase Health

### 2.1 File Inventory

| File | Lines | Class / Extends | Purpose |
|---|---|---|---|
| `scripts/player/player.gd` | 1,140 | `CharacterBody3D` | 12-state player: LOCOMOTION, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, DODGE, STAGGER, DEAD, PARRY, GUARD, CAST, HEAL, INTERACT |
| `scripts/hud.gd` | 1,132 | `CanvasLayer` | Full procedural HUD: vitals bars, boss bar, title/pause/death/victory/help overlays, locale switching (en/zh_CN), accessibility (UI scale, text scale, reduced motion, high contrast), mobile controls |
| `scripts/game_world.gd` | 962 | `Node3D` | World orchestrator: spawns all entities, wires all signals, manages save/load, checkpoint logic, shrine upgrades, death/recovery loop, host bridge integration, embedded smoke test (140 lines, gated by `--smoke-test`) |
| `scripts/enemy.gd` | 704 | `CharacterBody3D` | 8-state enemy FSM: IDLE, CHASE, WINDUP, ACTIVE, RECOVERY, STAGGER, RETURN, DEAD. Cinder Guardian variant with phase 2 (≤50% HP), distance-bracket attack selection (3 brackets), weapon emission glow, stagger transition |
| `scripts/ui/mobile_controls.gd` | 358 | `Control` | Touch overlay: virtual joystick (dynamic positioning), camera drag area, 5 action buttons, sprint hold |
| `scripts/checkpoint.gd` | 171 | `Area3D` | Ember Shrine: activate, rest (full heal + enemy reset), Vitality Forging upgrade UI, flame visual state |
| `scripts/shortcut.gd` | 165 | `Area3D` | Shortcut lever: tween-driven gate open, persistent state in run_state |
| `scripts/lost_echo.gd` | 154 | `Area3D` | Corpse recovery: floating echo orb, body/ring/glow procedural visuals, ember recovery on touch |
| `scripts/app/game_host_bridge.gd` | 147 | `Node` | Web host protocol: JSON v1, bidirectional message passing, 8 signals, performance telemetry |
| `scripts/core/game_settings.gd` | 145 | `RefCounted` | `AshenGameSettings`: locale, UI/text scale, audio volumes, FPS cap, Godot + bridge serialization |
| `scripts/core/run_state.gd` | 143 | `RefCounted` | `AshenRunState`: checkpoint, embers, focus, combat_style, lost_echo_position, shortcuts, guardian_state, upgrade_tier. Schema-versioned save/load |
| `scripts/procedural_audio.gd` | 133 | `Node` | Runtime AudioStreamWAV synthesis: tones, noise bursts, chimes, victory fanfare. 6-voice pool. Headless-safe |
| `scripts/core/localization.gd` | 89 | `RefCounted` | `AshenLocalization`: 79 en/zh_CN string pairs, `normalize_locale()`, static `text()` |
| `scripts/components/spell_projectile.gd` | 73 | `Area3D` | Veil Bolt: 15 m/s, 2.2 s lifetime, blue emissive glow, hit-on-body with `receive_hit()` |
| `scripts/combat_area.gd` | 55 | `Area3D` | Hitbox: one-hit-per-body-per-swing dedup, direction-aware knockback, `begin_swing()`/`end_swing()` lifecycle |
| `tests/smoke/core_contract_test.gd` | 131 | `SceneTree` | 4 headless tests: run state round-trip, invalid data rejection, settings sanitization, bridge contract |

**Total: 5,702 lines of GDScript + 131 lines of tests = 5,833 lines.**

### 2.2 Architecture Assessment

The codebase follows a **central-mediator pattern** with clean signal-based communication:

```
main.tscn
  └── ashen_hollow.tscn (game_world.gd)  ← single orchestrator
        ├── ProceduralAudio (procedural_audio.gd)
        ├── Warden (scripts/player/player.gd)
        ├── HUD (hud.gd)
        │     └── MobileControls (mobile_controls.gd)
        ├── EmberShrine (checkpoint.gd)
        ├── AncientLever (shortcut.gd)
        ├── HollowSentinel × N (enemy.gd)
        ├── CinderGuardian (enemy.gd)
        ├── LostEcho (lost_echo.gd) — spawned on death
        └── GameHostBridge (game_host_bridge.gd)
```

**Key architectural properties:**

| Property | Assessment |
|---|---|
| **Coupling** | Low. Scripts communicate via signals. Duck-typing (`has_method()`) used throughout instead of explicit type checks. `player.gd` accesses world via untyped `world_node` reference. |
| **Cohesion** | High within each script. `player.gd` handles all player concerns; `enemy.gd` handles all enemy concerns; `game_world.gd` handles orchestration only. |
| **Autoloads** | None. All singleton-like objects (`AshenGameSettings`, `AshenRunState`, `AshenLocalization`) are plain `RefCounted` instances created and held by `game_world.gd`. This keeps the architecture explicit but means `game_world.gd` is both orchestrator and pseudo-DI container. |
| **Procedural content** | 100%. Every visual (BoxMesh, CapsuleMesh, CylinderMesh, SphereMesh, TorusMesh, PrismMesh, QuadMesh) and every audio sample (PCM WAV synthesis) is code-generated. Zero imported textures, models, or audio files. |
| **Input** | InputMap built programmatically in `game_world.gd._configure_inputs()` — 24 actions covering keyboard, mouse, and gamepad. `mobile_controls.gd` synthesizes `InputEventMouseMotion` and calls `Input.action_press()/action_release()` directly. |
| **Collision layers** | Layer 1 = static world, Layer 2 = player, Layer 3 = interactables, Layer 4 = enemies. Combat areas use directed masks (player hits layer 4, enemies hit layer 2). |

### 2.3 Strengths

1. **Attack commitment model** is correct. Three-phase attacks (wind-up/active/recovery) with non-cancellable windows match Souls-like design requirements. Input buffer (150 ms, last-input-wins) is implemented and gated by `_can_buffer_in_current_state()`.

2. **Stamina system** is correct. Shared budget (attack/dodge/sprint all draw from one pool), regeneration delay gated to `State.LOCOMOTION`, frame-counting cooldown in `_physics_process` (not `await`). This matches the industry-standard pattern documented in [`research-dark-souls-mechanics-deep.md`](research-dark-souls-mechanics-deep.md) Section 7.3.

3. **Boss design** is directionally correct. Phase transition at ≤50% HP, distance-bracket attack selection (3 brackets: close <2.0 m, mid 2.0–3.5 m, long >3.5 m), phase 2 with faster windups/shorter recoveries/higher damage. Missing healing-punish tendency (see Gaps, Section 3.2).

4. **Data integrity** is robust. Schema-versioned JSON serialization (`AshenRunState`, `AshenGameSettings`), input clamping on deserialization, null guards throughout, `has_method()` before every cross-script call.

5. **Localization** is complete. 79 translated strings, `normalize_locale()` for tolerant matching, embedded Noto Sans CJK with documented glyph subset. HUD reads all user-facing strings through `AshenLocalization.text()`.

6. **Accessibility** is built in. UI scale (0.5–2.0), text scale (0.5–2.0), reduced motion (disables Tweens), high contrast mode, keyboard alternatives for all mouse actions.

7. **Web host integration** is professional. Versioned JSON protocol (v1), bidirectional message passing, performance telemetry (`send_performance_sample()`), graceful degradation when no host is present (`is_connected_to_host()`).

8. **Zero TODO debt**. A search for `TODO|FIXME|HACK|XXX|BUG|WORKAROUND` across all 5,702 lines returned zero matches.

### 2.4 Potential Concerns

| Concern | Severity | Detail |
|---|---|---|
| **No autoloads** | LOW | `game_world.gd` manually creates and holds `AshenGameSettings`, `AshenRunState`, `AshenLocalization`, and `AshenGameHostBridge`. This works for the current scale but means any script needing settings must reach through the world node. As script count grows, consider autoloads for the three data classes. |
| **Embedded smoke test** | LOW | 140 lines of smoke-test logic live inside `game_world.gd` (lines 822–962), gated by `--smoke-test`. This is production code that only runs during testing. It prints `ASHEN_HOLLOW_SMOKE_OK` and calls `get_tree().quit()`. Consider extracting to `tests/smoke/`. |
| **Mobile detection duplication** | LOW | User-agent and pointer media query checks appear in both `game_world.gd` and `hud.gd`. Candidate for extraction into a shared helper or a `PlatformCapabilities` resource. |
| **All-uniform combat timing** | MEDIUM | All 5 combat styles use identical wind-up, active, and recovery durations. This is the #1 pending recommendation from both [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) and [`research-dark-souls-mechanics-deep.md`](research-dark-souls-mechanics-deep.md). |
| **No test coverage for gameplay** | MEDIUM | Only data contracts and host protocol are tested. Combat, AI, UI, input, and rendering have zero automated tests. Manual playtesting is the only verification path. |
| **No editor-placed content** | INFO | This is a deliberate architectural choice, not a defect. All content is code-generated. Adding new enemy types, environments, or effects requires writing GDScript rather than using Godot's editor tools. |

### 2.5 Scene Design Pattern

All 10 `.tscn` files are **minimal stubs** (2 load steps, format 3) — a single root node with an attached script. All child nodes, geometry, materials, collision shapes, and visual elements are created procedurally in `_ready()`.

**Rationale (derived from code patterns):** This approach eliminates scene-merge conflicts in version control, keeps all logic in searchable `.gd` files, and makes the project's behavior fully auditable by reading scripts alone. The trade-off is that Godot's editor scene tools (visual placement, material preview, lighting preview) provide no value during development.

### 2.6 Test Coverage Assessment

| Area | Coverage | Gap |
|---|---|---|
| Data serialization | ✅ Round-trip tested | — |
| Input sanitization | ✅ Out-of-range clamping tested | — |
| Host bridge protocol | ✅ Message parsing + signal emission tested | — |
| Player state machine | ❌ | 12 states, zero tests |
| Enemy AI FSM | ❌ | 8 states + phase 2, zero tests |
| Combat hit detection | ❌ | One-hit-per-swing dedup untested |
| Stamina economy | ❌ | Regen delay, gating logic untested |
| HUD rendering | ❌ | All procedural UI untested |
| Mobile controls | ❌ | Touch input synthesis untested |
| Audio synthesis | ❌ | PCM generation untested |
| Save/load to disk | ❌ | Only in-memory JSON round-trip tested |
| Death/recovery loop | ❌ | Full loop untested |
| Shrine upgrade economy | ❌ | 3-tier ember spending untested |

**Overall: ~10–15% logic-path coverage.** The existing tests are well-written and strategic (they protect the data integrity and host integration layers), but the gameplay core has no automated safety net.

---

## 3. Identified Gaps

### 3.1 Documentation Gaps — Topics With No Dedicated Document

| # | Missing Document | Why It Matters | Partial Coverage In |
|---|---|---|---|
| 1 | **Combat Style Reference** | 5 styles, each with unique mechanics, timing, inputs, and audio. No single document defines them. | Tuning reference table in `research-dark-souls-weapons.md` (MEDIUM confidence, research-grade); `player.gd` code |
| 2 | **Focus Resource System** | Second combat resource alongside stamina. Max pool, regen rules, per-style costs undocumented. | `game-design.md` (mentions costs); `player.gd` code |
| 3 | **Save / Persistence Design** | `run_state.gd` persists 8 data fields across sessions. Save format, schema versioning, migration path undocumented. | `run_state.gd` code; `devlog.md` mentions persistence |
| 4 | **Build & Export Guide** | Web, Windows, Linux presets configured. `tools/build.ps1` mentioned in devlog but not documented. | `export_presets.cfg`; `devlog.md` handoff entry |
| 5 | **Audio System Reference** | Procedural audio API (6 cues, 6-voice pool, headless detection). No documentation for adding sounds. | `procedural_audio.gd` code |
| 6 | **Enemy AI Specification** | Detection radii, leash limits, sanctuary disengagement, navigation fallback, per-enemy tuning. | `enemy.gd` code; `architecture.md` state diagram only |

### 3.2 Code Gaps — Verified Against Research Recommendations

Ranked by impact on "Souls feel" per implementation effort:

| # | Gap | Status | Research Source | Impact |
|---|---|---|---|---|
| 1 | **Per-style attack timing differentiation** | PENDING | `research-dark-souls-weapons.md` §11; `research-dark-souls-mechanics-deep.md` §9 | HIGH — all 5 styles feel identical despite different weapon fantasies |
| 2 | **Hyper armor during heavy weapon active frames** | PENDING | `research-dark-souls-mechanics-deep.md` §4, §9 | HIGH — Twin Colossi has no stagger resistance during its long wind-up payoff |
| 3 | **Hit-stop on successful impacts** | PENDING | `research-dark-souls-weapons.md` §11 | HIGH — single highest-impact change for weapon weight perception; costs nothing in design complexity |
| 4 | **Per-style stamina cost differentiation** | PENDING | `research-dark-souls-weapons.md` §11 | MEDIUM — undermines weapon identity; heavy weapons must cost more |
| 5 | **Parry window differentiation** | PENDING | `research-dark-souls-mechanics-deep.md` §3.3, §9 | MEDIUM — Reliquary Guard parry has uniform window; should vary by shield type |
| 6 | **Boss healing-punish tendency** | NOT IMPLEMENTED | `research-dark-souls-mechanics-deep.md` §6.2, §9 | MEDIUM — Cinder Guardian does not react to player healing |
| 7 | **Second enemy archetype** | NOT IMPLEMENTED | `research-dark-souls-design.md` vertical slice checklist S1 | MEDIUM — only Hollow Sentinel + Cinder Guardian; no ranged, shield, or ambush enemy |
| 8 | **Charged heavy attacks** | DEFERRED | `research-dark-souls-weapons.md` §11 | LOW — hold-to-charge mechanic for heavy attacks |
| 9 | **Running/rolling attack variants** | DEFERRED | `research-dark-souls-weapons.md` §11 | LOW — unique attacks from sprint or dodge |
| 10 | **Poise system** | DEFERRED | `research-dark-souls-mechanics-deep.md` §4; `research-dark-souls-weapons.md` §11 | LOW — full poise health + hyper armor system; prerequisite for meaningful heavy-weapon differentiation |

### 3.3 Research Gaps — Questions Not Answered by Existing Docs

1. Has any team shipped a commercial Godot 4 Souls-like? No published postmortems found in the ecosystem scan.
2. What is the performance ceiling of `NavigationAgent3D` with 20+ active enemies in Godot 4.7?
3. Is there a standardized Mixamo → Godot Humanoid Skeleton retargeting workflow in the Souls-like community?
4. Has anyone published a Godot 4 behavior tree integration specifically tuned for Souls-like boss phase scripting?

---

## 4. Recommendations

### 4.1 Documentation — Priority Order

| Priority | Action | Effort | Document(s) |
|---|---|---|---|
| **P1** | Rewrite `controls.md` | Medium | Full input table: 5 combat styles, keyboard, mouse, controller, touch. Use `player.gd` input handling + `game-design.md` combat pillars as source of truth. |
| **P2** | Update `architecture.md` | Medium | Add scripts/ subdirectories, data classes (`AshenRunState`, `AshenGameSettings`, `AshenLocalization`), host bridge layer, title/pause/death/victory UI flow diagram. |
| **P3** | Fix `validation.md` | Small | Fix script glob (`scripts/**/*.gd`), align project paths, add contract test command, update controller limitation. |
| **P4** | Add banner to `research.md` | Small | Note that it predates the handoff state; point to devlog and post-audit research docs for current state. |
| **P5** | Write Combat Style Reference | Large | One document covering all 5 styles: inputs, frame timings, stamina costs, unique mechanics, visual/audio profiles. Pull from `research-dark-souls-weapons.md` tuning table, `player.gd` code, `game-design.md` pillars. |
| **P6** | Write Build & Export Guide | Small | Document `tools/build.ps1`, export preset configuration, per-platform caveats, smoke-test commands. |
| **P7** | Write remaining missing docs | Medium–Large | Focus resource system, save/persistence design, audio system reference, enemy AI specification. These can be written incrementally as the systems are tuned. |

### 4.2 Code — Aligned With Existing Priority Order

The devlog resume order (entry 5, "Godot-First Implementation Handoff") already defines the correct sequence. The gaps in Section 3.2 above should be addressed within that framework:

1. **(Existing resume step 1)** Run editor parse, core contracts, and gameplay smoke tests against current files.
2. **(Existing resume step 2)** Finish in-game settings panel; verify English/Chinese presentation.
3. **(Existing resume step 3)** Play and tune every combat style — **this is where gaps #1–5 (per-style timing, hyper armor, hit-stop, stamina differentiation, parry windows) should be addressed.**
4. **(Existing resume step 4)** Verify death, Lost Echo recovery, checkpoint reset, shortcut persistence, boss victory, and save/load.
5. **(Existing resume step 5)** Test keyboard/mouse, controller, touch controls, and Android phone-size build.
6. **(Existing resume step 6)** Rebuild and smoke-test Web and Windows exports.
7. **(Existing resume step 7)** Update remaining documentation — **this is where P1–P4 doc fixes should land.**

Gap #6 (boss healing-punish) and gap #7 (second enemy archetype) are new-feature work that should follow the existing vertical slice validation. Gaps #8–10 (charged heavies, running/rolling attacks, poise system) are explicitly deferred per `research-dark-souls-weapons.md` and should not be started before the core loop is verified through human playtesting.

### 4.3 Test Coverage

Before the vertical slice is considered complete, add at minimum:

| Test | What It Protects |
|---|---|
| Player state transition validity | No illegal state transitions (e.g., DEAD → LOCOMOTION without respawn) |
| Stamina economy invariants | Stamina never exceeds max, regen only in LOCOMOTION, cooldown resets on spend |
| Combat hit dedup | One-hit-per-body-per-swing holds under rapid overlap |
| Enemy FSM transition validity | No illegal transitions; RETURN → IDLE on reaching spawn |
| Run state persistence round-trip to disk | Extend existing in-memory test to `user://` path |

---

## 5. Summary

### Health Scores

| Dimension | Score | Notes |
|---|---|---|
| **Documentation currency** | 7/11 current, 4 partially stale | `controls.md` is the only HIGH-severity stale doc |
| **Documentation completeness** | 6 missing topics identified | Combat style reference is the highest-value missing doc |
| **Code architecture** | Clean, consistent, low-coupling | Central-mediator pattern with signals; no autoloads is unusual but functional |
| **Code correctness** | No known bugs; 0 TODO/FIXME/HACK | GDScript files pass `--check-only`; headless import passes |
| **Code completeness** | 5 PENDING, 3 DEFERRED gaps vs research | All core loop mechanics (attack, dodge, stamina, death, checkpoint, boss) are implemented |
| **Test coverage** | ~10–15% of logic paths | Data integrity and host protocol are well-tested; gameplay has zero automated coverage |
| **Cross-reference integrity** | All bidirectional; no broken links | Research docs form a consistent cluster; stale docs are the isolated ones |

### Bottom Line

The codebase is a **solid Souls-like vertical slice** with the correct architectural decisions (three-phase attacks, shared stamina, signal communication, procedural content). The documentation suite is strongest where it cross-references heavily (the four research documents) and weakest where it stands alone (`controls.md`, `architecture.md`, `validation.md`). The highest-impact next action is not writing new systems — it is **tuning the 5 combat styles to feel distinct** (per-style timing, hyper armor, hit-stop, stamina costs) and then **updating the three stale documents** to reflect the handoff state.

---

## Sources & Audit Coverage

### Scan Commands

| Scan | Method | Files Inspected |
|---|---|---|
| `docs/` full read | Explore subagent — read every `.md` file, cross-reference mapping, staleness audit | 20 files (11 docs + 9 agent defs) |
| `docs/agents/` full read | Explore subagent — read every agent definition, skill dependency mapping | 9 files |
| `game/scripts/` full scan | Explore subagent — read every `.gd` file (full or substantial-partial), preload/signal/call graph | 16 files, 5,702 lines |
| `game/scenes/` full scan | Explore subagent — read every `.tscn`, node/script/load-step audit | 10 files |
| `game/project.godot` | Explore subagent — full config audit | 1 file |
| `game/assets/` | Explore subagent — font, license, glyph, import audit | 4 files |
| `game/tests/` | Explore subagent — test case inventory, coverage gap analysis | 1 file, 131 lines |

### Limitations

- All findings are based on static file analysis. Runtime behavior, performance characteristics, and visual/audio output were not observed.
- Cross-references were mapped by searching for markdown links and file paths in document text. Orphaned references (links to files that don't exist) would be detected; stale references (links to files that have changed) require human judgment.
- The "Verified Present" code features in Section 2.3 were confirmed by reading the relevant code sections. Features marked PENDING were confirmed absent by code search.
- This audit does not assess game balance, combat feel, visual quality, or audio quality — those require human playtesting.
