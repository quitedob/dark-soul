# 会话执行复盘：全缺口修复编排（14 子代理 · 3 Wave · 4 轮 fix-back · 全部行动 / 难点 / 决策 / 记忆）

> 2026-08-11 · 本条目是**过程复盘**（不是交付快照）。交付清单见上方验证小节与 `tasks-master.md`。
> 记录：我（Claude Code）在这一整轮"修复所有问题"会话里做了什么、遇到哪些难点、怎么排查解决的、留下哪些可复用经验与记忆。

---

## 1. 会话总览（做了什么）

1. **缺口扫描**：`用 subagent scan docs/ + game/ /godot` → 只读 recon 子代理返回权威缺口报告（P0 手感/内容真缺口、P1 资产、P2 动画/引擎、工程债、5 处文档-代码矛盾）。
2. **动画路线定案**：用户要求克隆 `Godot4-OpenAnimationLibraries` + `Godot-Mixamo-Animation-Retargeter` 到 `example/`；我跑了决定性检查 `grep -a '"animations"' *.glb` → **88 个 GLB 只有 2 个带动画 chunk**（mannyquin/minnyquinn 测试骨架），确认路线 B：真模型全是静态网格，动画必须外补 + 重定向。
3. **读 key 文件锁所有权**：boss_attack_executor / chapter_3/4/5_content / enemy.gd 信号 / game_world 生成点 / real_model_resolver / run_state / player_animation_bridge / limboai_plugin_path / boss_execution_catalog，为 14 个子任务排无冲突所有权矩阵。
4. **3 个 Wave 派发 14 个子代理**（全部 general-purpose + prompt 内约束包）：
   - Wave 1a（6 个，并行）：L-19 executor、L-24 数据、L-22 精英名、L-21 .tres、L-18 真模型、L-20 骨骼锚点。
   - Wave 1b（5 个，并行）：L-23 测试、BossFlow-Host、D-01 动画管线、H-04 模块、LimboAI。
   - Wave 2（3 个，并行，依赖 BossFlow 契约）：九尾凝视、玄霄逃出、烛阴零重力。
5. **父进程集成修复**：两处 `:=` 类型推断错误（`player_visuals.gd`、`game_world.gd`），headless 解析从红转绿。
6. **独立验证**：解析 0 错误；11 个新增/改动合约全绿；D01 抽库工具 `ASHEN_MANNYQUIN_ANIM_EXPORT_OK` + 生成 `mannyquin_lib.tres`；GUT 95/96（1 个基线既有陈旧断言）；主 smoke `ASHEN_HOLLOW_SMOKE_OK`。
7. **4 轮 fix-back**（用 SendMessage + agentId 续跑原 agent 上下文）：L-19 测试树时序、L-20 parse、D-01 Animation API、L-23 的 4 个测试连环修复。
8. **文档**：本复盘 + devlog 索引 + 记忆文件（Godot 4.7 坑 + 项目架构契约）。

---

## 2. 难点与排查（detail — 你要的重点）

### D1. 88 个 GLB "几乎全没动画"（路线判定）
- **症状**：用户给了路线 A/B 决策树，前提是"先确认 GLB 里有没有动画 chunk"。`grep -a '"animations"'` 结果：88 个里只有 **2 个**命中。
- **排查**：对命中者再 grep 内容确认是真 channel→sampler 动画（不是空数组）；对未命中者抽样确认连 `"animations":[]` 都没有。
- **解决**：结论明确 —— 86/88 是纯静态网格（只有 61 骨骨架 + 网格），必须走路线 B（Mixamo/OpenAnimationLibraries 动捕 + retargeter 重定向）；mannyquin/minnyquinn 是现成竖切候选。
- **经验**：决策树前置的"侦查性 grep"成本极低、价值极高——一次确认就避免整条错误管线。

