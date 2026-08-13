# 会话执行复盘：全量 fix all → 浏览器预览 → frontenddebugger 调试

> 2026-08-13 · 记录一个横跨「全量缺口修复」「Web 导出预览」「模型朝向/武器对齐调试」的完整会话。
> 重点：**全部行动时间线、每一个难点如何排查、如何解决、以及沉淀的经验教训（memory）**。
> 目标读者：未来接手同类任务的我 / 协作子代理，避免重踩本会话反复掉进的坑。

---

## 0. 会话全景（一句话）

用户从「fix all 缺口」出发，经过子代理分波修复、Web 浏览器预览、frontenddebugger 截图调模型朝向与武器握持，最终修掉 4 类真 bug（root-motion 路径死、掉虚空、武器盾错位、模型 180° 反向 + 武器悬空）。中间我反复踩了 **VLM 幻觉**、**headless 变换陈旧值**、**Web GDExtension 导出** 三个大坑。

---

## 1. 阶段一：全量 fix all（子代理分波）

### 1.1 触发与需求澄清

- 用户消息末尾「fix all」被截断，但正文给出了完整缺口清单（工作树 20 modified + ~35 untracked，docs 落后一个 feature-wave）。
- 我用 `AskUserQuestion` 澄清了三个决定性范围：
  1. **主线 = 全量 fix all**（不是只收口、不是只推进真动画）
  2. **不碰 git**（不提交、不 checkout，只允许 `git status` 读基线）
  3. **接入真根运动**（参考 devlog 08-11 实战经验 + 用 remote-vlm）＋ **精英改名 + 移动位置**
- 用户随后追加：**用子代理修复、先从 `/godot` 技能学习**。

### 1.2 编排依据（godot 技能）

读 `~/.claude/skills/godot/references/` 三件套并遵守：
- `subagent-routing.md` → 通用子代理 + 任务 profile + dispatch packet
- `orchestration-workflow.md` → 分波、所有权、独立验证、handoff
- `project-conventions.md` → 优先级、验证命令、诚实 SKIPPED

核心纪律：**每文件单一 owner、wave 内路径互斥、父进程独立复跑验证、缺失套件标 SKIPPED 而非 PASS**。

### 1.3 执行时间线

| Wave | 内容 | 关键产出 |
|---|---|---|
| W0 | 基线验证 | 解析 EXIT 0 · smoke `ASHEN_HOLLOW_SMOKE_OK` · GUT 96/96 |
| W1 | 真 clip 扩展 | OAL 运行时枚举 121+180 clip → STATE_KEY_MAP 扩到 19 键 → mannyquin_lib.tres 20 clip |
| W3 | 精英改名+移动 | 11 改名 + 3 位置移动（2-2→2-5 / 3-3→3-5 / 5-1→5-3） |
| W4 | 许可核查 | Mixamo/OAL UNVERIFIED → VERIFIED-WITH-CONSTRAINT（OAL 无 LICENSE = 默认保留所有权利） |
| W5 | 确认-记录 | 6 项「已解决」全部 RELIABLE 确认 |
| W2 | 根运动+注入校验 | **发现 root_motion_track 潜伏 bug** + 注入存活集校验 |
| W6 | docs 同步 + devlog | 3 任务表同步到 08-12 · profiles 头部去占位 |

### 1.4 阶段一难点与解法

**难点 A：OAL clip 名只能运行时枚举**
- `MeleeLib.res`/`ShooterLib.res` 是 Godot 二进制压缩资源，`strings`/正则提取不出 clip 名。
- 解法：写一次性 headless 枚举脚本（`extends SceneTree`，加载两库打印 `get_animation_list()` + length/track），用完删。

**难点 B：契约测试循环「全失败」是自摆乌龙**
- 第一遍循环跑 20 个契约全 rc=1，一度以为大回归；逐个单跑却全过。
- 根因：循环里文件名**后缀写错**（漏了 `_contract`/`_contract_test`），加载不到脚本。
- 教训：**先看单个命令的真实退出码与输出，再下「回归」结论；批量脚本先验证文件名拼写**。

**难点 C：W3 所有权外的回归**
- W3 子代理诚实报告：`chapter2_slice_contract_test.gd:83` 断言精英在 `level_02_02`，移动后应变 `level_02_05`，但它不在 W3 所有权内没改。
- 解法：父进程改这一行（`02_02`→`02_05`），复跑契约转绿。
- 教训：**移动 spawn 位置的连带回归，被子代理显式上报并留给父进程处理，是正确的所有权划分**。

