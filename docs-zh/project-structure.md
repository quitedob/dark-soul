# 项目结构 (Project Structure)

此仓库包含多个协作项目。目录归属应保持明确，以便 Godot 游戏、宿主应用、平台插件、文档和构建工具可以独立演进。

## 仓库布局 (Repository Layout)

```text
newproject/
├── app/                         # Flutter/OpenHarmony 宿主应用
├── docs/                        # 产品、设计、架构和验证文档
├── game/                        # 独立的 Godot 项目
│   ├── project.godot            # Godot 项目根和引擎配置
│   ├── main.tscn                # Godot 入口场景
│   ├── export_presets.cfg       # Godot 导出配置
│   ├── scenes/                  # 按角色分组的可复用场景定义
│   ├── scripts/                 # 游戏玩法和运行时实现
│   └── tests/                   # Godot 自动化测试
├── packages/                    # 可复用的 Flutter/平台集成包
└── tools/                       # 仓库级构建和验证自动化
```

## 目录职责 (Directory Responsibilities)

### `game/`

`game/` 是唯一的 Godot 项目根。所有 `res://` 路径均相对于此目录解析。因此 Godot 命令应使用：

```text
--path D:/godot/newproject/game
```

其当前内部结构为：

```text
game/
├── scenes/
│   ├── actors/                  # 玩家和敌人场景入口点
│   ├── audio/                   # 音频系统场景
│   ├── components/              # 可复用的游戏组件
│   ├── interactables/           # 神坛、捷径和恢复物件
│   ├── ui/                      # HUD 场景
│   └── world/                   # 可玩世界场景
├── scripts/
│   ├── app/                     # Godot 到宿主通信桥接
│   ├── components/              # 可复用的战斗/投射物行为
│   ├── core/                    # 存档状态、设置和本地化
│   ├── ui/                      # 辅助 UI 行为
│   └── *.gd                     # 现有游戏玩法和角色脚本
└── tests/
    └── smoke/                   # 无头合约和烟雾检查
```

场景文件夹传达运行时含义。现有的顶层游戏脚本在其他代理正在修改游戏时仍然有效。未来的脚本迁移只应作为一个协调变更进行：移动文件、保留 `.uid` 文件、更新每个 `res://` 引用，并通过 Godot 导入和烟雾验证。

### `app/`

`app/` 是托管导出游戏的 Flutter 壳层，并拥有应用层面的关注点，如生命周期、设置、本地化、持久化协调以及 OpenHarmony 应用程序包。它不得包含 Godot 游戏逻辑。

生成的 Flutter 输出，如 `app/build/` 和 `app/.dart_tool/`，不是源代码并保持忽略状态。

### `packages/`

`packages/` 包含可复用的 Flutter 或平台插件。`packages/ashen_hollow_web_host/` 拥有用于托管 Godot Web 导出的 OpenHarmony Web 平台视图集成。包代码应暴露窄集成 API，不应依赖游戏特定的场景内部。

### `docs/`

`docs/` 是项目意图和工程决策的真实来源：

- `game-design.md`：游戏玩法目标和垂直切片范围。
- `architecture.md`：运行时系统和数据流。
- `project-structure.md`：仓库边界和目录归属。
- `controls.md`：面向玩家的输入行为。
- `validation.md`：自动化命令和手动验证清单。
- `devlog.md`：按时间顺序的实现记录。
- `research.md`：辅助设计和引擎研究。
- `agents/`：本地专业代理指导。

文档必须描述已验证的行为。计划中的工作应标注为计划中，而非记录为已完成。

### `tools/`

`tools/` 包含仓库级自动化。此处的脚本可协调 Godot、Flutter、插件、导出和打包步骤，但应将产品行为委托给所属项目。

## 依赖方向 (Dependency Direction)

```text
app/ ───────────────▶ packages/ashen_hollow_web_host/
 │
 └── hosts/export ──▶ game/

tools/ ─────────────▶ game/ + app/ + packages/

docs/ ──────────────▶ 描述所有项目；运行时项目不依赖 docs/
```

`app/` 和 `game/` 之间的通信应通过已定义的宿主桥接和序列化契约传递。Flutter 层不得直接访问 Godot 节点，Godot 游戏代码不得依赖 Flutter 实现类。

## 命名规则 (Naming Rules)

- Godot 场景和脚本使用小写 `snake_case` 命名。
- 场景按其实例化的游戏对象命名，如 `ember_shrine.tscn`。
- 将可复用行为放在特定角色的目录下，如 `components/`、`core/` 或 `ui/`。
- 将生成的文件排除在源代码目录之外，并由 `.gitignore` 覆盖。
- 移动脚本时保留 Godot 的 `.uid` 文件。
- 将路径变更视为集成变更：更新所有 preload/resource 引用并验证整个项目。

## 安全的结构变更 (Safe Structure Changes)

在重新组织文件之前：

1. 检查 `git status` 是否存在并发或未提交的工作。
2. 识别所有指向待移动文件的 `res://` 引用。
3. 将脚本与其 `.uid` 文件一起移动。
4. 在一次变更中更新场景、脚本、测试、文档和构建命令。
5. 运行 Godot 编辑器导入、脚本解析、合约测试和游戏玩法烟雾测试。
6. 仅将已验证的结果记录在 `devlog.md` 中。

除非工作明确协调，否则在其他代理正在编辑运行时文件时不要重新组织它们。
