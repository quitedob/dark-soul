# 2026-07-29 — Repository Structure Documented

### Scope

- Added [project-structure.md](project-structure.md) as the repository-level directory and ownership guide.
- Defined `game/` as the standalone Godot project, `app/` as the Flutter/OpenHarmony host, `packages/` as reusable platform integration, `tools/` as cross-project automation, and `docs/` as the documentation source of truth.
- Documented that Godot `res://` paths resolve from `game/` and that engine commands should use `D:/godot/newproject/game` as the project path.
- Recorded naming, dependency-direction, generated-file, `.uid`, and safe file-migration rules.

### Coordination

- This update changes documentation only.
- Runtime files were intentionally left unchanged because other agents are actively modifying the game structure and implementation.
- Any future script-directory migration must be coordinated as one integration change and verified through Godot import and smoke tests.
