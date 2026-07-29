# Research — Dark Souls Design Principles

Research conducted 2026-07-29 to evaluate whether Ashen Hollow's game design correctly reflects Dark Souls 1/3 core design, what is missing, and what should not be copied directly.

## Source Reliability Disclaimer

This report uses a three-tier evidence classification:

| Label | Criteria |
|---|---|
| **Observable rule** | Verifiable through game executable, official manual, or official guide. Version/platform/patch must be stated. |
| **Developer intent** | Requires named developer quotation from a datable, accessible interview, talk, or official publication. URL and quote must be provided. |
| **Analysis** | Interpretation built from observable mechanics. Not developer-confirmed; must be labeled as analysis. |

**Important:** Two Perplexity deep_research queries were executed during this investigation. The first returned a framework-level answer without any source URLs. The second follow-up also could not return verifiable URLs with page-specific quotations. Therefore, no conclusion below is attributed to a Perplexity-returned source unless independently verified. Conclusions marked **Analysis** are supported by observable game mechanics and widely documented design patterns but lack developer-attributed confirmation.

---

## 1. DS1 vs DS3 — Combat Speed, Movement Weight, Action Commitment, Input Buffering

### Observable Rules

| Aspect | DS1 (original, PS3/360) | DS3 (PS4/XB1) |
|---|---|---|
| Equipment load thresholds | ~25% fast roll, ~50% mid roll, >50% fat roll | ~30% fast roll, ~70% mid roll, >70% fat roll |
| Locked-on roll directions | Four-directional when locked | Omnidirectional when locked |
| Roll stamina cost | Varies by equipment load tier | Generally lower across tiers |
| Input buffering | Present; narrow windows, action-specific | Present; generally wider windows |
| Attack cancellation | Not possible after commitment frames begin | Not possible after commitment frames begin |

### Analysis

DS1's four-directional locked roll and slower stamina recovery create a heavier, more deliberate feel. DS3's omnidirectional locked roll and more generous stamina economy produce faster-paced combat. Neither game allows canceling attacks once past early startup frames. The difference is in animation speed, recovery windows, stamina costs, and lock-on mobility — not a fundamental "DS1 can't cancel, DS3 can."

**Status for Ashen Hollow:** The design correctly identifies wind-up/active/recovery phases and that attacks should not be freely cancellable. Input buffering is mentioned in research (`docs/research.md:15`) but not yet implemented. This is a **should-have** for the slice.

---

## 2. Stamina Economy

### Observable Rules

- Both DS1 and DS3: attacking, rolling, sprinting, blocking all consume stamina.
- Stamina regenerates with a delay after each costly action.
- Empty stamina prevents most actions; the exact blocked actions differ between games.
- DS1: endurance stat governs stamina pool; equipment load is separate.
- DS3: endurance governs stamina; vitality governs equipment load.

### Analysis

Stamina functions as a shared budget across offensive, defensive, and movement actions. This creates natural decision tension: attacking reduces ability to evade. Regeneration delay creates a rhythm where players must disengage to recover.

**Status for Ashen Hollow:** The design (`docs/game-design.md:32`) correctly implements shared stamina for sprinting, attacking, and dodging with regeneration delay. The specific costs (20/38/26) are prototype targets, not derived from DS. The current implementation's regeneration delay counts during attack execution (`game/scripts/player.gd:626`), which may make heavy attacks effectively consume no delay. This should be tuned to start delay from actionable recovery.

### What NOT to Copy

Exact stamina pool sizes, cost ratios, regen rates, and equipment load thresholds. These must be tuned against Ashen Hollow's own animation timings, enemy pressure, and intended pace.

---

## 3. Lock-On and Camera

### Observable Rules

- DS1: lock-on selects nearest target in view; four-directional roll when locked; camera follows target.
- DS3: lock-on selects nearest target in view; omnidirectional roll when locked; camera follows target; target switching via right stick.
- Both: lock releases on target death, exceeding max distance, or manual unlock.

### Analysis

Lock-on provides spatial anchoring for one-on-one combat. The camera tracks the locked target, freeing the player from manual camera control during combat. Known limitations in both games include: target selection through walls/geometry, camera collision with walls in tight spaces, disorientation against very large or very fast enemies, and no distance-based or occlusion-aware target filtering.

