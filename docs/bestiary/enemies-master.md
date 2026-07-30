# 烬渊 — Enemy Compendium (敌人图鉴)

## Classification System

All enemies are classified by their spiritual nature, which affects their behavior, weaknesses, and Ember yield:

| Type | Chinese | Description | Common Trait |
|------|---------|-------------|--------------|
| 失魂 (Lost Soul) | Shī Hún | Human souls broken by the cycle's collapse | Erratic behavior, vulnerable to Spirit damage |
| 妖 (Yāo) | Yāo | Nature spirits corrupted by Ember-madness | Elemental affinities, vulnerable to opposing element |
| 精 (Jīng) | Jīng | Objects animated by excess Ember absorption | High physical defense, weak to magic |
| 鬼 (Guǐ) | Guǐ | Vengeful dead with unfinished business | Phases through walls, weak to Prayer damage |
| 仙堕 (Fallen Immortal) | Xiān Duò | Cultivators frozen mid-ascension | High all-around stats, vulnerable during specific attack frames |
| 神兽 (Divine Beast) | Shén Shòu | Sacred animals driven mad | Massive HP, specific weak points |
| 神 (Divine) | Shén | True divine beings (bosses only) | Unique mechanics per entity |

---

## Chapter 1: 灵墟·觉醒 — Enemy Roster

### 失魂士兵 (Lost Soul Soldier)
| Attribute | Value |
|-----------|-------|
| **Type** | 失魂 |
| **HP** | 60 |
| **Damage** | 12 |
| **Speed** | 2.8 |
| **Poise** | 20 |
| **Embers** | 20 |
| **Weakness** | Spirit damage (+20%) |
| **Resistance** | Physical (-10%) |

**Description:** The husk of a soldier who died attempting to reach the Celestial Furnace. Still wears tattered armor bearing the insignia of a forgotten kingdom. Attacks with slow, heavily telegraphed sword swings.

**Behavior:** Patrols in small loops. Pauses for 2s before attacking. Retreats after taking 3 consecutive hits.

**Appears In:** 1-1, 1-2, 1-3

---

### 守殿武士 (Temple Guardian Warrior)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 110 |
| **Damage** | 22 |
| **Speed** | 2.2 |
| **Poise** | 40 |
| **Embers** | 45 |
| **Weakness** | Magic damage (+25%) |
| **Resistance** | Physical (+15%), Spirit (-20%) |

**Description:** A stone and metal construct that once guarded the temple's inner corridors. Its programming has degraded — it now attacks anything that moves, including other temple constructs.

**Behavior:** Slow but relentless. Uses heavy overhead slams (1.5s windup) that cannot be parried. After missing a heavy attack, pauses for 2.5s — the safe punish window.

**Appears In:** 1-2, 1-4

---

### 镜中影 (Mirror Shade)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 35 |
| **Damage** | 10 |
| **Speed** | 5.0 |
| **Poise** | 8 |
| **Embers** | 25 |
| **Weakness** | Prayer damage (+30%) |
| **Resistance** | Physical (+50% — phases through attacks) |

**Description:** A spirit trapped within the bronze mirrors of the Hall of Mirrored Truth. It can only emerge when the player's back is turned — a manifestation of the fear of what lurks behind you.

**Behavior:** Only attacks from behind. Appears from mirror surfaces with a brief visual shimmer. If the player faces it for more than 1.5s, it retreats into the nearest mirror.

**Appears In:** 1-3

---

### 炉渣怪 (Furnace Slag Beast)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 150 |
| **Damage** | 18 (melee), 30 (death explosion) |
| **Speed** | 1.5 |
| **Poise** | 60 |
| **Embers** | 60 |
| **Weakness** | Water/Ice damage (+35%) |
| **Resistance** | Fire damage (-50%) |

**Description:** A creature formed from congealed alchemical waste in the temple's destroyed elixir hall. Its body is a shifting mass of cooled slag with glowing orange cracks. Extremely volatile.

**Behavior:** Slowly shambles toward the player. On death, glows brighter for 2s, then explodes (4m radius, 30 damage). The glow is the tell — dodge away when you see it.

