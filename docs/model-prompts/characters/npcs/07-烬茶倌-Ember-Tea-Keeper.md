---
名称: 烬茶倌（Ember Tea-Keeper）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m(与玩家相仿的年轻亡魂,记忆投影)
源文档: ../chapters/03-jade-veil/chapter-supplement.md, ../story/chapter-bridge-map.md
---

## 一句话概述

年轻人茶倌的亡魂,仅在支线「桥头的供茶」中借记忆苔/镜花倒影以记忆投影呈现;生前把挣到的每枚烬都寄给所爱之人,被榨空后从断桥跃入镜湖,如今只剩胸前一缕将熄的烬芯。

## 视觉描述

- **体型/比例:** 与玩家相仿的年轻亡魂,约 1.8m;身形颀长而消瘦、近乎耗竭,剪影单薄如将散的烟。
- **服装/甲胄:** 褴褛灰白的粗布衫(桥头送茶人的旧衣),衣摆破损、沾有烬灰。
- **武器/道具:** 一只手仍紧攥着一杯未能送出的温热供茶。
- **标志性特征:** 眼眶深陷空洞,面色灰败;身形极淡、几乎透明,唯胸前燃着一线将熄的烬芯——灰烬色由实向透明渐隐,一点微弱的烬橙火星是全身仅存的温度。
- **配色:** 主色烬灰渐隐至透明,辉光为胸前将熄的烬橙一点。
- **姿态参考:** 静立垂手,一手拢杯于胸前,双目茫然望向桥对岸(记忆中反复重演的"第三次")。

## 图片生成提示词

```
Ember Tea-Keeper, full body, front view, standing, a gaunt young translucent ghost with hollow sunken eyes and a threadbare ash-grey cloth robe, one hand holding a small warm cup of tea to his chest, faint nearly-consumed body fading from ash-grey to transparent, a single dying ember-orange point of light glowing inside the chest, cold moonlight, translucent fading materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3.5k tris / LOD1 ~2k;可作为静态剪影/顶点淡出 shader 呈现,无需完整战斗模型。
- **挂点/Socket:** 胸前烬芯 Emission 锚点(将熄火星特效)、手持茶杯挂点。
- **碰撞:** 记忆投影,无需碰撞;以视觉淡出隐藏于记忆苔/镜面场景中。
- **贴图:** 2K Base/Normal/Roughness;全身用顶点淡出/半透明由实渐隐,胸前烬芯强 Emission。
- **动画/骨骼:** 无需对白骨架——记忆投影,静态剪影 + 顶点淡出 shader 即可;同一模型亦在 Ch.5-3 轮回歧路以"平静之姿"或"怒之残影"的记忆形式出现。

## 出处

- 设计文档:`docs/chapters/03-jade-veil/chapter-supplement.md`(支线 4 · 桥头的供茶)、`docs/story/chapter-bridge-map.md`(5-3 轮回歧路记忆)
- 代码挂点:`game/scripts/`(记忆投影呈现,经记忆苔/镜花倒影触发,待建)
