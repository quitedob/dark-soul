# Controls

## Keyboard and Mouse

| Action | Primary | Alternative |
|---|---|---|
| Move | `W`, `A`, `S`, `D` | — |
| Orbit camera | Mouse movement | — |
| Light attack | Left mouse button | `J` |
| Heavy attack | Right mouse button | `K` |
| Dodge | `Space` | — |
| Sprint | Left `Shift` while moving | — |
| Lock on / release | Middle mouse button | `Q` |
| Cycle lock-on target | `Q` (on locked target) | — |
| Interact / rest | `E` | — |
| Guard | `C` (Reliquary Guard only) | — |
| Parry | `R` (Reliquary Guard only) | — |
| Special attack / skill | `F` | — |
| Cast spell / prayer | `G` | — |
| Cycle combat style | `Tab` | — |
| Direct style select | `1`–`5` | — |
| Pause | `Esc` | — |
| Help overlay | `F1` | — |

## Controller / Gamepad

| Action | Binding |
|---|---|
| Move | Left stick |
| Orbit camera | Right stick |
| Light attack | `RB` |
| Heavy attack | `LB` |
| Dodge | `A` |
| Sprint | `L3` |
| Lock on / cycle | `R3` |
| Interact / rest | `Y` |
| Guard | Left trigger |
| Parry | `X` |
| Special attack / skill | `B` |
| Cycle combat style | D-pad right |
| Pause | `Start` |
| Help overlay | `Back` |

## Touch / Mobile

| Action | Gesture |
|---|---|
| Move | Virtual joystick (left side) |
| Orbit camera | Drag in camera zone (right side) |
| Light attack | LIGHT button |
| Heavy attack | HEAVY button |
| Dodge | DODGE button (tap) |
| Sprint | DODGE button (hold ≥ 0.32 s) |
| Lock on | LOCK button |
| Interact / rest | USE button |
| Guard | GUARD button |
| Special attack / skill | SKILL button |
| Cycle style | STYLE button |
| Pause | PAUSE button |

Mobile controls auto-detect via `OS.has_feature("mobile")`, JS bridge pointer media query, or screen size ≤ 900 px.

## Combat Styles

| # | Style | Unique Mechanic | Input |
|---|---|---|---|
| 1 | Reliquary Guard | Timed parry (0.06–0.26 s window), shield guard (82% reduction), guarded thrust | Hold `C` to guard, `R` to parry, `F` while guarding for thrust |
| 2 | Twin Colossi | Colossal leap attack (hyper armor during active frames) | `F` for leap |
| 3 | Crescent Pair | Curved two-hit leap attack | `F` for leap |
| 4 | Veilcraft | Veil Bolt projectile (28 dmg, 15 m/s, costs 18 Focus) | `G` to cast |
| 5 | Ember Rite | AoE heal 24 HP + 20 dmg to enemies (costs 30 Focus, 0.92 s cast) | `G` to cast |

## Combat Notes

- Attacking and dodging require enough stamina.
- Stamina starts regenerating after a short delay (only during LOCOMOTION state).
- Lock-on selects a visible target near the camera's forward direction; subsequent presses cycle candidates.
- Dodges include a brief invulnerability window (0.08 s–0.38 s); the complete 0.58 s animation is not invulnerable.
- Resting at the Ember Shrine restores the player and resets enemies.
- Death drops carried embers. Touch the Lost Echo to recover them.
- Input buffering (150 ms window, last-input-wins) allows queuing actions during attack recovery.

## Accessibility

- Every mouse combat action has a keyboard alternative.
- Critical feedback combines text, movement, brightness, and sound rather than relying on color alone.
- Health and stamina include numeric labels and bars.
- The help overlay can be toggled at any time with `F1` and presents controls as separate action/input rows.
- Pause and help menus establish keyboard focus immediately, so their buttons can be navigated without precise mouse input.
- UI scale (0.75–1.6), text scale (0.85–2.0), reduced motion (disables tweens), and high contrast mode are configurable in settings.
- Input actions are registered through Godot's `InputMap`, so they can be moved into a remapping screen in a future iteration.

The prototype supports keyboard/mouse, controller (gamepad), and touch/mobile input. Controller glyphs and an in-game remapping UI are recommended next steps.
