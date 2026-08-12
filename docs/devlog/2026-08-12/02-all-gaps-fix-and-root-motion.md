# 全量缺口收口 + 真根运动接入

> 2026-08-12 · 依据 [01-cast-hitbox-real-animation-session-reflection.md](01-cast-hitbox-real-animation-session-reflection.md) 之后的缺口清点；subagent 分波执行（W1 真 clip 扩展 → W2 根运动+注入校验 → W3 精英改名移动 → W4 许可核查 → W5 确认-记录 → W6 文档同步）。

---

## 本波做了什么

### W1 — 真动画覆盖扩展（D-01 续）
- headless 枚举 OAL `MeleeLib.res`(121) + `ShooterLib.res`(180) 全 clip 清单（含每 clip length/track/根位移轨），选片映射 **12 个新状态键**：
  `colossal_leap`(←HeavyJumpAttack)、`greatsword_leap`、`hammer_slam`、`ultra_slam`（四个 leap-slam 战技共享源）、`riposte`(←Stab1)、`backstab`(←cqb-KO-attacker-back)、`spear_charge_stance`、`sword_guard_stance`、`shield_counter_stance`、`fist_deflect_stance`、`curved_spin`(←HeavySpin)、`dagger_backstep_stance`(←Retreat)。
- 重定向工具 `retarget_oal_to_mannyquin.gd` STATE_KEY_MAP 扩到 **19 键**；`mannyquin_lib.tres` 现含 **20 clip**（绑位兜底 + 19 状态键）。
- **施法键保持程序化**：法术 id（veil_bolt 等）无 OAL 对应。

### W2 — 真根运动接入 + 注入校验（D-05 + 04 记的边缘）
- **修复潜伏 bug**：桥 `root_motion_track` 原为 `../RootMotionSkeleton:Root`，Godot 按 NodePath 字符串精确匹配——**从未匹配，`consume_root_motion()` 恒返回 0**。改为 `RootMotionSkeleton:Root` 后 D-02 根运动路径首次激活。
- 工具对 `ROOT_MOTION_KEYS`（当前仅 `colossal_leap`）把源 `Hips` 根位移 bake 成 `RootMotionSkeleton:Root` 位置轨（相对位移、首键归零）；OAL 前进 = 本地 -Z，与游戏一致，无需翻转。
- 桥：`_real_surviving` 存活集——`_real_clip_for` 按注入后库解析，被剔 0 轨的 clip 不再被任何状态认领（闭合 04 记的边缘）；`_remap_real_clip` 对受控键保留 `RootMotionSkeleton:Root` 轨。
- `player.gd`：仅改跃击位移消费——真 clip 净前冲 ≥ 0.5m 时用真根运动，否则回退 authored `leap_lunge`。命中窗维持 state 计时（devlog-05 教训，未动）。
- 新契约 `real_root_motion_contract.gd`（`REAL_ROOT_MOTION_CONTRACTS_OK`）；`real_oal_retarget_contract.gd` BATCH_KEYS 扩到 19 键。

### W3 — 精英名册改名 + 位置移动（L-22）
- **11 项 display_name 对齐设计名册**（id 全不改）：Ch1 `elixir_golem`→炼丹痴魂；Ch2 `torture_master`→炉暴刑具、`beacon_lord`→双生烽火守将、`siege_commander`→贪噬军需官；Ch3 `reflection_lord`→镜湖织梦者、`fox_bride`→迷宫诗人；Ch4 `celestial_swordsman`→云桥守将、`alchemy_master`→坠天工匠、`scripture_keeper`→经文守卫；Ch5 `gravity_twister`→逆熵化身、`soul_forger_echo`→最后的烛阴侍者、`void_sentinel`→可能性之海。
- **3 个错位精英移动出生位**（改 `appears_in` + 目标 level case 加生成块）：`siege_commander` 2-2→2-5、`fox_bride` 3-3→3-5、`void_sentinel` 5-1→5-3。掉落/存档按 id 引用，自动跟随。
- 新契约 `elite_name_contract_test.gd`（`ELITE_NAME_CONTRACTS_OK`）；`chapter2_slice_contract_test.gd` 精英位置断言同步更新；`game_world.gd` 全部精英生成注释更新为新名。

