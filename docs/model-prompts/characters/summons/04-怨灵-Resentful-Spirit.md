---
名称: 怨灵（Resentful Spirit）
类别: 召唤物
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.7m(半透明怨鬼)
源文档: ../characters/classes/invocation-master.md
---

## 一句话概述

祝祷师以怨灵灵符召唤的复仇之鬼,玻璃大炮型召唤物;攻击附带业力叠加,输出高但极脆,为主人快速挂满业债、放大后续超度伤害。

## 视觉描述

- **体型/比例:** 颀长的怨鬼灵体,身形飘忽无足,长发垂覆,剪影瘦削幽怨。
- **服装/甲胄:** 褴褛苍白寿衣(衣角腐破),半透明鬼体透出暗红脉络。
- **武器/道具:** 无手持武器——以一双枯爪施怨;周身缠绕业火黑丝(化为鞭状挥击)。
- **标志性特征:** 低垂的脸庞只露出流血的泣眼;业火黑丝如蛇缠绕;哭嚎时鬼体震颤。
- **配色:** 主色暗灰 + 深红,辉光烬火橙红 + 业火赤黑。
- **姿态参考:** 悬浮低泣、双手前探作索命状,衣摆下垂如幕。

## 图片生成提示词

```
Resentful Spirit, full body, front view, standing, spectral vengeful ghost with pale tattered robes and long loose black hair, weeping red eyes, dark karma wisps curling around, faint ember glow, ash gray and deep red with ember-orange accents, translucent spirit and dark mist materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k;无实体武器件。
- **挂点/Socket:** 召唤根节点(脚下悬浮)、双手 `weapon_tip`(业火鞭挥击特效原点)。
- **碰撞:** 淡胶囊 ~0.4m 半径 × 1.7m 高;极脆低血,受击即颤。
- **贴图:** 2K Base/Normal/Roughness;鬼体用半透明 + 暗红脉络细节,业火黑丝用 Emission。
- **动画/骨骼:** 简化人形骨架;需悬浮前飘/挥爪/哭嚎/溃散消失循环。

## 出处

- 设计文档:`docs/characters/classes/invocation-master.md`(灵符召唤表,链接)
- 代码挂点:`game/scripts/enemy_factory.gd`(召唤物工厂参照)
