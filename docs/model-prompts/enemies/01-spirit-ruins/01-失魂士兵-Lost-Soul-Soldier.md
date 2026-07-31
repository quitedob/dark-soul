---
名称: 失魂士兵（Lost Soul Soldier）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m(与玩家等高的普通人形)
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第一章灵墟的基本小怪,失魂(残破甲胄的游魂),死于奔赴天炉之途的士兵,佩戴遗忘王国的徽记。HP 60、速度 2.8,绕小圈巡逻,用缓慢、前摇明显的剑击攻击。

## 视觉描述

- **体型/比例:** 与玩家等高的标准人形,略瘦削佝偻,剪影是"戴盔持剑的士兵"。
- **服装/甲胄:** 残破的汉代制式甲胄,胸前残存遗忘王国的褪色徽记,甲片缺损、布条飘垂。
- **武器/道具:** 单手短剑,锈迹斑斑,无护手或护手破损。
- **标志性特征:** 半透明游魂体,关节处泄出烬火橙红微光,眼窝两点幽蓝鬼火。
- **配色:** 幽蓝游魂 + 灰烬灰 + 烬火橙红辉光。
- **姿态参考:** 持剑自然垂立、缓慢拔剑蓄力姿态;弱点击破无特殊锚点(普通小怪)。

## 图片生成提示词

```
Lost Soul Soldier, full body, front view, standing, gaunt spectral soldier in tattered armor with a faded forgotten-kingdom insignia, translucent wispy body, ember-orange glow leaking from joints, rusty short sword, ghost-blue and ash gray palette, worn metal and rotted cloth materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~6k tris / LOD1 ~3k,半透明体用 fadeshader 或 AlphaScissor。
- **挂点/Socket:** 右手 `weapon_tip`(持剑),`ExecutionAnchor`(处决锚点)设在胸腔,`GrabProfile` 若做抓投则用躯干胶囊。
- **碰撞:** 单胶囊(CapsuleShape3D,半径 0.35,高 1.8)。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;关节烬光用 Emission,游魂半透明用 Alpha。
- **动画/骨骼:** 约 20 根骨骼(四肢+脊柱+头+持剑手);保持 `character_meshes.gd`/`enemy_factory.gd` 现有命名与姿态挂点。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/01-spirit-awakening/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_1_enemy_factory.gd`
