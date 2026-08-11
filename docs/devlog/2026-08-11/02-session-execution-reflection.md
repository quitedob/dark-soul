# 会话执行复盘：85 GLB 入游戏 + 动效层 + 调研（全部行动 / 难点 / 决策 / 记忆）

> 2026-08-11 · 本条目是**过程复盘**（不是交付快照）。交付快照见 `01-85-glb-into-game-real-model-milestone.md`。
> 记录：我（Claude Code）在这一长会话里做了什么、遇到哪些难点、怎么排查解决的、留下哪些可复用的经验。

---

## 1. 会话总览（做了什么）

1. `/godot` → 加载 `ashen-hollow-dev` 技能 → 按 **recon → foundation → parallel → verify** 编排。
2. **recon**：3 个 Explore 子代理并行扫 `docs/` + `game/` + three.js 技能引用（返回 path:line 证据 + 可靠度标签）。
3. **系统健康基线**：smoke / 全脚本解析 / 真模型契约 / GUT 全绿（除 5 个既有 UI 警告 + 1 个既有 `test_stamina_economy` 陈旧断言）。
4. **three.js 真模型 + 骨骼网络查看器**（`build/real-models/`，端口 8768）：真实骨骼 GLB + `AnimationMixer` 骨骼动画 + `SkeletonHelper` 骨骼网络可视化 + 武器挂 `DEF-hand.R` 骨 + 骨骼驱动滑杆；用 chrome-devtools + 本地 VLM 视觉验证。
5. **主线（用户澄清）**：把 three.js 里已有的 85 个 GLB "变进游戏"。
6. **导入 85 GLB** → `game/assets/models/`（镜像 out/ 结构）→ Godot 编辑器导入 88 个全过。
7. **RealModelResolver.REGISTRY 扩到 60+ 条** + 新增 `align_ground`（接地对齐）。
8. **敌人工厂按 id 分派**（`enemy/body/by_id/<id>` → body_type → 程序化回落）+ 真身体自带武器 → 跳过独立武器槽。
9. **召唤物 + NPC 接真模型**（`summon/<kind>`、`npc/<id>`，未注册回落占位）。
10. **专属动效档案**：`ModelMotionProfiles` 聚合器 + 8 个批次文件，**8 个子代理并行**编写 86 条（覆盖 85 GLB）movement + VFX；驱动 `ModelFx`（bob/float/sway/rock + embers/motes/dust + aura + windup 余烬）。
11. **验证**：全脚本解析 / smoke / 真模型契约（含接地对齐 + by-id 交换）/ GUT 全绿。
12. **文档**：devlog 快照 + 索引 + tasks-master L-18 → IN PROGRESS。
13. **`/perplexity-research`**：three.js GLTF 最佳实践 → 报告归档到 `docs/research/threejs-pipeline/threejs-gltf-best-practices.md`。

---

## 2. 难点与排查（detail — 你要的重点）

### D1. 查看器 `bones.map is not a function`
- **症状**：`build/real-models/viewer.mjs` 控制台报 `TypeError: bones.map is not a function`。
- **排查**：chrome-devtools 读控制台 → 定位到 `bonesDepth(s.root, s.skeleton)`——我把 `s.root`（一个 `THREE.Group`）当成了骨头数组传进去，`.map` 自然没有。
- **解决**：改成 `bonesDepth(s.skeleton?.bones ?? [], s.skeleton)`。重载后控制台无报错。
- **经验**：类型越界最容易藏在"名字像数组的对象"上；浏览器控制台是第一证据源。

### D2. bash 通配符没递归 → 只拷了 31 个 GLB
- **症状**：`build/glb-models/out/**/*.glb` 只复制了 31 个（bosses/equipment/props/weapons 直接层），`enemies/<chapter>/*.glb` 三层路径全漏。
- **排查**：复制后数了 `find game/assets/models -name '*.glb'` 数量不对，且看到 enemies/characters 子目录为空。
- **解决**：改用 `find ... -name '*.glb'` 逐行走 `cp`，补齐到 85。
- **经验**：本 shell **默认不开 globstar**；批量遍历一律用 `find`。

