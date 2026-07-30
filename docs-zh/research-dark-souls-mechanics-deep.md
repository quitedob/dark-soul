# 研究 — Dark Souls 机制深度解析：帧数据、Poise 数学与 Godot 实现

**日期：** 2026-07-30
**状态：** `ACTIVE` — 研究已完成；帧数据、Poise 公式和 Godot 模式已整理成文档
**参见：** [`research-dark-souls-design.md`](research-dark-souls-design.md) — 12 主题 DS 设计审计，垂直切片检查清单
**参见：** [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) — 每种风格的武器调校、Hit-stop、Hyper Armor、音频分析
**参见：** [`research-github-godot-soulslike-ecosystem.md`](research-github-godot-soulslike-ecosystem.md) — GitHub 仓库、Godot 资源库模板、生态系统调研
**参见：** [`research.md`](research.md) — 原始垂直切片研究，Godot API 映射

研究于 2026-07-30 进行。本报告提供 Dark Souls 战斗机制的帧级别细节——i-frame 持续时间、弹反窗口帧数、Poise Health 数学公式及详细计算示例、属性缩放曲线，以及相应的 Godot 实现模式。它是对 [`research-dark-souls-design.md`](research-dark-souls-design.md) 中更广泛设计审计的补充，提供了在 GDScript 中实现这些系统所需的精确数值与架构深度。

---

## 来源可靠性声明

本报告采用三级证据分类：

| 标签 | 标准 |
|---|---|
| **可观察规则** | 可通过游戏可执行程序行为、社区帧数据分析（wikidot、fextralife）或官方攻略数据验证。帧数因版本/补丁而异，应视为方向性参考。 |
| **开发者意图** | 需要来自可考证、可访问的采访或官方出版物中的具名开发者引述。 |
| **分析** | 基于可观察机制构建的解读。未经开发者确认；必须标注为分析。 |

本报告中的帧数据值均以 **30 FPS 参考基准**（DS1 基线）为社区估算值，并提供 60 FPS 等效值。精确帧数因游戏版本（DS1 vs DS3 vs Elden Ring）和补丁而异。各分类之间的比率和相对差异比绝对数值更可靠。所有数值应视为调校起点，而非规范标准。

---

## 1. 核心设计哲学：经典复兴与机制叙事

### 1.1 挑战作为满足感的催化剂

宫崎英高的设计哲学从根本上拒绝现代商业游戏中盛行的"动态难度调整"和"手把手教程"。其核心逻辑建立在对玩家智力的绝对尊重之上——极端难度充当催化剂，迫使玩家通过反复失败、深度系统学习和肌肉记忆，最终获得无与伦比的成就感，即学者所称的"游戏崇高感"（ludic sublime）。

### 1.2 回归 NES 时代的经典设计

在动作设计上，Dark Souls 本质上是对 NES 时代经典游戏设计的回归。现代动作游戏（如 Batman: Arkham 系列）通常采用"磁性"战斗系统——按下攻击键后，角色会自动滑向敌人并进行角度修正。Dark Souls 刻意剥离了这些底层辅助——系统将动作分解为离散的、不可撤销的输入指令。如果玩家在错误的时机按下攻击、或朝向错误的方向，角色将毫不妥协地挥空，完全暴露自身破绽。

**分析：** 这种"所见即所输"的哲学要求玩家具备精确的距离感和站位意识，确保游戏"难，但绝对公平"。

### 1.3 Godot 实现：输入缓冲与不可中断状态机

在 Godot 中复现这种经典操控手感需要两大技术支柱：**输入缓冲**和**不可取消的状态机**。

开发者不能依赖简单的 `if-else` 链来控制角色状态。需要基于 `AnimationTree` 和 `AnimationNodeStateMachine` 构建严格的架构。在特定攻击动画帧结束之前，系统必须完全阻止玩家的移动或闪避输入，直到恢复阶段进入可取消窗口。这在代码中通过读取 AnimationPlayer 的当前播放位置或通过关键帧触发的信号来实现。

**核心原则：** 真正的 Souls-like 手感往往不是来自更复杂的输入，而是来自更严格的"何时不能行动"。游戏通过可预测性而非宽容度来传达对玩家的尊重。

### 1.4 环境叙事与叙事架构

Dark Souls 的另一基石是**环境叙事**（environmental storytelling，也称为**嵌入式叙事** embedded narrative）。传统 RPG 依赖冗长的 NPC 对话和过场动画来推进剧情；Souls 游戏则将其庞大的世界观打碎成片段，散落在场景布置、物品描述、甚至敌人的摆放位置之中。

