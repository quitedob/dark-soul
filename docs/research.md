# Research Report — Original Soulslike Vertical Slice

> **Historical note (2026-07-30):** This report was written during the initial prototype phase (2026-07-29). For current implementation state, see [`devlog.md`](devlog.md), [`tasks-master.md`](tasks-master.md), and the post-audit research documents. Design principles and Godot API mappings below remain valid; concrete feature claims may be stale.

Accessed: **2026-07-29**

## Scope and Method

This report translates broad Soulslike genre conventions into a small, original Godot 4.7 prototype. It does not reproduce protected names, lore, characters, dialogue, maps, music, art, or data from any commercial game.

Research used Perplexity deep research and focused follow-up searches, then checked engine claims against official Godot documentation and the local Godot 4.7.1 CLI help. The initial broad Perplexity result supplied useful categories but no returned source list, so unsupported numeric claims were discarded. Prototype timings and costs in this project are explicitly design recommendations to be playtested, not sourced facts.

## Key Findings

### High Confidence — Structure combat as explicit timed states

A deliberate melee attack is easier to reason about and test when split into wind-up, active, and recovery states. Damage exists only during the active state. Movement, rotation, stamina spending, buffering, and cancellation rules can then be defined per state instead of being hidden inside animation playback.

**Prototype decision:** Gameplay state is authoritative. Procedural poses communicate the state, and `Area3D` hit volumes activate only for the active interval. This avoids frame-rate-dependent hit checks and keeps imported animation optional.

Implementation references:

