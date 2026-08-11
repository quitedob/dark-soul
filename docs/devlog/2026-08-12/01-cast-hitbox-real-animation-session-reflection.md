# 会话执行复盘：施法/战技动画 + 命中盒审查修复 + 真动画管线（子代理编排 · 全部行动 / 难点排查 / 决策 / 记忆）

> 2026-08-12 · 本条目是**过程复盘**（不是交付快照）。交付清单见验证小节与 `docs/tasks/`、`docs/research-real-animation-pipeline.md`。
> 记录：Claude Code 在这整轮"施法/战技动画 + Hitbox 修复 → 全部未决项 → 真动画资产管线"会话里做了什么、遇到哪些难点、怎么排查解决、留下哪些可复用经验与记忆。提交链：`bef2ff8` → `2af1440` → `a9c1a6e`。

---

## 1. 会话总览（4 轮，做了什么）

1. **Code Review 修复（/godot，4 个并行只读调查 → 4 个 EDIT worker）**：修复 code review 的 Finding 1–7 —— 轻击 0 伤害（HIGH）、施法/战技无身体动画（MEDIUM）、空中轻击落空（MEDIUM）、`stance_animation` 死字段（LOW）、Boss clone 物理免疫（LOW）、socket 跟随不转（LOW）、死闩锁+冗余三元（INFO）。另在验证中发现并修复**根运动跃击同源死锁**与**弹体小目标盲点**、**socket 偏移旋转回归**。
2. **全部未决项收口（/godot，6 个并行 EDIT worker）**：A1 cast/skill 真 clip 解析契约 + 程序化前臂抬手；A2a clone 物理命中契约；A2b socket 旋转契约；A3 跃击 windup 位移削减；B4 stamina 测试（根因是测试玩家不在地面，非数据漂移）；B5+C6 文档调和 + devlog 归档。
3. **真动画资产管线调研（/perplexity-research，Phase 0–4）**：Perplexity Pro 合并调研 + 本地 headless 反校验 → 归档 `docs/research-real-animation-pipeline.md`。
4. **真 clip 落地（Step 1 + Step 2，各 1 个 EDIT worker + 父集成）**：Step 1 零重定向种子 `strafe_back`；Step 2 批量重定向工具 `retarget_oal_to_mannyquin.gd`（rest-pose 烘焙，对照地面真值 ≤0.056°），7 个真 clip 全量上线。

**最终验证**（父协调者独立重跑，非 worker 自报）：editor import EXIT 0；12 个契约全绿；smoke `ASHEN_HOLLOW_SMOKE_OK`（真 clip 上线无 track 解析错误）；**GUT 96/96**。

---

## 2. 全部动作时间线（含提交）

| 步骤 | 动作 | 产出 |
|---|---|---|
| 1 | `/godot` · 只读调查（docs scout + 动画 + hitbox 3 worker）→ 协调者逐行复验全部结论 | CONFIRMED 全部 7 finding |
| 2 | Wave：Worker A(player.gd+新测试) / B(bridge) / C(combat_area) / D(boss_clone) 并行 EDIT | Finding 1–7 落地 + `light_attack_hitbox_contract.gd` |
| 3 | 父集成：重跑验证 → **发现 GUT 回归**（死闩锁被 unit test 读取）→ 修测试 | GUT 转绿 |
| 4 | 复查命中盒 → **发现跃击同源死锁** → 退役全部 anim-defer，更新契约测试 | 轻/重/跃统一 state 计时 |
| 5 | 第二轮 6 个并行 EDIT（A1/A2a/A2b/A3/B4/B5+C6） | 未决项全部落地 |
| 6 | 集成期发现 2 个真实判定 bug（W7 弹体盲点 / W8 socket 偏移）→ 各派 1 worker 修 | `projectile_small_target_contract` / `socket_follow_rotation_contract` |
| 7 | 提交 `bef2ff8` | 22 个文件，hitbox/animation/clone/projectile/socket/docs |
| 8 | `/perplexity-research` Phase 0–4（1 只读扫描 + 1 反校验 + 2 次 Perplexity 调用） | `docs/research-real-animation-pipeline.md` |
| 9 | Step 1 worker：导出 minnyquinn `retreat` → `strafe_back` 入库 + 契约 | 提交 `2af1440`（首个真 clip） |
| 10 | 启动 `f:/python/llamacpp/start_server.bat`（llama-server，Gemma4，`127.0.0.1:9090/v1`） | 本地 debug 接口就绪 |
| 11 | Step 2 worker：`retarget_oal_to_mannyquin.gd`（rest-pose 烘焙，7 真 clip）+ 父集成修 2 条过期断言 | 提交 `a9c1a6e`（真 clip 全量上线） |

---

## 3. 难点与应对（detail — 你要的重点）

