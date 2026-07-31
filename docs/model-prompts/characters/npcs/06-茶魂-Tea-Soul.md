---
名称: 茶魂（Tea Soul）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.7m(略矮于玩家的佝偻老者,半透明)
源文档: ../chapters/03-jade-veil/chapter-supplement.md, ../story/main-story.md
---

## 一句话概述

桥头茶摊的佝偻老魂,半透明的"断桥唯一暖意";在支线「桥头的供茶」中被悼念的怨魂诬为害死年轻人的罪人,月圆封魂仪式上由玩家证伪而获救,或随众怒被牺牲。

## 视觉描述

- **体型/比例:** 佝偻老者形,约 1.7m 略矮于玩家;身形瘦小半透明,剪影如拢在热气里的老茶贩。
- **服装/甲胄:** 洗旧发灰的褐灰布衫(老茶贩装束),袖口磨损,腰间系粗布围裙。
- **武器/道具:** 一手提着长嘴铜壶,另一手捧一只带豁口的瓷茶杯。
- **标志性特征:** 全身半透明,自内透出温琥珀的茶光与袅袅蒸汽——断桥上唯一温暖的存在,与四周冷蓝的悼念怨魂形成冷暖对峙;眼含善意、皱纹深刻。
- **配色:** 主色茶褐 + 灰,辉光温琥珀茶光,辅以玉青月白微光。
- **姿态参考:** 躬身立定、两手护茶,微微抬头相询(迎客姿态);封魂仪式被缚时双臂垂落。

## 图片生成提示词

```
Tea Soul, full body, front view, standing, a hunched kindly old translucent spirit woman with a weathered gentle face, worn grey-brown cloth robe of an old tea seller, long-spout copper teapot in one hand, chipped ceramic cup in the other, warm amber tea-glow shining from within her translucent body with faint steam rising, contrasting the cold blue moonlight of the mourning crowd around, tea-brown and grey with warm amber glow and jade-moonlight accents, translucent cloth and warm steam materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2.5k;长嘴铜壶与茶杯为独立低模件。
- **挂点/Socket:** 右手长嘴铜壶挂点、左手茶杯挂点、对话聚焦点(头部)、封魂仪式被缚时的手臂动画锚点。
- **碰撞:** 非战斗 NPC,可无实体碰撞或用淡胶囊;站位于断桥茶摊,供茶互动时靠近触发。
- **贴图:** 2K Base/Normal/Roughness;茶光用 Emission + 半透明,蒸汽用半透明粒子;温琥珀辉光与冷月光的冷暖对比在漫反射里拉开。
- **动画/骨骼:** 简化人形骨架;需躬身迎客/护茶/低头/被缚垂手循环;蒸汽可加顶点或粒子。

## 出处

- 设计文档:`docs/chapters/03-jade-veil/chapter-supplement.md`(支线 4 · 桥头的供茶)、`docs/story/main-story.md`
- 代码挂点:`game/scripts/character_meshes.gd`(NPC 复用玩家骨架挂点)、`game/scripts/story/dialogue_runner.gd`(茶魂对白,待建)
