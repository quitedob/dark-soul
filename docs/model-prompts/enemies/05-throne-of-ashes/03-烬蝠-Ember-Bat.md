---
名称: 烬蝠（Ember Bat）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 翼展约 0.8m,躯干 0.4m
源文档: ../bestiary/enemies-master.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

妖类群聚飞行怪,5-2/5-3 由冷却烬灰凝成的蝙蝠,可攀附**任意表面**(地板/墙壁/天花板)并从任何角度袭击。AI 4–7 只群起包围;血量 35、伤害 16、机动 9.0,冰属 +30%、火属 -40%。

## 视觉描述

- **体型/比例:** 非人形小型蝙蝠,翼展约 0.8m,躯干约 0.4m;体型小、数量多,剪影是一团飞灰。
- **服装/甲胄:** 无甲胄;体表为凝聚的烬灰,粗糙颗粒感,带焦黑质地。
- **武器/道具:** 无;利齿与翼膜边缘即攻击部位。
- **标志性特征:** 翼膜半透明,烬火橙红纹路在翼脉间流动;攀附时足爪抓壁、倒挂如灰烬结壳。
- **配色:** 烬灰黑为主,翼脉烬橙辉光;星辉蓝黑背景衬托。
- **姿态参考:** 正面展翼悬停(对称);攀附姿态作收翼挂壁,与悬停形成对比。

## 图片生成提示词

```
Ember Bat, full body, front view, hovering, small bat formed from cooled grey ash, leathery translucent wings with glowing ember-orange vein cracks, tiny glowing ember eyes, ash crumb flakes drifting off body, soot black and ember orange color palette, cinder and membrane materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 1.5k tris / LOD1 0.8k;群战单位面数从简,翼膜用半透明面片。
- **挂点/Socket:** 口部 `weapon_tip`(叮咬判定);翼尖 `wing_tip`(拖尾粒子)。
- **碰撞:** 盒碰撞(0.4m × 0.3m × 0.6m);攀附状态用 `surface_normal` 附着,旋转对齐墙面/天花板。
- **贴图:** 1K Base/Normal/Roughness + Alpha(翼膜);翼脉烬火用 Emission。
- **动画/骨骼:** 轻骨架(躯干 + 双翼 4 骨);悬停扑翅 + 攀附收翼两态,支持四向表面附着。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 5 烬蝠)、`../chapters/05-throne-of-ashes/chapter-overview.md`(5-2/5-3)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `wing_tip` 命名