学者 Henry Jenkins 提出的**叙事架构**（narrative architecture）概念在 Souls 游戏中得到了完美体现。叙事并非线性时间结构，而是空间信息的总和。例如，面对吞噬神明的艾尔德利奇时，游戏从未播放任何解说性过场动画。取而代之的是，玩家击败 Boss，在物品描述中读到"艾尔德利奇的红玉"，并观察到亚诺尔隆德被腐化的视觉奇观——自行拼凑出这位薪王们悲剧的历史。

**Godot 实现关联：** 环境叙事要求关卡不仅仅是战斗背景，而是承载信息的数据库。利用 Godot 的 `MeshLibrary` 和模块化场景实例化，开发者在每个角落、每具尸体旁放置带有独立数据结构的物品节点，通过背包系统的文本词典，以无言的方式传递历史的碎片。

---

## 2. 关卡设计：空间记忆与垂直盒庭拓扑

### 2.1 互联世界与循环时间

初代 Dark Souls 的地图设计——尤其是以传火祭祀场为枢纽的上半部分——至今仍是 3D 关卡设计的巅峰之作。其标志性特征是极致的**垂直性**和**互联性**。

游戏刻意移除了小地图和任务标记，迫使玩家利用环境地标和视线构建认知地图。其精妙之处在于对玩家心理状态的精确操控：当玩家在危险的未知区域筋疲力尽、补给耗尽时，突然发现一扇单向门或一个可踢下的梯子——穿过捷径发现自己回到了数小时前离开的安全区（篝火）——从极度焦虑到瞬间释然的情绪落差，构成了无可比拟的游戏体验。

**分析：** 这种通过空间捷径折叠游戏时间的设计，在学术文献中被概括为"循环时间与终结时间"的空间-叙事循环。

### 2.2 Godot 灰盒原型与场景管理

在 Godot 中实现这种复杂的垂直盒庭结构：

1. **灰盒/体块阶段：** 使用 Godot 内置的 CSG（Constructive Solid Geometry）节点或 `GridMap` 工具进行粗略关卡原型制作。调整不同区域的视线高度，放置遮挡视野的障碍物，精确控制从特定位置可见的地标——实现无形的技能门槛引导。

2. **场景流式加载：** 因为 Souls 地图广阔且无缝连接，Godot 的场景流式加载至关重要。开发者不能将整个世界一次性加载到内存中。取而代之的是，基于 `Area3D` 的触发体积检测玩家是否接近特定通道或电梯，并在后台线程上异步加载相邻场景树区块——从技术上保证沉浸式的无缝探索。

### 2.3 视线与探索引导

使用三层结构：
- **远距离地标：** 告诉玩家"那里是我的目标"。
- **中距离威胁：** 制造谨慎推进的紧张感。
- **近距离奖励：** 引诱分支探索。

不要在每个角落放置发光宝箱。不要把所有好东西都放在主路中线上。Souls-like 的探索快感来自玩家自行将风险解读为机遇。

---

## 3. 动作机制：帧数据的微观博弈

Souls 战斗的深度建立在严密的动作帧数据之上。起手（前摇）、无敌帧（i-frames）、弹反窗口和恢复帧，共同构成玩家与敌人之间的全部微观博弈。

### 3.1 Root Motion：动画驱动位移的必要性

在传统动作游戏中，角色位移通常由代码控制（例如直接修改 `velocity`），动画作为运动之上的视觉叠加层——容易产生"滑冰"现象。在 Souls-like 游戏中，为了传达重型武器的物理重量和惯性，**Root Motion** 是一项必不可少的底层技术。

在 Godot 4 中，成熟的 Souls-like 模板（如 catprisbrey 的模块化模板）深度集成了 Root Motion。开发者在 Blender 中将角色的绝对位移烘焙到根骨骼的动画轨道中。当动画通过 Godot 的 `AnimationTree` 播放时，系统提取根骨骼的位移和旋转增量，在 `_physics_process` 中应用到 `CharacterBody3D` 的实际物理坐标上。

**核心洞察：** 角色向前踏出的距离完全由动画师决定，使每次攻击和闪避都具备无与伦比的扎实感和重量感。

### 3.2 闪避机制与 I-Frame 矩阵

翻滚闪避是 Dark Souls 的核心伤害规避工具。游戏根据装备负重百分比将翻滚严格分为三个等级。基于 30 FPS 基线逻辑，i-frame 数据直接决定生存概率。

#### 翻滚类型对比

