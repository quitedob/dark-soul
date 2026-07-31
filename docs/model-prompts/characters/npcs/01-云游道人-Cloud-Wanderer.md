---
名称: 云游道人（Cloud Wanderer）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.85m(略高于玩家)
源文档: ../story/main-story.md
---

## 一句话概述

Ch.1 起出现的引导 NPC,昔日九位铸魂者之一(云游),曾逆转灵魂回流导致五方碎裂;以云游道人形象在烬龛处指引玩家、讲解世界与战斗,并伴行至 Ch.5 烬海岸作最后见证。

## 视觉描述

- **体型/比例:** 清瘦老道、身高中等偏上,微驼却挺拔,白须长垂,剪影飘逸带仙气。
- **服装/甲胄:** 风尘仆仆的灰色云游道袍(云纹刺绣,下摆磨旧)、束发道髻木簪、肩搭褡裢。
- **武器/道具:** 鹤头拐杖(鹤首杖头,杖身有细碎烬火纹)、腰间葫芦 + 云纹布袋。
- **标志性特征:** 眉目间透出岁月与悔意;衣角偶有缥缈烬火辉光(昔日铸魂者余辉);鹤杖剪影极具辨识度。
- **配色:** 主色灰袍 + 暗金云纹,辉光烬火橙红(克制的微光)。
- **姿态参考:** 站姿拄杖挺立、目光投向远方,引导时抬手示意。

## 图片生成提示词

```
Cloud Wanderer, full body, front view, standing, elderly daoist sage with long white beard in weathered gray travel robe with cloud embroidery, tall crane-headed walking staff, gourd, faint ember glow, ash gray and gold with ember-orange accents, worn cloth and wood materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~3k(NPC 非战斗,可低于玩家)。
- **挂点/Socket:** 鹤杖手部挂点(杖头可选 `weapon_tip` 供引导光效)、对话聚焦点(头部)。
- **碰撞:** 胶囊 ~0.55m 半径 × 1.85m 高;静态 NPC 不参与战斗碰撞。
- **贴图:** 2K Base/Normal/Roughness;烬火微光用弱 Emission(区别于玩家)。
- **动画/骨骼:** 人形骨架;需站立拄杖/抬手示意/行走(跟随剧情转场)基础姿态。

## 出处

- 设计文档:`docs/story/main-story.md`(链接)、`docs/chapters/01-spirit-awakening/chapter-overview.md`、`docs/chapters/05-throne-of-ashes/chapter-overview.md`
- 代码挂点:`game/scripts/character_meshes.gd`(NPC 复用玩家骨架挂点)
