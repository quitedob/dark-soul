---
名称: 失落回声 (Lost Echo)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 直径 ~0.4m 的悬浮微光球(玩家 1.8m)
源文档: ../game-design.md
---

## 一句话概述

> 死亡掉落拾取物:玩家死亡时携带的全部烬会在死亡地点留下一团微光余烬,回到此处触碰即取回;再次死亡则替换旧回声。是死亡-回收循环的核心视觉锚点。

## 视觉描述

- **体型/比例:** 一团悬浮在腰部高度(约 1.3m)的余烬簇,直径约 0.4m。
- **材质:** 半透明自发光核心 + 粒子;Emission 为主。
- **标志性特征:** 持续上浮的橙红火星螺旋,中央一枚亮暖光核,地面伴随一道浅色光柱。
- **配色:** 烬橙 + 暖金 + 灰烬微粒灰。
- **姿态参考:** 无骨骼,悬浮静态 + 循环粒子。

## 图片生成提示词

```
A small floating cluster of glowing embers, a spiral of rising orange sparks with a bright warm core, soft radiant light haloing the drifting cinders, tiny ash particles swirling around it, faint golden glow, translucent luminous effect,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~400 tris(以粒子/自发光表现为主,几何极简)。
- **挂点:** `EchoCollect`(拾取判定)、`GlowSocket`(光柱)。
- **碰撞:** 球形触发体。
- **贴图:** 1K Base + Emission;透明度可置于材质透明层。
- **动画:** 旋转 + 上下浮动循环;拾取播放消散动画。

## 出处

- 设计文档:`docs/game-design.md`(死亡掉落与失落回声机制)
- 代码挂点:`game/scripts/`(死亡回收循环,待建)
