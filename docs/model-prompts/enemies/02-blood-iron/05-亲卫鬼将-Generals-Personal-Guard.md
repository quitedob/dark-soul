---
名称: 亲卫鬼将（General's Personal Guard）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2m 的魁梧精英鬼将人形
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第二章刑天的亲卫鬼将(鬼·精英),保留了比其他失魂更完整的武艺。HP 140、速度 3.5,总是 2-3 人成组,以"侧翼包抄+围杀"的阵型配合;拆散阵型后 AI 会退化。

## 视觉描述

- **体型/比例:** 约 2m 的魁梧人形,比普通鬼卒更高大修长,剪影是"披重甲扛长杆兵器的将军亲卫"。
- **服装/甲胄:** 装饰繁复的将军亲卫甲胄,鎏金包边、肩吞兽首,盔顶带红缨流苏,背插残破战旗。
- **武器/道具:** 重型长杆兵器(偃月刀/长戟),刀身缠着褪色红绸。
- **标志性特征:** 半透明鬼体但轮廓更清晰,甲上刻着刑天军徽,甲缝中泄出烬火橙红辉光。
- **配色:** 幽蓝鬼体 + 血红战旗 + 烬火橙红辉光。
- **姿态参考:** 挺立持戟、侧身掩护的阵型站姿;成组时呈互成犄角的位置。

## 图片生成提示词

```
General's Personal Guard, full body, front view, standing at attention, elite spectral warrior in ornate general's guard armor, plumed helmet, crimson banner cloth, heavy war glaive, tattered war regalia, ghost-blue and blood red palette with ember glow, lacquered iron and silk materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~9k tris / LOD1 ~4.5k,装饰件(缨、旗、吞兽)单独低模件便于复用。
- **挂点/Socket:** 右手 `weapon_tip`(长戟),`ExecutionAnchor`(处决锚点)设胸腔/颈部,背部 `banner_anchor`(战旗)。
- **碰撞:** 躯干胶囊(半径 0.4,高 2.0);阵型站位由 AI 控制。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;鎏金用 Metalness 高值,烬光用 Emission。
- **动画/骨骼:** 约 26 根骨骼;需侧移/包抄/掩护步态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/02-blood-iron/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_2_enemy_factory.gd`
