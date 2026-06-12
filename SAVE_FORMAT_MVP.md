# Project-L MVP 存档格式与变量规范（v3）

## 槽位约定

- `res://Save/Save0.txt`：0 进度模板，只用于重置/复制，不参与正常游玩。
- `res://Save/Save1.txt`：唯一手动主存档。
- `res://Save/SaveAuto.txt`、`res://Save/SaveAuto2.txt`：自动存档 A/B，交替写入。

`SaveDataJSON` 是唯一真实进度。外层 `SaveSlotId / SaveTime / SaveChapterID` 只给旧 UI 读取显示。

## 根字段总览

```json
{
  "meta": {},
  "economy": {},
  "battle_loadout": {},
  "progress": {},
  "unlocks": {},
  "upgrades": {},
  "dungeon": {},
  "merchant": {},
  "story": {},
  "runtime": {},
  "flags": {}
}
```

## meta

存档槽、显示、章节、最后场景、自动存档代数。

- `format_version`：存档格式版本。
- `slot_id`：`Save1 / SaveAuto / SaveAuto2 / Save0`。
- `slot_role`：`manual / autosave / template`。
- `is_zero_progress`：是否 0 进度模板。
- `save_name`：存档显示名。
- `save_time`：存档显示时间。
- `chapter_id`：当前章节编号。
- `chapter_name`：当前章节名。
- `last_scene`：最后场景路径。
- `play_seconds`：游玩秒数，暂可为 0。
- `autosave_generation`：自动存档代数。
- `last_autosave_slot`：上次写入的自动档。
- `last_loaded_slot`：最近载入槽位，调试用。

## economy

全局资源。

- `lust`：淫能。商人购买、局外升级、地窖放置收益、战斗结算都走这里。
- `humiliation`：全局屈辱统计，暂不作为地窖成长依据；地窖成长用每个俘虏自己的 `humiliation_xp / humiliation_level`。

## battle_loadout

备战选择。

- `character_id`：出击角色 ID，对齐 `Config/Characters.csv`。
- `weapon_id`：出击武器 ID，对齐 `Config/Weapons.csv`。
- `equipment_id`：出击装备 ID，对齐 `Config/Equipments.csv`。

## progress

章节/关卡进度。

- `unlocked_chapters`：已解锁章节 ID 列表。
- `unlocked_levels`：已解锁关卡 ID 列表。以后关卡解锁以这个为准。
- `cleared_levels`：已通关关卡 ID 列表。
- `last_level_id`：最近进入/通关关卡 ID。
- `level_bonus_collect`：旧构思遗留字段，不再作为关卡解锁来源；保留兼容旧存档。

## unlocks

和 Config 表对齐的解锁集合。

- `characters`：已解锁角色，对齐 `Characters.csv`。
- `weapons`：已解锁武器，对齐 `Weapons.csv`。
- `equipments`：已解锁/已见过装备，对齐 `Equipments.csv`，包括俘虏物化装备。
- `torture_items`：已解锁地窖调教道具，对齐 `TortureItems.csv`。
- `temporary_items_seen`：曾购买/见过的商人临时道具，对齐 `TemporaryItems.csv`。
- `story_events`：已触发剧情事件总集合，对齐 `StoryEvents.csv`。
- `cg_events`：已取得 CG 事件，通常是 `CG_` 前缀的 `StoryEvents.csv` ID。
- `narrative_events`：已取得非 CG 剧情事件。
- `codex`：图鉴条目。

## upgrades

局外升级等级。统一分组为：

- `player`
- `base`
- `minion`
- `dungeon`
- `merchant`

旧字段 `building` 会迁移到 `base`，旧字段 `tentacle` 会迁移到 `minion`。脚本里的 `set_upgrade_level/get_upgrade_level` 会自动兼容旧组名，但新 CSV 不应继续写 `building/tentacle`。

## dungeon

地窖状态。

- `captives`：拥有俘虏字典。key 是俘虏 ID，对齐 `Captives.csv`。
- `last_processed_battle_id`：最近处理过的战斗 ID，防止重复结算。
- `next_battle_captive_equipment_id`：物化后下局临时装备 ID，对齐 `Equipments.csv`。
- `events_seen`：已触发过的 DungeonEvents 事件开关。
- `last_event_id`：最近匹配到的 DungeonEvents 行 ID。
- `last_story_event_id`：最近触发的 StoryEvents ID。
- `last_action_result`：最近一次地窖操作的调试结果。

每个俘虏结构：

