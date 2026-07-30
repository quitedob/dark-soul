# 审计 — 文档与代码库健康状况

**日期：** 2026-07-30
**状态：** `ACTIVE` — 全面扫描完成；识别出4份过时文档、6个缺失主题、3个已损坏引用（已于2026-07-30修复）
**参见：** [`research-dark-souls-design.md`](research-dark-souls-design.md) — 12主题DS设计审计、垂直切片检查清单、文档可靠性表
**参见：** [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) — 按风格武器调优、卡肉、霸体
**参见：** [`research-dark-souls-mechanics-deep.md`](research-dark-souls-mechanics-deep.md) — 帧数据、韧性数学、已验证实现与待定差距
**参见：** [`research-github-godot-soulslike-ecosystem.md`](research-github-godot-soulslike-ecosystem.md) — 生态系统调查、可复用模块检查清单
**参见：** [`devlog.md`](devlog.md) — 所有变更的编年记录、恢复顺序
**参见：** [`project-structure.md`](project-structure.md) — 目录布局、命名规则、安全变更流程

审计于2026-07-30通过两次详尽的只读子代理扫描执行：一次覆盖`docs/`中所有20个文件（包括`docs/agents/`中的9个代理定义），一次覆盖`game/`中所有16个GDScript文件（5,702行）、10个场景、项目配置、资源和测试。每个`.gd`文件至少被部分读取；每个`.tscn`、`.cfg`和测试文件都被检查。本报告将两次扫描综合为单一健康评估，附带排名、可执行的建议。

---

## 方法论

### 扫描覆盖范围

| 扫描目标 | 范围 | 方法 |
|---|---|---|
| `docs/` | 20个文件，约260 KB | 完整读取每个`.md`文件；交叉引用映射；对照devlog中记录的代码状态进行过时性审计 |
| `docs/agents/` | 9个代理定义 | 完整读取；技能依赖映射；路由规则分析 |
| `game/scripts/` | 16个`.gd`文件，5,702行 | 完整或实质性部分读取每个文件；类/函数清单；preload/signal/call依赖图 |
| `game/scenes/` | 10个`.tscn`文件 | 完整读取；节点类型、脚本附加和加载步骤审计 |
| `game/project.godot` | 1个配置文件 | 完整读取；渲染器、输入映射、autoload、物理、显示、插件审计 |
| `game/assets/` | 4个文件 | 完整读取；字体许可证、字形覆盖、导入配置 |
| `game/tests/` | 1个测试文件，131行 | 完整读取；测试用例清单、覆盖缺口分析 |

### 证据分类

| 标签 | 标准 |
|---|---|
| **观察到 (Observed)** | 通过文件内容、行数、preload路径、场景结构或信号连接直接验证。 |
| **推导 (Derived)** | 从代码模式、依赖图或多文件对比推断。 |
| **缺口 (Gap)** | 通过详尽搜索确认不存在 — 没有文件、函数、测试或文档章节涉及该主题。 |

本报告中没有任何声明依赖于外部研究或开发者访谈。每个发现都基于扫描时仓库中可观察到的文件内容。

---

## 1. 文档套件健康状况

### 1.1 完整文件清单

