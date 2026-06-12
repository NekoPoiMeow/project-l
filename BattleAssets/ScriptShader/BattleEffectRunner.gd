extends RefCounted

func apply_effects(director, source, target, effects: Array, context: Dictionary = {}) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue

		apply_effect(director, source, target, effect, context)

func apply_effect(director, source, target, effect: Dictionary, context: Dictionary = {}) -> void:
	var mode: String = str(effect.get("mode", "damage"))

	if mode == "damage":
		apply_damage(director, source, target, effect, context)
		return

	if mode == "heal":
		apply_heal(source, target, effect)
		return

	if mode == "force":
		apply_force(director, target, effect, context)
		return

	if mode == "spawn_attack":
		apply_spawn_attack(director, source, target, effect, context)
		return

	if mode == "status":
		apply_status(source, target, effect)
		return

	if mode == "chain_attack":
		apply_chain_attack(director, source, target, effect, context)
		return

func apply_damage(director, source, target, effect: Dictionary, context: Dictionary = {}) -> void:
	if target == null or !is_instance_valid(target):
		return

	if target.is_dead:
		return

	var value: float = float(effect.get("value", effect.get("damage", 0.0)))
	value *= get_life_scale(effect, context)
	value *= get_distance_scale(target, effect, context)
	value += get_attack_bonus_damage(context)
	value += get_mechanic_bonus_damage(target, context)
	value *= get_mechanic_damage_multiplier(target, context)
	value *= get_ramp_damage_multiplier(context)
	value *= get_attack_crit_multiplier(context)
	if source != null and is_instance_valid(source):
		value = source.get_scaled_damage(value, target, effect)

	var dealt: float = target.take_damage(value, source)
	if dealt > 0.0 and director != null and director.has_method("notify_attack_hit"):
		director.notify_attack_hit(source, target, dealt, context)
	apply_attack_on_damage(source, target, dealt, context)
	var life_steal: float = float(effect.get("life_steal", 0.0))
	if life_steal > 0.0 and source != null and is_instance_valid(source):
		source.heal(dealt * life_steal, source)

func get_attack_bonus_damage(context: Dictionary) -> float:
	var attack = context.get("attack", {})
	if typeof(attack) != TYPE_DICTIONARY:
		return 0.0
	return float(attack.get("bonus_damage_add", 0.0))

func get_attack_crit_multiplier(context: Dictionary) -> float:
	var attack = context.get("attack", {})
	if typeof(attack) != TYPE_DICTIONARY:
		return 1.0

	var crit_chance: float = float(attack.get("crit_chance", 0.0))
	if crit_chance <= 0.0:
		return 1.0

	if randf() > crit_chance:
		return 1.0
	var crit_mul: float = max(1.0, float(attack.get("crit_multiplier", 1.5)))
	print("[BattleCrit] attack=", str(attack.get("id", "")), " chance=", snapped(crit_chance, 0.001), " mul=", snapped(crit_mul, 0.01))
	return crit_mul

func get_mechanic_bonus_damage(target, context: Dictionary) -> float:
	var attack = context.get("attack", {})
	if typeof(attack) != TYPE_DICTIONARY:
		return 0.0

	var mechanics: Array = attack.get("mechanics", [])
	var bonus: float = 0.0
	if mechanics.has("boomerang_percent_hp") and target != null and is_instance_valid(target) and !target.is_building:
		bonus += min(target.hp * 0.10, 120.0)
	return bonus

func get_mechanic_damage_multiplier(target, context: Dictionary) -> float:
	var attack = context.get("attack", {})
	if typeof(attack) != TYPE_DICTIONARY:
		return 1.0

	if target == null or !is_instance_valid(target) or target.max_hp <= 0.0:
		return 1.0

	var mechanics: Array = attack.get("mechanics", [])
	var ratio: float = target.hp / target.max_hp
	var multiplier: float = 1.0
	if mechanics.has("low_hp_bonus") and ratio <= 0.35:
		multiplier *= 1.45
	if mechanics.has("high_hp_percent_bonus") and ratio >= 0.70:
		multiplier *= 1.35
	if mechanics.has("execute_low_hp") and ratio <= 0.18:
		multiplier *= 2.2
	if mechanics.has("late_life_bonus") and float(context.get("life_ratio", 0.0)) >= 0.65:
		multiplier *= 1.28
	if mechanics.has("same_target_rend"):
		multiplier *= 1.12
	if mechanics.has("shock_counter_execute") and randf() < min(0.02 + ratio * 0.02, 0.06):
		multiplier *= 3.0
	return multiplier

