---
名称: 残缺仙体（Broken Immortal Body）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.4m,明显高于玩家
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

仙堕精英,全书最常见的堕仙——躯体开始飞升却中途停滞:半成羽翼、半能量体、未竟的超脱。AI 慢速重击,每击后失衡 1.5s;血量 150、伤害 35,**头部是完全转化唯一脆弱点**(+50%)。

## 视觉描述

- **体型/比例:** 人形但约 2.4m,身形高大僵硬,像"冻在飞升瞬间的雕像",剪影沉厚。
- **服装/甲胄:** 白色飞升仙袍已半边腐坏,袍面绣云纹,朽烂处露出石化肌肤。
- **武器/道具:** 无手持武器,以拳/掌重击;腕部有残断的能量手甲。
- **标志性特征:** 半成羽翼——一侧长出石质/半透明光羽、另一侧仍是肉肩;半身化为发光能量体,头后残留残缺光晕。
- **配色:** 飞升圣白(辉光) vs 腐朽肉灰,烬火橙红从石化裂缝渗出;头为最亮最"完整"部位。
- **姿态参考:** 正面微俯身、蓄力挥拳;头为弱点击破锚点,应做最醒目的高亮。

## 图片生成提示词

```
Broken Immortal Body, full body, front view, standing, tall half-ascended cultivator with a radiant fully-transformed head, half-grown stone feather wings on one shoulder, one arm dissolved into glowing white energy, tattered white ascension robes, cracked halo behind head, ember-orange cracks in limbs, white divine light and rotting flesh color palette, stone skin and luminous energy materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 8k tris / LOD1 4k(精英,需较精细剪影);羽翼 1.5k tris。
- **挂点/Socket:** 双手 `weapon_tip`(重击特效);`ExecutionAnchor`(处决锚点);`GrabProfile`(抓投捕获)。
- **弱点击破锚点:** **头部**为唯一 +50% 弱点(设计文档明示),建模将头作为高亮/受击判定独立网格。
- **碰撞:** 胶囊(0.45m × 2.3m),受重击失衡 1.5s 用重心后仰动画。
- **贴图:** 2K Base/Normal/Roughness/Metalness;能量半身用半透明 + Emission;烬火裂缝走 Emission。
- **动画/骨骼:** 单人形骨架 + 单侧羽翼骨骼(6 骨);需"石化→发光"两套材质交替的切换。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 残缺仙体)、`../chapters/04-celestial-fall/chapter-overview.md`(4-4/4-5/4-6)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `ExecutionAnchor` / `GrabProfile` 命名
