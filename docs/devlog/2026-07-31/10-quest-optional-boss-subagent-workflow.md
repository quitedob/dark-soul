# 人间事件改编 + 可选 Boss + 模型提示词（Subagent 编排工作流）

**日期:** 2026-07-31
**范围:** docs/story 同步；胖猫事件 → 第三章支线「桥头的供茶」；全新可选 Boss「盲钟·听烬」；5 个 model-prompts；过时模块测试修复。**并记录本次 Subagent 与工具的调用方式（重点）。**

---

## 结论

一次「检索 → 改编 → 实现 → 验证」的完整闭环，全程以 **11 次 subagent 调度** 拆解并行。交付：1 支线（桥头的供茶，含贪烬鬼精英）、1 可选 Boss（盲钟·听烬，无命运旗、致死击杀）、5 个 model-prompts（NPC×2 / 敌人×1 / 道具×1 / Boss×1）、1 处过时测试修复。验证：新增合约与既有 smoke 全绿、运行时 smoke 绿、编辑器解析 EXIT 0。

**核心经验：先只读侦察、后并行实施、再独立验证——把"怎么想"交给侦察 agent，把"怎么写"交给实施 agent，把"怎么验"交给合约测试。** 实施 agent 在编码时发现的两个真实问题（重复刷怪、fate 软锁）都来自侦察报告提前标出的坑。

---

## Subagent 与工具怎么用的（本次重点）

### 1) 侦察阶段 —— 只读 Explore，先图后写

写任何代码/文档前，先派 **Explore（只读）subagent** 并行扫目标目录，要求返回 `path:line` 证据 + 可靠性标签（RELIABLE / STALE / CONTRADICTED）。本轮共 4 次侦察：

| 侦察 | 输入 | 产出（给实施 agent 的"地图"） |
|---|---|---|
| docs/ vs game/ | 对比设计文档与实现 | 找出「内容与运行时边界」过时、结局 ID 三套命名、save-persistence 缺新旗标 |
| 支线实现路径 | quest_state / dialogue_runner / game_world / boss_fate_catalog / chapter_3_content / tests | 每个组件该改哪个文件哪一行 + 可复制的最近模式 + 坑（`progression_values` 只收非负 int、`choice_flags` 只收 bool/非空 string、`level_03_04` 键名） |
| model-prompts 模板 | 00-template + 忆姬 / 烬龛 / 嫁衣女鬼 三份完整范例 | 5 键 frontmatter、6 节结构、共享英文 suffix 逐字抄写、文件名编号规则 |
| Boss 实现路径 | campaign_content / boss_execution_catalog / enemy_factory / content_validator / 传送机制 | 数据 schema、致命坑（空 `story_flag` 会触发 `enter_story_resolution` 软锁）、推荐方案（`level_05_06` 规范 ID + 传送入口） |

**要点：** 侦察 agent 只读不改；它的输出当"地图"而非"真理"——写代码的 agent 仍须先读原文件核对行号与 schema。

### 2) 检索阶段 —— perplexity-research，单线程不并发

按 skill 规则：先建任务清单（Phase 0 文档扫描 → Phase 1 主检索 → Phase 2 深潜 → Phase 3 核验 → Phase 4 归档）；**一次合并清单主检索 + 至多一次 follow_up（复用同一 `backend_uuid`）**，绝不并发调 MCP；`mode=pro, language=zh`；返回来源 URL 列表 + 逐项可信度。

本次实操：胖猫事件首次检索模型推脱未给事实 → 用 `follow_up` 逼其基于警方通报 / 维基「胖猫跳江事件」/ 央视 / 澎湃逐项作答；「51 万转账净额」官方口径无法核实 → 如实标记为缺口，不采信（改编也不需要具体金额）。报告落盘 `docs/research/soulslike/story-fat-cat-event.md`，含来源 10 条 + 伦理改编红线（去实名、不消费死者、随波分支明示代价）。

### 3) 实施阶段 —— general-purpose 并行，详细 prompt 传线

在侦察图上，把**互不冲突的文件集**并行交给 general-purpose agent：

- **支线**：1 个 agent 写全部 game 实现（串行推进共享文件，避免冲突）+ 2 个 agent 并行写 model-prompts（NPC×2+道具 / 敌人×1）；
- **Boss**：1 个 agent 写全部 game 实现 + 1 个 agent 写 Boss prompt。

每个实施 prompt 都附上侦察报告的关键片段（schema、函数名、坑、禁止项、headless 验证命令）。实施 agent **必须自跑 headless 合约测试并修到绿才返回**。并行写不同文件（game/ vs docs/）零冲突。

