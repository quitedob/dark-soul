# Ashen Hollow Development Log

## 2026-07-29 — Research Documents Updated to Post-Fix State

### Scope

Updated both Dark Souls research documents to accurately reflect the post-fix code state after all 9 audit fixes were applied in commit `7f30d4f`. The documents were originally written before the fixes and described features as missing that are now implemented.

### Changes to `research-dark-souls-design.md`

- Added metadata header (last updated, revision history, status, cross-reference to weapons doc).
- Added **Post-Audit Implementation Summary** table mapping all 9 resolved gaps to their fixes.
- Updated 6 per-section "Status for Ashen Hollow" blocks (Sections 1–5, 7–9) from "not implemented" / "defect" to resolved descriptions with code references.
- Updated **Vertical Slice Checklist**: M1, M2, S2, S3, S4, S5, S6 now `✅ Implemented`; M5 now `✅ Verified`.
- Replaced the "Highest-Priority Gaps" list (4 of 5 resolved) with **Current Remaining Gaps (Post-Fix)** — 5 items cross-referenced to the weapons research.
- Updated **documentation reliability table**: `game-design.md` → RELIABLE, `devlog.md` → RELIABLE, others refined.
- Resolved the **healing design conflict** (Option A/B fork removed; Ember Rite documented as intentional, following DS3 pattern).
- Added **"Related Research"** cross-reference to weapons doc; moved unresolved questions to an appendix.

### Changes to `research-dark-souls-weapons.md`

