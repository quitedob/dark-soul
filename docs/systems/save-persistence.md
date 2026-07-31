# Save / Persistence Design

**Status:** CURRENT (2026-07-30)  
**Task:** J-08  
**Authority:** `game/scripts/core/run_state.gd`, `game/scripts/core/game_settings.gd`, `game/scripts/game_world.gd`

---

## Storage Layout (`user://`)

| File | Constant | Purpose |
|------|----------|---------|
| `user://ashen_hollow_run_v1.json` | `game_world.SAVE_PATH` | Active run progress |
| `user://ashen_hollow_settings_v1.json` | `game_world.SETTINGS_PATH` | Audio/FPS/accessibility settings |

Filename retains `_v1` for historical path stability; **run content schema** is versioned inside JSON (`schemaVersion`).

Web embeds may let the host own persistence via `GameHostBridge` instead of local `user://`.

---

## Run State Schema

| Field | Meaning |
|-------|---------|
| `SCHEMA_VERSION` | **2** (current) |
| `LEGACY_SCHEMA_VERSION` | **1** (accepted + migrated) |

### Core fields

| Key | Type | Notes |
|-----|------|-------|
| `schemaVersion` | int | Must be 1 or 2 |
| `chapter_id` / `level_id` | string | Canonical IDs (`chapter_01`, `level_01_01`) |
| `checkpoint_id` | string | Default `ember_shrine`; shrine rest writes campaign shrine id |
| `embers` | int | Currency |
| `focus` | float | Default 80 |
| `combat_style` | int | 0–4 |
| `right_hand` / `left_hand` | string | Hand loadout ids |
| `upgrade_tier` | int | Shrine upgrade tier |
| `guardian_defeated` | bool | Chapter 1 boss flag (also mapped to progression) |
| `lost_echo_amount` / `lost_echo_position` | int / Vector3 | Death drop |
| `activated_shortcuts` | string[] | e.g. `ancient_gate` |
| `play_time_ms` | int | Accumulated play time |
| `inventory`, progression arrays, `choice_flags`, `progression_values` | various | Campaign/story hooks |

### `choice_flags` (narrative)

Values may be **`bool` (legacy)** or **`String` (canonical fate outcomes)**. Validation uses `_is_choice_flags_map`.

| Flag | Example values | Writer |
|------|----------------|--------|
| `ch1_guardian_fate` | `released` / `preserved` | FateChoiceOverlay after 巨阙 floor |
| `ch2_xingtian_fate` | `honored` / `absorbed` | FateChoiceOverlay |
| `ch3_nine_tails_fate` | `redeemed` / `sealed` | FateChoiceOverlay |
| `ch4_xuanxiao_fate` | `ascended` / `remembered` | FateChoiceOverlay |
| `ending_state` | `kindle` / `keeper` / `void` | FateChoiceOverlay (烛阴) |

API: `AshenRunState.set_choice_flag(flag, value)` / `get_choice_flag(flag, default)`.

### API

```text
AshenRunState.to_dictionary() / to_json() / save_to_path(path)
AshenRunState.from_json() / from_dictionary() / load_from_path(path)
AshenRunState.to_bridge_dictionary()  # camelCase nested payload for Web host
```

Reject unknown schema versions outside `{1, 2}`.

---

## Migration (v1 → v2)

Handled in `from_dictionary`:

1. Fill missing `chapter_id` / `level_id` / hand loadout defaults.
2. `_migrate_shortcut_ids`: map legacy `ancient_gate` ↔ namespaced forms.
3. Map `guardian_defeated` ↔ progression id `boss_giant_gate` when needed.

Always keep a one-way upgrade path; do not write schema 1 after loading as 2.

---

## Runtime Apply Rules (`game_world.gd`)

1. Load JSON → `_apply_run_state`.
2. Load campaign level from `level_id`.
3. Restore embers, focus, style/loadout, upgrade tier, shortcuts, Lost Echo.
4. If `checkpoint_id` is set, **respawn at checkpoint marker**, not spawn marker.
5. If `guardian_defeated`, remove boss and open victory exit path.

Shrine rest (`rest_at_checkpoint`) writes `checkpoint_id`, heals, resets enemies, saves.

---

## Settings Schema

`AshenGameSettings.SCHEMA_VERSION := 1`

| Field | Default | Notes |
|-------|---------|-------|
| `master_volume` | 0.8 | |
| `music_volume` | 0.7 | **Not yet wired to AudioBus** |
| `effects_volume` | 0.85 | |
| `target_fps` | 60 | Allowed 30 / 60 |
| `combat_tip_mode` | false | Teaching HUD gate |
| reduced-motion / quality knobs | — | Mobile Web may force low/30 via `apply_runtime_defaults` |

---

## Host Bridge

On Web, when connected to host:

- Host may supply / consume run JSON via bridge messages.
- Local `user://` load may be skipped when host controls save.

See `game/scripts/app/game_host_bridge.gd`.

---

## Related

- [architecture.md](../architecture.md) — composition root  
- [validation.md](../validation.md) — `core_contract_test` covers round-trip; I-07 death-loop contracts cover Lost Echo + checkpoint respawn  
- [chapter-bridge-map.md](../story/chapter-bridge-map.md) — narrative flags (design authority)  
