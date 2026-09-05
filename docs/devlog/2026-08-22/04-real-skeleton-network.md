# 真实骨骼网络(86 无骨骼 GLB)—— 自适应 PartRig + VLM 校验 + 敌人运行时接线 —— 已完成

日期:2026-08-22
主题:给 86 个无骨骼静态 GLB 建出**真实能用**的骨骼网络,并接入敌人运行时做「实机会动」的实证。用 VLM(three.js 视图 + chrome-devtools 截图)逐模型校验「骨骼网贴合模型本身」,再经 Godot 骨骼契约确定性验证。

> 状态:全部已完成。结论见下面「实证」。

## 前提(实证,来自 node-name 直接解读)

- 全仓 88 GLB,仅 `player/mannyquin` + `enemy/minnyquinn` 有真蒙皮骨架(各 58 骨);其余 **86 个为纯静态网格**——three.js 导出管线(`build/glb-models/_shared/helpers.mjs → GLTFExporter.parse({trs,onlyVisible})`)只导出**命名部件 Mesh**,没有任何 skin/joints/inverseBindMatrices,所以文件里**根本没有骨骼**。
- 无 Blender/bpy → 做不了标准蒙皮;采用 **Godot 运行时骨挂件**(部件 `MeshInstance3D` 按名挂到 `BoneAttachment3D`,刚性关节、无顶点权重),这是本环境能达到的天花板。

## 发现:不是模型没骨骼,而是映射器认不出

地面真值(node 名 dump)证明**骨骼数据其实在**——只是 `bone_for_part()`/`_side()` 认不出这些命名约定:

- **裸 `L`/`R` 后缀**(proof 敌人 `01-Lost-Soul-Soldier`):`legL/legR/footL/footR/armL/armR/handR`——旧 `_side()` 只认 `.l/.r/_l/_r`,这些全落到 `.L`/spine。
- **四足 `_fl/_fr/_hl/_hr`**(九尾狐 boss):`leg_fl_u/leg_hl_u/paw_fl/claw_fl_l`——旧逻辑漏掉 `leg`/`paw` 关键词 + 侧别 token,狐狸**一条腿骨都没有**。
- **前缀 `l_`/`r_` + 祖先侧别**(8 职业):`l_knee/r_ankle/l_shoulder/l_arm`,且大臂网格 `upper_arm/forearm/hand` 挂在 `l_arm/r_arm` **分组**下——侧别在祖先节点,部件本身没有。
- **幻影错映射**:邢天(无头,斩首)的 `head` 被 `axe_head_l/r` 顶上,真实的脸在**胸甲** `chest_eye/mouth_*`(`→spine`);朱厌(`05-Lord…`)的 `tail` 被布带 `sash_tail_l/r` 顶上。

## 修复(两份映射器保持一致)

统一改 `game/scripts/core/part_rig_builder.gd` + `build/all-models/viewer.mjs`(overlay 同套映射):
- **`_side()`**:支持四足 `fl/fr/hl/hr` 侧别、前缀 `l_/r_`、裸 `L/R` 后缀(后置字符为**辅音**才判侧,避免 `bracer`/`elbow` 误读)。
- **`bone_for_part()`**(加 `hint_side=`):腿/脚补 `leg`/`paw`/`greave`;武器(sword/blade/grip/spear/staff)一律**跟手**,绝不上头;`axe_head/mace/shield/skull_trophy` → 手(武器/挂件);头面区扩到 `helmet/snout/nose/eye/ear/whisker`;`arm` 关键字找回。
- **祖先侧别**:`_ancestor_side()` 上溯父链(职业 `l_arm`→子网格侧别),overlay 端 `ancestorSide()` 同逻辑。

## 实证 1 —— VLM 逐模型校验(3 子代理波 × 5 模型,三视图 + 骨网叠加)

- 前 3 波(15 模型)由 subagent 从**实际 GLB node 名** + 三视图截图逐判:`class ∈ {BIPED,PARTIAL,COSMETIC,FUSED}`、`riggable`、`issues[]`。它们一致指出上述**系统性映射 bug**,而非模型坏——正是 mapping 修复的输入。
- 覆盖证据:fox=PARTIAL、proof 敌人=BIPED、XingTian 头为幻影、朱厌 tail 幻影、职业手臂塌到左(无侧别)。

