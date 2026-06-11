extends Node2D

# Shared GIF frame cache for trash units. GIF resources are still the source art,
# but common enemies should not run one GIFPlayer/Control node per body.
static var shared_gif_frame_cache: Dictionary = {}

var visual_base_scale := Vector2.ONE
var facing_right := true

var director = null
var data: Dictionary = {}

var entity_id := ""
var faction := ""
var entity_type := ""
var tags: Array = []

var max_hp := 100.0
var hp := 100.0
var move_speed := 0.0
var attack_power := 10.0
var defense := 0.0
var hp_regen_per_second := 0.0
var regen_visual_timer := 0.0
var regen_visual_amount := 0.0
var damage_number_accum := 0.0
var damage_number_timer := 0.0
var damage_number_min_interval := 0.20


var radius := 20.0
var block_radius := 20.0
var sense_radius := 400.0
var is_building := false

var ai_mode := "idle"
var movement_mode := "direct"
var target_priority := "nearest"
var target_priority_order: Array = []
var target_distance_mode := "nearest"
var repath_interval := 0.35
var close_range := 120.0
var close_speed_mul := 1.0
var orbit_dir := 1.0
var objective_fallback := true
var objective_fallback_radius := 0.0
var objective_fallback_priority_order: Array = []
var leash_radius := 0.0
var target_factions: Array = []
var attacks: Array = []
var attack_cooldowns: Array[float] = []
var damage_multipliers: Dictionary = {}
var status_effects: Array[Dictionary] = []
var original_faction_before_control := ""
var original_target_factions_before_control: Array = []
var invincible := false
var contact_pause_timer := 0.0
var worker_home_radius := 0.0
var worker_state := "seek"
var worker_target_drop = null
var worker_wander_target := Vector2.ZERO
var worker_wander_timer := 0.0
var worker_delivery_target := Vector2.ZERO

var target = null
var target_scan_timer := 0.0

# Time-sliced AI movement. Target scan already has repath_interval, but avoidance/path steering
# used to run every physics frame for every unit. Cache the steering result and stagger
# recalculation across units so 100+ enemies do not all call avoid/grid checks in one frame.
var ai_steer_timer := 0.0
var ai_steer_interval := 0.12
var cached_ai_move_dir := Vector2.ZERO

# Swarm/flow AI. Most trash units can be cheap followers while only a few leaders
# run the full target/steering logic. This keeps the vampire-survivor swarm feeling
# without giving every body a full brain every frame.
var ai_role := "leader"
var ai_group_id := -1
var ai_group_key := ""
var ai_leader = null
var follower_recheck_timer := 0.0
var follower_recheck_interval := 0.45
var follower_attack_scan_timer := 0.0
var follower_attack_scan_interval := 0.28
var follower_attack_scan_radius := 240.0
var follower_keep_distance := 86.0
var follower_break_distance := 760.0
var follower_side_bias := 0.0
# Followers stay visually numerous, but they only run precise attack/contact logic
# when they are near a real threat. Far followers just move with the cached flow.
var follower_precision_active := false
var follower_precision_timer := 0.0
var follower_precision_interval := 0.22
var follower_precision_radius := 260.0
var follower_last_flow_dir := Vector2.ZERO
# Soft horde spacing. This is not hard physics collision; it is a cheap visual/logic
# pressure used only by follower trash so hundreds of bodies do not collapse into
# one pixel pile around the player/base. It is sampled at low frequency and then
# cached, so it should not reintroduce N^2 scans.
var follower_spacing_timer := 0.0
var follower_spacing_interval := 0.14
var follower_spacing_radius := 54.0
var follower_spacing_strength := 1.15
var follower_spacing_max_neighbors := 8
var follower_spacing_push := Vector2.ZERO
var follower_target_standoff := 58.0
var follower_target_standoff_strength := 0.75
var follower_orbit_slot_angle := 0.0
var follower_orbit_radius_bias := 0.0

# Non-player attack logic does not need to check cooldown/target every physics frame.
# This is especially important when hundreds of trash bodies are close to the player/base.
var attack_logic_timer := 0.0
var attack_logic_interval := 0.12
var attack_logic_accum := 0.0

# GIF/visual LOD. Trash followers can keep moving as nodes while their GIFPlayer
# is frozen on a static frame when the battle is crowded and they are not in
# precise combat. This preserves the GIF art format but avoids 100+ independent
# GIF players advancing frames every tick.
var gif_lod_timer := 0.0
var gif_lod_interval := 0.18
var gif_static_lod_active := false
var gif_lod_entity_threshold := 90
var gif_lod_precise_radius := 360.0

# Lightweight shared-GIF sprite runtime. For minor units this replaces GIFPlayer
# with a Sprite2D using frames extracted from GIFTexture once per GIF path.
var visual_is_shared_gif_sprite := false
var shared_gif_path := ""
var shared_gif_frame_textures: Array = []
var shared_gif_frame_delays: Array = []
var shared_gif_total_duration := 0.0
var shared_gif_frame_index := -1
var shared_gif_anim_timer := 0.0
var shared_gif_anim_interval := 0.05
# Optional batch drawing: when crowded, far follower trash units hide their own
# Sprite2D and are rendered by one shared batch node in BattleDirector. This
# keeps GIF art and logic, but removes many Sprite2D CanvasItems from the tree.
var batch_shared_gif_visual_active := false
var batch_shared_gif_visual_dirty := false
var batch_shared_gif_visual_parent: Node = null

var is_dead := false
var last_move_position := Vector2.ZERO
var stuck_timer := 0.0
var forced_avoid_timer := 0.0
var forced_avoid_side := 1.0

var visual_holder: Node2D = null
var visual = null
var visual_size := Vector2(64.0, 64.0)
var visual_fx_config: Dictionary = {}
var visual_stage_config: Dictionary = {}
var visual_fx_nodes: Array = []
var visual_fx_phase := 0.0
var visual_attachment_config: Array = []
var visual_attachment_nodes: Dictionary = {}
var attack_sfx: AudioStreamPlayer = null
var hurt_sfx: AudioStreamPlayer = null
var die_sfx: AudioStreamPlayer = null

var health_bar_root: Node2D = null
var health_bar_back: ColorRect = null
var health_bar_fill: ColorRect = null
var hit_flash_timer := 0.0
var force_hide_health_bar := false

var alert_ring: Line2D = null
var alert_radius := 0.0
var delivery_ring: Line2D = null
var delivery_radius := 0.0
var delivery_offset := Vector2.ZERO
var delivery_texture_path := ""
var delivery_visual = null
var contact_ring: Line2D = null
var contact_radius := 0.0
var contact_damage := 0.0
var contact_cooldown := 1.0
var contact_knockback_min := 80.0
var contact_knockback_max := 150.0
var contact_timers: Dictionary = {}
var contact_statuses: Array = []
var contact_execute_chance := 0.0
var contact_execute_hp_ratio := 0.0

var bio_cargo: int = 0
var bio_cargo_max: int = 20
var bio_visual_unit: int = 10
var bio_transfer_chunk: int = 10
var bio_stack_root: Node2D = null
var bio_texture_path := "res://scenes/Battle/Battle_00/Bio.png"
var bio_transfer_timer := 0.0
var bio_transfer_interval := 0.07
var base_progress_root: Node2D = null
var base_progress_fill: ColorRect = null
var base_progress_label: Label = null

var base_bio: float = 0.0
var base_bio_cap: float = 120.0
var base_level: int = 1
var base_max_level: int = 3
var base_upgrade_thresholds: Array = [60, 120]
var base_upgrade_cd: float = 12.0
var base_upgrade_timer: float = 0.0
var base_passive_bio_per_second: float = 0.0
var base_level_passive_bio: Array = [0, 10, 15]
var base_can_spawn_level: int = 3
var base_spawn_entity_id: String = "004"
var base_spawn_cost: float = 40.0
var base_spawn_interval: float = 1.5
var base_spawn_timer: float = 0.0
var base_spawn_radius: float = 180.0
var base_spawn_queues: Array = []
var base_level_config: Array = []
var base_low_power_queue_speed := 0.5
var base_low_power_upgrade_speed := 0.2
var base_bio_cycle_timer := 0.0
var base_bio_cycle_interval := 5.0
var base_bio_cycle_amounts: Array = []
var base_pending_upgrade_choice := false
var base_aura_speed_mul := 1.0
var base_aura_regen_add := 0.0
var base_spawn_enemy_base_damage := 0.0
var mutation_gift_enabled := false
var mutation_gift_chance_base := 0.0
var mutation_gift_chance_per_level := 0.0
var mutation_gift_entity_ids: Array = []
var death_attack: Dictionary = {}
var low_hp_attack_damage_mul := 1.0
var low_hp_attack_threshold := 0.35

func setup(new_director, new_data: Dictionary) -> void:
	director = new_director
	data = new_data

	entity_id = str(data.get("id", ""))
	faction = str(data.get("faction", "neutral"))
	entity_type = str(data.get("type", "unit"))
	tags = data.get("tags", [])
	is_building = entity_type == "base" or tags.has("building") or tags.has("base")

	var stats: Dictionary = data.get("stats", {})
	max_hp = float(stats.get("max_hp", 100.0))
	hp = max_hp
	move_speed = float(stats.get("move_speed", 0.0))
	attack_power = float(stats.get("attack", 10.0))
	defense = float(stats.get("defense", 0.0))
	hp_regen_per_second = float(stats.get("hp_regen", stats.get("hp_regen_per_second", 0.0)))
	bio_cargo_max = int(stats.get("bio_cargo_max", bio_cargo_max))
	bio_visual_unit = max(1, int(stats.get("bio_visual_unit", bio_visual_unit)))
	bio_transfer_chunk = max(1, int(stats.get("bio_transfer_chunk", bio_visual_unit)))
	invincible = bool(stats.get("invincible", false))
	worker_home_radius = float(stats.get("worker_home_radius", 0.0))

	var body: Dictionary = data.get("body", {})
	radius = float(body.get("radius", 20.0))
	block_radius = float(body.get("block_radius", radius))
	sense_radius = float(body.get("sense_radius", 400.0))

	var ai: Dictionary = data.get("ai", {})
	ai_mode = str(ai.get("mode", "idle"))
	movement_mode = str(ai.get("movement_mode", "direct"))
	target_priority = str(ai.get("target_priority", "nearest"))
	target_priority_order = ai.get("target_priority_order", [])
	target_distance_mode = str(ai.get("target_distance_mode", "nearest"))
	if target_priority_order.is_empty():
		target_priority_order = get_legacy_target_priority_order(target_priority)
	repath_interval = float(ai.get("repath_interval", 0.35))
	# Spread first target scans instead of making every spawned unit think on the same frame.
	target_scan_timer = randf() * max(repath_interval, 0.05)
	# Steering/avoidance can be lower-frequency than movement. The unit still moves every frame
	# using cached direction; only expensive avoid calculations are staggered.
	ai_steer_interval = float(ai.get("steer_interval", randf_range(0.10, 0.22)))
	ai_steer_timer = randf() * max(ai_steer_interval, 0.03)
	ai_role = str(ai.get("role", ai.get("ai_role", ai_role)))
	ai_group_id = int(ai.get("group_id", ai.get("ai_group_id", ai_group_id)))
	ai_group_key = str(ai.get("group_key", ai.get("ai_group_key", ai_group_key)))
	follower_recheck_interval = float(ai.get("follower_recheck_interval", randf_range(0.36, 0.72)))
	follower_recheck_timer = randf() * max(follower_recheck_interval, 0.05)
	follower_attack_scan_interval = float(ai.get("follower_attack_scan_interval", randf_range(0.22, 0.42)))
	follower_attack_scan_timer = randf() * max(follower_attack_scan_interval, 0.05)
	follower_attack_scan_radius = float(ai.get("follower_attack_scan_radius", follower_attack_scan_radius))
	follower_precision_radius = float(ai.get("follower_precision_radius", max(160.0, follower_attack_scan_radius)))
	follower_precision_interval = float(ai.get("follower_precision_interval", randf_range(0.18, 0.36)))
	follower_precision_timer = randf() * max(follower_precision_interval, 0.05)
	follower_keep_distance = float(ai.get("follower_keep_distance", randf_range(58.0, 118.0)))
	follower_break_distance = float(ai.get("follower_break_distance", follower_break_distance))
	follower_spacing_interval = float(ai.get("follower_spacing_interval", randf_range(0.10, 0.20)))
	follower_spacing_timer = randf() * max(follower_spacing_interval, 0.05)
	follower_spacing_radius = float(ai.get("follower_spacing_radius", max(58.0, min(96.0, radius * 2.35))))
	follower_spacing_strength = float(ai.get("follower_spacing_strength", max(follower_spacing_strength, 1.45)))
	follower_spacing_max_neighbors = int(ai.get("follower_spacing_max_neighbors", follower_spacing_max_neighbors))
	follower_target_standoff = float(ai.get("follower_target_standoff", max(68.0, radius * 2.35)))
	follower_target_standoff_strength = float(ai.get("follower_target_standoff_strength", max(follower_target_standoff_strength, 1.05)))
	follower_side_bias = randf_range(-1.0, 1.0)
	# Stable ring slot around targets. This makes follower hordes look like a flow/cloud
	# instead of every trash unit aiming for the exact same target center.
	var slot_seed: int = int(abs(hash(str(ai_group_id) + ":" + str(get_instance_id()))))
	follower_orbit_slot_angle = fmod(float(slot_seed % 4096) / 4096.0 * TAU + randf_range(-0.10, 0.10), TAU)
	follower_orbit_radius_bias = randf_range(-0.18, 0.28)
	attack_logic_interval = float(ai.get("attack_logic_interval", 0.0))
	if attack_logic_interval <= 0.0:
		attack_logic_interval = randf_range(0.16, 0.28) if ai_role == "follower" else randf_range(0.08, 0.16)
	attack_logic_timer = randf() * max(attack_logic_interval, 0.04)
	attack_logic_accum = 0.0
	if ai_role == "follower":
		# Followers should be much cheaper than leaders. They still move every frame,
		# but expensive local target pickup is low frequency and staggered.
		repath_interval = max(repath_interval, follower_recheck_interval)
		ai_steer_interval = max(ai_steer_interval, 0.20)
	close_range = float(ai.get("close_range", 120.0))
	close_speed_mul = float(ai.get("close_speed_mul", 1.0))
	orbit_dir = -1.0 if bool(ai.get("orbit_clockwise", false)) else 1.0
	objective_fallback = bool(ai.get("objective_fallback", objective_fallback))
	objective_fallback_radius = float(ai.get("objective_fallback_radius", objective_fallback_radius))
	objective_fallback_priority_order = ai.get("objective_fallback_priority_order", [])
	leash_radius = float(ai.get("leash_radius", leash_radius))
	target_factions = ai.get("target_factions", [])

	var combat: Dictionary = data.get("combat", {})
	damage_multipliers = combat.get("damage_multipliers", {})

	setup_base_system()
	visual_fx_config = data.get("visual_fx", {})
	visual_stage_config = data.get("visual_stages", {})
	visual_attachment_config = data.get("visual_attachments", [])

	attacks = data.get("attacks", [])
	attack_cooldowns.clear()
	for attack in attacks:
		attack_cooldowns.append(randf() * float(attack.get("interval", 1.0)))

	create_visual()
	create_sfx()
	create_bio_stack()
	create_configured_visual_fx()
	create_configured_visual_attachments(1)
	last_move_position = global_position

