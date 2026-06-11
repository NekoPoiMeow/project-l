extends Node

const ENTITY_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleEntity.gd")
const PROJECTILE_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleProjectile.gd")
const ATTACK_RUNNER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleAttackRunner.gd")
const BIO_DROP_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleBioDrop.gd")
const BIO_TRANSFER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleBioTransfer.gd")
const ATTACK_INSTANCE_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleAttackInstance.gd")
const FLOATING_NUMBER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleFloatingNumber.gd")
const LINE_FX_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleLineFx.gd")
const SHARED_GIF_BATCH_RENDERER_SCRIPT := preload("res://BattleAssets/ScriptShader/BattleSharedGifBatchRenderer.gd")

@export var stage_config_path := "res://scenes/Battle/Battle_00.ini"

const CHARACTERS_CSV := "res://Config/Characters.csv"
const WEAPONS_CSV := "res://Config/Weapons.csv"
const EQUIPMENTS_CSV := "res://Config/Equipments.csv"
const WEAPON_UPGRADES_CSV := "res://Config/WeaponUpgrades.csv"
const RUN_STAT_UPGRADES_CSV := "res://Config/RunStatUpgrades.csv"
const OUTGAME_UPGRADES_CSV := "res://Config/OutGameUpgrades.csv"
const OUTGAME_UPGRADE_SCENE_PATH := "res://scenes/OutGame/OutGameUpgrade.tscn"

@onready var battle_camera: Camera2D = $"../Camera2DBattle"
@onready var root: Node2D = get_parent()
@onready var entities_root: Node2D = $"../Node2DWorld/Node2DNode2DEntities"
@onready var projectiles_root: Node2D = $"../Node2DWorld/Node2DProjectiles"
@onready var effects_root: Node2D = $"../Node2DWorld/Node2DEffects"
@onready var spawn_root: Node2D = $"../Node2DSpawnPoints"
@onready var block_mask_sprite: Sprite2D = $"../Sprite2DBlockMask"
@onready var ui_layer: CanvasLayer = $"../CanvasLayerUI"
@onready var timer_label: Label = $"../CanvasLayerUI/LabelTimer"
@onready var objective_label: Label = $"../CanvasLayerUI/LabelObjective"
@onready var player_base_bar: TextureProgressBar = $"../CanvasLayerUI/TextureProgressBarPlayerBaseHP"
@onready var enemy_base_bar: TextureProgressBar = $"../CanvasLayerUI/TextureProgressBarEnemyBaseHP"

var config := ConfigFile.new()
var battle_time := 0.0
var map_size := Vector2(3200, 2133)
var entities: Array = []
var projectiles: Array = []
var waves: Array[Dictionary] = []
var drops: Array = []

var player_entity = null
var tentacle_base = null
var enemy_base = null
var attack_runner = ATTACK_RUNNER_SCRIPT.new()
var attack_instances: Array = []
var block_mask_image: Image = null
var block_alpha_limit := 0.1
var enemy_kill_count := 0
var battle_lust_score := 0.0
var player_level := 1
var player_xp := 0
var player_xp_cap := 3
var player_level_cap := 8
var xp_curve: Array[int] = [3, 6, 10, 15, 21, 28, 36]
var level_choice_active := false
var kill_label: Label = null
var level_label: Label = null
var mana_panel: PanelContainer = null
var mana_bar: ProgressBar = null
var mana_label: Label = null
var level_choice_panel: PanelContainer = null
var base_queue_panel: PanelContainer = null
var base_queue_box: VBoxContainer = null
var base_choice_active := false
var pending_base_level := 0
var pending_base_choice := {}
var assimilation_jobs: Array[Dictionary] = []
var debug_label: Label = null
var bio_texture_path := "res://scenes/Battle/Battle_00/Bio.png"
var unit_contact_timers: Dictionary = {}
# Time-slice expensive unit-vs-unit contact checks. Contacts do not need 60 Hz precision;
# checking a rotating slice every frame prevents one frame from doing all pair queries.
var unit_contact_cursor := 0
var unit_contact_budget_min := 28
var unit_contact_budget_fraction := 0.28
var test_mode := false
var test_attack_ids: Array = []
var test_spawn_entity_id := "002"
var test_spawn_count := 8
var test_spawn_radius := 120.0
var test_selected_attack_index := 0
var test_damage_mul := 1.0
var test_radius_mul := 1.0
var test_count_add := 0
var test_cooldown_mul := 1.0
var test_duration_mul := 1.0
var test_speed_mul := 1.0
var test_skill2_ids: Array[String] = ["player_laser", "camera_blast", "tentacle_execute_rect"]
var test_skill2_index := 0
var test_source_modes: Array[String] = ["player", "tentacle_base", "friendly_minion", "enemy", "enemy_base"]
var test_source_index := 0
var floating_numbers_this_frame := 0
var floating_number_cap_per_frame := 8
var entity_grid: Dictionary = {}
var entity_grid_cell_size := 260.0

# Short-lived spawn reservation points. This prevents large waves/base batches from
# being born on the same pixel and immediately forcing expensive overlap/contact
# resolution. It does not reduce count; it only spreads a spawn burst over nearby
# valid points.
var recent_spawn_positions: Array[Dictionary] = []
var recent_spawn_ttl := 1.15
var spawn_position_min_spacing := 34.0

# Shared-GIF batch rendering. Minor follower units can keep their logic entity,
# but the visible frame is drawn by one batch node instead of one Sprite2D per unit.
var shared_gif_batch_renderer: Node2D = null
var shared_gif_batch_entity_threshold := 120
var shared_gif_batch_enter_distance := 220.0
var shared_gif_batch_exit_distance := 140.0
var shared_gif_batch_enabled := true

# Old-wave pressure control. This is not a hard enemy cap. It prevents weak trash
# from every previous wave permanently accumulating off-screen or in far corners.
var old_wave_retire_enabled := true
var old_wave_retire_timer := 0.0
var old_wave_retire_interval := 0.75
var old_wave_retire_entity_threshold := 340
var old_wave_retire_min_age := 42.0
var old_wave_retire_far_distance := 1200.0
var old_wave_retire_per_tick := 18

# Standard mode tempo/balance patch. Keeps the existing systems, but makes the
# default battle play closer to a roguelite horde: weak trash dies faster,
# player weapons reach farther, skills are real burst buttons, and wave INI can
# use stat multipliers without rewriting JSON.
var standard_mode_balance_enabled := true
var standard_player_weapon_damage_mul := 1.75
var standard_player_weapon_interval_mul := 0.72
var standard_player_weapon_range_mul := 2.10
var standard_player_weapon_area_mul := 1.35
var standard_player_projectile_speed_mul := 1.55
var standard_player_skill_damage_mul := 4.00
var standard_player_skill_area_mul := 1.90
var standard_player_skill_cooldown_mul := 0.55
var standard_player_skill_mana_cost_mul := 0.55

# Swarm flow AI state. Instead of making every trash body run full target logic,
# waves/base spawns are automatically split into a few leaders plus many cheap followers.
var swarm_next_group_id := 1
var swarm_group_states: Dictionary = {}
var swarm_group_leaders: Dictionary = {}
var swarm_group_flow_cache: Dictionary = {}
var swarm_flow_cursor := 0
var swarm_flow_cache_budget := 16
var swarm_default_group_size := 10
var battle_loadout: Dictionary = {}
var battle_won := false
var battle_lost := false
var battle_result_settled := false
var battle_result_transition_timer := -1.0
var battle_result_transition_delay := 2.0
var outgame_upgrade_rows: Array[Dictionary] = []
var outgame_upgrade_effects: Dictionary = {}
var win_condition := "destroy_enemy_base"
var objective_text := "摧毁敌方基地"
var objective_area_id := ""
var objective_area_ids: Array[String] = []
var objective_duration := 0.0
var objective_target_count := 0
var objective_target_entity_id := ""
var objective_target_faction := ""
var objective_progress_count := 0
var objective_hold_time := 0.0
var objective_activated_areas: Dictionary = {}
var stage_areas: Dictionary = {}
var stage_events: Array[Dictionary] = []
var stage_area_visuals: Dictionary = {}
var max_active_entities_soft := 72
var character_catalog: Dictionary = {}
var weapon_catalog: Dictionary = {}
var equipment_catalog: Dictionary = {}
var weapon_upgrade_rows: Array[Dictionary] = []
var run_stat_upgrade_rows: Array[Dictionary] = []
var selected_character_id := "C001"
var selected_weapon_id := "W001"
var selected_equipment_id := "E001"
var selected_weapon_type := "ranged"
var selected_character_skill_mul := 1.0
var active_equipment_effects: Array = []
var equipment_event_counts: Dictionary = {}
var equipment_last_event_payloads: Dictionary = {}
var equipment_last_player_pos := Vector2.ZERO
var equipment_move_distance := 0.0
var equipment_stop_timer := 0.0
var equipment_was_moving := false
var whip_charge_layers := 0
var whip_distance_per_layer := 260.0
var whip_max_layers := 3
var shooter_timer := 0.0
var plug_forced_direction := Vector2.RIGHT
var hide_enemy_health_bars := false
var owned_weapon_ids: Array[String] = []
var weapon_levels: Dictionary = {}
var catchup_level_choices_given := 0
var catchup_level_choices_max := 1
var run_damage_add := 0.0
var run_bonus_damage_add := 0.0
var run_crit_chance_add := 0.0
var run_crit_multiplier_add := 0.0
var run_mana_recovery_mul := 1.0
var run_lust_reward_add := 0.0
var run_lust_reward_mul := 1.0
var run_mana_recovered := 0.0
var player_mana_max := 100.0
var player_mana := 100.0
var player_mana_regen := 8.0
var player_skill_ids: Array[String] = ["player_overdrive", "player_laser"]
var player_skills: Dictionary = {}
var player_skill_cooldowns: Dictionary = {}
var player_skill_min_cooldown := 7.0
var active_channel_skill_id := ""
var base_mana_return_per_bio := 0.0
var equipment_minute_timer := 0.0
var player_revives_remaining := 0
var revive_base_hp_cost_ratio := 0.35
var revive_base_min_hp_ratio := 0.45
var assimilation_lust_reward_add := 0.0
var extraction_lust_reward_add := 0.0
var assimilated_stat_mul: Dictionary = {}
var assimilated_building_mul := 1.0
var assimilated_invuln_interval := 0.0
var assimilated_invuln_duration := 0.0

const BASE_LEVEL_CHOICES := {
	2: {
		"base": [
			{"id": "multi_cell", "name": "多胞触手", "desc": "不稳定造物每次生产数量 +1。", "queue_id": "unstable", "quantity_add": 1},
			{"id": "bio_convert", "name": "触质转化", "desc": "基地每循环额外生产 10 生物质。", "bio_cycle_add": 10, "attachment": {"id": "bio_convert_gland", "offset": [-150, 92], "size": [52, 68], "color": "76ff6b", "alpha": 0.32, "z_index": -1}},
			{"id": "pheromone", "name": "费洛蒙域", "desc": "基地警戒区内友军移速和回血小幅提高。", "aura_speed_mul": 1.03, "aura_regen_add": 1.0, "attachment": {"id": "pheromone_node", "offset": [154, 92], "size": [58, 58], "color": "57d7ff", "alpha": 0.30, "z_index": -1}}
		],
		"minion": [
			{"id": "unstable_blast", "name": "同归于触", "desc": "不稳定造物自爆伤害和范围提高。", "queue_id": "unstable", "stat_mul": {"attack": 1.15}},
			{"id": "unstable_hate", "name": "仇恨拉取", "desc": "不稳定造物更容易吸引敌方杂鱼。", "queue_id": "unstable", "target_priority_order": "minion|building|player|unit"},
			{"id": "unstable_bio", "name": "尸骨有存", "desc": "不稳定造物死亡时额外掉落生物质。", "queue_id": "unstable", "reward_bio_add": 8}
		],
		"unlock": {"id": "unstable", "level": 2, "entity_id": "021", "interval": 4.2, "power_cost": 70, "quantity": 1}
	},
	3: {
		"base": [
			{"id": "drainer_birth", "name": "剖腹生产", "desc": "汲取萃汁触生产更快，低供能也更稳定。", "queue_id": "drainer", "interval_mul": 0.85},
			{"id": "mutation_gift", "name": "突变赠礼", "desc": "每个单位生产时，低概率额外生成一只？？？生物；基地等级越高概率越高。", "mutation_gift": {"chance_base": 0.04, "chance_per_level": 0.012, "entity_ids": ["031", "027", "032"]}},
			{"id": "majesty", "name": "母巢威仪", "desc": "基地越健康，友军触手攻击越高。当前 MVP 提升小兵攻击。", "all_minion_stat_mul": {"attack": 1.08}}
		],
		"minion": [
			{"id": "drainer_body", "name": "精壮触须", "desc": "汲取萃汁触血量和攻击频率提升。", "queue_id": "drainer", "stat_mul": {"max_hp": 1.2}, "interval_mul": 0.94},
			{"id": "drainer_lust", "name": "掠淫夺色", "desc": "汲取萃汁触命中时提高战后淫能基数。当前 MVP 用生物质回流表现。", "queue_id": "drainer", "bio_on_hit_add": 3},
			{"id": "drainer_punish", "name": "责罚榨汁", "desc": "汲取萃汁触对杂鱼追加固定比例伤害。当前 MVP 提升攻击。", "queue_id": "drainer", "stat_mul": {"attack": 1.18}}
		],
		"unlock": {"id": "drainer", "level": 3, "entity_id": "022", "interval": 5.6, "power_cost": 150, "quantity": 1}
	},
	4: {
		"base": [
			{"id": "mana", "name": "灵触秘法", "desc": "交付生物质时返还玩家 Mana。", "mana_per_bio": 0.08},
			{"id": "void_laser", "name": "虚空触炮", "desc": "基地周期性向敌方基地发射固定伤害射线。", "base_laser": true, "attachment": {"id": "void_laser_node", "offset": [0, -128], "size": [78, 54], "color": "b35cff", "alpha": 0.36, "z_index": 2}},
			{"id": "revive", "name": "不灭分身", "desc": "玩家死亡时若基地仍然安稳，消耗基地生命让玩家复活 1 次。", "revive_count": 1, "revive_base_hp_cost_ratio": 0.35, "revive_base_min_hp_ratio": 0.45}
		],
		"minion": [
			{"id": "caster_fast", "name": "触能高潮", "desc": "淫能施释触子弹生成频率加快。", "queue_id": "caster", "interval_mul": 0.85},
			{"id": "caster_control", "name": "触及神经", "desc": "淫能施释触子弹有概率短暂控制非建筑敌人。", "queue_id": "caster", "on_hit_status": {"status": "control", "duration": 1.2, "chance": 0.18, "speed_mul": 0.65}},
			{"id": "caster_break", "name": "触破万物", "desc": "淫能施释触命中后让非建筑敌人短时间更易受伤。", "queue_id": "caster", "on_hit_status": {"status": "vulnerable", "duration": 3.0, "chance": 0.35, "damage_taken_mul": 1.18}}
		],
		"unlock": {"id": "caster", "level": 4, "entity_id": "023", "interval": 6.5, "power_cost": 260, "quantity": 1}
	},
	5: {
		"base": [
			{"id": "lust_burst", "name": "淫能迸发", "desc": "同化敌人时提高战后淫能。", "assimilation_lust_add": 2.0},
			{"id": "execute", "name": "触手绝杀", "desc": "基地菌毯击退低血量非建筑敌人时，有概率直接斩杀。", "contact_execute_chance": 0.28, "contact_execute_hp_ratio": 0.22},
			{"id": "slow_creep", "name": "致敏菌毯", "desc": "基地菌毯会让非建筑敌人短暂减速。", "contact_status": {"status": "slow", "duration": 1.8, "slow_mul": 0.58, "chance": 1.0}, "contact_cooldown_mul": 0.9}
		],
		"minion": [
			{"id": "charm_evolve", "name": "共同进化", "desc": "同化后的触手服美少女能力提高。", "assimilated_stat_mul": {"max_hp": 1.2, "attack": 1.2}},
			{"id": "charm_rebel", "name": "反叛战士", "desc": "同化单位对敌方基地伤害提高。", "assimilated_building_mul": 1.6},
			{"id": "charm_invuln", "name": "杰出造物", "desc": "同化单位血量提高，并周期短暂无敌。", "assimilated_stat_mul": {"max_hp": 1.20}, "assimilated_invuln": {"interval": 7.0, "duration": 1.1}}
		],
		"unlock": {"id": "charm", "level": 5, "entity_id": "024", "interval": 4.5, "power_cost": 180, "quantity": 1}
	},
	6: {
		"base": [
			{"id": "breakthrough", "name": "破局之触", "desc": "敌方基地血量越低，强袭触战兵生产越快。", "queue_id": "assault", "enemy_base_missing_hp_interval_mul": 0.55},
			{"id": "afterbirth", "name": "产后欢愉", "desc": "每次生产触手造物时伤害敌方基地。", "spawn_enemy_base_damage": 10, "attachment": {"id": "afterbirth_organ", "offset": [0, 138], "size": [86, 54], "color": "ff477f", "alpha": 0.34, "z_index": 1}},
			{"id": "extract", "name": "淫能萃取", "desc": "生物质转化为战后淫能基数。", "extraction_lust_add": 18.0}
		],
		"minion": [
			{"id": "assault_charge", "name": "横冲直撞", "desc": "强袭触战兵移速和碰撞伤害提升。", "queue_id": "assault", "stat_mul": {"move_speed": 1.2, "attack": 1.2}},
			{"id": "assault_berserk", "name": "越战越勇", "desc": "强袭触战兵低血量时攻击力提高。", "queue_id": "assault", "low_hp_attack_damage_mul": 1.65, "low_hp_attack_threshold": 0.38},
			{"id": "assault_boom", "name": "易燃易爆", "desc": "强袭触战兵死亡时爆炸伤害周围非建筑敌人。", "queue_id": "assault", "death_attack": {"kind": "attack_instance", "requires_target": false, "origin": {"mode": "self_center"}, "aim": {"mode": "fixed_angle", "angle": 0}, "motion": {"mode": "static", "duration": 0.18}, "hit_shape": {"mode": "circle", "radius": 118}, "hit_rule": {"mode": "on_spawn_once", "hit_same_target_delay": 999}, "target_filter": {"relation": "enemy", "include_building": false}, "effects": [{"mode": "damage", "value": 72}], "visual": {"primary": "ff355d", "secondary": "ffd0a8", "alpha": 0.74, "pixel_count": 18}}}
		],
		"unlock": {"id": "assault", "level": 6, "entity_id": "025", "interval": 10.0, "power_cost": 620, "quantity": 1}
	},
	7: {
		"base": [
			{"id": "maggot", "name": "尸山蛆蝇触", "desc": "召唤一只随杀敌数成长的究极近战兵。", "summon_entity_id": "026"},
			{"id": "shadow", "name": "影之从者触", "desc": "工蜂解放为失色玩家从者。当前 MVP 召唤强力从者。", "summon_entity_id": "029"},
			{"id": "rocket", "name": "裂空噬灭触", "desc": "母巢发射额外弹幕。当前 MVP 让基地周期性触炮更强。", "base_laser": true, "contact_damage_mul": 1.4}
		],
		"minion": [],
		"unlock": {}
	}
}

func _ready() -> void:
	randomize()
	load_stage()
	load_battle_catalogs()
	load_battle_loadout()
	load_outgame_upgrade_effects()
	load_player_skills()
	setup_block_mask()
	setup_ui()
	setup_stage_area_visuals()
	setup_shared_gif_batch_renderer()
	spawn_initial_entities()
	load_waves()
	setup_camera()
	update_ui()

func _physics_process(delta: float) -> void:
	floating_numbers_this_frame = 0
	battle_time += delta
	process_recent_spawn_positions(delta)
	rebuild_entity_grid()
	process_swarm_flow_cache(delta)
	process_assimilations(delta)
	process_assimilated_periodic_buffs(delta)
	process_base_contact_auras(delta)
	process_base_aura_buffs(delta)
	process_unit_contacts(delta)
	process_base_delivery_and_production(delta)
	process_equipment_timers(delta)
	process_player_skills(delta)
	process_equipment_events(delta)
	process_waves(delta)
	process_old_wave_retirement(delta)
	process_stage_objectives(delta)
	process_stage_events()
	cleanup_lists()
	update_camera_position()
	update_shared_gif_batch_renderer()
	update_ui()
	process_battle_result_transition(delta)

func setup_shared_gif_batch_renderer() -> void:
	if !shared_gif_batch_enabled or entities_root == null:
		return
	if shared_gif_batch_renderer != null and is_instance_valid(shared_gif_batch_renderer):
		return
	shared_gif_batch_renderer = Node2D.new()
	shared_gif_batch_renderer.name = "SharedGifBatchRenderer"
	shared_gif_batch_renderer.set_script(SHARED_GIF_BATCH_RENDERER_SCRIPT)
	# Added before spawned entities, so it draws behind full-detail entity nodes
	# but still above the map background.
	shared_gif_batch_renderer.z_index = 0
	entities_root.add_child(shared_gif_batch_renderer)
	if shared_gif_batch_renderer.has_method("setup"):
		shared_gif_batch_renderer.call("setup", self)

func update_shared_gif_batch_renderer() -> void:
	if shared_gif_batch_renderer != null and is_instance_valid(shared_gif_batch_renderer):
		shared_gif_batch_renderer.queue_redraw()

func mark_shared_gif_batch_dirty() -> void:
	update_shared_gif_batch_renderer()

func should_batch_shared_gif_entity(entity) -> bool:
	if !shared_gif_batch_enabled:
		return false
	if entity == null or !is_instance_valid(entity):
		return false
	if entities.size() < shared_gif_batch_entity_threshold:
		return false
	if !bool(entity.get("visual_is_shared_gif_sprite")):
		return false
	if str(entity.get("ai_role")) != "follower":
		return false
	if bool(entity.get("follower_precision_active")):
		return false
	# After the previous optimization proved useful, batch more aggressively:
	# every non-precision follower can be drawn by the shared renderer. Units that
	# are hit or enter precise combat automatically restore their own Sprite2D.
	# The distance hysteresis remains as a safety fallback for very near important
	# objects if you later want to raise the thresholds again.
	var pos: Vector2 = entity.global_position
	var min_dist := INF
	if player_entity != null and is_instance_valid(player_entity):
		min_dist = min(min_dist, pos.distance_to(player_entity.global_position))
	if tentacle_base != null and is_instance_valid(tentacle_base):
		min_dist = min(min_dist, pos.distance_to(tentacle_base.global_position))
	if enemy_base != null and is_instance_valid(enemy_base):
		min_dist = min(min_dist, pos.distance_to(enemy_base.global_position))
	var already_batched: bool = bool(entity.get("batch_shared_gif_visual_active"))
	if already_batched:
		return min_dist > shared_gif_batch_exit_distance
	return min_dist > shared_gif_batch_enter_distance

func setup_camera() -> void:
	if battle_camera == null:
		return

	battle_camera.enabled = true
	battle_camera.make_current()
	update_camera_position()

func update_camera_position() -> void:
	if battle_camera == null:
		return

	if player_entity == null or !is_instance_valid(player_entity):
		return

	var half_view: Vector2 = Vector2(800.0, 450.0)
	var target_pos: Vector2 = player_entity.global_position

	target_pos.x = clamp(target_pos.x, half_view.x, map_size.x - half_view.x)
	target_pos.y = clamp(target_pos.y, half_view.y, map_size.y - half_view.y)

	battle_camera.global_position = target_pos

func load_stage() -> void:
	var err: int = config.load(stage_config_path)
	if err != OK:
		push_error("Failed to load stage ini: " + stage_config_path)
		return

	var map_size_text: String = str(config.get_value("stage", "map_size", "3200,2133"))
	map_size = parse_vector2(map_size_text, Vector2(3200, 2133))
	block_alpha_limit = float(config.get_value("stage", "block_alpha_limit", 0.1))
	max_active_entities_soft = int(config.get_value("stage", "max_active_entities_soft", max_active_entities_soft))
	bio_texture_path = str(config.get_value("stage", "bio_texture", bio_texture_path))
	load_test_config()
	load_leveling_config()
	load_stage_objectives()
	load_stage_areas_and_events()

func load_test_config() -> void:
	test_mode = bool(config.get_value("test", "enabled", false))
	test_attack_ids = parse_string_list(str(config.get_value("test", "attack_ids", "")))
	test_spawn_entity_id = str(config.get_value("test", "spawn_entity_id", "002"))
	test_spawn_count = int(config.get_value("test", "spawn_count", 8))
	test_spawn_radius = float(config.get_value("test", "spawn_radius", 120.0))

