# Build & Export Guide

**Status:** CURRENT (2026-07-30)  
**Task:** J-06  
**Engine:** Godot 4.7.1  
**Project root:** `game/`

---

## Quick Start

```powershell
# Full pipeline (Godot export + Flutter/OHOS packaging)
.\tools\build.ps1

# Godot-only (skip Flutter / HAP)
.\tools\build.ps1 -SkipFlutter -SkipHap

# Skip export, still run tests
.\tools\build.ps1 -SkipGodotExport -SkipFlutter -SkipHap
```

Default binaries in `tools/build.ps1`:

| Tool | Default path |
|------|----------------|
| Godot console | `D:\godot\Godot_v4.7.1-stable_win64_console.exe` (override if needed; this machine may use `E:\godot\...`) |
| Flutter | `D:\flutter\OpenHarmony-flutter\flutter_flutter\bin\flutter.bat` |

Success marker: `ASHEN_HOLLOW_BUILD_OK`

---

## Export Presets (`game/export_presets.cfg`)

| Preset | Platform | Output | Notes |
|--------|----------|--------|-------|
| **Web** | Web | `app/ohos/entry/src/main/resources/rawfile/game/index.html` | Single-threaded; no GDExtension; virtual keyboard on; canvas resize policy 2 |
| **Windows Desktop** | Windows | `dist/windows/AshenHollow.exe` | `embed_pck=true`, S3TC/BPTC |
| **Linux** | Linux | `dist/linux/ashen-hollow.x86_64` | `runnable=false`, `embed_pck=true` |

### Web / mobile caveats

- No standalone `CAPABILITIES` file in-repo; see [phone-compatibility.md](phone-compatibility.md).
- Web build is **Emscripten single-threaded** (`variant/thread_support=false`, `extensions_support=false`).
- Viewport is **1280×720**, `stretch_mode=canvas_items`, renderer `gl_compatibility`.
- Portrait phone layouts are effectively unplayable; landscape lock is not automated.
- Host bridge (`AshenHollowHost`) is for embedded Web shells — not expected in bare standalone Web export.

### Manual Godot export

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --export-debug "Web"
```

Replace `"Web"` with `"Windows Desktop"` or `"Linux"` as needed.

---

## Smoke & Contract Commands

Always pass `--path` to **`game/`**.

```bash
GODOT="E:/godot/Godot_v4.7.1-stable_win64_console.exe"
ROOT="e:/godot/darksoul/game"

# Bounded runtime
"$GODOT" --headless --path "$ROOT" --quit-after 180

# Gameplay smoke
"$GODOT" --headless --path "$ROOT" --quit-after 600 -- --smoke-test

# Contracts
"$GODOT" --headless --path "$ROOT" --script tests/smoke/core_contract_test.gd
"$GODOT" --headless --path "$ROOT" --script tests/smoke/combat_contract_test.gd
"$GODOT" --headless --path "$ROOT" --script tests/smoke/poise_contract_test.gd
"$GODOT" --headless --path "$ROOT" --script tests/smoke/chapter1_slice_contract_test.gd
"$GODOT" --headless --path "$ROOT" --script tests/smoke/death_loop_contract_test.gd

# GUT unit suite
"$GODOT" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd
```

Expected prints include `ASHEN_*_OK` markers documented in [validation.md](validation.md).

`tools/build.ps1` already runs GUT + multiple smoke contracts before export.

---

## Pipeline Stages (`tools/build.ps1`)

1. Editor quit / import sanity  
2. GUT unit tests  
3. Smoke contract scripts  
4. `--smoke-test --new-run` gameplay path  
5. `--export-debug "Web"` into OHOS rawfile  
6. Flutter `pub get` / `analyze` / `test` / `build bundle` / `build hap` (unless skipped)

---

## Related Docs

- [validation.md](validation.md) — full checklist  
- [phone-compatibility.md](phone-compatibility.md) — mobile/Web UX limits  
- [project-structure.md](project-structure.md) — repo layout  
- [mcp-setup-guide.md](mcp-setup-guide.md) — editor MCP tooling  
