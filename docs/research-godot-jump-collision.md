# Godot 4.x 跳跃、落地与碰撞穿模研究

**研究日期：** 2026-07-30  
**目标版本：** Godot 4.7.1  
**项目：** 《焰渊》/ Ashen Hollow 兼容原型  
**状态：** 研究归档；**P0/P1 核心项已落地到运行时**（见下方 Implementation Status）

## Implementation Status (2026-07-30)

| 项 | 状态 | 代码 |
|---|---|---|
| P0 弹体 World mask + sweep | ✅ | `scripts/components/spell_projectile.gd` (`QUERY_MASK`, `cast_motion`) |
| P0 垂直拓扑坡道 | ✅ | `scripts/world/procedural_campaign_level_builder.gd` (`_add_height_ramps`) |
| P0 柱子碰撞 | ✅ | 同上 `KitPillar` → `StaticBody3D` |
| P0 安全重生 / Lost Echo 投影 | ✅ | `scripts/core/safe_placement.gd` + `player.respawn_at` / `game_world` |
| P1 通用跳跃 | ✅ 基础 | `jump` 键位 `V` / D-pad up；`JUMP_VELOCITY`；落地速度采样 |
| P1 显式 CharacterBody 参数 | ✅ | `scripts/core/player_visuals.gd` |
| P1 jump attack / falling attack | ✅ | 通用跳攻/下落攻；tip socket + ShapeCast；leap 独立 |
| P2 last_safe 恢复传送 | ✅ | `player.recover_to_last_safe` / void Y 与超深跌落触发 |
| 合约测试 | ✅ | `tests/smoke/jump_collision_contract_test.gd` |

## Key Findings

### 高置信：官方文档与当前代码共同确认

1. `floor_snap_length` 只负责沿 `-up_direction` 的向下贴地，不会自动跨越向上的垂直台阶。Godot 的内置 stair stepping proposal 仍为 open，因此垂直台阶需要坡道碰撞体或自定义 step-up 测试。
2. 自动 floor snap 在角色沿 `up_direction` 上升时停用，以允许跳跃离地。`apply_floor_snap()` 是忽略速度、按需强制贴地的 API；不应无条件每帧调用，否则可能破坏正常跳跃。
3. 当前弹体为 `Area3D`，每物理帧直接修改 `global_position`。官方 `Area3D` 文档只保证物理步上的 overlap monitoring，没有连续 swept collision 保证。当前 mask 还排除了世界层，因此穿墙是明确的配置行为，而非偶发 bug。
4. 当前程序化 `vertical_tower`、`vertical_library`、`vertical_floating_path` 每层增加 2 m 高差，而玩家没有通用 jump，floor snap 也不能向上跨越，存在确定的可达性缺口。
5. 玩家重生、敌人重置与 Lost Echo 生成均直接设置位置，没有目标重叠检测、向下找地面、可达性检查或安全候选搜索。
6. `RigidBody3D.continuous_cd` 只属于 `RigidBody3D`，默认关闭。它不能直接修复 `CharacterBody3D` 或 `Area3D` 通过代码更新 transform 的问题。
7. 动态角色碰撞体应优先使用未缩放的 primitive/convex shape；`ConcavePolygonShape3D` 应保留给静态场景。

### 中置信：需要项目实测确定阈值

1. 8.4 m/s 闪避和当前代码 lunge 不应被简单判定为“必然穿模”。`move_and_slide()` 本身执行运动和碰撞恢复；实际风险取决于物理 tick、极端单步位移、薄/异常几何、初始重叠、凹角和 `max_slides` 耗尽。
2. `safe_margin` 可在小幅范围内提高接触稳定性，但过大会造成窄通道拒绝进入、悬浮或过早分离。项目应基于 0.001 默认值测试，而不是盲目放大。
3. 自定义台阶处理常用“抬升 → 前移 sweep → 下压找地面”或上下两个 ShapeCast。此模式来自社区与 open proposal，不是 Godot 当前内置保证。
4. `last_safe_transform`、卡住计时器和异常位移恢复是防御性工程实践，不应掩盖错误关卡碰撞、坏 spawn 或缺失可达性连接。

## Project Documentation Reviewed

