---
名称: 玄门法印（Mystic Gate Spell Seal）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 印体约 0.35m,加悬浮符箓与元素环绕整体约 0.7m
源文档: ../../systems/weapons-compendium.md
---

## 一句话概述

> 玄法师初始武器,漂浮的符箓法印,印周五行元素环绕;INT C 加成,施法聚焦法器,元素亲和切换载体。

## 视觉描述

- **造型:** 六边形青铜法印(印钮 + 印面),印面刻"玄门"铭文与门阙纹;印钮系一截深色丝绦。印体下方悬垂一张黄纸符箓,印周以细环悬浮五枚小元素珠(火红/水青/木绿/金白/土褐)。
- **材质:** 青铜(氧化发绿)+ 玉嵌钮 + 黄纸符箓(朱砂符文);元素珠为半透明琉璃。
- **辉光:** 印面铭文与符箓符文泛烬火橙红;元素珠各自微光,整印有漂浮悬停感。
- **尺寸:** 印体约 0.35m,悬浮元素环直径约 0.7m。
- **握持方式:** 单手持印(手部挂点于印钮),印体绕掌心缓慢旋转,符箓与元素珠静止环绕。

## 图片生成提示词

```
A single floating spell seal weapon prop, front view, levitating upright. A hexagonal bronze seal tablet engraved with gate runes, pale yellow paper talismans orbiting it, five small colored elemental sparks circling around the rim, jade accents, soft ember-orange glyph glow, dark tassel hanging below.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2.5k tris(印体 + 5 元素珠 + 符箓 + 丝绦);LOD1 ~1.2k。
- **挂点/Socket:** `weapon_tip` 置于印面上方(施法特效);手部挂点于印钮;元素珠做旋转环(子节点围绕,无需真实物理)。
- **碰撞:** 印体用盒碰撞;元素珠与符箓无碰撞。
- **贴图:** 2K;青铜 Base/Normal/Roughness,元素珠用自发光 + 半透明;烬火符文走 Emission。
- **动画:** 印体自转、元素环公转、符箓轻微飘动;保持 `character_meshes.gd` 替换时的现有手部姿势挂点。

## 出处

- 设计文档:`docs/systems/weapons-compendium.md`(玄法师起始武器)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`staff_seal` shape_id)
