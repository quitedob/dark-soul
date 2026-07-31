---
名称: 刑天·不屈（Xing Tian · Indomitable）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 单斧全长约 1.15m,双斧横持宽约 1.3m
源文档: ../../bestiary/bosses-master.md
---

## 一句话概述

> 传奇 Boss 锻造武器(第 2 章刑天);刑天双斧·不屈,斧面赤红纹身如血脉跳动;被动"不屈之魂"——致死攻击改为 1 HP 存活并获 3s 无敌。

## 视觉描述

- **造型:** 一对巨型双斧,斧面布满赤红仪式纹身(犄角/獠牙/回纹),纹路粗如血管、随斧体有"脉动"暗示;斧背短刺,斧柄粗直,柄末端缠绕断裂的灵锁链残段与铁环。
- **材质:** 烧蚀黑铁 + 赤铜嵌线(纹身)+ 缠皮柄;表面有长期劈砍留下的豁口与熔灼痕。
- **辉光:** 赤红纹身透出炽烈烬火橙红(Emission 中高),如刑天胸口之眼的余怒;锁链残段泛幽蓝灵光点缀。
- **尺寸:** 单斧约 1.15m,斧面宽约 0.5m。
- **握持方式:** 左右手各持一斧(手部挂点),斧柄末端锁链随挥动摆动。

## 图片生成提示词

```
A pair of legendary twin battle axes, front view, crossed diagonally. Two massive crimson-tattooed war axes, red ritual scar-lines pulsing like veins across each blade, broken spectral chain fragments at the pommels, fierce ember fire glow in the grooves.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3k tris(两斧合计);LOD1 ~1.5k。
- **挂点/Socket:** `weapon_tip` 分别置于左右斧刃前缘(劈砍/冲击特效);左右手部挂点各一;锁链为次级绑定可摆动。
- **碰撞:** 每斧一根细盒 + 斧面薄盒;锁链无碰撞。
- **贴图:** 4K;纹身用 Emission(橙红,脉动可走材质 Shader 明暗);斧面 Normal 加豁口/熔灼细节。
- **动画:** 双斧连击时锁链摆动、纹身辉光随蓄力增亮;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/bestiary/bosses-master.md`(刑天 · Boss Weapon)、`docs/systems/weapons-compendium.md`(Legendary: Xing Tian · Indomitable)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`axe_right` / `axe_left` shape_id,替换材质)
