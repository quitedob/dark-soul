# 全 GLB 可靠性校验(three.js 逐模型渲染 + 多子代理对抗复核)—— 已验证

日期:2026-08-22
主题:把 `game/assets/models/` 下全部 88 个 GLB 用 chrome-devtools + three.js 逐模型渲染截图,再用 18 个子代理逐 5 模型校验 + 3 个对抗性子代理"反驳 + 要证据",最终确认"模型可靠、可动、能真正进游戏"。

> 状态:全部为**已验证**结论。所有截图位于 `screenshot/2026-08-22/`(88 张 `NN_category_name.png` + `manifest.json` + 4 张 `recheck_*` 近景复核图)。

## 1. 资产盘点(实证)

- `game/assets/models/` 下共 **88 个 GLB**;分类分布:bosses 8、characters 20(8 职业 + 5 召唤 + 7 NPC)、enemies 32、equipment 5、props 8、weapons 13、player 1、enemy 1。
- **仅 2 个 GLB 带骨骼/动画** :`player/mannyquin.glb`(玩家身体,58 骨)与 `enemy/minnyquinn.glb`(敌人模板,58 骨)。grep `"animations"` 证实;其余 86 个为纯静态网格。
- 两具骨骼 GLB 各只有 1 支 clip = **绑定姿态**(`Armature|mixamo_com|Layer0_godot_rig`,约 0.04s)。真正 locomotion 来自玩家动画桥 `combat/player_animation_bridge.gd` 注入的 `mannyquin_lib.tres`(OAL 重定向)而非 GLB 自带 clip。

## 2. 登记一致性(0 悬空,6 未登记)

用脚本交叉核对 `core/real_model_resolver.gd` 的 `REGISTRY`(115 条)与磁盘 88 个 GLB:
- **82 个登记路径全部存在于磁盘,0 悬空** —— 解析器路径不会因缺文件而失败。
- **6 个未登记** :
  - `enemy/minnyquinn.glb` —— 仅被导出/重定向工具引用(`tools/export_minnyquinn_strafe_back.gd`、`tools/retarget_oal_to_mannyquin.gd`)作为**动画真值源**,非局内敌人身体;属设计用途,非缺陷。
  - `equipment/01-LightArmor` … `equipment/05-SoulVessels`(5 个)—— 在 `data/motion/profiles_classes_weapons_props.gd:191-225` 有动效档案(按 resolver id 键控),但**没有任何消费方调用 `try_instance("equipment/…")`**。装备目前是纯数值(hand_equipment.gd 权重/武器 id),不渲染 3D 装备层 → 这 5 个属**未接线的未来内容**,加登记条目本身不会渲染(缺消费方),不作为可靠性缺陷。

## 3. 校验流程(子代理 + 对抗)

1. **侦察**:2 个 Explore 子代理分别扫 `docs/` 与 `game/scripts/`,确认管线位置(真实模型解析器 / 动画桥 / BodyYaw 朝向 / 武器 pivot 模型空间 rest)。
2. **逐模型渲染**:新建 `build/all-models/` three.js 查看器(port 8769),服务 `game/assets/models/` 全部 GLB;`window.runBatch()` 逐模型加载 + `canvas.toDataURL()` POST `/capture` 落盘到 `screenshot/2026-08-22/`。**88/88 全部成功加载,0 浏览器加载失败**。
3. **Wave1 校验**:18 个 VLM 校验子代理,每代理 5 个模型,Read 其截图判定 `OK/SUSPECT/BROKEN` → **85 OK / 3 SUSPECT**。
4. **Wave2 对抗复核**("反驳 + 要证据"):3 个对抗性子代理独立重读高风险样本,质疑 Wave1 的 OK,并复核 3 个 SUSPECT。结果:
   - `[56] Inverted-Guardian`、`[57] Ember-Bat`、`[66] mannyquin`(玩家身体)3 个 SUSPECT **经 `window.focus()` 近景复核决议为 RESOLVED** —— 全部为默认广角 + 自动旋转取景导致"小/细/角度不佳"的**取景伪影**,非模型缺陷;mannyquin 近景为完整直立方 biped + 蓝色 SkeletonHelper 骨架线框。
   - `[51] Alchemy-Fallen-Immortal` 被 Wave2 翻转为 CONFLICT(默认图过小/抽象)→ 近景复核决议为 **OK**:是"炼丹鼎中的陨落仙人"风格化模型(暗色鼎身 + 薄荷青光角 + 金珠,立在底环上,贴地、材质正常、轮廓完密),非塌缩。
- **终态:88/88 全部可靠渲染**。唯一有意悬浮:`[25] RebirthLotus`(空中灵体,设计如此)。若干模型在默认截图"偏小/偏暗/抽象"属取景/打光产物,已用近景排除,非几何缺陷。

## 4. 进游戏佐证(引擎层)

- `godot --headless --path game --editor --quit`:**EXIT=0**,无 GDScript 解析/加载期类型错误(结束的 ObjectDB/resources-in-use 为编辑器关闭常态)。
- `tests/smoke/real_model_contract_test.gd` → `REAL_MODEL_CONTRACTS_OK`(解析器实例化真实模型正确)。
- `tests/smoke/player_weapon_grip_contract.gd` → `ASHEN_PLAYER_WEAPON_GRIP_CONTRACTS_OK`(mannyquin 身体 + 武器 pivot 落在 `DEF-hand.R` 世界骨位,朝向一致)—— 证明"武器在手 + 朝向正确"这一"可动/可用"核心路径在工作。

## 5. 可复用工具(build/all-models/)

- `server.mjs`(port 8769):枚举 `game/assets/models/` 全部 GLB → `/game-models/list.json`;serves `/game-models/<rel>` GLB + `/capture`(接收前端 canvas PNG 落盘)。
- `viewer.mjs`:`window.goTo(i)` / `window.goNext()` / `window.runBatch()`(逐模型加载+截图)/ `window.focus()`(受控近景,关闭自动旋转)/ `window.captureNow()`。importmap 复用 `build/glb-models/node_modules/three`。
- 用法:`node build/all-models/server.mjs` → 浏览器 `http://localhost:8769/?i=0`。

## 6. 结论

- **可靠性**:88/88 GLB 加载 + 渲染正常;82 登记路径 0 悬空。
- **可动**:2 具 58 骨骼 biped(玩家身体 + 敌人模板);玩家体实际动画走重定向库;武器握持契约通过。
- **进游戏**:脚本解析干净 + 解析器契约 + 握持契约全绿。
- **遗留(非缺陷)**:5 个 equipment GLB 为未接线未来内容(有动效档案、无渲染消费方);minnyquinn 为动画真值源。均不阻塞"可靠 + 可用"。
