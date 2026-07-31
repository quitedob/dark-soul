# 2026-07-31 — 模型提示词库（Model Prompts Library：md→图片→3D 流水线上游）

### Scope

为正式 3D 资产生产建立**上游提示词库**：subagent 并行通读 `docs/` 与 `game/` 后，将全部已设计模型的"图片生成提示词"写成 md，按语义分类入文件夹。当前游戏内 100% 为程序化占位几何体（`character_meshes.gd` / `weapon_meshes.gd` / `enemy_factory.gd`），本目录是替换它们的资产生产清单。

### Pipeline

```
md 提示词（本目录）→ 生图（概念图 / image-to-3D）→ TRELLIS / Hunyuan3D-2 → GLB
→ Godot MCP 导入 res://assets/models/ → 替换程序化工厂（保留 weapon_tip / ExecutionAnchor / GrabProfile 挂点）
```

流水线研究与工具选型：`docs/research-llm-mcp-3d-godot.md`。

### Structure

```text
docs/model-prompts/
  README.md                 # 流水线 + 命名规范 + 美术语言 + P0/P1/P2 优先级
  00-template.md            # 统一模板（frontmatter + 6 段结构）
  characters/  player-classes/（8 职业） npcs/（5） summons/（5）
  bosses/      5 主线 Boss（多阶段独立提示词）+ sub-bosses/（2）
  enemies/     01-spirit-ruins/（4） 02-blood-iron/（6） 03-jade-veil/（9）
               04-celestial-fall/（7） 05-throne-of-ashes/（5）
  environment/ 每章一个 md，内含各区域/地标提示词（共 28 区域）
  props/       烬龛 / 失落回声 / 锻造台 + 机关·谜题·幻影·拾取物合集
  weapons/     4 起始武器 + 7 传奇武器 + 17 类武器类型合集
  equipment/   轻/中/重甲 + 饰品头饰 + Boss 魂器
```

### Coverage

- 共 **85 个提示词 md + README + 模板**（87 文件）
- 人物 18、Boss 7（多阶段各一提示词块）、敌人 31、环境 28 区域、道具 7、武器 12、装备 5
- 校验：85/85 含 `图片生成提示词` 字段，每段以统一风格后缀收尾；多提示词文件块数与设计一致

### Conventions

- 命名 `<序号>-<中文名>-<English-Name>.md`；章节敌人/环境沿用 `01-spirit-ruins` 前缀
- 每 md 必备：YAML frontmatter → 一句话概述 → 视觉描述 → 图片生成提示词（英文，可整段粘贴生图）→ 建模备注（挂点/弱点击破锚点/碰撞/贴图）→ 出处
- 全局美术语言（烬火辉光、失魂/妖/精/鬼/仙堕视觉谱系、四职业文化锚点）强制写入提示词
- 环境/合集类文件为一个文件多段提示词；人物/Boss/敌人为一物一文件

### Entry points

- [devlog/index.md](../index.md)
- [model-prompts/README.md](../../model-prompts/README.md)
- [master-index.md](../../master-index.md)（已登记）
- 流水线：[research-llm-mcp-3d-godot.md](../../research-llm-mcp-3d-godot.md)
