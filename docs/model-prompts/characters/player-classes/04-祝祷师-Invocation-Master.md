---
名称: 祝祷师（Invocation Master）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/invocation-master.md
---

## 一句话概述

治疗支援型职业(天祝术/佛门因果),以檀香念珠施放慈悲之光照料友方,以往生符纸施业火符叠加业力;可召唤灵符灵体,袈裟 + 僧冠的低直伤高存活定位。

## 视觉描述

- **体型/比例:** 身形温和圆润、身高中等,宽袖袈裟垂坠,剪影柔和内敛。
- **服装/甲胄:** 僧冠(佛冠束发)、袈裟(橙金拼色袈裟,斜披搭肩)、念珠护腕(腕绕念珠)。
- **武器/道具:** 主手檀香念珠(垂挂的一串佛珠,珠粒微光)、副手往生符纸(腰间一叠黄符纸);胸前挂观音玉佩(青玉观音)。
- **标志性特征:** 念珠辉光与符纸漂浮;慈悲之光以柔和金光溢出;胸前轮回印微光。
- **配色:** 主色橙红 + 金色袈裟,辉光烬火橙红 + 柔白金光。
- **姿态参考:** 站姿合掌持珠、符纸漂浮身侧;念珠挂点用于治疗光效。

## 图片生成提示词

```
Invocation Master, full body, front view, standing, monk in orange and gold kasaya robe with monastic crown and bead bracers, holding sandalwood prayer beads and talisman papers, guanyin jade pendant, rebirth seal on chest, red and gold with ember-orange accents, silk and wood materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;念珠与符纸可并入主网格或用低模件。
- **挂点/Socket:** 念珠挂点 + `weapon_tip`(治疗/符弹发射点)、符纸抛出点、`ExecutionAnchor`、`GrabProfile`。
- **碰撞:** 玩家胶囊 ~0.6m 半径 × 1.8m 高;符纸无实体碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;念珠与符纸辉光用 Emission;袈裟用高 Roughness 织物。
- **动画/骨骼:** 标准人形骨架;需合掌/抛符/诵经引导(往生咒)/超度施放姿态。

## 出处

- 设计文档:`docs/characters/classes/invocation-master.md`(链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