### D3. GLB 尺寸扫描没递归
- **症状**：`glb_size_scan.gd` 用 `DirAccess.get_files_at(dir)`——**不递归**，`enemies/`、`characters/` 下的 GLB 全没输出。
- **解决**：改成递归 walker（`list_dir_begin`/`get_next`/`current_is_dir`）。
- **经验**：Godot `DirAccess.get_files_at` 只列当前层；要递归必须自己走目录。

### D4. 旧契约测试与新行为冲突
- **症状**：`real_model_contract_test.gd` 三个断言失败：
  1. `ethereal_flicker` 现在**已注册**真模型（契约还断言它回落程序化）；
  2. `memory_claw` 因真身体自带武器、武器槽**有意留空**，契约却断言武器槽有孩子。
- **解决**：这是**行为有意改变**，不是回归 → 重写契约：换用未注册 body_type 测回落、断言"真身体武器槽留空"、新增 by-id 交换 + 40 个活动模型接地对齐检查。
- **经验**：契约不是神圣的——**行为变了就要同步改契约**，但要先确认行为变更是有意的（我核对过 `build_into_slots` 的真实语义）。

### D5. 接地对齐测试量错了参考系（实现是对的，测试是错的）
- **症状**：`Ground-align: boss_blind_bell ... y=-0.221` 报错，但实现看起来对。
- **排查**：我测的是 **ModelRoot 容器本地** min-y——`align_ground` 是把容器**抬起来**，容器内的网格相对容器还是负 y；真正"是否陷地"要看**父空间**（含容器位移）。
- **解决**：测试改为 `_min_y_relative(parent)`（把容器的 ground lift 算进去）。全绿。
- **经验**：**先想清楚被测量的"参考系"**。容器本地 y 和父空间 y 差了整整一个 offset，量错框架会得出"正确实现被误杀"。

### D6. enemy.gd 引用了不存在的 `State.CAST`
- **症状**：解析报 `Identifier "CAST" not declared`。
- **排查**：读 `enum State { ... }`——敌人状态机**没有 CAST**（那是玩家侧的）。
- **解决**：改成 `[State.IDLE, State.CHASE]`。
- **经验**：跨类抄状态枚举名最容易翻车；先 grep 源枚举再引用。

### D7. 新 `class_name` 在 headless 解析里"没声明"
- **症状**：`ModelFx` 报 `not declared in the current scope`——`model_fx.gd` 是新建文件，全局类缓存还没注册。
- **解决**：不依赖 `class_name`，改用项目一贯的 `const ModelFx = preload("res://scripts/fx/model_fx.gd")`；事后跑了一次编辑器导入正式注册。
- **经验**：新脚本在 Godot 里要一次编辑器导入才会进全局类表；**显式 preload 比裸 `class_name` 更稳**，也和本项目风格一致。

### D8. GDScript 集合字面量 `{a, b}` 解析失败
- **症状**：`body_type in {"a", "b", ...}` 报 `Expected ":" or "=" after dictionary key`。
- **解决**：GDScript 里逗号集合字面量按字典解析会炸 → 改回 const Dictionary `{"a": true, ...}` + `.has()`。
- **经验**：GDScript 写"集合"老老实实用 Dictionary；别用 JS 的习惯。

### D9. 子代理 schema 漂移（加了 `aura`）
- **症状**：8 个子代理交回的文件里，不少在 `vfx` 下加了**我没定义的 `aura`** 字段（带注释）。schema 没要求它。
- **处理**：没有粗暴回退（文件本身合法、语义合理），而是**顺势采纳**——驱动层补 `ModelFx.ensure_aura()`（软性 OmniLight3D），enemy.gd 读取 `vfx.aura`。
- **经验**：并行代理会按直觉扩 schema。要么 prompt 里把 schema 写成"白名单 + 禁止扩展"，要么**校验输出并采纳无害扩展**。这次选后者，速度快且语义没坏。

