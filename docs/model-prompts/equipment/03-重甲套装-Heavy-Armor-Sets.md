---
名称: 重甲套装合集（Heavy Armor Sets）
类别: 装备
目标格式: GLB (Godot 4.7.1)
参考尺寸: 相对 1.8m 玩家(战甲/袍/王冠/腰带,分部件挂点)
源文档: ../../systems/equipment-compendium.md
---

## 一句话概述

> 重甲/重装提示词合集:铁啸战甲 / 云锦天衣 / 铸魂者长袍 / 烬渊王冠 / 督军腰带,每件一段独立生图提示词。注:云锦天衣、铸魂者长袍、烬渊王冠在图鉴中登记为轻/中甲,此处按任务分组归类,生图不受影响。

## 视觉描述

- **统一语言:** 厚重金属/大块面、轮廓敦实,烬火橙红辉光为标志;战甲重、长袍飘、王冠夺目。
- **铁啸战甲(重,Ch2)** — 整副铁胸甲:铆钉甲片 + 暗皮内衬,明式护肩护胸,战损烟熏(造型:胸甲;材质:铁+皮;辉光:甲片缝烬橙)。
- **云锦天衣(轻,Ch4)** — 白金云锦仙衣,宽袖飘带,云纹织金(造型:仙衣;材质:云锦绸+金线;辉光:金线遇光微烬橙)。
- **铸魂者长袍(轻,Ch5)** — 黑色铸魂者仪式长袍,铜铆饰边,魂币扣,烟渍补丁(造型:长袍;材质:黑布+铜;辉光:织缝渗烬火)。
- **烬渊王冠(中,Ch5)** — 黑铁+青铜王冠,炉齿式锯齿冠沿,冠心嵌一枚炽烬(造型:王冠;材质:铁+铜;辉光:冠心烬橙炽亮)。
- **督军腰带(重,Ch2)** — 重皮腰带,青铜牌饰,虎头扣,垂铁片护裙(造型:腰带;材质:皮+铜+铁;辉光:牌饰刻纹烬橙)。
- **尺寸:** 战甲盖全身;长袍及踝;王冠戴于额;腰带围腰并垂至大腿。

## 图片生成提示词

```
A single heavy armor chest piece, front view, floating upright. A full iron cuirass of riveted plates over dark leather, Ming-style shoulder and chest guards, battle-scarred and smoke-stained, faint ember-orange glow in the plate seams.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single heavenly garment chest piece, front view, floating upright. A flowing robe of white-and-gold cloud brocade with billowing sleeves and long trailing ribbons, luminous cloud embroidery, faint ember-orange thread catching the light.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single robe garment, front view, floating upright. A long black Soul-Forger ceremonial robe with bronze rivet trim and a soul-coin clasp, soot-stained and patched, faint ember-orange ember-light seeping through the weave.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single crown headgear, front view, floating upright. A dark crown of black iron and bronze forged from furnace gears, jagged flame-shaped prongs, a single large glowing ember setting at the center, tattered cloth lining.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single belt waist armor piece, front view, floating upright. A heavy leather warlord belt with large bronze plaques and a tiger-head buckle, riveted iron hanging straps, faint ember-orange glow along the engraved plaques.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 每件 LOD0 ~3k–4k tris(战甲/王冠偏上限);LOD1 减半。
- **挂点/Socket:** 胸甲/长袍挂胸腔、王冠挂头部、腰带挂髋部;飘带/下摆/垂片为次级绑定;烬渊王冠冠心走 Emission(`weapon_tip` 不适用)。
- **碰撞:** 战甲/长袍上身盒;王冠薄盒贴合头部;腰带髋部胶囊。
- **贴图:** 2K–4K(王冠 4K);金属件高金属,布/皮高粗糙;烬火辉光用 Emission。
- **动画:** 铁啸战甲甲片硬朗、云锦天衣与铸魂者长袍大摆动;保持现有姿势挂点。

## 出处

- 设计文档:`docs/systems/equipment-compendium.md`(Ch2 铁啸战甲、督军腰带 / Ch4 云锦天衣 / Ch5 铸魂者长袍、烬渊王冠)
- 代码挂点:占位护甲由 `game/scripts/core/character_meshes.gd` 生成(替换时保持姿势挂点)