func load_leveling_config() -> void:
	player_level = int(config.get_value("leveling", "start_level", 1))
	player_xp = 0
	player_level_cap = int(config.get_value("leveling", "level_cap", 8))
	xp_curve = parse_int_list(str(config.get_value("leveling", "xp_curve", "3,6,10,15,21,28,36")))
	player_xp_cap = get_xp_cap_for_level(player_level)

func load_stage_objectives() -> void:
	win_condition = str(config.get_value("stage", "win_condition", "destroy_enemy_base"))
	objective_text = str(config.get_value("objective", "text", get_default_objective_text(win_condition)))
	objective_area_id = str(config.get_value("objective", "area", ""))
	objective_area_ids.clear()
	for area_id in parse_string_list(str(config.get_value("objective", "areas", ""))):
		objective_area_ids.append(str(area_id))
	objective_duration = float(config.get_value("objective", "duration", config.get_value("stage", "duration", 0.0)))
	objective_target_count = int(config.get_value("objective", "target_count", 0))
	objective_target_entity_id = str(config.get_value("objective", "target_entity_id", ""))
	objective_target_faction = str(config.get_value("objective", "target_faction", ""))
	objective_progress_count = 0
	objective_hold_time = 0.0
	objective_activated_areas.clear()

func get_default_objective_text(condition: String) -> String:
	if condition == "survive_time":
		return "坚持到倒计时结束"
	if condition == "reach_area":
		return "抵达指定区域"
	if condition == "escort_entity":
		return "护送目标抵达指定区域"
	if condition == "kill_count":
		return "击败指定数量敌人"
	if condition == "kill_entity_id":
		return "击败指定目标"
	if condition == "hold_area":
		return "在指定区域内坚持"
	if condition == "activate_areas":
		return "激活所有仪式区域"
	if condition == "test":
		return "测试弹幕与机制"
	return "摧毁敌方基地"

func load_stage_areas_and_events() -> void:
	stage_areas.clear()
	stage_events.clear()
	for section in config.get_sections():
		if section.begins_with("area_"):
			var area_id: String = section.substr(5)
			stage_areas[area_id] = {
				"id": area_id,
				"shape": str(config.get_value(section, "shape", "circle")),
				"center": parse_vector2(str(config.get_value(section, "center", "0,0")), Vector2.ZERO),
				"radius": float(config.get_value(section, "radius", 120.0)),
				"size": parse_vector2(str(config.get_value(section, "size", "160,160")), Vector2(160.0, 160.0))
			}
		elif section.begins_with("event_"):
			stage_events.append({
				"id": section.substr(6),
				"condition": str(config.get_value(section, "condition", "")),
				"action": str(config.get_value(section, "action", "play_avg")),
				"area": str(config.get_value(section, "area", "")),
				"time": float(config.get_value(section, "time", 0.0)),
				"target_count": int(config.get_value(section, "target_count", 0)),
				"avg_id": str(config.get_value(section, "avg_id", "")),
				"entity_id": str(config.get_value(section, "entity_id", "")),
				"scene_path": str(config.get_value(section, "scene_path", "")),
				"count": int(config.get_value(section, "count", 1)),
				"spawn": str(config.get_value(section, "spawn", "")),
				"random_radius_min": float(config.get_value(section, "random_radius_min", 0.0)),
				"random_radius": float(config.get_value(section, "random_radius", 0.0)),
				"amount": float(config.get_value(section, "amount", 0.0)),
				"reason": str(config.get_value(section, "reason", "stage_event")),
				"once": bool(config.get_value(section, "once", true)),
				"triggered": false
			})

func load_battle_catalogs() -> void:
	character_catalog = load_catalog_by_id(CHARACTERS_CSV)
	weapon_catalog = load_catalog_by_id(WEAPONS_CSV)
	equipment_catalog = load_catalog_by_id(EQUIPMENTS_CSV)
	weapon_upgrade_rows = load_catalog_rows(WEAPON_UPGRADES_CSV)
	run_stat_upgrade_rows = load_catalog_rows(RUN_STAT_UPGRADES_CSV)

func load_battle_loadout() -> void:
	var tree_root := get_tree().root
	var got_pending: bool = false
	if tree_root.has_meta("pending_battle_loadout"):
		var payload = tree_root.get_meta("pending_battle_loadout")
		if typeof(payload) == TYPE_DICTIONARY:
			battle_loadout = payload
			got_pending = true
		tree_root.remove_meta("pending_battle_loadout")
	if !got_pending and typeof(GameState) != TYPE_NIL and GameState.has_method("get_battle_loadout"):
		battle_loadout = GameState.get_battle_loadout()

	selected_character_id = str(battle_loadout.get("character_id", selected_character_id))
	selected_weapon_id = str(battle_loadout.get("weapon_id", selected_weapon_id))
	selected_equipment_id = str(battle_loadout.get("equipment_id", selected_equipment_id))
	if !character_catalog.has(selected_character_id):
		selected_character_id = "C001"
	if !weapon_catalog.has(selected_weapon_id):
		selected_weapon_id = "W001"
	if !equipment_catalog.has(selected_equipment_id):
		selected_equipment_id = "E001"
	battle_loadout = {"character_id": selected_character_id, "weapon_id": selected_weapon_id, "equipment_id": selected_equipment_id}
	if typeof(GameState) != TYPE_NIL and GameState.has_method("set_battle_loadout"):
		GameState.set_battle_loadout(battle_loadout, false)

	var equipment_row: Dictionary = equipment_catalog.get(selected_equipment_id, {})
	active_equipment_effects = parse_string_list(str(equipment_row.get("effect_keys", "")))
	equipment_event_counts.clear()
	hide_enemy_health_bars = active_equipment_effects.has("hide_enemy_hp")
	if active_equipment_effects.has("mana_recovery_up"):
		run_mana_recovery_mul *= 1.35
	if active_equipment_effects.has("crit_rate_down"):
		run_crit_chance_add -= 0.08
	if active_equipment_effects.has("lust_reward_up"):
		run_lust_reward_mul *= 1.5
	if active_equipment_effects.has("exhibitionist"):
		run_damage_add += 2.0
		run_crit_chance_add += 0.06
		run_crit_multiplier_add += 0.18
	if active_equipment_effects.has("slime_belt"):
		run_lust_reward_add += 20.0

func load_player_skills() -> void:
	player_skills.clear()
	player_skill_cooldowns.clear()
	for skill_id in player_skill_ids:
		var skill: Dictionary = load_skill_data(skill_id)
		if skill.is_empty():
			continue
		player_skills[int(skill.get("slot", 0))] = skill
		player_skill_cooldowns[str(skill.get("id", skill_id))] = 0.0

func load_skill_data(skill_id: String) -> Dictionary:
	if skill_id == "":
		return {}
	var path: String = "res://BattleAssets/Skill_" + skill_id + ".json"
	if !FileAccess.file_exists(path):
		push_error("Missing skill json: " + path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid skill json: " + path)
		return {}
	return parsed

func load_catalog_by_id(path: String) -> Dictionary:
	var result: Dictionary = {}
	var rows: Array[Dictionary] = load_catalog_rows(path)
	for row in rows:
		var id: String = str(row.get("id", "")).strip_edges()
		if id != "":
			result[id] = row
	return result

func load_catalog_rows(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if !FileAccess.file_exists(path):
		return result

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result

	var headers := file.get_csv_line()
	while !file.eof_reached():
		var columns := file.get_csv_line()
		if columns.is_empty():
			continue

		var row: Dictionary = {}
		for i in range(headers.size()):
			var key := headers[i].strip_edges()
			var value := ""
			if i < columns.size():
				value = columns[i].strip_edges()
			row[key] = value

		var id := str(row.get("id", "")).strip_edges()
		if id != "":
			result.append(row)

	file.close()
	return result

func load_outgame_upgrade_effects() -> void:
	outgame_upgrade_rows = load_catalog_rows(OUTGAME_UPGRADES_CSV)
	outgame_upgrade_effects.clear()
	if outgame_upgrade_rows.is_empty():
		return
	if !GameState.is_loaded:
		return

	for row in outgame_upgrade_rows:
		var id: String = str(row.get("id", "")).strip_edges()
		if id == "":
			continue
		var group_name: String = str(row.get("group", row.get("tab", "player"))).strip_edges()
		if group_name == "base":
			group_name = "building"
		var level: int = GameState.get_upgrade_level(group_name, id)
		if level <= 0:
			continue
		var max_level: int = int(row.get("max_level", 1))
		level = clamp(level, 0, max_level)
		var effect_keys: Array = parse_string_list(str(row.get("effect_key", row.get("effect_keys", ""))))
		if effect_keys.is_empty():
			continue
		var values: Array[float] = parse_float_list(str(row.get("values", row.get("value", "0"))))
		var value := 0.0
		if values.size() > 0:
			value = values[int(clamp(level - 1, 0, values.size() - 1))]
		for key in effect_keys:
			var effect_key: String = str(key).strip_edges()
			if effect_key == "":
				continue
			outgame_upgrade_effects[effect_key] = float(outgame_upgrade_effects.get(effect_key, 0.0)) + value


	if GameState.is_loaded and GameState.has_method("get_merchant_next_battle_effects"):
		var merchant_effects: Dictionary = GameState.get_merchant_next_battle_effects()
		for raw_key in merchant_effects.keys():
			var merchant_key: String = str(raw_key).strip_edges()
			if merchant_key == "":
				continue
			outgame_upgrade_effects[merchant_key] = float(outgame_upgrade_effects.get(merchant_key, 0.0)) + float(merchant_effects[raw_key])

func get_outgame_upgrade_effect(key: String, fallback: float = 0.0) -> float:
	return float(outgame_upgrade_effects.get(key, fallback))

func parse_float_list(text: String) -> Array[float]:
	var result: Array[float] = []
	var clean := text.strip_edges()
	if clean == "":
		return result
	var parts: PackedStringArray = clean.split("|", false)
	for part in parts:
		var value_text := part.strip_edges()
		if value_text == "":
			continue
		result.append(float(value_text))
	return result

func apply_outgame_upgrades_to_player_entity() -> void:
	if player_entity == null or !is_instance_valid(player_entity):
		return
	var hp_mul := 1.0 + get_outgame_upgrade_effect("player_hp_mul", 0.0)
	if hp_mul != 1.0:
		player_entity.multiply_max_hp(hp_mul)
		player_entity.hp = player_entity.max_hp
	var regen_mul := 1.0 + get_outgame_upgrade_effect("player_regen_mul", 0.0)
	if regen_mul != 1.0:
		player_entity.multiply_regen(regen_mul)
	var speed_mul := 1.0 + get_outgame_upgrade_effect("player_move_speed_mul", 0.0)
	if speed_mul != 1.0:
		player_entity.move_speed *= speed_mul
	var defense_add := get_outgame_upgrade_effect("player_defense_add", 0.0)
	if defense_add != 0.0 and player_entity.has_method("add_defense"):
		player_entity.call("add_defense", defense_add)
	elif defense_add != 0.0:
		var current_defense = player_entity.get("defense")
		if current_defense != null:
			player_entity.set("defense", float(current_defense) + defense_add)
	var mana_add := get_outgame_upgrade_effect("player_mana_max_add", 0.0)
	if mana_add != 0.0:
		player_mana_max += mana_add
		player_mana = player_mana_max
	var mana_regen_add := get_outgame_upgrade_effect("player_mana_regen_add", 0.0)
	if mana_regen_add != 0.0:
		player_mana_regen += mana_regen_add

func apply_outgame_upgrades_to_attack(attack: Dictionary) -> void:
	if attack.is_empty() or attack.get("_outgame_upgrade_applied", false) == true:
		return
	var damage_mul := 1.0 + get_outgame_upgrade_effect("player_attack_mul", 0.0)
	if damage_mul != 1.0:
		multiply_attack_damage(attack, damage_mul)
	var range_mul := 1.0 + get_outgame_upgrade_effect("player_range_mul", 0.0)
	var area_mul := 1.0 + get_outgame_upgrade_effect("player_area_mul", 0.0)
	var speed_mul := 1.0 + get_outgame_upgrade_effect("player_projectile_speed_mul", 0.0)
	if range_mul != 1.0 or area_mul != 1.0 or speed_mul != 1.0:
		multiply_attack_geometry(attack, area_mul, range_mul, speed_mul)
	var count_add: int = int(round(get_outgame_upgrade_effect("player_projectile_count_add", 0.0)))
	if count_add != 0:
		add_nested_number(attack, "emitter", "count", count_add, true)
		add_nested_number(attack, "pattern", "count", count_add, true)
	var fire_rate_bonus: float = get_outgame_upgrade_effect("player_attack_frequency_mul", 0.0)
	if fire_rate_bonus != 0.0:
		var interval_mul: float = 1.0 / max(0.15, 1.0 + fire_rate_bonus)
		if attack.has("interval"):
			attack["interval"] = max(0.05, float(attack.get("interval", 1.0)) * interval_mul)
		if attack.has("cooldown"):
			attack["cooldown"] = max(0.05, float(attack.get("cooldown", 1.0)) * interval_mul)
	attack["_outgame_upgrade_applied"] = true

func apply_outgame_upgrades_to_spawned_entity(entity) -> void:
	if entity == null or !is_instance_valid(entity):
		return
	if entity == player_entity:
		return
	if entity == tentacle_base or (entity.faction == "tentacle" and entity.tags.has("base")):
		var base_hp_mul := 1.0 + get_outgame_upgrade_effect("base_hp_mul", get_outgame_upgrade_effect("building_hp_mul", 0.0))
		if base_hp_mul != 1.0:
			entity.multiply_max_hp(base_hp_mul)
		var base_regen_mul := 1.0 + get_outgame_upgrade_effect("base_regen_mul", get_outgame_upgrade_effect("building_regen_mul", 0.0))
		if base_regen_mul != 1.0:
			entity.multiply_regen(base_regen_mul)
		var bio_gain_mul := 1.0 + get_outgame_upgrade_effect("base_bio_gain_mul", 0.0)
		if bio_gain_mul != 1.0:
			var amounts = entity.get("base_bio_cycle_amounts")
			if typeof(amounts) == TYPE_ARRAY:
				for i in range(amounts.size()):
					amounts[i] = float(amounts[i]) * bio_gain_mul
				entity.set("base_bio_cycle_amounts", amounts)
		var start_bio_add := get_outgame_upgrade_effect("base_start_bio_add", 0.0)
		if start_bio_add != 0.0:
			var current_bio = entity.get("base_bio")
			if current_bio != null:
				entity.set("base_bio", float(current_bio) + start_bio_add)
		return

	if entity.faction == "tentacle" and (entity.tags.has("minion") or entity.tags.has("unit") or entity.tags.has("worker")):
		var minion_hp_mul := 1.0 + get_outgame_upgrade_effect("minion_hp_mul", 0.0)
		if minion_hp_mul != 1.0:
			entity.multiply_max_hp(minion_hp_mul)
		var minion_regen_mul := 1.0 + get_outgame_upgrade_effect("minion_regen_mul", 0.0)
		if minion_regen_mul != 1.0:
			entity.multiply_regen(minion_regen_mul)
		var minion_speed_mul := 1.0 + get_outgame_upgrade_effect("minion_move_speed_mul", 0.0)
		if minion_speed_mul != 1.0:
			entity.move_speed *= minion_speed_mul
		var minion_attack_mul := 1.0 + get_outgame_upgrade_effect("minion_attack_mul", 0.0)
		if minion_attack_mul != 1.0:
			var attacks = entity.get("attacks")
			if typeof(attacks) == TYPE_ARRAY:
				for attack in attacks:
					if typeof(attack) == TYPE_DICTIONARY:
						multiply_attack_damage(attack, minion_attack_mul)


func apply_loadout_to_player() -> void:
	if player_entity == null or !is_instance_valid(player_entity):
		return

	var character_row: Dictionary = character_catalog.get(selected_character_id, {})
	if !character_row.is_empty():
		player_entity.multiply_max_hp(float(character_row.get("hp_mul", 1.0)))
		player_entity.hp = player_entity.max_hp
		player_entity.multiply_regen(float(character_row.get("regen_mul", 1.0)))
		selected_character_skill_mul = float(character_row.get("skill_mul", selected_character_skill_mul))

	if active_equipment_effects.has("player_hp_down"):
		player_entity.multiply_max_hp(0.78)
		player_entity.hp = min(player_entity.hp, player_entity.max_hp)
	if active_equipment_effects.has("player_hp_down_big"):
		player_entity.multiply_max_hp(0.34)
		player_entity.hp = min(player_entity.hp, player_entity.max_hp)
	if active_equipment_effects.has("player_regen_down"):
		player_entity.multiply_regen(0.25)
	if active_equipment_effects.has("player_speed_down_big"):
		player_entity.move_speed *= 0.34
	if active_equipment_effects.has("player_speed_up_small"):
		player_entity.move_speed *= 1.15

	apply_outgame_upgrades_to_player_entity()

	var weapon_row: Dictionary = weapon_catalog.get(selected_weapon_id, {})
	if weapon_row.is_empty():
		return

	selected_weapon_type = str(weapon_row.get("weapon_type", "ranged"))
	if active_equipment_effects.has("range_weapon_only"):
		selected_weapon_id = get_first_weapon_id_with_tag("area", selected_weapon_id)
		weapon_row = weapon_catalog.get(selected_weapon_id, weapon_row)
		selected_weapon_type = str(weapon_row.get("weapon_type", "area"))
	var attack_id: String = str(weapon_row.get("attack_id", "")).strip_edges()
	var attack_data: Dictionary = load_attack_data(attack_id)
	if attack_data.is_empty():
		return

	attack_data["weapon_id"] = selected_weapon_id
	attack_data["weapon_level"] = 1
	apply_character_weapon_multiplier(attack_data, character_row, selected_weapon_type)
	apply_run_stats_to_attack(attack_data)
	apply_equipment_to_player_attack(attack_data)
	player_entity.set_attacks([attack_data])
	owned_weapon_ids.clear()
	owned_weapon_ids.append(selected_weapon_id)
	weapon_levels.clear()
	weapon_levels[selected_weapon_id] = 1

func apply_character_weapon_multiplier(attack: Dictionary, character_row: Dictionary, weapon_type: String) -> void:
	if character_row.is_empty():
		return

	var multiplier := 1.0
	if weapon_type == "melee":
		multiplier = float(character_row.get("melee_mul", 1.0))
	elif weapon_type == "ranged" or weapon_type == "area" or weapon_type == "aura":
		multiplier = float(character_row.get("ranged_mul", 1.0))

	if multiplier == 1.0:
		return

	multiply_attack_damage(attack, multiplier)

func get_first_weapon_id_with_tag(required_tag: String, fallback_id: String) -> String:
	for id in weapon_catalog.keys():
		var row: Dictionary = weapon_catalog[id]
		var tags: Array = parse_string_list(str(row.get("tags", "")))
		var weapon_type: String = str(row.get("weapon_type", ""))
		if tags.has(required_tag) or weapon_type == required_tag:
			return str(id)
	return fallback_id

func apply_equipment_to_player_attack(attack: Dictionary) -> void:
	if bool(attack.get("_equipment_applied", false)):
		return
	if active_equipment_effects.has("whip_weapon_penalty"):
		multiply_attack_damage(attack, 0.5)
	if active_equipment_effects.has("bind_area_boost"):
		multiply_attack_damage(attack, 1.166)
		multiply_nested_number(attack, "hit_shape", "radius", 1.66, true)
		multiply_nested_number(attack, "hit_shape", "width", 1.66, true)
		add_nested_number(attack, "hit_shape", "angle", 18.0)
	if active_equipment_effects.has("melee_lifesteal"):
		add_effect_number(attack, "life_steal", 0.06)
	attack["_equipment_applied"] = true

func multiply_attack_damage(attack: Dictionary, multiplier: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "damage" and effect.has("value"):
			effect["value"] = float(effect["value"]) * multiplier
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			multiply_attack_damage(effect["attack"], multiplier)

func apply_run_stats_to_attack(attack: Dictionary) -> void:
	if run_damage_add != 0.0:
		add_attack_damage(attack, run_damage_add)
	if run_bonus_damage_add != 0.0:
		attack["bonus_damage_add"] = float(attack.get("bonus_damage_add", 0.0)) + run_bonus_damage_add
	if run_crit_chance_add != 0.0:
		attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + run_crit_chance_add
	if run_crit_multiplier_add != 0.0:
		attack["crit_multiplier"] = float(attack.get("crit_multiplier", 1.5)) + run_crit_multiplier_add
	if standard_mode_balance_enabled:
		apply_standard_player_weapon_tuning(attack)
	apply_outgame_upgrades_to_attack(attack)

func add_attack_damage(attack: Dictionary, amount: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "damage" and effect.has("value"):
			effect["value"] = float(effect["value"]) + amount
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			add_attack_damage(effect["attack"], amount)

func apply_standard_player_weapon_tuning(attack: Dictionary) -> void:
	if bool(attack.get("_standard_weapon_tuned", false)):
		return
	attack["_standard_weapon_tuned"] = true
	multiply_attack_damage(attack, standard_player_weapon_damage_mul)
	multiply_attack_geometry(attack, standard_player_weapon_area_mul, standard_player_weapon_range_mul, standard_player_projectile_speed_mul)
	if attack.has("interval"):
		attack["interval"] = max(0.10, float(attack.get("interval", 1.0)) * standard_player_weapon_interval_mul)
	if attack.has("cooldown"):
		attack["cooldown"] = max(0.10, float(attack.get("cooldown", 1.0)) * standard_player_weapon_interval_mul)

func apply_standard_player_skill_tuning(attack: Dictionary) -> void:
	if bool(attack.get("_standard_skill_tuned", false)):
		return
	attack["_standard_skill_tuned"] = true
	multiply_attack_geometry(attack, standard_player_skill_area_mul, standard_player_skill_area_mul, standard_player_projectile_speed_mul)

func multiply_attack_geometry(attack: Dictionary, area_mul: float, range_mul: float, speed_mul: float) -> void:
	if attack.has("range"):
		attack["range"] = float(attack.get("range", 0.0)) * range_mul
	if attack.has("radius"):
		attack["radius"] = float(attack.get("radius", 0.0)) * area_mul
	if attack.has("speed"):
		attack["speed"] = float(attack.get("speed", 0.0)) * speed_mul
	if attack.has("life_time"):
		attack["life_time"] = float(attack.get("life_time", 0.0)) * max(1.0, range_mul * 0.85)

	var motion: Dictionary = attack.get("motion", {})
	if !motion.is_empty():
		if motion.has("speed"):
			motion["speed"] = float(motion.get("speed", 0.0)) * speed_mul
		if motion.has("max_distance"):
			motion["max_distance"] = float(motion.get("max_distance", 0.0)) * range_mul
		if motion.has("range"):
			motion["range"] = float(motion.get("range", 0.0)) * range_mul
		if motion.has("duration"):
			motion["duration"] = float(motion.get("duration", 0.0)) * max(1.0, range_mul * 0.72)
		if motion.has("life_time"):
			motion["life_time"] = float(motion.get("life_time", 0.0)) * max(1.0, range_mul * 0.72)
		attack["motion"] = motion

	var hit_shape: Dictionary = attack.get("hit_shape", {})
	if !hit_shape.is_empty():
		if hit_shape.has("radius"):
			hit_shape["radius"] = float(hit_shape.get("radius", 0.0)) * area_mul
		if hit_shape.has("width"):
			hit_shape["width"] = float(hit_shape.get("width", 0.0)) * area_mul
		if hit_shape.has("length"):
			hit_shape["length"] = float(hit_shape.get("length", 0.0)) * range_mul
		if hit_shape.has("angle"):
			hit_shape["angle"] = min(360.0, float(hit_shape.get("angle", 0.0)) + 6.0)
		attack["hit_shape"] = hit_shape

	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			multiply_attack_geometry(effect["attack"], area_mul, range_mul, speed_mul)

func apply_equipment_to_entity_data(data: Dictionary) -> void:
	if active_equipment_effects.is_empty():
		return

	if str(data.get("faction", "")) == "enemy" and active_equipment_effects.has("enemy_hp_random_up"):
		var stats: Dictionary = data.get("stats", {})
		stats["max_hp"] = float(stats.get("max_hp", 100.0)) * randf_range(1.05, 1.35)
		data["stats"] = stats

func apply_equipment_to_spawned_entity(entity) -> void:
	if entity == null or !is_instance_valid(entity):
		return

	if hide_enemy_health_bars and entity.faction == "enemy":
		entity.set_health_bar_hidden(true)

func setup_block_mask() -> void:
	if block_mask_sprite == null:
		return

	if block_mask_sprite.texture == null:
		return

	block_mask_image = block_mask_sprite.texture.get_image()

func setup_ui() -> void:
	if timer_label:
		timer_label.position = Vector2(24, 18)
		timer_label.size = Vector2(260, 32)
		timer_label.add_theme_font_size_override("font_size", 24)

	if objective_label:
		objective_label.position = Vector2(24, 54)
		objective_label.size = Vector2(620, 80)
		objective_label.add_theme_font_size_override("font_size", 20)

	if player_base_bar:
		player_base_bar.position = Vector2(24, 138)
		player_base_bar.size = Vector2(280, 18)

	if enemy_base_bar:
		enemy_base_bar.position = Vector2(24, 166)
		enemy_base_bar.size = Vector2(280, 18)

	kill_label = ui_layer.get_node_or_null("LabelKills")
	if kill_label == null:
		kill_label = Label.new()
		kill_label.name = "LabelKills"
		ui_layer.add_child(kill_label)

	kill_label.position = Vector2(24, 196)
	kill_label.size = Vector2(360, 32)
	kill_label.add_theme_font_size_override("font_size", 20)

	level_label = ui_layer.get_node_or_null("LabelPlayerLevel")
	if level_label == null:
		level_label = Label.new()
		level_label.name = "LabelPlayerLevel"
		ui_layer.add_child(level_label)

	level_label.position = Vector2(24, 224)
	level_label.size = Vector2(440, 32)
	level_label.add_theme_font_size_override("font_size", 20)

	setup_mana_panel()

	debug_label = ui_layer.get_node_or_null("LabelBattleDebug")
	if debug_label == null:
		debug_label = Label.new()
		debug_label.name = "LabelBattleDebug"
		ui_layer.add_child(debug_label)

	debug_label.position = Vector2(24, 310)
	debug_label.size = Vector2(560, 70)
	debug_label.add_theme_font_size_override("font_size", 16)
	setup_base_queue_panel()
	setup_level_choice_panel()

func setup_mana_panel() -> void:
	mana_panel = ui_layer.get_node_or_null("PanelMana")
	if mana_panel == null:
		mana_panel = PanelContainer.new()
		mana_panel.name = "PanelMana"
		ui_layer.add_child(mana_panel)

	mana_panel.position = Vector2(24, 254)
	mana_panel.size = Vector2(300, 48)
	mana_panel.custom_minimum_size = Vector2(300, 48)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.08, 0.72)
	style.border_color = Color(0.30, 0.72, 1.0, 0.78)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	mana_panel.add_theme_stylebox_override("panel", style)

	for child in mana_panel.get_children():
		mana_panel.remove_child(child)
		child.queue_free()

	var box := VBoxContainer.new()
	box.name = "VBoxMana"
	mana_panel.add_child(box)

	mana_label = Label.new()
	mana_label.name = "LabelMana"
	mana_label.text = "Mana"
	mana_label.add_theme_font_size_override("font_size", 13)
	mana_label.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0, 1.0))
	box.add_child(mana_label)

	mana_bar = ProgressBar.new()
	mana_bar.name = "ProgressBarMana"
	mana_bar.min_value = 0.0
	mana_bar.max_value = player_mana_max
	mana_bar.value = player_mana
	mana_bar.show_percentage = false
	mana_bar.custom_minimum_size = Vector2(280, 12)
	box.add_child(mana_bar)

func setup_base_queue_panel() -> void:
	base_queue_panel = ui_layer.get_node_or_null("PanelBaseQueues")
	if base_queue_panel == null:
		base_queue_panel = PanelContainer.new()
		base_queue_panel.name = "PanelBaseQueues"
		ui_layer.add_child(base_queue_panel)

	base_queue_panel.position = Vector2(24, 390)
	base_queue_panel.size = Vector2(360, 168)
	base_queue_panel.custom_minimum_size = Vector2(360, 168)
	base_queue_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.02, 0.05, 0.72)
	style.border_color = Color(0.95, 0.34, 0.86, 0.68)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	base_queue_panel.add_theme_stylebox_override("panel", style)

	for child in base_queue_panel.get_children():
		base_queue_panel.remove_child(child)
		child.queue_free()

	base_queue_box = VBoxContainer.new()
	base_queue_box.name = "VBoxBaseQueues"
	base_queue_panel.add_child(base_queue_box)

