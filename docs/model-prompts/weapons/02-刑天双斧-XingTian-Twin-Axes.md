---
名称: 刑天双斧（Xing Tian Twin Axes）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 单斧全长约 0.95m,双斧横持时斧刃宽约 1.1m
源文档: ../../systems/weapons-compendium.md
---

## 一句话概述

> 狂战士初始武器,双持战斧,斧面刻赤红刑天纹;STR C 加成,基础伤害 26,双斧连击架势高。

## 视觉描述

- **造型:** 一对互为镜像的战斧——直柄、单刃宽斧面 + 斧背短尖;斧面两侧刻粗犷的刑天纹(无头神纹/盾形回纹),斧柄末端带一节锁链与铁环。
- **材质:** 旧铁(斧刃磨亮、斧身氧化发暗)+ 深色缠绳木柄;赤红纹路为烧蚀嵌入的铜线/朱砂。
- **辉光:** 纹路内透出极淡的烬火橙红,如余烬在刻痕中游走。
- **尺寸:** 单斧全长约 0.95m,斧面宽约 0.4m;双手各持一斧。
- **握持方式:** 左右手各握一柄(手部挂点),斧柄末端锁链垂下作为装饰摆动。

## 图片生成提示词

```
A pair of twin battle axes, front view, crossed diagonally. Two matching heavy war axes with dark iron blades and scarred wood handles, crimson ritual tattoo lines carved into each blade face, chained pommels, dim ember fire glow tracing the grooves.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2k tris(两斧合计);LOD1 ~1k。
- **挂点/Socket:** `weapon_tip` 分别置于左右斧刃前缘(劈砍特效);左右手部挂点各一;碰撞用每斧一根细盒 + 斧面薄盒。
- **贴图:** 2K;斧刃高金属低粗糙,斧身锈蚀用粗糙度噪声;赤红纹路走 Emission(低能量)。
- **动画:** 双斧摆动时锁链/铁环为次级绑定可摆动;斧柄握持处保持现有姿势挂点。

## 出处

- 设计文档:`docs/systems/weapons-compendium.md`(狂战士起始武器)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`axe_right` / `axe_left` shape_id)
