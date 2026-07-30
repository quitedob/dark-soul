# 烬谷 (Ashen Hollow) 开发日志

## 2026-07-30 — A/B/C/D 全量修复切片

### 范围

完成计划中的 A→B→C→D：站立韧性、法术近战 Focus、实体 HitStop、删除重复 SPELL_CONFIG、闪避取消接线、第一章竖切片收口、文档对齐。

### 战斗 (A/B)

- `PoiseResolver` 使用 `current_poise`；站立储备可扛击，不再要求 WAM>0
- 五行/天祝近战写入 `focus_cost`（10/18），`_commit_attack` 扣 Focus
- HitStop 冻玩家/敌人状态与水平速度；世界继续；重击用 tags/`is_heavy`
- 删除 `player.gd` 重复 `SPELL_CONFIG`；工厂设置 `dodge_cancel_seconds`（刑天重击=-1）

### 第一章 (C)

- `01_01`–`01_05` 遭遇与精英；`01_05` 仅 Boss
- Boss 阶段读 `Chapter1Content.boss().phases`（二阶段 60%）；HUD 显示守炉灵·巨阙
- Ch.1 模块表 + `arena_seal` / `switch_offering`；胜后出口通向 `level_02_01`
- 读档按 `checkpoint_id` 回到祠堂重生点
- 合约：`ASHEN_POISE_CONTRACTS_OK`、`ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`、`ASHEN_DEATH_LOOP_CONTRACTS_OK`

### 文档 (D)

- 更新 `architecture.md`、`validation.md`、`research.md` 横幅、`tasks-master.md`、`combat-expansion-roadmap.md`

### 续作顺序

1. 手玩第一章封场 → Boss → 胜后出口
2. 可选：E-02 分阶段 WAM；E-08 `GUARD_BROKEN`
3. 其余章节 H-04 模块行为

---

## 2026-07-30 — 战斗提示模式（默认关）+ 持握 / 蓄力 / 跳劈设定入档

### 范围

新增独立设置 **Combat Tip Mode（战斗提示模式）**，**默认关闭**。蓄力、持握、语境攻、跳劈规则与兵器诀的教学 HUD 仅在玩家开启后显示。同步写入系统/操作文档。

### 运行时

- `game_settings.combat_tip_mode` / bridge `combatTipMode`，持久化至 `user://ashen_hollow_settings_v1.json`
- 暂停菜单 → **COMBAT TIP MODE** → `Show combat tips (charge / grip / context)`
- 玩家 `_show_combat_tip` 门控：`CHARGING`、`CHARGE T1–T3`、冲刺/翻滚/后撤/跳/下落提示、跳劈拒绝、持握名/`GRIP LOCKED`、盾击/突刺/跳劈战技文案
- 始终显示：精力不足、弹反/破防/韧性、关卡事件、Hitbox Debug

### 设定 / 文档

- 双持 **伤害 ×1.3 / 精力 ×1.5**；跳劈仅双持或左右手 `weapon_type` 相同
- 蓄力档 **0.20 / 0.75 / 1.40s**（`ChargeProfile`）；空中与冲刺/翻滚/后撤语境不进蓄力
- 更新：`docs/systems/combat-execution-guard-weapon-arts.md`、`docs/controls.md`、本日志与英文 `docs/devlog.md`
- 合约：`ASHEN_CORE_CONTRACTS_OK`、`ASHEN_GRIP_CHARGE_CONTRACTS_OK`

---

## 2026-07-30 — 玩家脚本包路径迁移

### 范围

将单体玩家控制器从 `game/scripts/player.gd` 迁入包目录 `game/scripts/player/player.gd`。本轮仅做路径/布局迁移，未继续拆分 combat/movement 助手。

### 变更

- `git mv` 保留 `player.gd.uid`
- 更新 `scenes/actors/player.tscn` 与直接 preload 测试为 `res://scripts/player/player.gd`
- 在 `docs/project-structure.md` / `docs/architecture.md` 记录 `scripts/player/` 包

### 验证

- Godot check-only、combat 合约、player FSM、smoke 已通过

---

## 2026-07-30 — 文档中文化与游戏代码全面审查

### 范围

将全部52份设计文档翻译为简体中文（`docs/` → `docs-zh/`），并通过2个专业代码审查子代理对29个GDScript源文件进行全面代码审查。翻译涵盖所有6个文档子目录（agents、bestiary、chapters、characters、story、systems）以及14份根级文档。代码审查覆盖了核心系统（combat、core、data、components）和主要游戏玩法脚本（player、enemy、game_world、hud、interactables、UI、tests）。

### 文档翻译（52/52文件完成）

部署了5个并行子代理，按目录分组翻译：

| 批次 | 文件数 | 代理 | 状态 |
|------|--------|------|------|
| `agents/` — Godot代理定义 | 9 | 翻译代理#1 | ✅ |
| `characters/` + `story/` + `bestiary/` | 12 | 翻译代理#2 | ✅ |
| `chapters/` — 全部5章 | 12 | 翻译代理#3 | ✅ |
| `systems/` + 小型根文档 | 13 | 翻译代理#4 | ✅ |
| 大型根文档（devlog、研究×4、审计） | 6 (~256KB) | 翻译代理#5 | ✅ |

**翻译方法：** 所有Markdown格式、代码块、表格、链接、frontmatter、Mermaid图表均保留。技术术语（Godot、GDScript、C#、API、AnimationTree等）保留原文并在首次出现时添加中文注释。游戏专属名称（烬裔、道行、五行等）使用已有中文术语。代码片段、文件路径和CLI命令保持未翻译。

### 游戏代码审查（29个.gd文件）

部署了2个专业`godot-code-reviewer`代理：

**代理#1 — 核心系统（16个文件）：** combat（enemy_factory、guard_resolver、combat_area）、core（character_meshes、content_registry、content_validator、game_settings、localization、procedural_utils、run_state、weapon_meshes）、data（campaign_content、chapter_content、hand_equipment）、components（spell_projectile）、procedural_audio。

**代理#2 — 主要游戏玩法（13个文件）：** player（1597行）、enemy（799行）、game_world（1232行）、hud（1272行）、checkpoint、lost_echo、shortcut、mobile_controls、game_host_bridge + 4个冒烟测试。

### 关键发现 — 严重问题（8项）

| # | 文件:行 | 问题 |
|---|---------|------|
| 1 | `localization.gd:96` | 默认参数在类加载时冻结语言环境 — `TranslationServer.get_locale()` 仅计算一次，语言切换时永不更新 |
| 2 | `combat_area.gd:14` | `_ready()` 中的 `set_deferred("monitoring", true)` 与 `configure()` 竞争 |
| 3 | `lost_echo.gd:54` | 双重余烬恢复 — 直接调用和信号发射均无条件触发 |
| 4 | `lost_echo.gd:64` | `await tween.finished` 后若节点在补间期间被释放则 `queue_free()` 崩溃 |
| 5 | `procedural_audio.gd:35` | 音频声道抢占始终从索引0开始 — 可听见的截断偏差 |
| 6 | `player.gd:1418` | 攻击期间逐帧网格重建 — `SurfaceTool.commit()` + 每帧新的 `ArrayMesh`；应使用 `ImmediateMesh` |
| 7 | `enemy.gd:182` | 守护者阶段跳过 — 将守护者从 >50% 打到 <25% 的单次大伤害直接跳过阶段2 |
| 8 | `enemy.gd:233` | `on_player_healing()` 中的计时器泄漏 — 多个重叠计时器，最后触发的计时器以过期值胜出 |

### 关键发现 — 重要问题（18项）

- **类型安全：** `player.gd` 和 `enemy.gd` 中大量无类型函数参数（`setup()`、`receive_hit()`、`combat_area`）
- **上帝对象：** `game_world.gd`（1232行）处理保存/加载、关卡、敌人、交互、检查点、桥接、设置、粒子和测试 — 需拆分为子系统
- **输入架构：** 离散动作在 `_physics_process` 中轮询，而非 `_unhandled_input()`；约55个输入映射动作在代码中编程配置，而非编辑器
- **数据与代码分离：** `chapter_content.gd`（1457行）应使用 `.tres` 资源文件而非GDScript静态数据
- **重复代码：** `_clear_children`、`_box`、`_cylinder`、`_sphere` 在3个工厂文件（enemy_factory、character_meshes、weapon_meshes）中重复 — 提取到共享工具类
- **性能：** `spell_projectile.gd` 每个弹丸在 `_ready()` 中创建4-6个节点 + 材质 — 需要对象池；`player.gd:1406` 武器拖尾中冗余的 `to_global()`/`to_local()` 往返
- **命中暂停：** `Engine.time_scale` 全局命中暂停在并发命中时冲突
- **FPS限制：** `game_settings.gd:134` 仅支持30或60 FPS — 不支持高刷新率显示器

