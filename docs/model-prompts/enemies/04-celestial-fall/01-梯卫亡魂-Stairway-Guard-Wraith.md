---
名称: 梯卫亡魂（Stairway Guard Wraith）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.0m,略高于玩家
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

失魂类小怪,镇守 4-1 登天梯的破碎石阶。AI 以宽幅横扫为主、高击退优先于伤害,目的是把玩家推下浮空平台边缘;血量 100、伤害 20、机动 2.5,雷属 +20%。

## 视觉描述

- **体型/比例:** 近人形、约 2.0m,明显比玩家高出一头,轮廓厚重以强调"站桩守卫、不可撼动"的剪影。
- **服装/甲胄:** 残破的银白明光铠,肩甲破损露出内衬、下摆甲片碎裂飘散,是"登天未成而坠落"的亡者。
- **武器/道具:** 一面宽大的塔盾与一杆长戟,常以横持/大架姿态示意横扫击退。
- **标志性特征:** 半透明残躯,体表泛魂光,双目与甲缝透出烬火橙红微光;持械横扫时甲片会化作细碎光屑。
- **配色:** 银白锈甲 + 冷蓝魂光,辉光用烬火橙红点缀;天空背景为永恒夕阳(金红→暗紫)。
- **姿态参考:** 正面站立、持盾横戟的防守起手式;击退动画应让重心后移、横臂前推。

## 图片生成提示词

```
Stairway Guard Wraith, full body, front view, standing, translucent phantom soldier in tattered white-gold celestial armor with broken shoulder plates, spectral wisp trail, tower shield and long halberd held in wide defensive stance, ember-orange eye glow, sunset gold and cold spirit-blue color palette, ethereal cloth and rusted metal materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 6k tris / LOD1 3k;塔盾 500 tris,长戟 400 tris。
- **挂点/Socket:** 右手 `weapon_tip`(长戟特效/击退冲击波锚点);`GrabProfile` 圆柱形(供抓投捕获形状用)。
- **碰撞:** 胶囊(Capsule 0.4m × 1.9m,高约 2.0m);塔盾可加矩形盒 `CollisionShape3D`。
- **贴图:** 2K Base/Normal/Roughness/Metalness;残躯半透明走 Alpha;魂光与烬火用 Emission(Additive)。
- **动画/骨骼:** 单人形骨架(40 骨),命名沿用 `character_meshes.gd` 姿势挂点;横扫为两段 windup→active→recovery。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 梯卫亡魂)、`../chapters/04-celestial-fall/chapter-overview.md`(4-1 登天梯)
- 代码挂点:替换 `enemy_factory.gd` 中的程序化占位时,保持 `weapon_tip` / `GrabProfile` 命名
