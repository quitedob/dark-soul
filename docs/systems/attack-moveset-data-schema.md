# Attack and Moveset Data Schema

> **Status:** Core Resources implemented (`AttackData` / `MovesetData` / `ChargeProfile` / `WeaponData` / `WeaponArtData` / `ExecutionProfile`); Reliquary authored `.tres` present; grip/charge/context/guard-execution runtime shipped. AnimationTree root-motion is a straight-sword POC only.
>
> **Purpose:** Replace per-style scalar dictionaries and code-specific dispatch with composable Resources for attacks, movement actions, defensive tools, paired interactions, and weapon arts. Existing `CombatStyleData` remains a compatibility container until its gameplay fields are migrated.

## Ownership Rules

1. `AttackData` owns one attack's gameplay timing, costs, hit payload, movement, tags, and chaining.
2. `MovesetData` maps stance and context to `AttackData`; it does not duplicate attack values.
3. `WeaponData` selects one-hand, two-hand, or paired movesets and owns critical/requirement metadata.
4. `GuardProfile` belongs to a defensive tool or valid weapon guard mode.
5. `ExecutionProfile` owns paired critical interaction requirements and damage timing.
6. `MovementActionProfile` owns dodge, backstep, jump, and landing immunity/cancel rules.
7. Animation resources consume these IDs and timings; animation names never determine gameplay behavior.
8. `CombatArea` remains the shared hit payload boundary and receives normalized metadata from `AttackData`.

## Enumerations

```gdscript
enum GripMode {
    ONE_HANDED,
    TWO_HANDED,
    PAIRED,
}

enum AttackContext {
    NEUTRAL_LIGHT,
    NEUTRAL_HEAVY,
    CHARGED_HEAVY,
    SPRINT,
    ROLL_RECOVERY,
    BACKSTEP_RECOVERY,
    JUMP,
    FALLING,
    GUARD_COUNTER,
    WEAPON_ART_LIGHT,
    WEAPON_ART_HEAVY,
}

enum VulnerabilityType {
    NONE,
    GUARD_BREAK,
    PARRY,
    BACK,
    WEAK_POINT,
}
```

Use globally registered enums or dedicated scripts rather than duplicating integer values across Resources.

## `AttackData`

Suggested path: `game/scripts/combat/data/attack_data.gd`

```gdscript
class_name AttackData
extends Resource

@export_group("Identity")
@export var action_id: StringName
@export var display_name_key: StringName
@export var animation_name: StringName
@export var hand: StringName = &"right"
@export var grip_mode: int
@export var tags: Array[StringName] = []

@export_group("Timeline")
@export_range(0.0, 5.0, 0.01) var windup_seconds := 0.30
@export_range(0.01, 2.0, 0.01) var active_seconds := 0.15
@export_range(0.0, 5.0, 0.01) var recovery_seconds := 0.35
@export_range(0.0, 5.0, 0.01) var chain_open_seconds := 0.0
@export_range(0.0, 5.0, 0.01) var chain_close_seconds := 0.0
@export_range(0.0, 5.0, 0.01) var dodge_cancel_seconds := -1.0

@export_group("Costs")
@export_range(0.0, 200.0, 0.5) var stamina_cost := 20.0
@export_range(0.0, 200.0, 0.5) var focus_cost := 0.0
@export_enum("START", "BRANCH_CONFIRMED", "HIT") var stamina_spend_timing := 0
@export_enum("START", "BRANCH_CONFIRMED", "HIT") var focus_spend_timing := 0

@export_group("Hit Payload")
@export_range(0.0, 1000.0, 0.5) var damage := 20.0
@export_range(0.0, 500.0, 0.5) var poise_damage := 16.0
@export_range(0.0, 500.0, 0.5) var guard_power := 24.0
@export_range(0.0, 500.0, 0.5) var execution_break_damage := 0.0
@export var blockable := true
@export var parryable := true
@export var critical_multiplier := 1.0

@export_group("Movement")
@export var root_motion_mode: int
@export var authored_displacement := Vector3.ZERO
@export_range(0.0, 720.0, 1.0) var max_turn_degrees_per_second := 240.0
@export var lock_turn_after_active := true

@export_group("Action Armor")
@export_range(0.0, 2.0, 0.01) var poise_modifier_windup := 0.0
@export_range(0.0, 2.0, 0.01) var poise_modifier_active := 0.0
@export_range(0.0, 2.0, 0.01) var poise_modifier_recovery := 0.0

@export_group("Hitbox")
@export var hitbox_socket: StringName = &"weapon_tip"
@export var hitbox_shape: Shape3D
@export var hitbox_offset := Transform3D.IDENTITY
@export_range(1, 8, 1) var maximum_hits_per_target := 1
@export_range(0.0, 2.0, 0.01) var repeat_hit_interval_seconds := 0.0

@export_group("Chains")
@export var next_light: AttackData
@export var next_heavy: AttackData
@export var on_hit_followup: AttackData
@export var on_guard_followup: AttackData
@export var chain_requires_hit := false   # L-07: chain continues only if the hit lands; whiffed swings do not chain
```

