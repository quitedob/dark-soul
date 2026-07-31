# 烬渊 (Ember Abyss) — Master Design Index

**Game Title:** 烬渊 (Jìn Yuān) — *Ember Abyss*  
**Genre:** Chinese Dark Fantasy Soulslike Action RPG  
**Engine:** Godot 4.7.1  
**Updated:** 2026-07-31

---

## Vision

烬渊是第三人称暗黑奇幻动作 RPG：三界崩坏后烬火散落五章碎片大地。战斗走刻意的类魂节奏，美学融合武侠兵器诀、道门法术、佛门祷告与山海经式妖物。

---

## 文档地图（按文件夹）

### 导航 / 工程

| 路径 | 说明 |
|------|------|
| [architecture.md](architecture.md) | 运行时组成、FSM、碰撞层 |
| [controls.md](controls.md) | 键鼠 / 手柄 / 触控 |
| [validation.md](validation.md) | 自动化与手测清单 |
| [project-structure.md](project-structure.md) | 仓库布局与改动纪律 |
| [mcp-setup-guide.md](mcp-setup-guide.md) | Godot MCP |
| [game-design.md](game-design.md) | 垂直切片愿景与支柱 |
| [phone-compatibility.md](phone-compatibility.md) | 手机屏测试 |

### 日志 / 规划 / 任务

| 路径 | 说明 |
|------|------|
| [devlog/index.md](devlog/index.md) | **唯一交付日志**（按日期文件夹） |
| [planning/soulslike-gap-analysis.md](planning/soulslike-gap-analysis.md) | **类魂缺口权威** |
| [tasks-master.md](tasks-master.md) | 仍开放项 + 已完成维度摘要 |
| [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md) | 战斗里程碑对照 |

### 调研

| 路径 | 说明 |
|------|------|
| [research/index.md](research/index.md) | **调研汇总**（现网对照表） |
| [research/soulslike/](research/soulslike/) | 魂系设计 / 武器 / 帧与韧性 |
| [research/godot/](research/godot/) | 生态 / 跳跃碰撞 / 招式管线 / 早期基线 |

### 叙事 / 章节 / 角色 / 图鉴

| 路径 | 说明 |
|------|------|
| [story/](story/) | 主线、设定、章节桥接图 |
| [chapters/](chapters/) | 五章 overview + supplement |
| [characters/](characters/) | 职业、升级、切换、天赋 |
| [bestiary/](bestiary/) | 小怪与 Boss 权威名册 |

### 系统参考

| 路径 | 说明 |
|------|------|
| [systems/combat-styles.md](systems/combat-styles.md) | 五兼容 loadout |
| [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md) | 处决 / 格挡 / 韧性 / 兵器诀 |
| [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md) | Resource schema |
| [systems/focus-resource.md](systems/focus-resource.md) | Focus |
| [systems/enemy-ai.md](systems/enemy-ai.md) | 敌人 AI |
| [systems/save-persistence.md](systems/save-persistence.md) | 存档 |
| [systems/audio-system.md](systems/audio-system.md) | 音频 |
| [systems/build-export-guide.md](systems/build-export-guide.md) | 构建导出 |
| [systems/weapons-compendium.md](systems/weapons-compendium.md) / [spells](systems/spells-compendium.md) / [equipment](systems/equipment-compendium.md) | 内容名册 |
| [systems/level-design-patterns.md](systems/level-design-patterns.md) | 关卡模式 |

---

## 当前实现边界

- **已设计：** 五章因果、28 关、Boss/选择/NPC/结局规格。
- **已进代码：** 战役壳、Ch.1–2 遭遇、处决/抓投/镜头、命运旗标、云游叙事竖切；战斗/AI/测试见 [devlog](devlog/index.md)。
- **仍开放：** 真蒙皮动画、LimboAI 真插件、Ch.3–5 抛光、跨章 NPC 与隐藏结局证物。权威：[planning/soulslike-gap-analysis.md](planning/soulslike-gap-analysis.md)。

---

## 章节速览

| | Ch.1 灵墟 | Ch.2 血铁 | Ch.3 玉障 | Ch.4 天崩 | Ch.5 烬座 |
|---|---|---|---|---|---|
| **Theme** | Ruined Temple | War Fortress | Jade Forest | Sky City | Cosmic Furnace |
| **Boss** | 守炉灵·巨阙 | 血将军·刑天 | 玉面狐·九尾 | 堕仙·玄霄 | 烬渊之主·烛阴 |
| **Overview** | [spirit-awakening](chapters/01-spirit-awakening/chapter-overview.md) | [blood-iron](chapters/02-blood-iron/chapter-overview.md) | [jade-veil](chapters/03-jade-veil/chapter-overview.md) | [celestial-fall](chapters/04-celestial-fall/chapter-overview.md) | [throne-of-ashes](chapters/05-throne-of-ashes/chapter-overview.md) |

> 章节目录保留 `01`…`05` 前缀仅为阅读顺序；任务/审计**禁止**再用 `e-1` / `a01` 式散落文件名。