func add_attack(attack: Dictionary) -> void:
	if attack.is_empty():
		return

	attacks.append(attack)
	attack_cooldowns.append(0.05)

func set_attacks(new_attacks: Array) -> void:
	attacks.clear()
	attack_cooldowns.clear()
	for attack in new_attacks:
		if typeof(attack) != TYPE_DICTIONARY:
			continue
		attacks.append(attack)
		attack_cooldowns.append(0.05)

func multiply_max_hp(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	var ratio: float = 1.0
	if max_hp > 0.0:
		ratio = hp / max_hp
	max_hp *= multiplier
	hp = max_hp * ratio

func multiply_regen(multiplier: float) -> void:
	hp_regen_per_second *= multiplier

func set_health_bar_hidden(should_hide: bool) -> void:
	force_hide_health_bar = should_hide
	if health_bar_root != null:
		health_bar_root.visible = false

func apply_upgrade(upgrade: Dictionary) -> void:
	if upgrade.is_empty():
		return

	var mode: String = str(upgrade.get("upgrade_mode", "add_attack"))
	if mode == "add_attack":
		add_attack(upgrade)
		return

	if mode == "modify_attacks":
		modify_attacks(upgrade)
		return

	if mode == "add_effect_to_attacks":
		add_effect_to_attacks(upgrade)
		return

func modify_attacks(upgrade: Dictionary) -> void:
	var selector: Dictionary = upgrade.get("selector", {})
	var modifiers: Array = upgrade.get("modifiers", [])

	for attack in attacks:
		if !attack_matches_selector(attack, selector):
			continue

		for modifier in modifiers:
			if typeof(modifier) != TYPE_DICTIONARY:
				continue
			apply_attack_modifier(attack, modifier)

func add_effect_to_attacks(upgrade: Dictionary) -> void:
	var selector: Dictionary = upgrade.get("selector", {})
	var effect: Dictionary = upgrade.get("effect", {})
	if effect.is_empty():
		return

	for attack in attacks:
		if !attack_matches_selector(attack, selector):
			continue

		var effects: Array = attack.get("effects", [])
		effects.append(effect.duplicate(true))
		attack["effects"] = effects

func attack_matches_selector(attack: Dictionary, selector: Dictionary) -> bool:
	if selector.is_empty():
		return true

	if selector.has("kind") and str(attack.get("kind", "")) != str(selector.get("kind", "")):
		return false

	if selector.has("id") and str(attack.get("id", "")) != str(selector.get("id", "")):
		return false

	if selector.has("tag"):
		var attack_tags: Array = attack.get("tags", [])
		if !attack_tags.has(str(selector.get("tag", ""))):
			return false

	return true

func apply_attack_modifier(attack: Dictionary, modifier: Dictionary) -> void:
	var path: String = str(modifier.get("path", ""))
	if path == "":
		return

	var op: String = str(modifier.get("op", "add"))
	var value = modifier.get("value", 0.0)
	var current = get_nested_value(attack, path, 0.0)

	if op == "mul":
		set_nested_value(attack, path, float(current) * float(value))
	elif op == "set":
		set_nested_value(attack, path, value)
	else:
		set_nested_value(attack, path, float(current) + float(value))

func get_nested_value(dict: Dictionary, path: String, fallback):
	var parts: PackedStringArray = path.split(".", false)
	var current = dict
	for part in parts:
		if typeof(current) != TYPE_DICTIONARY:
			return fallback
		if !current.has(part):
			return fallback
		current = current[part]
	return current

func set_nested_value(dict: Dictionary, path: String, value) -> void:
	var parts: PackedStringArray = path.split(".", false)
	var current = dict
	for i in range(parts.size()):
		var part: String = parts[i]
		if i == parts.size() - 1:
			current[part] = value
			return
		if !current.has(part) or typeof(current[part]) != TYPE_DICTIONARY:
			current[part] = {}
		current = current[part]

func get_facing_direction() -> Vector2:
	return Vector2.RIGHT if facing_right else Vector2.LEFT

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_target(delta)
	update_movement(delta)
	update_follower_precision_state(delta)
	update_shared_gif_sprite_animation(delta)
	update_visual_lod(delta)
	update_shared_gif_batch_visual_state()
	update_damage_number_queue(delta)
	update_attacks(delta)
	update_regen(delta)
	update_status_effects(delta)
	update_status_visuals(delta)
	z_index = int(global_position.y)

func update_regen(delta: float) -> void:
	if hp_regen_per_second <= 0.0:
		return

	if hp >= max_hp:
		regen_visual_timer = 0.0
		regen_visual_amount = 0.0
		return

	var before_hp: float = hp
	heal(hp_regen_per_second * delta, self, false)
	var healed: float = hp - before_hp
	if healed <= 0.0:
		return

	regen_visual_amount += healed
	regen_visual_timer -= delta
	if regen_visual_timer <= 0.0 and regen_visual_amount >= 1.0 and director != null:
		regen_visual_timer = 1.0
		director.spawn_floating_number(global_position + Vector2(0.0, -radius - 38.0), "+" + str(int(round(regen_visual_amount))), Color(0.45, 1.0, 0.74, 1.0))
		regen_visual_amount = 0.0

func add_status_effect(effect: Dictionary, source = null) -> void:
	if is_dead:
		return

	var status: Dictionary = effect.duplicate(true)
	status["source"] = source
	status["time_left"] = float(status.get("duration", 1.0))
	status["tick_timer"] = 0.0
	var incoming_status_type: String = str(status.get("status", status.get("status_type", "")))
	for i in range(status_effects.size()):
		var existing: Dictionary = status_effects[i]
		var existing_type: String = str(existing.get("status", existing.get("status_type", "")))
		if existing_type == incoming_status_type and existing.get("source", null) == source:
			existing["time_left"] = max(float(existing.get("time_left", 0.0)), float(status["time_left"]))
			for key in ["speed_mul", "slow_mul", "attack_damage_mul", "attack_interval_mul", "damage_taken_mul", "skill_damage_mul", "mana_recovery_mul"]:
				if status.has(key):
					existing[key] = status[key]
			status_effects[i] = existing
			return
	if str(status.get("status", status.get("status_type", ""))) == "control":
		status["original_faction"] = faction
		status["original_target_factions"] = target_factions.duplicate()
		if source != null and is_instance_valid(source):
			original_faction_before_control = faction
			original_target_factions_before_control = target_factions.duplicate()
			faction = source.faction
			target_factions = ["enemy"]
			target = null
			target_scan_timer = 0.0
	status_effects.append(status)

func update_status_effects(delta: float) -> void:
	if status_effects.is_empty():
		return

	for i in range(status_effects.size() - 1, -1, -1):
		var status: Dictionary = status_effects[i]
		var status_type: String = str(status.get("status", status.get("status_type", "")))
		status["time_left"] = float(status.get("time_left", 0.0)) - delta

		if status_type == "poison" or status_type == "burn" or status_type == "bleed":
			status["tick_timer"] = float(status.get("tick_timer", 0.0)) - delta
			if float(status["tick_timer"]) <= 0.0:
				status["tick_timer"] = float(status.get("tick_interval", 0.5))
				var source = status.get("source", null)
				take_damage(float(status.get("value", 1.0)), source)

		if float(status["time_left"]) <= 0.0:
			if status_type == "control" and status.has("original_faction"):
				faction = str(status.get("original_faction", faction))
				target_factions = status.get("original_target_factions", target_factions)
				target = null
				target_scan_timer = 0.0
			status_effects.remove_at(i)
		else:
			status_effects[i] = status


func should_use_shared_gif_sprite(visual_data: Dictionary, texture_path: String) -> bool:
	if texture_path.get_extension().to_lower() != "gif":
		return false
	if bool(visual_data.get("force_gif_player", false)):
		return false
	if bool(visual_data.get("use_shared_gif_sprite", false)):
		return true
	# Default: cheap runtime for repeated trash bodies. Keep important/special
	# actors on GIFPlayer so their custom UI/control behavior is untouched.
	if entity_type == "player" or entity_type == "base" or is_building:
		return false
	if tags.has("building") or tags.has("base") or tags.has("boss") or tags.has("elite") or tags.has("worker"):
		return false
	return true

static func get_shared_gif_cache(texture_path: String) -> Dictionary:
	if shared_gif_frame_cache.has(texture_path):
		return shared_gif_frame_cache[texture_path]

	var result: Dictionary = {
		"frames": [],
		"delays": [],
		"duration": 0.0,
		"size": Vector2.ZERO
	}
	var gif_texture = load(texture_path)
	if gif_texture == null:
		shared_gif_frame_cache[texture_path] = result
		return result
	if !gif_texture.has_method("get_frame_count"):
		shared_gif_frame_cache[texture_path] = result
		return result

	var frame_count: int = int(gif_texture.call("get_frame_count"))
	if frame_count <= 0:
		shared_gif_frame_cache[texture_path] = result
		return result

	var frames: Array = []
	var delays: Array = []
	var duration := 0.0
	for i in range(frame_count):
		var frame_tex = null
		if gif_texture.has_method("get_frame_texture"):
			frame_tex = gif_texture.call("get_frame_texture", i)
		elif gif_texture.has_method("get_frame"):
			frame_tex = gif_texture.call("get_frame", i)
		if frame_tex == null:
			continue
		frames.append(frame_tex)
		var delay := 0.10
		if gif_texture.has_method("get_frame_delay"):
			delay = float(gif_texture.call("get_frame_delay", i))
		elif gif_texture.has_method("get_delay"):
			delay = float(gif_texture.call("get_delay", i))
		delay = clamp(delay, 0.04, 0.35)
		delays.append(delay)
		duration += delay

	var raw_size := Vector2.ZERO
	if frames.size() > 0 and frames[0] != null and frames[0].has_method("get_size"):
		raw_size = frames[0].get_size()
	result["frames"] = frames
	result["delays"] = delays
	result["duration"] = max(duration, 0.05)
	result["size"] = raw_size
	shared_gif_frame_cache[texture_path] = result
	return result

func create_shared_gif_sprite_visual(texture_path: String, visual_data: Dictionary, max_size: Vector2) -> bool:
	var cache: Dictionary = get_shared_gif_cache(texture_path)
	var frames: Array = cache.get("frames", [])
	if frames.is_empty():
		return false

	visual_is_shared_gif_sprite = true
	shared_gif_path = texture_path
	shared_gif_frame_textures = frames
	shared_gif_frame_delays = cache.get("delays", [])
	shared_gif_total_duration = float(cache.get("duration", 0.1))
	shared_gif_frame_index = -1

	visual = Sprite2D.new()
	visual.name = "SharedGifSprite"
	visual_holder.add_child(visual)
	visual.centered = true
	visual.texture = frames[0]

	var raw_size: Vector2 = cache.get("size", Vector2.ZERO)
	if raw_size.x <= 0.0 or raw_size.y <= 0.0:
		raw_size = frames[0].get_size()
	visual_size = raw_size
	if max_size.x > 0.0 and max_size.y > 0.0 and raw_size.x > 0.0 and raw_size.y > 0.0:
		var fit_scale: float = min(max_size.x / raw_size.x, max_size.y / raw_size.y)
		visual.scale = Vector2.ONE * fit_scale
		visual_size = raw_size * fit_scale
	else:
		visual.scale = Vector2.ONE
	visual.position = Vector2.ZERO
	apply_body_centered_visual_position(visual_data)
	update_shared_gif_sprite_animation(999.0)
	return true

func get_shared_gif_frame_index_at_time(t: float) -> int:
	if shared_gif_frame_textures.is_empty():
		return -1
	if shared_gif_frame_delays.is_empty() or shared_gif_total_duration <= 0.0:
		return int(floor(t / 0.10)) % shared_gif_frame_textures.size()
	var local_t := fmod(max(t, 0.0), shared_gif_total_duration)
	var acc := 0.0
	for i in range(shared_gif_frame_delays.size()):
		acc += float(shared_gif_frame_delays[i])
		if local_t <= acc:
			return clamp(i, 0, shared_gif_frame_textures.size() - 1)
	return shared_gif_frame_textures.size() - 1

func update_shared_gif_sprite_animation(delta: float) -> void:
	if !visual_is_shared_gif_sprite or shared_gif_frame_textures.is_empty():
		return
	if is_swarm_visual_sleeping():
		return
	shared_gif_anim_timer -= delta
	if shared_gif_anim_timer > 0.0:
		return
	shared_gif_anim_timer = shared_gif_anim_interval
	var clock := Time.get_ticks_msec() / 1000.0
	# Use one shared clock per GIF path. Same-type trash units no longer each own
	# an independent animation timer; they simply sample the same loop.
	var idx := get_shared_gif_frame_index_at_time(clock)
	if idx < 0 or idx == shared_gif_frame_index:
		return
	shared_gif_frame_index = idx
	# When this entity is batch-drawn, do not touch the hidden Sprite2D texture.
	# The batch renderer samples the same shared frame cache directly.
	if !batch_shared_gif_visual_active and visual != null:
		visual.texture = shared_gif_frame_textures[idx]

func update_shared_gif_batch_visual_state() -> void:
	if !visual_is_shared_gif_sprite:
		return
	var should_batch := false
	if director != null and director.has_method("should_batch_shared_gif_entity"):
		should_batch = bool(director.call("should_batch_shared_gif_entity", self))
	if should_batch == batch_shared_gif_visual_active:
		return
	batch_shared_gif_visual_active = should_batch
	set_shared_gif_sprite_in_batch_tree(batch_shared_gif_visual_active)
	if director != null and director.has_method("mark_shared_gif_batch_dirty"):
		director.call("mark_shared_gif_batch_dirty")

func set_shared_gif_sprite_in_batch_tree(should_batch: bool) -> void:
	if visual == null or !is_instance_valid(visual):
		return
	if should_batch:
		# Hiding a CanvasItem avoids drawing, but the node is still in the SceneTree.
		# Removing the per-unit Sprite2D while the batch renderer draws it cuts more
		# CanvasItem traversal cost when hundreds of trash units are visible.
		var current_parent: Node = visual.get_parent()
		if current_parent != null:
			batch_shared_gif_visual_parent = current_parent
			current_parent.remove_child(visual)
		visual.visible = false
	else:
		var current_parent_restore: Node = visual.get_parent()
		if current_parent_restore == null:
			var restore_parent: Node = batch_shared_gif_visual_parent
			if restore_parent == null or !is_instance_valid(restore_parent):
				restore_parent = visual_holder
			if restore_parent != null and is_instance_valid(restore_parent):
				restore_parent.add_child(visual)
		visual.visible = true

func get_shared_gif_batch_texture():
	if !visual_is_shared_gif_sprite or shared_gif_frame_textures.is_empty():
		return null
	var idx := shared_gif_frame_index
	if idx < 0 or idx >= shared_gif_frame_textures.size():
		idx = get_shared_gif_frame_index_at_time(Time.get_ticks_msec() / 1000.0)
	if idx < 0 or idx >= shared_gif_frame_textures.size():
		idx = 0
	return shared_gif_frame_textures[idx]

func get_shared_gif_batch_size() -> Vector2:
	return visual_size

func is_batch_shared_gif_visible() -> bool:
	return visual_is_shared_gif_sprite and batch_shared_gif_visual_active and !is_dead

func should_center_visual_on_body(visual_data: Dictionary = {}) -> bool:
	if visual_data.has("center_on_body"):
		return bool(visual_data.get("center_on_body", false))
	var base_visual: Dictionary = data.get("visual", {})
	return bool(base_visual.get("center_on_body", false))

func get_body_center_fit_radius(visual_data: Dictionary) -> float:
	var base_visual: Dictionary = data.get("visual", {})
	var radius_key: String = str(visual_data.get("fit_inside_radius", base_visual.get("fit_inside_radius", "contact_radius")))
	var zones: Dictionary = data.get("zones", {})
	if radius_key == "contact_radius":
		return float(zones.get("contact_radius", radius))
	if radius_key == "block_radius":
		return block_radius
	if radius_key == "body_radius" or radius_key == "radius":
		return radius
	return float(zones.get(radius_key, radius))

func get_body_safe_visual_max_size(visual_data: Dictionary, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var configured_max: Vector2 = get_config_vector2(visual_data.get("max_size", []), fallback)
	if !should_center_visual_on_body(visual_data):
		return configured_max

	var base_visual: Dictionary = data.get("visual", {})
	var margin: float = float(visual_data.get("fit_inside_body_margin", base_visual.get("fit_inside_body_margin", 10.0)))
	var fit_radius: float = get_body_center_fit_radius(visual_data)
	var safe_diameter: float = max(1.0, (fit_radius - margin) * 2.0)
	var safe_max := Vector2(safe_diameter, safe_diameter)

	if configured_max.x <= 0.0 or configured_max.y <= 0.0:
		return safe_max

	return Vector2(min(configured_max.x, safe_max.x), min(configured_max.y, safe_max.y))

func configure_gif_player_for_explicit_size(gif_node) -> void:
	if gif_node == null:
		return
	# GIFPlayer is a TextureRect-like control in this project. To make size actually affect
	# the drawn GIF, it must use Expand Mode = IgnoreSize and Stretch Mode = Scale.
	# These are the Godot enum values used by TextureRect:
	#   EXPAND_IGNORE_SIZE = 1
	#   STRETCH_SCALE = 0
	gif_node.set("expand_mode", 1)
	gif_node.set("stretch_mode", 0)
	gif_node.scale = Vector2.ONE

func apply_centered_gif_layout(gif_node, target_size: Vector2) -> void:
	if gif_node == null:
		return
	var raw_size: Vector2 = gif_node.size
	if raw_size.x <= 0.0 or raw_size.y <= 0.0:
		raw_size = target_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = raw_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return
	configure_gif_player_for_explicit_size(gif_node)
	gif_node.size = target_size
	gif_node.position = -target_size * 0.5
	visual_size = target_size

func apply_body_centered_visual_position(visual_data: Dictionary) -> void:
	if !should_center_visual_on_body(visual_data):
		return
	if visual_holder != null:
		visual_holder.position = Vector2.ZERO
		visual_holder.scale = Vector2.ONE
		visual_base_scale = Vector2.ONE
	if visual == null:
		return
	if visual is Sprite2D:
		visual.centered = true
		visual.offset = Vector2.ZERO
		visual.position = Vector2.ZERO
	else:
		apply_centered_gif_layout(visual, visual_size)

func create_visual() -> void:
	var visual_data: Dictionary = data.get("visual", {})
	var texture_path: String = str(visual_data.get("gif", visual_data.get("texture", "")))

	if texture_path == "":
		return

	var scale_value: float = float(visual_data.get("scale", 1.0))
	var offset_array = visual_data.get("offset", [0, 0])
	var offset: Vector2 = Vector2.ZERO

	if offset_array is Array and offset_array.size() >= 2:
		offset = Vector2(float(offset_array[0]), float(offset_array[1]))

	visual_size = get_config_vector2(visual_data.get("size", []), Vector2(64.0, 64.0))
	var max_size: Vector2 = get_body_safe_visual_max_size(visual_data, Vector2.ZERO)
	visual_holder = Node2D.new()
	visual_holder.name = "VisualHolder"
	add_child(visual_holder)
	visual_holder.position = offset
	if should_center_visual_on_body(visual_data):
		visual_holder.position = Vector2.ZERO
	visual_holder.scale = Vector2.ONE * scale_value
	visual_base_scale = visual_holder.scale

	if texture_path.get_extension().to_lower() == "gif":
		if should_use_shared_gif_sprite(visual_data, texture_path):
			if create_shared_gif_sprite_visual(texture_path, visual_data, max_size):
				apply_visual_shader()
				create_health_bar()
				create_zone_rings()
				return

		visual = GIFPlayer.new()
		visual_holder.add_child(visual)
		visual.gif = load(texture_path)
		var raw_gif_size: Vector2 = visual.size
		if raw_gif_size.x > 0.0 and raw_gif_size.y > 0.0:
			visual_size = raw_gif_size
		var target_gif_size: Vector2 = visual_size
		if max_size.x > 0.0 and max_size.y > 0.0 and visual_size.x > 0.0 and visual_size.y > 0.0:
			var fit_scale: float = min(max_size.x / visual_size.x, max_size.y / visual_size.y)
			target_gif_size = visual_size * fit_scale
		if should_center_visual_on_body(visual_data):
			apply_centered_gif_layout(visual, target_gif_size)
		else:
			visual_size = target_gif_size
			configure_gif_player_for_explicit_size(visual)
			visual.size = visual_size
			visual.position = -visual_size * 0.5
		apply_visual_shader()
		create_health_bar()
		create_zone_rings()
		return

	visual = Sprite2D.new()
	visual_holder.add_child(visual)

	var texture = load(texture_path)
	if texture:
		visual.texture = texture
		visual_size = texture.get_size()
		if max_size.x > 0.0 and max_size.y > 0.0 and visual_size.x > 0.0 and visual_size.y > 0.0:
			var sprite_fit_scale: float = min(max_size.x / visual_size.x, max_size.y / visual_size.y)
			visual.scale = Vector2.ONE * sprite_fit_scale
			visual_size *= sprite_fit_scale

	visual.centered = true
	visual.position = Vector2.ZERO
	apply_body_centered_visual_position(visual_data)
	apply_visual_shader()
	create_health_bar()
	create_zone_rings()

func update_facing(move_dir: Vector2) -> void:
	if visual == null:
		return

	if abs(move_dir.x) < 0.01:
		return

	facing_right = move_dir.x > 0.0

	if visual_holder == null:
		return

	if visual is Sprite2D:
		visual.flip_h = !facing_right
	else:
		visual_holder.scale.x = abs(visual_base_scale.x) if facing_right else -abs(visual_base_scale.x)

	if entity_type == "player":
		update_bio_stack_visual()

func get_attack_point(mode: String, custom_offset = [0, 0]) -> Vector2:
	var scale_abs: Vector2 = Vector2(abs(visual_base_scale.x), abs(visual_base_scale.y))
	var half: Vector2 = visual_size * 0.5 * scale_abs
	var local: Vector2 = Vector2.ZERO

	if mode == "top":
		local = Vector2(0.0, -half.y)
	elif mode == "bottom":
		local = Vector2(0.0, half.y)
	elif mode == "left":
		local = Vector2(-half.x, 0.0)
	elif mode == "right":
		local = Vector2(half.x, 0.0)
	elif mode == "custom":
		local = get_config_vector2(custom_offset, Vector2.ZERO)
	else:
		local = Vector2.ZERO

	if !facing_right and mode == "custom":
		local.x = -local.x

	return global_position + local

func get_config_vector2(value, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	return fallback

func parse_config_color(value, fallback: Color) -> Color:
	if value is Color:
		return value

	var text: String = str(value).strip_edges()
	if text == "":
		return fallback
	if !text.begins_with("#"):
		text = "#" + text

	var color: Color = Color.html(text)
	if color == Color.BLACK and text.to_lower() != "#000000":
		return fallback
	return color

func apply_visual_shader(shader_config: Dictionary = {}) -> void:
	if visual == null or typeof(shader_config) != TYPE_DICTIONARY:
		return

	if shader_config.is_empty():
		shader_config = visual_fx_config.get("shader", {})
	if shader_config.is_empty():
		return

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 0.45, 0.95, 1.0);
uniform float tint_strength = 0.18;
uniform float pulse_strength = 0.12;
uniform float pulse_speed = 3.2;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * pulse_strength;
	c.rgb = mix(c.rgb, tint_color.rgb, tint_strength + pulse);
	COLOR = c;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("tint_color", parse_config_color(shader_config.get("tint", "ff66d9"), Color(1.0, 0.45, 0.95, 1.0)))
	shader_material.set_shader_parameter("tint_strength", float(shader_config.get("tint_strength", 0.16)))
	shader_material.set_shader_parameter("pulse_strength", float(shader_config.get("pulse_strength", 0.08)))
	shader_material.set_shader_parameter("pulse_speed", float(shader_config.get("pulse_speed", 3.2)))
	if visual is CanvasItem:
		visual.material = shader_material

func create_health_bar() -> void:
	# Trash followers are the bulk of the horde. Their HP bar nodes cost more than
	# they help; damage is still communicated through hit flash / merged numbers.
	# Leaders, bases, player, workers, bosses and precise/special units keep bars.
	if visual_is_shared_gif_sprite and ai_role == "follower":
		return
	health_bar_root = Node2D.new()
	health_bar_root.name = "HealthBar"
	add_child(health_bar_root)
	health_bar_root.position = Vector2(-30.0, -visual_size.y * 0.5 * abs(visual_base_scale.y) - 18.0)

	health_bar_back = ColorRect.new()
	health_bar_back.color = Color(0.08, 0.02, 0.08, 0.78)
	health_bar_back.size = Vector2(60.0, 7.0)
	health_bar_root.add_child(health_bar_back)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.95, 0.35, 0.92, 0.92)
	health_bar_fill.position = Vector2(1.0, 1.0)
	health_bar_fill.size = Vector2(58.0, 5.0)
	health_bar_root.add_child(health_bar_fill)

func create_bio_stack() -> void:
	if entity_type != "player" and entity_type != "worker" and !tags.has("worker"):
		return

	bio_stack_root = Node2D.new()
	bio_stack_root.name = "BioStack"
	add_child(bio_stack_root)
	bio_stack_root.z_index = -6
	update_bio_stack_visual()

func create_zone_rings() -> void:
	var zones: Dictionary = data.get("zones", {})
	alert_radius = float(zones.get("alert_radius", 0.0))
	delivery_radius = float(zones.get("delivery_radius", 0.0))
	delivery_offset = get_config_vector2(zones.get("delivery_offset", []), Vector2.ZERO)
	delivery_texture_path = str(zones.get("delivery_texture", ""))
	contact_radius = float(zones.get("contact_radius", 0.0))
	contact_damage = float(zones.get("contact_damage", 0.0))
	contact_cooldown = float(zones.get("contact_cooldown", 1.0))
	contact_knockback_min = float(zones.get("contact_knockback_min", 80.0))
	contact_knockback_max = float(zones.get("contact_knockback_max", 150.0))

	if alert_radius > 0.0:
		alert_ring = make_ring("AlertRing", alert_radius, Color(1.0, 0.28, 0.92, 0.36))
		add_child(alert_ring)

	if delivery_radius > 0.0:
		delivery_ring = make_ring("DeliveryRing", delivery_radius, Color(0.88, 0.62, 1.0, 0.48))
		delivery_ring.position = delivery_offset
		add_child(delivery_ring)
		create_delivery_visual()

	if contact_radius > 0.0:
		contact_ring = make_ring("ContactDamageRing", contact_radius, Color(1.0, 0.2, 0.72, 0.75))
		add_child(contact_ring)

	if is_building:
		create_base_progress_bar()

func create_delivery_visual() -> void:
	if delivery_texture_path == "":
		return

	if delivery_texture_path.get_extension().to_lower() == "gif":
		var gif_visual = GIFPlayer.new()
		delivery_visual = gif_visual
		add_child(gif_visual)
		gif_visual.gif = load(delivery_texture_path)
		configure_gif_player_for_explicit_size(gif_visual)
		# This GIFPlayer is TextureRect-like. Do not rely on its loaded raw size here;
		# several optimization passes accidentally left the delivery area as only a ring.
		# The delivery area should behave like the old hand-placed node:
		# top-left = delivery center - size / 2.
		var area_size: Vector2 = get_config_vector2(data.get("zones", {}).get("delivery_size", []), Vector2.ZERO)
		if area_size.x <= 0.0 or area_size.y <= 0.0:
			area_size = Vector2(delivery_radius * 2.0, delivery_radius * 2.0)
		gif_visual.size = area_size
		gif_visual.position = delivery_offset - area_size * 0.5
		gif_visual.scale = Vector2.ONE
		gif_visual.process_mode = Node.PROCESS_MODE_INHERIT
		gif_visual.visible = true
		gif_visual.modulate = Color(1.0, 0.72, 0.98, 0.72)
		gif_visual.z_index = 2
		return

	var sprite: Sprite2D = Sprite2D.new()
	delivery_visual = sprite
	add_child(sprite)
	sprite.texture = load(delivery_texture_path)
	sprite.centered = true
	sprite.position = delivery_offset
	sprite.modulate = Color(1.0, 0.72, 0.98, 0.72)
	sprite.z_index = 2

func make_ring(ring_name: String, ring_radius: float, ring_color: Color) -> Line2D:
	var ring: Line2D = Line2D.new()
	ring.name = ring_name
	ring.width = 4.0
	ring.default_color = ring_color
	ring.closed = true
	ring.z_index = 4

	var point_count: int = 96
	for i in range(point_count):
		var t: float = float(i) / float(point_count)
		ring.add_point(Vector2.RIGHT.rotated(t * TAU) * ring_radius)

	return ring

func create_configured_visual_fx() -> void:
	if visual_fx_config.is_empty():
		return

	if visual_fx_config.has("halo"):
		var halo_data: Dictionary = visual_fx_config.get("halo", {})
		var halo := ColorRect.new()
		halo.name = "FxHalo"
		halo.color = parse_config_color(halo_data.get("color", "ff66d9"), Color(1.0, 0.4, 0.85, 1.0))
		halo.color.a = float(halo_data.get("alpha", 0.16))
		var size_value: Vector2 = get_config_vector2(halo_data.get("size", []), Vector2(radius * 3.2, radius * 2.0))
		halo.size = size_value
		halo.position = -size_value * 0.5 + get_config_vector2(halo_data.get("offset", []), Vector2.ZERO)
		halo.z_index = int(halo_data.get("z_index", -4))
		add_child(halo)
		visual_fx_nodes.append({"node": halo, "kind": "halo", "base_alpha": halo.color.a, "base_scale": Vector2.ONE, "pulse": float(halo_data.get("pulse", 0.12))})

	if visual_fx_config.has("aura_ring"):
		var ring_data: Dictionary = visual_fx_config.get("aura_ring", {})
		var fx_radius: float = float(ring_data.get("radius", radius * 2.6))
		var ring_color: Color = parse_config_color(ring_data.get("color", "ff66d9"), Color(1.0, 0.4, 0.85, 1.0))
		ring_color.a = float(ring_data.get("alpha", 0.42))
		var ring := make_ring("FxAuraRing", fx_radius, ring_color)
		ring.width = float(ring_data.get("width", 3.0))
		ring.z_index = int(ring_data.get("z_index", -3))
		add_child(ring)
		visual_fx_nodes.append({"node": ring, "kind": "ring", "base_alpha": ring_color.a, "base_width": ring.width, "pulse": float(ring_data.get("pulse", 0.18))})

	if visual_fx_config.has("orbit_dots"):
		var dots_data: Dictionary = visual_fx_config.get("orbit_dots", {})
		var dot_count: int = max(1, int(dots_data.get("count", 4)))
		var orbit_radius: float = float(dots_data.get("radius", radius * 1.8))
		var dot_color: Color = parse_config_color(dots_data.get("color", "ffffff"), Color.WHITE)
		dot_color.a = float(dots_data.get("alpha", 0.72))
		var dot_root := Node2D.new()
		dot_root.name = "FxOrbitDots"
		dot_root.z_index = int(dots_data.get("z_index", 6))
		add_child(dot_root)
		for i in range(dot_count):
			var dot := ColorRect.new()
			dot.color = dot_color
			dot.size = Vector2.ONE * float(dots_data.get("size", 5.0))
			dot.position = Vector2.RIGHT.rotated(float(i) / float(dot_count) * TAU) * orbit_radius - dot.size * 0.5
			dot_root.add_child(dot)
		visual_fx_nodes.append({"node": dot_root, "kind": "orbit", "speed": float(dots_data.get("speed", 1.4))})

func create_configured_visual_attachments(current_level: int) -> void:
	if visual_attachment_config.is_empty():
		return

	for attachment in visual_attachment_config:
		if typeof(attachment) != TYPE_DICTIONARY:
			continue
		var min_level: int = int(attachment.get("level_min", 1))
		var max_level: int = int(attachment.get("level_max", 999))
		if current_level < min_level or current_level > max_level:
			continue
		apply_visual_attachment(attachment)

func apply_visual_attachment(attachment: Dictionary) -> void:
	if attachment.is_empty():
		return

	var attachment_id: String = str(attachment.get("id", "attachment_" + str(visual_attachment_nodes.size())))
	if visual_attachment_nodes.has(attachment_id):
		var old_node = visual_attachment_nodes[attachment_id]
		if old_node != null and is_instance_valid(old_node):
			old_node.queue_free()

	var root := Node2D.new()
	root.name = "Attachment_" + attachment_id
	root.position = get_config_vector2(attachment.get("offset", []), Vector2.ZERO)
	root.scale = Vector2.ONE * float(attachment.get("scale", 1.0))
	root.z_index = int(attachment.get("z_index", -2))
	add_child(root)

	var texture_path: String = str(attachment.get("gif", attachment.get("texture", "")))
	if texture_path != "":
		if texture_path.get_extension().to_lower() == "gif":
			var gif_visual := GIFPlayer.new()
			root.add_child(gif_visual)
			gif_visual.gif = load(texture_path)
			var gif_size: Vector2 = gif_visual.size
			if gif_size.x <= 0.0 or gif_size.y <= 0.0:
				gif_size = get_config_vector2(attachment.get("size", []), Vector2(80.0, 80.0))
			gif_visual.position = -gif_size * 0.5
		else:
			var sprite := Sprite2D.new()
			root.add_child(sprite)
			sprite.texture = load(texture_path)
			sprite.centered = true
	else:
		create_attachment_placeholder(root, attachment)

	visual_attachment_nodes[attachment_id] = root

func create_attachment_placeholder(root: Node2D, attachment: Dictionary) -> void:
	var size_value: Vector2 = get_config_vector2(attachment.get("size", []), Vector2(72.0, 72.0))
	var color: Color = parse_config_color(attachment.get("color", "ff66d9"), Color(1.0, 0.42, 0.86, 1.0))
	color.a = float(attachment.get("alpha", 0.36))

	var rect := ColorRect.new()
	rect.color = color
	rect.size = size_value
	rect.position = -size_value * 0.5
	root.add_child(rect)

	var ring := make_ring("AttachmentRing", max(size_value.x, size_value.y) * 0.55, color)
	ring.width = float(attachment.get("ring_width", 3.0))
	root.add_child(ring)

func update_configured_visual_fx(delta: float) -> void:
	if visual_fx_nodes.is_empty():
		return

	visual_fx_phase += delta
	for i in range(visual_fx_nodes.size() - 1, -1, -1):
		var fx = visual_fx_nodes[i]
		if typeof(fx) != TYPE_DICTIONARY:
			continue
		var node = fx.get("node", null)
		if node == null or !is_instance_valid(node):
			visual_fx_nodes.remove_at(i)
			continue

		var pulse: float = sin(Time.get_ticks_msec() * 0.006 + float(get_instance_id() % 37)) * 0.5 + 0.5
		var kind: String = str(fx.get("kind", ""))
		if kind == "halo" and node is ColorRect:
			var color: Color = node.color
			color.a = float(fx.get("base_alpha", 0.16)) * lerp(0.72, 1.35, pulse)
			node.color = color
			var pulse_scale: float = 1.0 + float(fx.get("pulse", 0.12)) * pulse
			node.scale = Vector2.ONE * pulse_scale
		elif kind == "ring" and node is Line2D:
			var color_ring: Color = node.default_color
			color_ring.a = float(fx.get("base_alpha", 0.42)) * lerp(0.72, 1.25, pulse)
			node.default_color = color_ring
			node.width = float(fx.get("base_width", 3.0)) * lerp(0.8, 1.3, pulse)
		elif kind == "orbit" and node is Node2D:
			node.rotation += float(fx.get("speed", 1.4)) * delta
		elif kind == "burst" and node is Line2D:
			fx["age"] = float(fx.get("age", 0.0)) + delta
			var life: float = max(0.05, float(fx.get("life", 0.65)))
			var ratio: float = clamp(float(fx["age"]) / life, 0.0, 1.0)
			var burst_color: Color = node.default_color
			burst_color.a = float(fx.get("base_alpha", 0.78)) * (1.0 - ratio)
			node.default_color = burst_color
			node.width = float(fx.get("base_width", 8.0)) * lerp(1.0, 0.18, ratio)
			node.scale = Vector2.ONE * lerp(0.72, 1.45, ratio)
			visual_fx_nodes[i] = fx
			if ratio >= 1.0:
				node.queue_free()
				visual_fx_nodes.remove_at(i)

func update_status_visuals(delta: float) -> void:
	# Sleeping swarm followers should not spend UI/FX frames unless they were just hit.
	# They still move, take damage, and can wake into precise combat near targets.
	if is_swarm_visual_sleeping():
		if health_bar_root != null:
			health_bar_root.visible = false
		if hit_flash_timer > 0.0:
			update_hit_flash(delta)
		return

	update_health_bar()
	update_hit_flash(delta)
	update_zone_rings()
	update_base_progress_bar()
	update_configured_visual_fx(delta)

func update_visual_lod(delta: float) -> void:
	if visual == null or !(visual is GIFPlayer):
		return
	if entity_type == "player" or entity_type == "base" or is_building or tags.has("worker"):
		set_gif_static_lod(false)
		return

	gif_lod_timer -= delta
	if gif_lod_timer > 0.0:
		return
	gif_lod_timer = gif_lod_interval + randf_range(0.0, 0.08)

	var should_static := false
	if director != null:
		var crowded: bool = director.entities.size() >= gif_lod_entity_threshold
		if crowded and ai_role == "follower" and !follower_precision_active:
			should_static = true
		# Far non-player trash can also be static while crowded. Movement still updates;
		# only the GIF frame advance is paused.
		if !should_static and crowded and director.battle_camera != null:
			var dist_to_camera: float = global_position.distance_to(director.battle_camera.global_position)
			if dist_to_camera > gif_lod_precise_radius and ai_role == "follower":
				should_static = true

	set_gif_static_lod(should_static)

func set_gif_static_lod(should_static: bool) -> void:
	if visual == null or !(visual is GIFPlayer):
		return
	if gif_static_lod_active == should_static:
		return
	gif_static_lod_active = should_static
	if should_static:
		visual.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		visual.process_mode = Node.PROCESS_MODE_INHERIT

func is_swarm_visual_sleeping() -> bool:
	if ai_role != "follower":
		return false
	if follower_precision_active:
		return false
	if hit_flash_timer > 0.0:
		return false
	if director == null:
		return false
	return director.entities.size() >= gif_lod_entity_threshold

func update_health_bar() -> void:
	if health_bar_root == null or health_bar_fill == null:
		return

	if force_hide_health_bar:
		health_bar_root.visible = false
		return

	var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	health_bar_fill.size.x = 58.0 * ratio

	var danger: float = 1.0 - smoothstep(0.18, 0.55, ratio)
	var pulse: float = sin(Time.get_ticks_msec() * 0.018) * 0.5 + 0.5
	health_bar_fill.color = Color(
		lerp(0.95, 1.0, danger),
		lerp(0.35, 0.05, danger),
		lerp(0.92, 0.18, danger),
		lerp(0.85, 1.0, danger * pulse)
	)

	health_bar_root.scale.x = 1.0 + danger * pulse * 0.08
	health_bar_root.scale.y = 1.0 - danger * pulse * 0.04
	health_bar_root.visible = hp < max_hp

func update_hit_flash(delta: float) -> void:
	if visual_holder == null:
		return

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		var power: float = clamp(hit_flash_timer / 0.12, 0.0, 1.0)
		visual_holder.modulate = Color(1.0, 0.55 + power * 0.45, 0.9 + power * 0.1, 1.0)
	elif has_status("control"):
		var pulse_control: float = sin(Time.get_ticks_msec() * 0.018) * 0.5 + 0.5
		visual_holder.modulate = Color(0.65, 0.78 + pulse_control * 0.22, 1.0, 1.0)
	elif has_status("vulnerable"):
		var pulse_vulnerable: float = sin(Time.get_ticks_msec() * 0.02) * 0.5 + 0.5
		visual_holder.modulate = Color(1.0, 0.55 + pulse_vulnerable * 0.25, 0.88, 1.0)
	elif has_status("poison"):
		var pulse_poison: float = sin(Time.get_ticks_msec() * 0.014) * 0.5 + 0.5
		visual_holder.modulate = Color(0.82 + pulse_poison * 0.12, 0.45, 1.0, 1.0)
	elif has_status("burn"):
		var pulse_burn: float = sin(Time.get_ticks_msec() * 0.02) * 0.5 + 0.5
		visual_holder.modulate = Color(1.0, 0.42 + pulse_burn * 0.28, 0.22, 1.0)
	elif has_status("invincible"):
		var pulse_invincible: float = sin(Time.get_ticks_msec() * 0.028) * 0.5 + 0.5
		visual_holder.modulate = Color(0.68 + pulse_invincible * 0.32, 0.92, 1.0, 1.0)
	else:
		visual_holder.modulate = Color.WHITE

func has_status(status_type: String) -> bool:
	for status in status_effects:
		if str(status.get("status", status.get("status_type", ""))) == status_type:
			return true
	return false

func update_zone_rings() -> void:
	if director == null or director.player_entity == null or !is_instance_valid(director.player_entity):
		return

	if alert_ring:
		update_one_ring(alert_ring, alert_radius, Color(1.0, 0.28, 0.92, 1.0))

	if delivery_ring:
		update_one_ring(delivery_ring, delivery_radius, Color(0.78, 0.55, 1.0, 1.0))
		if delivery_visual != null:
			var delivery_pulse: float = sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
			delivery_visual.modulate = Color(1.0, 0.68, 0.98, lerp(0.46, 0.82, delivery_pulse))

	if contact_ring:
		update_contact_ring()

func update_one_ring(ring: Line2D, ring_radius: float, base_color: Color) -> void:
	if ring_radius <= 0.0:
		return

	var dist: float = ring.global_position.distance_to(director.player_entity.global_position)
	var alpha: float = 1.0 - clamp((dist - ring_radius) / max(ring_radius * 0.75, 1.0), 0.0, 1.0)
	var pulse: float = sin(Time.get_ticks_msec() * 0.006) * 0.5 + 0.5
	base_color.a = lerp(0.22, 0.92, alpha) * lerp(0.72, 1.0, pulse)
	ring.default_color = base_color
	ring.width = lerp(3.0, 6.0, alpha)

func update_contact_ring() -> void:
	if contact_ring == null:
		return

	var pulse: float = sin(Time.get_ticks_msec() * 0.01) * 0.5 + 0.5
	var color: Color = Color(1.0, lerp(0.12, 0.42, pulse), 0.78, lerp(0.42, 0.82, pulse))
	contact_ring.default_color = color
	contact_ring.width = lerp(3.0, 8.0, pulse)

func create_sfx() -> void:
	var sfx: Dictionary = data.get("sfx", {})

	attack_sfx = AudioStreamPlayer.new()
	add_child(attack_sfx)
	if sfx.has("attack") and ResourceLoader.exists(str(sfx["attack"])):
		attack_sfx.stream = load(str(sfx["attack"]))

	hurt_sfx = AudioStreamPlayer.new()
	add_child(hurt_sfx)
	if sfx.has("hurt") and ResourceLoader.exists(str(sfx["hurt"])):
		hurt_sfx.stream = load(str(sfx["hurt"]))

	die_sfx = AudioStreamPlayer.new()
	add_child(die_sfx)
	if sfx.has("die") and ResourceLoader.exists(str(sfx["die"])):
		die_sfx.stream = load(str(sfx["die"]))

func update_target(delta: float) -> void:
	if ai_role == "follower":
		update_follower_target(delta)
		return

	target_scan_timer -= delta
	if target_scan_timer > 0.0:
		return

	target_scan_timer = repath_interval

	if target != null and is_instance_valid(target) and !target.is_dead:
		var dist: float = global_position.distance_to(target.global_position)
		if dist <= sense_radius:
			return

	var previous_target = target
	target = director.find_target_for(self, target_factions, sense_radius)
	if target == null and should_use_objective_fallback():
		target = director.find_objective_target_for(self, target_factions, objective_fallback_radius, objective_fallback_priority_order)
	if target != previous_target:
		ai_steer_timer = 0.0
		cached_ai_move_dir = Vector2.ZERO

func update_follower_target(delta: float) -> void:
	follower_recheck_timer -= delta
	follower_attack_scan_timer -= delta

	if ai_leader == null or !is_instance_valid(ai_leader) or ai_leader.is_dead:
		if follower_recheck_timer <= 0.0:
			follower_recheck_timer = follower_recheck_interval
			if director != null:
				ai_leader = director.find_swarm_leader_for(self)
			if ai_leader == null or !is_instance_valid(ai_leader) or ai_leader.is_dead:
				promote_to_swarm_leader()
		return

	# Borrow the leader's current target. This avoids a full priority scan for every
	# trash unit but still lets followers attack the same meaningful objective.
	if ai_leader.target != null and is_instance_valid(ai_leader.target) and !ai_leader.target.is_dead:
		target = ai_leader.target
	else:
		target = null

	# Only when already near the fight do followers pick a nearby immediate target.
	# Far followers inherit the leader intent and do not run target-priority scans.
	if follower_attack_scan_timer <= 0.0 and director != null:
		follower_attack_scan_timer = follower_attack_scan_interval
		if is_follower_near_leader_target(follower_precision_radius * 1.35):
			var close_target = director.find_target_for(self, target_factions, follower_attack_scan_radius)
			if close_target != null and is_instance_valid(close_target):
				target = close_target

func is_follower_near_leader_target(range_limit: float) -> bool:
	if ai_role != "follower":
		return true
	if ai_leader != null and is_instance_valid(ai_leader) and !ai_leader.is_dead:
		if ai_leader.target != null and is_instance_valid(ai_leader.target) and !ai_leader.target.is_dead:
			return global_position.distance_to(ai_leader.target.global_position) <= range_limit
	if target != null and is_instance_valid(target) and !target.is_dead:
		return global_position.distance_to(target.global_position) <= range_limit
	return false

func update_follower_precision_state(delta: float) -> void:
	if ai_role != "follower":
		follower_precision_active = true
		return

	follower_precision_timer -= delta
	if follower_precision_timer > 0.0:
		return
	follower_precision_timer = follower_precision_interval

	follower_precision_active = false
	if is_building or is_dead:
		return

	# Cheap early-out: if the leader target is nearby, this follower is in the fighting band.
	if is_follower_near_leader_target(follower_precision_radius):
		follower_precision_active = true
		return

	# Otherwise ask the spatial grid only occasionally. This is the precise switch for
	# attacks/contact: far horde bodies move, but do not spend frames on combat checks.
	if director != null and director.has_method("query_entities_near"):
		var candidates: Array = director.query_entities_near(global_position, follower_precision_radius)
		for entity in candidates:
			if entity == null or !is_instance_valid(entity) or entity == self:
				continue
			if entity.is_dead or entity.is_building:
				continue
			if director.are_factions_allied(entity.faction, faction):
				continue
			follower_precision_active = true
			return

func promote_to_swarm_leader() -> void:
	ai_role = "leader"
	ai_leader = null
	repath_interval = min(repath_interval, 0.35)
	ai_steer_interval = min(ai_steer_interval, 0.18)
	target_scan_timer = 0.0
	ai_steer_timer = 0.0
	if director != null:
		director.register_swarm_leader(self)

func should_use_objective_fallback() -> bool:
	if !objective_fallback:
		return false
	if target_factions.is_empty():
		return false
	if entity_type == "player" or entity_type == "worker" or tags.has("worker"):
		return false
	if leash_radius > 0.0 and director != null and director.tentacle_base != null and is_instance_valid(director.tentacle_base):
		if global_position.distance_to(director.tentacle_base.global_position) > leash_radius:
			return false
	return ai_mode == "chase_nearest" or ai_mode == "attack_building_first" or target_priority == "building_first"

func get_legacy_target_priority_order(priority: String) -> Array:
	if priority == "building_first":
		return ["building", "player", "minion", "unit"]

	if priority == "player_first":
		return ["player", "minion", "building", "unit"]

	if priority == "minion_first":
		return ["minion", "player", "building", "unit"]

	if priority == "base_first":
		return ["base", "building", "minion", "player", "unit"]

	return ["any"]

func get_target_rank(candidate) -> int:
	for i in range(target_priority_order.size()):
		if target_matches_priority(candidate, str(target_priority_order[i])):
			return i

	return target_priority_order.size() + 10

func target_matches_priority(candidate, priority: String) -> bool:
	if priority == "any":
		return true

	if priority == "building":
		return candidate.is_building

	if priority == "non_building":
		return !candidate.is_building

	if priority == "unit":
		return !candidate.is_building and candidate.entity_type != "player"

	if priority == "base":
		return candidate.tags.has("base") or candidate.entity_type == "base"

	if priority == "player":
		return candidate.entity_type == "player"

	if priority == "minion":
		return candidate.entity_type == "minion" or candidate.tags.has("minion")

	if priority.begins_with("tag:"):
		return candidate.tags.has(priority.substr(4))

	if priority.begins_with("type:"):
		return candidate.entity_type == priority.substr(5)

	return candidate.entity_type == priority or candidate.tags.has(priority)

func is_better_target_distance(dist: float, best_dist: float) -> bool:
	if target_distance_mode == "farthest":
		return dist > best_dist

	return dist < best_dist

func update_movement(delta: float) -> void:
	if contact_pause_timer > 0.0:
		contact_pause_timer = max(0.0, contact_pause_timer - delta)
		return

	if ai_mode == "player":
		var input: Vector2 = Vector2.ZERO
		input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

		if input.length() > 1.0:
			input = input.normalized()

		var face_dir: Vector2 = input
		if abs(face_dir.x) < 0.01:
			var mouse_dir: Vector2 = get_global_mouse_position() - global_position
			if abs(mouse_dir.x) > 8.0:
				face_dir = mouse_dir

		update_facing(face_dir)
		director.move_entity(self, input * move_speed * get_status_speed_multiplier() * delta)
		return

	if ai_mode == "worker_collect_bio":
		update_worker_movement(delta)
		return

	if ai_mode == "idle" or move_speed <= 0.0:
		return

	if ai_role == "follower":
		update_follower_movement(delta)
		return

	if target == null or !is_instance_valid(target):
		return

	if ai_mode == "chase_nearest" or ai_mode == "attack_building_first":
		var dir: Vector2 = target.global_position - global_position
		var dist_to_target: float = dir.length()
		if dist_to_target > 6.0:
			if target.is_building and is_in_primary_attack_range(target):
				update_facing(dir)
				update_stuck_state(global_position, delta)
				return

			ai_steer_timer -= delta
			if ai_steer_timer <= 0.0 or cached_ai_move_dir.length() <= 0.01:
				ai_steer_timer = max(0.03, ai_steer_interval)
				cached_ai_move_dir = get_ai_move_direction(dir)

			var move_dir: Vector2 = cached_ai_move_dir
			if move_dir.length() <= 0.01:
				move_dir = dir.normalized()
			var speed_mul: float = close_speed_mul if dist_to_target <= close_range else 1.0
			speed_mul *= get_status_speed_multiplier()
			update_facing(move_dir)
			var before_move: Vector2 = global_position
			director.move_entity(self, move_dir * move_speed * speed_mul * delta)
			update_stuck_state(before_move, delta)

func update_follower_movement(delta: float) -> void:
	update_follower_spacing_pressure(delta)

	if ai_leader == null or !is_instance_valid(ai_leader) or ai_leader.is_dead:
		# No leader yet; drift toward inherited target if any, otherwise stay cheap.
		if target != null and is_instance_valid(target) and !target.is_dead:
			var orphan_dir: Vector2 = (target.global_position - global_position).normalized()
			orphan_dir = apply_follower_target_standoff(orphan_dir, target)
			move_follower_in_direction(orphan_dir + follower_spacing_push, delta)
		return

	var leader_pos: Vector2 = ai_leader.global_position
	var to_leader: Vector2 = leader_pos - global_position
	var dist_to_leader: float = to_leader.length()

	var dir: Vector2 = Vector2.ZERO
	if target != null and is_instance_valid(target) and !target.is_dead:
		var to_target: Vector2 = target.global_position - global_position
		var target_dist: float = to_target.length()
		if target_dist <= follower_attack_scan_radius * 1.15:
			# Close to the fight, but do not let every trash body drive into the
			# exact same center point. A soft standoff turns the pile into a ring/cloud.
			dir += apply_follower_target_standoff(to_target.normalized(), target) * 1.25

	if dist_to_leader > follower_break_distance:
		# Fell too far behind: rejoin the pack instead of doing independent brain work.
		dir += to_leader.normalized() * 2.0
	elif dist_to_leader > follower_keep_distance:
		dir += to_leader.normalized() * 0.75
	else:
		var leader_dir: Vector2 = Vector2.ZERO
		if director != null and director.has_method("get_swarm_flow_dir_for"):
			leader_dir = director.get_swarm_flow_dir_for(self)
		if leader_dir.length() <= 0.01:
			leader_dir = ai_leader.cached_ai_move_dir
		if leader_dir.length() <= 0.01 and ai_leader.target != null and is_instance_valid(ai_leader.target):
			leader_dir = (ai_leader.target.global_position - ai_leader.global_position).normalized()
		if leader_dir.length() > 0.01:
			dir += leader_dir.normalized()
			var side := Vector2(-leader_dir.y, leader_dir.x) * follower_side_bias * 0.18
			dir += side

	if dir.length() <= 0.01 and target != null and is_instance_valid(target) and !target.is_dead:
		dir = apply_follower_target_standoff((target.global_position - global_position).normalized(), target)

	# Low-frequency cached local pressure. This keeps centers apart without making
	# every follower an expensive rigid body.
	if follower_spacing_push.length() > 0.01:
		dir += follower_spacing_push

	move_follower_in_direction(dir, delta)

func update_follower_spacing_pressure(delta: float) -> void:
	if ai_role != "follower" or director == null or is_dead:
		follower_spacing_push = Vector2.ZERO
		return

	follower_spacing_timer -= delta
	if follower_spacing_timer > 0.0:
		return
	follower_spacing_timer = follower_spacing_interval

	follower_spacing_push = Vector2.ZERO
	if !director.has_method("query_entities_near"):
		return

	var candidates: Array = director.query_entities_near(global_position, follower_spacing_radius)
	var push := Vector2.ZERO
	var checked := 0
	for entity in candidates:
		if entity == null or !is_instance_valid(entity) or entity == self:
			continue
		if entity.is_dead or entity.is_building:
			continue
		if !director.are_factions_allied(entity.faction, faction):
			continue
		# This pressure is for cheap horde bodies. Do not let a worker/player/base or
		# boss strongly push trash units around.
		if entity.entity_type == "player" or entity.entity_type == "worker":
			continue
		var away: Vector2 = global_position - entity.global_position
		var dist_sq: float = away.length_squared()
		if dist_sq <= 0.01:
			away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			dist_sq = max(away.length_squared(), 0.01)
		var dist: float = sqrt(dist_sq)
		if dist >= follower_spacing_radius:
			continue
		var weight: float = 1.0 - (dist / follower_spacing_radius)
		push += away.normalized() * weight
		checked += 1
		if checked >= follower_spacing_max_neighbors:
			break

	if push.length() > 0.01:
		follower_spacing_push = push.normalized() * follower_spacing_strength

func apply_follower_target_standoff(dir: Vector2, target_entity) -> Vector2:
	if target_entity == null or !is_instance_valid(target_entity):
		return dir
	var to_target: Vector2 = target_entity.global_position - global_position
	var dist: float = to_target.length()
	if dist <= 0.01:
		return dir

	# Instead of every follower steering to the exact target center, give it a stable
	# personal slot on a ring around that target. This is deliberately regular: a
	# horde/legion look is cheaper and more readable than 300 independent pathing brains.
	var ring_radius: float = follower_target_standoff + target_entity.radius * 0.35
	ring_radius *= 1.0 + follower_orbit_radius_bias
	var orbit_vec: Vector2 = Vector2.RIGHT.rotated(follower_orbit_slot_angle) * ring_radius
	var desired_point: Vector2 = target_entity.global_position + orbit_vec
	var to_slot: Vector2 = desired_point - global_position
	var slot_dir: Vector2 = to_slot.normalized() if to_slot.length() > 0.01 else dir

	var influence: float = clamp(1.0 - ((dist - ring_radius) / max(ring_radius * 2.4, 1.0)), 0.0, 1.0)
	if dist < ring_radius:
		var away: Vector2 = -to_target.normalized()
		var tangent: Vector2 = Vector2(-to_target.y, to_target.x).normalized() * follower_side_bias * 0.45
		return (dir + away * follower_target_standoff_strength + tangent + slot_dir * 0.55).normalized()
	if influence > 0.0:
		return dir.lerp(slot_dir, min(0.72, influence * 0.55)).normalized()
	return dir

func move_follower_in_direction(dir: Vector2, delta: float) -> void:
	if dir.length() <= 0.01:
		return
	dir = dir.normalized()
	follower_last_flow_dir = dir
	var before_move: Vector2 = global_position
	var speed_mul: float = get_status_speed_multiplier()
	update_facing(dir)
	director.move_entity(self, dir * move_speed * speed_mul * delta)
	# Stuck state is still useful, but only as a cheap timer; no extra scans here.
	update_stuck_state(before_move, delta)

func get_status_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for status in status_effects:
		var status_type: String = str(status.get("status", status.get("status_type", "")))
		if status_type == "slow":
			multiplier *= float(status.get("slow_mul", 0.75))
		elif status_type == "poison" and status.has("slow_mul"):
			multiplier *= float(status.get("slow_mul", 0.92))
		elif status_type == "control" and status.has("speed_mul"):
			multiplier *= float(status.get("speed_mul", 1.0))
		elif status_type == "speed":
			multiplier *= float(status.get("speed_mul", 1.0))
		elif status.has("speed_mul"):
			multiplier *= float(status.get("speed_mul", 1.0))
	return clamp(multiplier, 0.18, 2.5)

func get_ai_move_direction(to_target: Vector2) -> Vector2:
	if to_target.length() <= 0.01:
		return Vector2.ZERO

	var direct: Vector2 = to_target.normalized()

	if movement_mode == "orbit_close" and to_target.length() <= close_range:
		var tangent: Vector2 = Vector2(-direct.y, direct.x) * orbit_dir
		return (direct * 0.35 + tangent * 0.65).normalized()

	if movement_mode == "strafe_close" and to_target.length() <= close_range:
		var tangent: Vector2 = Vector2(-direct.y, direct.x) * orbit_dir
		return (direct * 0.55 + tangent * 0.45).normalized()

	var forced_side: float = forced_avoid_side if forced_avoid_timer > 0.0 else 0.0
	var ignored_building: Node2D = null
	if target != null and is_instance_valid(target) and target.is_building:
		ignored_building = target
	var building_avoid: Vector2 = director.get_building_avoid_direction(self, direct, target.global_position, forced_side, ignored_building)
	var wall_avoid: Vector2 = director.get_walkable_avoid_direction(self, direct, ignored_building)
	var result: Vector2 = direct

	if building_avoid.length() > 0.01:
		result = (result * 0.35 + building_avoid * 0.95).normalized()

	if wall_avoid.length() > 0.01:
		result = (result * 0.25 + wall_avoid * 0.95).normalized()

	return result

func is_in_primary_attack_range(candidate) -> bool:
	if attacks.is_empty():
		return false

	var best_range: float = 0.0
	for attack in attacks:
		best_range = max(best_range, float(attack.get("range", 0.0)))

	if best_range <= 0.0:
		return false

	var attack_point: Vector2 = get_attack_point("center")
	var target_point: Vector2 = candidate.get_attack_point("center")
	return attack_point.distance_to(target_point) <= best_range * 0.95

func update_stuck_state(before_move: Vector2, delta: float) -> void:
	if entity_type == "player" or is_building:
		return

	if forced_avoid_timer > 0.0:
		forced_avoid_timer = max(0.0, forced_avoid_timer - delta)

	var moved: float = before_move.distance_to(global_position)
	if moved < max(move_speed * delta * 0.18, 0.6):
		stuck_timer += delta
	else:
		stuck_timer = max(0.0, stuck_timer - delta * 1.5)

	if stuck_timer >= 0.45:
		stuck_timer = 0.0
		forced_avoid_timer = 1.0
		forced_avoid_side = -forced_avoid_side
		if entity_type == "worker" or tags.has("worker"):
			worker_target_drop = null
			worker_wander_target = Vector2.ZERO
			worker_delivery_target = Vector2.ZERO

func update_contact_aura(delta: float) -> void:
	if contact_radius <= 0.0 or contact_damage <= 0.0:
		return

	for key in contact_timers.keys():
		contact_timers[key] = max(0.0, float(contact_timers[key]) - delta)

	var candidates: Array = director.entities
	if director.has_method("query_entities_near"):
		candidates = director.query_entities_near(global_position, contact_radius + 128.0)

	for entity in candidates:
		if entity == null or !is_instance_valid(entity):
			continue

		if entity == self:
			continue

		if entity.is_dead:
			continue

		if entity.is_building:
			continue

		if director.are_factions_allied(entity.faction, faction):
			continue

		var dist: float = global_position.distance_to(entity.global_position)
		if dist > contact_radius + entity.radius:
			continue

		var key: String = str(entity.get_instance_id())
		if float(contact_timers.get(key, 0.0)) > 0.0:
			continue

		contact_timers[key] = contact_cooldown
		var away: Vector2 = (entity.global_position - global_position).normalized()
		if away.length() <= 0.01:
			away = Vector2.RIGHT.rotated(randf() * TAU)

		var knockback_distance: float = randf_range(contact_knockback_min, contact_knockback_max)
		var dealt: float = entity.take_damage(get_scaled_damage(contact_damage, entity, {"kind": "contact"}), self)
		apply_contact_statuses(entity)
		try_contact_execute(entity, dealt)
		if entity != null and is_instance_valid(entity) and !entity.is_dead:
			director.move_entity(entity, away * knockback_distance)

func apply_contact_statuses(entity) -> void:
	if entity == null or !is_instance_valid(entity) or entity.is_dead or entity.is_building:
		return
	for status in contact_statuses:
		if typeof(status) != TYPE_DICTIONARY:
			continue
		var chance: float = float(status.get("chance", 1.0))
		if randf() > chance:
			continue
		entity.add_status_effect(status, self)

func try_contact_execute(entity, _dealt: float) -> void:
	if contact_execute_chance <= 0.0 or contact_execute_hp_ratio <= 0.0:
		return
	if entity == null or !is_instance_valid(entity) or entity.is_dead or entity.is_building:
		return
	if entity.max_hp <= 0.0:
		return
	if entity.hp / entity.max_hp > contact_execute_hp_ratio:
		return
	if randf() > contact_execute_chance:
		return
	entity.take_damage(entity.max_hp * 8.0, self)

func setup_base_system() -> void:
	if !is_building:
		return

	var base_config: Dictionary = data.get("base", {})
	base_bio_cap = float(base_config.get("bio_cap", base_bio_cap))
	base_level = int(base_config.get("level", base_level))
	base_max_level = int(base_config.get("max_level", base_max_level))
	base_upgrade_thresholds = base_config.get("upgrade_thresholds", base_upgrade_thresholds)
	base_upgrade_cd = float(base_config.get("upgrade_cd", base_upgrade_cd))
	base_level_passive_bio = base_config.get("level_passive_bio_per_second", base_level_passive_bio)
	base_can_spawn_level = int(base_config.get("can_spawn_level", base_can_spawn_level))
	base_spawn_entity_id = str(base_config.get("spawn_entity_id", base_spawn_entity_id))
	base_spawn_cost = float(base_config.get("spawn_cost", base_spawn_cost))
	base_spawn_interval = float(base_config.get("spawn_interval", base_spawn_interval))
	base_spawn_radius = float(base_config.get("spawn_radius", base_spawn_radius))
	base_spawn_queues = base_config.get("spawn_queues", [])
	base_level_config = base_config.get("level_config", [])
	base_low_power_queue_speed = float(base_config.get("low_power_queue_speed", base_low_power_queue_speed))
	base_low_power_upgrade_speed = float(base_config.get("low_power_upgrade_speed", base_low_power_upgrade_speed))
	base_bio_cycle_interval = float(base_config.get("bio_cycle_interval", base_bio_cycle_interval))
	base_bio_cycle_amounts = base_config.get("bio_cycle_amounts", base_level_passive_bio)
	update_base_passive_rate()

func receive_bio(amount: int) -> void:
	if !is_building:
		return

	base_bio = clamp(base_bio + float(amount), 0.0, base_bio_cap)

func update_base_system(delta: float) -> void:
	if !is_building:
		return

	update_base_bio_production(delta)

	update_base_upgrade(delta)
	if base_spawn_queues.is_empty():
		update_base_spawn(delta)
	else:
		update_base_spawn_queues(delta)

func update_base_bio_production(delta: float) -> void:
	if base_bio_cycle_amounts.size() > 0:
		base_bio_cycle_timer -= delta
		if base_bio_cycle_timer <= 0.0:
			base_bio_cycle_timer = max(0.1, base_bio_cycle_interval)
			var index: int = clamp(base_level - 1, 0, base_bio_cycle_amounts.size() - 1)
			base_bio = clamp(base_bio + float(base_bio_cycle_amounts[index]), 0.0, base_bio_cap)
		return

	if base_passive_bio_per_second > 0.0:
		base_bio = clamp(base_bio + base_passive_bio_per_second * delta, 0.0, base_bio_cap)

func update_base_upgrade(delta: float) -> void:
	if base_level >= base_max_level:
		return

	var threshold: float = float(base_upgrade_thresholds[base_level - 1])
	var speed_mul: float = 1.0 if base_bio >= threshold else base_low_power_upgrade_speed
	base_upgrade_timer += delta * speed_mul
	if base_upgrade_timer < base_upgrade_cd:
		return

	base_level += 1
	base_upgrade_timer = 0.0
	update_base_passive_rate()
	update_base_level_visual()
	apply_base_level_baseline()
	if director != null:
		director.on_base_leveled_up(self, base_level)

func update_base_passive_rate() -> void:
	var index: int = clamp(base_level - 1, 0, base_level_passive_bio.size() - 1)
	base_passive_bio_per_second = float(base_level_passive_bio[index])

func update_base_level_visual() -> void:
	if visual_holder == null:
		return

	if base_level == 2:
		visual_holder.modulate = Color(1.0, 0.78, 1.0, 1.0)
	elif base_level >= 3:
		visual_holder.modulate = Color(1.0, 0.62, 0.92, 1.0)
	apply_visual_stage("level_" + str(base_level))
	create_configured_visual_attachments(base_level)

func apply_visual_stage(stage_key: String) -> void:
	if visual_stage_config.is_empty() or !visual_stage_config.has(stage_key):
		return

	var stage_data: Dictionary = visual_stage_config.get(stage_key, {})
	var visual_data: Dictionary = stage_data.get("visual", {})
	var texture_path: String = str(visual_data.get("gif", visual_data.get("texture", "")))
	if texture_path != "":
		if texture_path.get_extension().to_lower() == "gif" and visual is GIFPlayer:
			visual.gif = load(texture_path)
			var stage_raw_size: Vector2 = visual.size
			if stage_raw_size.x > 0.0 and stage_raw_size.y > 0.0:
				visual_size = stage_raw_size
			var stage_target_size: Vector2 = visual_size
			var stage_max_size: Vector2 = get_body_safe_visual_max_size(visual_data, Vector2.ZERO)
			if stage_max_size.x > 0.0 and stage_max_size.y > 0.0 and visual_size.x > 0.0 and visual_size.y > 0.0:
				var fit_scale: float = min(stage_max_size.x / visual_size.x, stage_max_size.y / visual_size.y)
				stage_target_size = visual_size * fit_scale
			if should_center_visual_on_body(visual_data):
				apply_centered_gif_layout(visual, stage_target_size)
			else:
				visual_size = stage_target_size
				visual.size = visual_size
				visual.position = -visual_size * 0.5
		elif visual is Sprite2D:
			visual.texture = load(texture_path)
			var sprite_stage_max_size: Vector2 = get_body_safe_visual_max_size(visual_data, Vector2.ZERO)
			if visual.texture != null:
				visual_size = visual.texture.get_size()
				if sprite_stage_max_size.x > 0.0 and sprite_stage_max_size.y > 0.0 and visual_size.x > 0.0 and visual_size.y > 0.0:
					var sprite_fit_scale: float = min(sprite_stage_max_size.x / visual_size.x, sprite_stage_max_size.y / visual_size.y)
					visual.scale = Vector2.ONE * sprite_fit_scale
					visual_size *= sprite_fit_scale

	apply_body_centered_visual_position(visual_data)

	if stage_data.has("modulate") and visual_holder != null:
		visual_holder.modulate = parse_config_color(stage_data.get("modulate", "ffffff"), Color.WHITE)

	if stage_data.has("shader"):
		apply_visual_shader(stage_data.get("shader", {}))

	if stage_data.has("burst"):
		spawn_stage_burst(stage_data.get("burst", {}))

	if stage_data.has("attachments"):
		var attachments: Array = stage_data.get("attachments", [])
		for attachment in attachments:
			if typeof(attachment) == TYPE_DICTIONARY:
				apply_visual_attachment(attachment)

func spawn_stage_burst(burst_data: Dictionary) -> void:
	var burst_radius: float = float(burst_data.get("radius", max(radius * 2.8, 120.0)))
	var burst_color: Color = parse_config_color(burst_data.get("color", "ff66d9"), Color(1.0, 0.4, 0.85, 1.0))
	burst_color.a = float(burst_data.get("alpha", 0.78))
	var burst := make_ring("FxStageBurst", burst_radius, burst_color)
	burst.width = float(burst_data.get("width", 8.0))
	burst.z_index = 18
	add_child(burst)
	visual_fx_nodes.append({"node": burst, "kind": "burst", "base_alpha": burst_color.a, "base_width": burst.width, "life": float(burst_data.get("life", 0.65)), "age": 0.0})

func create_base_progress_bar() -> void:
	base_progress_root = Node2D.new()
	base_progress_root.name = "BaseProgress"
	add_child(base_progress_root)
	base_progress_root.position = Vector2(-46.0, -visual_size.y * 0.5 * abs(visual_base_scale.y) - 36.0)

	var back: ColorRect = ColorRect.new()
	back.color = Color(0.05, 0.0, 0.08, 0.82)
	back.size = Vector2(92.0, 10.0)
	base_progress_root.add_child(back)

	base_progress_fill = ColorRect.new()
	base_progress_fill.color = Color(0.9, 0.36, 1.0, 0.95)
	base_progress_fill.position = Vector2(1.0, 1.0)
	base_progress_fill.size = Vector2(0.0, 8.0)
	base_progress_root.add_child(base_progress_fill)

	base_progress_label = Label.new()
	base_progress_label.position = Vector2(0.0, -20.0)
	base_progress_label.size = Vector2(140.0, 20.0)
	base_progress_label.add_theme_font_size_override("font_size", 13)
	base_progress_root.add_child(base_progress_label)

func update_base_progress_bar() -> void:
	if base_progress_root == null or base_progress_fill == null or base_progress_label == null:
		return

	var ratio: float = 0.0
	var label_text: String = "Lv" + str(base_level)

	if base_level < base_max_level:
		var threshold: float = float(base_upgrade_thresholds[base_level - 1])
		if threshold <= 0.0:
			ratio = 0.0
			label_text += " Bio"
		elif base_bio >= threshold:
			ratio = clamp(base_upgrade_timer / max(base_upgrade_cd, 0.001), 0.0, 1.0)
			label_text += " Upgrade"
		else:
			ratio = clamp(base_bio / threshold, 0.0, 1.0)
			label_text += " Bio"
	elif base_level >= base_can_spawn_level:
		if base_spawn_cost <= 0.0:
			ratio = 0.0
			label_text += " Spawn"
		elif base_bio >= base_spawn_cost:
			ratio = 1.0 - clamp(base_spawn_timer / max(base_spawn_interval, 0.001), 0.0, 1.0)
			label_text += " Spawn"
		else:
			ratio = clamp(base_bio / base_spawn_cost, 0.0, 1.0)
			label_text += " Bio"
	else:
		ratio = 0.0 if base_bio_cap <= 0.0 else clamp(base_bio / base_bio_cap, 0.0, 1.0)

	base_progress_fill.size.x = 90.0 * ratio
	base_progress_label.text = label_text + " " + str(int(base_bio))

func update_base_spawn(delta: float) -> void:
	if base_level < base_can_spawn_level:
		return

	if base_bio < base_spawn_cost:
		return

	base_spawn_timer -= delta
	if base_spawn_timer > 0.0:
		return

	base_spawn_timer = base_spawn_interval
	base_bio -= base_spawn_cost
	var spawn_pos: Vector2 = get_base_spawn_position(base_spawn_entity_id)
	director.spawn_entity(base_spawn_entity_id, spawn_pos)

func update_base_spawn_queues(delta: float) -> void:
	var power_budget: float = base_bio
	var sorted: Array = base_spawn_queues.duplicate()
	sorted.sort_custom(func(a, b):
		var la: int = int(a.get("level", 0))
		var lb: int = int(b.get("level", 0))
		if la != lb:
			return la > lb
		return str(a.get("entity_id", a.get("id", ""))) < str(b.get("entity_id", b.get("id", "")))
	)

	for queue in sorted:
		if typeof(queue) != TYPE_DICTIONARY:
			continue
		if !bool(queue.get("unlocked", false)):
			continue

		var cost: float = float(queue.get("power_cost", queue.get("cost", 0.0)))
		var speed_mul: float = base_low_power_queue_speed
		if power_budget >= cost:
			speed_mul = 1.0
			power_budget -= cost

		queue["progress"] = float(queue.get("progress", 0.0)) + delta * speed_mul
		var interval: float = get_effective_queue_interval(queue)
		while float(queue.get("progress", 0.0)) >= interval:
			queue["progress"] = float(queue.get("progress", 0.0)) - interval
			spawn_queue_minions(queue)

		var original_index: int = base_spawn_queues.find(queue)
		if original_index >= 0:
			base_spawn_queues[original_index] = queue

func get_effective_queue_interval(queue: Dictionary) -> float:
	var interval: float = max(0.1, float(queue.get("interval", 3.0)))
	if queue.has("enemy_base_missing_hp_interval_mul") and director != null and director.enemy_base != null and is_instance_valid(director.enemy_base):
		var enemy_base = director.enemy_base
		if enemy_base.max_hp > 0.0:
			var missing_ratio: float = clamp(1.0 - enemy_base.hp / enemy_base.max_hp, 0.0, 1.0)
			var min_mul: float = float(queue.get("enemy_base_missing_hp_interval_mul", 1.0))
			interval *= lerp(1.0, min_mul, missing_ratio)
	return max(0.1, interval)

func spawn_queue_minions(queue: Dictionary) -> void:
	var entity_id_to_spawn: String = str(queue.get("entity_id", ""))
	if entity_id_to_spawn == "":
		return

	var quantity: int = max(1, int(queue.get("quantity", 1)))
	for i in range(quantity):
		var spawn_pos: Vector2 = get_base_spawn_position(entity_id_to_spawn)
		var spawned = director.spawn_entity(entity_id_to_spawn, spawn_pos)
		if spawned != null and is_instance_valid(spawned):
			var stat_mul: Dictionary = queue.get("stat_mul", {})
			spawned.apply_runtime_stat_multipliers(stat_mul)
			if int(queue.get("reward_bio_add", 0)) > 0:
				var reward: Dictionary = spawned.data.get("reward", {})
				reward["bio"] = int(reward.get("bio", 0)) + int(queue.get("reward_bio_add", 0))
				spawned.data["reward"] = reward
			if int(queue.get("bio_on_hit_add", 0)) > 0:
				for attack in spawned.attacks:
					if typeof(attack) == TYPE_DICTIONARY:
						attack["bio_to_base_on_hit"] = int(attack.get("bio_to_base_on_hit", 0)) + int(queue.get("bio_on_hit_add", 0))
			var on_hit_statuses: Array = queue.get("on_hit_statuses", [])
			if !on_hit_statuses.is_empty():
				for attack in spawned.attacks:
					if typeof(attack) == TYPE_DICTIONARY:
						var attack_statuses: Array = attack.get("on_hit_statuses", [])
						attack_statuses.append_array(on_hit_statuses.duplicate(true))
						attack["on_hit_statuses"] = attack_statuses
			if queue.has("death_attack"):
				spawned.death_attack = queue["death_attack"].duplicate(true)
			if queue.has("low_hp_attack_damage_mul"):
				spawned.low_hp_attack_damage_mul = float(queue["low_hp_attack_damage_mul"])
				spawned.low_hp_attack_threshold = float(queue.get("low_hp_attack_threshold", spawned.low_hp_attack_threshold))
			if base_spawn_enemy_base_damage > 0.0 and director != null:
				director.damage_enemy_base_from_spawn(base_spawn_enemy_base_damage, self)
			try_spawn_mutation_gift(entity_id_to_spawn)

func try_spawn_mutation_gift(_source_entity_id: String) -> void:
	if !mutation_gift_enabled or mutation_gift_entity_ids.is_empty() or director == null:
		return
	var chance: float = clamp(mutation_gift_chance_base + float(max(base_level - 1, 0)) * mutation_gift_chance_per_level, 0.0, 0.75)
	if randf() > chance:
		return
	var gift_id: String = str(mutation_gift_entity_ids[randi() % mutation_gift_entity_ids.size()])
	if gift_id == "":
		return
	if gift_id == "032" and director.has_method("spawn_mutation_head_bullets"):
		director.spawn_mutation_head_bullets(self)
		return
	var spawn_pos: Vector2 = get_base_spawn_position(gift_id)
	var gifted = director.spawn_entity(gift_id, spawn_pos)
	if gifted != null and is_instance_valid(gifted):
		if gifted.tags.has("assimilated_girl") and director.has_method("apply_assimilated_runtime_modifiers"):
			director.apply_assimilated_runtime_modifiers(gifted)
		director.spawn_floating_number(spawn_pos + Vector2(0.0, -gifted.radius - 48.0), "突变赠礼", Color(0.85, 0.55, 1.0, 1.0))

func unlock_or_update_base_queue(queue_data: Dictionary) -> void:
	if queue_data.is_empty():
		return

	var queue_id: String = str(queue_data.get("id", queue_data.get("entity_id", "")))
	for i in range(base_spawn_queues.size()):
		var queue: Dictionary = base_spawn_queues[i]
		var existing_id: String = str(queue.get("id", queue.get("entity_id", "")))
		if existing_id == queue_id:
			for key in queue_data.keys():
				queue[key] = queue_data[key]
			queue["unlocked"] = true
			base_spawn_queues[i] = queue
			return

	var new_queue: Dictionary = queue_data.duplicate(true)
	new_queue["unlocked"] = true
	new_queue["progress"] = float(new_queue.get("progress", 0.0))
	base_spawn_queues.append(new_queue)

func apply_base_level_baseline() -> void:
	for entry in base_level_config:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("level", 0)) != base_level:
			continue

		var hp_mul: float = float(entry.get("hp_mul", 1.0))
		var regen_mul: float = float(entry.get("regen_mul", 1.0))
		if hp_mul != 1.0:
			multiply_max_hp(hp_mul)
			hp = min(max_hp, hp + max_hp * 0.08)
		if regen_mul != 1.0:
			multiply_regen(regen_mul)

		var zones: Dictionary = entry.get("zones", {})
		if zones.has("contact_damage"):
			contact_damage = float(zones["contact_damage"])
		if zones.has("contact_cooldown"):
			contact_cooldown = float(zones["contact_cooldown"])
		if zones.has("contact_radius"):
			contact_radius = float(zones["contact_radius"])
			if contact_ring != null:
				contact_ring.queue_free()
			contact_ring = make_ring("ContactDamageRing", contact_radius, Color(1.0, 0.2, 0.72, 0.75))
			add_child(contact_ring)
		return

