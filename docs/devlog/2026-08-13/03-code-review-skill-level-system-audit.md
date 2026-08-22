# 代码审查复盘：技能系统 + 关卡系统（"永不生效"排查 + 文档与历史对账）

> 2026-08-13 · 用户报告「技能系统、关卡系统**从不生效**，且文档与 history 不符」，要求「一文件夹一子代理」审查 `game/scripts` 与 `docs`。
> 重点：**每一个动作的完整时间线、每一处难点如何定位与化解、以及沉淀的持久记忆（memory）**。
> 目标读者：未来接手同类排查的我 / 协作子代理，避免重踩本会话反复掉进的坑。

---

## 0. 会话全景（一句话）

用户前提是「技能 + 关卡两个系统都坏了，且文档对不上历史」。我派 2 个只读子代理分头审查（`docs` 探路 + `game/scripts` 代码），随后**独立复核**每个关键结论，得出修正后的真相：**技能系统是真坏（数据已写、接线缺失），关卡核心推进链路其实完好，坏的是文档过度声称了「已验证/已上线」**。

---

## 1. 全部动作（按序时间线）

1. **加载审查方法论**：读 `codereviewer` skill 的三个参考文件（`subagent-strategy.md` / `change-impact.md` / `report-template.md`），拿到「子代理任务简报必须含 9 字段」「docs 探路先于代码审查」「命名/字面量不回归约束」等硬要求。
2. **侦察仓库边界**：`ls` `game/scripts` 与 `docs`，`find` 全库找 `history` 目录。
3. **消歧**（见难点 1）：确认 `docs/history` 不存在 → 实为 `docs/devlog`；把「技能系统」「关卡系统」映射到具体文件。
4. **建 3 任务清单**（docs 探路 / 代码审查 / 复核合并）。
5. **并行派 2 子代理**，各自带完整简报（问题 / 根目录 / 边界 / 排除 / 只读 / 证据 / 覆盖 / 命名约束）。
   - `docs-scout`（Explore，只读）：扫描 `docs/`，交叉核对代码，给每份关键文档打可靠性标签。
   - `code-reviewer`（general-purpose）：追踪技能链 + 关卡链，跑一次 `--headless --editor --quit` 解析校验，找具体缺陷。
6. **独立复核**（见难点 3）：对每个 HIGH/MEDIUM 结论跑 grep 闭包 + 定点读，4 批验证全部命中。
7. **合并出报告**，向用户交付「一半命中、一半修正」的结论。

---

## 2. 难点与化解（每一处怎么卡住、怎么拆）

### 难点 1：术语歧义 —— `docs/history` 不存在、"skill/level" 一词多义

- **卡在哪**：用户写了 `@docs/history`，但 `ls docs` 没有 `history/`；「技能系统」在魂系里可能是法术、天赋、经脉、职业切换任一种，「关卡系统」可能是关卡生成、章节推进、关卡内容任一种。
- **怎么拆**：`find docs -type d -name '*histor*'` → 空；`grep -ril 'history' docs` 只命中 4 处普通单词。再结合 `docs/devlog/2026-07-31/06-docs-folder-reorg.md` 确认「历史」= `docs/devlog`（`docs-zh/` 已移除、根级 CHANGELOG 已废）。「技能」用 `grep -rli 'skill' game/scripts` + 目录列举收敛到 `combat/player_spells.gd` + `data/player_combat_data.gd`（SPELL_CONFIG）+ `player.gd` 的 focus/stamina/talent/meridian；「关卡」收敛到 `levels/` + `world/` + `data/campaign_content.gd` + `data/chapter_*_content.gd`。
- **教训**：用户口中的「系统名」和代码里的文件名/注册表名往往不是一回事，**先消歧再派工**，否则子代理扫错范围白费一轮。

### 难点 2：用户前提部分错误 —— 「level system never works」不完全成立

