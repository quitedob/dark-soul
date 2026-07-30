# Phone Screen Compatibility

Tested on **2026-07-30** using Chrome DevTools device emulation against the Godot 4.7.1 Web export (WebGL 2.0, Emscripten 4.0.20, single-threaded).

## Test Environment

| Property | Value |
|---|---|
| Godot engine | 4.7.1.stable.official.a13da4feb |
| Renderer | OpenGL ES 3.0 (WebGL 2.0 Chromium) |
| Game viewport | 1280×720 (16:9), stretch_mode = canvas_items |
| Web build size | ~40 MB (wasm + pck + js) |
| Touch controls | `mobile_controls.gd` — auto-detect via user-agent + pointer media query |

## Results Summary

| Viewport | Orientation | Content% | Touch Controls | Letterbox | Verdict |
|---|---|---|---|---|---|
| 750×420 (~16:9) | Landscape | 92.3% | 99.4% ✅ | No | ✅ **Ideal** |
| 720×405 (16:9) | Landscape | — | — | No | ✅ **Perfect match** |
| 640×360 (16:9) | Landscape | — | — | No | ✅ Good |
| 812×375 (iPhone X) | Landscape | 76.1% | 80.3% ✅ | Yes (sides) | ⚠️ Minor bars |
| 915×412 (Pixel 7) | Landscape | — | — | Yes (sides) | ⚠️ Minor bars |
| 414×896 (iPhone) | Portrait | 4.7% | 0% ❌ | Yes (massive) | ❌ Unusable |
| 412×915 (Pixel 7) | Portrait | — | — | Yes (massive) | ❌ Unusable |

## Recommended Phone Sizes

The game renders at 1280×720 (16:9). Phone screens that match or approximate this ratio in landscape work best:

| Tier | CSS Viewport (landscape) | Example Devices |
|---|---|---|
| **Ideal** | 720×405, 640×360 | 16:9 budget/mid phones |
| **Good** | 960×540, 800×450 | HD+ flagships |
| **Acceptable** | 812×375, 915×412 | iPhone X, Pixel 7 — minor side bars |
| **Poor** | Any portrait orientation | All phones — massive letterboxing |

## HarmonyOS Phone Estimates

HarmonyOS phones (Huawei P60 Pro: 1220×2700 physical, ~408×900 CSS portrait) in landscape (~900×408 CSS) will have **minor black bars on sides** since the display is wider than 16:9. The game area fills ~73% of the screen. Touch controls will auto-activate via the mobile user-agent.

| Device | Phys. Resolution | CSS (landscape) | Fit |
|---|---|---|---|
| Huawei P60 Pro | 1220×2700 | 900×408 (@3x) | ⚠️ Side bars |
| Huawei Mate 60 | 1260×2720 | 907×420 (@3x) | ⚠️ Side bars |
| Generic 16:9 phone | 720×1280 | 720×405 (@1x) | ✅ Perfect |

## What Works

- **Game engine**: Full wasm load, WebGL 2.0 rendering, all 16 scripts compiled
- **Mobile touch controls**: Auto-detect and display correctly in mobile emulation (99.4% coverage in bottom zone)
- **Keyboard fallback**: All keyboard inputs work (Enter/Space for menus, WASD for movement)
- **16:9 landscape**: Game fills the entire viewport — no letterboxing
- **Localization**: Embedded CJK font loads correctly

## Known Issues

1. **❌ Portrait orientation is unplayable.** The game does not force landscape. In portrait, the 16:9 game area renders as a narrow ~460px strip in a ~1800px viewport — less than 5% screen usage. A landscape-lock meta tag or Godot orientation hint is needed.

2. **⚠️ HUD vitals are dim at phone scale.** Health/stamina bars score only ~16/255 brightness at 750×420, compared to ~80+ for the touch controls. At small phone sizes, players may not see their vitals clearly. Recommend increasing HUD element brightness or scaling at viewports below 800px wide.

3. **⚠️ Letterboxing on wide phones.** Modern phones (iPhone X: 2.17:1, Pixel 7: 2.22:1) are wider than the game's 1.78:1 (16:9) ratio. Black bars appear on the left and right sides. For the HarmonyOS Flutter shell, ensure the Web component background matches the game's dark aesthetic.

4. **⚠️ No landscape lock.** The web export has no `<meta name="screen-orientation">` or `screen.lockOrientation()` call. Players rotating their phone to portrait will see a black screen.

5. **⚠️ Title screen edges look like letterboxing.** The dark soulslike aesthetic means the title screen has naturally dark edges (1.6 brightness), which could confuse players into thinking the game didn't load.

## Web Export Console Log

```text
Godot Engine v4.7.1.stable.official.a13da4feb
OpenGL API OpenGL ES 3.0 (WebGL 2.0) - Compatibility - WebKit WebGL
Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
ERROR: No interface 'AshenHollowHost' registered.  (expected — standalone browser, no Flutter shell)
```

The `AshenHollowHost` error is benign when running standalone. The bridge is designed for the HarmonyOS Flutter shell (`app/`) and gracefully degrades when absent.