func setup_level_choice_panel() -> void:
	level_choice_panel = ui_layer.get_node_or_null("PanelLevelChoice")
	if level_choice_panel == null:
		level_choice_panel = PanelContainer.new()
		level_choice_panel.name = "PanelLevelChoice"
		ui_layer.add_child(level_choice_panel)

	level_choice_panel.position = Vector2(430, 210)
	level_choice_panel.size = Vector2(520, 260)
	level_choice_panel.custom_minimum_size = Vector2(520, 260)
	level_choice_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	level_choice_panel.visible = false

func style_level_choice_panel(kind: String) -> void:
	if level_choice_panel == null:
		return

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2

	if kind == "base":
		level_choice_panel.position = Vector2(300, 96)
		level_choice_panel.size = Vector2(680, 500)
		level_choice_panel.custom_minimum_size = Vector2(680, 500)
		style.bg_color = Color(0.13, 0.025, 0.13, 0.94)
		style.border_color = Color(1.0, 0.38, 0.86, 0.92)
	else:
		level_choice_panel.position = Vector2(430, 210)
		level_choice_panel.size = Vector2(520, 260)
		level_choice_panel.custom_minimum_size = Vector2(520, 260)
		style.bg_color = Color(0.035, 0.075, 0.13, 0.94)
		style.border_color = Color(0.32, 0.78, 1.0, 0.88)

	level_choice_panel.add_theme_stylebox_override("panel", style)

func setup_stage_area_visuals() -> void:
	stage_area_visuals.clear()
	if effects_root == null:
		return
	for area_id in get_visible_stage_area_ids():
		if !stage_areas.has(area_id):
			continue
		var line: Line2D = make_stage_area_line(area_id, Color(0.54, 0.76, 1.0, 0.34))
		if line == null:
			continue
		effects_root.add_child(line)
		stage_area_visuals[area_id] = line

func get_visible_stage_area_ids() -> Array[String]:
	var ids: Array[String] = []
	if objective_area_id != "":
		ids.append(objective_area_id)
	for area_id in objective_area_ids:
		if !ids.has(area_id):
			ids.append(area_id)
	for event in stage_events:
		var area_id: String = str(event.get("area", ""))
		if area_id != "" and !ids.has(area_id):
			ids.append(area_id)
	return ids

func make_stage_area_line(area_id: String, color: Color) -> Line2D:
	if !stage_areas.has(area_id):
		return null
	var area: Dictionary = stage_areas[area_id]
	var center: Vector2 = area.get("center", Vector2.ZERO)
	var line := Line2D.new()
	line.name = "StageArea_" + area_id
	line.default_color = color
	line.width = 3.0
	line.closed = true
	line.z_index = 3
	var shape: String = str(area.get("shape", "circle"))
	if shape == "rect":
		var size: Vector2 = area.get("size", Vector2(160.0, 160.0))
		var half: Vector2 = size * 0.5
		line.add_point(center + Vector2(-half.x, -half.y))
		line.add_point(center + Vector2(half.x, -half.y))
		line.add_point(center + Vector2(half.x, half.y))
		line.add_point(center + Vector2(-half.x, half.y))
	else:
		var radius: float = float(area.get("radius", 120.0))
		for i in range(96):
			var t: float = float(i) / 96.0
			line.add_point(center + Vector2.RIGHT.rotated(t * TAU) * radius)
	return line

func spawn_initial_entities() -> void:
	var player_id: String = str(config.get_value("player", "entity_id", "000"))
	var player_spawn: String = str(config.get_value("player", "spawn", "PlayerSpawn"))
	player_entity = spawn_entity(player_id, get_spawn_position(player_spawn, {}))
	apply_loadout_to_player()

	var base_id: String = str(config.get_value("tentacle_base", "entity_id", "001"))
	var base_spawn: String = str(config.get_value("tentacle_base", "spawn", "TentacleBaseSpawn"))
	tentacle_base = spawn_entity(base_id, get_spawn_position(base_spawn, {}))
	apply_equipment_to_tentacle_base()
	spawn_starting_worker()

	var enemy_base_id: String = str(config.get_value("enemy_base", "entity_id", "003"))
	var enemy_base_spawn: String = str(config.get_value("enemy_base", "spawn", "EnemyBaseSpawn"))
	enemy_base = spawn_entity(enemy_base_id, get_spawn_position(enemy_base_spawn, {}))
	equipment_last_player_pos = player_entity.global_position if player_entity != null and is_instance_valid(player_entity) else Vector2.ZERO
	emit_equipment_event("on_battle_start", {})

func apply_equipment_to_tentacle_base() -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return

	if active_equipment_effects.has("base_bio_cycle_yield_up") and tentacle_base.base_bio_cycle_amounts.size() > 0:
		for i in range(tentacle_base.base_bio_cycle_amounts.size()):
			tentacle_base.base_bio_cycle_amounts[i] = float(tentacle_base.base_bio_cycle_amounts[i]) + 5.0

func spawn_starting_worker() -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return
	var worker_id: String = str(config.get_value("tentacle_base", "worker_entity_id", "020"))
	if worker_id == "":
		return
	var spawn_pos: Vector2 = get_starting_worker_spawn_position(worker_id)
	spawn_entity(worker_id, clamp_to_map(spawn_pos))

func get_starting_worker_spawn_position(worker_id: String) -> Vector2:
	var configured_offset: Vector2 = parse_vector2(str(config.get_value("tentacle_base", "worker_spawn_offset", "-170,245")), Vector2(-170.0, 245.0))
	var delivery_center: Vector2 = tentacle_base.get_delivery_center()
	var candidate_offsets: Array[Vector2] = [
		configured_offset,
		Vector2(-170.0, 245.0),
		Vector2(170.0, 245.0),
		Vector2(-220.0, 175.0),
		Vector2(220.0, 175.0),
		Vector2(0.0, 345.0)
	]

	for offset in candidate_offsets:
		var pos: Vector2 = clamp_to_map(tentacle_base.global_position + offset)
		if is_spawn_position_clear(pos, worker_id):
			return pos

	for side_offset in [Vector2(-120.0, 0.0), Vector2(120.0, 0.0), Vector2(0.0, 92.0)]:
		var pos_delivery: Vector2 = clamp_to_map(delivery_center + side_offset)
		if is_spawn_position_clear(pos_delivery, worker_id):
			return pos_delivery

	return tentacle_base.get_base_spawn_position(worker_id)

func on_base_leveled_up(base_entity, new_level: int) -> void:
	if base_entity != tentacle_base:
		return
	if !BASE_LEVEL_CHOICES.has(new_level):
		return

	var config_entry: Dictionary = BASE_LEVEL_CHOICES[new_level]
	var unlock: Dictionary = config_entry.get("unlock", {})
	if !unlock.is_empty():
		tentacle_base.unlock_or_update_base_queue(unlock)

	show_base_upgrade_choices(new_level, "base")

func show_base_upgrade_choices(level: int, phase: String) -> void:
	if level_choice_panel == null:
		return
	if !BASE_LEVEL_CHOICES.has(level):
		return

	base_choice_active = true
	pending_base_level = level
	style_level_choice_panel("base")
	level_choice_panel.visible = true
	get_tree().paused = true

	for child in level_choice_panel.get_children():
		level_choice_panel.remove_child(child)
		child.queue_free()

	var box: VBoxContainer = VBoxContainer.new()
	box.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	level_choice_panel.add_child(box)

	var title: Label = Label.new()
	title.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.68, 0.96, 1.0))
	title.text = "基地进化 Lv" + str(level)
	box.add_child(title)

	var info: Label = Label.new()
	info.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(620.0, 76.0)
	info.add_theme_color_override("font_color", Color(0.96, 0.82, 1.0, 1.0))
	info.text = get_base_level_info(level, phase)
	box.add_child(info)

	var choices: Array = BASE_LEVEL_CHOICES[level].get(phase, [])
	if choices.is_empty() and phase == "minion":
		get_tree().paused = false
		base_choice_active = false
		level_choice_panel.visible = false
		return

	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var button: Button = Button.new()
		button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		button.text = str(choice.get("name", "")) + "\n" + str(choice.get("desc", ""))
		button.custom_minimum_size = Vector2(620.0, 76.0)
		button.add_theme_font_size_override("font_size", 16)
		if phase == "base":
			button.pressed.connect(_on_base_upgrade_selected.bind(choice))
		else:
			button.pressed.connect(_on_minion_upgrade_selected.bind(choice))
		box.add_child(button)

func get_base_level_info(level: int, phase: String) -> String:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return ""
	var unlocked_name: String = "无"
	var unlock: Dictionary = BASE_LEVEL_CHOICES.get(level, {}).get("unlock", {})
	if !unlock.is_empty():
		unlocked_name = get_entity_display_name(str(unlock.get("entity_id", "")))
	var base_text: String = "基地已获得：Lv" + str(level) + " 基础生产/菌毯应激提升。"
	if phase == "base":
		return base_text + "\n基地可选当级额外能力：请选择 1 项。"
	return "触手兵：" + unlocked_name + " 已解锁。\n可选 " + unlocked_name + " 能力方向：请选择 1 项。"

func _on_base_upgrade_selected(choice: Dictionary) -> void:
	pending_base_choice = choice.duplicate(true)
	apply_base_upgrade_choice(choice)
	call_deferred("show_base_upgrade_choices", pending_base_level, "minion")

func _on_minion_upgrade_selected(choice: Dictionary) -> void:
	apply_minion_upgrade_choice(choice)
	base_choice_active = false
	level_choice_panel.visible = false
	get_tree().paused = false

func apply_base_upgrade_choice(choice: Dictionary) -> void:
	apply_upgrade_choice_to_runtime(choice)

func apply_minion_upgrade_choice(choice: Dictionary) -> void:
	apply_upgrade_choice_to_runtime(choice)

func apply_upgrade_choice_to_runtime(choice: Dictionary) -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return

	play_upgrade_choice_fx(choice)

	if choice.has("bio_cycle_add"):
		var index: int = clamp(tentacle_base.base_level - 1, 0, tentacle_base.base_bio_cycle_amounts.size() - 1)
		for i in range(index, tentacle_base.base_bio_cycle_amounts.size()):
			tentacle_base.base_bio_cycle_amounts[i] = float(tentacle_base.base_bio_cycle_amounts[i]) + float(choice["bio_cycle_add"])

	if choice.has("mutation_gift"):
		var gift_data: Dictionary = choice["mutation_gift"]
		tentacle_base.mutation_gift_enabled = true
		tentacle_base.mutation_gift_chance_base = float(gift_data.get("chance_base", tentacle_base.mutation_gift_chance_base))
		tentacle_base.mutation_gift_chance_per_level = float(gift_data.get("chance_per_level", tentacle_base.mutation_gift_chance_per_level))
		tentacle_base.mutation_gift_entity_ids = gift_data.get("entity_ids", tentacle_base.mutation_gift_entity_ids)

	if choice.has("contact_damage_mul"):
		tentacle_base.contact_damage *= float(choice["contact_damage_mul"])

	if choice.has("contact_cooldown_mul"):
		tentacle_base.contact_cooldown *= float(choice["contact_cooldown_mul"])

	if choice.has("contact_status"):
		tentacle_base.contact_statuses.append(choice["contact_status"].duplicate(true))

	if choice.has("contact_execute_chance"):
		tentacle_base.contact_execute_chance = max(tentacle_base.contact_execute_chance, float(choice["contact_execute_chance"]))

	if choice.has("contact_execute_hp_ratio"):
		tentacle_base.contact_execute_hp_ratio = max(tentacle_base.contact_execute_hp_ratio, float(choice["contact_execute_hp_ratio"]))

	if choice.has("aura_speed_mul"):
		tentacle_base.base_aura_speed_mul *= float(choice["aura_speed_mul"])

	if choice.has("aura_regen_add"):
		tentacle_base.base_aura_regen_add += float(choice["aura_regen_add"])

	if choice.has("spawn_enemy_base_damage"):
		tentacle_base.base_spawn_enemy_base_damage += float(choice["spawn_enemy_base_damage"])

	if choice.has("mana_per_bio"):
		base_mana_return_per_bio += float(choice["mana_per_bio"])

	if choice.has("revive_count"):
		player_revives_remaining += int(choice["revive_count"])
		revive_base_hp_cost_ratio = float(choice.get("revive_base_hp_cost_ratio", revive_base_hp_cost_ratio))
		revive_base_min_hp_ratio = float(choice.get("revive_base_min_hp_ratio", revive_base_min_hp_ratio))

	if choice.has("assimilation_lust_add"):
		assimilation_lust_reward_add += float(choice["assimilation_lust_add"])

	if choice.has("extraction_lust_add"):
		extraction_lust_reward_add += float(choice["extraction_lust_add"])
		run_lust_reward_add += float(choice["extraction_lust_add"])

	if choice.has("attachment") and tentacle_base.has_method("apply_visual_attachment"):
		tentacle_base.apply_visual_attachment(choice["attachment"])

	if choice.has("assimilated_stat_mul"):
		multiply_assimilated_stat_mul(choice["assimilated_stat_mul"])
		apply_assimilated_stat_mul_to_existing(choice["assimilated_stat_mul"])

	if choice.has("assimilated_building_mul"):
		var building_mul: float = float(choice["assimilated_building_mul"])
		assimilated_building_mul *= building_mul
		apply_assimilated_building_mul_to_existing(building_mul)

	if choice.has("assimilated_invuln"):
		var invuln_data: Dictionary = choice["assimilated_invuln"]
		assimilated_invuln_interval = max(0.1, float(invuln_data.get("interval", assimilated_invuln_interval)))
		assimilated_invuln_duration = max(0.05, float(invuln_data.get("duration", assimilated_invuln_duration)))
		apply_assimilated_invuln_to_existing()

	if choice.has("summon_entity_id"):
		var summon_entity_id: String = str(choice["summon_entity_id"])
		spawn_entity(summon_entity_id, tentacle_base.get_base_spawn_position(summon_entity_id))

	if choice.has("base_laser"):
		add_base_void_laser()

	if choice.has("all_minion_stat_mul"):
		for entity in entities:
			if entity != null and is_instance_valid(entity) and entity.faction == "tentacle" and entity.entity_type == "minion":
				entity.apply_runtime_stat_multipliers(choice["all_minion_stat_mul"])

	var queue_id: String = str(choice.get("queue_id", ""))
	if queue_id != "":
		modify_base_queue(queue_id, choice)

func multiply_assimilated_stat_mul(stat_mul: Dictionary) -> void:
	for key in stat_mul.keys():
		assimilated_stat_mul[key] = float(assimilated_stat_mul.get(key, 1.0)) * float(stat_mul[key])

func apply_assimilated_stat_mul_to_existing(stat_mul: Dictionary) -> void:
	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if !entity.tags.has("assimilated_girl"):
			continue
		entity.apply_runtime_stat_multipliers(stat_mul)

func apply_assimilated_building_mul_to_existing(building_mul: float) -> void:
	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if !entity.tags.has("assimilated_girl"):
			continue
		entity.damage_multipliers["building"] = float(entity.damage_multipliers.get("building", 1.0)) * building_mul
		for attack in entity.attacks:
			if typeof(attack) != TYPE_DICTIONARY:
				continue
			var damage_multipliers: Dictionary = attack.get("damage_multipliers", {})
			damage_multipliers["building"] = float(damage_multipliers.get("building", 1.0)) * building_mul
			attack["damage_multipliers"] = damage_multipliers

func apply_assimilated_invuln_to_existing() -> void:
	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if !entity.tags.has("assimilated_girl"):
			continue
		if assimilated_invuln_interval > 0.0 and assimilated_invuln_duration > 0.0:
			entity.set_meta("assimilated_invuln_interval", assimilated_invuln_interval)
			entity.set_meta("assimilated_invuln_duration", assimilated_invuln_duration)
			entity.set_meta("assimilated_invuln_timer", randf_range(0.4, assimilated_invuln_interval))

func apply_assimilated_runtime_modifiers(entity) -> void:
	if entity == null or !is_instance_valid(entity):
		return
	if !entity.tags.has("assimilated_girl"):
		return
	if bool(entity.get_meta("assimilated_runtime_applied", false)):
		return

	if !assimilated_stat_mul.is_empty():
		entity.apply_runtime_stat_multipliers(assimilated_stat_mul)

	if assimilated_building_mul != 1.0:
		entity.damage_multipliers["building"] = float(entity.damage_multipliers.get("building", 1.0)) * assimilated_building_mul
		for attack in entity.attacks:
			if typeof(attack) != TYPE_DICTIONARY:
				continue
			var damage_multipliers: Dictionary = attack.get("damage_multipliers", {})
			damage_multipliers["building"] = float(damage_multipliers.get("building", 1.0)) * assimilated_building_mul
			attack["damage_multipliers"] = damage_multipliers

	if assimilated_invuln_interval > 0.0 and assimilated_invuln_duration > 0.0:
		entity.set_meta("assimilated_invuln_interval", assimilated_invuln_interval)
		entity.set_meta("assimilated_invuln_duration", assimilated_invuln_duration)
		entity.set_meta("assimilated_invuln_timer", randf_range(0.4, assimilated_invuln_interval))

	entity.set_meta("assimilated_runtime_applied", true)

func play_upgrade_choice_fx(choice: Dictionary) -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return

	var color: Color = get_upgrade_choice_fx_color(choice)
	var center: Vector2 = tentacle_base.global_position
	spawn_ring_fx(center, float(choice.get("fx_radius", 150.0 + float(tentacle_base.base_level) * 18.0)), color, 8.0, 0.72)
	spawn_floating_number(center + Vector2(0.0, -tentacle_base.radius - 64.0), str(choice.get("name", "进化")), color)

	if choice.has("base_laser") and enemy_base != null and is_instance_valid(enemy_base):
		spawn_line_fx(center, enemy_base.global_position, color, 10.0, 0.38)

	if choice.has("all_minion_stat_mul") or choice.has("aura_speed_mul") or choice.has("aura_regen_add"):
		for entity in entities:
			if entity == null or !is_instance_valid(entity):
				continue
			if entity.faction == "tentacle" and entity.entity_type == "minion":
				spawn_line_fx(center, entity.global_position, color, 4.0, 0.22)

func get_upgrade_choice_fx_color(choice: Dictionary) -> Color:
	if choice.has("fx_color"):
		return parse_color(str(choice["fx_color"]), Color(1.0, 0.42, 0.9, 1.0))
	if choice.has("bio_cycle_add") or choice.has("bio_on_hit_add") or choice.has("reward_bio_add"):
		return Color(0.54, 1.0, 0.38, 0.92)
	if choice.has("mutation_gift"):
		return Color(0.92, 0.42, 1.0, 0.92)
	if choice.has("base_laser") or choice.has("contact_damage_mul") or choice.has("summon_entity_id"):
		return Color(1.0, 0.25, 0.34, 0.92)
	if choice.has("all_minion_stat_mul") or choice.has("stat_mul"):
		return Color(1.0, 0.72, 0.22, 0.92)
	if str(choice.get("queue_id", "")) != "":
		return Color(0.85, 0.45, 1.0, 0.92)
	return Color(1.0, 0.42, 0.9, 0.92)

func modify_base_queue(queue_id: String, choice: Dictionary) -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return

	for i in range(tentacle_base.base_spawn_queues.size()):
		var queue: Dictionary = tentacle_base.base_spawn_queues[i]
		if str(queue.get("id", "")) != queue_id:
			continue
		if choice.has("quantity_add"):
			queue["quantity"] = int(queue.get("quantity", 1)) + int(choice["quantity_add"])
		if choice.has("interval_mul"):
			queue["interval"] = max(0.2, float(queue.get("interval", 3.0)) * float(choice["interval_mul"]))
		if choice.has("stat_mul"):
			var stat_mul: Dictionary = queue.get("stat_mul", {})
			for key in choice["stat_mul"].keys():
				stat_mul[key] = float(stat_mul.get(key, 1.0)) * float(choice["stat_mul"][key])
			queue["stat_mul"] = stat_mul
		if choice.has("reward_bio_add"):
			queue["reward_bio_add"] = int(queue.get("reward_bio_add", 0)) + int(choice["reward_bio_add"])
		if choice.has("bio_on_hit_add"):
			queue["bio_on_hit_add"] = int(queue.get("bio_on_hit_add", 0)) + int(choice["bio_on_hit_add"])
		if choice.has("on_hit_status"):
			var statuses: Array = queue.get("on_hit_statuses", [])
			statuses.append(choice["on_hit_status"].duplicate(true))
			queue["on_hit_statuses"] = statuses
		if choice.has("enemy_base_missing_hp_interval_mul"):
			queue["enemy_base_missing_hp_interval_mul"] = min(float(queue.get("enemy_base_missing_hp_interval_mul", 1.0)), float(choice["enemy_base_missing_hp_interval_mul"]))
		if choice.has("low_hp_attack_damage_mul"):
			queue["low_hp_attack_damage_mul"] = max(float(queue.get("low_hp_attack_damage_mul", 1.0)), float(choice["low_hp_attack_damage_mul"]))
			queue["low_hp_attack_threshold"] = float(choice.get("low_hp_attack_threshold", queue.get("low_hp_attack_threshold", 0.35)))
		if choice.has("death_attack"):
			queue["death_attack"] = choice["death_attack"].duplicate(true)
		tentacle_base.base_spawn_queues[i] = queue
		return