**Status for Ashen Hollow:** The implementation (`game/scripts/player.gd:650`) uses distance and camera-facing angle for target selection. It lacks occlusion checks and target cycling — both known limitations also present in DS games, but target cycling is a **should-have** and occlusion checks are a documented planned improvement (`docs/research.md:57`).

### What NOT to Copy

Four-directional locked movement, inability to cycle targets, and camera behavior in tight corridors. These are historical limitations, not design principles.

---

## 4. Enemy Design — Telegraphs, Recovery, Combos, Teaching

### Observable Rules

- DS1 and DS3 enemies have distinct wind-up poses, attack trajectories, and recovery periods.
- Early-game enemies use slow, clearly telegraphed attacks. Later enemies combine attacks into sequences with varying delays.
- Ambushes and environmental hazards teach observation before engagement.
- Enemy placement is deliberate; each encounter tests a specific skill or combination.

### Analysis

The learning loop relies on: (1) safe observation reveals attack pattern, (2) pattern recognition enables successful response, (3) variation forces adaptation. High damage is a feedback mechanism, not the primary teaching tool. The sequence from isolated enemy → combination → environmental complication is a documented level-design pattern across both titles.

**Status for Ashen Hollow:** The design (`docs/game-design.md:26`) correctly requires readable telegraphs. Current implementation uses a glowing floor disc and weapon pose for telegraphs (`game/scripts/enemy.gd:461`). However, only one enemy archetype exists (Hollow Sentinel × 3, Guardian as a stat-scaled variant). A second archetype with a different attack profile is a **should-have** for demonstrating variety. Telegraph audio should play during wind-up, not at active hit (`game/scripts/enemy.gd:378`).

---

## 5. Death, Soul Recovery, Enemy Reset, Healing, Risk of Pushing Forward

### Observable Rules

**DS1:**
- Death drops souls and soft humanity at death location (bloodstain).
- One recovery chance; dying again replaces the bloodstain with the new death's contents (zero souls if none were carried, though prior souls are lost).
- Resting at bonfire: refills Estus, respawns most enemies, does NOT respawn bosses or special enemies.
- Bonfire Kindling (using Humanity) increases Estus charges for that specific bonfire.
- Fast travel unlocks after obtaining the Lordvessel; not all bonfires are warpable.

**DS3:**
- Death drops souls at death location (bloodstain).
- Same single-recovery mechanic as DS1.
- Resting at bonfire: refills Estus and Ashen Estus, respawns most enemies, does NOT respawn bosses.
- No Kindling mechanic; Estus Shards increase total flask count (globally), Undead Bone Shards increase recovery amount.
- Flask allocation (Estus vs Ashen Estus) is configured at the blacksmith, not at the bonfire.
- Fast travel available from the start between all lit bonfires.

### Analysis

The death-recovery loop creates push-your-luck tension: carrying many souls makes death costly, encouraging retreat to spend them; carrying few reduces the cost of exploration. The bloodstain mechanic forces re-traversal of the area that killed you, which reinforces route learning. Enemy reset links resource restoration (Estus refill at bonfire) with encounter replay, preventing attrition-based progress.

**Status for Ashen Hollow:** The implementation largely matches the described loop — death drops embers, Lost Echo enables recovery, second death replaces the old echo (`docs/game-design.md:40`, `game/scripts/game_world.gd:187`). However:

- **Defect:** Embers currently have no spending purpose, weakening the push-your-luck decision. A minimal shrine-based sink (e.g., "spend embers to reinforce weapon" or "spend embers to increase max health by 5") is a **must-have**.
- **Defect:** Enemy reset only occurs on manual rest, not on death (`game/scripts/game_world.gd:182`). DS games reset enemies on rest; Ashen Hollow should match this but should also consider whether death should reset enemies (current behavior: death does NOT reset enemies, allowing attrition across lives). This is a design decision, not a pure bug.

---

## 6. World Structure, Shortcuts, Minimum Viable Vertical Slice

### Observable Rules

**DS1:** Firelink Shrine connects to multiple branching paths. Shortcuts loop back to earlier bonfires. The first half of the game emphasizes interconnected topology; fast travel is gated behind mid-game progress. Shortcuts reduce re-traversal and create spatial comprehension rewards.

**DS3:** Macroscopic path is more linear (sequence of areas in intended order). Individual areas contain internal loops and shortcuts. Fast travel from game start reduces dependence on spatial shortcuts.

### Analysis

