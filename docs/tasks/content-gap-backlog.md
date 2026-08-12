# Content / Feature Gap Backlog — 内容与功能缺口

**Status:** ✅ P0–P2 + 工程项全部闭环（L-01…L-24 DONE，2026-08-12）
**Updated:** 2026-08-12  
**Authority:** [bestiary/enemies-master.md](../bestiary/enemies-master.md) · [bestiary/bosses-master.md](../bestiary/bosses-master.md) · [chapters/](../chapters/) · [systems/](../systems/) · [tasks-master.md](../tasks-master.md)

---

## 审计结论

系统层（战斗/防务/AI/镜头/存档/HUD/输入）实现扎实且测试良好；P0 接线（L-01…L-06）、P1 细节（L-07…L-17）、P2 资产（L-18…L-22）与工程项（L-23…L-24）已**全部闭环**，见 [devlog 08](docs/devlog/2026-07-31/08-l-p0-wiring-l-01-l-06.md)、[devlog 09](docs/devlog/2026-07-31/09-p1-wave-l-07-l-17.md) 与 [devlog 08-12](docs/devlog/2026-08-12/01-cast-hitbox-real-animation-session-reflection.md)。剩余为**内容债**（真动画观感 QA、施法/战技身体 clip、OAL 许可、Ch.3–5 专属 Boss 流程等）：

> **库房满仓、货架补满。** Ch.1–5 遭遇、Boss、NPC、命运抉择/隐藏结局链、真模型/真动画、Boss 攻击 type / 弱点锚点、.tres 作者化、精英对齐全部接入。

关键证据（随 P0/P1 更新后的现状）：
- 章节分发：`game/scripts/game_world.gd:369`（`_spawn_chapter_encounters`）按章调 `_spawn_chapter3/4/5_encounters`（`:383-394`）；三哨兵仅剩「未注册章节」兜底（`:395-400`）
- Boss 生成：7+1 Boss 全部可生成（含可选盲钟）
- 命运抉择闭环：`_on_fate_choice_made`（`game_world.gd:1512`）→ `_apply_fate_boon`（`:1544`）→ Boss 经 `conclude_story_fate` 结算

---

## P0 — 接线与闭环（✅ 已全部闭环，2026-07-31 见 [devlog 08](docs/devlog/2026-07-31/08-l-p0-wiring-l-01-l-06.md))

| ID | Task | 状态 |
|----|------|------|
| L-01 | **命运抉择玩法闭环**：抉择后 Boss 结算 / 开出口 / `defeated_bosses`；选项承诺效果（爆发增益/防护等）落地 | ✅ DONE（`conclude_story_fate` + `_apply_fate_boon`） |
| L-02 | **Ch.3–5 遭遇接线**：`_spawn_chapter_encounters` 改调 `chapter_3~5_content.gd` 内容表 | ✅ DONE（`_spawn_chapter3/4/5_encounters`） |
| L-03 | **Ch.3–5 Boss 生成**：九尾/玄霄/嗔念/执念/烛阴 spawn | ✅ DONE 生成层（战后专属流程：玄霄逃出/烛阴四结局/九尾凝视仍为后续内容债） |
| L-04 | **隐藏结局"共铸新炉"flag 链**：三任务 + `furnace_memory_1..4` 写入方 + QuestState 启动 + 终幕 `forge` 选项 | ✅ DONE（红晶证物 5-1..5-4 + `add_extra_option`） |
| L-05 | **跨章 NPC**：铁心（锻造）/ 忆姬 / 玄霄残识 / 寂灭进游戏 + 铁心工坊锻造 +10 | ✅ DONE（按章祠堂生成 + `_try_iron_heart_forge`） |
| L-06 | **召唤物**：护法灵童/金甲力士/往生莲/怨灵/白鹤童子 进 `player_spells` | ✅ DONE（`SUMMON_CONFIG` + `SpiritSummon` + `spirit_talisman` 灵符） |

## P1 — 已全部落地（✅ 2026-07-31 见 [devlog 09](docs/devlog/2026-07-31/09-p1-wave-l-07-l-17.md)）

