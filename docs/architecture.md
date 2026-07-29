# Architecture

## Runtime Composition

`main.tscn` contains one scripted `Node3D`. `game_world.gd` creates the complete playable scene at runtime. This keeps the project self-contained and makes every visual reproducible without imported assets.

```text
AshenHollow (Node3D, game_world.gd)
├── WorldEnvironment
├── DirectionalLight3D / OmniLight3D
├── StaticBody3D ruin geometry
├── ProceduralAudio
├── HUD
├── Warden (CharacterBody3D, player.gd)
│   ├── collision and primitive visual rig
│   ├── CombatArea
│   └── camera pivot / SpringArm3D / Camera3D
├── EmberShrine (Area3D)
├── AncientLever (Area3D)
├── ShortcutGate (Node3D + StaticBody3D)
├── HollowSentinel instances (CharacterBody3D, enemy.gd)
└── CinderGuardian (CharacterBody3D, enemy.gd)
```

## Responsibilities

- `game_world.gd`: Composition root, level generation, input registration, enemy registry, checkpoint/death loop, shortcut and victory progression.
- `player.gd`: Authoritative player state, movement, camera, targeting, stamina, attacks, invulnerability, damage, death, and embers.
- `enemy.gd`: Enemy finite state machine, navigation, telegraphs, attack timing, damage, reset, and rewards.
- `combat_area.gd`: Reusable `Area3D` damage window that records bodies already hit during a swing.
- `hud.gd`: Health/stamina/ember display, prompts, lock marker, guardian bar, messages, pause, and help.
- `checkpoint.gd`, `shortcut.gd`, `lost_echo.gd`: Small world interactions with procedural visuals.
- `procedural_audio.gd`: Runtime-generated PCM sound cues and pooled playback.

## Collision Layers

| Layer | Meaning |
|---:|---|
| 1 | Static world |
| 2 | Player body |
| 3 / value 4 | Enemy bodies |

Player attack areas mask enemy bodies. Enemy attack areas mask the player. Attack areas have no collision layer of their own and are monitor-only.

## State Machines

### Player

```text
LOCOMOTION -> ATTACK_WINDUP -> ATTACK_ACTIVE -> ATTACK_RECOVERY -> LOCOMOTION
LOCOMOTION -> DODGE -> LOCOMOTION
ANY_DAMAGEABLE -> STAGGER -> LOCOMOTION
ANY_DAMAGEABLE -> DEAD -> RESPAWN -> LOCOMOTION
```

### Enemy

```text
IDLE -> CHASE -> WINDUP -> ACTIVE -> RECOVERY -> CHASE
CHASE -> RETURN -> IDLE
ANY_DAMAGEABLE -> STAGGER -> CHASE
ANY_DAMAGEABLE -> DEAD -> RESET -> IDLE
```

Gameplay timers determine damage windows and invulnerability. Procedural poses visualize those states but do not decide whether a hit is valid.

## Data Flow

The player emits stat, ember, lock target, and death signals. The world owns progression outcomes and forwards presentation updates to the HUD. Enemies emit health, engagement, and defeat signals. Interactables call narrow world methods rather than owning global progression.

## Headless Validation

Passing `--smoke-test` as a user argument exercises construction, player stat changes, player damage/heal, and enemy damage before printing `ASHEN_HOLLOW_SMOKE_OK` and exiting. A standard bounded headless run additionally checks several seconds of physics and AI updates.
