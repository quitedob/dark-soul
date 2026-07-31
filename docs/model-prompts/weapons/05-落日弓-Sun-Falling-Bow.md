---
名称: 落日弓（Sun-Falling Bow）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 全长约 1.6m(相对 1.8m 玩家),为长弓中的巨物
源文档: ../../systems/weapons-compendium.md
---

## 一句话概述

> 传奇武器(后羿射日传说),需跨五章收集 5 碎片;落日金辉长弓,弓身裂痕续燃烬火,蓄力射击生成"小太阳"AoE 火伤。

## 视觉描述

- **造型:** 巨型反曲长弓,弓臂粗壮、向两端回卷成金乌衔日式钩梢;弓臂中部有一道纵向裂痕——裂痕中透出炽亮烬火,仿佛太阳正从裂缝中坠落。弓臂刻放射状日晖纹,两端各嵌一枚小日盘饰。
- **材质:** 鎏金铁 + 深色骨木复合;弓弦为赤红火丝;日盘为铜鎏金。
- **辉光:** 裂痕内烬火橙红炽亮(Emission 高),日晖纹泛暖金;整弓有"落日余晖"的暖光氛围。
- **尺寸:** 全长约 1.6m,宽约 1.0m。
- **握持方式:** 左手持弓把(手部挂点),右手拉弦;施放时裂痕喷出火星。

## 图片生成提示词

```
A legendary longbow, front view, floating diagonally. A massive golden sun-imbued bow with fiery red string, glowing ember cracks running across the body, small sun-disc ornaments at limb tips, rays etched down the arms, golden heat shimmer.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2.5k tris;LOD1 ~1.2k。
- **挂点/Socket:** `weapon_tip` 置于弓梢前上方(太阳弹丸/AoE 特效);握把手部挂点;碰撞用细长盒。
- **贴图:** 4K(传奇品质);鎏金高金属低粗糙,裂痕用 Emission 叠加(暖橙,multiplier 高);日晖纹可走 Normal/Emissive 双通道。
- **动画:** 拉弦位移幅度更大(蓄力阶段),裂痕辉光随蓄力渐亮;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/systems/weapons-compendium.md`(Legendary: Sun-Falling Bow)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`bow` shape_id,替换材质)
