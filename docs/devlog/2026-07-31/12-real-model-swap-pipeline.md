# 真模型替换管线 M1：Mock → Real（RealModelResolver + GLB 导入 + 工厂回落）

**日期:** 2026-07-31
**范围:** L-18「真模型资产生产」的首个里程碑——把 100% 程序化占位几何体升级为**可回落的真实 GLB 模型管线**：解析器 + 注册表 + 导入 CC0 资产 + 全部工厂入口接线。**并记录本次 Subagent 编排方式与验证结论。**

---

## 结论

游戏此前 100% 为程序化占位几何体（`character_meshes.gd` / `weapon_meshes.gd` / `enemy_factory.gd` + 5 个章节工厂），`game/assets/models/` 不存在。本次落地 **RealModelResolver**：注册表驱动的 GLB 解析器，命中即实例化真实模型、未命中静默回落程序化——战斗接线零改动、任何丢失资产都不会破坏游戏。同时从 `example/` 复制 3 个 **CC0** GLB（mannyquin / minnyquinn / templateweapons）实际替换了玩家身体、玩家武器、玩家盾牌与首批敌人/敌人武器，管线端到端跑通。

**核心方法论（沿用 devlog 10/11）：** 主线程写基础件 → 3 路 **general-purpose 并行**（文件所有权互斥）→ 主线程独立重跑验证。基础件自检时先抓出一个真实问题：GLB 子节点重挂后残留场景 owner 引用触发 Godot 一致性告警，修复后验证基线干净。

---

## Subagent 与工具怎么用的（本次）

| 阶段 | 方式 | 交付 | 验证 |
|---|---|---|---|
| 0. 摸底 | 主线程直读 devlog 10/11 + **3 路 Explore 并行**（game 现状 / docs 契约 / example 可复用资产） | 程序化工厂 API + 挂点契约 + 90 个 model-prompts P0 清单 + `example/` 内 ~90 个 GLB 盘点 | — |
| 1. 可行性 | 主线程检查环境（Blender / conda / TRELLIS / Hunyuan3D / GPU / Godot / MCP） | AI 生成管线**未安装**且 Windows/RTX-50 支持未验证 → 本里程碑走「建管线 + 导入既有 CC0 资产」 | — |
| 2. 基础件 | 主线程：复制 GLB + 写 `real_model_resolver.gd` + 跑 `--import` 生成 `.import` | REGISTRY + `try_instance(id, parent)` + 动画中和 + `sub_node` 提取 + 空网格 MeshInstance3D 容器 | 解析 EXIT 0 |
| 3. 并行实施 | **3 路 general-purpose**（每路只准改列出的文件，各自跑 `--check-only`） | A: player 工厂守卫 / B: enemy 工厂守卫 + palette 门 / C: 合约测试 | 各自 EXIT 0；C 自跑出 `REAL_MODEL_CONTRACTS_OK` |
| 4. 复核 | 主线程**独立重跑**解析 + 合约 + smoke + GUT | 全部绿（GUT 唯一失败为改动前已存在的 `test_stamina_economy` 过期断言） | 见下 |

**验证不信任代理自报**：C 自报全绿，但主线程复核时发现 resolver 的 `_attach_sub_node` 触发 3 条 `owner inconsistent` 告警 → 加 `target.owner = null` 修复，复跑后基线无告警。

---

## 变更明细

### 新文件
- `game/scripts/core/real_model_resolver.gd` — `class_name RealModelResolver`；`const REGISTRY`（`"category/key" → {path, sub_node, root_name, scale, scale_x, y_offset, yaw_deg, position}`）；`static try_instance(id, parent) -> bool`（PackedScene 缓存、失败 `push_warning` + 回落、嵌入动画中和、`sub_node` 重挂到握把原点、空网格 `MeshInstance3D` 容器名 `BodyRoot`/`ModelRoot`）。
- `game/tests/smoke/real_model_contract_test.gd` — SceneTree 合约：注册路径全部可 `load`、player body/weapon/shield 命中、enemy body/weapon 命中、**未注册键回落程序化**（无 ModelRoot 且子节点数 > 0）。

### 资产（CC0，来自 `example/Cats-Godot4-Modular-Souls-like-Template-main/assets/`）
- `mannyquin.glb` → `game/assets/models/player/`（玩家身体）
- `minnyquinn.glb` → `game/assets/models/enemy/`（敌人身体）
- `templateweapons.glb` → `game/assets/models/weapons/`（Sword/Ax/Shield 子节点）
- 三者均自包含（0 纹理、纯色 PBR）；已生成 `.import`。

### 接线（全部「先清子节点 → `if try_instance(...): return` → 程序化」）
- `character_meshes.gd`：`build_player` → `"player/body"`；`build_enemy` → `"enemy/body/%s"`
- `weapon_meshes.gd`：`build_into_parent` → `"player/weapon/%s"`；`build_shield` → `"player/shield"`；`build_enemy_weapon` → `"enemy/weapon/%s"`
- `enemy_factory.gd`：`_build_body_for_type` → `"enemy/body/%s"`；`_dispatch_weapon` → `"enemy/weapon/%s"`（两个钳制点覆盖全部章节工厂，章节文件零改动）
- `enemy.gd`：`_apply_palette_colors` 顶部加 `ModelRoot` 门——真实模型保留自带材质
- `tools/build.ps1`：追加 `real_model_contract_test.gd` 调用

### 注册表种子（近似 transform，视觉调参待后续）
`player/body`、`player/weapon/{sword,axe_right,axe_left}`、`player/shield`、`enemy/body/{armored_medium,hulking_molten}`、`enemy/weapon/rusted_blade`。

---

## 验证

- 解析：`--editor --quit` EXIT 0，无 `SCRIPT ERROR` / `Parse Error`。
- 新合约：`REAL_MODEL_CONTRACTS_OK`，EXIT 0。
- 运行时 smoke：`ASHEN_HOLLOW_SMOKE_OK`。
- 既有合约重跑：`chapter1/2_slice`、`content_registry`、`campaign_generation`、`combat` 全绿。
- GUT：389/393 —— 唯一失败 `test_stamina_economy`（期望 35/84 vs 实际 57.44/100）为**改动前已存在**的过期断言，与本次无关。

## 未做 / 遗留

- **视觉调参**：scale / yaw_deg / y_offset / position 为近似值，需在编辑器里跑起来后逐个校准（尤其武器握把朝向与敌人体型）。
- **武器特效对齐**：拖尾尖端（`weapon_pivot + (0,1.05,0)`）与命中框偏移为硬编码，真实武器长度/朝向可能不完全吻合；per-weapon `tip_offset` 留待后续。
- **AI 生成管线**：TRELLIS/Hunyuan3D/Blender 未安装（Windows/RTX-50 支持未验证），自定义中式暗黑奇幻 GLB 仍待后续生成后按同一注册表接入。
- `docs/model-prompts/README.md` 的「当前状态」行（"游戏内全部为程序化占位几何体"）需随本里程碑更新。
- `example/tsorcRevamp/`（266MB Terraria 模组，见 devlog 11）仍待清理确认。
