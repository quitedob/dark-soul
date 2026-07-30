# 验证 (Validation)

Validated on **2026-07-30** using Godot 4.7.1. Project root for all `--path` arguments is `game/` (this repository: `e:/godot/darksoul/game`).

## Engine

```text
E:\godot\Godot_v4.7.1-stable_win64.exe
E:\godot\Godot_v4.7.1-stable_win64_console.exe
```

Reported version:

```text
4.7.1.stable.official.a13da4feb
```

## Automated Results

### Script parsing

Command pattern (recursive):

```bash
for script in scripts/**/*.gd; do
  "E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
    --headless --path "e:/godot/darksoul/game" \
    --check-only --script "$script"
done
```

Result: `ALL_SCRIPTS_PARSE_OK` (re-run after large combat/campaign changes).

### Editor import

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --editor --path "e:/godot/darksoul/game" --quit
```

### Bounded runtime

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" --quit-after 180
```

### Gameplay smoke path

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --quit-after 600 -- --smoke-test
```

Result: `ASHEN_HOLLOW_SMOKE_OK` when the smoke path is enabled.

### Core / combat / campaign contracts

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/core_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/poise_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/chapter1_slice_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/death_loop_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/combat_contract_test.gd
```

Expected prints include `ASHEN_CORE_CONTRACTS_OK`, `ASHEN_POISE_CONTRACTS_OK`, `ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`, `ASHEN_DEATH_LOOP_CONTRACTS_OK`.

### GUT unit tests

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  -s addons/gut/gut_cmdln.gd
```

Uses `.gutconfig.json` (`tests/unit/`, `tests/integration/`).

## Manual Test Checklist

Automated headless tests cannot judge game feel. In the graphical build, verify:

- `WASD` movement follows camera orientation.
- Mouse orbit starts behind the player and the spring arm avoids walls.
- Light/heavy attacks spend different stamina amounts and hit only once per swing.
- Standing poise absorbs light hits without stagger until the reserve empties.
- Veilcraft/Ember melee spends Focus (not free stamina-zero spam).
- Hit-stop freezes the struck/striking actors briefly without global `Engine.time_scale`.
- Recovery dodge-cancel works on styles that author `dodge_cancel_seconds`.
- Dodge moves in the intended direction and avoids damage only during its central interval.
- Controller bindings work for move, attack, dodge, lock-on, and style cycle.
- `Q` or middle mouse locks to a nearby living enemy and releases on death/range.
- `E` activates and rests at the shrine; reload restores shrine respawn via `checkpoint_id`.
- Chapter 1: `level_01_01` 鈫?`01_05` encounters, arena seal, boss `瀹堢倝鐏德峰法闃檂, victory exit to `level_02_01`.
- Death drops embers and respawns at the shrine after the overlay.
- Touching the Lost Echo restores the dropped amount.
- `Esc` pauses; `F1` shows controls.

## Known Limitations

- Visuals and sounds are generated primitives intended to validate systems, not final production assets.
- Campaign levels beyond Chapter 1 still use placeholder encounters.
- The `music_volume` setting in game settings is not yet wired to any audio bus.
- Independent `GUARD_BROKEN` FSM state remains a target (E-08), not fully shipped.
- Human playtesting is still required for combat balance, telegraph clarity, camera comfort, and accessibility.
