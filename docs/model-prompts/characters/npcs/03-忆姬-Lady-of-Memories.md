---
名称: 忆姬（Lady of Memories）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.0m(漂浮灵体,高于玩家)
源文档: ../chapters/03-jade-veil/chapter-overview.md
---

## 一句话概述

Ch.3 记忆回廊中被困于记忆苔的记录者,看守森林的真实档案;解放后证明玩家的"前世记忆"来自碎片承载的亡魂,并逐步重建玩家真正的身世(烬裔起源)。

## 视觉描述

- **体型/比例:** 缥缈女子形,身量纤细高挑,自腰部以下化作记忆苔与流光的尾迹,剪影如垂落的卷轴。
- **服装/甲胄:** 记忆苔凝成的青绿长袍,袍摆化作翻卷的发光苔浪;发丝间缀以碎页与光尘。
- **武器/道具:** 身边漂浮的青玉书简与散页(铭刻记忆),指尖捻一片发光苔叶。
- **标志性特征:** 全身半透明苔光流萤;回望时背后浮现记忆卷轴虚影;神情哀而不悲。
- **配色:** 主色玉障青绿 + 月白,辉光烬火橙红(记忆灼烧处) + 苔光青绿。
- **姿态参考:** 悬空静立、双手拢于身前,俯身翻阅记忆时飘带低垂。

## 图片生成提示词

```
Lady of Memories, full body, front view, standing, ethereal woman woven from glowing memory moss with drifting translucent scrolls and pages, pale serene face, floating jade records orbiting, faint ember glow, jade green and moonlight white with ember-orange accents, translucent moss and paper materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~3k;漂浮书简/散页为独立低模件。
- **挂点/Socket:** 脚下悬浮点(不触地)、双手书简挂点、对话聚焦点(头部)。
- **碰撞:** 非战斗 NPC,可无实体碰撞或用淡胶囊;漂浮高度约离地 0.3m。
- **贴图:** 2K Base/Normal/Roughness;苔光与记忆页用 Emission + 半透明;烬火橙红仅作记忆灼烧的点缀。
- **动画/骨骼:** 简化人形骨架;需悬空静立/翻阅书卷/侧身回望循环;袍尾可加顶点飘动。

## 出处

- 设计文档:`docs/chapters/03-jade-veil/chapter-overview.md`(链接)、`docs/story/main-story.md`
- 代码挂点:`game/scripts/character_meshes.gd`(NPC 复用玩家骨架挂点)
