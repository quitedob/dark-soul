# 战斗风格系统 (Combat Style System)

## Overview

Building on Ashen Hollow's 5 compatibility loadouts, 烬渊 re-themes the current prototype while defining a broader weapon-class future. Tables in this file describe the **current or currently targeted compatibility loadouts**, not a complete one-hand/two-hand execution system. Planned charge attacks, grip modes, context attacks, executions, Boss weak points, grabs, and data-driven weapon arts are specified in [Combat Execution, Guard & Weapon Arts](combat-execution-guard-weapon-arts.md).

**Implementation boundary:** Ordinary light/heavy timing for the three melee loadouts is owned by `CombatStyleData` resources and matches the Compatibility Frame Baseline in `tasks-master.md`. Veilcraft / Ember Rite primary casts use Focus via `SPELL_CONFIG`; their `.tres` light row maps cast/Instant/recovery, while heavy columns are baseline N/A and retain offhand compatibility timings. Leap / dodge / action armor may still have legacy dependencies. `controls.md` is authoritative for currently playable inputs.

---

## Style Mapping: Original → 烬渊

| Original (Ashen Hollow) | 烬渊 Adaptation | Class Association | Weapon Type |
|------------------------|----------------|-------------------|-------------|
| Reliquary Guard | 护卫之道 (Way of the Guardian) | Universal (tutorial) | Sword + Shield |
| Twin Colossi | 刑天斧法 (Xíng Tiān Axe Method) | 狂战士 | Dual Battle Axes |
| Crescent Pair | 羿弓术 (Yì Archery) | 神射手 | Bow + Dagger |
| Veilcraft | 五行术 (Five Elements Arts) | 玄法师 | Spell Seal |
| Ember Rite | 天祝术 (Celestial Invocation) | 祝祷师 | Prayer Beads |

---

## 护卫之道 (Way of the Guardian)

**Associated:** Tutorial / Any class
**Weapon:** Sword + Shield
**Timing Profile:** Straight Sword tier (from Ashen Hollow research)

| Action | Stamina | Windup | Active | Recovery | Damage |
|--------|---------|--------|--------|----------|--------|
| Light Attack | 22 | 0.28s | 0.15s | 0.32s | 22 |
| Heavy Attack | 40 | 0.58s | 0.22s | 0.65s | 38 |
| Dodge | 24 | — | — | — | — |
| Medium Shield Parry | 10 | 0.40s | 0.20s | 0.60s × 1.5 miss | Counter |

**Special Abilities:**
- **Parry (格挡):** Frame-tight parry window, staggers enemy on success
- **Guard (防御):** Hold to block frontal attacks (82% reduction with stamina, 65% if guard-broken)
- **Shield Bash (盾击):** Guard + Heavy Attack — 18 dmg, high stagger, 0.4s windup

**Tutorial Purpose:** Teaches defensive play, parry timing, and shield management. Accessible to all classes as a fallback style.

---

## 刑天斧法 (Xíng Tiān Axe Method)

**Associated:** 狂战士 (Frenzied Warrior)
**Weapon:** Dual Battle Axes
**Timing Profile:** Ultra Greatsword tier

| Action | Stamina | Windup | Active | Recovery | Damage |
|--------|---------|--------|--------|----------|--------|
| Light Attack | 38 | 0.48s | 0.22s | 0.52s | 32 |
| Heavy Attack | 65 | 0.82s | 0.28s | 0.90s | 56 |
| Dodge | 32 | — | — | — | — |
| Leap Attack | 38 | 0.65s | 0.30s | 0.75s | 58 |

**Special Abilities:**
- **Berserker Rush (狂冲):** Sprint 8m with axes, damaging everything in path (18 dmg, 22 stamina)
- **Blood Price (血偿):** Convert 15% HP → full Rage meter (30s cooldown)
- **Execution (处决):** Slow overhead chop, triple damage vs enemies below 25% HP (24 stamina)
- **Hyper Armor:** Active during heavy attack and leap active frames

**Rage Mechanic:** Builds from dealing/taking damage. At 50+, enters Frenzy: +20% speed, +25% damage, -15% damage taken, +40% stamina regen.

---

## 羿弓术 (Yì Archery)

**Associated:** 神射手 (Divine Marksman)
**Weapon:** Bow + Dagger
**Timing Profile:** Custom (ranged-focused)