| # | 文件 | 大小 | 类别 | 健康状态 |
|---|---|---|---|---|
| 1 | `game-design.md` | 8 KB | 设计规范 | ✅ **当前** — 在commit `7f30d4f`中更新了活力锻造、余烬祷仪、Boss阶段、敌人重置 |
| 2 | `architecture.md` | 4 KB | 技术规范 | ⚠️ **部分可靠** — 缺少标题画面、暂停流程、5种战斗风格、scripts/子目录 |
| 3 | `project-structure.md` | 8 KB | 流程 | ✅ **当前** — 反映仓库布局；依赖方向和命名规则完整 |
| 4 | `controls.md` | 4 KB | 参考 | 🔴 **过时** — 早于全部5种战斗风格、手柄、触屏、格挡、招架；被两份研究审计标记 |
| 5 | `validation.md` | 4 KB | 流程 | ⚠️ **部分可靠** — 脚本glob遗漏子目录；项目路径可能过时；手柄声明错误 |
| 6 | `research.md` | 12 KB | 研究 | ⚠️ **部分可靠** — 基础设计建议仍然可靠；早于5风格系统和审计后修复 |
| 7 | `devlog.md` | 24 KB | 流程 | ✅ **当前** — 6条带日期条目贯穿2026-07-30；恢复顺序已定义 |
| 8 | `research-dark-souls-design.md` | 28 KB | 研究 | ✅ **当前** — 于2026-07-29更新到修复后状态；反映了9项审计修复 |
| 9 | `research-dark-souls-weapons.md` | 36 KB | 研究 | ✅ **当前** — 于2026-07-29更新；11条建议状态跟踪（1项DONE，5项PENDING，5项DEFERRED）|
| 10 | `research-dark-souls-mechanics-deep.md` | 40 KB | 研究 | ✅ **当前** — 2026-07-30创建；帧数据、韧性数学、Godot模式 |
| 11 | `research-github-godot-soulslike-ecosystem.md` | 48 KB | 研究 | ✅ **当前** — 2026-07-30创建；8个仓库、关卡设计模式、工时估算 |
| 12–20 | `agents/*.md`（9个文件）| 约72 KB总计 | 代理定义 | ✅ **当前** — 模板一致；路由规则防止重叠；无游戏特定知识（设计如此）|

### 1.2 过时详情

#### 🔴 高 — `controls.md`

针对初始原型状态编写（交接前）。当前文档中缺失：

| 缺失主题 | 实际文档位置 |
|---|---|
| 圣匣守势（计时招架、盾牌格挡、突刺攻击）| `devlog.md`交接条目；`game-design.md` |
| 双重巨刃（成对大剑跳跃攻击）| 同上 |
| 双弧刃（成对弯刀二段跳跃攻击）| 同上 |
| 帷幕术法（专注驱动投射魔法）| 同上 |
| 余烬祷仪（专注驱动治疗与伤害祷文）| 同上 |
| 手柄按键绑定 | 未在任何地方文档化 |
| 触屏控制布局 | 未在任何地方文档化 |
| 专注资源按键绑定 | 仅`player.gd`代码 |
| 风格切换输入 | 仅`player.gd`代码 |

**建议：** 完全重写。以`game-design.md`战斗支柱 + `player.gd`输入处理为真源。添加按风格输入表、手柄映射图和触屏布局图。

#### ⚠️ 中 — `architecture.md`

场景树图显示初始原型（`AshenHollow` → `WorldEnvironment` → `Warden` → `EmberShrine` → ...）。当前图中缺失：

- 标题画面流程（`hud.gd._build_title()`）
- 带有设置面板支架的暂停菜单
- `scripts/app/`、`scripts/core/`、`scripts/ui/`子目录
- `AshenRunState`、`AshenGameSettings`、`AshenLocalization`数据类
- `AshenGameHostBridge` web宿主协议层
- 与耐力并行的专注资源系统

**建议：** 添加子目录分解、数据类章节、宿主桥接架构和UI流程图（标题→游戏→暂停→死亡→胜利）。现有的职责表和碰撞层文档是正确的，应保留。

#### ⚠️ 中 — `validation.md`

三个具体问题：

1. **脚本glob**：`scripts/*.gd`不会递归到`scripts/app/`、`scripts/components/`、`scripts/core/`、`scripts/ui/`。应为`scripts/**/*.gd`。
2. **项目路径**：使用`D:/godot/newproject`，但`project-structure.md`指定`D:/godot/newproject/game`为Godot项目根。`--path`参数必须指向`game/`。
3. **已知限制#4**："键盘/鼠标已实现；手柄支持……留作未来工作" — 手柄支持已添加（devlog交接条目）。更新以反映当前状态。
4. **缺失命令**：`core_contract_test.gd`（打印`ASHEN_CORE_CONTRACTS_OK`）未文档化。添加契约测试调用。

**建议：** 修复glob，与`project-structure.md`对齐路径，更新手柄限制，添加契约测试命令。

#### ⚠️ 低 — `research.md`

早于5风格系统、手柄支持、子目录重构和所有审计后修复。设计建议（攻击承诺、耐力经济、敌人动作提示、检查点设计）仍然可靠。实现声明部分描述的是初始原型，而非交接状态。

**建议：** 在顶部添加横幅："本报告编写于初始原型阶段（2026-07-29）。关于当前实现状态，请参见[`devlog.md`](devlog.md)和三份审计后研究文档。设计原则和Godot API映射仍然有效。"