- **卡在哪**：用户把「技能」和「关卡」捆在一起说「都不生效」。但代码审查全链追踪关卡系统后，发现**核心推进链路完好**：`campaign_content.gd` 29 关 → `procedural_campaign_level_builder` 铺图 → `campaign_module_runtime` 接 20 族模块 → `game_world` 刷怪/出口转场/结局，且 08-13 的脚本化通关合约已真机跑通 29 关 + 8 Boss + 结局。
- **怎么拆**：**不盲从前提**。把结论拆成三句话交付——「技能系统：真坏（数据写死、无接线）」「关卡核心推进：可用」「关卡**内容**：文档写的精雕房间/谜题/支线/拾取 vs 实际铺的平铺 6m 竞技场，对不上」。用证据区分「坏了」和「和文档长不一样」两种完全不同的病。
- **教训**：审查要验证用户前提本身，而不是证明它。找到「某部分是好的」同样是关键产出，能防止用户误修没坏的东西。

### 难点 3：子代理结论不可全信 —— 必须独立复核

- **卡在哪**：两个子代理都返回了很长、很自信的结论，但 skill 明确要求「子代理结论只是线索，coordinator 必须独立复核每个用于结论的 material claim」。
- **怎么拆**：不读子代理的二手转述，直接自己跑 grep 闭包 + 定点读，逐条复核：
  1. `_pending_cast|begin_cast|try_summon|try_cast_for_style|resolve_cast|cast_spell` 的调用点 → 确认 `_pending_cast` 只被 7 个法术 id + `try_summon` 赋值（`player.gd:2637-2651`、`player_spells.gd:402-425`），其余 32 条只在 `resolve_cast` 自己的 `match` 里出现。
  2. `.spells()|.weapons()|chapter_1_spells|...` → 只有 `chapter_content.gd:28-124` 的**定义**，零运行时消费者。
  3. `set_talent_points|add_talent_points|spend_talent|respec_talent_class|try_switch_class|set_hand_loadout|_grant_loot` → `set/add_talent_points`、`spend_talent`、`respec_talent_class`、`try_switch_class` 全部**零调用者**；`set_hand_loadout` 只有 `player.gd:2413`（出自 `set_combat_style`）与 `game_world.gd:2218`（出自旧存档）两处。
  4. `_grant_loot`（`game_world.gd:1538-1543`）定点读 → 只 append `collected_loot` + `inventory` 计数，**从不装备**。
  5. 模块放置错位：`campaign_content.gd:135`（gravity_inversion@`level_04_03`）vs `level-design-patterns.md:93`（5-2）；`campaign_content.gd:122`（stealth_passage@`level_03_03`）vs `level-design-patterns.md:95`（5-1）。
- **结果**：全部命中，HIGH/MEDIUM 结论升级为 CONFIRMED，可放心写进报告。
- **教训**：grep「调用点闭包」是审查性价比最高的复核手段——一个符号定义后有没有人调用，一 grep 就定生死，比读 2500 行 `game_world.gd` 快得多。

### 难点 4：文档规则冲突 —— 用户说 "changelog or devlog"，仓库禁根级 CHANGELOG

- **卡在哪**：用户原话「add docs/changelog or docs/devlog」，但 `docs/project-structure.md:111` 明确「交付只写 `docs/devlog/<日期>/`，**禁止**再堆根级巨型 `devlog.md` / `CHANGELOG.md`」。
- **怎么拆**：二选一里只选合法的那个——写 `docs/devlog/2026-08-13/`，语义英文文件名，序号接现有 `01`/`02` 取 `03-...`。
- **教训**：用户给了「或」的选项时，**按仓库规则择一**，而不是挑更省事的那个或两个都写。

### 难点 5：devlog 索引陈旧 —— index.md 缺整个 08-13 节

- **卡在哪**：要按约定入索引时发现 `docs/devlog/index.md` 只到 `2026-08-12`，**整个 `2026-08-13` 节缺失**——已有的 `01-full-fixall...` 和 `02-orientation...` 两篇都没进索引（它们就是上两个会话的产物，但索引没跟上）。
- **怎么拆**：补 `### 2026-08-13` 节，把已存在的 `01`/`02` 两篇按实际标题收编进来，再加本次 `03`。
- **教训**：写交付前先看索引是否已同步，顺手把别人的漏更补上，别让索引继续漂。

### 难点 6：任务列表 ID 失效（非阻塞）