### D2. `var x := <Variant 返回>` 类型推断失败（Godot 4.7 严格类型）
- **症状**：headless 解析报 `SCRIPT ERROR: Parse Error: Cannot infer the type of "state" variable because the value doesn't have a set type.`，且**连带** `player.gd` 编译失败（依赖 `player_visuals`）。
- **排查**：错误指向 `_current_run_state()` 无返回类型注解 → `:=` 无法推断；同类错误后来出现在 `game_world.gd`（`run_state.get_body_class_override()` 返回 Variant）和 L-20 测试里（`profile.weak_point_offset` 是 Variant 字段）。
- **解决**：`:=` 改 `=`（放弃推断）或加显式类型。共修 4 处（2 生产 + 2 测试）。
- **经验**：**Godot 4.7 对 `:=` 推断很严格**——右侧是未定型函数返回值/Variant 字段时必炸；新写 GDScript 要么给函数加返回类型注解，要么用 `=`。

### D3. `--script` 测试在 `_init()` 里跑 → 节点不在树内
- **症状**：L-19 合约 11 条断言全挂（`multi_hit should hit the main target 3 times, got 0`、`radial_aoe should hit 2 candidates in range, got 3`、`multi_projectile should spawn 4 projectiles, got 0`…）。
- **排查**：读错误发现"多层共源"——executor 防御性守卫 `is_inside_tree()` 在测试的 `_init()` 阶段返回 false（`root.add_child` 在 `_init` 里不入树），且 `global_position` 在树外读返回 ZERO，所有候选塌到原点、范围过滤全部放行。
- **解决**：把测试体从 `_init()` 挪进 `_run_all()`，用 `call_deferred("_run_all")` 推迟到首帧 idle（树已运行）再断言。L-20、L-23 后续沿用同一模式。
- **经验**：**SceneTree 合约测试的主干必须 `_initialize()` + `call_deferred`，不能 `_init()`**；否则被测节点不入树，防御逻辑与坐标全错。

### D4. 信号计数 "got 0" —— lambda 按值捕获
- **症状**：save 合约 `First interact must emit activated once, got 0`（`activated_count`/`rested_count` 局部 int 全没涨）。
- **排查**：不是 interact 没触发——是 Godot 4 lambda 对基本类型按值捕获，`count += 1` 改的是副本。
- **解决**：计数改 `Dictionary`（按引用共享），lambda 内 `counts["activated"] += 1`。项目里 `core_contract_test.gd` 已有同款先例。
- **经验**：**GDScript 回调/信号里要跨 lambda 累计状态，用 Dictionary 容器，别用裸 int/float**。

### D5. 测试找不到子节点 —— Godot 4.7 给代码新建节点加 `@Name@N` 后缀
- **症状**：projectile 合约 `_ready must build a collision shape` / `visual mesh` / `light` / `trail`，但生产 `_ready` 明明 build 了。
- **排查**：写临时探针脚本实测 —— `_ready` 构建了 5 个子节点，但名字是 `@CollisionShape3D@3`、`@MeshInstance3D@4`…（Godot 4.7 对 `XXX.new()` 节点自动加唯一后缀），测试用固定名 `get_node_or_null("CollisionShape3D")` 查不到。
- **解决**：测试改**按类型查找** `find_children("*", "CollisionShape3D", true, false)`（`owned=false` 才匹配代码创建的运行时子节点）。
- **经验**：**4.x 代码创建的节点名带 `@…@N` 后缀，断言子节点别用固定名，按 `is Class`/`find_children` 类型查**。

### D6. projectile `_ready` 空 config —— `_spell_type` 只在 `setup()` 里写
- **症状**：projectile 合约 `_ready must build a collision shape` 持续失败，即便已入树触发 `_ready`。
- **排查**：读 `spell_projectile.gd` —— `_spell_type` 默认 `"default"`、只在 `setup()` 里写；`_ready` 读它取 config 构建子树。测试没先 `setup` 就 `add_child`，`_get_spell_config("default")` 走兜底分支返回缺 trail 的 config。
- **解决**：测试在 `add_child` 前先 `setup(source, …, {"spell_type": "veil_bolt", …})`，并加前置断言 `_spell_type == "veil_bolt"`。
- **经验**：**被测对象的 `_ready` 往往依赖 `setup()` 先填状态**；测试要先构造前置条件再入树。

