# 局外装备接入 MVP

## 数据入口

- 装备表：`Config/Equipments.csv`
- 装备当前仍通过 `effect_keys` 驱动，多个效果用 `|` 分隔。
- 战斗读取入口：`BattleDirector.load_battle_loadout()`。
- 当前装备不新建独立脚本；优先复用 Battle 里已有的攻击、状态、Mana、生物质、结算奖励接口。

## 当前已实现 effect_keys

- `hide_enemy_hp`：隐藏敌方血条。
- `enemy_hp_random_up`：敌方生成时最大生命随机提高。
- `lust_reward_up`：战后淫能结算倍率提高，目前为 `x1.5`。
- `mana_recovery_up`：玩家 Mana 回复倍率提高，目前为 `x1.35`。
- `crit_rate_down`：玩家局内暴击率降低，目前为 `-8%`。
- `player_regen_down`：玩家生命恢复速度降低，目前为 `x0.25`。
- `minute_lust_add`：战斗中每 60 秒增加战后淫能基数，目前为 `+20`。
- `base_bio_cycle_yield_up`：基地每周期生产生物质产量提高，目前为每级周期产量 `+5`。
- `skill2_full_mana_required`：二技能必须 Mana 满时才能释放；一技能不受限制。
- `whip_charge`：玩家移动距离累积蓄力，最多 3 层，停止时释放 `equipment_whip_slash`。
- `whip_weapon_penalty`：常规武器伤害降低，目前为 `x0.5`。
- `player_speed_down_big`：玩家移速大幅降低，目前为 `x0.34`。
- `range_weapon_only`：局内新武器选择只给范围类武器；初始武器不符合时切到第一个范围武器。
- `bind_area_boost`：范围攻击威力和范围提高。
- `liquid_madness`：每 5 秒扣除玩家剩余血量 10%，并释放 `equipment_liquid_arc`。
- `forced_forward_move`：无移动输入时沿最后输入方向继续移动。
- `player_speed_up_small`：玩家移速提高，目前为 `x1.15`。
- `player_hp_down_big`：玩家最大生命大幅降低，目前为 `x0.34`。
- `exhibitionist`：提高局内攻击加值、暴击率、暴击倍率。
- `melee_lifesteal`：当前 MVP 给持有武器追加吸血。

## 当前装备

- `E001 空装备`：无效果。
- `E002 马眼罩`：`hide_enemy_hp|enemy_hp_random_up|lust_reward_up`。
- `E003 乳环导体`：`mana_recovery_up|crit_rate_down`。
- `E004 触手戒指`：`player_regen_down`。
- `E005 粘液束带`：`minute_lust_add|base_bio_cycle_yield_up`。
- `E006 魔乳纹章`：`skill2_full_mana_required`。
- `E007 小皮鞭`：`whip_charge|whip_weapon_penalty`。
- `E008 拘束服`：`player_speed_down_big|range_weapon_only|bind_area_boost`。
- `E009 射液狂`：`liquid_madness`。
- `E010 阴肛塞`：`forced_forward_move|player_speed_up_small`。
- `E011 暴露癖`：`player_hp_down_big|exhibitionist`。
- `E012 近战淫纹`：`melee_lifesteal`。

## 技能释放限制

- 玩家技能 1：默认 `Q / N`。
- 玩家技能 2：默认 `2 / M`。
- 所有技能释放后都有最低 CD，目前为 `7 秒`，用于限制特效堆叠和性能压力。
- 持续型技能再次按键可以停止；停止不受自身 CD 阻挡。

## 事件接口

- 复杂装备优先接到统一事件层，而不是单件装备写独立脚本。
- 当前事件名：
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

事件入口在 `BattleDirector.emit_equipment_event()`；运行时会记录 `equipment_event_counts` 和 `equipment_last_event_payloads`，用于 debug。

## 平衡待调

- `crit_rate_down = -0.08`
- `mana_recovery_up = x1.35`
- `player_regen_down = x0.25`
- `minute_lust_add = +20 / 分钟`
- `base_bio_cycle_yield_up = +5 / 周期`
- `player_skill_min_cooldown = 7 秒`
