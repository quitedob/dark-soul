---
名称: 炼丹堕仙（Alchemy Fallen Immortal）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m,与玩家相近(略高)
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

仙堕类施法者,4-2 炼丹云台的丹道修士在飞升瞬间被冻结,半仙半朽、躯体不断散出丹气。AI 保持距离抛掷三类药瓶(爆裂/冰冻/毒),无近战;血量 80、远程伤害 28,近身冲脸为弱点。

## 视觉描述

- **体型/比例:** 人形、约 1.8m,身形清瘦;仙堕"半飞升"状态——一侧似灵体发亮、另一侧朽烂。
- **服装/甲胄:** 玄色道袍(丹砂袖口),外罩残破麻衣,袍角化为飘散的丹灰;无甲。
- **武器/道具:** 双手各持铜药瓶,攻击时抛掷;腰间挂一串玉葫芦。
- **标志性特征:** 体表持续升腾青绿丹气,双目与丹炉心口透出炽亮炉光;药瓶抛掷动作是唯一肢体语言。
- **配色:** 玄黑道袍 + 青绿丹气,辉光烬橙药火;仙堕的"半灵体"半透明处理。
- **姿态参考:** 侧身抛掷姿态(便于表现抛物线投掷);站立时脚尖半离地,暗示"悬停冻结"。

## 图片生成提示词

```
Alchemy Fallen Immortal, full body, front view, floating, cultivator frozen mid-ascension with one half human flesh and one half glowing green elixir energy, tattered grey alchemist robes, Taoist crown, clutching bronze elixir flasks in both hands, misty green vapor rising from body, ember-orange core glow, pale grey and toxic green color palette, rotting cloth and luminous vapor materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 6k tris / LOD1 3k;药瓶 3 个各 120 tris。
- **挂点/Socket:** 右手 `weapon_tip`(抛掷锚点);左手 `flask_hand`(副手药瓶);腰间 `belt_pouch`。
- **碰撞:** 胶囊(0.35m × 1.75m);被近身冲脸时重心后倾的受击动画。
- **贴图:** 2K Base/Normal/Roughness/Metalness;丹气半透明用 Alpha;炉心与眼用 Emission。
- **动画/骨骼:** 单人形骨架;关键动作=抛掷三段(后仰蓄力→抛出→恢复),无近战攻击帧。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 炼丹堕仙)、`../chapters/04-celestial-fall/chapter-overview.md`(4-2 炼丹云台)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `flask_hand` 命名
