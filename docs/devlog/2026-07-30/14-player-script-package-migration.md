# 2026-07-30 — Player Script Package Migration

### Scope

Moved the monolith player controller from `game/scripts/player.gd` into a dedicated package directory `game/scripts/player/player.gd`. This is a path/layout migration only — combat/movement helpers were not extracted further in this step.

### Changes

- `git mv` preserved `player.gd.uid`
- Updated `scenes/actors/player.tscn` and direct test preloads to `res://scripts/player/player.gd`
- Documented `scripts/player/` in `docs/project-structure.md` and `docs/architecture.md`
- Synchronized path references across `docs/` and `docs-zh/` (tasks, research, audit, mcp guide)

### Validation

- Godot check-only / combat contract / player FSM / smoke after reference updates
- Doc path sweep: no remaining live `res://scripts/player.gd` / `scripts/player.gd` inventory entries

---
