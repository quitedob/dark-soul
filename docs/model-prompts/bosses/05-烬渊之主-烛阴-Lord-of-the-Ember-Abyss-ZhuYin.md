---
名称: 烬渊之主·烛阴（Lord of the Ember Abyss Zhú Yīn）
类别: Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 龙形横跨地平线（约 40m+）；人形约 2.2m
源文档: ../bestiary/bosses-master.md、../chapters/05-throne-of-ashes/chapter-overview.md、../chapters/05-throne-of-ashes/chapter-supplement.md
---

## 一句话概述

Ch.5 烬座·归墟 最终 Boss，神（烛龙/堕铸魂者）：4 阶段（龙形 100-70% → 人形 70-40% → 深渊核心 40-10% → 终结抉择 10-0%）。烬座虚空平台；四种结局由玩家动作决定（薪火相传/守炉人/大寂灭/共铸新炉）。魂器：烛阴之鳞。

## 视觉描述

- **体型/比例:** 真身=群星光点构成的星光巨龙，横跨地平线（40m+，更像在与一片地域作战）；人形=魁梧苍老的凝光人形（~2.2m）。
- **服装/甲胄:** 人形=破旧褪色的铸魂者祭袍（原为庄严礼服，现破烂飘散）。
- **武器/道具:** 无实体武器；龙形用星光之爪/星落吐息，人形用凝光法术与烬火投矛。
- **标志性特征:** 身体由无数微小光点组成（每点一缕魂）、双眼如垂死之日、声音无口而响彻四方；星辰核心+颈裂为弱点。
- **配色:** 星辉蓝黑+垂死星辰多色微光+烬火橙红（P3 核心炽亮）。
- **姿态参考:** 龙形盘旋、人形站立/结印；P4 下跪于虚空孤台。弱点击破锚点：星辰核心+颈裂（龙形咽喉）。

## 图片生成提示词

> Phase 1 — Dragon Form（龙形）

```
Torch Dragon Zhu Yin, full body, front view, coiled colossal cosmic dragon of living starlight, body composed of countless tiny points of light each a fading soul, eyes like dying suns, sweeping starlight wings, constellation pattern forming in mouth, deep void black and starlight blue palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 2 — Human Form（人形）

```
Torch Dragon human form, full body, front view, standing, tall gaunt ancient figure of condensed starlight, tattered ceremonial soul-forger robes, weary sincere ancient face, dying stars glinting within body, long white beard, condensed light form, deep void black and starlight blue palette, ember-orange accents, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 3 — Core of the Abyss（烬渊之核）

```
Torch Dragon core of abyss, full body, floating in pure void zero-gravity, cosmic being collapsing into a burning core, human and dragon forms alternating translucent, core glowing ember-orange, soul storm erupting outward, event horizon black hole pulling, floating debris and starlight shards, void black and dying ember orange palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 4 — Final Choice（终结抉择）

```
Torch Dragon final choice, full body, front view, kneeling, ancient star-being kneeling on a single floating platform in the void, tattered soul-forger robes, exhausted sincere face, dying starlight dimming gently, hands open in offering, surrender pose, deep void black and faint starlight palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 龙形（背景级巨大）LOD0 ~20k tris / LOD1 ~10k / LOD2 ~5k；人形 LOD0 ~10k / LOD1 ~5k。
- **挂点/Socket:** `weapon_tip`（吐息/投矛特效）、`ExecutionAnchor`（处决）、`GrabProfile`（Soul Theft 抓取捕获形状）、星辰核心锚点 `star_core`、颈裂锚点 `neck_crack`（龙形咽喉）。
- **弱点击破锚点:** 星辰核心 `star_core`（P1/P3 可击、超新星预警）+ 颈裂 `neck_crack`（龙形咽喉，破后吐息减弱）。
- **碰撞:** 独立 `CollisionShape3D`；龙形分段碰撞（头/爪/尾各独立 `Area3D` 以配合尾扫/爪击时机）；人形标准胶囊。
- **贴图:** 4K；Emission：星点群（可用贴花+粒子叠加）、垂死之日双眼、星辰核心（P3 炽亮动画）。
- **骨骼/动画:** 龙形蛇骨长链骨骼+翅膀（Starfall Breath 抬首、Constellation Claws）；人形标准骨架+悬浮；P3 零重力翻转、Event Horizon 被吸姿态；P4 下跪投降/伸手。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/05-throne-of-ashes/chapter-overview.md`](../chapters/05-throne-of-ashes/chapter-overview.md)、[`../chapters/05-throne-of-ashes/chapter-supplement.md`](../chapters/05-throne-of-ashes/chapter-supplement.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
