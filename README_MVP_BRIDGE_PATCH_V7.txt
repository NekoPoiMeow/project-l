MVP Bridge Patch v7

重点：
1. BattleDirector 改为通过 GameState.build_battle_modifiers() 统一读取局外升级、商人临时道具和运行时加成。
2. 修复“命中敌人每帧显示淫能+20”的错误提示，命中不再伪造淫能收益。
3. 战斗结算使用 lust_before/lust_reward/lust_after 事务，OutGameUpgrade 显示前后值，避免看起来像重复结算。
4. 俘虏物化装备按屈辱等级 E_CPT_xxx_LV0~LV3 生效，Equipments.csv 描述和 effect_keys 已拉开等级差异。
5. 新增 scenes/StoryGallery 作为 CG/剧情回想占位 UI，读取 StoryEvents.csv 与存档 unlocks.story_events/cg_events/narrative_events。
6. Level/Level.csv 增量升级为关卡解锁/奖励俘虏字段，level_bonus_collect 仍兼容但不再作为主逻辑。

测试建议：
- 买 TMP_ATK/TMP_LUST 后进战斗，看 Debug/结算倍率是否变化。
- 地窖给俘虏加屈辱等级后物化，确认备战 UI 显示 E_CPT_xxx_LVn，进战斗效果有区别。
- 打爆敌方基地/主角死亡后，查看 OutGame 结算：淫能 before + reward = after。
