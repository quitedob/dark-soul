# GLB 浏览器查看器 + remote-VLM 视觉检查

当需要"看"导出的 GLB（或验证渲染效果）时用这两套工具。当前主模型读不了图片，
用本地 VLM 充当"眼睛"。

## 1. 浏览器 3D 查看器（build/glb-test/）

- `index.html` — Three.js GLTFLoader + OrbitControls 查看器：深色背景、网格地面、阴影、
  环境光+暖色主光+冷色轮廓光、自动旋转；左上角信息面板显示已加载网格数/节点名。
- `server.mjs` — 极简静态服务器（本地 `node_modules/three`，无外网），端口 8765。

```bash
cd build/glb-test && node server.mjs     # 后台跑
# 打开 http://localhost:8765/
```

默认加载 `/sword.glb`。看别的模型：改 `index.html` 里 `loader.load('/sword.glb', ...)`
路径，或把目标 GLB 复制到 `build/glb-test/` 下（如 `cp out/weapons/01-WindHunter-Bow.glb build/glb-test/`）。

验证渲染：浏览器打开后 `wait_for` 信息面板出现"已加载"，截图存文件，再交给 VLM 描述。
`readPixels` 全 0 是 `preserveDrawingBuffer:false` 正常现象，不代表没渲染；可用 2D canvas
`drawImage` 拷贝后 `getImageData` 统计亮像素佐证。

## 2. remote-VLM 视觉检查

本地 llama.cpp VLM 服务器在 `127.0.0.1:9090`（模型自动检测，默认 MiniCPM-V 4.6）。
**端点不带 `/v1`**（`/chat/completions`），`max_tokens>=2000`，用 `python`（不是 python3）。

脚本：`build/glb-test/vlm_look.py`（PIL 缩到 ≤512px、JPEG q60、模型自动检测、打印 content）

```bash
cd build/glb-test && PYTHONIOENCODING=utf-8 python vlm_look.py <image.png> "[描述提示词]"
```

- 截图存 `build/glb-test/*.png` 后传入。
- **Windows 控制台中文乱码**：必须带 `PYTHONIOENCODING=utf-8`。
- 服务器不可用时先探活：`python -c "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:9090/v1/models',timeout=5).read())"`。
- 依赖：`pip install pillow requests`。

## 3. 检查流程

1. 起查看器服务器 → 浏览器打开 → 截图到文件。
2. `PYTHONIOENCODING=utf-8 python vlm_look.py <截图> "描述画面：模型形态/材质/光照/是否有异常"`。
3. 用 VLM 描述与 md 的「视觉描述」比对：剪影、标志特征、配色是否到位。
4. 批量检查（85 个 GLB）时，先抽查代表（Boss、职业、武器、道具各 1-2 个），全部抽检由用户决定。