| 文档/代码 | 结论 | 可靠性 |
|---|---|---|
| `game/scripts/player/player.gd` | 当前每物理帧施加重力后调用一次 `move_and_slide()`；没有通用跳跃、落地事件或安全位置监控 | RELIABLE |
| `game/scripts/core/player_visuals.gd` | Capsule 半径 0.42、高 1.85；`floor_snap_length=0.35`；其他 CharacterBody 参数依赖默认值 | RELIABLE |
| `game/scripts/components/spell_projectile.gd` | `Area3D` 弹体直接逐帧平移，mask=4，仅检测敌人、不检测世界 | RELIABLE |
| `game/scripts/world/procedural_campaign_level_builder.gd` | 垂直 topology 每层增加 2 m；没有坡道或台阶连接；导航 max climb 不能赋予玩家运动能力 | RELIABLE |
| `game/scripts/game_world.gd` | Lost Echo 与重生位置未经 overlap/ground/reachability 检查 | RELIABLE |
| `docs/systems/combat-execution-guard-weapon-arts.md` | 已明确通用 jump、jump attack 和 falling attack 尚未实现 | RELIABLE |
| `docs/tasks-master.md` | B-08 将通用跳跃与空中攻击列为 Pending | RELIABLE |
| `docs/validation.md` | 有基础移动/重生手测，但缺少斜坡、台阶、墙角、薄墙、高速弹体与安全传送测试 | PARTIALLY RELIABLE |
| `docs/devlog.md` 旧 collision 条目 | 准确记录弹体 mask 排除世界；部分旧 STYLE_TIMING/hit-stop 描述已过时 | PARTIALLY RELIABLE |

## CharacterBody3D 官方参数基线

以下为 Godot stable/4.4 类文档中确认的默认值。项目目标是 4.7.1，当前 stable 页面给出了相同核心值；仍应在升级版本时复核。

| 属性 | 官方默认值 | 作用 | 项目建议 |
|---|---:|---|---|
| `motion_mode` | `MOTION_MODE_GROUNDED` | 区分 floor/wall/ceiling 并应用坡面规则 | 显式设置，避免依赖默认值 |
| `up_direction` | `Vector3.UP` | 定义 floor/wall/ceiling 分类方向 | 显式设置 |
| `floor_max_angle` | 45° | 超过该角度不再视为 floor | 从 45° 起测；与关卡坡道规范统一 |
| `floor_snap_length` | 0.1 m | 沿 `-up_direction` 维持下坡贴地 | 当前 0.35 m 可保留为测试值，但需验证坡顶/小落差 |
| `floor_stop_on_slope` | `true` | 静止时防止沿坡滑下 | 保持 true，除非设计需要滑坡 |
| `floor_constant_speed` | `false` | 默认上坡减速、下坡加速 | 按战斗移动设计选择并写测试 |
| `floor_block_on_wall` | `true` | 防止 grounded 模式走墙 | 显式设置 true；官方 #66249 已在 4.3 修复，不应沿用旧 workaround |
| `wall_min_slide_angle` | 15° | grounded + wall block 时允许墙面滑动的最小角 | 使用默认起测 |
| `safe_margin` | 0.001 m | 运动前 collision recovery 余量 | 显式设置；仅小步调参 |
| `max_slides` | 6 | 单次 `move_and_slide()` 最大改向次数 | 记录 slide count，先使用默认 |
| `slide_on_ceiling` | `true` | 顶头时沿天花板滑动 | 跳跃实现时决定是否改为 false |

### Snap 正确用法

```text
普通 grounded 移动
→ 设置 velocity
→ move_and_slide()
→ 使用 is_on_floor() / floor normal 读取本次结果
```

- `floor_snap_length > 0` 时，`move_and_slide()` 内部自动尝试向下贴地。
- 当 velocity 沿 `up_direction` 为正时，自动 snap 停用，以允许跳跃。
- `apply_floor_snap()` 会忽略 velocity 强制 snap，且已在 floor 上时无效果。
- 仅在需要恢复意外短暂离地、且确定当前不是跳跃/击飞时调用 `apply_floor_snap()`。
- 不要把它作为每帧固定调用，否则可能把刚起跳的角色拉回地面。

## 台阶与斜坡

### 官方能力边界

- Floor snap 解决的是向下地面贴合、小落差和斜坡连接。
- 它不能把胶囊自动抬过垂直台阶前缘。
- Godot stair stepping proposal `#2751` 仍为 open，说明该能力不应被假设为 `move_and_slide()` 内置功能。

### 推荐优先级

