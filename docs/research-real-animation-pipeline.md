# Research — 真动画资产管线（Real Animation Asset Pipeline）

**日期**: 2026-08-11 · **更新**: 2026-08-12（补真根运动决策 + 真 clip 覆盖表）· **引擎**: Godot 4.7.1（`gl_compatibility`, `e:/godot/darksoul/game`）· **调研方式**: Perplexity Pro（web 调研）+ 本地只读复验（headless Godot 4.7.1 实测）

## 一句话结论

管线钩子已全部就绪（真库优先 + 程序化回退），唯一缺的是**落在 mannyquin 58 骨 `DEF-*` 骨架、且按状态键命名的真 clip**。最实用路径是**Godot 内 headless 重定向烘焙**（OAL `SkeletonProfileHumanoid` 命名 → 映射到 `DEF-*`），无需 Blender；且本地已存在一个**零重定向可用种子**（`minnyquinn.glb` 的 `retreat` 就是 OAL "Retreat" 已重定向到玩家同款 DEF 骨架的成品）。

---

## Key Findings（按置信度）

### HIGH — 本地实测确认（`RELIABLE`）

1. **桥的匹配规则是"精确 clip 名 + 精确 `DEF-*` 骨名"**。`player_animation_bridge.gd:381-410`（`_remap_real_clip`）逐轨按 `real_bones.has(bone)` 纯名字匹配，剔除非目标骨与 `root/Root` 根运动骨；`_real_clip_for`（:456）按状态键精确查库。因此任何可用 clip 必须：轨道骨名 = mannyquin 的 `DEF-*`（58 骨），clip 名 = 状态键/战技 stance 键/法术 id。
   - 状态键（`REAL_STATE_KEYS`, :46-50）：`idle, walk, strafe_fwd/back/left/right, sword_light_1, colossal_leap, riposte, backstab`
   - stance 键（`weapon_arts/*.tres`）：`hammer_slam, curved_spin, dagger_backstep_stance, fist_deflect_stance, greatsword_leap, shield_counter_stance, spear_charge_stance, sword_guard_stance, ultra_slam`
   - cast 键 = 法术 id：`arcane_barrage, divine_smite, ...`（`travel_cast(_pending_cast)`）
2. **OAL（`example/Godot4-OpenAnimationLibraries`）MeleeLib（121 clip）/ ShooterLib（180 clip）的轨道骨名 = Godot `SkeletonProfileHumanoid` 精确命名**（headless 枚举 56 名全部对上；含 `Root/Hips/Spine/Chest/UpperChest/Neck/Head/Left*/Right*/手指*.L/.R`，外加 `Weapon/Shield` 与 `DEF-breast.L/R` 残留）。→ **OAL 已处在 Godot 官方重定向机制的原生命名里**（纠正了此前"Rigify 命名"的误判）。
3. **`minnyquinn.glb` 的 `retreat`/`root-retreat` 就是 OAL "Retreat"/"root-Retreat" 已重定向到玩家同款 DEF 骨架的成品**（时长 0.958s 逐骨 key 数近乎一致；`godot_rig/Skeleton3D:DEF-*` 轨道路径与 `mannyquin_lib.tres` 完全同构）。→ **零重定向种子，改一行即可导出**（`export_mannyquin_animations.gd:18 SOURCE_PATH`）。
4. **Godot 4.7.1 有 `SkeletonProfile` / `SkeletonProfileHumanoid` / `RetargetModifier3D`**（运行时 modifier），无 `SkeletonRetargeter` 类，无官方离线 bake。headless 帧捕获烘焙可行但 `UNVERIFIED`（纯 headless SceneTree 下 modifier 确定性未实测）。
5. **导出工具是通用 dumper**：`export_mannyquin_animations.gd` 遍历 GLB 的 AnimationPlayer 全部库/clip 无过滤，marker `ASHEN_MANNYQUIN_ANIM_EXPORT_OK`；只缺 clip 重命名到状态键。

### MEDIUM

