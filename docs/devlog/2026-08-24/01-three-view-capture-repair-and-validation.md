# Three.js GLB 三视图截图管线修复与重拍验证

日期：2026-08-24

## 背景

旧批次 `screenshot/2026-08-22/` 的 88 组三视图出现相邻模型串图、错误视角、重复画面和部分裁切。根因是查看器在模型加载期间直接返回，批量截图可能继续使用上一个模型的画面；同时旧截图使用透视相机、雾效和不对称补光，影响结构审计。

## 修复

### 查看器

修改 `build/all-models/viewer.mjs`：

- `loadModel()` 改为 Promise 链串行队列，多个切换请求不会并行覆盖 `state.root`。
- 同一模型的 `front/back/top` 复用已加载模型，不再为每个视角重复加载。
- 加载 GLB 路径使用逐段 URL 编码，避免路径字符导致请求歧义。
- 带动画 GLB 固定在同一姿态，保证三张图可比较。
- 三视图导出使用独立 `OrthographicCamera`，按当前投影面的包围盒计算 25% 安全边距。
- 导出模式关闭雾效，改用中性深灰背景、环境光、正面/背面/侧面补光，减少暗部误判。
- `captureNow()` 截图前核对当前 `index/name/category/view`，并检查 `/capture` HTTP 返回状态。
- `bones` 与 `preview` 截图也提供合法身份类型，不破坏既有查看器接口。

### 服务端

修改 `build/all-models/server.mjs`：

- 输出目录改为 `screenshot/2026-08-24-three-view/`，不覆盖旧批次。
- `/capture` 校验截图身份必须匹配启动时的模型清单。
- 服务端拒绝未知模型、错误名称、错误分类或非法视角。
- 每张截图写入 `manifest.json`，记录 `filename/index/path/name/category/view`。

## 重拍流程

使用 Chrome DevTools Protocol 单页串行执行：

```text
Page.setDeviceMetricsOverride(width=1920, height=1080, deviceScaleFactor=1)
Page.reload()
Runtime.evaluate("window.shootAllViews(0, 87)", awaitPromise=true)
```

所有模型使用同一清单顺序，`front/back` 分别表示固定 `+Z/-Z` 轴向，`top` 表示 `+Y` 俯视。当前项目没有为 GLB 提供 `yaw_deg` 语义朝向元数据，因此不能把 `front/back` 自动解释为模型设计上的正面/背面。

## 已验证结果

产物目录：`screenshot/2026-08-24-three-view/`

- `88` 个 GLB 全部参与截图。
- `264/264` 截图返回 `OK`。
- PNG 总数：`264`。
- manifest 条目：`264`。
- 每个模型恰好包含 `front/back/top` 各一张。
- 缺失文件：`0`。
- 多余文件：`0`。
- manifest 身份错误：`0`。
- PNG 头校验：全部通过。
- PNG 尺寸：全部 `1920×1080`。
- 视觉抽查确认三张图属于同一模型，`top` 为真实俯视；旧批次的相邻串图和缺失组三视图已消除。

## 后续边界

- 最终截图证明的是模型加载、批处理顺序、固定轴向投影和文件身份一致性，不自动证明模型的语义正面或资产几何质量。
- 模型/材质本身的暗部、穿插、悬浮部件和设计意图，应基于新批次单独审计，不再把旧批次的截图竞态问题混入模型缺陷统计。
- 截图目录和 `build/` 查看器属于生成产物，受仓库 `.gitignore` 规则忽略；本日志记录验证方法和结果。
