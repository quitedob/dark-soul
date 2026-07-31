# 烬渊 (Ember Abyss) — Master Design Index

**Game Title:** 烬渊 (Jìn Yuān) — *Ember Abyss*
**Genre:** Chinese Dark Fantasy Soulslike Action RPG
**Engine:** Godot 4.7.1 (built on Ashen Hollow codebase)
**Design Date:** 2026-07-30

---

## Vision

烬渊 is a third-person dark fantasy action RPG set in a dying world inspired by Chinese mythology, where the boundary between the mortal realm and the underworld has collapsed. Players traverse five distinct fractured regions across the Three Realms, each warped by a fragment of a shattered cosmic order. The game fuses deliberate Soulslike combat with Chinese cultural aesthetics: wuxia-inspired weapon arts, Taoist spellcraft, Buddhist prayer disciplines, and mythological creature design rooted in 山海经 (Classic of Mountains and Seas) and folk religion.

The world runs on **烬 (Embers)** — remnants of divine fire that once maintained the cycle of reincarnation. When the 天之炉 (Celestial Furnace) shattered, embers scattered across five fractured regions, each warped by the being who claimed them.

---

## Document Map

### 📖 Story & Lore
| File | Description |
|------|-------------|
| [story/main-story.md](story/main-story.md) | Canonical 5-chapter narrative arc and four endings |
| [story/lore.md](story/lore.md) | Canonical world history, cosmology, factions, and player origin |
| [story/chapter-bridge-map.md](story/chapter-bridge-map.md) | **Narrative implementation authority** — chapter causality, evidence, flags, NPC migration, ending matrix |

### 🚧 Current Implementation Boundary

- **Designed:** complete five-chapter causality, 28-level content catalog, boss narratives, chapter choices, NPC routes, side quests, and four ending specifications.
- **Present in code:** chapter/level IDs, topology links, a basic procedural campaign shell, 7 unique boss registry entries, **Boss Execution Break / weak-point executions**, **GrabPairedDirector**, **CombatCameraDirector**, **FateChoiceOverlay** writing string `choice_flags`, plus **QuestState / DialogueRunner / EndingResolver** shrine vertical slice (`npc_cloud_wanderer`).
- **Not yet playable:** chapter-wide quest/NPC migration beyond the shrine Cloud Wanderer vertical slice; hidden ending evidence chain still task-gated for full content.
- Treat story documents as implementation specifications for remaining narrative systems; boss fate flags are writable; `QuestState` / `DialogueRunner` / `EndingResolver` 最小竖切已落地（见 `docs/audits/2026-07-31-soulslike-gap-analysis.md`）。

### 📕 Chapters (5 Fractured Regions)
| Chapter | Name | Theme | File |
|---------|------|-------|------|
| 1 | 灵墟·觉醒 (Spirit Ruins · Awakening) | Tutorial — Abandoned Guardian Temple | [chapters/01-spirit-awakening/](chapters/01-spirit-awakening/chapter-overview.md) ← [精英怪·支线·音乐](chapters/01-spirit-awakening/chapter-supplement.md) |
| 2 | 血铁·战歌 (Blood & Iron · Warsong) | War-Torn Border Fortress | [chapters/02-blood-iron/](chapters/02-blood-iron/chapter-overview.md) ← [精英怪·支线·音乐](chapters/02-blood-iron/chapter-supplement.md) |
| 3 | 玉障·迷心 (Jade Veil · Lost Mind) | Illusion-Bound Jade Forest | [chapters/03-jade-veil/](chapters/03-jade-veil/chapter-overview.md) ← [精英怪·支线·音乐](chapters/03-jade-veil/chapter-supplement.md) |
| 4 | 天崩·陨落 (Celestial Fall) | Shattered Floating Immortal City | [chapters/04-celestial-fall/](chapters/04-celestial-fall/chapter-overview.md) ← [精英怪·支线·音乐](chapters/04-celestial-fall/chapter-supplement.md) |
| 5 | 烬座·归墟 (Throne of Ashes · Return to Void) | The Broken Celestial Furnace | [chapters/05-throne-of-ashes/](chapters/05-throne-of-ashes/chapter-overview.md) ← [精英怪·支线·音乐](chapters/05-throne-of-ashes/chapter-supplement.md) |

