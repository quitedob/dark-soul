# Godot 4.7 动作与战斗招式实现指南

**调研日期：** 2026-07-30  
**项目：** Ashen Hollow  
**扫描范围：** `docs/`、`game/`  
**目标版本：** Godot 4.7；Windows 测试脚本指定 4.7.1-stable

## 核心结论

### 高置信度

1. 项目已经具备部分数据驱动招式层：`AttackData`、`MovesetData`、`WeaponData`、`WeaponArtData`、`GuardProfile` 和兼容工厂均已存在。因此，`docs/systems/attack-moveset-data-schema.md` 中“尚未实现”的状态已经过时。
2. 当前战斗仍主要由 `player.gd` 中的单体计时 FSM 驱动。项目尚未使用 `AnimationPlayer`、`AnimationTree`、动画方法轨道或根运动提取来控制实战攻击。
3. 当前 150 毫秒、只能保存一个动作字符串的输入缓存不是真正的连招系统。它没有招式级连段窗口、来源招式、命中/防御分支、按住/释放信息或队列顺序。
4. `CombatArea` 已形成较好的统一命中载荷边界，并支持一次挥击内的目标去重；但它仍是固定在角色前方的胶囊体。`AttackData` 的多段命中字段未被消费，也不存在武器插槽命中箱或身体部位受击箱。
5. Godot 官方并不强制节点式 HFSM、动画权威伤害或全根运动控制器。这些是项目架构选择，而不是引擎要求。
6. 最稳妥的迁移方式是继续让招式数据和游戏逻辑保持权威。动画可以通过经过验证的适配层请求语义事件，但不能自行改变消耗、合法性、伤害或分支。

### 中等置信度

1. 加入招式级连段窗口后，小型时间戳或物理帧编号动作队列会比单字符串缓存更合适；但数据契约和边界测试比具体存储形式更重要。
2. `AnimationTree` 根运动适合部分攻击动作。相比一次性迁移移动、翻滚、重力、击退及所有攻击，混合控制器更安全。
3. 动画方法轨道可用于发送语义事件，但在混合、跳转、循环、中断、命中停顿和丢帧下的行为必须由项目测试确认，不能直接成为唯一的命中窗口权威。

### 尚未确认

1. Perplexity 在多次缩小查询范围后仍未完整返回 Godot 4.7 官方资料，因此论坛、视频、镜像及无关来源中的断言未被视为官方结论。
2. Godot 4.7 对循环自定义 `Resource` 引用的安全序列化保证没有得到确认。连招链接应暂时使用动作 ID 或索引，并通过 4.7.1 保存/加载测试验证。
3. `AnimationTree` 混合和 seek 情况下方法轨道的完整投递保证仍未确认。

## 项目文档可靠性

| 文档 | 状态 | 结论 |
|---|---|---|
| `docs/systems/attack-moveset-data-schema.md` | 部分可靠 | 所有权设计合理，但实现状态过时，多个字段尚未接入运行时。 |
| `docs/systems/combat-execution-guard-weapon-arts.md` | 可靠 | 能正确区分当前原型与目标战斗架构。 |
| `docs/tasks/combat-expansion-roadmap.md` | 过时 | 顺序仍有参考价值，但早于当前部分招式资源实现。 |
| `docs/architecture.md` | 部分可靠 | FSM 和动画现状准确，部分旧数据所有权描述已经过时。 |
| `docs/controls.md` | 可靠 | 当前按键和计划功能大体符合运行时代码。 |
| `docs/systems/combat-styles.md` | 过时 | 战斗幻想仍有价值，但部分时序和所有权已与代码不符。 |
| `docs/tasks/d-01-root-motion-setup.md` | 部分可靠 | 渐进式移动模式合理；回调 API 需要核实，`CharacterBody3D` CCD 建议缺乏依据。 |
| `docs/tasks/e-04-parry-windows.md` | 矛盾 | 标记完成，但验收项和部分时间值与运行时不一致。 |
| `docs/tasks-master.md` | 矛盾 | 未区分资源类存在、运行时采用和功能完成。 |

## 当前实现审计

### 输入与状态

- `InputConfigurator` 在运行时创建键盘、鼠标和手柄动作。
- 玩家以固定优先级处理语义化左右手动作及旧兼容动作。
- 一个缓存动作可在部分非移动状态下保留 `0.15` 秒。
- 玩家 FSM 包含移动、攻击三阶段、翻滚、弹反、盾击、跳劈、施法、硬直和死亡。
- `_change_state()` 集中处理状态进入和退出副作用，但没有合法转换图。
- 防御是仅在移动状态可用的叠加行为，而不是独立状态。

