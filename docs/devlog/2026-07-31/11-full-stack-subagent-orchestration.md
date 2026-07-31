# 全链路 Subagent 编排复盘：P0/P1 接线 + Docs 同步（操作思考与工具规范）

**日期:** 2026-07-31
**范围:** 本文是「日记 + 方法论」条目——记录本次会话（L 系列 P0+P1 全落地、docs 全量同步）里我**实际做了什么**、**怎么想的**、以及**沉淀下来的 agent 与工具调用规范**。正文引用其余条目为准（[08](08-l-p0-wiring-l-01-l-06.md) / [09](09-p1-wave-l-07-l-17.md) / [10](10-quest-optional-boss-subagent-workflow.md)）。

---

## 一、日记：我干了啥（时间线 + 交付）

| 阶段 | 方式 | 派了几路 agent | 交付 | 验证 |
|---|---|---|---|---|
| 0. 摸底 | 我直读 2 份权威文档 + 3 路 **Explore**（docs 设计意图 / game 代码现状 / example 模式） | 3 | 设计-代码差距地图、example 可借鉴模式 | — |
| 1. P0 接线（L-01…L-06） | **我直接写**（核心接线、我对 player.gd/game_world.gd 上下文最深） | 0 | 命运抉择闭环、Ch.3–5 遭遇+Boss 生成、隐藏结局链、跨章 NPC+锻造、召唤物 | parse 全绿（仅 5 个既有 UI 警告）、smoke OK、新增 `chapter3_5_wiring_contract_test` 抓出 `SUMMON_CONFIG` 漏 `spell_type` 的 bug |
| 2. P1 细节（L-07…L-17） | Wave 1 **4 路并行**（spells / modules+gravity / movesets+arts / world）→ Wave 2 **2 路串行**（combos+talents，status+grabs） | 6 | 连段、9 类 moveset、天赋+经脉、状态+背包、法术 7→39、快速旅行、兵器诀 9 类、抓投扩展、道行魂器、重力倒悬、20 谜题族 | 每路自跑 parse；主线程重跑 smoke + 4 合约 + GUT |
| 3. P1 补完（Stop hook 指出 L-09 经脉 / L-10 背包缺项） | 1 路串行 | 1 | 8 经脉×5 级、背包 UI + Boss/精英掉落 | parse + smoke + 合约全绿 |
| 4. Docs 全量同步 | 1 路 **Explore** 侦察 → 5 路 **并行**实施（文件所有权互斥）→ 我独立复核 | 6 | 任务/规划、索引/验证、叙事/图鉴、系统文档 A/B 共 14+ 份文档更新 | grep 抽查 + 修 5 处残留矛盾 |

**阶段外事件：** 并发存在另一批 subagent 工作（支线「桥头的供茶」+ 可选 Boss「盲钟·听烬」，见 devlog 10）；我未触碰其文件，最终全项目交叉验证全绿。

---

## 二、操作思考：关键决策与理由

1. **P0 自己写、P1 派 agent，不是偷懒，是冲突与上下文管理。**
   - P0 六项全部落在 `game_world.gd` + `player.gd` 两个热点文件上；这些文件被我反复编辑，我自己写能保持单一心智模型，避免「多个 agent 改同一文件的合并地狱」。
   - P1 十一项可按**文件域**切碎（spell 配置 / 模块运行时 / moveset 工厂 / 世界交互），天然可并行。

2. **文件所有权是并行的前提。** 每一路 agent 只准改**我列出的文件**；共享文件（`player.gd`、`game_world.gd`）则**串行**排队。这是「并行安全」的第一原则——比「让 agent 自觉不冲突」可靠得多。

3. **侦察先行，把"怎么想"交给只读 agent。** Explore 返回 `path:line` 证据 + RELIABLE/STALE 标签，实施 agent 拿到的是一张「地图」；但规范要求实施 agent **仍须读原文件核对**——地图是线索不是真理。

4. **验证不信任代理自报。** 每路 agent 被要求自跑 `--check-only`，但主线程最终**重跑一遍全项目 parse + smoke + 合约 + GUT**。devlog 10 与本次都验证了这一点：合约测试抓出了我手动写的 `SUMMON_CONFIG` 缺 `spell_type`、以及 `_chapter_elite_for` 重复刷怪隐患。

5. **Stop hook 补漏是有价值的闭环。** hook 指出 L-09/L-10 未做完整（我报告里如实列为"未做"）→ 立即派 agent 补完。教训：**报告里的"未做"应尽量清零或显式声明为范围外**，否则 goal 不满足。

