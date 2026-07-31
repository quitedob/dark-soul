# Architecture

**Status:** CURRENT (2026-07-31) — 与 `devlog/` / `tasks-master` 对齐

## Runtime Composition

`main.tscn` → `game_world.gd` 运行时组装可玩场景（过程化战役模块 + 章节内容）。

```text
AshenHollow (Node3D, game_world.gd)
├── WorldEnvironment / lights / braziers
├── Procedural campaign geometry + NavigationRegion3D
├── ProceduralAudio — SFX pool；Music 总线音量（C-06）
├── HUD — title/pause/death/victory、Focus、Boss bar、dialogue overlay
├── Warden (scripts/player/player.gd) — FSM + Action Queue + AnimationBridge
│   ├── CombatArea / camera SpringArm / spell spawn
├── EmberShrine / shortcuts / LostEcho
├── Enemies (enemy.gd + behavior modules / BossMacroController)
├── Story: QuestState / DialogueRunner / EndingResolver / FateChoiceOverlay
└── GameHostBridge · AshenRunState · AshenGameSettings
```

## Responsibilities

- `game_world.gd`：组合根、战役关卡、死亡环、存档、命运/对话接线
- `scripts/player/player.gd`：移动/相机/锁敌/体力/Focus/攻击/格挡/处决入口
- `enemy.gd`：追击 FSM + `EnemyAiCatalog` / behavior / Boss 宏层
- `combat_area.gd`：挥击去重与命中载荷
- `procedural_audio.gd`：程序化 SFX；设置音量经 `AudioServer` 总线

## Collision Layers

| Layer | Meaning |
|---:|---|
| 1 | Static world |
| 2 | Player body |
| 3 / value 4 | Enemy bodies |
| 4 / value 8 | Interactables |

## State Machines

### Player（运行时，18 态）

权威：`game/scripts/player/player.gd` → `enum State`（勿使用已删除的根目录旧脚本）。

```text
LOCOMOTION
ATTACK_WINDUP → ATTACK_ACTIVE → ATTACK_RECOVERY
DODGE | PARRY | GUARD_THRUST | CAST | CHARGE_HEAVY
LEAP_WINDUP → LEAP_ACTIVE → ATTACK_RECOVERY
STAGGER | GUARD_BROKEN
EXECUTE_WINDUP → EXECUTE_ACTIVE → EXECUTE_RECOVERY
GRABBED | DEAD
+ overlay: guard_active（非独立 State；E-11 setter）
```

Leap recovery 复用 `ATTACK_RECOVERY`。脆弱态与处决另由求解器/配对导演驱动。

### Enemy

```text
IDLE -> CHASE -> WINDUP -> ACTIVE -> RECOVERY -> CHASE
CHASE -> RETURN -> IDLE
+ STAGGER / PARRY_VULNERABLE / GUARD_BROKEN / WEAK_POINT_EXPOSED / DEAD
Boss：内容 phases + BossMacroBT（compat_macro，可换 LimboAI）
```

## Combat Data Ownership

- `CombatStyleData` / `AttackData` / `MovesetData` / `WeaponData` / `WeaponArtData` / `GuardProfile` 为权威 Resource
- `PoiseResolver` 玩家与敌人共用契约；`HandEquipment` 优先 Resource 引用
- 详表：[attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md)、[combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md)

## Focus Resource

独立 Focus 池（J-07）；法术/部分近战读 `AttackData.focus_cost`；扣费原子化（K-01）。见 [focus-resource.md](systems/focus-resource.md)。

## Related

- [devlog/index.md](devlog/index.md) · [tasks-master.md](tasks-master.md) · [controls.md](controls.md) · [validation.md](validation.md)
