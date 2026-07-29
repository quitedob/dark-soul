# Project Structure

This repository contains several cooperating projects. Directory ownership should remain explicit so the Godot game, host application, platform plugin, documentation, and build tooling can evolve independently.

## Repository Layout

```text
newproject/
├── app/                         # Flutter/OpenHarmony host application
├── docs/                        # Product, design, architecture, and validation documents
├── game/                        # Standalone Godot project
│   ├── project.godot            # Godot project root and engine configuration
│   ├── main.tscn                # Godot entry scene
│   ├── export_presets.cfg       # Godot export configuration
│   ├── scenes/                  # Reusable scene definitions grouped by role
│   ├── scripts/                 # Gameplay and runtime implementation
│   └── tests/                   # Godot automated tests
├── packages/                    # Reusable Flutter/platform integration packages
└── tools/                       # Repository-level build and validation automation
```

## Directory Responsibilities

### `game/`

`game/` is the only Godot project root. All `res://` paths are resolved relative to this directory. Godot commands should therefore use:

```text
--path D:/godot/newproject/game
```

Its current internal structure is:

```text
game/
├── scenes/
│   ├── actors/                  # Player and enemy scene entry points
│   ├── audio/                   # Audio system scenes
│   ├── components/              # Reusable gameplay components
│   ├── interactables/           # Shrine, shortcut, and recovery objects
│   ├── ui/                      # HUD scenes
│   └── world/                   # Playable world scenes
├── scripts/
│   ├── app/                     # Godot-to-host communication bridge
│   ├── components/              # Reusable combat/projectile behavior
│   ├── core/                    # Save state, settings, and localization
│   ├── ui/                      # Auxiliary UI behavior
│   └── *.gd                     # Existing gameplay composition and actor scripts
└── tests/
    └── smoke/                   # Headless contract and smoke checks
```

The scene folders communicate runtime meaning. The existing top-level gameplay scripts remain valid while other agents are actively changing the game. A future script migration should only happen as one coordinated change that moves files, preserves `.uid` files, updates every `res://` reference, and passes Godot import and smoke validation.

### `app/`

`app/` is the Flutter shell that hosts the exported game and owns application-level concerns such as lifecycle, settings, localization, persistence coordination, and the OpenHarmony application package. It must not contain Godot gameplay logic.

Generated Flutter output such as `app/build/` and `app/.dart_tool/` is not source code and remains ignored.

### `packages/`

`packages/` contains reusable Flutter or platform plugins. `packages/ashen_hollow_web_host/` owns the OpenHarmony Web platform-view integration used to host the Godot web export. Package code should expose a narrow integration API and should not depend on game-specific scene internals.

### `docs/`

`docs/` is the source of truth for project intent and engineering decisions:

- `game-design.md`: gameplay goals and vertical-slice scope.
- `architecture.md`: runtime systems and data flow.
- `project-structure.md`: repository boundaries and directory ownership.
- `controls.md`: player-facing input behavior.
- `validation.md`: automated commands and manual verification checklist.
- `devlog.md`: chronological implementation record.
- `research.md`: supporting design and engine research.
- `agents/`: local specialist-agent guidance.

Documentation must describe verified behavior. Planned work should be labeled as planned rather than recorded as complete.

### `tools/`

`tools/` contains repository-wide automation. Scripts here may coordinate Godot, Flutter, plugin, export, and packaging steps, but should delegate product behavior to the owning project.

## Dependency Direction

```text
app/ ───────────────▶ packages/ashen_hollow_web_host/
 │
 └── hosts/export ──▶ game/

tools/ ─────────────▶ game/ + app/ + packages/

docs/ ──────────────▶ describes all projects; runtime projects do not depend on docs/
```

Communication between `app/` and `game/` should pass through the defined host bridge and serialized contracts. The Flutter layer must not reach directly into Godot nodes, and Godot gameplay code must not depend on Flutter implementation classes.

## Naming Rules

- Use lowercase `snake_case` for Godot scenes and scripts.
- Name scenes after the gameplay object they instantiate, such as `ember_shrine.tscn`.
- Keep reusable behavior under a role-specific directory such as `components/`, `core/`, or `ui/`.
- Keep generated files out of source directories and covered by `.gitignore`.
- Preserve Godot `.uid` files when moving their corresponding scripts.
- Treat path changes as integration changes: update all preload/resource references and validate the complete project.

## Safe Structure Changes

Before reorganizing files:

1. Check `git status` for concurrent or uncommitted work.
2. Identify every `res://` reference to the files being moved.
3. Move scripts together with their `.uid` files.
4. Update scenes, scripts, tests, documentation, and build commands in one change.
5. Run Godot editor import, script parsing, contract tests, and gameplay smoke tests.
6. Record only the verified result in `devlog.md`.

Do not reorganize runtime files while another agent is editing them unless that work is explicitly coordinated.
