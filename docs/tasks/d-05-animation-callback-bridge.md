# D-05 — Animation Callback Bridge for Frame-Accurate Hitbox Windows

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** D-01 (AnimationTree POC), D-04 (process callback fix)
**Blocks:** None
**Source:** Code review — BreadbinEngine cross-pollination; `Scripts/Actors/ActorAnimationPlayer.gd:21-43`
**Authority:** `docs/systems/attack-moveset-data-schema.md`

---

## Problem

Ashen Hollow currently controls all attack timing via code constants (`state_time <= 0.0` in `player.gd:760-875`). This works but is less precise than frame-accurate animation events for:

1. **Hitbox activation/deactivation** — currently driven by state transitions (`ATTACK_WINDUP → ATTACK_ACTIVE`), not animation keyframes
2. **Combo window open/close** — currently a fixed `chain_window` in AttackData, not animation-driven
3. **Forward impulse timing** — `authored_displacement` is applied uniformly during active, not at specific keyframes
4. **Rotation lock/unlock** — no way to lock facing at specific animation moments

BreadbinEngine's `ActorAnimationPlayer` uses AnimationPlayer method-call tracks to invoke gameplay callbacks at exact keyframes, decoupling animation authoring from code timing.

## Target

Extend `PlayerAnimationBridge` to expose callback methods that can be triggered by animation keyframes via Godot's AnimationPlayer method-call tracks:

```gdscript
# PlayerAnimationBridge.gd — new callback methods
class_name PlayerAnimationBridge
extends Node

signal combo_window_opened
signal combo_window_closed
signal hitbox_activated
signal hitbox_deactivated
signal forward_impulse_requested(amount: float)
signal rotation_locked
signal rotation_unlocked

## Called by AnimationPlayer method track at hitbox start keyframe
func anim_event_hitbox_on() -> void:
    hitbox_activated.emit()

## Called by AnimationPlayer method track at hitbox end keyframe
func anim_event_hitbox_off() -> void:
    hitbox_deactivated.emit()

## Called by AnimationPlayer method track for forward displacement
func anim_event_push_forward(amount: float) -> void:
    forward_impulse_requested.emit(amount)

## Called at combo-window start
func anim_event_combo_open() -> void:
    combo_window_opened.emit()

## Called at combo-window end
func anim_event_combo_close() -> void:
    combo_window_closed.emit()
```

### Integration with player.gd

```gdscript
# player.gd:_ready() or setup()
func _connect_animation_bridge() -> void:
    _anim_bridge.combo_window_opened.connect(_on_combo_window_opened)
    _anim_bridge.combo_window_closed.connect(_on_combo_window_closed)
    _anim_bridge.hitbox_activated.connect(_on_anim_hitbox_activated)
    _anim_bridge.hitbox_deactivated.connect(_on_anim_hitbox_deactivated)

func _on_anim_hitbox_activated() -> void:
    if state == State.ATTACK_WINDUP:
        _change_state(State.ATTACK_ACTIVE)  # transition driven by animation

func _on_anim_hitbox_deactivated() -> void:
    if state == State.ATTACK_ACTIVE:
        _change_state(State.ATTACK_RECOVERY)  # transition driven by animation
```

### Fallback

When animations don't have method tracks (procedural/placeholder), fall back to existing `state_time`-based timing. The animation bridge checks if the current animation has the method track and only emits if it exists.

## Acceptance Criteria

- [ ] Animation method tracks can trigger hitbox activation/deactivation
- [ ] Animation method tracks can open/close combo windows
- [ ] Forward impulse timing is animation-driven when method tracks exist
- [ ] Fallback to `state_time` timing when animation lacks method tracks
- [ ] Existing combat timing unchanged when no animation method tracks present
- [ ] Smoke test passes
