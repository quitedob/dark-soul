---
名称: 铁砧与锻造台 (Forge & Anvil)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 高 ~1.6m,台面 ~1.5m×1.0m(玩家 1.8m)
源文档: ../chapters/02-blood-iron/chapter-overview.md, ../chapters/02-blood-iron/chapter-supplement.md
---

## 一句话概述

> 铁心工坊及烬龛锻造用的铁砧与锻造台:用于武器锻造、强化与重铸。由铁砧、炉火、淬火水槽与工具架构成,是玩家升级装备的交互地点。

## 视觉描述

- **体型/比例:** 重型铁砧置于石砌台座上(高约 1.1m),旁立矮炉(约 1.6m)与工具架,侧接淬火水槽。
- **材质:** 锻铁/砧面(金属度偏高)、风化木柄、石台;炉口为橙红烬火自发光。
- **标志性特征:** 砧面有反复锤击的凹痕与火痕;炉火不停;火星与余烬上飘;墙上悬铁钳、锻锤。
- **配色:** 铁灰 + 炉火橙红 + 炭黑 + 烬金。
- **姿态参考:** 静态地标,炉火循环粒子;无骨骼。

## 图片生成提示词

```
A heavy iron anvil mounted on a stone pedestal, a small open furnace with glowing orange ember flames beside it, a quenching water trough and a wooden tool rack holding iron tongs and hammers, dented scarred anvil face, drifting sparks and cinders, forge-gold glow on dark iron,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2.5k tris;LOD1 ~1.2k tris。
- **挂点:** `ForgeInteract`(锻造交互点)、`AnvilSurface`(锻造锤击锚点)。
- **碰撞:** 铁砧盒碰撞 + 台座;炉口触发体。
- **贴图:** 2K;铁砧用 Metalness 贴图,炉火用 Emission。
- **动画:** 炉火循环粒子;交互时可播放锤击音效锚点,无骨骼。

## 出处

- 设计文档:`docs/chapters/02-blood-iron/chapter-overview.md`(铁心/锻造)、`docs/chapters/02-blood-iron/chapter-supplement.md`(铁心之锤、铁心支线)
- 代码挂点:`game/scripts/`(锻造交互,待建)