DS1 uses spatial interconnection as a substitute for fast travel in the early game. DS3 uses fast travel as the primary navigation system while retaining local shortcuts within each area. Both games use shortcuts to create a sense of mastery: "I understand this space well enough to open a faster path through it."

**Status for Ashen Hollow:** The design (`docs/game-design.md:42`) includes one shortcut gate opened by a side-route lever. For a 10–15 minute slice, one shortcut is sufficient. The route should demonstrably reduce traversal time from shrine to boss by at least 30%. This is a **verifiable acceptance criterion**.

---

## 7. Boss Design

### Observable Rules

**DS1:** Bosses generally have distinct visual phases, new attack patterns at health thresholds, or arena changes. Some have multiple targets, arena hazards, or unconventional damage conditions. Not all bosses have formal "phase transitions."

**DS3:** Bosses more consistently use mid-fight cutscenes, visible form changes, expanded movesets at thresholds, and multi-health-bar encounters. Stage transitions are more theatrical and more frequent.

### Analysis

Core boss design principles observable in both games: (1) readable tells before every attack, (2) punish windows after committed attacks, (3) variation that prevents pattern memorization from trivializing the fight, (4) failure that teaches a specific lesson. Delayed attacks (holding a pose before striking) test observation rather than reflex. Phase changes test adaptation under pressure.

**Status for Ashen Hollow:** The Cinder Guardian alternates quick and delayed attacks deterministically (`game/scripts/enemy.gd:338`). No phase transitions, no distance-dependent attack selection, no arena mechanics. For a 10–15 minute slice:

- A second attack pattern that triggers at ~50% health is a **should-have**.
- Distance-dependent attack selection (close → swipe, far → lunge) is a **should-have**.
- A visible transition effect at the phase boundary is a **could-have**.

### What NOT to Copy

Any specific boss name, visual design, attack animation sequence, arena geometry, music, or sound design from a protected work.

---

## 8. Growth, Currency Utility, Build Choices

### Observable Rules

**DS1 and DS3:** Souls serve as both experience currency (leveling up) and purchase currency (items, upgrades, spells). This dual role creates tension: spend now on levels/gear, or save for later? Death loss means losing potential progress — the more souls carried, the higher the stakes.

### Analysis

Without a spending outlet, collected currency has no instrumental value beyond a score counter. The "risk recovery or cut losses" decision only has weight if the recovered currency can be meaningfully used.

**Status for Ashen Hollow:** Embers can be earned, lost, and recovered, but have no spending purpose (`docs/game-design.md:38`). This is the **highest-priority design gap**. A minimal sink — even a single stat investment or weapon reinforcement at the shrine — would activate the entire death-recovery loop's motivational structure.

### Minimum Viable Growth for the Slice

One of:
- Spend embers at shrine to increase max health by a small amount (permanent for the run).
- Spend embers at shrine to boost a single weapon's damage.
- Accumulate embers toward a visible threshold that unlocks a new combat capability.

This is a **must-have** for the slice to function as designed.

---

## 9. Healing and Resource Consumption

### Observable Rules

**DS1:** Estus Flask heals HP. Uses per rest depend on bonfire Kindling level. Kindling consumes Humanity. No FP system. Other healing: Humanity (full heal, rare), Divine Blessing (full heal, very rare). Estus drinking locks the player in place during the animation.

**DS3:** Estus Flask heals HP. Ashen Estus Flask restores FP. Total flask count shared between HP and FP types; allocation configured at blacksmith. Estus Shards increase total count. Undead Bone Shards increase recovery amount. Estus drinking allows slow movement during the animation.

### Analysis

Limited healing creates route endurance: can you reach the next bonfire before running out? The refill-on-rest mechanic ensures each attempt starts with full resources while preventing attrition-based progress through an area — you can't grind through by slowly healing between fights.

**Status for Ashen Hollow:** The design (`docs/game-design.md:36`) originally stated healing is limited to checkpoint restoration only. However, the current codebase added Ember Rite (one of five combat styles) which can heal 24 HP and passively regenerates Focus (`game/scripts/player.gd:537`, `game/scripts/player.gd:634`). The design doc and implementation are now in conflict. This must be resolved:

- **Option A:** Remove/disable in-combat healing for the slice; keep checkpoint-only healing as originally designed.
- **Option B:** Embrace limited healing and re-document the design with a resource constraint (e.g., Focus depletes and does NOT auto-regenerate, or Ember Rite costs embers).

