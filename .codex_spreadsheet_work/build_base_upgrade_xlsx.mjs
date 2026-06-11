import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputPath = "D:/project-l/output/BaseInRunUpgradeDraft_CN.xlsx";

const sheets = [
  {
    name: "总览规则",
    rows: [
      ["主题", "草案规则", "备注"],
      ["基地等级上限", "默认 Cap 为 Lv7；每个关卡可以单独降低 Cap。", "关卡配置决定本局能开放到几级。"],
      ["Lv1 基地", "无主动/被动战斗能力；开局拥有 1 个无敌工兵。", "工兵只负责拾取、搬运、交付，不攻击。"],
      ["升级暂停", "基地进化到下一级时暂停游戏，弹出基地升级选择。", "形式类似主角升级暂停。"],
      ["选择结构", "每次基地升级选择 1 个基地/系统能力 + 1 个小兵路线。", "Lv2 起生效。"],
      ["与 Player 切分", "基地升级不直接改 Player。", "Player 变化来自主角升级、武器、局外养成、下一局临时道具、俘虏临时转化。"],
      ["生物质含义", "生物质更像供能/电量，不是一次性消耗矿产。", "影响生产和进化速度。"],
      ["低生物质生产", "生物质不足时，小兵队列仍推进，但速度降到 50%。", "避免生产完全卡死。"],
      ["低生物质进化", "生物质不足时，基地进化仍推进，但速度降到 20%。", "保证基地慢慢长，但鼓励供能。"],
      ["独立生产队列", "每个兵种/等级有独立生产 Bar。", "Lv2 兵一个 Bar，Lv3 兵另一个 Bar。"],
      ["美术接口", "基地能力、小兵路线、建筑挂件、场地设施都预留资源与特效配置字段。", "可改基地本体图，也可在关卡指定坐标加载独立 png/gif。"],
    ],
  },
  {
    name: "工兵规则",
    rows: [
      ["规则项", "具体规则", "实现/配置备注"],
      ["基础定位", "工兵类似玩家的自动搬运单位，可以磁吸生物质，并把生物质带到交付区供给基地。", "无攻击，不参与伤害结算。"],
      ["生存规则", "工兵无敌，不会死亡。", "不显示血条；不吃弹幕伤害。"],
      ["行动半径", "工兵行动半径比基地警戒区略大。", "建议字段：worker_radius = base_alert_radius + extra_radius。"],
      ["磁吸拾取", "工兵在行动半径内不断寻找可拾取生物质；进入磁吸范围后自动吸附。", "建议字段：pickup_seek_radius、pickup_magnet_radius、pickup_speed。"],
      ["交付规则", "工兵携带生物质后前往基地交付区，把生物质交给基地。", "交付区沿用基地 delivery zone，或单独指定 worker_delivery_zone。"],
      ["接触暂停", "敌人接触工兵时，工兵暂停行动；接触它的敌人死亡后，工兵恢复行动。", "只响应敌方实体接触，不响应敌方弹幕。"],
      ["穿透规则", "敌我小兵、Player 都可以穿过工兵；工兵不阻挡路径。", "工兵不作为阻挡碰撞体。"],
      ["弹幕规则", "敌人弹幕不影响工兵行动。", "不触发暂停，不造成伤害，不推开。"],
      ["寻路要求", "工兵需要寻路，不能被基地或空气墙卡住。", "移动目标应经过可行走检测；被卡住时重算路径。"],
      ["默认 AI 循环", "找最近可拾取生物质 -> 磁吸拾取 -> 携带到交付区 -> 交付 -> 继续寻找。", "若无可拾取生物质，则在基地附近巡航等待。"],
    ],
  },
  {
    name: "供能规则",
    rows: [
      ["供能状态", "建议判定", "基地进化速度", "小兵队列速度", "设计说明"],
      ["饥饿", "生物质低于当前供能需求", "20%", "50%", "基地仍会成长，兵仍会生产，但明显变慢。"],
      ["供能正常", "生物质满足当前供能需求", "100%", "100%", "标准节奏。"],
      ["过量供能", "生物质高于较高阈值", "120%", "115%", "可选后续机制，用于奖励高效率交付，但不强迫频繁回家。"],
    ],
  },
  {
    name: "基地等级",
    rows: [
      ["基地等级", "升级后基础获得", "当级基地可选能力A", "当级基地可选能力B", "当级基地可选能力C", "当级解锁兵种", "当级小兵可选方向"],
      ["Lv1", "基地无能力；拥有 1 个无敌工兵。", "无", "无", "无", "工兵", "无"],
      ["Lv2", "周期性，每循环生产 5 生物质；解锁 2级兵生产队列。", "境界震荡：基地周期性释放弱伤害 AOE，清理贴近基地的弱敌。", "缠绕育床：缠绕者生产周期缩短，低供能时生产速度惩罚降低。", "柔性警戒：基地警戒区内，Player 和我方小兵移速、生命恢复速度小幅提高。", "缠绕者", "诱敌缠绕；肉鞭强化；供奉鞭挞"],
      ["Lv3", "基础生产能力提升为每循环 15 生物质；解锁 3级兵生产队列。", "双生育床：3级兵每次生产数量从 1 变为 2。", "境界加速：境界区内 Player 和我方小兵攻击速度、移动速度、生命恢复速度提高。", "汲取回路：汲取者造成伤害时，按比例直接给基地补充生物质。", "汲取者", "双生汲取；贴附缠绵；热咬"],
      ["Lv4", "基地境界区扩大；解锁 4级兵生产队列。", "黏滞境界：境界 AOE 命中敌人后附带短时间减速。", "饥饿续行：低供能时所有已解锁小兵队列速度从 50% 提高到 65%。", "缠汲协同：被缠绕者牵制的敌人，受到汲取者伤害提高。", "压制者", "软缚压制；集火标记；护巢牵引"],
      ["Lv5", "基地受击后获得短暂反应窗口；解锁 5级兵生产队列。", "反射触握：基地连续受击后释放击退与弱伤害脉冲。", "供奉反射：基地附近敌人死亡时，基地获得少量生物质。", "撕裂育成：撕裂者生产周期缩短，并提高对精英/建筑的伤害。", "撕裂者", "破巢；乱舞；掠食"],
      ["Lv6", "基地可以指定一个小兵家族作为本局眷族；解锁 6级兵生产队列。", "选定眷族：选择一个小兵家族，该家族生产速度提高。", "不倦工兵：工兵移动速度、磁吸范围、交付效率提高。", "母巢庇护：境界区内我方小兵获得防御和生命恢复。", "母巢幼体", "育动节律；丝膜庇护；狂热气味"],
      ["Lv7", "普通 Cap 的最终形态；军团节奏发生质变。", "资源母巢：基础生产进一步提高，供能正常时所有队列小幅加速。", "防卫境界：境界 AOE 更宽、更慢、更安全地触发。", "军团引擎/欲痕供奉：爆兵速度提高，或被束缚/控制敌人额外转化生物质。", "最终教义", "吞食眷族；束缚眷族；泛滥眷族"],
    ],
  },
  {
    name: "基地能力池",
    rows: [
      ["能力ID", "中文名", "最早等级", "效果草案", "设计目的", "美术资源接口", "挂点/坐标接口", "特效/动画配置接口"],
      ["B_AOE_01", "境界震荡", "Lv2", "基地周围周期释放弱伤害 AOE。伤害低，主要清理贴近基地的弱敌。", "让基地能自己清理边缘，不取代玩家和小兵。", "base_or_addon_texture", "base_attach_point 或 stage_art_point", "ability_fx_ini"],
      ["B_QUEUE_02", "缠绕育床", "Lv2", "缠绕者生产周期缩短，低供能时生产速度惩罚降低。", "让第一种战斗小兵更快形成存在感。", "addon_texture", "stage_art_point 可覆盖", "production_fx_ini"],
      ["B_AURA_01", "柔性警戒", "Lv2", "基地警戒区内，Player 和我方小兵移动速度、生命恢复速度小幅提高。", "让基地周边变成玩家愿意回防和交战的安全区。", "aura_texture", "base_center", "aura_fx_ini"],
      ["B_QUEUE_03", "双生育床", "Lv3", "3级兵每次生产数量从 1 变为 2。", "让 Lv3 解锁后生产节奏明显改变。", "addon_texture", "stage_art_point 可覆盖", "production_fx_ini"],
      ["B_AURA_02", "境界加速", "Lv3", "境界区内 Player 和我方小兵攻击速度、移动速度、生命恢复速度提高。", "替代扩大交付范围，直接提升基地周边战斗体验。", "aura_texture", "base_center", "aura_fx_ini"],
      ["B_DRAIN_01", "汲取回路", "Lv3", "汲取者造成伤害时，按比例直接给基地补充生物质。", "让 Lv3 兵和基地供能循环绑定。", "base_or_addon_texture", "base_attach_point 或 stage_art_point", "drain_link_fx_ini"],
      ["B_AOE_02", "黏滞境界", "Lv4", "境界 AOE 命中敌人后附带短时间减速。", "帮助基地应对成群敌人，避免只堆伤害。", "aura_texture", "base_center", "slow_fx_ini"],
      ["B_POWER_01", "饥饿续行", "Lv4", "低供能时小兵队列速度从 50% 提高到 65%。", "让缺生物质时不那么惩罚。", "addon_texture", "base_attach_point 或 stage_art_point", "power_state_fx_ini"],
      ["B_SYNERGY_01", "缠汲协同", "Lv4", "被缠绕者牵制的敌人，受到汲取者伤害提高。", "让前两级兵种形成组合，而不是各玩各的。", "addon_texture", "stage_art_point 可覆盖", "synergy_mark_fx_ini"],
      ["B_GUARD_01", "反射触握", "Lv5", "基地连续受击后释放短距离击退和弱伤害脉冲。", "解决基地被贴脸围住的问题。", "base_or_addon_texture", "base_center", "counter_pulse_fx_ini"],
      ["B_KILL_01", "供奉反射", "Lv5", "基地附近敌人死亡时，基地获得少量生物质。", "奖励围绕基地作战，但不强迫原地蹲守。", "addon_texture", "base_attach_point 或 stage_art_point", "offering_fx_ini"],
      ["B_QUEUE_05", "撕裂育成", "Lv5", "撕裂者生产周期缩短，并提高对精英/建筑的伤害。", "让进攻型重兵更快出场。", "addon_texture", "stage_art_point 可覆盖", "production_fx_ini"],
      ["B_FOCUS_01", "选定眷族", "Lv6", "选择一个小兵家族，该家族生产速度提高。", "支持玩家形成军团身份。", "addon_texture", "base_attach_point 或 stage_art_point", "chosen_family_fx_ini"],
      ["B_WORKER_01", "不倦工兵", "Lv6", "工兵移动速度、磁吸范围、交付效率提高；若关卡允许，可追加 1 个工兵。", "提高自动化，进一步降低回家压力。", "worker_variant_texture", "worker_spawn_point", "worker_pickup_fx_ini"],
      ["B_AURA_06", "母巢庇护", "Lv6", "境界区内我方小兵获得防御和生命恢复。", "让基地后期有明显的守巢感。", "aura_texture", "base_center", "shelter_fx_ini"],
      ["B_FINAL_RES", "资源母巢", "Lv7", "生物质产量大幅提高；供能正常时所有队列小幅加速。", "经济终局形态。", "base_replace_texture", "base_root", "resource_womb_fx_ini"],
      ["B_FINAL_DEF", "防卫境界", "Lv7", "境界 AOE 更宽，减速更强，并在基地受击时更稳定触发。", "防御终局形态。", "base_replace_texture", "base_root", "defense_boundary_fx_ini"],
      ["B_FINAL_ARMY", "军团引擎", "Lv7", "全部已解锁小兵队列加速；被选定家族额外加速。", "爆兵终局形态。", "base_replace_texture", "base_root", "brood_engine_fx_ini"],
      ["B_FINAL_LUST", "欲痕供奉", "Lv7", "被标记、被控制、被束缚的敌人会被小兵转化出额外生物质。", "主题更重的续航终局形态。", "base_replace_texture", "base_root", "lust_mark_fx_ini"],
    ],
  },
  {
    name: "小兵路线",
    rows: [
      ["阶层", "小兵", "基础定位", "路线A", "路线B", "路线C", "造型差异接口", "特效/动画配置接口"],
      ["工兵", "工兵", "无敌拾取/搬运单位；不攻击。", "搬运效率：拾取和交付更快。", "拾取范围：自动拾取半径扩大。", "追加工兵：后续若关卡 Cap 允许，可增加工兵数量。", "worker_variant_texture", "worker_pickup_fx_ini"],
      ["Lv2", "缠绕者", "短距离近战控制单位。", "诱敌缠绕：只要它不死，附近小范围敌人优先攻击它。", "肉鞭强化：血、攻、防、移速提高。", "供奉鞭挞：造成伤害的一定比例转为基地生物质。", "entangler_variant_texture", "entangler_fx_ini"],
      ["Lv3", "汲取者", "近中距离单位，偏持续纠缠与资源回流。", "双生汲取：每次队列完成生产 2 个汲取者。", "贴附缠绵：攻击目标被减速，并被纠缠更久。", "热咬：对已被控制/减速敌人伤害提高。", "drainer_variant_texture", "drainer_fx_ini"],
      ["Lv4", "压制者", "控制/辅助单位，让敌群更容易处理。", "软缚压制：周期削弱附近敌人的移速和攻击。", "集火标记：接触过的敌人受到触手小兵伤害提高。", "护巢牵引：轻微把敌人从基地核心附近拉向自己。", "suppressor_variant_texture", "suppressor_fx_ini"],
      ["Lv5", "撕裂者", "进攻型重兵，负责撕开敌方阵线。", "破巢：对敌方建筑/精英伤害提高。", "乱舞：对目标周围造成短距离顺劈。", "掠食：撕裂者击杀会额外掉落生物质或直接喂给基地。", "ravager_variant_texture", "ravager_fx_ini"],
      ["Lv6", "母巢幼体", "昂贵支援单位，强化其他小兵。", "育动节律：场上存在时，附近或对应队列生产速度提高。", "丝膜庇护：附近小兵获得防御/回复。", "狂热气味：附近小兵攻击被标记敌人时攻速提高。", "matron_variant_texture", "matron_fx_ini"],
      ["Lv7", "最终教义", "最终军团身份，不一定是新单位。", "吞食眷族：所有小兵的生物质回流效果提高。", "束缚眷族：控制、减速、嘲讽效果提高。", "泛滥眷族：生产速度和低供能生产速度提高。", "doctrine_visual_key", "doctrine_fx_ini"],
    ],
  },
  {
    name: "逐级选项",
    rows: [
      ["升级事件", "基地选项示例", "小兵选项示例"],
      ["Lv1 -> Lv2", "境界震荡；缠绕育床；柔性警戒", "缠绕者：诱敌缠绕；肉鞭强化；供奉鞭挞"],
      ["Lv2 -> Lv3", "双生育床；境界加速；汲取回路", "汲取者：双生汲取；贴附缠绵；热咬"],
      ["Lv3 -> Lv4", "黏滞境界；饥饿续行；缠汲协同", "压制者：软缚压制；集火标记；护巢牵引"],
      ["Lv4 -> Lv5", "反射触握；供奉反射；撕裂育成", "撕裂者：破巢；乱舞；掠食"],
      ["Lv5 -> Lv6", "选定眷族；不倦工兵；母巢庇护", "母巢幼体：育动节律；丝膜庇护；狂热气味"],
      ["Lv6 -> Lv7", "资源母巢；防卫境界；军团引擎；欲痕供奉", "最终教义：吞食眷族；束缚眷族；泛滥眷族"],
    ],
  },
  {
    name: "升级UI文案",
    rows: [
      ["升级事件", "UI区块", "玩家可见文案草案", "配置来源"],
      ["Lv1 -> Lv2", "基地已获得", "基地已获得：周期性，每循环生产 5 生物质。", "BaseLevelTable.base_grant_text"],
      ["Lv1 -> Lv2", "基地可选当级额外能力", "请选择 1 个基地能力：境界震荡 / 缠绕育床 / 柔性警戒。", "BaseAbilityPool filtered by level=2"],
      ["Lv1 -> Lv2", "触手兵已解锁", "触手兵：缠绕者已解锁。", "MinionUnlockTable.level=2"],
      ["Lv1 -> Lv2", "可选小兵能力方向", "请选择 1 个缠绕者方向：诱敌缠绕 / 肉鞭强化 / 供奉鞭挞。", "MinionRouteTable.minion=entangler"],
      ["Lv2 -> Lv3", "基地已获得", "基地已获得：基础生产能力提升为每循环 15 生物质；3级兵生产队列已启动。", "BaseLevelTable.base_grant_text"],
      ["Lv2 -> Lv3", "基地可选当级额外能力", "请选择 1 个基地能力：双生育床 / 境界加速 / 汲取回路。", "BaseAbilityPool filtered by level=3"],
      ["Lv2 -> Lv3", "触手兵已解锁", "触手兵：汲取者已解锁。", "MinionUnlockTable.level=3"],
      ["Lv2 -> Lv3", "可选小兵能力方向", "请选择 1 个汲取者方向：双生汲取 / 贴附缠绵 / 热咬。", "MinionRouteTable.minion=drainer"],
    ],
  },
  {
    name: "美术配置接口",
    rows: [
      ["接口字段", "用途", "示例", "备注"],
      ["base_visual_mode", "决定基地能力表现方式。", "replace_base / attach_to_base / spawn_at_stage_point", "替换基地本体；挂在基地上；在关卡坐标生成独立建筑。"],
      ["base_replace_texture", "替换基地 gif/png。", "res://BattleAssets/Base/Lv2_AOE.gif", "当 visual_mode = replace_base 时使用。"],
      ["base_attach_point", "基地挂件位置。", "root/tentacle_left 或 Vector2(32,-48)", "当建筑长在基地上时使用。"],
      ["stage_art_point", "关卡中独立建筑坐标或 Marker 名。", "Marker2DBaseAddonA / 1200,740", "允许建筑不站在基地上。"],
      ["addon_texture", "独立建筑或挂件图片。", "res://BattleAssets/BaseAddons/EntanglerNursery.gif", "png/gif 均可。"],
      ["ability_fx_ini", "能力额外动画/特效配置。", "res://BattleAssets/Fx/BoundaryTremor.ini", "AOE、光圈、生产动画等放这里。"],
      ["minion_variant_texture", "小兵路线带来的造型差异。", "res://BattleAssets/Minions/Entangler_Hate.gif", "不同升级方向可换图。"],
      ["minion_fx_ini", "小兵能力特效配置。", "res://BattleAssets/Fx/Entangler_HateAura.ini", "仇恨圈、汲取线、标记等。"],
      ["stage_override_key", "关卡覆盖字段。", "Battle_00.entangler_nursery_point", "不同关卡可以指定不同坐标/美术。"],
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
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);

  const rowCount = rows.length;
  const colCount = rows[0].length;
  const lastCol = columnLetter(colCount - 1);
  const used = sheet.getRange(`A1:${lastCol}${rowCount}`);
  used.values = rows;
  used.format = {
    wrapText: true,
    verticalAlignment: "Top",
    borders: { preset: "all", style: "thin", color: "#D8DEE9" },
  };

  const header = sheet.getRange(`A1:${lastCol}1`);
  header.format = {
    fill: "#3B4252",
    font: { bold: true, color: "#FFFFFF" },
    horizontalAlignment: "Center",
    verticalAlignment: "Center",
    wrapText: true,
  };

  sheet.getRange(`A1:${lastCol}${rowCount}`).format.rowHeightPx = 58;
  sheet.getRange("A1:A1").format.rowHeightPx = 32;
  sheet.tables.add(`A1:${lastCol}${rowCount}`, true, `${sheet.name.replaceAll(/[^A-Za-z0-9]/g, "") || "Table"}Table`);

  const widths = [120, 220, 250, 310, 310, 220, 230, 240];
  for (let i = 0; i < colCount; i++) {
    sheet.getRange(`${columnLetter(i)}:${columnLetter(i)}`).format.columnWidthPx = widths[i] ?? 220;
  }
}

const workbook = Workbook.create();

for (const spec of sheets) {
  const sheet = workbook.worksheets.add(spec.name);
  styleSheet(sheet, spec.rows);
}

await fs.mkdir("D:/project-l/output", { recursive: true });

for (const spec of sheets) {
  await workbook.render({ sheetName: spec.name, autoCrop: "all", scale: 1, format: "png" });
}

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 50 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

const summary = await workbook.inspect({
  kind: "table",
  range: "基地等级!A1:G8",
  include: "values",
  tableMaxRows: 8,
  tableMaxCols: 7,
});
console.log(summary.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(outputPath);
