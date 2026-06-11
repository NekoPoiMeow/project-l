# Battle 关卡目标与事件 MVP

## 目标

Battle 关卡先不依赖手工摆复杂节点，优先通过 `scenes/Battle/*.ini` 配置目标、区域、事件。用户主要提供美术资源；Codex 负责按这些接口配置关卡数值、波次、目标和演出触发。

## 胜负基础

失败条件当前固定：

- 玩家死亡：失败。
- 我方基地死亡：失败。

胜利条件由 `[stage] win_condition` 和 `[objective]` 决定。

## 已支持 win_condition

- `destroy_enemy_base`：摧毁敌方基地。当前 `Battle_00` 默认使用。
- `survive_time`：坚持到指定时间。
- `reach_area`：玩家抵达指定区域。
- `escort_entity`：指定实体抵达指定区域。
- `kill_count`：击败指定数量敌人。
- `kill_entity_id`：击败指定 ID 的敌人若干个。
- `hold_area`：玩家在指定区域内累计坚持指定秒数，离开后进度会缓慢衰减。
- `activate_areas`：玩家累计进入多个区域，全部激活后胜利。
- `test`：测试关使用，不自动判定胜利。

## 目标配置示例

### 摧毁敌方基地

```ini
[stage]
win_condition="destroy_enemy_base"

[objective]
text="摧毁敌方基地"
```

### 坚持时间

```ini
[stage]
win_condition="survive_time"

[objective]
text="坚持到仪式完成"
duration=240
```

### 抵达区域

```ini
[stage]
win_condition="reach_area"

[objective]
text="抵达逃离点"
area="escape"

[area_escape]
shape="circle"
center="2200,1300"
radius=140
```

### 护送 NPC

```ini
[stage]
win_condition="escort_entity"

[objective]
text="护送祭品抵达出口"
area="exit"
target_entity_id="030"
target_faction="tentacle"

[area_exit]
shape="rect"
center="2500,1100"
size="260,220"
```

### 区域坚持

```ini
[stage]
win_condition="hold_area"

[objective]
text="在仪式圈内坚持"
area="ritual"
duration=45

[area_ritual]
shape="circle"
center="1600,1000"
radius=180
```

### 激活多个区域

```ini
[stage]
win_condition="activate_areas"

[objective]
text="激活三个仪式点"
areas="sigil_a|sigil_b|sigil_c"

[area_sigil_a]
shape="circle"
center="1000,800"
radius=120

[area_sigil_b]
shape="circle"
center="1800,1200"
radius=120

[area_sigil_c]
shape="circle"
center="2400,900"
radius=120
```

## 已支持 event 条件

事件节只做轻量触发。当前通过 `action` 字段执行动作，多个动作可用 `|` 分隔。

- `condition="time"`：到达时间触发。
- `condition="player_enter_area"`：玩家进入区域触发。
- `condition="kill_count"`：击杀数达到后触发。
- `condition="win"`：胜利时触发。
- `condition="loss"`：失败时触发。

示例：

```ini
[event_intro]
condition="time"
time=3
action="play_avg"
avg_id="AVG_BattleIntro"
once=true

[event_area_hint]
condition="player_enter_area"
area="ritual"
action="play_avg|area_fx"
avg_id="AVG_RitualHint"
once=true

[event_win]
condition="win"
action="play_avg"
avg_id="AVG_BattleWin"
once=true
```

## 已支持 event action

- `play_avg`：播放 AVG。字段：`avg_id`。
- `spawn_entity`：生成实体。字段：`entity_id`、`count`、`spawn`、`random_radius_min`、`random_radius`。
- `add_base_bio`：给我方基地增加生物质。字段：`amount`。
- `heal_player`：治疗玩家。字段：`amount`。
- `heal_base`：治疗我方基地。字段：`amount`。
- `damage_enemy_base`：对敌方基地造成固定伤害。字段：`amount`。
- `win`：直接触发胜利。
- `loss`：直接触发失败。字段：`reason`。
- `area_fx`：在事件区域播放一次区域激活表现。字段：`area`。

示例：

```ini
[event_ambush]
condition="player_enter_area"
area="ritual"
action="spawn_entity|area_fx"
entity_id="013"
count=6
spawn="area:ritual"
once=true

[event_supply]
condition="time"
time=90
action="add_base_bio|heal_base"
amount=120
once=true
```

## spawn 位置规则补充

- `spawn="MarkerName"`：使用 `Node2DSpawnPoints` 下的 Marker。
- `spawn="random_around_player"`：围绕玩家随机生成。
- `spawn="random_near_tentacle_base"`：围绕我方基地随机生成。
- `spawn="x,y"`：直接使用坐标。
- `spawn="area:area_id"`：在 `[area_area_id]` 范围内随机生成。

## 区域表现

- 和当前目标/事件有关的 area 会自动画出淡蓝色范围线。
- `activate_areas` 或 `area_fx` 触发时，区域线会变亮，并播放一次简单光圈与浮字。
- 当前是脚本占位表现，后续可替换为 png/gif、Shader 仪式圈、地面特效。

## 当前限制

- 区域已有淡色范围线和简单光圈反馈，正式区域美术/Shader/节点表现待做。
- `escort_entity` 需要关卡波次或初始生成先放出对应 `target_entity_id`。
- 事件动作已有基础关卡控制能力；复杂机关如开门、改背景、改变敌方 AI、启停波次还需要继续扩展 action。
- 胜利/失败后的正式结算 UI、返回流程仍未完善。
