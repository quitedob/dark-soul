# 2026-07-30 — Phone Screen Compatibility Testing

### Scope

Exported the Godot 4.7.1 game as a Web build and tested across 6 phone viewport sizes using Chrome DevTools device emulation (WebGL 2.0, mobile + touch emulation). Created `docs/phone-compatibility.md` with full results.

### Godot Web Export

- Downloaded Godot 4.7.1 export templates (1.2 GB `.tpz`) from GitHub releases
- Exported release Web build to `dist/web/` — 40 MB (index.wasm + index.pck + index.js)
- Served via local HTTP server for Chrome DevTools testing

### Phone Size Test Results

| Viewport | Orientation | Content% | Touch Controls | Letterbox | Verdict |
|---|---|---|---|---|---|
| 750×420 (~16:9) | Landscape | 92.3% | 99.4% ✅ | No | ✅ Ideal |
| 720×405 (16:9) | Landscape | — | — | No | ✅ Perfect |
| 812×375 (iPhone X) | Landscape | 76.1% | 80.3% ✅ | Yes (sides) | ⚠️ Minor bars |
| 414×896 (iPhone) | Portrait | 4.7% | 0% ❌ | Yes (massive) | ❌ Unusable |

### Key Findings

- **Mobile touch controls auto-activate** — `mobile_controls.gd` correctly detects mobile emulation and renders overlay buttons (99.4% coverage)
- **Game engine runs** — Godot 4.7.1, WebGL 2.0, all 16 scripts load
- **Portrait is unplayable** — game is 1280×720 (16:9) landscape; portrait renders as 4.7% screen usage
- **Wide phones get side bars** — modern phones (~2.17:1) are wider than game's 1.78:1
- **HUD vitals are dim** — health/stamina bars at ~16/255 brightness vs ~80+ for controls
- **No landscape lock** — game doesn't force orientation; needs `<meta name="screen-orientation">`

### HarmonyOS Phone Estimates

Huawei P60 Pro (~408×900 CSS portrait) in landscape (~900×408) will have minor side bars — game fills ~73% of screen. Touch controls will auto-activate via mobile user-agent in the Flutter/ArkTS WebView shell.

### Files Changed

| File | Change |
|------|--------|
| `docs/phone-compatibility.md` | **NEW** — full phone screen testing report |
| `docs/master-index.md` | Added phone-compatibility.md + Platform & Testing section |
| `docs/devlog.md` | This entry |
| `dist/web/` | **NEW** — Godot Web export (not tracked) |
| `dist/screenshots/` | **NEW** — 6 phone viewport screenshots (not tracked) |

### Coordination

- Testing only. No Godot runtime files modified.
- The `AshenHollowHost` bridge error in standalone browser is expected — bridge degrades gracefully when no Flutter shell is present.
- For HarmonyOS deployment: the Flutter shell (`app/`) + ArkTS WebView infrastructure is complete but requires OpenHarmony Flutter SDK (not found at `D:\flutter\OpenHarmony-flutter\` on this machine).

---
