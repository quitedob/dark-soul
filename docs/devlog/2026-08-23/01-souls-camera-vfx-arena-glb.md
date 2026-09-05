# 类魂镜头取景 · 战斗 VFX · Boss 场地互动 · GLB 真入玩法 —— 已完成

日期：2026-08-23
主题：四线并行交付——(1) 锁敌镜头改为 Dark Souls 式取景（镜头驻留玩家身后、玩家/目标同框、臂长随分离展宽）；(2) 战斗表现层（GPU 命中冲击粒子池、相变雾/光/调色渐变、相变 hit-stop 节拍）；(3) Boss 攻击真正作用于场地（可破坏 GLB 药罐、可预告持续危害区、相变塌陷环）；(4) three.js GLB 以包装场景 + 物理进主场景。
编排：perplexity-research 技能 3 路研究子代理 + 1 路代码扫描子代理 → 2 波实现子代理（镜头 / VFX / 场地）+ 主线做 GLB 场景与 game_world 接线。

> 状态：全部已完成，5 个新 smoke 契约全绿（`ASHEN_LOCK_FRAMING_OK` / `ASHEN_IMPACT_VFX_OK` / `ASHEN_PHASE_ENV_OK` / `ASHEN_ARENA_INTERACTION_OK` / `ASHEN_GLB_PROP_OK`）。

## 1. 锁敌取景（G-05：DS 式绕背同框）

研究结论（web-grounded）：DS 锁敌 = rig 锚在玩家头顶、偏航缓慢跟踪「玩家→目标」连线（世界慢转不甩镜）、俯仰瞄准玩家头顶与目标胸口的加权中点、臂长随分离距离展宽；帧率无关平滑用 `1 - exp(-k·delta)`，偏航用 `lerp_angle` 防绕远路。

- 新 `game/scripts/camera/lock_camera_solver.gd`（纯静态，模式同 `lock_on_solver.gd`）：`desired_yaw / desired_pitch / desired_boom / exp_weight`；常量 `MIDPOINT_BIAS 0.55 / YAW_TRACK_SPEED 2.2 / PITCH_SPEED 3.5 / BOOM_SPEED 3.0 / PITCH∈(-0.65,0.30) / BOOM∈(5.2,7.4) 增益 0.30`。
- `player.gd _update_camera_rig` 锁敌分支重写：旧「整 Basis 四元数 slerp 直视目标」→ 新「Y 轴慢速跟踪 + 中点俯仰 + 臂长展宽」；断锁恢复分支补臂长收回 5.2。取目标仍走 `get_target_point()`，导演覆盖/回正/回中分支零改动。
- 契约：`tests/smoke/lock_camera_framing_test.gd`（偏航方向/±PI 最短路/退化保持、俯仰符号与夹紧、臂长单调夹紧、exp_weight 数值）；既有 `lock_on_contract_test`、`real_strafe_back_contract` 不受影响仍绿。

## 2. 战斗表现层（L-24）