func add_base_void_laser() -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return
	var attack: Dictionary = load_attack_data("base_void_laser")
	if attack.is_empty():
		return
	tentacle_base.add_attack(attack)

func damage_enemy_base_from_spawn(amount: float, source = null) -> void:
	if amount <= 0.0:
		return
	if enemy_base == null or !is_instance_valid(enemy_base):
		return
	enemy_base.take_damage(amount, source)

func get_entity_display_name(entity_id: String) -> String:
	var data: Dictionary = load_entity_data(entity_id)
	if data.is_empty():
		return entity_id
	return str(data.get("name", entity_id))

func load_waves() -> void:
	waves.clear()

	for section in config.get_sections():
		if !section.begins_with("wave_"):
			continue

		var wave: Dictionary = {
			"section": section,
			"time": float(config.get_value(section, "time", 0.0)),
			"entity_id": str(config.get_value(section, "entity_id", "")),
			"count": int(config.get_value(section, "count", 1)),
			"spawn": str(config.get_value(section, "spawn", "")),
			"interval": float(config.get_value(section, "interval", 0.5)),
			"distance_min": float(config.get_value(section, "distance_min", 700.0)),
			"distance_max": float(config.get_value(section, "distance_max", 1000.0)),
			"random_radius_min": float(config.get_value(section, "random_radius_min", 0.0)),
			"random_radius": float(config.get_value(section, "random_radius", 0.0)),
			"ai_mode": str(config.get_value(section, "ai_mode", "")),
			"movement_mode": str(config.get_value(section, "movement_mode", "")),
			"target_factions": str(config.get_value(section, "target_factions", "")),
			"target_priority": str(config.get_value(section, "target_priority", "")),
			"target_priority_order": str(config.get_value(section, "target_priority_order", "")),
			"target_distance_mode": str(config.get_value(section, "target_distance_mode", "")),
			"ai_role": str(config.get_value(section, "ai_role", "")),
			"role": str(config.get_value(section, "role", "")),
			"swarm_group_size": int(config.get_value(section, "swarm_group_size", swarm_default_group_size)),
			"swarm_flow": bool(config.get_value(section, "swarm_flow", true)),
			"max_hp_mul": float(config.get_value(section, "max_hp_mul", 1.0)),
			"move_speed_mul": float(config.get_value(section, "move_speed_mul", 1.0)),
			"attack_mul": float(config.get_value(section, "attack_mul", 1.0)),
			"defense_mul": float(config.get_value(section, "defense_mul", 1.0)),
			"xp_mul": float(config.get_value(section, "xp_mul", 1.0)),
			"bio_mul": float(config.get_value(section, "bio_mul", 1.0)),
			"started": false,
			"spawned": 0,
			"timer": 0.0
		}

		waves.append(wave)

func process_waves(delta: float) -> void:
	for wave in waves:
		if !wave["started"]:
			if battle_time >= wave["time"]:
				wave["started"] = true
				wave["timer"] = 0.0

		if !wave["started"]:
			continue

		if wave["spawned"] >= wave["count"]:
			continue

		wave["timer"] -= delta
		if wave["timer"] > 0.0:
			continue

		var pos: Vector2 = get_spawn_position(str(wave["spawn"]), wave)
		spawn_entity(str(wave["entity_id"]), pos, wave)
		wave["spawned"] += 1
		wave["timer"] = wave["interval"]

func process_stage_objectives(delta: float) -> void:
	if battle_won or battle_lost:
		return

	if is_player_defeated():
		record_battle_loss("player_dead")
		return
	if is_base_defeated():
		record_battle_loss("base_dead")
		return

	if win_condition == "destroy_enemy_base" or win_condition == "test":
		return

	if win_condition == "survive_time":
		if objective_duration > 0.0 and battle_time >= objective_duration:
			record_battle_win(null)
		return

	if win_condition == "reach_area":
		if is_entity_in_area(player_entity, objective_area_id):
			record_battle_win(null)
		return

	if win_condition == "escort_entity":
		if is_any_matching_entity_in_area(objective_target_entity_id, objective_target_faction, objective_area_id):
			record_battle_win(null)
		return

	if win_condition == "kill_count":
		if objective_target_count > 0 and enemy_kill_count >= objective_target_count:
			record_battle_win(null)
		return

	if win_condition == "kill_entity_id":
		if objective_target_count > 0 and objective_progress_count >= objective_target_count:
			record_battle_win(null)
		return

	if win_condition == "hold_area":
		if is_entity_in_area(player_entity, objective_area_id):
			objective_hold_time += delta
		else:
			objective_hold_time = max(0.0, objective_hold_time - delta * 0.6)
		if objective_duration > 0.0 and objective_hold_time >= objective_duration:
			record_battle_win(null)
		return

	if win_condition == "activate_areas":
		for area_id in objective_area_ids:
			if !objective_activated_areas.has(area_id) and is_entity_in_area(player_entity, area_id):
				objective_activated_areas[area_id] = true
				spawn_stage_area_fx(area_id)
		if !objective_area_ids.is_empty() and objective_activated_areas.size() >= objective_area_ids.size():
			record_battle_win(null)

func process_stage_events() -> void:
	if stage_events.is_empty():
		return
	for i in range(stage_events.size()):
		var event: Dictionary = stage_events[i]
		if bool(event.get("once", true)) and bool(event.get("triggered", false)):
			continue
		if !is_stage_event_condition_met(event):
			continue
		event["triggered"] = true
		stage_events[i] = event
		trigger_stage_event(event)

func is_stage_event_condition_met(event: Dictionary) -> bool:
	var condition: String = str(event.get("condition", ""))
	if condition == "time":
		return battle_time >= float(event.get("time", 0.0))
	if condition == "player_enter_area":
		return is_entity_in_area(player_entity, str(event.get("area", "")))
	if condition == "kill_count":
		return enemy_kill_count >= int(event.get("target_count", 0))
	if condition == "win":
		return battle_won
	if condition == "loss":
		return battle_lost
	if condition == "player_hp_below" and player_entity != null and is_instance_valid(player_entity) and player_entity.max_hp > 0.0:
		return player_entity.hp / player_entity.max_hp <= float(event.get("amount", 0.35))
	if condition == "base_hp_below" and tentacle_base != null and is_instance_valid(tentacle_base) and tentacle_base.max_hp > 0.0:
		return tentacle_base.hp / tentacle_base.max_hp <= float(event.get("amount", 0.35))
	if condition == "enemy_base_hp_below" and enemy_base != null and is_instance_valid(enemy_base) and enemy_base.max_hp > 0.0:
		return enemy_base.hp / enemy_base.max_hp <= float(event.get("amount", 0.35))
	return false

func trigger_stage_event(event: Dictionary) -> void:
	var actions: Array = parse_string_list(str(event.get("action", "play_avg")))
	if actions.is_empty():
		actions.append("play_avg")
	for action in actions:
		apply_stage_event_action(str(action), event)

func apply_stage_event_action(action: String, event: Dictionary) -> void:
	if action == "play_avg":
		play_stage_event_avg(event)
	elif action == "spawn_entity":
		spawn_stage_event_entities(event)
	elif action == "add_base_bio":
		add_bio_to_tentacle_base(int(round(float(event.get("amount", 0.0)))))
	elif action == "heal_player":
		if player_entity != null and is_instance_valid(player_entity):
			player_entity.heal(float(event.get("amount", 0.0)), player_entity, true)
	elif action == "heal_base":
		if tentacle_base != null and is_instance_valid(tentacle_base):
			tentacle_base.heal(float(event.get("amount", 0.0)), tentacle_base, true)
	elif action == "damage_enemy_base":
		damage_enemy_base_from_spawn(float(event.get("amount", 0.0)), tentacle_base)
	elif action == "win":
		record_battle_win(null)
	elif action == "loss":
		record_battle_loss(str(event.get("reason", "stage_event")))
	elif action == "area_fx":
		spawn_stage_area_fx(str(event.get("area", "")))
	elif action == "change_scene":
		change_scene_from_stage_event(event)

func play_stage_event_avg(event: Dictionary) -> void:
	var avg_id: String = str(event.get("avg_id", "")).strip_edges()
	if avg_id != "":
		play_battle_avg(avg_id)

func spawn_stage_event_entities(event: Dictionary) -> void:
	var entity_id: String = str(event.get("entity_id", "")).strip_edges()
	if entity_id == "":
		return
	var count: int = max(1, int(event.get("count", 1)))
	var spawn_rule: String = str(event.get("spawn", ""))
	if spawn_rule == "":
		spawn_rule = str(event.get("area", ""))
		if spawn_rule != "":
			spawn_rule = "area:" + spawn_rule
	for i in range(count):
		var pos: Vector2 = get_spawn_position(spawn_rule, event)
		spawn_entity(entity_id, pos, event)

func play_battle_avg(avg_id: String) -> void:
	var manager := get_node_or_null("/root/AVGManager")
	if manager == null:
		manager = get_node_or_null("/root/avg_manager")
	if manager != null and manager.has_method("play"):
		manager.play(avg_id)

func change_scene_from_stage_event(event: Dictionary) -> void:
	var scene_path: String = str(event.get("scene_path", "")).strip_edges()
	if scene_path == "":
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)

func is_player_defeated() -> bool:
	return player_entity == null or !is_instance_valid(player_entity) or player_entity.is_dead

func is_base_defeated() -> bool:
	return tentacle_base == null or !is_instance_valid(tentacle_base) or tentacle_base.is_dead

func is_any_matching_entity_in_area(entity_id: String, faction: String, area_id: String) -> bool:
	for entity in entities:
		if entity == null or !is_instance_valid(entity) or entity.is_dead:
			continue
		if entity_id != "" and entity.entity_id != entity_id:
			continue
		if faction != "" and entity.faction != faction:
			continue
		if is_entity_in_area(entity, area_id):
			return true
	return false

func is_entity_in_area(entity, area_id: String) -> bool:
	if entity == null or !is_instance_valid(entity):
		return false
	if !stage_areas.has(area_id):
		return false
	return is_position_in_stage_area(entity.global_position, stage_areas[area_id])

func is_position_in_stage_area(pos: Vector2, area: Dictionary) -> bool:
	var center: Vector2 = area.get("center", Vector2.ZERO)
	var shape: String = str(area.get("shape", "circle"))
	if shape == "rect":
		var size: Vector2 = area.get("size", Vector2(160.0, 160.0))
		var half_size: Vector2 = size * 0.5
		return pos.x >= center.x - half_size.x and pos.x <= center.x + half_size.x and pos.y >= center.y - half_size.y and pos.y <= center.y + half_size.y
	var radius: float = float(area.get("radius", 120.0))
	return pos.distance_to(center) <= radius

func spawn_stage_area_fx(area_id: String) -> void:
	if !stage_areas.has(area_id):
		return
	var area: Dictionary = stage_areas[area_id]
	var center: Vector2 = area.get("center", Vector2.ZERO)
	if stage_area_visuals.has(area_id):
		var visual = stage_area_visuals[area_id]
		if visual != null and is_instance_valid(visual):
			visual.default_color = Color(0.92, 0.48, 1.0, 0.82)
			visual.width = 5.0
	spawn_ring_fx(center, float(area.get("radius", 120.0)), Color(0.66, 0.88, 1.0, 0.72), 7.0, 0.8)
	spawn_floating_number(center + Vector2(0.0, -56.0), "区域激活", Color(0.66, 0.88, 1.0, 1.0))

func spawn_entity(entity_id: String, pos: Vector2, overrides: Dictionary = {}):
	var data: Dictionary = load_entity_data(entity_id)
	if data.is_empty():
		return null

	apply_entity_overrides(data, overrides)
	apply_equipment_to_entity_data(data)
	var swarm_key: String = prepare_swarm_ai_role(entity_id, data, overrides)

	var entity: Node2D = Node2D.new()
	entity.name = "BattleEntity" + entity_id
	entity.set_script(ENTITY_SCRIPT)
	entities_root.add_child(entity)
	entity.global_position = pos
	entity.setup(self, data)
	apply_outgame_upgrades_to_spawned_entity(entity)
	entity.set_meta("spawn_time", battle_time)
	entity.set_meta("spawn_section", str(overrides.get("section", overrides.get("wave_id", ""))))
	register_swarm_spawned_entity(entity, swarm_key)
	apply_equipment_to_spawned_entity(entity)
	entities.append(entity)
	reserve_spawn_position(pos, entity.radius)
	return entity

func prepare_swarm_ai_role(entity_id: String, data: Dictionary, overrides: Dictionary) -> String:
	var ai: Dictionary = data.get("ai", {})
	if !is_swarm_ai_eligible(data, overrides):
		data["ai"] = ai
		return ""

	# Explicit role in JSON/INI wins. Use this for bosses, elites, scripted units, etc.
	if ai.has("role") or ai.has("ai_role") or overrides.has("ai_role") or overrides.has("role"):
		var explicit_role: String = str(overrides.get("ai_role", overrides.get("role", ai.get("role", ai.get("ai_role", "leader")))))
		ai["role"] = explicit_role
		var explicit_group: int = int(overrides.get("ai_group_id", overrides.get("group_id", ai.get("group_id", -1))))
		if explicit_group < 0:
			explicit_group = allocate_swarm_group_id()
		ai["group_id"] = explicit_group
		data["ai"] = ai
		return str(overrides.get("section", overrides.get("swarm_group_key", ai.get("group_key", "explicit_" + str(explicit_group)))))

	var swarm_key: String = get_swarm_group_key(entity_id, data, overrides)
	var group_size: int = max(2, int(overrides.get("swarm_group_size", ai.get("swarm_group_size", swarm_default_group_size))))
	var state: Dictionary = swarm_group_states.get(swarm_key, {"count": 0, "group_id": 0})
	var count: int = int(state.get("count", 0))
	var group_id: int = int(state.get("group_id", 0))
	var role := "follower"
	if group_id <= 0 or count % group_size == 0:
		group_id = allocate_swarm_group_id()
		role = "leader"

	state["count"] = count + 1
	state["group_id"] = group_id
	swarm_group_states[swarm_key] = state

	ai["role"] = role
	ai["group_id"] = group_id
	ai["group_key"] = swarm_key
	# Leaders keep existing intervals. Followers are intentionally lazier; they inherit
	# the leader's intent and only do near-range target pickup.
	if role == "follower":
		ai["follower_recheck_interval"] = float(ai.get("follower_recheck_interval", randf_range(0.40, 0.75)))
		ai["follower_attack_scan_interval"] = float(ai.get("follower_attack_scan_interval", randf_range(0.32, 0.62)))
		ai["follower_precision_interval"] = float(ai.get("follower_precision_interval", randf_range(0.22, 0.42)))
		ai["follower_precision_radius"] = float(ai.get("follower_precision_radius", 260.0))
		ai["steer_interval"] = max(float(ai.get("steer_interval", 0.22)), 0.28)
	data["ai"] = ai
	return swarm_key

func is_swarm_ai_eligible(data: Dictionary, overrides: Dictionary) -> bool:
	if bool(overrides.get("swarm_flow", true)) == false:
		return false
	var entity_type: String = str(data.get("type", "unit"))
	var tags: Array = data.get("tags", [])
	if entity_type == "player" or entity_type == "base" or tags.has("building") or tags.has("base") or tags.has("worker"):
		return false
	var stats: Dictionary = data.get("stats", {})
	if float(stats.get("move_speed", 0.0)) <= 0.0:
		return false
	var ai: Dictionary = data.get("ai", {})
	var mode: String = str(ai.get("mode", overrides.get("ai_mode", "")))
	if mode == "":
		mode = str(overrides.get("ai_mode", ""))
	return mode == "chase_nearest" or mode == "attack_building_first"

func get_swarm_group_key(entity_id: String, data: Dictionary, overrides: Dictionary) -> String:
	if overrides.has("swarm_group_key"):
		return str(overrides["swarm_group_key"])
	if overrides.has("section"):
		return str(overrides["section"])
	return str(data.get("faction", "neutral")) + "_" + entity_id

func allocate_swarm_group_id() -> int:
	var id := swarm_next_group_id
	swarm_next_group_id += 1
	return id

func register_swarm_spawned_entity(entity, swarm_key: String = "") -> void:
	if entity == null or !is_instance_valid(entity):
		return
	if !entity.has_method("promote_to_swarm_leader"):
		return
	var group_id: int = int(entity.ai_group_id)
	if group_id < 0:
		return
	if entity.ai_role == "leader":
		register_swarm_leader(entity)
	elif entity.ai_role == "follower":
		entity.ai_leader = find_swarm_leader_for(entity)

func register_swarm_leader(entity) -> void:
	if entity == null or !is_instance_valid(entity):
		return
	var group_id: int = int(entity.ai_group_id)
	if group_id < 0:
		return
	swarm_group_leaders[group_id] = entity

func find_swarm_leader_for(entity):
	if entity == null or !is_instance_valid(entity):
		return null
	var group_id: int = int(entity.ai_group_id)
	if group_id < 0:
		return null
	var leader = swarm_group_leaders.get(group_id, null)
	if leader != null and is_instance_valid(leader) and !leader.is_dead:
		return leader

	# Repair stale references lazily. This only scans the current entity list when a
	# follower actually loses its leader, not every frame for every follower.
	for candidate in entities:
		if candidate == null or !is_instance_valid(candidate):
			continue
		if candidate.is_dead:
			continue
		if int(candidate.ai_group_id) == group_id and candidate.ai_role == "leader":
			swarm_group_leaders[group_id] = candidate
			return candidate
	return null

func process_swarm_flow_cache(_delta: float) -> void:
	# Precompute one flow direction per swarm group. Followers read this cached value
	# instead of touching leader target/steering state and recomputing intent separately.
	var group_ids: Array = swarm_group_leaders.keys()
	if group_ids.is_empty():
		return

	var budget: int = min(swarm_flow_cache_budget, group_ids.size())
	for i in range(budget):
		if swarm_flow_cursor >= group_ids.size():
			swarm_flow_cursor = 0
		var group_id = group_ids[swarm_flow_cursor]
		swarm_flow_cursor += 1
		var leader = swarm_group_leaders.get(group_id, null)
		if leader == null or !is_instance_valid(leader) or leader.is_dead:
			swarm_group_flow_cache.erase(int(group_id))
			continue
		update_swarm_flow_cache_for_leader(leader)

func update_swarm_flow_cache_for_leader(leader) -> void:
	if leader == null or !is_instance_valid(leader):
		return
	var group_id: int = int(leader.ai_group_id)
	if group_id < 0:
		return

	var flow_dir: Vector2 = leader.cached_ai_move_dir
	if flow_dir.length() <= 0.01 and leader.target != null and is_instance_valid(leader.target) and !leader.target.is_dead:
		flow_dir = (leader.target.global_position - leader.global_position).normalized()
	if flow_dir.length() <= 0.01:
		flow_dir = Vector2.RIGHT if leader.facing_right else Vector2.LEFT

	var target_pos: Vector2 = leader.global_position + flow_dir.normalized() * 240.0
	if leader.target != null and is_instance_valid(leader.target) and !leader.target.is_dead:
		target_pos = leader.target.global_position

	swarm_group_flow_cache[group_id] = {
		"dir": flow_dir.normalized(),
		"target_pos": target_pos,
		"leader_pos": leader.global_position,
		"time": battle_time
	}

func get_swarm_flow_dir_for(entity) -> Vector2:
	if entity == null or !is_instance_valid(entity):
		return Vector2.ZERO
	var group_id: int = int(entity.ai_group_id)
	if group_id < 0:
		return Vector2.ZERO
	var cached = swarm_group_flow_cache.get(group_id, null)
	if typeof(cached) == TYPE_DICTIONARY:
		var dir: Vector2 = cached.get("dir", Vector2.ZERO)
		if dir.length() > 0.01:
			return dir.normalized()
	return Vector2.ZERO

func is_entity_precise_combat_active(entity) -> bool:
	if entity == null or !is_instance_valid(entity):
		return false
	if !entity.has_method("promote_to_swarm_leader"):
		return true
	if str(entity.ai_role) != "follower":
		return true
	return bool(entity.follower_precision_active)

func apply_entity_overrides(data: Dictionary, overrides: Dictionary) -> void:
	if overrides.is_empty():
		return

	var ai: Dictionary = data.get("ai", {})
	var stats: Dictionary = data.get("stats", {})

	var faction_override: String = str(overrides.get("faction", ""))
	if faction_override != "":
		data["faction"] = faction_override

	var ai_mode: String = str(overrides.get("ai_mode", ""))
	if ai_mode != "":
		ai["mode"] = ai_mode

	var movement_mode: String = str(overrides.get("movement_mode", ""))
	if movement_mode != "":
		ai["movement_mode"] = movement_mode

	var target_priority: String = str(overrides.get("target_priority", ""))
	if target_priority != "":
		ai["target_priority"] = target_priority

	var target_priority_order_text: String = str(overrides.get("target_priority_order", ""))
	if target_priority_order_text != "":
		ai["target_priority_order"] = parse_string_list(target_priority_order_text)

	var target_distance_mode: String = str(overrides.get("target_distance_mode", ""))
	if target_distance_mode != "":
		ai["target_distance_mode"] = target_distance_mode

	if overrides.has("objective_fallback"):
		ai["objective_fallback"] = bool(overrides["objective_fallback"])

	if overrides.has("objective_fallback_radius"):
		ai["objective_fallback_radius"] = float(overrides["objective_fallback_radius"])

	var objective_fallback_priority_text: String = str(overrides.get("objective_fallback_priority_order", ""))
	if objective_fallback_priority_text != "":
		ai["objective_fallback_priority_order"] = parse_string_list(objective_fallback_priority_text)

	if overrides.has("leash_radius"):
		ai["leash_radius"] = float(overrides["leash_radius"])

	var target_factions_text: String = str(overrides.get("target_factions", ""))
	if target_factions_text != "":
		ai["target_factions"] = parse_string_list(target_factions_text)

	var ai_role_text: String = str(overrides.get("ai_role", overrides.get("role", "")))
	if ai_role_text != "":
		ai["role"] = ai_role_text
	if overrides.has("ai_group_id"):
		ai["group_id"] = int(overrides["ai_group_id"])
	elif overrides.has("group_id"):
		ai["group_id"] = int(overrides["group_id"])
	if overrides.has("swarm_group_size"):
		ai["swarm_group_size"] = int(overrides["swarm_group_size"])

	for stat_key in ["max_hp", "move_speed", "attack", "defense", "hp_regen"]:
		if overrides.has(stat_key):
			stats[stat_key] = float(overrides[stat_key])

	var stat_mul_keys: Dictionary = {
		"max_hp_mul": "max_hp",
		"move_speed_mul": "move_speed",
		"attack_mul": "attack",
		"defense_mul": "defense"
	}
	for mul_key in stat_mul_keys.keys():
		if overrides.has(mul_key):
			var target_key: String = str(stat_mul_keys[mul_key])
			stats[target_key] = float(stats.get(target_key, 0.0)) * float(overrides[mul_key])

	var reward: Dictionary = data.get("reward", {})
	if overrides.has("xp_mul"):
		var default_xp: float = 5.0 if str(data.get("type", "")) == "base" or data.get("tags", []).has("building") else 1.0
		var base_xp: float = float(reward.get("xp", default_xp))
		var xp_mul: float = float(overrides["xp_mul"])
		var scaled_xp: int = int(round(base_xp * xp_mul))
		reward["xp"] = max(1 if base_xp > 0.0 and xp_mul > 0.0 else 0, scaled_xp)
	if overrides.has("bio_mul"):
		reward["bio"] = max(0, int(round(float(reward.get("bio", 0)) * float(overrides["bio_mul"]))))
	if !reward.is_empty():
		data["reward"] = reward

	data["ai"] = ai
	data["stats"] = stats

func run_attack(attacker, target, attack: Dictionary) -> void:
	attack_runner.run_attack(self, attacker, target, attack)

func spawn_projectile(projectile_owner, target, attack: Dictionary, start_pos: Vector2, target_pos: Vector2) -> void:
	var projectile: Node2D = Node2D.new()
	projectile.name = "BattleProjectile"
	projectile.set_script(PROJECTILE_SCRIPT)
	projectiles_root.add_child(projectile)
	projectile.global_position = start_pos
	projectile.setup(self, projectile_owner, target, attack, target_pos)
	projectiles.append(projectile)

