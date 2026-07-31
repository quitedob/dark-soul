---
名称: 回音灵（Echo Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的人形战斗能量体
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章记忆回廊的"精"类敌人,由森林中残存的战斗能量凝聚而生,会学习并复刻玩家的上一个招式。HP 70、速度 3.5,观察 3s 后镜像玩家最近的攻击类型。

## 视觉描述

- **体型/比例:** 约 1.8m 的人形战斗能量体,身形由流动的残响能量构成,剪影是"持刀镜影的武士轮廓"。
- **服装/甲胄:** 无实体甲胄,只有能量勾勒出的模糊武士轮廓,边缘拖出残影尾迹。
- **武器/道具:** 手中凝聚一把能量长刀,随复刻的招式变换形态。
- **标志性特征:** 半透明能量体 + 拖曳的 afterimage(残影),胸口有一团核心能量漩涡。
- **配色:** 淡金战斗能量 + 玉青绿 + 烬火橙核心光。
- **姿态参考:** 模仿持刀的待机姿态;需能复现轻/重两种挥砍动作轮廓。

## 图片生成提示词

```
Echo Spirit, full body, front view, standing, humanoid spirit of residual combat energy, shimmering ghostly warrior with trailing afterimages, distorted mirroring sword stance, pale gold and jade green palette with ember glow, translucent energy and light materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~2.5k;残影/尾迹用粒子或 Shader 拖尾,半透明 Blend。
- **挂点/Socket:** 右手 `weapon_tip`(能量刀),`ExecutionAnchor`(处决锚点)设胸腔核心漩涡。
- **碰撞:** 胶囊(CapsuleShape3D,半径 0.35,高 1.8)。
- **贴图:** 2K,Alpha 半透明;核心与刀光用 Emission,残影用 Additive。
- **动画/骨骼:** 约 18 根骨骼;重点是轻/重两套镜像挥砍动作,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