### D7. `track_get_update_mode` 在 Godot 4.7 已不存在
- **症状**：D-01 合约 `SCRIPT ERROR: Invalid call. Nonexistent function 'track_get_update_mode' in base 'Animation'` + `get_track_count on a null value`。
- **排查**：报错顺序证明插值 API 存在、update-mode API 没了（4.0–4.3 曾有，4.7 移除）；且 `_remap_real_clip` 报错中止 → 返回 null → 下游 `get_track_count` 连环崩。
- **解决**：删掉 `track_set/get_update_mode` 一行；`_ingest_real_library` 加 `remapped == null or remapped.get_track_count() < 1` 防御。
- **经验**：**Godot 4.x 小版本会删 API**；新代码撞 `Nonexistent function` 先查该 API 在目标版本是否存活，别假设一直存在。

### D8. GUT 那 1 个失败是"基线既有"，不是回归
- **症状**：GUT 96 测 95 过 1 挂（`test_target_style_costs_and_insufficient_block`），数值差一大截（57.44 vs 35.0）。
- **排查**：先怀疑我方改动（L-21 的 .tres 会不会改了敌人攻击数值影响玩家格挡体力？）→ `git diff --name-only HEAD -- tests/unit/` 为空 → 再查 devlog：`01/02-...` 明写 **"GUT 95/96（1 个既有 test_stamina_economy 陈旧断言，未改动）"**。
- **解决**：判定为 pre-existing 债，**只报不改**（技能硬规则），在交付里标注。
- **经验**：**看到失败先做基线归因**：`git diff` 是否触及 + devlog/validation 是否已记录，别急着当回归修。

### D9. 三个 Boss 流程都想动 enemy.gd / game_world.gd —— 共享文件冲突
- **症状**：P0-2 的三场专属流程（凝视/逃出/零重力）如果各自改 `enemy.gd` 相变或 `game_world.gd` 生成点会互相踩。
- **排查**：读 enemy.gd 发现已有 `phase_changed`/`story_threshold_reached` 信号（game_world 也已连接）→ **不需要改 enemy.gd**。
- **解决**：设计**通用 flow 主机** `boss_flow_controller.gd`（content `flow.script` + `flow.config`，宿主挂载、接信号、注入 `flow_boss`/`flow_config`），wave 1b 一个子代理拥有 game_world.gd 加挂载点；wave 2 三个子代理各写**一个自己的 flow 脚本 + 自己的 chapter dict**。信号参数不匹配（`phase_changed` 发 2 参、flow `_on_phase` 只收 1 参）用转发层映射解决。
- **经验**：**共享文件冲突的正解是"抽通用宿主 + 每场景独立新脚本 + 内容字段驱动"**，而不是硬切行号。一个 wave 只放一个 game_world.gd 拥有者，后 wave 序列化追加。

### D10. 烛阴要 player.gd + game_world.gd，D-01 也要 player —— 二次冲突
- **症状**：烛阴（重力覆盖 + body_class 接线）与 D-01（动画）都想碰 player 侧。
- **排查**：梳理实际触碰面 —— D-01 只改 `player_animation_bridge.gd`（独立文件），不需要 player.gd；烛阴才需要 `player.gd`（重力 API）+ `game_world.gd`（装载接线）。
- **解决**：player.gd 唯一拥有者 = 烛阴；D-01 只读 player.gd；L-18 的 run_state 覆盖由烛阴在 `_apply_run_state` 接线（L-18 暴露静态读取入口）。三者在同一文件上不重叠。
- **经验**：**所有权按"实际编辑的文件"切分，不按"语义相关"**；让子代理声明"只改 X，读 Y"，父进程检查 diff 是否越界。