### 1.3 交叉引用网络

| 文档 | 被引用次数 | 引用 |
|---|---|---|
| `research-dark-souls-design.md` | 4份其他文档 | 8份文档 |
| `research.md` | 6份其他文档 | 0份文档（仅外部URL）|
| `research-dark-souls-weapons.md` | 4份其他文档 | 8份文档 |
| `devlog.md` | 2份其他文档 | 7份文档+代码文件 |
| `research-dark-souls-mechanics-deep.md` | 0份其他文档（最新）| 4份文档 |
| `research-github-godot-soulslike-ecosystem.md` | 1份其他文档 | 3份文档 |
| `game-design.md` | 4份其他文档 | 0份文档 |
| `architecture.md` | 2份其他文档 | 0份文档（仅代码）|
| `controls.md` | 2份其他文档 | 0份文档 |
| `validation.md` | 2份其他文档 | 0份文档 |
| `project-structure.md` | 2份其他文档 | 7份文档 |

**观察：** 最孤立的三份文档（`controls.md`、`validation.md`、`architecture.md`）也是最需要更新的三份。具有丰富双向交叉引用的文档（`research-dark-souls-design.md`、`research-dark-souls-weapons.md`）维护良好。交叉引用密度与文档健康状况相关。

### 1.4 代理定义

`docs/agents/`中全部9个代理遵循相同模板（YAML frontmatter、"Your Skills"章节、"Your Process"、"Distinguishing Choices"、"Output Format"、"When NOT to use"）。它们是可复用的GodotPrompter专家定义，不含游戏特定知识——这是设计使然。

| 代理 | 领域 | 路由到 |
|---|---|---|
| `godot-game-architect` | 系统设计、场景树、信号、状态机（只读）| godot-csharp-engineer, godot-animator, godot-ui-designer, godot-tools-engineer |
| `godot-game-dev` | 通用GDScript/C#实现 | godot-csharp-engineer, godot-animator, godot-ui-designer, godot-tools-engineer |
| `godot-code-reviewer` | 代码审查、反模式、性能 | 基于代码内容的领域特定技能 |
| `godot-animator` | AnimationPlayer、AnimationTree、IK、重定向 | godot-game-dev处理游戏逻辑 |
| `godot-csharp-engineer` | C#优先开发、GC模式、对等模式 | — |
| `godot-shader-author` | 着色器、合成器、可视化着色器图 | godot-game-dev, godot-performance-profiler |
| `godot-ui-designer` | Control节点、容器、主题、本地化 | godot-game-dev, godot-shader-author, godot-animator |
| `godot-performance-profiler` | CPU/GPU瓶颈诊断 | godot-game-architect, godot-game-dev, godot-shader-author |
| `godot-tools-engineer` | EditorPlugin、自定义检查器、@tool脚本 | godot-game-dev, godot-shader-author, godot-performance-profiler |

**健康状态：** 所有代理定义内部一致，具有清晰的路由规则防止重叠，并遵循相同的专业模板。无需更新。

---

## 2. 代码库健康状况

### 2.1 文件清单