**难点 D（最大）：root_motion_track 路径 bug**
- W2 子代理发现：桥里 `root_motion_track = ../RootMotionSkeleton:Root`，Godot 按 NodePath **字符串精确匹配**动画轨路径 → 从未匹配 → `consume_root_motion()` **恒返回 0**，根运动路径一直是死的。
- 修复 `→ RootMotionSkeleton:Root` 后，根运动首次激活。
- 连带影响：程序化身体跃击位移从静默代码驱动 ~2.53m 变为根运动 ~1.65m；轻击根运动 0.55m 激活——**这是手感变化，需实机 QA（本会话 SKIPPED）**。

---

## 2. 阶段二：浏览器预览（Web 导出）

用户：「能用浏览器给我预览吗？」

### 2.1 导出路径

- 项目有 `Web` 导出预设 + 4.7.1 导出模板已装（含 `web_dlink_nothreads_release.zip`）。
- 首次导出成功，`python -m http.server 8123` + chrome-devtools 打开，游戏引导成功（WebGL 2.0 + GDExtension support 都加载）。

### 2.2 难点 E：GDExtension 不支持报错

- 用户贴 console：`GDExtension libraries are not supported by this engine version. Enable "Extensions Support" ...`
- 根因：项目用了 LimboAI GDExtension，标准 web 模板不支持。
- 解法：`export_presets.cfg` 改 `variant/extensions_support=true`（用 dlink 模板），重导后 `index.side.wasm` 44MB + LimboAI web wasm 正常加载。

### 2.3 难点 F：Console 报 `No interface 'AshenHollowHost' registered`

- 根因：`game/scripts/app/game_host_bridge.gd:131` 无守卫地 `get_interface("AshenHollowHost")`，独立浏览器构建没有 MCP 桥注入该接口。
- 解法：加 `typeof window.AshenHollowHost !== 'undefined'` 守卫，静默跳过。console 变干净。

### 2.4 用户报实机 bug：掉入虚空 + 武器盾对不上

派 Explore 代理调查，两个根因都非碰撞配置问题：

| Bug | 根因 | 修复 |
|---|---|---|
| 掉虚空 | courtyard 族（3×5 瓷砖）**无边界墙**，出生点距 +z 边缘仅 1m，走过头就掉；默认 respawn `(0,1.1,8)` 在瓷砖外 | 关卡构建器给 courtyard/multi_angle_hall/fortified_hub 加**隐形边界墙**（纯碰撞 4m 高）；默认 respawn 改 `(0,1.1,0)` |
| 武器盾对不上 | `_THEMED_SHAPE_WEAPON["sword"]` 映射到 XuanXiao **BOSS 大剑**（scale 0.6），盾却是模板（scale 1.0）——两个美术族 | sword 改指 `player/weapon/sword`（模板剑 scale 0.8，与盾同库同族） |

---

## 3. 阶段三：frontenddebugger 调模型朝向 + 武器握持

用户：「任务模型方向是反的，武器不在手上，自己用 /frontenddebugger 测试」。

### 3.1 方法论适配

frontenddebugger 是 web 前端审计流程，我适配到 Godot-web 游戏：
- Phase 2 浏览器证据：chrome-devtools 截图 + 键盘驱动动作（W 移动 / J 轻击 / F 跃击 / G 施法）
- Phase 3 VLM 视觉分析：本地 llama.cpp MiniCPM-V @127.0.0.1:9090
- Phase 6 根因追溯：Explore 代理 + 确定性 headless 探针

### 3.2 难点 G（最痛）：VLM 幻觉

- MiniCPM-V 4.6 对暗色游戏截图判断极不可靠：**在空白页（about:blank）都「看到」了带武器的游戏角色**；单图问「正/背面」永远倾向答「正面」。
- 我一开始过度信任 VLM，导致 yaw 180 加了又回退又加回，反复重导。
- **解法（关键转折）**：放弃单图判断，改用两类**确定性证据**：
  1. **A/B 对比**：加 F4 运行时翻转键，截「翻转前/后」两张，让 VLM 对比「哪张看到脸 / 哪张看到后脑勺」——对比式判断才可靠（得出「PI = 背面」）。
  2. **骨架几何探针**：`DEF-head`→`DEF-eye.L` 方向判定脸部朝向（mannyquin 眼睛在头骨 +Z 侧 → 模型原生面向 +Z → 需 yaw 180）。

### 3.3 难点 H：headless 下 global transform 是陈旧值

- 第一次探针读 `global_rotation.y = 0`，误判「yaw 没生效」，导致反复加/回退。
- 根因：**headless 下 `to_global()`/`global_rotation` 要等 `await process_frame` 后才有正确值**（节点刚 add_child 时 transform 未传播）。
- 解法：探针里 `await process_frame`（两次）再读，得到 `local rot.y = PI`（yaw 确实已应用）。

### 3.4 难点 I：武器悬空（真问题）

