---
名称: 盲钟·听烬（Blind Bell · Hearer）
类别: Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 5m（悬于塔心，无目钟塔直径 25m）
源文档: ../bestiary/bosses-master.md、../bestiary/boss-blind-bell-hearer.md
---

## 一句话概述

隐藏可选 Boss，精（器物成精）：一口被"最后一声丧钟"惊醒的青铜编钟，全盲、以声捕猎亡魂，并不想吃灵魂只想再听一次活人心跳。2 阶段（听者 100-55% → 聋世 55-0%）；弱点击破锚点 `bell_mouth`，魂器：听烬之心。独立定位，不承接任何章节主线、不写任何章节命运旗标。

## 视觉描述

- **体型/比例:** 高约 5m 的青铜编钟，由锈铁链悬于塔心，非行走而是在链上晃动；钟身即整体，剪影如一口悬空的巨钟。
- **服装/甲胄:** 无甲胄——钟身是本体：青铜锈绿、旧铜包浆，全身布满蚀锈与磨损；"头"是钟顶的裂口音孔，"双臂"是两根铁链悬着的钟舌（cast-iron）。
- **武器/道具:** 两根铁链悬着的**钟舌**（cast-iron bell tongues），既是手臂也是武器，可挥摆横扫、缠绕拖拽。
- **标志性特征:** 无目、无脸——钟面即钟口，一个空洞的黑暗开口（聆听的耳朵）；青铜绿锈间裂开烬火色缝隙，内里游动着被吞亡魂的余烬；钟口内部透出微弱烬光。听到声源时整口钟向声音方向倾斜、顿住，像侧耳倾听。
- **配色:** 青铜锈绿 + 烬火橙红缝隙 + 钟口内部微弱烬光（内部烬光），锈链暗铁色，P1 叠冷月光、P2 转近全黑。
- **姿态参考:** 悬链晃动、向声源侧耳倾听（倾斜顿住）；扑袭时前倾、钟舌横扫。弱点击破锚点：钟口音孔 `bell_mouth`。

## 图片生成提示词

> Phase 1 — The Listener（听者）

```
A huge hanging bronze chime bell suspended on a rusted chain, tilted as if listening, cracked patina seams glowing with ember-orange, an empty dark bell-mouth at the bottom with a faint ember light inside, two cast-iron bell-tongues hanging on chains like arms, cold moonlight slanting through arrow-slit windows, aged bronze and rust palette, bronze material, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 2 — The Deafening（聋世）

```
The same bell in near-total darkness, arrow-slit shutters closed, only the bell-mouth's ember glow and its silhouette visible, bell-tongues swinging aggressively, ember seams burning brighter, deep shadow and a single amber light source, darker palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** Boss：LOD0 ~12k tris / LOD1 ~6k / LOD2 ~3k。
- **挂点/Socket:** `bell_hang`（钟顶链条锚点）、`ExecutionAnchor`（处决/静默硬直触发）、弱点击破锚点 `bell_mouth`（钟口音孔）、`bell_tongue_l/r`（两根钟舌）。
- **碰撞:** Boss 独立 `CollisionShape3D`：主钟大圆柱/胶囊 + 两根钟舌独立 `Area3D`。
- **贴图:** 2K 青铜 Base/Normal/Roughness/Metalness；接缝与钟口内部用 Emission 做烬光（P2 增亮可走强度动画）。
- **动画/骨骼:** 非人形——链条摆动、钟身侧耳倾听、钟舌挥摆横扫、扑袭前倾；P2 黑暗下仅剪影；命名保持 `enemy_factory.gd`。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md) § Boss Classification（Optional Boss 槽位）、[`../bestiary/boss-blind-bell-hearer.md`](../bestiary/boss-blind-bell-hearer.md)
- 代码挂点（待实现）：`game/scripts/combat/enemy_factory.gd`（`body_type` `hanging_bell`）、`game/scripts/combat/data/boss_execution_catalog.gd`（无 `story_flag`，弱点击破锚点 `bell_mouth`）