### D10. Perplexity 首答低保真（API 错 + 无 URL）
- **症状**：`/perplexity-research` 首答里 `loader.setDRACOLoader(new DRACOLoader(), '/path')`——不是真实签名；引文是 `[1][2]` 占位符，没有真 URL。
- **处理**：**counter-evidence 意识**——先自查：这 API 和我对 three.js 的知识冲突 → 做**一次 follow-up** 追问精确 API + 官方 URL；对 `GLTFExporter 无 meshopt 编码` 这类关键点单独确认。
- **经验**：**检索工具的答案要当"线索"不是"真理"**；低置信处主动复核，报告里如实标注中高置信 + 未逐 URL 复核的缺口。

---

## 3. 关键决策与理由

| 决策 | 理由 |
|---|---|
| 敌人/首领用 **per-id key**（`enemy/body/by_id/<id>`）而非 body_type | 多个敌人共享 body_type（`armored_medium` 有 2 个），GLB 却按实体定制；per-id 先试、body_type 回落，**不用改章节 content** 就 1:1 |
| 真身体**跳过独立武器槽** | 敌人 GLB 把武器烤在身体里（剑/戟/锤），再挂一把会双武器；视觉可接受（攻击时整身转） |
| 动效档案**数据驱动 + 8 文件分片** | 85 条 by 8 个子代理并行、**一文件一代理**不冲突；聚合器 `_merge_all` 运行时合并；无档回落空，**永远安全** |
| `align_ground` 做成**运行时 AABB**而非手填 y_offset | 40 个模型手填易错；运行时算一次最稳，模型变动自校正 |
| 先问 scope（查看器 vs 入游戏）再动手 | "use real model" 两个含义差很远；确认后用户又澄清"变进游戏"，方向对了 |
| 对 5 个既有 UI 警告 + 1 个 GUT 陈旧断言**只报不改** | 技能明确"pre-existing, report don't silently fix" |

---

## 4. 经验 / 记忆（可复用）

- **编排纪律**：recon 子代理给 `path:line + 可靠度标签`；实现子代理"只准改列出的文件 + 自跑 verify + 报 `git status --porcelain`"；主线程独立重跑全套——**不信任自报**。这次 8 个动效代理每个都自验过，我仍重跑了聚合器解析 + smoke + 契约，全部独立复绿。
- **契约测试**：行为有意变更时必须同步改契约（D4）；但先确认变更意图，别把正确行为当回归。
- **参考系**：测"是否陷地"要在父空间量（D5）；测网格 AABB 时用 `mesh.get_aabb()` + 累计 transform，注意容器位移与缩放。
- **批量文件**：shell 用 `find` 不用 globstar（D2）；Godot `DirAccess.get_files_at` 不递归（D3）。
- **新脚本**：显式 `preload` 优先；新 `class_name` 要先编辑器导入（D7）。
- **GDScript**：无集合字面量（D8）；状态枚举跨类引用先 grep（D6）。
- **并行代理**：schema 给白名单，输出要校验，无害扩展可采纳（D9）。
- **调研工具**：`/perplexity-research` 输出当线索；API 与常识冲突就 follow-up 复核；报告如实标注置信与缺口（D10）。
- **视觉验证**：主模型读不了图 → 用 chrome-devtools 截图 + 本地 remote-VLM（`build/glb-test/vlm_look.py`）当眼睛。

---

## 5. 验证与交付状态

- `ASHEN_HOLLOW_SMOKE_OK` · `REAL_MODEL_CONTRACTS_OK` · 全脚本解析 `fail=5`（全部既有）· GUT 95/96（1 既有陈旧断言）
- 交付：85 GLB 入 `game/assets/models/`；REGISTRY 60+ 条；敌人/首领/召唤/NPC 真模型激活；86 条动效档案；`build/real-models` 查看器；调研报告。
- 待办（已在 01 快照标注）：8 职业身体线程化、12 武器握持点映射、GLB 压缩（`gltfpack`）、导出 `maxTextureSize` 上限。

---

## 6. 关联

- 交付快照：[01-85-glb-into-game-real-model-milestone.md](01-85-glb-into-game-real-model-milestone.md)
- 调研：[research/threejs-pipeline/threejs-gltf-best-practices.md](../../research/threejs-pipeline/threejs-gltf-best-practices.md)
- 任务：[tasks-master.md](../../tasks-master.md)（L-18 🟡 IN PROGRESS）