### D11. Boss 模型没有 Skeleton3D —— 弱点锚点怎么"真"？
- **症状**：L-20 要求真骨骼锚点，但 `.godot/imported/*.scn` 是二进制不可读；任务前提"61 骨"可能不成立。
- **排查**：用 Python 解 GLB JSON chunk —— **6 个 boss GLB 全是 `skins: 0`，没有真 Skeleton3D**，只有语义化命名节点层级（`furnace_core`/`chest_eye`/`tail_root_1`/`fused_core`/`star_core`/`bell_mouth`，恰好与 profile 锚名对应；玄霄节点名 `fused_core` vs 锚名 `fusion_core` 差个 s）。
- **解决**：`get_execution_anchor` 三级解析 —— Skeleton3D 骨锚（有骨架时）→ **GLB 语义节点 world 坐标**（本项目实际走这条）→ 原虚拟 offset 回退；camera 硬编码移除改读 profile。
- **经验**：**"真锚点"不等于"必须 Skeleton3D"**；静态命名节点 + 运行时 world 坐标同样有效。资产结构要先核实再设计方案。

### D12. props/ 8 GLB 注册了却没人放 —— 消费者在别处
- **症状**：L-18 注册 `prop/<slug>` 8 条，但没有运行时调用方（仍是休眠）。
- **排查**：放置点是关卡生成，属 H-04 的 `procedural_level_modules.gd`，与 L-18（resolver/run_state/weapon_meshes）文件不同。
- **解决**：跨 wave 解耦 —— L-18 只负责 REGISTRY 注册（`has_model` 可验证），H-04 负责在模块族里 `RealModelResolver.try_instance("prop/<slug>")` 放置。交付文档标注"注册就绪，放置归 H-04"。
- **经验**：**跨任务的"注册 vs 消费"天然要拆两个拥有者**；在交付里显式写清依赖，避免一个子代理越权改别人的文件。

---

## 3. 关键决策与理由

| 决策 | 理由 |
|---|---|
| 每个大类**一个专属子代理**，不批处理 | 用户明确要求；文件所有权按"实际编辑路径"切分，wave 内并行、共享文件序列化 |
| Boss 专属流程 = **通用 flow 主机 + 每 boss 独立脚本** | enemy.gd/game_world.gd 是热点文件，抽主机避免三份并行改动互踩；内容 dict `flow` 字段驱动，行为全可选、零回归 |
| 动画走**真库优先 + 程序化回退** | 86/88 GLB 无动画，不能等真资产；管线先通（D-01），生产 clip 到位即换 |
| L-19 未实现 type **push_warning 不再静默** | 静默 pass 等于隐形无效果 bug；显式告警让未来漏网 type 立刻被发现 |
| LimboAI 只装插件、**不动项目.godot、不切后端** | 官方 gdextension 无 plugin.cfg（`.gdextension` 自动加载），写 `[editor_plugins]` 反而报错；compat_macro 仍默认，避免 AI 系统被拖垮 |
| GUT 1 个失败**只报不改** | devlog 已确认为基线既有陈旧断言（`test_stamina_economy`）；技能硬规则"pre-existing 不静默修" |
| 测试树时序统一 **`_initialize()` + `call_deferred`** | 这是 `--script` SceneTree 合约测试唯一可靠模式（L-19 先趟通，L-20/L-23 复用） |
| 解析红线由**父进程独立重跑**，不信子代理自报 | 14 个子代理每个都自检过，我仍重跑 parse + 全部合约 + GUT + 主 smoke，全部独立复绿 |

---

## 4. 经验 / 记忆（可复用）

