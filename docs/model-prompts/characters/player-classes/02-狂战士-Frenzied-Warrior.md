---
名称: 狂战士（Frenzied Warrior）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/frenzied-warrior.md
---

## 一句话概述

高血量近战肉盾,以刑天斧(刑天无头巨神之血路)双斧近战,血量越低越强(怒气机制);兽皮战甲 + 战鬼面扛伤换伤,怒值满进入狂暴状态强化攻速与减伤。

## 视觉描述

- **体型/比例:** 宽肩厚背、身高中等偏上,躯干宽阔、四肢粗壮,剪影厚实如铜墙铁壁。
- **服装/甲胄:** 兽皮战甲(毛皮镶边的厚皮甲 + 铁片护胸)、战鬼面(遮上半脸的狞恶鬼面,露眼)、铁腕甲(前臂重型铁腕)。
- **武器/道具:** 双持刑天双斧(短柄战斧,斧刃镶刑天血石红纹);胸前挂刑天血石(兽牙血坠)。
- **标志性特征:** 暴怒时体表浮现猩红纹身辉光;战鬼面獠牙与鬼角剪影;胸前轮回印微光。
- **配色:** 主色暗烬灰 + 血铁红,辉光烬火橙红 + 猩红。
- **姿态参考:** 站姿双斧交叉胸前、屈膝戒备;斧刃挂点用于怒气暴走拖尾特效。

## 图片生成提示词

```
Frenzied Warrior, full body, front view, standing, muscular man wearing beast-hide battle armor with fur trim and iron bracers, war-demon mask, crimson ritual scarification, paired battle axes, faint rebirth seal on chest, dark ash gray and blood red palette, worn metal and leather materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;双斧为独立武器件,共享一套骨权重。
- **挂点/Socket:** 左右手主手挂点(双斧)、斧刃 `weapon_tip`(暴走拖尾)、`ExecutionAnchor`(处决)、`GrabProfile` 捕获形状。
- **碰撞:** 玩家胶囊略大 ~0.65m 半径 × 1.8m 高(肉盾体型);双斧盒碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;猩红纹身与血石辉光用 Emission;毛皮用 Roughness 高值。
- **动画/骨骼:** 标准人形骨架;需双斧连段/跃斩/怒吼/冲刺姿态;战鬼面可为独立蒙皮或吸附件。

## 出处

- 设计文档:`docs/characters/classes/frenzied-warrior.md`(链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
