---
名称: 九尾·幻月（Nine-Tails · Illusion Moon）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 扇面展开宽约 0.6m,合拢长约 0.4m
源文档: ../../bestiary/bosses-master.md
---

## 一句话概述

> 传奇 Boss 锻造武器(第 3 章九尾);九尾扇法印,扇面幻月流光;施法生成幻影分身延迟复施同一法术(幻月之舞)。

## 视觉描述

- **造型:** 玉骨折扇,扇面展开如满月,上绘九尾狐尾纹与幻月(半轮月 + 流动光带);扇骨尾端系九色丝绦(九尾九色);扇心嵌一枚小玉镜,映出朦胧流光。
- **材质:** 白玉扇骨 + 绢面(泛珍珠光)+ 金粉勾线 + 玉镜。
- **辉光:** 幻月与流光泛月光银蓝 + 烬火橙红相间;玉镜微泛青白。
- **尺寸:** 展开宽约 0.6m,合拢长约 0.4m。
- **握持方式:** 单手持扇(手部挂点于扇根),施法时扇面半开、流光随指尖游走。

## 图片生成提示词

```
A single legendary folding fan spell focus, front view, floating upright half-open. White jade fan ribs and silk face painted with nine fox-tail patterns and a crescent moon, flowing moonlit light streaks, nine-colored tassels at the base, tiny jade mirror center, ember and silver glow.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2.5k tris(扇骨 + 扇面 + 丝绦);LOD1 ~1.2k。
- **挂点/Socket:** `weapon_tip` 置于扇面前方(幻影分身/幻月特效);手部挂点于扇根;丝绦为次级绑定可摆动。
- **碰撞:** 扇合拢时细盒,展开时薄盒(两套碰撞或统一按展开)。
- **贴图:** 4K;绢面半透明 + 幻月 Emission(月光银蓝 + 烬橙),玉骨半透;九色丝绦各带微光。
- **动画:** 扇面开合(施法时张合)、流光沿扇面流动、丝绦摆动;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/bestiary/bosses-master.md`(九尾 · Boss Weapon)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`fox_fan` shape_id,替换材质)
