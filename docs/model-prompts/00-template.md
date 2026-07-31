# 提示词模板 · 00 Template

> 新建模型文件时**复制本文件**到对应分类文件夹,按注释填写。文件名:
> `<序号>-<中文名>-<英文名>.md`。提交前删掉本段和 `<!-- -->` 注释。

---

```yaml
---
名称: 模型中文名（English Name）
类别: 玩家角色 / NPC / Boss / 子Boss / 敌人 / 召唤物 / 环境 / 道具 / 武器 / 装备
目标格式: GLB (Godot 4.7.1)
参考尺寸: 相对玩家(身高 ~1.8m / 胶囊高 ~1.8)的倍数,或具体米数
源文档: 相对 docs/model-prompts 的源文档路径
---
```

## 一句话概述

> 它在游戏里是做什么的 / 在哪里出现 / 机制要点。(1–2 句)

## 视觉描述

- **体型/比例:** 身高、体宽、是否人形、剪影特征
- **服装/甲胄:** 材质、层数、装饰
- **武器/道具:** 手持物与挂点
- **标志性特征:** 一眼可识别的轮廓 / 发光部位 / 纹理
- **配色:** 主色、辉光色、材质基调
- **姿态参考:** 站姿 / T-pose / 弱点击破锚点位置

## 图片生成提示词

> ⭐ 整段复制到生图工具。英文、单主体、正面、纯色背景、无文字。
> 若走 image-to-3D(TRELLIS/Hunyuan3D),保持"正面全身、中性背景"以利抠网格。

```
<!-- 提示词结构:主体 + 姿态 + 服装/细节 + 武器 + 配色 + 材质 + 风格统一后缀 -->
<subject>, full body, front view, standing, <armor/clothing details>,
<signature feature>, <weapon/held item>,
<color palette>, <material>,
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike,
ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 面数建议、LOD 层级(如 LOD0 8k tris / LOD1 4k)
- **挂点/Socket:** `weapon_tip`(武器特效)、`ExecutionAnchor`(处决)、`GrabProfile`(抓投捕获形状)、手部挂点
- **弱点击破锚点:** 若为 Boss/精英,标注设计文档里的破绽部位(如 刑天=胸口之眼与腕链)
- **碰撞:** 胶囊/盒碰撞建议;Boss 用独立 `CollisionShape3D`
- **贴图:** 2K/4K、Base/Normal/Roughness/Metalness、烬火辉光用 Emission
- **动画/骨骼:** 骨骼数量与命名约定(替换 `character_meshes.gd` 时保持现有姿势挂点)

## 出处

- 设计文档:`docs/<对应文档>.md`(链接)
- 代码挂点:`game/scripts/<对应文件>.gd`(若已存在)
