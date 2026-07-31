---
名称: 玄霄·嗔念（Wrath Fragment）
类别: 子Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.2m（相对玩家约 1.2 倍）
源文档: ../bestiary/bosses-master.md、../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

Ch.4 4-4 嗔念台 子 Boss：玄霄第一道人格碎片，纯攻击无防御（冲拳/狂怒 5 连击/裂地砸拳）。赤红辉光+咆哮，赤红修袍人形，拳击。击败后该碎片平息并得嗔念之拳；HP 不并入主 Boss 池。

## 视觉描述

- **体型/比例:** 人形约 2.2m，宽肩怒躯、怒目横眉，战斗姿态前倾。
- **服装/甲胄:** 赤红修袍（玄霄道袍的碎片人格），袍角飘忽、边缘燃起红炎。
- **武器/道具:** 裸拳；巨大赤红拳套光效（无实体武器）。
- **标志性特征:** 赤红辉光全身燃烧、愤怒咆哮的面部、拳上红炎升腾。
- **配色:** 赤红+烬橙+焦黑。
- **姿态参考:** 站立怒冲姿态（倾身出拳）。单阶段，无设计弱点击破。

## 图片生成提示词

```
Wrath Fragment, full body, front view, aggressive stance, humanoid figure in crimson daoist robe burning with red fire, furious roaring face, bare fists wreathed in blazing ember-red flames, hunched rushing posture, red robe torn, charred black and crimson ember palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 子 Boss：LOD0 ~6k tris / LOD1 ~3k。
- **挂点/Socket:** `weapon_tip`（拳光特效）、`ExecutionAnchor`（处决）、`GrabProfile`（抓投捕获形状）、左右拳 `hand_l/hand_r`。
- **弱点击破锚点:** 非主 Boss、设计文档无弱点击破；可选拳部破坏（破拳减攻）作为额外锚点。
- **碰撞:** 独立 `CollisionShape3D` 胶囊。
- **贴图:** 2K；Base/Normal/Roughness/Metalness；赤红袍纹、拳上红炎用 Emission。
- **骨骼/动画:** 人形骨架；Rushing Fist、Fury Combo（5 连击）、Ground Shatter、狂暴 idle/咆哮。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/04-celestial-fall/chapter-overview.md`](../chapters/04-celestial-fall/chapter-overview.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
