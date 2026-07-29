# Dark Souls Weapon Design Research

**Date**: 2026-07-29
**Last updated**: 2026-07-29 (post-audit fixes verified; recommendations status-tracked)
**Purpose**: Research Dark Souls weapon models, design philosophy, and moveset principles to inform weapon implementation in Ashen Hollow (Godot 4.7 soulslike vertical slice).
**Method**: Perplexity MCP (pro + deep_research modes) + project documentation scan.
**Status**: `ACTIVE` — recommendations differentiate implemented vs pending vs deferred
**See also**: [`research-dark-souls-design.md`](research-dark-souls-design.md) — 12-topic DS design audit, vertical slice checklist, post-fix gap analysis

---

## Key Findings (Ranked by Confidence)

### HIGH Confidence

1. **Attack commitment is the foundational principle**: FromSoftware designs weapons around the idea that every swing is a decision. Wind-up, active, and recovery phases create a risk/reward loop. Ashen Hollow already implements this correctly with its three-phase attack model.

2. **Weapon classes are differentiated by timing, not just damage**: The primary differentiator between a straight sword and an ultra greatsword is the *shape of the risk curve* — how long you're exposed during wind-up and recovery. Light weapons have short exposure windows (20-25f wind-up); heavy weapons demand long commitments (40-45f wind-up).

3. **Stamina costs follow a clear hierarchy**: Dagger (~20-25%) → Straight/Curved Sword (~35-45%) → Katana/Spear (~40-50%) → Greatsword (~55-65%) → Ultra Greatsword (~65-80%) of base stamina bar. Ashen Hollow's current costs (light 20, heavy 38, dodge 26 from a 100 pool) map closely to a straight sword/curved sword profile.

4. **Sound design is a weapon-class multiplier**: Dark Souls uses layered audio per weapon class — whoosh (wind-up) → metallic impact (active) → room reverb (recovery) — with pitch shifting lower for heavier weapons. Ashen Hollow's procedural audio system is well-positioned to implement this.

5. **Visual language communicates weapon identity before first swing**: Silhouette, proportion, material wear, and ornamentation are read by players in milliseconds. A broad, weathered blade signals "heavy, slow, high damage" before any animation plays.

### MEDIUM Confidence

6. **Boss weapons translate boss DNA into player movesets**: FromSoftware preserves the boss's attack rhythm, elemental motif, and visual identity in the player weapon. The weapon art typically references the boss's signature attack. Ashen Hollow has no boss weapons yet — this is a future-depth opportunity.

7. **Five combat styles already cover the minimum viable weapon roster**: Ashen Hollow's existing styles (Reliquary Guard, Twin Colossi, Crescent Pair, Veilcraft, Ember Rite) span the essential archetypes: shield+1H, paired heavy, paired fast, ranged magic, and support/utility. No new weapon types are needed for the vertical slice.

8. **Historical references ground fantasy exaggeration**: FromSoftware starts with real medieval weapons (Zweihander, Claymore, Uchigatana all have documented real-world counterparts) and exaggerates proportions, wear, and ornamentation for gameplay clarity and thematic resonance.

### LOW Confidence

9. **Specific frame data varies by game and patch**: The exact wind-up/active/recovery frame counts differ between DS1, DS3, and Elden Ring. Community-sourced data often disagrees. The approximate ratios are reliable; exact frame counts should be tuned through playtesting.

10. **Developer quotes are widely cited but hard to verify**: Miyazaki's design philosophy quotes circulate widely but often lack precise publication details. The *intent* is well-documented; exact wording should be verified against Design Works or EDGE interviews.

---

## Changes Since Initial Research

The following combat-related fixes from the design audit (commit `7f30d4f`) have been applied since this research was conducted. Readers should be aware these features are now implemented, not pending:

| Change | Source (Audit Gap) | Status |
|--------|-------------------|--------|
| Input buffering (150ms window) | S4 | **Done** — `player.gd:357-400` |
| Boss phase transition at ≤50% HP | S2 | **Done** — `enemy.gd:165-166, 423-435` |
| Boss distance-dependent attack selection | S3 | **Done** — `enemy.gd:345-420` |
| Telegraph audio during wind-up | S6 | **Done** — `enemy.gd:446-447` |
| Stamina regen gated to LOCOMOTION | — | **Done** — `player.gd:717-730` |

The weapon-specific recommendations (per-style timing, stamina costs, hit-stop, hyper armor, audio profiling) remain **pending** — the changes above improve the combat foundation but do not address style differentiation.

---

## Project Documentation Reviewed

| File | Relevant Claims | Reliability |
|------|----------------|-------------|
| `game-design.md` | 4 combat pillars (commitment, readability, resource pressure, recovery); 5 combat styles; tuning targets (100 HP, 100 stamina, light=20, heavy=38, dodge=26) | RELIABLE — updated to reflect audit fixes |
| `research-dark-souls-design.md` | 12-topic DS design audit; all 9 fixes verified against game code; post-fix state documented | RELIABLE — cross-validated with code |
| `architecture.md` | State machines (player + enemy), collision layers, data flow, scene tree | PARTIALLY RELIABLE — scene tree current; title screen and pause flow still undescribed |
| `devlog.md` | 9 research-audit fixes applied; 5 combat styles shipped; input buffering (150ms), target cycling, boss phase transition, Vitality Forging added | RELIABLE — chronological record includes full post-fix state |
| `research.md` | 9-step implementation sequence; Godot-specific soulslike recommendations | RELIABLE — initial design research, predates 5-style + controller |
| `controls.md` | Input mapping; keyboard alternatives; accessibility notes | STALE — missing 5 combat styles, guard, parry, controller inputs per research audit |
| `validation.md` | All automated tests pass; 16-item manual checklist; Godot 4.7.1 | CONTRADICTED — controller status claim outdated; script glob misses subdirectories |
| `project-structure.md` | Multi-project layout; `game/` as Godot root; `snake_case` naming | RELIABLE |

The design research audit ([`research-dark-souls-design.md`](research-dark-souls-design.md), Section 11) contains a Vertical Slice Checklist that tracks implementation status of combat-related features — input buffering, lock-on cycling, boss phases, and telegraph audio — several of which directly affect weapon feel.

---

## Detailed Research Sections

### 1. Core Design Philosophy

**FromSoftware's weapon design centers on three principles:**

- **Weight as gameplay**: Every weapon swing must feel consequential. The animation timing, stamina cost, and audio feedback combine to create a sense of physical mass. Light weapons feel snappy; heavy weapons feel like commitments you can't take back.
- **Weapons as worldbuilding**: Each weapon tells a story through its visual design, item description, and acquisition context. A weapon found in a decayed castle feels different from one forged from a boss soul.
- **Fairness through readability**: Enemy weapons telegraph their attacks clearly. Player weapons have visible wind-up, active, and recovery states. Nothing damages the player without an animation cue.

**Relevance to Ashen Hollow**: The three-phase attack model, stamina economy, and telegraph readability are covered in detail in the design research audit ([`research-dark-souls-design.md`](research-dark-souls-design.md), Sections 1–4). The weapon research below focuses on differentiation *within* that framework — per-style timing, stamina costs, audio profiles, and unique mechanical properties.

### 2. Weapon Category Design Matrix

