---
名称: 玄法师（Mystic Mage）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/mystic-mage.md
---

## 一句话概述

极脆的五行术输出法师(玄门道法),以漂浮法印投射五行元素弹与法阵控场;道士冠 + 玄色道袍,依靠瞬移与法盾保命,五行八卦镜增幅元素伤害。

## 视觉描述

- **体型/比例:** 清瘦颀长、身高中等偏上,道袍宽袖遮身形,剪影修长飘逸。
- **服装/甲胄:** 道士冠(高冠束发)、玄色道袍(多层黑绸道袍,绣八卦纹)、结印手套(露指黑手套,指节绘符)。
- **武器/道具:** 主手玄门法印(漂浮旋转的符文法印,五行符箓环绕)、副手灵石(腰间悬浮的发光灵石);胸前挂五行八卦镜(圆镜配五行爻)。
- **标志性特征:** 法印漂浮旋转的五行辉光;道袍暗纹符箓微光;胸前轮回印微光。
- **配色:** 主色玄黑 + 金色符纹,辉光烬火橙红 + 五行各色微光。
- **姿态参考:** 站姿单手结印、法印悬于掌心前;法印 pivot 用于法术投射方向。

## 图片生成提示词

```
Mystic Mage, full body, front view, standing, cultivator in layered black daoist robe and high daoist crown, floating glowing spell seal before open palm, spirit stone, bagua mirror, faint rebirth seal on chest, ink black and gold with ember-orange accents, silk and jade materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;法印与灵石为独立浮动件(空中 pivot,勿并入主网格烘焙)。
- **挂点/Socket:** 法印悬浮挂点 + `weapon_tip`(法术弹发射点)、右手结印挂点、`ExecutionAnchor`、`GrabProfile`。
- **碰撞:** 玩家胶囊略小 ~0.55m 半径 × 1.8m(脆皮);法印无实体碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;法印符文与五行环用 Emission;道袍暗纹用贴花。
- **动画/骨骼:** 标准人形骨架;需结印/抬手施法/瞬移(短距离闪烁)/法盾姿态;法印自身可加缓慢自旋动画。

## 出处

- 设计文档:`docs/characters/classes/mystic-mage.md`(链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
