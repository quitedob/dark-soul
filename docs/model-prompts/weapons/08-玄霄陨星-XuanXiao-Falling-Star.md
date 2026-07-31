---
名称: 玄霄·陨星（Xuan Xiao · Falling Star）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 全长约 1.4m(直剑中偏长,含光尾)
源文档: ../../bestiary/bosses-master.md
---

## 一句话概述

> 传奇 Boss 锻造武器(第 4 章玄霄);法剑,剑身圣光与腐朽双色同体;空中重攻击落地生成陨星冲击 AoE(天崩)。

## 视觉描述

- **造型:** 直剑,剑身纵向一分为二——一半为炽白圣光剑刃(半透亮、嵌金星纹),另一半为腐朽锈铁 + 发绿腐肉状剑身;剑格为残破仙冠造型,护手半边飞升半边腐烂;剑尾拖一道彗星尾迹光带。
- **材质:** 圣光半透明琉璃白铁 + 锈蚀黑铁/腐植;陨星元素为光微粒。
- **辉光:** 圣光侧炽白(高 Emission),腐侧幽绿 + 烬火橙红交织;彗星尾带流光。
- **尺寸:** 全长约 1.4m。
- **握持方式:** 单手持剑(手部挂点于剑格),剑身斜置,陨星尾随挥动拉长。

## 图片生成提示词

```
A legendary spell sword, front view, levitating diagonally. A straight sword split into two halves, one half radiant white-gold holy light, the other half rotting green-black flesh and rusted iron, comet-tail star streaks curling around the blade, drifting embers.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2.5k tris;LOD1 ~1.2k。
- **挂点/Socket:** `weapon_tip` 置于剑尖(陨星/天崩落点特效);手部挂点于剑格;彗星尾带为可关闭的粒子/平面带。
- **碰撞:** 剑身细盒(按整体轮廓);腐侧无需单独碰撞。
- **贴图:** 4K;双材质——圣光侧半透明自发光,腐侧氧化 Normal + Emission(绿/橙);过渡区做像素化熔接。
- **动画:** 彗星尾随挥动生成;圣光侧辉光随充能变化;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/bestiary/bosses-master.md`(玄霄 · Boss Weapon)、`docs/systems/weapons-compendium.md`(Legendary: Xuan Xiao · Falling Star)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`sword` shape_id,替换材质)