### Validation

- All durations must be non-negative and `active_seconds > 0`.
- Chain windows must fit within the attack's total duration.
- `dodge_cancel_seconds` is either `-1` or inside recovery.
- A `grab` attack cannot use the normal hitbox path.
- `unblockable` tag requires `blockable=false`; `unparryable` requires `parryable=false`.
- `ground_wave` and physical weapon hits must be separate `AttackData` entries if they can hit independently.
- Multi-hit attacks require explicit `maximum_hits_per_target` and repeat interval.
- `focus_spend_timing=HIT` is forbidden for projectiles that can despawn without resolving ownership; use start or branch confirmation.

## Charge Profile

A charged attack should not create one Resource per arbitrary hold duration. Use discrete authored tiers.

```gdscript
class_name ChargeProfile
extends Resource

@export var minimum_hold_seconds := 0.20
@export var tier_two_seconds := 0.75
@export var tier_three_seconds := 1.40
@export var tier_one_attack: AttackData
@export var tier_two_attack: AttackData
@export var tier_three_attack: AttackData
@export var release_on_stamina_failure := true
```

Charge only changes to a tier with its own authored timing and movement. Avoid continuous damage interpolation that makes animation and hit feedback disagree.

## `MovesetData`

Suggested path: `game/scripts/combat/data/moveset_data.gd`

```gdscript
class_name MovesetData
extends Resource

@export var moveset_id: StringName
@export var grip_mode: int
@export var neutral_light: AttackData
@export var neutral_heavy: AttackData
@export var charged_heavy: ChargeProfile
@export var sprint_attack: AttackData
@export var roll_attack: AttackData
@export var backstep_attack: AttackData
@export var jump_attack: AttackData
@export var falling_attack: AttackData
@export var guard_counter: AttackData
@export var weapon_art_light: AttackData
@export var weapon_art_heavy: AttackData
```

A moveset may leave unsupported contexts empty. The input resolver must fall back deliberately, not silently substitute neutral light for every missing action.

## `WeaponData`

Suggested path: `game/scripts/combat/data/weapon_data.gd`

```gdscript
class_name WeaponData
extends Resource

@export var weapon_id: StringName
@export var weapon_class_id: StringName
@export var one_hand_moveset: MovesetData
@export var two_hand_moveset: MovesetData
@export var paired_moveset: MovesetData
@export var guard_profile: GuardProfile
@export var default_weapon_art: WeaponArtData
@export_range(0.5, 5.0, 0.05) var critical_multiplier := 1.0
@export var supports_backstab := true
@export var supports_riposte := true
```

`HandEquipment.ITEMS` should eventually point to `WeaponData` / defensive Resources instead of embedding action IDs and defensive dictionaries.

## `WeaponArtData`

Suggested path: `game/scripts/combat/data/weapon_art_data.gd`

```gdscript
class_name WeaponArtData
extends Resource

@export var art_id: StringName
@export var stance_animation: StringName
@export var entry_attack: AttackData
@export var light_branch: AttackData
@export var heavy_branch: AttackData
@export var guard_success_branch: AttackData
@export var requires_guard_success := false
@export var cooldown_seconds := 0.0
@export var uses_per_rest := 0
```

At least two of Focus, stamina, recovery, interruption, cooldown, use count, or positional prerequisite must be non-trivial. A validator should reject no-cost, uninterruptible, zero-recovery arts unless explicitly marked for developer testing.

## `GuardProfile`

Suggested path: `game/scripts/combat/data/guard_profile.gd`