| 翻滚类型 | 装备负重阈值 | 30 FPS I-Frames | 60 FPS 等效值 | 特征 |
|---|---|---|---|---|
| 快速翻滚 | < 25% | 13 帧（~0.433s） | 26 帧 | 位移最长，恢复最短，极致机动性 |
| 中速翻滚 | 25% – 70% | 11 帧（~0.366s） | 22 帧 | 位移适中，恢复适中——平衡甜点区 |
| 沉重翻滚 | > 70% | 9 帧（~0.300s） | 18 帧 | 位移极短，背部砸地，灾难性长恢复 |
| 忍者翻转（暗木纹戒指） | < 25%（装备戒指） | 15 帧（~0.500s） | 30 帧 | 动作变为忍者后空翻；游戏中 i-frame 窗口最宽 |

#### 设计分析："向攻击方向翻滚"哲学

与 Monster Hunter: World（基础翻滚 i-frames：约 0.267s）相比，Dark Souls 给予玩家慷慨的 0.433s 无敌时间。这一设计并非为了降低难度——它鼓励玩家**向攻击方向翻滚穿过去**。如果角色的 i-frames 完全覆盖了敌人武器 hitbox 的重叠时间，玩家受到零伤害。反之，如果玩家因恐惧向后翻滚，i-frames 往往在敌人武器 hitbox 仍与角色模型重叠时已经过期——导致残酷的"翻滚被抓"。

**Godot 实现：** 闪避状态必须在一个较长的运动状态中激活一个短暂的 `invulnerable = true` 窗口。i-frame 持续时间是一个调校常量，而非代码结构。在 `_physics_process` 中，当 `invulnerable` 为 true 时，传入的伤害调用被静默丢弃。

```gdscript
# 闪避状态 — 简化版
var i_frame_remaining := 0.0
const I_FRAME_DURATION := 0.366  # 中速翻滚：30fps 下 11 帧

func start_dodge() -> void:
    i_frame_remaining = I_FRAME_DURATION
    invulnerable = true
    stamina -= dodge_cost
    stamina_regen_cooldown = 0.6

func _physics_process(delta: float) -> void:
    if i_frame_remaining > 0.0:
        i_frame_remaining -= delta
        if i_frame_remaining <= 0.0:
            invulnerable = false
```

### 3.3 弹反与处决：极限反应窗口

弹反机制要求玩家在极窄的时间窗口内格挡敌人攻击，以换取一次高额伤害的处决。不同弹反工具在启动帧和有效帧上差异巨大。

#### 弹反工具帧数据

| 弹反工具 | 启动帧数 | 有效弹反帧数 | 恢复帧数 | 战术分析 |
|---|---|---|---|---|
| 护手带（拳套） | 8 | 8 | 中等 | 最快启动——适合反应弹反。但挥空会耗尽全部精力并承受极高伤害。 |
| 靶盾 / 小圆盾 | 8 | 10 | 极长 | 快速启动 + 最长有效窗口。容错率最高的专业弹反工具，但挥空惩罚极为残酷。 |
| 小盾 | 12 | 12 | 中等 | 有效时间长但启动较慢。需要预判。提供一定的常规防御能力。 |
| 中盾 | 14 | ~6 | 极长 | 最慢启动 + 最小窗口。仅适用于"预置弹反"——先防御第一击，再弹反第二击。 |

#### 部分弹反机制

当敌人攻击（即使是不可弹反的巨型箭矢）在弹反有效帧之外、但在特定动画缓冲帧之内命中时，玩家承受部分伤害和大量精力损耗，但不会受到硬直（hitstun/stagger），并且在此期间获得额外的 Hyper Armor。速通玩家经常利用这一高级机制来硬抗致命攻击，强行突破防线。

**Godot 实现考量：** Ashen Hollow 的 Reliquary Guard 风格具有弹反输入。当前实现使用统一的弹反窗口。为实现差异化，弹反窗口持续时间应按盾牌类型通过 `Resource` 字段进行调校。小盾获得更宽的窗口；中盾窗口较窄但可以先进行防御。

---

## 4. Poise 与 Hyper Armor 计算模型

Poise 系统是 Dark Souls 底层逻辑中最复杂且最具争议的模块。从 DS1 的"被动 Poise"（重甲 = 站桩硬抗）到 DS3 的"动态 Hyper Armor"，该系统的演变达到了极致的精确性。

### 4.1 隐藏的"Poise Health"与倍率公式

在 Dark Souls 3 中，防具上显示的 Poise 值不再提供绝对的抗硬直免疫。取而代之的是，它转换为一个**Poise Damage Reduction（PDR）** 百分比。系统运行一个隐藏的 **Poise Health（PH）** 变量，上限为 100。Poise 仅在玩家挥动具有 Hyper Armor 属性的武器时（例如大剑、特大剑）才会激活。

