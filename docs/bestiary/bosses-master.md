# 烬渊 — Boss Compendium (首领图鉴)

## Boss Design Principles

Each boss follows the design principles established in the Dark Souls research:
1. **Unique identity** — no two bosses share mechanics, visual design, or narrative role
2. **Telegraphed attacks** — every attack has visible windup and audio cue
3. **Phase transitions** — all main bosses have at least 2 phases with mechanical shifts
4. **Lore integration** — bosses are characters with history, motivation, and tragedy
5. **Soul Vessel reward** — each boss drops a unique equippable item themed after them

---

## Chapter 1: 守炉灵·巨阙 (Furnace-Keeper · Giant Gate)

| Attribute | Detail |
|-----------|--------|
| **Type** | 精 (Animated Construct) |
| **HP** | 360 |
| **Phases** | 2 (Dutiful Guardian → Furnace Overload) |
| **Damage Range** | 18-60 |
| **Speed** | 2.0 → 2.4 (Phase 2) |
| **Arena** | Circular sanctum, 30m diameter, 4 pillars |
| **Soul Vessel** | 守炉之核 (Furnace-Keeper's Core) |

**Full details:** [Chapter 1 Boss](../chapters/01-spirit-awakening/bosses.md)

---

## Chapter 2: 血将军·刑天 (Blood General · Xíng Tiān)

| Attribute | Detail |
|-----------|--------|
| **Type** | 神 (Corrupted War God) |
| **HP** | 580 |
| **Phases** | 3 (Chained Titan → Unchained Berserker → Honor Duel) |
| **Damage Range** | 28-68 |
| **Speed** | 3.0 → 4.5 → 3.5 |
| **Arena** | Mountain peak colosseum with phantom army spectators |
| **Soul Vessel** | 刑天之心 (Xíng Tiān's Heart) |

### Visual Design
A headless giant (12m tall), his torso covered in ritual scarification that glows with crimson Ember-light. His eyes are on his chest (nipples → eyes), his mouth is on his abdomen (navel → mouth) — exactly as described in 山海经. Two massive battle axes are chained to his wrists; in Phase 2, the chains break.

### Phase 1: 缚锁刑天 (Chained Xíng Tiān — 100-70%)
刑天 is bound by spectral chains (the Soul-Forgers' seal). His movements are restricted but his attacks are devastating when they land.

| Attack | Windup | Damage | Tell |
|--------|--------|--------|------|
| **Chain Sweep** | 1.5s | 35 | Drags axe across ground, sparks fly |
| **Shackled Slam** | 2.0s | 48 | Both axes overhead, chains rattle |
| **Chest Glare** | 1.0s | 0 dmg (stun) | Eyes on chest glow — 3s paralysis gaze |

### Phase 2: 破锁刑天 (Unchained Xíng Tiān — 70-30%)
Chains break. 刑天 enters true berserker rage. The phantom armies in the stands begin chanting.

| Attack | Windup | Damage | Tell |
|--------|--------|--------|------|
| **Whirlwind Rage** | 0.8s | 22 ×5 hits | Spins with both axes extended — 8m radius |
| **Titan's Leap** | 1.2s | 52 (AoE) | Crouches, then leaps across the arena |
| **War Cry** | 0.6s | 0 dmg (fear) | Roar from belly-mouth — 5s damage debuff (-20%) |
| **Axe Throw** | 1.8s | 40 | Throws one axe, retrieves via chain pull-back |

### Phase 3: 荣誉之决 (Honor Duel — 30-0%)
刑天's rage subsides into something colder — recognition. He has found a worthy opponent. He drops one axe and fights one-handed, matching the player's style. Attacks become slower but more precise. Damage increases but windups are longer and telegraphed with honor — he waits for you to be ready.

| Attack | Windup | Damage | Tell |
|--------|--------|--------|------|
| **Honor Strike** | 2.0s | 68 | Single deliberate overhead. He nods before swinging. |
| **Counter Stance** | — | 58 | Stands still, axe held across chest. If hit during this, instant counterattack. Wait him out. |
| **Final Salute** | 3.0s | 80 (one-hit KO range) | Below 10%: raises axe in salute, then one final earth-shattering slam. Arena floor cracks. Can be dodged — the salute is the tell. |

### Unique Interaction: 狂战士 Class
When a 狂战士 player enters the arena, 刑天 pauses. Instead of attacking immediately, the player can kneel (emote) to initiate a dialogue. 刑天 recognizes the fragment of his own spirit within the player. He offers a choice:
- **Fight with honor:** Standard boss fight proceeds
- **Prove your rage:** Skip Phase 1 entirely, start at Phase 2 with 刑天 at 70% HP — but the player starts with full Rage and +25% damage throughout

### Rewards
| Reward | Details |
|--------|---------|
| 刑天之心 (Xíng Tiān's Heart) | Soul Vessel — When HP drops below 20%, gain +30% damage and +20% speed for 15s (60s cooldown) |
| 战烬碎片 (War Ember Fragment) | Story progression |
| 刑天断角 (Xíng Tiān's Broken Horn) | Crafting — forge boss weapon |
| 680 Embers | Currency |
| 2 Talent Points | Progression |

### Boss Weapon
**刑天·不屈 (Xíng Tiān · Indomitable)** — Dual Battle Axes
- Damage: 62
- Special: **不屈之魂 (Indomitable Spirit)** — If an attack would kill you while wielding these axes, instead survive at 1 HP and gain 3s invincibility. Once per rest.

---

## Chapter 3: 玉面狐·九尾 (Jade-Faced Fox · Nine-Tails)

| Attribute | Detail |
|-----------|--------|
| **Type** | 妖 (Corrupted Nature Deity) |
| **HP** | 450 |
| **Phases** | 3 (Testing → Illusion Storm → Memory Form) |
| **Damage Range** | 18-52 |
| **Speed** | 6.0 → 5.0 → 4.0 |
| **Arena** | Moonlit Terrace, surrounded by 9 Illusion Flowers |
| **Soul Vessel** | 九尾幻心 (Nine-Tails' Illusion Heart) |

### Visual Design
In her true form: a massive nine-tailed fox with jade-green fur and eyes like liquid moonlight. Each tail is a different color, representing a different type of illusion. She is beautiful in the way a predator is beautiful — mesmerizing and deadly.

In human form (Phase 3): an elegant woman in layered jade robes, face partially hidden behind a translucent fan. Her eyes never blink.

### Phase 1: 测试 (Testing the Intruder — 100-70%)
Nine-Tails is curious about this intruder who can see through illusions. She tests your capabilities rather than trying to kill you outright.

| Attack | Damage | Tell |
|--------|--------|------|
| **Tail Swipe** | 24 | Single tail sweeps, each with 0.8s windup |
| **Foxfire** | 18 (homing) | Summons 3 floating foxfire orbs that slowly home in on the player |
| **Mist Step** | 0 (teleport) | Dissolves into mist and reappears elsewhere |
| **Charm Gaze** | 0 (effect) | If player faces her during gaze, movement slowed 50% for 3s |

### Phase 2: 幻境风暴 (Illusion Storm — 70-30%)
Nine-Tails' nine tails each manifest a different illusion type. The arena fills with shifting realities.

| Attack | Effect |
|--------|--------|
| **Tail Clone (×3 per activation)** | Creates 3 illusion clones. Each has 1 HP. Hitting a clone deals 10 damage back to the player. The real Nine-Tails has a subtle jade shimmer in her fur. |
| **Dream Eater** | A wave of purple energy. If hit, the player enters a 5s dream state where controls are reversed and Nine-Tails appears multiplied. |
| **Fox Wedding (Ultimate)** | At 50%: the arena transforms into a phantom wedding procession. Illusion guests crowd the arena (block movement), and Nine-Tails attacks from within the crowd. Lasts 15s. |

### Phase 3: 记忆之形 (Memory Form — 30-0%)
Nine-Tails takes a human form — specifically, the form of someone the player character loved in a past life (narrative reveal). She fights with graceful martial arts and borrowed memories.

| Attack | Effect |
|--------|--------|
| **Memory Strike** | Uses the player's own light attack animation — 22 dmg. Each strike shows a brief flashback. |
| **Borrowed Technique** | Copies the player's most-used special ability and uses it against them (Leap, Arrow Rain, Elemental Burst, or Soul Release) |
| **Heart's Desire** | At 15%: The arena shows a vision of the thing the player most desires (varies by class/choices). Nine-Tails offers to make it real if you stop fighting. Attacking breaks the vision. Standing still for 10s results in death. |

### The Memory Gaze (Interactive Cutscene)
At 50% HP (Phase 2 → 3 transition): combat pauses. Nine-Tails shares her memory — a vision of her as the forest's gentle guardian before the Illusion Ember corrupted her. The player experiences her tragedy firsthand. This is unskippable on first playthrough. On NG+, the player can strike during this moment to skip directly to Phase 3.

### Rewards
| Reward | Details |
|--------|---------|
| 九尾幻心 (Nine-Tails' Illusion Heart) | Soul Vessel — After dodging, leave behind an illusion clone for 3s (confuses enemies) |
| 幻烬碎片 (Illusion Ember Fragment) | Story progression |
| 九尾玉簪 (Nine-Tails Jade Hairpin) | Crafting — forge boss weapon |
| 520 Embers | Currency |
| 2 Talent Points | Progression |

### Boss Weapon
**九尾·幻月 (Nine-Tails · Illusion Moon)** — Spell Focus (Fan)
- Damage: +25% spell damage
- Special: **幻月之舞 (Dance of the Illusion Moon)** — Casting a spell creates an illusion clone that casts the same spell 1s later at 50% damage

---

## Chapter 4: 堕仙·玄霄 (Fallen Immortal · Xuán Xiāo)

| Attribute | Detail |
|-----------|--------|
| **Type** | 仙堕 (Fallen Immortal) |
| **HP** | 520 (shared across all fragments) |
| **Phases** | 3 (Divine Half → Unified Form → Fragmented Mind) |
| **Damage Range** | 22-62 |
| **Speed** | 3.0 → 4.0 → Variable |
| **Arena** | Crumbling celestial platform at city zenith |
| **Soul Vessel** | 玄霄残愿 (Xuán Xiāo's Lingering Wish) |

### Visual Design
玄霄's true body is a figure frozen in the moment of ascension — right half divine light, left half rotting flesh. His robes are those of a high cultivator: white silk embroidered with cloud patterns, now stained and torn. Three "wisps" of his fragmented consciousness (the sub-bosses defeated in 4-4 and 4-5) orbit around him.

### Sub-Boss: 玄霄·嗔念 (Wrath Fragment) — Level 4-4
Pure aggression. All attacks, no defense.
- HP: 120, Damage: 45, Speed: 6.0
- Attacks: Rushing Fist, Fury Combo (5 rapid punches), Ground Shatter
- Defeat reward: 嗔念之拳 (Wrath Fist weapon)

### Sub-Boss: 玄霄·执念 (Obsession Fragment) — Level 4-5
Pure defense and ritual. Summons spirit guardians, activates arena traps.
- HP: 140, Damage: 28, Speed: 2.0
- Attacks: Spirit Summon, Ritual Trap Activation, Defensive Barrier
- Defeat reward: 执念护符 (Obsession Talisman accessory)

### Main Boss: Phase 1 — 神堕二元 (Divine and Fallen — 100-60%)
玄霄's divine half attacks while the rotting half is passive.

| Attack | Damage | Tell |
|--------|--------|------|
| **Celestial Beam** | 32 | Divine half raises hand, 1.5s charge, sweeping beam of light |
| **Light Spear** | 24 ×3 | Summons three spears of light, fires sequentially |
| **Decay Pulse** | 18 + DoT | Rotting half pulses every 30s — passive AoE |
| **Half-Step** | 0 | Teleports by dissolving into light, reappearing elsewhere |

### Phase 2: 归一 (Reunification — 60-30%)
Divine and rotting halves merge. 玄霄 fights as a unified being, alternating between light and decay attacks.

| Attack | Effect |
|--------|--------|
| **Celestial Rot** | Stacking debuff — each hit reduces max HP by 3% (stacks 5 times, resets after 30s) |
| **Ascension Strike** | Light-and-decay combined slam. 48 dmg. Leaves zone of mixed healing/damage energy. |
| **Fragment Orbit** | Two sub-boss fragments orbit and attack independently. Reduced HP versions. |

### Phase 3: 意识风暴 (Mindstorm — 30-0%)
玄霄's mind fully fragments. The arena becomes chaos — the player must identify which personality (Wrath, Obsession, or Core) is currently dominant and respond accordingly.

| Personality | Attack Pattern | Counter |
|-------------|---------------|---------|
| **Wrath Dominant** | Aggressive rushdown, fast combos | Parry/dodge, punish recovery |
| **Obsession Dominant** | Ritual casting, arena traps, summons | Interrupt casts, avoid traps |
| **Core Dominant** | Balanced light/decay attacks | Standard combat |

Personality shifts every 20s. Visual/audio tells: Wrath = red glow + roar; Obsession = blue glow + chanting; Core = white glow + silence.

### Post-Boss Escape Sequence
After absorbing the Sky Ember, Cloud Zenith City begins its final collapse. The player must navigate a 90-second escape sequence through crumbling platforms, using the newly-acquired gravity manipulation to reach safe ground. This is cinematic but mechanically real — the player can die here and must retry the escape (not the boss).

### Rewards
| Reward | Details |
|--------|---------|
| 玄霄残愿 (Xuán Xiāo's Lingering Wish) | Soul Vessel — Below 30% HP, gain brief flight (anti-gravity jumps, slow fall) for 12s (90s cooldown) |
| 天烬碎片 (Sky Ember Fragment) | Story progression, unlock gravity manipulation |
| 玄霄道心 (Xuán Xiāo's Dao Heart) | Crafting — forge boss weapon |
| 750 Embers | Currency |
| 2 Talent Points | Progression |

### Boss Weapon
**玄霄·陨星 (Xuán Xiāo · Falling Star)** — Spell Sword
- Damage: 44 physical + 28 light
- Special: **天崩 (Celestial Fall)** — Heavy attack while airborne creates a meteor-impact AoE at the landing point (35 dmg, 6m radius)

---

## Chapter 5: 烬渊之主·烛阴 (Lord of the Ember Abyss · Zhú Yīn)

| Attribute | Detail |
|-----------|--------|
| **Type** | 神 (Torch Dragon / Fallen Soul-Forger) |
| **HP** | 800 |
| **Phases** | 4 (Dragon Form → Human Form → Core of Abyss → Final Choice) |
| **Damage Range** | 28-85 |
| **Speed** | Variable by phase |
| **Arena** | The Throne of Ashes — platforms in void |
| **Soul Vessel** | 烛阴之鳞 (Zhú Yīn's Scale) |

### Visual Design
烛阴's true form is a dragon of living starlight. His body is composed of countless tiny points of light — each one a soul that faded due to the broken cycle. His eyes are dying suns. His voice echoes not from a mouth but from everywhere at once.

His human form (Phase 2) is a tall, gaunt figure of condensed light, wearing tattered robes that were once the ceremonial attire of the Soul-Forgers. His face is ancient, tired, and utterly sincere.

### Pre-Fight Dialogue (Summary)
烛阴 does not attack immediately. He speaks for approximately 3 minutes — the longest dialogue in the game. He is not a villain giving a villain speech. He is a tired, ancient being explaining himself to perhaps the only person who might understand:

Every calculation he ever made confirmed the same thing: the cycle was failing. The Ember-light was dimming. In time — cosmically short time — all souls would fade to nothing. His solution was extreme, but it was the only one that prevented the extinction of all consciousness.

He does not ask for forgiveness. He asks for understanding. And then he asks: **"What would you have done?"**

### Phase 1: 龙形 (Dragon Form — 100-70%)

| Attack | Damage | Tell |
|--------|--------|------|
| **Starfall Breath** | 18/s (beam) | Dragon head rears back, constellation pattern forms in mouth — 2s tell |
| **Constellation Claws** | 35 ×3 | Star patterns appear on ground marking claw strike zones — 1.5s tell |
| **Tail of Eternity** | 42 | The entire tail sweeps across the arena — duck or jump over (timing-based, 1s window) |
| **Ember Rain** | 12/s (AoE) | Meteors of cooled Ember fall across the arena — random pattern, find gaps |

### Phase 2: 人形 (Human Form — 70-40%)

| Attack | Damage | Tell |
|--------|--------|------|
| **Light-Step** | 28 ×3 | Rapid teleport strikes, blinks to three positions around the player |
| **Ember Lance** | 34 + 18 (explosion) | Throws Ember spears that stick in the ground, explode after 2s |
| **Gravity Well** | 55 (if caught) | Creates singularity — constant pull, 3s duration |
| **Soul Theft** | 0 dmg, drains Embers | Grabs player, drains 20% of total earned Embers (devastating economy hit) |

### Phase 3: 烬渊之核 (Core of the Abyss — 40-10%)
Zero-gravity phase. Player uses Chapter 4's gravity manipulation to navigate.

| Attack | Damage | Tell |
|--------|--------|------|
| **Supernova** | 70 (entire arena) | Core glows orange for 5s → everything explodes. Hide behind floating debris. |
| **Event Horizon** | 15/s (pull) | Black hole at center — constant pull. Must fight while managing drift. |
| **Soul Storm** | 8/s per projectile | Hundreds of soul-projectiles erupt outward. Bullet-hell pattern, 8s duration. |
| **Gravity Flip** | Variable | Arena gravity randomly inverts every 15s. Audio cue: low rumble. |

### Phase 4: 终结抉择 (Final Choice — 10-0%)
At 10% HP, 烛阴 kneels. The fight ends. The player is alone with him on a single floating platform in the void. He speaks his final words:

> *"So. An Ember Scion who can truly choose. Not bound by the old cycle. Not chained by my vision. Free."*
> *"Then choose. I have waited five hundred years to see what a free being would do."*

**Three actions, three endings:**

| Player Action | Ending | Outcome |
|--------------|--------|---------|
| Absorb 烛阴's remaining Ember into yourself | **薪火相传 (Passing the Flame)** | The Furnace reignites. Souls resume their cycle. You dissolve — your Ember becomes the new kindling. |
| Walk to the Throne and sit | **守炉人 (Furnace-Keeper)** | You take 烛阴's place. Eternal vigil. The realms heal slowly under your silent watch. |
| Strike the Throne until it shatters | **大寂灭 (The Great Silence)** | The Furnace is destroyed. No more cycle. Souls are free — free to live, die, and truly end. |

Endings available may be affected by choices in Level 5-3 (Samsara Path). A player who chose violence in all memories may be locked out of Ending A (sacrifice). A player who showed mercy may be locked out of Ending C (destruction).

### Rewards
| Reward | Details |
|--------|---------|
| 烛阴之鳞 (Zhú Yīn's Scale) | Soul Vessel — Once per rest, cheat death: survive a fatal blow at 1 HP and gain 6s invincibility |
| 终烬碎片 (Final Ember Fragment) | Story completion |
| 烛龙之息 (Torch Dragon Breath) | Legendary spell |
| 1000 Embers | Currency |
| 3 Talent Points | Progression |
| Ending-specific reward | Varies (NG+ item, secret class unlock, or special weapon) |

### Boss Weapon
**烛阴·终末 (Zhú Yīn · The End)** — Ultra Greatsword
- Damage: 85
- Special: **龙息 (Dragon Breath)** — Charged heavy attacks fire a sweeping beam of Ember-light (Starfall Breath, 50% weapon damage, 40 Focus cost)
- Description: *"Forged from the Torch Dragon's final scale. Heavy with the weight of ten thousand fading stars. Each swing whispers of endings."*

---

## Boss Comparison Table

| Boss | Chapter | HP | Phases | Type | Difficulty | Unique Mechanic |
|------|---------|-----|--------|------|------------|-----------------|
| 巨阙 | 1 | 360 | 2 | Construct | Tutorial | Patrol pattern exploitation |
| 刑天 | 2 | 580 | 3 | War God | Medium | Class-specific interaction |
| 九尾 | 3 | 450 | 3 | Fox Spirit | Medium-Hard | Memory Gaze unskippable cutscene |
| 玄霄 | 4 | 520 | 3 | Fallen Immortal | Hard | Post-boss escape sequence |
| 烛阴 | 5 | 800 | 4 | Cosmic Dragon | Very Hard | Ending determined by player action |
