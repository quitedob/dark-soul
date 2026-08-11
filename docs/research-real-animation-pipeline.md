# Research — 真动画资产管线（Real Animation Asset Pipeline）

**日期**: 2026-08-11 · **引擎**: Godot 4.7.1（`gl_compatibility`, `e:/godot/darksoul/game`）· **调研方式**: Perplexity Pro（web 调研）+ 本地只读复验（headless Godot 4.7.1 实测）

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
7. **许可约束**：Mixamo 派生资产不可随商品分发（Adobe ToS）；OAL 已移除 Mixamo 派生库，MeleeLib/ShooterLib 为非 Mixamo 源。游戏分发 `mannyquin_lib.tres` 属派生 clip，须只用许可干净源。`UNVERIFIED`：OAL 实际许可文本逐字核对。

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
- `UNVERIFIED`：① headless 下 `RetargetModifier3D` 帧捕获烘焙的确定性；② 纯名字重映射旋转朝向是否需要调整；③ OAL 许可文本逐字核对。
- 已知边界（devlog 04:52）：恰名但被剔空的 clip 会让 `_clip_path` 指向不存在的 `real/<clip>` —— 建议注入前校验。

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