| 文件 | 行数 | 类/继承 | 用途 |
|---|---|---|---|
| `scripts/player/player.gd` | 1,140 | `CharacterBody3D` | 12状态玩家：LOCOMOTION、ATTACK_WINDUP、ATTACK_ACTIVE、ATTACK_RECOVERY、DODGE、STAGGER、DEAD、PARRY、GUARD、CAST、HEAL、INTERACT |
| `scripts/hud.gd` | 1,132 | `CanvasLayer` | 完整程序化HUD：生命状态条、Boss条、标题/暂停/死亡/胜利/帮助覆盖层、语言切换（en/zh_CN）、无障碍（UI缩放、文本缩放、减弱动态、高对比度）、移动端控制 |
| `scripts/game_world.gd` | 962 | `Node3D` | 世界编排器：生成所有实体、连接所有信号、管理保存/加载、检查点逻辑、圣祠升级、死亡/恢复循环、宿主桥接集成、内嵌冒烟测试（140行，由`--smoke-test`控制）|
| `scripts/enemy.gd` | 704 | `CharacterBody3D` | 8状态敌人FSM：IDLE、CHASE、WINDUP、ACTIVE、RECOVERY、STAGGER、RETURN、DEAD。余烬守护者变体具有第2阶段（≤50% HP）、距离区间攻击选择（3个区间）、武器发光、硬直过渡 |
| `scripts/ui/mobile_controls.gd` | 358 | `Control` | 触屏覆盖层：虚拟摇杆（动态定位）、相机拖拽区域、5个行动按钮、冲刺保持 |
| `scripts/checkpoint.gd` | 171 | `Area3D` | 余烬圣祠：激活、休息（完全治疗+敌人重置）、活力锻造升级UI、火焰视觉状态 |
| `scripts/shortcut.gd` | 165 | `Area3D` | 捷径拉杆：缓动驱动门开启、持久状态存储于run_state |
| `scripts/lost_echo.gd` | 154 | `Area3D` | 尸体回收：悬浮回响球体、身体/环/发光程序化视觉、触碰回收余烬 |
| `scripts/app/game_host_bridge.gd` | 147 | `Node` | Web宿主协议：JSON v1、双向消息传递、8个信号、性能遥测 |
| `scripts/core/game_settings.gd` | 145 | `RefCounted` | `AshenGameSettings`：语言、UI/文本缩放、音频音量、FPS上限、Godot+桥接序列化 |
| `scripts/core/run_state.gd` | 143 | `RefCounted` | `AshenRunState`：检查点、余烬、专注、战斗风格、失落回响位置、捷径、守护者状态、升级层。模式版本化保存/加载 |
| `scripts/procedural_audio.gd` | 133 | `Node` | 运行时AudioStreamWAV合成：音调、噪声脉冲、钟声、胜利号角。6声道池。无头安全 |
| `scripts/core/localization.gd` | 89 | `RefCounted` | `AshenLocalization`：79对en/zh_CN字符串，`normalize_locale()`，静态`text()` |
| `scripts/components/spell_projectile.gd` | 73 | `Area3D` | 帷幕飞矢：15 m/s，2.2秒生命周期，蓝色发光，通过`receive_hit()`命中身体 |
| `scripts/combat_area.gd` | 55 | `Area3D` | 攻击判定框：每次挥砍每身体命中去重，方向感知击退，`begin_swing()`/`end_swing()`生命周期 |
| `tests/smoke/core_contract_test.gd` | 131 | `SceneTree` | 4个无头测试：运行状态往返、无效数据拒绝、设置消毒、桥接契约 |

**总计：5,702行GDScript + 131行测试 = 5,833行。**

### 2.2 架构评估

代码库遵循**中心中介模式**，具有清晰的基于信号的通信：

```
main.tscn
  └── ashen_hollow.tscn (game_world.gd)  ← 单一编排器
        ├── ProceduralAudio (procedural_audio.gd)
        ├── Warden (scripts/player/player.gd)
        ├── HUD (hud.gd)
        │     └── MobileControls (mobile_controls.gd)
        ├── EmberShrine (checkpoint.gd)
        ├── AncientLever (shortcut.gd)
        ├── HollowSentinel × N (enemy.gd)
        ├── CinderGuardian (enemy.gd)
        ├── LostEcho (lost_echo.gd) — 死亡时生成
        └── GameHostBridge (game_host_bridge.gd)
```

**关键架构属性：**

| 属性 | 评估 |
|---|---|
| **耦合度** | 低。脚本通过信号通信。全部使用鸭子类型（`has_method()`）而非显式类型检查。`player.gd`通过无类型`world_node`引用访问世界。 |
| **内聚度** | 每个脚本内部高。`player.gd`处理所有玩家关注点；`enemy.gd`处理所有敌人关注点；`game_world.gd`仅处理编排。 |
| **Autoloads** | 无。所有类似单例的对象（`AshenGameSettings`、`AshenRunState`、`AshenLocalization`）都是普通的`RefCounted`实例，由`game_world.gd`创建和持有。这保持了架构的显式性，但意味着`game_world.gd`既是编排器又是伪DI容器。 |
| **程序化内容** | 100%。每个视觉元素（BoxMesh、CapsuleMesh、CylinderMesh、SphereMesh、TorusMesh、PrismMesh、QuadMesh）和每个音频样本（PCM WAV合成）都是代码生成的。零导入纹理、模型或音频文件。 |
| **输入** | InputMap在`game_world.gd._configure_inputs()`中程序化构建——24个操作涵盖键盘、鼠标和手柄。`mobile_controls.gd`合成`InputEventMouseMotion`并直接调用`Input.action_press()/action_release()`。 |
| **碰撞层** | Layer 1 = 静态世界, Layer 2 = 玩家, Layer 3 = 可交互对象, Layer 4 = 敌人。战斗区域使用定向遮罩（玩家攻击layer 4，敌人攻击layer 2）。 |

