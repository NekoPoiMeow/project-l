# MVP Bridge Patch V6 - Clean Save + Remaining Work Notes

本包基于 v5 增量，额外加入干净 Save 文件，用于清除 v4 期间测试兜底俘虏造成的污染。

## Save 覆盖策略

- `Save/Save0.txt`：干净 0 进度模板，lust=0，无俘虏。
- `Save/SaveAuto.txt`：调试自动档，lust=20000，无俘虏。
- `Save/SaveAuto2.txt`：调试自动档，lust=20000，无俘虏。
- 不覆盖 `Save/Save1.txt`，避免误伤你的手动主档。

## 俘虏测试方式

正式/调试统一逻辑：开局无俘虏，通过商人初始商品购买至少一个俘虏。

- `MER_CAP_WITCH_001`：START 解锁，可开局购买。
- 购买后写入 `SaveDataJSON.dungeon.captives` 与 `SaveDataJSON.unlocks.captives`。

## 当前已知未完全收尾

1. BattleDirector 中商人临时道具的实际数值加成已接入口，但仍需要逐项确认每个 `effect_key` 是否真的影响对应战斗变量。
2. 物化装备 ID 已能从地窖写入下局，但 `Equipments.csv.effect_keys` 到局内具体数值的映射还需要补全测试。
3. CG/StoryEvents 目前是占位文本/解锁记录，尚未接完整 AVG Router/画廊。
4. 章节/关卡解锁 CSV 与关卡奖励还没有正式表驱动化。
5. 局外升级 UI/CSV 已有占位，但每个升级 effect_key 是否全部落到 GameState/BattleDirector 仍需逐个补钩子。