func get_base_spawn_position(entity_id_to_spawn: String = "") -> Vector2:
	var unit_radius: float = 20.0
	if director != null and entity_id_to_spawn != "":
		var entity_data: Dictionary = director.load_entity_data(entity_id_to_spawn)
		var body: Dictionary = entity_data.get("body", {})
		unit_radius = float(body.get("radius", unit_radius))

	var min_distance: float = block_radius + unit_radius + 36.0
	var max_distance: float = max(base_spawn_radius, min_distance + 24.0)
	for i in range(40):
		var angle: float = randf() * TAU
		var pos: Vector2 = global_position + Vector2.RIGHT.rotated(angle) * randf_range(min_distance, max_distance)
		pos = director.clamp_to_map(pos)
		if director.is_spawn_position_clear(pos, entity_id_to_spawn):
			return pos

	for fallback_dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var fallback_pos: Vector2 = director.clamp_to_map(global_position + fallback_dir * min_distance)
		if director.is_spawn_position_clear(fallback_pos, entity_id_to_spawn):
			return fallback_pos

	return director.clamp_to_map(global_position + Vector2.RIGHT * min_distance)

func get_delivery_center() -> Vector2:
	return global_position + delivery_offset

func collect_bio(amount: int) -> bool:
	return collect_bio_amount(amount) > 0