6. **humanoid→DEF 骨名映射表完全可推导且已被 minnyquinn 证明**（`LeftUpperArm→DEF-upper_arm.L`, `LeftLowerArm→DEF-forearm.L`, `LeftHand→DEF-hand.L`, `Hips→DEF-hips`, `Spine→DEF-spine.001`, `Chest→DEF-spine.002`, `UpperChest→DEF-spine.003`, `Neck→DEF-neck`, `Head→DEF-head`, `LeftThumbMetacarpal→DEF-thumb.01.L`, `LeftIndexProximal→DEF-f_index.01.L`, … `LeftUpperLeg→DEF-thigh.L`, `LeftLowerLeg→DEF-shin.L`, `LeftFoot→DEF-foot.L`, `LeftToes→DEF-toe.L`）。纯名字重映射的**旋转朝向是否无需调整仍待一个测试 clip 校验**（web 调研提示可能需朝向微调；minnyquinn 成品降低了该风险）。
7. **许可约束**（`VERIFIED-WITH-CONSTRAINT`，2026-08-12）：Mixamo/Adobe —— Adobe 官方 Mixamo FAQ 明确 Mixamo 资产可用于任意项目（含商业）无限次使用，唯一禁止的是"分发原始角色/动画文件"（"the only thing you can't do is distribute the raw character and animation files"）；Adobe 社区 moderator 进一步确认"把 Mixamo 内容做成数据集/数据库发布违反 ToS"、任何独立再分发均违反 ToS。**但** FORMER-README 所引的"Adobe ToS §6.2.E"具体条号未能在 Adobe 一手原文核实（`adobe.com/legal/terms.html` 多次抓取超时、Wayback 不可达），该条号仅见于作者自述，须按"作者转述、非逐字引用"对待。OAL —— 仓库**无 LICENSE 文件**（GitHub license API 404、完整 tree 与本地 clone 均无 `LICENSE`/`COPYING`、侧栏无 license 字段、Godot Asset Library 亦未收录该库），无许可 = 默认"保留所有权利"（proprietary）；MeleeLib/ShooterLib 系作者自建 rigify 系动画（提交历史 "Updating the rigify based body shape animations, in prep for natural based libraries"、"in active development as a build my game"），非 Mixamo 下载资产，故 Adobe/Mixamo 限制对本库大概率不适用。**保守结论**：商业游戏内使用、重定向烘焙进 `mannyquin_lib.tres`、随游戏分发烘焙库，均需 OAL 作者（catprisbrey / "Bones in the Walls"，https://bonesinthewalls.bandcamp.com）书面许可，否则须换用许可干净且来源可溯的源（CC0/MIT/CC-BY）。来源：Adobe 官方 Mixamo FAQ https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400 · Adobe 社区 dataset 回复 https://community.adobe.com/t5/mixamo-discussions/making-dataset/m-p/11470217#M76 · OAL 仓库 https://github.com/catprisbrey/Godot4-OpenAnimationLibraries（`.../blob/main/LICENSE` 返回 404）· Adobe ToS https://www.adobe.com/legal/terms.html（一手原文抓取超时）。

### LOW

8. `RetargetModifier3D` 无离线 "bake to Animation" 方法；烘焙需自写帧捕获循环。

---

## Project Documentation Reviewed

| 文档 | 状态 | 证据 |
|---|---|---|
| `docs/devlog/2026-08-11/04-risk-fixes-validation.md:51`（"真 clip 命名用状态键即精确匹配"） | RELIABLE | 与桥实现一致 |
| `docs/devlog/2026-08-11/01-85-glb-into-game-real-model-milestone.md`（真模型 86/88 静态、路线 B 待重定向） | RELIABLE | 与 GLB 静态事实一致 |
| `docs/devlog/2026-08-11/03-all-gaps-fix-orchestration-reflection.md:11,27-29,106,148`（真库优先+程序化回退；路线 B 待 Mixamo/OAL 重定向为显式遗留项） | RELIABLE | 与桥一致 |
| `docs/planning/soulslike-gap-analysis.md:39`（真动画资产 P0 #1） | RELIABLE | 未完成项 |
| `docs/research/godot/actions-combat.md`（"no AnimationTree / single-slot" 结论） | STALE/CONTRADICTED | 已被 D-01 真库优先管线取代（此前已标注） |
| `game/scripts/tools/export_mannyquin_animations.gd` / `mannyquin_lib.tres`（当前仅绑位 clip） | RELIABLE | 实测 |

