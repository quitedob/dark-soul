# Blender MCP：86 个 GLB 的内嵌蒙皮骨架重建

> 历史记录：下文保留 2026-09-06 首轮状态。最新结果见 [86/86 完成记录](../2026-09-08/03-complete-skinned-library.md)：全部 GLB 已内嵌蒙皮并发布，19 项旧模型法线问题也已修复；严格校验与 Godot 导入均为 86/86 通过。

> 2026-09-09 [自动化复核](../2026-09-09/01-model-conversion-recheck.md)：当前发布文件再次通过 86/86 严格校验和 Godot 导入，文件与清单哈希一致，无剩余转换项。

日期：2026-09-06。状态：**6/86 已完成基础蒙皮骨架并更新 out；1 个九尾模型待修正；79 个未转换。当前续作受 Blender MCP 权限阻断。** 逐项状态以下表为准。

## 范围与实际起点

用户要求：把 GLB 导入 Blender，通过 Blender MCP 建立真实骨骼网络，自己截图判断，更新 `build/glb-models/out`；每完成一个记录操作、结果和改进方法。

实际清点：`out` 有 85 个 GLB，全部 `skins=0`。第 86 个是 `game/assets/models/weapons/templateweapons.glb`，包含 Shield/Sword/Ax/Torch。mannyquin/minnyquinn 已有蒙皮，不属于这批重建。历史 PartRig 文档中的运行时骨挂件并不是文件内的顶点蒙皮；部分“无部件/不可绑定”判断也已被当前模型内容推翻。

本次只更新指定 `out`。游戏内 `game/assets/models` 不自动替换：当前 resolver 会提取武器子节点并释放原场景，后续同步时必须一并处理骨架依赖。

## 可复现操作

1. Blender MCP 确认 Blender 5.2.1 LTS；保留用户原 Scene，在独立场景导入原始 GLB。
2. 使用 `tools/rig_glb_models.py`，在 Blender 内创建 Armature/Edit Bones，根据部件几何与祖先命名确定关节和父子关系。
3. 添加 Armature modifier 与 vertex groups。硬质部件使用刚性顶点权重；躯干、披肩、袍摆、尾链使用相邻骨混合权重，最多两个影响。
4. 检查绑定前后 evaluated mesh 世界顶点误差；旋转非根骨，确认顶点真正移动，再还原姿态。导出 `export_skins=True` 的 GLB 到 `rigging/staged`。
5. 开启骨骼透视、关闭关系辅助线，通过 MCP 截图检查静止与旋转姿态，修正实际看到的问题。
6. 用 `tools/preserve_glb_samplers.py` 恢复原纹理采样设置。发现 Blender 导出会把 minFilter 从 9728 改为 9984；该后处理只调整 GLB 的 sampler JSON，不修改网格、骨架或图片字节。
7. 独立 Node 校验器 `tools/validate_skinned_glbs.mjs` 校验 joints/weights/IBMs、骨架层级、每个网格的静止顶点云、三角形/UV/法线覆盖以及非根骨变形。增加逐材质贴图 SHA256、sampler 和默认 sheen 值比较，避免只比较图片数量漏掉采样回归。只有该模型通过并完成截图检查，才复制到 `out`。

原始备份：`build/glb-models/rigging/originals/`。待发布：`rigging/staged/`。逐模型机器报告：`rigging/reports/`。独立验证：`rigging/validation.json`。截图：`rigging/screenshots/`。可编辑 Blender 场景：`rigging/blend/`。这些构建产物位于仓库已忽略的 build 目录，不能只依赖 Git 备份。

## 逐模型完成记录