### 招式数据

- 普通轻击、重击和跳劈已经使用兼容工厂生成的 `AttackData`。
- `MovesetData.resolve()` 显式解析上下文，不支持的上下文会返回 `null`。
- 当前 `AttackData` 已拥有基础阶段时长、消耗、伤害、位移、动作韧性和多段命中配置。
- 连段窗口、后续招式、消耗发生时机、转向限制、命中箱形状/插槽/偏移和根运动模式仍缺失或未生效。
- 战技及部分左右手动作仍采用硬编码分派。

### 命中检测与动画

- `CombatArea` 动态创建胶囊体，在攻击期间开启监测，标准化命中元数据，并对目标去重。
- 它直接检测角色物理体，没有专用受击箱或身体区域协议。
- 攻击区域固定在角色前方，没有附着在武器插槽上。
- `maximum_hits_per_target` 和 `repeat_hit_interval_seconds` 尚未被使用。
- 玩家视觉完全由程序化姿势驱动；`AttackData.animation_name` 尚未使用。
- `authored_displacement.z` 当前实际上按速度使用，名称却表达总位移，导致攻击距离会受主动阶段时长影响。

## 推荐动作架构

### 1. 保持单一游戏逻辑权威

游戏逻辑应负责：

- 动作是否合法；
- 耐力、专注等资源检查与扣除；
- 招式选择和分支；
- 当前招式时间和阶段；
- 命中载荷和目标合法性；
- 取消、中断和恢复；
- 状态转换和异常回退。

动画只消费已选中的招式，并可请求 `commit`、`active_started`、`active_ended`、`branch_point` 等语义事件。控制器必须根据当前招式实例和状态验证事件后才能执行。

`animation_name` 只能作为表现资源索引，不能作为游戏动作 ID。

### 2. 渐进扩展 `AttackData`

建议优先增加：

```gdscript
@export_group("Timeline")
@export var buffer_open_seconds := 0.0
@export var chain_open_seconds := 0.0
@export var chain_close_seconds := 0.0
@export var dodge_cancel_seconds := -1.0

@export_group("Chains")
@export var next_light_id: StringName
@export var next_heavy_id: StringName
@export var on_hit_followup_id: StringName
@export var on_guard_followup_id: StringName

@export_group("Hitbox")
@export var hitbox_socket: NodePath
@export var hitbox_shape: Shape3D
@export var hitbox_offset := Transform3D.IDENTITY
```

在确认循环 `Resource` 序列化安全之前，后续招式优先使用 ID，不直接互相引用 `AttackData`。验证器应拒绝无效窗口、缺失链接、意外自循环、标签冲突、无有效间隔的多段攻击及缺少命中箱数据的物理攻击。

### 3. 用动作记录替换单字符串缓存

```gdscript
class_name BufferedCombatAction
extends RefCounted

var action_id: StringName
var pressed_at_tick: int
var released_at_tick := -1
var requested_context: StringName
var consumed := false
```

实现规则：

1. 缓存语义动作，而不是原始按键。
2. 使用小型有界队列，初期保存 2–4 个记录即可。
3. 根据招式定义的窗口过期，不使用唯一全局窗口。
4. 在消费时解析当前上下文，同时保留原始动作意图。
5. 每条记录只能消费一次，并在调试模式记录拒绝或过期原因。
6. 明确定义同时输入时的优先级并添加测试。
7. 点击、按住、释放和蓄力应使用不同语义。

Godot 提供 `InputMap` 和动作轮询，但没有内置的类 Souls 战斗输入缓存。

### 4. 将连招建模为受验证的转换

连招转换至少需要检查：

- 来源攻击 ID；
- 请求的语义动作；
- 来源招式已经过的时间；
- 命中、防御、挥空或弹反结果；
- 耐力和专注；
- 当前移动上下文；
- 中断和取消规则；
- 当前招式表中是否存在目标动作。

只有分支真正合法时才提交目标招式和扣除资源。缓存输入不代表攻击一定执行。

### 5. 同步动画而不交出游戏权威

第一个动画攻击应按以下顺序实现：

1. 游戏逻辑选择 `AttackData`。
2. 播放该数据指定的动画。
3. 在物理时间中推进游戏招式时间线。
4. 对比动画进度与游戏阶段边界。
5. 通过验证适配器接收语义动画事件。
6. 动画缺失、中断或失配时保留计时回退。

