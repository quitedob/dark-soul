# 研究报告 — 原始魂系垂直切片 (Research Report — Original Soulslike Vertical Slice)

访问日期: **2026-07-29**

## 范围与方法 (Scope and Method)

本报告将广泛的魂系游戏类型规范转化为一个小型、原创的 Godot 4.7 原型。它不复制任何商业游戏的受保护名称、传说、角色、对话、地图、音乐、美术或数据。

研究使用了 Perplexity 深度研究和针对性后续搜索，然后通过官方 Godot 文档和本地 Godot 4.7.1 CLI 帮助验证引擎声明。最初的广泛 Perplexity 结果提供了有用的分类，但未返回任何来源列表，因此无依据的数值声明被丢弃。本项目中的原型出招时机和消耗数值是明确的、需要游戏测试的设计建议，而非来源化的事实。

## 关键发现 (Key Findings)

### 高度确信 — 将战斗结构化为明确的计时状态

一个刻意的近战攻击在分解为前摇、判定帧和后摇状态时，更易于理解和测试。伤害仅存在于判定帧期间。移动、旋转、耐力消耗、输入缓冲和取消规则可以按状态定义，而非隐藏在动画播放内部。

**原型决策：** 游戏状态是权威的。过程化姿态传达状态，`Area3D` 判定体仅在判定帧区间内激活。这避免了帧率相关的命中检测，并使导入动画成为可选项。

实现参考：

