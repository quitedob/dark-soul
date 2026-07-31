---
名称: 丹炉精怪（Elixir Furnace Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 高约 2.4m,直径约 1.8m
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

精类固定炮台,4-2 炼丹云台上的青铜丹炉因五百年药火不停而活物化。AI 静止不动,每 8s 脉冲一次状态毒雾(减速/伤害反转/反转操作随机);血量 180、AoE 25,水属 +35%。

## 视觉描述

- **体型/比例:** 非人形器物;大型三足青铜圆鼎,高约 2.4m,比玩家高一截,整体为厚重的圆柱+鼎盖轮廓。
- **服装/甲胄:** 无服装;鼎身满布云雷纹、饕餮纹与丹砂铭文,铸造年久,表面铜绿斑驳。
- **武器/道具:** 鼎口为攻击孔——毒雾由鼎盖缝和出烟口脉冲喷出。
- **标志性特征:** 鼎腹透出炽亮药火橙光(五百年的炉火),喷毒前炉火骤亮即为读条报信。
- **配色:** 铜绿青铜 + 灼亮炉火橙红,毒雾为青绿色;整体是"炉火 v.s. 毒云"的两色冲突。
- **姿态参考:** 固定静止,无站立姿态;以炉体为中轴的脉冲缩放/发光动画为主。

## 图片生成提示词

```
Elixir Furnace Spirit, full body, front view, stationary, ancient bronze alchemy furnace with three beast legs and round sealed lid, ornate Taoist cloud reliefs, open mouth venting glowing green toxic vapor, ember-orange furnace fire glowing through seams, verdigris bronze and boiling elixir green color palette, aged metal and stone materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 7k tris / LOD1 3.5k;纹样用 Normal 贴图烘焙,不占拓扑。
- **挂点/Socket:** 出烟口 `weapon_tip`(毒雾粒子发射锚点);鼎腹 `core_point`(炉火核心)。
- **碰撞:** 静止单位用圆柱碰撞(0.9m 半径 × 2.4m 高);毒雾 AoE 范围用透明 Trigger。
- **贴图:** 2K Base/Normal/Roughness/Metalness;炉火、毒雾用 Emission + Alpha;铜绿走 Roughness 差异。
- **动画/骨骼:** 无移动骨骼;用 Shader 做炉火脉动、鼎盖微颤。替换占位时保持 `weapon_tip` 位置。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 丹炉精怪)、`../chapters/04-celestial-fall/chapter-overview.md`(4-2 炼丹云台)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `core_point` 命名
