---
名称: 战巫（War Shaman）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/README.md
---

## 一句话概述

狂战士 + 祝祷师的混合职业(第三章后解锁),身披战甲却以符纸战舞自我加持;近战重击与战斗祝祷并用,把血越打越勇的战意与护体庇佑合为一体。

## 视觉描述

- **体型/比例:** 宽肩健硕、身高中等,战甲厚实但比纯狂战士轻量,剪影刚健带飘带。
- **服装/甲胄:** 兽皮战甲外披符纸扎成的护带与骨坠,铁腕甲绘符,额佩战巫骨面(半掩脸)。
- **武器/道具:** 主手刑天战斧(单把,斧身缚往生符纸)、副手一把符纸(抛撒战舞);腰间挂念珠 + 骨哨。
- **标志性特征:** 符纸在战舞中漂浮发光;战吼时符带燃起烬火;胸前轮回印微光。
- **配色:** 主色暗烬灰 + 血铁红,辉光烬火橙红 + 金符光。
- **姿态参考:** 站姿单手持斧横胸、另一手捻符纸,蓄势战舞。

## 图片生成提示词

```
War Shaman, full body, front view, standing, warrior in heavy beast-hide armor with fur trim and bone charms, war paint, single battle axe, talisman papers bound to weapon, faint rebirth seal on chest, dark ash gray and ember-orange palette, worn iron and hide materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;战斧为独立武器件。
- **挂点/Socket:** 右手主手战斧挂点、斧刃 `weapon_tip`(拖尾/符火)、左手抛符点、`ExecutionAnchor`、`GrabProfile`。
- **碰撞:** 玩家胶囊 ~0.62m 半径 × 1.8m 高;战斧盒碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;符纸与骨坠辉光用 Emission。
- **动画/骨骼:** 标准人形骨架;需战斧连段/抛符/战吼施法融合姿态。

## 出处

- 设计文档:`docs/characters/classes/README.md`(混合职业表,链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