**Recommendation:** Option A is more consistent with the vertical slice's stated scope boundaries. The five-style expansion should be consolidated before adding healing mechanics.

### What NOT to Copy

Estus Flask quantity, Kindling mechanics, Estus/Ashen allocation ratio. Ashen Hollow should design its own healing economy.

---

## 10. Accessibility and Originality

### Analysis

Soulslike difficulty is not equivalent to inaccessibility. Core risk-reward gameplay can coexist with: remappable controls, camera sensitivity options, subtitle support, colorblind-friendly telegraph alternatives, reduced-motion options for camera effects, and clear UI feedback. DS1 and DS3 have limited built-in accessibility features; newer games have demonstrated that these can be added without compromising challenge.

### Originality Boundaries

Ashen Hollow should avoid:
- Copying specific map layouts, bonfire positions, boss attack sequences, enemy placements, UI compositions, icons, names, text, sound effects, animations, or artistic trade dress from protected games.
- Reproducing precise stamina costs, iframe durations, recovery frames, damage formulas, soul drop values, or Estus allocations — these should be independently tuned.
- Claiming that genre-level conventions (attack commitment, stamina economy, death-recovery loop) are proprietary to any single game.

---

## 11. Vertical Slice Checklist

### Must-Have (blocking)

| # | Item | Current Status | Verification |
|---|---|---|---|
| M1 | Ember spending purpose (shrine sink) | ❌ Missing | Player can spend embers at shrine; spending changes gameplay state |
| M2 | Enemy reset on death (or documented design choice) | ❌ Partial | Death restores all regular enemies to spawn state |
| M3 | All GDScript files parse without errors | ✅ Passes | `--check-only` on every .gd file |
| M4 | Headless import completes | ✅ Passes | Godot editor import without script/resource errors |
| M5 | Complete death→echo→recovery→rest cycle | ⚠️ One defect | Shrine resting works repeatedly; echo replaced on second death |
| M6 | Boss is defeatable with intended tactics | ⚠️ Untested | Full manual Guardian kill from fresh start |
| M7 | 10–15 minute complete loop playable | ⚠️ Untimed | Manual stopwatch run |

### Should-Have (high priority)

| # | Item | Current Status |
|---|---|---|
| S1 | Second enemy archetype | ❌ Only Sentinel variant |
| S2 | Boss phase transition at ~50% HP | ❌ No phases |
| S3 | Boss distance-dependent attack selection | ❌ Deterministic alternation only |
| S4 | Input buffering for attacks/rolls | ❌ Inputs discarded outside locomotion |
| S5 | Lock-on target cycling | ❌ No cycling |
| S6 | Telegraph audio during wind-up | ❌ Audio plays at active hit |
| S7 | Shortcut demonstrably reduces route by ≥30% | ⚠️ Untimed |
| S8 | Controller + keyboard input complete | ⚠️ Controller mapped but untested |

### Could-Have (nice to have)

| # | Item |
|---|---|
| C1 | Boss arena hazard or environmental interaction |
| C2 | Enemy patrol routes (not just idle→chase) |
| C3 | Hitstop / camera impulse on heavy hits |
| C4 | Weapon-trail or impact VFX |
| C5 | Sensitivity, inversion, colorblind settings |
| C6 | Death recap (what killed the player) |

---

## 12. Common Unverified Claims About Dark Souls

The following claims circulate in player discussions but lack confirmed developer attribution. They should not be cited as FromSoftware design intent without primary-source evidence:

| Claim | Observable Reality | Risk if Misused |
|---|---|---|
| "DS1 locked roll is 4-directional to force commitment" | Observable rule, but no developer statement confirms the intent was "to force commitment" | Overstates intent |
| "DS3 removed poise" | Incorrect: DS3 uses hyper-armor poise on specific attack frames, not passive poise from DS1 | Misrepresents mechanics |
| "DS1 has no fast travel" | Lordvessel unlocks warp to select bonfires mid-game | Factual error |
| "DS3 is purely linear" | Main path is sequential but areas contain loops and branches | Over-simplification |
| "Death makes you lose levels or items" | Death drops souls and soft humanity; levels, equipment, and items are retained | Factual error |
| "Zero stamina = completely helpless" | Walking, item use, and some actions remain available; varies by game | Exaggeration |
| "Estus drinking always locks you in place" | DS3 allows slow movement during Estus animation | Factual error for DS3 |
| "Bosses are all about memorizing roll timing" | Ignores positioning, spacing, stamina management, build choices, and arena use | Reductive |