### D1. 轻击 0 伤害的根因是"两套独立作者化、从未对齐的计时系统"（HIGH）
- **症状**：默认战斗风格轻击命中盒永不开启 → 主攻击键近战 0 伤害。smoke 不测轻击伤害所以从未暴露。
- **排查**：method-track `hitbox_on` @0.18s（`player_animation_bridge.gd:539`）在动画 t=0.18 触发；此时玩家仍在 `ATTACK_WINDUP`（`combat_style_data.gd` 默认 `windup_light=0.3`）。`_should_defer_hitbox_to_anim`（`player.gd:2896`）在 WINDUP 入场算出 defer=false；0.30s 进 `ATTACK_ACTIVE` 时 defer 变 true → `if not _hitbox_anim_deferred: _begin_melee_swing()` 被跳过；动画轨的 hitbox_on 已经错过 → **没有任何路径再开盒**。`_anim_hitbox_latched` 只写不读。
- **应对**：采用 review 方案 (b) —— 退役 anim-defer：轻/重/跃击统一**state 计时**在 `_change_state(ATTACK_ACTIVE/LEAP_ACTIVE)` 入场 `_begin_melee_swing()`；`_should_defer_hitbox_to_anim` 恒返回 false。方法：先逐行读 4 处代码路径确认，再改，再加回归契约（`light_attack_hitbox_contract.gd`，先用 revert/restore 证明测试真能抓 bug）。
- **经验**：`docs/research/godot/actions-combat.md:25,31` 早就警告"method-track 不能成为唯一命中窗口权威"——**代码违背了自己的文档**。先读文档、再读代码、用契约测试把修复钉死。

### D2. 跃击同源死锁（我以为"保留跃击 defer 是安全的"）
- **症状**：修完轻击后，我复查跃击 windup 数据——`twin_colossi.tres leap_windup=0.38`、类 dict 默认 0.3，全部 **> 桥 colossal-leap method-track hitbox_on @0.28s**（`player_animation_bridge.gd:564`）→ 根运动跃击与轻击**完全同构的死锁**，也是 0 伤害。曲刃（crescent）因 `_leap_uses_root_motion=false` 走 state 计时不受影响。
- **应对**：把跃击 defer 一并退役（与轻击同一处改动），并更新契约测试 (d) 断言从"跃击 defer 保留"翻转为"跃击 LEAP_ACTIVE 入场命中盒 active"。
- **经验**：修一类 bug 时，**主动扫描同类模式的所有实例**（同一个 `_should_defer_hitbox_to_anim` 的所有返回真分支），不要只信 review 的排查范围；数据（windup）与动画轨（method-track 时间）必须对齐校验。

### D3. 删死闩锁引发 GUT 回归（我的 grep 漏了 `tests/` 目录）
- **症状**：全量 GUT 报 `Invalid access to property '_anim_hitbox_latched'`（`test_animation_callback_bridge.gd`）。
- **排查**：我删 `_anim_hitbox_latched/_anim_combo_latched` 前只 grep 了 `game/scripts/`，**漏了 `game/tests/unit/`**。unit test 在断言"转发应置位闩锁"。
- **应对**：把该断言改为断言**桥信号被转发**（`hitbox_activated`/`hitbox_deactivated` 触发 + 状态机不被改变）——这才是转发契约的真实语义。
- **经验**：**删除任何"死"符号前，grep 全树（含 tests、unit、integration）**；验证覆盖要全量跑 GUT，不能只跑 smoke/contracts。

### D4. 并行 worker 的缓存污染（phantom 错误）
- **症状**：Worker C 跑 contract 时报 `Function "_resolve_pose_path() not found in base self`，指向我还没写完的 bridge 函数；第二次重跑干净。
- **排查**：Worker B 正在并行改 `player_animation_bridge.gd`，陈旧 `.godot` 缓存让中途状态被其他 worker 的验证读到。
- **应对**：**所有 worker 落地后再统一串行重跑**验证，且父进程不采信 worker 自报。
- **经验**：并行派发时，验证必须放在集成后的父进程统一串行跑；跨文件接口（如 `travel_cast`/`travel_skill` 签名）由父进程在**两个 packet 里都写死**，避免并行期接口漂移。

### D5. stamina 测试"数据漂移"其实是测试环境 bug（推翻初判）
- **症状**：`test_stamina_economy.gd::test_target_style_costs_and_insufficient_block` 失败（57.44 vs 35.0）。我最初在 clean HEAD worktree **复现了同样的失败** → 判为"pre-existing 数据漂移"。
- **排查**：B4 worker 追根——**资源与工厂其实都源自信奉值**（twin heavy 65）；真正原因是 **GUT 玩家不在地面** → `is_on_floor()=false` → `_resolve_context_attack` 走空中分支解析成 `jump_attack`（cost 42.56）。"42.56" 正是空中跳攻的花费。
- **应对**：测试补 `StaticBody3D` 地板（Layer 1，玩家 mask=1）+ await 24 物理帧 + 强制 ONE_HANDED grip → 9/9，全 GUT 96/96。
- **经验**：**"在基线复现失败"≠"数据错了"**——先查测试环境假设（on-floor、grip、state），再怪数据。这推翻了我在上一轮 handoff 里写的"pre-existing 数据漂移"结论，必须诚实修正。

