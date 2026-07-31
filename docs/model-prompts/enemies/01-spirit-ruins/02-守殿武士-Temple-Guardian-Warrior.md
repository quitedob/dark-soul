---
名称: 守殿武士（Temple Guardian Warrior）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.6m 高的非人形石+金属构造体
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第一章灵墟的精英级"精"(活物化的构造体),曾守护神殿内廊的巨石机关,程序已损坏、会攻击一切移动之物。HP 110、速度 2.2,用 1.5s 前摇的重劈横扫,不可弹反。

## 视觉描述

- **体型/比例:** 非人形构造体,约 2.6m 高,厚重方正,剪影是"拄长刀的石像武士"。
- **服装/甲胄:** 风化雕刻的石甲片 + 青铜包边,关节处生锈的金属枢轴,石缝中长着苔藓。
- **武器/道具:** 巨型石质重剑/长刀,与臂部一体或可拆卸。
- **标志性特征:** 全身刻满防御阵法纹路,纹路中流淌烬火橙红辉光;眼窝是两团凝固的橙光。
- **配色:** 灰石 + 铜绿(verdigris)+ 烬火橙红辉光。
- **姿态参考:** 直立持刀守势;1-2 守门廊另有精英变体"守阵石卫"(双盾)可参考此底模。

## 图片生成提示词

```
Temple Guardian Warrior, full body, front view, standing, colossal stone and metal construct in weathered carved temple armor, mossy stone plates with bronze fittings, glowing ember-orange runic lines, heavy stone greatsword, gray stone and verdigris copper palette, carved stone and aged bronze materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~9k tris / LOD1 ~4.5k,大体积用 UnityStyle 拓扑,便于 Blender 修整。
- **挂点/Socket:** 右臂 `weapon_tip`(石刀),`ExecutionAnchor`(处决锚点)设胸口核心,`GrabProfile` 躯干盒;肩部预留可挂盾。
- **碰撞:** 盒碰撞(CapsuleShape3D 或 BoxShape3D,约 0.6×2.4×0.6);Boss/精英建议独立 `CollisionShape3D`。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;阵法纹路与眼窝用 Emission(烬橙)。
- **动画/骨骼:** 约 24 根骨骼(厚重关节旋转);重劈前摇用蓄力曲线,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/01-spirit-awakening/chapter-overview.md`、`../chapters/01-spirit-awakening/chapter-supplement.md`
- 代码挂点:`game/scripts/combat/chapter_1_enemy_factory.gd`
