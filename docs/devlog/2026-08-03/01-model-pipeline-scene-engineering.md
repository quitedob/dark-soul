# 模型资产管线（三轮迭代）+ three.js 场景工程 + 技能沉淀

**日期:** 2026-08-03
**范围:** 本条目记录一次完整会话：为 Ashen Hollow 建 **GLB 模型资产管线**（`docs/model-prompts` → 85 个程序化 GLB → 三轮质量迭代）、**three.js 场景工程**（28 关场景脚手架 + 图鉴查看器 + Boss 阶段场景变换）、以及把方法论沉淀进 `.claude/skills/ashen-hollow-dev` 技能。

---

## 一、交付物清单

| 资产 | 路径 | 说明 |
|---|---|---|
| 项目技能 | `.claude/skills/ashen-hollow-dev/` | 项目开发工作流（子 agent 编排/验证基线/坑）+ 3 个 GLB reference + 10 个 threejs-* 参考 + threejs-game-skills-main |
| GLB 模型库 | `build/glb-models/` | 85 个 GLB（bosses 8 / characters 20 / enemies 32 / equipment 5 / props 8 / weapons 12），27.4 MB，全部过 `verify-glbs.mjs` |
| 导出脚手架 | `build/glb-models/_shared/helpers.mjs` | 材质库 + 几何小件 + DataTexture 纹理工厂 + physical 材质 + FileReader/document/ImageData polyfill |
| 图鉴查看器 | `build/glb-models/index.html` + `server.mjs` | 85 模型左侧列表 + 左右切换 + 3D 查看（端口 8766） |
| 场景工程 | `build/scenes/` | `_shared/scene-helpers.mjs`（环境库）+ `_shared/renderer.mjs`（渲染器/阶段切换/WASD）+ `index.html`（28 场景选择器，端口 8767） |
| 本地 VLM | `F:/python/llamacpp/start_vlm_server.bat` | llama.cpp MiniCPM-V 4.6（127.0.0.1:9090），配合 `build/glb-test/vlm_look.py` |

## 二、GLB 资产管线：三轮迭代方法论

**核心经验：模型质量 = 让子 agent 真正读对参考，不是给更多几何类型。**

| 轮 | 子 agent 被要求读的参考 | 效果 | 体积 |
|---|---|---|---|
| v1 | 只给 helpers 基础 API（box/cyl/sphere） | 几何体堆叠，剪影/质感差 | 14.4 MB |
| v2 | `threejs-{geometry,materials,textures}`（Extrude/Lathe/Tube、MeshPhysicalMaterial、DataTexture） | 高级几何 + 程序化纹理 + 物理材质，质量提升但仍有"拼凑感" | 19.1 MB |
| v3 | `threejs-game-skills-main` 的 `aaa-graphics-builder` + `model-recipes` + `procedural-model-quality` | **剪影优先 + 功能性部件（面板/接缝/铆钉/铰链）+ 材质分区 + emissive 克制 + Reject 自检**，26 个模型 ≥60 mesh | 27.4 MB |

**v3 质量协议（可复用）**：①剪影纯色可读；②每模型 ≥3 种功能性部件；③材质分区（skin/fabric/armor/metal/glass/emissive）+ roughness 对比；④emissive 只做信号点；⑤命名功能部件；⑥对照 `model-recipes` 的 "Reject if"（不得读作堆叠几何体）。

**每轮都要求子 agent 在报告里列出读过的参考文件绝对路径 + 每模型用到的技术 + verify 结果**——强制"真读了"并可追溯。

## 三、场景工程脚手架

`build/scenes/` 设计：**场景定义（数据）+ 通用渲染器（引擎）分离**。

- 场景定义 `scenes/ch{1..5}.mjs`：`{ id, name, en, chapter, theme(雾/光/色板), env(S)=>[构件], entities[{glb,x,z,scale,name}], labels, phases[{name,build(S,root)}] }`
- `scene-helpers.mjs`：材质库（每章主题色板：灵墟月光/血铁炉火/玉障青绿/天崩夕阳/烬座星辉）+ 地面/建筑 kit/烬火/粒子/雾/光 + `placeGLB`（导入已有模型归一化+台座）+ 阶段辅助
- `renderer.mjs`：OrbitControls + WASD 平移 + 点击实体显示名 + **Boss 阶段切换**（`phases` 数组，数字键 1-4 切换）
- `index.html`：左侧 28 场景列表（分组按章，Boss 场景 ⚔ 标记）+ 中央渲染

**Boss 多阶段场景变换**（据 `docs/story/chapter-bridge-map.md`）：巨阙 2 阶段（点火盆）、刑天 3 阶段（缚锁→破锁→荣誉决）、九尾 2 阶段（魂暴）、玄霄 3 阶段（嗔念→执念→核心残识/真身）、烛阴 4 阶段（龙形→人形→烬渊之核→终结抉择）。

