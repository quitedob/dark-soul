# Chapter 1 Boss: 守炉灵·巨阙 (Furnace-Keeper · Giant Gate)

**Chapter:** 1 — 灵墟·觉醒
**Type:** Tutorial Boss
**Soul Vessel Drop:** 守炉之核 (Furnace-Keeper's Core)

---

## Visual Design

A massive humanoid construct (8 meters tall) built from interlocking stone plates with visible seams of glowing orange Ember-light. Its body is architectural — its shoulders resemble temple roofs, its chest is a sealed furnace door, and its head is a carved stone mask with a single glowing eye-ember. It carries a colossal **门刀 (Gate Blade)** — a weapon shaped like a temple gate, wide as a door and thick as a pillar.

As it walks, stone grinds against stone with a deep, resonant sound. Ember-light pulses through its seams with each step, like a heartbeat.

---

## Combat Design

### Phase 1 (100% - 60% HP): The Dutiful Guardian

巨阙 fights like a construct following ancient programming: methodical, predictable, but punishing if disrespected.

**Attacks:**
| Attack | Windup | Active | Recovery | Damage | Tell |
|--------|--------|--------|----------|--------|------|
| **Gate Slam (门击)** | 1.2s | 0.3s | 1.5s | 35 | Raises blade overhead, both hands, pauses, smashes down — creates shockwave in a line |
| **Sweeping Guard (横扫)** | 0.8s | 0.4s | 1.0s | 24 | Low rumble, blade sweeps in a wide 180° arc at knee height |
| **Stone Stomp (踏地)** | 0.6s | 0.2s | 0.8s | 18 | Raises one foot, AoE stagger in 4m radius, no damage beyond stagger |
| **Ember Pulse (烬脉)** | 1.5s | 0.5s | 2.0s | 30 | Chest-furnace glows bright orange, then emits a 360° expanding ring of fire |

**Behavior:**
- Patrols four watch-points in sequence
- Pauses for 3 seconds at each point (safe healing/punish window)
- Always returns to center before executing Ember Pulse
- Can be staggered by breaking its knee-joint hitbox (takes 40 poise damage)

**Tutorial Purpose:** Teaches the player to observe attack patterns, find safe windows, and punish during recovery.

### Phase 2 (60% - 0% HP): Furnace Overload

At 60% HP, 巨阙's programming recognizes a true threat. Its Ember-core overclocks — the seams glow brighter, stone plates shift and crack, and its Gate Blade ignites with Ember-fire.

**New/Modified Attacks:**
| Attack | Windup | Active | Recovery | Damage | Notes |
|--------|--------|--------|----------|--------|-------|
| **Burning Gate Slam** | 1.0s | 0.4s | 1.2s | 45 + fire DoT | Faster than Phase 1, leaves burning ground (3s, 8 dmg/s) |
| **Triple Sweep** | 0.6s ×3 | 0.3s ×3 | 1.5s | 20 ×3 | Three consecutive sweeps — dodge timing tightens with each |
| **Furnace Breath (炉息)** | 2.0s | 2.5s | 2.0s | 12/s beam | Chest-furnace opens, fires a sweeping beam of concentrated Ember-fire. The beam tracks the player slowly — must sprint perpendicularly |
| **Desperate Slam** | 1.8s | 0.5s | 3.0s | 60 | Below 25% HP only. Overhead smash with both arms that cracks the arena floor, creating a permanent hazard zone |

**Behavior Changes:**
- No longer pauses at watch-points; becomes aggressive
- Attack patterns randomize instead of following a sequence
- Moves 20% faster
- Ember Pulse cooldown reduced from 20s to 12s

**Tutorial Purpose:** Teaches the player to adapt when enemy patterns change, recognize phase transitions, and manage increased pressure.

---

## Arena Design

The **守炉殿·内廷 (Inner Sanctum)** is a circular chamber, 30m in diameter, open to the sky. Four stone pillars (non-destructible) provide cover from the Ember Pulse and Furnace Breath. The floor is inscribed with concentric circles representing the cosmic cycle — useful as distance markers.

Four watch-points are marked by extinguished braziers. During Phase 1, 巨阙 pauses at these points. In Phase 2, the braziers ignite one by one, adding fire hazards.

---

## Strategy Hints (Diegetic)

Scattered throughout Chapter 1 are hints about this fight:
- A mural in 1-3 shows a figure attacking the knee of a giant construct
- An alchemist's note in 1-4 mentions that "overloaded furnace cores become unstable if struck directly"
- The Wandering Sage comments at the 1-5 shrine: "It still follows the old patrol routes. Use that."

---

## Rewards

| Reward | Type | Details |
|--------|------|---------|
| 守炉之核 (Furnace-Keeper's Core) | Soul Vessel | Equippable, grants "Ember Guard" — 10% damage reduction for 8s after taking a hit |
| 始烬碎片 (First Ember Fragment) | Key Item | Story progression, unlocks Talent system |
| 守炉人面具 (Furnace-Keeper's Mask) | Head Armor | +10% Ember gain from enemies |
| 巨阙门刀碎片 (Gate Blade Shard) | Crafting | Used to forge the boss weapon (Chapter 3+) |
| 350 Embers | Currency | First major Ember reward |
| 1 Talent Point | Progression | First talent unlock |

---

## Boss Weapon (Forged in Chapter 3+)

**巨阙·守门人 (Giant Gate · Gatekeeper)**
- Weapon Type: Ultra Greatsword (Twin Colossi style)
- Damage: 68 (base)
- Special: **Furnace Pulse** — charged heavy attacks release a short-range Ember shockwave (20% of weapon damage, AoE)
- Description: *"A colossal blade forged from the Gate-Keeper's arm. Heavy as duty, hot as the furnace it once guarded. Each strike echoes with ancient purpose."*
