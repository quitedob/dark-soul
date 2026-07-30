# 烬渊 (Ember Abyss) — 设计总索引

**游戏名称：** 烬渊 (Jìn Yuān) — *Ember Abyss*
**类型：** 中国黑暗奇幻魂系动作角色扮演游戏
**引擎：** Godot 4.7.1（基于 Ashen Hollow 代码库）
**设计日期：** 2026-07-30

---

## 愿景 (Vision)

烬渊是一款以中国神话为灵感的第三人称黑暗奇幻动作角色扮演游戏，设定于一个濒死的世界——凡间与冥界之间的边界已然崩塌。玩家穿越五片截然不同的领域——每一片都是一个破碎宇宙秩序的碎片——与堕落的精怪、谪仙和远古神兽战斗。游戏融合了刻意的魂系战斗与中国文化美学：武侠风格的武器技艺、道家法术、佛门祷告修行，以及植根于《山海经》和民间信仰的神话生物设计。

世界运行于**烬 (Embers)**——曾经维持轮回的圣火残余。当**天之炉 (Celestial Furnace)** 碎裂后，烬火散落于五片破碎的领域，每片领域都被占据它的存在所扭曲。

---

## 文档导览 (Document Map)

### 📖 故事与传说 (Story & Lore)
| 文件 | 描述 |
|------|-------------|
| [story/main-story.md](story/main-story.md) | 完整五章叙事弧线 |
| [story/lore.md](story/lore.md) | 世界历史、宇宙观、派系 |

### 📕 章节（五重领域）(Chapters — 5 Realms)
| 章节 | 名称 | 主题 | 文件 |
|---------|------|-------|------|
| 1 | 灵墟·觉醒 (Spirit Ruins · Awakening) | 教程 — 废弃的守护神庙 | [chapters/01-spirit-awakening/](chapters/01-spirit-awakening/chapter-overview.md) ← [精英怪·支线·音乐](chapters/01-spirit-awakening/chapter-supplement.md) |
| 2 | 血铁·战歌 (Blood & Iron · Warsong) | 战火纷飞的边塞堡垒 | [chapters/02-blood-iron/](chapters/02-blood-iron/chapter-overview.md) ← [精英怪·支线·音乐](chapters/02-blood-iron/chapter-supplement.md) |
| 3 | 玉障·迷心 (Jade Veil · Lost Mind) | 幻境笼罩的玉林 | [chapters/03-jade-veil/](chapters/03-jade-veil/chapter-overview.md) ← [精英怪·支线·音乐](chapters/03-jade-veil/chapter-supplement.md) |
| 4 | 天崩·陨落 (Celestial Fall) | 破碎的浮空仙城 | [chapters/04-celestial-fall/](chapters/04-celestial-fall/chapter-overview.md) ← [精英怪·支线·音乐](chapters/04-celestial-fall/chapter-supplement.md) |
| 5 | 烬座·归墟 (Throne of Ashes · Return to Void) | 破碎的天之炉 | [chapters/05-throne-of-ashes/](chapters/05-throne-of-ashes/chapter-overview.md) ← [精英怪·支线·音乐](chapters/05-throne-of-ashes/chapter-supplement.md) |

### 🦸 角色 (Characters)
| 文件 | 描述 |
|------|-------------|
| [characters/classes/](characters/classes/) | 4种初始职业 + 可解锁路径 |
| [characters/upgrade-system.md](characters/upgrade-system.md) | 升级、属性分配、升级层级 |
| [characters/switching-system.md](characters/switching-system.md) | 角色切换机制 |
| [characters/talent-skills.md](characters/talent-skills.md) | 天赋树和技能进度 |

### ⚔️ 战斗与装备 (Combat & Equipment)
| 文件 | 描述 |
|------|-------------|
| [systems/combat-styles.md](systems/combat-styles.md) | 5种战斗风格（来自 Ashen Hollow）改编为中式主题 |
| [systems/weapons-compendium.md](systems/weapons-compendium.md) | 五章全部武器 |
| [systems/spells-compendium.md](systems/spells-compendium.md) | 五章全部法术和祷告 |
| [systems/equipment-compendium.md](systems/equipment-compendium.md) | 护甲、护符、戒指、章节神器 |

### 👹 怪物图鉴 (Bestiary)
| 文件 | 描述 |
|------|-------------|
| [bestiary/enemies-master.md](bestiary/enemies-master.md) | 全部小怪（每章4-9种，共32种） |
| [bestiary/bosses-master.md](bestiary/bosses-master.md) | 全部Boss（5个主线 + 可选副Boss） |

### 🔧 系统 (Systems)
| 文件 | 描述 |
|------|-------------|
| [systems/level-design-patterns.md](systems/level-design-patterns.md) | 谜题类型、陷阱图鉴、捷径模式 |
| [systems/equipment-compendium.md](systems/equipment-compendium.md) | 护甲、消耗品和成长经济体系 |

### 📱 平台与测试 (Platform & Testing)
| 文件 | 描述 |
|------|-------------|
| [controls.md](controls.md) | 键盘、鼠标、手柄和触屏输入绑定 |
| [validation.md](validation.md) | 自动化测试命令和手动测试清单 |
| [phone-compatibility.md](phone-compatibility.md) | 手机屏幕尺寸测试结果（Chrome DevTools） |
| [audit-docs-codebase-health.md](audit-docs-codebase-health.md) | 完整文档 + 代码库健康评估 |
| [project-structure.md](project-structure.md) | 仓库布局、命名规则、安全变更流程 |

---

## 设计约束检查清单 (Design Constraints Checklist)

- [x] 5个章节，第一章 = 教程
- [x] 每章：独特敌人（3+种小怪），独特Boss（无重复）
- [x] 每章5+个关卡，含谜题和陷阱
- [x] 独特的章节主题（无跨章节重复）
- [x] 丰富战利品：章节专属武器、装备、法术、祷告
- [x] 连贯故事连接全部5章
- [x] 4种初始职业，中国文化命名和技能
- [x] 角色升级系统 + 切换系统 + 天赋技能
- [x] 所有概念均在组织好的文档文件夹中

---

## 快速参考：章节速览 (Quick Reference: Chapter at a Glance)

| | 第一章 灵墟 | 第二章 血铁 | 第三章 玉障 | 第四章 天崩 | 第五章 烬座 |
|---|---|---|---|---|---|
| **主题** | 废墟神庙 | 战争堡垒 | 玉林 | 天空之城 | 宇宙熔炉 |
| **Boss** | 守炉灵·巨阙 | 血将军·刑天 | 玉面狐·九尾 | 堕仙·玄霄 | 烬渊之主·烛阴 |
| **小怪** | 4种 | 6种 | 9种 | 7种 | 6种 |
| **关卡数** | 5 | 6 | 6 | 6 | 5 |
| **氛围基调** | 教程、神秘 | 残酷、尚武 | 欺诈、优雅 | 悲剧、史诗 | 宇宙、终末 |
| **核心机制** | 基础战斗 | 攻城器械 | 幻象谜题 | 重力/平台 | 相位现实 |
