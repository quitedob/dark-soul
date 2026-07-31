---
名称: 炉渣怪（Furnace Slag Beast）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.2m 的厚重块状体(近方形剪影)
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第一章炼丹房遗迹的"精"类敌人,由炼药房冷却凝固的矿渣凝结成兽。HP 150、速度 1.5,缓慢蹒跚逼近,死亡时先亮 2s 再爆炸(4m 半径 30 伤害),辉光变亮就是远离的信号。

## 视觉描述

- **体型/比例:** 非人形,约 2.2m 高、肩宽近等高的厚重块状体,剪影是"会移动的熔渣堆"。
- **服装/甲胄:** 无甲胄,通体为凹凸不平的冷却矿渣,像凝固的炉壁结壳。
- **武器/道具:** 巨大的粗壮岩拳,无手持武器。
- **标志性特征:** 全身分布炽热橙红的裂缝(如岩浆裂纹),随死亡倒计时愈发明亮;头顶/躯干有崩裂的熔壳。
- **配色:** 焦黑炭灰 + 烬火橙红裂纹。
- **姿态参考:** 微俯身、双臂前垂的蹒跚姿态;死亡爆炸前需要全身辉光增亮通道。

## 图片生成提示词

```
Furnace Slag Beast, full body, front view, standing, hulking creature of congealed furnace slag, lumpy cooled cinder rock body, glowing orange lava cracks, ember-red heat seams, massive crude fists, dark charcoal and ember orange palette, rough slag and cinder materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~7k tris / LOD1 ~3.5k,块状低模即可,靠贴图表现熔渣质感。
- **挂点/Socket:** 无武器;`ExecutionAnchor`(处决锚点)设胸口核心;死亡爆炸 VFX 挂 `death_explosion` 空节点。
- **碰撞:** 矮盒碰撞(BoxShape3D,约 0.9×1.9×0.9);Boss/精英用独立 `CollisionShape3D`。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;橙色裂纹用 Emission,并预留死亡时增亮的 emission_energy 通道。
- **动画/骨骼:** 约 18 根骨骼;重点是蹒跚步态与"死亡增亮"状态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/01-spirit-awakening/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_1_enemy_factory.gd`