## 四、踩过的技术坑（全部已解决并记入技能）

| # | 坑 | 解决 |
|---|---|---|
| 1 | Node 无 `FileReader`，GLTFExporter `binary:true` 抛 `ReferenceError` | 顶部 shim：`readAsArrayBuffer(blob)` 用 `blob.arrayBuffer()` |
| 2 | Node 无 `document`/`ImageData`，导出带纹理 GLB 抛 `document is not defined` | 装 `@napi-rs/canvas`，polyfill `document.createElement('canvas')` + 全局 `ImageData` |
| 3 | DataTexture 导出需走 data 路径（`image.data !== undefined`），否则进 element 路径抛 `Invalid image type` | `makeTex` 返回 `THREE.DataTexture`（image 自带 `{data,width,height}`） |
| 4 | `verify-glbs.mjs` 判 chunk 类型 `"BIN\0"` ≠ `"BIN"` 误报 | chunk 类型 `.replace(/\0+$/,'')` 再比较 |
| 5 | helpers `cone(rt,rb,h)` 忽略 rb（ConeGeometry 非截锥） | 记入技能文档；要截锥用 `cyl` |
| 6 | 场景页相对 import 基准错：访问 `/` 被重定向到 `/scenes/index.html`，但 `./x.mjs` 相对根解析 → 404 | index.html 加 `<base href="/scenes/">` |
| 7 | `createViewer` 内 `container.innerHTML=''` 清空了 #title/#loading | 渲染放独立子容器 `#render`，UI 元素留在外面 |
| 8 | 扩展名 `renderer.js` vs `renderer.mjs` 不一致 → 模块加载失败 | 统一 `.mjs` |
| 9 | 页面卡在"加载场景清单"→ 用 remote-vlm 看截图 + 查 network requests 定位 | VLM 确认页面结构，`list_network_requests` 暴露 404 根因 |

## 五、VLM 视觉检查（remote-vlm 技能）

- 服务器：`F:/python/llamacpp/start_vlm_server.bat`（llama.cpp MiniCPM-V 4.6，127.0.0.1:9090，启动方式 `cd F:/python/llamacpp && ./start_vlm_server.bat`）
- 脚本：`build/glb-test/vlm_look.py`（PIL 缩放 ≤512px、JPEG q60、模型自动检测、`PYTHONIOENCODING=utf-8` 防乱码）
- 用途：主模型读不了图时，用本地 VLM 当"眼睛"看截图/渲染

## 六、场景工程实录（脚手架 → 8 agent 并行 → 技能落地）

### 6.1 脚手架（build/scenes/）
- `server.mjs`(8767, 服务 build/ 根, `/` 重定向 `/scenes/index.html`) + `index.html`(28 场景选择器, 分组按章, ⚔ Boss 标记) + `_shared/scene-helpers.mjs`(环境构建库) + `_shared/renderer.mjs`(通用渲染器) + `verify-scenes.mjs`(主线程复核)
- **设计:场景定义(数据)与渲染器(引擎)分离**。场景模块零 import, 只用 `S` 参数;渲染器注入。
- 场景定义格式: `{ id, name, en, chapter, theme, env:(S)=>[...], entities:[{glb,x,z,scale,name}], labels, phases:[{name,build(S,root)}] }`

### 6.2 浏览器验证踩坑（全部已修）
| # | 坑 | 解决 |
|---|---|---|
| 1 | 访问 `/` 被重定向到 `/scenes/index.html`, 相对 import `./x.mjs` 以根为基准 → 404 | `<base href="/scenes/">` |
| 2 | `renderer.js` vs `renderer.mjs` 扩展名不一致 → 模块加载失败 | 统一 `.mjs` |
| 3 | `createViewer` 内 `container.innerHTML=''` 清空 #title/#loading | 渲染放独立子容器 `#render` |
| 4 | 页面卡"加载场景清单" → VLM 看截图 + `list_network_requests` 定位根因 | network 请求暴露 `_shared/renderer.mjs` 404 |

### 6.3 用户反馈迭代
- 用户嫌"太粗糙太暗" → 调亮默认 exposure(1.15→1.35) + 光照强度 + **同时并行派 8 个 agent**
- **8 个并行 agent**(每章拆 1-2, 每个专注 2-4 场景精打磨): ch1a/ch1b/ch2a/ch2b/ch3a/ch3b/ch4/ch5 → 28 场景全齐
- 主线程复核 `verify-scenes.mjs`: **28 场景全通过**(字段/GLB 路径/Boss 阶段结构)

