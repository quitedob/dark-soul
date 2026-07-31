# F-06 — Camera Auto-Follow Timer for Non-Locked Exploration

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** F-03 (quaternion slerp tracking)
**Blocks:** None
**Source:** Code review — Third-Person Controller cross-pollination; `scripts/CameraTemplate.gd:30,46-49`
**Authority:** `docs/architecture.md` §Camera System

---

## Problem

Ashen Hollow's non-locked camera requires constant manual mouse/gamepad input to adjust. There is no "auto-follow behind player" mode — the camera stays wherever the player last left it. This is functional but misses a polish feature present in most third-person action games: after the player stops manual camera input, the camera smoothly rotates to face the same direction as the player.

The Third-Person Controller example implements this with a simple Timer pattern: after `control_stay_delay` seconds of no manual camera input, the camera auto-rotates behind the character. The rotation speed is proportional to player velocity — faster movement = faster re-center.

## Target

Add a camera auto-follow mode that activates after manual camera input stops:

```gdscript
# player.gd — camera section (~line 2015)
const CAMERA_RECENTER_DELAY := 1.5       # seconds before auto-follow begins
const CAMERA_RECENTER_SPEED := 4.0       # base slerp speed
var _camera_recenter_timer := 0.0

func _process_camera_auto_follow(delta: float) -> void:
    if _is_locked_on:
        return  # lock-on has its own camera logic

    var look_input := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.18)

    if look_input.length() > 0.0:
        _camera_recenter_timer = CAMERA_RECENTER_DELAY  # reset timer on input
        _apply_manual_camera(look_input, delta)
    else:
        _camera_recenter_timer -= delta
        if _camera_recenter_timer <= 0.0:
            _auto_follow_camera(delta)

func _auto_follow_camera(delta: float) -> void:
    # Speed proportional to player velocity
    var h_speed := Vector2(velocity.x, velocity.z).length()
    var dynamic_speed := CAMERA_RECENTER_SPEED * (h_speed / sprint_speed)
    dynamic_speed = maxf(dynamic_speed, 1.0)  # minimum speed even when idle

    # Slerp camera yaw toward player yaw
    var target_yaw := _player_model.rotation.y
    var cam_yaw := camera_rig.rotation.y
    camera_rig.rotation.y = lerp_angle(cam_yaw, target_yaw, dynamic_speed * delta)

    # Slerp camera pitch toward default
    var target_pitch := LOCK_CAMERA_DEFAULT_PITCH  # -0.18 rad
    camera_rig.rotation.x = lerp_angle(camera_rig.rotation.x, target_pitch, dynamic_speed * 0.5 * delta)
```

## Acceptance Criteria

- [ ] Camera auto-rotates behind player after 1.5s of no manual camera input
- [ ] Auto-follow speed increases with player velocity (faster movement = faster recenter)
- [ ] Manual camera input immediately interrupts auto-follow
- [ ] Auto-follow does not activate during lock-on
- [ ] Pitch returns to default angle during auto-follow
- [ ] Existing lock-on camera behavior unchanged
- [ ] Manual feel test: run forward → camera smoothly tracks behind without touching mouse