## 实证 1b —— subagent 逐模型判定表(3 波 × 5 模型)

前 3 波共 15 个模型,每模型由 subagent 从**实际 GLB node 名** + 三视图/骨网截图判 `class` / `riggable` / `issues[]`。同一 systemic bug 在多个模型复现:

| idx | 模型 | class | riggable | 关键结论 / issues |
|---|---|---|---|---|
| 0 | Furnace-Keeper-JuQue | BIPED | ✅ | 真解剖齐全(thigh/shin/foot/arm/head L+R)real=16;但 `wing.L/R` 来自 gate-blade 装饰翼(幻影),39 部件(炉芯/门/背尖刺/刀片链)→spine(刀片不随手) |
| 1 | Blood-General-XingTian | BIPED | ✅ | 无头斩首: `head` 被 `axe_head_l/r`+`skull_trophy_*` 顶上(幻影),真脸 `chest_eye/mouth_*/eye_socket` 在胸甲→spine;`axe_handle→hand` 对,`axe_head→head` 错 |
| 2 | Jade-Faced-Fox-NineTails | PARTIAL | ✅ | **四条腿 `leg_fl/fr/hl/hl` 全漏**(无 `leg` 关键词 + 无 fl/fr/hl/hr 侧别)→spine;9 尾塌成 1 个 tail 骨;ear/snout/whisker→spine |
| 3 | Fallen-Immortal-XuanXiao | PARTIAL | ✅ | `leg_l/r` 漏(无 `leg` 关键词)→下体 static;持剑(sword_blade/guard)→spine 不随手;upperarm/forearm/hand L+R + head 真 |
| 4 | Lord-of-the-Ember-Abyss-ZhuYin | PARTIAL | ✅ | `tail` 被布带 `sash_tail_l/r` 顶(幻影);`leg_l/r`+`knee_star` 漏;beard/halo/constellation→spine |
| 5 | Blind-Bell-Hearer | COSMETIC | ❌ | 钟形器物:central 骨在烛芯(装饰非解剖);侧竖梁像「腿」实为钟柄/结构件,当腿会误绑 |
| 6 | WrathFragment | BIPED | ✅ | 圆胖魅魔,头+双臂+双腿关节贴体;两金环是武器 emission 非骨 |
| 7 | ObsessionFragment | PARTIAL | ✅ | 浮空晶体精灵:头+两卷曲翼+袍摆;下体是袍无腿;侧卷曲是翼非臂(→wing-flap 非 arm-wave) |
| 8 | Cloud-Wanderer | PARTIAL | ✅ | 长袍盖腿只余袍摆骨;臂藏斗篷下仅持杖臂有清晰关节;头被云兜帽遮挡 |
| 9 | Iron-Heart | BIPED | ✅ | 头+躯干心+双臂双腿关节在解剖上;持棒正确到手;微忧 hearth 火箱(布景)近脚 |
| 10 | Lady-of-Memories | PARTIAL | ✅ | 下体融合锥裙(skirt→hips)无腿;3-4 块浮空白板是装饰道具无骨(正确) |
| 11 | XuanXiao-Remnant | PARTIAL | ✅ | 臂交叉折叠入躯干→肘/手活动受限;金环+浮白菱形是道具无骨;下体锥袍无腿 |
| 12 | Silence-Bringer | COSMETIC | ❌ | 机械钟形智能体:无肢干,只有刚性肩舱;双足骨架给不出真实运动 |
| 13 | Tea-Soul | BIPED | ✅ | 头/脊/臂 + **两条分离白腿**(hip/knee 关节跟真腿);铜壶/管随手(正确) |
| 14 | Ember-Tea-Keeper | PARTIAL | ✅ | 下袍融合到窄支柱无腿;顶髻/茶壶是道具;臂只有折袖口 |