每种武器的特定攻击动画提供一个**Weapon Attack Modifier（WAM）**。判定玩家是否在挥砍中被硬直的公式为：

```
Settled Poise Health = (Base_PH × WAM) − [(1 − PDR) × Enemy_Poise_Damage]
```

### 4.2 计算示例

**场景：** 玩家双手持大剑。该动画的 WAM 为 21.1%（即，在挥砍开始时，PH 重置为 100 × 0.211 = 21.1）。玩家被敌人的火球击中，该火球的基础 Poise Damage（PD）为 30。玩家穿着显示 Poise 值为 43.72 的重甲（即 PDR = 43.72%）。

1. 实际承受的 Poise 伤害：`30 × (1 − 0.4372) = 30 × 0.5628 = 16.884`
2. 结算后的 Poise Health：`21.1 − 16.884 = 4.216`
3. 结果 > 0 → Poise **未被击破**。角色硬抗火球伤害并完成大剑挥砍（Hyper Armor 成功触发）。

### 4.3 Poise 重置机制与关键阈值

关键附加规则：承受一次攻击后，下一次挥砍的 Poise Health 重置为仅为原来的 **80%**（除非特定战技将其恢复至 100%）。这意味着连续的拼刀交换需要逐次递增的防具 Poise 才能避免被打断。

关键阈值（DS3 社区验证）：

| Poise 阈值 | 效果 |
|---|---|
| **61 poise** | 关键阈值。Hyper Armor 可以硬抗大多数轻武器连续攻击或单次大剑轻攻击。 |
| **52 poise** | 适用于大锤使用者：52 显示 Poise 确保双手挥砍在面对敌人重型武器时也不会被打断——因为大锤本身就提供较高的 WAM 基础值。 |

### 4.4 Godot 实现

复现此系统需要一个属性管理器实时监控攻击状态机的转换，动态调整 `poise_health`，并在 `take_damage()` 期间首先执行 Poise 伤害的浮点减法。仅当结果 ≤ 0 时，才强制中断当前动画并触发硬直状态。

```gdscript
# poise_component.gd — 简化版
var poise_health: float = 0.0
var base_poise_health: float = 100.0
var poise_reset_mult: float = 1.0   # 初次交战时为 1.0，承受一次攻击后为 0.8
var pdr: float = 0.0                 # 由装备护甲推算

func activate_hyper_armor(wam: float) -> void:
    poise_health = base_poise_health * wam * poise_reset_mult

func apply_poise_damage(enemy_poise_damage: float) -> bool:
    var actual_damage := enemy_poise_damage * (1.0 - pdr)
    poise_health -= actual_damage
    if poise_health <= 0.0:
        poise_reset_mult = 1.0   # 被击破时重置
        return true               # Poise 被击破 → 硬直
    poise_reset_mult = 0.8       # 下一次挥砍仅获得 80%
    return false                  # Hyper Armor 保持

func reset_poise() -> void:
    poise_health = 0.0
    poise_reset_mult = 1.0
```

**Ashen Hollow 关联：** 当前实现没有 Poise/Hyper-Armor 系统。这作为待实现建议记录在 [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) 中（第 11 节，建议 #5）。Twin Colossi 风格在有效帧期间应不可被硬直——这是承受漫长前摇的主要回报。

---

## 5. 武器系统、属性缩放与 Godot 软编码架构

### 5.1 属性缩放数学

Souls 游戏拥有庞大的武器库。伤害深度源自复杂的属性缩放：武器根据力量（STR）、敏捷（DEX）、智力（INT）和信仰（FTH）提供额外的攻击力（AR）加成。

缩放是非线性的，遵循收益递减规律，并具有明确的软上限和硬上限：

| 属性区间 | 缩放行为 |
|---|---|
| 10 – 40 | 每点收益最大化——每一点属性都显著增加 AR |
| 40 – 60 | 收益递减开始；每点价值明显下降 |
| 60 – 99 | 断崖式下跌：每点收益趋近于零，直至绝对硬上限 99 |

#### 双手持握力量加成

当武器双手持握时，角色的力量在内部乘以 **1.5×**。这极大地影响配点规划：

- **27 STR：** 双手持握 → 有效值 27 × 1.5 = 40.5 → 完美达到第一个软上限。
- **66 STR：** 双手持握 → 有效值 66 × 1.5 = 99 → 达到绝对硬上限，节省大量点数用于生命或持久力。

#### 质变机制

质变从根本上改变缩放曲线：
- **厚重质变：** 完全移除 DEX 缩放，最大化 STR 缩放。任何投入 DEX 的点数变为浪费的沉没成本。
- **锋利质变：** 最大化 DEX，移除 STR 缩放。
- **熟练质变：** 平衡 C/C 缩放，适合 STR+DEX 混合配点。
- **元素质变：** 添加 INT/FTH 缩放，降低物理缩放。