func collect_bio_amount(amount: int) -> int:
	if entity_type != "player" and entity_type != "worker" and !tags.has("worker"):
		return 0

	if bio_cargo >= bio_cargo_max:
		return 0

	var accepted: int = min(amount, bio_cargo_max - bio_cargo)
	bio_cargo += accepted
	update_bio_stack_visual()
	return accepted

func deliver_all_bio() -> int:
	if entity_type != "player" and entity_type != "worker" and !tags.has("worker"):
		return 0

	var delivered: int = bio_cargo
	bio_cargo = 0
	update_bio_stack_visual()
	return delivered

func try_transfer_bio_to_base(base_entity, delta: float) -> void:
	if entity_type != "player" and entity_type != "worker" and !tags.has("worker"):
		return

	if bio_cargo <= 0:
		bio_transfer_timer = 0.0
		return

	bio_transfer_timer -= delta
	if bio_transfer_timer > 0.0:
		return

	bio_transfer_timer = bio_transfer_interval
	var transfer_value: int = min(bio_transfer_chunk, bio_cargo)
	var start_pos: Vector2 = get_bio_stack_emit_position()
	bio_cargo -= transfer_value
	update_bio_stack_visual()
	director.spawn_bio_transfer(start_pos, base_entity, transfer_value)

func get_bio_stack_emit_position() -> Vector2:
	var side: float = -1.0 if facing_right else 1.0
	var scale_abs: Vector2 = Vector2(abs(visual_base_scale.x), abs(visual_base_scale.y))
	var outside_x: float = side * (visual_size.x * 0.5 * scale_abs.x + 18.0)
	var lower_y: float = visual_size.y * 0.22 * scale_abs.y
	var stack_index: int = max(get_bio_stack_shown_count() - 1, 0)
	var row_offset: Vector2 = Vector2(side * float(stack_index % 3) * 7.0, -float(stack_index) * 6.0)
	return global_position + Vector2(outside_x, lower_y) + row_offset

