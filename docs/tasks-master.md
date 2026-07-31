# 烬渊 (Ember Abyss) — Master Task Backlog

**Created:** 2026-07-30  
**Updated:** 2026-07-31  
**Status:** `ACTIVE` — 绝大多数 A–K 已收口；开放项以真资产 / 内容抛光为主  
**Engine:** Godot 4.7.1  
**缺口权威:** [planning/soulslike-gap-analysis.md](planning/soulslike-gap-analysis.md)  
**交付日志:** [devlog/index.md](devlog/index.md)（按日期文件夹；禁止再写巨型单文件）  
**调研汇总:** [research/index.md](research/index.md)

---

## 状态图例

| Status | Meaning |
|--------|---------|
| ✅ DONE | 已落地（细节见 `docs/devlog/<日期>/`；任务规格已归档删除） |
| 🟡 PARTIAL | 逻辑/POC 已有，真资产或章节抛光未完 |
| ⬜ PENDING | 未开始 |

---

## 仍开放

| ID | Task | Priority | Status | Notes |
|----|------|----------|--------|-------|
| D-01 | AnimationTree 真蒙皮 / 根骨资产替换占位骨架 | P1 | 🟡 PARTIAL | POC + Physics callback 已有；缺生产动画 |
| D-03 | 锁敌 strafe BlendSpace2D | P2 | ⬜ PENDING | 依赖真位移动画 |
| D-05 | 刑天跃击 root-motion 作者化动画路径 | P2 | ⬜ PENDING | 程序化 leap + RM 接入已有 |
| H-04 | 29 关模块族行为抛光（Ch.2–5） | P1 | 🟡 PARTIAL | 模块可生成；章节行为未全量抛光 |
| — | LimboAI 真 GDExtension 替换 `compat_macro` | P3 | ⬜ PENDING | G-01 兼容层已 DONE |
| — | 敌人攻击更多磁盘 `.tres` 作者化 | P3 | ⬜ PENDING | Catalog + 哨兵样例已有 |

### L 系列缺口（2026-07-31 四路 subagent 审计新增）

> 明细见 [tasks/content-gap-backlog.md](tasks/content-gap-backlog.md)。P0 接线（L-01…L-06）与 P1（L-07…L-17）已全部闭环，见 [devlog 09](devlog/2026-07-31/09-p1-wave-l-07-l-17.md)。

| 优先级 | 要点 | 状态 |
|--------|------|------|
| P0 | **L-01** 命运抉择闭环 / **L-02** Ch.3–5 遭遇接线 / **L-03** Ch.3–5 Boss 生成 / **L-04** 隐藏结局 flag 链 / **L-05** 跨章 NPC（含锻造）/ **L-06** 召唤物 | ✅ DONE（2026-07-31，[devlog 08](devlog/2026-07-31/08-l-p0-wiring-l-01-l-06.md)） |
| P1 | **L-07** 连段 / **L-08** 逐类 moveset / **L-09** 职业天赋成长（含经脉）/ **L-10** 装备状态（含背包 UI）/ **L-11** 法术 7→32 / **L-12** 快速旅行 / **L-13** 兵器诀 / **L-14** 抓投扩展 / **L-15** 锻造扩展 / **L-16** 重力倒悬 / **L-17** 谜题 | ✅ DONE（2026-07-31，[devlog 09](devlog/2026-07-31/09-p1-wave-l-07-l-17.md)） |
| P2 | **L-18** 真模型资产 / **L-19** Boss 攻击 type 全覆盖 / **L-20** 弱点骨骼锚点 / **L-21** .tres 作者化 / **L-22** 精英对齐文档 | ⬜ PENDING |
| 工程 | **L-23** 测试补齐 / **L-24** uid + devlog/数据口径修正 | ⬜ PENDING |

战斗扩展里程碑总览仍见 [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md)。

---

## 已完成（按维度摘要）

> 单任务规格文件已从 `docs/tasks/` 删除；以本表 + [devlog](devlog/index.md) + 系统文档为准。

| Dim | Done | 要点 |
|-----|------|------|
| **A** 数据解耦 | A-01…A-07 | CombatStyle / Attack / Moveset / WeaponArt / GuardProfile / HandEquipment Resource 路径 |
| **B** 帧与手感 | B-01…B-12 | 分风格体力与帧、取消窗、蓄力/握持/语境攻击、多槽队列、tap-hold、下落重力、分状态加速度 |
| **C** 反馈 | C-01…C-06 | 本地 HitStop、trauma 震屏、重击低通、武器拖尾、Music 总线音量 |
| **D** 动画 | D-02, D-04, D-06, D-07, D-08 | RM 物理接入、Physics callback、处决/抓投导演、动画 method-track 钩子 |
| **E** 防务 | E-01…E-11 | 连续 Poise、招架窗、Guard Meter、脆弱态、人型/Boss 处决、guard setter |
| **F** 镜头 | F-01…F-06 | SpringArm mask、锁敌打分/slerp/循环/断锁、自动回跟 |
| **G** AI | G-01…G-08 | Boss 宏 BT、治疗惩罚、远程伏击、相变 VFX、AI Catalog、章节 Boss 权能、命中载荷、EnemyAttackCatalog |
| **H** 战役 | H-01…H-03, H-05…H-07 | 关卡 ID、迁移、builder、捷径折叠、死亡环、Ch.1 竖切（H-04 仍 PARTIAL） |
| **I** 测试 | I-01…I-16 | GUT、FSM/体力/命中/格挡/死亡环、CI、smoke 抽离、求解器单测、敌 FSM 覆盖 |
| **J** 文档 | J-01…J-12 | controls / architecture / validation / systems/* 权威参考 |
| **K** 正确性 | K-01…K-04 | Focus 原子扣费、guard `_ready` 防双初始化、关卡断锁、未知 cue 警告 |

---

## Status Summary（2026-07-31）

| | Count |
|--|------:|
| 主表任务（A–J 原 78 + Audit Wave） | ~100 |
| ✅ DONE | ~96 |
| 🟡 PARTIAL | 2（D-01, H-04） |
| ⬜ PENDING（主表内） | 2（D-03, D-05） |
| 后续内容债（无旧 ID） | LimboAI 真插件、Ch.3–5 专属 Boss 流程、跨章叙事填充 |
| L 系列缺口（2026-07-31 审计） | P0 6 项 + P1 11 项 ✅ DONE；P2 5 项 + 工程 2 项 ⬜ PENDING → [content-gap-backlog](tasks/content-gap-backlog.md) |

---

## 相关文档

- [master-index.md](master-index.md) — 文档地图  
- [devlog/index.md](devlog/index.md) — 按日交付日志  
- [research/index.md](research/index.md) — 调研汇总  
- [validation.md](validation.md) — 验证命令  
- [planning/soulslike-gap-analysis.md](planning/soulslike-gap-analysis.md) — 类魂缺口权威  