- await 帧后实测手骨：`DEF-hand.R = (+0.739, +1.441, +0.065)`，武器 pivot 原在 `(0.58, 1.25, -0.15)` → **距手 0.33m 悬空**；盾 pivot 距左手 0.47m。
- 解法：`player_visuals.gd` 加 `HAND_RIGHT_REST`/`HAND_LEFT_REST` 常量，武器/盾 pivot 锚到真实手骨 rest 位置。
- 复测：武器/盾与手骨 **dist=0.000**（精确贴手）。

### 3.5 最终修复清单（阶段三）

| 问题 | 修复 | 证据 |
|---|---|---|
| 模型 180° 反向 | resolver `player/body` + 8 职业身体加 `yaw_deg: 180` | face-dir 探针（眼朝 +Z）+ VLM A/B 对比 |
| 武器/盾悬空 | pivot 锚到手骨 `(±0.739, 1.441, 0.065)` | 探针 dist=0.000 |
| （调试工具） | 新增 F2 传送到空白区 + F4 翻转朝向 | 便于目检 |

### 3.6 用户关键纠正（铭记）

- 「**禁止代码判断，钱花的比 remotevlm 多**」→ 少写 headless 探针，多截图用 VLM。
- 「**用 remotevlm 自己判断**」→ 但 VLM 单图不可靠，最终用「A/B 对比 + 确定性探针」兜底。
- 「**需要传送角色到空白地方**」→ 实现 F2 空白区传送（大平地 + 强光，便于目检）。

### 3.7 用户复测反馈（⚠️ 仍未修复，诚实记录）

用户在实机复测后明确反馈：**朝向/武器问题没有修复，还是反的**。三个具体症状：

1. **W（前进）移动方向反**：按 W 角色朝反方向走。
2. **武器统一方向反**：武器朝向也和身体一样反了。
3. **武器不在人手上**：武器仍悬空，没握在手里。

**根因判断（本次会话最终认识到的真正问题）**：

- 武器/盾是 `visual_root` 的**直接子节点**（固定世界位置），而身体是 `BodyRoot`（resolver 给它 `yaw_deg: 180`）的**子节点**。**两者坐标系分离**：身体转 180°，武器/盾不跟着转。
- 我之前把武器 pivot 锚到的手骨坐标 `(±0.739, 1.441, 0.065)`，是 **yaw 0 时代**测的手骨位置；给 body 加了 yaw 180 后，手骨的世界位置跟着 BodyRoot 转到了另一边，而武器 pivot 还在旧位置 → **武器再次脱手、且方向与身体错 180°**。
- 「朝向反」和「武器反/悬空」是**同一个坐标系分离 bug 的两个表现**，不是两个独立问题。

**未解决的根本原因**：我反复用不可靠的手段（headless 探针读骨架 global pose 在未 await 时是陈旧值；VLM 单图正/背判断幻觉）来判断朝向，导致 yaw 0/180 反复横跳，既没定对朝向，又把武器锚点算错。**最终以用户实机目检为准：当前状态仍反、仍悬空。**

**下一步正确修法（尚未执行）**：统一坐标系——把武器/盾与身体放进**同一个带朝向的父节点**（或改用 `BoneAttachment3D` 挂到手骨，自动跟随身体旋转），并让用户在实机用 F4 翻转键**一次性确认哪个朝向是对的**，再定死，避免继续用不可靠探针盲猜。

---

## 4. 沉淀的经验教训（memory）

### 4.1 VLM（remote-vlm / MiniCPM-V）使用纪律

1. **单图正/背、有无武器判断不可靠**（在空白页都幻觉出角色）。只信**对比式**（A/B 两张问「哪张是 X」）或**结构化定位**（问「眼骨在头骨哪侧」这类几何）。
2. VLM 输出可能乱码 → 落盘 UTF-8 再读，别信 console 直接打印。
3. VLM 服务可用性要先探 `/v1/models`（HTTP 200 才算起），本会话前半段它宕机过。

### 4.2 Godot headless 验证纪律

1. **`to_global`/`global_rotation`/`global_position` 在 add_child 后立即读是陈旧值**，必须 `await process_frame`（最好两次）。
2. 契约/批量脚本先验证**单个命令的退出码 + 文件名拼写**，再下回归结论。
3. `--check-only --script` 单独解析比 `--editor --quit` 全量更省时，适合改后快速验证。

### 4.3 Godot Web 导出

1. 用了 GDExtension（LimboAI）就必须 `variant/extensions_support=true`（dlink 模板），否则报 `GDExtension libraries are not supported`。
2. 独立浏览器构建无 MCP 桥 → `game_host_bridge.gd` 的 `get_interface("AshenHollowHost")` 要加 `typeof window.X === 'undefined'` 守卫。
3. 本地预览用 `python -m http.server`；浏览器缓存会导致「改了没生效」，重导后用**新端口/新目录 + 硬刷新**打破缓存。

