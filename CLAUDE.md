# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

烬渊 / Ember Abyss — a soulslike ARPG in Godot 4.7.1, pure GDScript, `gl_compatibility` renderer. The Godot project root is `game/` (not the repo root); all `res://` paths are relative to `game/`. The main scene `game/main.tscn` composes the whole campaign through `game/scripts/game_world.gd`. (Note: `game/project.godot` still carries the pre-rename name `Ashen Hollow`; the canonical name is 烬渊/Ember Abyss.)

## Commands

Godot console binary (Windows): `E:/godot/Godot_v4.7.1-stable_win64_console.exe` (Linux/CI sets `GODOT_BIN`). Run Godot with `--path game` from the repo root.

- Full test suite (editor script-parse check + GUT unit + integration):
  - `./tools/ci.sh` (Linux/CI) or `.\tools\ci.ps1` (Windows). Success prints `ASHEN_HOLLOW_CI_OK`.
- GUT only:
  - `godot --headless --path game -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
- Run one smoke contract test (`SceneTree` tests under `game/tests/smoke/`):
  - `godot --headless --path game --script tests/smoke/<name>.gd`
- Script-parse / import validation (catches most load-time type errors):
  - `godot --headless --path game --editor --quit`

## Architecture

The game is **data-driven, not scene-driven**: there are no per-level scenes. Levels, enemies, bosses, weapons, and spells are plain data dicts that code composes at runtime.

- **Content data** (`game/scripts/data/`): `campaign_content.gd` defines the 29-level/chapter graph; `chapter_N_content.gd` hold enemy/elite/boss dicts; `player_combat_data.gd` is the spell registry (`SPELL_CONFIG`); `combat_style_data.gd` / `hand_equipment.gd` define the 5 loadouts. Module families are in `game/scripts/levels/procedural_level_modules.gd`, wired at runtime by `game/scripts/world/campaign_module_runtime.gd`.
- **World composition** (`game/scripts/game_world.gd`, ~2500 lines): the hub that owns the player, spawns enemies/bosses, drives level progression, save/load, the ending/epilogue flow, and delegates to the HUD.
- **Player** (`game/scripts/player/player.gd`): 18-state FSM (`enum State`), the 5-value `CombatStyle` enum, and the focus/stamina/talent/meridian systems (`talent_data.gd`, `meridian_data.gd`).
- **Enemies/bosses** (`game/scripts/enemy.gd`): a data-driven FSM. Bosses are spawned by `game_world._spawn_content_enemy`; a content dict's `phases` (threshold → attacks) drives phase behavior.
  - **Boss-flow contract**: to add per-boss behavior, add `"flow": {"script": "res://scripts/boss/flow/<x>_flow.gd", "config": {...}}` to the boss content dict. `boss_flow_controller.gd` hosts the flow script and forwards `phase_changed` and `story_threshold_reached` — per-boss flow does **not** require editing `enemy.gd`. Existing flows: `nine_tails_flow.gd`, `xuanxiao_escape_flow.gd`, `zhu_yin_zero_g_flow.gd`.
- **Save** (`game/scripts/core/run_state.gd`, `AshenRunState` schema v2): single run + settings, persisted under `SAVE_PATH` in `game_world.gd`. Body-class override lives in `progression_values["body_class_override"]`.
- **Models & animation**: real GLBs resolve through `core/real_model_resolver.gd` (a `REGISTRY` keyed by namespace, e.g. `player/weapon/sword`, `enemy/body/by_id/<id>`). Most GLBs are static — only mannyquin/minnyquinn test skeletons carry clips. `combat/player_animation_bridge.gd` implements "real clip first, procedural pose fallback". The player body/weapon/shield/trail hang under a single `BodyYaw` orientation node (`core/player_visuals.gd`) whose rest is the `DEF-hand.R/L` model-space rest — keep weapon-pivot and orientation logic consistent with that.
- **Ending flow**: `FateChoiceOverlay` (kindle/keeper/void/forge) → `story/ending_resolver.gd:commit` writes `ending_state` → on exiting 5-5, `game_world._show_ending_epilogue` → `story/dialogue_runner.gd:ending_epilogue` → `hud.gd:show_epilogue`.

## Tests

Three tiers:

- **GUT unit** (`game/tests/unit/`) and **integration** (`game/tests/integration/`) — run via `gut_cmdln.gd`.
- **Smoke contract tests** (`game/tests/smoke/`, ~53 files): `extends SceneTree`, entry is `_initialize()` + `call_deferred("_run_all")` (NOT `_init()` — the tree isn't ready in `_init`). Each prints a unique `ASHEN_*_OK` marker on success and is run individually with `--script`.

## Godot 4.7 GDScript gotchas (hit repeatedly here)

- `var x := <untyped call/field>` fails with "Cannot infer the type" — annotate the return type or drop `:=`.
- Some errors only surface when a script is actually `load()`ed (e.g. boss flow scripts), so `--editor --quit` won't catch them; run the script directly or the playthrough smoke contract.
- Code-created nodes get a `@Name@N` suffix — match children with `find_children("*", "ClassName", true, false)` / `is Class`, not fixed `get_node_or_null("X")`.
- GDScript lambdas capture primitives by value — use a Dictionary for accumulated callback state.
- Removed in 4.7: e.g. `track_get_update_mode`; verify a small-version API exists before assuming.
- `get_bone_global_rest(idx).origin` returns **model-space** (not world); world = `skeleton.to_global(rest.origin)`.

## Documentation conventions

`docs/` is the single authority. Deliverables go only under `docs/devlog/<date>/` with semantic-English filenames; do **not** create a root-level giant `devlog.md`/`CHANGELOG.md`, and do not use `e-1`/`a01`-style scattered task filenames. Docs must describe *verified* behavior (mark planned items "planned"). See `docs/project-structure.md:109-115` and `docs/master-index.md`.
