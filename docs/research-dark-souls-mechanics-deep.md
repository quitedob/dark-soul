# Research — Dark Souls Mechanics Deep-Dive: Frame Data, Poise Math, and Godot Implementation

**Date:** 2026-07-30
**Status:** `ACTIVE` — research complete; frame data, poise formulas, and Godot patterns documented
**See also:** [`research-dark-souls-design.md`](research-dark-souls-design.md) — 12-topic DS design audit, vertical slice checklist
**See also:** [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) — per-style weapon tuning, hit-stop, hyper armor, audio profiling
**See also:** [`research-github-godot-soulslike-ecosystem.md`](research-github-godot-soulslike-ecosystem.md) — GitHub repos, Godot Asset Library templates, ecosystem survey
**See also:** [`research.md`](research.md) — original vertical slice research, Godot API mapping

Research conducted 2026-07-30. This report provides frame-level detail on Dark Souls combat mechanics — i-frame durations, parry window frame counts, poise health mathematics with worked examples, attribute scaling curves, and corresponding Godot implementation patterns. It complements the broader design audit in [`research-dark-souls-design.md`](research-dark-souls-design.md) with the precise numerical and architectural depth needed to implement these systems in GDScript.

---

## Source Reliability Disclaimer

This report uses a three-tier evidence classification:

| Label | Criteria |
|---|---|
| **Observable rule** | Verifiable through game executable behavior, community frame-data analysis (wikidot, fextralife), or official guide data. Frame counts are version/patch-dependent and should be treated as directional. |
| **Developer intent** | Requires named developer quotation from a datable, accessible interview or official publication. |
| **Analysis** | Interpretation built from observable mechanics. Not developer-confirmed; must be labeled as analysis. |

Frame data values in this report are **community-estimated at 30 FPS reference** (DS1 baseline) with 60 FPS equivalents provided. Exact frame counts vary by game version (DS1 vs DS3 vs Elden Ring) and patch. The ratios and relative differences between categories are more reliable than absolute numbers. All values should be treated as tuning starting points, not specifications.

---

## 1. Core Design Philosophy: Classical Revival and Mechanical Narrative

### 1.1 Challenge as Catalyst for Satisfaction

Hidetaka Miyazaki's design philosophy fundamentally rejects the "dynamic difficulty adjustment" and "hand-holding tutorials" prevalent in modern commercial games. The core logic rests on absolute respect for the player's intelligence — extreme difficulty serves as a catalyst, forcing the player through repeated failure, deep system learning, and muscle memory to ultimately achieve an incomparable sense of accomplishment and what scholars call the "ludic sublime."

### 1.2 Return to NES-Era Classical Design

In action design, Dark Souls is effectively a return to NES-era classical game design. Modern action games (e.g., Batman: Arkham series) typically employ "magnetic" combat systems where pressing attack causes the character to automatically slide toward the enemy with angle correction. Dark Souls deliberately strips away these底层 assists — the system decomposes actions into discrete, irrevocable input commands. If the player presses attack at the wrong moment, or faces the wrong direction, the character swings uncompromisingly at empty air, fully exposing their vulnerability.

**Analysis:** This "input-is-what-you-see" philosophy demands precise spacing and positioning from the player, ensuring the game is "hard but absolutely fair."

### 1.3 Godot Implementation: Input Buffering and Uninterruptible State Machines

Replicating this classical control feel in Godot requires two technical pillars: **input buffering** and **non-cancellable state machines**.

Developers cannot rely on simple `if-else` chains to control character state. A rigorous architecture built on `AnimationTree` and `AnimationNodeStateMachine` is required. Before specific attack animation frames conclude, the system must completely block player movement or dodge inputs until the recovery phase enters its cancellation window. This is implemented in code by reading the animation player's current position or keyframe-triggered signals.

**Key principle:** True Souls-like feel often comes not from more complex inputs but from stricter "when you cannot act." The game communicates respect by being predictable, not by being lenient.

### 1.4 Environmental Narrative and Narrative Architecture

Dark Souls' other cornerstone is **environmental storytelling** (also called **embedded narrative**). Traditional RPGs rely on lengthy NPC dialogue and cutscenes to deliver plot; Souls games fragment their vast worldbuilding into pieces scattered across scene arrangement, item descriptions, and even enemy placement.

