# Controls

## Keyboard and Mouse

| Action | Input |
|---|---|
| Move | `W`, `A`, `S`, `D` |
| Orbit camera | Mouse movement |
| Light attack | Left mouse button or `J` |
| Heavy attack | Right mouse button or `K` |
| Dodge | `Space` |
| Sprint | Left `Shift` while moving |
| Lock on / release | Middle mouse button or `Q` |
| Interact / rest | `E` |
| Pause | `Esc` |
| Help overlay | `F1` |

## Combat Notes

- Attacking and dodging require enough stamina.
- Stamina starts regenerating after a short delay.
- Lock-on selects a visible target near the camera's forward direction.
- Dodges include a brief invulnerability window; the complete dodge animation is not invulnerable.
- Resting at the Ember Shrine restores the player and resets enemies.
- Death drops carried embers. Touch the Lost Echo to recover them.

## Accessibility

- Every mouse combat action has a keyboard alternative.
- Critical feedback combines text, movement, brightness, and sound rather than relying on color alone.
- Health and stamina include numeric labels and bars.
- The help overlay can be toggled at any time with `F1` and presents controls as separate action/input rows.
- Pause and help menus establish keyboard focus immediately, so their buttons can be navigated without precise mouse input.
- Input actions are registered through Godot's `InputMap`, so they can be moved into a remapping screen in a future iteration.

The prototype currently targets keyboard and mouse. Controller glyphs, remapping UI, camera sensitivity settings, subtitle scaling, and reduced-motion options are recommended next steps.
