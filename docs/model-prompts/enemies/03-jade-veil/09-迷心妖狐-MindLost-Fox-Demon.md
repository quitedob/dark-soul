---
名称: 迷心妖狐（Mind-Lost Fox Demon）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的狂暴人形狐妖
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章九尾迷宫的妖类敌人,在迷宫中迷失自我、丧失神志的狐妖。HP 80、速度 5.5,开场施放粉色"迷心术"弹(使玩家操作反转 4s),随后扑上来疯狂爪击。

## 视觉描述

- **体型/比例:** 约 1.8m 的人形狐妖,身形妖冶而狂野,姿态暴躁,剪影是"龇牙甩尾的狐妖"。
- **服装/甲胄:** 残破的妖裙/披帛,毛茸茸的狐尾 1 至 2 条,衣带散乱。
- **武器/道具:** 无手持武器,攻击为利爪与迷心术弹。
- **标志性特征:** 蓬乱的白红相间毛发,脸戴一道裂开的狐面(或露出的妖异狐脸),爪尖凝聚粉紫色迷心术光球。
- **配色:** 玉青绿 + 绯红狐毛 + 粉紫迷心光 + 烬火橙点缀。
- **姿态参考:** 低俯、亮爪欲扑的狂暴姿态;施法时前爪上托粉色光球。

## 图片生成提示词

```
Mind-Lost Fox Demon, full body, front view, feral lunging stance, wild humanoid fox demon, disheveled white and crimson fur, cracked fox mask, glowing pink confusion magic in raised claw, jade green and pink palette with ember glow, fur and silk materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~7k tris / LOD1 ~3.5k;狐毛用低模毛刺+Alpha 贴图,尾巴单独骨骼。
- **挂点/Socket:** 右爪 `claw_tip`(迷心术投射点),`ExecutionAnchor`(处决锚点)设胸腔。
- **碰撞:** 细胶囊(CapsuleShape3D,半径 0.35,高 1.8)。
- **贴图:** 2K,Alpha 毛须;迷心术光球与爪光用 Emission(粉紫),狐面裂纹用 Roughness 变化。
- **动画/骨骼:** 约 24 根骨骼(含尾);重点是狂暴爪击与施放迷心术两态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