### 🦸 Characters
| File | Description |
|------|-------------|
| [characters/classes/](characters/classes/) | 4 starting classes + unlockable paths |
| [characters/upgrade-system.md](characters/upgrade-system.md) | Leveling, stat allocation, upgrade tiers |
| [characters/switching-system.md](characters/switching-system.md) | Character swapping mechanics |
| [characters/talent-skills.md](characters/talent-skills.md) | Talent trees and skill progression |

### ⚔️ Combat & Equipment
| File | Description |
|------|-------------|
| [systems/combat-styles.md](systems/combat-styles.md) | Current five compatibility loadouts, timings, and class-fantasy boundaries |
| [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md) | **Target combat authority** — moves, grip modes, guard break, poise, executions, Boss weak points, grabs, and original weapon arts |
| [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md) | Godot Resource ownership and schemas for attacks, movesets, guard, execution, movement, and grabs |
| [systems/focus-resource.md](systems/focus-resource.md) | Focus pool, regen, spell/melee costs, HUD (J-07) |
| [systems/weapons-compendium.md](systems/weapons-compendium.md) | All weapons across 5 chapters |
| [systems/spells-compendium.md](systems/spells-compendium.md) | All spells (法术) and prayers (祷告) across 5 chapters |
| [systems/equipment-compendium.md](systems/equipment-compendium.md) | Armor, talismans, rings, chapter artifacts |

### 👹 Bestiary
| File | Description |
|------|-------------|
| [bestiary/enemies-master.md](bestiary/enemies-master.md) | All minion enemies (4-9 per chapter, 32 total) |
| [bestiary/bosses-master.md](bestiary/bosses-master.md) | Boss authority: 5 chapter bosses + 2 sub-bosses + 4 narrative echoes |
| [systems/enemy-ai.md](systems/enemy-ai.md) | Runtime AI: aggro/leash/sanctuary/nav fallback, per-type behavior (J-10) |

### 🔧 Systems
| File | Description |
|------|-------------|
| [systems/level-design-patterns.md](systems/level-design-patterns.md) | Puzzle types, trap catalog, shortcut patterns |
| [systems/equipment-compendium.md](systems/equipment-compendium.md) | Armor, consumables, and progression economy |
| [systems/save-persistence.md](systems/save-persistence.md) | Run/settings JSON schema, migration, `user://` paths (J-08) |
| [systems/audio-system.md](systems/audio-system.md) | Procedural SFX cues, 6-voice pool, headless rules (J-09) |
| [systems/build-export-guide.md](systems/build-export-guide.md) | `tools/build.ps1`, export presets, smoke commands (J-06) |

### 🛠️ Tools & Integration
| File | Description |
|------|-------------|
| [mcp-setup-guide.md](mcp-setup-guide.md) | **Godot MCP Native** — installation, test results (✅ verified), CLI usage, AI tool integration |
| [architecture.md](architecture.md) | Runtime composition, FSM, collision layers, Focus overview |
| [controls.md](controls.md) | Keyboard, mouse, controller, and touch input bindings |

### 📱 Platform & Testing
| File | Description |
|------|-------------|
| [validation.md](validation.md) | Automated test commands and manual test checklist |
| [research-godot-jump-collision.md](research-godot-jump-collision.md) | Godot 4.x jump, landing, slopes, stairs, projectile sweep, safe respawn, and collision-tunneling research |
| [phone-compatibility.md](phone-compatibility.md) | Phone screen size testing results (Chrome DevTools) |
| [audit-docs-codebase-health.md](audit-docs-codebase-health.md) | Full doc + codebase health assessment |
| [audits/2026-07-31-soulslike-gap-analysis.md](audits/2026-07-31-soulslike-gap-analysis.md) | **Soulslike gap authority** — 审查纠偏、P0–P2 缺口、三期路线（Phase 1–3 竖切已标注） |
| [project-structure.md](project-structure.md) | Repository layout, naming rules, safe-change procedures |
| [devlog.md](devlog.md) | Chronological change log and resume order |
| [tasks-master.md](tasks-master.md) | **Master task backlog** — dimensions A–J |

