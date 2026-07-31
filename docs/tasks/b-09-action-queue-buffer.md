# B-09 — Implement Action Queue Input Buffer System

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review — Adventure Mode Godot cross-pollination; `scripts/actor.gd:437-468`
**Authority:** `docs/controls.md` §Combat Inputs

---

## Problem

Ashen Hollow currently has a single-slot 150ms input buffer (`_buffered_action` in `player.gd:684-706`) but no generic multi-action buffer. Actions are consumed immediately when the state machine transitions, meaning inputs pressed slightly before the state machine is ready are dropped.

Adventure Mode Godot has a simple, dependency-free Action Queue that supports multiple concurrent buffered actions with auto-expiry — exactly what a Souls-like needs for responsive combat feel.

## Target

Adopt the Adventure Mode Action Queue pattern:

```gdscript
# player.gd — new action queue
const ACTION_Q_BUFFER_MS := 150
var _action_queue: Dictionary = {}  # StringName → int (expiry tick msec)

func enqueue_action(action: StringName, duration_ms: int = ACTION_Q_BUFFER_MS) -> void:
    _action_queue[action] = Time.get_ticks_msec() + duration_ms

func _process_action_queue() -> void:
    var now := Time.get_ticks_msec()
    for key in _action_queue.keys():
        if _action_queue[key] <= now:
            _action_queue.erase(key)

func action_queued(action: StringName, consume: bool = false) -> bool:
    if action in _action_queue:
        if consume:
            _action_queue.erase(action)
        return true
    return false
```

### Integration points

Replace direct action checks in `_handle_action_input()` with queue consumption:

```gdscript
# BEFORE:
if Input.is_action_just_pressed("light_attack"):
    _begin_light_attack()

# AFTER:
if Input.is_action_just_pressed("light_attack"):
    enqueue_action(&"light_attack")

# In state update, when ready to accept:
if action_queued(&"light_attack", true):
    _begin_light_attack()
```

### Key behaviors

- Multiple actions can be queued simultaneously (e.g., dodge + attack)
- Actions auto-expire after buffer window (no stale inputs)
- `consume=true` removes the action so it only fires once
- Replaces or complements the existing single-slot `_buffered_action`

## Acceptance Criteria

- [ ] Action queue accepts multiple concurrent buffered actions
- [ ] Actions auto-expire after buffer window (150ms default)
- [ ] Queue is processed each frame in `_physics_process`
- [ ] Attacking during recovery window buffers the attack for the next available frame
- [ ] Dodge can be buffered during attack recovery
- [ ] Input feel is audibly more responsive (no dropped inputs at combo boundaries)
- [ ] Existing FSM tests continue to pass
- [ ] Manual test: spam light attack — combo should chain smoothly without dropped inputs

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Buffered actions fire in wrong state | Low | State machine validates state before consuming actions |
| Queue accumulates stale actions | Low | Auto-expiry after buffer window |
| Conflicts with existing `_buffered_action` | Low | Replace existing buffer with queue; single source of truth |
