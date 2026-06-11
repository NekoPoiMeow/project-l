# Battle 基地与小兵 MVP 接口文档

本文记录基地/小兵系统当前接口、已实现状态和遗留项。后续改脚本、json、表格时请同步更新。

## 已实现

- 基地升级暂停选择：每级先选基地能力，再选小兵能力方向。
- 基地生产队列：`base.spawn_queues` 每个兵种一条独立队列，高级队列优先获得生物质供能。
- 生物质电量逻辑：生物质不足时生产/进化继续，但走低速倍率。
- 工蜂：`ai.mode = "worker_collect_bio"`，负责基地附近资源拾取、交付、随机巡游。仍偶发卡位，后续集中优化。
- 小兵目标：战斗小兵支持 `objective_fallback`，无合适目标时推进敌方建筑/基地。
- 基地队列 UI：运行时动态创建 `PanelBaseQueues`，显示已解锁队列、等级、数量、供能和进度。
- Mana 占位 UI：运行时动态创建 `PanelMana / ProgressBarMana / LabelMana`，后续可替换为 png 边框或 `TextureProgressBar`。
- 表现层接口：实体支持 `visual_fx`、`visual_stages`、`visual_attachments`，升级选项支持 `attachment`。
- 实体视觉支持 `visual.max_size`，GIF/PNG 会按最大盒子居中缩放；基地 033 系列已用该接口限制尺寸。
- 不灭分身：选到 Lv4 基地能力后，玩家死亡时若基地血量足够，消耗基地生命并在基地附近复活玩家 1 次。
- 小兵命中状态：队列支持 `on_hit_statuses`，当前用于淫能施释触的短控/易伤方向。
- 基地菌毯特殊效果：支持 `contact_status`、`contact_execute_chance`、`contact_execute_hp_ratio`。
- 小兵死亡/低血机制：队列支持 `death_attack`、`low_hp_attack_damage_mul`。
- 队列动态生产周期：队列支持 `enemy_base_missing_hp_interval_mul`，可随敌方基地残血加快生产。

## Entity JSON 接口

### AI

```json
{
  "ai": {
    "mode": "chase_nearest",
    "movement_mode": "direct",
    "target_priority_order": ["minion", "unit", "base", "building"],
    "target_distance_mode": "nearest",
    "target_factions": ["enemy"],
    "objective_fallback": true,
    "objective_fallback_radius": 0,
    "objective_fallback_priority_order": ["base", "building"],
    "leash_radius": 0
  }
}
```

- `objective_fallback`: 没有感知目标时是否找敌方建筑/基地。
- `objective_fallback_radius`: fallback 搜索半径，`0` 表示不限制。
- `objective_fallback_priority_order`: fallback 目标排序，常用 `["base","building"]`。
- `leash_radius`: 未来护家/游击用。`0` 表示不限制，非 0 时超出基地距离后不做全图 fallback。

### 表现

```json
{
  "visual_fx": {
    "shader": {"tint": "ff5fdc", "tint_strength": 0.12, "pulse_strength": 0.06},
    "halo": {"color": "ff4fd8", "alpha": 0.10, "size": [260, 150], "offset": [0, 18]},
    "aura_ring": {"color": "ff50cf", "alpha": 0.34, "radius": 120, "width": 4},
    "orbit_dots": {"color": "ffd8fb", "count": 6, "radius": 92, "size": 5}
  },
  "visual_stages": {
    "level_3": {
      "modulate": "ffc6ef",
      "shader": {"tint": "ff4bb9"},
      "burst": {"color": "ff3eb6", "radius": 178, "width": 8},
      "attachments": []
    }
  },
  "visual_attachments": [
    {"id": "base_level_2_left", "level_min": 2, "offset": [-118, 42], "size": [50, 72], "color": "ff76d7"}
  ]
}
```

- `visual_fx`: 常驻脚本表现，不依赖美术资源。
- `visual_stages.level_N`: 基地或实体阶段变化时触发，可换图、染色、burst、挂附件。
- `visual_attachments`: 实体常驻/等级条件附件。没有 `texture/gif` 时用脚本占位色块+圈；有资源时写 `texture` 或 `gif`。

### 升级选项附件

```gdscript
{
  "id": "void_laser",
  "base_laser": true,
  "attachment": {
    "id": "void_laser_node",
    "offset": [0, -128],
    "size": [78, 54],
    "color": "b35cff",
    "z_index": 2
  }
}
```

## 基地升级效果状态

