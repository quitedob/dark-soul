---
名称: 狐火灯妖（Foxfire Lantern Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 直径约 0.9m 的悬浮纸灯笼
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章狐嫁道的妖类敌人,由狐火点亮的漂浮纸灯笼,沿固定路线在狐嫁道中漂浮。HP 50、速度 2.0(漂浮),被近身时爆发 3m 火圈,建议远程或水系法术处理。

## 视觉描述

- **体型/比例:** 直径约 0.9m 的纸灯笼球体,下方垂挂穗子,剪影是"悬浮发光灯笼"。
- **服装/甲胄:** 无甲胄;灯笼身为红色宣纸,隐约透出内部狐火。
- **武器/道具:** 无手持武器,攻击为爆发火圈。
- **标志性特征:** 内部青白狐火明灭,纸面映出狐狸剪影纹样;顶端飘出细小火苗。
- **配色:** 绯红灯笼纸 + 青白狐火 + 烬火橙红余焰。
- **姿态参考:** 静止悬浮,以自身为圆心爆发;漂浮时需轻微晃动。

## 图片生成提示词

```
Foxfire Lantern Spirit, full body, front view, floating, glowing paper lantern lit by cyan foxfire flame, red silk lantern with fox silhouette pattern, foxfire wisps, floating tassels, crimson paper and cyan flame palette with ember glow, translucent paper and flame materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3k tris / LOD1 ~1.5k;灯笼低模,内部火用粒子或自发光球体。
- **挂点/Socket:** 无武器;爆发火圈 VFX 挂 `fire_burst` 空节点;顶部可挂悬浮吊点。
- **碰撞:** 小球碰撞(SphereShape3D,半径 0.45)。
- **贴图:** 2K,Alpha 半透明纸面;内部狐火用 Emission,顶部余焰粒子用 Additive。
- **动画/骨骼:** 约 6 根骨骼(仅悬挂摆动);漂浮路线由 AI 控制,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
