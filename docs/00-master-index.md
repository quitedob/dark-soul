# 烬渊 (Ember Abyss) — Master Design Index

**Game Title:** 烬渊 (Jìn Yuān) — *Ember Abyss*
**Genre:** Chinese Dark Fantasy Soulslike Action RPG
**Engine:** Godot 4.7.1 (built on Ashen Hollow codebase)
**Design Date:** 2026-07-30

---

## Vision

烬渊 is a third-person dark fantasy action RPG set in a dying world inspired by Chinese mythology, where the boundary between the mortal realm and the underworld has collapsed. Players traverse five distinct realms — each a fragment of a shattered cosmic order — battling corrupted spirits, fallen immortals, and ancient divine beasts. The game fuses deliberate Soulslike combat with Chinese cultural aesthetics: wuxia-inspired weapon arts, Taoist spellcraft, Buddhist prayer disciplines, and mythological creature design rooted in 山海经 (Classic of Mountains and Seas) and folk religion.

The world runs on **烬 (Embers)** — remnants of divine fire that once maintained the cycle of reincarnation. When the 天之炉 (Celestial Furnace) shattered, embers scattered across five fractured realms, each warped by the being who claimed them.

---

## Document Map

### 📖 Story & Lore
| File | Description |
|------|-------------|
| [story/main-story.md](story/main-story.md) | Complete 5-chapter narrative arc |
| [story/lore.md](story/lore.md) | World history, cosmology, factions |

### 📕 Chapters (5 Realms)
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
| [systems/combat-styles.md](systems/combat-styles.md) | 5 combat styles (from Ashen Hollow) adapted to Chinese themes |
| [systems/weapons-compendium.md](systems/weapons-compendium.md) | All weapons across 5 chapters |
| [systems/spells-compendium.md](systems/spells-compendium.md) | All spells (法术) and prayers (祷告) across 5 chapters |
| [systems/equipment-compendium.md](systems/equipment-compendium.md) | Armor, talismans, rings, chapter artifacts |

### 👹 Bestiary
| File | Description |
|------|-------------|
| [bestiary/enemies-master.md](bestiary/enemies-master.md) | All minion enemies (4-9 per chapter, 32 total) |
| [bestiary/bosses-master.md](bestiary/bosses-master.md) | All bosses (5 main + optional sub-bosses) |

### 🔧 Systems
| File | Description |
|------|-------------|
| [systems/level-design-patterns.md](systems/level-design-patterns.md) | Puzzle types, trap catalog, shortcut patterns |
| [systems/equipment-compendium.md](systems/equipment-compendium.md) | Armor, consumables, and progression economy |

### 📱 Platform & Testing
| File | Description |
|------|-------------|
| [controls.md](controls.md) | Keyboard, mouse, controller, and touch input bindings |
| [validation.md](validation.md) | Automated test commands and manual test checklist |
| [phone-compatibility.md](phone-compatibility.md) | Phone screen size testing results (Chrome DevTools) |
| [audit-docs-codebase-health.md](audit-docs-codebase-health.md) | Full doc + codebase health assessment |
| [project-structure.md](project-structure.md) | Repository layout, naming rules, safe-change procedures |

---

## Design Constraints Checklist

- [x] 5 chapters, Chapter 1 = tutorial
- [x] Each chapter: unique enemies (3+ minion types), unique boss (no repeats)
- [x] 5+ levels per chapter with puzzles and traps
- [x] Unique chapter theme (no repeats across chapters)
- [x] Rich loot: chapter-exclusive weapons, equipment, spells, prayers
- [x] Coherent story connecting all 5 chapters
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
