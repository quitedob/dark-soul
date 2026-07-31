---
名称: 五行法印（Five Elements Seal）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 印面直径约 0.4m,五行环整体约 0.8m
源文档: ../../systems/weapons-compendium.md
---

## 一句话概述

> 传奇武器(玄法师),跨五章收集 5 碎片;五行齐转的八卦法印,可同时共鸣五元素,切换元素不丢失旧元素增益。

## 视觉描述

- **造型:** 圆形八卦青铜镜印,印面外圈八卦纹、内圈双鱼(阴阳)旋核;五枚元素符(火/水/木/金/土)绕印面悬停转动,符形为古篆单字;印背嵌圆玉。
- **材质:** 青铜(包浆氧化)+ 玉 + 符纸/琉璃元素珠。
- **辉光:** 双鱼核泛烬火橙红,五元素珠各带本色微光(火红/水青/木绿/金白/土褐),整印如五行转盘。
- **尺寸:** 印面直径约 0.4m,五行环绕环直径约 0.8m。
- **握持方式:** 单手持印(手部挂点于印背),印面朝前,五行环匀速公转。

## 图片生成提示词

```
A single legendary spell seal prop, front view, levitating upright. A round eight-trigram bronze mirror-seal with a central yin-yang core, five glowing elemental symbols orbiting around it, rotating paper talismans, layered ember-orange energy rings, jade inlay.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3k tris(印体 + 八卦纹 + 5 元素 + 双鱼);LOD1 ~1.5k。
- **挂点/Socket:** `weapon_tip` 置于印面前方(施法特效);手部挂点于印背;五行环为子节点环形旋转,元素珠逐一挂点。
- **碰撞:** 印体盒碰撞;元素环无碰撞。
- **贴图:** 4K;八卦纹走 Normal + Emission,双鱼核 Emission(橙红);五元素珠自发光 + 半透明。
- **动画:** 双鱼缓旋、五行环公转、施法时符文明灭;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/systems/weapons-compendium.md`(Legendary: Five Elements Seal)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`staff_seal` shape_id,替换材质)
