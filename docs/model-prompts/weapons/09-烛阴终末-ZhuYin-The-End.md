---
名称: 烛阴·终末（Zhu Yin · The End）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 全长约 2.2m(巨剑,剑身比玩家还高)
源文档: ../../bestiary/bosses-master.md
---

## 一句话概述

> 传奇 Boss 锻造武器(第 5 章烛阴);终极巨剑,剑身嵌无数群星光点如"载着万颗垂死星辰";蓄力重击放出星陨吐息光束(龙息)。

## 视觉描述

- **造型:** 庞大的深空黑铁巨剑,剑身平直厚重,通体密布微小的群星光点(像捕获的星系/星河);剑身沿星点连出幽蓝星座裂纹;剑格为双翼烛龙龙头造型,柄缠黑金丝。
- **材质:** 虚空黑铁 + 嵌星光点(自发光微粒)+ 黑金护手。
- **辉光:** 群星为冷白蓝点,核心烬火橙红微光在星点间流动;整剑"星蓝打底、烬橙点睛"。
- **尺寸:** 全长约 2.2m,剑身宽约 0.35m。
- **握持方式:** 双手持剑(手部挂点于剑格下方双位),巨剑斜扛或正握。

## 图片生成提示词

```
A single legendary ultra greatsword, front view, standing diagonally upright. An enormous dark void-metal greatsword inlaid with countless tiny star-points of light, glowing constellation cracks across the blade, dragon-scale guard, heavy black grip, cold starlight with warm ember core.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3.5k tris;LOD1 ~1.8k。
- **挂点/Socket:** `weapon_tip` 置于剑尖(龙息光束起点);双手部挂点;碰撞用长盒(含剑身厚度)。
- **贴图:** 4K;群星用发射贴图散点(自发光微粒),星座裂纹 Emission(冷蓝),核心烬火 Emission(橙);剑身低金属低粗糙偏哑。
- **动画:** 蓄力时星点由蓝转橙、裂纹增亮;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/bestiary/bosses-master.md`(烛阴 · Boss Weapon)、`docs/systems/weapons-compendium.md`(Legendary: Zhu Yin · The End)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`dragon_greatsword` shape_id)