func get_bio_stack_shown_count() -> int:
	if bio_cargo <= 0:
		return 0

	var max_icons: int = max(1, int(ceil(float(bio_cargo_max) / float(bio_visual_unit))))
	var icons: int = int(ceil(float(bio_cargo) / float(bio_visual_unit)))
	return clamp(icons, 1, max_icons)

func update_bio_stack_visual() -> void:
	if bio_stack_root == null:
		return

	for child in bio_stack_root.get_children():
		bio_stack_root.remove_child(child)
		child.free()

	var shown: int = get_bio_stack_shown_count()
	var side: float = -1.0 if facing_right else 1.0
	var scale_abs: Vector2 = Vector2(abs(visual_base_scale.x), abs(visual_base_scale.y))
	var outside_x: float = side * (visual_size.x * 0.5 * scale_abs.x + 18.0)
	var lower_y: float = visual_size.y * 0.22 * scale_abs.y
	for i in range(shown):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(bio_texture_path)
		sprite.centered = true
		sprite.position = Vector2(outside_x, lower_y - float(i) * 6.0)
		sprite.scale = Vector2(0.78, 0.78)
		sprite.modulate = Color(1.0, 0.72, 0.95, 0.88)
		sprite.z_index = -shown + i
		bio_stack_root.add_child(sprite)

