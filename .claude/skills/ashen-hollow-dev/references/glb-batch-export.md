# 多 agent 批量 GLB 导出（build/glb-models）

把 `docs/model-prompts/` 的**全部实体模型**程序化导出为 GLB 占位资产，供 `RealModelResolver`
回落/替换。全流程 = **主线程建脚手架 → 验证跑通 → 9 路并行子 agent → 主线程独立复核**。
`environment/*.md`（5 个）是场景级地标，**不导出**。

## 目录结构

```
build/glb-models/
├── _shared/helpers.mjs     # 共享脚手架：材质库 + 建模小件 + 导出封装（只读复用）
├── verify-glbs.mjs         # 主线程复核：遍历 out/ 校验 glTF2 + 生成 MANIFEST.json
├── MANIFEST.json           # 复核产物（自动重写）
├── scripts/<group>/        # 每个子 agent 的建模脚本（文件所有权互斥）
└── out/<category>/         # 输出 GLB（bosses/characters/enemies/equipment/props/weapons）
```

`build/` 在根 `.gitignore` 中被忽略——产物不污染 git。

## helpers 关键 API

- 材质 `M.*`：`ember/emberHi/cinder`(烬火)、`steel/darkIron/rusted/brass/bronze/gold/silver`(金属)、
  `jade/jadeDark/moonlight`(玉障)、`white/silk/rot`(天崩vs腐朽)、`starBlue/voidBlack`(烬座)、
  `leather/bone/wood/stone/paper/flesh/ghost/shadow`、`flat(color)`
- 建模小件：`box(w,h,d,mat,{name,x,y,z,ry,rx,rz})`、`cyl(rt,rb,h,seg,mat,{...})`、
  `sphere(r,mat,{name,x,y,z})`、`cone(rt,rb,h,seg,mat,{...})`、`capsule(rt,midH,mat,{...})`、
  `group(name)`、`add(root,child)`
- 导出：`exportRoot(root, new URL('../../out/<category>/<file>.glb', import.meta.url))`
  —— 脚本在 `scripts/<group>/`（两级深）所以用 `../../out/`
- **内置 Node FileReader shim**（`binary:true` 必需，否则 `ReferenceError: FileReader is not defined`）
- ⚠️ 语义坑：`cone(rt, rb, h)` **忽略 rb**（ConeGeometry 非截锥，尖端恒朝 +Y）；要截锥用 `cyl`。

## 切分方案（9 路，文件所有权互斥）

| 子 agent（group） | 模型 | 输出 out/ |
|---|---|---|
| boss-main | 6 主线 Boss | bosses/ |
| boss-sub-summons | 2 sub-boss + 5 召唤物 | bosses/sub-bosses/ + characters/summons/ |
| player-classes | 8 职业 | characters/player-classes/ |
| npcs | 7 NPC | characters/npcs/ |
| enemies-ch1ch2 | 4 + 6 敌人 | enemies/01-spirit-ruins/ + 02-blood-iron/ |
| enemies-ch3 | 10 敌人 | enemies/03-jade-veil/ |
| enemies-ch4ch5 | 7 + 5 敌人 | enemies/04-celestial-fall/ + 05-throne-of-ashes/ |
| weapons | 12 武器 | weapons/ |
| props-equipment | 8 道具 + 5 装备 | props/ + equipment/ |

## 子 agent prompt 模板（沿用 ashen-hollow-dev §4）

1. **背景**：项目根、脚手架路径、helpers API 清单、运行命令（`cd build/glb-models && node <script>.mjs`）、"严禁下载/克隆/联网安装"。
2. **文件清单**：逐个列出要读的 `docs/model-prompts/<分类>/<file>.md`（读「一句话概述/视觉描述/图片生成提示词/建模备注」四部分）。
3. **建模规范**：低模风格化占位，剪影+配色+标志特征；人形脚底 `y=0` 身高 1.6–1.8（Boss 2.0–2.6）；每模型部件 15–60；灵体用 `M.ghost` 半透明；命名 `<序号>-<English>.glb` 去中文。
4. **文件所有权**：只准在自己的 `scripts/<group>/` 新建、在指定 `out/<category>/` 输出；严禁改 `_shared/`、`verify-glbs.mjs`、其他 `scripts/*/`、`out/*/`、`build/glb-test/`、`game/`、`docs/`。
5. **验证**：每个脚本必须打印 `[OK] ...glb — N bytes`；全部完成后运行 `node verify-glbs.mjs` 确认自己的 GLB 全 ✅。
6. **诚实**：跑通的才算，失败列文件名+报错。

## 主线程独立复核（不信任自报）

```bash
cd build/glb-models && node verify-glbs.mjs
```

- 遍历 `out/` 所有 `.glb`：magic `glTF`、version 2、length 匹配、JSON+BIN chunk（**chunk 类型比较要 `.replace(/\0+$/,'')`**，`"BIN\0"` ≠ `"BIN"`）、有 meshes。
- 输出每文件字节/mesh/mat/命名节点数 + `MANIFEST.json` 汇总。
- 2026-08-03 基线：**85 个 GLB 全合格**（bosses 8 / characters 20 / enemies 32 / equipment 5 / props 8 / weapons 12）。

## 后续接入 Godot

1. GLB → `game/assets/models/<category>/` + Godot `--headless --editor --quit` 导入（生成 `.import`）。
2. 注册 `RealModelResolver.REGISTRY`（`"category/key" → {path, sub_node, root_name, scale, yaw_deg, position}`），一次一个实体，跑 `real_model_contract_test.gd` + smoke。
3. 视觉抽检：VLM 或浏览器查看器，见 [glb-viewer-and-vlm.md](glb-viewer-and-vlm.md)。