- **命中冲击粒子池** `fx/impact_vfx.gd`（Node3D，8 槽 + 3 槽环形池）：一次性 GPUParticles3D（`one_shot + explosiveness 1.0`），重触发用 `use_fixed_seed + seed=randi() + restart()`（`emitting=true` 在 one_shot 上不可靠，实证 Godot #83599）。kind→颜色：stone_sparks/ember/steel/dust。compat 渲染器确认：GPUParticles3D 可用（transform feedback），禁用 trails/sub-emitters/emit_particle（4.7 实证 API 偏差：`transform_align` 在节点上、无 `ParticleProcessMaterial.seed`、无 `angle_randomness`）。
- **相变环境漂移** `fx/phase_environment.gd`：`bind(world_env, key_light)` 快照默认 → `apply_lighting_key(key, duration)` 并行 tween（fog_light_color/density/energy、ambient、adjustment_saturation/contrast、glow_intensity、月光 color/energy；TRANS_SINE/EASE_IN_OUT）→ `restore_defaults()`。覆盖全 5 章 + 可选 Boss 共 **21 个 lighting 键**（此前 `phases.lighting` 一直是死数据），未知键按阶段数字做通用暖化渐变。
- **game_world 接线**：`on_boss_phase_changed` → env 漂移 + `HitStopManager.trigger(0.1s)` 节拍（reduced_motion 关闸）；`_on_player_hit_landed` → 命中点冲击粒子（Boss 石躯=stone_sparks、小怪=steel，重击 ×1.4）；新公开 `spawn_boss_impact_vfx(pos, radius)`（slam ring + ember 爆发 + 距离衰减创伤注入）供执行器调用；Boss 胜利 → `restore_defaults()`。
- 顺带修掉历史 bug：`game_world.world_environment` 从未被赋值（低画质开关静默失效），`_ready` 补 `get_node_or_null("NightEnvironment")`。
- 相变「镜头节拍」本就有（`PhaseFocusProfile` 焦点镜头 + 过渡姿态混合），本次补 env 漂移 + hit-stop 即成完整节拍。

## 3. Boss 场地互动（L-26）

- **可预告危害区** `boss_attack_hazard.gd`（86→232 行）：新元数据 `telegraph`（默认 0=旧即时行为，字节级兼容）与 `dot_interval`（默认 0=旧一击）。预告期：琥珀警示材质 + 缩放/发光脉冲、`monitoring=false` 零伤害；激活：稳态炽热视觉 + `monitoring=true` + 立即 `get_overlapping_bodies()` 扫描（body_entered 有滞后，按研究结论每 tick 重查）+ 一帧 physics_frame 复扫；DoT 按体限速重击；lifetime 从激活起算。
- **执行器挂钩** `boss_attack_executor.gd`：`_radial_aoe/_stage_wide_aoe/_targeted_impact_aoe` 落点统一走 `_notify_arena_impact`（组播 `destructibles.apply_boss_impact` + `has_method("spawn_boss_impact_vfx")` 探测调 world）与 `_spawn_aoe_hazard`（攻击键 `spawn_hazard/hazard_radius/hazard_lifetime/hazard_telegraph/hazard_dot_interval` → 落点持续危害区，父节点同 `_trail_hazard`）。
- **场地导演** `world/arena_director.gd`：守卫 Boss 入场 `build_arena(boss_pos)` —— 6 座石台环（StaticBody3D layer 1 + BoxShape/BoxMesh，`arena_chunks` 组）+ 5 只 GLB 药罐（种子散布，离中心 >3m、间距 ≥1.6m）；`on_boss_phase` 读 `phases[str(p)].arena_event`（同 polisher 读 vfx 的模式），`ring_collapse` → 爆炸档创伤注入 → 每块 0.12s 阶梯 → 1.2s 隆隆震颤（位置抖动 + ff5522 发光闪）→ `set_deferred disabled` + 下沉 12m（TRANS_QUAD EASE_IN）→ 自由；`ring_collapsed` 闩防重入；`on_boss_died` 清场。
- **内容接线**：`chapter_1_content.gd` 巨阙 phase 2 增 `"arena_event": "ring_collapse"`；`furnace_burst` 增 `spawn_hazard: true, hazard_radius 2.2, hazard_lifetime 5.0, hazard_telegraph 0.8`（= 至少一个 Boss 攻击真正改写场地：范围碎罐 + 留火区 + 相变塌环）。
- game_world：`_spawn_content_enemy(is_guardian)` → `_setup_boss_arena`（导演生命周期与守卫绑定）；相变/死亡转发如上。
- 契约：`tests/smoke/arena_interaction_contract_test.gd`（预告期零伤→激活扫描命中→DoT 重击；旧元数据即时一击；执行器 spawn_hazard 正/负例 + VFX stub 落点；药罐半径内碎/外存；导演建场计数、phase-1 无为、真内容 phase-2 塌陷 + 创伤注入 + 下沉自由 + 无双塌 + 死亡清场）。

