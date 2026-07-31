---
名称: 魔弓手（Arcane Archer）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/README.md
---

## 一句话概述

神射手 + 玄法师的混合职业(第三章后解锁),把道门五行术注入箭矢,射出的每一支箭都带元素附魔;皮甲与法袍并存,近身用猎刀、远距以符箓箭雨覆盖。

## 视觉描述

- **体型/比例:** 中等偏瘦、身高略高,皮甲外罩法袍半身,剪影修长带悬浮符箓。
- **服装/甲胄:** 轻皮甲 + 玄色道袍披风叠穿,羽冠保留但加符纹,弓手护腕绘五行爻。
- **武器/道具:** 主手玄纹长弓(弓身刻符箓、弓弦泛五行微光)、副手猎刀 + 灵石(挂腰);箭袋插附魔符箭。
- **标志性特征:** 箭镞萦绕五行元素光(火/冰/雷/灵);拉弦时符箓在弓身浮现;胸前轮回印微光。
- **配色:** 主色皮棕 + 玄黑,辉光烬火橙红 + 元素色(青蓝/紫)。
- **姿态参考:** 站姿侧身拉弦、箭镞聚光;弓体挂点用于元素箭特效。

## 图片生成提示词

```
Arcane Archer, full body, front view, standing, marksman in dark leather and silk armor with feather crown, enchanted longbow glowing with runes, arrows alight, spirit stone at hip, faint rebirth seal on chest, midnight blue and silver with ember-orange accents, leather and silk materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;长弓与猎刀为独立武器件,符箭为低模道具。
- **挂点/Socket:** 弓体 `weapon_tip`(元素箭发射点)、右手主手弓挂点、左手副手猎刀挂点、`ExecutionAnchor`、`GrabProfile`。
- **碰撞:** 玩家胶囊 ~0.6m 半径 × 1.8m 高;弓盒碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;弓身符箓与箭镞辉光用 Emission(可切换元素色)。
- **动画/骨骼:** 标准人形骨架;需拉弓蓄力/翻滚射击/抛洒符箭雨姿态。

## 出处

- 设计文档:`docs/characters/classes/README.md`(混合职业表,链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