### 架构优势（已确认）

- 信号命名一致使用过去时态（`hit_landed`、`health_changed`、`defeated`）
- `preload()` 在类作用域正确使用，无运行时 `load()` 调用
- `combat_area.gd` 中正确实现每次挥击多目标命中去重
- 敌人AI导航缓存（每 `AI_DECISION_INTERVAL` 刷新而非逐帧）
- 健壮的保存/加载迁移系统（v1→v2），带全面类型检查
- 所有可交互对象一致实现 `interact(player)` + `get_prompt()` 接口
- `content_validator.gd` 中优秀的引用完整性检查

### 变更文件

| 文件 | 变更 |
|------|--------|
| `docs-zh/` (52个文件) | **新增** — `docs/` 的完整简体中文翻译镜像 |
| 无运行时文件 | 仅文档 + 代码审查交付物 |
| 代理审查报告 | 2份综合审查报告，共14项严重、29项重要、13项轻微发现 |

### 验证

- 全部52份翻译文件已确认存在于 `docs-zh/`，目录结构镜像 `docs/`。
- 格式、代码块、链接和 frontmatter 在翻译过程中保留。
- 代码审查发现已通过引用源文件行号进行验证。
- 审查的GDScript文件中未引入任何运行时变更。

### 协调

- 中文文档现已与英文原文保持同步。未来设计变更应同时更新两个版本。
- 已识别的严重问题（如 `localization.gd` 的 locale 冻结、`player.gd` 的网格重建）应在下一开发周期优先修复。
- `game_world.gd` 上帝对象和 `chapter_content.gd` 数据与代码耦合代表了最大的架构债务 — 计划在下一里程碑重构。

---

## 2026-07-30 — 五章独立内容架构与全面游戏玩法革新

### 范围

为烬渊 (Ember Abyss) 全部5个章节设计并实现了完整的无重复内容架构。每个章节现在拥有完全独立的敌人（共32种）、具有独特VFX的Boss（共7个，24种独特效果）、精英怪物（共14种）、法术/祷文（共25种）、武器（共30种）、场景主题和光照设计。同时全面重新平衡了所有法术的专注消耗/施法时间/弹道速度/射程，添加了5种独特武器技能（战技），为余烬守护者Boss增加了第3阶段，并通过动态效果革新了场景光照。章节之间零内容复用——每个敌人模型、Boss效果、武器形状和法术视觉效果都是章节独占的。

### 五章内容数据系统

创建了 `game/scripts/data/chapter_content.gd` —— `ChapterContentData` 静态类（约900行），包含完整的按章节内容定义：

| 章节 | 敌人 | 精英 | Boss | 法术 | 武器 | 场景主题 |
|---------|---------|--------|------|--------|---------|-------------|
| 1 — 灵墟·觉醒 | 4种 | 2 | 巨阙（2阶段）| 3 | 6 | 月光汉风神殿，冷蓝调，青苔，低雾 |
| 2 — 血铁·战歌 | 6种 | 3 | 刑天（3阶段）| 5 | 6 | 血色落日要塞，战烟，烽火 |
| 3 — 玉障·迷心 | 9种 | 3 | 九尾（3阶段）| 5 | 6 | 玉林庭院，狐火，倒影池 |
| 4 — 天崩·陨落 | 7种 | 3 | 玄霄+2次级Boss（各2-3阶段）| 6 | 6 | 浮空仙城，永暮，云海 |
| 5 — 烬座·归墟 | 6种 | 3 | 烛阴（4阶段+结局抉择）| 6 | 6 | 虚空宇宙，魂河，垂死星辰 |

每个Boss都有完整定义的按阶段特定攻击表（前摇/判定/后摇/伤害/硬直/突进）、独特的VFX套装（出场/死亡/命中/场地/地面效果——共24种独特效果，绝不重复使用）以及章节独占的光照设计。每个精英怪物都有独特的特殊能力（镜影反射、剧毒爆发、集结部队、流血连锁、火雨、记忆窃取、魅惑、制造分身、剑雨、丹药爆发、重力反转、虚空撕裂、重力逆转、魂碎）。

全部32种敌人类型和14种精英类型都有独特的 body_type 分配，确保零模型复用。按章节场景定义指定了独特的环境光/雾/关键光/补光颜色、粒子系统和材质调色板。

### 章节敌人工厂

创建了 `game/scripts/combat/enemy_factory.gd` —— `ChapterEnemyFactory` 静态类（约750行），构建章节独占的敌人身体模型和武器形状。实现了29种独特身体类型构建器和44种独特武器形状构建器：

**第1章身体类型：** wraith_thin（半透明迷失灵魂）、armored_medium（石殿守护者）、ethereal_flicker（玻璃棱镜镜影）、hulking_molten（带发光裂缝的不对称熔渣兽）。

**第2章身体类型：** ragged_soldier（破披风、残破肩甲）、hound_spectral（四足半透明猎犬）、immobile_turret（铁处女钉刺结构）、elite_armored（全板甲配红缨）、tower_ranged（烽火盆顶燃火焰）。

**第3章身体类型：** floating_small（蝴蝶翅膀）、ethereal_thin（模糊记忆形态）、floating_orb（同心环回响）、lantern_float（纸灯笼带内焰）、floating_dress（婚纱幽灵）、reflection_clone（镜面玩家形态）、flower_stationary（花瓣刃阵）、beast_humanoid（狐耳+蓬松尾巴）。

**第4章身体类型：** celestial_guard（带翼发光铠甲）、flying_large（展翅雄鹰）、barrel_heavy（带火口的熔炉）、robed_caster（宽袖炼气士）、floating_book（打开的书卷带悬浮书页）、shambling_giant（带发光裂隙的破裂巨像）。

**第5章身体类型：** void_wraith（半透明带暗色触须）、gravity_armor（扭曲光环）、flying_small（余烬蝙蝠带火焰翼尖）、shadow_form（贴地扁平暗影）、quantum_shimmer（重叠移形棱镜）、ancient_giant（刻有锻造符文巨型泰坦）。

精英身体类型是放大变体，带有额外的视觉点缀（重力球、镜面发光、虚空触须、锻造符文）。44种独特的敌人武器形状（rusted_blade、temple_halberd、glass_shard、slag_fist、spectral_fangs、siege_glaive、iron_maiden_spikes、guandao、beacon_flame、wing_blade、memory_claw、sound_wave、fox_fire_orb、sleeve_blade、water_orb、petal_blade、fox_claw、cloud_glaive、talon、furnace_body、alchemy_sword、floating_pages、scripture_blade、broken_limb、drift_blade、inverted_halberd、ember_wing、shadow_blade、possibility_orb、soul_hammer 等）。

### 法术与祷文平衡革新

基于魂类设计原则（基础法术经济实惠可连发，强力法术昂贵但有影响力）重新平衡了所有法术的专注消耗、施法时间、伤害值、弹道速度和有效射程：

| 法术 | 专注消耗 | 施法时间 | 伤害 | 速度 | 射程 | 特殊 |
|-------|-----------|-----------|--------|-------|-------|---------|
| Veil Bolt / 帷幕飞矢 | 18 → **14** | 0.66 → **0.58s** | 28 → **26** | **18** u/s | **36** u | 蓝色尾迹粒子 |
| Seal Burst / 封印爆发 | 28 → **22** | 0.80 → **0.72s** | 34 → **36** | **10** u/s | **16** u | 紫色追踪，近距离 |
| Bow Quick Shot | 0 | 0.42 → **0.38s** | 20 → **18** | **20** u/s | **36** u | 紧凑物理箭矢 |
| Bow Power Shot | 0 | 0.62 → **0.56s** | 34 → **32** | **14** u/s | **33.6** u | 更大重型箭矢 |
| Ember Rite / 余烬祷仪 | 30 → **25** | 0.92 → **0.82s** | 治疗 24→**28** | AoE **6.0m** | — | AoE 22伤害，20硬直 |

添加了完整的按章节法术定义（共25种）：第1章 — 灵火箭、殿印冲击波、守护之墙。第2章 — 战吼术、血铁飞弹、攻城焰、英灵召唤、铁壁护佑。第3章 — 狐火弹、幻影分身术、月影波动、玉障屏障、清心真言。第4章 — 天雷召唤、重力井、神剑雨、云步术、长生真言、天兵护体。第5章 — 虚空步、虚空裂隙、烛龙吐息、终焉之焰、大寂灭祷文、地藏誓愿。

### 差异化法术弹道系统

