# Combat Expansion Roadmap — 执行·格挡·韧性·招式·兵器诀

**Status:** 🟡 IN PROGRESS（握持/蓄力/语境攻击已落地；Guard Meter / 独立盾破态 / root motion 仍待）  
**Scope:** 将当前兼容原型扩展为 `combat-execution-guard-weapon-arts.md` 定义的原创战斗体系。  
**Non-goal:** 本路线不包含第三方动作资产导入或逐帧复刻。

## Baseline

当前已经存在：

- `CombatStyleData` 与五个 `.tres`（含 leap/dodge/WAM）。
- 轻/重攻击三阶段代码计时 + `AttackData` / `MovesetData` 工厂合成。
- 单持/双持/成对持握、蓄力档、跑/翻滚/后撤/跳/下落语境攻击。
- `CombatArea` 标准命中 payload、单次挥击去重、`is_heavy` 标签反馈。
- `GuardResolver` 的方向、吸收、稳定性和精力破防。
- 连续站立韧性（`PoiseResolver` + `poise_health`）；动作 WAM 抬高容量。
- 本地 HitStop（冻实体状态推进，非全局 `time_scale`）。
- recovery `dodge_cancel_seconds` 接线；刑天重击零取消。
- 四种装备化弹反窗口。
- 敌人简化 Poise 累积与章节 Boss 内容阶段表。

当前仍缺：

- Guard Meter 与直接冲击击穿。
- 独立 `GUARD_BROKEN` FSM 状态。
- 人型处决、背刺、Boss 弱点处决完善。
- 抓投配对状态。
- AnimationTree/root motion 战斗管线。

## Milestone 0 — Freeze Compatibility Contracts

**Priority:** P0  
**Depends:** none  
**Effort:** M

1. 为当前五套 loadout、轻/重攻击、leap、盾击和五种兵器诀记录 action ID、费用、时序和 payload。
2. 为输入缓冲、攻击 active 窗、单次命中去重、Focus/精力扣费时点补 contract tests。
3. 将 `architecture.md` 的状态图改为真实当前状态；明确 guard 是 overlay。
4. 标记 `CombatStyleData` 是兼容容器，而非最终武器招式格式。

**Exit criteria:** 后续数据迁移若改变当前行为，测试会明确失败。

## Milestone 1 — Single Combat Data Owner

**Priority:** P0  
**Depends:** Milestone 0  
**Effort:** M

1. 消除 `player.gd.STYLE_TIMING`、`PlayerCombatData.STYLE_TIMING` 与 `.tres` 的三份所有权。
2. 将 leap、dodge 和 action armor 读取迁入现有 `CombatStyleData`。
3. 消除法术配置双份所有权，保留一个权威入口。
4. 为 Resource 加载和字段范围增加 ContentValidator 检查。

**Exit criteria:** gameplay 不再读取旧 `STYLE_TIMING`；五套兼容 loadout 行为不变。

## Milestone 2 — Attack and Moveset Resources

**Priority:** P1  
**Depends:** Milestone 1  
**Effort:** L

1. 实现 `AttackData`、`ChargeProfile`、`MovesetData`、`WeaponData`、`WeaponArtData`。
2. 将现有轻/重攻击和特殊动作编码为 Resource。
3. `_try_attack()` 改为按 stance + context 解析招式。
4. 将普通命中统一映射到现有 `CombatArea` payload。
5. 保留程序化姿态，不在此阶段强制引入 AnimationTree。

**Exit criteria:** 无新增动作的情况下，新 Resource 管线与旧行为完全等价。

## Milestone 3 — Guard Meter and Guard Break

**Priority:** P1  
**Depends:** Milestone 2  
**Effort:** M

1. 实现 `GuardProfile` Resource，并迁移当前盾牌字典。
2. 增加 Guard Meter、恢复延迟和每秒恢复。
3. 增加 `direct_break_threshold` 与盾角系数。
4. 增加独立 `GUARD_BROKEN` 状态。
5. 人型破防只生成处决候选，不在此阶段播放处决。
6. 非人型破防进入短硬直或弱点标记。

**Exit criteria:** 精力破防、Guard Meter 破防和单击击穿均有独立测试。

## Milestone 4 — Continuous Poise

**Priority:** P1  
**Depends:** Milestone 2  
**Effort:** L

1. 将玩家二值 `hyper_armor` 替换为 Base Poise、装备减伤和招式阶段修正。
2. 统一玩家与普通敌人的 Poise 术语和恢复规则。
3. 保留 HP 伤害与 Poise 独立结算。
4. Boss 新增独立 Execution Break，不复用普通 Poise。
5. HUD 只在 Poise 受损或 Boss 弱点积累时显示对应条。

**Exit criteria:** 重武器可扛有限轻击但会被连续打破；轻武器不获得隐性霸体。

## Milestone 5 — Human Executions

**Priority:** P1  
**Depends:** Milestone 3, Milestone 4  
**Effort:** L

