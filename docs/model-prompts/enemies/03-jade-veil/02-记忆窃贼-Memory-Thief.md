---
名称: 记忆窃贼（Memory Thief）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的驼背暗影人形
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章记忆回廊的鬼类敌人,以记忆为食的暗影窃忆者,从掩体后偷袭。HP 55、速度 4.5,每次命中同时吸取 8 点 Focus;玩家 Focus 归零时它会强化(+50% 伤害)。

## 视觉描述

- **体型/比例:** 约 1.8m 的驼背暗影人形,身形细长、肢体异常,剪影是"佝偻伸手的斗篷黑影"。
- **服装/甲胄:** 无实体甲胄,披着破烂的黑斗篷状暗影,边缘如烟如雾。
- **武器/道具:** 无武器,攻击为长而纤细的抓取利爪。
- **标志性特征:** 兜帽下只有两点幽蓝鬼火;周身漂浮着被窃取的发亮记忆光球。
- **配色:** 深紫黑暗影 + 幽蓝鬼火 + 微弱的烬火橙点缀。
- **姿态参考:** 半弓身、单臂前伸的伏击姿态;背部斗篷要能飘散。

## 图片生成提示词

```
Memory Thief, full body, front view, hunched reaching stance, shadowy hooded ghost, dark wispy silhouette with long grasping fingers, floating stolen memory orbs, tattered flowing cloak, deep violet-black and ghost-blue palette with faint ember glow, shadow and mist materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~2.5k;斗篷可做低模+布料模拟或顶点动画。
- **挂点/Socket:** 右爪 `claw_tip`(命中/吸取 VFX),`ExecutionAnchor`(处决锚点)设胸腔,记忆光球挂 `memory_orb` 空节点。
- **碰撞:** 细胶囊(CapsuleShape3D,半径 0.3,高 1.7)。
- **贴图:** 2K,Alpha 半透明暗影;幽蓝鬼火与记忆光球用 Emission。
- **动画/骨骼:** 约 18 根骨骼;重点是伏击扑出与"Focus 归零强化"时的体型膨胀状态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
