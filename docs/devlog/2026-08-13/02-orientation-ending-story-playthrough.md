# 会话执行复盘：朝向/武器 → 分结局尾声 → 5-3/5-4 剧情 → 脚本化通关

> 2026-08-13 · 记录一个从「修朝向/武器握持」一路推进到「整局可玩通验证」的完整会话。
> 重点：**每一处难点的根因、如何定位、如何修复，以及沉淀的持久记忆**。
> 目标读者：未来接手同类任务的我 / 协作子代理。

---

## 0. 会话全景（一句话）

用户目标是「修到能玩通整款游戏」。本会话从上一个会话遗留的**朝向/武器握持 bug** 出发，一路补到**分结局尾声**、**5-3 因果回放 / 5-4 证词汇合**，最后写了一个**脚本化通关合约**驱动真实游戏循环，抓出并修复了两个会卡关的既有 bug。

---

## 1. 朝向 + 武器握持修复

### 1.1 根因

身体是 `BodyRoot`（`real_model_resolver.gd` 里 `yaw_deg: 180`）的子节点，武器/盾是 `visual_root` 的**直接子节点**（yaw 0、写死位置）——**两套坐标系分离**。身体转 180°，武器不跟着转，所以「朝向反 + 武器方向反 + 武器不在手上」是同一个根因的三个表现。

### 1.2 修复（统一坐标系）

- 引入 `BodyYaw`（Node3D，`rotation.y = BODY_YAW = PI`）作为 `visual_root` 与「身体 + 武器 + 盾 + 拖尾」之间的**单一朝向父节点**；删掉 resolver 里所有逐模型 `yaw_deg: 180`。
- `visual_root` 退回纯逐状态姿态节点（dodge/leap/stagger/death 的 x/z、parry/cast 的 y 摆动）。
- 4 文件：`real_model_resolver.gd` / `player_visuals.gd` / `player.gd` / `player_animation_bridge.gd`（BodyRoot 改递归查找）。

### 1.3 难点 A（最痛）：手骨常量是「yaw-180 世界坐标」，不是 model-space

上一个会话的 `HAND_RIGHT_REST = (0.739, 1.441, 0.065)` / `HAND_LEFT_REST = (-0.739, 1.441, 0.065)` 是**yaw-180 时代测的世界坐标**。统一坐标系后（BodyRoot 变单位变换），武器 pivot 应挂的是**骨架 model-space rest 位置**，两者正好差 180°。

- **如何定位**：写一次性探针脚本读 `skel.get_bone_global_rest("DEF-hand.R").origin`，得到真实 model-space rest = `(-0.7389, 1.4408, -0.0654)`；左 = `(0.7389, 1.4408, -0.0654)`。
- **如何修复**：把常量改成 `HAND_RIGHT_REST = (-0.739, 1.441, -0.065)`、`HAND_LEFT_REST = (0.739, 1.441, -0.065)`；顺手把 `offhand_weapon_pivot`（左副手武器）也对齐到 `HAND_LEFT_REST`。
- **教训**：`get_bone_global_rest(idx)` 返回的是 **model-space（骨架局部系）rest**，不是 world；世界位置要 `skel.to_global(rest.origin)`。判断「常量对不对」必须读 model-space，别用世界坐标混进局部系。

### 1.4 验证

新合约 `tests/smoke/player_weapon_grip_contract.gd`（marker `ASHEN_PLAYER_WEAPON_GRIP_CONTRACTS_OK`）：武器 pivot 必须落在 `DEF-hand.R` 世界骨位（两处断言：①重合、②yaw 确实应用到公共父节点）。

---

## 2. 分结局尾声（补齐「结局/尾声」）

### 2.1 根因

烛阴 10% 处决 → `FateChoiceOverlay` 选结局 → `EndingResolver.commit` 写入 `ending_state` → Boss `defeated` → 通用胜利卡 → 走出口 → `hud.show_message("THE PATH ENDS HERE")`。**结局 id 写入后从未被运行时读回**，尾声是 100% 通用英文占位，四种结局无区分；7 个命运旗（`fate_*`）写后从不消费。

### 2.2 修复

- `dialogue_runner.gd` 新增 `ending_epilogue(ending_id, run_state) -> Dictionary`：4 结局标题/副标题/叙事段落 + 消费 7 命运旗 + 5 个 `npc_*_met` 见证行。
- `hud.gd` 新增 `show_epilogue(data)` + `_build_epilogue_overlay()` + `epilogue_finished` 信号（滚动叙事面板 + 「返回标题」按钮）。
- `game_world.gd`：走完 5-5 出口且无下一关时 `_show_ending_epilogue()` 读回 `EndingResolver.resolve` → 显示尾声；`_on_epilogue_finished()` → `reload_current_scene()` 回标题。
- `boss_execution_catalog.gd`：补嗔念/执念执行档案（`story_flag=""` + 致死处决），**修复 Ch.4 子 Boss 处决泄漏 `ch1_guardian_fate` 的 bug**（原回退巨阙档案会错误弹出 Ch.1 命运浮层）。

### 2.3 难点 B：`ui/victory_overlay.gd` 等是死代码

探查时发现 `ui/victory_overlay.gd` / `title_overlay.gd` / `death_overlay.gd` 是**从未实例化的死代码**；真正的标题/胜利/终幕 UI 都在 `hud.gd` 内建（`_make_end_overlay` / `_build_title_overlay`）。所以尾声也放 hud 内建，不新建 CanvasLayer 类。

---

## 3. 5-3 因果回放 + 5-4 证词汇合

### 3.1 根因

`chapter-bridge-map.md` §「仍待扩展」指出：`samsara_stance`（5-3 接受/悔）与 5-4 证词是**设计态元数据**，代码里没有对应玩法系统。

### 3.2 修复

