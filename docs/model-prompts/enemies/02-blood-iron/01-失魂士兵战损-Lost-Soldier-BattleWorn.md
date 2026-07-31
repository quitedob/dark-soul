---
名称: 失魂士兵·战损（Lost Soldier — Battle-Worn）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m(与玩家等高的普通人形)
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第二章铁啸关的失魂士兵战损变体,死于铁啸关无尽战事的战士,盔甲比第一章更完整、攻势更凶。HP 80、速度 3.0,50% 血量时会冲刺,并会佯装撤退再回身攻击。

## 视觉描述

- **体型/比例:** 与玩家等高的标准人形,比第一章士兵更壮实挺拔,剪影是"挺矛冲锋的明代士兵"。
- **服装/甲胄:** 更完整的明代制式战甲,甲片拼接整齐、血迹斑斑,肩披残破的战旗布条。
- **武器/道具:** 铁制长矛(或长刀),矛尖带锈与干涸血迹。
- **标志性特征:** 半透明游魂体 + 战伤裂口处泄出烬火橙红辉光,眼窝两点幽蓝鬼火;铠甲上刻满战损刮痕。
- **配色:** 幽蓝游魂 + 血锈红 + 烬火橙红辉光。
- **姿态参考:** 持矛前冲的进攻姿态,区别于第一章的垂剑姿态;佯退-回马枪需预留转身动画。

## 图片生成提示词

```
Lost Soldier Battle-Worn, full body, front view, charging stance, vengeful spectral soldier in more intact Ming-style battle armor, blood-stained steel plates, torn war-banner scarf, rusted iron spear, ghost-blue and blood red palette with ember glow, weathered steel and stained cloth materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~7k tris / LOD1 ~3.5k,可在第一章士兵模型基础上加甲片复用。
- **挂点/Socket:** 右手 `weapon_tip`(长矛),`ExecutionAnchor`(处决锚点)设胸腔,`GrabProfile` 躯干胶囊。
- **碰撞:** 单胶囊(CapsuleShape3D,半径 0.35,高 1.8)。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;战损刮痕用 Roughness/Metalness 贴图,烬光用 Emission。
- **动画/骨骼:** 约 22 根骨骼;复用第一章骨骼+冲刺/佯退动画,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/02-blood-iron/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_2_enemy_factory.gd`