### D6. 弹体扫掠小目标盲点（layer 数学正确 ≠ 物理命中）
- **症状**：W2 做 clone 物理契约时发现：现实速度（15）下 4m 迎面法术**穿 clone 而过**；speed 26/27/30 miss、28/29/32 hit——帧对齐依赖。
- **排查**：`spell_projectile._sweep_motion` 用 `cast_motion` 的 `safe_fraction` 停在**恰好相触边界**（0 穿透），随后 `intersect_shape`（严格相交）返回 0，零半径射线又擦过小目标。
- **应对**：overlap 查询位置沿运动方向前推 `max(radius*0.2, 0.015)` 的 nudge → 球体进入严格相交。W7 修 + `projectile_small_target_contract.gd`（默认速度 15 命中）+ clone 契约降回速度 15。
- **经验**：**静态 layer 数学验证 ≠ 运行时物理命中**；运行时物理帧契约抓得住层位推导漏掉的东西。这类"验证时发现的真实 bug"要如实上报并单独派 worker 修。

### D7. socket `translated()` 语义与代码注释相反（引擎实证压过注释）
- **症状**：W3 实证 Godot 4.7 的 `Transform3D.translated(offset)` **按世界空间加偏移**（只复制 basis），与 `combat_area.gd` 注释声称的"旋转后的局部偏移"相反——旧代码 `to_global(local_offset)` 是旋转偏移的，被 Worker C 的修复**回归**了。
- **应对**：`translated_local(_socket_local_offset)`（偏移进局部帧 + 继承 basis），并更新 `socket_follow_rotation_contract.gd` 断言旋转后的偏移。
- **经验**：**引擎运行时行为压过代码注释/文档**；新 API 先用最小脚本实测语义再信注释。

### D8. 真动画管线的骨名错配（调研推翻直觉）
- **症状/直觉**：初扫认为 OAL 是 Rigify `DEF-*` 命名；Perplexity 回答偏泛化；本地 headless dump 证明 OAL 轨道是 **Godot `SkeletonProfileHumanoid` 精确命名**（56 名全对上）。
- **关键发现**：`minnyquinn.glb` 的 `retreat` = OAL "Retreat" **已重定向到玩家同款 58 骨 DEF 骨架**（逐骨 key 数一致）→ **零重定向种子 + 地面真值**。
- **最大难点**：直接骨名重映射（humanoid→DEF）对照真值 **180° 错**（DEF-hips 104.5°、DEF-forearm 90°、DEF-thigh 180°）。
- **应对**：推导 `RetargetModifier3D` rest-pose 烘焙公式（`pre * src_pose * post`，`pre=tgt_parent_grest.inv * src_parent_grest`，`post=src_rest.inv * src_parent_grest.inv * tgt_parent_grest * tgt_rest`），对照 minnyquinn 真值 **44 根共享骨最大角误差 ≤0.056°**。工具：`retarget_oal_to_mannyquin.gd`（幂等合并，7 个真 clip 上线）。
- **经验**：**本地 headless 实证 > web 调研**；找到 ground truth（minnyquinn）后验证门槛极高，直接否决看似正确的"改名直贴"方案。

### D9. 本地 llama.cpp 服务器（用户要求 subagent 用它 debug）
- **症状**：用户给 `f:/python/llamacpp/start.bat`；实际文件是 `start_server.bat`（llama-server，Gemma4 Q4_K_M，`127.0.0.1:9090/v1` OpenAI 兼容）。
- **应对**：后台启动 + `/health` 轮询确认 `{"status":"ok"}`；在 W10 packet 里写明 curl 调用法。最终 W10 用**引擎 ground truth 验证**烘焙公式，未用到本地 LLM——但接口已就绪，后续 debug 可用。
- **经验**：用户给的路径可能不是字面文件名，先 `find` 定位；本地 LLM 是 debug 辅助，不是唯一权威——**引擎/契约测试才是**。

---

## 4. 决策记录