- **5-3 轮回歧路**：`boss_fate_catalog.gd` 加 `samsara_stance_ch1..ch4` 四章回放条目（接受/悔）；新增 `samsara_fork_interact.gd`（Area3D）；`game_world.gd` 用 `_samsara_queue` **链式弹出 4 次 FateChoiceOverlay**，逐章写 `samsara_stance_ch1..ch4`。`_on_fate_choice_made` 顶部加 samsara 早退分支（写旗 + 推进队列，不落命运抉择闭环）。
- **5-4 九铸魂者之墓**：`dialogue_runner.gd` 加 `npc_soul_forgers` 证词（依命运旗追加）；`game_world.gd` `_spawn_soul_forger_communion()` 复用 `shrine_npc_interact` 交互节点。
- **尾声消费「悔」**：`ending_epilogue` 读 `samsara_stance_chX == "regret"` 追加悔行。

### 3.3 难点 C：`throne_choice` 元数据冗余

`chapter_5_content.gd` 的 `ending_triggers` 写着 `absorb_ember/sit_throne/...`，但这些字符串从未被消费（实际裁决经 FateChoiceOverlay 的 kindle/keeper/void/forge）。修复：把元数据对齐到真实结局 id，并注释说明（`EndingResolver.resolve` 兼容旧别名 `absorb→kindle` 等）。

---

## 4. 脚本化通关 + 抓出 2 个真实 bug

### 4.1 为什么需要它

数据级合约（`campaign_generation` 等）只验证「关卡能生成、档案存在」，不验证「实际玩起来 Boss 战、转场、结局能走通」。于是写 `tests/smoke/playthrough_progression_contract.gd`：**驱动真实 `game_world` 依序载 29 关、击败 8 Boss（命运抉择 / 致死击杀）、走出口转场、终局提交裁决并触发尾声**。

### 4.2 它抓出的 2 个既有 bug（`--editor --quit` 漏掉的）

| 文件 | bug | 为什么编辑器扫描漏掉 |
|---|---|---|
| `nine_tails_flow.gd` | `func _world()` 无返回注解 + `var world := _world()` → `Cannot infer the type` | 该脚本只在 `_attach_boss_flow` 运行时 `load()`，编辑器扫描不触发完整类型推断 |
| `zhu_yin_zero_g_flow.gd` | `flow_boss.get("engaged", false)` 双参调用（`Node.get()` 只收 1 参） | 同上 |

修复：`_world() -> Node`（显式返回类型 + `return world as Node`）；`flow_boss.get("engaged")`。

### 4.3 难点 D：脚本化通关自己的两个坑

1. **命运 Boss 击杀不生效**：`conclude_story_fate()` 有守卫 `if state == DEAD or not _story_resolution: return`。脚本里直接 `_on_fate_choice_made` 前必须先 `guardian.enter_story_resolution()`（真实流程里由 `_on_boss_story_threshold` 做）。
2. **存档污染**：脚本里 `_on_campaign_exit_requested` 会 `_save_run`，把上一轮测试的 `level_05_06` 写进存档，导致下次启动 load 到错误关卡。修复：测试开头/结尾 `DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ashen_hollow_run_v1.json"))` 双端清档。

---

## 5. 沉淀的记忆（persistent memory）

| 文件 | 内容 |
|---|---|
| `model-orientation-weapon-coordinate-split.md` | 更新为「已修复」；记录手骨 rest 是 model-space 非 world 的坑 |
| `ember-abyss-architecture-facts.md` | 追加「结局/尾声 + 5-3/5-4 剧情」架构事实 + `ui/*.gd` 死代码警示 |
| `godot47-gdscript-gotchas.md` | 追加 gotcha #8：`--editor --quit` 漏掉「运行时才 load() 的脚本」的类型推断错误，用脚本化通关兜底 |

---

## 6. 验证（全绿）

- 解析 `--headless --editor --quit` → EXIT 0
- smoke → `ASHEN_HOLLOW_SMOKE_OK`
- **13 个合约全 PASS**：`campaign_generation` / `chapter3_5_wiring` / `story_runtime` / `boss_execution_anchor` / `boss_polish` / `real_model` / `player_animation_real` / `weapon_trail` / `socket_follow_rotation` / `player_weapon_grip` / `ending_epilogue` / `samsara_communion` / `playthrough_progression`

---

## 7. 仍未做（已知债，记录不展开）

- **实机手感/观感 QA**：唯一需要人在屏幕前的步骤（朝向自然度、拖尾观感、Boss 节奏）。逻辑/加载/Boss 战/转场/结局数据流已被脚本化通关覆盖。
- **英文本地化**：全游戏对白硬编码中文（`LocalizationScript.ZH_CN` 只覆盖 HUD）；中文下完整可玩，加英文是独立内容大项。
- `throne_choice` 物理交互：冗余于 FateChoiceOverlay（结局已由命运浮层完成）。

---

## 8. 本会话改动文件清单

**朝向/武器**：`core/real_model_resolver.gd`、`core/player_visuals.gd`、`player/player.gd`、`combat/player_animation_bridge.gd`
**结局/尾声**：`story/dialogue_runner.gd`、`hud.gd`、`game_world.gd`、`combat/data/boss_execution_catalog.gd`、`data/chapter_5_content.gd`
**5-3/5-4**：`combat/data/boss_fate_catalog.gd`、`world/samsara_fork_interact.gd`（新）、`world/shrine_npc_interact.gd`（复用）
**bug 修复**：`boss/flow/nine_tails_flow.gd`、`boss/flow/zhu_yin_zero_g_flow.gd`
**测试（新）**：`player_weapon_grip_contract.gd`、`ending_epilogue_contract.gd`、`samsara_communion_contract.gd`、`playthrough_progression_contract.gd`