### 📋 Task Specs (selected)
| File | Description |
|------|-------------|
| [tasks/a-01-combat-style-data.md](tasks/a-01-combat-style-data.md) | A-01 — `CombatStyleData` Resource |
| [tasks/b-01-stamina-differentiation.md](tasks/b-01-stamina-differentiation.md) | B-01 — Per-style stamina |
| [tasks/c-01-local-hitstop.md](tasks/c-01-local-hitstop.md) | C-01 — Local hit-stop |
| [tasks/c-02-trauma-shake.md](tasks/c-02-trauma-shake.md) | C-02 — Trauma shake |
| [tasks/d-01-root-motion-setup.md](tasks/d-01-root-motion-setup.md) | D-01 — Root motion POC |
| [tasks/e-01-poise-system.md](tasks/e-01-poise-system.md) | E-01 — Continuous poise |
| [tasks/e-04-parry-windows.md](tasks/e-04-parry-windows.md) | E-04 — Parry windows |
| [tasks/f-02-lockon-scoring.md](tasks/f-02-lockon-scoring.md) | F-02 — Lock-on scoring |
| [tasks/g-01-limboai-bt.md](tasks/g-01-limboai-bt.md) | G-01 — LimboAI BT |
| [tasks/h-01-schema-conflict.md](tasks/h-01-schema-conflict.md) | H-01 — Level ID schema |
| [tasks/h-02-tool-migration.md](tasks/h-02-tool-migration.md) | H-02 — Migration tool |
| [tasks/i-01-gut-deploy.md](tasks/i-01-gut-deploy.md) | I-01 — GUT deploy |
| [tasks/i-03-fsm-tests.md](tasks/i-03-fsm-tests.md) | I-03 — FSM tests |
| [tasks/i-04-stamina-tests.md](tasks/i-04-stamina-tests.md) | I-04 — Stamina tests |
| [tasks/i-10-extract-smoke.md](tasks/i-10-extract-smoke.md) | I-10 — Extract smoke |
| [tasks/j-01-controls-rewrite.md](tasks/j-01-controls-rewrite.md) | J-01 — Controls rewrite |
| [tasks/combat-expansion-roadmap.md](tasks/combat-expansion-roadmap.md) | Combat milestones roadmap |

---

## Design Constraints Checklist

- [x] 5 chapters, Chapter 1 = tutorial
- [x] Each chapter: unique enemies (3+ minion types), unique boss (no repeats)
- [x] 5+ levels per chapter with puzzles and traps
- [x] Unique chapter theme (no repeats across chapters)
- [x] Rich loot: chapter-exclusive weapons, equipment, spells, prayers
- [x] Coherent story specification connecting all 5 chapters
- [ ] Runtime quest/NPC/dialogue/event pipeline carrying that story in game
- [x] 4 starting classes with Chinese cultural naming and skills
- [x] Character upgrade system + switching system + talent skills
- [x] All concepts in organized docs folders

---

## Quick Reference: Chapter at a Glance

| | Ch.1 灵墟 | Ch.2 血铁 | Ch.3 玉障 | Ch.4 天崩 | Ch.5 烬座 |
|---|---|---|---|---|---|
| **Theme** | Ruined Temple | War Fortress | Jade Forest | Sky City | Cosmic Furnace |
| **Boss** | 守炉灵·巨阙 | 血将军·刑天 | 玉面狐·九尾 | 堕仙·玄霄 | 烬渊之主·烛阴 |
| **Minions** | 4 types | 6 types | 9 types | 7 types | 6 types |
| **Levels** | 5 | 6 | 6 | 6 | 5 |
| **Tone** | Tutorial, mystery | Brutal, martial | Deceptive, elegant | Tragic, epic | Cosmic, final |
| **Key Mechanic** | Basic combat | Siege weapons | Illusion puzzles | Gravity/platform | Phase reality |