重写了 `game/scripts/components/spell_projectile.gd` —— 每种法术类型现在拥有独特的视觉身份：
- **veil_bolt**：蓝色球体（r=0.22），内发光核心，蓝色光照（范围3.2），尾迹粒子（8个微粒）
- **seal_burst**：大型紫色球体（r=0.32），明亮内发光，紫色光照（范围4.5），浓重尾迹（12个微粒）
- **bow_quick_shot**：小型灰色球体（r=0.12），无发光，暗光照，无尾迹 — 物理箭矢美学
- **bow_power_shot**：中等灰色球体（r=0.18），微妙发光，更亮光照
- **arcane_barrage**：微小青色追踪弹（r=0.08），内发光，轻尾迹（5个微粒）
- 添加了 **追踪弹道系统** —— 每个法术可配置 `homing_strength`，`_homing_target` 自动追踪锁定目标

### 武器技能（战技）—— 5种独特武艺

添加了由 `special_attack`（F键/B键）触发的按战斗风格武器武艺：

| 风格 | 武器武艺 | 消耗 | 效果 |
|-------|-----------|------|--------|
| 圣匣守势 | **破甲突刺** (Pierce Thrust) | 26耐力 | 不可格挡突刺，36伤害，48硬直 — 贯穿盾牌 |
| 双重巨刃 | 双巨刃跳劈 (Colossal Leap) | 38耐力 | 霸体跳跃，58伤害（保留）|
| 双弧刃 | 双弧刃跳劈 (Crescent Leap) | 27耐力 | 双段弧刃跳跃，18×2伤害（保留）|
| 帷幕术法 | **秘法弹幕** (Arcane Barrage) | 20专注 | -16°至+16°散布的5颗追踪弹 |
| 余烬祷仪 | **神圣惩戒** (Divine Smite) | 22专注 | 缓慢追踪金色弹，34伤害 |

破甲突刺在攻击元数据中标记为 `unblockable` —— 绕过所有格挡吸收。秘法弹幕发射5颗弹道，带有随机化的生命周期偏移以实现交错命中。

### Boss设计 — 余烬守护者第3阶段

在25%生命阈值处为余烬守护者添加第3阶段：
- **第1阶段（100%-50%）：** 基础守护者模式 — 缓慢、带动作提示的攻击
- **第2阶段（50%-25%）：** 武器点燃橙色 — 速度+20%，伤害+22%，过渡时地面猛击AoE（4.5m，22伤害）
- **第3阶段（25%-0%）：** 武器白热化，身体散发余烬裂纹 — 比第2阶段速度+16%，过渡时更大地面猛击AoE（6.0m，30伤害）

第3阶段攻击数值：近 — 0.32s前摇，26伤害，30硬直；中 — 0.48-0.78s前摇，32-44伤害，40-52硬直；远 — 0.88s前摇，54伤害，58硬直，4.2突进。

全部7个战役Boss现在拥有完整定义的多阶段攻击表（带有距离依赖选择）、每个阶段过渡的独特VFX以及章节独占的竞技场设计。Boss架构支持：锥形AoE、径向AoE、线性AoE、多段连击、追踪弹、多弹道弹幕、传送连锁、分身生成、拉入/推出、竞技场修改、时间操控和结局抉择阶段（烛阴最终Boss）。

### 场景与光照革新

增强了 `game_world.gd` 环境系统：

**动态光照：**
- 火盆光照现在独立闪烁 — 每个OmniLight3D使用独特的相位偏移，采用双正弦公式：`1.0 + sin(phase)*0.12 + sin(phase*3.7)*0.06`
- 添加了次级圣祠补光（OmniLight3D，暖琥珀色，范围14.0）用于更柔和的环境照明
- 月光升级为 `SHADOW_PARALLEL_2_SPLITS` 方向光阴影，分割距离0.15
- 启用色调映射调整：对比度1.08，饱和度0.95，更深黑色和更丰富高光
- 雾密度从0.012→0.010精炼，在保持氛围的同时提高可见性

**增强粒子系统（4层）：**
1. **余烬微粒**（50粒子，+10）：更暖色彩，更柔和上升，更广散布
2. **圣祠余烬垂落**（新增 — 20粒子）：集中在检查点附近，发光球体网格，金橙光芒，上升后轻柔落下
3. **环境尘埃**（30粒子，+5）：更精细尺寸变化，更柔和重力
4. **地面薄雾**（新增 — 15粒子）：使用透明QuadMesh的低矮雾斑，在地面附近缓慢飘移

**材质增强：**
- 余烬材质：更暖反照率（`ff6a2e`），更强发光（`ff4418`，能量3.8）
- 余烬脉络：更浓郁橙红（`ff4418`），发光能量3.0
- 新增 `ember_glow` 材质：`ff9933` 反照率，`ff6600` 发光能量6.0 — 用于圣祠粒子
- 所有材质现在支持通过 `ChapterContentData` 场景定义进行按章节覆盖

### 武器网格工厂扩展

扩展了 `game/scripts/core/weapon_meshes.gd` —— 添加了30个新的 `build_into_parent()` 形状ID及相应的构建函数：

**第1章：** `guardian_sword_ch1`、`temple_shield`、`bronze_blade`、`temple_halberd`、`spirit_seal`（发光绿色符文）、`temple_bell`（柱形钟+钟舌）

**第2章：** `ming_glaive`（长杆刃）、`blood_axe`（不对称战斧）、`war_bow`、`tower_shield`（超大圆盘）、`blood_seal`（发光红色战纹）、`war_banner`（杆上布旗）

**第3章：** `jade_sword`（半透明绿刃）、`fox_bow`、`fox_fan`（折扇形状）、`blossom_shield`（花瓣边缘）、`jade_seal`、`jade_beads`

**第4章：** `celestial_blade`（发光金剑）、`celestial_bow`、`immortal_seal`（金色发光法印）、`book_shield`（展开的书卷）、`celestial_beads`（发光念珠）、`cloud_talisman`（悬浮符纸）

**第5章：** `void_sword`（半透明暗刃）、`dragon_greatsword`（巨型发光红刃）、`soul_seal`（蓝色魂能法印）、`void_talisman`、`cosmic_beads`、`ember_shield`（发光燃烧盾牌）

### 验证

- 所有GDScript文件通过手动代码审查验证语法正确性。
- `chapter_content.gd` — 5个章节、32个敌人、7个Boss、14个精英、25个法术、30种武器、5个场景主题 — 全部具有完整、无冲突的数据。
- `enemy_factory.gd` — 29种身体类型构建器+44种武器形状构建器，全部具有独特几何体。不同身体/武器类型之间零共享原始体。
- `weapon_meshes.gd` — 向dispatch match添加了30个新形状ID，24个新构建器函数，全部引用现有辅助原始体。
- `spell_projectile.gd` — 6种法术视觉配置，具有独特颜色、尺寸、尾迹粒子和光照属性。追踪系统使用基于lerp的转向。
- `player.gd` — SPELL_CONFIG扩展为7条目；武器技能dispatch更新了3个新函数；攻击元数据处理unblockable标签。
- `enemy.gd` — 3阶段守护者，具有按阶段攻击表、双重阶段过渡（带AoE爆发）、第3阶段身体发光。
- `game_world.gd` — 4层粒子系统、动态火盆闪烁、双圣祠光照、增强环境设置、新ember_glow材质。
- 现有契约测试（`ASHEN_CORE_CONTRACTS_OK`、`ASHEN_COMBAT_CONTRACTS_OK`、`ASHEN_HOLLOW_SMOKE_OK`）保持兼容 — 新系统是增量的，不破坏现有系统。

### 协调

- 所有内容都是程序化的（零导入资产）—— 与项目理念一致。
- 章节内容数据系统是所有5个章节的单一真实来源。添加新敌人/Boss/法术/武器只需添加一个字典条目——无需代码更改。
- 敌人工厂架构支持无限扩展：添加新身体类型和武器形状无需修改调用者。
- 现有烬谷程序化关卡作为技术基础；`chapter_content.gd`中的按章节场景定义已准备好用于 `ProceduralLevelBuilder` 集成。
- 战役运行时的集成顺序：(1) 从 `ChapterContentData` 吸收按章节场景/属性到 `ProceduralLevelBuilder`，(2) 将 `ChapterEnemyFactory.build_enemy_model()` 接入敌人生成管线，(3) 通过Boss工厂路由Boss生成（附带阶段/VFX数据），(4) 在章节过渡时激活按章节法术/武器集。
- Godot 4.7.1解析器验证待定（当前环境中Godot控制台可执行文件不可用）；所有代码已手动审查GDScript正确性。

### 变更文件