### 5.2 Godot 中的软编码武器架构

在拥有数百种武器的 Souls-like 中，为每种武器编写独立的 `if-else` 逻辑会产生臃肿、不可维护的代码。现代 Godot 框架模式（以 BreadbinEngine 为例）提供了一种优雅的**高度软编码**解决方案。

武器连段不硬编码在角色控制器中。每种武器被定义为一个独立的 `Resource` 文件，包含一个 `String` 类型的动画名称数组：

```gdscript
# sword_resource.tres — 示例数据
[resource]
script = preload("res://weapon_data.gd")
weapon_id = "straight_sword_01"
light_chain_anims = ["sword_R1_01", "sword_R1_02", "sword_R1_03"]
heavy_chain_anims = ["sword_R2_01", "sword_R2_02"]
stamina_light = [22.0, 24.0, 28.0]
stamina_heavy = [35.0, 40.0]
str_scaling = 0.65
dex_scaling = 0.45
```

当玩家按下攻击键时，战斗状态机记录当前的连段索引，从字符串数组中提取对应的动画名称，并将其直接传递给主 `AnimationPlayer` 进行播放。

```gdscript
# combat_state_machine.gd — 简化连段逻辑
var combo_index := -1
var current_weapon: WeaponData

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("light_attack") and can_attack():
        combo_index = (combo_index + 1) % current_weapon.light_chain_anims.size()
        var anim_name := current_weapon.light_chain_anims[combo_index]
        var stamina_cost := current_weapon.light_stamina_costs[combo_index]
        execute_attack(anim_name, stamina_cost)

func execute_attack(anim_name: String, cost: float) -> void:
    if stamina < cost:
        return
    stamina -= cost
    anim_tree["parameters/playback"].travel(anim_name)
```

**核心优势：** 通过将数据与逻辑完全解耦，设计师或 Mod 开发者无需编写任何 GDScript 代码。他们只需配置字符串并在主 `AnimationLibrary` 中挂载对应的动画文件，即可快速创建具有独特派生动作的新武器。

**Ashen Hollow 关联：** 所有五种战斗风格目前使用统一的时机和消耗。基于每种风格的 `Resource` 差异化是最高优先级的待实现建议（见 [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md)，第 11 节）。

---

## 6. Boss 战设计：从视觉反应到心理博弈

Souls 的 Boss 战是整个系统设计的集大成之作。纵观整个系列，Boss AI 逻辑从简单的"攻击-恢复"回合制模式演变为复杂的心理施压系统。

### 6.1 延迟攻击与站位控制

现代 Souls-like 游戏（尤其是 Elden Ring）大量使用"快慢刀"设计。Boss 以物理上反直觉的超长前摇举起武器，然后在一瞬间释放致命一击。这种设计专门惩罚由本能恐惧触发的**恐慌翻滚**。

该设计刻意模糊了闪避的收益窗口，迫使玩家学习**基于站位的闪避**。面对玛莲妮娅的标志性水鸟乱舞或统帅尼尔亚的野猪冲锋，仅依赖按下闪避按钮必然死亡。正确的应对方案是：
- 在中立阶段严格控制交战距离。
- 预判到超必杀技时提前解除锁定并反向冲刺。
- 精确贴紧特定的攻击盲区（如玛莲妮娅的右腿）进行角度盲滚。

系统不仅要求玩家识别虚假的惩罚窗口，还要求在攻击动画的最后几帧执行闪避。

### 6.2 输入读取与 AI 状态树

另一个臭名昭著但策略深度十足的 Souls Boss 设计是**输入读取**（input reading，或**动画读取** animation reading）。当玩家生命值低下、本能地后撤并按下治疗时，Boss AI 在同一帧捕获此输入状态，并立即触发极其致命的突刺或火球作为惩罚。

其本质是：剥夺玩家对战斗节奏的单方面控制权。玩家不能随心所欲地治疗——他们必须将治疗窗口视为与攻击窗口同等珍贵，仅在 Boss 真正的挥空恢复期间使用。

### 6.3 Godot AI 实现

在 Godot 引擎中（遵循 BreadbinEngine 的 AI 模式），此机制通过暴露 Inspector 中的概率调整变量来实现。开发者设定"打断阈值"和"追击概率"（几率值）。当 AI 节点检测到玩家状态机的 `current_state` 切换到 `healing` 时，行为树或 FSM 触发高优先级打断事件，强制 Boss 立即从巡逻状态切换到冲锋攻击状态。

