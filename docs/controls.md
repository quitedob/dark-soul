# Controls — 烬渊 (Ember Abyss)

The game uses semantic right-hand and left-hand actions. Their exact behavior changes with the equipped loadout, while the physical bindings stay consistent.

## Keyboard and Mouse

### Movement and Camera

| Action | Binding | Notes |
|---|---|---|
| Move | `W`, `A`, `S`, `D` | Camera-relative |
| Sprint | Hold left `Shift` | Drains stamina while moving |
| Jump | `V` | Grounded locomotion only; separate from dodge. Airborne light = jump attack; airborne falling heavy = falling attack |
| Dodge | `Space` | Directional roll with invulnerability; pure back input = backstep (no i-frames). Recovery window enables roll/backstep attacks |
| Sprint + attack | Hold `Shift` + attack | Sprint attack while moving at sprint speed |
| Orbit camera | Mouse movement | Uses SpringArm3D collision avoidance |
| Lock on / cycle | `Q` or middle mouse | First press acquires a centered visible target; later presses cycle by screen angle |
| Interact / rest | `E` | Shrines, levers, and Lost Echo |

### Combat

| Semantic action | Mouse | Keyboard | Meaning |
|---|---|---|---|
| Right primary | Left mouse | `J` | Light attack; **riposte/backstab/weak-point** when an execution candidate is in range |
| Right secondary | Right mouse | `K` | Heavy attack (tap) or charged heavy (hold/release); power shot / stronger spell |
| Left primary | — | `C` | Guard, off-hand attack, or spell shield (disabled while two-handing) |
| Left secondary | — | `R` | Parry, off-hand heavy, or utility action |
| Weapon skill | — | `F` | Style-specific special action |
| Cast | — | `G` | Current style spell or prayer |
| Cycle style | — | `Tab` | Cycles all five compatibility loadouts |
| Toggle grip | — | `T` | Cycles grip. Two-hand: **1.3× damage / 1.5× stamina**, no shield. Jump slash only if hands share `weapon_type` (or two-handing) |

## Settings

| Setting | Default | Where | Effect |
|---|---|---|---|
| Combat Tip Mode (`combat_tip_mode`) | **Off** | Pause → Combat Tip Mode | When on, shows teaching HUD for charge tiers, grip, context attacks, jump-slash denial, and weapon arts. Rules still apply when off. |
| Combat Hitbox Debug | Off | `F3` / settings | Visualizes active CombatArea capsules |
| Direct style select | — | `1`–`5` | Selects a loadout directly |

### Menus

| Action | Binding |
|---|---|
| Pause | `Esc` |
| Help | `F1` |
| Hitbox debug | `F3` | Toggles CombatArea capsule visualization |

## Controller

| Xbox | PlayStation | Action |
|---|---|---|
| Left stick | Left stick | Move |
| Right stick | Right stick | Orbit camera |
| `RB` | `R1` | Right primary |
| `RT` | `R2` | Right secondary |
| `LB` | `L1` | Left primary |
| `LT` | `L2` | Left secondary |
| `B` | Circle | Weapon skill |
| `X` | Square | Parry compatibility action |
| `A` | Cross | Dodge |
| D-pad up | D-pad up | Jump |
| `Y` | Triangle | Interact / rest |
| `L3` | `L3` | Sprint |
| `R3` | `R3` | Lock on / cycle |
| D-pad right | D-pad right | Cycle style |
| Start | Options | Pause |
| Back | Touchpad/Create | Help |

## Touch and Mobile

- The left-side dynamic stick controls movement.
- Dragging the right-side camera zone orbits the camera.
- `R1`, `R2`, `L1`, and `L2` buttons show the current equipment-driven action labels.
- Tap `DODGE / SPRINT` to dodge; hold it for at least 0.32 seconds to sprint.
- `LOCK`, `USE`, and `PAUSE` occupy the upper-right utility cluster.
- Touch controls use a minimum 48-pixel target, configurable UI scale, and configurable opacity.
- Mobile controls are enabled for mobile builds, coarse-pointer Web hosts, or narrow screens.

