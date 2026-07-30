# E-01 — Continuous Poise and Action Armor

**Priority:** P1 (critical)  
**Status:** 🟡 PARTIAL  
**Effort:** L (week)  
**Depends On:** A-03 (`AttackData`), B-01  
**Blocks:** E-02, E-03, E-08, E-09, E-10  
**Authority:** `systems/combat-execution-guard-weapon-arts.md`

## Problem

当前玩家只使用 `hyper_armor: bool`：指定重击或 leap 处于 active 时，任何普通 stagger 都被完全忽略。该模型无法表达：

1. 重武器可以扛住一两次轻击，但会被连续攻击打破。
2. 轻甲、重甲和不同招式阶段的抗打断差异。
3. 生命伤害、普通硬直、盾破和 Boss 处决槽之间的边界。
4. 一次攻击在 windup、active、recovery 三个阶段不同的动作护甲。
5. 玩家和普通敌人共用同一术语与测试契约。

敌人已有 `poise` 累积和 `poise_limit`，但它与玩家二值霸体不对称，也没有 Resource 所有权。

## Design Boundary

Poise 只决定普通受击是否打断动作：

- HP 伤害始终独立结算。
- Guard Meter 决定防具是否破防。
- Execution Break 只属于明确的大型敌人弱点或 Boss。
- Poise 归零只产生 `STAGGER`，不自动授予正面处决。
- Boss 的处决窗口不得由普通 Poise 意外触发。

## Target Model

```text
EffectivePoiseDamage = IncomingPoiseDamage × (1 - ArmorPoiseReduction)
ActionPoise = BasePoise × ActionArmorModifier
PoiseRemaining = current action reserve - accumulated EffectivePoiseDamage
```

| Parameter | Meaning | Initial range |
|---|---|---:|
| `BasePoise` | 角色与装备提供的基础韧性储备 | 0–150 |
| `ArmorPoiseReduction` | 装备对 incoming poise damage 的减免 | 0.0–0.50 |
| `ActionArmorModifier` | 当前 `AttackData` 阶段提供的动作护甲倍率 | 0.0–2.0 |
| `IncomingPoiseDamage` | 攻击 payload 的 Poise 伤害 | ≥0 |
| `PoiseRemaining` | 当前剩余韧性；≤0 时进入普通硬直 | — |

`ActionArmorModifier=0` 表示该动作不提供霸体，并不表示角色没有基础站立韧性。站立受击和动作霸体可共用同一储备，但恢复、重置和倍率必须在测试中固定。

## Data Ownership

### `AttackData`

每个攻击阶段拥有：

```gdscript
@export var poise_modifier_windup := 0.0
@export var poise_modifier_active := 0.0
@export var poise_modifier_recovery := 0.0
```

- 轻武器通常只在极短 active 窗拥有很低倍率或零倍率。
- 重武器可在 late windup 与 active 拥有有限倍率。
- recovery 默认无动作护甲，避免重武器空挥后仍不可打断。
- leap 兵器诀与通用 jump attack 使用不同 `AttackData`，不能共享一个布尔值。

### Character / Equipment

建议新增纯逻辑 `PoiseComponent` 或等价可测试模块：

```gdscript
class_name PoiseComponent
extends RefCounted

var base_poise := 30.0
var current_poise := 30.0
var armor_reduction := 0.0
var reset_delay_seconds := 1.6
var reset_remaining := 0.0

func receive_poise_damage(raw_damage: float, action_modifier: float) -> Dictionary:
    var effective := maxf(raw_damage, 0.0) * (1.0 - clampf(armor_reduction, 0.0, 0.5))
    var action_capacity := base_poise * maxf(action_modifier, 0.0)
    var capacity := maxf(current_poise, action_capacity)
    current_poise = capacity - effective
    reset_remaining = reset_delay_seconds
    return {
        "broke": current_poise <= 0.0,
        "effective_damage": effective,
        "remaining": current_poise,
    }
```

具体实现可以调整，但结算必须可在无场景环境中测试。

## Initial Tuning Bands

这些是《焰渊》的首轮测试区间，不是外部作品系数表。

