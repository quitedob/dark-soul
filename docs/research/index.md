# Research — 调研汇总

**Status:** ARCHIVE + 对照现网  
**权威实现状态:** [devlog/index.md](../devlog/index.md) · [tasks-master.md](../tasks-master.md) · [planning/soulslike-gap-analysis.md](../planning/soulslike-gap-analysis.md)

本目录只放**调研原稿**。正文保留作设计参考；文首 PENDING 表多已过时，**不要当开放债**。

---

## 分类

### Soulslike（魂系设计）

| 文档 | 内容 | 现网对照（2026-07-31） |
|------|------|------------------------|
| [soulslike/design.md](soulslike/design.md) | 12 主题设计审计、垂直切片清单、勿照搬项 | 缓冲/锁敌循环/Boss 相位/治疗惩罚等已落地；跨章内容仍开放 |
| [soulslike/weapons.md](soulslike/weapons.md) | 分风格武器手感、卡肉、霸体、音频建议 | 分风格帧/体力、本地 HitStop、Poise/WAM **已落地**；真蒙皮动画仍缺 |
| [soulslike/mechanics.md](soulslike/mechanics.md) | 帧数据、招架窗、韧性公式、Godot 模式 | PoiseResolver / GuardProfile / 招架矩阵 **已落地** |

### Godot（引擎与工程）

| 文档 | 内容 | 现网对照（2026-07-31） |
|------|------|------------------------|
| [godot/prototype-baseline.md](godot/prototype-baseline.md) | 早期垂直切片调研与 API 映射 | 历史基线；具体功能以 devlog 为准 |
| [godot/ecosystem.md](godot/ecosystem.md) | GitHub / AssetLib 类魂生态与可复用模块 | 参考用；项目自有 Resource/FSM 优先 |
| [godot/jump-collision.md](godot/jump-collision.md) | 跳跃、坡面、snap、弹体穿透、安全重生 | P0–P1 运行时已接（见 2026-07-30 landing 条目） |
| [godot/actions-combat.md](godot/actions-combat.md) | 招式数据、AnimationTree、输入队列建议 | 多槽队列 / AnimationBridge / RM **已落地**；真资产仍缺 |

---

## 阅读顺序（新人）

1. [planning/soulslike-gap-analysis.md](../planning/soulslike-gap-analysis.md) — 现在还缺什么  
2. [systems/combat-execution-guard-weapon-arts.md](../systems/combat-execution-guard-weapon-arts.md) — 战斗目标契约  
3. 本目录 soulslike → godot，按需深挖公式与生态  
4. [devlog/index.md](../devlog/index.md) — 已交付时序  

---

## 维护规则

- 新调研按主题放入 `soulslike/` 或 `godot/`，**禁止**根目录堆 `research-*.md`
- 文件名用语义英文（`design` / `weapons`），**禁止** `e-1`、`a01` 一类编号文件名
- 实现状态只改 **devlog 日目录** + `tasks-master`，不在调研稿里维护 DONE 表