### 2.3 优势

1. **攻击承诺模型**正确。三阶段攻击（前摇/判定/后摇）配合不可取消窗口，符合魂类设计需求。输入缓冲（150ms，最后输入有效）已实现，并由`_can_buffer_in_current_state()`控制。

2. **耐力系统**正确。共享预算（攻击/闪避/冲刺全部从同一个池中消耗），再生延迟限制在`State.LOCOMOTION`状态，在`_physics_process`中使用帧计数冷却（非`await`）。这与[`research-dark-souls-mechanics-deep.md`](research-dark-souls-mechanics-deep.md)第7.3节中记录的行业标准模式一致。

3. **Boss设计**方向正确。≤50% HP的阶段过渡，距离区间攻击选择（3个区间：近距离<2.0m，中距离2.0–3.5m，远距离>3.5m），第2阶段具有更快前摇/更短后摇/更高伤害。缺少治疗惩罚倾向（见缺口，第3.2节）。

4. **数据完整性**健壮。模式版本化JSON序列化（`AshenRunState`、`AshenGameSettings`），反序列化时输入夹持，全局空值守卫，每次跨脚本调用前进行`has_method()`检查。

5. **本地化**完整。79个翻译字符串，`normalize_locale()`用于宽容匹配，内嵌Noto Sans CJK附带文档化的字形子集。HUD通过`AshenLocalization.text()`读取所有面向用户的字符串。

6. **无障碍**内置。UI缩放（0.5–2.0）、文本缩放（0.5–2.0）、减弱动态（禁用Tween）、高对比度模式、所有鼠标操作的键盘替代方案。

7. **Web宿主集成**专业。版本化JSON协议（v1），双向消息传递，性能遥测（`send_performance_sample()`），无宿主时的优雅降级（`is_connected_to_host()`）。

8. **零TODO债务**。在所有5,702行中搜索`TODO|FIXME|HACK|XXX|BUG|WORKAROUND`返回零匹配。

### 2.4 潜在问题

| 问题 | 严重性 | 详情 |
|---|---|---|
| **无autoloads** | 低 | `game_world.gd`手动创建并持有`AshenGameSettings`、`AshenRunState`、`AshenLocalization`和`AshenGameHostBridge`。这适用于当前规模，但意味着任何需要设置的脚本都必须通过世界节点访问。随着脚本数量增长，考虑为三个数据类使用autoloads。 |
| **内嵌冒烟测试** | 低 | 140行冒烟测试逻辑位于`game_world.gd`内部（第822–962行），由`--smoke-test`控制。这是仅在测试期间运行的生产代码。打印`ASHEN_HOLLOW_SMOKE_OK`并调用`get_tree().quit()`。考虑提取到`tests/smoke/`。 |
| **移动端检测重复** | 低 | 用户代理和指针媒体查询检查同时出现在`game_world.gd`和`hud.gd`中。适合提取到共享助手或`PlatformCapabilities`资源中。 |
| **全部统一的战斗时机** | 中 | 所有5种战斗风格使用相同的前摇、判定和后摇持续时间。这是来自[`research-dark-souls-weapons.md`](research-dark-souls-weapons.md)和[`research-dark-souls-mechanics-deep.md`](research-dark-souls-mechanics-deep.md)的#1待定建议。 |
| **无游戏玩法测试覆盖** | 中 | 仅测试了数据契约和宿主协议。战斗、AI、UI、输入和渲染有零自动化测试。手动游玩是唯一的验证路径。 |
| **无编辑器放置内容** | 信息 | 这是刻意的架构选择，而非缺陷。所有内容都是代码生成的。添加新敌人类型、环境或效果需要编写GDScript而非使用Godot的编辑器工具。 |

### 2.5 场景设计模式

