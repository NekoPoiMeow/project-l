MVP Bridge Patch V5
===================

本包是 v4 的增量修正，重点回应：不要在 Save0/AutoSave 里硬塞测试俘虏、商人俘虏必须走购买入存档、战斗胜负后必须进入局外升级。

覆盖内容：
- Script/SaveMgr/GameState.gd
- scenes/Dungeon/Dungeon.gd
- scenes/Merchant/Merchant.gd
- BattleAssets/ScriptShader/BattleDirector.gd
- Config/MerchantGoods.csv
- 其余 v4 所需 Config / UI 脚本保留

重要变化：
1. 不再在 make_default_data / normalize_save_schema / Dungeon._ready 里自动补 CPT_KNIGHT_001。
   新档默认俘虏为空，这是正式逻辑。

2. 商人初期保留一个 START 俘虏商品：MER_CAP_WITCH_001 -> CPT_WITCH_001。
   购买后通过 GameState.add_captive() 写入：
   - dungeon.captives[ref_id]
   - unlocks.captives
   - autosave

3. 第二个商人俘虏 MER_CAP_PRIEST_001 改为 CHAPTER_2 解锁，方便后续扩展正式进度。

4. 战斗胜负处理：
   敌方基地爆 / 我方基地爆 / 主角死，都会：
   - 结算淫能奖励（失败为当前奖励的 45%）
   - 清除 merchant.next_battle_effects / next_battle_temp_items / dungeon.next_battle_captive_equipment_id
   - autosave
   - 切换到 res://scenes/OutGame/OutGameUpgrade.tscn

5. 本包不再覆盖 Save/Save0.txt、SaveAuto.txt、SaveAuto2.txt，避免污染正式存档和测试档。

测试建议：
1. 确认覆盖的是 Godot 当前打开的项目文件夹。
2. 从有 20000 淫能的 AutoSave 载入。
3. 到商人购买 CPT_WITCH_001。
4. 进地窖确认俘虏列表出现狱原实验员。
5. 买一个临时道具，进 Chamber 确认显示。
6. 战斗胜利或死亡，确认回到局外升级，临时道具被清空，淫能写入自动档。

注意：
- 如果你之前已经把 v4 的 Save0/AutoSave 覆盖进项目，想恢复“新档无俘虏”，需要手动删除对应存档 JSON 里的 dungeon.captives.CPT_KNIGHT_001 与 unlocks.captives 里的 CPT_KNIGHT_001，或者重新从干净 Save0 模板生成。