| Action | Stamina/Focus | Windup | Active | Recovery | Damage |
|--------|--------------|--------|--------|----------|--------|
| Quick Shot / Light | 16 stam | 0.20s | 0.12s | 0.20s | 16 |
| Power Shot / Heavy | 28 stam | 0.38s | 0.16s | 0.38s | 26 |
| Evade / Crescent Leap | 27 stam | 0.22s | 0.34s | 0.34s | 18×2 |
| Dodge | 18 stam | — | — | — | — |

**Special Abilities:**
- **Elemental Arrows:** Toggle Fire/Ice/Lightning/Spirit arrows (8-10 Focus per arrow)
- **Arrow Rain:** Volley that rains on locked target (40 Focus)
- **Spirit Arrow Sense:** Passive detection of hidden enemies/traps within 12m

---

## 五行术 (Five Elements Arts)

**Associated:** 玄法师 (Mystic Mage)
**Weapon:** Spell Seal + Spirit Stone
**Timing Profile:** Spellcasting tier

| Action | Focus | Cast Time | Active | Recovery | Damage |
|--------|-------|-----------|--------|----------|--------|
| Spirit Bolt (compat light) | 14 | 0.25s | Instant | 0.20s | 16 |
| Elemental Burst | 22 | 1.00s | Instant | 0.50s | 28-38 (varies by element) |
| Magic Formation | 35 | 0.80s | Instant | 0.30s | Varies (8s duration) |
| Flash Step | 15 Focus + 20 Stam | Instant | — | 0.15s | 0 (movement) |
| Spell Shield | 5 Focus/s | Instant | — | — | Absorbs 70% dmg as Focus drain |

**Five Elements:**
| Element | Burst Effect | Formation Effect |
|---------|-------------|------------------|
| Fire | Fireball AoE (32 dmg) | Damage zone (12 dmg/s) |
| Water | Ice Lance (28 dmg, pierce) | Healing zone (8 HP/s) |
| Wood | Vine Snare (18 dmg, root) | Speed boost (+25%) |
| Metal | Lightning Strike (38 dmg) | Damage reflection (20%) |
| Earth | Stone Spikes (24 dmg, cone) | Defense zone (-30% dmg) |

---

## 天祝术 (Celestial Invocation)

**Associated:** 祝祷师 (Invocation Master)
**Weapon:** Prayer Beads + Talisman Papers
**Timing Profile:** Prayer casting tier

| Action | Focus | Cast Time | Active | Recovery | Effect |
|--------|-------|-----------|--------|----------|--------|
| Light of Compassion (compat light) | 20 | 0.50s | Instant | 0.30s | Heal self/ally 22 HP |
| Karmic Fire Talisman | 35 | 0.55s | Instant | 0.35s | 24 dmg + Karmic Debt |
| Spirit Summon | 30 + 20% reserve | 1.00s | Instant | 0.40s | Summon spirit ally |
| Purification | 25 | 0.60s | Instant | 0.25s | Cleanse all debuffs |
| Rebirth Mantra | 8/s channel | — | — | — | 5m aura, 6 HP/s heal |
| Soul Release | 40 | 0.70s | Instant | 0.45s | Dmg = stored karma × 1.5 |

**Karmic Debt Mechanic:** Each application adds 1 stack (max 10). Per stack: enemy -2% damage dealt, +2% damage taken. At 10 stacks, Soul Release deals double.

**Spirit Summons:**
- 护法灵童 (Tank/Taunt)
- 金甲力士 (Defense/Anti-projectile)
- 往生莲 (Healing totem)
- 怨灵 (Glass cannon DPS)
- 白鹤童子 (Focus support)

---

## Style Unlock Progression

| Chapter | Styles Available |
|---------|-----------------|
| 1 (Start) | 护卫之道 (Universal tutorial style) |
| 1 (1-3) | Player's chosen class style unlocks |
| 2 | Second class style (if second class unlocked) |
| 4 | All class styles available |

---

## Style Switching

Styles can be switched at any Ember Shrine. During combat experimentation, players may temporarily use other styles in specific "trial" areas (Chapter 1 alcoves, Chapter 5 Soul-Forger trials) without permanently unlocking them.

**Technical Note:** The current prototype keeps the original `CombatStyle` enum as a compatibility selector and loads ordinary timing from five `CombatStyleData` resources. Legacy dictionaries still service leap, dodge, and action armor and must be removed before `AttackData` / `MovesetData` migration. See [Attack and Moveset Data Schema](attack-moveset-data-schema.md).