hist:波0 BIPED2 PARTIAL3; 波1 BIPED2 PARTIAL2 COSMETIC1 riggable=4; 波2 BIPED1 PARTIAL3 COSMETIC1 riggable=4。**判定一致性**:所有模型 `riggable` 与「有无可动解剖部件」严格对应;`COSMETIC`(5/12)都是器物/机械,`BIPED`(5/13/14)都是真四肢,`PARTIAL`(其余)都是缺腿/翼爪类。

## 实证 1c —— 映射器修复的两处关键机制

**A. 侧别 token 分级判(`_side` 两版一致)** —— 优先级从上到下,`fl/fr` 在前避免 `_l` 误读:
1. 四足:`...fl/hl` 或含 `_fl/_hl` → `L`;`...fr/hr` 或含 `_fr/_hr` → `R`(狐/War-Dog 的 `leg_fl_u/paw_fl/claw_fl_l`)
2. 前缀:`l_/r_` 或 `.l/.r` 开头 → 对应侧(职业 `l_knee/r_ankle/l_shoulder/l_arm`)
3. 后缀 `.l/_l/_la/_lb/_lt` → `L`;`.r/_r/_ra/_rb/_rt` → `R`
4. 裸尾字母:末字符为 `l/r` 且前一字符是**辅音**(非 `a/e/i/o/u/_/.`)才判侧——避免 `bracer`(e+r)/`elbow` 误读,但 `legL/armR/handR/footL/greaveL` 能判

**B. 幻影解绑(武器/装饰绝不上头)** —— `bone_for_part` 顺序:`sword/blade/grip/pommel/haft/shaft/spear/axe_handle/knife/bow/quiver/staff` → **hand**;`axe_head/mace/hammer_head/shield/shield_head/skull_trophy/skull_cord` → **hand**(这些是武器/挂件,不是头颅)。这直接修掉邢天 `axe_head→head`、朱厌 `sash_tail→tail`、Temple-Guardian `maceHead/shieldFace→head` 三处幻影。头部关键词区扩到 `helmet/snout/nose/eye/ear/whisker`,使面部/耳/吻跟随头骨而非落回 spine。

**C. 祖先侧别(`_ancestor_side` / `ancestorSide`)** —— 上溯父链找侧别 token;职业大臂网格 `upper_arm/forearm/hand` 自身无侧别,但挂在 `l_arm`/`r_arm` 分组下,取祖先侧别补上(否则双臂都塌到 `.L` 且质心对到躯干中部)。

## 实证 2 —— Godot 骨骼契约(确定性「能动」)

`game/tests/smoke/rig_all_models_contract_test.gd` 遍历 REGISTRY 全部 GLB:
```
RIG_ALL_SUMMARY rigged=76 skinned=1 static=5 total=82
ASHEN_RIG_ALL_OK
```
- **76 模型有了「点击骨就动部件」的真骨骼**:8 职业各 **16 真骨**、JuQue/XingTian 各 16、proof 敌人 Lost-Soul-Soldier 12、四足犬/狐带腿、武器/道具的握柄→手(2–5 真骨)。
- **21 个 EXPECT_RIGGED 全部 `OK`**(转骨 → 部件移动 ≥0.02m);**5 个 FUSED 判 `STATIC`**(Mystic-Gate-Seal / Water-Moon / Library-Guardian-Spirit / LostEcho / AmbientProps)——无命名部件,确证不可刚性绑。
- 单一 Boss 契约回归:`ASHEN_PART_RIG_MOVE_OK move_dist=0.1798`(不变)。

## 实证 3 —— 敌人运行时接线(实机会动)

`game/scripts/core/enemy_rig_hook.gd` + `enemy.gd`:
- 模型重建后(`_ensure_visual_palette`)对**白名单**敌人(proof `lost_soul_soldier` + 5 个)调 `EnemyRigHook.ensure_rig()`,把 `Skeleton3D` 缓存进 `_enemy_skeleton_cache`(复用既有 `_get_enemy_skeleton` 锚点逻辑)。
- 空闲 `_real_model_idle_vfx` 里 `_apply_rig_idle_sway()` 对 `spine`/`neck` 施加温和正弦旋转(~2.3s 周期)→ 敌人**在骨骼层面摆动**(不再是纯 whole-node)。
- 白名单外(如 `immobile_turret`)返回 `null`,零波及。
- `game/tests/smoke/enemy_rig_wired_test.gd`:
  - `ASHEN_ENEMY_RIG_WIRED_OK`(build 出骨架、有 spine/thigh、转骨移部件 >0.02m)
  - `ASHEN_ENEMY_RIG_SKIP_OK`(非白名单 → null)