### 4) 验证阶段 —— 独立复核（不信任代理自报）

subagent 返回后，由主线程**再独立重跑**受影响合约 + 抽查产物（model-prompts 的 frontmatter 键数、共享 suffix 次数、`git status` 确认改动来源）。本轮所有交付均过双检；`level_module_contract_test` 的既有失败也被确认为**改动前已存在**（模块族 10 vs 20 断言过时），随后单独修复。

### 5) 收益与两个真实收获

- **侦察抓到真 bug**：实施 Boss 的 agent 发现 `level_03_04` 已含 `elite_reflection_lord`，若按 `_chapter_elite_for`（取第一个匹配）会重复刷怪 → 改为按 id 精确取（新增 `_chapter_elite_by_id`）。
- **soft-lock 预警**：Boss 侦察报告指出空 `story_flag` 会进 `_on_boss_story_threshold` → 无条件 `enter_story_resolution` + `_pending_fate_boss` 软锁 → 实现时在 `_on_boss_story_threshold` 顶部加**空旗早退兜底**，`make_blind_bell()` 再置 `allow_lethal_on_execution=true`，双保险。

---

## 变更明细

### docs/story 同步（2 Explore 侦察后直改）
- `chapter-bridge-map.md`：§内容与运行时边界 从「仍待内容填充」改为「L-01…L-06 已实现 + 仍待扩展」；结局矩阵 / NPC 迁移补运行时 ID（`kindle/keeper/void/forge`、`npc_*`、`furnace_memory_1..4`、`quest_soul_return` 等）。
- `main-story.md`：「centuries」→「five centuries」（对齐 lore 500 年）；隐藏结局解锁条件补四段炉忆。

### 支线「桥头的供茶」（胖猫事件去实名改编，Ch3 支线 4）
- 检索报告 → `docs/research/soulslike/story-fat-cat-event.md` + `docs/research/index.md` 索引行。
- 设计 → `docs/chapters/03-jade-veil/chapter-supplement.md` 支线 4（含寓言层：制造对立掩盖系统失败）。
- 实现：`quest_bridge_tea` + `npc_bridge_tea_soul` 四分支对白 + `bridge_tea_fate` 抉择（证伪 / 随波）+ 供茶拾取 + 茶魂 NPC + 贪烬鬼精英（`level_03_04`）。
- 合约：`tests/smoke/bridge_tea_quest_contract_test.gd` → OK。

### 可选 Boss「盲钟·听烬」（全新原创，禁止重复）
- 设计 → `docs/bestiary/boss-blind-bell-hearer.md`；注册进 `bosses-master.md` Optional Boss 槽位（0→1，身份计数 7→8）。
- 实现：`level_05_06` 无目钟塔、`OptionalBossContent.boss()`（2 阶段、weak_point `bell_mouth`）、`make_blind_bell()`（空 story_flag + 致死）、`enemy_factory` `hanging_bell` 体型、3-4 桥头隐藏入口（`_travel_to_level` 传送）。
- 合约：`tests/smoke/optional_boss_contract_test.gd` → OK；关卡 28→29 / 档案 5→6 计数同步（content_validator + 3 个既有合约）。

### model-prompts（5 个，全部符合 00-template）
- `characters/npcs/06-茶魂`、`07-烬茶倌`、`enemies/03-jade-veil/10-贪烬鬼`、`props/08-桥头供茶`、`bosses/06-盲钟-听烬`。

### 修复过时测试
- `level_module_contract_test.gd`：模块族 10→20（对齐 L-16/L-17 扩展）、28→29 关、错误文案同步。

---

## 验证

- 新增合约：`BRIDGE_TEA` / `OPTIONAL_BOSS_BLIND_BELL` → OK。
- 既有合约（重跑全绿）：`story_runtime` / `chapter3_5_wiring` / `content_registry` / `campaign_generation` / `boss_weakpoint` / `level_module`。
- 运行时 smoke `ASHEN_HOLLOW_SMOKE_OK`；编辑器 `--headless --editor --quit` EXIT 0，无 GDScript 解析错误。

## 未做（本次明确不做）

- 支线奖励（桥头供茶饰品 / 怒烬团）未接入真实物品系统（当前旗标 + HUD）。
- Boss 标志性机制（P2 纯音频前摇、摄魂鸣吸烬、12 口诱饵钟、静默硬直）目前为**数据 / 元数据级**（phase / weak_point / status），交互系统待下一批。
- 胖猫事件「51 万转账净额」官方口径无法核实，未采信。
- 现实事件改编伦理红线已写入报告：去实名、不消费死者、随波分支明示代价。
