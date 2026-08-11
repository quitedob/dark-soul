# 雕刻工具箱 + 三项研究（穿模 / 真实感 / 多场景串联）

**日期:** 2026-08-03（深夜续）
**范围:** 本条目记录一次连续会话：为 `build/scenes/` 28 场景精雕升级打前站——扩展 scene-helpers **高级雕刻几何工具箱**（禁止简单几何占位），并完成三项 Perplexity 研究（穿模检测、真实感升级、多场景串联），归档到 `docs/research/threejs-pipeline/`。

---

## 一、雕刻几何工具箱（scene-helpers.mjs）

**动机（用户方向）**：禁止程序化占位 / 简单几何；用多种复杂几何雕刻物体；每场景拆 ≥5 分工 sub-agent 精雕小细节与灯光。工具箱是精雕 agent 的"雕刻刀"。

**新增（`build/scenes/_shared/scene-helpers.mjs`，import `RoundedBoxGeometry`）**：

| 原语 | 用途 |
|---|---|
| `extrude(pts, depth, m)` | 轮廓拉伸（柱体/台座/祭坛侧面） |
| `lathe(pts, m)` | 车床旋转体（香炉/罐/圆顶/灯座） |
| `tube(pts, r, m)` | CatmullRom 管（藤蔓/锁链/血管/走廊拱管） |
| `torus / ring` | 圆环 / 平环（门户环/圆桌/符文盘） |
| `capsule / ico` | 胶囊（骨节/脊椎）/ 二十面体（水晶原石/瘤块） |
| `bevelBox(w,h,d,bev)` | **圆角盒**（金属件倒角，魂味关键） |
| `rivetRing(r,n)` | 铆钉环（重型机械/棺材/大门的边缘细节） |
| `gear(R,teeth)` | 齿轮（机关/钟楼/锻造坊） |
| `knurl(rt,h,ridges)` | 滚花柄（武器柄/转轮） |
| `chain(n,linkR)` | 链节（铁链/束缚） |
| `crystal(h,r)` | 晶簇（矿脉/魔法水晶） |
| `coil(loops,r,pitch)` | 螺旋线圈（弹簧/缠绕蛇/藤蔓螺旋） |
| `spikeRing(r,n,h)` | 尖刺环（q.朝外，狱火/王座/荆棘） |

**配套纪律**：`noShadow()` 把精细小件 castShadow=false（性能）；复杂雕刻本身不会穿模，穿模来自摆放坐标——归精雕 agent 的穿模纪律管（见下）。

## 二、研究一：物体穿模（interpenetration）

**结论**：场景系统**零穿模处理**（placeGLB 只归一化，无碰撞避让/相交检测）。正确做法是**检测→避免→校正三位一体**。

- **检测分层**：`Box3.intersectsBox` 初筛 → three-mesh-bvh 精确 → Raycaster 复核关键件。
- **避免**（摆放阶段）：占位碰撞 + 空间哈希 + ground snap + 摆放避让。
- **校正**（装饰场景）：snap-to-surface → 推离 → 缩小/替换 → **CSG 作最后手段**（代价高，禁止）。
- **关键分类**：墙根埋地/石柱扎入地板/雕像贴墙是**有意锚固**（允许），与"两个显眼道具互相穿插"（修复）不同性质。AABB 会误报锚固型，需分类。
- 落地：`intersect-audit.mjs` 检测工具（见下一步）+ SCENE-SPECS「穿模纪律」。

## 三、研究二：真实感升级（角色/物品/场景）

**结论**：程序化管线可达**风格化写实**（魂类正确路线），追照片级写实是误区。真实感 = 材质响应正确 + 质感细节 + 克制后期。

- **PBR 真实取值**：skin 低 roughness + SSS 近似；fabric 0.8–1.0；leather 0.6–0.9；bone 0.7–0.9；metal metalness≈0.9 + roughness 0.1–0.5 + **clearcoat**。
- **SSS 廉价替代**：transmission + 边缘光 + 浅色腔面渐变（ghost/皮肤类）。
- **金属倒角 bevel + 清漆**；划痕/锈蚀走**边缘加强**噪声叠加，禁止全覆盖。
- **后期克制**：Bloom 0.6–1.0 高阈值、微颗粒、弱晕影、**禁过量 DOF/全屏粒子遮丑**；构图 leading lines + 焦点。
- 与 Godot 4 对照：PBR 参数/IBL/SSAO/雾直接等价，后处理链与节点化材质要换实现。

## 四、研究三：多场景串联（three.js 连续世界）

**现状**：`createViewer` 每次 new WebGLRenderer + Camera + Controls + Composer，切场景 dispose 重建——**切换式，非串联式**。