func get_scaled_damage(base_damage: float, target_entity, attack: Dictionary = {}) -> float:
	var multiplier: float = 1.0

	if attack.has("damage_multipliers"):
		multiplier *= get_multiplier_from_dict(attack.get("damage_multipliers", {}), target_entity)

	multiplier *= get_multiplier_from_dict(damage_multipliers, target_entity)
	if low_hp_attack_damage_mul != 1.0 and max_hp > 0.0 and hp / max_hp <= low_hp_attack_threshold:
		multiplier *= low_hp_attack_damage_mul
	return base_damage * multiplier * get_status_attack_damage_multiplier()

func get_status_attack_damage_multiplier() -> float:
	var multiplier: float = 1.0
	for status in status_effects:
		multiplier *= float(status.get("attack_damage_mul", 1.0))
	return clamp(multiplier, 0.1, 8.0)

func get_status_attack_interval_multiplier() -> float:
	var multiplier: float = 1.0
	for status in status_effects:
		multiplier *= float(status.get("attack_interval_mul", 1.0))
	return clamp(multiplier, 0.05, 4.0)

func get_status_skill_damage_multiplier() -> float:
	var multiplier: float = 1.0
	for status in status_effects:
		multiplier *= float(status.get("skill_damage_mul", 1.0))
	return clamp(multiplier, 0.1, 8.0)

