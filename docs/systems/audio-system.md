# Audio System Reference

**Status:** CURRENT (2026-07-30)  
**Task:** J-09  
**Authority:** `game/scripts/procedural_audio.gd`

---

## Overview

All SFX are **procedural PCM** generated at runtime (no imported wav/ogg required for the vertical slice). Playback uses a fixed pool of `AudioStreamPlayer` voices.

---

## Cue Catalog

| Cue ID | Typical use |
|--------|-------------|
| `swing` | Light attack whoosh |
| `heavy` | Heavy attack whoosh |
| `hit` | Successful strike impact |
| `parry_shield` | Shield parry |
| `parry_buckler` | Buckler parry |
| `parry_dagger` | Dagger parry |
| `parry_fist` | Fist/open-hand parry |
| `hurt` | Player/enemy damaged |
| `dodge` | Roll / backstep / jump accent |
| `rest` | Shrine rest, seals, offerings |
| `death` | Death / floor collapse accents |
| `recover` | Heal / recover |
| `victory` | Boss victory |

Callers pass optional `volume_db` and `pitch` (defaults roughly `-7.0` dB / `1.0`).

---

## Voice Pool

- **Size:** 6 players (`Voice0` … `Voice5`)
- **Scheduling:** round-robin (`_next_voice`); prefer idle voice, otherwise steal oldest/next
- Keeps concurrent swings/hits from silently dropping when multiple enemies attack

---

## API

```gdscript
func play_cue(cue: String, volume_db: float = -7.0, pitch: float = 1.0) -> void
```

World wiring: `game_world.audio.play_cue(...)`; player/enemy helpers call into the same node.

Unknown cue ids should no-op or fail soft — do not crash gameplay.

---

## Headless Behavior

```text
_audio_enabled = DisplayServer.get_name() != "headless"
```

When headless (CI / contract tests):

- Do not build the cue library / players
- `play_cue` returns immediately

This keeps smoke/GUT runs silent and deterministic.

---

## Adding a New Sound

1. Add a generator function in `procedural_audio.gd` that builds an `AudioStreamWAV` (or reuse an existing waveform with new envelope).
2. Register the cue id in the cue dictionary built during `_ready`.
3. Document the id in the table above.
4. Call `audio.play_cue("your_cue", volume_db, pitch)` from gameplay.
5. Re-run a headless smoke path to ensure no errors when audio is disabled.

Prefer short one-shots; long loops need a dedicated player outside the 6-voice SFX pool.

---

## Known Gaps

- `music_volume` in settings is **not** connected to any `AudioBus`.
- No separate music bed system yet — victory/rest cues are SFX-scale.

---

## Related

- [save-persistence.md](save-persistence.md) — settings volumes  
- [validation.md](../validation.md) — headless expectations  
