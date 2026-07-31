---
名称: 书精（Book Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 0.4m,书本大小
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

精类小怪,4-3 藏经阁的活书,书页如翼在空中群飞。AI 4–6 只成群袭击,每击偷取玩家一件消耗品(击杀返还);血量 30、伤害 10、机动 7.0,火属 +50%(纸怕火)。

## 视觉描述

- **体型/比例:** 非人形;一本展开的线装古书,约 0.4m,书页展开如蝴蝶/飞蛾双翼。
- **服装/甲胄:** 无服装;书脊为焦木/兽皮,书页泛黄脆裂,夹着几张金色符页。
- **武器/道具:** 无手持物;翻动的书页边缘即是攻击部位,飞行时页缘带锋。
- **标志性特征:** 书页如翼扑扇,飘落细碎纸屑;夹缝透出幽蓝经文荧光与烬火橙点。
- **配色:** 泛黄宣纸 + 焦黑书脊,辉光幽蓝经文;整只是"燃烧图书馆"的缩影。
- **姿态参考:** 悬停展页、微微上下浮动;飞行轨迹轻快、不可预测。

## 图片生成提示词

```
Book Spirit, full body, front view, hovering, small ancient tome with splayed open pages fluttering like wings, gold-thread binding and frayed paper edges, glowing blue scripture glyphs drifting from pages, ember-orange spark at spine, aged parchment yellow and faded ink black color palette, paper and cloth materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 2.5k tris / LOD1 1.2k;书页可用弯曲面片 + 双向翻页动画,不逐页建模。
- **挂点/Socket:** 书脊 `weapon_tip`(偷取判定/吸附特效);页缘 `page_tip` 若干供翻页驱动。
- **碰撞:** 盒碰撞(0.3m × 0.15m × 0.4m),小目标利于群战。
- **贴图:** 1K Base/Normal/Roughness;经文荧光用 Emission;纸面用卷曲 Normal 表现脆裂。
- **动画/骨骼:** 以书脊为根的轻骨架(书页 4–6 片);飞行动画=扑翅 + 自转,替换占位时保持 `weapon_tip`。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 书精)、`../chapters/04-celestial-fall/chapter-overview.md`(4-3 藏经阁)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` 命名