**Appears In:** 1-4

---

## Chapter 2: 血铁·战歌 — Enemy Roster

### 失魂士兵·战损 (Lost Soldier — Battle-Worn)
| Attribute | Value |
|-----------|-------|
| **Type** | 失魂 |
| **HP** | 80 |
| **Damage** | 18 |
| **Speed** | 3.0 |
| **Poise** | 25 |
| **Embers** | 30 |
| **Weakness** | Prayer damage (+15%) |
| **Resistance** | — |

**Description:** A stronger variant of the Lost Soldier, these are warriors who fell in the endless battle for Iron Howl Pass. Their armor is more intact, their attacks more aggressive.

**Behavior:** More aggressive than Chapter 1 variant. Will sprint toward the player when at 50% HP. Sometimes fakes a retreat before spinning back into an attack.

**Appears In:** 2-1, 2-2, 2-3

---

### 战犬亡魂 (War Dog Wraith)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 40 |
| **Damage** | 14 |
| **Speed** | 7.0 |
| **Poise** | 5 |
| **Embers** | 18 |
| **Weakness** | Fire damage (+25%) |
| **Resistance** | Ice (-20%) |

**Description:** Spectral hunting dogs that once served the armies of Iron Howl Pass. They hunt in pairs, circling their prey while their partner attacks.

**Behavior:** Always appears in pairs. One circles while the other attacks. If one is killed, the other becomes frenzied (+30% speed, +20% damage) for 15s.

**Appears In:** 2-2, 2-4

---

### 守营鬼卒 (Camp Guard Wraith)
| Attribute | Value |
|-----------|-------|
| **Type** | 失魂 |
| **HP** | 100 |
| **Damage** | 24 |
| **Speed** | 2.5 |
| **Poise** | 45 |
| **Embers** | 50 |
| **Weakness** | Back attacks (+30%) |
| **Resistance** | Frontal attacks (-25% with shield up) |

**Description:** Elite phantom soldiers tasked with guarding the prisoner camp. Carry heavy shields that block frontal attacks. More disciplined than other Lost Souls.

**Behavior:** Advances with shield raised, blocking frontal attacks. Drops shield briefly to attack (1s window). Can be guard-broken by heavy attacks to the shield (8 heavy hits).

**Appears In:** 2-3

---

### 刑具精怪 (Torture Device Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 200 |
| **Damage** | 30 (AoE, 5m radius) |
| **Speed** | 0 (stationary) |
| **Poise** | 100 |
| **Embers** | 70 |
| **Weakness** | Magic damage (+30%) |
| **Resistance** | Physical (+30%) |

**Description:** An iron maiden and rack animated by centuries of absorbed pain and Ember-energy. Cannot move but controls a wide area around itself.

**Behavior:** Stationary hazard. Pulses AoE damage every 6s. Chains extend outward — stepping within 5m triggers a grab that pulls the player closer and deals damage.

**Appears In:** 2-3

---

### 亲卫鬼将 (General's Personal Guard)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 140 |
| **Damage** | 28 |
| **Speed** | 3.5 |
| **Poise** | 50 |
| **Embers** | 90 |
| **Weakness** | Isolation (fighting alone) |
| **Resistance** | Formation bonus (+20% all stats when near other guards) |

**Description:** The personal retinue of 刑天, these elite spirits retain more of their martial skill than any other Lost Souls. They fight with formation tactics.

**Behavior:** Always in groups of 2-3. Attempt to flank and surround. If separated, their AI degrades — they become less coordinated. Kill one to break the formation.

**Appears In:** 2-5

---

### 烽火守魂 (Beacon Keeper Wraith)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 60 |
| **Damage** | 20 (ranged fire) |
| **Speed** | 2.0 |
| **Poise** | 15 |
| **Embers** | 35 |
| **Weakness** | Water/Ice (+35%) |
| **Resistance** | Fire (+40%) |

**Description:** The spirits of soldiers assigned to man the beacon towers. Centuries of staring into flames have fused their essence with fire.

**Behavior:** Keeps distance. Throws fireballs (3s cooldown). If approached, teleports to another beacon platform. Must be chased down or sniped.

