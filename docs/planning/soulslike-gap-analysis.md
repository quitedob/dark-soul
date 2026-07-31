# 《烬渊》类魂缺口剖析

**Authority:** 本文件 + [devlog/2026-07-31/](../devlog/2026-07-31/) + `game/scripts/player/player.gd`  
**Scope:** 纠正过时审查稿；盘点相对「可玩类魂垂直切片」仍缺什么  
**非目标:** 零售魂游逆向、联机服务器、Unity 克隆照搬

---

## 1. 总判

系统骨架已接近 Ch.1–2 类魂垂直切片。  
**真正还缺：** 真动画驱动 timing/位移闭环、Ch.3–5 内容抛光、跨章叙事填充——而不是单槽缓冲或全局 `time_scale` hit-stop。

审计只认 `game/scripts/player/player.gd`（根目录旧 `scripts/player.gd` **已不存在**）。

---

## 2. 审查稿纠错（勿再当开放债）

| 审查稿说法 | 实况 |
|-----------|------|
| 仅单槽缓冲 | **多槽** `enqueue_action` |
| 缺翻滚/冲刺同键 | **tap≤200ms / hold** |
| 缺 floor_snap / 下落加重 | **已有** |
| Hit-stop 用 `time_scale` | **本地 HitStopManager** |
| 缺脆弱态 | **敌人 FSM + 处决导演** |
| 敌人无 PoiseResolver | **已统一** |
| 命中载荷 / 攻击 Catalog 未做 | **逻辑层已做**；磁盘 `.tres` 仍可扩展 |
| 无叙事运行时 | **云游竖切已落地**；跨章迁移已做（L-05） |

证据见 [devlog 索引](../devlog/index.md)（尤其 2026-07-31 Delivery Summary）。

---

## 3. 仍缺什么

### P0 — 手感真缺口

1. **真动画资产** — method-track 钩子已有；需作者化 clip 真正接管 timing  
2. **刑天跃击作者化路径** — 程序化 leap + RM 已有  
3. **锁敌 BlendSpace** — 可后置

### P1 — 内容 / 抛光

4. Ch.3–5 专属 Boss 流程（九尾记忆凝视 / 玄霄 90s 逃出 / 烛阴 P3 零重力与四结局）  
5. 29 关模块行为抛光仍 PARTIAL  
6. 终局消费 fate_* 增益旗 / 分结局尾声

### P2 — 工程

7. LimboAI 真 GDExtension（现 `compat_macro`）  
8. 更多敌人攻击 `.tres` 作者化  
9. 人工手感验收（Boss 节奏、镜头舒适度）

---

## 4. 明确排除

| 维度 | 为何不进主路线 |
|------|----------------|
| RAM / EAC 逆向 | 需要自有 Resource 曲线 |
| ds3os 联机 | 产品愿景单机 |
| Markov 台词 | 不替代 DialogueRunner |
| Unity clone | 已有项目 schema |

---

## 5. 三期路线（竖切状态）

| Phase | 目标 | 状态 |
|-------|------|------|
| 1 | 动画钩子 / RM / 敌人 Poise / 角速度 | ✅ 逻辑竖切 |
| 2 | GuardProfile / AttackData 落盘 / 捷径 / 敌 FSM 测 | ✅ |
| 3 | QuestState / DialogueRunner / EndingResolver | ✅ 云游竖切 |

后续主线：真资产 + Ch.3–5 专属流程与抛光 + 跨章叙事填充。

---

## 6. 关键路径

| 用途 | 路径 |
|------|------|
| 交付日志 | `docs/devlog/index.md` |
| Backlog | `docs/tasks-master.md` |
| 调研汇总 | `docs/research/index.md` |
| 玩家脚本 | `game/scripts/player/player.gd` |
| 敌人 AI | `docs/systems/enemy-ai.md` |
| 叙事边界 | `docs/story/chapter-bridge-map.md` |
