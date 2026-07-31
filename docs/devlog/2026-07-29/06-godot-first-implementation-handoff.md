# 2026-07-29 — Godot-First Implementation Handoff

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
