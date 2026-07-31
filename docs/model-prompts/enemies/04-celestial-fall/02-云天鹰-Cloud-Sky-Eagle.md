---
名称: 云天鹰（Cloud Sky Eagle）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 翼展约 6m,躯干 1.8m
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

妖类飞禽,栖居 4-1/4-2 浮空城周围云海,因吞噬泄漏的灵气而肥硕成巨鹰。AI 在高空盘旋后俯冲(有声报音频),落地 2s 为惩罚窗口;血量 50、伤害 18、机动 8.0,远程克制。

## 视觉描述

- **体型/比例:** 非人形大型猛禽,翼展约 6m,躯干粗壮、翼缘宽厚,剪影是一团横贯天际的云影。
- **服装/甲胄:** 无甲胄;羽毛致密层叠,末端有焦化烧痕——吞灵吃火留下的伤疤。
- **武器/道具:** 弯钩状利喙与巨大爪足是唯一攻击部位。
- **标志性特征:** 羽翼间隙透出烬火橙红微光,俯冲时带出一道云焰尾迹。
- **配色:** 云白 + 暮金渐变,羽尖焦黑,辉光烬橙;符合"吞食天炉泄漏灵气"的设定。
- **姿态参考:** 正面展翅悬停(利于建模对称);俯冲应作收翼斜掠姿态。

## 图片生成提示词

```
Cloud Sky Eagle, full body, front view, hovering, massive eagle with storm-grey and sunset-gold feathers, wide wingspan, curved golden beak, ember-orange glowing eyes, faint ember sparks trailing from feather tips, charred black feather edges, cloud-white and burnt-gold color palette, feather and ember-glow materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 5k tris / LOD1 2.5k;翼片可做平板+Alpha 羽毛通道以省面数。
- **挂点/Socket:** 喙部 `weapon_tip`(俯冲特效/啸声);两翼各一 `wing_tip` 供俯冲拖尾。
- **碰撞:** 翼展 6m 用盒碰撞(2m × 1m × 6m),躯干胶囊;俯冲判定用独立 `CollisionShape3D`。
- **贴图:** 2K Base/Normal/Roughness/Metalness;烬火羽尖用 Emission。
- **动画/骨骼:** 骨骼以躯干为根 + 左右翼链(各 8 骨)做扑翼;旋转中心在翼根,便于动画驱动。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 云天鹰)、`../chapters/04-celestial-fall/chapter-overview.md`(4-1/4-2)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `wing_tip` / `weapon_tip` 命名
