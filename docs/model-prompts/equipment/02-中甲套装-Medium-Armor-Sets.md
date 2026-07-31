---
名称: 中甲套装合集（Medium Armor Sets）
类别: 装备
目标格式: GLB (Godot 4.7.1)
参考尺寸: 相对 1.8m 玩家(护腕/护手/肩甲/袍,分部件挂点)
源文档: ../../systems/equipment-compendium.md
---

## 一句话概述

> 中甲套装提示词合集(金属与布混编,mid roll,-5% 耐力回复):炼丹师护腕 / 铁心护手 / 将军肩甲 / 将军护手 / 玉鳞袍,每件一段独立生图提示词。

## 视觉描述

- **统一语言:** 金属板件 + 内衬布,半刚半柔;烬火橙红辉光为标志,勾边点缀。
- **炼丹师护腕** — 皮腕甲 + 铜板,绑小琉璃药瓶,瓶内绿液发光(造型:护腕;材质:皮革+铜+琉璃;辉光:绿液与铜扣烬橙)。
- **铁心护手** — 铁制护手,关节甲片,腕口錾"心"形徽记(造型:护手;材质:暗铁+铆钉;辉光:铆缝透烬橙)。
- **将军肩甲** — 明式多层钢肩甲,隆起脊线,缀红缨结(造型:肩甲;材质:黑漆钢+黄铜;辉光:甲纹凹槽烬橙)。
- **将军护手** — 配肩甲的礼仪护手,宽腕口,缀缨结(造型:护手;材质:黑漆钢+黄铜;辉光:錾刻纹烬橙)。
- **玉鳞袍** — 层叠青玉鳞片长袍,深色绸里,立领(造型:鳞袍;材质:玉+绸;辉光:鳞片缝间烬橙)。
- **尺寸:** 护腕/护手贴臂;肩甲盖肩至大臂;玉鳞袍及膝。

## 图片生成提示词

```
A single medium armor arms piece, front view, floating upright. Pair of leather bracers reinforced with brass plates, small glass elixir vials strapped on, green glowing liquid, faint ember-orange glow on the brass fittings.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single medium armor arms piece, front view, floating upright. Pair of iron gauntlets with articulated knuckle plates and a riveted heart emblem on each cuff, dark steel with warm ember-orange glow in the rivet seams.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single medium armor shoulders piece, front view, floating upright. Pair of layered Ming-style steel pauldrons with raised ridges and a red general's knot, lacquered black with tarnished brass trim, faint ember glow in the grooves.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single medium armor arms piece, front view, floating upright. Pair of ceremonial Ming general gauntlets with flared cuffs and a tasseled knot, black lacquered steel with brass trim matching pauldrons, faint ember-orange glow in the engraved ridges.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single medium armor chest piece, front view, floating upright. A layered robe of overlapping jade-green scales with dark silk lining and a high collar, polished jade shimmer, faint ember-orange glow between the scale edges.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 每件 LOD0 ~2.5k–3k tris;LOD1 减半。
- **挂点/Socket:** 护腕/护手挂于前臂骨骼、肩甲挂于肩关节、袍挂于胸腔;药瓶/缨结为次级绑定可摆动;发光走 Emission(`weapon_tip` 不适用)。
- **碰撞:** 护腕/护手用臂套胶囊;肩甲薄盒;玉鳞袍上身盒。
- **贴图:** 2K;金属件中高金属低粗糙,玉/琉璃半透;烬火辉光用 Emission。
- **动画:** 玉鳞袍下摆随移动摆动;护手关节片随握拳微动;保持现有姿势挂点。

## 出处

- 设计文档:`docs/systems/equipment-compendium.md`(Ch1 炼丹师护腕 / Ch2 铁心护手、将军肩甲 / Ch3 玉鳞袍)、`docs/chapters/02-blood-iron/chapter-supplement.md`(将军护手)
- 代码挂点:占位护甲由 `game/scripts/core/character_meshes.gd` 生成(替换时保持姿势挂点)
