# Ashen Hollow Development Log

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
