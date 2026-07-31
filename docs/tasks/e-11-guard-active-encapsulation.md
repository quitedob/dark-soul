# E-11 — Encapsulate `guard_active` in Explicit Setter

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review full audit 2026-07-30, finding M-2

---

## Problem

`guard_active` in `player.gd` is modified from two separate locations with implicit coupling:

1. `_change_state()` at line 1703-1704: sets `guard_active = false` when leaving LOCOMOTION
2. `_handle_action_input()`: re-evaluates guard state independently

There is no explicit contract: the guard deactivation logic is split across two methods, making it fragile to refactoring. Adding a new state that should also support guard requires updating both locations.

```gdscript
# _change_state() — guards deactivation on state exit
if new_state != State.LOCOMOTION:
    guard_active = false  # ❌ implicit knowledge that only LOCOMOTION supports guard

# _handle_action_input() — re-evaluates independently
if Input.is_action_pressed("guard"):
    guard_active = true   # ❌ no coordination with _change_state()
```

## Target

Create an explicit `_set_guard_active(value: bool)` method that encapsulates all guard state transitions:

```gdscript
func _set_guard_active(value: bool) -> void:
    if value and state != State.LOCOMOTION:
        return  # guard only allowed in locomotion
    if guard_active == value:
        return  # no change
    guard_active = value
    if guard_active:
        _begin_guard()
    else:
        _end_guard()

func _begin_guard() -> void:
    # guard meter start, animation blend, stance change
    pass

func _end_guard() -> void:
    # guard meter stop, animation blend, stance restore
    pass
```

Then replace all direct `guard_active = ...` assignments with `_set_guard_active(...)` calls.

## Acceptance Criteria

- [ ] All guard state changes go through `_set_guard_active()`
- [ ] No direct assignments to `guard_active` outside the setter
- [ ] Guard is only active during `State.LOCOMOTION`
- [ ] `_change_state()` calls `_set_guard_active(false)` for non-locomotion transitions
- [ ] Existing guard contract tests continue to pass
- [ ] Guard meter behavior unchanged
