# 角色切换系统 (Character Switching System)

## Overview

烬渊 allows players to **switch between unlocked character classes** at any Ember Shrine. This system is designed to encourage experimentation and tactical adaptation without trivializing class identity.

---

## Unlock Progression

| Event | Classes Available |
|-------|-------------------|
| Game Start | 1 class (chosen at character creation) |
| After Chapter 1 Boss | Starting class + 1 additional (player's choice) |
| After Chapter 2 Boss | +1 additional class |
| After Chapter 4 Boss | All 4 classes available |

After Chapter 4, all four base classes are available. Hybrid classes (阴阳师, 战巫, 魔弓手, 修罗) unlock after Chapter 3 if the player has invested in both parent classes' talent trees.

---

## Switching Mechanics

### At Ember Shrines

The primary switching interface. While resting at any Ember Shrine:

1. Select **切换法门 (Switch Path)** from the shrine menu
2. Choose an unlocked class
3. Confirm switch — current HP/Stamina/Focus adjust to the new class's values (proportional to current %)
4. Equipment auto-switches to that class's saved loadout
5. Active buffs are cleared; passive effects from the old class are removed
6. A brief ink-painting transition animation plays (1.5s)

### Stat Conversion

When switching classes, stats convert proportionally:

```
New Stat = (Current Stat / Old Class Max) × New Class Max
```

Example: Switching from 狂战士 (130 HP, currently at 65 HP = 50%) to 玄法师 (65 HP max) → 32 HP (50% of 65, rounded down).

### Equipment Loadouts

Each class maintains its **own equipment loadout**, saved automatically:
- Weapon(s)
- Off-hand item
- Head / Chest / Arms / Legs armor
- Two accessories
- Spirit Talisman (Invocation Master only)
- Active elemental attunement (Mystic Mage only)

Equipment is **not shared** between classes — if you equip a sword on 狂战士, it stays with 狂战士. This prevents micromanagement and encourages building each class independently.

---

## Combat Style Adaptation

Each class maps to a specific combat style (from the Ashen Hollow system):

| Class | Combat Style | Notes |
|-------|-------------|-------|
| 神射手 | 羿弓术 (custom ranged style) | New combat style for archery |
| 狂战士 | 刑天斧 (Twin Colossi adaptation) | Uses paired heavy weapon timing |
| 玄法师 | 五行术 (Veilcraft adaptation) | Uses spell casting timing |
| 祝祷师 | 天祝术 (Ember Rite adaptation) | Uses prayer casting timing |

The existing Ashen Hollow combat styles (Reliquary Guard, Twin Colossi, Crescent Pair, Veilcraft, Ember Rite) are re-themed and adapted to fit the Chinese cultural context.

---

## Switching Restrictions

| Context | Can Switch? | Notes |
|---------|------------|-------|
| At Ember Shrine | ✅ Yes | Primary switching location |
| In combat | ❌ No | "You cannot focus enough to change paths" |
| In boss arena | ❌ No | Even outside combat |
| After death (lost soul state) | ❌ No | Must recover lost Embers first or rest at shrine |
| During co-op | ❌ No | Class locked for multiplayer sessions |

---

## Class Mastery Bonuses

Playing a class earns **精通度 (Mastery Points)** — invisible progression tracked per-class:

| Mastery Level | Play Time Required | Bonus |
|--------------|-------------------|-------|
| 初学 (Novice) | 0 hours | — |
| 入门 (Initiate) | 2 hours | +3% class-specific stat |
| 熟练 (Adept) | 5 hours | +6% class-specific stat, title unlock |
| 精通 (Master) | 12 hours | +10% class-specific stat, secret class emote |
| 宗师 (Grandmaster) | 25 hours | +15% class-specific stat, class aura effect |

Mastery bonuses apply **only when playing that class** and are permanent unlocks once achieved.

---

## Story Integration

The ability to switch paths is justified in-world: as an **烬裔 (Ember Scion)** , your soul was forged from the original Furnace-fire, which contained all possible soul-configurations. Unlike ordinary beings who are born into one path, an Ember Scion's nature is **fundamentally fluid**. The Wandering Sage comments:

> *"其他灵魂如溪流——固定、可测、终归一处。而你的灵魂如烬火——飘忽、多变、何处不可燃？"*
> *"Other souls are like streams — fixed, predictable, flowing to one destination. But your soul is like Ember-fire — drifting, changeable. Where cannot it burn?"*

---

## Technical Architecture (For Godot Implementation)

Building on the existing Ashen Hollow codebase:

```
# New Resource type for class data
class_name CharacterClass extends Resource
var class_id: StringName           # "divine_marksman", etc.
var class_name: String             # Display name (localized)
var base_stats: Dictionary         # {hp, stamina, focus}
var combat_style: CombatStyle      # Maps to existing enum
var talent_tree: TalentTree        # New Resource type
var equipment_loadout: Dictionary  # Serialized equipment slots
var mastery_level: int             # 0-4
var mastery_points: float          # Accumulated play time

# Player gains class management
class_name PlayerClassManager extends Node
var unlocked_classes: Array[StringName]
var active_class: StringName
var class_data: Dictionary         # StringName -> CharacterClass
var can_switch: bool               # Gated by combat state
```

The existing `CombatStyle` enum gets new entries:
- `YI_ARCHERY` (5) — for 神射手
- `XINGTIAN_AXE` (6) — for 狂战士 (uses Twin Colossi timing)
- `FIVE_ELEMENTS` (7) — for 玄法师 (uses Veilcraft timing)
- `CELESTIAL_INVOCATION` (8) — for 祝祷师 (uses Ember Rite timing)
