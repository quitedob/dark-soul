# 85 个 three.js GLB 入游戏 + 真模型动效层

> 2026-08-11 · 里程碑：把 `build/glb-models/out/` 的 **85 个 three.js 生成的 GLB** 整体迁入 Godot 游戏，按内容实体逐 id 注册，并为全部 85 个模型用**子代理并行**编写专属运动 + 视觉特效档案。

## 1. 目标

用户目标：`we already have many glb in three.js, change them into the game`。
- 85 个 GLB 全部导入游戏（`game/assets/models/`）并按内容实体激活；
- 该激活的模型要有专属 movement + visual effect；
- 全部有 docs/story 逻辑；游戏能跑。

## 2. 做了什么

### 2.1 资产导入（85 个 GLB）
- 从 `build/glb-models/out/**` 镜像复制到 `game/assets/models/`（bosses/ · enemies/<chapter>/ · characters/{npcs,player-classes,summons}/ · weapons/ · equipment/ · props/），共 85 个新 GLB（+ 原 3 个 = 88 个）。
- `Godot --headless --editor --import` 生成全部 `.import` + `.scn`，EXIT 0。

### 2.2 RealModelResolver 注册（`scripts/core/real_model_resolver.gd`）
- REGISTRY 扩到 **60+ 条目**，覆盖：player 身体/武器/盾、8 职业身体、33 敌人 by_id、8 首领 by_id、32 body_type 回落、5 召唤、7 NPC。
- 新增 **`align_ground`**：按实例 AABB 把模型最低点抬到容器原点（作者以脚踩原点导出，部分埋在 y<0）。新增 `_scene_min_y` / `_collect_meshes` / `_xf_to` 辅助。

### 2.3 敌人工厂按 id 分派（`scripts/combat/enemy_factory.gd`）
- `_build_body_for_type(parent, body_type, mat, enemy_id)` 现在先试 **`enemy/body/by_id/<id>`** → 再试 `enemy/body/<body_type>` → 程序化回落；返回是否用了真模型。
- 真模型身体**自带武器**（剑/戟/锤烤在 GLB 里）→ 命中后**跳过独立武器槽**，避免双武器。

### 2.4 召唤物 + NPC 真模型
- `spirit_summon.gd:_build_visual`：先 `try_instance("summon/<kind>", _visual)`，未注册回落发光体。
- `game_world.gd` 两处 NPC 生成（神社 NPC + 桥头茶魂）：`try_instance("npc/<id>", npc)`，未注册回落胶囊占位。

### 2.5 专属动效档案（86 条，8 个子代理并行编写）
- `scripts/data/model_motion_profiles.gd`（聚合器）+ `scripts/data/motion/profiles_*.gd`（8 个批次文件，每文件一个子代理独占）。
- Schema：`{ "movement": {type, amplitude, speed}, "vfx": {windup_ember, ambient{type,color,count}, aura} }`。
- `scripts/fx/model_fx.gd`（ModelFx）驱动：`apply_movement`（bob/float/sway/rock）、`ensure_ambient`（embers/motes/dust 循环粒子）、`ensure_aura`（环境点光源）、`spawn_ember_burst`（蓄力余烬）。
- `enemy.gd` 接入：`_real_model_idle_vfx` 每帧按档案施动 + 环境粒子 + 光环；WINDUP 时按档案色喷余烬。

### 2.6 three.js 真实模型 + 骨骼网络查看器（`build/real-models/`）
- 加载 `game/assets/models` 的真实骨骼 GLB（mannyquin 61 关节 / minnyquinn 3 动画），AnimationMixer 播骨骼动画、SkeletonHelper 可视化骨骼网络、Sword 挂到 `DEF-hand.R` 骨、骨骼驱动滑杆。VLM 视觉验证通过。

## 3. 验证

| 项 | 结果 |
|---|---|
| 编辑器导入 88 GLB | EXIT 0（仅退出时的 ObjectDB/resource 正常告警） |
| 全脚本解析 | `ALL_SCRIPTS_PARSE_OK`（仅 5 个既有 UI `is_visible()` 警告） |
| 运行冒烟 | `ASHEN_HOLLOW_SMOKE_OK` |
| 真模型契约 | `REAL_MODEL_CONTRACTS_OK`（路径全可载 + 按 id/body_type 换真 + 真身体武器槽留空 + 未注册回落 + 40 个活动模型接地对齐） |
| GUT | 95/96（1 个既有 `test_stamina_economy` 陈旧断言，未改动） |

## 4. 已知缺口（后续）

- **8 职业身体**已注册 `player/body/class_*`，但 `build_player` 尚未按 class 线程化（需 player_visuals 传 class_id + 切换职业时重建身体）——档案已就绪。
- **12 武器 GLB** 尚未 sub_node 映射到玩家武器槽（需按 GLB 内部节点名对齐握持点）；档案已就绪（dormant）。
- 真模型被 `enemy.gd:_apply_palette_colors` 的 ModelRoot 门跳过状态换色——由新动效层补足"活"感。
- `docs/model-prompts/README.md` 的"游戏内全部为程序化占位"状态行已过期，待随文档同步更新。

## 5. 关联

- 前序：`docs/devlog/2026-07-31/12-real-model-swap-pipeline.md`（M1 mock→real）
- 资产源：`docs/model-prompts/`（md→image→3D 流水线上游）· `build/glb-models/`（three.js 导出）
- 查看器：`build/real-models/`（端口 8768）
