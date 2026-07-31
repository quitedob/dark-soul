# B-10 — Dodge/Sprint Dual-Button Mapping

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review — Adventure Mode Godot cross-pollination; `scripts/playerSocket_adventure.gd:132-147`
**Authority:** `docs/controls.md` §Movement Inputs

---

## Problem

Ashen Hollow currently uses separate buttons for dodge (Space) and sprint (Shift). The Souls-like genre standard is a single button: tap = dodge, hold = sprint. This frees up a button and is a core part of the control feel.

Adventure Mode Godot has a clean implementation using a simple timer threshold (200ms).

## Target

Map dodge and sprint to a single input action using a hold-threshold timer:

```gdscript
# player.gd
const DODGE_SPRINT_THRESHOLD := 0.2  # seconds
var _ds_timer := 0.0

func _process_dodge_sprint(delta: float) -> void:
    if Input.is_action_pressed("dodge"):
        _ds_timer += delta
        if _ds_timer > DODGE_SPRINT_THRESHOLD:
            _set_sprinting(true)
    elif Input.is_action_just_released("dodge"):
        if _ds_timer < DODGE_SPRINT_THRESHOLD and _ds_timer > 0.0:
            _begin_dodge()  # was a tap
        _set_sprinting(false)
        _ds_timer = 0.0
```

### Input map changes

- Remove separate "sprint" action from Input Map
- Keep "dodge" action bound to Space (keyboard) / B/circle (controller)
- The dual-behavior is handled in code, not in the input map

### Edge cases

- If the player is in a state where dodge is invalid but sprint is valid (e.g., LOCOMOTION), holding past threshold enters sprint
- If the player is in a state where both are invalid, neither triggers
- Releasing the button after sprinting stops sprint; no accidental dodge

## Acceptance Criteria

- [ ] Space tap (<200ms) = dodge
- [ ] Space hold (≥200ms) = sprint
- [ ] Releasing Space after sprint stops sprint without triggering dodge
- [ ] Dodge cannot trigger during states where dodge is blocked
- [ ] Sprint cannot trigger during states where sprint is blocked
- [ ] Existing dodge and sprint mechanics unchanged (stamina cost, i-frames, speed)
- [ ] Keyboard: Shift key can remain as alternative sprint-only binding
- [ ] Controller: B/circle works identically (tap dodge, hold sprint)
- [ ] Manual feel test: movement feels like Dark Souls
