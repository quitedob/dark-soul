# Combat Expansion Roadmap — 执行·格挡·韧性·招式·兵器诀

**Status:** 🟢 MOSTLY SHIPPED（逻辑层已齐；真蒙皮动画 / 锁敌 BlendSpace 仍开放）  
**Updated:** 2026-07-31  
**Authority:** [combat-execution-guard-weapon-arts.md](../systems/combat-execution-guard-weapon-arts.md) · [tasks-master.md](../tasks-master.md)

---

## Baseline（已落地）

- `CombatStyleData` ×5、`AttackData` / `MovesetData` / `WeaponData` / `WeaponArtData` / `GuardProfile`
- 轻/重三阶段计时 + 工厂合成；蓄力档、单/双/成对持握、跑/翻/后撤/跳/下落语境攻击
- `CombatArea` 标准 payload、单挥去重；本地 `HitStopManager`（禁全局 `time_scale`）
- `PoiseResolver`（玩家+敌人）、相位 WAM；`GuardResolver` + Guard Meter + 盾重稳定性
- `GUARD_BROKEN` / `PARRY_VULNERABLE` / `WEAK_POINT_EXPOSED`；人型处决、Boss 弱点处决、抓投导演
- `PlayerAnimationBridge`：占位 AnimationTree、Physics callback、method-track 轻击/跃击、RM 物理接入
- 多槽 Action Queue、dodge/sprint tap-hold、武器拖尾重量档

## 仍缺（与 tasks-master 对齐）

| 项 | 状态 |
|----|------|
| 真蒙皮 / 作者化跃击动画（D-01 / D-05） | 🟡 / ⬜ |
| 锁敌 strafe BlendSpace2D（D-03） | ⬜ |
| LimboAI 真插件替换 compat 宏层 | ⬜ |
| 更多敌人攻击 `.tres` 作者化 | ⬜ |

---

## Milestone 对照（历史；均已收口除非标注）

| Milestone | 内容 | 状态 |
|-----------|------|------|
| 0 | 兼容契约冻结 + 测例 | ✅ |
| 1 | 单一战斗数据所有者 | ✅ |
| 2 | 连续 Poise / WAM | ✅ |
| 3 | Guard Meter / 破防 | ✅ |
| 4 | 独立脆弱态 | ✅ |
| 5 | 人型处决 / 背刺 | ✅ |
| 6 | 握持 / 蓄力 / 语境攻击 | ✅ |
| 7 | 兵器诀 Resource | ✅ |
| 8 | Root motion / 真动画闭环 | 🟡 PARTIAL（POC + 钩子；缺资产） |

---

## Related

- [devlog/index.md](../devlog/index.md)
- [planning/soulslike-gap-analysis.md](../planning/soulslike-gap-analysis.md)
