# 程序化场景摆放：物体穿模的检测与正确处理

**日期:** 2026-08-03
**研究方式:** Perplexity pro 单次合并搜索（backend_uuid `14adc0e4-...`）
**主题:** three.js 程序化场景（魂类装饰性环境，无物理引擎，大量程序化雕刻静态物件）中物体穿模（interpenetration/clipping）的检测、避免与校正。
**用途:** 为 Ashen Hollow `build/scenes/` 28 场景精雕升级前的先决项——当前场景系统**零穿模处理**（Phase 0 扫描确认：placeGLB 只归一化缩放/原点，无碰撞避让、无相交检测）。

---

## Key Findings（按置信度排序）

### 高置信度

1. **没有"一键解决"，正确做法是 检测→避免→校正 三位一体**，不同阶段用不同粒度的检测。程序化关卡稳定避免穿模必须三者组合，不能只靠其中一个。

2. **检测的分层组合（按精度↑ / 性能↓）**：
   | 方法 | 用途 | 权衡 |
   |---|---|---|
   | `THREE.Box3.intersectsBox` | 初筛（快） | 精度依赖包围盒紧密度，易误报/漏报 |
   | three-mesh-bvh（meshBVH） | 精确穿透/最近点（静态网格最优） | 构建成本高，实现复杂 |
   | Raycaster 多方向投射 | 细粒度验证、地面贴合 | 射线数决定成本 |
   | 自定义 AABB/OBB | 比 Box3 贴形 | 实现复杂 |
   | 球/胶囊近似 | 距离初筛 | 有误差 |

   **推荐：Box3 做预筛选 → BVH 精确检测 → Raycaster 复核关键件。**

3. **源头避免（放置阶段）**：占位碰撞几何 + 空间哈希/网格对齐 + 地面贴合（ground snapping）+ 摆放时对已有物件做包围盒避让 + 随机抖动+重叠回退。摆放候选位姿先快速碰撞筛选，无冲突才落位。

4. **穿模后校正（非物理、装饰场景）**：优先 `snap-to-surface`（贴合表面）→ 推离到最近合规点 → 局部网格修正 → 隐藏/替换冲突物件。**CSG 布尔裁剪作为最后手段**（拓扑/UV 代价高）。避免全局物理求解。

### 中置信度

5. **跨引擎等价**（Godot 移植）：Area + CollisionShape 做碰撞检测，RayCast 做贴合/推离，GridMap/Voxel 做分区。核心是保持"检测-避免-校正"循环一致，注意坐标系/单位/缩放一致性。

6. **容易遗漏的点**：穿模修正要考虑遮挡关系（避免视觉跳跃）；远距离对象用简化碰撞体/LOD；开发阶段提供**统一调试可视化**（显示包围盒、最近点、冲突）帮助快速定位。

---

## Project Documentation Reviewed

| 文件 | 相关发现 | 可靠性 |
|---|---|---|
| `build/scenes/_shared/scene-helpers.mjs` | `placeGLB` 用 `Box3.setFromObject` 归一化缩放与原点，但**无**碰撞避让/相交检测；`ground/disc` 置地于 y=0 | RELIABLE |
| `build/scenes/_shared/renderer.mjs` | `getBoundingClientRect` 仅用于点击 raycast，与穿模无关 | RELIABLE |
| `build/scenes/_shared/SCENE-SPECS.md` | 有材质/光照/密度清单，**无**穿模纪律条目 | RELIABLE |
| `build/scenes/audit-scenes.mjs` | 现有合规审计只查字段/密度/阶段，不查空间相交 | RELIABLE |

**结论：场景系统在摆放空间关系上零保障，需新增检测工具 + 放置纪律 + 校正。**

---

## Sources

Perplexity 汇总（回答内嵌引用，未提供可点击 URL 明细，置信度标注在回答中）：
- THREE.Box3.intersectsBox 快速筛选
- three-mesh-bvh meshBVH 精确相交/最近点查询
- Raycaster 多方向投射与地面贴合
- 占位碰撞几何 + 空间哈希 + grid alignment 摆放实践
- Godot Area/CollisionShape/RayCast 等价做法

---

## Contradictions & Gaps

- **意图穿模 vs 穿模 bug 的边界**：装饰场景中"墙根埋入地面 / 石柱扎入地板 / 雕像贴墙"常是**有意锚固**，与"两个显眼道具互相穿插"是不同性质。单纯 AABB 检测会误报锚固型。**需分类处理**：锚固（base 低于地表/贴墙，允许）vs 道具互相重叠（修复）。
- Perplexity 未给出可直接复制的最小可运行示例骨架（提问末尾它反问要不要生成）——实现需自行完成。

---

## Recommendations（落地到 Ashen Hollow）

1. **写 `build/scenes/intersect-audit.mjs`**（检测层）：
   - 构建每个场景 env + 实体，按**顶层摆放容器**分组（env 条目 / entity 各自的 Group/Mesh）。
   - 跨容器两两 AABB 相交 → 计算重叠深度，超过阈值（如 0.15m）上报。
   - 地面锚固判断：容器最低 mesh 顶点 y 明显 < 0（非 ground 层）→ 报"下沉"；贴墙（与墙 AABB 重叠但仅边缘）→ 报"贴墙锚固"，与真正重叠区分。
   - 输出按重叠深度排序的 offenders 清单，供 agent/主线程判定修复。
2. **SCENE-SPECS 新增「穿模纪律」**（避免层 + 校正规则）：
   - 每个独立道具与相邻道具**净空 ≥ 0.1m**；hero 道具（雕像/机关/宝箱）绝不互相重叠。
   - 锚固规则：需要埋地的（墙/柱/栅栏）统一以"底面贴 y=0"锚固；雕像/奖杯只能通过基座/台座接触地面，主体不得入地。
   - 每个场景放置完成后，agent 必须跑 `intersect-audit.mjs`，把剩余真实穿模（非锚固型）清零再交付。
3. **精雕 agent 提示词纳入**：所有雕刻物件放置坐标遵循穿模纪律；复杂雕刻（工具箱）本身不会穿模，穿模只来自摆放坐标选择。
4. **校正策略**（供 agent 修复时用）：优先抬高/外推（改 y/x/z 使净空满足）；必要时缩小；不得用 CSG/顶点修正（装饰场景不值得）。

---

## Search Coverage

- **查询 1**（pro，zh，单次合并）：5 题检查清单——检测方法/避免策略/校正方法/推荐组合/Godot 移植。覆盖全部 5 题。
- **未做** deep_research（本主题是实操综述，pro 已够）；未做 follow_up（回答已覆盖，可落地）。
- **Phase 0**：项目内文档/代码扫描完成（见上表），确认无既有实现。
