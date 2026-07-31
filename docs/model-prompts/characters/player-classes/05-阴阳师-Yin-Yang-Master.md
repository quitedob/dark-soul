---
名称: 阴阳师（Yin-Yang Master）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/README.md
---

## 一句话概述

玄法师 + 祝祷师的混合职业(第三章后解锁),一手五行毁灭、一手慈悲治疗,在道门法印与佛门念珠之间切换;道袍与袈裟熔铸为一件阴阳相济的法衣。

## 视觉描述

- **体型/比例:** 清瘦颀长、身高中等偏上,融合道袍宽袖与袈裟垂坠,剪影左右不对称。
- **服装/甲胄:** 半黑玄色道袍 + 半橙金袈裟熔铸为一(中线阴阳分界),道士冠混入佛冠元素,腰间阴阳鱼束带。
- **武器/道具:** 主手玄门法印外缠一串念珠(道法 + 佛珠复合法器)、副手灵石 + 往生符纸;胸前挂五行八卦镜与观音玉佩并置。
- **标志性特征:** 法衣左右两半的阴阳辉光;法印与念珠同旋;胸前轮回印微光。
- **配色:** 主色玄黑对橙金,辉光烬火橙红 + 冷暖双色法术光。
- **姿态参考:** 站姿一手结印、一手合掌,法印与念珠分悬两掌前。

## 图片生成提示词

```
Yin-Yang Master, full body, front view, standing, figure in robe half black daoist silk and half gold kasaya, yin-yang sash, floating spell seal wrapped with prayer beads, talisman papers, faint rebirth seal on chest, black and gold with ember-orange accents, silk and brocade materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;法印/念珠/灵石为独立浮动件。
- **挂点/Socket:** 法印悬浮挂点 + `weapon_tip`(法术/治疗发射点)、双手施法挂点、`ExecutionAnchor`、`GrabProfile`。
- **碰撞:** 玩家胶囊 ~0.6m 半径 × 1.8m 高。
- **贴图:** 2K Base/Normal/Roughness/Metalness;法衣阴阳分界用无缝接缝材质,辉光用 Emission。
- **动画/骨骼:** 标准人形骨架;需同时表现结印与合掌两套施法姿势,法印/念珠各自自旋。

## 出处

- 设计文档:`docs/characters/classes/README.md`(混合职业表,链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
