# 角色切换系统 (Character Switching System)

## 概述

烬渊允许玩家在任何烬龛（Ember Shrine）处**切换已解锁的职业**。此系统旨在鼓励尝试和战术适应，同时不削弱职业身份的意义。

---

## 解锁进度

| 事件 | 可用职业 |
|-------|-------------------|
| 游戏开始 | 1个职业（角色创建时选择） |
| 第一章首领战后 | 初始职业 + 1个额外职业（玩家自选） |
| 第二章首领战后 | +1个额外职业 |
| 第四章首领战后 | 全部4个职业可用 |

第四章后，所有四个基础职业均可用。混合职业（阴阳师、战巫、魔弓手、修罗）在第三章后解锁，前提是玩家已在两个母职业的天赋树中投入过点数。

---

## 切换机制

### 在烬龛处

主要的切换界面。在任何烬龛休息时：

1. 从神龛菜单中选择**切换法门 (Switch Path)**
2. 选择一个已解锁的职业
3. 确认切换——当前HP/体力/专注按比例调整为新职业的数值（基于当前百分比）
4. 装备自动切换为该职业保存的配装
5. 当前增益被清除；旧职业的被动效果被移除
6. 播放一段简短的水墨画过渡动画（1.5秒）

### 属性转换

切换职业时，属性按比例转换：

```
新属性 = (当前属性 / 旧职业最大值) × 新职业最大值
```

示例：从狂战士（130 HP，当前65 HP = 50%）切换到玄法师（65 HP最大值）→ 32 HP（65的50%，向下取整）。

### 装备配装

每个职业维护**自己的装备配装**，自动保存：
- 武器
- 副手物品
- 头部 / 胸部 / 手臂 / 腿部护甲
- 两个饰品
- 灵符（仅祝祷师）
- 当前元素调和（仅玄法师）

装备**不在**职业间共享——如果你在狂战士上装备一把剑，它将保持在狂战士上。这避免了频繁的微管理，并鼓励独立构建每个职业。

---

## 战斗风格适配

每个职业映射到特定的战斗风格（来自灰烬空洞 (Ashen Hollow) 系统）：

| 职业 | 战斗风格 | 备注 |
|-------|-------------|-------|
| 神射手 | 羿弓术（自定义远程风格） | 弓箭的新型战斗风格 |
| 狂战士 | 刑天斧（双巨像 (Twin Colossi) 改编） | 使用双持重武器节奏 |
| 玄法师 | 五行术（织法 (Veilcraft) 改编） | 使用法术施放节奏 |
| 祝祷师 | 天祝术（烬礼 (Ember Rite) 改编） | 使用祈祷施放节奏 |

现有的灰烬空洞战斗风格（圣物守卫 (Reliquary Guard)、双巨像、弯月双刃 (Crescent Pair)、织法、烬礼）被重新主题化并改编以契合中国文化背景。

---

## 切换限制

| 情景 | 可切换？ | 备注 |
|---------|------------|-------|
| 在烬龛处 | ✅ 是 | 主要切换地点 |
| 战斗中 | ❌ 否 | "你无法集中精神来改变道路" |
| 首领战区域中 | ❌ 否 | 即使不在战斗中 |
| 死亡后（失魂状态） | ❌ 否 | 必须先恢复丢失的烬或在神龛处休息 |
| 合作模式中 | ❌ 否 | 多人游戏锁定职业 |

---

## 职业精通奖励

玩某个职业可赚取**精通度 (Mastery Points)**——按职业追踪的隐形进度：

| 精通等级 | 所需游玩时间 | 奖励 |
|--------------|-------------------|-------|
| 初学 (Novice) | 0小时 | — |
| 入门 (Initiate) | 2小时 | +3%职业专属属性 |
| 熟练 (Adept) | 5小时 | +6%职业专属属性，解锁称号 |
| 精通 (Master) | 12小时 | +10%职业专属属性，解锁秘密职业表情 |
| 宗师 (Grandmaster) | 25小时 | +15%职业专属属性，获得职业光环效果 |

精通奖励**仅在游玩该职业时生效**，且一旦达成即为永久解锁。

---

## 剧情整合

切换道路的能力在世界观中有其根据：作为一个**烬裔 (Ember Scion)**，你的灵魂由原始天之炉之火锻造而成，其中包含了所有可能的灵魂形态。与注定走上一条道路的普通存在不同，烬裔的本质是**根本流动的**。云游道人评论道：

> *"其他灵魂如溪流——固定、可测、终归一处。而你的灵魂如烬火——飘忽、多变、何处不可燃？"*
> *"Other souls are like streams — fixed, predictable, flowing to one destination. But your soul is like Ember-fire — drifting, changeable. Where cannot it burn?"*

---

## 技术架构（Godot 实现参考）

基于现有的灰烬空洞代码库构建：

```
# 职业数据的新资源类型
class_name CharacterClass extends Resource
var class_id: StringName           # "divine_marksman" 等
var class_name: String             # 显示名称（本地化）
var base_stats: Dictionary         # {hp, stamina, focus}
var combat_style: CombatStyle      # 映射到现有枚举
var talent_tree: TalentTree        # 新资源类型
var equipment_loadout: Dictionary  # 序列化装备槽
var mastery_level: int             # 0-4
var mastery_points: float          # 累积游玩时间

# 玩家职业管理
class_name PlayerClassManager extends Node
var unlocked_classes: Array[StringName]
var active_class: StringName
var class_data: Dictionary         # StringName -> CharacterClass
var can_switch: bool               # 受战斗状态限制
```

现有的 `CombatStyle` 枚举新增条目：
- `YI_ARCHERY` (5) — 神射手专用
- `XINGTIAN_AXE` (6) — 狂战士专用（使用双巨像节奏）
- `FIVE_ELEMENTS` (7) — 玄法师专用（使用织法节奏）
- `CELESTIAL_INVOCATION` (8) — 祝祷师专用（使用烬礼节奏）
