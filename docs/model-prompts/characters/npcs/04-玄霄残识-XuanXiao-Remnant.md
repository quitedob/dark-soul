---
名称: 玄霄残识（Xuan Xiao's Remnant）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.0m(半透明漂浮残识,高于玩家)
源文档: ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

Ch.4 堕仙·玄霄的清醒核心残识(藏经阁中被释放的 lucid core),保留未被污染的天炉记录;于最终战后依玩家抉择完成飞升或回归凡忆,并赐下炉心敕印开启下坠之路。

## 视觉描述

- **体型/比例:** 高大清癯的高阶修士残影,半身光体、半身消散为烬尘,剪影虚实交叠。
- **服装/甲胄:** 白色云锦道袍(绣云纹、染污撕破),高冠半损,丝绦飘散。
- **武器/道具:** 身前悬浮一枚破碎的天书法卷;指尖凝聚一线炉心敕印光纹。
- **标志性特征:** 右半身圣白辉光、左半身灰烬残影(半飞升的静态凝固感);神情平静通透如清醒者。
- **配色:** 主色圣白白绸 + 金,辉光烬火橙红 + 圣白光,腐朽处以暗灰过渡。
- **姿态参考:** 悬空而立、双手结印于胸,俯瞰时衣摆化光尘。

## 图片生成提示词

```
Xuan Xiao's Remnant, full body, front view, standing, translucent floating remnant of a high cultivator in white cloud-brocade robes, right half divine light, left half dissolving into ember wisps, calm lucid face, white and gold with ember-orange light, silk and ethereal mist materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~3k;光体半身可用 Emission + 半透明显示透明度。
- **挂点/Socket:** 脚下悬浮点、双手结印挂点(炉心敕印特效点)、对话聚焦点(头部)。
- **碰撞:** 非战斗 NPC,可无实体碰撞或用淡胶囊;悬浮高度约离地 0.4m。
- **贴图:** 2K Base/Normal/Roughness;光体半身强 Emission,灰烬半身用半透明消散噪点;圣光用边缘光。
- **动画/骨骼:** 简化人形骨架;需悬空静立/结印/颔首微动循环;光尘可加粒子。

## 出处

- 设计文档:`docs/chapters/04-celestial-fall/chapter-overview.md`(链接)、`docs/bestiary/bosses-master.md`(玄霄真身参照)
- 代码挂点:`game/scripts/character_meshes.gd`(NPC 复用玩家骨架挂点)