- [Area3D class](https://docs.godotengine.org/en/stable/classes/class_area3d.html) — documents monitorable 3D regions and `body_entered`/`body_exited` signals used by hit and interaction volumes.
- [Using AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) — supports a later upgrade from procedural poses to animation state machines and blending.

### High Confidence — Keep movement and camera collision engine-native

`CharacterBody3D` is intended for user-controlled bodies and provides collision-aware movement through `move_and_slide()`. `SpringArm3D` moves child camera nodes toward its origin when geometry obstructs the desired camera distance.

**Prototype decision:** The player and enemies use `CharacterBody3D`; the camera sits below a yaw/pitch pivot and `SpringArm3D`. Lock-on changes the desired facing and camera aim but does not replace collision handling.

Implementation references:

- [CharacterBody3D class](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) — authoritative API reference for velocity, floor detection, and `move_and_slide()`.
- [3D kinematic character movement](https://docs.godotengine.org/en/stable/tutorials/physics/kinematic_character_3d.html) — official movement tutorial for `CharacterBody3D`.
- [SpringArm3D class](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html) — authoritative camera obstruction API.
- [Third-person camera with spring arm](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html) — official setup pattern and collision behavior.

### High Confidence — Model enemy behavior with a small explicit FSM

A vertical slice benefits more from a few inspectable states than from a large behavior framework. Navigation should answer “where should this body move next?” while combat states still control whether the enemy is allowed to move or attack.

**Prototype decision:** Enemies use idle, chase, wind-up, active, recovery, stagger, return, and dead states. `NavigationAgent3D.get_next_path_position()` supplies pursuit direction when a map is synchronized; a direct steering fallback keeps the prototype safe during initial frames.

Implementation references:

- [NavigationAgent3D class](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) — documents target positions, path updates, avoidance, and `get_next_path_position()`.
- [Using NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html) — warns that path updates must be called from physics processing and explains agent synchronization.
- [Navigation overview](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html) — describes maps, regions, meshes, links, and agents.

### High Confidence — Treat stamina as action economy, not decoration

Stamina makes a choice meaningful only when actions have different costs and regeneration cannot erase every commitment immediately. Exact values are game-specific and require playtesting.

**Prototype recommendation:** Movement is free; sprint, attacks, and dodge spend stamina. Regeneration pauses briefly after spending. Attacks cannot begin without their full cost. The HUD combines a bar and numeric state so depletion is not communicated by color alone.

Initial prototype targets are 100 maximum stamina, 20 light-attack cost, 38 heavy-attack cost, and 26 dodge cost. These numbers are hypotheses, not researched constants.

### Medium Confidence — Lock-on should prioritize readable targets and fail gracefully

Lock-on is useful in close melee but can become disorienting when targets move behind walls, leave range, die, or cluster together.

**Prototype recommendation:** Score candidates by camera-facing angle and distance, enforce a finite range, release invalid/dead targets automatically, keep manual camera available while unlocked, and show a non-color-only target marker. Future work should add occlusion rejection and right-stick/mouse target switching.

### High Confidence — Checkpoints should compress repetition

For a short prototype, a checkpoint can serve several technical and pacing roles: establish respawn, restore player state, reset enemies, and give a safe place to learn controls. A shortcut rewards spatial understanding by reducing repeated traversal after failure.

**Prototype recommendation:** Resting heals and revives enemies. Death drops carried embers at one recoverable echo; a later death replaces it. The shortcut remains open for the current run. Persistent save files are intentionally deferred.

Save-system reference:

- [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) — official patterns for identifying persistent nodes and writing state to `user://` when persistence is added.

### High Confidence — Accessibility must be designed into feedback and input

Important state should not depend on color alone. Keyboard alternatives, readable text, adjustable camera behavior, captions or text equivalents for important audio, and remappable actions should be considered independently from difficulty tuning.

**Implemented now:** keyboard alternatives for mouse attacks and lock-on; textual prompts; numeric and bar feedback; target markers; a persistent help overlay; no required audio-only information.

**Recommended next:** full rebinding UI, controller support, camera sensitivity sliders, separate X/Y inversion, text scaling, reduced motion, screen-shake controls, and optional combat assists.

Accessibility references:

- [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/) — practical guidance grouped by basic, intermediate, and advanced impact/cost.
- [Game Accessibility Guidelines full list](https://gameaccessibilityguidelines.com/full-list/) — includes remapping, alternatives to color, text presentation, camera motion, and audio guidance.
- [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines) — official platform guidance for input, visual, audio, cognitive, and testing considerations.
- [Microsoft game accessibility overview](https://learn.microsoft.com/en-us/gaming/game-design/accessibility) — accessibility-first game design and testing guidance.

### High Confidence — Validate with the exact engine executable

The installed executable reports `4.7.1.stable.official.a13da4feb`. Its local `--help` output confirms `--headless`, `--editor`, `--import`, `--quit`, `--quit-after`, and the `--` separator for user arguments.

**Prototype decision:** Run an editor import, a bounded headless gameplay run, and a dedicated `--smoke-test` user argument using the requested console executable.

Reference:

- [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) — official CLI flags and automation patterns.

## Practical Implementation Sequence

1. Create a collision-safe player controller and camera in a gray-box arena.
2. Add stamina and one complete light attack state cycle.
3. Add damage areas, invulnerability, stagger, death, and reset.
4. Add one enemy using the same combat timing vocabulary.
5. Add lock-on only after free-camera combat works.
6. Build a compact route with a checkpoint and shortcut.
7. Add a guardian by retuning and extending the same enemy architecture.
8. Add HUD/audio/visual feedback, then headless smoke tests.
9. Playtest costs and timings; change constants only in response to observed failure modes.

## Contradictions and Gaps

- Perplexity's first deep-research response offered broad design guidance but returned no source URLs. This report therefore labels those elements as recommendations and relies on official engine/accessibility sources for verifiable claims.
- Godot's online `stable` documentation may move to a newer minor release after 4.7. Engine APIs are validated by running the installed 4.7.1 build; links remain `stable` because a permanent 4.7 branch may not yet be published.
- This prototype uses procedural poses instead of authored animation clips. It validates state timing and gameplay architecture, but not final animation blending, root motion, motion matching, or production-quality hit alignment.
- Headless tests cannot evaluate camera comfort, telegraph readability, perceived fairness, visual composition, or audio mix. Those require human playtesting in the graphical build.
- Navigation works best with a baked `NavigationRegion3D`; because this project generates geometry at runtime, the first version permits direct steering fallback. A later authored level should bake navigation and test narrow passages explicitly.
- No single authoritative source defines correct stamina costs, dodge invulnerability duration, or enemy timing. Those are tuning variables and should not be copied from another game.

## Recommendations

- Keep this vertical slice small until the complete death/recovery/boss loop is playable.
- Add imported animations only after gameplay state timing passes tests; animation should present the rules, not secretly define them.
- Conduct short observation-based playtests and record: missed telegraphs, accidental unlocks, camera collisions, stamina confusion, repeated traversal frustration, and guardian deaths by cause.
- Treat accessibility options as orthogonal controls rather than a single “easy mode.”
- If the prototype expands, move tuning constants into `Resource` data assets and save world progression under `user://`.

## Godot Skill Search

No Godot-specific `SKILL.md` was installed under the local Claude skills or plugin caches when development began. The project therefore follows official Godot documentation and direct engine validation rather than installing an unreviewed third-party skill. This avoids introducing opaque instructions or executable dependencies into the empty workspace.
