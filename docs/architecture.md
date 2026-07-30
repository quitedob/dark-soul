# Architecture

## Runtime Composition

`main.tscn` contains one scripted `Node3D`. `game_world.gd` creates the complete playable scene at runtime. This keeps the project self-contained and makes every visual reproducible without imported assets.

```text
AshenHollow (Node3D, game_world.gd)
├── WorldEnvironment
├── DirectionalLight3D / OmniLight3D / landmark braziers
├── StaticBody3D ruin geometry (walls, pillars, platforms)
├── ProceduralAudio (procedural_audio.gd) — 9 cues, 6-voice pool
├── HUD (hud.gd, CanvasLayer)
│   ├── Title screen / Pause / Death / Victory overlays
│   ├── Vitals bars (HP, Stamina, Focus) + Ember counter
│   ├── Boss bar, interaction prompts, lock-on marker
│   ├── Help overlay, messages panel
│   └── MobileControls (mobile_controls.gd) — touch overlay
├── Warden (CharacterBody3D, player.gd) — 12-state FSM
│   ├── Collision and primitive visual rig (body, cloak, visor)
│   ├── CombatArea (combat_area.gd) — one-hit-per-swing
│   ├── Camera pivot / SpringArm3D / Camera3D
│   └── SpellProjectile spawn point
├── EmberShrine (Area3D, checkpoint.gd)
├── AncientLever (Area3D, shortcut.gd)
├── ShortcutGate (Node3D + StaticBody3D)
├── HollowSentinel ×3 (CharacterBody3D, enemy.gd)
├── AshStalker ×2 (CharacterBody3D, enemy.gd)
├── CinderGuardian (CharacterBody3D, enemy.gd) — boss with phase 2
├── LostEcho (Area3D, lost_echo.gd) — spawned on death
├── GameHostBridge (game_host_bridge.gd) — Web ↔ app protocol
├── NavigationRegion3D — baked navmesh (0.5 m radius, 45° slope)
└── Data classes: AshenRunState, AshenGameSettings, AshenLocalization
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
| 4 / value 8 | Interactables |

Player attack areas mask enemy bodies. Enemy attack areas mask the player. Attack areas have no collision layer of their own and are monitor-only.

## State Machines

### Player

```text
LOCOMOTION -> ATTACK_WINDUP -> ATTACK_ACTIVE -> ATTACK_RECOVERY -> LOCOMOTION
LOCOMOTION -> DODGE -> LOCOMOTION
LOCOMOTION -> PARRY -> LOCOMOTION
LOCOMOTION -> GUARD -> LOCOMOTION
LOCOMOTION -> CAST -> LOCOMOTION
LOCOMOTION -> LEAP_WINDUP -> LEAP_ACTIVE -> LEAP_RECOVERY -> LOCOMOTION
ANY_DAMAGEABLE -> STAGGER -> LOCOMOTION
ANY_DAMAGEABLE -> DEAD -> RESPAWN -> LOCOMOTION
```

### Enemy

```text
IDLE -> CHASE -> WINDUP -> ACTIVE -> RECOVERY -> CHASE
CHASE -> RETURN -> IDLE
ANY_DAMAGEABLE -> STAGGER -> CHASE
ANY_DAMAGEABLE -> DEAD -> RESET -> IDLE
Boss (Cinder Guardian): Phase 1 → Phase 2 at ≤50% HP (faster windups, higher damage, visual/audio transition)
```

Gameplay timers determine damage windows and invulnerability. Procedural poses visualize those states but do not decide whether a hit is valid.

## Data Flow

The player emits stat, ember, lock target, and death signals. The world owns progression outcomes and forwards presentation updates to the HUD. Enemies emit health, engagement, and defeat signals. Interactables call narrow world methods rather than owning global progression.

## Headless Validation

Passing `--smoke-test` as a user argument exercises construction, player stat changes, player damage/heal, and enemy damage before printing `ASHEN_HOLLOW_SMOKE_OK` and exiting. A standard bounded headless run additionally checks several seconds of physics and AI updates.
