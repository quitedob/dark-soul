# 《烬渊》类魂缺口剖析（2026-07-31）

**Authority:** 以本文件 + `docs/devlog.md`（2026-07-31）+ `game/scripts/player/player.gd` 为准。  
**Scope:** 纠正过时审查稿；盘点相对「可玩类魂垂直切片」仍缺什么；给出三期演进路线。  
**非目标:** 零售魂游内存逆向、EAC、ds3os 联机服务器、Unity 克隆照搬。

---

## 1. 总判

宏观架构（过程化战役壳、Boss 宏观 BT、命运旗标、灰盒资产壁垒）判断成立。  
**2026-07-31 Audit Backlog Wave 之后，战斗手感债务表已大面积过时。**

一句话：系统骨架已接近 Ch.1 类魂垂直切片；真正还缺的是「真动画驱动 timing / 位移承诺闭环」「敌人与玩家同一套韧性契约」「Ch.2–5 + 叙事运行时」，而不是再去修单槽缓冲或全局 `Engine.time_scale` hit-stop。

**审计陷阱：** `game/scripts/player.gd`（根目录）仍是旧单槽实现，**未被场景引用**。后续审查只认 `game/scripts/player/player.gd`。

---

## 2. 审查稿纠错（勿再当开放技术债）

| 审查稿说法 | 实况 | 证据 |
|-----------|------|------|
| 仅单槽 `_buffered_action`、指令易吞没 | **已有多槽** `enqueue_action` / `_process_action_queue`；单槽仅兼容 HUD | `player/player.gd`；`docs/tasks/b-09-action-queue-buffer.md` ✅ |
| 缺翻滚/冲刺同键 | **已有** tap≤200ms 翻滚 / hold 冲刺 | `_process_dodge_sprint`；`docs/tasks/b-10-*.md` ✅ |
| 缺 `floor_snap` / 下落加重 | **已有** snap=0.35 + 下落重力×2 | `player_visuals.gd`；`docs/tasks/b-11-*.md` ✅ |
| 各状态无加速度衰减 | **线加速度已有**（locomotion/attack/dodge）；角速度分状态为 Phase 1 补完项 | `_get_current_acceleration`；B-12 线加速度 ✅ |
| Hit-stop 用 `Engine.time_scale` | **禁止且已换本地** `HitStopManager`；`game_world` assert `time_scale==1` | `hit_stop_manager.gd`；C-01 ✅ |
| 缺 `PARRY_VULNERABLE` / `WEAK_POINT_EXPOSED` | **敌人 FSM 已有**；处决/抓取导演已接线 | `enemy.gd`；E-08–E-10 ✅ |
| G-07 / G-08 未做 | **逻辑层已做**；磁盘 `.tres` 作者化仍弱 | `CombatArea`→`receive_hit_payload`；`EnemyAttackCatalog` |

---

## 3. 仍缺什么（按影响排序）

### P0 — 魂系手感真缺口

1. **真动画资产 + Method Track 驱动判定**  
   - 现状：`PlayerAnimationBridge` 有钩子与占位轨；hitbox 仍可由 FSM `state_time` 开关；需让 `_anim_hitbox_latched` 真正接管 active。  
   - 任务：D-08 钩子已 DONE，玩法接管属 Phase 1。

2. **Root Motion 物理闭环**  
   - 现状：直剑 POC / 程序化 leap 常量；重击仍代码 lunge。  
   - 任务：D-02（`get_root_motion_*`→物理）、D-05（刑天跃击路径）、D-03（锁敌 BlendSpace，可后置）。

3. **敌人韧性与玩家不对称**  
   - 玩家：`PoiseResolver` + WAM。  
   - 敌人：历史为 `poise += stagger` / `poise_limit`。  
   - 任务：E-01 收口统一契约 + E-02 相位 WAM。

4. **动作承诺角速度**  
   - B-12 线加速度已做；攻击/翻滚中 `_face_direction` 固定权重 → 转向承诺不足。

### P1 — 垂直切片可玩性 / 内容