**Appears In:** 2-4

---

## Chapter 3: 玉障·迷心 — Enemy Roster

### 幻影蝶 (Illusion Butterfly)
| Attribute | Value |
|-----------|-------|
| **Type** | 妖 |
| **HP** | 25 |
| **Damage** | 8 |
| **Speed** | 3.0 |
| **Poise** | 3 |
| **Embers** | 12 |
| **Weakness** | Fire (+40%) |
| **Resistance** | Spirit (+30%) |

**Description:** Beautiful butterflies with jade-green wings that shed hallucinogenic dust. Harmless-looking but dangerous in numbers.

**Behavior:** Flutters erratically. Dust cloud on death (3m radius, controller inversion for 5s). Kill from range if possible.

**Appears In:** 3-1

---

### 记忆窃贼 (Memory Thief)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 55 |
| **Damage** | 14 (+ Focus drain) |
| **Speed** | 4.5 |
| **Poise** | 12 |
| **Embers** | 28 |
| **Weakness** | Prayer (+35%) |
| **Resistance** | Magic (+25%) |

**Description:** Shadowy figures that feed on memories. Their touch drains not just health but Focus — they steal the player's spiritual energy.

**Behavior:** Ambushes from behind cover. Each hit drains 8 Focus in addition to HP damage. If the player's Focus reaches 0, the Memory Thief becomes empowered (+50% damage).

**Appears In:** 3-2

---