1. **关卡几何优先：** 视觉楼梯使用独立的坡道 `StaticBody3D` 碰撞体。这是最稳定、最便于导航和自动测试的方案。
2. **低矮台阶才用代码 step-up：** 定义统一 `max_step_height`，进行抬升、前移 sweep、向下找稳定 floor 的三段测试。
3. **拒绝不稳定落点：** 下压命中面必须在 `floor_max_angle` 内，头部空间必须无碰撞，最终位置不得重叠。
4. **不要用直接加 Y 穿过台阶：** 所有候选位移都要经过 `test_move()`、`body_test_motion()` 或 shape sweep。

### 社区 step-up 模式

```text
前方运动被低墙阻挡
→ 从当前 transform 向上 test max_step_height
→ 从抬升后的 transform 测试水平 motion
→ 从新位置向下 cast 找 floor
→ floor 法线与高度合法时接受位移
→ 否则按普通墙碰撞处理
```

该模式需要处理移动平台、斜台阶、凹角、顶头空间和网络/回放一致性，因此只建议在坡道碰撞无法满足美术需求时使用。

## 高速 CharacterBody3D

### 不应采用的结论

“8.4 m/s 必然穿墙”没有官方证据。当前 60 physics ticks 下理论水平位移约 0.14 m/step，仍需以真实薄墙和帧率测试判断。

### 应检测的风险

- 直接设置 `global_position` 或 transform 绕过运动 API。
- hit-stop、卡顿或低 tick 导致单步 motion 显著增大。
- 比胶囊和 `safe_margin` 更薄的错误几何。
- 出生时已与墙体重叠。
- 凹角/多墙面接触导致 `max_slides` 用尽。
- lunge/root motion 在同一物理帧额外叠加 transform 位移。

### 推荐监控

每物理帧记录：

```text
requested_motion = velocity * delta
actual_motion = global_position - previous_position
slide_count = get_slide_collision_count()
```

触发诊断日志的条件：

- requested motion 很大且 actual motion 异常接近 requested motion，但路径中预扫命中静态世界。
- 连续若干帧有显著水平速度但 actual horizontal displacement 接近零。
- slide count 达到 `max_slides`。
- floor 状态反复抖动且 floor normal/angle 大幅变化。
- 位置落到关卡最低合法高度以下。

高承诺闪避/lunge 可在执行前用 `test_move(global_transform, requested_motion)` 诊断目标 motion；只有真实回归测试证明单步过大时才增加 bounded substeps。

## 弹体与 Area3D

### 当前问题

当前 `SpellProjectile`：

- `collision_mask = 4`，只检测敌人层。
- `global_position += direction * speed * delta`。
- 依赖 `Area3D.body_entered` overlap 事件。

官方 `Area3D` 文档说明 overlap 列表每 physics step 更新，并未保证移动路径的连续扫掠。因此当前设计：

- **确定会忽略世界阻挡**，因为 mask 不包含 layer 1。
- **可能跨过小目标而无 overlap**，尤其弹体单步位移大于碰撞直径时；需要 sweep 查询验证，不应依赖 overlap 补救。

### 推荐修复

1. 将 projectile query mask 包含世界层与敌人层，例如当前语义下使用 `1 | 4`。
2. 每帧从 previous position 到 next position 做 query：
   - 极细、极快箭矢：`intersect_ray()`。
   - 有半径的法球、宽射线：`cast_motion()` 或 `ShapeCast3D`。
3. 在最近命中点停止，按距离排序决定世界阻挡或敌人命中。
4. `intersect_shape()` 用于当前位置 overlap，不读取 query motion，不能替代 sweep。
5. `cast_motion()` 排除初始已重叠 shape；出生时应先用 `intersect_shape()` 检查。
6. 保留 `Area3D` 可用于持续区域效果，但飞行路径碰撞必须由显式 sweep 决定。
7. 只有需要真实物理反弹/质量/力时才改为 `RigidBody3D` 并启用 `continuous_cd`；普通魔法弹不必为 CCD 改成刚体。

## 安全出生、重生和传送

### API 选择

| API | 最适合 | 注意事项 |
|---|---|---|
| `PhysicsDirectSpaceState3D.intersect_shape()` | 检查目标 transform 当前是否与世界/角色重叠 | 不处理 motion；适合 spawn candidate |
| `PhysicsBody3D.test_move()` | 从给定 transform 预测一段 motion 是否被阻挡 | 不移动 body；可返回 `KinematicCollision3D` |
| `PhysicsServer3D.body_test_motion()` | 用 body RID + 参数执行更底层 motion test | 官方没有“性能最高”承诺；优先使用可维护的高层 API |
| `ShapeCast3D` | 持续或可视化的 shape sweep、向下找地面 | 结果通常在 physics update 刷新；即时需要调用 `force_shapecast_update()` |
| `intersect_ray()` | 从候选位置向下找第一地面 | 线查询无法验证胶囊完整空间 |