不要把所有计时器替换成动画长度轮询。输入过期、耐力恢复延迟、韧性恢复、冷却、无敌帧等规则独立于表现系统。

命中停顿必须明确规定：游戏招式时间是否暂停、动画是否暂停、输入缓存是否继续、其他物理对象是否继续，以及命中箱是否保持激活。

### 6. 仅对合适动作引入根运动

建议保留三种移动模式：

- `CODE_DRIVEN`：移动回退、翻滚、重力、击退和边缘处理；
- `ANIMATION_DRIVEN`：少量具有明确脚步和位移的攻击；
- `HYBRID`：代码负责方向与碰撞，动画提供受限的平面位移。

实现前必须在本机 Godot 4.7.1 类参考中确认 `AnimationTree` 根运动方法和 `AnimationMixer.callback_mode_process` 的准确名称与语义。

`CharacterBody3D` 没有已确认的 CCD 开关。应删除文档中“启用 CharacterBody3D continuous CD”的建议，改为测试受限位移、子步进、`move_and_collide()` 或形状投射。

### 7. 使用招式定义的命中箱和插槽

推荐顺序：

1. 先让当前 `CombatArea` 支持最大命中次数和重复间隔。
2. 允许 `AttackData` 提供形状和局部偏移。
3. 把攻击区域附着到稳定的武器插槽或战斗标记。
4. 只有在需要身体区域机制时才引入专用受击箱。
5. 所有命中结果继续通过当前标准化载荷边界。

命中箱只报告接触；攻击实例负责每目标命中次数；防御者负责弹反、防御、韧性和生命结算；招式控制器记录命中、防御或挥空结果用于分支。

如果在重叠回调中修改监测、碰撞层、形状或节点，应使用延迟修改，避免在物理查询刷新期间直接改变查询状态。

### 8. 在引入 HFSM 前保持一个状态权威

先增加合法转换规则、明确的招式实例、状态进入/退出测试、叠加状态所有权和中断清理保证。如果 `player.gd` 仍然过大，可以提取纯状态处理器，但继续保留唯一权威状态值。

应避免枚举 FSM、节点 FSM 和 `AnimationTree` 状态机同时成为游戏逻辑权威。

## 分阶段实施计划

### 阶段一：先保证正确性

1. 修复 `dagger_feint` 等没有运行时分支的动作 ID。
2. 增加测试，确保每个装备动作都能解析或明确标记为不支持。
3. 修正位移命名，或根据目标总位移和阶段时长计算速度。
4. 实现每目标命中次数和重复命中间隔。
5. 为弹反、翻滚无敌、攻击激活窗口和去重增加边界测试。

### 阶段二：数据化动作转换

1. 增加每招式缓存、连段和取消窗口。
2. 增加有界动作记录和确定性优先级。
3. 增加基于 ID 的轻击、重击及命中/防御分支。
4. 将盾击、突刺、跳劈和战技迁移到资源。
5. 为敌人攻击补充 ID、标签、可防御性、可弹反性和防御伤害。

### 阶段三：提升碰撞精度

1. 增加每招式命中箱形状和偏移。
2. 将命中箱附着到武器插槽或战斗标记。
3. 仅为实际需要的机制添加身体区域受击箱。
4. 测试激活时已经重叠、重新进入、多物理体目标、中断和高速移动。

### 阶段四：单一动画试点

1. 为一个直剑攻击加入 `AnimationPlayer`/`AnimationTree`。
2. 保持游戏计时权威。
3. 通过适配器加入语义动画事件。
4. 记录并比较游戏阶段与动画阶段。
5. 验证混合、中断、seek、暂停、命中停顿和回退。

### 阶段五：可选根运动

1. 只在试点攻击中使用根运动。
2. 测试斜坡、墙壁、楼梯、薄障碍、悬崖、锁定转向和中断。
3. 比较 30、60、120 和 144 Hz。
4. 重力、翻滚、击退及回退继续由代码驱动。
5. 只有碰撞和同步测试通过后才扩展到其他动作。

## 审计清单

