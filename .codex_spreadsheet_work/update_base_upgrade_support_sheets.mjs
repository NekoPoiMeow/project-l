import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const path = "D:/project-l/output/BaseInRunUpgradeDraft_CN.xlsx";
const input = await FileBlob.load(path);
const workbook = await SpreadsheetFile.importXlsx(input);

const supportSheets = [
  {
    name: "总览规则",
    rows: [
      ["主题", "草案规则", "备注"],
      ["增量原则", "只在现有 Battle MVP、场景和脚本架构上增量扩展。", "不推翻重写；用户不使用 git，避免不可回滚的大改。"],
      ["基地等级上限", "默认 Cap 为 Lv7；每个关卡可以单独降低 Cap。", "关卡配置决定本局能开放到几级。"],
      ["Lv1 基地", "基地无能力；拥有 1 个无敌工兵（工蜂）。", "工蜂只负责拾取、搬运、交付，不攻击。"],
      ["升级暂停", "基地进化到下一级时暂停游戏，弹出基地升级选择。", "形式类似主角升级暂停。"],
      ["选择结构", "每次基地升级：展示基础获得，再从当级 3 个基地能力中选 1 个；同时展示已解锁触手兵，并从该兵 3 个方向中选 1 个。", "UI 文案必须主谓宾清晰，避免只有词条名。"],
      ["与 Player 切分", "基地升级原则上不直接改 Player；若表中出现 Player 相关效果，应该标记为基地/菌毯/交付区提供的外部效果。", "例如费洛蒙域、触感同调、灵触秘法、不灭分身。"],
      ["生物质含义", "生物质更像供能/电量，不是单纯矿产。", "影响生产队列速度和基地进化速度。"],
      ["高级兵供能优先", "同一时刻供能不足时，优先满足当前已解锁的最高级兵生产队列；低级队列因生物质不足进入低速生产。", "例如库存 666 只能满足顶级兵，则顶级兵正常生产，其他兵按低供能速度生产。"],
      ["低生物质生产", "生物质不足时，小兵队列仍推进，但速度降到 50%。", "后续能力可把 50% 提升到更高。"],
      ["低生物质进化", "生物质不足时，基地进化仍推进，但速度降到 20%。", "保证基地慢慢长，但鼓励供能。"],
      ["独立生产队列", "每个兵种/等级有独立生产 Bar。", "Lv2 一个 Bar，Lv3 另一个 Bar；供能分配时按等级从高到低处理。"],
      ["基地暴击规则", "基地类输出默认暴击率 0、暴击倍率 0，不参与暴击。", "暴击只给 Player、敌我小兵使用。"],
      ["实体与素材来源", "小兵、基地、敌友单位优先通过 BattleAssets 下的 json entity_id 调用；视觉读取 json 内 visual.gif。", "同一个 json/素材可在不同关卡通过 faction、stats、ai 覆盖变成敌人或友军。"],
      ["演出接口", "受伤、死亡、攻击、生产、生成、待机等演出资源全部预留字段；为空时跳过。", "占位素材不全时保持为空即可，不需要单独开 Minions 占位目录。"],
    ],
  },
  {
    name: "工兵规则",
    rows: [
      ["规则项", "具体规则", "实现/配置备注"],
      ["基础定位", "工蜂类似玩家的自动搬运单位，可以磁吸生物质，并把生物质带到交付区供给基地。", "无攻击，不参与伤害结算。"],
      ["生存规则", "工蜂无敌，不会死亡。", "不显示血条；不吃弹幕伤害。"],
      ["行动半径", "工蜂行动半径比基地警戒区略大。", "建议字段：worker_radius = base_alert_radius + extra_radius。"],
      ["磁吸拾取", "工蜂在行动半径内不断寻找可拾取生物质；进入磁吸范围后自动吸附。", "建议字段：pickup_seek_radius、pickup_magnet_radius、pickup_speed。"],
      ["交付规则", "工蜂携带生物质后前往基地交付区，把生物质交给基地。", "交付区沿用基地 delivery zone，或单独指定 worker_delivery_zone。"],
      ["接触暂停", "敌人接触工蜂时，工蜂暂停行动；接触它的敌人死亡后，工蜂恢复行动。", "只响应敌方实体接触，不响应敌方弹幕。"],
      ["穿透规则", "敌我小兵、Player 都可以穿过工蜂；工蜂不阻挡路径。", "工蜂不作为阻挡碰撞体。"],
      ["弹幕规则", "敌人弹幕不影响工蜂行动。", "不触发暂停，不造成伤害，不推开。"],
      ["寻路要求", "工蜂需要寻路，不能被基地或空气墙卡住。", "移动目标应经过可行走检测；被卡住时重算路径。"],
      ["默认 AI 循环", "找最近可拾取生物质 -> 磁吸拾取 -> 携带到交付区 -> 交付 -> 继续寻找。", "若无可拾取生物质，则在基地附近巡航等待。"],
      ["占位素材建议", "优先复用 BattleAssets 现有 gif/json；工蜂也应是一个可调用 entity_id。", "不单独新建 Minions 占位目录。"],
    ],
  },
  {
    name: "供能规则",
    rows: [
      ["规则项", "草案规则", "数值/顺序", "备注"],
      ["队列结构", "每个触手兵种拥有独立生产 Bar。", "Lv2-Lv6 常规兵各一条；Lv7 究极兵不是常规生产。", "避免所有兵抢同一个进度条。"],
      ["供能优先级", "同一帧/同一结算周期中，优先满足最高级已解锁兵种的供能需求。", "从最高等级队列向低等级队列依次判定。", "库存不足时，低级队列不会停，只会降速。"],
      ["正常供能", "当前库存/供能状态能满足该队列需求时，该队列正常生产。", "100% 生产速度。", "是否扣库存以后实现时再定；表意上按“供能满足”处理。"],
      ["低供能生产", "轮到某队列时供能不足，该队列进入低速生产。", "默认 50% 生产速度。", "能力可提高低供能速度。"],
      ["基地进化供能", "基地进化不应完全停摆；供能不足时仍慢速推进。", "默认 20% 进化速度。", "避免玩家节奏断掉。"],
      ["过量供能", "可选后续状态：库存很高时，生产/进化略微加速。", "例如生产 115%，进化 120%。", "先保留，不急着实现。"],
      ["基地基础产出", "以基地等级 sheet 为准。", "Lv2=5；Lv3=15；Lv4=40；Lv5=80；Lv6=200；Lv7=400。", "这是基础获得，不属于三选一能力。"],
      ["生物质转结算", "淫能萃取等能力可把当局获得的生物质按比例转化为战后淫能基数。", "Lv6 20%，Lv7 25%。", "这是结算规则，不影响战中库存。"],
    ],
  },
  {
    name: "基地能力池",
    rows: [
      ["能力ID", "来源等级", "中文名", "玩家可见效果草案", "数值随等级", "影响对象", "基地是否暴击", "美术/特效接口"],
      ["BASE_PASSIVE_HP_REGEN", "Lv1-Lv7 基础", "基地血量/回血成长", "基地升级后，基地最大血量和回血速度提高。", "以基地等级 sheet 的倍率为准。", "基地", "不暴击", "base_level_visual_key；base_idle_anim"],
      ["BASE_PASSIVE_CREEP_AOE", "Lv1-Lv7 基础", "菌毯应激", "基地警戒区周期性释放弱伤害 AOE，清理贴近基地的弱敌。", "范围、周期、伤害以基地等级 sheet 为准。", "基地输出", "不暴击", "creep_aoe_fx_ini；base_attack_anim"],
      ["BASE_PASSIVE_BIO_PROD", "Lv2-Lv7 基础", "基础生物质生产", "基地周期性生产生物质。", "Lv2=5；Lv3=15；Lv4=40；Lv5=80；Lv6=200；Lv7=400。", "基地经济", "不暴击", "bio_production_fx_ini"],
      ["B_L2_MULTI_CELL", "Lv2 可选", "多胞触手", "2级触手生物“不稳定造物”每次生产数量增加。", "Lv2+1；Lv3+2；Lv4+2；Lv5+3；Lv6+3；Lv7+4。", "不稳定造物队列", "不暴击", "addon_texture；production_fx_ini"],
      ["B_L2_BIO_CONVERT", "Lv2 可选", "触质转化", "加强基地周期性生物质产出。", "Lv2+10；Lv3+15；Lv4+25；Lv5+50；Lv6+100；Lv7+200。", "基地经济", "不暴击", "addon_texture；bio_production_fx_ini"],
      ["B_L2_PHEROMONE", "Lv2 可选", "费洛蒙域", "基地警戒区内，Player 和我方小兵移速、生命恢复速度小幅提高。", "Lv2+3%；Lv3+3.5%；Lv4+4%；Lv5+4.5%；Lv6+5%；Lv7+6%。", "菌毯内友军", "不暴击", "aura_texture；pheromone_aura_fx_ini"],
      ["B_L3_BIRTH", "Lv3 可选", "剖腹生产", "3级触手生物“汲取萃汁触”生产周期缩短，所需生物质减少，低供能惩罚降低。", "Lv3-15%；Lv4-18%；Lv5-21%；Lv6-24%；Lv7-30%。", "汲取萃汁触队列", "不暴击", "addon_texture；birth_fx_ini"],
      ["B_L3_SYNC", "Lv3 可选", "触感同调", "基地母巢每等级加强玩家攻击技能威力。", "Lv3+10%；Lv4+12%；Lv5+15%；Lv6+20%；Lv7+25%。", "Player 技能，来源为基地能力", "不暴击", "sync_aura_fx_ini"],
      ["B_L3_MAJESTY", "Lv3 可选", "母巢威仪", "基地血量百分比越高，场上其他友军攻击加成越高。", "Lv3+3%；Lv4+3.5%；Lv5+4%；Lv6+4.5%；Lv7+5%。", "友军小兵", "不暴击", "majesty_aura_fx_ini"],
      ["B_L4_MANA", "Lv4 可选", "灵触秘法", "玩家在交付区交付生物质时，玩家技能 Mana 按比例快速回升。", "Lv4每100生物质+2%蓝；Lv5+3%；Lv6+4%；Lv7+5%。", "Player Mana，来源为交付区", "不暴击", "delivery_mana_fx_ini"],
      ["B_L4_LASER", "Lv4 可选", "虚空触炮", "基地母巢周期性向敌方基地射出固定伤害激光，并伤害路径敌人。", "Lv4 15秒/100伤/3秒；Lv5 14秒/120；Lv6 13秒/150；Lv7 12秒/200。", "基地固定伤害", "不暴击", "void_laser_fx_ini；base_attack_anim"],
      ["B_L4_REVIVE", "Lv4 可选", "不灭分身", "Player 死亡时，基地扣除 90% 残余血量，并按剩余血量比例复活 Player。", "CD：Lv4 120秒；Lv5 100秒；Lv6 80秒；Lv7 60秒。", "Player 复活，来源为基地", "不暴击", "revive_fx_ini；base_hurt_anim"],
      ["B_L5_LUST", "Lv5 可选", "淫能迸发", "每魅惑一个敌人时，战后淫能基础结算点额外增加。", "Lv5+50；Lv6+75；Lv7+100。", "战后结算", "不暴击", "charm_lust_fx_ini"],
      ["B_L5_EXECUTE", "Lv5 可选", "触手绝杀", "碰撞伤害基地的地方杂鱼小兵，每次被母巢击退时有概率被立刻斩杀。", "Lv5 5%；Lv6 7%；Lv7 10%。", "基地接触反击", "不暴击", "execute_fx_ini；base_counter_anim"],
      ["B_L5_SENSITIVE", "Lv5 可选", "致敏菌毯", "菌毯上的敌人移动速度降低。", "Lv5-10%；Lv6-20%；Lv7-35%。", "敌人减速", "不暴击", "sensitive_creep_fx_ini"],
      ["B_L6_BREAK", "Lv6 可选", "破局之触", "敌方建筑残留血量越低，强袭触战兵生产速度越快。", "敌建筑每降低约10%血量，强袭触战兵生产 CD 约-5%。", "强袭触战兵队列", "不暴击", "breakthrough_fx_ini"],
      ["B_L6_AFTERBIRTH", "Lv6 可选", "产后欢愉", "每次生产触手造物时，对敌方基地造成固定伤害。", "Lv6=10；Lv7=15。", "基地规则伤害", "不暴击", "afterbirth_hit_fx_ini"],
      ["B_L6_EXTRACT", "Lv6 可选", "淫能萃取", "当局获得的生物质按比例转化为战后淫能基数。", "Lv6=20%；Lv7=25%。", "战后结算", "不暴击", "extract_fx_ini"],
      ["B_L7_MAGGOT", "Lv7 可选", "尸山蛆蝇触", "选择后出现一只究极近战兵；其能力随杀敌数成长，但对建筑输出平庸。", "以基地等级 sheet 为准。", "究极兵", "小兵可暴击，基地不暴击", "ultimate_maggot_entity_id；hurt/death/idle/attack_anim"],
      ["B_L7_SHADOW", "Lv7 可选", "影之从者触", "工蜂姿态解放，变成失色玩家从者；不再无敌，不再回收生物质，优先攻击敌方基地。", "以基地等级 sheet 为准。", "究极兵/从者", "小兵可暴击，基地不暴击", "shadow_follower_entity_id；shader_key；hurt/death/idle/attack_anim"],
      ["B_L7_ROCKET", "Lv7 可选", "裂空噬灭触", "母巢不断发射特别火箭弹协助开路；无血量，对建筑伤害低。", "以基地等级 sheet 为准。", "基地弹幕", "不暴击", "ultimate_rocket_attack_id；projectile_texture；rocket_fx_ini"],
    ],
  },
  {
    name: "逐级选项",
    rows: [
      ["升级事件", "基地基础获得", "基地三选一", "解锁触手兵", "小兵三选一"],
      ["Lv1 -> Lv2", "周期性，每循环生产 5 生物质；解锁 2级兵生产队列；菌毯应激升级。", "多胞触手；触质转化；费洛蒙域", "不稳定造物", "同归于触；仇恨拉取；尸骨有存"],
      ["Lv2 -> Lv3", "周期性，每循环生产 15 生物质；解锁 3级兵生产队列；菌毯应激升级。", "剖腹生产；触感同调；母巢威仪", "汲取萃汁触", "精壮触须；掠淫夺色；责罚榨汁"],
      ["Lv3 -> Lv4", "周期性，每循环生产 40 生物质；解锁 4级兵生产队列；菌毯应激升级。", "灵触秘法；虚空触炮；不灭分身", "淫能施释触", "触能高潮；触及神经；触破万物"],
      ["Lv4 -> Lv5", "周期性，每循环生产 80 生物质；解锁 5级兵生产队列；菌毯应激升级。", "淫能迸发；触手绝杀；致敏菌毯", "魅惑同化触", "共同进化；反叛战士；杰出造物"],
      ["Lv5 -> Lv6", "周期性，每循环生产 200 生物质；解锁 6级兵生产队列；菌毯应激升级。", "破局之触；产后欢愉；淫能萃取", "强袭触战兵", "横冲直撞；越战越勇；易燃易爆"],
      ["Lv6 -> Lv7", "周期性，每循环生产 400 生物质；选择后出现 1 只究极兵；菌毯应激升级。", "尸山蛆蝇触；影之从者触；裂空噬灭触", "究极兵三选一", "究极兵不可再细分额外路线"],
    ],
  },
  {
    name: "升级UI文案",
    rows: [
      ["升级事件", "UI区块", "玩家可见文案草案", "配置来源"],
      ["通用", "标题", "基地进化 Lv{旧等级} -> Lv{新等级}", "level_up_title"],
      ["通用", "基地已获得", "基地已获得：{基础获得文本}", "基地等级 sheet：基础获得"],
      ["通用", "基地可选当级额外能力", "请选择 1 个基地能力。每个选项说明必须写清：谁，在什么条件下，对谁，造成什么效果，数值是多少。", "基地等级 sheet：能力A/B/C"],
      ["通用", "触手兵已解锁", "触手兵：{当级解锁兵种} 已解锁。", "基地等级 sheet：当级解锁兵种"],
      ["通用", "可选小兵能力方向", "请选择 1 个 {当级解锁兵种} 方向。", "小兵路线 sheet：路线A/B/C"],
      ["Lv1 -> Lv2", "基地已获得", "基地已获得：周期性，每循环生产 5 生物质；不稳定造物生产队列已启动；菌毯应激升级。", "基地等级 Lv2"],
      ["Lv1 -> Lv2", "基地能力", "多胞触手：不稳定造物每次生产数量增加。 / 触质转化：基地周期性生物质产出增加。 / 费洛蒙域：基地警戒区内友军移速和生命恢复提高。", "基地等级 Lv2"],
      ["Lv1 -> Lv2", "小兵能力", "同归于触：自爆范围增加。 / 仇恨拉取：自身更容易吸引敌方杂鱼。 / 尸骨有存：自爆时基地直接获得生物质。", "小兵路线 Lv2"],
      ["Lv2 -> Lv3", "基地已获得", "基地已获得：周期性，每循环生产 15 生物质；汲取萃汁触生产队列已启动；菌毯应激升级。", "基地等级 Lv3"],
      ["Lv2 -> Lv3", "基地能力", "剖腹生产：汲取萃汁触生产更快、需求更低、低供能惩罚降低。 / 触感同调：基地母巢加强玩家攻击技能威力。 / 母巢威仪：基地血量百分比越高，友军攻击加成越高。", "基地等级 Lv3"],
    ],
  },
  {
    name: "美术配置接口",
    rows: [
      ["接口字段", "用途", "示例", "为空时行为"],
      ["entity_id", "实体配置 ID，优先调用 BattleAssets/{id}.json。", "004", "为空则该单位/召唤不生成。"],
      ["entity_json", "实体配置路径。", "res://BattleAssets/004.json", "为空则按 entity_id 组合默认路径。"],
      ["visual.gif", "实体 json 内的主视觉。", "res://BattleAssets/004.gif", "为空则用程序占位或不显示，不建议常规兵为空。"],
      ["faction_override", "关卡或能力可覆盖阵营。", "tentacle / enemy / player", "为空则使用 json 原始 faction。"],
      ["stats_override", "关卡或能力可覆盖基础数值。", "max_hp=120|attack=14|move_speed=90", "为空则使用 json 原始 stats。"],
      ["ai_override", "关卡或能力可覆盖 AI。", "mode=chase_nearest|target_factions=enemy", "为空则使用 json 原始 ai。"],
      ["idle_anim", "待机动画。", "res://BattleAssets/004.gif", "为空则使用默认 visual gif/png。"],
      ["move_anim", "移动动画。", "res://BattleAssets/004.gif", "为空则复用待机或默认图。"],
      ["attack_anim", "攻击/释放动画。", "res://BattleAssets/Base/base_attack.gif", "为空则直接结算效果，不播动画。"],
      ["hurt_anim", "受伤动画。", "res://BattleAssets/Base/base_hurt.gif", "为空则跳过受伤演出。"],
      ["death_anim", "死亡动画。", "res://BattleAssets/Minions/ravager_death.gif", "为空则直接消失或进入待机，按实体规则处理。"],
      ["spawn_anim", "出生/生产动画。", "res://BattleAssets/Fx/minion_spawn.gif", "为空则直接生成实体。"],
      ["cast_fx_ini", "能力释放特效配置。", "res://BattleAssets/Fx/VoidLaser.ini", "为空则只执行逻辑。"],
      ["hit_fx_ini", "命中特效配置。", "res://BattleAssets/Fx/HitSmall.ini", "为空则无命中特效。"],
      ["base_visual_mode", "决定基地能力表现方式。", "replace_base / attach_to_base / spawn_at_stage_point", "为空则不改变基地外观。"],
      ["base_replace_texture", "替换基地 gif/png。", "res://BattleAssets/Base/Lv4_VoidCannon.gif", "为空则不替换基地图。"],
      ["base_attach_point", "基地挂件位置。", "root/tentacle_left 或 Vector2(32,-48)", "为空则挂到基地中心或跳过挂件。"],
      ["stage_art_point", "关卡中独立建筑坐标或 Marker 名。", "Marker2DBaseAddonA / 1200,740", "为空则不生成独立建筑。"],
      ["addon_texture", "独立建筑或挂件图片。", "res://BattleAssets/BaseAddons/EntanglerNursery.gif", "为空则只生效逻辑。"],
      ["minion_variant_entity_id", "小兵路线带来的实体差异。", "004_HATE 或 004", "为空则使用基础小兵 entity_id。"],
      ["minion_variant_texture", "小兵路线仅换图时使用。", "res://BattleAssets/004.gif", "为空则使用基础小兵图。"],
      ["projectile_texture", "弹幕/火箭/激光贴图。", "res://BattleAssets/Projectiles/void_laser.png", "为空则使用程序绘制或默认弹幕。"],
      ["shader_key", "特殊 shader 表现。", "shadow_player_desaturate", "为空则不套 shader。"],
      ["stage_override_key", "关卡覆盖字段。", "Battle_00.void_cannon_point", "为空则使用通用配置。"],
    ],
  },
  {
    name: "占位素材清单",
    rows: [
      ["素材/配置类别", "建议配置方式", "用途", "现在可否为空"],
      ["工蜂 entity", "新增或复用 res://BattleAssets/{id}.json，visual.gif 指向 BattleAssets 现有 gif。", "工蜂待机/移动/拾取占位。", "不建议为空，需要能看见工蜂。"],
      ["不稳定造物 entity", "新增或复用一个 BattleAssets json；可临时从 004.json 复制后改 id/type/stats/ai。", "Lv2 自爆兵。", "不建议为空。"],
      ["汲取萃汁触 entity", "新增或复用一个 BattleAssets json。", "Lv3 近战汲取兵。", "不建议为空。"],
      ["淫能施释触 entity", "新增或复用一个 BattleAssets json，并配置 ranged/attack_id。", "Lv4 远程弹幕兵。", "不建议为空。"],
      ["魅惑同化触 entity", "新增或复用一个 BattleAssets json。", "Lv5 同化兵。", "不建议为空，但同化动画可先空。"],
      ["触手服美少女 entity", "新增一个 BattleAssets json，faction=tentacle，type=minion，visual.gif 可先复用现有美少女 gif。", "魅惑同化完成后生成的我方单位。", "建议准备。"],
      ["强袭触战兵 entity", "新增或复用一个 BattleAssets json。", "Lv6 厚血近战兵。", "不建议为空。"],
      ["Lv7 究极兵 entity/attack", "尸山蛆蝇触/影之从者触用 entity_id；裂空噬灭触用 attack_id/projectile 配置。", "Lv7 三选一。", "可先只配被测试的一种。"],
      ["基地等级图", "继续使用 res://BattleAssets/001.json 的 visual.gif，或为各级配置 base_replace_texture。", "基地升级后外观变化。", "可为空，先使用现有基地图。"],
      ["基地挂件图", "可以使用 BattleAssets 下 gif/png，字段 addon_texture 指向资源。", "能力建筑/挂件。", "可为空，逻辑先跑。"],
      ["菌毯 AOE 特效", "creep_aoe_fx_ini 或程序绘制默认圈。", "基地周期 AOE。", "可为空，用程序圈或跳过演出。"],
      ["虚空触炮特效", "void_laser_fx_ini 或复用 BattleLineFx 程序线。", "Lv4 激光。", "建议实现前准备占位线条/光束。"],
      ["同化动画", "assimilation_anim 或 assimilation_fx_ini。", "敌人位置播放同化中动画，完成后原地生成触手服美少女。", "可先为空，直接延迟生成。"],
      ["受伤/死亡动画", "hurt_anim / death_anim 指向 BattleAssets gif 或 fx ini。", "受伤、死亡演出。", "可为空，脚本检测空值跳过。"],
    ],
  },
];

