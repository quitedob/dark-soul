---
名称: 烬龛 (Ember Shrine)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 高 ~2.2m,底座 ~1.5m(玩家 1.8m)
源文档: ../systems/level-design-patterns.md, ../game-design.md
---

## 一句话概述

> 类魂篝火式存档点:激活后设定复活点、回满血精、刷新普通敌人,并提供"生命锻造"(花烬提升最大 HP)与铁心锻造入口。由汉式石龛、青铜香台与一簇不熄的烬火构成。

## 视觉描述

- **体型/比例:** 矮石龛(高约 1.2m)+ 龛顶上升的烬火柱(总高约 2.2m),前置一个小型石供台与香炉。
- **材质:** 风化灰石、青铜托盘、釉面香炉;烬火为自发光(Emission),青烟为半透明粒子。
- **标志性特征:** 一簇稳定的橙红烬火在龛顶缓缓升腾,火星上浮;香台一缕青烟袅袅,远处剪影即可辨认。
- **配色:** 冷灰石 + 烬火橙红辉光 + 微蓝青烟。
- **姿态参考:** 静态地标,无骨骼;火焰部分可循环浮动。

## 图片生成提示词

```
A weathered Han-style stone shrine with a small arched niche and a low offering platform, a steady orange ember flame rising from a bronze tray on top, glowing sparks drifting upward, a small ceramic incense burner with a thin blue smoke wisp, weathered grey stone with moss in the cracks, carved flame motifs,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~1.5k tris;LOD1 ~700 tris。
- **挂点:** `FlameSocket`(烬火粒子)、`InteractPoint`(交互点)、`RespawnAnchor`(复活锚点)。
- **碰撞:** 底座盒碰撞;火焰区小型触发体。
- **贴图:** 2K Base/Normal/Roughness;火焰与火星用 Emission 叠加。
- **动画:** 火焰可选循环旋转/浮动;无需骨骼。

## 出处

- 设计文档:`docs/game-design.md`(烬龛/存档/生命锻造)、`docs/systems/level-design-patterns.md`(烬龛放置规则)
- 代码挂点:`game/scripts/`(存档交互,待建)