```gdscript
class_name GuardProfile
extends Resource

@export_range(1.0, 180.0, 1.0) var guard_angle_degrees := 120.0
@export_range(0.0, 1.0, 0.01) var physical_absorption := 0.80
@export_range(0.0, 0.95, 0.01) var stability := 0.65
@export_range(0.0, 500.0, 1.0) var max_guard_meter := 100.0
@export_range(0.0, 500.0, 1.0) var direct_break_threshold := 75.0
@export_range(0.0, 4.0, 0.05) var guard_meter_damage_multiplier := 1.0
@export_range(0.0, 4.0, 0.05) var stamina_damage_multiplier := 1.0
@export var can_parry := false
@export var parry_start_seconds := 0.10
@export var parry_active_seconds := 0.12
@export var parry_recovery_seconds := 0.42
@export var parry_miss_multiplier := 1.0
```

During migration, adapt the existing dictionary fields:

| Current key | Target field |
|---|---|
| `absorption` | `physical_absorption` |
| `stability` | `stability` |
| `front_dot` | derived from `guard_angle_degrees` or retained as cached runtime value |
| parry `startup` | `parry_start_seconds` |
| parry `active` | `parry_active_seconds` |
| parry `recovery` | `parry_recovery_seconds` |
| parry `miss_penalty` | `parry_miss_multiplier` |

## `MovementActionProfile`

Suggested path: `game/scripts/combat/data/movement_action_profile.gd`

```gdscript
class_name MovementActionProfile
extends Resource

@export var action_id: StringName
@export var animation_name: StringName
@export_range(0.0, 5.0, 0.01) var duration_seconds := 0.50
@export var full_body_invulnerability_start_seconds := -1.0
@export var full_body_invulnerability_end_seconds := -1.0
@export var lower_body_low_sweep_immunity_start_seconds := -1.0
@export var lower_body_low_sweep_immunity_end_seconds := -1.0
@export_range(0.0, 200.0, 0.5) var stamina_cost := 20.0
@export var can_cancel_to_attack := false
@export var followup_attack: AttackData
@export var authored_displacement := Vector3.ZERO
```

A jump profile normally leaves full-body invulnerability at `-1`; it uses lower-body low-sweep immunity instead.

## `ExecutionProfile`

Suggested path: `game/scripts/combat/data/execution_profile.gd`

```gdscript
class_name ExecutionProfile
extends Resource

enum ExecutionType {
    FRONT_RIPOSTE,
    BACKSTAB,
    WEAK_POINT,
}

@export var profile_id: StringName
@export var execution_type: ExecutionType
@export var allowed_vulnerability: int
@export_range(0.1, 5.0, 0.05) var interaction_distance := 2.0
@export_range(1.0, 180.0, 1.0) var interaction_angle_degrees := 45.0
@export_range(0.1, 10.0, 0.05) var vulnerability_seconds := 2.2
@export_range(0.1, 10.0, 0.05) var critical_multiplier := 2.5
@export var initiator_animation: StringName
@export var victim_animation: StringName
@export var required_anchor: StringName = &"chest"
@export var damage_event_name: StringName = &"critical_damage"
@export var allow_lethal_damage := true
```

Boss weak-point profiles should set `allow_lethal_damage=false` when the encounter must transition to a story choice rather than die.

## `GrabProfile`

Suggested path: `game/scripts/combat/data/grab_profile.gd`

```gdscript
class_name GrabProfile
extends Resource

@export var grab_id: StringName
@export var telegraph_seconds := 1.0
@export var recovery_on_miss_seconds := 1.0
@export var capture_shape: Shape3D
@export var capture_socket: StringName
@export var initiator_animation: StringName
@export var victim_animation: StringName
@export var damage_event_name: StringName = &"grab_damage"
@export var escape_rule: StringName = &"none"
@export var blockable := false
@export var parryable := false
```

Grab resolution must never call `CombatArea.begin_swing()`. It uses an exclusive victim claim, paired-state transition, collision suppression, and event-driven damage.

## Normalized Hit Payload

Extend the current `CombatArea` payload without renaming existing compatibility keys prematurely:

```gdscript
{
    "damage": float,
    "stagger": float,              # compatibility alias during migration
    "poise": float,
    "guard_damage": float,         # compatibility alias for guard_power
    "guard_power": float,
    "execution_break_damage": float,
    "direction": Vector3,
    "source": Node,
    "hand": String,
    "item_id": String,
    "action_id": String,
    "tags": Array[StringName],
    "blockable": bool,
    "parryable": bool,
}
```

