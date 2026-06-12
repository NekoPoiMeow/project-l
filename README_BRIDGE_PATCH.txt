地窖/商人/局外升级/局内传递占位补丁

覆盖路径：
Script/SaveMgr/GameState.gd
BattleAssets/ScriptShader/BattleDirector.gd
scenes/Dungeon/Dungeon.gd
scenes/Dungeon/Dungeon.tscn
scenes/Merchant/Merchant.gd
scenes/Merchant/Merchant.tscn
scenes/OutGame/OutGameUpgrade.gd
scenes/OutGame/OutGameUpgrade.tscn
Config/Captives.csv
Config/TortureItems.csv
Config/DungeonActions.csv
Config/DungeonEvents.csv
Config/TemporaryItems.csv
Config/MerchantGoods.csv
Config/StoryEvents.csv
Config/Equipments.csv
Config/OutGameUpgrades.csv

规则：
1. 不重写 Save 机制，只增量扩展 SaveDataJSON 内的 unlocks/merchant/dungeon/flags。
2. 调教必须 actor + torture item + captive 三者齐全；缺任意一个就按放置处理。
3. DungeonEvents.csv 使用 exact actor 特别CG + * actor 普通CG。特别CG一次性，flag_key=1 后回到普通CG。
4. 俘虏物化直接映射到 Equipments.csv 的 E_CPT_XXX_LV0~LV3，不再单独维护 CaptiveEquipments.csv。
5. 商人临时强化来自 TemporaryItems.csv，购买后写入 merchant.next_battle_effects，下局进 BattleDirector。
6. 战斗胜/败结算后清除下局临时道具和俘虏物化装备。
