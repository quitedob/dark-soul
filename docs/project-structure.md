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
├── mcp/                         # Godot MCP Native plugin and CLI tools
├── packages/                    # Reusable Flutter/platform integration packages
├── screenshot/                  # Scene screenshots and editor viewport captures
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
│   ├── boss/                    # Boss 相变与流程
│   ├── camera/                  # 战斗相机镜头（抓投/弱点/命运）
│   ├── combat/                  # 战斗系统（spirit_summon.gd、data/ 兵器诀/状态目录）
│   ├── components/              # Reusable combat/projectile behavior
│   ├── core/                    # Save state, settings, and localization
│   ├── data/                    # 数据 schema 与目录（weapon_arts_catalog.gd）
│   ├── enemy/                   # 敌人 AI / AttackData 目录
│   ├── fx/                      # 战斗/环境特效
│   ├── levels/                  # 关卡逻辑（29 关）
│   ├── player/                  # Player controller（player.gd 入口；talent/meridian 数据）
│   ├── story/                   # 叙事（dialogue_runner.gd）
│   ├── tools/                   # CLI 校验入口
│   ├── ui/                      # UI（fast_travel_overlay.gd、inventory_overlay.gd）
│   ├── world/                   # 世界物（furnace_memory_crystal.gd）
│   └── *.gd                     # Remaining gameplay composition and actor scripts
├── resources/                   # Resource 数据树（.tres 资产）
│   ├── combat_styles/           # 五兼容 loadout（5 件 .tres）
│   ├── weapons/                 # 武器数据（class_*.tres 9 件）
│   ├── movesets/                # moveset 资源（2 件）
│   ├── guards/                  # 格挡 profile（6 件）
│   ├── enemies/                 # 敌人数据（hollow_sentinel/）
│   ├── weapon_arts/             # 兵器诀（9 件 .tres）
│   └── boss/                    # Boss 配置（heal_punish_defaults.gd）
└── tests/
    ├── unit/                    # GUT 单元测试（combat/state_machines/systems）
    ├── smoke/                   # Headless contract and smoke checks（34 个 .gd 文件）
    │     例如：chapter1_slice / chapter2_slice / chapter3_5_wiring / boss_weakpoint / combat_style_resource / grip_charge / guard_execution / heal_punish …
    └── run_tests.ps1 / run_tests.sh
```

The scene folders communicate runtime meaning. Actor scripts may live in packages under `scripts/` (for example `scripts/player/player.gd`); coordinated moves must preserve `.uid` files, update every `res://` reference, and pass Godot import and smoke validation.

### `app/`

`app/` is the Flutter shell that hosts the exported game and owns application-level concerns such as lifecycle, settings, localization, persistence coordination, and the OpenHarmony application package. It must not contain Godot gameplay logic.

Generated Flutter output such as `app/build/` and `app/.dart_tool/` is not source code and remains ignored.

### `packages/`

`packages/` contains reusable Flutter or platform plugins. `packages/ashen_hollow_web_host/` owns the OpenHarmony Web platform-view integration used to host the Godot web export. Package code should expose a narrow integration API and should not depend on game-specific scene internals.

### `docs/`

`docs/` is the source of truth for project intent and engineering decisions. Layout (2026-07-31):

```text
docs/
├── master-index.md          # 文档地图入口
├── architecture.md / controls.md / validation.md / …
├── planning/                # 开放缺口（如 soulslike-gap-analysis）
├── research/
│   ├── index.md             # 调研汇总
│   ├── soulslike/           # 魂系设计调研
│   └── godot/               # 引擎/工程调研
├── devlog/
│   ├── index.md             # 唯一交付日志索引
│   └── YYYY-MM-DD/*.md      # 按日拆分条目（含 delivery-summary）
├── systems/ story/ chapters/ characters/ bestiary/
└── tasks/                   # 仅保留活路线图（如 combat-expansion-roadmap）
```

规则：

- 交付只写 `docs/devlog/<日期>/`，**禁止**再堆根级巨型 `devlog.md` / `CHANGELOG.md`
- 文件名用语义英文；**禁止** `e-1` / `a01` 式散落任务文件
- 文档描述已验证行为；计划项须标明 planned

中文镜像 `docs-zh/` 已移除；文档权威仅为 `docs/`。

### `screenshot/`

`screenshot/` is the **only** directory where scene screenshots and editor viewport captures may be placed. All screenshots — whether taken via Godot MCP (`get_editor_screenshot`, `get_runtime_screenshot`), manual `Print Screen`, or any other tool — must go under `screenshot/`.

**Rules:**
- ❌ **禁止乱放** — do not scatter screenshots in `game/`, `docs/`, the repository root, or any other directory
- ✅ 所有截图统一放在 `screenshot/` 根目录下
- 📁 可按日期或场景创建子目录，例如 `screenshot/2026-07-30/` 或 `screenshot/chapter-1/`
- 🚫 不要将截图提交到其他目录的 `.gitignore` 白名单之外

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
6. Record only the verified result in `docs/devlog/index.md`（逐日条目按 `docs/devlog/<日期>/` 目录记录）.

Do not reorganize runtime files while another agent is editing them unless that work is explicitly coordinated.