func get_status_mana_recovery_multiplier() -> float:
	var multiplier: float = 1.0
	for status in status_effects:
		multiplier *= float(status.get("mana_recovery_mul", 1.0))
	return clamp(multiplier, 0.1, 8.0)

func get_multiplier_from_dict(multipliers, target_entity) -> float:
	if typeof(multipliers) != TYPE_DICTIONARY:
		return 1.0

	var result: float = 1.0
	var dict: Dictionary = multipliers

	if dict.has(target_entity.entity_type):
		result *= float(dict[target_entity.entity_type])

	if target_entity.is_building and dict.has("building"):
		result *= float(dict["building"])

	for tag in target_entity.tags:
		var key: String = "tag:" + str(tag)
		if dict.has(key):
			result *= float(dict[key])

	return result

func update_attacks(delta: float) -> void:
	# Cheap horde mode: followers outside the local fighting band do not run attack
	# cooldown/target checks every frame. They are bodies in the flow until near enemies.
	if ai_role == "follower" and !follower_precision_active:
		return

	var logic_delta: float = delta
	if ai_mode != "player" and !is_building:
		attack_logic_accum += delta
		attack_logic_timer -= delta
		if attack_logic_timer > 0.0:
			return
		logic_delta = max(attack_logic_accum, delta)
		attack_logic_accum = 0.0
		attack_logic_timer = attack_logic_interval

	for i in range(attacks.size()):
		attack_cooldowns[i] -= logic_delta
		if attack_cooldowns[i] > 0.0:
			continue

		var attack: Dictionary = attacks[i]
		var interval: float = float(attack.get("interval", 1.0))
		attack_cooldowns[i] = interval * get_status_attack_interval_multiplier()

		var requires_target: bool = bool(attack.get("requires_target", true))
		if requires_target and (target == null or !is_instance_valid(target) or target.is_dead):
			continue

		fire_attack(attack)