## Combat Loadouts

### Reliquary Guard — Sword and Shield

| Input | Action | Cost / behavior |
|---|---|---|
| Right primary | Sword light | 22 stamina |
| Right secondary | Sword heavy | 40 stamina; shield bash while guarding |
| Left primary | Shield guard | 82% frontal absorption; stability-driven stamina loss |
| Left secondary | Medium-shield parry | 0.40 s startup, 0.20 s active, heavy miss recovery |
| Weapon skill | Pierce Thrust | 26 stamina; unblockable lunge |
| Dodge | Guard-style dodge | 24 stamina |

Additional parry-capable equipment uses its own data profile: the Jade Buckler has a wider active window and harsher miss penalty, while dagger and fist parries recover faster.

### Twin Colossi — Paired Axes

| Input | Action | Cost / behavior |
|---|---|---|
| Right primary | Right axe strike | 38 stamina |
| Right secondary | Colossal Leap | 38 stamina; heavy leap |
| Left primary | Left axe strike | 38 stamina |
| Left secondary | Left heavy | 65 stamina |
| Weapon skill | Colossal Leap | 38 stamina; hyper armor during heavy execution |
| Dodge | Heavy dodge | 32 stamina |

### Crescent Pair — Bow and Dagger

| Input | Action | Cost / behavior |
|---|---|---|
| Right primary | Quick shot | 16 stamina |
| Right secondary | Power shot | 28 stamina |
| Left primary | Dagger slash | Uses the light action profile |
| Left secondary | Dagger feint | Uses the heavy action profile |
| Weapon skill | Crescent Leap | 27 stamina; two-hit curved leap |
| Dodge | Agile dodge | 18 stamina |

### Veilcraft — Seal and Spirit Stone

| Input | Action | Cost / behavior |
|---|---|---|
| Right primary | Seal bolt | Focus-driven spell action |
| Right secondary | Seal burst | Stronger Focus-driven spell action |
| Left primary | Spell shield | 58% frontal absorption |
| Left secondary | Stone pulse | Off-hand utility |
| Weapon skill | Arcane Barrage | 20 Focus |
| Cast | Veil Bolt | 14 Focus |
| Dodge | Mystic dodge | 22 stamina |

### Ember Rite — Prayer Beads and Talismans

| Input | Action | Cost / behavior |
|---|---|---|
| Right primary | Beads heal | Focus-driven prayer |
| Right secondary | Ember Rite | Stronger prayer |
| Left primary | Talisman strike | Off-hand action |
| Left secondary | Talisman burst | Off-hand heavy action |
| Weapon skill | Divine Smite | 22 Focus |
| Cast | Ember Rite heal/AoE | 20–35 Focus depending on action |
| Dodge | Prayer dodge | 24 stamina |

## Planned Combat Inputs

The combat system includes hold-to-charge heavies, grip modes, human executions, **Boss Execution Break / weak-point executions**, and a **Boss grab telegraph** vertical slice. See [Combat Execution, Guard & Weapon Arts](systems/combat-execution-guard-weapon-arts.md).

## Resources

| Resource | HUD | Rules |
|---|---|---|
| Vitality | Red bar and numeric value | Rest, upgrades, and Ember Rite restore or increase it |
| Endurance | Green bar and numeric value | Regenerates after the spend delay while locomoting |
| Focus | Blue bar and numeric value | Powers Veilcraft and Ember Rite actions |
| Embers | Top-right counter | Earned from enemies; dropped into a Lost Echo on death |

## Accessibility

- UI scale, text scale, control opacity, camera sensitivity, camera inversion, reduced motion, high contrast, locale, and quality preset are configurable.
- Reduced motion disables HUD tween motion; gameplay camera effects must also honor this setting.
- Bars include numeric values and do not rely only on color.
- Keyboard alternatives exist for all mouse combat actions.
- The help and pause overlays take keyboard focus when opened.

## References

- [Game Design](game-design.md)
- [Combat Style System](systems/combat-styles.md)
- [Validation](validation.md)