| 决策 | 依据 | 结果 |
|---|---|---|
| 轻/重/跃击全部退役 anim-defer（方案 b） | method-track 时间与 AttackData 计时从未对齐；state 计时与重击一致、零动画依赖 | 命中盒一律在 ATTACK_ACTIVE/LEAP_ACTIVE 入场开启 |
| 保留桥的 `combo_window_*` 信号、只删玩家侧死闩锁 | 测试（unit + smoke）直接消费桥信号 | 信号契约不破 |
| clone 用 `StaticBody3D` + Enemies 层（raw 4）、mask 0 | 玩家命中盒 mask=4、法术扫掠 1\|4；自身永不反碰 | 物理可命中且无副作用 |
| `translated_local()` 而非 `translated()` | 引擎实证偏移需进局部帧 | 旋转偏移语义恢复 |
| 批量重定向用 rest-pose 烘焙而非改名直贴 | 真值对比 180° 错 | ≤0.056° 误差 |
| `strafe_back` 先零重定向落地 | 它是 OAL 已重定向成品，改一行即可 | 端到端证明管线 |
| 只提交本会话文件，不扫入用户既有 dirty 树 | 用户 49 个 pre-existing dirty/untracked 文件属于其独立工作 | 3 个 commit 干净可回溯 |

---

## 5. 验证结果（父协调者独立重跑）

- **Editor import**：EXIT 0。
- **12 个契约**全绿（每个都读源码 marker 再跑）：`light_attack_hitbox`、`cast_skill_real_clip`、`boss_clone_collision`、`socket_follow_rotation`、`projectile_small_target`、`real_strafe_back`、`real_oal_retarget`、`player_animation_real`、`animation_root_motion`、`combat`、`boss_attack_types`、`boss_polish`、`projectile`（integration）。
- **Smoke**：`ASHEN_HOLLOW_SMOKE_OK`——Step 2 后真 clip 全量上线，无 "couldn't resolve track" / "Nonexistent function" 错误。
- **GUT**：`tests/unit` **96/96**（B4 修掉唯一失败；死闩锁回归已修）。
- **范围**：3 个 commit 只含本会话 22+6 个文件；用户 49 个 pre-existing dirty/untracked 原样保留。

---

## 6. 记忆更新（auto-memory）

`ember-abyss-architecture-facts.md` 增量记录（非重复已有代码结构）：
- **D-08 命中盒计时架构**：method-track 时间与 AttackData 计时两套独立作者化从未对齐 → 轻击 + root-motion 跃击 0 伤害；anim-defer 全量退役，统一 state 计时；回归契约 `light_attack_hitbox_contract.gd`。若未来恢复动画驱动命中盒，必须先让 method-track 与 AttackData 对齐。
- **附加命中判定修复**：`spell_projectile._sweep_motion` 小目标盲点（cast_motion 相触边界 + intersect_shape 严格相交返回 0）→ overlap 查询加 nudge；`combat_area._sync_socket_follow` 用 `translated_local()`；`test_stamina_economy` 根因是测试玩家不在地面（补地板修好）。
- **真动画管线（Step1+Step2）**：桥按精确 clip 名 + `DEF-*` 骨名匹配；OAL 是 `SkeletonProfileHumanoid` 命名；minnyquinn = OAL 已重定向成品（地面真值）；`retarget_oal_to_mannyquin.gd` rest-pose 烘焙 ≤0.056°；`mannyquin_lib.tres` 现有 9 clip（绑位 + strafe_back + 7 批量）；本地 llama.cpp `127.0.0.1:9090/v1` 可作 subagent debug 接口。

---

## 7. 未完成项（诚实清单）

1. **真 clip 视觉观感未实机验证**：idle/walk/light 姿态、跃击 windup 削减手感——headless 只能证结构/数学正确，不能看观感。
2. **`colossal_leap / riposte / backstab` 与战技 stance（`hammer_slam` 等）/ 施法 clip 仍程序化回退**——OAL 无现成对应，需再选源或混搭。
3. **分发许可**：Mixamo ToS / OAL 逐字核对（`UNVERIFIED`）。
4. **真 clip 根运动**：现在 root 轨被剔，位移靠游戏自身 RootMotionSkeleton 契约（轻击 lunge 走代码 `authored_displacement`）——若未来想用真 clip 的位移，需要单独接根运动。

---

## 8. 可复用经验速查

- 修一类 bug → **扫描同类模式全部实例**（D1→D2）。
- 删"死"符号 → **grep 全树含 tests**（D3）。
- 并行派发 → 验证在**集成后父进程统一串行重跑**；跨文件接口签名由父写死在所有 packet（D4）。
- "基线复现失败" → **先查测试环境假设再怪数据**（D5）。
- layer 数学正确 ≠ 物理命中 → **运行时物理契约**（D6）。
- 引擎运行时行为 **压过代码注释**（D7）。
- 本地 headless 实证 **压过 web 调研**；找到 ground truth 设高验证门槛（D8）。
- 用户给的脚本路径可能是别名 → 先 `find` 定位；本地 LLM 是辅助，**契约测试才是权威**（D9）。