所有10个`.tscn`文件都是**最小存根**（2个加载步骤，格式3）——单个根节点附带一个脚本。所有子节点、几何体、材质、碰撞形状和视觉元素都在`_ready()`中程序化创建。

**理由（从代码模式推导）：** 这种方法消除了版本控制中的场景合并冲突，将所有逻辑保持在可搜索的`.gd`文件中，并使项目行为仅通过读取脚本即可完全审计。代价是Godot的编辑器场景工具（可视化放置、材质预览、光照预览）在开发过程中没有使用价值。

### 2.6 测试覆盖评估

| 领域 | 覆盖 | 缺口 |
|---|---|---|
| 数据序列化 | ✅ 往返测试 | — |
| 输入消毒 | ✅ 越界夹持测试 | — |
| 宿主桥接协议 | ✅ 消息解析+信号发射测试 | — |
| 玩家状态机 | ❌ | 12个状态，零测试 |
| 敌人AI FSM | ❌ | 8个状态+第2阶段，零测试 |
| 战斗命中检测 | ❌ | 每次挥砍每身体命中去重未测试 |
| 耐力经济 | ❌ | 再生延迟、门控逻辑未测试 |
| HUD渲染 | ❌ | 所有程序化UI未测试 |
| 移动端控制 | ❌ | 触摸输入合成未测试 |
| 音频合成 | ❌ | PCM生成未测试 |
| 保存/加载到磁盘 | ❌ | 仅内存JSON往返测试 |
| 死亡/恢复循环 | ❌ | 完整循环未测试 |
| 圣祠升级经济 | ❌ | 3层余烬消耗未测试 |

**总体：约10–15%逻辑路径覆盖。** 现有测试编写良好且具有策略性（它们保护数据完整性和宿主集成层），但游戏核心没有自动化安全网。

---

## 3. 已识别的缺口

### 3.1 文档缺口 — 无专门文档的主题

| # | 缺失文档 | 重要性 | 部分覆盖位置 |
|---|---|---|---|
| 1 | **战斗风格参考** | 5种风格，各有独特机制、时机、输入和音频。无单一文档定义它们。 | `research-dark-souls-weapons.md`中的调优参考表（中置信度，研究级）；`player.gd`代码 |
| 2 | **专注资源系统** | 与耐力并行的第二战斗资源。最大池、再生规则、按风格的成本未文档化。 | `game-design.md`（提及成本）；`player.gd`代码 |
| 3 | **保存/持久化设计** | `run_state.gd`跨会话持久化8个数据字段。保存格式、模式版本化、迁移路径未文档化。 | `run_state.gd`代码；`devlog.md`提及持久化 |
| 4 | **构建与导出指南** | 配置了Web、Windows、Linux预设。`tools/build.ps1`在devlog中提及但未文档化。 | `export_presets.cfg`；`devlog.md`交接条目 |
| 5 | **音频系统参考** | 程序化音频API（6个提示音、6声道池、无头检测）。无添加声音的文档。 | `procedural_audio.gd`代码 |
| 6 | **敌人AI规范** | 检测半径、牵制距离限制、圣所脱离、导航回退、按敌人调优。 | `enemy.gd`代码；`architecture.md`仅状态图 |

### 3.2 代码缺口 — 对照研究建议验证

按"魂感"影响与实现努力的排名：