func spawn_attack(source, attack: Dictionary, context: Dictionary = {}) -> void:
	if attack.is_empty():
		return
	if source == player_entity:
		emit_equipment_event("on_attack_fired", {"attack_id": str(attack.get("id", ""))})

	var emitter: Dictionary = attack.get("emitter", {})
	var mode: String = str(emitter.get("mode", "single"))
	var count: int = max(1, int(emitter.get("count", 1)))

	if mode == "ring":
		for i in range(count):
			var ctx: Dictionary = context.duplicate(true)
			ctx["direction"] = Vector2.RIGHT.rotated(float(i) / float(count) * TAU)
			spawn_attack_instance(source, attack, ctx)
		return

	if mode == "spread":
		var spread_angle: float = deg_to_rad(float(emitter.get("spread_angle", 45.0)))
		var base_dir: Vector2 = get_attack_base_direction(source, attack, context)
		for i in range(count):
			var ratio: float = 0.5
			if count > 1:
				ratio = float(i) / float(count - 1)
			var angle: float = lerp(-spread_angle * 0.5, spread_angle * 0.5, ratio)
			var ctx: Dictionary = context.duplicate(true)
			ctx["direction"] = base_dir.rotated(angle).normalized()
			spawn_attack_instance(source, attack, ctx)
		return

	if mode == "random_scatter":
		for i in range(count):
			var ctx: Dictionary = context.duplicate(true)
			ctx["direction"] = Vector2.RIGHT.rotated(randf() * TAU)
			spawn_attack_instance(source, attack, ctx)
		return

	for i in range(count):
		spawn_attack_instance(source, attack, context)

func spawn_attack_instance(source, attack: Dictionary, context: Dictionary = {}) -> void:
	var instance: Node2D = Node2D.new()
	instance.name = "BattleAttackInstance"
	instance.set_script(ATTACK_INSTANCE_SCRIPT)
	projectiles_root.add_child(instance)
	instance.setup(self, source, attack, context)
	attack_instances.append(instance)

func spawn_mutation_head_bullets(source_base) -> void:
	if source_base == null or !is_instance_valid(source_base):
		return
	var attack: Dictionary = load_attack_data("mutation_head_bullets")
	if attack.is_empty():
		return
	var dir := Vector2.RIGHT
	if enemy_base != null and is_instance_valid(enemy_base):
		dir = (enemy_base.global_position - source_base.global_position).normalized()
	spawn_attack(source_base, attack, {"direction": dir})
	spawn_floating_number(source_base.global_position + Vector2(0.0, -source_base.radius - 62.0), "突变头弹", Color(0.95, 0.62, 1.0, 1.0))

func get_attack_base_direction(source, attack: Dictionary, context: Dictionary = {}) -> Vector2:
	if context.has("direction"):
		var context_dir: Vector2 = context["direction"]
		if context_dir.length() > 0.01:
			return context_dir.normalized()

	var aim: Dictionary = attack.get("aim", {})
	var mode: String = str(aim.get("mode", "target"))
	var origin: Vector2 = Vector2.ZERO
	if source != null and is_instance_valid(source):
		origin = source.global_position

	if mode == "player" and player_entity != null and is_instance_valid(player_entity):
		return (player_entity.global_position - origin).normalized()

	if mode == "fixed_angle":
		return Vector2.RIGHT.rotated(deg_to_rad(float(aim.get("angle", 0.0))))

	if mode == "mouse" and source != null and is_instance_valid(source):
		var mouse_dir: Vector2 = source.get_global_mouse_position() - origin
		if mouse_dir.length() > 0.01:
			return mouse_dir.normalized()

	if mode == "facing" and source != null and is_instance_valid(source):
		if source.has_method("get_facing_direction"):
			return source.get_facing_direction()
		return Vector2.RIGHT if bool(source.get("facing_right")) else Vector2.LEFT

	if mode == "nearest_enemy" and source != null and is_instance_valid(source):
		var found = find_target_for(source, source.target_factions, source.sense_radius)
		if found != null and is_instance_valid(found):
			return (found.global_position - origin).normalized()

	var trigger_target = context.get("trigger_target", null)
	if trigger_target != null and is_instance_valid(trigger_target):
		return (trigger_target.global_position - origin).normalized()

	return Vector2.RIGHT

func load_attack_data(attack_id: String) -> Dictionary:
	if attack_id == "":
		return {}

	var path: String = "res://BattleAssets/Attack_" + attack_id + ".json"
	if !FileAccess.file_exists(path):
		push_error("Missing attack json: " + path)
		return {}

	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid attack json: " + path)
		return {}

	return normalize_attack_data(attack_id, parsed)

func normalize_attack_data(attack_id: String, raw_data: Dictionary) -> Dictionary:
	var data: Dictionary = raw_data.duplicate(true)
	var key: String = (attack_id + " " + str(data.get("id", "")) + " " + str(data.get("name", ""))).to_lower()
	if !data.has("id") or str(data.get("id", "")) == "":
		data["id"] = attack_id

	# Do not overwrite explicit art, but fill missing placeholder visuals from the known BattleAssets.
	var visual: Dictionary = data.get("visual", {})
	var has_asset: bool = visual.has("texture") or visual.has("gif")
	var asset_path: String = ""
	var visual_size: Array = []
	var visual_anchor: String = str(visual.get("anchor", "center"))

	if key.contains("strong") and key.contains("melee"):
		asset_path = "res://BattleAssets/StrongMelee.png"
		visual_size = [190, 90]
		visual_anchor = "left_center"
	elif (key.contains("mid") or key.contains("normal")) and key.contains("melee"):
		asset_path = "res://BattleAssets/NormalMelle.png"
		visual_size = [158, 76]
		visual_anchor = "left_center"
	elif key.contains("weak") and key.contains("melee"):
		asset_path = "res://BattleAssets/WeakMelle.png"
		visual_size = [130, 62]
		visual_anchor = "left_center"
	elif key.contains("tracer"):
		asset_path = "res://BattleAssets/TracerBullet.png"
		visual_size = [56, 20]
	elif key.contains("sniper"):
		asset_path = "res://BattleAssets/Sniper.png"
		visual_size = [92, 22]
	elif key.contains("boomerang"):
		asset_path = "res://BattleAssets/Boomerang.png"
		visual_size = [78, 78]
	elif key.contains("shotgun"):
		asset_path = "res://BattleAssets/Shotgun.png"
		visual_size = [42, 16]
	elif key.contains("beam") or key.contains("laser"):
		asset_path = "res://BattleAssets/Beam.png"
		visual_anchor = "left_center"
	elif key.contains("poison"):
		asset_path = "res://BattleAssets/Poison.png"
	elif key.contains("thunder") or key.contains("落雷"):
		asset_path = "res://BattleAssets/Thunder.png"
		visual_size = [130, 260]
	elif key.contains("spike"):
		asset_path = "res://BattleAssets/Spike.png"
	elif key.contains("charm"):
		asset_path = "res://BattleAssets/Charm.png"
		visual_size = [58, 58]
	elif key.contains("lighting") or key.contains("lightning") or key.contains("chain"):
		asset_path = "res://BattleAssets/Lighting.png"
		visual_size = [180, 34]
		visual_anchor = "left_center"
	elif key.contains("curve"):
		asset_path = "res://BattleAssets/CurveBullet.png"
		visual_size = [54, 22]
	elif key.contains("flame") or key.contains("fire") or key.contains("喷"):
		asset_path = "res://BattleAssets/Flame.png"
		visual_size = [300, 104]
		visual_anchor = "left_center"
		var flame_shape: Dictionary = data.get("hit_shape", {})
		flame_shape["mode"] = "beam_rect"
		flame_shape["length"] = max(float(flame_shape.get("length", 0.0)), 300.0)
		flame_shape["width"] = max(float(flame_shape.get("width", 0.0)), 104.0)
		data["hit_shape"] = flame_shape
		var flame_origin: Dictionary = data.get("origin", {})
		if !flame_origin.has("point"):
			flame_origin["point"] = "right"
		data["origin"] = flame_origin
	elif key.contains("rpg") or key.contains("rocket"):
		asset_path = "res://BattleAssets/RPG.png"
		visual_size = [74, 28]
	elif key.contains("strong") and key.contains("strafe"):
		asset_path = "res://BattleAssets/StrongStrafe.png"
		visual_size = [360, 190]
	elif key.contains("weak") and key.contains("strafe"):
		asset_path = "res://BattleAssets/WeakStrafe.png"
		visual_size = [300, 168]
	elif key.contains("strafe") or key.contains("bombing") or key.contains("轰"):
		asset_path = "res://BattleAssets/GeneralBombing.gif"
		visual_size = [320, 180]
	elif key.contains("bullet"):
		asset_path = "res://BattleAssets/Bullet.png"
		visual_size = [46, 16]

	if asset_path != "":
		if !has_asset:
			if asset_path.get_extension().to_lower() == "gif":
				visual["gif"] = asset_path
			else:
				visual["texture"] = asset_path
		if !visual_size.is_empty() and !visual.has("size"):
			visual["size"] = visual_size
		if visual_anchor != "center" and !visual.has("anchor"):
			visual["anchor"] = visual_anchor
		data["visual"] = visual

	if key.contains("strafe") or key.contains("bombing") or key.contains("轰"):
		var strafe_visual: Dictionary = data.get("visual", {})
		strafe_visual["indicator_texture"] = "res://BattleAssets/StrafeBox.png"
		strafe_visual["indicator_alpha"] = 0.72
		if !strafe_visual.has("size"):
			strafe_visual["size"] = [340, 180]
		data["visual"] = strafe_visual
		var shape: Dictionary = data.get("hit_shape", {})
		shape["mode"] = "rect"
		shape["length"] = max(float(shape.get("length", 0.0)), float(strafe_visual.get("size", [340, 180])[0]))
		shape["width"] = max(float(shape.get("width", 0.0)), float(strafe_visual.get("size", [340, 180])[1]))
		data["hit_shape"] = shape
		var origin: Dictionary = data.get("origin", {})
		origin["mode"] = "aim_offset"
		origin["distance"] = float(origin.get("distance", 360.0))
		data["origin"] = origin
		var aim: Dictionary = data.get("aim", {})
		aim["mode"] = "mouse"
		data["aim"] = aim
		data["duration"] = max(float(data.get("duration", data.get("life_time", 0.55))), 0.55)

	# Baseline player projectiles should reach beyond the visible play area, not die just inside the camera.
	if key.contains("bullet") or key.contains("sniper") or key.contains("tracer") or key.contains("charm") or key.contains("curve"):
		var motion: Dictionary = data.get("motion", {})
		motion["max_distance"] = max(float(motion.get("max_distance", data.get("range", 0.0))), 1250.0)
		if motion.has("speed"):
			motion["speed"] = max(float(motion.get("speed", 0.0)), 720.0)
		data["motion"] = motion

	return data

func spawn_textured_line_fx(start_pos: Vector2, end_pos: Vector2, texture_path: String = "res://BattleAssets/Lighting.png", width: float = 42.0, lifetime: float = 0.16, color: Color = Color(1.0, 1.0, 1.0, 0.92)) -> void:
	var tex = load(texture_path)
	if tex == null:
		spawn_line_fx(start_pos, end_pos, color, width * 0.35, lifetime)
		return
	var delta: Vector2 = end_pos - start_pos
	var dist: float = delta.length()
	if dist <= 1.0:
		return
	var sprite := Sprite2D.new()
	sprite.name = "TexturedLineFx"
	sprite.texture = tex
	sprite.centered = true
	sprite.global_position = start_pos.lerp(end_pos, 0.5)
	sprite.rotation = delta.angle()
	sprite.modulate = color
	sprite.z_index = 95
	var tex_size: Vector2 = tex.get_size()
	sprite.scale = Vector2(dist / max(tex_size.x, 1.0), width / max(tex_size.y, 1.0))
	effects_root.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, lifetime)
	tween.tween_callback(sprite.queue_free)

func spawn_bio_drop(pos: Vector2, value: int) -> void:
	if value <= 0:
		return

	var drop: Node2D = Node2D.new()
	drop.name = "BattleBioDrop"
	drop.set_script(BIO_DROP_SCRIPT)
	effects_root.add_child(drop)
	drop.setup(self, pos, value, bio_texture_path)
	drops.append(drop)

func find_bio_collector_for(pos: Vector2, magnet_radius: float):
	var best = null
	var best_dist: float = magnet_radius
	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead:
			continue
		if entity.entity_type != "player" and entity.entity_type != "worker" and !entity.tags.has("worker"):
			continue
		if entity.bio_cargo >= entity.bio_cargo_max:
			continue
		var dist: float = pos.distance_to(entity.global_position)
		if dist < best_dist:
			best_dist = dist
			best = entity
	return best

func find_nearest_bio_drop(pos: Vector2, max_radius: float):
	var best = null
	var best_dist: float = max_radius
	for drop in drops:
		if drop == null or !is_instance_valid(drop):
			continue
		var dist: float = pos.distance_to(drop.global_position)
		if dist < best_dist:
			best_dist = dist
			best = drop
	return best

func find_nearest_available_bio_drop(pos: Vector2, max_radius: float, collector = null):
	var best = null
	var best_dist: float = max_radius
	for drop in drops:
		if drop == null or !is_instance_valid(drop):
			continue
		if drop.target != null and is_instance_valid(drop.target) and drop.target != collector:
			continue
		var dist: float = pos.distance_to(drop.global_position)
		if dist < best_dist:
			best_dist = dist
			best = drop
	return best

func add_bio_to_tentacle_base(amount: int) -> void:
	if amount <= 0:
		return
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return
	tentacle_base.receive_bio(amount)

func on_bio_delivered_to_base(target_base, amount: int) -> void:
	if target_base != tentacle_base:
		return
	if amount <= 0:
		return
	emit_equipment_event("on_bio_delivered", {"amount": amount})
	if base_mana_return_per_bio <= 0.0:
		return
	var recovered: float = float(amount) * base_mana_return_per_bio * run_mana_recovery_mul
	run_mana_recovered += recovered
	if player_entity != null and is_instance_valid(player_entity):
		player_mana = min(player_mana_max, player_mana + recovered)
		spawn_floating_number(player_entity.global_position + Vector2(0.0, -player_entity.radius - 58.0), "Mana +" + str(int(round(recovered))), Color(0.46, 0.82, 1.0, 1.0))

func process_equipment_timers(delta: float) -> void:
	if !active_equipment_effects.has("minute_lust_add"):
		pass
	else:
		equipment_minute_timer += delta
		while equipment_minute_timer >= 60.0:
			equipment_minute_timer -= 60.0
			run_lust_reward_add += 20.0
			emit_equipment_event("on_minute_tick", {"lust_add": 20.0})

	if active_equipment_effects.has("liquid_madness"):
		shooter_timer += delta
		while shooter_timer >= 5.0:
			shooter_timer -= 5.0
			trigger_liquid_madness()

func emit_equipment_event(event_name: String, payload: Dictionary = {}) -> void:
	if active_equipment_effects.is_empty():
		return
	equipment_event_counts[event_name] = int(equipment_event_counts.get(event_name, 0)) + 1
	equipment_last_event_payloads[event_name] = payload.duplicate(true)

func process_equipment_events(delta: float) -> void:
	if player_entity == null or !is_instance_valid(player_entity):
		return

	var current_pos: Vector2 = player_entity.global_position
	if equipment_last_player_pos == Vector2.ZERO:
		equipment_last_player_pos = current_pos

	var moved: float = current_pos.distance_to(equipment_last_player_pos)
	var is_moving: bool = moved > max(1.2, player_entity.move_speed * delta * 0.12)
	if is_moving:
		equipment_stop_timer = 0.0
		emit_equipment_event("on_player_moved", {"distance": moved})
		process_equipment_movement_distance(moved)
	else:
		equipment_stop_timer += delta
		if equipment_was_moving and equipment_stop_timer >= 0.12:
			emit_equipment_event("on_player_stopped", {})
			process_equipment_player_stopped()

	if active_equipment_effects.has("forced_forward_move"):
		process_forced_forward_move(delta, is_moving)

	equipment_was_moving = is_moving
	equipment_last_player_pos = player_entity.global_position

func process_equipment_movement_distance(distance: float) -> void:
	if !active_equipment_effects.has("whip_charge"):
		return
	equipment_move_distance += distance
	while equipment_move_distance >= whip_distance_per_layer and whip_charge_layers < whip_max_layers:
		equipment_move_distance -= whip_distance_per_layer
		whip_charge_layers += 1
		spawn_floating_number(player_entity.global_position + Vector2(0.0, -player_entity.radius - 58.0), "鞭蓄力 " + str(whip_charge_layers), Color(1.0, 0.55, 0.86, 1.0))
	if whip_charge_layers >= whip_max_layers:
		equipment_move_distance = min(equipment_move_distance, whip_distance_per_layer)

func process_equipment_player_stopped() -> void:
	if active_equipment_effects.has("whip_charge") and whip_charge_layers > 0:
		release_whip_charge()

func process_forced_forward_move(delta: float, is_moving: bool) -> void:
	var input: Vector2 = Vector2.ZERO
	input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if input.length() > 0.05:
		plug_forced_direction = input.normalized()
		return
	if plug_forced_direction.length() <= 0.01:
		plug_forced_direction = Vector2.RIGHT
	if !is_moving:
		player_entity.update_facing(plug_forced_direction)
		move_entity(player_entity, plug_forced_direction * player_entity.move_speed * delta)

func release_whip_charge() -> void:
	var attack: Dictionary = load_attack_data("equipment_whip_slash")
	if attack.is_empty():
		whip_charge_layers = 0
		return
	var layers: int = clamp(whip_charge_layers, 1, whip_max_layers)
	var dir: Vector2 = player_entity.get_global_mouse_position() - player_entity.global_position
	if dir.length() <= 0.01:
		dir = plug_forced_direction if plug_forced_direction.length() > 0.01 else Vector2.RIGHT
	var emitter: Dictionary = attack.get("emitter", {})
	emitter["count"] = layers
	emitter["spread_angle"] = 8.0 + float(layers - 1) * 12.0
	attack["emitter"] = emitter
	multiply_attack_damage(attack, 0.85 + float(layers) * 0.25)
	spawn_attack(player_entity, attack, {"direction": dir.normalized()})
	spawn_skill_cast_fx({"visual": {"color": "ff66b8", "radius": 96.0 + layers * 22.0}}, player_entity.global_position)
	emit_equipment_event("on_whip_released", {"layers": layers})
	whip_charge_layers = 0
	equipment_move_distance = 0.0

func trigger_liquid_madness() -> void:
	if player_entity == null or !is_instance_valid(player_entity) or player_entity.is_dead:
		return
	var self_damage: float = max(1.0, player_entity.hp * 0.10)
	player_entity.take_damage(self_damage, player_entity)
	var attack: Dictionary = load_attack_data("equipment_liquid_arc")
	if attack.is_empty():
		return
	var dir: Vector2 = player_entity.get_global_mouse_position() - player_entity.global_position
	if dir.length() <= 0.01:
		dir = plug_forced_direction if plug_forced_direction.length() > 0.01 else Vector2.RIGHT
	spawn_attack(player_entity, attack, {"direction": dir.normalized()})
	spawn_floating_number(player_entity.global_position + Vector2(0.0, -player_entity.radius - 64.0), "射液狂", Color(0.62, 1.0, 0.78, 1.0))
	emit_equipment_event("on_liquid_madness", {"self_damage": self_damage})

func notify_attack_hit(source, target, dealt: float, context: Dictionary = {}) -> void:
	if source == player_entity:
		emit_equipment_event("on_attack_hit", {
			"target_id": target.entity_id if target != null and is_instance_valid(target) else "",
			"damage": dealt,
			"attack_id": str(context.get("attack", {}).get("id", ""))
		})

func spawn_bio_transfer(start_pos: Vector2, target_base, value: int) -> void:
	if value <= 0:
		return

	if target_base == null or !is_instance_valid(target_base):
		return

	var transfer: Node2D = Node2D.new()
	transfer.name = "BattleBioTransfer"
	transfer.set_script(BIO_TRANSFER_SCRIPT)
	effects_root.add_child(transfer)
	transfer.setup(self, start_pos, target_base, value, bio_texture_path)

func start_assimilation(target_entity, result_entity_id: String, duration: float = 1.0, source_entity = null) -> void:
	if target_entity == null or !is_instance_valid(target_entity):
		return
	var pos: Vector2 = target_entity.global_position
	var source_faction := "tentacle"
	if source_entity != null and is_instance_valid(source_entity):
		source_faction = source_entity.faction
	target_entity.queue_free()
	assimilation_jobs.append({
		"time_left": max(0.1, duration),
		"position": pos,
		"result_entity_id": result_entity_id,
		"faction": source_faction
	})
	spawn_assimilation_fx(pos, duration)
	spawn_floating_number(pos + Vector2(0.0, -38.0), "同化中", Color(1.0, 0.5, 0.95, 1.0))

func spawn_assimilation_fx(pos: Vector2, duration: float) -> void:
	var fx := Node2D.new()
	fx.name = "AssimilationFx"
	effects_root.add_child(fx)
	fx.global_position = pos
	fx.z_index = 35
	var gif_visual = GIFPlayer.new()
	fx.add_child(gif_visual)
	gif_visual.gif = load("res://BattleAssets/024_1.gif")
	gif_visual.size = Vector2(128.0, 150.0)
	gif_visual.position = -gif_visual.size * 0.5
	gif_visual.modulate = Color(1.0, 0.75, 1.0, 0.82)
	var timer := get_tree().create_timer(max(0.1, duration))
	timer.timeout.connect(func():
		if fx != null and is_instance_valid(fx):
			fx.queue_free()
	)

func process_assimilations(delta: float) -> void:
	for i in range(assimilation_jobs.size() - 1, -1, -1):
		var job: Dictionary = assimilation_jobs[i]
		job["time_left"] = float(job.get("time_left", 0.0)) - delta
		if float(job["time_left"]) > 0.0:
			assimilation_jobs[i] = job
			continue
		var pos: Vector2 = job.get("position", Vector2.ZERO)
		var result_id: String = str(job.get("result_entity_id", ""))
		if assimilation_lust_reward_add > 0.0:
			run_lust_reward_add += assimilation_lust_reward_add
			spawn_floating_number(pos + Vector2(0.0, -64.0), "淫能 +" + str(int(round(assimilation_lust_reward_add))), Color(1.0, 0.46, 0.86, 1.0))
		if result_id != "":
			var spawned = spawn_entity(result_id, pos, {"faction": str(job.get("faction", "tentacle"))})
			apply_assimilated_runtime_modifiers(spawned)
		assimilation_jobs.remove_at(i)

func process_assimilated_periodic_buffs(delta: float) -> void:
	if assimilated_invuln_interval <= 0.0 or assimilated_invuln_duration <= 0.0:
		return

	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead or !entity.tags.has("assimilated_girl"):
			continue
		var timer: float = float(entity.get_meta("assimilated_invuln_timer", assimilated_invuln_interval))
		timer -= delta
		if timer <= 0.0:
			timer = assimilated_invuln_interval
			entity.add_status_effect({
				"status": "invincible",
				"duration": assimilated_invuln_duration
			}, tentacle_base)
			spawn_ring_fx(entity.global_position, entity.radius + 34.0, Color(0.55, 0.92, 1.0, 0.72), 4.0, 0.45)
		entity.set_meta("assimilated_invuln_timer", timer)

func spawn_floating_number(pos: Vector2, text: String, color: Color) -> void:
	if floating_numbers_this_frame >= floating_number_cap_per_frame:
		return
	floating_numbers_this_frame += 1
	var number: Node2D = Node2D.new()
	number.name = "BattleFloatingNumber"
	number.set_script(FLOATING_NUMBER_SCRIPT)
	effects_root.add_child(number)
	number.setup(text, color, pos)

func spawn_line_fx(start_pos: Vector2, end_pos: Vector2, color: Color, width: float = 8.0, lifetime: float = 0.18) -> void:
	var fx: Node2D = Node2D.new()
	fx.name = "BattleLineFx"
	fx.set_script(LINE_FX_SCRIPT)
	effects_root.add_child(fx)
	fx.setup(start_pos, end_pos, color, width, lifetime)

func spawn_ring_fx(pos: Vector2, radius: float, color: Color, width: float = 6.0, lifetime: float = 0.6) -> void:
	var ring := Line2D.new()
	ring.name = "BattleRingFx"
	ring.global_position = pos
	ring.closed = true
	ring.width = width
	ring.default_color = color
	ring.z_index = 90
	var point_count: int = 96
	for i in range(point_count):
		var t: float = float(i) / float(point_count)
		ring.add_point(Vector2.RIGHT.rotated(t * TAU) * radius)
	effects_root.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.45, lifetime).from(Vector2.ONE * 0.62)
	var fade_color: Color = color
	fade_color.a = 0.0
	tween.tween_property(ring, "default_color", fade_color, lifetime)
	tween.tween_property(ring, "width", 1.0, lifetime)
	tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)

