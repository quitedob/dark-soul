---
名称: 巨阙·守门人（JuQue · Gatekeeper）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 全长约 2.0m(巨剑,剑身接近守门巨像之臂)
源文档: ../../chapters/01-spirit-awakening/bosses.md
---

## 一句话概述

> 传奇 Boss 锻造武器(第 1 章巨阙,第 3 章后锻造);终极巨剑,以守炉灵之臂铸成——石质剑身遍布烬火裂纹;蓄力重击释放短距烬火冲击波(Furnace Pulse)。

## 视觉描述

- **造型:** 巨柱式石质大剑,剑身由灰石与黑铁混铸,横截面近乎方形(双巨人式);剑身表面布满放射状烬火裂纹,如地脉在石中奔涌;剑格为两道门阙式横杠,柄缠粗麻。
- **材质:** 守炉神殿灰石 + 黑铁 + 麻布柄;石面刻冥文铭文。
- **辉光:** 裂纹透出炽亮烬火橙红(Emission 高),石缝间火星缓飘;剑格凹槽处亦有暗橙余光。
- **尺寸:** 全长约 2.0m,剑身宽约 0.3m、厚约 0.25m。
- **握持方式:** 双手持剑(手部挂点),巨剑斜扛肩后或拖地。

## 图片生成提示词

```
A single legendary ultra greatsword, front view, standing diagonally upright. An enormous stone-and-iron colossus blade with glowing ember cracks running across the grey rock, engraved dark inscriptions, gate-like crossguard, coarse rope-wrapped grip, hot furnace glow in the fissures.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3.5k tris;LOD1 ~1.8k。
- **挂点/Socket:** `weapon_tip` 置于剑尖(烬火冲击波/Furnace Pulse 特效);双手部挂点;碰撞用长盒。
- **贴图:** 4K;灰石高粗糙低金属,裂纹 Emission(橙红,multiplier 高),冥文走 Normal;麻布柄哑光。
- **动画:** 蓄力时裂纹辉光增强、火星粒子增多;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/chapters/01-spirit-awakening/bosses.md`(巨阙 · Boss Weapon)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`guardian_sword_ch1` / `dragon_greatsword` shape_id,替换材质)
