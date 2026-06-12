extends RefCounted

func run_attack(director, attacker, target, attack: Dictionary) -> void:
	if attacker == null or !is_instance_valid(attacker):
		return

	# IMPORTANT: weapon_rocket/explosive projectiles must stay in the projectile path.
	# Several normalization passes add hit_shape/effects to attacks, and the old generic
	# branch below would convert rockets into BattleAttackInstance/GIFPlayer visuals.
	# That is why the rocket looked like one huge bullet and never printed projectile
	# explosion logs. Force rocket-like attacks through BattleProjectile first.
	if _is_rocket_attack(attack):
		_spawn_projectile(director, attacker, target, _normalize_rocket_projectile_attack(attack))
		return

	var kind: String = str(attack.get("kind", "projectile"))

	if kind == "attack_instance" or attack.has("hit_shape") or attack.has("hit_rule") or attack.has("effects"):
		director.spawn_attack(attacker, attack, {"trigger_target": target})
		return

	if kind == "melee":
		_apply_melee(attacker, target, attack)
		return

	if kind == "projectile":
		_spawn_projectile(director, attacker, target, attack)
		return

func _is_rocket_attack(attack: Dictionary) -> bool:
	var id_text := (str(attack.get("id", "")) + "|" + str(attack.get("attack_id", "")) + "|" + str(attack.get("name", ""))).to_lower()
	if id_text.find("rocket") >= 0 or id_text.find("rpg") >= 0 or id_text.find("火箭") >= 0:
		return true
	var tags_value = attack.get("tags", [])
	if typeof(tags_value) == TYPE_ARRAY:
		for tag in tags_value:
			var t := str(tag).to_lower()
			if t == "rocket" or t == "explosive" or t == "rpg":
				return true
	elif typeof(tags_value) == TYPE_STRING:
		var tags_text := str(tags_value).to_lower()
		if tags_text.find("rocket") >= 0 or tags_text.find("explosive") >= 0 or tags_text.find("rpg") >= 0:
			return true
	return false

func _normalize_rocket_projectile_attack(attack: Dictionary) -> Dictionary:
	var result: Dictionary = attack.duplicate(true)
	result["kind"] = "projectile"
	result["id"] = str(result.get("id", result.get("attack_id", "weapon_rocket")))
	result["is_rocket_projectile"] = true
	result["explode_on_hit"] = true
	result["explode_on_expire"] = bool(result.get("explode_on_expire", true))
	result["damage"] = 0.0
	result["direct_hit_damage"] = 0.0

	var base_damage: float = float(attack.get("explosion_damage", attack.get("damage", 18.0)))
	result["explosion_damage"] = base_damage
	result["explosion_radius"] = float(result.get("explosion_radius", max(150.0, float(result.get("radius", 18.0)) * 5.0)))
	result["explosion_edge_damage_mul"] = float(result.get("explosion_edge_damage_mul", 0.55))
	result["explosion_visual_size"] = float(result.get("explosion_visual_size", result["explosion_radius"] * 2.0))
	result["radius"] = min(float(result.get("radius", 18.0)), 18.0)
	result["speed"] = float(result.get("speed", 320.0))
	result["life_time"] = float(result.get("life_time", 2.6))
	if !result.has("motion"):
		result["motion"] = "homing"
	result.erase("hit_shape")
	result.erase("hit_rule")
	result.erase("effects")

	var visual: Dictionary = result.get("visual", {}) if typeof(result.get("visual", {})) == TYPE_DICTIONARY else {}
	if str(visual.get("texture", visual.get("gif", ""))) == "":
		visual["texture"] = "res://BattleAssets/Textures/RPG.png"
	visual["max_size"] = visual.get("max_size", [44, 44])
	visual["size"] = visual.get("size", [44, 44])
	result["visual"] = visual
	return result

func _apply_melee(attacker, target, attack: Dictionary) -> void:
	if target == null or !is_instance_valid(target):
		return

	var attack_point: Vector2 = attacker.get_attack_point(str(attack.get("fire_point", "center")), attack.get("fire_offset", [0, 0]))
	var target_point: Vector2 = target.get_attack_point(str(attack.get("target_point", "center")), attack.get("target_offset", [0, 0]))
	var attack_range: float = float(attack.get("range", 60.0))

	if attack_point.distance_to(target_point) > attack_range:
		return

	var damage: float = attacker.get_scaled_damage(float(attack.get("damage", attacker.attack_power)), target, attack)
	var dealt: float = target.take_damage(damage, attacker)

	if attack.has("bio_to_base_on_hit") and attacker.director != null:
		attacker.director.add_bio_to_tentacle_base(int(attack.get("bio_to_base_on_hit", 0)))

	if attack.has("bio_to_base_damage_ratio") and attacker.director != null:
		attacker.director.add_bio_to_tentacle_base(int(round(dealt * float(attack.get("bio_to_base_damage_ratio", 0.0)))))

	if attack.has("assimilate_result_entity_id") and attacker.director != null:
		attacker.director.start_assimilation(
			target,
			str(attack.get("assimilate_result_entity_id", "")),
			float(attack.get("assimilate_duration", 1.0)),
			attacker
		)

	_apply_on_hit_statuses(attacker, target, attack)

	if bool(attack.get("suicide_on_hit", false)):
		attacker.die(target)

func _spawn_projectile(director, attacker, target, attack: Dictionary) -> void:
	if director == null:
		return

	var fire_mode: String = str(attack.get("fire_point", "center"))
	var target_mode: String = str(attack.get("target_point", "center"))
	var fire_offset = attack.get("fire_offset", [0, 0])
	var target_offset = attack.get("target_offset", [0, 0])
	var start_pos: Vector2 = attacker.get_attack_point(fire_mode, fire_offset)
	var target_pos: Vector2 = start_pos + Vector2.RIGHT

	if target != null and is_instance_valid(target):
		target_pos = target.get_attack_point(target_mode, target_offset)

	director.spawn_projectile(attacker, target, attack, start_pos, target_pos)

func _apply_on_hit_statuses(attacker, target, attack: Dictionary) -> void:
	if target == null or !is_instance_valid(target):
		return
	var statuses: Array = attack.get("on_hit_statuses", [])
	for status in statuses:
		if typeof(status) != TYPE_DICTIONARY:
			continue
		if target.is_building and !bool(status.get("include_building", false)):
			continue
		var chance: float = float(status.get("chance", 1.0))
		if randf() > chance:
			continue
		target.add_status_effect(status, attacker)
