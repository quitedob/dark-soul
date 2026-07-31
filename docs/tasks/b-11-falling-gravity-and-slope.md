# B-11 — Enhanced Falling Gravity and Slope Slide Prevention

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review — Third-Person Controller cross-pollination; `scripts/PlayerTemplate.gd:103-107`

---

## Problem

Ashen Hollow uses standard `gravity * 1` for falling and has no slope-slide prevention on the player (enemies use `floor_snap_length = 0.35` but the player does not). Two simple game-feel improvements from the Third-Person Controller example:

1. **Doubled falling gravity:** `gravity * 2` when airborne creates snappier, heavier-feeling jumps and falls — standard action-game technique
2. **Floor-normal slope prevention:** `-get_floor_normal() * gravity / 3` glues the character to slopes, preventing slow slide-off

## Target

### Falling gravity

```gdscript
# player.gd:_update_velocity() — gravity section (~line 298)
func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        # Double gravity when falling for snappier feel
        var grav_mult := 2.0 if velocity.y < 0.0 else 1.0
        velocity.y -= gravity * grav_mult * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0  # grounded, clear downward velocity
```

### Slope slide prevention

```gdscript
# When grounded and not actively moving on slopes:
if is_on_floor() and horizontal_input.length() < 0.1:
    var floor_normal := get_floor_normal()
    if floor_normal.y < 0.99:  # on a slope
        velocity += floor_normal * gravity * delta / 3.0  # slight downward along slope
```

Or simply:

```gdscript
# Add to player CharacterBody3D
floor_snap_length = 0.35  # match enemy value
floor_max_angle = deg_to_rad(45.0)
```

## Acceptance Criteria

- [ ] Player falls with noticeably snappier/heavier feel
- [ ] Player does not slowly slide off inclined surfaces when idle
- [ ] Jump arc height unchanged (only falling phase affected)
- [ ] No clipping through floors at high fall speeds
- [ ] Existing movement tests continue to pass
- [ ] Manual feel test: jump off ledge — landing should feel crisp
