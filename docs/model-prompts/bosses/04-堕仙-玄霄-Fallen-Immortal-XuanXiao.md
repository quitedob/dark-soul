---
名称: 堕仙·玄霄（Fallen Immortal Xuán Xiāo）
类别: Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.5m（悬浮，约玩家 1.4 倍）
源文档: ../bestiary/bosses-master.md、../chapters/04-celestial-fall/chapter-overview.md、../chapters/04-celestial-fall/chapter-supplement.md
---

## 一句话概述

Ch.4 天崩·陨落 Boss，仙堕（半飞升冻结 500 年）：3 阶段（神性半身 100-60% → 归一 60-30% → 碎裂心智 30-0%）。崩坏天顶平台，嗔念/执念碎片回归、核心残识临时代语。战后选择「完成飞升」或「归还记忆」（`ch4_xuanxiao_fate`），魂器：玄霄残愿。

## 视觉描述

- **体型/比例:** 人形悬浮约 2.5m，冻结于飞升瞬间；右半圣光、左半腐朽，对半分裂剪影。
- **服装/甲胄:** 高修者云纹白绸道袍，右半圣洁白绸明亮、左半腐坏染污破损。
- **武器/道具:** 玄霄·陨星法剑（法术剑）；三道意识碎片环绕：嗔念（赤红）、执念（幽蓝）、核心（白）。
- **标志性特征:** 半身光/半身腐的对半剪影、三道环绕碎片、冻结飞升姿态（抬手持咒）。
- **配色:** 白绸圣光（炽白）+腐朽（灰绿棕）+烬橙余烬。
- **姿态参考:** 悬浮/盘坐结印。弱点击破锚点：光腐融合核心（Phase 2 归一后胸口融合核心）。

## 图片生成提示词

> Phase 1 — Divine and Fallen（神堕二元）

```
Fallen Immortal Xuan Xiao, full body, front view, floating, half-transformed ascendant figure, right half blazing divine white light, left half rotting decaying flesh, cloud-pattern white silk daoist robe stained and torn, frozen mid-ascension, raised hand conjuring celestial light, holy white and decayed green-brown palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 2 — Reunification（归一）

```
Fallen Immortal Xuan Xiao, full body, front view, floating, divine light half and rotting half merged into one body, alternating radiant and decayed energy, fused light-rot core glowing on chest, swirling cloud-pattern silk robe half luminous half withered, three fragment wisps orbiting, holy white and decayed palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 3 — Fragmented Mind（碎裂心智）

```
Fallen Immortal Xuan Xiao, full body, front view, dissolving into storm of three consciousnesses, body splitting into shards of light and decay, wrath fragment burning red glow, obsession fragment blue glow, core fragment white glow, torn ascension robe shredded, fragmented mind chaos, red blue and white glow palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~10k tris / LOD1 ~5k / LOD2 ~2.5k。
- **挂点/Socket:** `weapon_tip`（法剑特效）、`ExecutionAnchor`（处决）、`GrabProfile`（抓投捕获形状）、碎片环绕挂点 `fragment_orbit_1..3`（嗔念/执念/核心）、手印挂点。
- **弱点击破锚点:** 光腐融合核心 `fused_core`（Phase 2/3 胸口，破核有晕眩窗）。
- **碰撞:** 独立 `CollisionShape3D` 胶囊；半身圣光/腐化可加装饰 `Area3D`（Decay Pulse 被动圈）。
- **贴图:** 2K-4K；Emission：圣光半身、融合核心、三道碎片（红/蓝/白各一通道或三组）。
- **骨骼/动画:** 人形悬浮骨架；悬浮 idle、Celestial Beam/Light Spear、Decay Pulse、Half-Step 光解瞬移；Phase 3 三种人格姿态切换（嗔念=狂暴冲拳、执念=结印诵经、核心=均衡剑术）。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/04-celestial-fall/chapter-overview.md`](../chapters/04-celestial-fall/chapter-overview.md)、[`../chapters/04-celestial-fall/chapter-supplement.md`](../chapters/04-celestial-fall/chapter-supplement.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
