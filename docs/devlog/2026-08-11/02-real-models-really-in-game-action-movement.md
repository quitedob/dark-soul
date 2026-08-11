# 真模型"真正入游戏"：玩家职业身体 + 主题武器 + 世界活物（动效层全覆盖）

> 2026-08-11 · 承接 `01-85-glb-into-game-real-model-milestone.md`：85 个 GLB 已入游戏，但 §4「已知缺口」里四个缺口这次全部关闭——**玩家**职业身体按 class 线程化 + 12 把武器真模型入槽，**世界**里召唤物/NPC 补上动效层，并同步更新过期文档行。

## 1. 目标

- 玩家侧：`player/body/class_*` 职业身体真正进入 `build_player`（不再是"已注册但没接"），切换职业时身体重建；玩家身体获得逐帧 ModelFx 运动（bob + ambient 光尘 + aura）——来自 `player/body/class_*` 档案。
- 武器侧：`weapon/01-WindHunter-Bow` … `weapon/12-Weapon-Types` 12 把武器 GLB 注册进 resolver，并按玩家武器 shape 做主题映射，替换原先的程序化占位。
- 世界侧：召唤物与 NPC 补上动效层（ModelFx movement + ambient + aura），与敌人/首领同级"活"。
- 文档：`docs/model-prompts/README.md` 的过期状态行（"游戏内全部为程序化占位"）同步更正。

## 2. 做了什么

### 2.1 G1 — 玩家职业身体线程化 + 切换重建 + 逐帧动效
- `character_meshes.gd` / `player_visuals.gd` / `player.gd`：`build_player` 现在接收 `class_id`，经由 `RealModelResolver` 解析 `player/body/class_<id>` 实例化真身体；`class_id` 为空时回落基础 `player/body`。
- `player_visuals.gd:rebuild_body(class_id)`：切换职业时重建身体节点（旧节点替换为对应职业 GLB）。
- 玩家身体逐帧驱动 `update_real_body_motion(delta, class_id)`，resolver_id 取 `"player/body/class_%s" % class_id`（空则 `player/body`），施加该职业档案的 bob + ambient 光尘 + aura。

### 2.2 G2 — 12 武器 GLB 注册 + 形状→主题映射
- `real_model_resolver.gd` REGISTRY 新增 `weapon/01-WindHunter-Bow` … `weapon/12-Weapon-Types` 共 12 条，统一 `scale: 0.6`；握持点（grip）已在导出时对齐原点，**无需 yaw / 位置补偿**。
- `weapon_meshes.gd:_THEMED_SHAPE_WEAPON` 做 shape→主题映射（先于模板回落、后于程序化兜底）：
  - `sword` → `weapon/08-XuanXiao-Falling-Star`（玄霄坠星剑）
  - `bow` → `weapon/01-WindHunter-Bow`（追风弓），主弓失败回落 `weapon/05-Sun-Falling-Bow`（落日弓）
  - `axe_right` / `axe_left` → `player/weapon/axe_right` / `player/weapon/axe_left`（刑天双斧按手拆 sub_node）
  - `staff_seal` → `weapon/03-Mystic-Gate-Seal`（玄门印）
  - `prayer_beads` → `weapon/04-Sandalwood-Beads-Talisman`（檀珠符）
  - **盾保持不变**（模板 `player/shield`）；`dagger` / `spirit_stone` / `talisman_papers` / 各章专属形状继续走程序化。

### 2.3 G3 — 召唤物 + NPC 补上动效层
- `spirit_summon.gd:_drive_model_motion`：召唤物逐帧按 `summon/<kind>` 档案施动（float/bob + motes + aura）。
- `shrine_npc_interact.gd:_process` 驱动：NPC 逐帧按 `npc/<id>` 档案施动（sway/bob + dust/embers）。
- 敌人/首领此前已接入（devlog 01 §2.5）——至此**可复用的 ModelFx 模式已覆盖玩家 / 敌人 / 首领 / 召唤物 / NPC 五类**。

### 2.4 G4 — 过期文档行更正
- `docs/model-prompts/README.md`「当前状态」行由"游戏内全部为程序化占位几何体"更正为：玩家职业身体/武器、敌人/首领/召唤物/NPC 已接入 `real_model_resolver.gd` 真 GLB；未注册 key 仍回落程序化几何体。

### 2.5 可复用动效层现状
- `ModelFx`（`scripts/fx/model_fx.gd`）+ `ModelMotionProfiles` 聚合器 + 8 个批次档案文件，同一套 `movement + vfx` schema 驱动五类实体；无档回落为空操作，永远安全。

## 3. 验证

| 项 | 结果 |
|---|---|
| 编辑器导入 + 全脚本解析 | 全脚本解析 EXIT 0 |
| 真模型契约 `tests/smoke/real_model_contract_test.gd` | `REAL_MODEL_CONTRACTS_OK` |
| 运行冒烟 | `ASHEN_HOLLOW_SMOKE_OK` |
| GUT | 95/96（1 个既有 `test_stamina_economy` 陈旧断言，未改动） |
| 临时自检脚本 ×3 | `player_class_selfcheck_pw` / `weapon_selfcheck_qd` / `npc_summon_motion_selfcheck_qd` 全过 |

## 4. 已知缺口 / 后续

- **混合职业覆盖仅运行时生效**：`get_active_class_id()` 的混合职业覆盖未持久化到存档——若在 Asura 状态下存档，读档会回到基础野蛮人身体。
- **每帧构造字符串**：`get_active_class_id()` / `update_real_body_motion` 每帧拼 `"player/body/class_%s"` String（与敌人侧既有模式一致，非新债，但可缓存优化）。
- **props/ GLB 仍未激活**：`prop/01-EmberShrine` … `prop/08-BridgeTea` 的动效档案已就绪（dormant），但 resolver **尚无 registry key、也无运行时驱动**——仍是"档案在、模型休眠"。
- **武器 scale 0.6 未经游戏内目检**：缩放值拍板时没有做游戏内视觉校准，后续需要视觉 pass 调优。
- **`weapon/12-Weapon-Types` 陈列架已注册但未映射**：只是展示架 GLB，暂无形状引用它。
- **尚无游戏内截图/视觉验证**：本批改动全部通过解析 + 契约 + 冒烟 + 自检覆盖，缺一次真机/编辑器内的目检截图。

## 5. 关联

- 前序：`docs/devlog/2026-08-11/01-85-glb-into-game-real-model-milestone.md`（85 GLB 入游戏 + 动效层 §4 缺口）
- 上游资产清单：`docs/model-prompts/README.md`（md→image→3D 流水线）
- 关键实现：`game/scripts/core/real_model_resolver.gd` · `game/scripts/core/character_meshes.gd` · `game/scripts/core/player_visuals.gd` · `game/scripts/core/weapon_meshes.gd` · `game/scripts/player/player.gd` · `game/scripts/combat/spirit_summon.gd` · `game/scripts/world/shrine_npc_interact.gd`
