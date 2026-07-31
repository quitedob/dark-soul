---
名称: 刑具精怪（Torture Device Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 3m 高的直立铁处刑构造体
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第二章俘虏营的"精"类敌人,由铁处女与刑架吸收了数百年痛苦与烬火之力后活物化。HP 200、无法移动,每 6s 脉冲 AoE,伸出的铁链爪在 5m 内会抓拖玩家靠近并造成伤害。

## 视觉描述

- **体型/比例:** 约 3m 高的直立铁处刑构造体,窄高的剪影"如一架站立的人形刑架"。
- **服装/甲胄:** 通体为锈蚀铁板拼成的"铁处女"外壳,正面有带钉的门缝,肩部伸出铁质刑架横梁。
- **武器/道具:** 两侧手臂化为缠绕的铁链,末端是钩爪;腔内可见被挤压的受刑者残魂。
- **标志性特征:** 正面钉门/胸口缝隙中透出暗红烬火辉光;链爪随呼吸伸缩。
- **配色:** 铁锈红 + 焦黑 + 烬火暗红内光。
- **姿态参考:** 静止直立;攻击由链爪/脉冲体光体现,非攻击时保持静态结构。

## 图片生成提示词

```
Torture Device Spirit, full body, front view, standing, animated iron maiden torture engine, rusted iron body with internal spikes, chain-wrapped claw arms, embedded tormented souls, blood rust and cinder black palette, red ember glow from within, rusted iron materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;结构件(门、横梁、链)可分块便于 Blender 拆件。
- **挂点/Socket:** 左右链爪端 `chain_tip_L/R`(特效与抓取),`ExecutionAnchor`(处决锚点)设胸口;`GrabProfile` 捕获形状设于链爪攻击半径。
- **碰撞:** 静止:盒碰撞(BoxShape3D,约 1.2×3×0.9);链爪单独动态碰撞。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;胸口内光用 Emission,锈蚀用 Roughness 变化。
- **动画/骨骼:** 约 20 根骨骼,以链关节与爪为动画主体;本体静止,靠脉冲光/链爪表达攻击,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/02-blood-iron/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_2_enemy_factory.gd`
