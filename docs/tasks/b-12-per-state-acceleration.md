# B-12 — Per-State Acceleration Tuning Parameters

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** A-03 (AttackData has movement fields)
**Blocks:** None
**Source:** Code review — Third-Person Controller cross-pollination; `scripts/PlayerTemplate.gd:99-123`
**Authority:** `docs/game-design.md` §Combat Pillars — Commitment

---

## Problem

Ashen Hollow uses a single `MOVE_ACCELERATION = 24.0` constant for all movement states. The Third-Person Controller example demonstrates that per-state acceleration tuning is critical for Souls-like feel:

- Normal movement: `acceleration = 15`, `angular_acceleration = 10`
- During rolls: `acceleration = 2`, `angular_acceleration = 2` (heavy movement restriction)
- During big attacks: `acceleration = 3` (committed feel)

Lower acceleration during actions creates the "committed" feel that is signature to the genre — you can't instantly change direction mid-swing.

## Target

Replace the single `MOVE_ACCELERATION` constant with per-state acceleration multipliers:

```gdscript
# player.gd
const MOVE_ACCELERATION := 24.0          # base, used in LOCOMOTION
const ATTACK_ACCELERATION := 3.0         # during attack states
const ROLL_ACCELERATION := 2.0           # during dodge
const ROLL_ANGULAR_ACCELERATION := 2.0   # rotation during dodge
const SPRINT_ANGULAR_ACCELERATION := 8.0 # rotation during sprint

func _get_current_acceleration() -> float:
    match state:
        State.LOCOMOTION:
            return MOVE_ACCELERATION
        State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY:
            return ATTACK_ACCELERATION
        State.DODGE:
            return ROLL_ACCELERATION
        _:
            return MOVE_ACCELERATION

func _get_current_angular_acceleration() -> float:
    match state:
        State.DODGE:
            return ROLL_ANGULAR_ACCELERATION
        State.LOCOMOTION:
            if _is_sprinting:
                return SPRINT_ANGULAR_ACCELERATION
            return 10.0
        _:
            return 10.0
```

### Future: expose on AttackData

Long-term, these could be `@export` fields on `AttackData`:
```gdscript
@export var movement_acceleration_mult: float = 1.0
@export var rotation_acceleration_mult: float = 1.0
```

## Acceptance Criteria

- [ ] Movement during attack states feels noticeably heavier/more committed
- [ ] Dodge/roll has restricted steering (can't 180-turn mid-roll)
- [ ] Sprint has tighter turning than walk (angular accel difference)
- [ ] Locomotion feel unchanged from current behavior
- [ ] Values are tunable constants (not hardcoded inline)
- [ ] Existing FSM and stamina tests continue to pass

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Attacks feel unresponsive | Medium | Tune ATTACK_ACCELERATION higher if needed; start at 6.0, reduce iteratively |
| Dodge feels sluggish | Low | Souls-like standard is restricted dodge steering; test against DS3 feel |
