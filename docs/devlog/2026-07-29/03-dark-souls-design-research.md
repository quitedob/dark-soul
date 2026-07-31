# 2026-07-29 — Dark Souls Design Research

### Scope

- Conducted a structured investigation into Dark Souls 1/3 core design principles to evaluate Ashen Hollow's game design.
- Executed two Perplexity deep_research queries covering: combat speed, stamina economy, lock-on/camera, enemy teaching, death/soul-recovery loop, world/shortcuts, boss design, growth/currency, healing, accessibility, and vertical-slice acceptance criteria.
- Cross-referenced every claim against current game code, scenes, configuration, and tests via three local read-only sub-agents.

### Key Findings

- Ashen Hollow's core combat skeleton (attack phases, shared stamina, iframe dodge, death-recovery, checkpoint, shortcut) is **directionally correct** for a Soulslike vertical slice.
- The **highest-priority gap** is that embers have no spending purpose, removing the motivational anchor from the entire death-recovery loop.
- Boss lacks behavioral depth — two alternating attacks are trivially solvable; a phase transition and distance-dependent attack selection are recommended.
- All six existing design documents are stale or contradicted by current code — project path, controls, healing, persistence, and architecture claims all need updating.
- Perplexity deep_research could not return verifiable source URLs; conclusions are therefore based on observable game mechanics and analysis, not developer-attributed intent.
- Detailed findings, evidence classification, a vertical-slice checklist, and a "what not to copy" guide are in [research-dark-souls-design.md](research-dark-souls-design.md).

### Source Limitations

- Two deep_research queries returned framework-level answers without specific URLs or quotable passages.
- Report uses a three-tier evidence system: Observable Rule / Developer Intent / Analysis. No conclusion is attributed to a Perplexity-returned source without independent verification.
- Six common player-consensus claims about Dark Souls were flagged as unverified or factually incorrect against observable game mechanics.
- Unresolved questions (requiring primary-source retrieval from GDC Vault, CEDEC archives, or Japanese developer interviews) are listed in the report.
