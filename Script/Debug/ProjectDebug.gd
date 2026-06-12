extends Node

@export var enabled: bool = true
@export var print_scene_changes: bool = true
@export var print_save_snapshot_on_scene_change: bool = true
@export var scene_poll_interval: float = 0.35

var _last_scene_text: String = ""
var _poll_timer: float = 0.0

func _ready() -> void:
	if enabled:
		print("[ProjectDebug] loaded. This node is optional; remove it from Autoload for release builds.")
		_dump_current_scene("ready")
		_dump_save_snapshot("ready")

func _process(delta: float) -> void:
	if !enabled:
		return
	_poll_timer += delta
	if _poll_timer < scene_poll_interval:
		return
	_poll_timer = 0.0
	var scene_text: String = _get_scene_text()
	if scene_text != _last_scene_text:
		_last_scene_text = scene_text
		if print_scene_changes:
			print("[ProjectDebug][Scene] ", scene_text)
		if print_save_snapshot_on_scene_change:
			_dump_save_snapshot("scene_changed")

func log(scope: String, message: String) -> void:
	if enabled:
		print("[ProjectDebug][", scope, "] ", message)

func warn(scope: String, message: String) -> void:
	if enabled:
		push_warning("[ProjectDebug][" + scope + "] " + message)

func dump_save_snapshot(reason: String = "manual") -> void:
	_dump_save_snapshot(reason)

func dump_next_battle(reason: String = "manual") -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		print("[ProjectDebug][NextBattle] no GameState")
		return
	if gs.has_method("get_next_battle_debug_summary"):
		print("[ProjectDebug][NextBattle][", reason, "] ", JSON.stringify(gs.call("get_next_battle_debug_summary")))
	else:
		print("[ProjectDebug][NextBattle] GameState has no get_next_battle_debug_summary")

func _dump_current_scene(reason: String) -> void:
	_last_scene_text = _get_scene_text()
	print("[ProjectDebug][Scene][", reason, "] ", _last_scene_text)

func _dump_save_snapshot(reason: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		print("[ProjectDebug][Save][", reason, "] no GameState autoload found")
		return
	var parts: PackedStringArray = PackedStringArray()
	if gs.has_method("get_active_slot_debug_name"):
		parts.append("slot=" + str(gs.call("get_active_slot_debug_name")))
	if gs.has_method("get_lust"):
		parts.append("lust=" + str(gs.call("get_lust")))
	if gs.has_method("get_chapter_id"):
		parts.append("chapter=" + str(gs.call("get_chapter_id")))
	if gs.has_method("get_next_battle_temp_items"):
		parts.append("temp_items=" + JSON.stringify(gs.call("get_next_battle_temp_items")))
	if gs.has_method("get_merchant_next_battle_effects"):
		parts.append("temp_effects=" + JSON.stringify(gs.call("get_merchant_next_battle_effects")))
	if gs.has_method("get_next_battle_captive_equipment_id"):
		parts.append("captive_eq=" + str(gs.call("get_next_battle_captive_equipment_id")))
	if gs.has_method("get_captives"):
		var captives: Variant = gs.call("get_captives")
		if typeof(captives) == TYPE_DICTIONARY:
			var captive_dict: Dictionary = captives
			parts.append("captives=" + str(captive_dict.size()))
	print("[ProjectDebug][Save][", reason, "] ", " | ".join(parts))

func _get_scene_text() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return "<none>"
	var path: String = scene.scene_file_path
	if path == "":
		path = scene.name
	return path


func dump_battle_modifiers(reason: String = "manual") -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		print("[ProjectDebug][BattleModifiers] no GameState")
		return
	if gs.has_method("build_battle_modifiers"):
		print("[ProjectDebug][BattleModifiers][", reason, "] ", JSON.stringify(gs.call("build_battle_modifiers")))
	elif gs.has_method("get_merchant_next_battle_effects"):
		print("[ProjectDebug][BattleModifiers][", reason, "] merchant_only=", JSON.stringify(gs.call("get_merchant_next_battle_effects")))
	else:
		print("[ProjectDebug][BattleModifiers] no modifier method")
