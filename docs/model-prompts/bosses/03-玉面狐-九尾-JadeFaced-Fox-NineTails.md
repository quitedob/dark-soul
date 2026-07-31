---
名称: 玉面狐·九尾（Jade-Faced Fox Nine-Tails）
类别: Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 真身巨狐约 10m（九尾展开如扇）；人形约 1.8m
源文档: ../bestiary/bosses-master.md、../chapters/03-jade-veil/chapter-overview.md、../chapters/03-jade-veil/chapter-supplement.md
---

## 一句话概述

Ch.3 玉障·迷心 Boss，妖（堕自然神）：3 阶段（试探 100-70% → 幻境风暴 70-30% → 记忆之形 30-0%）。月华台被 9 幻花环绕；50% HP 记忆凝视过场；可用「真实之镜」选择救赎或战后封印（`ch3_nine_tails_fate`）。魂器：九尾幻心。

## 视觉描述

- **体型/比例:** 真身=九尾巨狐（月下约 10m，九条巨尾展开如扇）；人形=青玉罗裳女子（~1.8m），面半遮透明扇、永不合眼。
- **服装/甲胄:** 真身=玉青绿毛皮、月白腹毛；人形=多层青玉罗裳（唐/宋式广袖）、绡纱、玉石发簪。
- **武器/道具:** 人形手持半遮面绢扇（兼做法术法器）；真身用尾与狐火。
- **标志性特征:** 九尾每尾一色（各代表一类幻象：白/青/绯/紫/蓝…）、月光眼眸、玉石微光；真身有极淡青玉微光可辨真伪。
- **配色:** 玉青绿+月光银蓝+狐火青白+九尾多色（绯红花瓣点缀）。
- **姿态参考:** 真身伏地昂首/尾如扇；人形站姿持扇。弱点击破锚点：尾根（9 尾根基）+玉核（眉心/胸口）。

## 图片生成提示词

> Phase 1 — Testing（试探）

```
Nine-Tails Jade Fox, full body, front view, lying poised, massive nine-tailed fox with jade-green fur, moonlight-silver eyes like liquid moon, nine tails fanned out each a different color, elegant predatory posture, curious calm gaze, one tail raised, jade-green and moonlight silver palette, soft luminous fur material, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 2 — Illusion Storm（幻境风暴）

```
Nine-Tails Jade Fox, full body, front view, surrounded by illusion storm, massive jade-green fox with nine tails manifesting nine different illusion energies, translucent shifting realities, jade shimmer in fur, floating foxfire orbs, dreamlike swirling mist, claws raised, jade green and foxfire cyan palette, shimmering fur material, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 3 — Memory Form（记忆之形）

```
Jade-Faced Fox human form, full body, front view, standing, elegant woman in layered jade-green robes, translucent fan partially hiding her face, eyes that never blink, graceful martial arts stance, jade hairpin, sorrowful moonlit beauty, flowing silk robes, jade green and moonlight silver palette, fine silk material, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 真身巨狐 LOD0 ~12k tris / LOD1 ~6k / LOD2 ~3k；人形 LOD0 ~8k / LOD1 ~4k。
- **挂点/Socket:** `weapon_tip`（扇尖法术特效/狐火发射点）、`ExecutionAnchor`（处决）、`GrabProfile`（抓投捕获形状）、尾根挂点 `tail_root_1..9`（九尾独立）、狐火挂点 `foxfire`。
- **弱点击破锚点:** 尾根 `tail_root`（断尾减少尾攻/幻象数）、玉核 `jade_core`（眉心或胸口，真身弱点，可辨幻象本体）。
- **碰撞:** 独立 `CollisionShape3D`：真身躯干胶囊+九尾碰撞（尾扫命中）；人形标准胶囊。
- **贴图:** 2K-4K；Emission：玉核、月光眼眸、狐火；真身毛皮可用半透明/多通道（青玉微光=真身辨识）。
- **骨骼/动画:** 真身四足+9 尾链式多段骨骼（尾扫/尾卷）；人形两足+扇开合；Memory Gaze 过场动画（卧坐、注视、伏地）。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/03-jade-veil/chapter-overview.md`](../chapters/03-jade-veil/chapter-overview.md)、[`../chapters/03-jade-veil/chapter-supplement.md`](../chapters/03-jade-veil/chapter-supplement.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
