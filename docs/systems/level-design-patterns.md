# 关卡设计模式 (Level Design Patterns)

## Design Philosophy

烬渊 levels follow the **FromSoftware design principles** identified in the project's Dark Souls research, adapted to Chinese architectural and landscape traditions:

1. **Interconnected spaces with shortcuts** — levels loop back on themselves
2. **Environmental storytelling** — every object placement tells a story
3. **Telegraphed danger** — traps and hazards have visible/audible warnings
4. **Safe zones (shrines)** — placed before challenges, after gauntlets
5. **Optional exploration** — side paths reward curiosity with unique items/lore

---

## Puzzle Catalog

### Type 1: Environmental Manipulation (环境操作)

**Description:** Change the environment to open new paths.

| Puzzle | Chapter | Mechanic |
|--------|---------|-----------|
| Mirror Light Alignment | 1-3 | Rotate mirrors to direct light onto sealed door |
| Valve Shutoff | 1-4 | Pull two valves to disable toxic mist |
| War Banner Order | 2-5 | Raise banners in historical battle order |
| Beacon Lighting | 2-4 | Light beacons to affect next level's enemy behavior |
| Celestial Dials | 4-1 | Rotate floating stair segments into alignment |
| Alchemy Ingredients | 4-2 | Feed correct ingredients to three cauldrons |
| Gravity Anchors | 5-2 | Activate four anchor points in geometric sequence |

### Type 2: Key Item Gates (钥匙门)

**Description:** Find and use specific items to progress.

| Puzzle | Chapter | Key Item |
|--------|---------|----------|
| Furnace-Keeper's Seal | 1-5 | 守炉符文 → Boss door |
| Prisoner Keys | 2-3 | 3 key fragments → Free spirit-smiths |
| Offering Pedestal | 1-4 | Place rune on pedestal → Open door |
| Library Index | 4-3 | Find 4 texts → Combine cultivation technique |

### Type 3: Riddle/Knowledge (谜题/知识)

**Description:** Answer questions based on environmental clues or classical knowledge.

| Puzzle | Chapter | Source of Answer |
|--------|---------|-----------------|
| Nine-Tails Riddles | 3-5 | Chinese classical poetry, observable patterns in maze |
| Memory Verification | 3-2 | Identify real vs false memories |
| Samsara Choices | 5-3 | No correct answer — player's moral choice |

### Type 4: Stealth/Avoidance (潜行/回避)

**Description:** Avoid rather than fight.

| Puzzle | Chapter | Mechanic |
|--------|---------|-----------|
| Fox Wedding Procession | 3-3 | Hide from Wedding Gown Ghost during procession |
| Ember Shore | 5-1 | Bypass souls peacefully or face consequences |

### Type 5: Combat Trial (战斗试炼)

**Description:** Specific combat constraints create puzzle-like encounters.

| Puzzle | Chapter | Constraint |
|--------|---------|-----------|
| Soul-Forger Trials | 5-4 | No healing / time limit / point defense |

### Type 6: Gravity Inversion (重力反转) — L-16

**Description:** Gravity becomes a puzzle axis — flip it to walk ceilings, or toggle it per-zone. 不只作为陷阱：`campaign_module_runtime.gd` 现在真正取反 `player.gravity`（记录原符号、退出还原）。

| Puzzle | Chapter | Mechanic |
|--------|---------|-----------|
| 倒悬殿 (Inverted Hall) | 5-2 | `gravity_inversion` 纯翻转区：进入取反重力、离开还原（不含速度偏置） |
| Gravity Anchors | 5-2 | `gravity_anchor`：interact 切换目标区重力，按几何序列解锁通路 |

---

## Procedural Module Families (程序化模块族) — L-16/L-17

`procedural_level_modules.gd` 的 `MODULE_IDS` 现含 **20 族**（原 10 族 + 新增 10 族），关卡共 29 关。基础族：`hazard` / `gate_exit` / `fragile_floor` / `projectile_lane` / `poison_fire_zone` / `switch_offering` / `moving_platform` / `illusion_marker` / `gravity_visual_zone` / `arena_seal`。

新增谜题族（对应上方 Puzzle Catalog 各类型）：