| 模型（相对 out） | 骨骼 / 混合网格 | 操作、截图判断及改进 | 验证与发布 |
|---|---:|---|---|
| characters/player-classes/01-Divine-Marksman.glb | 20 / 2 | 按 l_arm/r_arm 祖先确定两侧，直接使用肩、肘、手的原始枢轴。保留持弓和箭的手骨关系，腰刀/箭袋跟 hips。首轮发现 elbow 被 bow 子串误认，修正为词边界匹配；截图发现披肩横向骨链且误挂 head，改成胸背向下的两段布链。正面静止及斜侧前臂转 20°、布料转 7°截图已目检：四肢与布链贴体，武器跟手。后续可加手指控制与拉弓专用动画。证据 001-marksman-rest.png / 001-marksman-posed.png。 | 完成并更新 out。10,015 顶点；静止包围盒误差 1.39e-7，非根骨位移 0.100；三角形、UV、法线、材质属性不变。原模型 10,039 顶点导入后合并 24 个重复顶点，逐网格双向顶点云检验通过。 |
| bosses/01-Furnace-Keeper-JuQue.glb | 18 / 1 | 导入 99 部件；建立躯干、头与双臂双腿骨链，刀翼按武器装饰处理。MCP 正面与斜侧图中腿链位于甲内、手臂链连接持械部件。后续改进：大肩甲极限抬臂姿态与重武器 IK 需专门调试。 | 完成并更新 out。10,552 顶点；静止误差 9.54e-8；Godot 非根骨位移 0.312。 |
| bosses/02-Blood-General-XingTian.glb | 24 / 5 | 导入 97 部件；保留无头结构，胸眼/腹口跟胸骨，腰间骷髅跟 hips，双斧跟手，披风建立布链。MCP 图中无额外头骨，胸部和四肢分支分离。后续改进：斧链可增加摆动控制，披风应做大幅挥斧避穿检查。 | 完成并更新 out。8,592 顶点；静止误差 3.99e-7；Godot 披风骨位移 0.492。 |
| bosses/04-Fallen-Immortal-XuanXiao.glb | 20 / 4 | 导入 74 部件；建头、双臂、腿和袍摆骨链，法器/持剑部件接入持械控制。MCP 斜侧图检查腿链与袍摆，不把脚下光环并入腿。后续改进：长袍与腿部跨步时的交叠需动画姿态精修。 | 完成并更新 out。7,444 顶点；静止误差 4.80e-7；Godot 袍摆骨位移 0.186。 |
| bosses/05-Lord-of-the-Ember-Abyss-ZhuYin.glb | 22 / 4 | 导入 71 部件；躯干、头、双臂双腿及垂饰分别绑定，sash_tail 使用布链。MCP 正面/斜侧图未把垂带生成动物尾骨。后续改进：下方悬浮特效应在动画系统单独驱动，补衣带摆动限幅。 | 完成并更新 out。9,965 顶点；静止误差 4.08e-7；Godot 袍摆骨位移 0.211。 |
| bosses/06-Blind-Bell-Hearer.glb | 9 / 0 | 导入 100 部件；按钟体、钟舌与原部件组建立机械骨架，硬件使用单骨刚性权重。MCP 截图确认钟体与两侧机械组件结构，未生成人形腿。后续改进：钟舌加铰链限位与独立敲击动作。 | 完成并更新 out。15,684 顶点；静止误差 1.00e-7；Godot 钟体分支位移 0.596。 |

上述 5 个 Boss 的共同截图证据为 `rigging/screenshots/002-bosses-rest.png`；MCP 斜侧姿态截图已在对话中检查，但权限中断前未另存 PNG。截图是基础骨架合理性检查，尚非逐骨极限姿态和正式战斗动画美术验收。可编辑 `.blend` 位于 `rigging/blend/bosses/`。这次发布前的旧文件另存于 `rigging/pre-publish-20260906/`，原始无骨架文件仍在 originals。

## 已生成但未发布

| 模型 | 状态与下一步 |
|---|---|
| bosses/03-Jade-Faced-Fox-NineTails.glb | Blender 已生成 45 骨、36 个混合权重网格、14,908 顶点；包含前后四足与 9 条独立三段尾链。Node 静止误差 1.65e-6；Godot 尾骨旋转位移 0.386，结构与蒙皮数据通过。但当前尾链沿主轴直线布局，源码 `build/glb-models/scripts/boss-main/03-Jade-Faced-Fox-NineTails.mjs:113` 的 baseCurve/tipCurve 是弯曲中心线，结合斜侧截图需沿真实曲线重排关节并重新分配权重。留在 staged，不覆盖 out。 |