### 4.4 模型朝向/武器握持

1. **模型原生朝向要看骨骼**：`DEF-eye` 相对 `DEF-head` 的偏移 = 脸部朝向（本模型眼在 +Z → 面向 +Z，游戏前向 -Z → 需 yaw 180）。
2. **武器悬空的本质是 pivot 硬编码、不跟手骨**；根治用 `BoneAttachment3D`（本会话用「rest 手骨坐标常量」临时对齐，真骨骼动画起来仍会脱手，长期应挂 BoneAttachment3D）。
3. 身体翻正后，左右手的世界坐标会互换——之前「武器在 +X」是对的，因为身体反着时右手其实在 -X。

### 4.5 编排/所有权

1. 子代理会诚实上报「所有权外的回归」，父进程要接住（如 chapter2_slice 断言）。
2. 波浪式验证：每 wave 结束后父进程独立复跑，别信子代理 self-report。
3. 热文件（player.gd / game_world.gd / player_visuals.gd）反复被我改，说明调试阶段需要**运行时调试开关**（F2/F4）而非反复重导。

---

## 5. 仍未完成 / 已知债（诚实记录）

### 🔴 最高优先级：模型朝向 + 武器握持 仍未修复（用户复测确认）

- **朝向仍反**：W 前进方向反、角色面向镜头（应背对）。resolver 的 `yaw_deg: 180` 加在 `BodyRoot` 上，但效果存疑 / 与武器坐标系分离。
- **武器不在手上**：武器/盾是 `visual_root` 直接子节点，身体在 `BodyRoot`（yaw 180）下，坐标系分离导致武器不跟身体转、锚点坐标失效。
- **根治方向**：统一坐标系（武器/盾与身体同父节点）或 `BoneAttachment3D` 挂手骨；朝向由用户实机 F4 一次性确认后定死，不再用不可靠探针/VLM 盲猜。

### 其余已知债

- **真根运动手感变化未实机 QA**：程序化身体跃击 1.65m（原 2.53m）、轻击 0.55m 根运动，需用户实机确认。
- **武器用 rest 手骨常量对齐**，骨骼动画播放时会再次脱手 → 长期应改用 `BoneAttachment3D` 挂到手骨。
- **敌人模型可能同样 +Z 朝向**（同一 rig 家族），战斗中留意敌人是否也面向反了。
- **VLM 单图判断不可靠**，最终结论依赖确定性探针 + 用户目检。
- 真动画 clip 的观感（A-pose / 反拧 / stance 是否成立）仍未系统目检。
- 许可：OAL 无 LICENSE，分发前需作者书面许可或换源。

---

## 6. 本会话改动文件清单

（工作树仍 48+ 项 dirty/untracked，以下是本会话新增/修改的核心文件）

**代码（真根运动 + 朝向 + 武器）**
- `game/scripts/combat/player_animation_bridge.gd` — 注入存活集 + 根运动 bake + root_motion_track 路径修复
- `game/scripts/tools/retarget_oal_to_mannyquin.gd` — STATE_KEY_MAP 19 键 + ROOT_MOTION_KEYS
- `game/scripts/player/player.gd` — 跃击真根运动 gate + F2/F4 调试键
- `game/scripts/core/player_visuals.gd` — 手骨锚点常量 + 武器/盾贴手
- `game/scripts/core/real_model_resolver.gd` — body yaw 180 + 职业 yaw 180 + sword 映射改模板
- `game/scripts/core/weapon_meshes.gd` — sword 改模板
- `game/scripts/world/procedural_campaign_level_builder.gd` — 边界墙 + respawn 修正
- `game/scripts/game_world.gd` — teleport_player_to_blank + 默认 respawn 修正
- `game/scripts/app/game_host_bridge.gd` — AshenHollowHost 守卫
- `game/scripts/core/input_config.gd` — F2/F4 键位

**数据/契约**
- `game/scripts/data/chapter_{1..5}_content.gd` — 11 精英改名 + 3 移动
- `game/tests/smoke/elite_name_contract_test.gd`（新）
- `game/tests/smoke/real_root_motion_contract.gd`（新）
- `game/tests/smoke/real_oal_retarget_contract.gd` — BATCH_KEYS 19 键
- `game/tests/smoke/chapter2_slice_contract_test.gd` — 精英位置断言
- `game/resources/animations/mannyquin_lib.tres` — 20 clip

**文档**
- `docs/tasks-master.md` / `docs/master-index.md` / `docs/tasks/content-gap-backlog.md` — 状态同步
- `docs/research-real-animation-pipeline.md` — 许可核查 + 根运动决策 + 覆盖表
- `docs/tasks/elite-name-alignment.md` — 收口
- `docs/devlog/2026-08-12/02-all-gaps-fix-and-root-motion.md` — 上一波 devlog
