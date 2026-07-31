---
名称: 谜题道具合集 (Puzzle Props)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 单体 0.3–3m;玩家身高 ~1.8m
源文档: ../systems/level-design-patterns.md, ../chapters/01-spirit-awakening/levels/01-levels-detail.md, ../chapters/02-blood-iron/chapter-overview.md, ../chapters/04-celestial-fall/chapter-overview.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

> 可交互谜题机关单体合集,覆盖全书谜题目录:旋转青铜镜、毒雾阀门、四战旗、烽火台火口、青铜鼎、星图机关盘与倒悬锁。每个单体可单独建模。

## 视觉描述

- **风格:** 中式暗黑低模 PBR,机关需有明确的**可读提示**(铭文、发光缝、待机态)。
- **材质:** 青铜/青铜鎏金、灰石、木质柄杆;发光部件用 Emission。
- **配色:** 青铜绿锈 + 石灰为底;待机发光(烬橙/玉青/星蓝)标记可交互处。
- **剪影:** 每类机关独有的转动/推拉/插拔形态,远处即可辨认。

## 图片生成提示词

### 旋转青铜镜 (Rotating Bronze Mirror)

```
A circular polished bronze mirror set in a carved stone frame on a pivot, hinged to rotate on its axis, aged tarnished reflective surface, engraved star-glyphs around the rim, a soft light beam glinting off the face,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 毒雾阀门 (Toxic Mist Valve)

```
A large rusted bronze valve wheel mounted on a broken pipe run, heavy hand-spokes, corrosion and green residue, a red-lacquered lever arm beside it, faint glow behind the pipe seams,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 四战旗 (War Banner)

```
A tall weathered banner pole planted in the earth, holding a torn faded war banner painted with a faded campaign emblem, frayed edges, iron finial, ropes and a weighted stone base, wind-bent cloth,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 烽火台火口 (Beacon Fire Mouth)

```
A wide stone fire-basket opening on a beacon tower parapet, heavy iron basket and grates, soot-blackened inner throat, unlit tinder and charcoal inside, carved signal glyphs around the mouth,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 青铜鼎 (Bronze Cauldron)

```
A massive archaic bronze cauldron with three legs and two upright ear-handles, raised taotie mask reliefs on the body, green patina and ash crust, glowing ember coals inside, molten heat shimmer above the rim,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 星图机关盘 (Celestial Dial)

```
A flat bronze astrolabe disc mounted on a stone anchor plinth, engraved constellations and graduated rings, a rotatable pointer arm, star-chart lines etched across the face, faint blue-white glow along the markings,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 倒悬锁 (Inversion Lock)

```
A massive inverted bronze lock mechanism bolted to a stone ceiling, upside-down latch plate and rotating gear rings, glowing geometry runes on the plates, gravity-defying orientation, chains hanging upward into the dark,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 单体 LOD0 0.8–2k tris;共用铰链/盘面部件。
- **挂点/判定:** `RotatePivot`(转动轴)、`InteractPoint`(交互)、`StateSocket`(解谜状态灯)。
- **碰撞:** 盘/阀用盒碰撞;战旗/火口为静态碰撞。
- **贴图:** 2K;青铜用 Metalness + 绿锈 AO,发光用 Emission。
- **动画:** 转动/推拉/点火为局部旋转或状态切换(无骨骼);点火后 Emission 增强。

## 出处

- 设计文档:`docs/systems/level-design-patterns.md`(谜题目录)、`docs/chapters/01-spirit-awakening/levels/01-levels-detail.md`(三铜镜/毒雾阀门)、`docs/chapters/02-blood-iron/chapter-overview.md`(四战旗/烽火)、`docs/chapters/04-celestial-fall/chapter-overview.md`(星图机关盘)、`docs/chapters/05-throne-of-ashes/chapter-overview.md`(倒悬锁)
- 代码挂点:`game/scripts/`(谜题逻辑,待建)
