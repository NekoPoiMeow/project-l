# Project-L Story / CG Authoring Guide

> Goal: add story, dungeon CG, merchant events, and gallery entries without disturbing the core systems.

## 1. StoryEvents.csv Row

Current columns:

```csv
id,name,kind,description,cg_path,avg_scene_path,placeholder_text
```

Recommended row:

```csv
CG_DUN_PRIEST_BIND_GENERIC,白花修女拘束普通,dungeon,修女拘束调教普通事件。,res://CG/Dungeon/priest_bind_generic.png,res://AVG/Dungeon/priest_bind_generic.tres,白花修女拘束普通CG占位。
```

## 2. Event ID Naming

Use stable prefixes:

| Prefix | Use |
|---|---|
| `EVT_` | Non-CG story/merchant/outgame event. |
| `CG_DUN_` | Dungeon CG. |
| `CG_MAIN_` | Main story CG. |
| `CG_MER_` | Merchant CG. |
| `CG_CAP_` | Captive personal event. |

Do not rename event IDs after they appear in saves.

## 3. DungeonEvent Connection

`DungeonEvents.csv` connects actor/item/captive combinations to StoryEvents.

Columns:

```csv
id,actor_id,item_id,captive_id,min_humiliation_level,flag_key,special_event_id,generic_event_id,locked_text,unlocked_text
```

Recommended pattern:

- Generic row: `actor_id=*`, no `flag_key`, empty `special_event_id`, valid `generic_event_id`.
- Special row: exact actor + item + captive, unique `flag_key`, valid `special_event_id`, fallback `generic_event_id`.

Example logic:

1. Player selects actor + torture item + captive.
2. Dungeon checks exact special combo.
3. If `flag_key` not seen, unlock special event.
4. After seen, use generic fallback.

## 4. Placeholder Policy

It is okay for MVP to use placeholders if:

- `placeholder_text` clearly describes the scene.
- `cg_path` is stable even if the image is not final.
- Gallery can display fallback text if art is missing.

Do not block gameplay because final CG is not ready.

## 5. Recommended Story Production Order

For each story/CG event:

1. Add `StoryEvents.csv` row.
2. Add unlock source:
   - Level clear, or
   - DungeonEvents row, or
   - Merchant event, or
   - Manual story flag.
3. Test unlock.
4. Test gallery display.
5. Test save/load.
6. Replace placeholder art later.

## 6. Mainline Chapter Skeleton

A practical MVP chapter structure:

| Beat | Content |
|---|---|
| 1 | Arrival / beach or ruins entry. |
| 2 | First base defense clear. |
| 3 | First captive reward. |
| 4 | Dungeon tutorial event. |
| 5 | Merchant introduction event. |
| 6 | Branch level with special captive or CG. |
| 7 | Chapter boss/base-defense spike. |

Keep each beat short. The base-mode battle does the replayable work.

## 7. One-Off Story Scenes

For short story scenes, do not build a new game mode unless necessary. Prefer:

- Existing battle scene with low enemy count.
- Existing outgame UI with a popup/StoryTeller entry.
- Existing dungeon event path.
- Existing gallery route.

## 8. Save/Unlock Test

After adding a story event:

- [ ] Trigger event once.
- [ ] Confirm gallery unlock.
- [ ] Save and reload.
- [ ] Confirm event remains unlocked.
- [ ] Confirm one-time special events do not repeat unless intended.
- [ ] Confirm generic fallback still works.
