# Ashen Hollow — Game Design

## Vision

**Ashen Hollow** is an original third-person action game vertical slice about crossing a ruined moonlit sanctuary, opening a forgotten shortcut, and defeating the construct guarding its sealed heart.

The project borrows only broad genre conventions: deliberate melee timing, stamina-limited actions, recoverable resources after death, checkpoints that reset enemies, readable enemy telegraphs, and spatial shortcuts. Its setting, names, layout, characters, geometry, code, materials, sounds, and presentation are original.

## Player Experience

The prototype should create a ten-to-fifteen-minute loop:

1. Rest at the Ember Shrine and learn the controls.
2. Cross the first courtyard while managing stamina against a sentinel.
3. Explore the side route to raise the shortcut gate.
4. Defeat or bypass two additional sentinels.
5. Enter the lower arena and face the Cinder Guardian.
6. On death, return to the shrine and decide whether recovering lost embers is worth the risk.

## Combat Pillars

### Commitment

Attacks have wind-up, active, and recovery phases. The player can change facing during early wind-up but cannot cancel every mistake. Heavy attacks cost more stamina and expose the player longer in exchange for damage and stagger.

### Readability

Enemy bodies brighten during wind-up, weapons move to a readable preparation pose, and sound reinforces the active strike. Damage is never meant to arrive without an animation or positional cue.

### Resource Pressure

Movement is free, while sprinting, attacking, and dodging spend stamina. Regeneration pauses after costly actions. Emptying the bar removes the player's safest responses and makes overcommitment dangerous.

### Recovery

A dodge contains a short invulnerability interval inside a longer movement state. It is a timing tool rather than permanent immunity. Healing is primarily available at checkpoints; the Ember Rite combat style provides a limited exception — a 24 HP heal costing 30 Focus with a 0.92s cast time, making it a high-commitment tactical choice rather than a safety net.

## Progression

Defeated enemies award **embers**. Death drops all carried embers as a **Lost Echo** at the death location. Death also resets all regular enemies to their spawn positions. Reaching the echo restores the amount. Dying again replaces the prior echo.

Resting at an activated Ember Shrine offers a **Vitality Forging** option: spend embers to permanently increase max health by 10 HP per tier (up to 3 tiers, costing 50 / 120 / 250 embers). This upgrade persists across deaths and application restarts, giving the death-recovery loop a progressive anchor.

The Ember Shrine updates the respawn point, restores health and stamina, and revives regular enemies. The shortcut remains open for the current application run, rewarding spatial progress even after death.

## Encounter Design

- **Hollow Sentinel:** A basic melee construct that closes distance, telegraphs one strike, and retreats into recovery.
- **Cinder Guardian:** A larger construct with more health, longer reach, a dedicated health bar, and distance-dependent attack selection (close-range swipes, mid-range alternating quick/delayed strikes, long-range lunges). At 50% health the Guardian enters a more aggressive second phase with faster attacks, increased damage, and a distinct fiery visual transformation.
- **Ruins:** Broken walls create sight-line changes and opportunities to separate enemies. The side lever returns toward the shrine through the shortcut gate.

## Tuning Targets

| Value | Target |
|---|---:|
| Player health | 100 |
| Player stamina | 100 |
| Light attack cost | 20 |
| Heavy attack cost | 38 |
| Dodge cost | 26 |
| Regular enemy hits to defeat | 3–5 light hits |
| Guardian hits to defeat | 10–15 mixed hits |
| Lock-on range | about 18 metres |
| Interaction range | 3 metres |

These values are prototype targets, not claims about any existing game.

## Scope Boundaries

The vertical slice intentionally excludes inventory grids, equipment statistics, character creation, online features, dialogue trees, quests, save slots, consumable healing, complex animation retargeting, and imported art. Those systems would increase production cost without improving validation of the core combat loop.
