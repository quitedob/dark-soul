# Blender MCP：86 个 GLB 的内嵌蒙皮骨架重建

日期：2026-09-06。状态：进行中，按下表逐项记录；未列为完成的模型仍待处理。

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
6. 独立 Node 校验器 `tools/validate_skinned_glbs.mjs` 校验 joints/weights/IBMs、骨架层级、每个网格的静止顶点云、三角形/UV/法线覆盖以及非根骨变形。只有该模型通过并完成截图检查，才复制到 `out`。

原始备份：`build/glb-models/rigging/originals/`。待发布：`rigging/staged/`。逐模型机器报告：`rigging/reports/`。独立验证：`rigging/validation.json`。截图：`rigging/screenshots/`。可编辑 Blender 场景：`rigging/blend/`。这些构建产物位于仓库已忽略的 build 目录，不能只依赖 Git 备份。

## 逐模型完成记录

| 模型（相对 out） | 骨骼 / 混合网格 | 操作、截图判断及改进 | 验证与发布 |
|---|---:|---|---|
| characters/player-classes/01-Divine-Marksman.glb | 20 / 2 | 按 l_arm/r_arm 祖先确定两侧，直接使用肩、肘、手的原始枢轴。保留持弓和箭的手骨关系，腰刀/箭袋跟 hips。首轮发现 elbow 被 bow 子串误认，修正为词边界匹配；截图发现披肩横向骨链且误挂 head，改成胸背向下的两段布链。正面静止及斜侧前臂转 20°、布料转 7°截图已目检：四肢与布链贴体，武器跟手。后续可加手指控制与拉弓专用动画。证据 001-marksman-rest.png / 001-marksman-posed.png。 | 完成并更新 out。10,015 顶点；静止包围盒误差 1.39e-7，非根骨位移 0.100；三角形、UV、法线、材质属性不变。原模型 10,039 顶点导入后合并 24 个重复顶点，逐网格双向顶点云检验通过。 |

当前全量验证命令：

```powershell
node tools/validate_skinned_glbs.mjs --source build/glb-models/rigging/originals --output build/glb-models/rigging/staged --report build/glb-models/rigging/validation.json
```

首项完成时 checked=1 / passed=1 / failed=0 / missing=85，整体退出 1 表示批次未完成，不能宣称 86 个全部通过。尚未执行 Godot 最终导入验证或游戏全量回归。

## 后续操作改进

- 不能只凭骨骼数量或整模晃动判成功；必须有每个网格静止形状一致、实际蒙皮、非根骨运动和截图证据。
- 保留九尾编号、四足前后肢以及原始组层级；避免把刀翼、斧头、胸眼、书脊套成人体骨骼。
- 源文件、阶段导出和已发布文件分开保存；重新生成始终读 originals，避免在已蒙皮版本上叠骨架。
- 每个模型在发布后立即补记，失败模型留在 staged 修正；不要把程序自动通过写成已经逐关节人工精修。
- 用户明确禁止 reset 重置余额，遵守。当前工具未提供额度归零监听和自动唤醒调度，未创建或声称创建 5 小时自动续作闹钟。