Scholar Henry Jenkins' concept of **narrative architecture** finds perfect expression in Souls games. The narrative is not a linear temporal structure but a sum of spatial information. For example, when facing Aldrich, Devourer of Gods, the game never plays an exposition cutscene. Instead, the player defeats the boss, reads "Aldrich's Ruby" in the item description, and observes the corrupted visual spectacle of Anor Londo — assembling the tragic history of this Lord of Cinder themselves.

**Godot implementation relevance:** Environmental narrative demands that levels are not mere combat backdrops but information-carrying databases. Using Godot's `MeshLibrary` and modular scene instantiation, developers place item nodes with independent data structures at every corner and beside every corpse, using the inventory system's text dictionary to deliver fragments of history without words.

---

## 2. Level Design: Spatial Memory and Vertical Box-Garden Topology

### 2.1 Interconnected World and Circular Time

The original Dark Souls' map design — especially the upper half centered on Firelink Shrine as hub — remains a pinnacle of 3D level design. Its defining characteristics are extreme **verticality** and **interconnectivity**.

The game deliberately removes minimaps and quest markers, forcing the player to build a cognitive map using environmental landmarks and sightlines. The brilliance lies in precise manipulation of the player's psychological state: when the player, exhausted and out of supplies in a dangerous unknown area, suddenly discovers a one-way door or a kickable ladder — and passes through the shortcut to find themselves back at the safe zone (bonfire) they left hours ago — the emotional drop from extreme anxiety to instant relief constitutes an incomparable play experience.

**Analysis:** This design of folding game time through spatial shortcuts is characterized in academic literature as the spatial-narrative loop of "looping time and end time."

### 2.2 Godot Graybox Prototyping and Scene Management

To achieve such complex vertical box-garden structure in Godot:

1. **Graybox/Blockout phase:** Use Godot's built-in CSG (Constructive Solid Geometry) nodes or `GridMap` tools for rough level prototyping. Adjust sightline heights across different zones and place vision-blocking cover to precisely control which landmarks are visible from specific positions — achieving invisible skill-gate guidance.

2. **Scene streaming:** Because Souls maps are vast and seamlessly connected, Godot's scene streaming is critical. Developers cannot load the entire world into memory at once. Instead, `Area3D`-based trigger volumes detect player proximity to specific passages or elevators and asynchronously load adjacent scene-tree chunks on background threads — technically guaranteeing immersive, seamless exploration.

### 2.3 Sightline and Exploration Guidance

Use a three-layer structure:
- **Distant landmark:** Tells the player "that's where I'm going."
- **Mid-range threat:** Creates cautious advance.
- **Close-range reward:** Lures branch exploration.

Don't put glowing chests at every corner. Don't put every good item on the main path center-line. Souls-like exploration pleasure comes from the player interpreting risk as opportunity themselves.

---

## 3. Action Mechanics: Frame Data Micro-Game

Souls combat depth is built on rigorous action frame data. Wind-up (telegraph), invulnerability frames (i-frames), parry windows, and recovery frames constitute the entirety of the micro-game between player and enemy.

### 3.1 Root Motion: The Necessity of Animation-Driven Displacement

In traditional action games, character displacement is typically code-controlled (e.g., directly modifying `velocity`), with animation serving as a visual overlay atop movement — easily producing the "ice-skating" phenomenon. In Souls-like games, to convey the physical weight and inertia of heavy weapons, **root motion** is an essential底层 technology.

