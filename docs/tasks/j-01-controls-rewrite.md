# J-01 — Rewrite controls.md

**Priority:** P0 (documentation)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** None
**Source:** Audit document §10 "文档治理"; `audit-docs-codebase-health.md` §1.2, §4.1 P1

---

## Problem

`controls.md` is the highest-severity stale document in the project. It was written for the initial prototype (pre-handoff) and is missing:

| Missing Topic | Where Documented Instead |
|---|---|
| Reliquary Guard (timed parry, shield guard, thrust attacks) | `devlog.md`, `game-design.md` |
| Twin Colossi (paired great-blade jump attack, hyper armor) | `player.gd` code |
| Crescent Pair (paired curved-blade two-hit jump attack) | `player.gd` code |
| Veilcraft (focus-powered projectile magic, Arcane Barrage) | `player.gd` code |
| Ember Rite (focus-powered healing and AoE damage prayer) | `player.gd` code |
| Controller bindings (Xbox/PlayStation button mapping) | Not documented anywhere |
| Touch control layout (virtual joystick + action buttons) | Not documented anywhere |
| Focus resource keybinding display | `player.gd` code only |
| Style-switching input | `player.gd` code only |
| Weapon skill (战技) input: F key / B button | `player.gd` code only |

Source of truth: `player.gd` input handling + `game_world.gd._configure_inputs()` + `game-design.md` combat pillars.

## Target Structure

```markdown
# Controls — 烬渊 (Ember Abyss)

## Keyboard & Mouse

### Movement & Camera
| Action | Key | Notes |
|--------|-----|-------|
| Move | WASD | Camera-relative |
| Sprint (hold) | Left Shift | Drains stamina |
| Camera orbit | Mouse movement | SpringArm3D collision avoidance |
| Lock-on / Cycle target | Q / Middle Mouse | Press to lock, press again to cycle, hold to release |
| Interact | E | Shrines, levers, pickups |

### Combat — Core
| Action | Key | Notes |
|--------|-----|-------|
| Right hand primary | Left Mouse | Light attack / Quick shot |
| Right hand secondary | Right Mouse | Heavy attack / Power shot |
| Left hand primary | C | Guard / Block (shield) |
| Left hand secondary | R | Parry / Shield bash |
| Special attack (战技) | F | Weapon art (per-style) |
| Dodge / Roll | Space | Directional, i-frames |
| Style cycle | Tab | Cycle through 5 combat styles |

### Combat — Style-Specific
[Table per style with input summary]

### UI & Menus
| Action | Key |
|--------|-----|
| Pause | Esc |
| Help / Controls | F1 |
| Style switch | 1-5 (number keys) |

## Controller (Xbox / PlayStation)

### Layout Diagram
[Text diagram showing button mapping]

| Xbox | PlayStation | Action |
|------|-------------|--------|
| RB | R1 | Right hand primary (light attack) |
| RT | R2 | Right hand secondary (heavy attack) |
| LB | L1 | Left hand primary (guard) |
| LT | L2 | Left hand secondary (parry) |
| B | Circle | Special attack (weapon art) |
| A | Cross | Dodge / Roll |
| X | Square | Interact |
| Y | Triangle | Cycle style |
| Left Stick | Left Stick | Movement |
| Right Stick | Right Stick | Camera |
| L3 (click) | L3 | Sprint toggle |
| R3 (click) | R3 | Lock-on / Cycle target |
| D-Pad Up/Down | D-Pad Up/Down | Cycle spells |
| Start | Options | Pause |
| Select | Touchpad | Help / Controls |

## Touch Controls (Mobile/Web)

### Layout
[Text description of virtual joystick + button layout]

- Left zone: Virtual joystick (dynamic positioning)
- Right zone: Camera drag area
- Bottom-right: 4 action buttons (R1/R2/L1/L2) + Dodge + Interact
- Context-sensitive labels from equipment definitions
- Sprint: Hold joystick to edge

## Combat Style Input Summary

### 护卫之道 (Reliquary Guard) — Sword + Shield
| Action | Input | Effect |
|--------|-------|--------|
| Light slash | RMB / RB | 22 dmg, 22 stam, fast chain |
| Heavy thrust | LMB / RT | 40 dmg, 40 stam, unblockable |
| Guard | C / LB (hold) | 82% absorption, directional |
| Parry | R / LT (tap) | 0.06-0.26s window, riposte 26 dmg |
| Shield bash | Guard + Heavy | 18 dmg, high stagger |
| Pierce Thrust (战技) | F / B | 26 stam, unblockable, 36 dmg |

### 刑天斧法 (Twin Colossi) — Dual Axes
[Similar table structure]

### 羿弓术 (Crescent Pair) — Bow + Dagger
[Similar table structure]

### 五行术 (Veilcraft) — Seal + Spirit Stone
[Similar table structure]

### 天祝术 (Ember Rite) — Prayer Beads + Talisman
[Similar table structure]

## Resource Display

| Resource | HUD Position | Max | Regen |
|----------|-------------|-----|-------|
| Health (HP) | Top-left bar (red) | 100 + upgrades | Shrine rest / Ember Rite |
| Stamina | Top-left bar (green) | 100 | After 1.5s delay, LOCOMOTION only |
| Focus | Top-left bar (blue) | 100 | Passive, slow |
| Embers | Top-left counter | — | Enemy kills, Lost Echo recovery |

## Accessibility

| Setting | Effect |
|---------|--------|
| UI Scale (0.5-2.0) | HUD element size |
| Text Scale (0.5-2.0) | Font size |
| Reduced Motion | Disables camera shake and Tween animations |
| High Contrast | Increased HUD element contrast |
| Screen Shake Toggle | Enable/disable camera shake |
```

## Implementation Steps

1. Read current `controls.md` to identify any salvageable content
2. Read `player.gd` input handling sections for actual keybinding source of truth
3. Read `game_world.gd._configure_inputs()` for InputMap action names
4. Read `game/scripts/core/input_config.gd` for static binding definitions
5. Read `mobile_controls.gd` for touch layout
6. Write new `controls.md` following the target structure above
7. Add per-style input summary tables (5 tables, one per combat style)
8. Add controller mapping diagram
9. Add touch control layout description
10. Cross-reference with `game-design.md` combat pillars for mechanic descriptions
11. Update `00-master-index.md` to point to new controls.md

## Acceptance Criteria

- [ ] All 5 combat styles have complete input tables with key/controller bindings
- [ ] Weapon skill (战技) input is documented (F key / B button)
- [ ] Controller mapping covers all 24 InputMap actions
- [ ] Touch control layout described
- [ ] Focus resource and style-switching inputs documented
- [ ] No references to pre-handoff prototype remain
- [ ] Accessibility settings documented
- [ ] Cross-reference links to `game-design.md`, `systems/combat-styles.md` work