func parse_color(text: String, fallback: Color) -> Color:
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		return fallback
	if !clean_text.begins_with("#"):
		clean_text = "#" + clean_text
	var color: Color = Color.html(clean_text)
	if color == Color.BLACK and clean_text.to_lower() != "#000000":
		return fallback
	return color

func add_player_xp(amount: int) -> void:
	if amount <= 0:
		return

	if player_level >= player_level_cap:
		return

	player_xp += amount
	while player_level < player_level_cap and player_xp >= player_xp_cap:
		player_xp -= player_xp_cap
		player_level += 1
		player_xp_cap = get_xp_cap_for_level(player_level)
		show_level_choices()
		if level_choice_active:
			break

func get_xp_cap_for_level(level: int) -> int:
	var index: int = clamp(level - 1, 0, max(xp_curve.size() - 1, 0))
	if xp_curve.is_empty():
		return 999999
	return max(1, int(xp_curve[index]))

func show_level_choices() -> void:
	if level_choice_panel == null:
		return

	var choices: Array = pick_level_choices(3)
	if choices.is_empty():
		return

	level_choice_active = true
	style_level_choice_panel("player")
	level_choice_panel.visible = true
	get_tree().paused = true
	for child in level_choice_panel.get_children():
		level_choice_panel.remove_child(child)
		child.free()

	var box: VBoxContainer = VBoxContainer.new()
	box.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	level_choice_panel.add_child(box)

	var title: Label = Label.new()
	title.text = "升级  Lv" + str(player_level)
	title.add_theme_font_size_override("font_size", 24)
	title.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	box.add_child(title)

	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var button: Button = Button.new()
		button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		button.text = get_level_choice_label(choice)
		button.custom_minimum_size = Vector2(480, 48)
		button.pressed.connect(_on_level_choice_selected.bind(choice))
		box.add_child(button)

func pick_level_choices(count: int) -> Array:
	var pool: Array = []
	if should_force_new_weapon_choice():
		pool.append_array(build_new_weapon_choices())
	elif should_force_weapon_upgrade_choice():
		pool.append_array(build_weapon_upgrade_choices(true))
	else:
		pool.append_array(build_weapon_upgrade_choices(false))
		pool.append_array(build_new_weapon_choices())
		if player_level >= 12 or pool.size() < count:
			pool.append_array(build_run_stat_choices())

	if pool.is_empty() and player_level >= 12:
		pool.append_array(build_run_stat_choices())

	pool.shuffle()
	var result: Array = []
	for choice in pool:
		result.append(choice)
		if result.size() >= count:
			break
	return result

func _on_level_choice_selected(choice: Dictionary) -> void:
	if player_entity == null or !is_instance_valid(player_entity):
		return

	apply_level_choice(choice)

	level_choice_active = false
	level_choice_panel.visible = false

	if should_offer_catchup_level_choice():
		catchup_level_choices_given += 1
		show_level_choices()
		return

	get_tree().paused = false

func should_force_new_weapon_choice() -> bool:
	return player_level <= 11 and owned_weapon_ids.size() < 3

func should_force_weapon_upgrade_choice() -> bool:
	return player_level <= 11 and get_weapon_completion_actions_needed() > 0

func should_offer_catchup_level_choice() -> bool:
	if catchup_level_choices_given >= catchup_level_choices_max:
		return false
	if player_level > 11:
		return false

	var remaining_regular_choices: int = max(0, 11 - player_level)
	return get_weapon_completion_actions_needed() > remaining_regular_choices

func get_weapon_completion_actions_needed() -> int:
	var needed: int = max(0, 3 - owned_weapon_ids.size())
	for weapon_id in owned_weapon_ids:
		needed += max(0, 4 - int(weapon_levels.get(weapon_id, 1)))
	return needed

func build_weapon_upgrade_choices(lowest_only: bool = false) -> Array:
	var result: Array = []
	var lowest_level: int = 99
	if lowest_only:
		for weapon_id in owned_weapon_ids:
			lowest_level = min(lowest_level, int(weapon_levels.get(weapon_id, 1)))

	for row in weapon_upgrade_rows:
		var weapon_id: String = str(row.get("weapon_id", "")).strip_edges()
		if !owned_weapon_ids.has(weapon_id):
			continue
		var current_level: int = int(weapon_levels.get(weapon_id, 1))
		if lowest_only and current_level > lowest_level:
			continue
		var row_level: int = int(row.get("level", 0))
		if row_level != current_level + 1:
			continue
		result.append({"type": "weapon_upgrade", "row": row})
	return result

func build_new_weapon_choices() -> Array:
	var result: Array = []
	if owned_weapon_ids.size() >= 3:
		return result

	for weapon_id in weapon_catalog.keys():
		if owned_weapon_ids.has(str(weapon_id)):
			continue
		var row: Dictionary = weapon_catalog[weapon_id]
		if str(row.get("unlocked", "TRUE")).to_upper() != "TRUE":
			continue
		if !is_weapon_allowed_by_equipment(row):
			continue
		result.append({"type": "new_weapon", "row": row})
	return result

func is_weapon_allowed_by_equipment(row: Dictionary) -> bool:
	var weapon_type: String = str(row.get("weapon_type", ""))
	var tags: Array = parse_string_list(str(row.get("tags", "")))
	if active_equipment_effects.has("range_weapon_only"):
		return weapon_type == "area" or tags.has("area")
	if active_equipment_effects.has("melee_weapon_only"):
		return weapon_type == "melee" or tags.has("melee")
	return true

func build_run_stat_choices() -> Array:
	var result: Array = []
	for row in run_stat_upgrade_rows:
		result.append({"type": "run_stat", "row": row})
	return result

func get_level_choice_label(choice: Dictionary) -> String:
	var choice_type: String = str(choice.get("type", ""))
	var row: Dictionary = choice.get("row", {})
	if choice_type == "new_weapon":
		return "新武器：" + str(row.get("name", row.get("id", ""))) + "\n" + str(row.get("description", ""))
	if choice_type == "weapon_upgrade":
		var weapon_id: String = str(row.get("weapon_id", ""))
		var weapon_name: String = get_weapon_name(weapon_id)
		return weapon_name + " Lv" + str(row.get("level", "")) + "：" + str(row.get("name", "")) + "\n" + str(row.get("description", ""))
	if choice_type == "run_stat":
		return "局内强化：" + str(row.get("name", row.get("id", ""))) + "\n" + str(row.get("description", ""))
	return str(row.get("name", choice_type))

func get_weapon_name(weapon_id: String) -> String:
	var row: Dictionary = weapon_catalog.get(weapon_id, {})
	return str(row.get("name", weapon_id))

func apply_level_choice(choice: Dictionary) -> void:
	var choice_type: String = str(choice.get("type", ""))
	var row: Dictionary = choice.get("row", {})
	if choice_type == "new_weapon":
		add_player_weapon(row)
	elif choice_type == "weapon_upgrade":
		apply_weapon_upgrade(row)
	elif choice_type == "run_stat":
		apply_run_stat_upgrade(row)

func add_player_weapon(row: Dictionary) -> void:
	var weapon_id: String = str(row.get("id", "")).strip_edges()
	if weapon_id == "" or owned_weapon_ids.has(weapon_id):
		return

	var attack_id: String = str(row.get("attack_id", "")).strip_edges()
	var attack_data: Dictionary = load_attack_data(attack_id)
	if attack_data.is_empty():
		return

	var character_row: Dictionary = character_catalog.get(selected_character_id, {})
	var weapon_type: String = str(row.get("weapon_type", "ranged"))
	attack_data["weapon_id"] = weapon_id
	attack_data["weapon_level"] = 1
	apply_character_weapon_multiplier(attack_data, character_row, weapon_type)
	apply_run_stats_to_attack(attack_data)
	apply_equipment_to_player_attack(attack_data)
	player_entity.add_attack(attack_data)
	owned_weapon_ids.append(weapon_id)
	weapon_levels[weapon_id] = 1

func apply_weapon_upgrade(row: Dictionary) -> void:
	var weapon_id: String = str(row.get("weapon_id", "")).strip_edges()
	if weapon_id == "":
		return

	var next_level: int = int(row.get("level", int(weapon_levels.get(weapon_id, 1)) + 1))
	for attack in player_entity.attacks:
		if typeof(attack) != TYPE_DICTIONARY:
			continue
		if str(attack.get("weapon_id", "")) != weapon_id:
			continue
		apply_stat_ops_to_attack(attack, str(row.get("stat_ops", "")))
		apply_weapon_mechanic(attack, str(row.get("mechanic_id", "")))
		apply_equipment_to_player_attack(attack)
		attack["weapon_level"] = next_level
	weapon_levels[weapon_id] = next_level

func apply_run_stat_upgrade(row: Dictionary) -> void:
	var stat_ops: String = str(row.get("stat_ops", ""))
	for pair in parse_stat_ops(stat_ops):
		var key: String = str(pair.get("key", ""))
		var value: float = float(pair.get("value", 0.0))
		if key == "max_hp_add" and player_entity != null and is_instance_valid(player_entity):
			player_entity.max_hp += value
			player_entity.hp += value
		elif key == "global_damage_add":
			run_damage_add += value
			for attack in player_entity.attacks:
				if typeof(attack) == TYPE_DICTIONARY:
					add_attack_damage(attack, value)
		elif key == "global_bonus_damage_add":
			run_bonus_damage_add += value
			for attack in player_entity.attacks:
				if typeof(attack) == TYPE_DICTIONARY:
					attack["bonus_damage_add"] = float(attack.get("bonus_damage_add", 0.0)) + value
		elif key == "crit_up":
			run_crit_chance_add += value
			for attack in player_entity.attacks:
				if typeof(attack) == TYPE_DICTIONARY:
					attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + value
		elif key == "crit_mul_add":
			run_crit_multiplier_add += value
			for attack in player_entity.attacks:
				if typeof(attack) == TYPE_DICTIONARY:
					attack["crit_multiplier"] = float(attack.get("crit_multiplier", 1.5)) + value
		elif key == "mana_recovery_mul":
			run_mana_recovery_mul *= value
		elif key == "lust_reward_add":
			run_lust_reward_add += value

func parse_stat_ops(text: String) -> Array:
	var result: Array = []
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		return result

	var parts: PackedStringArray = clean_text.split("|", false)
	for part in parts:
		var pair_text: String = part.strip_edges()
		if pair_text == "" or not ("=" in pair_text):
			continue
		var pair_parts: PackedStringArray = pair_text.split("=", false, 1)
		if pair_parts.size() < 2:
			continue
		result.append({"key": pair_parts[0].strip_edges(), "value": float(pair_parts[1].strip_edges())})
	return result

func apply_stat_ops_to_attack(attack: Dictionary, stat_ops: String) -> void:
	for pair in parse_stat_ops(stat_ops):
		var key: String = str(pair.get("key", ""))
		var value: float = float(pair.get("value", 0.0))
		apply_one_stat_op_to_attack(attack, key, value)

func apply_one_stat_op_to_attack(attack: Dictionary, key: String, value: float) -> void:
	if key == "damage_mul":
		multiply_attack_damage(attack, value)
	elif key == "damage_add":
		add_attack_damage(attack, value)
	elif key == "interval_mul":
		attack["interval"] = max(0.05, float(attack.get("interval", 1.0)) * value)
	elif key == "emitter_count_add":
		var emitter: Dictionary = attack.get("emitter", {})
		emitter["count"] = max(1, int(emitter.get("count", 1)) + int(value))
		attack["emitter"] = emitter
	elif key == "speed_mul":
		multiply_nested_number(attack, "motion", "speed", value, true)
	elif key == "duration_mul":
		multiply_motion_duration(attack, value)
	elif key == "radius_mul":
		multiply_nested_number(attack, "hit_shape", "radius", value, true)
	elif key == "width_mul":
		multiply_nested_number(attack, "hit_shape", "width", value, true)
	elif key == "angle_add":
		add_nested_number(attack, "hit_shape", "angle", value)
	elif key == "tick_mul":
		multiply_nested_number(attack, "hit_rule", "tick_interval", value, true)
		multiply_nested_number(attack, "hit_rule", "hit_same_target_delay", value, true)
	elif key == "chain_count_add":
		add_chain_depth(attack, int(value))
	elif key == "status_duration_mul":
		multiply_status_duration(attack, value)
	elif key == "poison_damage_mul":
		multiply_status_value(attack, "poison", value)
	elif key == "pierce_add":
		attack["pierce"] = int(attack.get("pierce", 0)) + int(value)
	elif key == "life_steal_add":
		add_effect_number(attack, "life_steal", value)
	elif key == "crit_up":
		attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + value
	elif key == "crit_mul_add":
		attack["crit_multiplier"] = float(attack.get("crit_multiplier", 1.5)) + value
	elif key == "knockback_mul":
		multiply_force_strength(attack, value)

func multiply_nested_number(attack: Dictionary, section_name: String, key: String, value: float, require_existing: bool = false) -> void:
	var section: Dictionary = attack.get(section_name, {})
	if require_existing and !section.has(key):
		return
	section[key] = float(section.get(key, 0.0)) * value
	attack[section_name] = section

func add_nested_number(attack: Dictionary, section_name: String, key: String, value: float, require_existing: bool = false) -> void:
	var section: Dictionary = attack.get(section_name, {})
	if require_existing and !section.has(key):
		return
	section[key] = float(section.get(key, 0.0)) + value
	attack[section_name] = section

func multiply_motion_duration(attack: Dictionary, value: float) -> void:
	var motion: Dictionary = attack.get("motion", {})
	if motion.has("duration"):
		motion["duration"] = float(motion["duration"]) * value
	if motion.has("life_time"):
		motion["life_time"] = float(motion["life_time"]) * value
	attack["motion"] = motion

func add_chain_depth(attack: Dictionary, amount: int) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "chain_attack":
			effect["max_depth"] = int(effect.get("max_depth", 3)) + amount
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			add_chain_depth(effect["attack"], amount)