| 等级 | 方向 | 选项/接口 | 当前状态 |
|---|---|---|---|
| Lv2 | 基地 | `quantity_add` | 已实装，生产数量增加 |
| Lv2 | 基地 | `bio_cycle_add` | 已实装，周期生物质增加 |
| Lv2 | 基地 | `aura_speed_mul` / `aura_regen_add` | 已实装，警戒区内友军加速/回血 |
| Lv2 | 小兵 | `stat_mul` / `reward_bio_add` | 已实装 |
| Lv3 | 基地 | `interval_mul` | 已实装，队列生产周期缩短 |
| Lv3 | 基地 | `mutation_gift` | 已实装，生产单位时低概率额外生成？？？生物 |
| Lv3 | 基地 | `all_minion_stat_mul` | 已实装，已有小兵即时加成 |
| Lv3 | 小兵 | `stat_mul` / `bio_on_hit_add` | 已实装 |
| Lv4 | 基地 | `mana_per_bio` | 已实装，交付生物质会实际回复玩家 Mana，并显示占位 Mana UI |
| Lv4 | 基地 | `base_laser` | 已实装，基地周期触炮 |
| Lv4 | 基地 | `revive_count` | 已实装，不灭分身消耗基地生命复活玩家 |
| Lv4 | 小兵 | `on_hit_status` | 已实装，caster 可获得短控或易伤命中状态 |
| Lv5 | 基地 | `assimilation_lust_add` | 已实装，计入本局战后淫能奖励 |
| Lv5 | 基地 | `contact_damage_mul` / `contact_cooldown_mul` | 已实装 |
| Lv5 | 基地 | `contact_status` / `contact_execute_*` | 已实装，菌毯减速/低血斩杀 |
| Lv5 | 小兵 | `assimilated_stat_mul` | 已实装，影响已有和未来同化单位 |
| Lv5 | 小兵 | `assimilated_building_mul` | 已实装 |
| Lv5 | 小兵 | `assimilated_invuln` | 已实装，周期短暂无敌 |
| Lv6 | 基地 | `spawn_enemy_base_damage` | 已实装，每次生产伤害敌方基地 |
| Lv6 | 基地 | `extraction_lust_add` | 已实装，计入本局战后淫能奖励 |
| Lv6 | 基地 | `enemy_base_missing_hp_interval_mul` | 已实装，敌方基地越残，强袭触战兵生产越快 |
| Lv6 | 小兵 | `low_hp_attack_damage_mul` / `death_attack` | 已实装，低血狂暴/死亡爆炸 |
| Lv7 | 基地 | `summon_entity_id` | 已实装，按实体半径找基地外出生点 |
| Lv7 | 基地 | `base_laser` + `contact_damage_mul` | 已实装 |

## 遗留项

- 工蜂路径仍是 steering，不是完整寻路；偶发卡位后续集中处理。
- 生产队列 UI 是 MVP 动态 UI，视觉还需统一美术和布局。
- 附属建筑附件目前只支持实体相对坐标；如需关卡空气墙坐标，应扩展为 `space: "world"` 或 stage 配置。

## Runtime UI 节点约定

- `PanelMana`：Mana 条占位容器。
- `ProgressBarMana`：当前 Mana 数值条。
- `LabelMana`：Mana 数字与回复速率。
- `PanelBaseQueues`：基地生产队列容器。

这些节点目前由 `BattleDirector.setup_ui()` 动态创建。后续如果场景中手工放置同名节点，脚本会优先复用，方便替换美术资源。

## 小兵命中状态接口

基地队列可写：

```json
{
  "on_hit_statuses": [
    {"status": "control", "duration": 1.2, "chance": 0.18, "speed_mul": 0.65},
    {"status": "vulnerable", "duration": 3.0, "chance": 0.35, "damage_taken_mul": 1.18}
  ]
}
```

- `control`：临时改变非建筑敌人的阵营/目标，结束后恢复。
- `vulnerable`：易伤，`damage_taken_mul` 会进入受伤乘区。
- 默认不影响建筑；若某状态要影响建筑，需要显式写 `include_building: true`。

## 基地接触圈接口

基地升级可写：

```json
{
  "contact_status": {"status": "slow", "duration": 1.8, "slow_mul": 0.58, "chance": 1.0},
  "contact_execute_chance": 0.28,
  "contact_execute_hp_ratio": 0.22
}
```

- `contact_status`：基地菌毯/接触圈命中非建筑敌人时挂状态。
- `contact_execute_chance`：低血斩杀概率。
- `contact_execute_hp_ratio`：敌人血量比例低于该值时才会判定斩杀。

## 队列特殊机制接口

```json
{
  "enemy_base_missing_hp_interval_mul": 0.55,
  "low_hp_attack_damage_mul": 1.65,
  "low_hp_attack_threshold": 0.38,
  "death_attack": {
    "kind": "attack_instance",
    "hit_shape": {"mode": "circle", "radius": 118},
    "hit_rule": {"mode": "on_spawn_once"},
    "target_filter": {"relation": "enemy", "include_building": false},
    "effects": [{"mode": "damage", "value": 72}]
  }
}
```

## 突变赠礼接口

Lv3 基地选项使用突变赠礼。该能力写在基地升级选项中：

```json
{
  "mutation_gift": {
    "chance_base": 0.04,
    "chance_per_level": 0.012,
    "entity_ids": ["031", "027", "032"]
  }
}
```

- 每次基地队列成功生产一个单位后独立判定一次。
- 实际概率为 `chance_base + (base_level - 1) * chance_per_level`，脚本内上限暂锁 75% 防止测试爆量。
- `031`：暗影美少女，高速冲撞型突变单位，实体由 `BattleAssets/031.json` 配置。
- `027`：成品触手服美少女，吃同化单位相关加成。
- `032`：不直接生成实体，调用 `Attack_mutation_head_bullets.json` 发射 3 枚美少女头子弹。

## 新素材实体接入

- `020.gif`：工蜂，已映射到 `020.json`。
- `021-027.gif`：基地生产线小兵与同化完成单位，已映射到对应 JSON。
- `029.gif`：影之从者触，已新增 `029.json`，Lv7 基地召唤项调用该 ID。
- `030.gif`：裂空噬灭触，已新增 `030.json`，当前作为可被关卡/测试直接调用的远程爆破小兵。
- `031.gif`：暗影美少女，已新增 `031.json`，突变赠礼可生成。
- `032.gif`：美少女头子弹，突变赠礼中通过 `Attack_mutation_head_bullets.json` 发射。
- `033.gif` 到 `033_7.gif`：基地等级图，已配置 `visual_stages.level_2` 到 `level_7`，并用 `max_size` 约束显示尺寸。

- `enemy_base_missing_hp_interval_mul`：敌方基地血量越低，生产周期越接近该倍率。
- `low_hp_attack_damage_mul`：单位自身低血量时攻击乘区。
- `death_attack`：单位死亡时在死亡位置释放一次攻击实例。
