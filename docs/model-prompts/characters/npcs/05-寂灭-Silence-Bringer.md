---
名称: 寂灭（Silence Bringer）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 3.0m(巨体守门者,高于玩家)
源文档: ../story/main-story.md
---

## 一句话概述

Ch.5 九铸魂者之墓的守门古神,幸存铸魂者之一(寂灭),认可烛阴的衰败诊断却拒绝强制静止;于烬座入口化作沉默的守门者,是最终考验——玩家可选择战斗或献上证词通过。

## 视觉描述

- **体型/比例:** 高大无言的巨体古神,身形如山峰般静立,宽袍垂地,剪影伟岸静止。
- **服装/甲胄:** 铸魂者祭仪长袍(灰白圣袍,缀星纹,边缘朽败),肩披厚重披帛,头戴垂帘冠。
- **武器/道具:** 双手拄一柄巨权杖(杖头为闭合的轮回环);身侧悬垂半断的星辉锁链。
- **标志性特征:** 双目闭合、面容古井无波;垂帘冠遮目;周身笼着静谧的星光蓝黑,唯杖环烬火微亮。
- **配色:** 主色烬灰 + 星辉蓝黑,辉光烬火橙红(克制的守门灯) + 微星芒。
- **姿态参考:** 端然静立如雕塑,双掌叠于杖顶,守门时纹丝不动。

## 图片生成提示词

```
Silence Bringer, full body, front view, standing, towering silent ancient guardian in ceremonial soul-forger robes with closed eyes and motionless posture, spectral chains, weathered ancient face, faint starlight and ember glow, ash gray and starless black with ember-orange accents, stone and tattered silk materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~6k tris / LOD1 ~3k;巨权杖为独立道具件。
- **挂点/Socket:** 杖柄手部挂点 + 杖环 `weapon_tip`(守门灯特效)、`ExecutionAnchor`(若触发战斗处决)、对话聚焦点(头部)。
- **碰撞:** 独立胶囊 ~1.0m 半径 × 3.0m 高;战斗形态可换独立 `CollisionShape3D`。
- **贴图:** 2K Base/Normal/Roughness/Metalness;星纹与杖环用 Emission;圣袍用高 Roughness 织物 + 朽败细节。
- **动画/骨骼:** 放大版人形骨架;以静立/举杖/放行三态为主,战斗时启用战斗骨架。

## 出处

- 设计文档:`docs/story/main-story.md`(链接)、`docs/chapters/05-throne-of-ashes/chapter-overview.md`(九铸魂者之墓)
- 代码挂点:`game/scripts/character_meshes.gd`(NPC 复用玩家骨架挂点)
