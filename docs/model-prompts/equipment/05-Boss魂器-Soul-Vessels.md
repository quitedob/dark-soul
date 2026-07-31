---
名称: Boss 魂器合集（Soul Vessels）
类别: 装备
目标格式: GLB (Godot 4.7.1)
参考尺寸: 小物件(直径/边长 ≤0.4m),悬浮展示
源文档: ../../bestiary/bosses-master.md
---

## 一句话概述

> 五章主线 Boss 掉落的魂器/锻造材料合集,小物件 + 强发光;每件独立生图提示词,供掉落拾取与装备栏展示。

## 视觉描述

- **统一语言:** 小体积、强发光、悬浮;每件对应 Boss 主题色:巨阙=炉橙、刑天=血红、九尾=月光银、玄霄=圣白vs腐朽、烛阴=星蓝。
- **守炉之核(Ch1)** — 熔铜炉核球,烬火裂纹蛛网,暗铁环箍(辉光:炽橙)。
- **刑天之心(Ch2)** — 石铁心脏,赤红仪式疤线,断链悬垂(辉光:血红+烬橙)。
- **刑天断角(Ch2 锻造)** — 断裂黑铁战角,赤红纹环,断口冒烟(辉光:烬橙)。
- **九尾幻心(Ch3)** — 半透明玉心,内藏九道彩光狐尾幻影(辉光:月光银+烬橙)。
- **九尾玉簪(Ch3 锻造)** — 白狐玉簪,九尾展开为彩光丝缕(辉光:月白+烬橙;与饰品 04 共享件)。
- **玄霄残愿(Ch4)** — 半白半腐凝光球,符字环绕(辉光:圣白+腐绿+烬橙)。
- **玄霄道心(Ch4 锻造)** — 裂纹白玉心,半圣半腐,云纹(辉光:白金+烬橙)。
- **烛阴之鳞(Ch5)** — 活星光巨龙鳞,嵌群星光点(辉光:星蓝+烬橙)。

## 图片生成提示词

```
A single soul-vessel core, front view, floating upright. A molten bronze furnace-core orb with a spiderweb of glowing ember cracks, contained by a ring of dark iron, heat shimmer, deep ember-orange glow.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel heart, front view, floating upright. A pulsing stone-and-iron heart wrapped in crimson ritual scar-lines, hanging from a broken chain, blood-red glow with an ember-orange pulse.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel horn, front view, floating diagonally. A broken black-iron war horn etched with crimson tattoo rings and a jagged fracture, smoke curling from the break, ember-orange glow in the etchings.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel heart, front view, floating upright. A translucent jade heart with nine swirling tail-shaped illusions of colored light inside, floating, moonlight silver with an ember-orange core.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel jade hairpin, front view, floating diagonally. A white-jade hairpin carved as a nine-tailed fox, its tails unfurling into wisps of colored illusion light, ember-orange glow at the heart.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel wish, front view, floating upright. A half-white half-decayed sphere of congealed light and rot, a faint prayer written in glowing characters orbiting it, divine white with a dim ember glow.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel heart, front view, floating upright. A cracked white jade heart split into holy and decayed halves, cloud-pattern engraving, fine fissures of light, white-gold with a slow ember-orange pulse.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

```
A single soul-vessel scale, front view, floating upright. A large dragon-scale of living starlight inlaid with countless tiny points of light, floating in the dark, cold star-blue with an ember-orange ember core.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 每件 LOD0 ~0.5k–1.5k tris;LOD1 减半。
- **挂点/Socket:** 掉落拾取时悬浮(无握持);装备栏展示用旋转台;发光走 Emission,建议叠加半透明辉光球(不适用 `weapon_tip`)。
- **碰撞:** 拾取用球形/盒形小碰撞体。
- **贴图:** 2K;主体半透明/自发光,辉光 Emission multiplier 高;九尾幻心/玄霄残愿需透光与多色发光。
- **动画:** 悬浮缓转、辉光脉动、烟/光丝粒子;刑天断角断口冒烟可加粒子。

## 出处

- 设计文档:`docs/bestiary/bosses-master.md`(各 Boss Soul Vessel 与锻造材料)、`docs/systems/equipment-compendium.md`(魂器强化经济)
- 代码挂点:掉落拾取物由 `game/scripts/core/weapon_meshes.gd` 的 `spirit_stone` 风格占位替换
