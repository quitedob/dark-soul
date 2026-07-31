---
名称: 护法灵童（Dharma-Protecting Child Spirit）
类别: 召唤物
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 0.9m(孩童灵体)
源文档: ../characters/classes/invocation-master.md
---

## 一句话概述

祝祷师以护法灵符召唤的孩童灵体,佛门护法童子;脆皮但专职嘲讽、吸引敌火,为主人拉扯仇恨,是前排替身型召唤物。

## 视觉描述

- **体型/比例:** 娇小的孩童灵体,身量约为玩家一半,圆脸肉乎,剪影圆润可爱却目光凛然。
- **服装/甲胄:** 红金护法小袍(斜披),项挂莲瓣项圈,腕绕红绳,赤足。
- **武器/道具:** 一手持法轮(转经轮)、一手摇小金刚铃;腰间垂红穗。
- **标志性特征:** 周身萦绕淡淡的护法金光与烬火辉光;法轮转动时飘出微尘;眼神天真又认真。
- **配色:** 主色金 + 朱砂红,辉光烬火橙红 + 金光。
- **姿态参考:** 悬空稍离地,举轮摇铃、一脸"看这边"的挑衅神态。

## 图片生成提示词

```
Dharma Protecting Child Spirit, full body, front view, standing, small glowing spirit child with innocent face and fierce eyes, red and gold dharma robes, dharma wheel and hand bell, tassels, ember glow, gold and cinnabar red with ember-orange accents, silk and ethereal light materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k(召唤物尺寸小,细节以剪影与辉光为主)。
- **挂点/Socket:** 召唤根节点(脚下悬浮)、法轮手部挂点 + 轮心 `weapon_tip`(嘲讽光环特效)。
- **碰撞:** 胶囊 ~0.3m 半径 × 0.9m 高;随召唤持续存在,驱散时淡出。
- **贴图:** 2K Base/Normal/Roughness;护法金光用 Emission + 半透明边缘光。
- **动画/骨骼:** 简化人形骨架;需悬浮/举轮/摇铃/被击溃散(消失)循环。

## 出处

- 设计文档:`docs/characters/classes/invocation-master.md`(灵符召唤表,链接)
- 代码挂点:`game/scripts/enemy_factory.gd`(召唤物工厂参照)
