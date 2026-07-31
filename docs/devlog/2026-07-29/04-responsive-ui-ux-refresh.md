# 2026-07-29 — Responsive UI/UX Refresh

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
