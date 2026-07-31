---
名称: 玄霄·执念（Obsession Fragment）
类别: 子Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.2m（相对玩家约 1.2 倍）
源文档: ../bestiary/bosses-master.md、../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

Ch.4 4-5 执念台 子 Boss：玄霄第二道人格碎片，纯防御与仪式（召唤灵卫/激活机关/防御屏障）。蓝辉光+诵经，蓝纹法袍人形。战斗发生在完美保存的修炼密室；击败后揭示玄霄为救逝去所爱而放弃飞升的历史，并得执念护符；HP 不并入主 Boss 池。

## 视觉描述

- **体型/比例:** 人形约 2.2m，低眉垂目、瘦削端立，仪态沉静。
- **服装/甲胄:** 蓝纹法袍（玄霄道袍另一碎片），袍面绣道家符文、幽蓝微光流转。
- **武器/道具:** 无实体武器；手持符咒/法印（结印施法）。
- **标志性特征:** 幽蓝辉光、诵经唇动、环绕蓝光法阵/屏障、悬浮符箓与咒印。
- **配色:** 幽蓝+青白+烬橙点缀。
- **姿态参考:** 端立/盘坐结印。单阶段，无设计弱点击破。

## 图片生成提示词

```
Obsession Fragment, full body, front view, standing meditative, humanoid figure in indigo-blue daoist robe with glowing arcane talisman patterns, chanting with closed eyes, hands forming ritual seals, blue magic barrier circle glowing beneath, floating talisman charms orbiting, calm serene expression, deep blue and pale cyan palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 子 Boss：LOD0 ~6k tris / LOD1 ~3k。
- **挂点/Socket:** `weapon_tip`（法印特效/召唤发射点）、`ExecutionAnchor`（处决）、`GrabProfile`（抓投捕获形状）、手印挂点 `seal_l/seal_r`、法阵挂点 `barrier_root`。
- **弱点击破锚点:** 非主 Boss、设计文档无弱点击破；可选屏障核心 `barrier_core`（破屏打断召唤）作为额外锚点。
- **碰撞:** 独立 `CollisionShape3D` 胶囊；屏障可用 `Area3D`（阻挡判定）。
- **贴图:** 2K；Emission：蓝纹法袍、符箓、法阵、咒印。
- **骨骼/动画:** 人形骨架；结印、诵经、Spirit Summon 召唤、Ritual Trap 激活、Defensive Barrier 施放、缓慢踱步。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/04-celestial-fall/chapter-overview.md`](../chapters/04-celestial-fall/chapter-overview.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
