---
名称: 桥头供茶（Bridge Tea Offering）
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 0.12m(小瓷杯)
源文档: ../chapters/03-jade-veil/chapter-supplement.md, ../story/chapter-bridge-map.md
---

## 一句话概述

> 支线「桥头的供茶」的触发道具:断桥桥栏上一杯仍温热的瓷供茶——崩坏的幻境里不应存在的暖意。触碰即回放一段他人的记忆(烬片携带),并引出桥头悼念与月圆封魂仪式。

## 视觉描述

- **体型/比例:** 一掌可握的小瓷杯,高约 0.12m;置于断桥石栏顶面,杯身微倾朝桥外。
- **服装/甲胄:** 风化粗陶/青白瓷胎,杯沿有细微磕碰与茶渍;整体如尘世旧物。
- **武器/道具:** 杯内一盏清茶,热气袅袅。
- **标志性特征:** 茶面自内透出温琥珀烬光,是冰冷月光世界里唯一温热之物;周围散落几片苍白花瓣与冷蓝烬灰(悼念者的供品)。
- **配色:** 青灰陶 + 温琥珀茶光辉光,点缀冷蓝月白花瓣与烬灰。
- **姿态参考:** 静态单物,无骨骼;蒸汽为循环粒子。

## 图片生成提示词

```
A single small weathered ceramic cup of tea on a stone bridge railing, faint steam rising, soft amber ember glow from within, a few pale flower petals and ashes around it, cold moonlight, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~400 tris;单杯 + 茶面,极低面数小道具。
- **挂点/Socket:** `InteractPoint`(触碰触发记忆回放)、`SteamPoint`(蒸汽粒子)。
- **碰撞:** 杯身小型盒碰撞;置于断桥石栏,可被触碰/拾取触发支线。
- **贴图:** 1K Base/Normal/Roughness;茶面辉光用 Emission(温琥珀);花瓣与烬灰用地面贴花。
- **动画/骨骼:** 无需骨骼;蒸汽循环粒子;触碰后杯光渐隐(支线推进)。

## 出处

- 设计文档:`docs/chapters/03-jade-veil/chapter-supplement.md`(支线 4 · 桥头的供茶,触发条件)、`docs/story/chapter-bridge-map.md`
- 代码挂点:`game/scripts/world/`(供茶交互与记忆回放触发,待建)
