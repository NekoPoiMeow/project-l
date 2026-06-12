MVP Bridge Patch V8 - debug + render recovery

主要内容：
1. 修 StoryGallery/AppConfig 未声明：新增 Script/AppConfig.gd 兼容类，不需要 Autoload。
2. BattleDirector 恢复 shared GIF batch renderer 入口，配套 BattleSharedGifBatchRenderer.gd。
3. BattleDirector 恢复攻击数据 normalize：Flame/Strafe/Bullet/Lighting 等素材、anchor、hit_shape 兜底。
4. ProjectDebug 增加 dump_battle_modifiers()；BattleDirector 会在载入 loadout 后打印实际局内倍率。
5. floating number 每帧上限降到 8，避免调试浮字拖性能。

测试建议：
- 加 ProjectDebug 为 Autoload 后进战斗，控制台应出现 [BattleRuntime]，显示 run_player_attack_mul / run_lust_reward_mul。
- 买 TMP_ATK_001 后进战斗，run_player_attack_mul 应大于 1。
- 买 TMP_LUST_001 后进战斗，run_lust_reward_mul 应大于 1。
- StoryGallery 不应再报 AppConfig 未声明。
- 喷火器/Flame 类攻击应使用 left_center anchor，从角色右侧发出。

这版没有改 Save 文件。
