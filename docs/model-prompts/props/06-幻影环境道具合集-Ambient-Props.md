---
名称: 幻影环境道具合集 (Ambient Props)
类别: 道具
目标格式: GLB (Godot 4.7.1)
参考尺寸: 单体 0.4–4m;玩家身高 ~1.8m
源文档: ../chapters/03-jade-veil/chapter-overview.md, ../chapters/03-jade-veil/chapter-supplement.md, ../chapters/01-spirit-awakening/chapter-overview.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

> 以叙事与氛围为主的幻境/环境道具单体合集:记忆苔、纸灯笼、狐嫁花轿、九幻花、石棺与烬座王座。用于点缀环境、讲述环境叙事,替换程序化占位。

## 视觉描述

- **风格:** 中式暗黑低模 PBR,氛围道具强调**发光与幻境质感**。
- **材质:** 苔藓(半透明发光)、纸/绢、木/竹、玉、灰石、凝固烬光。
- **配色:** 玉青、狐火青、月光银蓝、绯红花瓣、烬橙。
- **剪影:** 每类道具以独特轮廓(藤蔓、灯笼、轿、花、棺、座)点题。

## 图片生成提示词

### 记忆苔 (Memory Moss)

```
A patch of glowing teal memory moss clinging to a cracked stone wall, luminous lichen pulsing softly, faint blue-green bioluminescent light seeping across the rock, droplets of condensed mist, shadowy carved script beneath the moss,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 纸灯笼 (Paper Lantern)

```
A round paper lantern glowing with foxfire-cyan light, red paper frame with faded painted flowers, thin wooden ribs, a small metal cap and tassel, soft translucent glow cast on the surrounding air,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 狐嫁花轿 (Fox Wedding Palanquin)

```
A ghostly crimson wedding palanquin resting on its carrying poles, red silk drapery with faded gold embroidery, carved wooden frame, tassels and silk tassel finials, faint foxfire glow seeping through the curtain, worn bridal lace trim,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 九幻花 (Illusion Flower)

```
A single large illusory flower with layered translucent petals, each petal a different luminous pastel hue, glowing stamen core, soft bloom of light, slender jade-green stem, faint drifting petal motes,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 石棺 (Stone Sarcophagus)

```
A massive carved stone sarcophagus, lid etched with the sealed figure of a robed soul-forger, weathered runes and a broken seal-mark, moss and ash in the grooves, dim ember-orange light leaking from the seams,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

### 烬座王座 (Throne of Ashes)

```
A monumental throne built from nine interlocking bronze seal-plates, condensed ember-light glowing in the joints, ritual-vessel motifs rising up the backrest, a halo of fading sparks around the seat, solemn and vast,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 单体 LOD0 0.6–2.5k tris;苔藓/灯笼以贴图 + Emission 表现为主。
- **挂点/判定:** `AmbientGlow`(发光)、`InteractPoint`(记忆苔/花可交互)、`MossTrigger`(触碰触发)。
- **碰撞:** 灯笼/花/苔可用较小碰撞体或仅触发;石棺/王座用盒碰撞。
- **贴图:** 2K;纸/绢用半透明次表面,苔/花/烬光用 Emission。
- **动画:** 灯笼摇曳、花呼吸闪烁、烬光脉动(局部动画,无骨骼)。

## 出处

- 设计文档:`docs/chapters/03-jade-veil/chapter-overview.md` 与 `chapter-supplement.md`(记忆苔/纸灯笼/花轿/九幻花)、`docs/chapters/01-spirit-awakening/chapter-overview.md`(石棺)、`docs/chapters/05-throne-of-ashes/chapter-overview.md`(烬座王座)
- 代码挂点:`game/scripts/`(环境交互,待建)
