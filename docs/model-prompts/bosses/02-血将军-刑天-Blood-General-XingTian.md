---
名称: 血将军·刑天（Blood General Xíng Tiān）
类别: Boss
目标格式: GLB (Godot 4.7.1)
参考尺寸: 12m（无头巨神，山顶角斗场）
源文档: ../bestiary/bosses-master.md、../chapters/02-blood-iron/chapter-overview.md、../chapters/02-blood-iron/chapter-supplement.md
---

## 一句话概述

Ch.2 血铁·战歌 Boss，神（堕战神）：3 阶段（缚锁巨神 100-70% → 破锁狂战 70-30% → 荣誉决斗 30-0%）。山顶角斗场，两方幽灵军队观战。狂战士职业可交互跳过 P1 直入 P2。战后选择「荣耀其名」或「吞噬其怒」（`ch2_xingtian_fate`），魂器：刑天之心。

## 视觉描述

- **体型/比例:** 无头 12m 巨神，宽厚如山、如柱的战躯，脖颈为断面；胸口之眼（乳→目）、腹部之口（脐→口），完全照山海经。
- **服装/甲胄:** 褪色旧甲的残破将军战甲+残破战旗披风，躯干遍布赤红仪式纹身（图腾符文），纹身透出烬光。
- **武器/道具:** 双巨型战斧，腕链连接（P1 被幽灵锁链束缚受限；P2 锁链断裂可掷斧回拉；P3 丢一斧、单手持斧）。
- **标志性特征:** 无头剪影+胸口之眼+腹部之口+双斧腕链；赤红烬纹随阶段由「束缚微光」→「狂暴炽燃」→「余烬暖光」变化。
- **配色:** 暗铁灰+血赤红；烬火橙红辉光（纹身、胸眼、腹口）。
- **姿态参考:** 站立巨神/双手持斧。弱点击破锚点：双腕链（破锁）+胸口之眼（凝视麻痹/处决）。

## 图片生成提示词

> Phase 1 — Chained Xíng Tiān（缚锁刑天）

```
Headless Blood General, full body, front view, standing, headless 12-meter war god chained by spectral chains, torso covered in ritual scarification glowing crimson ember light, chest eyes on nipples, abdomen mouth at navel, twin giant battle axes chained to wrists, tattered general armor and torn war cloak, dark iron gray and blood red palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 2 — Unchained Xíng Tiān（破锁刑天）

```
Headless Blood General, full body, front view, berserker stance, headless 12-meter war god unchained, broken spectral chains dangling from wrists, twin battle axes whirling free, ritual scars blazing crimson ember, chest eyes and abdomen mouth agape in war cry, flying axe mid-throw, dark iron gray and blood red palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

> Phase 3 — Honor Duel（荣誉决斗）

```
Headless Blood General, full body, front view, solemn duel stance, headless 12-meter war god fighting one-handed, single battle axe held across chest, other axe dropped and embedded in ground, ritual scars dimmed to warm ember glow, chest eyes calm, respectful ceremonial posture, dark iron gray and ember crimson palette, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 巨大 Boss：LOD0 ~15k tris / LOD1 ~8k / LOD2 ~4k。
- **挂点/Socket:** `weapon_tip`（双斧特效/掷斧点）、`ExecutionAnchor`（处决：胸口之眼）、`GrabProfile`（抓投捕获形状）、腕链挂点 `chain_l/chain_r`、双手挂点。
- **弱点击破锚点:** 双腕链 `chain_l/chain_r`（P1 破锁触发 P2 转场）、胸口之眼 `chest_eye`（凝视麻痹 3s + 处决锚点）。
- **碰撞:** Boss 独立 `CollisionShape3D`：躯干大胶囊+分离双下肢（12m 高度避免踮脚）；双斧独立碰撞/`Area3D`（掷斧命中）。
- **贴图:** 2K-4K；Emission：赤红纹身、胸眼、腹口（P1 微光 / P2 炽燃 / P3 暖光，走强度动画）。
- **骨骼/动画:** 人形大骨架；P1 受限动作（锁链牵制）、P2 旋风回旋/跃击/掷斧链回拉、P3 单斧礼仪姿态+「敬礼→终末砸地」；狂战士互动可选下跪/对话动作。

## 出处

- 设计文档：[`../bestiary/bosses-master.md`](../bestiary/bosses-master.md)、[`../chapters/02-blood-iron/chapter-overview.md`](../chapters/02-blood-iron/chapter-overview.md)、[`../chapters/02-blood-iron/chapter-supplement.md`](../chapters/02-blood-iron/chapter-supplement.md)
- 代码挂点（占位几何体）：`game/scripts/character_meshes.gd`、`game/scripts/enemy_factory.gd`