---

## Sources（web，访问 2026-08-11，Perplexity Pro）

- Godot 官方动画重定向：https://godotengine.org/article/animation-retargeting-in-godot-4-0/ · https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Mixamo 库 + bone map 实用工作流：https://github.com/jwelchgames/Godot4-MixamoLibraries
- OpenAnimationLibraries：https://github.com/catprisbrey/Godot4-OpenAnimationLibraries
- Mixamo 动画 → Godot 库导出：https://github.com/geowarin/godot-anim-lib-export
- Mixamo retargeter 插件：https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter
- 许可讨论（Godot 社区 / Reddit）：https://www.reddit.com/r/godot/comments/xg2av0/ · https://www.youtube.com/watch?v=NZpj25eu5BQ

（本地证据为最高优先级来源，均已 headless 实测；web 结论为次要引用，未做逐条反校验的部分标 `UNVERIFIED`。）

---

## Contradictions & Gaps

- **Phase-0 误判已修正**：OAL 轨道命名是 `SkeletonProfileHumanoid`（非 Rigify `DEF-*`、非自定义）。
- "61 骨" vs 实测 58 骨（devlog 01 §2.6 与 GLB 不一致，minor）。
- `UNVERIFIED`：① headless 下 `RetargetModifier3D` 帧捕获烘焙的确定性；② 纯名字重映射旋转朝向是否需要调整。`VERIFIED-WITH-CONSTRAINT`（2026-08-12）：③ OAL 许可——仓库确无 LICENSE（默认"保留所有权利"，详见项 7）；Adobe §6.2.E 逐字文本未取得 Adobe 一手来源（官网抓取超时），仍须法律复核 Adobe ToS §6.2。
- 已知边界（devlog 04:52）：恰名但被剔空的 clip 会让 `_clip_path` 指向不存在的 `real/<clip>` —— 建议注入前校验。**已于 2026-08-12 落地**：桥在注入时按"幸存 clip 集"解析——被剥离/0 轨的 clip 永不被状态认领（回退程序化），并有契约 `real_root_motion_contract.gd`（marker `REAL_ROOT_MOTION_CONTRACTS_OK`）。

---

## 2026-08-12 补充：真根运动决策（RELIABLE — 本会话实测定稿）

- **路径 bug**：桥的 `root_motion_track` 原为 `"../RootMotionSkeleton:Root"`（相对 AnimationTree 子节点），与动画轨 `RootMotionSkeleton:Root`（相对 AnimationPlayer 根）是两条不同 NodePath → `consume_root_motion()` 恒 0，根运动从未流过树（leap/轻击一直静默回退代码驱动）。**已改为 `NodePath("RootMotionSkeleton:Root")`**（`player_animation_bridge.gd:776`）。
- **烘焙**：`colossal_leap` 的真根位移已烘焙进 `mannyquin_lib.tres`（`REAL_ROOT_MOTION_KEYS` 白名单 `[&"colossal_leap"]` 保留 `RootMotionSkeleton:Root` position 轨）。
- **玩家门槛**：仅当真 clip 净前向 ≥ 0.5m（`LEAP_REAL_ROOT_MIN_FORWARD`）才走真根运动；OAL `HeavyJumpAttack` 实测仅 ~0.04m（0.0431m）→ **真模型跃击仍回落 authored 代码驱动前冲（~2.53m）**。
- **手感变化（需实机 QA，本会话 SKIPPED——VLM 服务不可用、无渲染路径）**：程序化身体跃击现在经真根运动行进（~1.65m，而非旧的静默代码驱动 ~2.53m）；轻击根运动（0.55m）现已激活。
- **移动模式**：真根运动只负责角色级位移（`consume_root_motion`/`consume_root_motion_rotation`）；locomotion 移动速度仍由游戏侧 `MovementMode` 控制，二者解耦。

## 2026-08-12 补充：真 clip 覆盖表（20 clip）

