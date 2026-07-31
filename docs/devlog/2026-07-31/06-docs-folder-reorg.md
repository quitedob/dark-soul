# 2026-07-31 — Docs Folder Reorg（分类目录 + 按日 Devlog）

### Scope

按语义文件夹重组 `docs/`：调研汇总、规划缺口、按日期拆分的唯一日志；删除已完成审计与巨型单文件。

### Structure

```text
docs/
  master-index.md          # 原 00-master-index（去掉排序魔法前缀）
  planning/
    soulslike-gap-analysis.md
  research/
    index.md               # 调研汇总 + 现网对照
    soulslike/             # design / weapons / mechanics
    godot/                 # ecosystem / jump-collision / actions-combat / prototype-baseline
  devlog/
    index.md
    2026-07-29|30|31/      # 每日多文件；含 delivery-summary.md
  systems/ story/ chapters/ characters/ bestiary/ tasks/
```

### Rules

- **只使用** `docs/devlog/` 记交付；已删除根级 `devlog.md` 与 `CHANGELOG.md`（摘要并入各日 `delivery-summary.md`）
- 文件夹/文件名用语义英文，**禁止** `e-1` / `a01` 式散落规格文件
- 已完成审计：核对日志后删除（见 `99-completed-audits-archived.md`）

### Deleted after log check

| 文件 | 日志覆盖 |
|------|----------|
| `audit-docs-codebase-health.md` | 07-29 Research Audit Fixes 等 |
| `code-review-full-audit-2026-07-30.md` | 07-30 Skill Waves / Gap 纠偏 |
| `CHANGELOG.md` / 根 `devlog.md` | 拆入 `devlog/<date>/` |

### Entry points

- [devlog/index.md](../index.md)
- [research/index.md](../../research/index.md)
- [master-index.md](../../master-index.md)
