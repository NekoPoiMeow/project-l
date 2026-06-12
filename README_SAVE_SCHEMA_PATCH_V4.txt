MVP patch v4

修正点：
1. 调试期默认补种一个占位俘虏 CPT_KNIGHT_001，避免地窖俘虏列表为 0。
2. 商人购买俘虏会写入 SaveDataJSON.dungeon.captives，并同步 unlocks.captives。
   如果旧存档已有商人购买次数但缺俘虏，也允许重新购买一次修复。
3. 商人俘虏商品调试期解锁改为 START。
4. 敌方基地不会被 hide_enemy_health_bars 隐藏本体血条，UI 顶部敌方基地血条强制显示。
5. destroy_enemy_base/test 条件增加兜底：敌方基地无效、is_dead 或 hp<=0 都会 record_battle_win，并触发临时道具清理/autosave。
6. Save0/SaveAuto/SaveAuto2 已写入调试用 20000 淫能 + 初始女骑士俘虏。

测试顺序：
- 确认覆盖的是正在打开的 Godot 项目文件夹。
- 从 SaveAuto 或 SaveAuto2 载入，进地窖应能看到白蔷薇女骑士。
- 商人买 CPT_WITCH_001 后，SaveDataJSON.dungeon.captives 应出现 CPT_WITCH_001。
- 打爆敌方基地后应显示目标完成并 autosave，临时商人道具和物化装备应在结算后清空。
