# Project L 开发接续索引

这个目录给 Codex 后续接续开发使用，避免 Markdown 散在项目根目录。项目原有文档暂不强行搬动，只在这里做索引。

## 文档位置

- `Docs/BATTLE_BASE_MINION_MVP.md`：基地与小兵 MVP 接口、升级效果状态、遗留项。
- `PROJECT_HANDOFF.md`：旧总交接文档，包含存档、关卡选择、个室、Battle、武器等历史信息。
- `Save/SAVE_FORMAT.md`：存档结构与 `GameState` 常用接口。
- `BattleAssets/BATTLE_STAGE_EDITOR.md`：Battle 关卡编辑、场景节点、ini、实体 json、攻击 json 说明。
- `Design/BaseInRunUpgradeDraft.md`：早期基地局内升级草案。
- `Docs/AI_CONTINUATION_GUIDE.md`：给后续 AI/开发者接手用的详细工程说明。
- `Docs/关卡配置中文说明.md`：中文关卡配置速查。

## 不重复造轮子的提醒

已有接口优先复用：

- 角色、武器、装备、运行时属性升级数据：`Config/Characters.csv`、`Config/Weapons.csv`、`Config/Equipments.csv`、`Config/WeaponUpgrades.csv`、`Config/RunStatUpgrades.csv`。
- Battle 已经会读取上述 CSV：`BattleDirector.load_battle_catalogs()`。
- 存档/解锁/局外升级接口：`Script/SaveMgr/GameState.gd`，包括 `unlock_item`、`is_unlocked`、`set_upgrade_level`、`get_upgrade_level`。
- 关卡选择数据：`Level/Level.csv`，不要重新发明关卡图鉴/关卡解锁结构。

## 模块状态速览

### 已有可继续扩展

- 存档与 AutoSave：已有。
- 角色/武器/装备 CSV：已有初步管理接口。
- 武器局内升级：已有 CSV + Battle 应用逻辑。
- Battle 攻击/弹幕/范围实例：已有骨架。
- Battle 基地/小兵 MVP：已有，详见 `Docs/BATTLE_BASE_MINION_MVP.md`。
- Battle 玩家技能 MVP：已有 Q/N 辅助技能、2/M 伤害技能，技能定义在 `BattleAssets/Skill_*.json`。
- LevelSelect 关卡选择：已有 CSV 驱动。

### 完全或接近 0 待做

- 触手祭坛局外升级 UI/购买流程。
- 局外临时 buff 道具的获取、装备、消耗流程。
- 俘虏/地窖转化为局外装备或下一局变化的完整流程。
- 装备局外 UI/购买/保存流程。
- 基地局外升级树真正驱动局内基地、小兵、建筑数值。
- 附属建筑的关卡内放置/切换/升级完整流程。

### MVP 占位，后续要改成实际机制

- 工蜂寻路：当前是 steering + 随机巡游，偶发卡位后续集中优化。
- 工蜂暂停规则：只有敌方非建筑单位与工蜂碰撞重叠时才暂停；镜头内有敌人不会暂停。
- `mutation_gift` 突变赠礼：基地生产单位时低概率额外生成？？？生物。
- `mana_per_bio`：已接入真实 Mana 回复和占位 Mana UI；正式美术条未做。
- 玩家技能 UI 目前有 Mana 占位条和 debug 文本；正式技能图标/冷却 UI 未做。
- 装备事件 API：已接入 MVP 事件分发，复杂装备可以监听移动、停止、命中、击杀、分钟 tick、生物质交付等事件。
- `revive` 不灭分身：已实装为消耗基地生命复活玩家 1 次。
- 基地/小兵升级选项：大部分可运行，仍有少量数值和表现层需要继续细化。
- 表现层：脚本光圈/染色/附件占位已接入，武器攻击 JSON 已开始映射 png/gif 素材，后续可继续换更精细 shader。
- 近战攻击图：`visual.anchor="left_center"` 表示默认向右素材左边中心绑定攻击点；向左攻击通过旋转保持边缘绑定。
- 基地图：基地 `visual.max_size` 约束显示大小，图片中心就是碰撞/实体圆心。