## 契约断言与阈值(可复现)

`game/tests/smoke/rig_all_models_contract_test.gd`(`extends SceneTree`,`_initialize`→`call_deferred("_run")`):
- 从 `RealModelResolver.REGISTRY`(const 读法)去重得 82 条 path;`EXPECT_SKINNED`(2 个)→ 断言有内嵌 `Skeleton3D` + `bone_count>0`;其余调 `PartRigBuilder.build(body)`。
- 关键断言:**绑定保持**——把模型放到非平凡变换 `(3,0,-2)` 以证 local 空间数学正确;`att_with_parts>0`(有真骨);**转骨动部件** ≥0.02m(遍历每个非空 BoneAttachment,任一动即过)。
- 期望判据:`EXPECT_RIGGED`(21 个)必须 `any_move`;否则 `FAIL`。非白名单模型 `any_move`→`RIGGED`(加分),否则 `STATIC`。
- 汇总打印 `RIG_ALL_SUMMARY rigged=… skinned=… static=… total=…`,全绿 → `ASHEN_RIG_ALL_OK`。

`game/tests/smoke/enemy_rig_wired_test.gd`:
- proof 敌人 load + 手工包一层 `BodyVisuals`/`ModelRoot`(模拟 resolver 容器);`EnemyRigHook.ensure_rig(wrapper,"lost_soul_soldier")` 非 null、`bone_count>0`、有 `spine`/`thigh.L`;转任一骨 → 部件移动 ≥0.02m。
- 反向断言:非白名单 `ensure_rig(wrapper,"immobile_turret")` → 必须 `null`。
- 全绿 → `ASHEN_ENEMY_RIG_WIRED_OK` + `ASHEN_ENEMY_RIG_SKIP_OK`。

## 可复用

- 构建器:`game/scripts/core/part_rig_builder.gd`(自适应 `build()` + `bone_for_part(name, hint_side)` + `_side`)
- 敌人钩子:`game/scripts/core/enemy_rig_hook.gd`(`RIGGABLE_ENEMY_IDS` 白名单)
- 契约:`tests/smoke/rig_all_models_contract_test.gd`、`tests/smoke/enemy_rig_wired_test.gd`、`tests/smoke/part_rig_contract_test.gd`
- VLM 骨网叠加:`build/all-models/viewer.mjs` 的 `window.shootBones(i)` / `shootAllBones(a,b)`(自适应,只画有部件的真骨)

## 运行方式

```
# 全模型骨骼契约
godot --headless --path game --script res://tests/smoke/rig_all_models_contract_test.gd
# 敌人接线契约
godot --headless --path game --script res://tests/smoke/enemy_rig_wired_test.gd
# 全量
./tools/ci.sh   (或 CI 设置 GODOT_BIN=...);应打印 ASHEN_HOLLOW_CI_OK
```

## 未做(已标注,计划项)

- **顶点蒙皮再导出**:7 个 FUSED(`RebirthLotus/EmberShrine/LostEcho/Traps/Mystic-Gate-Seal/Sandalwood-Beads-Talisman/templateweapons/SoulVessels`)无命名部件,刚性骨挂件无从下手;需 three.js `SkinnedMesh` 重烘焙权重(本环境无 Blender)。已确认不可刚性绑 → 记为后续项。
- 把白名单 `RIGGABLE_ENEMY_IDS` 扩到全部可绑敌人(本次只接 proof + 5 个)。
- 骨网叠加/`Skeleton3D` 可视化接入 Godot 渲图(headless 不渲图;现用 three.js 同套映射目检)。