func fire_attack(attack: Dictionary) -> void:
	var kind: String = str(attack.get("kind", "projectile"))

	if attack_sfx and attack_sfx.stream:
		attack_sfx.play()

	if kind == "melee":
		director.run_attack(self, target, attack)
		return

	if kind == "projectile":
		director.run_attack(self, target, attack)
		return

	if kind == "attack_instance":
		director.run_attack(self, target, attack)
		return

func apply_melee_attack(attack: Dictionary) -> void:
	var melee_range: float = float(attack.get("range", 60.0))
	if target == null or !is_instance_valid(target):
		return

	if global_position.distance_to(target.global_position) > melee_range:
		return

	var damage: float = float(attack.get("damage", attack_power))
	target.take_damage(damage, self)

func take_damage(amount: float, source = null) -> float:
	if is_dead:
		return 0.0

	if invincible or has_status("invincible"):
		return 0.0

	var final_damage: float = 0.0
	if amount > 0.0:
		amount *= get_status_damage_taken_multiplier()
		final_damage = max(1.0, amount - defense)
	hp -= final_damage
	hit_flash_timer = 0.12
	if final_damage > 0.0:
		# A hit unit may be close to player attention. Put its own Sprite2D back
		# temporarily so flash/hit feedback works; it can re-enter batch after sleep.
		if batch_shared_gif_visual_active:
			batch_shared_gif_visual_active = false
			set_shared_gif_sprite_in_batch_tree(false)
			if director != null and director.has_method("mark_shared_gif_batch_dirty"):
				director.call("mark_shared_gif_batch_dirty")
		queue_damage_number(final_damage)

	if hurt_sfx and hurt_sfx.stream:
		hurt_sfx.play()

	if hp <= 0.0:
		flush_damage_number_queue()
		die(source)

	return final_damage

func queue_damage_number(amount: float) -> void:
	if amount <= 0.0 or director == null:
		return
	damage_number_accum += amount
	if damage_number_timer <= 0.0:
		flush_damage_number_queue()
		damage_number_timer = damage_number_min_interval

func update_damage_number_queue(delta: float) -> void:
	if damage_number_timer > 0.0:
		damage_number_timer -= delta
	if damage_number_timer <= 0.0 and damage_number_accum >= 1.0:
		flush_damage_number_queue()
		damage_number_timer = damage_number_min_interval

func flush_damage_number_queue() -> void:
	if director == null or damage_number_accum < 1.0:
		return
	var shown_damage: int = int(round(damage_number_accum))
	damage_number_accum = 0.0
	director.spawn_floating_number(global_position + Vector2(0.0, -radius - 24.0), str(shown_damage), Color(1.0, 0.22, 0.48, 1.0))

func get_status_damage_taken_multiplier() -> float:
	var multiplier: float = 1.0
	for status in status_effects:
		multiplier *= float(status.get("damage_taken_mul", 1.0))
	return clamp(multiplier, 0.1, 8.0)

func heal(amount: float, _source = null, show_number: bool = true) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	var before_hp: float = hp
	hp = min(max_hp, hp + amount)
	var healed: float = hp - before_hp
	if healed > 0.0 and show_number and director != null:
		director.spawn_floating_number(global_position + Vector2(0.0, -radius - 24.0), "+" + str(int(round(healed))), Color(0.45, 1.0, 0.74, 1.0))

func die(source = null) -> void:
	if is_dead:
		return

	is_dead = true
	if batch_shared_gif_visual_active and director != null and director.has_method("mark_shared_gif_batch_dirty"):
		director.call("mark_shared_gif_batch_dirty")
	batch_shared_gif_visual_active = false
	# If the shared Sprite2D had been removed from the tree for batch rendering,
	# it is no longer a child of this entity and would not be freed by queue_free().
	if visual_is_shared_gif_sprite and visual != null and is_instance_valid(visual) and visual.get_parent() == null:
		visual.queue_free()

	if die_sfx and die_sfx.stream:
		die_sfx.play()

	if !death_attack.is_empty() and director != null:
		director.spawn_attack(self, death_attack, {"position": global_position})

	if director != null:
		director.register_entity_death(self, source)

	queue_free()

func update_worker_movement(delta: float) -> void:
	if director == null or director.tentacle_base == null or !is_instance_valid(director.tentacle_base):
		return

	var base_entity = director.tentacle_base
	if bio_cargo > 0:
		if worker_delivery_target == Vector2.ZERO:
			worker_delivery_target = pick_worker_delivery_target(base_entity)
		var to_delivery: Vector2 = worker_delivery_target - global_position
		var deliver_distance: float = max(radius + 42.0, base_entity.delivery_radius * 0.72)
		if to_delivery.length() <= deliver_distance:
			try_transfer_bio_to_base(base_entity, delta)
			if bio_cargo <= 0:
				worker_delivery_target = Vector2.ZERO
				worker_target_drop = null
				worker_wander_target = pick_worker_wander_target(base_entity)
				worker_wander_timer = randf_range(0.45, 1.1)
			return
		move_worker_toward(worker_delivery_target, delta)
		return

	worker_delivery_target = Vector2.ZERO
	worker_target_drop = director.find_nearest_available_bio_drop(global_position, get_worker_seek_radius(), self)
	if worker_target_drop != null and is_instance_valid(worker_target_drop):
		move_worker_toward(worker_target_drop.global_position, delta)
		return

	update_worker_wander(delta, base_entity)

func pick_worker_delivery_target(base_entity) -> Vector2:
	var center: Vector2 = base_entity.get_delivery_center()
	var jitter_radius: float = max(8.0, base_entity.delivery_radius * 0.10)
	for i in range(10):
		var pos: Vector2 = director.clamp_to_map(center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, jitter_radius))
		if director.can_entity_stand_at(self, pos):
			return pos
	return director.clamp_to_map(center)

func get_worker_seek_radius() -> float:
	if director != null and director.tentacle_base != null and is_instance_valid(director.tentacle_base):
		var base_seek_radius: float = max(director.tentacle_base.alert_radius * 1.5, director.tentacle_base.delivery_radius + 180.0)
		if worker_home_radius > 0.0:
			return min(worker_home_radius, base_seek_radius)
		return base_seek_radius
	return 760.0

func move_worker_toward(target_pos: Vector2, delta: float) -> void:
	var dir: Vector2 = target_pos - global_position
	if dir.length() <= 4.0:
		return
	var move_dir: Vector2 = get_worker_move_direction(target_pos)
	update_facing(move_dir)
	var before_move: Vector2 = global_position
	director.move_entity(self, move_dir * move_speed * delta)
	update_stuck_state(before_move, delta)

func get_worker_move_direction(target_pos: Vector2) -> Vector2:
	var to_target: Vector2 = target_pos - global_position
	if to_target.length() <= 0.01:
		return Vector2.ZERO

	var direct: Vector2 = to_target.normalized()
	var forced_side: float = forced_avoid_side if forced_avoid_timer > 0.0 else 0.0
	var building_avoid: Vector2 = director.get_building_avoid_direction(self, direct, target_pos, forced_side, null)
	var wall_avoid: Vector2 = director.get_walkable_avoid_direction(self, direct)
	var result: Vector2 = direct
	if building_avoid.length() > 0.01:
		result = (result * 0.35 + building_avoid * 0.95).normalized()
	if wall_avoid.length() > 0.01:
		result = (result * 0.25 + wall_avoid * 0.95).normalized()
	return result

func update_worker_wander(delta: float, base_entity) -> void:
	worker_wander_timer -= delta
	var seek_radius: float = get_worker_seek_radius()
	var base_center: Vector2 = base_entity.global_position
	var need_new_target: bool = worker_wander_timer <= 0.0
	need_new_target = need_new_target or worker_wander_target == Vector2.ZERO
	need_new_target = need_new_target or global_position.distance_to(worker_wander_target) <= 18.0
	need_new_target = need_new_target or global_position.distance_to(base_center) > seek_radius + 120.0
	need_new_target = need_new_target or forced_avoid_timer > 0.0 and stuck_timer <= 0.01

	if need_new_target:
		worker_wander_target = pick_worker_wander_target(base_entity)
		worker_wander_timer = randf_range(1.2, 2.8)

	move_worker_toward(worker_wander_target, delta)

func pick_worker_wander_target(base_entity) -> Vector2:
	var seek_radius: float = get_worker_seek_radius()
	var center: Vector2 = base_entity.global_position
	var min_radius: float = max(base_entity.block_radius + radius + 42.0, base_entity.delivery_radius * 0.55)
	var max_radius: float = max(seek_radius, min_radius + 80.0)

	for i in range(24):
		var pos: Vector2 = center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(min_radius, max_radius)
		pos = director.clamp_to_map(pos)
		if director.can_entity_stand_at(self, pos):
			return pos

	var delivery_center: Vector2 = base_entity.get_delivery_center()
	for offset in [Vector2(-96.0, 0.0), Vector2(96.0, 0.0), Vector2(0.0, 86.0), Vector2(0.0, -86.0)]:
		var fallback_pos: Vector2 = director.clamp_to_map(delivery_center + offset)
		if director.can_entity_stand_at(self, fallback_pos):
			return fallback_pos

	return director.clamp_to_map(global_position + Vector2.RIGHT.rotated(randf() * TAU) * 80.0)

func pause_worker_by_contact() -> void:
	if entity_type != "worker" and !tags.has("worker"):
		return
	contact_pause_timer = 0.35

func apply_runtime_stat_multipliers(multipliers: Dictionary) -> void:
	if multipliers.is_empty():
		return
	if multipliers.has("max_hp"):
		multiply_max_hp(float(multipliers["max_hp"]))
		hp = max_hp
	if multipliers.has("attack"):
		attack_power *= float(multipliers["attack"])
	if multipliers.has("defense"):
		defense *= float(multipliers["defense"])
	if multipliers.has("move_speed"):
		move_speed *= float(multipliers["move_speed"])
