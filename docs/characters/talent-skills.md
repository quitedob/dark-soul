# 天赋技能系统 (Talent Skill System)

## Overview

Each character class has a unique **天赋树 (Talent Tree)** with 3 tiers of unlockable abilities. Talent Points are earned by raising **道行 (Cultivation Level)** — 1 point per level. Talents provide permanent, class-specific passive bonuses and active abilities.

---

## Talent Point Economy

| Source | Points |
|--------|--------|
| Cultivation Level (each level) | +1 |
| Chapter Boss defeated (first time) | +2 |
| Optional sub-boss defeated | +1 |
| Secret talent scrolls (hidden in world) | +1 each (8 total across all chapters) |
| **Max theoretical points** | ~120 (Lv.99 + 10 boss + 8 scrolls) |

**Full talent tree completion** requires ~35 points per class. With 4 classes, full completion requires ~140 points — impossible in one playthrough, forcing choices.

---

## Talent Tier Structure (Per Class)

### Tier 1 (Novice Talents)
- **Requirement:** Cultivation Level 1+
- **Max investable points:** 9 (3 per talent × 3 talents)
- **Unlocks Tier 2 at:** 3 points spent in Tier 1
- **Role:** Core stat enhancements, foundational playstyle shaping

### Tier 2 (Adept Talents)
- **Requirement:** 3 points in Tier 1 + Cultivation Level 10+
- **Max investable points:** 6 (3 per talent × 2-3 talents)
- **Unlocks Tier 3 at:** 5 points spent in Tiers 1+2 combined
- **Role:** Mechanical depth, synergy effects, new capabilities

### Tier 3 (Master Talents)
- **Requirement:** 5 points in Tiers 1+2 + Cultivation Level 25+
- **Max investable points:** 3 (1 per talent × 3 talents)
- **Role:** Game-changing capstone abilities, class-defining ultimates

---

## Talent Respeccing

Players can respec talent points at any Ember Shrine after Chapter 2:

| Respec | Cost |
|--------|------|
| First respec | Free |
| Subsequent respecs | Level × 50 Embers |
| Per-class respec | Yes — respec one class without affecting others |

The respec cost encourages thoughtful building while allowing experimentation.

---

## Cross-Class Talent Synergies

When a player has invested in multiple classes' talent trees, **synergy bonuses** unlock:

| Investment | Synergy Bonus |
|-----------|---------------|
| 5 pts in 狂战士 + 5 pts in 神射手 | +8% physical damage for both classes |
| 5 pts in 玄法师 + 5 pts in 祝祷师 | +10% Focus pool for both classes |
| 5 pts in 狂战士 + 5 pts in 祝祷师 | Unlocks 战巫 (War Shaman) hybrid class |
| 5 pts in 神射手 + 5 pts in 玄法师 | Unlocks 魔弓手 (Arcane Archer) hybrid class |
| 5 pts in 狂战士 + 5 pts in 神射手 | Unlocks 修罗 (Asura) hybrid class |
| 5 pts in 玄法师 + 5 pts in 祝祷师 | Unlocks 阴阳师 (Yin-Yang Master) hybrid class |

---

## Class Talent Tree Summaries

### 神射手 (Divine Marksman) — 羿神之道

| Tier | Talents | Theme |
|------|---------|-------|
| 1 | 鹰眼, 疾步, 蓄力专精 | Accuracy, mobility, draw speed |
| 2 | 穿云, 火神之血, 寒冰之心 | Penetration, fire enhancement, ice enhancement |
| 3 | 后羿之魂, 九日连珠, 天人合一 | Legendary bow techniques |

### 狂战士 (Frenzied Warrior) — 刑天血路

| Tier | Talents | Theme |
|------|---------|-------|
| 1 | 嗜血, 钢筋铁骨, 不屈 | Lifesteal, defense, survival |
| 2 | 刑天怒目, 浴血奋战, 狂怒风暴 | Taunt, low-HP damage, area control |
| 3 | 刑天之志, 以乳为目, 脐为口 | Revival, anti-blindness, healing war cry |

### 玄法师 (Mystic Mage) — 五行真解

| Tier | Talents | Theme |
|------|---------|-------|
| 1 | 灵力充沛, 元素亲和, 快速结印 | Focus pool, cost reduction, cast speed |
| 2 | 相生之力, 相克之威, 法阵强化 | Generation cycle, overcoming cycle, formations |
| 3 | 五行归一, 道法自然, 太上老君之炉 | Elemental unity, self-buff formations, ultimate explosion |

### 祝祷师 (Invocation Master) — 慈悲之道

| Tier | Talents | Theme |
|------|---------|-------|
| 1 | 大慈大悲, 业力掌控, 灵体亲和 | Healing, karma, spirit buffs |
| 2 | 普度众生, 轮回之眼, 金刚不坏 | AoE karma, death triggers, defense |
| 3 | 地藏王愿, 千手观音, 涅槃寂静 | Revive, dual spirits, death nuke |

---

## Talent UI Design

The talent tree interface uses a **卷轴 (scroll)** aesthetic:
- Scroll unfurls horizontally to reveal the talent tree
- Each talent node is a **篆书 (seal script)** character inside a circular seal
- Invested talents glow with Ember-light; uninvested are dim stone-gray
- Tooltips appear on hover with ink-brush calligraphy descriptions
- A counter at the top shows available points

---

## Balance Philosophy

Talents follow these design rules:
1. **No "must-have" talents** — every Tier 1 option is viable for different playstyles
2. **Tier 3 talents are powerful but situational** — not always-on buffs, but tools for specific challenges
3. **Cross-class synergy is reward, not requirement** — hybrid classes are strictly optional
4. **Respec is accessible but costly enough to make choices meaningful**
5. **No talent makes the game easier in a way that bypasses mechanics** — talents enhance, not replace, player skill
