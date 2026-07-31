---
名称: 可能性之影（Shadow of Possibility）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 人形剪影,随形态变化
源文档: ../bestiary/enemies-master.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

未知存在(类别 ???),5-3 轮回歧路中"未走之路"的化身、循环之外的来客。AI 形态在**四职业外观(狂战士/玄法师/神射手/祝祷师)间随机切换**,攻击每 10s 重排,玩家犹豫 3s 以上则增强;血量 100、伤害 28,克制=果断连攻。

## 视觉描述

- **体型/比例:** 人形剪影约 1.8m,但**没有固定外观**——轮廓不断在四种职业形象间切换闪现。
- **服装/甲胄:** 无常服装;切换瞬间依次浮现四职业剪影(兽皮战甲/玄色道袍/轻皮甲/袈裟),均以半透明残影呈现,永不"定格"。
- **武器/道具:** 每切换一次就换一次武器虚影:双斧(狂战士)/法印(玄法师)/弓(神射手)/念珠(祝祷师)。
- **标志性特征:** 身体由流动的暗影构成,边缘碎成"可能性残像"(同一轮廓的多重错位叠影);脸部为深邃空洞,烬火橙红在内闪烁。
- **配色:** 纯黑暗影为主,烬橙轮廓光;切换时的四职业残影各带其标志色但全部蒙上一层冷灰。
- **姿态参考:** 站姿中性、不暴露攻击意图(呼应"随机攻击");攻击起手前轮廓会短暂凝固成某个职业姿态。

## 图片生成提示词

```
Shadow of Possibility, full body, front view, standing, humanoid silhouette made of shifting black shadow, blank void face, edge dissolving into multiple ghosted afterimages, weapon form flickering between twin axes and daoist spell seal and bow and prayer beads, ember-orange glow pulsing in core, void black and faint ember orange color palette, shadow and fading light materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 4k tris / LOD1 2k(本体);四职业武器虚影各 400–600 tris(可复用玩家武器库模型)。
- **挂点/Socket:** 右手 `weapon_tip`(当前职业武器虚影挂点,随切换换装);核心 `core_point`(烬火)。
- **弱点击破锚点:** "确定性"为机制弱点(设计文档:攻击毫不犹豫则容易),无固定身体破绽;但轮廓凝固瞬间(切换前 0.3s)为可打断帧。
- **碰撞:** 胶囊(0.35m × 1.75m);残影/错位叠影用 Shader 位移,不做实体碰撞。
- **贴图:** 1K–2K Base + 强 Alpha;边缘残影用 Emission + 顶点偏移;核心烬火用 Additive。
- **动画/骨骼:** 单人形骨架(4 骨武器虚影层);需四职业各一套武器持握姿势的"闪现"过渡 + 本体暗影流动动画。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 5 可能性之影)、`../chapters/05-throne-of-ashes/chapter-overview.md`(5-3 轮回歧路)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `core_point` 命名