- Updated metadata header with status tracking and cross-reference to design doc.
- Added **"Changes Since Initial Research"** table: 5 audit fixes relevant to weapons, all marked **Done**.
- Updated **Documentation Reviewed** table — all 8 rows refreshed to reflect post-fix state.
- Added **`[DONE]` / `[PENDING]` / `[DEFERRED]`** status markers to all 11 recommendations. Result: 1 DONE (input buffering), 5 PENDING (per-style tuning, hit-stop, hyper armor, audio, timing), 5 DEFERRED (charged heavies, running/rolling attacks, boss weapon, poise, spear style).
- Renamed section to **"Recommendations — Status Tracked"**.
- Fixed **contradictions**: healing conflict marked RESOLVED; controls.md staleness replaced with cross-reference.
- Added `(uniform timing currently used)` flags to Ashen Hollow mapping.
- Added prominent ⚠️ **playtesting warning** above the Tuning Reference table (frame data is MEDIUM confidence — tune, don't copy).
- **Reordered sections**: Sources & Search Coverage moved after Conclusion.
- Consolidated overlapping combat pillar descriptions to cross-reference design doc.

### Cross-Document Status

Both documents now:
- Accurately reflect the post-fix code state (verified against `player.gd`, `enemy.gd`, `game_world.gd`).
- Cross-reference each other via metadata headers and inline links.
- Provide clear status tracking: readers can see at a glance which recommendations are done, pending, or deferred.
- Preserve all original evidence classifications, "What NOT to Copy" guidance, and analytical structure.

### Coordination

- Documentation-only change. No runtime files modified.
- The three stale documents flagged by both research audits (`architecture.md`, `controls.md`, `validation.md`) remain out of scope for this update.

## 2026-07-29 — Research Audit Fixes Applied

### Scope

Applied 9 fixes identified by the Dark Souls design research audit ([research-dark-souls-design.md](research-dark-souls-design.md)) across `game/scripts/enemy.gd`, `game/scripts/player.gd`, `game/scripts/game_world.gd`, `game/scripts/core/run_state.gd`, and `docs/game-design.md`.

### Code Bug Fixes

1. **Telegraph audio during windup** (`enemy.gd:375–383`): Moved enemy swing audio from `State.ACTIVE` to `State.WINDUP` match arm so the player hears the warning cue when the telegraph disc appears, not when the hitbox opens.

2. **Stamina regeneration delay frozen during attacks** (`player.gd:626–638`): Gated `stamina_delay` decrement and stamina/focus regeneration behind `state == State.LOCOMOTION`. Previously the delay counted down during the entire attack animation, making heavy attacks effectively consume no delay.

3. **Lock-on target cycling** (`player.gd:651–702`): Replaced toggle-only `_toggle_lock_on()` with cycling logic. First press acquires the best camera-facing target; subsequent presses cycle through all valid candidates; press releases when only one target remains. Added `_collect_lock_candidates()` and `_cycle_lock_target()` helpers.

4. **Input buffering** (`player.gd:92–93, 292–323, 327–328`): Added a 150 ms input buffer window so combat actions (dodge, parry, light/heavy attack, special attack, cast) pressed during attack recovery are stored and executed on return to LOCOMOTION. Last-input-wins; buffer decays in `_update_state()`. Added `_can_buffer_in_current_state()`, `_try_buffer_action()`, and `_execute_buffered_action()` helpers.

### Boss Feature Work

5. **Boss distance-dependent attack selection** (`enemy.gd:345–398`): Restructured `_select_attack_profile()` for the Cinder Guardian into three distance brackets: close (< 2.0 m) fast swipe, mid (2.0–3.5 m) alternating quick/heavy, long (> 3.5 m) heavy lunge with large gap-close. Sentinel enemies remain unchanged.

6. **Boss phase transition at 50% HP** (`enemy.gd:47–49, 158–160, 367–370, 373–444`): Added a second phase for the Cinder Guardian triggering at ≤ 50% health. Phase 2 features faster windups, shorter recoveries, and higher damage across all distance brackets. Transition includes weapon emission glow (fiery orange), a distinct audio cue, and a brief 0.6 s stagger animation. Phase state resets on enemy reset or shrine rest. Added `_current_phase()`, `_trigger_phase_transition()`, and phase-tuned parameters in each attack bracket helper.

### System Design Changes

7. **Enemy reset on player death** (`game_world.gd:253–255`): Added `enemy.reset_enemy()` loop to `_on_player_died()` before the death overlay. All regular enemies now reset to full HP and spawn positions on player death, matching Soulslike convention.

8. **Shrine vitality upgrades** (`player.gd:56–59, 262–295`, `game_world.gd:194, 204–223, 368–369, 387–388`, `run_state.gd:13, 20, 34, 97`): Added a 3-tier ember spending system at the Ember Shrine. Each tier costs [50, 120, 250] embers and grants +10 max HP. Upgrades persist in `run_state.upgrade_tier` across deaths and application sessions. On rest, `_try_shrine_upgrade()` attempts to spend embers and displays tier progress via HUD messages.

### Documentation

9. **Updated game-design.md**: Documented Ember Rite as a limited in-combat healing exception (30 Focus cost, 0.92 s cast), added Vitality Forging upgrade mechanic, updated Cinder Guardian description with distance-dependent attacks and phase transition, and noted enemy reset on death.

### Validation

- All GDScript files pass `--check-only` with Godot 4.7.1.
- Headless editor import completes without errors.
- Smoke test prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly.
- Manual playtesting is still required for combat feel, boss balance, input buffer timing, and upgrade economy.

## 2026-07-29 — Repository Structure Documented

### Scope

- Added [project-structure.md](project-structure.md) as the repository-level directory and ownership guide.
- Defined `game/` as the standalone Godot project, `app/` as the Flutter/OpenHarmony host, `packages/` as reusable platform integration, `tools/` as cross-project automation, and `docs/` as the documentation source of truth.
- Documented that Godot `res://` paths resolve from `game/` and that engine commands should use `D:/godot/newproject/game` as the project path.
- Recorded naming, dependency-direction, generated-file, `.uid`, and safe file-migration rules.

### Coordination

- This update changes documentation only.
- Runtime files were intentionally left unchanged because other agents are actively modifying the game structure and implementation.
- Any future script-directory migration must be coordinated as one integration change and verified through Godot import and smoke tests.

## 2026-07-29 — Dark Souls Design Research

### Scope

- Conducted a structured investigation into Dark Souls 1/3 core design principles to evaluate Ashen Hollow's game design.
- Executed two Perplexity deep_research queries covering: combat speed, stamina economy, lock-on/camera, enemy teaching, death/soul-recovery loop, world/shortcuts, boss design, growth/currency, healing, accessibility, and vertical-slice acceptance criteria.
- Cross-referenced every claim against current game code, scenes, configuration, and tests via three local read-only sub-agents.

### Key Findings

- Ashen Hollow's core combat skeleton (attack phases, shared stamina, iframe dodge, death-recovery, checkpoint, shortcut) is **directionally correct** for a Soulslike vertical slice.
- The **highest-priority gap** is that embers have no spending purpose, removing the motivational anchor from the entire death-recovery loop.
- Boss lacks behavioral depth — two alternating attacks are trivially solvable; a phase transition and distance-dependent attack selection are recommended.
- All six existing design documents are stale or contradicted by current code — project path, controls, healing, persistence, and architecture claims all need updating.
- Perplexity deep_research could not return verifiable source URLs; conclusions are therefore based on observable game mechanics and analysis, not developer-attributed intent.
- Detailed findings, evidence classification, a vertical-slice checklist, and a "what not to copy" guide are in [research-dark-souls-design.md](research-dark-souls-design.md).

### Source Limitations

- Two deep_research queries returned framework-level answers without specific URLs or quotable passages.
- Report uses a three-tier evidence system: Observable Rule / Developer Intent / Analysis. No conclusion is attributed to a Perplexity-returned source without independent verification.
- Six common player-consensus claims about Dark Souls were flagged as unverified or factually incorrect against observable game mechanics.
- Unresolved questions (requiring primary-source retrieval from GDC Vault, CEDEC archives, or Japanese developer interviews) are listed in the report.

## 2026-07-29 — Responsive UI/UX Refresh

### Guidance and Scope

- Reviewed the installed GodotPrompter configuration and delegated a full read of `.claude/skills` and `docs/agents`.
- The local skills cover GodotPrompter package authoring and releases rather than game UI implementation, so they were inspected but not invoked.
- Applied the checked-in Godot UI guidance: `Control`-based HUD composition, container-first responsive layout, centralized theme styling, focused menu navigation, and restrained `Tween` feedback.
- Kept the project self-contained with no external fonts, textures, icons, or other asset dependencies.

### HUD and Menus

- Rebuilt the HUD around `MarginContainer`, `VBoxContainer`, `HBoxContainer`, `CenterContainer`, and `GridContainer` instead of viewport-specific positioning.
- Added a responsive safe-area layout with grouped player vitals, ember currency, boss status, and interaction lanes.
- Added compact non-color labels for health and stamina, a dedicated interaction keycap, clearer lock-on marker, and improved boss hierarchy.
- Centralized shared label, button, separator, panel, hover, pressed, and keyboard-focus styling in one runtime `Theme`.
- Added restrained prompt, message, boss, ember-count, death, and victory transitions.
- Reworked pause and controls overlays into responsive centered panels with immediate keyboard focus and readable action/input rows.

### UX and Reliability

- Preserved the HUD's existing gameplay-facing API so combat and progression systems remain decoupled from presentation details.
- Fixed the death-overlay lifecycle so it clears when the player respawns.
- Expanded the smoke path to verify prompt, boss bar, death overlay, cleanup, stat, ember, damage, and message transitions.

### Validation

- Every GDScript file passes `--check-only` with Godot 4.7.1.
- Headless editor import completes without script or resource errors.
- The bounded runtime completes without runtime errors.
- The expanded smoke path prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly.
- Manual graphical review is still required for hierarchy, clipping, focus navigation, lock marker placement, and motion comfort at multiple window sizes.

## 2026-07-29 — Vertical Slice Created

### Project Goal

Started **Ashen Hollow**, an original third-person Soulslike-inspired vertical slice built with Godot 4.7.1. The prototype focuses on deliberate melee combat, stamina management, readable enemies, death recovery, checkpoints, shortcuts, and a guardian encounter.

The project deliberately avoids copying protected characters, maps, names, lore, art, animation, music, or other assets from existing games.

### Research

- Researched common Soulslike design methods with Perplexity.
- Reviewed combat commitment, attack telegraphing, stamina pressure, lock-on camera behavior, enemy state machines, checkpoints, resource recovery, interconnected routes, accessibility, and feedback.
- Cross-referenced engine decisions with official Godot documentation.
- Verified Godot command-line behavior using the installed 4.7.1 executable.
- Searched local Claude skill and plugin directories for an installed Godot development skill. None was available during implementation, so the project followed official Godot documentation and direct engine testing.

Detailed findings are available in [research.md](research.md).

### Foundation

- Created `project.godot` and `main.tscn`.
- Configured a 1280×720 desktop viewport and the OpenGL compatibility renderer.
- Registered keyboard and mouse actions at runtime.
- Kept the project self-contained with no external asset dependencies.

### Procedural World

- Built a moonlit ruined sanctuary from primitive meshes and static collision bodies.
- Added atmospheric fog, directional moonlight, shrine lighting, emissive landmarks, pillars, broken walls, moss-covered platforms, and a guardian arena.
- Added a side-route lever and moving shortcut gate.
- Created all materials and environmental presentation in code.

### Player Controller

Implemented:

- Camera-relative `CharacterBody3D` movement.
- Mouse-controlled third-person camera using `SpringArm3D`.
- Sprinting and delayed stamina regeneration.
- Light and heavy attacks with separate wind-up, active, and recovery timings.
- One-hit-per-swing combat areas.
- Directional dodge with a limited invulnerability interval.
- Damage, stagger, knockback, death, and respawn states.
- Target lock-on with distance and camera-facing selection.
- Contextual interaction with checkpoints and levers.
- Carried ember rewards, loss on death, and recovery.
- Procedural body, cloak, visor, and weapon poses.

### Enemy Combat

Implemented a finite state machine with:

- Idle and detection behavior.
- Target pursuit using `NavigationAgent3D` with direct steering fallback.
- Attack wind-up, active, and recovery states.
- Visible attack telegraphs and procedural weapon poses.
- Damage, poise, stagger, knockback, death, rewards, and checkpoint reset.
- Regular Hollow Sentinel tuning.
- Cinder Guardian tuning with increased health, reach, rewards, and alternating quick and delayed attacks.

### Progression Loop

- Added the Ember Shrine checkpoint.
- Resting restores health and stamina and revives enemies.
- Death respawns the player at the active shrine.
- Carried embers become a Lost Echo at the death location.
- Touching the Lost Echo restores the dropped embers.
- Opening the shortcut reduces repeated traversal.
- Defeating the Cinder Guardian displays the victory state.

### HUD and Feedback

- Added health and stamina bars.
- Added ember counter and contextual interaction prompts.
- Added lock-on target marker.
- Added dedicated guardian health bar.
- Added temporary progression and combat messages.
- Added death, victory, pause, and help overlays.
- Added keyboard alternatives for mouse combat actions.
- Generated attack, impact, dodge, checkpoint, recovery, death, and victory sounds procedurally.

### Integration Fixes

During the first integration pass:

- Corrected setup argument order for the checkpoint, shortcut, and Lost Echo scripts.
- Widened world callbacks to support interaction context supplied by reusable components.
- Removed restrictive base-class annotations from dynamically scripted instances.
- Added explicit `Vector3` typing to lock-on calculations where GDScript could not infer dynamic return types.
- Corrected the initial camera orientation so it begins behind the player.
- Updated the help overlay to match the actual control bindings.
- Delayed smoke-test shutdown until generated audio playback completed, removing false leak warnings.

### Validation

Validated with:

```text
D:\godot\Godot_v4.7.1-stable_win64_console.exe
```

Results:

- Engine version: `4.7.1.stable.official.a13da4feb`
- Every GDScript file passes `--check-only`.
- Headless editor import completes without script or resource errors.
- A bounded 180-iteration runtime completes without errors.
- The dedicated smoke path prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly.
- The playable build was launched with `D:\godot\Godot_v4.7.1-stable_win64.exe`.

Full commands and the manual test checklist are recorded in [validation.md](validation.md).

## Current Limitations

- Primitive models and generated sounds are prototype assets, not production-quality content.
- Runtime world generation does not provide a baked navigation mesh; enemies use direct steering fallback when navigation is unavailable.
- Progress is not saved between application sessions.
- Input currently targets keyboard and mouse.
- Combat balance, camera comfort, telegraph readability, and accessibility still require human playtesting.
- The prototype uses procedural poses rather than authored animation clips and root motion.

## Suggested Next Milestone

1. Conduct a complete manual playthrough and record camera or combat problems.
2. Add controller support and a control-remapping screen.
3. Replace procedural poses with original authored animations while retaining authoritative gameplay timing.
4. Convert the generated ruin into an authored level with a baked navigation mesh.
5. Add persistent settings and checkpoint progression under `user://`.
6. Introduce one additional enemy archetype only after the existing guardian encounter is balanced.

## 2026-07-29 — Godot-First Implementation Handoff

Implementation was paused at the user's request. Flutter and OpenHarmony work is explicitly deferred; the Godot game is the only active product target when work resumes.

### Completed Since the Initial Prototype

- Reorganized the playable project under `game/`, with reusable scenes for the world, player, enemies, HUD, checkpoint, shortcut, Lost Echo, audio, and spell projectile.
- Added a title screen, pause flow, help overlay, English/Simplified Chinese language selection, and an embedded subset of Noto Sans CJK for reliable Chinese glyph rendering.
- Added keyboard, controller, and touch/mobile input paths.
- Added focus as a combat resource and five selectable combat styles:
  - Reliquary Guard: timed parry, shield guard, and thrust attacks.
  - Twin Colossi: paired great-blade jump attack.
  - Crescent Pair: paired curved-blade two-hit jump attack.
  - Veilcraft: focus-powered projectile magic.
  - Ember Rite: focus-powered healing and damage prayer.
- Added persistent run/settings data for locale, focus, combat style, Lost Echo state, shortcut state, guardian state, and play time.
- Improved regular-enemy behavior with sanctuary disengagement, return-to-spawn behavior, and leash limits.
- Moved the nearest enemy away from the shrine so a new run begins safely.
- Opened the guardian threshold into a traversable central doorway and added lightweight ember braziers to guide the route.
- Extended the rear play space to improve the initial third-person camera position.
- Corrected desktop Web runtime detection so touch controls and mobile-quality defaults are not forced on desktop browsers.
- Added Web, Windows, and Linux export presets.

### Verification Reached

- Godot 4.7.1 editor parsing and headless import passed before the final small UI/world edits.
- Core contract tests printed `ASHEN_CORE_CONTRACTS_OK`.
- Gameplay smoke tests printed `ASHEN_HOLLOW_SMOKE_OK`.
- Web export completed successfully.
- Windows export completed successfully, and the exported console build passed its headless smoke test.
- The title screen and initial shrine scene were inspected in a desktop browser. Desktop touch controls were hidden correctly, the player started at full health, and nearby enemies did not engage inside the sanctuary.

### Work in Progress When Paused

- The latest HUD alignment, route-brazier, projectile-collision, and weapon-pose changes still need a complete parser/test/export pass.
- The pause menu still needs the planned settings panel for camera sensitivity, UI scale, reduced motion, and high contrast.
- Chinese text is configured with the embedded CJK font, but a final fresh-browser visual pass is still required after re-export.
- All five combat styles are implemented but still need hands-on balance tuning, controller verification, and phone playtesting.
- The boss encounter, death/recovery loop, checkpoint reset, shortcut, victory flow, and full level traversal need a complete manual playthrough.
- `tools/build.ps1` should be changed to build the Godot game by default and make Flutter/OpenHarmony an optional, explicitly requested step.
- Project documentation outside this log still contains some initial-prototype limitations that no longer reflect the current build and should be reconciled after final gameplay behavior is settled.

### Resume Order

1. Run editor parse, core contracts, and gameplay smoke tests against the current files.
2. Finish the in-game settings panel and verify English/Chinese presentation.
3. Play and tune every combat style against regular enemies and the guardian.
4. Verify death, Lost Echo recovery, checkpoint reset, shortcut persistence, boss victory, and save/load.
5. Test keyboard/mouse, controller, touch controls, and a real Android phone-size build.
6. Rebuild and smoke-test Web and Windows exports.
7. Update the remaining documentation to match the verified game.