**Godot 4.7 语法/运行时坑（本项目多次踩，建议写进记忆）：**
- `var x := <无类型函数返回 / Variant 字段>` 必报 "Cannot infer the type" —— 用 `=` 或给函数加返回类型（D2）。
- SceneTree 合约测试：**`_initialize()` + `call_deferred("_run_all")`，别用 `_init()`**（D3）。
- 回调/lambda 累计状态用 Dictionary，不用裸 int（D4）。
- 代码创建的节点名带 `@Name@N` 后缀，断言用 `is`/`find_children` 类型查（D5）。
- 被测对象常需 `setup()` 先填状态再 `_ready`（D6）。
- 撞 `Nonexistent function` 先查该 API 是否被 4.7 移除（D7）。
- 失败先做**基线归因**：`git diff --name-only HEAD -- <test dir>` + devlog/validation 是否已记录（D8）。

**编排纪律（复用到下次）：**
- 派发前读热点文件锁所有权矩阵；共享文件只放一个拥有者，后 wave 序列化追加（D9/D10）。
- "注册 vs 消费"拆两个子代理，交付里写清依赖（D12）。
- 每子代理 prompt：`read first`（skill 引用 + 项目文件）→ `ownership（只能改这些）` → `do not touch` → `contracts` → `checks（别运行 godot，父进程统一跑）` → `report（打开文件/改动/自检/风险）`。
- 失败回修用 **SendMessage + agentId 续跑原 agent**（保持其上下文），比重新派发省一半；父进程先读代码给精确根因，再让 agent 动手（D5/D6/D7 都是我先实测定位）。
- 新脚本用显式 `preload` 优先；新 `class_name` 要一次编辑器导入才进全局类表。

---

## 5. 验证与交付状态

**验证（全部父进程独立重跑）：**
- headless 解析（wave1 / wave2 / 最终）：0 错误
- 11 个新增/改动合约全绿：`boss_attack_types` · `boss_execution_anchor` · `player_animation_real` · `g01_macro_bt` · 6×integration（audio/camera/save/input/spell/projectile）· `verify_combat_resource_schema_cli`（16 个新 .tres schema 全过）
- D-01 抽库工具：`ASHEN_MANNYQUIN_ANIM_EXPORT_OK` + 生成 `resources/animations/mannyquin_lib.tres`
- GUT：96 测 95 过 1 挂（**1 挂为基线既有** `test_stamina_economy` 陈旧断言）
- 主游戏 smoke：`ASHEN_HOLLOW_SMOKE_OK`

**交付足迹**：22 改 + 24 新（`git status`，不含 `mcp` 子模块）。
- 改：boss_attack_executor / enemy / game_world / player / real_model_resolver / run_state / weapon_meshes / player_visuals / player_animation_bridge / enemy_attack_catalog / 6×chapter_content / campaign_content / chapter_1_content / limboai_plugin_path / procedural_level_modules / campaign_module_runtime / 2×combat_data / 2×boss_data / g01 测试
- 新：3×boss attack helper（projectile/hazard/clone）· boss_flow_controller + flow/（3 个）· export_mannyquin_animations 工具 · mannyquin_lib.tres · 16×AttackData .tres · LimboAI addon · 6×integration 合约 · 3×smoke 合约 · docs/tasks/elite-name-alignment.md · example/ 两个仓库

**记录在案的风险/待续（未收口）**：真 locomotion 动画资产（路线 B 待 Mixamo/OpenAnimationLibraries 重定向）、玄霄逃出不触发 arena 解封（`ch4_xuanxiao_escaped` 留给内容接）、LimboAI BTPlayer 真替换未做、NG+ 凝视打断 / 结局尾声 / 精英名册错位 11 项 / 武器 scale 0.6 目检 / P3 浮空手测。

---

## 6. 关联

- 任务：[tasks-master.md](../../tasks-master.md)（L-18…L-24、D-01…D-05 状态）
- 缺口权威：[planning/soulslike-gap-analysis.md](../../planning/soulslike-gap-analysis.md)
- 精英对齐：[tasks/elite-name-alignment.md](../../tasks/elite-name-alignment.md)
- 同会话交付快照：[01-85-glb-into-game-real-model-milestone.md](01-85-glb-into-game-real-model-milestone.md) / [02-real-models-really-in-game-action-movement.md](02-real-models-really-in-game-action-movement.md)
