---
名称: 镜中影（Mirror Shade）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的半透明人形剪影
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第一章明镜殿的鬼类敌人,被困于青铜镜中的怨灵,只能在玩家背对时从镜面钻出。HP 35、速度 5.0,以"背后偷袭+钻回镜中"为战术,受祷告伤害加成。

## 视觉描述

- **体型/比例:** 标准人形,但被拉长、扭曲,剪影是"从镜面半身探出的模糊人影"。
- **服装/甲胄:** 无实体甲胄,只有游魂袍一般的黑雾轮廓,边缘碎裂。
- **武器/道具:** 无武器,攻击为伸出的利爪状黑雾。
- **标志性特征:** 半透明剪影 + 残片状镜玻璃碎片悬浮身周;钻出镜面瞬间有银白闪光的"shimmer"。
- **配色:** 幽蓝黑雾 + 银白镜光,暗部近纯黑。
- **姿态参考:** 半弓身、蓄势扑出的姿态;从镜面浮现时应把底部做平以便嵌入镜面。

## 图片生成提示词

```
Mirror Shade, full body, front view, emerging, translucent humanoid silhouette rising from a cracked bronze mirror, blurred ghostly figure with mirror-glass shards, wispy tattered edges, ghost-blue and silver shimmer palette, faint ember glow, semi-transparent reflective materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k,半透明+Blend(Additive)渲染。
- **挂点/Socket:** `ExecutionAnchor`(处决锚点)设胸腔;无需武器挂点。
- **碰撞:** 小胶囊(CapsuleShape3D,半径 0.3,高 1.7);穿墙由 AI/碰撞层处理,模型自身无实体碰撞。
- **贴图:** 2K,Alpha 用于半透明;银白闪光用 Emission 或渐变贴图,底部预留镜面接触平面。
- **动画/骨骼:** 约 16 根骨骼;重点是"浮现/缩回"动画与 `AmbushBehavior`,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/01-spirit-awakening/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_1_enemy_factory.gd`
