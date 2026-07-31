---
名称: 守炉灵·巨阙（Furnace-Keeper JuQue）
类别: Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 8m（约玩家 4.4 倍，环形内廷 30m）
源文档: ../bestiary/bosses-master.md、../chapters/01-spirit-awakening/bosses.md、../chapters/01-spirit-awakening/chapter-overview.md
---

## 一句话概述

Ch.1 灵墟·觉醒 教学 Boss，精（活物构造）：2 阶段（尽忠守卫 100-60% → 炉心过载 60-0%）。环形内廷 30m 有 4 石柱与 4 守望点，P1 巡逻规律、P2 过载狂暴。击败后选择「释放职责」或「保留核心」（`ch1_guardian_fate`），魂器：守炉之核。

## 视觉描述

- **体型/比例:** 8m 巨大人形石构造体，肩如庙顶、胸为封闭炉门、头为雕石面具+单只烬眼，四肢如粗石柱，建筑感剪影。
- **服装/甲胄:** 交错咬合的石板/石甲板覆盖全身，接缝透出橙色烬光；肩甲与护胫带庙宇檐脊造型。
- **武器/道具:** 巨阙门刀（Gate Blade）——形如庙门、宽如门厚如柱的巨刃；P2 刀刃燃起烬火。
- **标志性特征:** 胸口可开合的炉门（P2 打开喷炉息）、石面具单烬眼、肩如殿顶；步行时石磨石声。
- **配色:** 冷灰岩色+蚀锈青铜；烬火橙红辉光（接缝、炉门、烬眼）。
- **姿态参考:** 站立巡逻/双手持门刀。弱点击破锚点：双膝关节（破膝 40 架势）+胸口炉心（P2 过载核心）。

## 图片生成提示词

> Phase 1 — Dutiful Guardian（尽忠守卫）

```
Furnace-Keeper Giant, full body, front view, standing, colossal 8-meter stone construct, interlocking architectural stone plates with glowing ember seams, temple-roof shoulders, carved stone mask head with one burning ember eye, sealed furnace-door chest, colossal temple-gate blade wide as a door, ash gray stone and rusted bronze palette, worn carved stone material, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 2 — Furnace Overload（炉心过载）

```
Furnace-Keeper Giant, full body, front view, standing aggressive, colossal 8-meter stone construct overclocked, cracked stone plates glowing hotter, chest furnace door thrown open spewing Ember-fire, single eye-ember burning white-hot, giant temple-gate blade ignited with Ember-flame, ember-orange and molten gold palette, cracked glowing stone material, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 巨大 Boss 可放宽：LOD0 ~12k tris / LOD1 ~6k / LOD2 ~3k。
- **挂点/Socket:** `weapon_tip`（门刀刀尖特效）、`ExecutionAnchor`（处决/核心破坏）、`GrabProfile`（抓投捕获形状）、双手挂点、炉门开合节点 `FurnaceDoor`。
- **弱点击破锚点:** 双膝关节 `knee_joint_l/r`（破膝 40 架势、处决触发）、胸口炉心 `furnace_core`（P2 过载核心直接打击）。
- **碰撞:** Boss 独立 `CollisionShape3D`：躯干大胶囊+分离下肢；门刀可用独立碰撞或 `Area3D`。
- **贴图:** 2K；Base/Normal/Roughness/Metalness；接缝、炉门、烬眼用 Emission 做烬火辉光（P2 增亮可走强度动画）。
- **骨骼/动画:** 人形骨架，命名与 `character_meshes.gd` 保持；巡逻步、门刀三连/横扫、踏地、开胸炉息、P2 加速与随机化。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/01-spirit-awakening/bosses.md`](../chapters/01-spirit-awakening/bosses.md)、[`../chapters/01-spirit-awakening/chapter-overview.md`](../chapters/01-spirit-awakening/chapter-overview.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
