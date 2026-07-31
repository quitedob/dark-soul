# C-06 — Wire `music_volume` Setting to AudioBus

**Priority:** P3 (nice-to-have)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review full audit 2026-07-30, finding M-3
**Authority:** `docs/systems/audio-system.md`

---

## Problem

`game_world.gd:903-905` has a commented-out block for routing `settings.music_volume` to the Music AudioBus. The setting is stored in `user://ashen_hollow_settings_v1.json` and exposed in the settings UI, but has no runtime effect:

```gdscript
# game_world.gd:_apply_settings() — line 903-905:
# TODO: Wire music bus when AudioBus layout is finalized
# var music_bus_idx = AudioServer.get_bus_index("Music")
# AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(settings.music_volume))
```

## Target

1. Ensure a "Music" AudioBus exists in the project's `default_bus_layout`
2. Uncomment and wire the volume setting
3. If no Music bus exists yet, create a minimal bus layout or fall back to Master

```gdscript
func _apply_settings(settings: GameSettings) -> void:
    # ... existing master/effects volume ...

    # Music volume
    var music_bus := "Music"
    var music_idx := AudioServer.get_bus_index(music_bus)
    if music_idx >= 0:
        AudioServer.set_bus_volume_db(music_idx, linear_to_db(settings.music_volume))
    # Else: silently skip — no Music bus configured yet
```

## Acceptance Criteria

- [ ] `music_volume` slider in settings has audible effect
- [ ] Volume persists across restart (save/load round-trip)
- [ ] No crash if Music AudioBus doesn't exist
- [ ] Settings schema v1 round-trip test passes
