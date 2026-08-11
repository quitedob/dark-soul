---
name: ashen-hollow-dev
description: Use when developing the Ashen Hollow (烬渊) Godot 4 project in game/ — implementing features, quests, bosses, content, model assets, or syncing docs. Enforces the repo's subagent orchestration protocol (Explore recon → general-purpose parallel implementation with file ownership → main-thread independent verification), the headless verification baseline, and the subagent prompt templates distilled from devlog 10/11/12.
---

# Ashen Hollow Dev Workflow

> **Related skills:** **authoring-godot-prompter-skills** for writing/editing skill and agent files in this repo · **releasing-godot-prompter** for cutting GodotPrompter releases. External reusable Godot skills live in `example/godot-ai-builder-main/skills/*/SKILL.md` (godot-gdscript / godot-effects / godot-physics / godot-enemies / godot-ui) + `example/godot-ai-builder-main/knowledge/game-patterns.md` — they are NOT registered here; have subagents **read those files directly** and apply their patterns (typed var / match dispatch / SceneTreeTimer one-shot / Control layout).

## 1. Project map

- **Godot project root:** `game/` (Godot 4.7.1). Repo root is `E:/godot/darksoul`. All `--path` args use `e:/godot/darksoul/game`.
- **Hot shared files (serial-only, main thread writes them):** `game/scripts/game_world.gd`, `game/scripts/player/player.gd`. Own these to keep a single mental model; never let parallel agents touch them simultaneously.
- **Core systems:** `game/scripts/core/` — `content_registry.gd`, `content_validator.gd`, `level_builder.gd`, `real_model_resolver.gd`, `character_meshes.gd`, `weapon_meshes.gd`, `procedural_utils.gd`, `game_settings.gd`.
- **Factories:** `game/scripts/enemy/enemy_factory.gd`, per-chapter factories; `game/scripts/enemy/enemy.gd` (palette gate).
- **Tests:** `game/tests/smoke/*_contract_test.gd` (SceneTree `--script`, print `*_CONTRACTS_OK`) · `game/tests/unit/` + `game/tests/integration/` (GUT via `.gutconfig.json`).
- **Docs:** `docs/` — devlog `docs/devlog/YYYY-MM-DD/`, tasks `docs/tasks-master.md`, `docs/planning/soulslike-gap-analysis.md` (authoritative gap doc), `docs/research/`, `docs/model-prompts/`, `docs/story/`, `docs/bestiary/`, `docs/chapters/`, `docs/validation.md` (full command reference).
- **External reference:** `example/godot-ai-builder-main/` (Godot AI builder plugin, 14 skills, MCP tooling) and `example/Cats-Godot4-Modular-Souls-like-Template-main/assets/` (CC0 GLB assets).

## 2. Orchestration protocol — recon → foundation → parallel → verify

Apply for any non-trivial change (task series, quests, optional bosses, content waves, model assets, docs sync).

### Phase 0 — Recon (Explore, read-only agents)
Sweep the relevant `docs/` + `game/` + `example/` directories in parallel. Each agent returns **`path:line` evidence + a reliability tag** (`RELIABLE` / `STALE` / `CONTRADICTED`) and identifies: what to change, the closest existing pattern to copy, and the traps (`progression_values` only non-negative int, `choice_flags` only bool/non-empty string, empty `story_flag` soft-lock, `_chapter_elite_for` first-match). **The output is a map, not truth** — implementers must still read the original file to verify line numbers and schema.

### Phase 1 — Foundation (main thread)
Write the base infrastructure and all hot/shared files yourself: registries, resolvers, `game_world.gd`, `player.gd`, test scaffolding. Contended files stay on one thread.

### Phase 2 — Parallel implementation (general-purpose agents)
Split the remaining work **by file domain** (spell config / module runtime / moveset factory / world interaction / story / quests / content / docs). Each agent gets exclusive file ownership (below). Each agent must run its own `--check-only` + relevant contract test and fix to green **before returning**.

### Phase 3 — Independent verification (main thread)
**Never trust agent self-reports.** Re-run the full baseline yourself (parse + smoke + contracts + GUT) and grep-diff the produced content. Independent re-run is what caught the resolver `owner inconsistent` warnings and the `SUMMON_CONFIG` missing `spell_type`.

## 3. Parallel discipline (the #1 rule)

- **One file, one agent at a time.** Each prompt lists owned files explicitly and forbids touching anything else ("你只准改这些文件；其余一律不许动"). Hot files (`player.gd`, `game_world.gd`) queue serial.
- **Declare a baseline before agents start:** run `git status` to confirm no uncommitted in-flight edits, and have each agent report `git status --porcelain` when done so you can verify change provenance.
- **Forbid external pulls:** agents must NOT download/clone external content (a past agent cloned a 266 MB Terraria mod into `example/tsorcRevamp/`). Check untracked files during review; flag out-of-ownership artifacts for cleanup.
- **Shared-file coordination:** if two batches run concurrently (e.g. main + a side batch), any agent touching a hot file must check `git status` first to avoid clobbering in-flight edits.