```gdscript
# boss_brain.gd — 输入读取启发式逻辑（伪代码）
func decide_next_action(dist: float, player_state: String, my_hp_ratio: float) -> StringName:
    # 阶段转换门槛
    if my_hp_ratio < 0.5 and phase == Phase.PHASE_1:
        phase = Phase.PHASE_2
        return &"phase_transition"

    # 输入读取：惩罚治疗
    if player_state == "healing" and dist < 8.0 and cooldowns["gap_close"] <= 0.0:
        return &"gap_close"

    # 距离区间攻击选择
    if dist < 2.5 and cooldowns["slash_combo"] <= 0.0:
        return &"slash_combo"
    if dist > 5.0 and cooldowns["gap_close"] <= 0.0:
        return &"gap_close"

    # 第二阶段新机制
    if phase == Phase.PHASE_2 and cooldowns["aoe_burst"] <= 0.0:
        return &"aoe_burst"

    return &"reposition"
```

**Ashen Hollow 关联：** Cinder Guardian 已经具备阶段转换（≤50% HP）和距离区间攻击选择。添加治罪惩罚倾向将使其更接近此处所述的行为复杂度。

---

## 7. 核心 Godot 架构：技术实践

将宏伟的设计概念转化为现实取决于底层代码架构。开源社区已经在 Godot 4 中探索出一套高度标准化的 Souls-like 开发范式。

### 7.1 碰撞检测：基于鸭子类型的 Hitbox 与 Hurtbox

逐帧精确的碰撞检测是 Souls-like 拳拳到肉打击感的基石。在 Godot 4 中，该系统构建在两个核心节点之上：`HitArea3D`（攻击 hitbox）和 `HurtArea3D`（伤害接收器）。

**单向碰撞扫描优化：**

| 节点 | `collision_layer` | `collision_mask` | 角色 |
|---|---|---|---|
| HitArea3D | 2（自定义 Hitbox 层） | 0 | 伤害输出者——不扫描其他对象 |
| HurtArea3D | 0 | 2（自定义 Hitbox 层） | 伤害接收者——持续监测来袭伤害 |

HurtArea3D 使用 GDScript 鸭子类型实现优雅的解耦与安全过滤：

```gdscript
# hurt_area_3d.gd
class_name HurtArea3D extends Area3D

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(hit_area: Area3D) -> void:
    # 鸭子类型检查：确保进入的区域确实是一个 hitbox
    if hit_area is HitArea3D and owner.has_method("take_damage"):
        owner.take_damage(hit_area.damage)
```

为防止非攻击状态下的误判命中，Hitbox 的 `CollisionShape3D` 默认为 `disabled`。开发者在 `AnimationPlayer` 中于特定攻击帧放置关键帧，仅在武器姿态实际构成威胁的那几分之一秒内激活碰撞——实现极其精确的命中窗口。

### 7.2 锁定系统

在 3D 战斗中，锁定系统确保玩家可以围绕目标旋转。正如在 G4-Super-3D-Targeting-System 等社区系统中所见，锁定逻辑远不止是一个简单的摄像机朝向调用。

**目标筛选：** 一个大范围感应器 `Area3D` 收集附近敌人。利用屏幕空间变换和向量点积数学，系统选择与屏幕中心准星夹角最小的目标。

**平滑追踪：** 一旦锁定，代码剥离鼠标的自由视角控制。附加在玩家上的 `SpringArm3D` 持续更新其朝向。为避免令人眩晕的瞬时镜头切换，代码不能使用硬性的 `look_at()`——取而代之的是，使用四元数球面线性插值（`slerp`）以恒定旋转速度（`targeting_speed`）平滑追踪敌人核心骨骼位置，构建电影化的对峙视角。

```gdscript
# lock_on.gd — 简化目标选择
func _collect_lock_candidates() -> Array[Node3D]:
    var candidates: Array[Node3D] = []
    for body in $SensorArea.get_overlapping_bodies():
        if body.is_in_group("enemy") and body.has_method("get_lock_point"):
            candidates.append(body)
    return candidates

func _score_target(candidate: Node3D) -> float:
    var to_target := candidate.get_lock_point() - camera.global_position
    var cam_forward := -camera.global_transform.basis.z
    var angle := to_target.normalized().dot(cam_forward)
    var dist := to_target.length()
    # 优先选择更近、更靠近屏幕中心的目标
    return angle - (dist * 0.01)

func _smooth_look_at(target_pos: Vector3, delta: float) -> void:
    var desired := (target_pos - spring_arm.global_position).normalized()
    var current := -spring_arm.global_transform.basis.z
    var slerped := current.slerp(desired, targeting_speed * delta)
    spring_arm.look_at(spring_arm.global_position + slerped, Vector3.UP)
```