func get_ramp_damage_multiplier(context: Dictionary) -> float:
	var attack = context.get("attack", {})
	if typeof(attack) != TYPE_DICTIONARY:
		return 1.0
	var ramp: float = float(attack.get("ramp_damage", 0.0))
	if ramp <= 0.0:
		return 1.0
	return 1.0 + clamp(float(context.get("life_ratio", 0.0)), 0.0, 1.0) * ramp

func apply_attack_on_damage(source, _target, dealt: float, context: Dictionary) -> void:
	if dealt <= 0.0:
		return
	var attack = context.get("attack", {})
	if typeof(attack) != TYPE_DICTIONARY:
		return
	if source != null and is_instance_valid(source):
		var heal_on_hit: float = float(attack.get("heal_on_hit", 0.0))
		if heal_on_hit > 0.0:
			source.heal(heal_on_hit, source)

func get_life_scale(effect: Dictionary, context: Dictionary) -> float:
	if !effect.has("scale_over_life"):
		return 1.0

	var scale_data = effect.get("scale_over_life", {})
	if typeof(scale_data) != TYPE_DICTIONARY:
		return 1.0

	var ratio: float = float(context.get("life_ratio", 0.0))
	var from_value: float = float(scale_data.get("from", 1.0))
	var to_value: float = float(scale_data.get("to", 1.0))
	var curve: String = str(scale_data.get("curve", "linear"))
	if curve == "ease_out":
		ratio = 1.0 - pow(1.0 - ratio, 2.0)
	elif curve == "ease_in":
		ratio = ratio * ratio

	return lerp(from_value, to_value, clamp(ratio, 0.0, 1.0))

func get_distance_scale(target, effect: Dictionary, context: Dictionary) -> float:
	if !effect.has("scale_by_distance"):
		return 1.0

	if target == null or !is_instance_valid(target):
		return 1.0

	var scale_data = effect.get("scale_by_distance", {})
	if typeof(scale_data) != TYPE_DICTIONARY:
		return 1.0

	var origin: Vector2 = context.get("position", target.global_position)
	var radius: float = max(float(context.get("radius", 1.0)), 1.0)
	var ratio: float = clamp(target.global_position.distance_to(origin) / radius, 0.0, 1.0)
	var from_value: float = float(scale_data.get("from", 1.0))
	var to_value: float = float(scale_data.get("to", 1.0))
	return lerp(from_value, to_value, ratio)

func apply_heal(source, target, effect: Dictionary) -> void:
	if target == null or !is_instance_valid(target):
		return

	if target.is_dead:
		return

	var value: float = float(effect.get("value", effect.get("heal", 0.0)))
	target.heal(value, source)

func apply_status(source, target, effect: Dictionary) -> void:
	if target == null or !is_instance_valid(target):
		return

	if target.is_dead or target.is_building:
		return

	target.add_status_effect(effect, source)