5. Ch.2–5 真可玩内容（非占位遭遇）。  
6. H-05 捷径空间折叠；H-04 28 关行为抛光仍 PARTIAL。  
7. 叙事运行时：`QuestState` / NPC / `DialogueRunner` / `EndingResolver`（设计见 `docs/story/chapter-bridge-map.md`）。Fate `choice_flags` 已可写。  
8. A-07：`HandEquipment` → `WeaponData` / `GuardProfile`。  
9. G-02 每 Boss 治疗惩罚变体；G-04 相变 VFX/动画混合剩余。

### P2 — 工程与资产管线

10. LimboAI 真 GDExtension（现 `compat_macro`）。  
11. 敌人攻击磁盘 `.tres` 作者化。  
12. I-16 全敌 FSM 覆盖；归档误导性旧 `scripts/player.gd`。  
13. 人工手感验收（Boss 节奏、死亡环、镜头舒适度）。

---

## 4. 明确排除出指导主线

| 维度 | 为何不应进主路线 |
|------|------------------|
| RAM / EAC / 作弊表逆向 | 零售客户端分析；本项目需要自有 Resource 数值曲线 |
| ds3os 异步联机 | 产品愿景单机；`PlayerSocket` 仅未来解耦提示 |
| Markov 台词生成 | 可作写作辅助，不替代 DialogueRunner / 证物链 |
| Unity clone 照搬 | 已有项目 schema；翻译模式即可 |

**可选附录：** 软封顶、负重→i-frame、体力回复延迟公式对照 → 喂给 `.tres` 调参，不新开系统。

---

## 5. 三期演进路线

### Phase 1 — 手感闭环

- Method-track / `anim_event_*` 驱动 hitbox 与 combo window。**（已落地：轻击/跃击 defer）**
- D-02 root motion 写入物理；D-05 至少一条重武器跃击路径。**（程序化 leap + RM 已落地；真资产仍缺）**
- 敌人接入 `PoiseResolver`；E-02 相位 modifier。**（已落地）**
- B-12 角速度分状态。**（已落地）**
- 归档旧 `scripts/player.gd`。**（根目录旧脚本已不存在）**

### Phase 2 — Ch.1 抛光 + 数据盘作者化

- A-07 装备引用迁移；敌人攻击 `.tres` 落盘；G-02 / G-04 收口。**（竖切已落地）**
- H-05 捷径；Ch.1 人工验收清单。**（已落地）**
- I-16 + 必要 smoke。**（FSM 测例已扩；story smoke 新增）**

### Phase 3 — 叙事运行时最小竖切

1. 扩展 `AshenRunState` NPC/支线旗（已有 Boss `choice_flags`）。**（`npc_cloud_wanderer_met`）**
2. `QuestState` 阶段机。**（已落地）**
3. `DialogueRunner`（条件 / 一次性）。**（云游竖切）**
4. `EndingResolver` 读状态 → 四结局可达性验证。**（已落地）**

并行：Ch.2 第一关可玩内容，而非一次填满 28 关。

---

## 6. 成功标准

- 新审计不再引用「单槽缓冲 / 全局 time_scale / 无招架脆弱态」为开放债务。  
- Phase 1：轻重视挥砍 timing 可由动画事件复现；敌人破韧与玩家共用求解器契约。  
- Phase 3：至少一条 NPC 对话链 + 一种结局可由运行时解析（隐藏结局可仍任务门控）。

---

## 7. 关键证据路径

| 用途 | 路径 |
|------|------|
| 当前焦点 | `docs/devlog.md` |
| 主 backlog | `docs/tasks-master.md` |
| 验证边界 | `docs/validation.md` |
| 叙事运行时边界 | `docs/story/chapter-bridge-map.md`、`docs/00-master-index.md` |
| 权威玩家脚本 | `game/scripts/player/player.gd` |
| 本地 Hit-stop | `game/scripts/combat/hit_stop_manager.gd` |
| 敌人 AI | `docs/systems/enemy-ai.md` |
