---
名称: 机关陷阱合集 (Trap Props)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 单体 0.5–3m;玩家身高 ~1.8m
源文档: ../systems/level-design-patterns.md, ../chapters/01-spirit-awakening/levels/01-levels-detail.md, ../chapters/04-celestial-fall/chapter-overview.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

> 环境危害与陷阱的交互单体合集,覆盖全书:压力板、火焰喷口、落石闸、毒雾喷口、塌陷地板、油锅、风阵与烬涌。每个单体可单独建模,替换 `game/scripts/` 中的程序化占位。

## 视觉描述

- **风格:** 中式暗黑低模 PBR,威胁必须**有可读的预警**(焦痕、裂痕、颜色差异),遵循"telegraphed danger"设计原则。
- **材质:** 灰石/锻铁/青铜 + 危险部位自发光(火焰橙、毒液绿、烬光暖橙)。
- **配色:** 中性石色为底,危险元素以亮色高对比标记。
- **剪影:** 每个陷阱一眼可辨的触发形态(板、喷口、闸、灶、阵)。

## 图片生成提示词

### 压力板 (Pressure Plate)

```
A flat round stone pressure plate set slightly raised above the floor, discolored and scorch-marked around its rim, small carved warning glyphs on its surface, cracked edges, dim ember glow leaking from the seam,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 火焰喷口 (Flame Vent)

```
A carved stone wall vent shaped like a beast mouth, soot-blackened opening, scorch marks fanning across the stone below, faint orange ember glow deep inside the throat, warning cracks radiating outward,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 落石闸 (Falling Stone Gate)

```
A massive square stone gate slab hanging from iron chains in a stone frame, thick grooved face, heavy iron brackets, dusty and cracked, slight downward tilt ready to drop, dim light passing around its edges,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 毒雾喷口 (Toxic Mist Vent)

```
A rusted bronze pipe nozzle protruding from a stone wall, green toxic mist curling from its mouth, corroded valve wheel beside it, dripping residue and sickly green glow pooling at the base,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 塌陷地板 (Collapsing Floor)

```
A cracked stone floor section with hairline fractures and sunken panels, fragments already fallen away into a dark pit below, dust drifting from the seams, edges crumbling and uneven,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 油锅 (Oil Cauldron)

```
A large black iron oil cauldron suspended over a smoldering brazier on the fortress wall, dark bubbling oil surface, rising heat shimmer, carved iron legs and chain hangers, cinders drifting,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 风阵 (Wind Gust Array)

```
A floating stone wind-gate formed of overlapping jade and bronze rings, swirling air currents visible as translucent streaks, glowing runes on the ring edges, ropes of displaced dust curling through the center,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 烬涌 (Ember Geyser)

```
A stone vent ringed by scorched volcanic rock, a column of superheated ash and ember-fire erupting upward, glowing orange sparks and gray cinders bursting at the rim, heat-distorted air, crusted glowing veins in the stone,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 单体 LOD0 0.5–1.5k tris;多复用部件(阀门、喷口)做共享网格。
- **挂点/判定:** `TriggerArea`(触发体)、`DamageArea`(伤害区)、`VisualSocket`(火焰/毒/风粒子)。
- **碰撞:** 板/闸用盒碰撞;喷口伤害为区域触发体。
- **贴图:** 2K Base/Normal/Roughness;危险部位用 Emission(火焰橙/毒绿)。
- **动画:** 火焰喷口/风阵/烬涌用循环粒子;落石闸可播放下坠动画(无骨骼)。

## 出处

- 设计文档:`docs/systems/level-design-patterns.md`(陷阱目录)、`docs/chapters/01-spirit-awakening/levels/01-levels-detail.md`(火焰喷口/落石闸)、`docs/chapters/04-celestial-fall/chapter-overview.md`(风阵)、`docs/chapters/05-throne-of-ashes/chapter-overview.md`(烬涌)
- 代码挂点:`game/scripts/`(陷阱模块行为,待建)
