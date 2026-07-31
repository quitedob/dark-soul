---
名称: 倒悬守卫（Inverted Guardian）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.3m,明显高于玩家
源文档: ../bestiary/enemies-master.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

精类构造体,5-2 倒悬殿巡逻的甲胄护卫,倒悬建筑里如履平地——能**倒立行走**于天花板/墙壁。AI 从玩家意想不到的角度(头顶/侧壁)进攻;血量 160、伤害 36、机动 2.5,重力魔法 +40%。

## 视觉描述

- **体型/比例:** 近人形构造体、约 2.3m,关节粗大、重心偏向躯干,剪影方正厚重。
- **服装/甲胄:** 全套青铜+玄铁重甲,层叠甲片与铆钉,肩吞兽纹,甲缝透出冷光,背部有锚定倒悬的棘刺/锁扣。
- **武器/道具:** 手持长柄朴刀/戟,刀脊厚重,横扫为主。
- **标志性特征:** 头顶与足底各有一对**反向脚掌纹路**的锚定装置(暗示可倒挂);双眼冷冽蓝光,烬火橙红在核心闪烁。
- **配色:** 玄黑甲 + 冷铜,辉光烬橙(天炉残火);倒悬殿背景为深空星辉蓝黑。
- **姿态参考:** 正面站立时即呈现"足底朝上亦可行走"的倒挂脚掌;巡逻动画强调四向(顶/墙/地)行走切换。

## 图片生成提示词

```
Inverted Guardian, full body, front view, standing, armored construct of bronze and dark iron plates, faceted helm with cold blue visor slit, reverse-facing clawed feet for walking on ceilings, heavy poleblade held low, ember-orange core glow through chest seams, void-black and cold bronze color palette, aged metal and stone materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 7k tris / LOD1 3.5k;甲片用 Normal 烘焙省面。
- **挂点/Socket:** 右手 `weapon_tip`(朴刀特效);背部 `anchor_spike`(倒悬挂点/抓投)。
- **弱点击破锚点:** 足底反向脚掌为倒挂特征部位;重力魔法命中后失衡,需给"被扳正"动画。
- **碰撞:** 胶囊(0.45m × 2.2m);行走模式支持 `up` 方向四向切换(天花板时碰撞朝下)。
- **贴图:** 2K Base/Normal/Roughness/Metalness;胸口烬火用 Emission;双眼冷蓝用 Emission。
- **动画/骨骼:** 单人形骨架 + 背部锚链 4 骨;需头顶/墙壁/地面三套行走循环,倒挂时姿势镜像。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 5 倒悬守卫)、`../chapters/05-throne-of-ashes/chapter-overview.md`(5-2 倒悬殿)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `anchor_spike` 命名
