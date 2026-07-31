---
名称: 烽火守魂（Beacon Keeper Wraith）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的人形火焰魂(半悬浮)
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第二章烽火台的鬼类敌人,生前是值守烽火台的士兵,数百年凝视火焰后其本质已与火融合。HP 60、速度 2.0,保持距离投掷火球(3s 冷却),被接近就瞬移到另一座烽火台。

## 视觉描述

- **体型/比例:** 约 1.8m 的人形火焰魂,身形以燃烧的游魂为底,轻微悬浮,剪影是"人形燃烧的烽火"。
- **服装/甲胄:** 残破的守军甲胄轮廓,但大半被翻腾的火焰吞没,甲片如炭般发红。
- **武器/道具:** 双手托举/凝聚一团炽热火球,作为投掷弹。
- **标志性特征:** 全身裹着高耸的烬火橙红烈焰,顶端拖出火苗与烟柱;眼窝两点纯白炽光。
- **配色:** 燃烧橙红 + 焦黑 + 金星飞屑。
- **姿态参考:** 双手前托火球、半悬浮的投射姿态;瞬移时需全身短暂化为一团火。

## 图片生成提示词

```
Beacon Keeper Wraith, full body, front view, floating, spectral soldier wreathed in roaring beacon fire, body of living flame, ember-orange and gold fire tendrils, rising smoke wisps, ball of fire in hand, ash black and burning orange palette, flame and smoke materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~2.5k;火焰可作低模壳+顶点动画/粒子,VFX 主用粒子系统。
- **挂点/Socket:** 右手 `weapon_tip`(火球投射点),`ExecutionAnchor`(处决锚点)设胸腔。
- **碰撞:** 小胶囊(CapsuleShape3D,半径 0.35,高 1.7);火焰本身无碰撞。
- **贴图:** 2K,Alpha 半透明火焰;Emission 强,受 `RangedAmbushBehavior` 的瞬移节奏控制。
- **动画/骨骼:** 约 16 根骨骼 + 火焰 shader 参数;重点是投射与"化火瞬移"两种状态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/02-blood-iron/chapter-overview.md`、`../chapters/02-blood-iron/chapter-supplement.md`
- 代码挂点:`game/scripts/combat/chapter_2_enemy_factory.gd`