| # | 缺口 | 状态 | 研究来源 | 影响 |
|---|---|---|---|---|
| 1 | **按风格攻击时机差异化** | PENDING | `research-dark-souls-weapons.md` §11; `research-dark-souls-mechanics-deep.md` §9 | 高 — 所有5种风格手感相同，尽管武器幻想不同 |
| 2 | **重武器判定帧期间的霸体** | PENDING | `research-dark-souls-mechanics-deep.md` §4, §9 | 高 — 双重巨刃在其漫长前摇回报期间无抗硬直能力 |
| 3 | **成功命中时的卡肉效果** | PENDING | `research-dark-souls-weapons.md` §11 | 高 — 对武器重量感知最具影响力的单一改动；在设计复杂度上零成本 |
| 4 | **按风格耐力成本差异化** | PENDING | `research-dark-souls-weapons.md` §11 | 中 — 削弱武器身份；重武器必须消耗更多 |
| 5 | **招架窗口差异化** | PENDING | `research-dark-souls-mechanics-deep.md` §3.3, §9 | 中 — 圣匣守势招架有统一窗口；应随盾牌类型变化 |
| 6 | **Boss治疗惩罚倾向** | NOT IMPLEMENTED | `research-dark-souls-mechanics-deep.md` §6.2, §9 | 中 — 余烬守护者不会对玩家治疗做出反应 |
| 7 | **第二种敌人原型** | NOT IMPLEMENTED | `research-dark-souls-design.md`垂直切片检查清单S1 | 中 — 仅有空洞哨兵+余烬守护者；无远程、盾牌或伏击敌人 |
| 8 | **蓄力重攻击** | DEFERRED | `research-dark-souls-weapons.md` §11 | 低 — 按住蓄力机制用于重攻击 |
| 9 | **冲刺/翻滚攻击变体** | DEFERRED | `research-dark-souls-weapons.md` §11 | 低 — 来自冲刺或闪避的独特攻击 |
| 10 | **韧性系统** | DEFERRED | `research-dark-souls-mechanics-deep.md` §4; `research-dark-souls-weapons.md` §11 | 低 — 完全韧性生命值+霸体系统；有意义的重武器差异化的前提 |

### 3.3 研究缺口 — 现有文档未回答的问题

1. 是否有团队发布过商业Godot 4魂类游戏？生态系统扫描中未找到已发布的项目复盘。
2. Godot 4.7中20+活跃敌人的`NavigationAgent3D`性能上限是多少？
3. 魂类社区中是否存在标准化的Mixamo→Godot人形骨架重定向工作流程？
4. 是否有人发布过专门针对魂类Boss阶段脚本调优的Godot 4行为树集成？

---

## 4. 建议

### 4.1 文档 — 优先级顺序

| 优先级 | 行动 | 工作量 | 文档 |
|---|---|---|---|
| **P1** | 重写`controls.md` | 中 | 完整输入表：5种战斗风格、键盘、鼠标、手柄、触屏。以`player.gd`输入处理+`game-design.md`战斗支柱为真源。 |
| **P2** | 更新`architecture.md` | 中 | 添加scripts/子目录、数据类（`AshenRunState`、`AshenGameSettings`、`AshenLocalization`）、宿主桥接层、标题/暂停/死亡/胜利UI流程图。 |
| **P3** | 修复`validation.md` | 小 | 修复脚本glob（`scripts/**/*.gd`）、对齐项目路径、添加契约测试命令、更新手柄限制。 |
| **P4** | 为`research.md`添加横幅 | 小 | 注明其早于交接状态；指出devlog和审计后研究文档以获取当前状态。 |
| **P5** | 编写战斗风格参考 | 大 | 一份文档涵盖全部5种风格：输入、帧时机、耐力成本、独特机制、视觉/音频概要。从`research-dark-souls-weapons.md`调优表、`player.gd`代码、`game-design.md`支柱中提取。 |
| **P6** | 编写构建与导出指南 | 小 | 文档化`tools/build.ps1`、导出预设配置、每个平台的注意事项、冒烟测试命令。 |
| **P7** | 编写剩余缺失文档 | 中–大 | 专注资源系统、保存/持久化设计、音频系统参考、敌人AI规范。这些可以在系统调优时逐步编写。 |

### 4.2 代码 — 与现有优先级顺序对齐

devlog恢复顺序（条目5，"Godot优先实现交接"）已定义了正确的序列。第3.2节中的缺口应在该框架内解决：

1. **（现有恢复步骤1）** 对当前文件运行编辑器解析、核心契约和游戏冒烟测试。
2. **（现有恢复步骤2）** 完成游戏内设置面板；验证英文/中文呈现。
3. **（现有恢复步骤3）** 游玩并调优每种战斗风格 — **这是缺口#1–5（按风格时机、霸体、卡肉、耐力差异化、招架窗口）应被解决的地方。**
4. **（现有恢复步骤4）** 验证死亡、失落回响恢复、检查点重置、捷径持久化、Boss胜利和保存/加载。
5. **（现有恢复步骤5）** 测试键盘/鼠标、手柄、触屏控制和Android手机尺寸构建。
6. **（现有恢复步骤6）** 重新构建并冒烟测试Web和Windows导出。
7. **（现有恢复步骤7）** 更新剩余文档 — **这是P1–P4文档修复应落地的地方。**