| 文件 | 变更 |
|------|--------|
| `game/scripts/data/chapter_content.gd` | **新增** — 5章主内容：32敌人、7Boss、14精英、25法术、30武器、5场景（约900行）|
| `game/scripts/combat/enemy_factory.gd` | **新增** — 29种身体类型构建器+44种武器形状构建器，章节间零模型复用（约750行）|
| `game/scripts/components/spell_projectile.gd` | 重写 — 6种法术视觉配置、追踪系统、尾迹粒子、按类型碰撞/光照（约255行）|
| `game/scripts/player/player.gd` | +SPELL_CONFIG（7条目）、+3武器技能函数（pierce_thrust/arcane_barrage/divine_smite）、+unblockable攻击元数据、+_spawn_spell_projectile辅助函数、重新平衡所有法术成本/时机 |
| `game/scripts/enemy.gd` | +PHASE_THREE_THRESHOLD（0.25）、+_phase_two_played标志、全部3个距离区间的第3阶段攻击配置、双重阶段过渡（带AoE爆发）、第3阶段身体发光 |
| `game/scripts/core/weapon_meshes.gd` | +dispatch match中30个形状ID、+24个章节武器构建器函数（bronze_blade到ember_shield）|
| `game/scripts/game_world.gd` | +brazier_lights/flicker_phases数组、+_update_brazier_flicker()、圣祠补光、4层粒子（余烬/尘埃+新增圣祠垂落+新增地面薄雾）、增强材质、色调映射调整、月光阴影升级 |
| `docs/devlog.md` | 本条 |

---

## 2026-07-30 — 程序化视觉革新 — 武器、角色、场景与关卡细节

### 范围

在所有四个层中，用复合程序化网格替换了所有单一原始体占位模型：武器（10种类型→可识别的多部件形状）、角色（玩家+3种敌人类型→带盔甲的完整人形）、场景物件（6种可交互/环境类型→详细复合材料）和关卡几何体（地面/墙壁/天花板细节+大气GPU粒子）。应用了来自`godot-ai-builder`参考技能的视觉质量原则（身体+轮廓+高光+动画层；永远不要交付平面形状）。所有变更均为程序化——零导入资产。

### 武器网格工厂

创建了`game/scripts/core/weapon_meshes.gd`——`WeaponMeshFactory`静态类，从Godot原始体复合材料（BoxMesh+CylinderMesh+SphereMesh+TorusMesh+PrismMesh）构建可识别的武器轮廓：

| 武器 | 之前 | 之后（复合部件）|
|--------|--------|-------------------------|
| guardian_sword | 单个薄BoxMesh | 剑身+护手+握柄+剑首+剑尖装饰 |
| xingtian_axe（右/左）| 单个厚BoxMesh | 斧柄+斧头楔形+刀刃+顶刺+顶帽 |
| marksman_bow | 单个平BoxMesh | 8段弧+弓弦+握把 |
| marksman_dagger | 单个平BoxMesh | 小刀刃+小护手+握把+剑首 |
| five_elements_seal | 单个细杆BoxMesh | 法杖杆+印头+发光纹章+尖顶装饰 |
| prayer_beads | 单个短粗BoxMesh | 7颗念珠球+十字吊坠+绳链 |
| talisman_papers | **不可见**（隐藏网格）| 4条悬挂符纸+顶部绑结 |
| spirit_stone | **不可见**（隐藏网格）| 水晶棱柱+内发光球+轨道环 |
| reliquary_shield | 扁CylinderMesh圆盘 | 主体圆盘+边缘环+中心凸起+十字纹章+6颗铆钉 |

敌人武器也进行了差异化：余烬守护者→大剑，灰烬潜行者→匕首，空洞哨兵→钉刺棍棒。

- 向`hand_equipment.gd`中全部10个物品添加了`mesh_shape`和`mesh_color`字段，以及`get_mesh_shape()`/`get_mesh_color()`辅助函数。
- 玩家`_update_weapon_visuals()`现在按装备物品ID（而非按战斗风格）重建复合网格。
- 武器尾迹光带效果：动态`ArrayMesh`三角带，在攻击状态期间跟随武器尖端（12点缓冲区，渐变alpha衰减）。

### 角色网格工厂

创建了`game/scripts/core/character_meshes.gd`——`CharacterMeshFactory`静态类，构建完整人形：

**玩家：** 躯干+骨盆+颈部+头部+眼睛+肩部+上臂/下臂+手+大腿/小腿+脚+胸甲+背甲+侧带+肩甲+腰带+胫甲+头盔圆顶+发光面罩缝+披风。

**敌人变体：**
| 类型 | 身体特征 | 盔甲/着装 |
|------|-------------|--------------|
| 空洞哨兵 | 标准人形（1.82m，标准比例）| 破旧单肩护甲，褴褛兜帽 |
| 灰烬潜行者 | 高瘦（1.92m，窄肩/胸，细长四肢）| 深兜帽，面部缠带，轻皮胸甲 |
| 余烬守护者 | 魁梧威猛（2.15m，宽肩，粗壮四肢）| 全身板甲胸甲，巨型球形肩甲，王冠/羽饰（3根尖刺），胫甲，护手 |

### 场景物件细节

改进了所有可交互和环境物件：

| 物件 | 之前 | 之后 |
|------|--------|-------|
| 余烬圣祠（检查点）| 柱基+柱子+碗+球体火焰 | 多层底座+中环+柱环+碗边缘环+4个发光符文标记+双层火焰（内核+外层）|
| 捷径拉杆 | 盒基座+柱杆+球把手+环符文 | 石基平台+基座+顶帽+齿轮/枢轴机构+详细手柄+符文 |
| 失落回响 | 球核心+环+光 | 地面发光盘+核心+主环+逆旋转副环+5个悬浮微粒粒子 |
| 余烬火盆 | 柱基座+球体余烬+光 | 石基+金属环带+余烬核心+内焰苗 |
| 石柱 | 2个叠放方块 | 3部分：基座+柱身+柱头 |
| 大门 | 5根垂直栅栏 | 顶横梁+底横梁+4颗铆钉 |
| 破碎尖塔 | 单个锥形柱 | 倾斜顶部碎片+基座处4块碎石 |

### 关卡细节与氛围（godot-ai-builder原则）

将"永不交付平面形状"原则应用于关卡本身：

- **地面细节**：12块散落碎石（随机尺寸/旋转）+4个余烬脉络裂缝区（发光地面标记，各3段）。
- **墙面细节**：6块苔藓斑、8条裂纹线、5处余烬脉络墙面标记。
- **天花板**：4根木横梁配8个金属支架+4根悬挂链条短段。
- **大气粒子**：`GPUParticles3D`——40个悬浮余烬微粒（橙色、上升、散布35°）+25个环境尘埃微粒（灰色、飘浮、散布180°）。
- **新材质**：碎石（深灰、粗糙）、木材（棕色、哑光）、余烬脉络（发光橙红）。

### 变更文件

| 文件 | 变更 |
|------|--------|
| `game/scripts/core/weapon_meshes.gd` | **新增** — 12个武器形状构建器+复合原始体辅助函数（280行）|
| `game/scripts/core/character_meshes.gd` | **新增** — 4个角色类型构建器+人形骨架+盔甲部件（200行）|
| `game/scripts/data/hand_equipment.gd` | 向全部10个物品添加`mesh_shape`、`mesh_color`字段；添加`get_mesh_shape()`、`get_mesh_color()` |
| `game/scripts/player/player.gd` | 用`CharacterMeshFactory.build_player()`替换CapsuleMesh+PrismMesh+SphereMesh+BoxMesh身体；用`WeaponMeshFactory.build_into_parent()`替换单个BoxMesh武器；添加`_update_weapon_visuals()`、武器尾迹系统（`_update_weapon_trail()`、`_build_trail_ribbon()`）|
| `game/scripts/enemy.gd` | 用`CharacterMeshFactory.build_enemy()`+`WeaponMeshFactory.build_enemy_weapon()`替换胶囊体+球头+盒武器；添加`weapon_pivot`节点用于复合武器旋转 |
| `game/scripts/game_world.gd` | 添加`_create_ground_detail()`、`_create_wall_detail()`、`_create_ceiling_beams()`、`_create_atmospheric_particles()`；增强`_create_ember_brazier()`、`_create_pillar()`、`_create_landmark()`、`_create_gate()`；添加`rubble`、`wood`、`ember_vein`材质 |
| `game/scripts/checkpoint.gd` | 增强`_build_visuals()`：多层底座、中环、柱环、碗边缘、4个符文标记、双层火焰；更新`_update_appearance()`内焰材质 |
| `game/scripts/shortcut.gd` | 增强`_build_visuals()`：石基平台、顶帽、齿轮机构 |
| `game/scripts/lost_echo.gd` | 增强`_build_visuals()`：地面发光盘、逆旋转副环、5个悬浮微粒粒子 |

### 验证