1. 实现 `ExecutionProfile`、正面/背面 `ExecutionAnchor` 和易处决状态。
2. 弹反成功进入 `PARRY_VULNERABLE`，不再只进入普通长硬直。
3. 盾破进入 `GUARD_BROKEN` 处决窗。
4. 实现背部扇区、距离、地形和目标免疫检查。
5. 实现独占 execution claim、防重复处决和事件点单次伤害。
6. 首个垂直切片只做一组直剑正面处决与一组匕首背刺。

**Exit criteria:** 无吸附穿墙、无提前扣血、无双人抢同一目标。

## Milestone 6 — Grip Modes and Context Attacks

**Priority:** P2  
**Depends:** Milestone 2, Milestone 5  
**Effort:** XL

1. 实现 `ONE_HANDED`、`TWO_HANDED`、`PAIRED`。
2. 同一武器按 grip mode 切换 `MovesetData`。
3. 先增加蓄力重击，再增加跑攻和翻滚攻。
4. 增加后撤步与后撤攻；后撤步默认无全身无敌。
5. 增加通用 jump/airborne/landing，再增加跳攻和下落攻。
6. 目标选择优先级按处决→空中→跑攻→闪避派生→蓄力→中立执行。

**Exit criteria:** 上下文输入不会误解析；所有动作有明确成本、转向和取消规则。

## Milestone 7 — Weapon Arts

**Priority:** P2  
**Depends:** Milestone 2, Milestone 6  
**Effort:** L

1. 将现有五种特殊动作迁入 `WeaponArtData`。
2. 为直剑、重武器、长枪、战锤、曲剑、拳套、匕首和盾牌建立首批原创兵器诀。
3. 每个兵器诀至少满足两项有效成本。
4. 增加 light/heavy 分支、格挡成功分支和冷却/次数支持。
5. 使用统一 Focus 与精力经济，不在兵器诀函数内硬编码。

**Exit criteria:** 兵器诀改变战术，不是无风险高伤普通攻击。

## Milestone 8 — Boss Weak-Point Executions

**Priority:** P2  
**Depends:** Milestone 4, Milestone 5, chapter boss runtime  
**Effort:** XL

1. 为五个主 Boss 建立独立弱点、Execution Break 和锚点。
2. 处决只在机制完成后开放，不接受普通背刺判定。
3. 巨阙、刑天、九尾、玄霄和烛阴的处决结果遵守章节剧情阈值。
4. 非致死处决不得越过 30%/10% 的故事选择节点。
5. 处决后阶段、弱点复原和镜头恢复必须数据化。

**Exit criteria:** 五个 Boss 都有符合体型和叙事的独立破绽动作，无人型处决复用。

## Milestone 9 — Grab Framework

**Priority:** P3  
**Depends:** Milestone 5, AnimationTree proof of concept  
**Effort:** L

1. 实现 `GrabProfile` 与独立抓取 `Area3D` / `ShapeCast3D`。
2. 复用 execution claim、锚点对齐和 paired-state 安全取消。
3. 实现 `GRAB_INITIATOR` / `GRABBED`。
4. 明确走位、翻滚和只针对 `low_grab` 的跳跃规避。
5. 命中与伤害由动画事件触发；普通 `CombatArea` 不参与。

**Exit criteria:** 抓投不可格挡/弹反，空挥有可惩罚恢复，失败取消不锁死角色。

## Milestone 10 — Authored Animation and Root Motion

**Priority:** P2  
**Depends:** Milestone 2; can start as a one-weapon proof of concept  
**Effort:** XL

1. 先用直剑建立 AnimationTree + root motion POC。
2. Gameplay 与动画共同消费 `AttackData`，命中合法性仍由 gameplay 契约决定。
3. 迁移攻击 lunge、跳攻、下落攻、处决和抓投位移。
4. 保留 root motion 失效时的安全位移和状态恢复。
5. Physics callback 下验证 30/60/120 FPS 和 Web 波动帧率。

**Exit criteria:** 动画驱动位移不改变命中时序、资源消耗和状态合法性。

## Required Test Families

| Family | Required coverage |
|---|---|
| Resource schema | 类型、字段范围、引用循环、缺失上下文 |
| Input context | 处决/空中/冲刺/闪避派生/蓄力/中立优先级 |
| Guard | 盾角、精力、Guard Meter、直接击穿、不可格挡 |
| Parry | 不同工具窗口、边界时刻、不可弹反攻击 |
| Poise | 轻重武器、装备减伤、霸体持有与打破 |
| Execution | 锚点、独占 claim、事件点伤害、取消和致死规则 |
| Boss break | 弱点积累、阶段阈值、非致死故事保护 |
| Grab | 独立 capture path、空挥恢复、状态恢复 |
| Animation parity | gameplay timer 与动画事件一致、root motion 稳定 |

## Completion Definition

该路线只有在以下条件同时成立时才视为完成：

- 玩家可在至少三种武器类别上体验单持/双持或成对持握差异。
- 人型正面处决、背刺和五个主 Boss 的弱点处决均可用。
- 格挡、Guard Meter、Poise、Execution Break 是四个独立概念。
- 跳跃不会成为通用全身无敌，抓投不复用普通攻击判定。
- 所有兵器诀由 Resource 驱动并具有明确成本。
- 关键逻辑具备 headless contracts，场景配对动作具备集成测试。