### 安全落点流程

```text
候选 checkpoint/spawn
→ 胶囊 intersect_shape：排除静态世界与阻挡角色
→ 从候选上方向下 ray/shape cast 找 floor
→ 验证 floor angle
→ 用完整胶囊再次 intersect_shape
→ 设置 global_transform
→ 等待/进入下一个 physics step 后启用碰撞
→ 记录 last_safe_transform
```

如果候选无效，按固定、可重复顺序搜索同心环或预定义备用 marker；不要随机采样，保证存档和测试可复现。

Lost Echo 应投影到最近可站立 floor，并验证从 checkpoint 到该位置可达；否则将其放回最近安全路径 marker。

## 碰撞形状与层

### 官方最佳实践

- CharacterBody3D 与移动 RigidBody3D 优先使用 Box/Sphere/Capsule/Cylinder 等 primitive。
- 小型复杂动态物体可用单 convex hull；更复杂物体可有限 convex decomposition。
- Concave/trimesh 只用于复杂静态场景；官方文档明确 concave shape 只能用于 StaticBody。
- 避免移动、旋转或缩放 `CollisionShape3D` 子节点；尤其避免非均匀缩放。直接修改 Shape3D 尺寸。
- 视觉柱子、门框或台阶若会阻挡玩家，必须有独立碰撞体；当前程序化 `KitPillar` 只有视觉 mesh，不会阻挡。

### 项目层建议

在 `project.godot` 中显式命名：

```text
Layer 1: World
Layer 2: Player
Layer 3: Enemies
Layer 4: Interactables
```

为 projectile 区分“能伤害什么”和“能阻挡什么”，不要为了避免和施法者碰撞而移除 World mask；应使用 query exclude/source RID。

## 异常检测与恢复

### 建议状态

```gdscript
var was_on_floor := false
var previous_position := Vector3.ZERO
var previous_vertical_velocity := 0.0
var last_safe_transform := Transform3D.IDENTITY
var stuck_frames := 0
```

### 落地检测

在 `move_and_slide()` 前保存 `was_on_floor` 和垂直速度，之后检测：

```text
landed = not was_on_floor and is_on_floor()
landing_speed = max(0, -previous_vertical_velocity)
```

使用 landing speed 决定普通落地、重落地和伤害；不要用当前已被 `move_and_slide()` 修改的 `velocity.y` 推断冲击速度。

### last_safe_transform 更新条件

仅在以下条件同时满足时更新：

- `is_on_floor()`。
- floor angle 合法。
- 完整胶囊不重叠。
- 不在移动危险平台边缘或死亡区。
- 距离上个位置没有异常瞬移。

恢复只作为最终保险。每次恢复必须记录原因、原位置、目标位置、requested/actual motion 和最近 slide normals，便于找到根因。

## Debugging

### 编辑器与运行时

- 在运行项目的 Debug 菜单启用 **Visible Collision Shapes**，检查视觉台阶、坡道、门框和薄墙是否与碰撞一致。
- 对 CharacterBody3D 输出 `get_slide_collision_count()` 与每个 `get_slide_collision(index)` 的 normal、position、collider。
- 给 floor、wall、ceiling 分类和 last-safe marker 使用不同 debug gizmo/颜色。
- ShapeCast 的查询结果通常在 physics step 更新；更改 cast 后立即读取前调用 `force_shapecast_update()`。
- ShapeCast 比 ray cast 昂贵，只在半径重要时使用。

### Headless 测试矩阵

| 场景 | 断言 |
|---|---|
| 平地起跳/落地 | 仅触发一次离地和一次落地；snap 不取消上升 |
| 坡顶/下坡 | floor 状态稳定，无悬空抖动或速度爆增 |
| 45°临界坡与陡坡 | floor/wall 分类与 `floor_max_angle` 一致 |
| 低台阶/高台阶 | 低于阈值可通过；高于阈值视为墙 |
| 顶头跳跃 | 无穿顶；`slide_on_ceiling` 行为符合规格 |
| 两墙凹角 | 不进入墙内；卡住检测不会误触发正常贴墙 |
| 薄墙闪避/lunge | 30/60/120 physics ticks 下不越过阻挡 |
| 弹体薄墙/敌人同线 | 最近碰撞者获胜；墙后敌人不受击 |
| 弹体初始重叠 | overlap 检测生效且只结算一次 |
| checkpoint 被占用 | 选择确定性的备用落点 |
| Lost Echo 位于墙内/虚空 | 投影到可站立、可达位置 |
| 程序化 28 关 | Spawn→Checkpoint→Exit 可达；垂直拓扑有合法连接 |

