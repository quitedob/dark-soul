---
名称: 水中月（Water Moon）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的半透明水中倒影人形
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章镜花水月亭的鬼类敌人,存在于湖面倒影世界的实体。HP 60、速度 3.0,在水面上可见但不可触碰,玩家只有站上"倒影显现"平台时才能击中它。

## 视觉描述

- **体型/比例:** 约 1.8m 的人形,由湖水倒影构成,形态扭曲晃动,剪影是"水中涟漪聚成的人形"。
- **服装/甲胄:** 无实体甲胄,只有水纹勾勒的模糊人形轮廓。
- **武器/道具:** 无手持武器,攻击为水波与捞月般的拍击。
- **标志性特征:** 通体为半透明的涟漪水面,胸前映出残缺的月影;边缘水花碎散。
- **配色:** 银蓝月光 + 水青 + 微弱烬火橙点缀。
- **姿态参考:** 悬停、双臂微张的"倒映"姿态;底部需平接水面以便贴合倒影平面。

## 图片生成提示词

```
Water Moon, full body, front view, floating, ghostly figure made of lake water reflection, translucent rippling water silhouette, lunar reflection shimmer, distorted humanoid form, silver-blue moonlight and water cyan palette, faint ember glow, liquid and mirror materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k;水面人形用半透明+波纹 Shader。
- **挂点/Socket:** `ExecutionAnchor`(处决锚点)设胸腔;底部贴合平面的水平锚点。
- **碰撞:** 仅在"倒影显现平台"上生效:胶囊(CapsuleShape3D,半径 0.35,高 1.8),其余层由碰撞层/状态控制。
- **贴图:** 2K,Alpha 半透明;水纹用 Normal+动画,月影用 Emission(银蓝)。
- **动画/骨骼:** 约 16 根骨骼;全身起伏晃动(模拟涟漪),保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