function columnLetter(index) {
  let n = index + 1;
  let s = "";
  while (n > 0) {
    const mod = (n - 1) % 26;
    s = String.fromCharCode(65 + mod) + s;
    n = Math.floor((n - mod) / 26);
  }
  return s;
}

function styleSheet(sheet, rows) {
  const rowCount = rows.length;
  const colCount = rows[0].length;
  const lastCol = columnLetter(colCount - 1);
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);
  sheet.getRange("A1:K80").clear({ applyTo: "all" });
  const used = sheet.getRange(`A1:${lastCol}${rowCount}`);
  used.values = rows;
  used.format = {
    wrapText: true,
    verticalAlignment: "Top",
    borders: { preset: "all", style: "thin", color: "#D8DEE9" },
  };
  sheet.getRange(`A1:${lastCol}1`).format = {
    fill: "#3B4252",
    font: { bold: true, color: "#FFFFFF" },
    horizontalAlignment: "Center",
    verticalAlignment: "Center",
    wrapText: true,
  };
  sheet.getRange(`A1:${lastCol}${rowCount}`).format.rowHeightPx = 62;
  sheet.getRange("A1:A1").format.rowHeightPx = 32;
  const widths = [140, 280, 280, 330, 260, 220, 180, 260];
  for (let i = 0; i < colCount; i++) {
    sheet.getRange(`${columnLetter(i)}:${columnLetter(i)}`).format.columnWidthPx = widths[i] ?? 220;
  }
}

for (const spec of supportSheets) {
  let sheet;
  try {
    sheet = workbook.worksheets.getItem(spec.name);
  } catch (_err) {
    sheet = workbook.worksheets.add(spec.name);
  }
  styleSheet(sheet, spec.rows);
}

for (const spec of supportSheets) {
  await workbook.render({ sheetName: spec.name, autoCrop: "all", scale: 1, format: "png" });
}

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 50 },
});
console.log(errors.ndjson);

const baseLevels = await workbook.inspect({
  kind: "table",
  range: "基地等级!A1:H8",
  include: "values",
  tableMaxRows: 8,
  tableMaxCols: 8,
  tableMaxCellChars: 160,
  maxChars: 8000,
});
console.log(baseLevels.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(path);
console.log(path);