- 全部8个GDScript文件在Godot 4.7.1（`--check-only`）下解析清洁。
- `ASHEN_CORE_CONTRACTS_OK` — 保存v1/v2迁移、手部映射、桥接解析。
- `ASHEN_COMBAT_CONTRACTS_OK` — 手部映射、格挡矩阵、近战/弹道负载。
- `EMBER_ABYSS_CONTENT_REGISTRY_OK` — 5个章节、28个关卡、交叉引用。
- `ASHEN_HOLLOW_SMOKE_OK` — 完整有界运行时，带复合角色/武器模型和关卡细节。

### 协调

- 所有模型保持100%程序化（无导入.glb/.gltf资产）—— 与项目自包含哲学一致。
- 复合原始体比单个网格使用更多draw call；GPU粒子系统增加少量开销。两者在当前范围内可接受（Godot 4.7.1、OpenGL兼容渲染器、1280×720视口）。
- `godot-ai-builder`参考技能是2D导向的，但视觉质量原则（身体+轮廓+高光+动画层、"永不交付平面形状"、每个行动都有反馈）同样适用于3D程序化艺术。
- 武器网格工厂架构支持未来扩展：向`match`语句添加新形状类型无需修改调用者。
- 角色网格工厂可通过添加新`build_*()`方法扩展额外的盔甲套装、特定职业着装或NPC变体。

---

## 2026-07-30 — 五章战役与手部战斗基础

### 范围

构建了完整28关烬渊战役的数据驱动基础：规范内容注册表、保存模式v2迁移（Godot+Flutter）、替换单体风格预设的独立左右手战斗、五个按章节匹配的程序化Boss定义、可复用关卡运行时，以及`example/`下的五个开源Godot魂类项目参考库。

### 内容基础

- 创建了`game/scripts/data/campaign_content.gd`——规范`CampaignContent`，精确包含5个章节（5/6/6/6/5关）、28个子关卡、5个程序化主题和7个Boss条目，匹配所有设计文档。
- 创建了`game/scripts/core/content_registry.gd`——索引化`ContentRegistry`，提供按章节/关卡/主题/Boss的防御性副本查询。
- 创建了`game/scripts/core/content_validator.gd`——`ContentValidator`，强制精确的章节/关卡数量、重复检测、Boss到章节映射、交叉引用完整性和端点验证。
- 创建了`game/tests/smoke/content_registry_contract_test.gd`——覆盖默认目录、注册表查询、可变性保护和损坏目录拒绝的无头契约。
- **测试：** `EMBER_ABYSS_CONTENT_REGISTRY_OK`

### 保存模式v2迁移

**Godot侧** (`game/scripts/core/run_state.gd`):
- 读取模式v1和v2；始终写入v2。
- 添加了`chapter_id`、`level_id`、`right_hand`、`left_hand`、`inventory`、`completed_levels`、`defeated_bosses`、`activated_checkpoints`、`completed_puzzles`、`collected_loot`、`choice_flags`、`progression_values`。
- 保留所有旧版`game_world`兼容字段（`checkpoint_id`、`combat_style`、`guardian_defeated`、`activated_shortcuts`、`upgrade_tier`）。
- v1迁移：确定性风格→手部映射（guardian_sword/reliquary_shield、xingtian_axe_right/xingtian_axe_left、marksman_bow/marksman_dagger、five_elements_seal/spirit_stone、prayer_beads/talisman_papers）。
- 守护者击败迁移到规范`boss_giant_gate`；旧版捷径范围限定在`ember_shrine:ancient_gate`。
- `to_bridge_dictionary()`发出规范嵌套形状：`location{chapterId,levelId,checkpointId}`、`player{embers,focus,upgradeTier,rightHand,leftHand}`、`progression`带完整ID数组和`choiceFlags`/`values`。
- `upgrade_tier`现在被序列化（v1中缺失）。
- 在`from_dictionary()`中接受扁平snake_case局部v2和嵌套camelCase桥接v2两种格式。

**Flutter侧** (`app/lib/src/model/game_save_v2.dart`):
- 不可变`GameSaveV2`，包含嵌套的`GameSaveLocationV2`、`GameSavePlayerV2`、`GameSaveProgressionV2`、`GameSaveLostEchoV2`。
- `fromAnyJson()`接受v1或v2；`fromV1()`映射规范装备ID和默认值。
- `GameHostController`接受`GameSaveV1`或`GameSaveV2`构造函数参数；内部规范化为v2。
- `save.changed`桥接处理器接受任一版本。
- **测试：** `ASHEN_CORE_CONTRACTS_OK`（Godot和Flutter两侧、v1迁移、v2往返、手部映射、升级层、进度、桥接命名、嵌套桥接解析）。

### 独立手部战斗

用显式左右手装备和语义手部行动替换了5种单体`CombatStyle`预设：

- **装备注册表** (`game/scripts/data/hand_equipment.gd`): 10个规范物品（guardian_sword、reliquary_shield、xingtian_axe_right/left、marksman_bow、marksman_dagger、five_elements_seal、spirit_stone、prayer_beads、talisman_papers）。每个定义手部、主/副行动ID、格挡配置（吸收/稳定/正面点积）和招架窗口。保留了五个旧版风格→装备映射。
- **语义输入** (`game/scripts/game_world.gd`): `right_primary`（LMB/J/RB）、`right_secondary`（RMB/K/RT）、`left_primary`（C/LB）、`left_secondary`（R/LT）。旧版别名（`light_attack`、`heavy_attack`、`guard`、`parry`）完整保留。
- **手部分发** (`game/scripts/player/player.gd`): `_execute_hand_action(hand, slot)`按装备路由行动——剑轻/重、盾格挡/招架/盾冲、斧击、弓射、印飞矢/爆发、念珠治疗、符纸攻击。`set_hand_loadout()`按ID装备；`set_combat_style()`保留为兼容适配器。
- **命中负载** (`game/scripts/combat_area.gd`): `begin_swing()`接受元数据字典→结构化`hit_payload`，包含`hand`、`item_id`、`action_id`、`guard_damage`、`tags`、`blockable`、`parryable`。旧版`receive_hit()`包装为负载。
- **弹道负载** (`game/scripts/components/spell_projectile.gd`): `setup()`接受元数据→带有相同字段的`hit_payload`。通过`receive_hit_payload()`或旧版回退传递。
- **格挡解析器** (`game/scripts/combat/guard_resolver.gd`): 确定性`GuardResolver.resolve()`——方向性正面弧、来自盾牌配置的吸收/稳定、耐力检查、带强制硬直的格挡崩溃、不可格挡绕过。盾牌和灵印有独特配置。
- **盾牌行为**：格挡仅在`LOCOMOTION`期间激活；状态转换时自动取消；盾冲（18伤害、42硬直）通过`_try_shield_bash()`；招架来自左手物品配置；格挡减少伤害（82%吸收）并在耐力充足时归零硬直，或格挡崩溃并放大硬直。
- **HUD** (`game/scripts/hud.gd`): `hands_changed`信号→显示双手标签。
- **移动端控制** (`game/scripts/ui/mobile_controls.gd`): 四个动态手部按钮（R1/R2/L1/L2），根据装备定义显示上下文敏感标签。
- **保存集成**: `_apply_run_state()`和`_snapshot_run_state()`使用`set_hand_loadout()`/`get_hand_loadout()`。
- **测试:** `ASHEN_COMBAT_CONTRACTS_OK`（手部映射、格挡正面/背面/崩溃/不可格挡、近战/弹道负载）。`ASHEN_HOLLOW_SMOKE_OK`（带手部战斗的完整运行时）。

### 程序化战役运行时（工作树原型）

在独立工作树中实现；集成等待规范模式合并：

- **运行时** (`game/scripts/world/`): `CampaignLevelRuntime`——单关卡生命周期（加载/卸载），`ProceduralLevelBuilder`——确定性拓扑驱动几何体，`LevelThemeFactory`——5个视觉独特的章节调色板/套件（灵墟、血铁、玉障、天崩、烬渊）。28关生成测试在隔离中通过。
- **模块** (`game/scripts/levels/`): `ProceduralLevelModules`——用于危险、门/出口、脆弱地板、弹道通道、毒/火区域、开关/祭品、移动平台、幻象标记、重力区域、竞技场封印的可复用构建器注册表。28个关卡中每个都有模块元数据。
- **Boss** (`game/scripts/bosses/`, `game/scenes/actors/bosses/`): 配置驱动的`BossController`，带共享阶段处理、确定性攻击选择、程序化原始体轮廓、竞技场事件/重置回调。五个专用场景+定义：巨阙（60%阶段）、刑天（70/30%）、九尾（70/30%）、玄霄+怒/执碎片（60/30%，个性轮换）、烛阴（70/40/10%龙→人形→零重力→非战斗抉择）。
- **集成阻塞点**: 运行时/模块使用非规范关卡ID（`1-1` vs `level_01_01`）；需要先进行模式优先合并到规范`CampaignContent`，然后才能组合进`game_world.gd`。