## 4. Subagent prompt template

See [references/subagent-prompt-template.md](references/subagent-prompt-template.md) — copy-paste base with the 5 mandatory sections (verified facts / change list / traps & forbidden / headless verify / honesty rules).

## 5. Verification baseline

Godot console exe: `E:/godot/Godot_v4.7.1-stable_win64_console.exe` (GUI variant `..._win64.exe`). Full command catalog: **`docs/validation.md`** — do not duplicate it here.

```bash
# Single-script parse
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --check-only --script "scripts/<file>.gd"
# All-scripts parse (expect ALL_SCRIPTS_PARSE_OK; ignore the 5 pre-existing UI is_visible() warnings in death/help/pause/title/victory overlays)
# Editor import (EXIT 0, no SCRIPT ERROR / Parse Error)
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --editor --path "e:/godot/darksoul/game" --quit
# Runtime smoke (expect ASHEN_HOLLOW_SMOKE_OK)
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --quit-after 600 -- --smoke-test
# One contract test (expect *_CONTRACTS_OK)
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/<contract>_contract_test.gd
# GUT unit suite (uses .gutconfig.json)
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
# Local CI (import + full suite + JUnit; expect ASHEN_HOLLOW_CI_OK)
powershell -File tools/ci.ps1 -Godot "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
```

Notes: add new work to `tools/build.ps1` when it needs a standing contract call. A pre-existing GUT failure (`test_stamina_economy` expected-vs-actual mismatch) is a known stale assertion — report it as pre-existing, do not silently fix.

## 6. Docs sync workflow

Same loop as code: **Explore recon** (compare design docs vs implementation, tag stale/correct) → **parallel implementation** (each doc owned by one agent; `game/` vs `docs/` writes never conflict) → **independent review** (grep the produced docs for contradictions — the devlog found 5 residual contradictions by re-grepping; do not trust stale `path:line` references, they drift after edits). Devlog updates go under `docs/devlog/YYYY-MM-DD/` and are indexed from `docs/devlog/index.md`.

## 7. Pitfalls (distilled from devlog 10/11/12)

- **Agents run away** → forbid download/clone in every prompt; review untracked files.
- **Agents overstep ownership** ("顺手" edits) → verify provenance at review; do not silently accept.
- **Concurrent edits clobber** hot files → `git status` baseline before any agent starts.
- **Line numbers drift** in docs → grep `path:line` at review, don't trust old references.
- **Data schema traps:** `progression_values` only non-negative int; `choice_flags` only bool/non-empty string; empty `story_flag` enters `_on_boss_story_threshold` → unconditional `enter_story_resolution` soft-lock (guard with an empty-flag early exit at the top); `_chapter_elite_for` takes the first match → use by-id (`_chapter_elite_by_id`) to avoid duplicate spawns.
- **"未做" in a delivery report must be cleared or explicitly marked out-of-scope** — a Stop hook will call it out.
- **Model/GLB wiring:** registry-driven `RealModelResolver.try_instance(id, parent)` must return a bool and fall back to procedural on miss; when re-attaching sub-nodes set `target.owner = null` or you trigger Godot `owner inconsistent` warnings; real models keep their own materials — gate palette application on the `ModelRoot` node.
- **Model asset pipeline (all 3 references):**
  - [references/glb-export-threejs.md](references/glb-export-threejs.md) — producing a GLB with Three.js `GLTFExporter` (API + Node FileReader shim)
  - [references/glb-batch-export.md](references/glb-batch-export.md) — **multi-agent batch export of all 85 model-prompts** (shared scaffold, 9-way split, per-agent prompt template, independent verify)
  - [references/glb-viewer-and-vlm.md](references/glb-viewer-and-vlm.md) — HTML 3D viewer + remote-VLM visual check

## 8. Checklist

- [ ] Recon agents returned `path:line` evidence + reliability tags before any implementation agent ran
- [ ] Every implementation prompt listed owned files, forbidden actions, traps, and its headless verify command
- [ ] Hot files (`player.gd`, `game_world.gd`) were written serially by the main thread only
- [ ] `git status` baseline declared before agents started; provenance checked after
- [ ] Main thread independently re-ran: all-script parse (ignore pre-existing UI warnings) + smoke `ASHEN_HOLLOW_SMOKE_OK` + affected contracts `*_CONTRACTS_OK` + GUT
- [ ] Docs re-grepped for contradictions; devlog entry written under `docs/devlog/YYYY-MM-DD/` and indexed
- [ ] No untracked out-of-ownership artifacts left behind
