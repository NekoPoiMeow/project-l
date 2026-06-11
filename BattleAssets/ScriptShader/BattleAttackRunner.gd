extends RefCounted

func run_attack(director, attacker, target, attack: Dictionary) -> void:
	if attacker == null or !is_instance_valid(attacker):
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