- [ ] 每个语义动作都有明确的键鼠、手柄和移动端策略。
- [ ] 已测试扳机死区、重复绑定和同时输入优先级。
- [ ] 缓存记录只消费一次，点击、按住、释放和蓄力相互独立。
- [ ] 每个动作有稳定 ID，并能通过验证。
- [ ] 每个状态转换合法，中断会关闭命中箱并清理动作效果。
- [ ] 连段、取消和结果分支窗口由招式数据定义。
- [ ] 动画名称只用于表现，动画缺失时存在回退。
- [ ] 动画语义事件会根据当前招式实例验证。
- [ ] 根运动有碰撞测试和代码回退。
- [ ] 命中箱形状、插槽、偏移和多段规则由招式拥有。
- [ ] 防御结算顺序明确并有测试。
- [ ] 所有重要窗口都测试前一刻、边界时刻和后一刻。
- [ ] 已检查 30、60、120、144 Hz、暂停和命中停顿。
- [ ] smoke 测试包含在文档化的总测试命令中。
- [ ] Godot 4.7.1 下资源保存/加载和缺失链接验证通过。

## Godot 4.7 兼容性说明

1. 项目声明 4.7，而 Windows 测试脚本指定 4.7.1-stable；应统一最低引擎版本和 CI 可执行文件。
2. 实现根运动前，确认 4.7.1 中 `AnimationTree` 根运动 API 和 `AnimationMixer.callback_mode_process`。不要直接复制现有任务文档中的旧式常量写法。
3. 运行时 `InputMap` 配置是可行的项目选择，但项目文件中看不到完整绑定。配置必须保持幂等，并在真实手柄上测试扳机轴和死区。
4. 自定义资源和类型化导出适合招式数据。循环资源链接仍有序列化风险，优先使用 ID。
5. `Area3D` 重叠检测不能保证高速武器连续接触，必须使用项目级扫掠或子步进测试。
6. 应确认仓库内 GUT 版本支持 Godot 4.7，并使用同一个引擎执行单元、集成和 smoke 测试。

## 来源

以下来源于 2026-07-30 的 Perplexity 调研。由于服务未完整满足“仅官方 Godot 4.7 来源”要求，因此明确区分来源质量。

### 官方或主要来源

- [Godot binary serialization API](https://docs.godotengine.org/en/stable/tutorials/io/binary_serialization_api.html) — 官方资料，但不足以证明循环自定义 `Resource` 的安全性。
- [Godot finite state machine demo, 4.0 branch](https://github.com/godotengine/godot-demo-projects/tree/4.0/2d/finite_state_machine) — 官方 MIT 示例；可参考模式，但不是 Godot 4.7 战斗架构要求。
- [Godot AnimationTree tutorial](https://docs.godotengine.org/en/latest/tutorials/animation/animation_tree.html) — 官方链接；Perplexity 未证明访问时 `latest` 是否精确对应 4.7。

### 社区示例

- [GDQuest Godot 4 hitbox/hurtbox demo](https://github.com/gdquest-demos/godot-4-hitbox-hurtbox) — MIT 社区示例，不是引擎规定。
- [Input buffer discussion](https://forum.godotengine.org/t/where-to-start-when-making-an-input-buffer-system/141330) — 仅社区讨论。
- [AnimationTree physics discussion](https://forum.godotengine.org/t/can-i-drive-physics-from-an-animationtree/134190) — 仅社区讨论。

实现前应在本机 4.7.1 编辑器中核对 `AnimationTree`、`AnimationMixer`、`CharacterBody3D`、`Area3D`、`InputMap`、`Input`、`InputEventJoypadMotion`、`Resource` 和自定义资源导出属性的类参考。

## 矛盾与缺口

1. 招式架构文档称资源尚不存在，但五个资源类和兼容测试已经存在。
2. 根运动任务强调动画驱动角色，而招式架构要求动画和游戏逻辑共同消费数据；应采用共享数据和游戏验证。
3. 根运动任务推荐了未找到的 `CharacterBody3D` 连续碰撞设置。
4. 当前输入缓存无法表达文档中的数据化连招。
5. 当前攻击区域不能实现武器插槽、低扫、弱点或数据化多段命中。
6. 项目状态应分别记录：架构定义、兼容生成、独立资源、运行时采用、测试覆盖和生产完成度。
7. 循环资源和方法轨道边界行为仍缺少可靠的 Godot 4.7 官方保证。

## 搜索覆盖

- 子代理扫描了战斗设计、架构、控制、任务和路线图文档。
- 独立子代理扫描了项目设置、玩家/敌人 FSM、输入、资源、攻击区域、场景和测试。
- 反证代理审查了输入缓存、HFSM、动画事件、根运动、Resource 和 Area3D 建议。
- Perplexity 执行了一次深度调研、一次纠偏跟进和一次仅官方来源查询。
- 未把插件内部实现和生成的 `.godot` 文件作为游戏逻辑证据。
- 本次未运行测试，也未修改战斗代码。
- 缺少官方证据的网络断言已被标记或拒绝。
