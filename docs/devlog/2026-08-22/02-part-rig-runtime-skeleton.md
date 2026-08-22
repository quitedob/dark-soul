# 运行时部件骨架(PartRig)—— 无骨骼 GLB 的骨挂件方案 —— 已验证

日期:2026-08-22
主题:给"没有骨骼数据的静态 GLB"加运行时骨挂件(Skeleton3D),使模型能用骨骼动起来;并用 VLM 检查"骨骼网贴合模型本身"。

> 状态:机制已验证(引擎层 smoke 契约 `ASHEN_PART_RIG_OK` + `ASHEN_PART_RIG_MOVE_OK`);骨网贴合度经三视图截图 + VLM 目检通过。范围:仅限**含命名单件(body-part)网格**的人形模型。

## 动机与前提(实证)

- 全仓 `game/assets/models/` 共 88 个 GLB;**仅 2 个**(`mannyquin`、`minnyquinn`)有真正骨骼/蒙皮(各 58 骨)。其余 86 个为纯静态网格,无任何骨架数据。
- 本环境**无 Blender / bpy**,无法做标准蒙皮(DCC 加权)绑定;故采用 **Godot 运行时骨挂件**方案。
- 关键:很多 GLB 的静态几何是**按命名单件拆开的** `MeshInstance3D`(`BodyRoot` 下直接子节点,如 `thigh_l/shin_l/boot_l`、`upperarm_r/forearm_r/fist_r`、`pauldron_l`、`head_mask`、`torso`、`pelvis`、`belt`…)。Boss `01-Furnace-Keeper-JuQue` 就有 99 个命名部件 → 可按名映射到人形骨骼、用 `BoneAttachment3D` 骨挂件驱动。

## 实现:`core/part_rig_builder.gd`

- 部件名 → 骨骼映射:`bone_for_part()`(腿/臂/头/颈/骨盆/尾/翅关键词 + `_l/_r` 侧别),未匹配细节锚到 `spine`(居中,不掉飞)。
- 骨架:人形 `BONE_TREE`(`root>hips>spine>chest>neck>head`、`upper_arm/forearm/hand.{L,R}`、`thigh/shin/foot.{L,R}`、`tail`、`wing.{L,R}`)。
- **关节 = 部件包围盒上距父关节最近的点(近端)**,使 pivot 落在髋/膝/肩/肘而非部件质心 → 骨骼"贴合模型"便于动画。
- `set_bone_rest` 在 Godot 是**相对父骨**,故按父-先序累积 `global_rest` 再转父相对;部件 `p.local = bone_global_rest^-1 * bind_local`,保证绑定姿态=原模型(不动)。
- 每个有部件的骨建一个 `BoneAttachment3D`(`bone_name=骨骼名`),部件挂其下 → 转骨即转部件。

## 验证(`tests/smoke/part_rig_contract_test.gd`)

- `ASHEN_PART_RIG_OK`:在 Boss GLB 上 build 出 Skeleton3D(>0 骨、有 BoneAttachment)、绑定姿态保持(`thigh_l` 世界网格中心位移 <0.02m)。
- `ASHEN_PART_RIG_MOVE_OK move_dist≈0.18`:转 `thigh.L` 骨 → `thigh_l` 部件世界网格中心移动 0.18m,**证明"模型能用骨骼动"**。
- 运行:`godot --headless --path game --script res://tests/smoke/part_rig_contract_test.gd`。

## 骨网贴合目检(three.js 叠加层)

`build/all-models/viewer.mjs` 实现了与 Godot 端**同套**部件→骨映射,按"部件包围盒近端关节"画骨网(`window.showBones()`/`shootBones(i)`,绿线+黄珠),再用 chrome-devtools 截图 + **VLM 目检**。抽查 Boss `01/02`、职业 `17/22` 等:**骨链沿头→脊→髋→双腿走,关节在髋/膝** —— 骨网贴合模型。

## 范围 / 剩余

- **可绑骨的人形部件模型约 12 个**(8 职业 + 部分 Boss 等);其余(剑/灯/炉/装备/融合网格敌人)无天然骨骼结构,骨挂件意义有限,保持静态。
- 当前 rig 是独立构建器 + 契约,尚未接入玩家/敌人的运行时姿态流程(接入需如 `player_visuals` / `enemy` 在某状态调 `PartRigBuilder.build(body_root)` 并驱动骨 pose)。
- 未处理:把骨网叠加/Skeleton3D 可视化接入 Godot 渲染截图(无 Blender 且 Godot headless 不渲图;现用 three.js 同套映射以作目检)。

## 可复用

- 构建器:`game/scripts/core/part_rig_builder.gd`(静态 `build(body_root)->Skeleton3D`)。
- 契约:`game/tests/smoke/part_rig_contract_test.gd`。
- 骨网目检叠加:`build/all-models/viewer.mjs` 的 `window.shootBones(i)`。
