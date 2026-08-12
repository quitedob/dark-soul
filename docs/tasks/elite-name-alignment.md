# Elite Name Alignment — 精英怪命名对齐清单

**Status:** ✅ 全部完成（11 个 display_name 已对齐设计名册；3 个错位精英已移动到设计层；memory_eater 已由 wave2 对齐）
**Owner:** L-22（P1-4）
**Updated:** 2026-08-12
**Authority:** [chapters/01-spirit-awakening/chapter-supplement.md](../chapters/01-spirit-awakening/chapter-supplement.md) · [chapters/02-blood-iron/chapter-supplement.md](../chapters/02-blood-iron/chapter-supplement.md) · [chapters/03-jade-veil/chapter-supplement.md](../chapters/03-jade-veil/chapter-supplement.md) · [chapters/04-celestial-fall/chapter-supplement.md](../chapters/04-celestial-fall/chapter-supplement.md) · [chapters/05-throne-of-ashes/chapter-supplement.md](../chapters/05-throne-of-ashes/chapter-supplement.md) · [bestiary/enemies-master.md](../bestiary/enemies-master.md) · [bestiary/bosses-master.md](../bestiary/bosses-master.md)
**Design name authority:** 设计精英名册以各章 `chapter-supplement.md`「👹 精英怪」小节为准；`bestiary/` 仅列普通敌人与 Boss，不含精英 display_name，故不作对照源。

---

## 目标

让代码精英 `display_name`（`game/scripts/data/chapter_*_content.gd` 的 `elites()`）与设计名册对齐，并保留 bilingual（英文/中文）格式。**只改 `display_name` 文案，不改 `id`**（id 为内部键，多处 spawn/掉落按 id 引用，改名会破坏引用链）。

---

## 本次改动（✅ DONE，2026-08-12）

### 1. 11 个 display_name 对齐设计名册（双语均取自各章 chapter-supplement）

| 文件 | id | 旧名 | 新名（设计值） |
|------|----|------|------|
| `chapter_1_content.gd` | `elite_elixir_golem` | Elixir Golem / 丹药魔像 | Alchemy-Obsessed Spirit / 炼丹痴魂 |
| `chapter_2_content.gd` | `elite_torture_master` | Torture Master / 刑讯官 | Forge-Rage Engine / 炉暴刑具 |
| `chapter_2_content.gd` | `elite_beacon_lord` | Beacon Lord / 烽火将 | Twin Beacon Generals / 双生烽火守将 |
| `chapter_2_content.gd` | `elite_siege_commander` | Siege Commander / 攻城校尉 | Gluttonous Quartermaster / 贪噬军需官 |
| `chapter_3_content.gd` | `elite_reflection_lord` | Reflection Lord / 镜像主 | Mirror Lake Dream-Weaver / 镜湖织梦者 |
| `chapter_3_content.gd` | `elite_fox_bride` | Fox Bride / 狐嫁娘 | Maze Poet / 迷宫诗人 |
| `chapter_4_content.gd` | `elite_celestial_swordsman` | Celestial Swordsman / 天剑士 | Cloud Bridge Guardian / 云桥守将 |
| `chapter_4_content.gd` | `elite_alchemy_master` | Alchemy Master / 炼丹宗师 | Falling Sky Artisan / 坠天工匠 |
| `chapter_4_content.gd` | `elite_scripture_keeper` | Scripture Keeper / 藏经主 | Scripture Guardian / 经文守卫 |
| `chapter_5_content.gd` | `elite_gravity_twister` | Gravity Twister / 重力扭曲者 | Avatar of Anti-Entropy / 逆熵化身 |
| `chapter_5_content.gd` | `elite_soul_forger_echo` | Soul-Forger Echo / 铸魂者回响 | The Last Torch-Servant / 最后的烛阴侍者 |
| `chapter_5_content.gd` | `elite_void_sentinel` | Void Sentinel / 虚空守卫 | Sea of Possibilities / 可能性之海 |

- 双语字符串均与各章 `chapter-supplement.md`「👹 精英怪」小节逐一核对一致。
- **其余未改：** `elite_bronze_mirror_keeper`（已对齐，守阵石卫）、`elite_memory_eater`（wave2 九尾任务已对齐，Thousand-Year Tree Spirit / 千年树魂）、`elite_ember_greed_ghost`（贪烬鬼，保持原样）。

### 2. 3 个错位精英移动到设计出现位（改 `appears_in`）

| id | 旧出现位 | 新出现位（设计） |
|----|---------|------------------|
| `elite_siege_commander`（贪噬军需官） | level_02_02 | level_02_05 |
| `elite_fox_bride`（迷宫诗人） | level_03_03 | level_03_05 |
| `elite_void_sentinel`（可能性之海） | level_05_01 | level_05_03 |