## Prioritized Recommendations

### P0 — 修复已证实问题

1. **弹体世界阻挡与 sweep：** mask 加 World，使用 ray/shape swept query，以最近命中结算。
2. **垂直拓扑可达性：** 在通用 jump 完成前，为 2 m 高差生成坡道、升降台或合法连接；加入 Spawn→Exit 可达性测试。
3. **安全重生：** 实现 spawn candidate overlap + floor 验证；Lost Echo 使用安全投影。

### P1 — 建立通用跳跃与检测

4. 增加 jump input、`AIRBORNE`/`LANDING` 语义、上升时禁用 snap、落地前速度采样、顶头处理。
5. 显式设置所有 CharacterBody 参数，避免引擎升级改变隐式行为。
6. 增加 floor normal/angle、slide count、requested/actual motion 与 stuck diagnostics。

### P2 — 场景手感与保险

7. 优先采用视觉楼梯 + 坡道 collider；只为小台阶实现 bounded step-up。
8. 引入 `last_safe_transform`，但仅作为记录充分的最终恢复机制。
9. 为 30/60/120 physics ticks 与低帧卡顿建立回归场景，再决定是否对 dash/lunge substep。
10. 在 `project.godot` 显式命名物理层，并把碰撞参数写入 validator/debug overlay。

## Sources

### Godot 官方文档

- [CharacterBody3D 4.4](https://docs.godotengine.org/en/4.4/classes/class_characterbody3d.html) — snap、坡面、safe margin、max slides、slide collision。
- [CharacterBody3D stable](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) — 当前 stable 参数基线。
- [PhysicsBody3D](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html) — `test_move()`。
- [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) — `cast_motion()`、`intersect_ray()`、`intersect_shape()`。
- [ShapeCast3D](https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html) — shape sweep、即时更新和性能说明。
- [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html) — overlap monitoring 与 physics-step 更新。
- [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html) — `continuous_cd`。
- [Collision shapes (3D)](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_3d.html) — primitive/convex/concave 与 transform 最佳实践。
- [PhysicsTestMotionParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicstestmotionparameters3d.html) — motion test 参数。

### Godot 官方 issue/proposal

- [Proposal #2751 — built-in stair stepping](https://github.com/godotengine/godot-proposals/issues/2751) — 当前仍 open，说明 stair step 不是内置保证。
- [Issue #66249 — floor_block_on_wall speed issue](https://github.com/godotengine/godot/issues/66249) — 已在 4.3 milestone 修复；不应作为 4.7 默认禁用 wall block 的理由。

### Perplexity 研究

- 主查询：Godot 4.x jump/collision/tunneling checklist，deep research，2026-07-30。
- Follow-up：官方文档核验；首次返回解析错误，第二次回复缺失具体引用，因此未把其中空缺作为证据。
- Perplexity thread UUID：`f92d7a8e-e7ba-4e38-97d3-07e10679dd34`。

## Contradictions & Gaps

- Perplexity 初答称“应始终调用 apply_floor_snap”和“8.4 m/s 确实导致隧穿”，均缺乏官方依据，已撤回。
- 官方文档没有承诺 `Area3D` transform movement 的连续 sweep；因此报告采用“无保证、应显式 sweep”，而非断言每次都会穿模。
- Godot 官方未宣称 `body_test_motion()` 是性能最高方案；报告不作此比较。
- `Visible Collision Shapes` 菜单路径未能从本次抓取的官方 troubleshooting 页面提取，菜单名属于常见编辑器功能，仍需在目标 4.7.1 编辑器中人工确认。
- 当前没有运行 Godot 测试；所有项目风险基于代码静态核验，实际复现频率仍需测试场景量化。

## Search Coverage

- 扫描项目玩家、敌人、弹体、程序化关卡、重生、碰撞层、测试和文档。
- 一次 Perplexity deep research + 一次有效 follow-up；未并发调用 Perplexity。
- 直接读取已识别的 Godot 官方文档和官方 issue/proposal。
- 未研究 2D 控制器、网络预测或第三方物理插件；它们不属于当前 CharacterBody3D 原型范围。