func multiply_status_duration(attack: Dictionary, value: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "status":
			effect["duration"] = float(effect.get("duration", 1.0)) * value
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			multiply_status_duration(effect["attack"], value)

func multiply_status_value(attack: Dictionary, status_name: String, value: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "status" and str(effect.get("status", effect.get("status_type", ""))) == status_name:
			effect["value"] = float(effect.get("value", 1.0)) * value
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			multiply_status_value(effect["attack"], status_name, value)

func add_effect_number(attack: Dictionary, key: String, amount: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "damage":
			effect[key] = float(effect.get(key, 0.0)) + amount
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			add_effect_number(effect["attack"], key, amount)

func multiply_force_strength(attack: Dictionary, value: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "force":
			effect["strength"] = float(effect.get("strength", 0.0)) * value
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			multiply_force_strength(effect["attack"], value)

func apply_weapon_mechanic(attack: Dictionary, mechanic_id: String) -> void:
	if mechanic_id.strip_edges() == "":
		return

	var mechanics: Array = attack.get("mechanics", [])
	if !mechanics.has(mechanic_id):
		mechanics.append(mechanic_id)
	attack["mechanics"] = mechanics

	if mechanic_id == "front_back_slash":
		var emitter: Dictionary = attack.get("emitter", {})
		emitter["mode"] = "ring"
		emitter["count"] = max(2, int(emitter.get("count", 1)))
		attack["emitter"] = emitter
	elif mechanic_id == "triple_flame":
		var emitter_flame: Dictionary = attack.get("emitter", {})
		emitter_flame["mode"] = "spread"
		emitter_flame["count"] = max(3, int(emitter_flame.get("count", 1)))
		emitter_flame["spread_angle"] = max(36.0, float(emitter_flame.get("spread_angle", 0.0)))
		attack["emitter"] = emitter_flame
	elif mechanic_id == "boomerang_five_sequence":
		var emitter_boomerang: Dictionary = attack.get("emitter", {})
		emitter_boomerang["mode"] = "spread"
		emitter_boomerang["count"] = max(5, int(emitter_boomerang.get("count", 1)))
		emitter_boomerang["spread_angle"] = max(90.0, float(emitter_boomerang.get("spread_angle", 0.0)))
		attack["emitter"] = emitter_boomerang
	elif mechanic_id == "boomerang_giant":
		apply_one_stat_op_to_attack(attack, "radius_mul", 1.8)
		apply_one_stat_op_to_attack(attack, "damage_mul", 1.35)
	elif mechanic_id == "random_thunder_count_up":
		apply_one_stat_op_to_attack(attack, "emitter_count_add", 1.0)
	elif mechanic_id == "shotgun_life_steal" or mechanic_id == "shotgun_lifesteal" or mechanic_id == "life_steal_small":
		apply_one_stat_op_to_attack(attack, "life_steal_add", 0.05)
	elif mechanic_id == "add_bleed":
		add_status_effect_to_attack(attack, "bleed", 3.0, 0.7, 4.0)
	elif mechanic_id == "add_slow":
		add_status_effect_to_attack(attack, "slow", 1.6, 0.0, 0.0, {"slow_mul": 0.82})
	elif mechanic_id == "add_slow_strong":
		add_status_effect_to_attack(attack, "slow", 2.2, 0.0, 0.0, {"slow_mul": 0.62})
	elif mechanic_id == "add_stun_short":
		add_status_effect_to_attack(attack, "slow", 0.45, 0.0, 0.0, {"slow_mul": 0.22})
	elif mechanic_id == "poison_stack_slow":
		add_status_effect_to_attack(attack, "slow", 2.5, 0.0, 0.0, {"slow_mul": 0.86})
	elif mechanic_id == "crit_up" or mechanic_id == "near_crit_up" or mechanic_id == "charm_raise_player_crit":
		attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + 0.06
		attack["crit_multiplier"] = float(attack.get("crit_multiplier", 1.5)) + 0.18
	elif mechanic_id == "center_bonus_damage" or mechanic_id == "rocket_center_second_hit":
		apply_one_stat_op_to_attack(attack, "damage_mul", 1.18)
	elif mechanic_id == "boomerang_small_aoe" or mechanic_id == "thunder_small_aoe" or mechanic_id == "shotgun_crit_extra_pellets":
		apply_one_stat_op_to_attack(attack, "radius_mul", 1.18)
		attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + 0.04
	elif mechanic_id == "spike_return_once" or mechanic_id == "spike_random_repeat":
		apply_one_stat_op_to_attack(attack, "emitter_count_add", 1.0)
	elif mechanic_id == "combo_interval_down":
		attack["interval"] = max(0.05, float(attack.get("interval", 1.0)) * 0.88)
	elif mechanic_id == "every_n_big_sweep" or mechanic_id == "random_heavy_punch":
		apply_one_stat_op_to_attack(attack, "damage_mul", 1.22)
		apply_one_stat_op_to_attack(attack, "radius_mul", 1.16)
	elif mechanic_id == "combo_mana_recovery":
		attack["mana_recovery_on_hit"] = float(attack.get("mana_recovery_on_hit", 0.0)) + 0.12
	elif mechanic_id == "trail_damage_short":
		add_status_effect_to_attack(attack, "bleed", 1.5, 0.5, 2.0)
	elif mechanic_id == "pierce_decay_down":
		soften_damage_decay(attack, 0.18)
	elif mechanic_id == "kill_retarget_once":
		apply_one_stat_op_to_attack(attack, "emitter_count_add", 1.0)
		apply_one_stat_op_to_attack(attack, "damage_mul", 0.78)
	elif mechanic_id == "low_hp_bonus" or mechanic_id == "high_hp_percent_bonus" or mechanic_id == "execute_low_hp" or mechanic_id == "same_target_rend" or mechanic_id == "late_life_bonus":
		pass
	elif mechanic_id == "bombard_ramp_damage":
		attack["ramp_damage"] = float(attack.get("ramp_damage", 0.0)) + 0.12
		apply_one_stat_op_to_attack(attack, "damage_mul", 1.12)
	elif mechanic_id == "delayed_second_blast":
		add_spawn_attack_effect(attack, make_simple_blast_attack("second_blast", 92.0, 18.0, Color(1.0, 0.55, 0.85, 0.8)))
	elif mechanic_id == "charm_heal_player_or_base":
		add_effect_number(attack, "heal_on_hit", 2.0)
	elif mechanic_id == "charm_speed_up":
		add_status_effect_to_attack(attack, "control", 2.8, 0.0, 0.0, {"speed_mul": 1.35})
	elif mechanic_id == "poison_stack_cap_up":
		multiply_status_duration(attack, 1.22)
		multiply_status_value(attack, "poison", 1.18)
	elif mechanic_id == "arson_speed_damage_loop":
		attack["speed_damage_loop"] = 0.08
		apply_one_stat_op_to_attack(attack, "damage_mul", 1.10)
	elif mechanic_id == "chain_static_aoe":
		add_spawn_attack_effect(attack, make_simple_blast_attack("chain_static", 86.0, 10.0, Color(1.0, 0.9, 0.35, 0.72)))
	elif mechanic_id == "shock_counter_execute":
		attack["shock_counter_execute"] = true
		attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + 0.05
	elif mechanic_id == "thunder_miss_compensate":
		attack["crit_chance"] = float(attack.get("crit_chance", 0.0)) + 0.12
		attack["crit_multiplier"] = float(attack.get("crit_multiplier", 1.5)) + 0.25
	elif mechanic_id == "rocket_fire_ground":
		add_status_effect_to_attack(attack, "burn", 2.4, 0.55, 5.0)

func soften_damage_decay(attack: Dictionary, amount: float) -> void:
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if effect.has("scale_over_life") and typeof(effect["scale_over_life"]) == TYPE_DICTIONARY:
			var scale_data: Dictionary = effect["scale_over_life"]
			scale_data["to"] = min(1.0, float(scale_data.get("to", 1.0)) + amount)
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			soften_damage_decay(effect["attack"], amount)

func add_spawn_attack_effect(attack: Dictionary, spawned_attack: Dictionary) -> void:
	var effects: Array = attack.get("effects", [])
	effects.append({"mode": "spawn_attack", "max_depth": 1, "attack": spawned_attack})
	attack["effects"] = effects

func make_simple_blast_attack(blast_id: String, blast_radius: float, damage: float, color: Color) -> Dictionary:
	return {
		"id": blast_id,
		"kind": "attack_instance",
		"requires_target": false,
		"origin": {"mode": "target_center"},
		"aim": {"mode": "fixed_angle", "angle": 0},
		"emitter": {"mode": "single", "count": 1},
		"motion": {"mode": "static", "duration": 0.18},
		"hit_shape": {"mode": "circle", "radius": blast_radius},
		"hit_rule": {"mode": "on_spawn_once", "hit_same_target_delay": 999},
		"target_filter": {"relation": "enemy", "include_building": false},
		"effects": [{"mode": "damage", "value": damage}],
		"visual": {
			"primary": color.to_html(false),
			"secondary": "ffe1c8",
			"alpha": color.a,
			"pixel_count": 14
		}
	}

func add_status_effect_to_attack(attack: Dictionary, status_name: String, duration: float, tick_interval: float, value: float, extra: Dictionary = {}) -> void:
	var effects: Array = attack.get("effects", [])
	var status_effect: Dictionary = {"mode": "status", "status": status_name, "duration": duration}
	if tick_interval > 0.0:
		status_effect["tick_interval"] = tick_interval
	if value != 0.0:
		status_effect["value"] = value
	for key in extra.keys():
		status_effect[key] = extra[key]
	effects.append(status_effect)
	attack["effects"] = effects

func load_entity_data(entity_id: String) -> Dictionary:
	var path: String = "res://BattleAssets/" + entity_id + ".json"
	if !FileAccess.file_exists(path):
		push_error("Missing entity json: " + path)
		return {}

	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid entity json: " + path)
		return {}

	return parsed

func find_target_for(source, target_factions: Array, sense_radius: float):
	var best = null
	var best_rank: int = 999999
	var best_dist: float = INF
	if source == null or !is_instance_valid(source):
		return null

	var candidates: Array = entities
	if sense_radius > 0.0:
		candidates = query_entities_near(source.global_position, sense_radius + 96.0)

	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue

		if entity == source:
			continue

		if entity.is_dead:
			continue

		if !target_factions.has(entity.faction):
			continue

		var dist: float = source.global_position.distance_to(entity.global_position)
		if sense_radius > 0.0 and dist > sense_radius:
			continue

		var rank: int = source.get_target_rank(entity)
		if rank < best_rank:
			best = entity
			best_rank = rank
			best_dist = dist
			continue

		if rank == best_rank and source.is_better_target_distance(dist, best_dist):
			best = entity
			best_dist = dist

	return best

func find_objective_target_for(source, target_factions: Array, max_radius: float = 0.0, priority_order: Array = []):
	var best = null
	var best_rank: int = 999999
	var best_dist: float = INF
	if source == null or !is_instance_valid(source):
		return null
	var original_priority_order: Array = []
	var use_override_priority: bool = !priority_order.is_empty() and source != null and is_instance_valid(source)
	if use_override_priority:
		original_priority_order = source.target_priority_order.duplicate()
		source.target_priority_order = priority_order

	var candidates: Array = entities
	if max_radius > 0.0:
		candidates = query_entities_near(source.global_position, max_radius + 128.0)

	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue

		if entity == source:
			continue

		if entity.is_dead:
			continue

		if !target_factions.has(entity.faction):
			continue

		if !entity.is_building:
			continue

		var dist: float = source.global_position.distance_to(entity.global_position)
		if max_radius > 0.0 and dist > max_radius:
			continue
		var rank: int = source.get_target_rank(entity)
		if rank < best_rank:
			best = entity
			best_rank = rank
			best_dist = dist
			continue

		if rank == best_rank and source.is_better_target_distance(dist, best_dist):
			best = entity
			best_dist = dist

	if use_override_priority:
		source.target_priority_order = original_priority_order

	return best

func get_building_avoid_direction(entity, direct: Vector2, target_pos: Vector2, forced_side: float = 0.0, ignored_building = null) -> Vector2:
	if entity == null or !is_instance_valid(entity):
		return Vector2.ZERO

	if entity.is_building or direct.length() <= 0.01:
		return Vector2.ZERO

	var best_building = null
	var best_score: float = INF

	var candidates: Array = query_entities_near(entity.global_position, entity.radius + 360.0)
	for other in candidates:
		if other == null or !is_instance_valid(other):
			continue

		if other == entity or other == ignored_building or other.is_dead or !other.is_building:
			continue

		var to_building: Vector2 = other.global_position - entity.global_position
		var dist: float = to_building.length()
		var avoid_radius: float = entity.radius + other.block_radius + 96.0
		var ahead: float = to_building.dot(direct)
		var side_dist: float = abs(to_building.cross(direct))
		var near_or_ahead: bool = dist < avoid_radius or (ahead > 0.0 and ahead < avoid_radius * 1.55 and side_dist < avoid_radius)

		if !near_or_ahead:
			continue

		var score: float = dist
		if forced_side == 0.0:
			score -= max(ahead, 0.0) * 0.25

		if score < best_score:
			best_score = score
			best_building = other

	if best_building == null:
		return Vector2.ZERO

	var away: Vector2 = entity.global_position - best_building.global_position
	if away.length() <= 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	away = away.normalized()

	var tangent_a: Vector2 = Vector2(-away.y, away.x)
	var tangent_b: Vector2 = Vector2(away.y, -away.x)
	var to_target: Vector2 = target_pos - entity.global_position
	if to_target.length() <= 0.01:
		to_target = direct
	to_target = to_target.normalized()

	var tangent: Vector2 = tangent_a
	if forced_side > 0.0:
		tangent = tangent_a
	elif forced_side < 0.0:
		tangent = tangent_b
	elif tangent_b.dot(to_target) > tangent_a.dot(to_target):
		tangent = tangent_b

	var dist_to_building: float = entity.global_position.distance_to(best_building.global_position)
	var push_strength: float = 1.0 - clamp((dist_to_building - entity.radius - best_building.block_radius) / 96.0, 0.0, 1.0)
	return (tangent * 0.86 + away * (0.28 + push_strength * 0.35) + direct * 0.18).normalized()

func get_walkable_avoid_direction(entity, direct: Vector2, ignored_building = null) -> Vector2:
	if entity == null or !is_instance_valid(entity):
		return Vector2.ZERO

	if direct.length() <= 0.01:
		return Vector2.ZERO

	var step_dist: float = max(entity.radius + 22.0, 42.0)
	if can_entity_stand_at(entity, clamp_to_map(entity.global_position + direct * step_dist), ignored_building):
		return Vector2.ZERO

	var candidates: Array[Vector2] = [
		direct.rotated(PI * 0.25),
		direct.rotated(-PI * 0.25),
		direct.rotated(PI * 0.5),
		direct.rotated(-PI * 0.5),
		-direct
	]

	for candidate in candidates:
		if can_entity_stand_at(entity, clamp_to_map(entity.global_position + candidate.normalized() * step_dist), ignored_building):
			return candidate.normalized()

	return Vector2.ZERO

func process_base_contact_auras(delta: float) -> void:
	for base_entity in entities:
		if base_entity == null or !is_instance_valid(base_entity):
			continue

		if base_entity.is_dead:
			continue

		if !base_entity.is_building:
			continue

		base_entity.update_contact_aura(delta)

func process_base_aura_buffs(delta: float) -> void:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return
	if tentacle_base.alert_radius <= 0.0:
		return
	if tentacle_base.base_aura_speed_mul <= 1.0 and tentacle_base.base_aura_regen_add <= 0.0:
		return

	var candidates: Array = query_entities_near(tentacle_base.global_position, tentacle_base.alert_radius + 96.0)
	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead or entity.is_building:
			continue
		if entity.entity_type != "player" and !(entity.faction == "tentacle" and entity.entity_type == "minion"):
			continue
		if entity.global_position.distance_to(tentacle_base.global_position) > tentacle_base.alert_radius + entity.radius:
			continue

		if tentacle_base.base_aura_speed_mul > 1.0:
			entity.add_status_effect({
				"status": "speed",
				"duration": 0.24,
				"speed_mul": tentacle_base.base_aura_speed_mul
			}, tentacle_base)
		if tentacle_base.base_aura_regen_add > 0.0:
			entity.heal(tentacle_base.base_aura_regen_add * delta, tentacle_base, false)

func process_unit_contacts(delta: float) -> void:
	for key in unit_contact_timers.keys():
		unit_contact_timers[key] = max(0.0, float(unit_contact_timers[key]) - delta)

	var total: int = entities.size()
	if total <= 0:
		return

	# Broadphase + time slicing. Each frame checks only a rotating slice of mobile units.
	# This trades a few frames of contact latency for much flatter frame time under swarms.
	var budget: int = clamp(int(ceil(float(total) * unit_contact_budget_fraction)), unit_contact_budget_min, total)
	var checked: int = 0
	while checked < budget and checked < total:
		if unit_contact_cursor >= total:
			unit_contact_cursor = 0
		var a = entities[unit_contact_cursor]
		unit_contact_cursor += 1
		checked += 1

		if a == null or !is_instance_valid(a):
			continue
		if a.is_dead or a.is_building or a.entity_type == "player":
			continue
		if !is_entity_precise_combat_active(a):
			continue

		var candidates: Array = query_entities_near(a.global_position, a.radius + 220.0)
		for b in candidates:
			if b == null or !is_instance_valid(b):
				continue
			if b == a:
				continue
			if b.get_instance_id() <= a.get_instance_id():
				continue
			if b.is_dead or b.is_building or b.entity_type == "player":
				continue
			if !is_entity_precise_combat_active(b):
				continue
			if are_factions_allied(a.faction, b.faction):
				continue

			var min_dist: float = a.radius + b.radius
			var dist: float = a.global_position.distance_to(b.global_position)
			if dist > min_dist:
				continue

			if is_worker_entity(a) or is_worker_entity(b):
				if is_worker_entity(a):
					a.pause_worker_by_contact()
				if is_worker_entity(b):
					b.pause_worker_by_contact()
				continue

			var key: String = make_contact_key(a, b)
			if float(unit_contact_timers.get(key, 0.0)) > 0.0:
				continue

			unit_contact_timers[key] = 0.45
			var away: Vector2 = b.global_position - a.global_position
			if away.length() <= 0.01:
				away = Vector2.RIGHT.rotated(randf() * TAU)
			away = away.normalized()

			var overlap: float = max(min_dist - dist, 8.0)
			move_entity(a, -away * (overlap * 0.65 + randf_range(8.0, 18.0)))
			move_entity(b, away * (overlap * 0.65 + randf_range(8.0, 18.0)))

			a.take_damage(b.get_scaled_damage(max(1.0, b.attack_power * 0.35), a, {"kind": "unit_contact"}), b)
			b.take_damage(a.get_scaled_damage(max(1.0, a.attack_power * 0.35), b, {"kind": "unit_contact"}), a)

func make_contact_key(a, b) -> String:
	var a_id: int = a.get_instance_id()
	var b_id: int = b.get_instance_id()
	if a_id < b_id:
		return str(a_id) + "_" + str(b_id)
	return str(b_id) + "_" + str(a_id)

func process_old_wave_retirement(delta: float) -> void:
	if !old_wave_retire_enabled:
		return
	old_wave_retire_timer -= delta
	if old_wave_retire_timer > 0.0:
		return
	old_wave_retire_timer = old_wave_retire_interval

	if entities.size() < old_wave_retire_entity_threshold:
		return
	if player_entity == null or !is_instance_valid(player_entity):
		return

	var retired := 0
	for entity in entities.duplicate():
		if retired >= old_wave_retire_per_tick:
			break
		if entity == null or !is_instance_valid(entity):
			continue
		if !can_retire_old_trash_entity(entity):
			continue
		retire_old_trash_entity(entity)
		retired += 1

func can_retire_old_trash_entity(entity) -> bool:
	if entity.is_dead or entity.is_building:
		return false
	if entity.entity_type == "player" or entity.entity_type == "base" or entity.entity_type == "worker":
		return false
	if entity.tags.has("boss") or entity.tags.has("elite") or entity.tags.has("building") or entity.tags.has("base") or entity.tags.has("worker"):
		return false
	if str(entity.get("ai_role")) == "leader":
		return false
	# Do not retire friendly minions around the mother base; this is mostly for old
	# enemy wave trash.
	if are_factions_allied(entity.faction, "tentacle"):
		return false
	var age: float = battle_time - float(entity.get_meta("spawn_time", battle_time))
	if age < old_wave_retire_min_age:
		return false
	var pos: Vector2 = entity.global_position
	var min_core_dist: float = pos.distance_to(player_entity.global_position)
	if tentacle_base != null and is_instance_valid(tentacle_base):
		min_core_dist = min(min_core_dist, pos.distance_to(tentacle_base.global_position))
	if enemy_base != null and is_instance_valid(enemy_base):
		min_core_dist = min(min_core_dist, pos.distance_to(enemy_base.global_position))
	if min_core_dist < old_wave_retire_far_distance:
		return false
	# If the unit is visible, let normal play handle it. Retire far historical trash only.
	if battle_camera != null and is_position_near_camera(pos, 260.0):
		return false
	return true

func retire_old_trash_entity(entity) -> void:
	# Remove without rewards. This is wave lifecycle cleanup, not a player kill.
	if entity == null or !is_instance_valid(entity):
		return
	entity.is_dead = true
	entities.erase(entity)
	if entity.has_method("set_shared_gif_sprite_in_batch_tree"):
		entity.set_shared_gif_sprite_in_batch_tree(false)
	entity.queue_free()
	mark_shared_gif_batch_dirty()

func is_position_near_camera(pos: Vector2, extra_margin: float = 0.0) -> bool:
	if battle_camera == null:
		return false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom: Vector2 = battle_camera.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		zoom = Vector2.ONE
	var half_size: Vector2 = viewport_size * 0.5 / zoom + Vector2.ONE * extra_margin
	var center: Vector2 = battle_camera.global_position
	return abs(pos.x - center.x) <= half_size.x and abs(pos.y - center.y) <= half_size.y

func process_base_delivery_and_production(delta: float) -> void:
	if tentacle_base != null and is_instance_valid(tentacle_base):
		tentacle_base.update_base_system(delta)

	if player_entity == null or !is_instance_valid(player_entity):
		return

	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return

	if tentacle_base.delivery_radius <= 0.0:
		return

	var delivery_center: Vector2 = tentacle_base.get_delivery_center()
	var dist: float = player_entity.global_position.distance_to(delivery_center)
	if dist <= tentacle_base.delivery_radius:
		player_entity.try_transfer_bio_to_base(tentacle_base, delta)

func process_player_skills(delta: float) -> void:
	if player_entity == null or !is_instance_valid(player_entity):
		return

	for skill_id in player_skill_cooldowns.keys():
		player_skill_cooldowns[skill_id] = max(0.0, float(player_skill_cooldowns[skill_id]) - delta)

	var regen: float = player_mana_regen * run_mana_recovery_mul
	if player_entity.has_method("get_status_mana_recovery_multiplier"):
		regen *= player_entity.get_status_mana_recovery_multiplier()
	player_mana = min(player_mana_max, player_mana + regen * delta)

	if active_channel_skill_id != "":
		var skill: Dictionary = get_skill_by_id(active_channel_skill_id)
		if skill.is_empty() or player_mana <= 0.0:
			stop_channel_skill()
			return
		var drain: float = float(skill.get("mana_drain_per_second", 0.0)) * delta
		player_mana = max(0.0, player_mana - drain)
		apply_channel_skill_tick(skill, delta)
		if player_mana <= 0.0:
			stop_channel_skill()

func get_skill_by_id(skill_id: String) -> Dictionary:
	for skill in player_skills.values():
		if str(skill.get("id", "")) == skill_id:
			return skill
	return {}

func try_activate_skill_slot(slot: int) -> void:
	if player_entity == null or !is_instance_valid(player_entity):
		return
	if !player_skills.has(slot):
		return

	var skill: Dictionary = player_skills[slot]
	var skill_id: String = str(skill.get("id", ""))

	var mode: String = str(skill.get("mode", "attack"))
	if mode == "channel_buff":
		if active_channel_skill_id == skill_id:
			stop_channel_skill()
		else:
			if float(player_skill_cooldowns.get(skill_id, 0.0)) > 0.0:
				spawn_floating_number(player_entity.global_position + Vector2(0.0, -72.0), "CD", Color(0.75, 0.85, 1.0, 1.0))
				return
			start_channel_skill(skill)
		return

	if float(player_skill_cooldowns.get(skill_id, 0.0)) > 0.0:
		spawn_floating_number(player_entity.global_position + Vector2(0.0, -72.0), "CD", Color(0.75, 0.85, 1.0, 1.0))
		return

	cast_attack_skill(skill, slot)

func start_channel_skill(skill: Dictionary) -> void:
	var cost: float = float(skill.get("mana_start_cost", 0.0))
	if player_mana < cost:
		spawn_floating_number(player_entity.global_position + Vector2(0.0, -72.0), "Mana不足", Color(0.55, 0.8, 1.0, 1.0))
		return
	player_mana -= cost
	active_channel_skill_id = str(skill.get("id", ""))
	player_skill_cooldowns[active_channel_skill_id] = get_skill_cooldown(skill)
	spawn_skill_cast_fx(skill, player_entity.global_position)

func stop_channel_skill() -> void:
	active_channel_skill_id = ""

func apply_channel_skill_tick(skill: Dictionary, delta: float) -> void:
	var heal_per_second: float = float(skill.get("heal_per_second", 0.0)) * selected_character_skill_mul
	if heal_per_second > 0.0:
		player_entity.heal(heal_per_second * delta, player_entity, false)
	var status: Dictionary = skill.get("status", {})
	if !status.is_empty():
		player_entity.add_status_effect(status, player_entity)

func cast_attack_skill(skill: Dictionary, slot: int) -> void:
	if slot == 2 and active_equipment_effects.has("skill2_full_mana_required") and player_mana < player_mana_max - 0.01:
		spawn_floating_number(player_entity.global_position + Vector2(0.0, -72.0), "Mana未满", Color(0.55, 0.8, 1.0, 1.0))
		return
	var cost: float = float(skill.get("mana_cost", 0.0))
	if standard_mode_balance_enabled:
		cost *= standard_player_skill_mana_cost_mul
	if player_mana < cost:
		spawn_floating_number(player_entity.global_position + Vector2(0.0, -72.0), "Mana不足", Color(0.55, 0.8, 1.0, 1.0))
		return
	player_mana -= cost
	var skill_id: String = str(skill.get("id", ""))
	player_skill_cooldowns[skill_id] = get_skill_cooldown(skill)
	var attack: Dictionary = skill.get("attack", {}).duplicate(true)
	var skill_multiplier: float = selected_character_skill_mul
	if standard_mode_balance_enabled:
		skill_multiplier *= standard_player_skill_damage_mul
	if player_entity.has_method("get_status_skill_damage_multiplier"):
		skill_multiplier *= player_entity.get_status_skill_damage_multiplier()
	scale_skill_attack(attack, skill_multiplier)
	if standard_mode_balance_enabled:
		apply_standard_player_skill_tuning(attack)
	var dir: Vector2 = player_entity.get_global_mouse_position() - player_entity.global_position
	if dir.length() <= 0.01:
		dir = Vector2.RIGHT
	spawn_attack(player_entity, attack, {"direction": dir.normalized()})
	spawn_skill_cast_fx(skill, player_entity.global_position)

func get_skill_cooldown(skill: Dictionary) -> float:
	var cd: float = float(skill.get("cooldown", 1.0))
	if standard_mode_balance_enabled:
		cd *= standard_player_skill_cooldown_mul
	return max(player_skill_min_cooldown * 0.62, cd)

func scale_skill_attack(attack: Dictionary, multiplier: float) -> void:
	if multiplier == 1.0:
		return
	for effect in attack.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("mode", "")) == "damage" and effect.has("value"):
			effect["value"] = float(effect["value"]) * multiplier
		if str(effect.get("mode", "")) == "heal" and effect.has("value"):
			effect["value"] = float(effect["value"]) * multiplier
		if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
			scale_skill_attack(effect["attack"], multiplier)

func spawn_skill_cast_fx(skill: Dictionary, pos: Vector2) -> void:
	var visual: Dictionary = skill.get("visual", {})
	var color: Color = parse_color(str(visual.get("color", "78eaff")), Color(0.47, 0.92, 1.0, 0.86))
	color.a = 0.82
	spawn_ring_fx(pos, float(visual.get("radius", 96.0)), color, 6.0, 0.42)

func are_factions_allied(a: String, b: String) -> bool:
	if a == b:
		return true

	if a == "player" and b == "tentacle":
		return true

	if a == "tentacle" and b == "player":
		return true

	return false

func process_recent_spawn_positions(delta: float) -> void:
	for i in range(recent_spawn_positions.size() - 1, -1, -1):
		var item: Dictionary = recent_spawn_positions[i]
		item["ttl"] = float(item.get("ttl", 0.0)) - delta
		if float(item["ttl"]) <= 0.0:
			recent_spawn_positions.remove_at(i)
		else:
			recent_spawn_positions[i] = item

func reserve_spawn_position(pos: Vector2, unit_radius: float) -> void:
	recent_spawn_positions.append({
		"pos": pos,
		"radius": max(spawn_position_min_spacing, unit_radius * 1.45),
		"ttl": recent_spawn_ttl
	})

func is_clear_of_recent_spawn_reservations(pos: Vector2, unit_radius: float) -> bool:
	var required: float = max(spawn_position_min_spacing, unit_radius * 1.45)
	for item in recent_spawn_positions:
		var other_pos: Vector2 = item.get("pos", Vector2.ZERO)
		var other_radius: float = float(item.get("radius", spawn_position_min_spacing))
		if pos.distance_to(other_pos) < required + other_radius:
			return false
	return true

func get_spawn_position(spawn_rule: String, wave: Dictionary) -> Vector2:
	if spawn_rule == "":
		return Vector2.ZERO

	if "," in spawn_rule:
		return parse_vector2(spawn_rule, Vector2.ZERO)

	if spawn_rule.begins_with("area:"):
		var area_id: String = spawn_rule.substr(5)
		return random_position_in_stage_area(area_id, str(wave.get("entity_id", "")))

	if spawn_rule == "random_around_player":
		if player_entity != null and is_instance_valid(player_entity):
			return random_ring_position(player_entity.global_position, wave)
		return Vector2.ZERO

	if spawn_rule == "random_near_tentacle_base":
		if tentacle_base != null and is_instance_valid(tentacle_base):
			return random_ring_position(tentacle_base.global_position, wave)
		return Vector2.ZERO

	var marker_name: String = "Marker2D" + spawn_rule
	var marker: Node = spawn_root.get_node_or_null(marker_name)

	if marker == null:
		marker = spawn_root.get_node_or_null(spawn_rule)

	if marker != null:
		var pos: Vector2 = marker.global_position
		var random_radius: float = float(wave.get("random_radius", 0.0))
		if random_radius > 0.0:
			var random_radius_min: float = float(wave.get("random_radius_min", 0.0))
			var entity_id: String = str(wave.get("entity_id", ""))
			for i in range(40):
				var test_pos: Vector2 = marker.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(random_radius_min, random_radius)
				test_pos = clamp_to_map(test_pos)
				if is_spawn_position_clear(test_pos, entity_id):
					return test_pos

			pos += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(max(random_radius_min, random_radius * 0.65), random_radius)
		return clamp_to_map(pos)

	return Vector2.ZERO

func random_position_in_stage_area(area_id: String, entity_id: String = "") -> Vector2:
	if !stage_areas.has(area_id):
		return Vector2.ZERO
	var area: Dictionary = stage_areas[area_id]
	var center: Vector2 = area.get("center", Vector2.ZERO)
	var shape: String = str(area.get("shape", "circle"))
	for i in range(40):
		var pos: Vector2 = center
		if shape == "rect":
			var size: Vector2 = area.get("size", Vector2(160.0, 160.0))
			pos += Vector2(randf_range(-size.x * 0.5, size.x * 0.5), randf_range(-size.y * 0.5, size.y * 0.5))
		else:
			var radius: float = float(area.get("radius", 120.0))
			pos += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, radius)
		pos = clamp_to_map(pos)
		if is_spawn_position_clear(pos, entity_id):
			return pos
	return clamp_to_map(center)

func is_spawn_position_clear(pos: Vector2, entity_id: String) -> bool:
	if !is_world_walkable(pos):
		return false

	var unit_radius: float = 20.0
	if entity_id != "":
		var entity_data: Dictionary = load_entity_data(entity_id)
		var body: Dictionary = entity_data.get("body", {})
		unit_radius = float(body.get("radius", unit_radius))

	if !is_clear_of_recent_spawn_reservations(pos, unit_radius):
		return false

	var candidates: Array = query_entities_near(pos, unit_radius + 420.0)
	for other in candidates:
		if other == null or !is_instance_valid(other):
			continue

		if other.is_dead:
			continue

		if !other.is_building:
			continue

		var min_dist: float = unit_radius + other.block_radius + 24.0
		if pos.distance_to(other.global_position) < min_dist:
			return false

	return true

func random_ring_position(center: Vector2, wave: Dictionary) -> Vector2:
	var min_dist: float = float(wave.get("distance_min", 700.0))
	var max_dist: float = float(wave.get("distance_max", 1000.0))

	for i in range(20):
		var pos: Vector2 = center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(min_dist, max_dist)
		pos = clamp_to_map(pos)
		if is_world_walkable(pos):
			return pos

	return clamp_to_map(center)

func clamp_to_map(pos: Vector2) -> Vector2:
	pos.x = clamp(pos.x, 0.0, map_size.x)
	pos.y = clamp(pos.y, 0.0, map_size.y)
	return pos

func move_entity(entity, move_delta: Vector2) -> Vector2:
	var from_pos: Vector2 = entity.global_position
	var wanted: Vector2 = clamp_to_map(from_pos + move_delta)

	if can_entity_stand_at(entity, wanted):
		entity.global_position = wanted
		return wanted

	var x_pos: Vector2 = clamp_to_map(from_pos + Vector2(move_delta.x, 0.0))
	if can_entity_stand_at(entity, x_pos):
		entity.global_position = x_pos
		return x_pos

	var y_pos: Vector2 = clamp_to_map(from_pos + Vector2(0.0, move_delta.y))
	if can_entity_stand_at(entity, y_pos):
		entity.global_position = y_pos
		return y_pos

	entity.global_position = from_pos
	return from_pos

func can_entity_stand_at(entity, pos: Vector2, ignored_building = null) -> bool:
	if !is_world_walkable(pos):
		return false

	if entity.is_building:
		return true

	var candidates: Array = query_entities_near(pos, entity.radius + 420.0)
	for other in candidates:
		if other == null or !is_instance_valid(other):
			continue

		if other == entity or other == ignored_building:
			continue

		if other.is_dead:
			continue

		if is_worker_entity(other):
			continue

		if !other.is_building:
			continue

		var min_dist: float = entity.radius + other.block_radius
		if pos.distance_to(other.global_position) < min_dist:
			return false

	return true

func is_worker_entity(entity) -> bool:
	if entity == null or !is_instance_valid(entity):
		return false
	return entity.entity_type == "worker" or entity.tags.has("worker")

func is_world_walkable(world_pos: Vector2) -> bool:
	if block_mask_sprite == null or block_mask_image == null:
		return true

	var local_pos: Vector2 = block_mask_sprite.to_local(world_pos)

	if block_mask_sprite.centered and block_mask_sprite.texture != null:
		local_pos += block_mask_sprite.texture.get_size() * 0.5

	var x: int = int(local_pos.x)
	var y: int = int(local_pos.y)

	if x < 0 or y < 0:
		return false

	if x >= block_mask_image.get_width() or y >= block_mask_image.get_height():
		return false

	var color: Color = block_mask_image.get_pixel(x, y)
	return color.a > block_alpha_limit

func register_entity_death(entity, _source = null) -> void:
	if entity == null:
		return

	if entity == player_entity:
		if try_consume_player_revive(entity):
			return
		record_battle_loss("player_dead")
		return

	if entity == tentacle_base:
		record_battle_loss("base_dead")
		return

	if int(entity.ai_group_id) >= 0 and swarm_group_leaders.get(int(entity.ai_group_id), null) == entity:
		swarm_group_leaders.erase(int(entity.ai_group_id))

	if entity.faction == "enemy":
		enemy_kill_count += 1
		battle_lust_score += get_lust_value_for_entity(entity)
		emit_equipment_event("on_enemy_killed", {"entity_id": entity.entity_id, "is_building": entity.is_building})
		if win_condition == "kill_entity_id" and objective_target_entity_id != "" and entity.entity_id == objective_target_entity_id:
			objective_progress_count += 1
		var reward_data: Dictionary = entity.data.get("reward", {})
		var default_xp: int = 1
		if entity.is_building:
			default_xp = 5
		var xp_value: int = int(reward_data.get("xp", default_xp))
		add_player_xp(xp_value)
		if entity == enemy_base or entity.tags.has("base"):
			record_battle_win(entity)

	var reward: Dictionary = entity.data.get("reward", {})
	var bio_value: int = int(reward.get("bio", 0))
	if bio_value > 0:
		spawn_bio_drop(entity.global_position, bio_value)

func get_lust_value_for_entity(entity) -> float:
	if entity == null or !is_instance_valid(entity):
		return 0.0
	var reward: Dictionary = entity.data.get("reward", {})
	if reward.has("lust"):
		return max(0.0, float(reward.get("lust", 0.0)))
	if entity == enemy_base or entity.tags.has("base"):
		return 100.0
	if entity.tags.has("boss") or entity.tags.has("elite"):
		return 10.0
	if entity.is_building:
		return 25.0
	return 1.0

func record_battle_win(_dead_base) -> void:
	if battle_won or battle_lost:
		return

	battle_won = true
	trigger_stage_result_events("win")
	settle_battle_result(true, "enemy_base_destroyed")

func record_battle_loss(reason: String) -> void:
	if battle_won or battle_lost:
		return
	battle_lost = true
	trigger_stage_result_events("loss")
	if objective_label:
		if reason == "base_dead":
			objective_label.text = "失败：基地被摧毁"
		elif reason == "player_dead":
			objective_label.text = "失败：玩家倒下"
		else:
			objective_label.text = "失败"
	settle_battle_result(false, reason)

func settle_battle_result(is_win: bool, reason: String) -> void:
	if battle_result_settled:
		return
	battle_result_settled = true
	var level_id: String = str(battle_loadout.get("level_id", ""))
	if level_id == "":
		level_id = str(config.get_value("stage", "id", ""))
	var base_lust: float = max(0.0, battle_lust_score + run_lust_reward_add)
	var result_mul := 1.0 if is_win else 0.55
	var outgame_lust_mul := 1.0 + get_outgame_upgrade_effect("battle_lust_reward_mul", 0.0)
	var lust_reward: int = max(0, int(round(base_lust * run_lust_reward_mul * result_mul * outgame_lust_mul)))
	var captive_id := ""
	var first_clear := false
	if GameState.is_loaded:
		if is_win and level_id != "":
			first_clear = !GameState.data.get("progress", {}).get("cleared_levels", []).has(level_id)
			GameState.record_level_clear(level_id, 1, false)
		if lust_reward > 0:
			GameState.add_lust(lust_reward, false)
		if is_win and first_clear and level_id != "":
			captive_id = "CAP_" + level_id + "_CLEAR"
			GameState.add_captive(captive_id, level_id, false)
		if GameState.has_method("clear_merchant_next_battle_effects"):
			GameState.clear_merchant_next_battle_effects(false)
		GameState.set_last_battle_result({
			"level_id": level_id,
			"win": is_win,
			"reason": reason,
			"lust_reward": lust_reward,
			"kill_count": enemy_kill_count,
			"lust_base_score": int(round(battle_lust_score)),
			"battle_time": battle_time,
			"captive_id": captive_id,
			"first_clear": first_clear,
		}, false)
		if GameState.has_method("save_progress_now"):
			GameState.save_progress_now("battle_result")
		else:
			GameState.autosave("battle_result")
	battle_result_transition_timer = battle_result_transition_delay

func process_battle_result_transition(delta: float) -> void:
	if battle_result_transition_timer < 0.0:
		return
	battle_result_transition_timer -= delta
	if battle_result_transition_timer > 0.0:
		return
	battle_result_transition_timer = -1.0
	get_tree().change_scene_to_file(OUTGAME_UPGRADE_SCENE_PATH)


func try_consume_player_revive(dead_player) -> bool:
	if player_revives_remaining <= 0:
		return false
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return false
	if tentacle_base.is_dead:
		return false

	var min_hp: float = tentacle_base.max_hp * revive_base_min_hp_ratio
	var cost: float = tentacle_base.max_hp * revive_base_hp_cost_ratio
	if tentacle_base.hp <= min_hp or tentacle_base.hp <= cost + 1.0:
		return false

	player_revives_remaining -= 1
	tentacle_base.take_damage(cost, tentacle_base)

	var revive_data: Dictionary = {
		"entity_id": str(dead_player.entity_id),
		"max_hp": float(dead_player.max_hp),
		"move_speed": float(dead_player.move_speed),
		"attack_power": float(dead_player.attack_power),
		"defense": float(dead_player.defense),
		"hp_regen": float(dead_player.hp_regen_per_second),
		"bio_cargo_max": int(dead_player.bio_cargo_max),
		"attacks": dead_player.attacks.duplicate(true)
	}
	call_deferred("revive_player_from_base", revive_data)
	if tentacle_base != null and is_instance_valid(tentacle_base):
		spawn_ring_fx(tentacle_base.global_position, 170.0, Color(0.52, 0.9, 1.0, 0.78), 8.0, 0.9)
	return true

func revive_player_from_base(revive_data: Dictionary) -> void:
	if battle_won or battle_lost:
		return
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return

	var entity_id: String = str(revive_data.get("entity_id", "000"))
	var spawn_pos: Vector2 = tentacle_base.get_base_spawn_position(entity_id)
	var revived = spawn_entity(entity_id, spawn_pos)
	if revived == null or !is_instance_valid(revived):
		record_battle_loss("player_dead")
		return

	player_entity = revived
	player_entity.max_hp = float(revive_data.get("max_hp", player_entity.max_hp))
	player_entity.hp = player_entity.max_hp * 0.55
	player_entity.move_speed = float(revive_data.get("move_speed", player_entity.move_speed))
	player_entity.attack_power = float(revive_data.get("attack_power", player_entity.attack_power))
	player_entity.defense = float(revive_data.get("defense", player_entity.defense))
	player_entity.hp_regen_per_second = float(revive_data.get("hp_regen", player_entity.hp_regen_per_second))
	player_entity.bio_cargo_max = int(revive_data.get("bio_cargo_max", player_entity.bio_cargo_max))
	var restored_attacks: Array = revive_data.get("attacks", [])
	if !restored_attacks.is_empty():
		player_entity.set_attacks(restored_attacks)
	player_mana = min(player_mana_max, max(player_mana, player_mana_max * 0.35))
	spawn_floating_number(player_entity.global_position + Vector2(0.0, -player_entity.radius - 54.0), "分身复活", Color(0.55, 0.9, 1.0, 1.0))

func trigger_stage_result_events(result_condition: String) -> void:
	for i in range(stage_events.size()):
		var event: Dictionary = stage_events[i]
		if str(event.get("condition", "")) != result_condition:
			continue
		if bool(event.get("once", true)) and bool(event.get("triggered", false)):
			continue
		event["triggered"] = true
		stage_events[i] = event
		trigger_stage_event(event)

func parse_vector2(text: String, fallback: Vector2) -> Vector2:
	var parts: PackedStringArray = text.split(",", false)
	if parts.size() < 2:
		return fallback

	return Vector2(float(parts[0]), float(parts[1]))

func parse_string_list(text: String) -> Array:
	var result: Array = []
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		return result

	var parts: PackedStringArray = clean_text.split("|", false)
	for part in parts:
		result.append(part.strip_edges())

	return result

func parse_int_list(text: String) -> Array[int]:
	var result: Array[int] = []
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		return result

	var parts: PackedStringArray = clean_text.split(",", false)
	for part in parts:
		result.append(int(part.strip_edges()))

	return result

func cleanup_lists() -> void:
	entities = entities.filter(func(item):
		return item != null and is_instance_valid(item)
	)

	projectiles = projectiles.filter(func(item):
		return item != null and is_instance_valid(item)
	)

	attack_instances = attack_instances.filter(func(item):
		return item != null and is_instance_valid(item)
	)

	drops = drops.filter(func(item):
		return item != null and is_instance_valid(item)
	)

func rebuild_entity_grid() -> void:
	entity_grid.clear()
	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead:
			continue
		var cell: Vector2i = get_entity_grid_cell(entity.global_position)
		var key: String = str(cell.x) + "_" + str(cell.y)
		if !entity_grid.has(key):
			entity_grid[key] = []
		entity_grid[key].append(entity)

func get_entity_grid_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / entity_grid_cell_size)), int(floor(pos.y / entity_grid_cell_size)))