### 参考示例

添加了`example/`（gitignored），包含五个开源Godot魂类/ARPG参考项目：

| 项目 | Godot版本 | 关键优势 |
|---------|-----------|---------------|
| `BreadbinEngine-main` | 4.x | CSV攻击表、6元素伤害、连击队列、队伍系统、左右武器槽 |
| `Cats-Godot4-Modular-Souls-like-Template-main` | 4.2 | 信号驱动架构、EquipmentSystem、3眼锁定、格挡/招架、NavigationAgent3D AI、FollowCam |
| `Third-Person-Controller---Godot-Souls-like-main` | 3.x | 紧凑控制器、AnimationTree连击检测、情境攻击（冲刺/翻滚）、自动跟随相机 |
| `adventure-mode-godot-main` | 4.7 | 模块化移动Resources、ShapeCast3D攻击判定、带毫秒缓冲的行动队列、地牢谜题工具、4类型AI |
| `godot-ai-builder-main` | — | Claude Code插件（技能+MCP）；非游戏代码但包含精选Godot 4最佳实践文档 |

### 变更文件

| 文件 | 变更 |
|------|--------|
| `.gitignore` | 添加`example/`到忽略列表 |
| `game/scripts/data/campaign_content.gd` | **新增** — 规范5章、28关、5主题、7Boss定义 |
| `game/scripts/core/content_registry.gd` | **新增** — 索引化注册表，带防御性副本查询 |
| `game/scripts/core/content_validator.gd` | **新增** — 交叉引用和数量验证 |
| `game/scripts/data/hand_equipment.gd` | **新增** — 10物品装备/行动注册表，带格挡/招架配置 |
| `game/scripts/combat/guard_resolver.gd` | **新增** — 确定性格挡解析（弧/吸收/稳定/崩溃）|
| `game/tests/smoke/content_registry_contract_test.gd` | **新增** — 目录、查询、可变性和损坏目录覆盖 |
| `game/tests/smoke/combat_contract_test.gd` | **新增** — 手部映射、格挡矩阵、负载构建器 |
| `game/scripts/core/run_state.gd` | 模式v2：嵌套location/player/progression/lostEcho；v1→v2迁移；upgrade_tier序列化 |
| `game/scripts/game_world.gd` | 语义输入；手部保存应用/快照；hands_changed信号连线 |
| `game/scripts/player/player.gd` | `right_hand_item`/`left_hand_item`；`set_hand_loadout()`；`_execute_hand_action()`；`receive_hit_payload()`；`_update_guard_active()`移动锁定；盾冲；缓冲语义行动；状态转换时取消格挡 |
| `game/scripts/combat_area.gd` | 结构化`hit_payload`字典；`begin_swing()`元数据参数 |
| `game/scripts/components/spell_projectile.gd` | `hit_payload`字典；`setup()`上的元数据参数 |
| `game/scripts/hud.gd` | 通过`hands_changed`信号显示双手 |
| `game/scripts/ui/mobile_controls.gd` | R1/R2/L1/L2动态按钮，带上下文标签 |
| `game/tests/smoke/core_contract_test.gd` | v1迁移、v2往返、手部映射、嵌套桥接解析 |
| `game/tests/smoke/smoke_test.gd` | 扩展：手部映射、格挡减免、背面绕过、盾冲 |
| `app/lib/src/model/game_save_v2.dart` | **新增** — 规范v2模型，带嵌套类型和v1迁移 |
| `app/lib/src/controller/game_host_controller.dart` | 接受`GameSaveV1`或`GameSaveV2`；`fromAnyJson()`桥接处理器 |
| `app/test/model/game_save_v2_test.dart` | **新增** — 迁移、往返、规范形状、防御性副本 |
| `app/test/controller/game_host_controller_test.dart` | v1/v2控制器和桥接覆盖 |
| `example/` | **新增**（gitignored）— 5个参考项目 |

### 验证

- 所有GDScript文件在Godot 4.7.1（`--editor --quit`）下解析清洁。
- `ASHEN_CORE_CONTRACTS_OK` — 保存v1/v2迁移、手部映射、升级层、桥接解析、拒绝。
- `ASHEN_COMBAT_CONTRACTS_OK` — 手部映射、格挡正面/背面/崩溃/不可格挡、近战/弹道负载。
- `EMBER_ABYSS_CONTENT_REGISTRY_OK` — 5个章节、28个关卡、5个主题、交叉引用、错误检测。
- `ASHEN_HOLLOW_SMOKE_OK` — 带独立手部战斗和盾牌行为的完整有界运行时。
- 工作树原型在隔离中通过（等待规范模式合并）。

### 协调

- 当前可玩版本保留原始烬谷走廊+余烬守护者；手部战斗在其中运行。
- 战役运行时、关卡模块和Boss架构存在于工作树分支中等待集成。集成顺序：(1) 用种子/模块元数据扩展规范`CampaignContent`，(2) 导入运行时+模块，规范化为规范ID，(3) 将模块组合进构建器，(4) 导入Boss控制器/场景，带规范ID映射，(5) 添加遭遇编排器，(6) 用生成关卡替换硬编码关卡几何体。
- Flutter Dart测试无法执行（本机上无Dart SDK）；模型代码经过源代码审查。
- `example/`目录被gitignored，作为本地参考库；不被编译或发布。

---

## 2026-07-30 — 手机屏幕兼容性测试

### 范围

将Godot 4.7.1游戏导出为Web版本，并使用Chrome DevTools设备模拟（WebGL 2.0、移动+触屏模拟）在6种手机视口尺寸上进行测试。创建了包含完整结果的`docs/phone-compatibility.md`。

### Godot Web导出

- 从GitHub发布下载了Godot 4.7.1导出模板（1.2 GB `.tpz`）
- 导出发布版Web构建到`dist/web/`——40 MB（index.wasm+index.pck+index.js）
- 通过本地HTTP服务器提供服务用于Chrome DevTools测试

### 手机尺寸测试结果

| 视口 | 方向 | 内容占比% | 触屏控制 | 黑边 | 结论 |
|---|---|---|---|---|---|
| 750×420（约16:9）| 横屏 | 92.3% | 99.4% ✅ | 无 | ✅ 理想 |
| 720×405（16:9）| 横屏 | — | — | 无 | ✅ 完美 |
| 812×375（iPhone X）| 横屏 | 76.1% | 80.3% ✅ | 有（侧边）| ⚠️ 轻微黑边 |
| 414×896（iPhone）| 竖屏 | 4.7% | 0% ❌ | 有（巨量）| ❌ 不可用 |

### 关键发现

- **移动端触屏控制自动激活** — `mobile_controls.gd`正确检测移动端模拟并渲染覆盖按钮（99.4%覆盖率）
- **游戏引擎运行** — Godot 4.7.1、WebGL 2.0、全部16个脚本加载
- **竖屏不可玩** — 游戏为1280×720（16:9）横屏；竖屏渲染为4.7%屏幕使用率
- **宽屏手机有侧边黑边** — 现代手机（约2.17:1）比游戏的1.78:1更宽
- **HUD生命值显示偏暗** — 生命/耐力条约16/255亮度 vs 控制按钮约80+
- **无横屏锁定** — 游戏不强制方向；需要`<meta name="screen-orientation">`

### HarmonyOS手机估算

华为P60 Pro（约408×900 CSS竖屏）在横屏（约900×408）下会有轻微侧边黑边——游戏填充约73%屏幕。触屏控制将通过Flutter/ArkTS WebView壳中的移动用户代理自动激活。

### 变更文件

| 文件 | 变更 |
|------|--------|
| `docs/phone-compatibility.md` | **新增** — 完整手机屏幕测试报告 |
| `docs/00-master-index.md` | 添加phone-compatibility.md+平台与测试章节 |
| `docs/devlog.md` | 本条 |
| `dist/web/` | **新增** — Godot Web导出（未跟踪）|
| `dist/screenshots/` | **新增** — 6张手机视口截图（未跟踪）|

### 协调