**方案**：复用渲染上下文 + 场景指针。
- **只建一次** renderer/camera/controls/composer 进全局上下文；单 rAF 循环按"当前场景指针"渲染。
- **SceneManager**：场景注册表 + `loadScene(id)` 换指针 + 懒加载 + 相邻预载（当前索引前后 N 场景 GLTF/纹理）。
- **WorldStateManager**：世界状态与场景解耦（玩家/解锁/Boss 阶段/门开关），场景经接口订阅；URL hash 存关键进度 + localStorage 存长期进度。
- **TransitionLayer**：loading 屏 + fade-out/in + 传送门全局过渡。
- **显式释放**：离开场景 dispose geometry/material/texture + 移除监听，防泄漏。
- 已给出"现在 vs 改为"对照表（`docs/research/threejs-pipeline/scene-chaining.md`）。**是否落地 SceneManager 重构待用户确认。**

## 五、下一步（按序）

1. SCENE-SPECS 新增「真实感纪律」+「穿模纪律」章节（精雕 agent 强制执行）— 见本条目下一步已落地。
2. `build/scenes/intersect-audit.mjs`：跨容器两两 AABB 相交检测，输出重叠深度排序 offenders，跑 28 场景。
3. 示范场景 level_01_01 苏醒之庭：拆 5+ 分工 agent 精雕（环境大形/主题道具/实体精雕/灯光栈/氛围粒子），读 SCENE-SPECS + threejs-* references。
4. 14 缺失精英程序化占位精雕替换（stoneSentinel/ginkgoElite/eliteCloudBridgeGuard/silenceBringer 等）。
5. scene-helpers 加 PBR 辅助：`phys`（clearcoat/transmission 工厂）、`roughTex`（噪声粗糙度变化）、`C.skin/C.ghostPhys`。

## 六、研究归档

`docs/research/threejs-pipeline/`（遵守 research/index.md「按主题子目录，禁止根目录堆」）：
- `2026-08-03-procedural-placement-interpenetration.md`
- `2026-08-03-realism-upgrade.md`
- `scene-chaining.md`

## 七、穿模审计落地（intersect-audit.mjs + SCENE-SPECS §7/§8）

**新工具 `build/scenes/intersect-audit.mjs`**：对照 §7 穿模纪律做 AABB 初筛（研究推荐 Box3 预筛 → 分类 → 人工/VLM 精查）。
- **执行**：复用 audit-scenes 的 @napi-rs/canvas polyfill，`env(S)` 真构建后跨顶层容器两两 AABB 相交 → 重叠深度排序；InstancedMesh 按实例展开精确；未命名容器附位置显示。
- **噪声分级收敛**（从数百 → 54 处候选）：跳过地面/粒子/灯/标签 + 大气层（全透明/叠加材质 + 关键词）+ 同名密集群（竹林/栅栏段）+ 远景/地形宏观件 + 宏观基底/屋顶/巨型舞台（cloudPlatform 等）+ 攀爬装饰贴墙（moss/藤）+ 建筑类（wall/palisade/canyonWall/beaconTower…）。
- **分类**：建筑-建筑 = 邻接候选（有意）；含道具 = 穿模候选；下沉 = 锚固候选。`--scene <id>` 单场景、`--json` 结构化供精雕 agent 消费。

**抓到一个真 Bug（scene-helpers）**：`stair()` 把 `x/z` 烘焙进子盒子**又**在组上加 `ry` 旋转——`{z:7.5, ry:π}` 叠加变换把楼梯翻到原点另一侧（z=-7.5），插进 stoneBier。修复：x/z 定位组、子件沿局部 -z 排布、ry 就地旋转（与 railing/pillar 一致）。顺手修 `railing()` 同类双 z 叠加。

**修复一个已验证真实穿模**：level_01_01 collapsedStatue(2,-5) 底座切入 stoneBier 0.45m → 移到 (3.2,-4.8) 保持"倒于苏醒石床旁"构图，净空满足。

**审计结果**：28 场景 54 处深重叠候选——绝大多数为设计使然（容器内含物：帐篷含桌/哨兵坐壁龛/武器架挂墙；贴墙锚固：火焰喷口/苔藓；雕塑组合：灰堆上篝火/池中铜锅）。**真正可疑需 VLM/视觉复核**：level_01_02 的 stoneSentinel 多处深重叠（占位精英 AABB 大）、level_01_05 未命名屋顶残块撞石柱、level_03_05 玉藤高墙↔会动墙 1.10m。属 #93 精雕阶段按 §7 修。

**验证**：`verify-scenes.mjs` 28 场景全通过；`phase-check.mjs` 18 阶段 0 错误。