- 配套在 `game_world.gd` 的 `level_02_05` / `level_03_05` / `level_05_03` 各新增精英 spawn 块（`_chapter*_elite_for` + 非空守卫），并同步更新目标层注释。
- 旧位置（level_02_02 / level_03_03 / level_05_01）原有的 `_chapter*_elite_for` 守卫块保留为标准空操作（匹配不到即返回 {}，安全）。

### 3. 回归保护

- 新增合约测试 `game/tests/smoke/elite_name_contract_test.gd`：断言全部 15 个 `elite_*` id 与硬编码期望集合一致（防误改 id 破坏 spawn/掉落引用链），并逐一断言每个精英的 `display_name` / `appears_in`。运行标记 `ELITE_NAME_CONTRACTS_OK`。

---

## 全量对照（代码 15 精英 vs 设计名册 — ✅ 全部对齐）

| Code id | Code display_name（现状） | Code 出现位 | 设计对应名 | 状态 |
|---------|---------------------------|-------------|-----------|------|
| `elite_bronze_mirror_keeper` | Formation-Guarding Stone Sentinel / 守阵石卫 | level_01_03 | 守阵石卫 (Formation-Guarding Stone Sentinel) | ✅ DONE |
| `elite_elixir_golem` | Alchemy-Obsessed Spirit / 炼丹痴魂 | level_01_04 | 炼丹痴魂 (Alchemy-Obsessed Spirit) | ✅ DONE |
| `elite_torture_master` | Forge-Rage Engine / 炉暴刑具 | level_02_03 | 炉暴刑具 (Forge-Rage Engine) | ✅ DONE |
| `elite_beacon_lord` | Twin Beacon Generals / 双生烽火守将 | level_02_04 | 双生烽火守将 (Twin Beacon Generals) | ✅ DONE |
| `elite_siege_commander` | Gluttonous Quartermaster / 贪噬军需官 | level_02_05 | 贪噬军需官 (Gluttonous Quartermaster) | ✅ DONE（已移至 2-5） |
| `elite_memory_eater` | Thousand-Year Tree Spirit / 千年树魂 | level_03_02 | 千年树魂 (Thousand-Year Tree Spirit) | ✅ DONE（wave2 九尾任务） |
| `elite_reflection_lord` | Mirror Lake Dream-Weaver / 镜湖织梦者 | level_03_04 | 镜湖织梦者 (Mirror Lake Dream-Weaver) | ✅ DONE |
| `elite_fox_bride` | Maze Poet / 迷宫诗人 | level_03_05 | 迷宫诗人 (Maze Poet) | ✅ DONE（已移至 3-5） |
| `elite_ember_greed_ghost` | Ember-Greedy Ghost / 贪烬鬼 | level_03_04 | 贪烬鬼（证伪线精英） | ✅ DONE（未改） |
| `elite_celestial_swordsman` | Cloud Bridge Guardian / 云桥守将 | level_04_01 | 云桥守将 (Cloud Bridge Guardian) | ✅ DONE |
| `elite_alchemy_master` | Falling Sky Artisan / 坠天工匠 | level_04_02 | 坠天工匠 (Falling Sky Artisan) | ✅ DONE |
| `elite_scripture_keeper` | Scripture Guardian / 经文守卫 | level_04_03 | 经文守卫 (Scripture Guardian) | ✅ DONE |
| `elite_gravity_twister` | Avatar of Anti-Entropy / 逆熵化身 | level_05_02 | 逆熵化身 (Avatar of Anti-Entropy) | ✅ DONE |
| `elite_soul_forger_echo` | The Last Torch-Servant / 最后的烛阴侍者 | level_05_04 | 最后的烛阴侍者 (The Last Torch-Servant) | ✅ DONE |
| `elite_void_sentinel` | Sea of Possibilities / 可能性之海 | level_05_03 | 可能性之海 (Sea of Possibilities) | ✅ DONE（已移至 5-3） |

---

## 结论

- ✅ 全部 15 个精英的 `display_name` 与设计名册一致（bilingual 格式沿用 `"English / 中文"`）。
- ✅ 3 个错位精英已按设计移动到对应出现层（2-2→2-5、3-3→3-5、5-1→5-3），`game_world.gd` 目标层已补精英 spawn 块。
- ✅ 所有 `elite_*` id 保持不变（合约测试守护）。
- ✅ `game_world.gd` 目标层注释已同步；旧位置注释已清理。

## 风险与约束

- **id 不可改**：`elite_*` 为 spawn/掉落/存档引用键；本次仅改 `display_name` 与 3 个 `appears_in`，id 全部保持不变，由 `elite_name_contract_test.gd` 守护。
- **出现位语义**：`appears_in` 仅控制该精英在哪个 level 通过 `_chapter*_elite_for` 被取出；掉落/任务引用按 id 走，精英移动后自动跟随，无需联动改动。