| Action family | Windup | Active | Recovery | Intent |
|---|---:|---:|---:|---|
| 直剑轻击 | 0.00 | 0.10 | 0.00 | 基本不可依赖霸体换血 |
| 直剑蓄力重击 | 0.10 | 0.35 | 0.00 | 只在完成蓄势后获得有限保护 |
| 大剑双持轻击 | 0.10 | 0.30 | 0.00 | 可扛一次极轻攻击 |
| 特大剑/巨锤重击 | 0.25 | 0.65 | 0.00 | 可换血但会被连续打破 |
| 长枪冲锋终结 | 0.05 | 0.30 | 0.00 | 防止冲锋被擦碰立即取消 |
| 曲剑/双刀 | 0.00 | 0.05 | 0.00 | 依靠位移而非霸体 |
| 拳套蓄力直拳 | 0.05 | 0.20 | 0.00 | 近距离有限抗打断 |
| 法术/祷告 | 0.00 | 由专属兵器诀决定 | 0.00 | 默认可被打断 |

最终值由武器与攻击 Resource 决定，不由 combat style 全局表决定。

## Runtime Resolution

在普通命中解析中：

```text
Parry / Guard 已处理？
├─ 是 → 不进入普通 Poise 分支
└─ 否
   ├─ 结算 HP damage
   ├─ 读取当前 AttackData 阶段的 ActionArmorModifier
   ├─ 结算 EffectivePoiseDamage
   ├─ PoiseRemaining > 0 → 动作继续，播放 hold feedback
   └─ PoiseRemaining ≤ 0 → 进入 STAGGER，清除攻击 Hitbox
```

- `unblockable` 不等于“无限 Poise 伤害”。
- 抓投不经过普通 Poise；它使用独立 capture 规则。
- 弹反成功直接进入 `PARRY_VULNERABLE`，不是通过把 Poise 设置为零模拟。
- 盾破直接进入 `GUARD_BROKEN`，不是普通 `STAGGER`。

## Migration Steps

1. 在 A-03 中加入 `AttackData` 三阶段动作护甲字段。
2. 为当前 player/enemy 建立可测试 Poise 组件或纯 resolver。
3. 将敌人 `poise` / `poise_limit` 迁移到统一术语与 reset 契约。
4. 将玩家 `hyper_armor` 保留为临时兼容输出，但内部改为连续结算。
5. 为现有五套 loadout 的 light/heavy/leap 配置初始值。
6. 删除任何“active 时完全免疫 stagger”的最终 gameplay 分支。
7. HUD 只在当前 Poise 低于基准时显示细条；Boss Execution Break 使用不同颜色、名称和组件。

## Feedback

| Event | Required feedback |
|---|---|
| Poise holds | 短促武器/护甲震动、低强度火星，不中断动作 |
| Poise damaged heavily | 更明显冲击、角色姿态偏移，但仍继续动作 |
| Poise breaks | 清晰碎裂音、橙色冲击和 `STAGGER` |
| Guard breaks | 盾具偏转、独立音效和 `GUARD_BROKEN` 提示 |
| Boss Execution Break | 弱点暴露、专属镜头/音效，不使用普通 Poise bar 文案 |

## Contract Tests

- 同一 HP damage 在不同 ArmorPoiseReduction 下产生不同 Poise 伤害，但 HP 相同。
- 特大武器 active 能承受有限轻击，连续命中最终打破。
- recovery 阶段默认可被打断。
- 曲剑、弓和普通施法不获得隐性动作护甲。
- Poise 归零只进入 `STAGGER`，不生成 execution candidate。
- Guard 成功时普通 Poise 不被扣除；guard break 进入独立状态。
- Parry 成功进入独立 vulnerability，不依赖 Poise 数值。
- Boss Execution Break 与普通 Poise 互不修改。
- Poise reset 在规定延迟后恢复，并在受击时重新计时。

## Acceptance Criteria

- [ ] 玩家二值 `hyper_armor` gameplay 判定被连续 Poise 替代
- [ ] 玩家和普通敌人使用同一 Poise 术语与 resolver 契约
- [ ] 每个攻击阶段从 `AttackData` 读取 ActionArmorModifier
- [ ] 重武器霸体可被连续打破，轻武器不依赖换血
- [ ] HP、Guard Meter、Poise、Execution Break 独立结算
- [ ] HUD 能区分普通 Poise 与 Boss Execution Break
- [ ] Headless contract 覆盖 hold、break、reset 和状态边界
- [ ] 现有 guard/parry 和 smoke contracts 继续通过

## Risks

| Risk | Mitigation |
|---|---|
| 重武器变成无脑换血 | recovery 无动作护甲；连续攻击可打破；HP 伤害照常 |
| 数值层过多难理解 | UI 仅在相关时显示；教程按“盾破/硬直/弱点”分别教学 |
| 与敌人旧 poise 行为漂移 | 先冻结当前敌人测试，再迁移 resolver |
| Boss 被普通攻击意外处决 | Boss 使用独立 Execution Break 和 story-threshold protection |
