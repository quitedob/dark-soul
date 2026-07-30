# 角色升级系统 (Character Upgrade System)

## Overview

烬渊 uses a **multi-layered upgrade system** that combines traditional Soulslike stat leveling with Chinese cultivation philosophy. Progression is measured in **道行 (Cultivation Level)** , and upgrades are performed exclusively at **烬龛 (Ember Shrines)** .

---

## Core Systems

### 1. 道行提升 (Cultivation Leveling)

The primary progression mechanic. The player spends accumulated **烬 (Embers)** at any Ember Shrine to increase their **道行 (Dào Háng — Cultivation Level)** .

| Mechanic | Detail |
|----------|--------|
| **Resource** | Embers (earned from enemies, found in world, rewarded for bosses) |
| **Location** | Any activated Ember Shrine |
| **Cost Scaling** | Level × 100 Embers (Lv.1→2: 100, Lv.2→3: 200, etc.) |
| **Max Level** | 99 (soft cap at 60 — costs increase 3× after 60) |

**Per-Level Gains:**

| Stat | Gain per Level | Notes |
|------|---------------|-------|
| Max HP | +5 | Scales linearly |
| Max Stamina | +2 (every odd level) | So +1/level average |
| Max Focus | +2 (every even level) | So +1/level average |
| Talent Points | +1 | Spent in talent trees |

### 2. 经脉系统 (Meridian System)

A secondary upgrade path inspired by Chinese **气功 (Qigong)** and meridian theory. Players unlock and strengthen **经脉 (meridian channels)** using rare items found throughout the world.

**Eight Meridians (奇经八脉):**

| Meridian | Chinese | Unlock Item | Effect |
|----------|---------|------------|--------|
| 任脉 (Conception Vessel) | Rèn Mài | Found Chapter 1 | +10% healing received |
| 督脉 (Governing Vessel) | Dū Mài | Found Chapter 2 | +10% stamina regen rate |
| 冲脉 (Penetrating Vessel) | Chōng Mài | Found Chapter 2 | +8% critical hit chance |
| 带脉 (Belt Vessel) | Dài Mài | Found Chapter 3 | +10% equip load capacity |
| 阴跷脉 (Yin Heel Vessel) | Yīn Qiāo Mài | Found Chapter 3 | +8% dodge invulnerability window |
| 阳跷脉 (Yang Heel Vessel) | Yáng Qiāo Mài | Found Chapter 4 | +10% movement speed |
| 阴维脉 (Yin Linking Vessel) | Yīn Wéi Mài | Found Chapter 4 | +10% Focus regen rate |
| 阳维脉 (Yang Linking Vessel) | Yáng Wéi Mài | Found Chapter 5 | +5% all damage dealt |

Each meridian can be upgraded 5 times (Level 1-5), requiring increasingly rare materials:

| Level | Material | Effect Increase |
|-------|----------|----------------|
| 1 → 2 | 灵气结晶 (Spirit Energy Crystal) ×3 | +50% of base effect |
| 2 → 3 | 灵气结晶 ×8 | +100% of base effect |
| 3 → 4 | 纯阳石 (Pure Yang Stone) ×5 | +150% of base effect |
| 4 → 5 | 龙脉精髓 (Dragon Vein Essence) ×3 | +200% of base effect |

### 3. 魂器强化 (Soul Vessel Reinforcement)

Each chapter boss drops a **魂器 (Soul Vessel)** — a unique equippable item that grows with the player. Soul Vessels can be reinforced at Ember Shrines:

| Reinforcement | Embers Cost | Effect |
|--------------|-------------|--------|
| +1 | 200 | Base effect +20% |
| +2 | 500 | Base effect +40% |
| +3 | 1000 | Base effect +60%, unlocks secondary effect |
| +4 | 2000 | Base effect +80% |
| +5 | 4000 | Base effect +100%, unlocks ultimate effect |

### 4. 武器锻造 (Weapon Forging)

After Chapter 2, players can forge and upgrade weapons at the **铁心工坊 (Iron Heart Forge)** using materials from defeated enemies and bosses.

| Upgrade Level | Material Required | Effect |
|--------------|-------------------|--------|
| +1 → +3 | 铁精 (Iron Essence) | +10% base damage per level |
| +4 → +6 | 灵铁 (Spirit Iron) | +12% base damage per level |
| +7 → +9 | 龙鳞石 (Dragon Scale Stone) | +15% base damage per level |
| +10 | 铸魂碎片 (Soul-Forge Shard) | +20% base damage, unlocks weapon art |

---

## Upgrade Economy Summary

| System | Resource | Gated By | Max Level |
|--------|----------|----------|-----------|
| 道行 (Cultivation) | Embers | Ember Shrine access | 99 (soft cap 60) |
| 经脉 (Meridians) | Rare world items | Chapter progression | 5 per meridian (40 total) |
| 魂器 (Soul Vessels) | Embers | Boss defeat | +5 per vessel |
| 武器 (Weapons) | Crafting materials | Iron Heart Forge (Ch.2+) | +10 |
| 防具 (Armor) | Crafting materials | Iron Heart Forge (Ch.2+) | +5 |
| 天赋 (Talents) | Talent Points | Cultivation Level | Varies by tree |

---

## Death and Resource Persistence

Following Soulslike conventions:

| On Death | Status |
|----------|--------|
| Embers carried | Dropped as 失魂印记 (Lost Soul Mark) at death location |
| Embers banked (spent) | Safe — cannot be lost |
| Cultivation Level | Safe — permanent |
| Meridian upgrades | Safe — permanent |
| Soul Vessel reinforcement | Safe — permanent |
| Weapon/Armor upgrades | Safe — permanent |
| Talent Points spent | Safe — permanent |
| Unspent Talent Points | Safe — cannot be lost |

---

## UI/UX Design

When resting at an Ember Shrine, the upgrade menu presents four options:

1. **提升道行 (Cultivate)** — Level up
2. **经脉修炼 (Meridian Training)** — Upgrade meridians
3. **强化魂器 (Reinforce Soul Vessel)** — Upgrade boss soul items
4. **天赋修行 (Talent Cultivation)** — Spend talent points

The menu uses Chinese calligraphy-style headers with ink-brush transition effects.