## 4. GLB 真入玩法（L-25）

- `scenes/props/destructible_jar.tscn`：**包装场景**（StaticBody3D 根 + `07-Pickups.glb` 实例子节点 + `world/destructible_prop.gd`）。不用「继承场景」的原因：glTF 导入根是 Node3D，继承场景无法把根换成物理体；包装实例化是 Godot 官方推荐做法，脚本在 `_ready` 动态裁剪 GLB 分组（只留 `pillJar` 药罐、隐其余）、落地对齐、按子树 AABB 建盒碰撞。
- `world/destructible_prop.gd`：`apply_boss_impact(pos, radius)` / `take_hit` / `smash`（`broken` 信号 → CPUParticles 碎屑 + ≤4 块刚体碎片（外抛、4s 自清）→ 隐模型 + `set_deferred disabled` + 自由）；碎屑颜色取自 GLB 首个表面材质；`ember_reward` 由 game_world 发放（`add_embers`）。
- **主场景实例**：`scenes/world/ashen_hollow.tscn`（= main.tscn 唯一世界）神龛旁 3 只 `HubJarA/B/C`（`hub_props` 组），`_update_hub_props()` 只在初始庭园 level_01_01 显示；Boss 场地另有导演生成的 5 只。
- 材质验证：glTF 导入已提取 5 张 PNG 纹理（`07-Pickups_*.png.import` 在侧），契约断言药罐网格表面材质非空。

## 5. 契约与回归

新增 5 个 smoke 契约（上文各节），全部独立可跑：

```
godot --headless --path game --script res://tests/smoke/lock_camera_framing_test.gd        # ASHEN_LOCK_FRAMING_OK
godot --headless --path game --script res://tests/smoke/impact_vfx_pool_test.gd            # ASHEN_IMPACT_VFX_OK
godot --headless --path game --script res://tests/smoke/phase_environment_contract_test.gd # ASHEN_PHASE_ENV_OK
godot --headless --path game --script res://tests/smoke/arena_interaction_contract_test.gd # ASHEN_ARENA_INTERACTION_OK
godot --headless --path game --script res://tests/smoke/glb_prop_scene_contract_test.gd    # ASHEN_GLB_PROP_OK
```

全量回归：`tools/ci.ps1` → **`ASHEN_HOLLOW_CI_OK`**（编辑器解析检查 0 错误；GUT 13 脚本 / 96 用例 / 394 断言全过；CI smoke 集全绿）。单独复跑 `boss_weakpoint_contract_test.gd` 确认其在 HEAD 即失败（见下节）。

## 6. 已知事项（非本次引入）

- `boss_weakpoint_contract_test.gd` 在 HEAD 即失败（"Need 5 main + 1 optional boss break profiles"，目录现 8 个 Boss）——两文件 `git diff HEAD` 为空，属上次 Boss 增容后契约未更新，已记录未修。
- `enemy.gd` / `core/part_rig_builder.gd` 的未提交改动属 2026-08-22 骨骼网会话（见 `2026-08-22/04-real-skeleton-network.md`），本次未触碰。

## 7. 可复用清单

- 取景数学：`scripts/camera/lock_camera_solver.gd`（纯静态可 headless 复算）
- 冲击粒子池 / 环形冲击：`scripts/fx/impact_vfx.gd`（`spawn_impact(pos, normal, kind, scale)` / `spawn_slam_ring`）
- 环境漂移：`scripts/fx/phase_environment.gd`（21 lighting 键 + 通用回退 + 快照恢复）
- 场地导演：`scripts/world/arena_director.gd`（build_arena/on_boss_phase/on_boss_died，参数全部可覆盖）
- 可破坏物：`scenes/props/destructible_jar.tscn` + `scripts/world/destructible_prop.gd`（换 `part_group` 即可复用 07-Pickups 其它物件）