| Category | Speed | Reach | Stamina Cost | Stagger | Tactical Identity |
|----------|-------|-------|-------------|---------|-------------------|
| Dagger | Fastest | Shortest | ~20-25% | Minimal | Critical hits, parry focus, low commitment |
| Straight Sword | Fast | Short-Medium | ~40-45% | Low | Versatile, reliable, jack-of-all-trades |
| Curved Sword | Fast | Short-Medium | ~35-45% | Low | Momentum-based combos, rolling attacks |
| Katana | Medium-Fast | Medium | ~40-50% | Medium | Precision, bleed buildup, counter-damage |
| Thrusting Sword | Fast | Medium (poke) | ~35-45% | Low | Spacing control, shield-poke, precise gap management |
| Spear | Medium | Long | ~40-50% | Medium | Outspacing, defensive pokes, guard breaks |
| Greatsword | Slow-Medium | Long | ~55-65% | High | Balanced heavy — reach + damage + manageable speed |
| Ultra Greatsword | Slowest | Longest | ~65-80% | Highest | Maximum commitment, maximum payoff, crowd control |
| Axe | Medium-Slow | Medium | ~45-55% | Medium-High | Higher stagger than swords, shorter reach |
| Hammer | Slow | Short-Medium | ~50-60% | High | Strike damage, poise break, armor crusher |
| Halberd | Slow-Medium | Very Long | ~50-60% | High | Sweet-spot mechanics, zone control, versatile moveset |

**Ashen Hollow mapping**:
- **Reliquary Guard** (shield + 1H): Straight sword or spear-tier speed and stamina costs *(uniform timing currently used across all styles)*
- **Twin Colossi** (paired great-blades): Ultra greatsword-tier commitment with dual-wield cadence *(uniform timing currently used across all styles)*
- **Crescent Pair** (paired curved-blades): Curved sword-tier speed with dual-hit patterns *(uniform timing currently used across all styles)*
- **Veilcraft** (projectile magic): No physical weapon — Focus-based resource, ranged
- **Ember Rite** (healing/damage prayer): No physical weapon — Focus-based, support/offense hybrid

### 3. Moveset Design Principles

**Attack timing ratios (approximate, 60fps reference)**:

| Attack Type | Wind-up | Active | Recovery | Total |
|-------------|---------|--------|----------|-------|
| Straight Sword R1 | 20-25f | 10-15f | 20-25f | ~60-65f |
| Ultra Greatsword R1 | 40-45f | 15-20f | 40-50f | ~95-115f |

**Ratio pattern**: The wind-up-to-recovery ratio is the key differentiator. Light weapons are roughly 1:1 wind-up:recovery. Heavy weapons approach 2:1 or more — the recovery is disproportionately long, creating the "I committed too early" feeling.

**Core moveset rules**:
1. **Light attacks (R1)**: Fast, low stamina, low damage, chainable. The bread-and-butter.
2. **Heavy attacks (R2)**: Charged/held, high stamina, high damage, high stagger. The punisher.
3. **Running attacks**: Extended forward momentum, longer reach, unique animation per class.
4. **Rolling attacks**: Quick recovery attacks with lower damage but faster wind-up than standing R1.
5. **Weapon Arts / Skills**: Signature move unique to weapon or class. The "soul" of the weapon.
6. **Two-handing**: Changes moveset (usually wider arcs, more damage, different stamina costs), often reduces STR requirement by 1.5x.

**Cancellation rules** (Dark Souls model):
- Wind-up: Partial cancellation possible in early frames (varies by weapon weight).
- Active: No cancellation. This is the commitment window.
- Recovery: Can be interrupted by dodge/roll after a minimum recovery threshold.

**Ashen Hollow current state**: Already implements wind-up → active → recovery with no cancellation after wind-up. Input buffering (150ms window, last-input-wins) was added in the research audit fixes (commit `7f30d4f`). Does NOT yet implement running attacks, rolling attacks, charged heavies, or two-handing — all are future-depth items. Attack timing is currently uniform across all combat styles; per-style differentiation is a pending recommendation.

### 4. Weapon Scaling & Stat Requirements

**Dark Souls scaling tiers**: E → D → C → B → A → S (S is best). Each weapon has base damage + scaling bonus derived from relevant stats. STR scaling favors slow, heavy weapons; DEX favors fast, precise weapons; quality (C/C in STR/DEX) favors versatile weapons like the Claymore.

**Stat requirements as design tool**:
- Create "build moments" — the player finds a weapon they can't wield yet, creating aspiration.
- Gate powerful weapons behind investment (Zweihander: 28 STR, 10 DEX — reachable but meaningful).
- Enable hybrid builds (weapons with INT/FTH requirements for spellblade archetypes).