| ID | Task | 状态 |
|----|------|------|
| L-07 | 连段 combo：`AttackData` 增 `next_light`/`next_heavy`/`chain_open|close_seconds` + 缓冲推进 | ✅ DONE（`_combo_chain_*`，动作族推导兜底） |
| L-08 | 武器类别逐类 moveset：直剑/大剑/特大剑/长枪/斧锤/曲剑/拳爪/匕首/盾 差异化动作家族 | ✅ DONE（`compatibility_moveset_factory._class_profile`） |
| L-09 | 职业/天赋/成长：8 职业（4 基础 + 4 混合体解锁）+ 3 层天赋树 + 切换门控 + **8 经脉 ×5 级** | ✅ DONE（`talent_data`/`talent_system` + `meridian_data`/`meridian_system`；材料以烬替代并标注） |
| L-10 | 装备/防具/状态效果：重量档/翻滚档 + 出血/狐火/迷心/中毒 + **背包入口** | ✅ DONE（`status_effect.gd` + ARMOR_DATA + 翻滚档 + `inventory_overlay.gd` 背包 UI + Boss/精英掉落实例化背包） |
| L-11 | 法术扩充 7→32：五行/灵体召唤/净化/复活 | ✅ DONE（`SPELL_CONFIG` 39 条 + `resolve_cast` 全分支 + CD） |
| L-12 | 快速旅行（跨烬龛传送） | ✅ DONE（`fast_travel_overlay.gd`，Ch.2 后祠堂可互传） |
| L-13 | 兵器诀数据驱动化（9 类） | ✅ DONE（9 个 `WeaponArtData` .tres + `weapon_arts_catalog`） |
| L-14 | 抓投扩展到人型敌人 + 玩家 | ✅ DONE（`can_grab` + 玩家 `try_player_grab` 复用执行导演） |
| L-15 | 升级锻造扩展：武器 +1~+10（已）/ 道行 / 魂器 | ✅ DONE（`dao_level` + `vessel_level`；经脉见 L-09） |
| L-16 | 重力操作 / 倒悬（Ch.4/5）真实现 | ✅ DONE（`player.gravity` 翻转 + `gravity_inversion`/`gravity_anchor`） |
| L-17 | 谜题模块扩充：镜光/阀门/天仪/配料/重力锚/谜语/记忆验证/潜行/铸魂试炼 | ✅ DONE（10 新家族挂载对应关卡） |

## P2 — 资产与占位（✅ 已全部闭环，2026-08-12）

| ID | Task | 状态 |
|----|------|------|
| L-18 | 真模型资产生产：85 GLB 导入+注册+敌人/首领/召唤/NPC 激活+专属动效档案（[devlog 08-11](docs/devlog/2026-08-11/01-85-glb-into-game-real-model-milestone.md)）；真动画扩至 **20 clip**（bind-pose 回退 + 19 状态键，见 [research-real-animation-pipeline](../research-real-animation-pipeline.md)） | ✅ DONE（职业身体线程化 / 武器握持点 / 观感 QA 仍为内容债） |
| L-19 | Boss 攻击 type 全覆盖：`boss_attack_executor.gd` 从 8 种扩到内容表 ~25 种，去掉 `_:` 静默近战兜底 | ✅ DONE（`boss_attack_types_contract.gd`） |
| L-20 | Boss 弱点骨骼锚点（替换虚拟偏移） | ✅ DONE（`boss_execution_anchor_contract.gd`） |
| L-21 | 资源 .tres 作者化：5 风格武器/招式 + 敌人攻击 .tres | ✅ DONE（敌人攻击 `.tres` 磁盘清单 17/17 路径齐全） |
| L-22 | 精英怪对齐文档（代码精英 → 设计精英名册） | ✅ DONE（11 个 `display_name` 对齐 + 3 处移层：`siege_commander` 2-2→2-5、`fox_bride` 3-3→3-5、`void_sentinel` 5-1→5-3；见 [elite-name-alignment.md](elite-name-alignment.md)） |

## 测试与工程债（✅ 已全部闭环，2026-08-12）

| ID | Task | 状态 |
|----|------|------|
| L-23 | 测试补齐：`tests/integration/` 目录 + 音频/UI/镜头/叙事/存档/输入/法术/投掷物契约测试 | ✅ DONE（新增 `real_root_motion_contract.gd` / `elite_name_contract_test.gd` / `boss_attack_types_contract.gd` / `boss_execution_anchor_contract.gd` 等；GUT 96/96） |
| L-24 | `.gd.uid` 补齐（5 脚本）+ devlog/数据口径修正：`05_04` 关卡名、嗔念/执念 HP、I-16 口径统一、精英名对齐 | ✅ DONE（`chapter2_slice_contract_test.gd` 断言随精英移层更新） |

---

## 建议实施顺序（2026-08-12 已全部完成）

1. **L-01 命运抉择闭环**（最小改动、最大诚信修复）
2. **L-02 + L-03 Ch.3–5 接线**（数据/工厂现成，改生成分支即解锁整章）
3. **L-05 + L-06 NPC/召唤物**（锻造挂烬龛升级，召唤挂 player_spells）
4. **L-04 隐藏结局链**
5. **L-18 资产化**（接 `docs/model-prompts` P0 清单）
6. 其余 P1/P2 + 测试债按需

> 上述 P0–P2 + 工程项已于 2026-08-12 全部落地（L-01…L-24 ✅ DONE）。后续内容债：真动画观感 QA、施法/战技身体 clip 选源、OAL 分发书面许可、Ch.3–5 专属 Boss 流程、跨章叙事填充。

## Related

- [devlog/index.md](../devlog/index.md)（2026-07-31 审计为 devlog 外的 4 路 subagent 扫描）
- [planning/soulslike-gap-analysis.md](../planning/soulslike-gap-analysis.md)
- [tasks-master.md](../tasks-master.md)
- [model-prompts/README.md](../model-prompts/README.md)
