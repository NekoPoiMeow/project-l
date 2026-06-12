MVP Save Schema Patch v3

覆盖重点：
1. 修复直接进入商人/地窖场景时可能没有正确载入当前存档的问题。
   - GameState.ensure_loaded() 在未显式 load_slot 时，会从 Save1/SaveAuto/SaveAuto2 中选择最像真实进度的槽位。
   - ProjectDebug 会打印当前 active slot 和 lust，方便确认 UI 读的是哪个存档。

2. 一次性规范 SaveDataJSON：
   - progress.unlocked_levels 正式接管关卡解锁。
   - level_bonus_collect 保留兼容，但不再作为关卡解锁来源。
   - upgrades 统一为 player/base/minion/dungeon/merchant。
   - building -> base, tentacle -> minion 自动迁移。
   - unlocks 增加 story_events/cg_events/narrative_events/temporary_items_seen。
   - dungeon 增加 events_seen/last_event_id/last_story_event_id/last_action_result。
   - merchant 增加 last_purchase_id。
   - story/runtime 新增，方便后续 AVG/CG 和 BattleDirector 接线。

3. 地窖 CG 规则保持：
   - 角色 x 调教道具 x 俘虏 全部存在才调教。
   - 特定组合第一次触发 special_event_id。
   - 触发后或通用 * 组合触发 generic_event_id。
   - 缺任意一项退回放置。

4. 局外升级 CSV 改为 base/minion/dungeon/merchant，不再继续扩散 building/tentacle。

5. SaveAuto/SaveAuto2 仍然是 20000 淫能测试档；Save0 是 0 进度模板。

建议测试顺序：
1. 启用 ProjectDebug Autoload。
2. 从 SaveAuto 或 SaveAuto2 载入，进入商人，确认打印 slot=SaveAuto/SaveAuto2 且 lust=20000。
3. 买 TMP_ATK_001，确认 lust 扣除，next_battle_temp_items 显示 TMP_ATK_001。
4. 进入备战，确认临时道具显示。
5. 战斗胜/败结算后，确认 clear_next_battle_consumables 清空临时道具。