**Ashen Hollow relevance**: The vertical slice explicitly excludes stat-based builds and equipment stats. However, the 5 combat styles serve a similar function — each is a "build choice" with distinct play patterns. If stats are added later, they should follow Dark Souls' pattern of STR/DEX/INT/FTH scaling with clear weapon identity mapping.

### 5. Visual Design Language

**Core principles**:

| Principle | Light Weapons | Heavy Weapons |
|-----------|--------------|---------------|
| Silhouette | Narrow, tapered, elegant | Broad, angular, imposing |
| Proportion | Realistic human-scale | Exaggerated — wider blade, longer hilt |
| Material | Clean lines, light ornament | Heavy wear, pitting, patina |
| Color palette | Bright steel, polished edges | Dark iron, oxidized, soot-stained |
| Hilt/Guard | Small crossguard, minimal | Large crossguard, counterweight pommel |
| Animation idle | Held at ready, light | Rested on shoulder, ground-drag |

**Iconic examples**:
- **Zweihander**: Tall straight blade, broad cross-section, thick blade, large pommel. The weight is visible before animation. Real-world counterpart: German Zweihänder (16th century Landsknecht sword).
- **Claymore**: Broad blade, pronounced angled crossguard, balanced proportions, weathered finish. Signals "reliable, versatile greatsword." Real-world counterpart: Scottish claidheamh-mòr.
- **Uchigatana**: Slender curved blade, pronounced curvature, small kissaki (tip), light hilt hardware. Signals "speed, dexterity, bleed." Real-world counterpart: Japanese uchigatana (predecessor to katana).
- **Black Knight weapons**: Rugged, jagged forging, heavy mass, angular geometry, dark rune-etched textures. Distinctive silhouette signals "boss-tier, lore-heavy lineage."

**Ashen Hollow application**: The existing combat styles need visual differentiation. Reliquary Guard's shield+sword should read as "knightly, defensive, reliable." Twin Colossi's paired great-blades should read as "brutal, overwhelming, high-risk." These visual cues should be established before the player presses a button.

### 6. Thematic Integration

**How weapons carry Dark Souls themes**:

- **Decay**: Weapons show wear — chipped edges, rust, patina. They're relics of a dying world, not fresh from a forge.
- **Struggle**: Heavy weapons are visibly difficult to wield. The character's stance and swing communicate effort. Victory feels earned because the tool itself seems reluctant.
- **Perseverance**: Finding and upgrading a weapon is a long-term commitment. The weapon grows with the player.
- **Cycles**: Boss weapons are trophies that preserve a fragment of the defeated enemy. Using Quelaag's Furysword means carrying her fire forward.

**Boss weapon translation rules** (inferred from analysis):
1. Preserve the boss's elemental motif (fire, lightning, magic, dark).
2. Reference the boss's signature attack in the weapon art/skill.
3. Match the boss's attack rhythm in the weapon's heavy attack timing.
4. Visual design echoes the boss's silhouette, color palette, and material.
5. Item description ties the weapon to the boss's lore and the player's triumph.

**Ashen Hollow application**: The Cinder Guardian's defeat could yield a weapon or ability that references its phase 2 fiery transformation. This would make the victory feel mechanically and narratively meaningful.

### 7. Iconic Case Studies