func apply_force(director, target, effect: Dictionary, context: Dictionary = {}) -> void:
	if director == null:
		return

	if target == null or !is_instance_valid(target):
		return

	if target.is_dead or target.is_building:
		return

	var force_type: String = str(effect.get("force_type", "push"))
	var strength: float = float(effect.get("strength", 120.0))
	var origin: Vector2 = context.get("position", target.global_position)
	var dir: Vector2 = Vector2.ZERO

	if force_type == "pull_to_origin":
		dir = origin - target.global_position
	elif force_type == "push_from_origin":
		dir = target.global_position - origin
	else:
		dir = context.get("direction", Vector2.ZERO)

	if dir.length() <= 0.01:
		return

	var falloff: String = str(effect.get("falloff", "none"))
	var scale: float = 1.0
	if falloff == "distance":
		var radius: float = max(float(context.get("radius", 1.0)), 1.0)
		scale = 1.0 - clamp(target.global_position.distance_to(origin) / radius, 0.0, 1.0)
	elif falloff == "inverse_distance":
		var radius: float = max(float(context.get("radius", 1.0)), 1.0)
		var ratio: float = clamp(target.global_position.distance_to(origin) / radius, 0.0, 1.0)
		var min_scale: float = float(effect.get("min_scale", 0.25))
		scale = lerp(1.0, min_scale, ratio * ratio)

	var delta: float = float(context.get("delta", 1.0 / 60.0))
	director.move_entity(target, dir.normalized() * strength * scale * delta)

func apply_spawn_attack(director, source, target, effect: Dictionary, context: Dictionary = {}) -> void:
	if director == null:
		return

	var chain_depth: int = int(context.get("chain_depth", 0))
	var max_depth: int = int(effect.get("max_depth", context.get("max_depth", 4)))
	if chain_depth >= max_depth:
		return

	var attack: Dictionary = {}
	if effect.has("attack"):
		attack = effect.get("attack", {})
	elif effect.has("attack_id"):
		attack = director.load_attack_data(str(effect.get("attack_id", "")))

	if attack.is_empty():
		return

	var next_context: Dictionary = context.duplicate(true)
	next_context["chain_depth"] = chain_depth + 1
	next_context["trigger_target"] = target
	var spawn_position: Vector2 = context.get("position", Vector2.ZERO)
	if !context.has("position") and target != null and is_instance_valid(target):
		spawn_position = target.global_position
	next_context["position"] = spawn_position

	if effect.has("emitter_override"):
		attack = attack.duplicate(true)
		attack["emitter"] = effect.get("emitter_override", {})

	director.spawn_attack(source, attack, next_context)

func apply_chain_attack(director, source, target, effect: Dictionary, context: Dictionary = {}) -> void:
	if director == null or target == null or !is_instance_valid(target):
		return

	var chain_depth: int = int(context.get("chain_depth", 0))
	var max_depth: int = int(effect.get("max_depth", 4))
	if chain_depth >= max_depth:
		return

	var radius: float = float(effect.get("radius", 360.0))
	var attack: Dictionary = {}
	if effect.has("attack"):
		attack = effect.get("attack", {})
	elif effect.has("attack_id"):
		attack = director.load_attack_data(str(effect.get("attack_id", "")))
	elif context.has("chain_attack"):
		attack = context.get("chain_attack", {})
	if attack.is_empty():
		return

	var best = null
	var best_dist: float = INF
	for entity in director.entities:
		if entity == null or !is_instance_valid(entity):
			continue
		if entity == target or entity.is_dead:
			continue
		if source != null and is_instance_valid(source):
			if director.are_factions_allied(entity.faction, source.faction):
				continue
		var dist: float = target.global_position.distance_to(entity.global_position)
		if dist <= radius and dist < best_dist:
			best = entity
			best_dist = dist

	if best == null:
		return

	var next_context: Dictionary = context.duplicate(true)
	next_context["chain_depth"] = chain_depth + 1
	next_context["chain_attack"] = attack
	next_context["position"] = target.global_position
	next_context["trigger_target"] = best
	next_context["direction"] = (best.global_position - target.global_position).normalized()
	if director.has_method("spawn_textured_line_fx"):
		director.spawn_textured_line_fx(target.global_position, best.global_position, "res://BattleAssets/Lighting.png", 56.0, 0.22, Color(1.0, 0.92, 0.35, 0.98))
	elif director.has_method("spawn_line_fx"):
		director.spawn_line_fx(target.global_position, best.global_position, Color(1.0, 0.88, 0.35, 0.98), 20.0, 0.28)
		director.spawn_line_fx(target.global_position, best.global_position, Color(1.0, 0.25, 0.92, 0.70), 7.0, 0.34)
	director.spawn_attack(source, attack, next_context)
