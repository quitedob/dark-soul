# L 系列 P0 接线：L-01…L-06 闭环落地

**日期:** 2026-07-31
**范围:** `content-gap-backlog.md` 建议实施顺序的前 5 项（L-01 命运抉择闭环 / L-02+L-03 Ch.3–5 接线 / L-05 跨章 NPC+锻造 / L-06 召唤物 / L-04 隐藏结局链）

---

## 结论

「库房满仓、货架只摆两层」的核心接线缺口已收口：Ch.3–5 生成层、命运抉择闭环、召唤物、隐藏结局证物链、跨章 NPC 全部进入代码。验证：编辑器导入 EXIT 0、smoke `ASHEN_HOLLOW_SMOKE_OK`、新增合约 `ASHEN_CHAPTER3_5_WIRING_CONTRACTS_OK`、GUT 95/96（唯一失败为**改动前已存在**的 `test_stamina_economy` 过期断言，见下）。

---

## 变更明细

### L-01 命运抉择闭环
- `game_world.gd`：`_on_fate_choice_made` 现在非致死终结 Boss（`conclude_story_fate` → `defeated` 信号 → 奖励/`defeated_bosses`/胜利出口），不再是写-only。
- 新增 `_apply_fate_boon`：兑现 `boss_fate_catalog` 选项承诺。即时型：刑天·吸收 → 玩家 +25% 伤害 30s（`player.grant_fate_damage_boost`，`_begin_melee_swing` 乘算）；其余写消费旗标（`fate_remnant_trust`/`fate_guardian_protection`/`fate_heroes_aid`/`fate_zhu_yin_wrath`/`fate_safe_illusion`/`fate_dispel_illusion`/`fate_gravity_boost`/`fate_zhu_yin_weakness`）。
- `enemy.gd`：新增 `conclude_story_fate()`（解冻 AI、非致死发 `defeated`、淡出移除）。

### L-02 + L-03 Ch.3–5 遭遇与 Boss 接线
- `game_world.gd`：preload `chapter_3/4/5_content.gd`；`_spawn_chapter_encounters` 占位分支（原 `:353` 三哨兵）改为按章分发。
- 新增 `_spawn_chapter3/4/5_encounters`（28 关布局）、通用 `_chapter_enemy_by_id` / `_chapter_elite_for`。
- `_spawn_content_enemy` 守卫体兜底扩展为 `match`：九尾/嗔念/执念/玄霄/烛阴 → 章节工厂体型与武器形状。
- Ch.4 复数 `bosses()` 经 `_chapter4_boss_by_id` 处理；嗔念(04_04)/执念(04_05)/玄霄(04_06)/九尾(03_06)/烛阴(05_05) 全部可生成。

### L-04 隐藏结局「共铸新炉」flag 链
- 新增 `world/furnace_memory_crystal.gd`；第五章 5-1..5-4 各刷一红晶证物。
- `game_world.gd`：拾取 → 置 `furnace_memory_1..4` + 三真相任务推进（第 1 块开启 `quest_soul_return`/`quest_forge_last_question`/`quest_furnace_whisper`，第 4 块齐备 complete）。
- `fate_choice_overlay.gd`：新增 `add_extra_option`；烛阴终幕 `ending_state` 且 `EndingResolver.reachable` 含 `forge` 时追加「共铸新炉」选项（此前仅 3 选项、`forge` 不可选）。

### L-05 跨章 NPC + 铁心锻造
- `game_world.gd`：`_spawn_shrine_npc` 重构为按章节生成 5 NPC（云游/铁心/忆姬/玄霄残识/寂灭），关卡加载时随祠堂重刷。
- `dialogue_runner.gd`：4 新 NPC 台词（忆姬读炉忆进度、玄霄残识按 `fate_zhu_yin_weakness` 给烛阴弱点情报、寂灭按 `forge` 可达给指引）+ `apply_aftermath`（铁心 → `npc_iron_heart_met` + `unlock_weapon_forging`）。
- 铁心工坊锻造：`_try_iron_heart_forge`（与铁心对话后结算）——武器 +1..+10（+5%/级），花费递增（120…2600 烬）。存档权威 `run_state.progression_values.weapon_forge_level`；`player.set_forge_level` 同步 `_begin_melee_swing` 乘算；`_apply_run_state` 恢复。

### L-06 召唤物
- `data/player_combat_data.gd`：`SUMMON_CONFIG` 5 灵（护法灵童/金甲力士/往生莲/怨灵/白鹤童子，`spell_type:"summon"`，含保留专注）。
- 新增 `combat/spirit_summon.gd`：嘲讽坦克/肉盾/治疗图腾/玻璃大炮 DPS/专注支援五种行为；`receive_hit`/`is_targetable`/`get_target_point` 与敌 FSM 互认；白鹤童子场时 `player.focus_regen_multiplier=1.5`。
- `player_spells.gd`：`resolve_cast` 召唤分支、`try_summon`/`set_active_summon`/`dismiss_all`/`active_summon_spell_id`；灵消失返还 `reserved_focus`。
- `hand_equipment.gd` + `player.gd`：新增 `spirit_talisman`（灵符）动作 `spirit_summon`/`spirit_dismiss`，施法可达。

---

## 验证

- 全脚本 `--check-only`：除 5 个**改动前已存在**的 UI overlay `is_visible()` 警告外全绿（death/help/pause/title/victory_overlay）。
- 编辑器导入 `--headless --editor --quit`：EXIT 0；`SpiritSummon` 等全局类注册正常；L-24 缺的 5 个 `.gd.uid`（dialogue_runner/ending_resolver/quest_state/dialogue_overlay/shrine_npc_interact）已由导入自动补齐。
- 运行时 smoke：`ASHEN_HOLLOW_SMOKE_OK`。
- 新增合约 `tests/smoke/chapter3_5_wiring_contract_test.gd`：内容表/Boss 相位/关卡链/命运目录/隐藏结局链/召唤配置 → `ASHEN_CHAPTER3_5_WIRING_CONTRACTS_OK`。该合约抓出 `SUMMON_CONFIG` 漏 `spell_type` 的 bug（已修）。
- GUT：95/96。唯一失败 `test_stamina_economy::test_target_style_costs_and_insufficient_block` 在 stash 掉本批改动后**同样失败**（过期数值断言 35/84 vs 实际 57.44/100），判定为既有负债，未在本次范围。

## 未做（本次明确不做）

- L-07..L-17（连段/逐类 moveset/天赋/装备/法术扩编/快速旅行/兵器诀数据化/抓投扩展/锻造深度/重力/谜题）仍 PENDING。
- L-18..L-22（真模型/Boss type 全覆盖/弱点骨骼锚点/.tres 作者化/精英对齐）。
- 烛阴 P3 零重力、玄霄 90s 逃出序列、九尾记忆凝视等 Boss 专属流程（本次只接线生成 + 命运闭环；专属流程为下一批内容债）。