`mannyquin_lib.tres` 现含 **20 clip**：bind-pose 回退 `Armature|mixamo_com|Layer0_godot_rig` + **19 状态键真 clip**。`retarget_oal_to_mannyquin.gd` 的 `STATE_KEY_MAP` 19 项（7 原 + 12 新，源 OAL MeleeLib/ShooterLib）。旧文档"7 clip"/"9 clip"计数已过时。

| 类别 | 键 | 真 / 程序化 | 来源 |
|------|----|-------------|------|
| 绑定回退 | `Armature|mixamo_com\|Layer0_godot_rig` | 真（静态 bind-pose） | 原 minnyquinn |
| 移动 | `idle` / `walk` | 真 | ShooterLib `idle` / MeleeLib `LightWalking` |
| 移动 | `strafe_fwd/back/left/right` | 真（驱动 D-03 BlendSpace2D） | `LightStrafe45L` / `Retreat`（ground truth）/ `LightStrafeL` / `LightStrafeR` |
| 近战 | `sword_light_1` | 真 | MeleeLib `Slash1` |
| 跃击 | `colossal_leap` / `greatsword_leap` / `hammer_slam` / `ultra_slam` | 真（根运动仅 `colossal_leap` 烘焙） | MeleeLib `HeavyJumpAttack` |
| 处决 | `riposte` / `backstab` | 真 | `Stab1` / `cqb-KO-attacker-back` |
| 战技 stance | `spear_charge_stance` / `sword_guard_stance` / `shield_counter_stance` / `fist_deflect_stance` / `curved_spin` / `dagger_backstep_stance` | 真 | `Stab1` / `Guarding` / `GuardParry` / `HeavySpin` / `Retreat` |
| 施法 / 法术 | `veil_bolt` 等 cast 键 | **程序化** | OAL 无 spell clips → 保留程序化（前臂抬手等身体姿态） |

---

## Recommendations（可执行下一步，按优先级）

1. **零重定向首真 clip（立即）**：把 `export_mannyquin_animations.gd` 的 `SOURCE_PATH` 指向 `res://assets/models/enemy/minnyquinn.glb`，导出 `retreat` 并重命名为 `strafe_back` 写入 `mannyquin_lib.tres` → 桥立刻用真 clip 驱动后撤步，端到端证明管线。注意 `retreat` 无根位移（travel 在 `root-retreat` 的 root 骨上），命名须贴合内容。
2. **批量重定向（主路径，headless，无 Blender）**：写 `tools/retarget_oal_to_mannyquin.gd`：
   a. 载 OAL `MeleeLib.res`/`ShooterLib.res`；
   b. 用 humanoid→DEF 映射表（上表）重命名轨道骨名（或 `RetargetModifier3D` + 帧捕获烘焙）；
   c. 剔除 `root/Root` 根运动轨与 `Weapon/Shield/DEF-breast.*` 残留轨；
   d. 按状态键/战技键命名，写 `mannyquin_lib.tres`；
   e. 先出 1-2 个测试 clip 校验朝向，再批量 15-20 个。
3. **注入前校验**：给桥加一个"注入后每个 REAL_STATE_KEYS 若声称真层驱动则轨道数 > 0"的契约断言，杜绝剔空 clip。
4. **许可**：分发前逐字核对 OAL 许可与 Mixamo ToS；只用许可干净源。

---

## Search Coverage

- 查询：1×Perplexity Pro 合并清单（6 项：4.7 兼容 retargeter / OAL 重定向方式 / mixamorig↔DEF 映射 / .tres 导出 / 许可 / 整体建议）+ 1×follow-up（headless bake、官方 import retarget 烘焙目标名、最实用路径）+ 1×follow-up（取源 URL）。
- 本地反校验：headless dump OAL 两库骨名全集、`SkeletonProfileHumanoid` 56 名枚举、minnyquinn/mannyquin 骨名与 clip 结构、导出工具行为、4.7.1 类 API 探测。
- 排除：未做任何文件修改；未运行 Blender（环境无）；未验证 web 来源的每条细节（标 `UNVERIFIED`）。