### 7.3 精力管理：延迟回复

Dark Souls 是资源管理的艺术，绿色条（精力）是核心货币。每次动作消耗精力，且精力停止消耗后不会立即恢复——存在一个惩罚性的延迟窗口。

**反模式——请勿使用：**
```gdscript
# 危险：在复杂战斗状态机中使用 await 会导致协程混乱
await get_tree().create_timer(1.5).timeout
stamina_regenerating = true
```

**业界最佳实践——`_physics_process` 中的帧计数计时器：**

```gdscript
var stamina := 100.0
var max_stamina := 100.0
var stamina_cooldown := 0.0
const REGEN_DELAY := 1.5
const REGEN_RATE := 20.0

func consume_stamina(amount: float) -> void:
    stamina -= amount
    stamina_cooldown = REGEN_DELAY  # 每次精力消耗都无情地重置延迟

func _physics_process(delta: float) -> void:
    if stamina_cooldown > 0.0:
        stamina_cooldown -= delta  # 倒计时——精力不恢复
    else:
        # 倒计时完成——安全的、帧无关的精力恢复
        stamina = minf(stamina + (REGEN_RATE * delta), max_stamina)
```

这段严谨的 GDScript 代码忠实地再现了 Souls 的惩罚机制：如果玩家在零精力时恐慌狂按闪避按钮，`stamina_cooldown` 会被不断重置，使精力恢复永久无法达成，死亡不可避免。

**Ashen Hollow 关联：** 当前实现将精力回复限制在 `state == State.LOCOMOTION` 条件下（在提交 `7f30d4f` 中修复）。上述 `_physics_process` 帧计数模式已在应用——这是正确的做法。

---

## 8. 全部帧数据参考表汇总

### 翻滚 I-Frames

| 翻滚类型 | 装备负重 | 30 FPS I-Frames | 持续时间（秒） | 60 FPS 等效值 |
|---|---|---|---|---|
| 快速翻滚 | < 25% | 13 | ~0.433 | 26 |
| 中速翻滚 | 25–70% | 11 | ~0.366 | 22 |
| 沉重翻滚 | > 70% | 9 | ~0.300 | 18 |
| 忍者翻转 | < 25% + 戒指 | 15 | ~0.500 | 30 |

### 弹反工具帧数据

| 工具 | 启动帧 | 有效帧 | 恢复帧 | 最佳用途 |
|---|---|---|---|---|
| 护手带 | 8f | 8f | 中等 | 反应弹反 |
| 靶盾 | 8f | 10f | 极长 | 最高容错率 |
| 小盾 | 12f | 12f | 中等 | 预判 + 防御 |
| 中盾 | 14f | ~6f | 极长 | 仅预置弹反 |

### 武器攻击时机比率（近似值，60 FPS）

| 攻击类型 | 前摇 | 有效帧 | 恢复 | 总计 |
|---|---|---|---|---|
| 直剑 R1 | 20–25f | 10–15f | 20–25f | ~60–65f |
| 特大剑 R1 | 40–45f | 15–20f | 40–50f | ~95–115f |

### 属性缩放曲线

| 区间 | 行为 |
|---|---|
| 10–40 | 每点收益最大化 |
| 40–60 | 收益递减开始 |
| 60–99 | 断崖式下跌；99 为绝对硬上限 |

### Poise 关键阈值（DS3）

| 阈值 | 效果 |
|---|---|
| 61 poise | 硬抗轻武器连段 + 单次大剑 R1 |
| 52 poise（大锤） | 双手挥砍永不被中断 |

---

## 9. 与 Ashen Hollow 的关联

### 当前实现中已验证正确的部分

1. **三段式攻击模型（前摇/有效帧/恢复）：** 精确匹配 Souls 战斗语法。
2. **精力作为共享预算带延迟回复：** 限制在 `State.LOCOMOTION` 条件下——正确。
3. **`_physics_process` 帧计数用于精力冷却：** 使用业界标准模式，而非 `await`。
4. **输入缓冲（150ms 窗口）：** 已实现（提交 `7f30d4f`），以最后一次输入为准。
5. **Boss 阶段转换 + 距离区间攻击选择：** 已实现。
6. **基于 Signals 的通信：** 符合 Godot 最佳实践和模块化模板理念。

### 影响最大的待补缺口

按"Souls 手感"影响与实现努力比排序：

1. **每种风格的攻击时机差异化**（待实现）—— 当前所有五种风格使用统一的前摇/有效帧/恢复时长。Twin Colossi 必须感觉比 Crescent Pair 慢得多。见 [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) 第 11 节，调校参考表。

