# three.js 多场景串联：魂类连续世界的架构方案

**日期:** 2026-08-03
**研究方式:** Perplexity pro 单次合并搜索（backend_uuid `93aad3f2-...`）
**背景问题:** 魂类原型有 28 个独立场景模块（纯数据定义：env 构件 + 实体 + Boss 阶段），要串成可推进的连续世界（关卡→关卡、Boss 战、篝火/传送、区域解锁、世界状态保持），而非图鉴式逐个切换。
**现状:** `build/scenes/_shared/renderer.mjs` 的 `createViewer` 每次 new WebGLRenderer + PerspectiveCamera + OrbitControls + EffectComposer，切场景时 `viewer.dispose()` 清空容器重建——**切换式，非串联式**。

---

## Key Findings（高置信度）

### 1. 正确架构：复用渲染上下文 + 场景指针

- **只创建一次** renderer / camera / controls / composer，放进全局上下文；单渲染循环（rAF）内按"当前场景指针"调用 `renderer.render(scene, camera)`。
- 场景对象通过 **SceneManager**（注册表）管理：`scenes[]` + `currentId` + 注册/注销 + 懒加载触发。
- 切换 = 换 `currentScene` 引用，**不销毁渲染链路**。公共资源（环境贴图/后期/材质池）跨场景共享。
- 场景间逻辑解耦用事件总线/注册表，不直接互相调用。

### 2. 切换与过渡

- **过渡阶段分离**：loading 屏（异步加载必要资源）→ fade-out 旧 / fade-in 新。
- 传送门/关卡门走**全局过渡层**（粒子/shader blend/屏幕后处理），不是切场景数据本身。
- 资源预加载：按"相邻区域优先"（当前场景索引前后各 N 个场景的 GLTF/纹理），`GLTFLoader.manager` 集中管理，离屏加载后入共享池。

### 3. 跨场景世界状态保持

- **世界状态与场景解耦**：全局 `WorldState` 对象集中管理（玩家属性/已解锁区域/Boss 阶段/门与开关/NPC 状态）。
- 场景通过**接口读取/订阅**状态，不直接写全局。
- 持久化：URL hash 存关键进度，localStorage 存长期进度（解锁/Boss 次序），离线恢复。

### 4. 资源与性能

- **按需加载 + 相邻预载**；GLTF cache + 全局材质/纹理去重；跨场景共享几何用 InstancedMesh。
- 离开场景**显式释放**：geometry/material/texture `.dispose()`，移除事件监听/动画/后处理引用，防内存泄漏。
- 高频切换对象用引用计数或资源池。

### 5. 对当前 createViewer 架构的改造要点

| 现在（每次重建） | 改为（全局上下文 + 指针） |
|---|---|
| `new WebGLRenderer` × 每场景 | 全局 renderer 一个 |
| `new PerspectiveCamera` × 每场景 | 全局 camera 一个 |
| `new OrbitControls` × 每场景 | 全局 controls 一个 |
| `new EffectComposer` × 每场景 | 全局 composer 一个（场景可覆盖个别 pass 参数） |
| `viewer.dispose()` 清空容器 | `SceneManager.loadScene(id)` 换指针 + TransitionLayer |
| 无状态 | `WorldStateManager`（registry + subscribe + hash/localStorage） |

---

## 落地建议（映射到本仓库）

1. **新增 `build/scenes/_shared/scene-manager.mjs`**：全局渲染上下文（renderer/camera/controls/composer）+ SceneManager（注册 28 场景、`loadScene(id)`、懒加载、相邻预载）+ TransitionLayer（fade/portal）+ WorldStateManager。
2. **改造 `renderer.mjs`**：`createViewer` 拆成「上下文初始化（一次）」+「buildScene(def, root)（每场景把数据装进共享 scene 根）」；切换时清共享 scene 根重建，不动 renderer/camera/composer。
3. **改造 `index.html`**：场景列表从"每点重建 viewer"改为 `SceneManager.loadScene(id)`；加世界状态 HUD（当前区域/已解锁/Boss 击败数）。
4. **场景数据不变**（已是零 import 纯数据），`env`/`entities`/`phases` 直接复用。
5. **资源纪律**：`S.instanced` 已提供实例化；新增全局材质去重表 + GLTF cache；切换时对 scene 根内资源统一 dispose。

---

## Sources

Perplexity 汇总（回答内嵌引用）：three.js 复用渲染器/相机/场景指针的常见模式、单循环 + 场景管理器、加载屏+过渡+相邻预加载策略、GLTFLoader.manager 缓存、全局状态注册表 + 事件驱动 + URL hash/localStorage 持久化、geometry/material/texture dispose 防泄漏、InstancedMesh 与材质池。

## 置信度与边界

- 高置信度：1/2/3/4 为行业通行做法，5 直接对应当前代码痛点。
- 未深挖：Godot 侧（真正游戏在 Godot 里跑，three.js 侧是原型/资产预览）；TransitionLayer 具体 shader 实现。
- 与既有文档关系：穿模纪律见 [[2026-08-03-procedural-placement-interpenetration]]；真实感纪律见 [[2026-08-03-realism-upgrade]]；三篇同属 threejs-pipeline 管线路演。