### 主要待调数值/体验

- 小兵生产周期、供能消耗、基地升级速度。
- 敌方波次、敌方基地血量、杂鱼压力。
- 工蜂移速、拾取范围、交付点位。
- 基地警戒区、交付区、接触伤害圈的可读性。

## 关卡编辑接续原则

- 关卡内效果、敌人波次、实体 json、攻击 json 主要由 Codex 逐步实现和记录。
- 非关卡的 UI 场景和美术搭建优先由用户手工做，Codex 负责指导接口和检查脚本接入，减少 token 消耗和美术反复。
- 新关卡优先复用 `Battle_00.tscn` / `Battle_00.ini` 结构；新增机制先写入 `BattleAssets/BATTLE_STAGE_EDITOR.md` 或本目录对应文档。

## Battle 固定输入

暂不做全局自定义键位 UI。Battle 先固定支持：

- 移动：WASD / 方向键。
- 技能1：Q / N，当前默认 `Skill_player_overdrive.json`，持续消耗 Mana，回血并强化输出/频率。
- 技能2：2 / M，当前默认 `Skill_player_laser.json`，鼠标方向释放伤害技能。
- 暂停：Space，由全局 `All_Pause.gd` 处理；升级暂停时仍允许空格暂停。
- 瞄准：鼠标方向。

## BulletTest 操作

`Battle_BulletTest.tscn` 用于攻击/技能/实体机制调试：

- Q / N：技能1。
- 2 / M：技能2。
- B：切换技能2预设：激光、camera 内非建筑爆破、前方矩形触手秒杀回血。
- V：在鼠标附近生成测试阵，包含调试超级兵、高血敌人、低血敌人、友方小兵、敌方基地。
- C：切换测试攻击来源：player / tentacle_base / friendly_minion / enemy / enemy_base。
- E：切换当前测试弹幕。
- Space：从当前测试来源发射当前测试弹幕。
- R：刷敌。
- 1-7：调整测试弹幕数量、伤害、范围、冷却、持续、速度、刷怪数量。

## 装备事件 API 规划

装备不是局外升级。局外升级偏数值；装备通过事件改变关卡内机制。当前 Battle 已有 MVP 事件层：

- `on_battle_start`
- `on_player_moved(distance)`
- `on_player_stopped`
- `on_attack_fired`
- `on_attack_hit`
- `on_bio_collected`
- `on_bio_delivered`
- `on_enemy_killed`
- `on_assimilation_complete`
- `on_minute_tick`
- `before_pick_level_choice`
- `filter_weapon_choice`

装备通过 `Equipments.csv.effect_keys` 注册行为，优先复用已有攻击、状态、Mana、生物质、结算奖励接口，避免每件装备写独立复杂脚本。

当前已接入的复杂装备 MVP：

- 小皮鞭：`whip_charge|whip_weapon_penalty`，移动蓄力，停止释放多段斩。
- 拘束服：`player_speed_down_big|range_weapon_only|bind_area_boost`，限制范围武器倾向并放大范围攻击。
- 射液狂：`liquid_madness`，每 5 秒扣剩余生命并发射穿透液弹。
- 阴肛塞：`forced_forward_move|player_speed_up_small`，无输入时沿最后方向前冲。
- 暴露癖：`player_hp_down_big|exhibitionist`，大幅降血换输出/暴击。
- 近战淫纹：`melee_lifesteal`，当前 MVP 给持有武器加吸血。

关卡事件动作补充：

- `change_scene`：读取 `scene_path` 并切换场景。
- 条件补充：`player_hp_below`、`base_hp_below`、`enemy_base_hp_below`，用 `amount` 表示血量比例阈值。