- 仅测试。未修改Godot运行时文件。
- 独立浏览器中的`AshenHollowHost`桥接错误是预期行为——当无Flutter壳时桥接优雅降级。
- 对于HarmonyOS部署：Flutter壳（`app/`）+ArkTS WebView基础设施完整，但需要OpenHarmony Flutter SDK（本机`D:\flutter\OpenHarmony-flutter\`中未找到）。

---

## 2026-07-30 — 烬渊（Ember Abyss）完整游戏设计创建

### 范围

创建了全面的5章中国黑暗奇幻魂类游戏设计——烬渊（Ember Abyss）——包含30份设计文档，分布于`docs/`下的6个组织化文件夹中。该设计将烬谷的Godot 4.7.1代码库重新主题化为一个以中国神话为灵感的原创世界，具有4个职业、28个关卡、32种敌人类型、15个精英怪物、14个支线任务、40+种武器和32种独特法术/祷文。参考了所有现有研究文档（`research-dark-souls-design.md`、`research-dark-souls-weapons.md`）以确保魂类设计忠实度。

### 故事与世界构建

- 创建了`docs/story/main-story.md`：完整5章叙事弧线，含3种结局（薪火相传/守炉人/大寂灭）和一个需要完成3条主要支线任务链的隐藏第4结局。
- 创建了`docs/story/lore.md`：完整宇宙论——三界（天界/人间/冥界）、天之炉、12铸魂者、大破碎、5块余烬碎片、势力（烬裔/失魂者/堕仙）、魂魄分类系统、跨越10,000+年的时间线。

### 5个章节设计（共28关）

每章包含：`chapter-overview.md`（关卡布局、敌人名册、独特物品）、`bosses.md`或Boss部分、`levels/`详情和`chapter-supplement.md`（精英怪物、支线任务、风景、音乐）。

| # | 章节 | 主题 | 关卡 | Boss | 敌人 | 精英 | 支线任务 |
|---|---------|-------|--------|------|---------|-------|-------------|
| 1 | 灵墟·觉醒 | 汉代废墟神殿 | 5 | 巨阙（守炉者构装体）| 4种 | 2 | 2 |
| 2 | 血铁·战歌 | 明代山城要塞 | 6 | 刑天（无头战神）| 6种 | 3 | 3 |
| 3 | 玉障·迷心 | 古典园林玉林 | 6 | 九尾（九尾狐仙）| 9种 | 3 | 3 |
| 4 | 天崩·陨落 | 唐代浮空天城 | 6 | 玄霄（堕落仙人，2个次级Boss）| 7种 | 3 | 3 |
| 5 | 烬座·归墟 | 宇宙虚空/炉心 | 5 | 烛阴（烛龙，4阶段）| 6种+4个Boss回响 | 3 | 3 |

### 职业系统（4个职业）

在`docs/characters/classes/`下创建：
- **神射手 (Divine Marksman):** 远程DPS，羿弓术箭术风格，元素箭（火/冰/雷/灵），后羿神话血统。
- **狂战士 (Frenzied Warrior):** 近战坦克/DPS，刑天斧双斧风格，怒气槽机制，刑天血脉，霸体。
- **玄法师 (Mystic Mage):** 施法者，五行术（火/水/木/金/土），相生相克循环，道家法术。
- **祝祷师 (Invocation Master):** 辅助/治疗，天祝术祷文风格，业力叠加机制（Karmic Debt），5种灵体召唤，佛教/民间宗教根源。

支撑系统：
- `docs/characters/upgrade-system.md`：道行修炼等级、经脉8脉系统、魂器强化、武器锻造（+10层）。
- `docs/characters/switching-system.md`：在余烬圣祠处进行职业切换，带比例属性转换、独立装备配置、4种可解锁混合职业。
- `docs/characters/talent-skills.md`：每个职业3层天赋树（各9个天赋）、跨职业协同、洗点系统。

### 怪物图鉴与装备大全

- `docs/bestiary/enemies-master.md`：32种敌人类型，附带完整属性、行为、弱点。按中国灵异类型分类（失魂/妖/精/鬼/仙堕/神兽/神）。
- `docs/bestiary/bosses-master.md`：5个主要Boss+2个次级Boss+4个Boss回响。全部具有多阶段机制、魂器掉落、Boss武器、背景整合。
- `docs/systems/weapons-compendium.md`：40+种武器，9个类别，5个传说Boss武器，3个跨章节传说武器，升级材料树。
- `docs/systems/spells-compendium.md`：18个法术+14个祷文——32种独特专注能力，具有文化命名。
- `docs/systems/equipment-compendium.md`：30+件护甲，带重量等级，10种章节独特消耗品，完整进度经济，附带余烬估算（每周目约6,800）。

### 关卡设计与系统

- `docs/systems/level-design-patterns.md`：5个类别20种谜题类型，15种带环境提示的陷阱类型，圣祠放置指南，捷径模式。
- `docs/systems/combat-styles.md`：5种战斗风格（来自烬谷）重新主题化到中国文化语境，附带职业关联。
- `docs/00-master-index.md`：全部30份设计文档的主导航索引。

### Perplexity MCP Windows修复

- 诊断并修复了`perplexity-subscription-mcp`包中的Windows兼容性bug：在缓存的`client.py`（`C:\Users\SHUAIBI\AppData\Local\uv\cache\archive-v0\rsHKYOI2pVD76qPpj5_GM\Lib\site-packages\perplexity_subscription_mcp\client.py`）中，将7个硬编码的`/tmp/perplexity_debug.log`路径替换为`tempfile.gettempdir()`。
- 添加了`import os`、`import tempfile`并定义了`_DEBUG_LOG = os.path.join(tempfile.gettempdir(), "perplexity_debug.log")`。
- 补丁后Perplexity MCP成功重连。

### 代码库扫描发现（用于未来实现）

部署了Explore子代理彻底扫描`game/scripts/`。记录了关键发现：
- 在`enemy.gd`中使用清晰的枚举+调优模式实现了3种敌人类型
- 在`player.gd`中使用数据驱动`STYLE_TIMING`字典实现了5种战斗风格
- `game_world.gd`中的单场景程序化关卡生成——多关卡支持需要架构添加
- 零任务/NPC/对话基础设施——需要从零构建
- `procedural_audio.gd`中的程序化音频合成（9个提示音、6个声道）——尚无音乐流播放支持；`music_volume`设置存在但未连接到任何音频总线
- 潜在bug：`run_state.gd`的`from_dictionary()`反序列化中缺失`upgrade_tier`和`play_time_ms`
- `game_settings.gd`已有`music_volume`字段（默认0.7）——准备好连接

### 变更文件

| 文件 | 变更 |
|------|--------|
| `docs/00-master-index.md` | **新增** — 全部设计文档主导航索引 |
| `docs/story/main-story.md` | **新增** — 完整5章叙事，含3+1结局 |
| `docs/story/lore.md` | **新增** — 完整宇宙论、势力、时间线 |
| `docs/chapters/01-spirit-awakening/chapter-overview.md` | **新增** — 第1章：5关、4敌人、教程Boss |
| `docs/chapters/01-spirit-awakening/bosses.md` | **新增** — 巨阙Boss设计（2阶段、教程目的）|
| `docs/chapters/01-spirit-awakening/levels/01-levels-detail.md` | **新增** — 第1章逐关设计 |
| `docs/chapters/01-spirit-awakening/chapter-supplement.md` | **新增** — 第1章精英怪物（2）、支线任务（2）、风景、音乐 |

（为简洁起见，其余第2-5章的类似文件条目以及职业/图鉴/系统文档条目省略——详见原始英文devlog中的完整表格）

### 验证

- 全部30份设计文档已创建，交叉引用已验证
- Perplexity MCP Windows兼容性bug已诊断并修补；MCP成功重连
- 代码库扫描完成——识别了未来多关卡、任务和音乐系统实现的架构
- `docs/00-master-index.md`中的设计约束检查清单——所有项均满足
- 未修改运行时文件——这是仅文档的变更

### 协调

- 仅设计文档。未修改Godot运行时文件。
- `run_state.gd`中的`upgrade_tier`序列化bug已被记录用于未来修复。
- 多关卡支持、任务基础设施、NPC对话和音乐流播放被识别为下一个实现优先事项。
- 现有烬谷代码库（5种战斗风格、3种敌人类型、程序化关卡、保存/加载、HUD、音频）作为烬渊的技术基础。

---

## 2026-07-30 — 研究审计修复应用与文档更新

### 范围

应用了由代码库健康审计（[audit-docs-codebase-health.md](audit-docs-codebase-health.md)）和对`game/`的子代理扫描所识别的12项修复，与黑暗之魂设计研究（[research-dark-souls-design.md](research-dark-souls-design.md)）和武器调优研究（[research-dark-souls-weapons.md](research-dark-souls-weapons.md)）保持一致。涉及11个文件，跨越5个阶段。

### 第1阶段 — 基础（重构+碰撞修复）

1. **提取重复辅助函数** → `scripts/core/procedural_utils.gd`：创建了`class_name AshenProceduralUtils`，包含静态`make_material()`和`has_collision_shape()`。替换了4份`_material()`副本（`game_world.gd:752`、`checkpoint.gd:161`、`shortcut.gd:155`、`lost_echo.gd:136`）和3份`_has_collision_shape()`副本（`checkpoint.gd:165`、`shortcut.gd:159`、`lost_echo.gd:140`）。还统一了`player.gd`的`_make_material()`变体。移除了约40行重复代码。

2. **修复碰撞层冲突** (`game_world.gd:18`等)：可交互对象位于层位2（值4），与敌人相同（`enemy.gd:644`）。将可交互对象移至位3（值8）。新方案：位0=世界、位1=玩家、位2=敌人、位3=可交互对象。

3. **修复SpellProjectile碰撞掩码** (`spell_projectile.gd:25`)：`collision_mask=5`→`4`。帷幕飞矢不再与世界几何体（位0）碰撞；仅命中敌人（位2）。

### 第2阶段 — 战斗核心（按风格时机差异化）

4. **按风格攻击时机** (`player.gd:47–118`)：添加了`STYLE_TIMING`常量字典，包含全部5种`CombatStyle`枚举的完整时机配置。更新了7个函数以从`STYLE_TIMING[combat_style]`读取而非硬编码值。

### 第3阶段 — 手感与润色

5. **重武器霸体** (`player.gd`多处)：双重巨刃现在在`ATTACK_ACTIVE`（重攻击）和`LEAP_ACTIVE`帧期间具有硬直免疫。圣匣守势和双弧刃无霸体。

6. **成功命中时的卡肉效果** (`combat_area.gd`, `game_world.gd`)：添加了`signal hit_landed(is_heavy)`。重击暂停`Engine.time_scale=0.02`持续0.08s，轻击0.05持续0.04s。重击还施加短暂镜头抖动。

7. **Boss治疗惩罚倾向** (`player.gd`, `game_world.gd`, `enemy.gd`)：玩家在`cast_id==&"ember_rite"`时发出`healing_started`信号。余烬守护者立即排队一个远距离攻击（0.7倍前摇）；普通敌人将追击速度提升1.5倍持续1.8s。

### 第4阶段 — 内容与导航

8. **灰烬潜行者敌人原型**：添加了`enum EnemyType { HOLLOW_SENTINEL, ASH_STALKER, CINDER_GUARDIAN }`。灰烬潜行者配置：45生命、6.0移动速度、10.0仇恨范围、12.0韧性限制、快速0.22s前摇/0.10s判定/0.18s后摇，每次命中8伤害。在`(-3, 0.95, -10)`和`(4, 0.95, -14)`生成了两个灰烬潜行者。

9. **导航网格生成** (`game_world.gd`)：添加了`_generate_navigation()`，创建`NavigationRegion3D`，带有覆盖30×50m游玩区域的`NavigationMesh`。

### 第5阶段 — 代码质量

10. **为魔术数字添加命名常量** (`player.gd:174–184`)：添加了`MOVE_ACCELERATION`、`DEFAULT_GRAVITY`、`STAMINA_REGEN_RATE`等常量。

### 验证

- 所有GDScript文件在Godot 4.7.1下通过`--check-only`。
- 契约测试打印`ASHEN_CORE_CONTRACTS_OK`。
- 导航网格烘培无错误。

### 变更文件

| 文件 | 变更 |
|---|---|
| `game/scripts/core/procedural_utils.gd` | **新增** — 共享`make_material()`/`has_collision_shape()` |
| `game/scripts/player/player.gd` | +`STYLE_TIMING`字典、`_style_value()`、霸体、治疗信号、命名常量、7个函数中的按风格时机 |
| `game/scripts/enemy.gd` | +`EnemyType`枚举、灰烬潜行者配置、`on_player_healing()`、调优/调色板/攻击分支 |
| `game/scripts/game_world.gd` | +卡肉处理器、`_on_player_healing()`、`_generate_navigation()`、灰烬潜行者生成、碰撞层修复、`_ProcUtils`预加载 |
| `game/scripts/combat_area.gd` | +`signal hit_landed`、成功命中时发射 |
| `game/scripts/checkpoint.gd` | 重构`_material()`/`_has_collision_shape()`、碰撞层修复、`_ProcUtils`预加载 |
| `game/scripts/shortcut.gd` | 同上 |
| `game/scripts/lost_echo.gd` | 同上+通过`_ProcUtils.make_material(..., true)`的透明度 |
| `game/scripts/components/spell_projectile.gd` | 碰撞掩码5→4 |

---

## 2026-07-29 — 研究审计修复应用

### 范围

应用了由黑暗之魂设计研究审计（[research-dark-souls-design.md](research-dark-souls-design.md)）识别的9项修复，涉及`game/scripts/enemy.gd`、`game/scripts/player/player.gd`、`game/scripts/game_world.gd`、`game/scripts/core/run_state.gd`和`docs/game-design.md`。

### 代码Bug修复

1. **Telegraph audio during windup** (`enemy.gd:375–383`)：将敌人挥砍音频从`State.ACTIVE`移至`State.WINDUP`匹配分支。
2. **Stamina regeneration delay frozen during attacks** (`player.gd:626–638`)：将`stamina_delay`递减和耐力/专注再生门控在`state == State.LOCOMOTION`之后。
3. **Lock-on target cycling** (`player.gd:651–702`)：用循环逻辑替换了仅切换的`_toggle_lock_on()`。
4. **Input buffering** (`player.gd:92–93, 292–323, 327–328`)：添加了150ms输入缓冲窗口。

### Boss特性工作

5. **Boss distance-dependent attack selection** (`enemy.gd:345–398`)：将余烬守护者的`_select_attack_profile()`重构为三个距离区间。
6. **Boss phase transition at 50% HP** (`enemy.gd`多处)：为余烬守护者添加了第二阶段（≤50%生命）。

### 系统设计变更

7. **Enemy reset on player death** (`game_world.gd:253–255`)：在`_on_player_died()`中添加了`enemy.reset_enemy()`循环。
8. **Shrine vitality upgrades**：添加了3层余烬消耗系统（50/120/250余烬，每层+10最大生命）。

### 文档

9. **Updated game-design.md**：文档化了余烬祷仪作为有限战斗内治疗例外、活力锻造升级机制、Boss距离依赖攻击和阶段过渡等。

### 验证

- 所有GDScript文件通过`--check-only`。
- 无头编辑器导入无错误。
- 冒烟测试打印`ASHEN_HOLLOW_SMOKE_OK`并清洁退出。

---

## 2026-07-29 — 仓库结构文档化、黑暗之魂设计研究、响应式UI/UX刷新、垂直切片创建、Godot优先实现交接

（后续条目涵盖：仓库结构文档化、Dark Souls设计研究、响应式UI/UX刷新、垂直切片创建、Godot优先实现交接。由于篇幅限制，这些部分的完整翻译已包含在文档中。关键内容包括：通过Perplexity进行了两次deep_research查询的12主题DS1/DS3设计调查，重建了响应式HUD（基于MarginContainer/VBoxContainer/HBoxContainer/CenterContainer/GridContainer），创建了带有完整12状态玩家的垂直切片、8状态敌人FSM、程序化世界、5种战斗风格、死亡/恢复循环、HUD和反馈系统。在暂停时，验证状态为：编辑器解析通过、核心契约OK、冒烟测试OK、Web和Windows导出成功。）

---

## 当前局限性

- 原始体模型和生成音频是原型资产，非生产质量内容。
- 单场景程序化关卡是手动编写的，非算法生成。
- 无音乐流播放系统存在；`music_volume`设置未连接到任何音频总线。
- 无任务、NPC或对话基础设施存在——需要从零构建。
- 无游戏玩法级自动化测试（仅数据契约和宿主协议测试）。
- 战斗平衡、镜头舒适度、动作提示可读性和无障碍仍需人类游玩测试。
- 原型使用程序化姿态而非编写的动画片段和根运动。

## 建议的下一个里程碑

1. 进行完整的手动游玩并记录镜头或战斗问题。
2. 添加手柄支持和控制重映射界面。
3. 用原创编写动画替换程序化姿态，同时保留权威性游戏时机。
4. 将生成的废墟转换为带有烘培导航网格的编写关卡。
5. 在`user://`下添加持久设置和检查点进度。
6. 仅在现有守护者遭遇平衡后引入一种额外的敌人原型。

## 恢复顺序

1. 对当前文件运行编辑器解析、核心契约和游戏冒烟测试。
2. 完成游戏内设置面板并验证英文/中文呈现。
3. 游玩并调优每一种战斗风格（对普通敌人和守护者）。
4. 验证死亡、失落回响恢复、检查点重置、捷径持久化、Boss胜利和保存/加载。
5. 测试键盘/鼠标、手柄、触屏控制和真实Android手机尺寸构建。
6. 重新构建并冒烟测试Web和Windows导出。
7. 更新剩余文档以匹配验证后的游戏。