- [Area3D 类](https://docs.godotengine.org/en/stable/classes/class_area3d.html) — 文档描述了可监控的3D区域以及命中体和交互体使用的 `body_entered`/`body_exited` 信号。
- [使用 AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) — 支持后续从过程化姿态升级到动画状态机和混合。

### 高度确信 — 保持移动和相机碰撞为引擎原生

`CharacterBody3D` 是为用户控制实体设计的，通过 `move_and_slide()` 提供碰撞感知移动。当几何体遮挡期望的相机距离时，`SpringArm3D` 会将子相机节点移向其原点。

**原型决策：** 玩家和敌人使用 `CharacterBody3D`；相机位于偏航/俯仰旋转轴和 `SpringArm3D` 之下。锁定改变期望朝向和相机瞄准，但不替代碰撞处理。

实现参考：

- [CharacterBody3D 类](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) — 关于速度、地面检测和 `move_and_slide()` 的权威API参考。
- [3D运动学角色移动](https://docs.godotengine.org/en/stable/tutorials/physics/kinematic_character_3d.html) — `CharacterBody3D` 的官方移动教程。
- [SpringArm3D 类](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html) — 权威的相机遮挡API。
- [使用弹簧臂的第三人称相机](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html) — 官方设置模式和碰撞行为。

### 高度确信 — 使用小型显式FSM建模敌人行为

垂直切片从少量可检查的状态中获益更多，而非大型行为框架。导航应回答"该实体下一步应移向何处？"，而战斗状态仍然控制敌人是否被允许移动或攻击。

**原型决策：** 敌人使用空闲、追逐、前摇、判定帧、后摇、硬直、返回和死亡状态。当地图同步时，`NavigationAgent3D.get_next_path_position()` 提供追踪方向；直接的转向回退在前几帧中保证原型安全。

实现参考：

- [NavigationAgent3D 类](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) — 文档描述了目标位置、路径更新、避让和 `get_next_path_position()`。
- [使用 NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html) — 警告路径更新必须从物理处理中调用，并解释代理同步。
- [导航概述](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html) — 描述地图、区域、网格、链接和代理。

### 高度确信 — 将耐力视为动作经济，而非装饰

只有当动作有不同的消耗且恢复无法立即消除每次承诺时，耐力才使选择有意义。确切数值是游戏特定的，需要游戏测试。

**原型建议：** 移动免费；冲刺、攻击和闪避消耗耐力。消耗后恢复短暂暂停。攻击未满足全部消耗时无法开始。HUD 结合了进度条和数值状态，因此耗尽不仅通过颜色传达。

初始原型目标为最大耐力100，轻攻击消耗20，重攻击消耗38，闪避消耗26。这些数值是假设，而非研究得出的常量。

### 中度确信 — 锁定应优先可读目标并优雅失败

锁定在近距离近战中很有用，但当目标移动到墙后、超出范围、死亡或聚集时会变得令人迷惑。

**原型建议：** 按相机面向角度和距离评分候选目标，强制执行有限范围，自动释放无效/死亡目标，未锁定时可手动操作相机，并显示非单一颜色目标标记。未来工作应添加遮挡排除和右摇杆/鼠标目标切换。

### 高度确信 — 检查点应压缩重复内容

对于短原型，检查点可以承担多个技术和节奏角色：建立重生点、恢复玩家状态、重置敌人，并提供学习操控的安全场所。捷径通过减少失败后的重复穿越来奖励空间理解。

**原型建议：** 休息治疗并复活敌人。死亡将携带的烬火掉落为一个可回收的回声；后续死亡替换它。捷径在当前运行期间保持开启。持久化存档文件有意推迟。

存档系统参考：

- [保存游戏](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) — 添加持久化时用于识别持久化节点并将状态写入 `user://` 的官方模式。

### 高度确信 — 无障碍必须设计到反馈和输入中

重要状态不应仅依赖颜色。键盘替代方案、可读文本、可调节相机行为、重要音频的字幕或文本等效内容以及可重映射的动作应独立于难度调校予以考虑。

**现已实现：** 鼠标攻击和锁定的键盘替代方案；文本提示；数值和进度条反馈；目标标记；持久帮助覆盖层；无不必要的仅音频信息。

**建议下一步：** 完整按键映射UI、手柄支持、相机灵敏度滑块、独立的X/Y反转、文字缩放、减少动态效果、屏幕震动控制以及可选的战斗辅助。

无障碍参考：

- [游戏无障碍指南](https://gameaccessibilityguidelines.com/) — 按基础、中级和高级影响/成本分组的实用指导。
- [游戏无障碍指南完整列表](https://gameaccessibilityguidelines.com/full-list/) — 包括按键重映射、颜色替代方案、文字呈现、相机运动和音频指导。
- [Xbox 无障碍指南](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines) — 关于输入、视觉、音频、认知和测试考量的官方平台指导。
- [Microsoft 游戏无障碍概述](https://learn.microsoft.com/en-us/gaming/game-design/accessibility) — 无障碍优先的游戏设计和测试指导。

### 高度确信 — 使用确切的引擎可执行文件进行验证

已安装的可执行文件报告 `4.7.1.stable.official.a13da4feb`。其本地 `--help` 输出确认了 `--headless`、`--editor`、`--import`、`--quit`、`--quit-after` 以及用于用户参数的 `--` 分隔符。

**原型决策：** 使用请求的控制台可执行文件运行编辑器导入、有界无头游戏玩法和专用的 `--smoke-test` 用户参数。

参考：

- [命令行教程](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) — 官方CLI标志和自动化模式。

## 实用实现顺序 (Practical Implementation Sequence)

1. 在灰盒竞技场中创建碰撞安全的玩家控制器和相机。
2. 添加耐力并完成一个完整的轻攻击状态循环。
3. 添加伤害区域、无敌帧、硬直、死亡和重置。
4. 使用相同的战斗时序词汇添加一个敌人。
5. 仅在自由视角战斗运作之后添加锁定。
6. 构建包含检查点和捷径的紧凑路线。
7. 通过重调并扩展现有的敌方架构添加守护者。
8. 添加HUD/音频/视觉反馈，然后进行无头烟雾测试。
9. 游戏测试消耗和时序；仅在观察到失败模式时才更改常量。

## 矛盾与缺口 (Contradictions and Gaps)

- Perplexity 的首次深度研究响应提供了广泛的设计指导，但未返回任何来源URL。因此本报告将这些元素标注为建议，并依赖官方引擎/无障碍来源获取可验证的声明。
- Godot 在线 `stable` 文档可能在 4.7 后移至更新的次要版本。引擎API通过运行已安装的4.7.1版本进行验证；链接保持 `stable`，因为永久4.7分支可能尚未发布。
- 此原型使用过程化姿态而非创作的动画片段。它验证了状态时序和游戏架构，但未验证最终的动画混合、根运动、运动匹配或制作质量的命中对齐。
- 无头测试无法评估相机舒适度、前摇可读性、感知公平性、视觉构图或音频混音。这些需要人工在图形构建中进行游戏测试。
- 导航在使用烘焙的 `NavigationRegion3D` 时效果最佳；由于此项目在运行时生成几何体，第一版允许直接转向回退。后期的创作关卡应烘焙导航并显式测试狭窄通道。
- 没有单一权威来源定义正确的耐力消耗、闪避无敌帧持续时间或敌人出招时机。这些是调校变量，不应从其他游戏中复制。

## 建议 (Recommendations)

- 保持此垂直切片规模较小，直至完整的死亡/恢复/Boss循环可玩。
- 仅在游戏状态时序通过测试后添加导入动画；动画应呈现规则，而非秘密定义它们。
- 进行短时基于观察的游戏测试并记录：错过的攻击前摇、意外解除锁定、相机碰撞、耐力困惑、重复穿行的挫败感以及按原因分类的守护者死亡情况。
- 将无障碍选项视为正交控制，而非单一的"简单模式"。
- 如果原型扩展，将调校常量移入 `Resource` 数据资源，并将世界进度保存在 `user://` 下。

## Godot 技能搜索 (Godot Skill Search)

在开发开始时，本地 Claude 技能或插件缓存下未安装任何 Godot 专用的 `SKILL.md`。因此本项目遵循官方 Godot 文档和直接引擎验证，而非安装未经审阅的第三方技能。这避免了在空白工作区中引入不透明的指令或可执行依赖。