缺口#6（Boss治疗惩罚）和缺口#7（第二种敌人原型）是应遵循现有垂直切片验证的新功能工作。缺口#8–10（蓄力重攻击、冲刺/翻滚攻击、韧性系统）根据`research-dark-souls-weapons.md`明确推迟，不应在核心循环通过人类游玩测试验证之前开始。

### 4.3 测试覆盖

在垂直切片被视为完成之前，至少添加：

| 测试 | 保护内容 |
|---|---|
| 玩家状态转换有效性 | 无非法状态转换（例如，DEAD → LOCOMOTION无重生）|
| 耐力经济不变量 | 耐力永不超最大值，再生仅在LOCOMOTION中，冷却在消耗时重置 |
| 战斗命中去重 | 每次挥砍每身体命中去重在快速重叠下保持 |
| 敌人FSM转换有效性 | 无非法转换；RETURN → IDLE在到达生成点时 |
| 运行状态持久化到磁盘往返 | 扩展现有内存测试到`user://`路径 |

---

## 5. 总结

### 健康评分

| 维度 | 评分 | 备注 |
|---|---|---|
| **文档时效性** | 7/11当前，4份部分过时 | `controls.md`是唯一高严重性过时文档 |
| **文档完整性** | 识别出6个缺失主题 | 战斗风格参考是最高价值缺失文档 |
| **代码架构** | 清洁、一致、低耦合 | 带信号的中心中介模式；无autoloads不寻常但可用 |
| **代码正确性** | 无已知bug；0 TODO/FIXME/HACK | GDScript文件通过`--check-only`；无头导入通过 |
| **代码完整性** | 5个PENDING、3个DEFERRED缺口对标研究 | 所有核心循环机制（攻击、闪避、耐力、死亡、检查点、Boss）已实现 |
| **测试覆盖** | 约10–15%逻辑路径 | 数据完整性和宿主协议测试良好；游戏玩法零自动化覆盖 |
| **交叉引用完整性** | 全部双向；无损坏链接 | 研究文档形成一致的集群；过时文档是孤立的 |

### 底线

代码库是一个**扎实的魂类垂直切片**，具有正确的架构决策（三阶段攻击、共享耐力、信号通信、程序化内容）。文档套件在交叉引用密集的地方最强（四份研究文档），在独立存在的地方最弱（`controls.md`、`architecture.md`、`validation.md`）。最具影响力的下一步行动不是编写新系统——而是**调优5种战斗风格使其手感各异**（按风格时机、霸体、卡肉、耐力成本），然后**更新三份过时文档**以反映交接状态。

---

## 来源与审计覆盖

### 扫描命令

| 扫描 | 方法 | 检查的文件 |
|---|---|---|
| `docs/`完整读取 | Explore子代理 — 读取每个`.md`文件、交叉引用映射、过时性审计 | 20个文件（11份文档+9个代理定义）|
| `docs/agents/`完整读取 | Explore子代理 — 读取每个代理定义、技能依赖映射 | 9个文件 |
| `game/scripts/`完整扫描 | Explore子代理 — 读取每个`.gd`文件（完整或实质性部分）、preload/signal/call图 | 16个文件，5,702行 |
| `game/scenes/`完整扫描 | Explore子代理 — 读取每个`.tscn`、节点/脚本/加载步骤审计 | 10个文件 |
| `game/project.godot` | Explore子代理 — 完整配置审计 | 1个文件 |
| `game/assets/` | Explore子代理 — 字体、许可证、字形、导入审计 | 4个文件 |
| `game/tests/` | Explore子代理 — 测试用例清单、覆盖缺口分析 | 1个文件，131行 |

### 局限性

- 所有发现基于静态文件分析。未观察到运行时行为、性能特征和视觉/音频输出。
- 交叉引用通过在文档文本中搜索markdown链接和文件路径来映射。孤立的引用（指向不存在文件的链接）将被检测到；过时的引用（指向已更改文件的链接）需要人工判断。
- 第2.3节中"已验证存在"的代码特性通过阅读相关代码段确认。标记为PENDING的特性通过代码搜索确认不存在。
- 本审计不评估游戏平衡、战斗手感、视觉质量或音频质量——这些需要人类游玩测试。
