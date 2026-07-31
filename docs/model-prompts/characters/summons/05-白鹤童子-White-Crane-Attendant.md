---
名称: 白鹤童子（White Crane Attendant）
类别: 召唤物
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.2m(悬浮童子灵体)
源文档: ../characters/classes/invocation-master.md
---

## 一句话概述

祝祷师以白鹤灵符召唤的羽化童子,仙道鹤童意象;可在空中飞行、以风系羽刃远程攻击,存活期间为主人提升 Focus 回复 +50%,是飞行辅助型召唤物。

## 视觉描述

- **体型/比例:** 娇小轻盈的童子灵体,背生鹤翼、身周浮羽,剪影如白鹤掠空。
- **服装/甲胄:** 雪白羽衣 + 轻袍,发顶扎鹤羽髻,腰系飘带。
- **武器/道具:** 手持一枚羽扇(扇缘凝风刃);身侧环绕回旋的风羽。
- **标志性特征:** 鹤翼纯白透光;挥扇时划出青色风旋;脚下有微小气流托举。
- **配色:** 主色雪白 + 浅青,辉光烬火橙红 + 风青辉光。
- **姿态参考:** 悬空展翼、持扇作抛射状,轻盈灵动。

## 图片生成提示词

```
White Crane Attendant, full body, front view, hovering, graceful small spirit attendant with white crane wings and feather robes, gentle childlike face, glowing wind currents circling, ember glow, snow white and pale blue with ember-orange accents, feathers and luminous wind materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k;羽扇为独立道具件,鹤翼可为半透明羽片。
- **挂点/Socket:** 召唤根节点(悬浮点)、羽扇手部挂点 + 扇缘 `weapon_tip`(风刃弹发射点)。
- **碰撞:** 淡胶囊 ~0.4m 半径 × 1.2m 高;飞行单位以悬浮点离地浮动。
- **贴图:** 2K Base/Normal/Roughness;鹤羽用半透明 + 自发光边缘,风旋用 Emission。
- **动画/骨骼:** 简化人形骨架 + 独立翼骨;需悬空展翅/挥扇/盘旋/被击退循环。

## 出处

- 设计文档:`docs/characters/classes/invocation-master.md`(灵符召唤表,链接)
- 代码挂点:`game/scripts/enemy_factory.gd`(召唤物工厂参照)