其余 79 个 GLB 尚未导入本轮工作场景/转换，不得把已有无骨架 out 文件统计为完成。

当前全量验证命令：

```powershell
node tools/validate_skinned_glbs.mjs --source build/glb-models/rigging/originals --output build/glb-models/rigging/staged --report build/glb-models/rigging/validation.json
```

首项完成时 checked=1 / passed=1 / failed=0 / missing=85；本次续作复核为 **checked=7 / passed=7 / failed=0 / missing=79**，整体退出 1 表示批次未完成。修复采样设置后只剩顶点去重和重复纹理对象数量变化，材质实际参数、贴图字节/映射/采样及三角形/UV/法线覆盖均保持。

Godot 4.7.1 直接导入验证（不复制到 game/assets，也不修改 import 元数据）：

```powershell
& 'E:/godot/Godot_v4.7.1-stable_win64_console.exe' --headless --log-file E:/godot/darksoul/build/glb-models/rigging/godot-import.log --path game --script E:/godot/darksoul/tools/verify_blender_glbs.gd -- E:/godot/darksoul/build/glb-models/rigging/staged
```

实际退出 0，标记 `ASHEN_BLENDER_GLB_IMPORT_OK`，count=7 / passed=7 / failed=0 / skeletons=7 / mesh_instances=627 / vertices=77160。

验证限制：`--headless` 使用 dummy 渲染服务，`bake_mesh_from_current_skeleton_pose()` 没有可用 SkinReference。脚本在此模式改为使用 **Godot 实际导入的 Skin 逆绑定矩阵和 Skeleton3D 骨姿态计算 CPU 蒙皮**，输出 `pose_method=cpu_imported_skin`；非 headless 模式保留引擎网格烘焙路径。GPU/渲染服务网格烘焙与游戏战斗运行时回归为 SKIPPED。受限环境还输出系统证书存储读取失败，但本测试不联网，离线模型验证正常完成。默认 user:// 日志目录写入失败曾导致引擎崩溃，改为显式工作区 `--log-file` 后可正常退出。

## 当前续作阻断与恢复顺序

1. 已收到自动任务 86 的续作事件，并重新读取本日志和磁盘结果。没有使用 reset。
2. 当前自动续作环境为 workspace-write、审批策略 never。调用 `mcp__blender__get_scene_info` 被工具权限层拒绝：`MCP tool call requires approval, but approval policy is never`。因此暂停 Blender 导入、建骨、姿态截图；没有绕过权限调用 Blender socket/CLI 执行同一操作。
3. 下一次先确认 Blender MCP 工具已获允许，读取当前场景，保持用户 Blender 打开。旧 Python 模块在 `sys.modules['glb_rig']`；如果重启，应重新载入 `tools/rig_glb_models.py`，调用 prepare()（不会覆盖 originals）。本次增加采样恢复逻辑后需要重载模块。
4. 首先修正九尾曲线骨链并截图；随后从 originals 中排除上述 6 个已发布文件，继续剩余模型。每次约 6 个，逐模型导出、验证、截图、记录后发布。
5. 全部转换后再运行 86 文件完整验证、更新 MANIFEST，并复核 out 中 skin 数量；不能仅根据 staged 文件存在判断发布完成。

## 后续操作改进

- 不能只凭骨骼数量或整模晃动判成功；必须有每个网格静止形状一致、实际蒙皮、非根骨运动和截图证据。
- 保留九尾编号、四足前后肢以及原始组层级；避免把刀翼、斧头、胸眼、书脊套成人体骨骼。
- 源文件、阶段导出和已发布文件分开保存；重新生成始终读 originals，避免在已蒙皮版本上叠骨架。
- 每个模型在发布后立即补记，失败模型留在 staged 修正；不要把程序自动通过写成已经逐关节人工精修。
- 用户明确禁止 reset 重置余额，遵守。自动任务 86 已送达续作消息；不能据此声称建立了额度归零监听，也不能保证权限受限的自动运行能操作 Blender。
