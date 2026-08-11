# Subagent prompt template (Ashen Hollow)

Copy-paste base for `general-purpose` implementation agents. Fill the bracketed sections.
Every prompt must carry the 5 mandatory sections from the devlog's distilled spec.

```markdown
You are implementing <feature / quest / boss / content> for the Ashen Hollow (烬渊) Godot 4
project. Project root: `e:/godot/darksoul/game`. Godot console:
`E:/godot/Godot_v4.7.1-stable_win64_console.exe`.

## 1. Background + current code state (verified facts)
<Authoritative facts with path:line from recon — e.g. "quest_state.gd:214 `add_progress(flag)` requires flag in
progression_values", "dialogue_runner.gd exposes _start_dialogue(id)". Quote schemas/function signatures.>

## 2. Change list (itemized: current reference → what to change to)
1. <file path>:<line> — <current behavior> → <new behavior>
2. <file path> — add <function/schema> for <reason>
3. <file path> — new contract test <name>_contract_test.gd asserting <markers>

## 3. Traps & forbidden actions
- You are ONLY allowed to modify these files: <explicit list>. Do NOT touch anything else.
- Do NOT download, clone, or fetch any external content (no git clone, no pip/npm install).
- Data schema rules: `progression_values` accepts non-negative int only; `choice_flags` accepts
  bool / non-empty string only; never leave `story_flag` empty for a boss (soft-locks
  `_on_boss_story_threshold` → add an empty-flag early exit); pick elites by id, not first-match.
- Match the existing style of the file you edit (typed vars, match dispatch, SceneTreeTimer
  one-shots, Control anchors). GDScript-first.

## 4. Headless verification (MUST run to green before returning)
- Parse: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game"
  --check-only --script scripts/<file>.gd` for each file you touched.
- Contract: `... --headless --path "e:/godot/darksoul/game" --script tests/smoke/<your>_contract_test.gd`
  → expect `<MARKER>_CONTRACTS_OK`, EXIT 0.
- Smoke (if you touch runtime path): `... --quit-after 600 -- --smoke-test` → ASHEN_HOLLOW_SMOKE_OK.

## 5. Honesty rules
- READ the original file first to confirm line numbers and schema — the recon map is a clue, not truth.
- Do NOT report a verification as green if you did not actually run it. If a check fails, fix it
  or report the exact failure with output.

Return: list of files changed, verification output markers you achieved, and any deviation.
```

## Pitfall callouts to keep inline

- **Runaway guard:** reassert "no download/clone/fetch" whenever the agent proposes shell commands.
- **Ownership guard:** if the agent reports touching an unlisted file, have it revert or justify before merging.
- **Line drift:** if a quoted `path:line` doesn't match after reading, search for the symbol instead and note the new location.