### W4 — 分发许可核查（UNVERIFIED→VERIFIED-WITH-CONSTRAINT）
- **Mixamo/Adobe**：项目内嵌（含商业）允许；**禁止再分发原始动画文件 / 构建数据集**（Adobe 官方 FAQ + 社区版主）。
- **OAL**：仓库**无 LICENSE 文件**（API/tree/本地 clone 三重确认）→ 默认"保留所有权利"；MeleeLib/ShooterLib 为作者自建 rigify 动画，非 Mixamo 资产。**商业使用 / bake 进 mannyquin_lib.tres / 随游戏分发，均需 OAL 作者书面许可**，或更换有干净许可的源。
- Adobe ToS §6.2.E 逐字文本未能取得一手来源（官网抓取超时），仍标 UNVERIFIED 待法律复核。

### W5 — 已解决项确认（只读）
props 8 GLB 全解析；`12-Weapon-Types` shelf 刻意排除；LimboAI 经 `.godot/extension_list.cfg` 加载（无 plugin.cfg 属正常）；`body_class_override` 已持久化；敌人攻击 `.tres` 17/17 覆盖；`memory_eater` 已改名。全部 RELIABLE，无需改动。

### W6 — 文档同步
`tasks-master.md` / `master-index.md` / `content-gap-backlog.md` 状态同步到 2026-08-12（D-01 部分、D-03/D-05/H-04/L-18…L-24 收口、20 clip 修正）；`profiles_ch1.gd`/`profiles_ch5.gd` 头部去"占位"；`research-real-animation-pipeline.md` 补真根运动决策 + 真 clip 覆盖表。

---

## 验证（父进程独立重跑）

| 项 | 结果 |
|---|---|
| 解析（`--headless --editor --quit`） | EXIT 0 |
| 运行时 smoke | `ASHEN_HOLLOW_SMOKE_OK` |
| GUT | **96/96** |
| 契约 | `REAL_ROOT_MOTION` / `ELITE_NAME` / `ASHEN_CHAPTER2_SLICE` / `ASHEN_REAL_OAL_RETARGET` / `PLAYER_ANIMATION_REAL` / `ASHEN_LIGHT_HITBOX` / `ASHEN_CAST_SKILL_REAL_CLIP` / `ASHEN_ANIMATION_ROOT_MOTION` / `G01_MACRO_BT` 全绿 |
| 范围 | 仅期望路径变动（工作树仍 48 项 dirty/untracked 基线 + 本波增量） |

---

## 关键发现与手感变化（需实机确认）

1. **根运动路径首次激活**：`root_motion_track` 路径 bug 修复后，**程序化身体/无真层的跃击位移从静默代码驱动 ~2.53m 变为根运动 ~1.65m**；轻击根运动（0.55m）同步激活。真模型场景：真 `colossal_leap` 源（HeavyJumpAttack）净前冲仅 ~0.04m → gate 正确回退 authored ~2.53m，主路径跃击位移不变。
2. **真 clip 手感未实机验证**（VLM 服务器不可达 + 无渲染通道，视觉 QA 本波 SKIPPED）：leap/riposte/backstab/stance 的姿势观感、`backstab` 2.2s 偏长、stance 用攻击循环充当"姿态"是否成立，均待实机。
3. **许可**：OAL 无 LICENSE → 分发前需作者书面许可或换源。

---

## 实机 QA 清单（用户）

1. 进游戏用真模型角色，依次触发：idle / walk / strafe（锁敌四向）/ 轻击 / 跃击 / 背刺处决 / 刺击处决 / 各战技 stance，**逐项看姿势**：有无 A-pose、四肢反拧、离地、滑步。
2. **跃击位移**：真模型下确认仍 ~2.4m（gate 回退 authored）；程序化身体下确认 1.65m 是否可接受（若不可接受，调 `_make_colossal_leap` Root 轨或 gate 阈值）。
3. **轻击位移**：根运动 0.55m 是否手感到位。
4. **stance clip**：`hammer_slam` 等战技是否有"起手攻击"而非"姿态"观感；不成立则改回程序化 stance（从 `STATE_KEY_MAP` 移除对应键重跑工具）。
5. **backstab 时长**：2.2s 处决是否过长。
6. 若想自动化：启动 llama.cpp VLM（127.0.0.1:9090）后，可用截图 + remote-vlm 复核姿势。

## 遗留 / 范围外（记录不改）

- **施法/部分战技 body 姿态仍程序化**：OAL 无法术 clip，施法键恒程序化兜底。
- **真根运动手感调优**：机制 + gate 已通，参数（阈值、源 clip 选择）待实机。
- **分发许可**：OAL 作者书面许可未取得（阻断商业分发的潜在风险点）。
- **git 提交**：本波按用户要求不碰 git；工作树整波仍未提交。
