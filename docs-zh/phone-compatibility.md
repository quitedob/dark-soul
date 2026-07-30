# 手机屏幕兼容性 (Phone Screen Compatibility)

测试于 **2026-07-30**，使用 Chrome DevTools 设备模拟，针对 Godot 4.7.1 Web 导出（WebGL 2.0，Emscripten 4.0.20，单线程）。

## 测试环境 (Test Environment)

| 属性 | 值 |
|---|---|
| Godot 引擎 | 4.7.1.stable.official.a13da4feb |
| 渲染器 | OpenGL ES 3.0 (WebGL 2.0 Chromium) |
| 游戏视口 | 1280×720 (16:9)，stretch_mode = canvas_items |
| Web 构建大小 | ~40 MB (wasm + pck + js) |
| 触屏操控 | `mobile_controls.gd` — 通过 user-agent + 指针媒体查询自动检测 |

## 结果汇总 (Results Summary)

| 视口 | 方向 | 内容占比% | 触屏操控 | 黑边 | 结论 |
|---|---|---|---|---|---|
| 750×420 (~16:9) | 横屏 | 92.3% | 99.4% ✅ | 无 | ✅ **理想** |
| 720×405 (16:9) | 横屏 | — | — | 无 | ✅ **完美匹配** |
| 640×360 (16:9) | 横屏 | — | — | 无 | ✅ 良好 |
| 812×375 (iPhone X) | 横屏 | 76.1% | 80.3% ✅ | 有（两侧） | ⚠️ 轻微黑边 |
| 915×412 (Pixel 7) | 横屏 | — | — | 有（两侧） | ⚠️ 轻微黑边 |
| 414×896 (iPhone) | 竖屏 | 4.7% | 0% ❌ | 有（大量） | ❌ 不可用 |
| 412×915 (Pixel 7) | 竖屏 | — | — | 有（大量） | ❌ 不可用 |

## 推荐手机尺寸 (Recommended Phone Sizes)

游戏以 1280×720 (16:9) 渲染。在横屏下匹配或接近此比例的屏幕效果最佳：

| 等级 | CSS 视口（横屏） | 示例设备 |
|---|---|---|
| **理想** | 720×405，640×360 | 16:9 入门/中端手机 |
| **良好** | 960×540，800×450 | HD+ 旗舰机 |
| **可接受** | 812×375，915×412 | iPhone X，Pixel 7 — 轻微侧边黑边 |
| **较差** | 任意竖屏方向 | 所有手机 — 大面积画面压缩 |

## 鸿蒙手机估算 (HarmonyOS Phone Estimates)

鸿蒙手机（华为P60 Pro：1220×2700物理像素，~408×900 CSS竖屏）在横屏（~900×408 CSS）下，由于屏幕宽于16:9，**两侧有轻微黑边**。游戏区域填充约73%屏幕。触屏操控将通过手机 user-agent 自动激活。

| 设备 | 物理分辨率 | CSS（横屏） | 适配情况 |
|---|---|---|---|
| 华为 P60 Pro | 1220×2700 | 900×408 (@3x) | ⚠️ 侧边黑边 |
| 华为 Mate 60 | 1260×2720 | 907×420 (@3x) | ⚠️ 侧边黑边 |
| 通用 16:9 手机 | 720×1280 | 720×405 (@1x) | ✅ 完美 |

## 正常工作的部分 (What Works)

- **游戏引擎**：完整的 wasm 加载，WebGL 2.0 渲染，全部16个脚本已编译
- **手机触屏操控**：在手机模拟中自动检测并正确显示（底部区域99.4%覆盖）
- **键盘回退**：所有键盘输入正常工作（Enter/空格用于菜单，WASD用于移动）
- **16:9 横屏**：游戏完全填充视口 — 无画面压缩
- **本地化**：嵌入的CJK字体正确加载

## 已知问题 (Known Issues)

1. **❌ 竖屏方向无法游玩。** 游戏不会强制横屏。在竖屏下，16:9的游戏区域在~1800px视口中渲染为一个狭窄的~460px条带 — 屏幕使用率不到5%。需要添加横屏锁定meta标签或Godot方向提示。

2. **⚠️ HUD状态条在手机尺寸下偏暗。** 生命/耐力条在750×420下亮度仅约为~16/255，而触屏操控按钮约为80+。在小型手机尺寸下，玩家可能无法清晰地看到自身状态。建议在视口宽度低于800px时增加HUD元素的亮度或缩放。

3. **⚠️ 宽屏手机上的画面压缩。** 现代手机（iPhone X：2.17:1，Pixel 7：2.22:1）宽于游戏的1.78:1 (16:9)比例。左右两侧会出现黑边。对于鸿蒙 Flutter 壳层，请确保 Web 组件背景色与游戏的暗黑美学匹配。

4. **⚠️ 无横屏锁定。** Web导出没有 `<meta name="screen-orientation">` 或 `screen.lockOrientation()` 调用。玩家将手机旋转至竖屏时将看到黑屏。

5. **⚠️ 标题画面边缘看起来像画面压缩。** 暗黑魂系美学意味着标题画面自然有暗边缘（1.6亮度），可能让玩家误以为游戏未加载。

## Web 导出控制台日志 (Web Export Console Log)

```text
Godot Engine v4.7.1.stable.official.a13da4feb
OpenGL API OpenGL ES 3.0 (WebGL 2.0) - Compatibility - WebKit WebGL
Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
ERROR: No interface 'AshenHollowHost' registered.  (expected — standalone browser, no Flutter shell)
```

在独立运行时 `AshenHollowHost` 错误是无害的。该桥接是为鸿蒙 Flutter 壳层（`app/`）设计的，在缺失时会优雅降级。