In Godot 4, mature Souls-like templates (e.g., catprisbrey's modular template) deeply integrate root motion. The developer bakes absolute character displacement into the root bone's animation track in Blender. When the animation plays through Godot's `AnimationTree`, the system extracts the root bone's displacement and rotation deltas, applying them to the `CharacterBody3D`'s actual physics coordinates in `_physics_process`.

**Key insight:** The distance a character steps forward is entirely determined by the animator, giving every attack and dodge unparalleled solidity and weight.

### 3.2 Dodge Mechanics and I-Frame Matrix

The dodge roll is Dark Souls' core damage-avoidance tool. The game divides rolls into three strict tiers based on equipment load percentage. Based on 30 FPS baseline logic, i-frame data directly determines survival probability.

#### Roll Type Comparison

| Roll Type | Equip Load Threshold | 30 FPS I-Frames | 60 FPS Equivalent | Characteristics |
|---|---|---|---|---|
| Fast Roll | < 25% | 13 frames (~0.433s) | 26 frames | Longest displacement, shortest recovery, extreme mobility |
| Mid Roll | 25% – 70% | 11 frames (~0.366s) | 22 frames | Moderate displacement, medium recovery — the balanced sweet spot |
| Fat Roll | > 70% | 9 frames (~0.300s) | 18 frames | Very short displacement, back slams ground, catastrophic long recovery |
| Ninja Flip (Dark Wood Grain Ring) | < 25% (with ring) | 15 frames (~0.500s) | 30 frames | Motion changes to ninja backflip; widest i-frame window in the game |

#### Design Analysis: The "Roll Through" Philosophy

Compared to Monster Hunter: World (basic roll i-frames: ~0.267s), Dark Souls grants the player a generous 0.433s of invulnerability. This design does not aim to lower difficulty — it encourages the player to **roll through attacks**. If the character's i-frames completely cover the overlap time of the enemy weapon hitbox, the player takes zero damage. Conversely, if the player rolls backward out of fear, the i-frames often expire while the enemy's weapon hitbox still overlaps the character model — resulting in brutal "roll catching."

**Godot implementation:** The dodge state must activate a short `invulnerable = true` window within a longer movement state. The i-frame duration is a tuning constant, not a code structure. In `_physics_process`, while `invulnerable` is true, incoming damage calls are silently discarded.

```gdscript
# Dodge state — simplified
var i_frame_remaining := 0.0
const I_FRAME_DURATION := 0.366  # mid-roll: 11 frames at 30fps

func start_dodge() -> void:
    i_frame_remaining = I_FRAME_DURATION
    invulnerable = true
    stamina -= dodge_cost
    stamina_regen_cooldown = 0.6

func _physics_process(delta: float) -> void:
    if i_frame_remaining > 0.0:
        i_frame_remaining -= delta
        if i_frame_remaining <= 0.0:
            invulnerable = false
```

### 3.3 Parry and Riposte: Extreme Reaction Windows

The parry mechanic demands the player deflect an enemy attack within an extremely tight time window in exchange for a massive-damage riposte. Different parry tools differ dramatically in startup frames and active frames.

#### Parry Tool Frame Data

| Parry Tool | Startup (Frames) | Active Parry (Frames) | Recovery (Frames) | Tactical Analysis |
|---|---|---|---|---|
| Caestus (Fist) | 8 | 8 | Medium | Fastest startup — suited for reaction parry. But whiffing drains all stamina and takes extreme damage. |
| Target Shield / Buckler | 8 | 10 | Very Long | Fast startup + longest active window. Highest forgiveness professional parry tool, but whiff punish is brutal. |
| Small Shield | 12 | 12 | Medium | Long active time but slower startup. Requires prediction. Offers some general block capability. |
| Medium Shield | 14 | ~6 | Very Long | Slowest startup + smallest window. Only viable for "setup parry" — blocking the first hit, then parrying the second. |

#### Partial Parry Mechanics

When an enemy attack (even an unparryable giant arrow) lands outside the parry active frames but within specific animation buffer frames, the player takes partial damage and heavy stamina drain but does NOT suffer hitstun (stagger), and gains extra hyper armor during this period. Speedrunners frequently exploit this advanced mechanic to tank lethal attacks and force through defensive lines.

**Godot implementation consideration:** Ashen Hollow's Reliquary Guard style has a parry input. Current implementation uses a uniform parry window. For differentiation, the parry window duration should be tunable per-shield-type via a `Resource` field. Smaller shields get wider windows; medium shields get narrower but can block first.

---

## 4. Poise and Hyper Armor Calculation Model

The poise system is the most complex and controversial module in Dark Souls'底层 logic. From DS1's "passive poise" (heavy armor = stand and tank hits) to DS3's "dynamic hyper armor," the system evolved to extreme precision.

### 4.1 Hidden "Poise Health" and Multiplier Formula

In Dark Souls 3, the poise value displayed on armor no longer provides absolute stagger immunity. Instead, it converts to a **Poise Damage Reduction (PDR)** percentage. The system runs a hidden **Poise Health (PH)** variable, capped at 100. Poise only activates when the player swings a weapon with hyper armor properties (e.g., greatswords, ultra greatswords).

Each weapon's specific attack animation provides a **Weapon Attack Modifier (WAM)**. The formula determining whether the player is staggered mid-swing:

```
Settled Poise Health = (Base_PH × WAM) − [(1 − PDR) × Enemy_Poise_Damage]
```

### 4.2 Worked Example

**Scenario:** Player two-hands a greatsword. The animation's WAM is 21.1% (i.e., at swing start, PH resets to 100 × 0.211 = 21.1). The player is hit by an enemy fireball with base Poise Damage (PD) of 30. The player wears heavy armor with displayed poise of 43.72 (i.e., PDR = 43.72%).

1. Actual poise damage taken: `30 × (1 − 0.4372) = 30 × 0.5628 = 16.884`
2. Settled poise health: `21.1 − 16.884 = 4.216`
3. Result > 0 → poise **not broken**. Character tanks the fireball damage and completes the greatsword swing (hyper armor triggered successfully).

### 4.3 Poise Reset Mechanics and Breakpoints

Critical additional rule: after taking one hit, the next swing's poise health resets to only **80%** (unless specific weapon arts restore it to 100%). This means consecutive trades require progressively higher armor poise to avoid being interrupted.

Key breakpoints (DS3 community-verified):

| Poise Threshold | Effect |
|---|---|
| **61 poise** | Critical breakpoint. Hyper armor can tank most light-weapon continuous attacks or a single greatsword light attack. |
| **52 poise** | For great-hammer users: 52 displayed poise ensures two-handed swings are never interrupted even against enemy heavy weapons — because great-hammers provide inherently high WAM base. |

### 4.4 Godot Implementation

Replicating this system requires a stats manager to monitor attack state machine transitions in real time, dynamically adjust `poise_health`, and during `take_damage()`, perform poise-damage float subtraction first. Only when the result ≤ 0 should the current animation be forcibly interrupted and the stagger state triggered.

```gdscript
# poise_component.gd — simplified
var poise_health: float = 0.0
var base_poise_health: float = 100.0
var poise_reset_mult: float = 1.0   # 1.0 on fresh engagement, 0.8 after one hit
var pdr: float = 0.0                 # derived from equipped armor

func activate_hyper_armor(wam: float) -> void:
    poise_health = base_poise_health * wam * poise_reset_mult

func apply_poise_damage(enemy_poise_damage: float) -> bool:
    var actual_damage := enemy_poise_damage * (1.0 - pdr)
    poise_health -= actual_damage
    if poise_health <= 0.0:
        poise_reset_mult = 1.0   # reset on break
        return true               # poise broken → stagger
    poise_reset_mult = 0.8       # next swing only gets 80%
    return false                  # hyper armor holds

func reset_poise() -> void:
    poise_health = 0.0
    poise_reset_mult = 1.0
```

**Ashen Hollow relevance:** Current implementation has no poise/hyper-armor system. This is documented as a pending recommendation in [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) (Section 11, recommendation #5). Twin Colossi style should be unstaggerable during active frames — this is the primary reward for surviving the long wind-up.

---

## 5. Weapon Systems, Attribute Scaling, and Godot Soft-Coded Architecture

### 5.1 Attribute Scaling Mathematics

Souls games feature vast weapon arsenals. Damage depth derives from complex attribute scaling: weapons provide bonus Attack Rating (AR) based on Strength (STR), Dexterity (DEX), Intelligence (INT), and Faith (FTH).

Scaling is non-linear and follows diminishing returns with defined soft caps and hard caps:

| Attribute Range | Scaling Behavior |
|---|---|
| 10 – 40 | Maximum per-point returns — every stat point significantly increases AR |
| 40 – 60 | Diminishing returns begin; per-point value drops noticeably |
| 60 – 99 | Cliff-drop: per-point returns approach zero until the absolute hard cap at 99 |

#### Two-Handing Strength Modifier

When a weapon is two-handed, the character's Strength is internally multiplied by **1.5×**. This dramatically impacts build planning:

- **27 STR:** Two-handing → effective 27 × 1.5 = 40.5 → perfectly hits the first soft cap.
- **66 STR:** Two-handing → effective 66 × 1.5 = 99 → reaches the absolute hard cap, saving massive points for Vigor or Endurance.

#### Infusion Mechanics

Infusions fundamentally alter scaling curves:
- **Heavy infusion:** Completely removes DEX scaling, maximizes STR scaling. Any points in DEX become wasted sunk cost.
- **Sharp infusion:** Maximizes DEX, removes STR scaling.
- **Quality infusion:** Balances C/C scaling for STR+DEX hybrids.
- **Elemental infusions:** Add INT/FTH scaling, reduce physical scaling.

### 5.2 Soft-Coded Weapon Architecture in Godot

In a Souls-like with hundreds of weapons, writing independent `if-else` logic per weapon produces bloated, unmaintainable code. The modern Godot framework pattern (exemplified by BreadbinEngine) offers an elegant **highly soft-coded** solution.

Weapon combo strings are not hardcoded in the character controller. Each weapon is defined as a standalone `Resource` file containing a `String` array of animation names:

```gdscript
# sword_resource.tres — example data
[resource]
script = preload("res://weapon_data.gd")
weapon_id = "straight_sword_01"
light_chain_anims = ["sword_R1_01", "sword_R1_02", "sword_R1_03"]
heavy_chain_anims = ["sword_R2_01", "sword_R2_02"]
stamina_light = [22.0, 24.0, 28.0]
stamina_heavy = [35.0, 40.0]
str_scaling = 0.65
dex_scaling = 0.45
```

When the player presses attack, the combat state machine records the current combo index, extracts the corresponding animation name from the string array, and passes it directly to the main `AnimationPlayer` for playback.

```gdscript
# combat_state_machine.gd — simplified combo logic
var combo_index := -1
var current_weapon: WeaponData

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("light_attack") and can_attack():
        combo_index = (combo_index + 1) % current_weapon.light_chain_anims.size()
        var anim_name := current_weapon.light_chain_anims[combo_index]
        var stamina_cost := current_weapon.light_stamina_costs[combo_index]
        execute_attack(anim_name, stamina_cost)

func execute_attack(anim_name: String, cost: float) -> void:
    if stamina < cost:
        return
    stamina -= cost
    anim_tree["parameters/playback"].travel(anim_name)
```

**Critical benefit:** By fully decoupling data from logic, designers or mod developers don't need to write a single line of GDScript. They configure strings and attach corresponding animation files in the main `AnimationLibrary` to rapidly create new weapons with unique derivative movesets.

**Ashen Hollow relevance:** All five combat styles currently use uniform timing and costs. Per-style `Resource`-based differentiation is the highest-priority pending recommendation (see [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md), Section 11).

---

## 6. Boss Battle Design: From Visual Reaction to Psychological Warfare

Souls boss battles are the culmination of the entire system design. Across the series, boss AI logic evolved from simple "attack-recovery" turn-based patterns into complex psychological pressure systems.

### 6.1 Delayed Attacks and Positioning Control

Modern Souls-like games (especially Elden Ring) heavily employ "fast-slow blade" design. Bosses hold weapons in physically unintuitive extended wind-ups, then unleash lethal strikes in an instant. This specifically punishes **panic rolling** triggered by instinctive fear.

The design deliberately blurs dodge payoff, forcing players to learn **positioning-based evasion**. Against Malenia's signature Waterfowl Dance or Commander Niall's boar charge, pressing dodge alone guarantees death. Correct solutions:
- Strictly control engagement distance during neutral.
- Pre-emptively unlock and sprint in the opposite direction when anticipating the super move.
- Precisely hug specific blind spots (e.g., Malenia's right leg) for angled blind-rolling.

The system demands the player not only identify fake punish windows but also execute the dodge on the final frames of the attack animation.

### 6.2 Input Reading and AI State Trees

Another notorious but strategically deep Souls boss design is **input reading** (or **animation reading**). When the player's HP drops low and they instinctively backstep and press heal, the boss AI captures this input state on the same frame and immediately triggers an extremely lethal lunge or fireball as punishment.

The essence: strip the player's unilateral control of combat rhythm. The player cannot heal whenever they want — they must treat the heal window as precious as an attack window, using it only during the boss's genuine whiff recovery.

### 6.3 Godot AI Implementation

In Godot engines (following BreadbinEngine's AI patterns), this mechanism is implemented by exposing probability adjustment variables in the Inspector. Developers set "interrupt thresholds" and "chase probabilities" (chance values). When the AI node detects the player state machine's `current_state` switching to `healing`, the behavior tree or FSM triggers a high-priority interrupt event, forcing the boss to immediately switch from patrol to charge-attack state.

```gdscript
# boss_brain.gd — input-reading heuristic (pseudocode)
func decide_next_action(dist: float, player_state: String, my_hp_ratio: float) -> StringName:
    # Phase transition gate
    if my_hp_ratio < 0.5 and phase == Phase.PHASE_1:
        phase = Phase.PHASE_2
        return &"phase_transition"

    # Input reading: punish healing
    if player_state == "healing" and dist < 8.0 and cooldowns["gap_close"] <= 0.0:
        return &"gap_close"

    # Distance-bracket attack selection
    if dist < 2.5 and cooldowns["slash_combo"] <= 0.0:
        return &"slash_combo"
    if dist > 5.0 and cooldowns["gap_close"] <= 0.0:
        return &"gap_close"

    # Phase 2 new mechanics
    if phase == Phase.PHASE_2 and cooldowns["aoe_burst"] <= 0.0:
        return &"aoe_burst"

    return &"reposition"
```

**Ashen Hollow relevance:** The Cinder Guardian already has phase transition (≤50% HP) and distance-bracket attack selection. Adding a healing-punish tendency would align it more closely with the behavioral sophistication described here.

---

## 7. Core Godot Architecture: Technical Practice

Translating grand design concepts into reality depends on底层 code architecture. The open-source community has explored a highly standardized Souls-like development paradigm in Godot 4.

### 7.1 Collision Detection: Hitbox and Hurtbox with Duck Typing

Frame-precise collision detection is the foundation of Souls-like impactful combat feel. In Godot 4, this system is built on two core nodes: `HitArea3D` (attack hitbox) and `HurtArea3D` (damage receiver).

**One-way collision scanning optimization:**

| Node | `collision_layer` | `collision_mask` | Role |
|---|---|---|---|
| HitArea3D | 2 (custom Hitbox layer) | 0 | Damage dealer — does NOT scan for others |
| HurtArea3D | 0 | 2 (custom Hitbox layer) | Damage receiver — continuously monitors for incoming damage |

The HurtArea3D uses GDScript duck typing for elegant decoupling and safety filtering:

```gdscript
# hurt_area_3d.gd
class_name HurtArea3D extends Area3D

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(hit_area: Area3D) -> void:
    # Duck-type check: ensure the entering area IS a hitbox
    if hit_area is HitArea3D and owner.has_method("take_damage"):
        owner.take_damage(hit_area.damage)
```

To prevent false hits when not attacking, the Hitbox's `CollisionShape3D` defaults to `disabled`. The developer places keyframes in the `AnimationPlayer` at specific attack frames, activating collision only during the fraction of a second when the weapon pose actually threatens — achieving extremely precise hit windows.

### 7.2 Lock-On System

In 3D combat, the lock-on system ensures the player can strafe around a target. As seen in community systems like G4-Super-3D-Targeting-System, lock-on logic is far more than a simple camera look-at call.

**Target filtering:** A large-range sensor `Area3D` gathers nearby enemies. Using screen-space transformation and vector dot product mathematics, the system selects the target with the smallest angle from the screen-center crosshair.

**Smooth tracking:** Once locked, the code strips the mouse of free camera control. The `SpringArm3D` attached to the player continuously updates its orientation. To avoid disorienting instant camera snaps, the code must not use a hard `look_at()` — instead, it uses quaternion spherical linear interpolation (`slerp`) at a constant rotation speed (`targeting_speed`) to smoothly track the enemy's core bone position, constructing a cinematic confrontation perspective.

```gdscript
# lock_on.gd — simplified target selection
func _collect_lock_candidates() -> Array[Node3D]:
    var candidates: Array[Node3D] = []
    for body in $SensorArea.get_overlapping_bodies():
        if body.is_in_group("enemy") and body.has_method("get_lock_point"):
            candidates.append(body)
    return candidates

func _score_target(candidate: Node3D) -> float:
    var to_target := candidate.get_lock_point() - camera.global_position
    var cam_forward := -camera.global_transform.basis.z
    var angle := to_target.normalized().dot(cam_forward)
    var dist := to_target.length()
    # Prefer closer, more center-screen targets
    return angle - (dist * 0.01)

func _smooth_look_at(target_pos: Vector3, delta: float) -> void:
    var desired := (target_pos - spring_arm.global_position).normalized()
    var current := -spring_arm.global_transform.basis.z
    var slerped := current.slerp(desired, targeting_speed * delta)
    spring_arm.look_at(spring_arm.global_position + slerped, Vector3.UP)
```

### 7.3 Stamina Management with Delayed Regeneration

Dark Souls is an art of resource management, and the green bar (stamina) is the core currency. Every action consumes stamina, and stamina does NOT immediately regenerate after stopping — there is a punishing delay window.

**Anti-pattern — do NOT use this:**
```gdscript
# DANGEROUS: await in complex combat state machines causes coroutine chaos
await get_tree().create_timer(1.5).timeout
stamina_regenerating = true
```

**Industry-standard best practice — frame-counting timer in `_physics_process`:**

```gdscript
var stamina := 100.0
var max_stamina := 100.0
var stamina_cooldown := 0.0
const REGEN_DELAY := 1.5
const REGEN_RATE := 20.0

func consume_stamina(amount: float) -> void:
    stamina -= amount
    stamina_cooldown = REGEN_DELAY  # Every stamina spend mercilessly resets the delay

func _physics_process(delta: float) -> void:
    if stamina_cooldown > 0.0:
        stamina_cooldown -= delta  # Countdown — stamina does NOT regenerate
    else:
        # Countdown complete — safe, frame-independent regeneration
        stamina = minf(stamina + (REGEN_RATE * delta), max_stamina)
```

This rigorous GDScript code faithfully reproduces the Souls punishment mechanism: if the player panic-mashes the dodge button at zero stamina, `stamina_cooldown` is continuously reset, making stamina recovery permanently unreachable, and death inevitable.

**Ashen Hollow relevance:** The current implementation gates stamina regeneration behind `state == State.LOCOMOTION` (fixed in commit `7f30d4f`). The `_physics_process` frame-counting pattern above is already in use — this is correct.

---

## 8. Summary of All Frame Data Reference Tables

### Dodge Roll I-Frames

| Roll Type | Equip Load | 30 FPS I-Frames | Duration (seconds) | 60 FPS Equivalent |
|---|---|---|---|---|
| Fast Roll | < 25% | 13 | ~0.433 | 26 |
| Mid Roll | 25–70% | 11 | ~0.366 | 22 |
| Fat Roll | > 70% | 9 | ~0.300 | 18 |
| Ninja Flip | < 25% + ring | 15 | ~0.500 | 30 |

### Parry Tool Frame Data

| Tool | Startup | Active | Recovery | Best Use |
|---|---|---|---|---|
| Caestus | 8f | 8f | Medium | Reaction parry |
| Target Shield | 8f | 10f | Very Long | Highest forgiveness |
| Small Shield | 12f | 12f | Medium | Prediction + block |
| Medium Shield | 14f | ~6f | Very Long | Setup parry only |

### Weapon Attack Timing Ratios (Approximate, 60 FPS)

| Attack Type | Wind-up | Active | Recovery | Total |
|---|---|---|---|---|
| Straight Sword R1 | 20–25f | 10–15f | 20–25f | ~60–65f |
| Ultra Greatsword R1 | 40–45f | 15–20f | 40–50f | ~95–115f |

### Attribute Scaling Curves

| Range | Behavior |
|---|---|
| 10–40 | Maximum returns per point |
| 40–60 | Diminishing returns begin |
| 60–99 | Cliff-drop; 99 is absolute hard cap |

### Poise Breakpoints (DS3)

| Threshold | Effect |
|---|---|
| 61 poise | Tank light-weapon combos + single greatsword R1 |
| 52 poise (great-hammer) | Two-handed swings never interrupted |

---

## 9. Relevance to Ashen Hollow

### Verified Correct in Current Implementation

1. **Three-phase attack model (wind-up/active/recovery):** Matches the Souls combat grammar precisely.
2. **Stamina as shared budget with regeneration delay:** Gated behind `State.LOCOMOTION` — correct.
3. **`_physics_process` frame-counting for stamina cooldown:** Using the industry-standard pattern, not `await`.
4. **Input buffering (150ms window):** Implemented (commit `7f30d4f`), last-input-wins.
5. **Boss phase transition + distance-bracket attack selection:** Implemented.
6. **Signals-based communication:** Matches Godot best practices and the modular template philosophy.

### Highest-Impact Remaining Gaps

Ranked by impact on "Souls feel" per implementation effort:

1. **Per-style attack timing differentiation** (PENDING) — Currently all five styles use uniform wind-up/active/recovery durations. Twin Colossi must feel dramatically slower than Crescent Pair. See [`research-dark-souls-weapons.md`](research-dark-souls-weapons.md) Section 11, Tuning Reference table.

2. **Hyper armor during heavy weapon active frames** (PENDING) — Twin Colossi should be unstaggerable during the active window. This is THE reward for surviving the long wind-up. The poise health formula in Section 4 above provides the mathematical model.

3. **Hit-stop on successful impacts** (PENDING) — 2–4 frame pause on heavy hits. Single highest-impact change for weapon weight perception. Costs nothing in design complexity.

4. **Per-style stamina cost differentiation** (PENDING) — Current flat 20/38 for all styles undermines weapon identity. Heavy weapons must cost more to swing.

5. **Parry window differentiation** (PENDING) — Reliquary Guard's parry should have tunable active frames per shield type, not a uniform window.

6. **Boss healing-punish tendency** — The Cinder Guardian could intercept player healing with a gap-close attack, adding the psychological pressure layer described in Section 6.

### What NOT to Copy Directly

- Exact frame counts from DS1/DS3 — tune against Ashen Hollow's own animation timings.
- Specific poise breakpoint values (61, 52) — these are DS3-specific and armor-set-dependent.
- Exact stamina cost ratios — must be tuned against Ashen Hollow's own stamina pool (100) and encounter pressure.
- Attribute scaling curves — Ashen Hollow has no stat system in the vertical slice; this is future-depth.

---

## 10. Conclusion

Dark Souls ascended from niche hardcore title to era-defining game icon not because of exaggerated numbers or malicious traps on the surface. Its greatness lies in building an extremely self-consistent, rigorous, and physics-respecting micro-mechanical system.

From the 1.5× two-handing strength modifier that reshapes build planning, to the meticulously tuned 13-frame fast-roll invulnerability window; from the dynamic mathematical model of poise health, to the fragmented narrative assembled through environmental fragments — every design element quietly forces the player to abandon浮躁, engage with absolute focus, deconstruct the world, and master it.

In technical implementation, with Godot 4's continued iteration, the open-source community can now deconstruct and reproduce this complex system with high fidelity. Root-motion-driven animation state machines eliminate ice-skating. Layered collision masks with duck-typing GDScript achieve millisecond-precision hitbox detection. Highly soft-coded string-array weapon resources enable vast derivative movesets. Rigorous frame-counting stamina delay faithfully reproduces the punishment of panic-mashing.

The modularization of technical architecture and the rigor of game design philosophy have achieved deep fusion here — not only providing a high-standard open-source paradigm for future indie game industrialization, but profoundly诠释ing the ultimate game aesthetic of "hardcore but fair."

---

## Sources & Search Coverage

### Data Sources

| Source Type | Content | Confidence |
|---|---|---|
| Community frame data (wikidot, fextralife) | Roll i-frame counts, parry frame data, poise breakpoints | MEDIUM — version/patch-dependent; ratios are reliable, absolute counts are directional |
| Community weapon data | Attribute scaling curves, infusion modifiers, two-handing 1.5× multiplier | HIGH — directly observable in-game |
| Dark Souls Design Works interviews | Miyazaki on level design collaboration, world structure, atmosphere | HIGH — published, translated primary source |
| Godot official documentation | `AnimationTree`, `CharacterBody3D`, `Area3D`, `AnimationPlayer` keyframe API, signals, `Resource` | HIGH — authoritative API reference |
| Open-source Godot projects (BreadbinEngine, catprisbrey templates) | Soft-coded weapon architecture, AI tendency patterns, root motion integration | MEDIUM — observable code patterns, not production-verified at scale |
| Academic analysis (Jenkins, IntechOpen) | Narrative architecture, ludic sublime, looping time | ANALYSIS — scholarly interpretation, not developer-confirmed |

### Search Limitations

- Frame data varies by game version (DS1 vs DS3 vs Elden Ring) and patch level. Values provided are approximate starting points.
- Poise breakpoints are DS3-specific and armor-set-dependent. DS1 uses an entirely different passive poise system.
- Community-sourced frame data sometimes disagrees between sources. Where conflicts exist, the most commonly cited values are used.
- No direct Miyazaki quotes with verified publication details for specific mechanical design intent (e.g., why 13 i-frames for fast roll). Mechanical values are observable rules; design rationale is analysis.
- Two-handing 1.5× STR modifier and infusion scaling rules are directly observable in-game and widely documented — HIGH confidence.