Do not put direct references to victim animation, execution ownership, or grab state in the ordinary hit payload.

## Runtime Resolution

```text
Input action
→ determine stance and context
→ MovesetData resolves AttackData
→ validate state, resources, and prerequisites
→ enter windup and spend configured resources
→ animation and gameplay timer consume same AttackData
→ active event configures CombatArea payload
→ defender resolves grab / parry / guard / poise / HP in that order
→ recovery opens declared chain and cancel windows
```

Recommended defender resolution order:

```text
1. Grab capture path?          → GrabResolver
2. Valid parry interaction?    → ParryResolver
3. Valid guard interaction?    → GuardResolver
4. Apply HP damage
5. Apply Poise damage
6. Apply Execution Break to an eligible weak point
7. Emit hit feedback and chain result
```

## Runtime Validation Audit (J-12 — 2026-07-30)

Checked against `game/scripts/combat/data/` and player commit path:

| Resource | Path | Status |
|----------|------|--------|
| `AttackData` | `attack_data.gd` | Present — timing, costs, hitbox, dodge_cancel, focus_cost, `validate()`, `to_hit_metadata()` |
| `MovesetData` | `moveset_data.gd` | Present — context resolve + charged heavy |
| `ChargeProfile` | `charge_profile.gd` | Present — tier hold thresholds |
| `WeaponData` | `weapon_data.gd` | Present — grip flags + moveset slots |
| `WeaponArtData` | `weapon_art_data.gd` + `weapon_arts_catalog.gd` | Present — 9 authored `.tres` (`resources/weapon_arts/`, L-13); `_execute_weapon_art` `match` dispatch retained (A-06 still open) |
| `ExecutionProfile` | `execution_profile.gd` | Present |
| `GuardProfile` | `guard_profile.gd` | Present — still dual-owned with HandEquipment dicts |
| `GrabProfile` | `grab_profile.gd` | Present — runtime via `GrabPairedDirector` + independent capture Area3D |
| `MovementActionProfile` | — | **Not a separate class yet**; dodge/backstep live on player + `CombatStyleData` |

Ownership rules 1–3 and 8 are active via `CompatibilityMovesetFactory` → `_commit_attack` → `CombatArea`.

Related runtime (not Resource schemas, but combat polish):

- `CombatCameraDirector` + `CameraShotProfile` — Boss exclusive shots
- `BossFateCatalog` + `FateChoiceOverlay` — story floor → string `choice_flags`
- `WeaponArtsCatalog` — per-class `WeaponArtData` lookup over 9 authored `.tres` (L-13)

Remaining gaps (tracked elsewhere):

- A-06: finish weapon-art `match` removal  
- A-07: HandEquipment → Resource references  
- D-01: AnimationTree root motion beyond POC  
- E-07: Guard Meter full ownership on `GuardProfile`

Automated coverage: `tests/unit/combat/test_attack_moveset_schema.gd` (+ grip/charge smoke contracts).

## Migration Plan

1. Freeze existing `CombatStyleData` values and record compatibility tests.
2. Remove gameplay reads from legacy `STYLE_TIMING`; move leap, dodge, and action armor to the existing `.tres` first.
3. Implement the new Resource classes and validators without changing behavior.
4. Encode existing sword light/heavy, paired axes, Crescent leap, shield bash, Pierce Thrust, Arcane Barrage, and Divine Smite as Resources.
5. Replace `_try_attack()` scalar lookup with `MovesetData` resolution.
6. Replace weapon-art style `match` dispatch with `WeaponArtData`.
7. Migrate `HandEquipment` dictionaries to Resource references.
8. Add new move contexts only after parity tests pass.

## Contract Tests

Minimum headless contracts:

- Every `WeaponData` has a valid neutral action for each supported grip mode.
- Every referenced `AttackData` has legal durations, costs, tags, and chain windows.
- Existing five compatibility loadouts resolve to the same action IDs and costs as before migration.
- One swing cannot hit one target more than configured.
- Unblockable and unparryable tags agree with booleans.
- Jump profiles have no accidental full-body invulnerability.
- Guard angle, stamina break, Guard Meter break, and direct impact break are tested independently.
- Execution claims are exclusive and damage occurs once at the event point.
- Boss non-lethal weak-point execution cannot bypass its story threshold.
- Grabs never pass through the ordinary `CombatArea` damage path.