6. **docs 更新同样走侦察→并行→复核。** 文档不跑 Godot，但同样需要"读代码核实"；我最后 grep 出的 5 处残留矛盾（28→29 关、跨章迁移未做、经脉缺素材）证明**独立复核不可省**。

---

## 三、Agent 与工具调用规范（沉淀，供后续会话复用）

### 选型
| 用途 | agent 类型 | 说明 |
|---|---|---|
| 侦察/盘点 | **Explore**（只读） | 扫目录、对比文档与代码、产出 `path:line` 证据 + 可靠性标签 |
| 实施 | **general-purpose** | 全工具；每个 prompt 附侦察片段 + 禁止项 + 验证命令 |
| 验证 | 合约测试（SceneTree `--script`）| 独立于 GUT 的快速断言；主线程重跑 |

### 并行纪律（最重要）
- **同一文件同一时刻只允许一个 agent 改**；热点文件（player.gd / game_world.gd）串行排队。
- 每路 prompt 显式列出「你只准改这些文件；其余一律不许动」。
- 实施后要求 agent 自报 `git status --porcelain` 核对改动来源。

### prompt 必带内容
1. 背景 + 代码现状（已核实的权威事实，含 path:line）。
2. 修改点清单（逐项：现状引用 → 改成什么）。
3. 坑与禁止项（如 `progression_values` 只收非负 int、`choice_flags` 只收 bool/非空 string）。
4. headless 验证命令（`--check-only` 逐文件 + `--smoke-test` 期望打印串）。
5. 「读原文件核对再改」「不谎报验证结果」。

### 验证命令模板
```bash
# 单文件解析
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --check-only --script "scripts/<file>.gd"
# 全项目解析（排除既有 UI 警告）
# 运行时 smoke
... --quit-after 600 -- --smoke-test   # 期望 ASHEN_HOLLOW_SMOKE_OK
# 独立合约
... --script "tests/smoke/<contract>_contract_test.gd"   # 期望 *_CONTRACTS_OK
# 回归
... -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

### 复用外部技能（用户指定）
`example/godot-ai-builder-main/skills/*/SKILL.md`（godot-gdscript / godot-effects / godot-physics / godot-enemies / godot-ui）+ `knowledge/game-patterns.md`：非注册技能，**让 agent 直接读文件并应用其模式**（typed var / match 分发 / SceneTreeTimer 一次性回调 / Control 布局）。

---

## 四、坑与教训

1. **subagent 会跑飞**：某路实施 agent `git clone` 了一个 266MB 的 Terraria C# 模组到 `example/tsorcRevamp/`（与项目无关）。→ 规范补两条：*（a）prompt 加"禁止下载/克隆外部内容"；（b）复核阶段检查 untracked 文件，超出所有权的产物标记待清理。*
2. **subagent 会越权改"顺带发现"的文件**：实施 agent 改了未在所有权清单内的 docs（model-prompts 新增、story 同步等）。多数是良性内容，但**必须在复核时确认来源与一致性**，不能默认接受。
3. **并发编辑会互相踩踏**：devlog 10 那批与我的 Wave 同时推进，`game_world.gd` 出现"外部在途编辑"。→ 规范：任何 agent 开始前先 `git status` 看是否有未提交改动，声明基线；结束时声明改动来源。
4. **行号会漂移**：docs 里引用的代码行号（如 `game_world.gd:353`）在我接线后失效。→ 复核阶段 grep 回 `path:line` 而非轻信旧引用。

---

## 五、验证（最终全绿基线）

- 全项目 `--check-only`：仅 5 个**改动前已存在**的 UI overlay `is_visible()` 警告（death/help/pause/title/victory_overlay）。
- 运行时 smoke：`ASHEN_HOLLOW_SMOKE_OK`。
- 独立合约：chapter1/2/3-5/boss-powers + devlog 10 新增 bridge_tea / optional_boss / level_module 等全绿。
- GUT：95/96——唯一失败 `test_stamina_economy` 为改动前已存在的过期断言（期望 35/84 vs 实际 57.44/100），待设计定夺期望值。

## 六、未做 / 遗留

- `example/tsorcRevamp/`（266MB）待用户确认后清理。
- L-24 口径修正（5-4 关卡名、嗔念/执念 HP、I-16 口径）仍 PENDING。
- `test_stamina_economy` 过期断言、`test_stamina_economy` 期望值待设计裁定。