- **卡在哪**：`TaskUpdate` 返回 `Task not found`——建任务时的 ID 在子代理/团队上下文中没同步回来。
- **怎么拆**：非阻塞，不纠缠；任务状态改在消息正文里口头自述，继续交付。
- **教训**：工具簿记失败时，**别停下等一个 ID**，用最轻的方式继续，把时间花在产出上。

---

## 3. 核心发现（已复核，CONFIRMED）

| # | 严重度 | 发现 | 关键证据 |
|---|---|---|---|
| 1 | HIGH | 39 条法术里 **32 条 + 全部 5 召唤**不可达（无输入/装备/解锁接线） | `player.gd:2637-2651` 只赋 7 个法术 id；其余 32 条仅存在于 `resolve_cast` 自身 `match` |
| 2 | HIGH | 法术/武器**获取层是死代码**（`chapter_X_spells()/weapons()` 零消费者） | `chapter_content.gd:28-124` 只有定义；grep 无运行时调用 |
| 3 | MEDIUM | Boss 掉落武器**只入库不装备** → 召唤触媒 `spirit_talisman` 不可达 | `game_world.gd:1538-1543` `_grant_loot` 从不 `set_hand_loadout` |
| 4 | MEDIUM | 天赋系统**死接线**：点数写存档但从不回读、无加点 UI | `game_world.gd:1067` 写 `talent_points`；`set/add_talent_points`/`spend_talent`/`respec_talent_class` 零调用者 |
| 5 | MEDIUM | 经脉升级**每次休息自动扣灰烬**、无 4 选项神龛菜单 | `game_world.gd:1233-1280` 自动循环 `_meridian_focus`；`upgrade-system.md:114-121` 描述的菜单不存在 |
| 6 | MEDIUM | `cast_spell` 在 5 职业中 **3 个是无操作/战技**，且拒绝施法时误报成功 | `player_spells.gd:27-37` 仅 3/4 返回法术 id；忽略 `begin_cast` 的 `bool` 返回 |

**文档可靠性标签**（material docs）：`spells-compendium.md` / `talent-skills.md` / `upgrade-system.md` / `switching-system.md` / `weapons-compendium.md` = **CONTRADICTED**；`chapters/*/chapter-overview.md` + `01-levels-detail.md` = **STALE**；`level-design-patterns.md` / `master-index.md` = PARTIALLY RELIABLE；`save-persistence.md` / `enemy-ai.md` / `architecture.md` / `validation.md` = RELIABLE。

**一句话根因**：`docs/project-structure.md:113` 规定「文档描述已验证行为；计划项须标明 planned」——但多份 compendium/overview 把「数据已写但接线缺失」的系统写成「已上线/已验证」，正是用户感觉「文档和实际对不上」的来源。

---

## 4. 沉淀的记忆（persistent memory）

| 文件 | 内容 |
|---|---|
| `skill-level-system-audit-facts.md`（新） | 技能系统死接线（32/39 法术 + 召唤 + 天赋 + 经脉 + 职业切换无接线）+ 关卡核心可用但文档过度声称内容的审计事实 |

---

## 5. 验证

- `godot --headless --path game --editor --quit` → **无脚本解析/加载错误**（由 code-reviewer 子代理执行）→ 上述缺陷全部是**逻辑/接线**缺陷，非加载期类型错误。
- grep 闭包复核（coordinator 亲自执行，见难点 3）→ 6 条 HIGH/MEDIUM 全部命中。

---

## 6. 仍未做（已知债，记录不展开）

- **零代码改动**：本次是 report-only 审查，用户未授权改码；未落地任何修复。
- **实机/运行时回归**：未跑 smoke/playthrough（只读审查限制），运行时回归未验证。
- **精确数值对账**：`.tres` 资源值 vs `combat-styles.md` 表、`docs/research/*`/`docs/story/*`/`docs/agents/*` 未深审。

---

## 7. 本会话改动文件清单

**新增文档**：`docs/devlog/2026-08-13/03-code-review-skill-level-system-audit.md`（本文）
**索引**：`docs/devlog/index.md`（补 `2026-08-13` 节，收编 01/02/03 三篇）
**持久记忆**：`skill-level-system-audit-facts.md`（新）+ `MEMORY.md`（加索引指针）
