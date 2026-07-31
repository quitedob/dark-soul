---
名称: 轻甲套装合集（Light Armor Sets）
类别: 装备
目标格式: GLB (Godot 4.7.1)
参考尺寸: 相对 1.8m 玩家(胸甲覆盖上身,轻甲贴身/披风式)
源文档: ../../systems/equipment-compendium.md
---

## 一句话概述

> 轻甲套装提示词合集(皮/布/披风,fast roll,无耐力惩罚):镜影斗篷 / 斥候斗篷 / 狐裘披风 / 登仙残袍,每套一段独立生图提示词,供批量替换程序化占位护甲。

## 视觉描述

- **统一语言:** 布料/皮革为主、行动轻便,烬火橙红辉光为标志;轮廓柔、层数多、可飘动。
- **镜影斗篷** — 暗色披风缀青铜镜片,镜面泛月光、边缘留残影(造型:带兜帽斗篷;材质:粗布+青铜镜片;辉光:镜缘微烬橙)。
- **斥候斗篷** — 灰绿斥候斗篷带兜帽,沾泥土草渍,骨钮与绳扣(造型:战术斗篷;材质:粗麻布;辉光:下摆线头微烬橙)。
- **狐裘披风** — 白狐裘披风,玉扣,层叠毛领(造型:裘皮披风;材质:皮毛+玉扣;辉光:玉扣泛月光与烬橙)。
- **登仙残袍** — 白色道袍撕裂半解,云纹褪色,一袖灼焦、另一袖泛圣光(造型:残破道袍;材质:白绸+焦痕;辉光:圣光白与烬橙交织)。
- **尺寸:** 均覆盖上身至膝;披风/斗篷下摆可飘动。

## 图片生成提示词

```
A single light armor chest piece, front view, floating upright. A flowing dark cloak sewn with small bronze mirror shards that catch faint moonlight, worn leather straps, blurred ghostly afterimage fringe, subtle ember-orange hem glow.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single light armor chest piece, front view, floating upright. A tattered scout's cloak of grey-green cloth with a hood, dirt and grass stains, small bone buttons and a weathered rope clasp, faint ember-orange thread at the hem.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single light armor chest piece, front view, floating upright. A warm cape of white fox fur with a jade clasp, layered fur trim and a trailing collar, soft lunar silver sheen with a faint ember-orange glow at the clasp.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single light armor chest piece, front view, floating upright. A white cultivator's robe torn and half-unraveled, cloud embroidery fading, one sleeve scorched and the other radiant with holy light, faint ember-orange thread among the tears.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 每套 LOD0 ~3k tris(含下摆/兜帽/镜片);LOD1 ~1.5k。
- **挂点/Socket:** 胸甲挂点于角色胸腔;斗篷/披风下摆做次级绑定(Cloth 或骨骼摆动);`weapon_tip` 不适用,装饰发光走 Emission。
- **碰撞:** 上身用盒/胶囊;披风无碰撞。
- **贴图:** 2K;布料高粗糙低金属,镜片/玉扣金属度高;烬火辉光用 Emission。
- **动画:** 登仙残袍与狐裘披风带飘动(行走/空中);镜影斗篷残影可用透明度闪烁模拟。

## 出处

- 设计文档:`docs/systems/equipment-compendium.md`(Ch1/Ch2 支线/Ch3/Ch4 胸甲项)、`docs/chapters/02-blood-iron/chapter-supplement.md`(斥候斗篷)
- 代码挂点:占位护甲由 `game/scripts/core/character_meshes.gd` 生成(替换时保持姿势挂点)
