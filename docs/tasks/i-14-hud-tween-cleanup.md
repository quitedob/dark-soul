# I-14 — HUD Message Tween Cleanup on Exit Tree

**Priority:** P3 (nice-to-have)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review full audit 2026-07-30, finding M-4

---

## Problem

`hud.gd:show_message()` uses `await` for tweened fade animations. If the HUD is freed (e.g., scene change, game exit) while a message tween is active, the coroutine becomes orphaned and may attempt to access freed nodes, causing errors.

```gdscript
# hud.gd — current pattern:
func show_message(text: String, duration: float = 3.0) -> void:
    _message_label.text = text
    _message_label.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(_message_label, "modulate:a", 1.0, 0.3)
    await tween.finished
    await get_tree().create_timer(duration).timeout
    tween = create_tween()
    tween.tween_property(_message_label, "modulate:a", 0.0, 0.3)
    # ❌ if HUD is freed during awaits, accessing _message_label crashes
```

## Target

Track active tweens and cancel them in `_exit_tree()`, and use `is_instance_valid()` guards:

```gdscript
var _active_message_tween: Tween = null

func show_message(text: String, duration: float = 3.0) -> void:
    _cancel_active_message()
    _message_label.text = text
    _message_label.modulate.a = 0.0
    _active_message_tween = create_tween()
    _active_message_tween.tween_property(_message_label, "modulate:a", 1.0, 0.3)
    await _active_message_tween.finished
    if not is_instance_valid(self):
        return  # HUD was freed
    await get_tree().create_timer(duration).timeout
    if not is_instance_valid(self):
        return
    _active_message_tween = create_tween()
    _active_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.3)

func _cancel_active_message() -> void:
    if _active_message_tween and _active_message_tween.is_valid():
        _active_message_tween.kill()
    _active_message_tween = null

func _exit_tree() -> void:
    _cancel_active_message()
```

## Acceptance Criteria

- [ ] No orphaned coroutines when HUD is freed mid-message
- [ ] No errors from accessing freed nodes
- [ ] Quick scene transitions don't cause message artifacts
- [ ] Smoke test passes