| Module | 用途 | 对应关卡 |
|--------|------|----------|
| `mirror_light` | 镜光：转动镜面点亮光束，充能开启受光之门 | 1-3 |
| `valve_shutoff` | 阀门：双阀关闭毒雾 | 1-4 |
| `celestial_dial` | 天仪：旋转漂浮阶梯对齐 | 4-1 |
| `alchemy_ingredients` | 配料：向三座釜投喂正确材料 | 4-2 |
| `gravity_anchor` | 重力锚：interact 切换目标区重力 | 5-2 |
| `gravity_inversion` | 倒悬：纯翻转玩家重力 | 5-2 |
| `riddle_gate` | 谜语门：以谜底开门 | — |
| `stealth_passage` | 潜行通道：回避而非战斗 | 5-1 |
| `memory_verification` | 记忆验证：辨认真伪记忆 | 3-2 |
| `soul_forger_trial` | 铸魂试炼：战斗约束谜题 | 5-4 |

---

## Trap Catalog

### Type 1: Pressure Plate Traps (压力板陷阱)

**Tell:** Slightly raised stone, different color, scorch marks nearby.

| Trap | Chapter | Effect |
|------|---------|--------|
| Flame Vent | 1-2 | Wall jets — 3s, 15 dmg/s |
| Falling Gate | 1-2 | Instant death if under gate |
| Collapsing Floor | 1-1 | Falls after 2s standing on it |
| Spiked Pit | 3-1 | Disguised as flower bed |

### Type 2: Environmental Hazards (环境危害)

**Tell:** Visual damage, audio cues, environmental signs.

| Hazard | Chapter | Effect |
|--------|---------|--------|
| Toxic Mist | 1-4 | 8 dmg/s in area (can be disabled) |
| Glowing Liquid | 1-4 | 20 dmg/s on contact |
| Unstable Floor | 1-4 | Breaks if running, safe if walking |
| Burning Oil | 2-2 | Cauldrons can be tipped by player or enemies |
| Avalanche | 2-1 | Sound-triggered — sprint or loud combat triggers it |
| Wind Gusts | 4-1 | Push player toward edges |
| Gravity Swap | 5-2 | Sudden gravity reversal |
| Ember Geyser | 5-2 | Periodic superheated ash columns |

### Type 3: Enemy Ambush (敌人伏击)

**Tell:** Suspiciously empty room, visible item in center, environmental clues.

| Ambush | Chapter | Setup |
|--------|---------|-------|
| Mirror Shade emergence | 1-3 | Only attacks from behind via mirrors |
| Foxfire Lantern trigger | 3-3 | Approaching lantern triggers eruption |
| Book Spirit swarm | 4-3 | Picking wrong book spawns swarm |
| War Dog pairs | 2-2 | One distracts, one flanks |

### Type 4: Trap-Enemy Combinations

| Combination | Chapter | Design |
|-------------|---------|--------|
| Soldier + Flame Vents | 1-2 | Enemy patrols through trap zone — player must manage both |
| Guardian + Collapsing Stairs | 4-1 | Enemy knockback into falling hazard |
| Lanterns + Procession Ghost | 3-3 | Environmental hazard + timed enemy patrol |

---

## Shortcut Design Patterns

Following Dark Souls shortcut philosophy:

| Shortcut Type | Example | Purpose |
|--------------|---------|--------|
| **One-way gate** | Gate opened from far side | Creates "aha!" loop-back moment |
| **Ladder kick** | Drop ladder to upper level | Vertical shortcut to previous area |
| **Door from behind** | Barred door opened from inside | Connects new area to known safe zone |
| **Elevator** | Platform between levels | Fast return to shrine |
| **Breakable wall** | Thin wall with light behind | Hidden shortcut — reward for observation |

---

## Shrine Placement Guidelines

| Context | Placement Rule |
|---------|---------------|
| Level start | Always one shrine at level entrance |
| Pre-boss | Shrine within 30s walk of boss door, no enemies between |
| Post-gauntlet | After a particularly difficult combat section |
| Secret area entrance | Before optional challenge areas |
| Vertical hub | At major vertical transition points |
| **Never** | In direct line of sight of another shrine |
| **Never** | In a zone with active traps |
| **Never** | More than 3 minutes from the nearest shrine |

---

## Chinese Architectural Integration

Level geometry is inspired by Chinese architectural traditions:

| Chapter | Architectural Style | Key Visual Elements |
|---------|-------------------|---------------------|
| 1 | Han Dynasty temple ruins | Stone pillars, bronze mirrors, courtyard layout |
| 2 | Ming Dynasty fortress | Crenellated walls, beacon towers, military encampments |
| 3 | Classical Chinese garden | Pavilions, moon gates, winding paths, water features |
| 4 | Mythical heavenly palace | Cloud platforms, jade bridges, celestial motifs |
| 5 | Cosmic void + ritual bronzes | Abstract geometry, ritual bronze vessel shapes, star maps |
