# 战斗风格系统 (Combat Style System)

## Overview

Building on Ashen Hollow's 5 original combat styles, 烬渊 re-themes and extends the combat style system to support 4 character classes, each with a unique style. The original 5 styles are preserved and adapted.

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
| Light Attack | 18 | 0.28s | 0.15s | 0.32s | 22 |
| Heavy Attack | 34 | 0.58s | 0.22s | 0.65s | 38 |
| Dodge | 24 | — | — | — | — |
| Parry Window | — | — | 0.06-0.26s | — | Counter: 26 |

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
| Light Attack | 22 | 0.48s | 0.22s | 0.52s | 32 |
| Heavy Attack | 42 | 0.82s | 0.28s | 0.90s | 56 |
| Dodge | 30 | — | — | — | — |
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
| Quick Shot | 12 stam | 0.20s | Instant | 0.18s | 18 |
| Power Shot | 28 stam | 0.80s | Instant | 0.40s | 42 |
| Evade Shot | 26 stam | — | — | — | 14 (mid-jump) |
| Dagger Slash | 10 stam | 0.18s | 0.12s | 0.20s | 12 |
| Arrow Rain | 40 Focus | 1.20s cast | 2.0s rain | 0.50s | 8×8 arrows |

**Special Abilities:**
- **Elemental Arrows:** Toggle Fire/Ice/Lightning/Spirit arrows (8-10 Focus per arrow)
- **Arrow Rain:** Volley that rains on locked target (40 Focus)
- **Spirit Arrow Sense:** Passive detection of hidden enemies/traps within 12m

---

## 五行术 (Five Elements Arts)

**Associated:** 玄法师 (Mystic Mage)
**Weapon:** Spell Seal + Spirit Stone
**Timing Profile:** Spellcasting tier

| Action | Focus | Cast Time | Recovery | Damage |
|--------|-------|-----------|----------|--------|
| Spirit Bolt | 8 | 0.25s | 0.20s | 16 |
| Elemental Burst | 25 | 1.00s | 0.50s | 28-38 (varies by element) |
| Magic Formation | 35 | 0.80s cast | 0.30s | Varies (8s duration) |
| Flash Step | 15 Focus + 20 Stam | Instant | 0.15s | 0 (movement) |
| Spell Shield | 5 Focus/s | Instant | — | Absorbs 70% dmg as Focus drain |

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

| Action | Focus | Cast Time | Recovery | Effect |
|--------|-------|-----------|----------|--------|
| Light of Compassion | 15 | 0.50s | 0.30s | Heal self/ally 22 HP |
| Karmic Fire Talisman | 20 | 0.55s | 0.35s | 24 dmg + Karmic Debt |
| Spirit Summon | 30 + 20% reserve | 1.00s | 0.40s | Summon spirit ally |
| Purification | 25 | 0.60s | 0.25s | Cleanse all debuffs |
| Rebirth Mantra | 8/s channel | — | — | 5m aura, 6 HP/s heal |
| Soul Release | 40 | 0.70s | 0.45s | Dmg = stored karma × 1.5 |

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

**Technical Note:** The existing Ashen Hollow `CombatStyle` enum and `STYLE_TIMING` dictionary in `player.gd` serve as the foundation. New styles extend this system with additional entries in the enum and timing profiles.
