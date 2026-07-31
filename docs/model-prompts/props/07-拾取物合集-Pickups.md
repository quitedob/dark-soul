---
名称: 拾取物合集 (Pickups)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 单体 0.1–0.4m;玩家身高 ~1.8m
源文档: ../systems/equipment-compendium.md, ../game-design.md, ../chapters/01-spirit-awakening/chapter-overview.md, ../chapters/02-blood-iron/chapter-overview.md
---

## 一句话概述

> 可拾取小物件合集:烬火(货币/魂)、各类消耗品(丹药、香、号角、尘、灵感、自我残影、终末余烬)与钥匙物(守炉符文、铁心之锤、经脉解锁石等)。以"通用小物件 + 发光"的统一风格合并建模,替换程序化占位。

## 视觉描述

- **风格:** 中式暗黑低模 PBR,统一采用"小物件 + 发光强调"以便远处可读、拾取有手感。
- **材质:** 陶瓷、青铜、玉、纸/绢、锻铁;发光件用 Emission。
- **配色:** 烬橙(魂/火)、玉青(解锁石)、青铜绿锈、药瓶青瓷釉。
- **剪影:** 每件小物轮廓清晰,发光点是拾取的视觉信号。

## 图片生成提示词

### 烬火 (Ember)

击杀与探索掉落的货币/魂,死亡回收的核心资源。

```
A single small ember of warm orange fire floating upright, a teardrop glowing core with a soft halo, a few sparks and ash motes rising around it, translucent luminous effect, faint golden light,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 丹药与灵药 (Pills & Medicinal Jars)

回神香、炽火丸、止血散、醒神丹、聚灵丹、回生丹、不朽丹等丹药消耗品,统一为药瓶/药丸/药香风格。

```
A small celadon pill jar with a cork stopper and red cord, a few luminous round medicine pills resting on the lid, a thin stick of incense with a wisp of blue smoke, warm soft glow on the glaze,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 特殊消耗品 (Special Consumables)

烽火号角、幻影尘、诗人灵感、自我残影、终末余烬等特殊道具,统一为带发光的祭器小件。

```
A small bronze war horn with engraved battle runes and a glowing ember mouth, a drawstring pouch of shimmering illusory dust, a roll of weathered poetry scroll with a faint luminous ribbon, clustered as tiny glowing relic trinkets,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 钥匙物 (Key Items)

守炉符文、铁心之锤、经脉解锁石等推进剧情的钥匙道具,统一为带发光印记的古老遗物。

```
A carved furnace-keeper's rune stone with a glowing orange seal-mark, a forged iron smithing hammer with a worn handle, a small jade meridian unlock-stone glowing blue-white, arranged as three ancient ritual relics,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 每件小物 LOD0 0.2–0.6k tris;可合并为图集 + 共享材质以省 Draw Call。
- **挂点/判定:** `PickupCollider`(拾取触发)、`GlowSocket`(发光/粒子)、`PickupRotate`(浮空旋转)。
- **碰撞:** 球形/小盒触发体。
- **贴图:** 1–2K;发光件用 Emission;瓶/玉加半透明。
- **动画:** 通用浮空 + 旋转 + 柔和呼吸发光;拾取播放消散。

## 出处

- 设计文档:`docs/systems/equipment-compendium.md`(消耗品清单)、`docs/game-design.md`(烬火/拾取)、`docs/chapters/01-spirit-awakening/chapter-overview.md`(守炉符文/回神香/炽火丸)、`docs/chapters/02-blood-iron/chapter-overview.md`(铁心之锤/烽火号角/督脉解锁石)
- 代码挂点:`game/scripts/`(拾取物生成,待建)
