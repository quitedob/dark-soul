# Validation

Validated on **2026-07-29** using the exact requested engine binaries.

## Engine

```text
D:\godot\Godot_v4.7.1-stable_win64.exe
D:\godot\Godot_v4.7.1-stable_win64_console.exe
```

Reported version:

```text
4.7.1.stable.official.a13da4feb
```

## Automated Results

### Script parsing

Command pattern:

```bash
for script in scripts/**/*.gd; do
  "D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
    --headless --path "D:/godot/newproject" \
    --check-only --script "$script"
done
```

Result: `ALL_SCRIPTS_PARSE_OK`

### Editor import

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --editor --path "D:/godot/newproject" --quit
```

Result: completed successfully with no script or resource errors.

### Bounded runtime

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "D:/godot/newproject" --quit-after 180
```

Result: completed successfully with no runtime errors.

### Gameplay smoke path

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "D:/godot/newproject" \
  --quit-after 600 -- --smoke-test
```

Result: `ASHEN_HOLLOW_SMOKE_OK`, clean exit.

The smoke path verifies runtime construction, player ember changes, player damage and healing, enemy damage, interaction prompt visibility, guardian HUD visibility, death overlay visibility and cleanup, and transient message creation. The bounded runtime also exercises several seconds of physics, camera setup, responsive UI processing, and enemy state updates.

### Core contract tests

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "D:/godot/newproject/game" \
  --script tests/smoke/core_contract_test.gd
```

Result: `ASHEN_CORE_CONTRACTS_OK`

The contract tests verify: run state serialization round-trip, invalid data rejection, settings value sanitization, and host bridge protocol message parsing.

## Manual Test Checklist

Automated headless tests cannot judge game feel. In the graphical build, verify:

- `WASD` movement follows camera orientation.
- Mouse orbit starts behind the player and the spring arm avoids walls.
- Light/heavy attacks spend different stamina amounts and hit only once per swing.
- Dodge moves in the intended direction and avoids damage only during its central interval.
- `Q` or middle mouse locks to a nearby living enemy and releases on death/range.
- `E` activates and rests at the shrine.
- The side lever raises the shortcut gate.
- Death drops embers and respawns at the shrine after the overlay.
- Touching the Lost Echo restores the dropped amount.
- The guardian displays a health bar and victory overlay.
- `Esc` pauses, focuses `RESUME`, and supports keyboard navigation.
- `F1` shows accurate controls in readable action/input rows, and closing it restores the prior pause state.
- The HUD remains unclipped and well-spaced at 1280×720 and at least one wider desktop window size.
- Interaction prompts and guardian health do not overlap, and the projected lock marker stays centered on visible targets.
- Death presentation clears after respawn; prompt and boss presentation remain hidden during death and victory states.
- Prompt, message, ember, boss, death, and victory motion remains readable without becoming distracting.

## Known Limitations

- Visuals and sounds are generated primitives intended to validate systems, not final production assets.
- The single-scene level is manually authored, not algorithmically generated.
- No quest, NPC, or dialogue infrastructure exists.
- The `music_volume` setting in game settings is not yet wired to any audio bus.
- Human playtesting is still required for combat balance, telegraph clarity, camera comfort, and accessibility.