```json
{
  "id": "CPT_KNIGHT_001",
  "source": "merchant/chapter/battle/debug",
  "obtained_time": "",
  "processed": false,
  "pending_action": true,
  "humiliation_xp": 0,
  "humiliation_level": 0,
  "action_count": 0,
  "last_action": "passive/train/materialize",
  "last_item_id": "",
  "last_character_id": "",
  "last_action_time": ""
}
```

## merchant

商人状态。

- `next_battle_effects`：下局临时数值加成字典，给 BattleDirector 读取。
- `next_battle_temp_items`：下局临时道具 ID 列表，给 UI 显示和核实。
- `purchases`：商品购买次数，key 对齐 `MerchantGoods.csv.id`。
- `events_seen`：商人事件已看标记。
- `last_purchase_id`：最近购买商品 ID，调试用。

同一 `effect_key` 的临时道具每次营地只允许购买一个；不同 `effect_key` 可以同时购买。战斗胜利或失败结算时清空 `next_battle_effects / next_battle_temp_items`。

## story

剧情和 CG 运行态。

- `events_seen`：已看过的 StoryEvents。
- `cg_seen`：已取得 CG，通常和 `unlocks.cg_events` 同步。
- `narrative_flags`：剧情分支开关。
- `pending_event_id`：待 AVG/CG 系统读取的事件 ID。
- `last_event_id`：最近触发剧情事件。

## runtime

需要传递到局内的运行态缓存。后续 BattleDirector 接入时优先读这里，或由 GameState 方法生成。

- `pending_battle_modifiers`：合并后的下局数值修正。
- `pending_battle_sources`：修正来源列表。
- `last_battle_clear_reason`：清理下局临时状态的原因。

## flags

自由剧情/系统开关。适合存：教程开关、一次性特殊地窖事件是否已触发、地图机关、最近战斗结果等。

CG/剧情取得不要只放 flags；要同步写入 `unlocks.story_events / unlocks.cg_events / story.events_seen`。

## 关键接口约定

- `GameState.add_lust(amount)` / `spend_lust(amount)`：淫能加减。
- `GameState.unlock_level(level_id)`：写 `progress.unlocked_levels`。
- `GameState.record_level_clear(level_id)`：写 `progress.cleared_levels`，并确保该关卡已解锁。
- `GameState.unlock_item(category, id)`：通用解锁。
- `GameState.unlock_story_event(event_id)`：写 `story_events`，若 ID 以 `CG_` 开头，同时写 `cg_events`。
- `GameState.record_dungeon_story_result(dungeon_event_id, story_event_id)`：记录地窖事件和剧情/CG 事件。
- `GameState.clear_next_battle_consumables(reason)`：战斗胜利/失败结算后清空商人临时道具和地窖物化装备。

## 直接跑场景的调试说明

如果没有通过标题/存档 UI 明确 `load_slot()`，`ensure_loaded()` 会选择已有槽位中最像真实进度的存档，优先考虑非 0 淫能、章节、自动存档代数。这样直接运行商人/地窖场景时，不会默默回到 0 淫能或旧默认值。

发布版仍然应该通过存档 UI 调用 `GameState.load_slot(path)`。


## V6 调试存档清理约定

- Save0 保持真正 0 进度：不送俘虏，lust=0。
- SaveAuto / SaveAuto2 可作为调试档：lust=20000，但不送俘虏。
- 俘虏必须通过商人/关卡/剧情写入 `dungeon.captives`，不得靠存档模板兜底。


## v7 补充

- `progress.unlocked_levels`：关卡解锁的唯一主字段。`level_bonus_collect` 只保留旧兼容，不再驱动关卡解锁。
- `unlocks.story_events / cg_events / narrative_events`：剧情、CG、回想 UI 的解锁索引。
- `story.events_seen / cg_seen / narrative_flags / pending_event_id / last_event_id`：剧情播放状态与占位 AVG 路由。
- `merchant.next_battle_effects / next_battle_temp_items`：下局临时道具实际数值与 UI 显示 ID。战斗结算后清空。
- `dungeon.next_battle_captive_equipment_id`：地窖物化装备 ID，按 `Captives.equipment_base_id + _LV + humiliation_level` 得出。战斗结算后清空。
- `runtime.pending_battle_modifiers / pending_battle_sources`：BattleDirector 可读的合并后运行时加成，来源包括局外升级、商人临时道具与运行时注入。
- `flags.last_battle_result`：最近一局结算，包含 `lust_before / lust_reward / lust_after / lust_reward_mul / kill_count / battle_time`，用于局外升级界面显示。