2. **重型武器有效帧期间的 Hyper Armor**（待实现）—— Twin Colossi 在有效窗口期间应不可被硬直。这是承受漫长前摇的主要回报。上文第 4 节的 Poise Health 公式提供了数学模型。

3. **成功命中时的 Hit-stop**（待实现）—— 重击命中时暂停 2–4 帧。对武器重量感知来说，这是影响最大的单项改动。设计复杂度成本为零。

4. **每种风格的精力消耗差异化**（待实现）—— 当前所有风格统一为 20/38，削弱了武器个性。重型武器的挥砍必须消耗更多精力。

5. **弹反窗口差异化**（待实现）—— Reliquary Guard 的弹反应按盾牌类型具有可调校的有效帧数，而非统一窗口。

6. **Boss 治罪惩罚倾向** —— Cinder Guardian 可以截断玩家治疗并发动追击攻击，添加第 6 节所述的心理施压层。

### 不应直接照搬的内容

- DS1/DS3 的精确帧数——应根据 Ashen Hollow 自身的动画时长进行调校。
- 特定的 Poise 阈值（61、52）——这些是 DS3 特有的且依赖于具体防具套装。
- 精确的精力消耗比率——必须根据 Ashen Hollow 自身的精力池（100）和战斗压力进行调校。
- 属性缩放曲线——垂直切片中的 Ashen Hollow 没有属性系统；这属于远期深度内容。

---

## 10. 结论

Dark Souls 从小众硬核作品升华为时代定义性的游戏标志，并非因为表面上夸张的数值或恶意的陷阱。其伟大之处在于构建了一个极其自洽、严谨且尊重物理规律的微观机制系统。

从重塑配点规划的 1.5× 双手持握力量加成，到精心调校的 13 帧快速翻滚无敌窗口；从动态数学模型的 Poise Health，到通过环境碎片拼合的分裂叙事——每一项设计元素都在悄然迫使玩家摒弃浮躁，以绝对的专注投入其中，解构这个世界，并最终将其征服。

在技术实现上，随着 Godot 4 的持续迭代，开源社区如今能够以高保真度解构并复现这一复杂系统。Root Motion 驱动的动画状态机消除了滑冰现象。分层碰撞掩码配合鸭子类型的 GDScript 实现了毫秒级精度的 Hitbox 检测。高度软编码的字符串数组武器资源支持海量派生动作模组。严谨的帧计数精力延迟忠实地再现了恐慌连按的惩罚。

技术架构的模块化与游戏设计哲学的严谨性在此达到了深度融合——不仅为未来的独立游戏工业化提供了高标准的开源范式，也深刻诠释了"硬核但公平"这一终极游戏美学。

---

## 来源与搜索覆盖

### 数据来源

| 来源类型 | 内容 | 可信度 |
|---|---|---|
| 社区帧数据（wikidot, fextralife） | 翻滚 i-frame 帧数、弹反帧数据、Poise 阈值 | 中等——因版本/补丁而异；比率可靠，绝对数值为方向性参考 |
| 社区武器数据 | 属性缩放曲线、质变修正值、双手持握 1.5× 倍率 | 高——可在游戏中直接观察 |
| Dark Souls Design Works 采访 | 宫崎英高论关卡设计协作、世界结构、氛围 | 高——已出版、已翻译的第一手来源 |
| Godot 官方文档 | `AnimationTree`、`CharacterBody3D`、`Area3D`、`AnimationPlayer` 关键帧 API、Signals、`Resource` | 高——权威 API 参考 |
| 开源 Godot 项目（BreadbinEngine, catprisbrey 模板） | 软编码武器架构、AI 倾向模式、Root Motion 集成 | 中等——可观察的代码模式，未经过大规模生产验证 |
| 学术分析（Jenkins, IntechOpen） | 叙事架构、游戏崇高感、循环时间 | 分析——学术解读，未经开发者确认 |

### 搜索局限性

- 帧数据因游戏版本（DS1 vs DS3 vs Elden Ring）和补丁级别而异。提供的数值为近似起始参考点。
- Poise 阈值是 DS3 特有的且依赖于具体防具套装。DS1 使用完全不同的被动 Poise 系统。
- 社区来源的帧数据有时在来源之间存在分歧。存在冲突时，使用最常被引用的数值。
- 没有带有已验证出版细节的宫崎英高直接引述来确认特定机制的设计意图（例如为何快速翻滚是 13 i-frames）。机制数值是可观察规则；设计理由是分析。
- 双手持握 1.5× STR 修正值和质变缩放规则可在游戏中直接观察并被广泛记录——高可信度。