### 6.4 按技能落地（用户批评"没按技能生成"后）
- **系统读两个技能文件夹**(3 个 Explore 并行提炼规范): 光照/材质/纹理/后期 + 几何/场景/着色器 + AAA 评分标准
- **落地到脚手架**:
  - renderer: RoomEnvironment 环境贴图(金属不发死灰) + 后期管线(Bloom threshold 0.85/strength 0.5 + Vignette + Grain + OutputPass)
  - scene-helpers: 石板/木纹程序化纹理、接触阴影、key/fill/rim 光照栈、`instanced`、`terrainMesh`
  - `build/scenes/_shared/SCENE-SPECS.md`: 场景生成规范(光照/材质配方表 + AAA 检查清单 12 项)
- **VLM 实测提升**: "月光与火光有层次感的泛光效果"——后期 bloom 已生效

### 6.5 本地 VLM 服务器（remote-vlm 前置）
- 启动: `cd F:/python/llamacpp && ./start_vlm_server.bat`(MiniCPM-V 4.6, 127.0.0.1:9090);服务器会因内存/进程被杀,需 `nohup ./start_vlm_server.bat` 重启
- 探活: `curl 127.0.0.1:9090/v1/models`;查询脚本 `build/glb-test/vlm_look.py`(PYTHONIOENCODING=utf-8)

## 七、场景合规审计与定向修复（2026-08-03 深夜）

**结论先行：不必全量重做 28 场景。** 原以为 28 场景是"未看 SCENE-SPECS 的 v1"，审计后发现大多已达标——8 agent 写作时 S helpers 已含 key/fill/rim 光照栈 + C.* 章节色板 + 接触阴影 + 纹理地面，场景天然接近规范。

**新增审计工具** `build/scenes/audit-scenes.mjs`：Node 里 polyfill `@napi-rs/canvas`（document.createElement）以真正执行 `env(S)` 构建环境，对照 SCENE-SPECS 12 项清单做可程序化检查（光照栈/密度/地面/阶段/实体/标签）。**关键：用展平 mesh 计数代替顶层 env 条目**——复合构件（tombPlatform/thronePlatform/ridgeScene）一个条目内含 10–30 mesh，顶层计数严重低估。

**误报排查**（已消除）：
- 实体"缺 pedestalR"：场景用 env 平台（entityBase/platform）或漂浮（`y`）定位，pedestalR 故意省略 → 审计只检查 glb 必填。
- ch5 "env 过稀"：全是复合构件（soulRiver/tombPlatform/thronePlatform 等），展开后 mesh 充足。
- level_03_01/03/05、level_02_04/06 类似误报。

**真实差距 → 定向修复**：

| # | 场景 | 问题 | 修复 |
|---|---|---|---|
| 1 | 玄霄·嗔念台 (04_04) | 仅 1 阶段，无场内变换 | 加「嗔怒初燃」阶段 → 2 阶段（红云压顶/熔岩缓燃/夕阳金红 → 赤红风暴） |
| 2 | 玄霄·执念台 (04_05) | 仅 1 阶段 | 加「执念失控」阶段 → 2 阶段（仪式封锁 → 符文碎裂飞散/书页狂舞/深蓝风暴） |
| 3 | 登天梯 (04_01) | 平台顶纯色（违 §3 禁纯色平地面） | 平台顶覆石板纹理 disc |
| 4 | 轮回歧路 (05_03) | 密度偏低（55 mesh） | 补断玉柱×2 / 裂地×2 / 碎玉瓦×8 / 玉烛台 |
| 5 | index.html + verify-scenes.mjs | 引用 ch1/ch2/ch3/extra 四个不存在模块（加载失败被 catch 静默吞掉） | 收敛到 8 个真实模块 |

**审计剩余 4 项 = 设计使然（非缺陷）**：level_02_03（459 mesh 大战场）/ level_04_03（366 mesh 藏经阁）本就该密；level_05_04 寂灭为程序化占位 + label（§6 允许）；level_05_05 Boss 舞台 base 稀疏但 4 阶段各加大量内容（留白让阶段变换清晰）。

**现状**：`verify-scenes.mjs` 全通过；Boss 阶段 **巨阙2 / 刑天3 / 九尾2 / 玄霄(嗔念2+执念2+真身3) / 烛阴4**。

## 八、当前状态与下一步

- ✅ 85 GLB 三轮迭代 + 图鉴查看器 + 28 场景（Boss 全多阶段，玄霄子竞技场补到 2 阶段）+ 场景脚手架按技能落地 + SCENE-SPECS 合规审计（audit-scenes.mjs）+ 定向修复
- ⏳ 缺失 14 精英怪的程序化占位已存在（stoneSentinel/ginkgoElite/eliteCloudBridgeGuard/silenceBringer 等），如后续生成真 GLB 需逐一替换
- 📌 `example/tsorcRevamp/`（266MB）仍待清理