### 回音灵 (Echo Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 70 |
| **Damage** | 16 (copies player's last attack type) |
| **Speed** | 3.5 |
| **Poise** | 20 |
| **Embers** | 32 |
| **Weakness** | Using different attack type than it copied |
| **Resistance** | Same attack type it copied |

**Description:** A spirit born from the residual combat energy in the forest. It learns from what it observes — literally copying the player's last attack pattern.

**Behavior:** Observes for 3s, then mirrors the player's most recent attack. If the player used light attack → it uses fast slashes. Heavy attack → slow but powerful. Switching attack types confuses it (3s cooldown on its adaptation).

**Appears In:** 3-2

---

### 狐火灯妖 (Foxfire Lantern Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 妖 |
| **HP** | 50 |
| **Damage** | 22 (fire) |
| **Speed** | 2.0 (floating) |
| **Poise** | 10 |
| **Embers** | 30 |
| **Weakness** | Water (+40%) |
| **Resistance** | Fire (+50%) |

**Description:** Floating paper lanterns illuminated by foxfire — the spiritual flames associated with fox spirits in Chinese folklore. They drift along set paths during the Fox Wedding.

**Behavior:** Floats along a predetermined route. Erupts in a 3m fire burst when approached within melee range. Best dealt with using ranged attacks or water magic.

**Appears In:** 3-3

---

### 嫁衣女鬼 (Wedding Gown Ghost)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 90 |
| **Damage** | 40 (devastating but avoidable) |
| **Speed** | 6.0 (during procession only) |
| **Poise** | 30 |
| **Embers** | 75 |
| **Weakness** | Stealth — cannot detect hidden players |
| **Resistance** | All (+20% during procession) |

**Description:** A bride who died on her wedding day, now eternally processing through the forest in her red wedding gown. Her wail paralyzes those who hear it.

**Behavior:** Appears only during the Fox Wedding Procession (every 3 minutes). If she spots the player, emits a **paralyzing wail** (5s stun), then rushes in for a devastating embrace. Must be avoided through stealth — hiding behind trees or structures breaks line of sight.

**Appears In:** 3-3

---

### 水中月 (Water Moon)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | 60 |
| **Damage** | 18 |
| **Speed** | 3.0 |
| **Poise** | 15 |
| **Embers** | 35 |
| **Weakness** | Only hittable from reflection platforms |
| **Resistance** | Invulnerable from non-reflection surfaces |

**Description:** An entity that exists in the reflection world of the lake. Visible in the water but intangible — unless the player stands on a "reflection-revealed" platform.

**Behavior:** Attacks from the reflection world. Can hit the player regardless of which surface they stand on. The player can only hit it back when standing on revealed platforms.

**Appears In:** 3-4

---

### 镜花精 (Mirror Flower Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 妖 |
| **HP** | 45 |
| **Damage** | 16 |
| **Speed** | 4.0 |
| **Poise** | 8 |
| **Embers** | 28 |
| **Weakness** | Fire (+30%) |
| **Resistance** | Illusion — creates 3 decoy clones on spawn |

**Description:** A flower spirit that has merged with the reflection magic of the pavilion area. Constantly surrounded by illusory duplicates.

**Behavior:** Spawns with 3 illusion clones that mimic its movements. The real one has a slightly different petal color (observable tell). Clones have 1 HP and explode into blinding light on death.

**Appears In:** 3-4

---

### 迷宫守卫 (Maze Guardian)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 120 |
| **Damage** | 28 |
| **Speed** | 2.0 |
| **Poise** | 55 |
| **Embers** | 50 |
| **Weakness** | Lightning (+30%) |
| **Resistance** | Physical (+25%) |

**Description:** Animate jade statues that guard the Nine-Tails Maze. Carved in the shape of seated lions, they are beautiful and deadly.

**Behavior:** Stationary until approached. Heavy sweeping attacks with long reach. After 3 attacks, overbalances and pauses for 2s.

**Appears In:** 3-5

---

### 迷心妖狐 (Mind-Lost Fox Demon)
| Attribute | Value |
|-----------|-------|
| **Type** | 妖 |
| **HP** | 80 |
| **Damage** | 22 |
| **Speed** | 5.5 |
| **Poise** | 25 |
| **Embers** | 55 |
| **Weakness** | Metal/Lightning (+25%) |
| **Resistance** | Wood/Spirit (+30%) |

**Description:** Fox spirits that have been in the maze so long they've lost all sense of self. They cast confusion magic and attack with feral desperation.

**Behavior:** Opens combat by casting **迷心术 (Mind-Lost Art)** — a projectile that reverses the player's movement controls for 4s. Then rushes in for rapid claw attacks. The confusion projectile has a distinct pink glow — dodge it.

**Appears In:** 3-5

---

## Chapter 4: 天崩·陨落 — Enemy Roster

### 梯卫亡魂 (Stairway Guard Wraith)
| Attribute | Value |
|-----------|-------|
| **Type** | 失魂 |
| **HP** | 100 |
| **Damage** | 20 |
| **Speed** | 2.5 |
| **Poise** | 35 |
| **Embers** | 40 |
| **Weakness** | Lightning (+20%) |
| **Resistance** | Knockback resistant |

**Description:** Guardians of the shattered Heaven-Stairway. Their attacks prioritize knockback over damage — in an area of floating platforms, a push is deadlier than a stab.

**Behavior:** Uses wide, sweeping attacks with high knockback. Position yourself with solid ground behind you before engaging.

**Appears In:** 4-1

---

### 云天鹰 (Cloud Sky Eagle)
| Attribute | Value |
|-----------|-------|
| **Type** | 妖 |
| **HP** | 50 |
| **Damage** | 18 |
| **Speed** | 8.0 (flying) |
| **Poise** | 8 |
| **Embers** | 30 |
| **Weakness** | Ranged attacks (can't be melee'd easily) |
| **Resistance** | Ground-based AoE (-50%) |

**Description:** Giant eagles that nest in the cloud-banks around the floating city. They've grown fat on the spiritual energy leaking from the fallen city.

**Behavior:** Circles overhead, then dive-bombs with a screech (audio tell). After dive, lands for 2s — the punish window. Ranged classes have an easier time.

**Appears In:** 4-1, 4-2

---

### 丹炉精怪 (Elixir Furnace Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 180 |
| **Damage** | 25 (AoE) |
| **Speed** | 0 |
| **Poise** | 80 |
| **Embers** | 65 |
| **Weakness** | Water (+35%) |
| **Resistance** | Fire (+50%) |

**Description:** Bronze alchemy furnaces animated by centuries of boiling elixirs. They vent toxic vapor in rhythmic pulses.

**Behavior:** Stationary. Pulses status-effect clouds every 8s (rotates between: slow, damage reversal, inverted controls). Must be destroyed to clear safe passage.

**Appears In:** 4-2

---

### 炼丹堕仙 (Alchemy Fallen Immortal)
| Attribute | Value |
|-----------|-------|
| **Type** | 仙堕 |
| **HP** | 80 |
| **Damage** | 28 (ranged) |
| **Speed** | 2.0 |
| **Poise** | 20 |
| **Embers** | 70 |
| **Weakness** | Melee (limited close-range options) |
| **Resistance** | Magic (+30%) |

**Description:** A cultivator who specialized in alchemical immortality. Frozen mid-ascension, their body constantly emits elixir vapor. They throw explosive flasks with deadly accuracy.

**Behavior:** Keeps distance. Throws three types of flasks: explosive (damage), freezing (slow), and toxic (DoT cloud). Rush them down — they have no melee attacks.

**Appears In:** 4-2

---

### 书精 (Book Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 30 |
| **Damage** | 10 |
| **Speed** | 7.0 |
| **Poise** | 2 |
| **Embers** | 15 |
| **Weakness** | Fire (+50% — paper burns) |
| **Resistance** | Physical (+30% — small and fast) |

**Description:** Animate books from the immortal library. Their pages flutter like wings. Harmless individually, dangerous in swarms.

**Behavior:** Swarms in groups of 4-6. Each hit steals one random consumable from the player's inventory (returned on kill). Kill quickly with fire or AoE.

**Appears In:** 4-3

---

### 守阁仙魂 (Library Guardian Spirit)
| Attribute | Value |
|-----------|-------|
| **Type** | 仙堕 |
| **HP** | 130 |
| **Damage** | 32 |
| **Speed** | 3.5 |
| **Poise** | 40 |
| **Embers** | 95 |
| **Weakness** | Varies — takes bonus damage from the class it's NOT currently copying |
| **Resistance** | Resistant to the class it IS copying |

**Description:** The spirit of a librarian-cultivator who has absorbed techniques from countless martial manuals. It adapts its fighting style to counter the player.

**Behavior:** Every 20s, switches to a fighting style that mirrors one of the four player classes. While copying 狂战士 → resistant to melee, weak to magic. Copying 玄法师 → resistant to magic, weak to melee. Etc.

**Appears In:** 4-3

---

### 残缺仙体 (Broken Immortal Body)
| Attribute | Value |
|-----------|-------|
| **Type** | 仙堕 |
| **HP** | 150 |
| **Damage** | 35 |
| **Speed** | 2.0 |
| **Poise** | 60 |
| **Embers** | 85 |
| **Weakness** | Head (weak point — +50% damage) |
| **Resistance** | Body (+30%) |

**Description:** The most common Fallen Immortal — a cultivator whose body began transforming but stopped partway. Half-formed wings, partial energy-body, incomplete transcendence.

**Behavior:** Slow, heavy hits. Each attack leaves it unbalanced for 1.5s. Aim for the head — the only part that fully transformed and is thus vulnerable.

**Appears In:** 4-4, 4-5, 4-6

---

## Chapter 5: 烬座·归墟 — Enemy Roster

### 烬岸游魂 (Ember Shore Drifter)
| Attribute | Value |
|-----------|-------|
| **Type** | 失魂 |
| **HP** | 50 |
| **Damage** | 0 (passive) |
| **Speed** | 1.0 |
| **Poise** | — |
| **Embers** | 0 |
| **Weakness** | — |
| **Resistance** | — |

**Description:** Harmless souls drifting toward the Throne. They ignore the player unless attacked.

**Behavior:** Passively drifts. Becomes hostile only if the player attacks first. Killing an innocent soul has **karmic consequences** — the final boss gains additional dialogue condemning your cruelty.

**Appears In:** 5-1

---

### 倒悬守卫 (Inverted Guardian)
| Attribute | Value |
|-----------|-------|
| **Type** | 精 |
| **HP** | 160 |
| **Damage** | 36 |
| **Speed** | 2.5 |
| **Poise** | 55 |
| **Embers** | 75 |
| **Weakness** | Gravity magic (+40%) |
| **Resistance** | Physical (+25%) |

**Description:** Armored constructs that patrol the inverted architecture of the Furnace's broken structure. They navigate inverted surfaces as easily as flat ground.

**Behavior:** Walks on ceilings and walls. Attacks come from unexpected angles. Using Chapter 4's gravity manipulation evens the playing field.

**Appears In:** 5-2

---

### 烬蝠 (Ember Bat)
| Attribute | Value |
|-----------|-------|
| **Type** | 妖 |
| **HP** | 35 |
| **Damage** | 16 |
| **Speed** | 9.0 |
| **Poise** | 3 |
| **Embers** | 22 |
| **Weakness** | Ice (+30%) |
| **Resistance** | Fire (+40%) |

**Description:** Bat-like creatures born from cooled Ember-ash. They can cling to any surface — floor, wall, ceiling — and attack from any angle.

**Behavior:** Swarms in groups of 4-7. Attacks from all directions simultaneously. Lock-on helps but can be disorienting. AoE attacks are most effective.

**Appears In:** 5-2, 5-3

---

### 歧路守魂 (Forked Path Guardian)
| Attribute | Value |
|-----------|-------|
| **Type** | 鬼 |
| **HP** | Variable (weaker version of corresponding boss) |
| **Damage** | ~60% of original boss |
| **Speed** | Same as original boss |
| **Poise** | ~50% of original boss |
| **Embers** | 100 |
| **Weakness** | Same as original boss |
| **Resistance** | Same as original boss |

**Description:** Spectral echoes of previous chapter bosses, manifesting at the crossroads of possibility.

**Variants:**
- **歧路·巨阙** — Weaker Furnace-Keeper echo
- **歧路·刑天** — Weaker Blood General echo
- **歧路·九尾** — Weaker Nine-Tails echo
- **歧路·玄霄** — Weaker Fallen Immortal echo

**Appears In:** 5-3

---

### 可能性之影 (Shadow of Possibility)
| Attribute | Value |
|-----------|-------|
| **Type** | ??? (Unknown) |
| **HP** | 100 |
| **Damage** | 28 |
| **Speed** | 4.5 |
| **Poise** | 25 |
| **Embers** | 60 |
| **Weakness** | Certainty — attacking without hesitation |
| **Resistance** | Indecision — standing still increases its damage |

**Description:** A being from outside the cycle — a manifestation of paths not taken, choices not made, lives not lived. Its form constantly shifts between the player's four possible class appearances.

**Behavior:** Grows stronger if the player hesitates (doesn't attack for 3s+). Its attack pattern randomizes every 10s. Commit to aggression and it becomes manageable.

**Appears In:** 5-3

---

### 铸魂者残影 (Soul-Forger Remnant)
| Attribute | Value |
|-----------|-------|
| **Type** | 神 |
| **HP** | 200 |
| **Damage** | 40 |
| **Speed** | 3.5 |
| **Poise** | 70 |
| **Embers** | 150 |
| **Weakness** | Trial-specific |
| **Resistance** | All (+15%) |

**Description:** The lingering essence of a dead Soul-Forger. Not hostile by nature — they are guardians testing if the Ember Scion is worthy of facing 烛阴.

**Behavior:** Offers a trial rather than a fight to the death. Each remnant tests a different skill. See Chapter 5 overview for trial details.

**Appears In:** 5-4

---

## Enemy Stats Quick Reference

| Chapter | Total Enemy Types | Total Variants | Elite Enemies | Sub-Bosses |
|---------|------------------|----------------|---------------|------------|
| 1 | 4 | 4 | Temple Guardian | — |
| 2 | 6 | 6 | General's Guard | — |
| 3 | 9 | 9 | Maze Guardian, Wedding Gown Ghost | — |
| 4 | 7 | 7 | Library Guardian, Broken Immortal | 玄霄·嗔念, 玄霄·执念 |
| 5 | 6 | 9 (includes 4 boss echoes) | Soul-Forger Remnants | 歧路守魂×4 |
| **Total** | **32** | **35** | — | — |