---

## Assessment of Ashen Hollow's Current Design

### What Is Correct

1. **Attack commitment:** Wind-up/active/recovery phases are modeled correctly.
2. **Stamina as shared budget:** Sprinting, attacking, and dodging all draw from one pool.
3. **Dodge invulnerability:** A short iframe window inside a longer movement state — correct interpretation.
4. **Death-recovery loop:** Lose embers on death, one recovery chance, replacement on second death — mechanically sound.
5. **Checkpoint + enemy reset on rest:** Matches bonfire conventions.
6. **Shortcut for spatial progress retention:** Matches DS design intent.
7. **Readable telegraphs as a stated requirement:** Correct design priority.

### Highest-Priority Gaps

1. **Embers have no use** → The entire death-recovery loop has no motivational anchor. Fix: add one shrine-based spending action.
2. **Enemy reset on death is missing** → Attrition across lives breaks the learning loop. Fix: reset all regular enemies on death, or document the design choice.
3. **Boss lacks behavioral depth** → Two alternating attacks are trivially solvable. Fix: add phase transition at 50% HP with distinct attack profile and distance-dependent selection.
4. **Design doc / implementation conflict** → Healing exists in code (Ember Rite) but doc says checkpoint-only. Fix: align doc and code.
5. **No input buffering** → Inputs outside locomotion are discarded, making commitment feel unresponsive. Fix: add short input queue or buffer window near recovery end.

### What NOT to Add (for This Slice)

- Complex inventory or equipment systems — explicitly excluded by scope (`docs/game-design.md:68`).
- Multiple weapon types with distinct movesets — one polished style is better than five half-finished ones.
- Consumable healing items — would require re-tuning the entire encounter economy.
- DS-style Estus/Kindling/FP allocation — design a simpler, original system.
- More than 3–4 enemy archetypes — the slice should prove the loop before expanding.

---

## References and Further Research

### Documentation Reviewed

| File | Status |
|---|---|
| `docs/game-design.md` | PARTIALLY RELIABLE — core design sound, conflicts with current code on healing |
| `docs/architecture.md` | STALE — entry scene description and responsibility table are outdated |
| `docs/controls.md` | STALE — missing five styles, guard, parry, spells, gamepad, touch |
| `docs/validation.md` | CONTRADICTED — Godot path, input platforms, persistence claims all outdated |
| `docs/devlog.md` | STALE — recent entries missing; claims about no fonts/controllers contradicted |
| `docs/research.md` | PARTIALLY RELIABLE — design advice still sound; no source URLs provided |
| `docs/project-structure.md` | RELIABLE — describes current repository layout accurately |

### Unresolved Research Questions

These require primary-source evidence that could not be obtained during this investigation:

1. Has Hidetaka Miyazaki or any FromSoftware combat designer publicly stated, in a recorded interview or talk, that DS3's faster pace was an intentional response to Bloodborne's reception?
2. Is there a developer-confirmed design rationale for DS1's locked four-directional roll?
3. Has FromSoftware publicly commented on the accessibility (or lack thereof) of Dark Souls?
4. Are there GDC/CEDEC presentations by FromSoftware staff covering boss design methodology, enemy teaching progression, or world interconnection principles?
5. Do official strategy guides (Future Press) contain developer commentary sections that confirm design intent, or are they purely gameplay documentation?

These questions should be pursued through direct source retrieval — searching GDC Vault, CEDEC archives, EDGE magazine interviews, and Famitsu/4Gamer developer interviews in Japanese — rather than through AI search tools that may return synthesized rather than retrieved content.

### Search Coverage

| Query | Mode | Result |
|---|---|---|
| Consolidated 12-topic DS1/DS3 design research + Ashen Hollow assessment | deep_research | Framework-level answer; no source URLs returned |
| Follow-up requesting specific URLs, quotes, and source types per topic | deep_research | Could not return verifiable URLs; offered retrieval template instead |
| Project documentation audit (6 files) | Local sub-agent | Full cross-reference with game code; reliability labels assigned |
| Evidence gap analysis | Local sub-agent | Minimum-evidence checklist for 12 topics; safe-claim templates |
| Counter-evidence review | Local sub-agent | Refuted or narrowed 8 common Dark-Souls-as-design-doctrine claims |