#### Moonlight Greatsword
- **Identity**: Recurring across FromSoftware games (King's Field → Armored Core → Dark Souls → Elden Ring). Pure magic damage, INT scaling.
- **Design philosophy**: A "legend" weapon — recognizable silhouette (broad blade, blue-green glow), projectile wave attack, always hidden behind obscure requirements.
- **Lesson**: A game's signature weapon can span multiple titles. Ashen Hollow could establish its own recurring weapon.

#### Zweihander
- **Identity**: Ultra greatsword, massive reach, devastating sweeps, high STR requirement (28), low weight for class (10.5).
- **Design philosophy**: Accessible ultra — lower stat requirements than other UGS, found early (Firelink Shrine graveyard in DS1). Teaches the player that heavy weapons are viable from the start.
- **Lesson**: Include at least one accessible heavy weapon early to signal that "big and slow" is a supported playstyle.

#### Claymore
- **Identity**: Greatsword, quality scaling (C/C STR/DEX), versatile moveset with thrusting R2.
- **Design philosophy**: The benchmark weapon. If a greatsword is better than Claymore, it's good. If worse, it's bad. The thrust R2 gives it a unique poke tool that other greatswords lack.
- **Lesson**: Every weapon class should have a "reference implementation" — the neutral, reliable option that defines the class baseline.

#### Uchigatana
- **Identity**: Katana, DEX scaling, innate bleed, fast slashes, low durability.
- **Design philosophy**: High skill ceiling through bleed buildup and counter-damage. Rewards aggression and precision. Low durability forces the player to manage weapon condition.
- **Lesson**: Weapons can create sub-systems (bleed buildup, durability management) that add depth without adding buttons.

#### Black Knight Weapons
- **Identity**: Unique weapons dropped by non-respawning Black Knights. Higher base damage than standard equivalents, unique movesets, bonus damage vs demons.
- **Design philosophy**: Reward exploration and risk-taking. Black Knights are tough early-game enemies; their weapons feel earned. The demon bonus damage is a diagetic hint about their lore.
- **Lesson**: Rare enemy drops with unique properties create memorable moments and encourage revisiting areas.

### 8. Common Soulslike Weapon Mistakes

| Mistake | Example | Fix |
|---------|---------|-----|
| **Weightless combat** | Lords of the Fallen (2014): weapons lacked hit-stop and audio feedback, making impacts feel floaty | Layer impact sounds, add brief hit-stop on contact, tune animation curves for acceleration at impact |
| **Undifferentiated classes** | Many indie soulslikes have 10+ weapon types that all feel the same | Start with 3-4 archetypes with dramatically different timing profiles; add variety later |
| **Stamina as suggestion** | Lords of the Fallen (2014): stamina regenerated so fast it didn't constrain choices | Ensure stamina costs are high enough that running out is a real possibility in combat |
| **Poor telegraph readability** | Enemies with instant attacks or attacks with identical wind-ups for different moves | Enforce minimum wind-up frames; use distinct prep poses per attack type (Ashen Hollow already does this) |
| **No recovery punishment** | Mortal Shell: hardening mechanic let players bypass recovery windows, reducing commitment | Recovery frames should have a minimum duration before any defensive action is available |
| **Generic weapon identity** | Weapons differentiated only by damage numbers and swing speed | Give each class a unique property (bleed, poise break, sweet spot, thrust access) |
| **Over-scoping weapon roster** | Too many weapon types before core feel is polished | Ship vertical slice with 3-4 weapon types max; expand based on playtest data |

### 9. Weapon Sound Design Framework

**Audio layers per weapon swing**:

| Phase | Light Weapon | Heavy Weapon | Technique |
|-------|-------------|-------------|-----------|
| Wind-up | High-pitched whoosh, fast attack | Low-pitched whoosh, slow build, doppler drop | Pitch shift down for heavier weapons; layer body movement/fabric |
| Active (hit) | Sharp metallic click, bright top-end | Dense metal-on-metal, low body impact, secondary edge ring | Multiple takes layered (blade contact + body impact + ground); pitch variation per swing |
| Recovery | Short tail, light reverb | Long tail, large room reverb, metal friction decay | Reverb size proportional to weapon weight; tail length matches recovery frames |
| Whiff (miss) | Air whoosh only, no impact | Heavy air displacement, subtle disappointment cue | Distinct "miss" sound reinforces the cost of whiffing |

**Ashen Hollow application**: The existing procedural audio system can implement this by parameterizing pitch, reverb size, and layer count based on weapon weight class. Each combat style should have its own audio profile.

### 10. Minimum Viable Weapon Roster for Vertical Slice

**Ashen Hollow already has 5 combat styles, which is MORE than sufficient for a 10-15 minute vertical slice.** The recommended focus is deepening existing styles rather than adding new ones:

| Style | Current State | Recommended Depth |
|-------|--------------|-------------------|
| **Reliquary Guard** | Shield + 1H with parry, guard, thrust | Add: distinct light/heavy attack timings, shield bash, parry riposte window |
| **Twin Colossi** | Paired great-blades, jump attack | Add: longer wind-up/recovery to match UGS profile, charged heavy sweep, hyper armor during active frames |
| **Crescent Pair** | Paired curved-blades, two-hit jump attack | Add: momentum-based combo chain (attack speed increases with consecutive hits), dodge-cancel window |
| **Veilcraft** | Focus-powered projectile magic | Add: charged shot (more damage, longer cast), projectile variation (fast/weak vs slow/strong) |
| **Ember Rite** | Focus-powered healing + damage prayer | Add: AoE heal zone, damage-over-time curse, resource tension between heal/damage |

**If a sixth style is ever added**, a spear/halberd archetype would fill the most obvious gap: long-reach, spacing-focused, with sweet-spot mechanics.

### 11. Accessibility Through Weapon Design

**Weapon variety as accessibility tool**:

- **Slower weapons** (greatswords, ultra greatswords) accommodate players with slower reaction times. The timing is about prediction and commitment, not twitch reflexes.
- **Shield weapons** (spear + shield, straight sword + shield) provide defensive safety nets. Blocking reduces the punishment for missed dodge timing.
- **Ranged weapons/magic** (Veilcraft, Ember Rite) let players engage from safe distance. Lower mechanical execution requirement.
- **Fast weapons** (daggers, curved swords) reward players with good reaction times. Low commitment means less punishment for aggressive play.

**Design patterns for accessibility**:
1. Multiple valid playstyles — no single "correct" weapon type.
2. Adjustable game speed (Ashen Hollow could add a "combat speed" slider).
3. Clear, multi-channel telegraphs (visual + audio, not just visual).
4. Generous parry/block windows on easier weapons, tighter on harder ones.
5. Remappable controls (already in Ashen Hollow's InputMap design).

---

## Contradictions & Gaps

### Contradictions
1. **Healing design conflict — RESOLVED**: `game-design.md` was updated in commit `7f30d4f` to document Ember Rite as an intentional limited in-combat healing exception (24 HP, 30 Focus, 0.92s cast). This follows the Dark Souls 3 pattern of checkpoint-refillable Estus coexisting with FP-cost healing miracles. Ember Rite is a high-commitment tactical choice, not a safety net.

2. **Controls doc vs reality**: `controls.md` remains stale. For a full documentation reliability audit, see [`research-dark-souls-design.md`](research-dark-souls-design.md), Documentation Reviewed table.

### Gaps
1. **No weapon-switching mechanic**: The 5 combat styles are selectable but there's no mid-combat weapon switching. Dark Souls allows this; most soulslikes benefit from it.
2. **No charged heavy attacks**: Dark Souls' R2 charged attacks create a risk/reward sub-decision. Ashen Hollow has light and heavy but no charge mechanic.
3. **No running/rolling attack variants**: These add tactical depth to movement. Ashen Hollow's combat is currently stationary-attack-only during the active phase.
4. **No hyper armor / poise system**: Heavy weapons in Dark Souls grant hyper armor during active frames, preventing stagger. This is essential for making slow weapons viable.
5. **No weapon durability or upgrade system**: Out of scope per design doc, but noted as a future-depth consideration.

---

## Recommendations — Status Tracked

Each recommendation is marked with its current implementation status: `[DONE]`, `[PENDING]`, or `[DEFERRED]`.

### Immediate (Vertical Slice Polish)

0. **Input buffering (150ms window)** `[DONE]` — Implemented in commit `7f30d4f` (`player.gd:357-400`). Combat actions pressed during attack recovery are stored and executed on return to LOCOMOTION.

1. **Tune stamina costs to weapon weight class** `[PENDING]` (Priority: HIGH)
   - Reliquary Guard (straight sword tier): Light attack ~40 stamina, Heavy ~55
   - Twin Colossi (UGS tier): Light attack ~65 stamina, Heavy ~80
   - Crescent Pair (curved sword tier): Light attack ~35 stamina, Heavy ~50
   - Current flat costs (20/38 for all styles) undermine weapon identity

2. **Differentiate attack timing per style** `[PENDING]` (Priority: HIGH)
   - Each style should have unique wind-up/active/recovery ratios
   - Twin Colossi should feel dramatically slower than Crescent Pair
   - Current implementation uses the same timing for all styles

3. **Add hit-stop on impact** `[PENDING]` (Priority: HIGH)
   - Brief (2-4 frame) pause on successful hits
   - Longer hit-stop for heavier weapons
   - Dramatically improves "weight" perception without changing any other system

4. **Layer audio per weapon weight class** `[PENDING]` (Priority: MEDIUM)
   - Parameterize the procedural audio system by weapon weight
   - Lower pitch, larger reverb, more layers for heavy weapons
   - Higher pitch, tighter reverb for light weapons

5. **Add hyper armor during heavy weapon active frames** `[PENDING]` (Priority: MEDIUM)
   - Twin Colossi should not be staggerable during the active window
   - This is the primary reward for surviving the long wind-up

### Future Depth (Post Vertical Slice)

6. **Add charged heavy attacks** `[DEFERRED]` (Priority: LOW)
   - Hold heavy attack button to extend wind-up for more damage
   - Creates a risk/reward sub-decision: "Do I have time for a charged R2?"

7. **Add running and rolling attack variants** `[DEFERRED]` (Priority: LOW)
   - Unique attack animations triggered from movement states
   - Running R1: forward momentum, longer reach, moderate damage
   - Rolling R1: quick recovery poke, low damage, fast wind-up

8. **Add boss weapon from Cinder Guardian** `[DEFERRED]` (Priority: LOW)
   - Defeating the Guardian could unlock a fiery weapon style or ability
   - Preserves the boss's phase 2 elemental motif
   - Creates a tangible trophy for the vertical slice's climax

9. **Add poise/stagger resistance system** `[DEFERRED]` (Priority: LOW)
   - Heavy weapons grant poise during active frames
   - Light weapons rely on speed and dodge cancels
   - Creates meaningful trade-off between weapon classes

10. **Consider a spear/halberd style** `[DEFERRED]` (Priority: LOW)
    - Fills the long-reach, spacing-focused archetype
    - Sweet-spot mechanic (more damage at tip, less at haft)
    - Different play pattern from all existing styles

---

## Ashen Hollow Combat Style Tuning Reference

> **⚠️ CRITICAL:** Frame counts and stamina values below are starting points derived from community Dark Souls frame data analyses. All values are **MEDIUM confidence** per the research confidence framework (see Key Findings). These numbers **MUST be tuned through actual playtesting** — implementing them verbatim without testing will produce incorrect feel. The **ratios and relative differences** between styles are more reliable than the absolute numbers. Use these as a directional guide, not a specification.

Based on Dark Souls weapon class data, here are recommended tuning targets for each style:

| Parameter | Reliquary Guard | Twin Colossi | Crescent Pair | Veilcraft | Ember Rite |
|-----------|----------------|--------------|---------------|-----------|------------|
| **DS Class Analog** | Straight Sword + Shield | Ultra Greatsword (paired) | Curved Sword (paired) | Sorcery Catalyst | Miracle Talisman |
| **Light Wind-up** | 20-25f | 40-45f | 18-22f | 25-30f (cast) | 30-35f (cast) |
| **Light Active** | 10-12f | 15-18f | 8-10f | Instant (projectile) | Instant (effect) |
| **Light Recovery** | 20-25f | 40-50f | 18-22f | 25-30f | 25-30f |
| **Light Stamina** | 38-42 | 65-75 | 32-38 | 30 Focus | 30 Focus |
| **Heavy Wind-up** | 30-35f | 50-60f | 25-30f | 40-50f (charged) | 40-50f |
| **Heavy Stamina** | 52-58 | 78-85 | 45-52 | 50 Focus | 45 Focus |
| **Hyper Armor** | No (shield block instead) | Yes (active frames) | No | No | No |
| **Unique Property** | Parry + riposte | Stagger immune during active | Combo speed ramp | Range + charge levels | Heal OR damage (choice) |
| **Audio Profile** | Bright metal, tight verb | Deep metal, large verb, low pitch | Light whoosh, fast attack | Ethereal, high pitch | Choral, warm reverb |
| **Visual Cue** | Knightly, clean steel | Brutal, worn, angular | Elegant, curved, flowing | Glowing, rune-etched | Warm, ember-lit |

*Frame counts assume 60fps reference. All values are starting points — tune through playtesting.*

---

## Conclusion

Ashen Hollow's combat foundation is solid and aligns well with Dark Souls weapon design principles. The three-phase attack model, stamina economy, and telegraph readability are all correct. The five combat styles cover a well-distributed weapon roster.

The primary recommendation is **deepening differentiation between styles**: Twin Colossi should feel dramatically heavier than Crescent Pair, not just look different. This differentiation comes from timing (wind-up/recovery ratios), stamina costs, audio profiles, and unique mechanical properties (hyper armor, parry windows, combo ramps, charge levels).

The single highest-impact change: **add hit-stop on successful impacts**. This 2-4 frame pause costs nothing in design complexity but dramatically improves the perception of weapon weight — it's the secret sauce that makes Dark Souls combat feel visceral rather than floaty.

**Post-audit note (2026-07-29):** Since the initial research, the design audit identified and resolved 9 gaps (commit `7f30d4f`). Input buffering, boss phases, distance-dependent attacks, telegraph audio timing, and stamina regen gating are now implemented. The remaining weapon-specific recommendations — per-style tuning, hit-stop, hyper armor — are still pending and represent the highest-impact remaining work for combat feel. See [`research-dark-souls-design.md`](research-dark-souls-design.md) for the complete post-fix gap analysis.

**Research confidence**: HIGH on design principles and directional numbers. MEDIUM on specific frame data (verify through playtesting). LOW on exact developer quotes (verify against primary sources). The Perplexity MCP did not return direct URLs in this session; all specific numbers are community-estimated and should be treated as tuning starting points, not authoritative references.

---

## Sources & Search Coverage

### Perplexity Queries Executed
1. `mode=pro`: Comprehensive weapon design philosophy checklist (8 items)
2. `mode=pro` follow-up: Developer quotes, frame data, visual examples, boss weapons, mistakes, minimum roster
3. `mode=deep_research`: Frame data, interviews, historical references, boss weapon rules, indie postmortems, sound design, accessibility
4. `mode=pro` follow-up: Concrete stamina costs, frame ratios, real weapon stats, Miyazaki quotes, specific mistakes, sound layers

### Source Types Consulted
- Community frame data analyses (wikidot, fextralife, YouTube breakdowns) — estimated values, flagged as medium confidence
- Developer interviews (Design Works, EDGE, Game Informer) — paraphrased, no direct URLs returned
- Game reviews and postmortems (Lords of the Fallen, Mortal Shell) — synthesized from multiple sources
- Dark Souls wiki weapon stat databases — specific numbers provided, flagged as patch-dependent

### Search Limitations
- Perplexity MCP in this session did not return direct source URLs. All specific numbers should be verified against community wikis.
- Frame data varies by game version (DS1 vs DS3 vs Elden Ring) and patch. Values provided are approximate starting points.
- No direct Miyazaki quotes with verified publication details were returned. Quotes cited are representative paraphrases.
- Historical weapon references are inferred from visual analysis and community research, not direct developer statements.