func query_entities_near(pos: Vector2, radius: float) -> Array:
	if radius <= 0.0 or entity_grid.is_empty():
		return entities

	var min_cell: Vector2i = get_entity_grid_cell(pos - Vector2(radius, radius))
	var max_cell: Vector2i = get_entity_grid_cell(pos + Vector2(radius, radius))
	var result: Array = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var key: String = str(x) + "_" + str(y)
			if entity_grid.has(key):
				result.append_array(entity_grid[key])
	return result

func update_ui() -> void:
	if timer_label:
		timer_label.text = "时间 " + str(int(battle_time))

	if objective_label:
		objective_label.text = format_objective_text()

	if kill_label:
		kill_label.text = "击杀 " + str(enemy_kill_count)

	if level_label:
		level_label.text = "等级 " + str(player_level) + "  经验 " + str(player_xp) + "/" + str(player_xp_cap)

	update_mana_ui()

	if debug_label:
		var test_text: String = ""
		if test_mode:
			test_text = "\n测试：E切弹幕 Space发射 R刷敌 V测试阵 C切来源 B切技能2 1数量 2伤害 3范围 4冷却 5持续 6速度 Z重置\n当前 " + get_test_attack_label()
		debug_label.text = "单位 " + str(entities.size()) + "  旧弹 " + str(projectiles.size()) + "  新弹 " + str(attack_instances.size()) + "  掉落 " + str(drops.size()) + "\n玩家 " + format_entity_hp(player_entity) + "  携带 " + format_player_cargo() + "  Mana " + str(int(player_mana)) + "/" + str(int(player_mana_max)) + "  " + format_skill_debug() + "\n基地 " + format_base_bio() + "  敌方基地 " + format_entity_hp(enemy_base) + "  淫能奖励 +" + str(int(round(run_lust_reward_add))) + " x" + str(snapped(run_lust_reward_mul, 0.01)) + test_text

	if player_base_bar and tentacle_base != null and is_instance_valid(tentacle_base):
		player_base_bar.max_value = tentacle_base.max_hp
		player_base_bar.value = tentacle_base.hp

	if enemy_base_bar and enemy_base != null and is_instance_valid(enemy_base):
		enemy_base_bar.max_value = enemy_base.max_hp
		enemy_base_bar.value = enemy_base.hp
	update_base_queue_ui()

func update_mana_ui() -> void:
	if mana_bar != null:
		mana_bar.max_value = player_mana_max
		mana_bar.value = clamp(player_mana, 0.0, player_mana_max)
	if mana_label != null:
		var regen: float = player_mana_regen * run_mana_recovery_mul
		if player_entity != null and is_instance_valid(player_entity) and player_entity.has_method("get_status_mana_recovery_multiplier"):
			regen *= player_entity.get_status_mana_recovery_multiplier()
		mana_label.text = "Mana " + str(int(round(player_mana))) + "/" + str(int(round(player_mana_max))) + "  回复 " + str(snapped(regen, 0.1)) + "/s"

func format_objective_text() -> String:
	if battle_lost:
		return str(objective_label.text) if objective_label != null and str(objective_label.text).begins_with("失败") else "失败"
	if battle_won:
		return "目标完成"
	var text: String = objective_text
	if win_condition == "survive_time" and objective_duration > 0.0:
		text += " " + str(max(0, int(ceil(objective_duration - battle_time)))) + "s"
	elif win_condition == "hold_area" and objective_duration > 0.0:
		text += " " + str(int(objective_hold_time)) + "/" + str(int(objective_duration)) + "s"
	elif win_condition == "activate_areas":
		text += " " + str(objective_activated_areas.size()) + "/" + str(objective_area_ids.size())
	elif win_condition == "kill_count" and objective_target_count > 0:
		text += " " + str(enemy_kill_count) + "/" + str(objective_target_count)
	elif win_condition == "kill_entity_id" and objective_target_count > 0:
		text += " " + str(objective_progress_count) + "/" + str(objective_target_count)
	return "目标：" + text

func update_base_queue_ui() -> void:
	if base_queue_panel == null or base_queue_box == null:
		return
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		base_queue_panel.visible = false
		return

	var unlocked: Array = []
	for queue in tentacle_base.base_spawn_queues:
		if typeof(queue) == TYPE_DICTIONARY and bool(queue.get("unlocked", false)):
			unlocked.append(queue)

	base_queue_panel.visible = !unlocked.is_empty()
	if unlocked.is_empty():
		return

	for child in base_queue_box.get_children():
		base_queue_box.remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "基地生产队列"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.96, 1.0))
	base_queue_box.add_child(title)

	unlocked.sort_custom(func(a, b):
		var la: int = int(a.get("level", 0))
		var lb: int = int(b.get("level", 0))
		if la != lb:
			return la < lb
		return str(a.get("entity_id", a.get("id", ""))) < str(b.get("entity_id", b.get("id", "")))
	)
	for queue in unlocked:
		add_base_queue_ui_row(queue)

func add_base_queue_ui_row(queue: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(330, 32)
	base_queue_box.add_child(row)

	var entity_id: String = str(queue.get("entity_id", ""))
	var interval: float = max(0.1, float(queue.get("interval", 1.0)))
	if tentacle_base != null and is_instance_valid(tentacle_base) and tentacle_base.has_method("get_effective_queue_interval"):
		interval = tentacle_base.get_effective_queue_interval(queue)
	var progress: float = clamp(float(queue.get("progress", 0.0)) / interval, 0.0, 1.0)
	var label := Label.new()
	label.text = "Lv" + str(int(queue.get("level", 0))) + " " + get_entity_display_name(entity_id) + " x" + str(int(queue.get("quantity", 1))) + "  供能 " + str(int(queue.get("power_cost", queue.get("cost", 0))))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.96, 0.86, 1.0, 1.0))
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(330, 9)
	row.add_child(bar)

func format_entity_hp(entity) -> String:
	if entity == null or !is_instance_valid(entity):
		return "-"

	return str(int(entity.hp)) + "/" + str(int(entity.max_hp))

func format_player_cargo() -> String:
	if player_entity == null or !is_instance_valid(player_entity):
		return "-"

	return str(player_entity.bio_cargo) + "/" + str(player_entity.bio_cargo_max)

func format_base_bio() -> String:
	if tentacle_base == null or !is_instance_valid(tentacle_base):
		return "-"

	return "Lv" + str(tentacle_base.base_level) + " 生物质 " + str(int(tentacle_base.base_bio)) + "/" + str(int(tentacle_base.base_bio_cap))

func format_skill_debug() -> String:
	var parts: Array[String] = []
	for slot in [1, 2]:
		if !player_skills.has(slot):
			continue
		var skill: Dictionary = player_skills[slot]
		var skill_id: String = str(skill.get("id", ""))
		var cd: float = float(player_skill_cooldowns.get(skill_id, 0.0))
		parts.append("S" + str(slot) + ":" + str(skill.get("name", skill_id)) + "(" + str(snapped(cd, 0.1)) + ")")
	if active_channel_skill_id != "":
		parts.append("持续:" + active_channel_skill_id)
	return " ".join(parts)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_N:
			try_activate_skill_slot(1)
			return
		if event.keycode == KEY_2 or event.keycode == KEY_M:
			try_activate_skill_slot(2)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if level_choice_active or base_choice_active:
			return

	if !test_mode:
		return

	if event is InputEventKey and event.pressed and !event.echo:
		if event.keycode == KEY_R:
			spawn_test_enemies()
			return
		if event.keycode == KEY_SPACE:
			fire_current_test_attack()
			return
		if event.keycode == KEY_E:
			select_test_attack(1)
			return
		if event.keycode == KEY_C:
			select_test_source(1)
			return
		if event.keycode == KEY_B:
			select_test_skill2(1)
			return
		if event.keycode == KEY_V:
			spawn_super_test_layout()
			return
		if event.keycode == KEY_Z:
			reset_test_params()
			return

		adjust_test_param(event.keycode, Input.is_key_pressed(KEY_SHIFT))

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		fire_current_test_attack()

func spawn_test_enemies() -> void:
	var center: Vector2 = Vector2.ZERO
	if player_entity != null and is_instance_valid(player_entity):
		center = player_entity.get_global_mouse_position()
	elif battle_camera != null:
		center = battle_camera.global_position

	for i in range(test_spawn_count):
		var pos: Vector2 = center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, test_spawn_radius)
		spawn_entity(test_spawn_entity_id, clamp_to_map(pos))

func fire_test_attack(attack_id: String) -> void:
	var source = get_test_attack_source()
	if source == null or !is_instance_valid(source):
		return

	var attack: Dictionary = load_attack_data(attack_id)
	if attack.is_empty():
		return

	apply_test_modifiers(attack)
	spawn_attack(source, attack)

func fire_current_test_attack() -> void:
	if test_attack_ids.is_empty():
		return
	test_selected_attack_index = clamp(test_selected_attack_index, 0, test_attack_ids.size() - 1)
	fire_test_attack(str(test_attack_ids[test_selected_attack_index]))

func select_test_attack(step: int) -> void:
	if test_attack_ids.is_empty():
		return
	test_selected_attack_index = wrapi(test_selected_attack_index + step, 0, test_attack_ids.size())

func select_test_source(step: int) -> void:
	test_source_index = wrapi(test_source_index + step, 0, test_source_modes.size())

func select_test_skill2(step: int) -> void:
	test_skill2_index = wrapi(test_skill2_index + step, 0, test_skill2_ids.size())
	var skill_id: String = test_skill2_ids[test_skill2_index]
	var skill: Dictionary = load_skill_data(skill_id)
	if !skill.is_empty():
		player_skills[2] = skill
		player_skill_cooldowns[str(skill.get("id", skill_id))] = 0.0
		if player_entity != null and is_instance_valid(player_entity):
			spawn_floating_number(player_entity.global_position + Vector2(0.0, -80.0), "S2 " + str(skill.get("name", skill_id)), Color(0.6, 0.9, 1.0, 1.0))

func get_test_attack_source():
	var mode: String = str(test_source_modes[clamp(test_source_index, 0, test_source_modes.size() - 1)])
	if mode == "tentacle_base":
		return tentacle_base
	if mode == "enemy_base":
		return enemy_base
	if mode == "friendly_minion":
		return find_first_entity_by_filter("tentacle", "minion")
	if mode == "enemy":
		return find_first_entity_by_filter("enemy", "unit")
	return player_entity

func find_first_entity_by_filter(wanted_faction: String, wanted_type: String):
	for entity in entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity.is_dead:
			continue
		if wanted_faction != "" and entity.faction != wanted_faction:
			continue
		if wanted_type == "unit" and entity.is_building:
			continue
		if wanted_type != "" and wanted_type != "unit" and entity.entity_type != wanted_type:
			continue
		return entity
	return null

func spawn_super_test_layout() -> void:
	var center: Vector2 = Vector2.ZERO
	if player_entity != null and is_instance_valid(player_entity):
		center = player_entity.get_global_mouse_position()
	elif battle_camera != null:
		center = battle_camera.global_position

	spawn_entity("028", clamp_to_map(center + Vector2(-180.0, 0.0)), {"faction": "tentacle"})
	spawn_entity("013", clamp_to_map(center + Vector2(160.0, -80.0)), {"max_hp": 2000, "hp_regen": 8, "target_factions": "player|tentacle"})
	spawn_entity("013", clamp_to_map(center + Vector2(220.0, 80.0)), {"max_hp": 80, "target_factions": "player|tentacle"})
	spawn_entity("022", clamp_to_map(center + Vector2(-80.0, 150.0)), {"faction": "tentacle"})
	spawn_entity("003", clamp_to_map(center + Vector2(360.0, 0.0)), {"faction": "enemy", "max_hp": 12000, "hp_regen": 15})
	spawn_floating_number(center + Vector2(0.0, -120.0), "Test Set", Color(1.0, 0.78, 0.25, 1.0))

func reset_test_params() -> void:
	test_damage_mul = 1.0
	test_radius_mul = 1.0
	test_count_add = 0
	test_cooldown_mul = 1.0
	test_duration_mul = 1.0
	test_speed_mul = 1.0
	test_spawn_count = int(config.get_value("test", "spawn_count", 8))

func adjust_test_param(keycode: int, reverse: bool) -> void:
	var dir: float = -1.0 if reverse else 1.0
	if keycode == KEY_1:
		test_count_add = max(0, test_count_add + int(dir))
	elif keycode == KEY_2:
		test_damage_mul = max(0.1, test_damage_mul + 0.25 * dir)
	elif keycode == KEY_3:
		test_radius_mul = max(0.2, test_radius_mul + 0.25 * dir)
	elif keycode == KEY_4:
		test_cooldown_mul = max(0.1, test_cooldown_mul + 0.15 * dir)
	elif keycode == KEY_5:
		test_duration_mul = max(0.1, test_duration_mul + 0.25 * dir)
	elif keycode == KEY_6:
		test_speed_mul = max(0.1, test_speed_mul + 0.25 * dir)
	elif keycode == KEY_7:
		test_spawn_count = max(1, test_spawn_count + int(4.0 * dir))

func get_test_attack_label() -> String:
	if test_attack_ids.is_empty():
		return "-"
	var attack_id: String = str(test_attack_ids[clamp(test_selected_attack_index, 0, test_attack_ids.size() - 1)])
	return attack_id + "  数量+" + str(test_count_add) + "  伤害x" + str(snapped(test_damage_mul, 0.01)) + "  范围x" + str(snapped(test_radius_mul, 0.01)) + "  冷却x" + str(snapped(test_cooldown_mul, 0.01)) + "  持续x" + str(snapped(test_duration_mul, 0.01)) + "  速度x" + str(snapped(test_speed_mul, 0.01)) + "  刷怪" + str(test_spawn_count)

func apply_test_modifiers(attack: Dictionary) -> void:
	if attack.has("interval"):
		attack["interval"] = float(attack.get("interval", 1.0)) * test_cooldown_mul
	if attack.has("emitter") and typeof(attack["emitter"]) == TYPE_DICTIONARY:
		var emitter: Dictionary = attack["emitter"]
		emitter["count"] = max(1, int(emitter.get("count", 1)) + test_count_add)
	if attack.has("hit_shape") and typeof(attack["hit_shape"]) == TYPE_DICTIONARY:
		var shape: Dictionary = attack["hit_shape"]
		for key in ["radius", "width", "length"]:
			if shape.has(key):
				shape[key] = float(shape[key]) * test_radius_mul
	if attack.has("motion") and typeof(attack["motion"]) == TYPE_DICTIONARY:
		var motion: Dictionary = attack["motion"]
		for key in ["duration", "life_time"]:
			if motion.has(key):
				motion[key] = float(motion[key]) * test_duration_mul
		for key in ["speed", "orbit_speed"]:
			if motion.has(key):
				motion[key] = float(motion[key]) * test_speed_mul
	for effect in attack.get("effects", []):
		if typeof(effect) == TYPE_DICTIONARY:
			apply_test_effect_modifiers(effect)

func apply_test_effect_modifiers(effect: Dictionary) -> void:
	if effect.has("value") and (str(effect.get("mode", "")) == "damage" or str(effect.get("mode", "")) == "heal"):
		effect["value"] = float(effect["value"]) * test_damage_mul
	if effect.has("damage"):
		effect["damage"] = float(effect["damage"]) * test_damage_mul
	if effect.has("attack") and typeof(effect["attack"]) == TYPE_DICTIONARY:
		apply_test_modifiers(effect["attack"])
