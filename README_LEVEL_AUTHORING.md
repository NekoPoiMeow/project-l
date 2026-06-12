# Project-L Level Authoring Guide

> Goal: create repeatable base-mode battle content without touching the architecture spine.

## 1. Minimum Level Row

`Level/Level.csv` columns:

```csv
id,chapter,level_no,name,x,y,next_ids,scene_path,unlocked,description,reward_captive_id,special_captive_id,unlock_flag,SelectSFX
```

Recommended row pattern:

```csv
L005,1,5,腐花庭院,1700,900,L006,res://scenes/Battle/Battle_005.tscn,FALSE,第一批基地防守关,CPT_PRIEST_001,,L004_CLEAR,res://Sound+BGM/06LevelSelect/SelectLevel.mp3
```

## 2. Required Meaning of Each Field

| Field | Meaning | Authoring Rule |
|---|---|---|
| `id` | Stable level ID | Never rename after save release. |
| `chapter` | Chapter number | Use for map grouping. |
| `level_no` | Display/order number | Keep unique inside chapter. |
| `name` | UI name | Content-facing. |
| `x,y` | Map node position | Visual only. |
| `next_ids` | Follow-up levels | Pipe-separated. Empty for chapter end. |
| `scene_path` | Battle scene | Must exist. Prefer duplicated Battle_00 style scenes first. |
| `unlocked` | Initial unlock | Only first/tutorial nodes should be TRUE. |
| `description` | UI description | Short. |
| `reward_captive_id` | Normal clear reward | Optional. Should be stable. |
| `special_captive_id` | Optional hidden/special reward | Use for branch/secret/scene rewards. |
| `unlock_flag` | Required clear flags | Pipe-separated, e.g. `L002_CLEAR|L003_CLEAR`. |
| `SelectSFX` | UI select audio | Optional but keep valid. |

## 3. Recommended MVP Level Types

### A. Tutorial / Entry

Purpose:

- Teach moving, shooting, base HP, enemy base target.
- Low enemy count.
- One reward captive or merchant unlock.

Rules:

- Enemy count: 20-60.
- No complex swarm.
- One clear reward only.

### B. Base Defense Mainline

Purpose:

- The repeatable core mode.
- Test base contact, spawn queues, equipment, merchant modifiers.

Rules:

- Enemy count: 80-180.
- 200 is acceptable as a stress ceiling.
- Use clear waves and one pressure spike.
- Keep story event optional after clear.

### C. Story / CG Short Scene

Purpose:

- Unlock a specific story event or captive/dungeon state.
- Can be shorter and more scripted.

Rules:

- Keep enemy count low.
- Use local scripted encounter.
- Do not invent a new battle architecture for one cutscene.

## 4. Battle Scene Creation Rule

For new levels, duplicate the closest existing battle scene/config first:

1. Duplicate `Battle_00.tscn` or current stable battle scene.
2. Create a matching `.ini` if needed.
3. Change only:
   - wave table
   - objective text/win condition
   - spawn positions
   - background/art references
   - reward linkage through `Level.csv`

Do not change shared scripts just to make a level unique.

## 5. Reward/Unlock Checklist

After clearing a new level:

- [ ] `Lxxx_CLEAR` or equivalent progress flag is saved.
- [ ] `next_ids` unlock visually on level map.
- [ ] `reward_captive_id` appears in dungeon/captive state if present.
- [ ] Story/CG unlock appears in gallery if intended.
- [ ] Returning to outgame does not wipe next-battle temp items incorrectly.
- [ ] Autosave works after settlement.

## 6. Base-Mode Design Notes

The main game can lean on base mode:

- Reusable waves.
- Different enemy compositions.
- Different reward/unlock rows.
- Different environmental blockers/backgrounds.
- Optional scripted stage events.

Avoid overdesigning every level. A good base-mode level needs:

1. One pressure pattern.
2. One reward or unlock.
3. One reason to replay/test a weapon/equipment.

## 7. Regression Test Per New Level

Run with at least three loadouts:

- Standard ranged weapon + empty equipment.
- Base/economy equipment, e.g. E005 or Princess equipment.
- Weird movement/behavior equipment, e.g. E007, E009, E010, E012.

Watch console for:

- Missing scene/path errors.
- Missing attack JSON.
- `[EquipmentAudit][MissingEffect]`.
- Save/load errors.
- Enemy/base contact not resolving.
