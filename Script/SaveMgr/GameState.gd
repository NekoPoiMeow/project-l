extends Node

signal state_loaded
signal state_saved

const SAVE_DIR := "res://Save"
const MANUAL_SLOT_PATH := "res://Save/Save1.txt"
const DEFAULT_SLOT_PATH := "res://Save/Save1.txt"
const AUTO_SLOT_PATHS := ["res://Save/SaveAuto.txt", "res://Save/SaveAuto2.txt"]
const DEFAULT_SAVE_IMAGE_PATH := "res://Save/Save0.png"
const BASEMENT_SCENE_PATH := "res://scenes/Basement.tscn"
const SAVE_FORMAT_VERSION := 1

var active_slot_path := ""
var active_slot_id := ""
var active_manual_slot_path := ""
var is_loaded := false
var dirty := false
var data: Dictionary = {}

func _ready() -> void:
	reset_to_default()

func reset_to_default() -> void:
	data = make_default_data()
	active_slot_path = ""
	active_slot_id = ""
	active_manual_slot_path = ""
	is_loaded = false
	dirty = false

func make_default_data() -> Dictionary:
	return {
		"meta": {
			"format_version": SAVE_FORMAT_VERSION,
			"slot_id": "Save1",
			"slot_role": "manual",
			"is_zero_progress": false,
			"save_name": "New Game",
			"save_time": "",
			"chapter_id": 0,
			"chapter_name": "未开始",
			"last_scene": BASEMENT_SCENE_PATH,
			"play_seconds": 0,
			"autosave_generation": 0,
			"last_autosave_slot": "SaveAuto2",
			"last_loaded_slot": "",
		},
		"economy": {
			"lust": 0,
			"humiliation": 0,
		},
		"battle_loadout": {
			"character_id": "C001",
			"weapon_id": "W001",
			"equipment_id": "E001",
		},
		"progress": {
			"unlocked_chapters": [],
			"unlocked_levels": [],
			"cleared_levels": [],
			"last_level_id": "",
			"level_bonus_collect": {},
		},
		"unlocks": {
			"characters": ["C001"],
			"weapons": ["W001"],
			"equipments": ["E001"],
			"captives": [],
			"torture_items": ["T_RIDINGCROP_001"],
			"temporary_items_seen": [],
			"story_events": [],
			"cg_events": [],
			"narrative_events": [],
			"codex": [],
		},
		"upgrades": {
			"player": {},
			"base": {},
			"minion": {},
			"dungeon": {},
			"merchant": {},
		},
		"dungeon": {
			"captives": {},
			"last_processed_battle_id": "",
			"next_battle_captive_equipment_id": "",
			"events_seen": {},
			"last_event_id": "",
			"last_story_event_id": "",
			"last_action_result": {},
		},
		"merchant": {
			"next_battle_effects": {},
			"next_battle_temp_items": [],
			"purchases": {},
			"events_seen": {},
			"last_purchase_id": "",
		},
		"story": {
			"events_seen": {},
			"cg_seen": {},
			"narrative_flags": {},
			"pending_event_id": "",
			"last_event_id": "",
		},
		"runtime": {
			"pending_battle_modifiers": {},
			"pending_battle_sources": [],
			"last_battle_clear_reason": "",
		},
		"flags": {},
	}

func start_new_game(slot_path: String = DEFAULT_SLOT_PATH) -> void:
	active_slot_path = normalize_slot_path(slot_path)
	active_slot_id = get_slot_id_from_path(active_slot_path)
	active_manual_slot_path = active_slot_path
	data = make_default_data()
	data["meta"]["slot_id"] = active_slot_id
	data["meta"]["slot_role"] = get_slot_role_from_path(active_slot_path)
	data["meta"]["is_zero_progress"] = false
	is_loaded = true
	dirty = true
	save_manual_now("new_game")
	state_loaded.emit()

func load_slot(slot_path: String) -> bool:
	var normalized_path: String = normalize_slot_path(slot_path)
	active_slot_path = normalized_path
	active_slot_id = get_slot_id_from_path(active_slot_path)
	if get_slot_role_from_path(active_slot_path) == "manual":
		active_manual_slot_path = active_slot_path

	if !FileAccess.file_exists(normalized_path):
		start_new_game(normalized_path)
		return true

	var loaded_data: Dictionary = read_slot_data(normalized_path)
	if loaded_data.is_empty():
		start_new_game(normalized_path)
		return true

	data = merge_defaults(loaded_data)
	data["meta"]["slot_id"] = active_slot_id
	data["meta"]["slot_role"] = get_slot_role_from_path(active_slot_path)
	data["meta"]["last_loaded_slot"] = active_slot_id
	is_loaded = true
	dirty = false
	state_loaded.emit()
	return true

func read_slot_data(slot_path: String) -> Dictionary:
	var file := FileAccess.open(slot_path, FileAccess.READ)
	if file == null:
		return {}

	var content: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = content.split("\n", false)
	var json_text := ""
	var legacy: Dictionary = {}

	for line in lines:
		var clean_line: String = line.strip_edges()
		if clean_line == "":
			continue
		if clean_line.begins_with("SaveDataJSON="):
			json_text = clean_line.substr("SaveDataJSON=".length())
		elif "=" in clean_line:
			var parts: PackedStringArray = clean_line.split("=", false, 1)
			if parts.size() >= 2:
				legacy[parts[0].strip_edges()] = parts[1].strip_edges()

	if json_text != "":
		var parsed = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed

	if legacy.is_empty():
		return {}

	var converted: Dictionary = make_default_data()
	converted["meta"]["save_name"] = str(legacy.get("SaveName", "New Game"))
	converted["meta"]["save_time"] = str(legacy.get("SaveTime", ""))
	converted["meta"]["chapter_id"] = int(legacy.get("SaveChapterID", 0))
	converted["meta"]["chapter_name"] = str(legacy.get("SaveChapterName", "未开始"))
	return converted

func merge_defaults(loaded_data: Dictionary) -> Dictionary:
	var result: Dictionary = make_default_data()
	deep_merge(result, loaded_data)
	normalize_save_schema(result)
	return result

func deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			deep_merge(target[key], source[key])
		else:
			target[key] = source[key]


func normalize_save_schema(save_data: Dictionary) -> void:
	# Central schema migration. Keep old saves playable, but only write the new MVP keys.
	var defaults: Dictionary = make_default_data()
	for key in defaults.keys():
		if !save_data.has(key):
			save_data[key] = defaults[key].duplicate(true) if typeof(defaults[key]) in [TYPE_DICTIONARY, TYPE_ARRAY] else defaults[key]

	ensure_dict(save_data, "meta")
	ensure_dict(save_data, "economy")
	ensure_dict(save_data, "progress")
	ensure_dict(save_data, "unlocks")
	ensure_dict(save_data, "upgrades")
	ensure_dict(save_data, "dungeon")
	ensure_dict(save_data, "merchant")
	ensure_dict(save_data, "story")
	ensure_dict(save_data, "runtime")
	ensure_dict(save_data, "flags")
	ensure_dict(save_data, "battle_loadout")

	# Economy.
	save_data["economy"]["lust"] = int(save_data["economy"].get("lust", 0))
	save_data["economy"]["humiliation"] = int(save_data["economy"].get("humiliation", 0))

	# Progress. level_bonus_collect is legacy; unlocked_levels is the actual unlock list now.
	ensure_array(save_data["progress"], "unlocked_chapters")
	ensure_array(save_data["progress"], "unlocked_levels")
	ensure_array(save_data["progress"], "cleared_levels")
	ensure_dict(save_data["progress"], "level_bonus_collect")
	if !save_data["progress"].has("last_level_id"):
		save_data["progress"]["last_level_id"] = ""

	# Unlock categories aligned with Config CSVs.
	for category in ["characters", "weapons", "equipments", "captives", "torture_items", "temporary_items_seen", "story_events", "cg_events", "narrative_events", "codex"]:
		ensure_array(save_data["unlocks"], category)
	append_unique(save_data["unlocks"]["characters"], "C001")
	append_unique(save_data["unlocks"]["weapons"], "W001")
	append_unique(save_data["unlocks"]["equipments"], "E001")
	append_unique(save_data["unlocks"]["torture_items"], "T_RIDINGCROP_001")

	# Upgrade group migration: old building -> base, old tentacle -> minion.
	ensure_dict(save_data["upgrades"], "player")
	ensure_dict(save_data["upgrades"], "base")
	ensure_dict(save_data["upgrades"], "minion")
	ensure_dict(save_data["upgrades"], "dungeon")
	ensure_dict(save_data["upgrades"], "merchant")
	if save_data["upgrades"].has("building") and typeof(save_data["upgrades"]["building"]) == TYPE_DICTIONARY:
		deep_merge(save_data["upgrades"]["base"], save_data["upgrades"]["building"])
		save_data["upgrades"].erase("building")
	if save_data["upgrades"].has("tentacle") and typeof(save_data["upgrades"]["tentacle"]) == TYPE_DICTIONARY:
		deep_merge(save_data["upgrades"]["minion"], save_data["upgrades"]["tentacle"])
		save_data["upgrades"].erase("tentacle")

	# Dungeon.
	ensure_dict(save_data["dungeon"], "captives")
	ensure_dict(save_data["dungeon"], "events_seen")
	if !save_data["dungeon"].has("last_processed_battle_id"):
		save_data["dungeon"]["last_processed_battle_id"] = ""
	if !save_data["dungeon"].has("next_battle_captive_equipment_id"):
		save_data["dungeon"]["next_battle_captive_equipment_id"] = ""
	if !save_data["dungeon"].has("last_event_id"):
		save_data["dungeon"]["last_event_id"] = ""
	if !save_data["dungeon"].has("last_story_event_id"):
		save_data["dungeon"]["last_story_event_id"] = ""
	ensure_dict(save_data["dungeon"], "last_action_result")
	# Merchant.
	ensure_dict(save_data["merchant"], "next_battle_effects")
	ensure_array(save_data["merchant"], "next_battle_temp_items")
	ensure_dict(save_data["merchant"], "purchases")
	ensure_dict(save_data["merchant"], "events_seen")
	if !save_data["merchant"].has("last_purchase_id"):
		save_data["merchant"]["last_purchase_id"] = ""

	# Story / CG state.
	ensure_dict(save_data["story"], "events_seen")
	ensure_dict(save_data["story"], "cg_seen")
	ensure_dict(save_data["story"], "narrative_flags")
	if !save_data["story"].has("pending_event_id"):
		save_data["story"]["pending_event_id"] = ""
	if !save_data["story"].has("last_event_id"):
		save_data["story"]["last_event_id"] = ""

	# Runtime data that can be read by BattleDirector. It is persisted only so reload-before-battle keeps the pending state.
	ensure_dict(save_data["runtime"], "pending_battle_modifiers")
	ensure_array(save_data["runtime"], "pending_battle_sources")
	if !save_data["runtime"].has("last_battle_clear_reason"):
		save_data["runtime"]["last_battle_clear_reason"] = ""

	# Loadout.
	save_data["battle_loadout"]["character_id"] = str(save_data["battle_loadout"].get("character_id", "C001"))
	save_data["battle_loadout"]["weapon_id"] = str(save_data["battle_loadout"].get("weapon_id", "W001"))
	save_data["battle_loadout"]["equipment_id"] = str(save_data["battle_loadout"].get("equipment_id", "E001"))

func ensure_dict(parent: Dictionary, key: String) -> void:
	if !parent.has(key) or typeof(parent[key]) != TYPE_DICTIONARY:
		parent[key] = {}

func ensure_array(parent: Dictionary, key: String) -> void:
	if !parent.has(key) or typeof(parent[key]) != TYPE_ARRAY:
		parent[key] = []

func append_unique(array_value: Array, item_id: String) -> void:
	if item_id != "" and !array_value.has(item_id):
		array_value.append(item_id)

func normalize_upgrade_group(group_name: String) -> String:
	var clean: String = group_name.strip_edges()
	if clean == "building":
		return "base"
	if clean == "tentacle":
		return "minion"
	return clean

func get_active_slot_debug_name() -> String:
	ensure_loaded()
	return "%s | lust=%d | chapter=%d | save_time=%s" % [active_slot_path, get_lust(), get_chapter_id(), str(data.get("meta", {}).get("save_time", ""))]

func print_save_debug(context: String = "") -> void:
	ensure_loaded()
	print("[GameState] ", context, " slot=", active_slot_path, " id=", active_slot_id, " lust=", get_lust(), " temp_items=", get_next_battle_temp_items(), " captive_equipment=", get_next_battle_captive_equipment_id(), " captives=", get_captives().keys())

func save_now(reason: String = "manual") -> bool:
	if !is_loaded:
		return false

	if active_slot_path == "":
		active_slot_path = DEFAULT_SLOT_PATH
		active_slot_id = get_slot_id_from_path(active_slot_path)
	if active_manual_slot_path == "":
		active_manual_slot_path = MANUAL_SLOT_PATH

	var role := get_slot_role_from_path(active_slot_path)
	var ok := write_slot(active_slot_path, role, reason)
	if ok:
		dirty = false
		state_saved.emit()
	return ok

func save_manual_now(reason: String = "manual") -> bool:
	ensure_loaded()
	if active_manual_slot_path == "":
		active_manual_slot_path = MANUAL_SLOT_PATH
	active_slot_path = active_manual_slot_path
	active_slot_id = get_slot_id_from_path(active_slot_path)
	var ok := write_slot(active_manual_slot_path, "manual", reason)
	if ok:
		dirty = false
		state_saved.emit()
	return ok

func write_slot(slot_path: String, slot_role: String, reason: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	normalize_save_schema(data)

	var slot_data: Dictionary = data.duplicate(true)
	slot_data["meta"]["format_version"] = SAVE_FORMAT_VERSION
	slot_data["meta"]["slot_id"] = get_slot_id_from_path(slot_path)
	slot_data["meta"]["slot_role"] = slot_role
	slot_data["meta"]["is_zero_progress"] = false
	slot_data["meta"]["save_time"] = Time.get_datetime_string_from_system(false, true)

	var file := FileAccess.open(slot_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write save: " + slot_path)
		return false

	file.store_line("SaveSlotId=" + str(slot_data["meta"].get("slot_id", "")))
	file.store_line("SaveRole=" + slot_role)
	file.store_line("SaveName=" + str(slot_data["meta"].get("save_name", "New Game")))
	file.store_line("SaveTime=" + str(slot_data["meta"].get("save_time", "")))
	file.store_line("SaveChapterID=" + str(slot_data["meta"].get("chapter_id", 0)))
	file.store_line("SaveChapterName=" + str(slot_data["meta"].get("chapter_name", "未开始")))
	file.store_line("SaveFormatVersion=" + str(SAVE_FORMAT_VERSION))
	file.store_line("SaveReason=" + reason)
	file.store_line("SaveDataJSON=" + JSON.stringify(slot_data))
	file.close()
	update_slot_preview_image(slot_path, int(slot_data["meta"].get("chapter_id", 0)))
	return true

func autosave(reason: String = "autosave") -> bool:
	ensure_loaded()
	mark_dirty()
	var next_auto_path := get_next_autosave_path()
	var next_auto_id := get_slot_id_from_path(next_auto_path)
	data["meta"]["last_autosave_slot"] = next_auto_id
	data["meta"]["autosave_generation"] = int(data["meta"].get("autosave_generation", 0)) + 1
	var ok := write_slot(next_auto_path, "autosave", reason)
	if ok:
		dirty = false
		state_saved.emit()
	return ok

func save_progress_now(reason: String = "progress") -> bool:
	# Important: out-of-battle upgrades and loadout must survive a normal game restart.
	# Autosave alone is easy to miss if the title screen loads the manual slot, so write both.
	ensure_loaded()
	var auto_ok: bool = autosave(reason)
	var manual_ok: bool = save_manual_now(reason)
	return auto_ok or manual_ok


func get_next_autosave_path() -> String:
	var last_auto_id := str(data.get("meta", {}).get("last_autosave_slot", "SaveAuto2"))
	if last_auto_id == "SaveAuto":
		return AUTO_SLOT_PATHS[1]
	return AUTO_SLOT_PATHS[0]

func mark_dirty() -> void:
	dirty = true

func ensure_loaded() -> void:
	if is_loaded:
		normalize_save_schema(data)
		return
	var boot_path: String = get_best_boot_slot_path()
	if boot_path != "" and FileAccess.file_exists(boot_path):
		load_slot(boot_path)
	else:
		start_new_game(DEFAULT_SLOT_PATH)

func get_best_boot_slot_path() -> String:
	# Development-friendly fallback: if a scene is run directly, do not silently create a fresh 0-lust state.
	# Pick the newest non-zero save among manual and autosaves, otherwise Save1.
	var candidates: Array[String] = [MANUAL_SLOT_PATH, AUTO_SLOT_PATHS[0], AUTO_SLOT_PATHS[1]]
	var best_path: String = ""
	var best_score: int = -999999
	for path: String in candidates:
		if !FileAccess.file_exists(path):
			continue
		var slot_data: Dictionary = read_slot_data(path)
		if slot_data.is_empty():
			continue
		var meta: Dictionary = slot_data.get("meta", {}) if typeof(slot_data.get("meta", {})) == TYPE_DICTIONARY else {}
		var economy: Dictionary = slot_data.get("economy", {}) if typeof(slot_data.get("economy", {})) == TYPE_DICTIONARY else {}
		var score: int = 0
		if int(economy.get("lust", 0)) > 0:
			score += 100000
		if int(meta.get("chapter_id", 0)) > 0:
			score += 1000 + int(meta.get("chapter_id", 0))
		score += int(meta.get("autosave_generation", 0))
		if path == MANUAL_SLOT_PATH:
			score += 10
		if score > best_score:
			best_score = score
			best_path = path
	if best_path == "":
		return DEFAULT_SLOT_PATH
	return best_path

func reload_active_slot_from_disk() -> bool:
	if active_slot_path == "":
		return false
	return load_slot(active_slot_path)

func set_last_scene(scene_path: String, autosave_now: bool = true) -> void:
	ensure_loaded()
	data["meta"]["last_scene"] = scene_path
	mark_dirty()
	if autosave_now:
		autosave("last_scene")

func set_chapter(chapter_id: int, chapter_name: String, autosave_now: bool = true) -> void:
	ensure_loaded()
	data["meta"]["chapter_id"] = chapter_id
	data["meta"]["chapter_name"] = chapter_name
	var chapter_key := str(chapter_id)
	if chapter_id > 0 and !data["progress"]["unlocked_chapters"].has(chapter_key):
		data["progress"]["unlocked_chapters"].append(chapter_key)
	mark_dirty()
	if autosave_now:
		autosave("chapter")

func set_chapter_progress(chapter_id: int, chapter_name: String = "", reason: String = "chapter_progress", autosave_now: bool = true) -> void:
	var display_name := chapter_name
	if display_name == "":
		display_name = "Chapter " + str(chapter_id)
	set_chapter(chapter_id, display_name, false)
	if autosave_now:
		autosave(reason)

func on_basement_loaded() -> void:
	ensure_loaded()
	var current_chapter := int(data["meta"].get("chapter_id", 0))
	if current_chapter <= 0:
		set_chapter(1, "Chapter 1", false)
	data["meta"]["last_scene"] = BASEMENT_SCENE_PATH
	mark_dirty()
	autosave("basement_loaded")

func unlock_level(level_id: String, autosave_now: bool = true) -> void:
	ensure_loaded()
	var clean_id: String = level_id.strip_edges()
	if clean_id == "":
		return
	if !data["progress"]["unlocked_levels"].has(clean_id):
		data["progress"]["unlocked_levels"].append(clean_id)
	# Legacy compatibility: keep the old dictionary but do not treat it as the source of truth.
	data["progress"]["level_bonus_collect"][clean_id] = int(data["progress"]["level_bonus_collect"].get(clean_id, 0))
	mark_dirty()
	if autosave_now:
		autosave("unlock_level")

func is_level_unlocked(level_id: String) -> bool:
	ensure_loaded()
	return data["progress"].get("unlocked_levels", []).has(level_id)

func record_level_clear(level_id: String, bonus_collect: int = 1, autosave_now: bool = true) -> void:
	ensure_loaded()
	if !data["progress"]["cleared_levels"].has(level_id):
		data["progress"]["cleared_levels"].append(level_id)
	if !data["progress"].get("unlocked_levels", []).has(level_id):
		data["progress"]["unlocked_levels"].append(level_id)
	data["progress"]["last_level_id"] = level_id
	var current_bonus: int = int(data["progress"]["level_bonus_collect"].get(level_id, 0))
	data["progress"]["level_bonus_collect"][level_id] = max(current_bonus, bonus_collect)
	mark_dirty()
	if autosave_now:
		autosave("level_clear")

func add_lust(amount: int, autosave_now: bool = true) -> void:
	ensure_loaded()
	data["economy"]["lust"] = max(0, int(data["economy"].get("lust", 0)) + amount)
	mark_dirty()
	if autosave_now:
		autosave("lust")

func spend_lust(amount: int, autosave_now: bool = true) -> bool:
	ensure_loaded()
	var current: int = int(data["economy"].get("lust", 0))
	if current < amount:
		return false
	data["economy"]["lust"] = current - amount
	mark_dirty()
	if autosave_now:
		autosave("spend_lust")
	return true

func add_humiliation(amount: int, autosave_now: bool = true) -> void:
	ensure_loaded()
	data["economy"]["humiliation"] = max(0, int(data["economy"].get("humiliation", 0)) + amount)
	mark_dirty()
	if autosave_now:
		autosave("humiliation")

func unlock_item(category: String, item_id: String, autosave_now: bool = true) -> void:
	ensure_loaded()
	if !data["unlocks"].has(category):
		data["unlocks"][category] = []
	if !data["unlocks"][category].has(item_id):
		data["unlocks"][category].append(item_id)
		mark_dirty()
	if autosave_now:
		autosave("unlock_" + category)

func is_unlocked(category: String, item_id: String) -> bool:
	ensure_loaded()
	if !data["unlocks"].has(category):
		return false
	return data["unlocks"][category].has(item_id)

func set_upgrade_level(group_name: String, upgrade_id: String, level: int, autosave_now: bool = true) -> void:
	ensure_loaded()
	var group_key: String = normalize_upgrade_group(group_name)
	if !data["upgrades"].has(group_key):
		data["upgrades"][group_key] = {}
	data["upgrades"][group_key][upgrade_id] = max(0, level)
	mark_dirty()
	if autosave_now:
		autosave("upgrade")

func get_upgrade_level(group_name: String, upgrade_id: String) -> int:
	ensure_loaded()
	var group_key: String = normalize_upgrade_group(group_name)
	if !data["upgrades"].has(group_key):
		return 0
	return int(data["upgrades"][group_key].get(upgrade_id, 0))

func set_battle_loadout(loadout: Dictionary, autosave_now: bool = true) -> void:
	ensure_loaded()
	if !data.has("battle_loadout") or typeof(data["battle_loadout"]) != TYPE_DICTIONARY:
		data["battle_loadout"] = {}
	var clean: Dictionary = data["battle_loadout"]
	clean["character_id"] = str(loadout.get("character_id", clean.get("character_id", "C001")))
	clean["weapon_id"] = str(loadout.get("weapon_id", clean.get("weapon_id", "W001")))
	clean["equipment_id"] = str(loadout.get("equipment_id", clean.get("equipment_id", "E001")))
	data["battle_loadout"] = clean
	mark_dirty()
	if autosave_now:
		save_progress_now("battle_loadout")

func get_battle_loadout() -> Dictionary:
	ensure_loaded()
	if !data.has("battle_loadout") or typeof(data["battle_loadout"]) != TYPE_DICTIONARY:
		data["battle_loadout"] = {"character_id": "C001", "weapon_id": "W001", "equipment_id": "E001"}
	var raw: Dictionary = data["battle_loadout"]
	return {
		"character_id": str(raw.get("character_id", "C001")),
		"weapon_id": str(raw.get("weapon_id", "W001")),
		"equipment_id": str(raw.get("equipment_id", "E001")),
	}

func get_lust() -> int:
	ensure_loaded()
	return int(data["economy"].get("lust", 0))

func get_humiliation() -> int:
	ensure_loaded()
	return int(data["economy"].get("humiliation", 0))

func set_last_battle_result(result: Dictionary, autosave_now: bool = true) -> void:
	ensure_loaded()
	data["flags"]["last_battle_result"] = result
	mark_dirty()
	if autosave_now:
		autosave("battle_result")

func get_last_battle_result() -> Dictionary:
	ensure_loaded()
	var value = data["flags"].get("last_battle_result", {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func get_chapter_id() -> int:
	ensure_loaded()
	return int(data.get("meta", {}).get("chapter_id", 0))

func get_chapter_name() -> String:
	ensure_loaded()
	return str(data.get("meta", {}).get("chapter_name", "未开始"))


func ensure_merchant_data() -> Dictionary:
	ensure_loaded()
	if !data.has("merchant") or typeof(data["merchant"]) != TYPE_DICTIONARY:
		data["merchant"] = {}
	var merchant: Dictionary = data["merchant"]
	if !merchant.has("next_battle_effects") or typeof(merchant["next_battle_effects"]) != TYPE_DICTIONARY:
		merchant["next_battle_effects"] = {}
	if !merchant.has("next_battle_temp_items") or typeof(merchant["next_battle_temp_items"]) != TYPE_ARRAY:
		merchant["next_battle_temp_items"] = []
	if !merchant.has("purchases") or typeof(merchant["purchases"]) != TYPE_DICTIONARY:
		merchant["purchases"] = {}
	if !merchant.has("events_seen") or typeof(merchant["events_seen"]) != TYPE_DICTIONARY:
		merchant["events_seen"] = {}
	if !merchant.has("last_purchase_id"):
		merchant["last_purchase_id"] = ""
	data["merchant"] = merchant
	return merchant

func get_merchant_next_battle_effects() -> Dictionary:
	var merchant: Dictionary = ensure_merchant_data()
	var effects_value: Variant = merchant.get("next_battle_effects", {})
	if typeof(effects_value) == TYPE_DICTIONARY:
		return effects_value.duplicate(true)
	return {}

func has_merchant_next_battle_effect(effect_key: String) -> bool:
	var clean_key: String = effect_key.strip_edges()
	if clean_key == "":
		return false
	var effects: Dictionary = get_merchant_next_battle_effects()
	return effects.has(clean_key) and abs(float(effects.get(clean_key, 0.0))) > 0.00001

func get_next_battle_debug_summary() -> Dictionary:
	ensure_loaded()
	return {
		"temp_items": get_next_battle_temp_items(),
		"temp_effects": get_merchant_next_battle_effects(),
		"captive_equipment": get_next_battle_captive_equipment_id(),
		"lust": get_lust(),
		"chapter_id": get_chapter_id(),
	}

func add_merchant_next_battle_effect(effect_key: String, value: float, autosave_now: bool = true) -> void:
	var clean_key: String = effect_key.strip_edges()
	if clean_key == "":
		return
	var merchant: Dictionary = ensure_merchant_data()
	var effects: Dictionary = merchant["next_battle_effects"]
	effects[clean_key] = float(effects.get(clean_key, 0.0)) + value
	merchant["next_battle_effects"] = effects
	data["merchant"] = merchant
	mark_dirty()
	if autosave_now:
		save_progress_now("merchant_next_battle_effect")

func get_next_battle_temp_items() -> Array[String]:
	var result: Array[String] = []
	var merchant: Dictionary = ensure_merchant_data()
	var raw: Array = merchant.get("next_battle_temp_items", [])
	for value: Variant in raw:
		var id: String = str(value).strip_edges()
		if id != "":
			result.append(id)
	return result

func add_next_battle_temp_item(item_id: String, autosave_now: bool = true) -> void:
	var clean_id: String = item_id.strip_edges()
	if clean_id == "":
		return
	var merchant: Dictionary = ensure_merchant_data()
	var items: Array = merchant["next_battle_temp_items"]
	items.append(clean_id)
	merchant["next_battle_temp_items"] = items
	unlock_item("temporary_items_seen", clean_id, false)
	data["merchant"] = merchant
	mark_dirty()
	if autosave_now:
		save_progress_now("merchant_temp_item")

func clear_merchant_next_battle_effects(autosave_now: bool = true) -> void:
	var merchant: Dictionary = ensure_merchant_data()
	merchant["next_battle_effects"] = {}
	merchant["next_battle_temp_items"] = []
	data["merchant"] = merchant
	mark_dirty()
	if autosave_now:
		save_progress_now("merchant_clear_next_battle")

func get_merchant_purchase_count(item_id: String) -> int:
	var merchant: Dictionary = ensure_merchant_data()
	var purchases: Dictionary = merchant["purchases"]
	return int(purchases.get(item_id, 0))

func record_merchant_purchase(item_id: String, autosave_now: bool = true) -> void:
	var clean_id: String = item_id.strip_edges()
	if clean_id == "":
		return
	var merchant: Dictionary = ensure_merchant_data()
	var purchases: Dictionary = merchant["purchases"]
	purchases[clean_id] = int(purchases.get(clean_id, 0)) + 1
	merchant["purchases"] = purchases
	merchant["last_purchase_id"] = clean_id
	data["merchant"] = merchant
	mark_dirty()
	if autosave_now:
		save_progress_now("merchant_purchase")

func has_merchant_event_seen(event_id: String) -> bool:
	var merchant: Dictionary = ensure_merchant_data()
	var events_seen: Dictionary = merchant["events_seen"]
	var seen_value: Variant = events_seen.get(event_id, false)
	return seen_value == true or str(seen_value).to_lower() == "true" or str(seen_value) == "1"

func record_merchant_event(event_id: String, autosave_now: bool = true) -> void:
	var clean_id: String = event_id.strip_edges()
	if clean_id == "":
		return
	var merchant: Dictionary = ensure_merchant_data()
	var events_seen: Dictionary = merchant["events_seen"]
	events_seen[clean_id] = true
	merchant["events_seen"] = events_seen
	data["merchant"] = merchant
	mark_dirty()
	if autosave_now:
		save_progress_now("merchant_event")

# Legacy-compatible entry point. New Merchant.gd handles ref_id/goods_type itself,
# but keeping this prevents older merchant scenes from breaking.
func buy_merchant_item(row: Dictionary) -> Dictionary:
	ensure_loaded()
	var item_id: String = str(row.get("id", "")).strip_edges()
	var cost: int = int(row.get("cost", 0))
	if item_id == "":
		return {"ok": false, "message": "商品ID为空"}
	if cost > 0 and !spend_lust(cost, false):
		return {"ok": false, "message": "淫能不足"}
	record_merchant_purchase(item_id, false)
	save_progress_now("merchant_buy_" + item_id)
	return {"ok": true, "message": "购买完成"}

func ensure_dungeon_data() -> Dictionary:
	ensure_loaded()
	if !data.has("dungeon") or typeof(data["dungeon"]) != TYPE_DICTIONARY:
		data["dungeon"] = {}
	var dungeon: Dictionary = data["dungeon"]
	if !dungeon.has("captives") or typeof(dungeon["captives"]) != TYPE_DICTIONARY:
		dungeon["captives"] = {}
	if !dungeon.has("last_processed_battle_id"):
		dungeon["last_processed_battle_id"] = ""
	if !dungeon.has("events_seen") or typeof(dungeon["events_seen"]) != TYPE_DICTIONARY:
		dungeon["events_seen"] = {}
	if !dungeon.has("next_battle_captive_equipment_id"):
		dungeon["next_battle_captive_equipment_id"] = ""
	if !dungeon.has("last_event_id"):
		dungeon["last_event_id"] = ""
	if !dungeon.has("last_story_event_id"):
		dungeon["last_story_event_id"] = ""
	if !dungeon.has("last_action_result") or typeof(dungeon["last_action_result"]) != TYPE_DICTIONARY:
		dungeon["last_action_result"] = {}
	data["dungeon"] = dungeon
	return dungeon

func get_captives() -> Dictionary:
	var dungeon: Dictionary = ensure_dungeon_data()
	var captives_value: Variant = dungeon.get("captives", {})
	if typeof(captives_value) == TYPE_DICTIONARY:
		return captives_value.duplicate(true)
	return {}

func get_captive_state(captive_id: String) -> Dictionary:
	var captives: Dictionary = get_captives()
	var value: Variant = captives.get(captive_id, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}

func get_captive_humiliation_level(captive_id: String) -> int:
	var captive: Dictionary = get_captive_state(captive_id)
	if captive.is_empty():
		return 0
	return int(captive.get("humiliation_level", calculate_humiliation_level(int(captive.get("humiliation_xp", 0)))))

func calculate_humiliation_level(xp: int) -> int:
	if xp >= 520:
		return 3
	if xp >= 260:
		return 2
	if xp >= 100:
		return 1
	return 0

func grant_debug_captive(captive_id: String = "CPT_KNIGHT_001") -> void:
	# 手动调试用，不会被 normalize/场景 ready 自动调用。正式流程请通过商人或关卡奖励获得俘虏。
	ensure_loaded()
	var clean_id := captive_id.strip_edges()
	if clean_id == "":
		return
	add_captive(clean_id, "debug_manual", false)
	unlock_item("captives", clean_id, false)
	mark_dirty()

func add_captive(captive_id: String, source: String = "", autosave_now: bool = true) -> void:
	ensure_loaded()
	var clean_id: String = captive_id.strip_edges()
	if clean_id == "":
		return
	var dungeon: Dictionary = ensure_dungeon_data()
	var captives: Dictionary = dungeon["captives"]
	if !captives.has(clean_id):
		captives[clean_id] = {
			"id": clean_id,
			"source": source,
			"obtained_time": Time.get_datetime_string_from_system(false, true),
			"processed": false,
			"pending_action": true,
			"humiliation_xp": 0,
			"humiliation_level": 0,
			"action_count": 0,
			"last_action": "",
			"last_item_id": "",
			"last_character_id": "",
			"last_event_id": "",
			"last_story_event_id": "",
		}
	else:
		var captive: Dictionary = captives[clean_id]
		captive["pending_action"] = true
		captive["processed"] = false
		captive["source"] = source
		captives[clean_id] = captive
	dungeon["captives"] = captives
	data["dungeon"] = dungeon
	unlock_item("captives", clean_id, false)
	mark_dirty()
	if autosave_now:
		save_progress_now("add_captive")

func has_captive(captive_id: String) -> bool:
	ensure_loaded()
	var dungeon: Dictionary = ensure_dungeon_data()
	var captives: Dictionary = dungeon["captives"]
	return captives.has(captive_id)

func add_captive_humiliation(captive_id: String, amount: int, autosave_now: bool = true) -> void:
	if captive_id == "":
		return
	var dungeon: Dictionary = ensure_dungeon_data()
	var captives: Dictionary = dungeon["captives"]
	if !captives.has(captive_id):
		add_captive(captive_id, "unknown", false)
		dungeon = ensure_dungeon_data()
		captives = dungeon["captives"]
	var captive: Dictionary = captives[captive_id]
	var xp: int = max(0, int(captive.get("humiliation_xp", 0)) + amount)
	captive["humiliation_xp"] = xp
	captive["humiliation_level"] = calculate_humiliation_level(xp)
	captives[captive_id] = captive
	dungeon["captives"] = captives
	data["dungeon"] = dungeon
	unlock_item("captives", captive_id, false)
	mark_dirty()
	if autosave_now:
		save_progress_now("captive_humiliation")

func get_pending_captive_ids() -> Array[String]:
	var result: Array[String] = []
	var captives: Dictionary = get_captives()
	for key in captives.keys():
		var captive_value: Variant = captives[key]
		if typeof(captive_value) != TYPE_DICTIONARY:
			continue
		var captive: Dictionary = captive_value
		var pending_value: Variant = captive.get("pending_action", true)
		if pending_value == true or str(pending_value).to_lower() == "true" or str(pending_value) == "1":
			result.append(str(key))
	return result

func process_captive_action(action: String, captive_id: String, item_id: String = "", character_id: String = "", autosave_now: bool = true, lust_gain_override: int = -999999, hum_gain_override: int = -999999) -> Dictionary:
	var clean_action: String = action.strip_edges()
	if clean_action == "idle":
		clean_action = "passive"
	if captive_id == "":
		return {"ok": false, "message": "没有选择俘虏"}
	var dungeon: Dictionary = ensure_dungeon_data()
	var captives: Dictionary = dungeon["captives"]
	if !captives.has(captive_id):
		return {"ok": false, "message": "俘虏不存在"}
	var captive: Dictionary = captives[captive_id]
	var level: int = int(captive.get("humiliation_level", calculate_humiliation_level(int(captive.get("humiliation_xp", 0)))))
	var lust_gain: int = 0
	var hum_gain: int = 0
	if clean_action == "passive":
		lust_gain = 80 + level * 35
		hum_gain = 10
	elif clean_action == "train":
		lust_gain = 25 + level * 8
		hum_gain = 35
	elif clean_action == "materialize":
		lust_gain = 0
		hum_gain = 70
	else:
		return {"ok": false, "message": "未知地窖操作"}
	if lust_gain_override != -999999:
		lust_gain = lust_gain_override
	if hum_gain_override != -999999:
		hum_gain = hum_gain_override
	if lust_gain > 0:
		add_lust(lust_gain, false)
	var xp: int = max(0, int(captive.get("humiliation_xp", 0)) + hum_gain)
	captive["humiliation_xp"] = xp
	captive["humiliation_level"] = calculate_humiliation_level(xp)
	captive["processed"] = true
	captive["pending_action"] = false
	captive["last_action"] = clean_action
	captive["last_item_id"] = item_id
	captive["last_character_id"] = character_id
	captive["action_count"] = int(captive.get("action_count", 0)) + 1
	captive["last_action_time"] = Time.get_datetime_string_from_system(false, true)
	captives[captive_id] = captive
	dungeon["captives"] = captives
	dungeon["last_action_result"] = {"action": clean_action, "captive_id": captive_id, "item_id": item_id, "character_id": character_id, "lust_gain": lust_gain, "humiliation_gain": hum_gain, "level": captive["humiliation_level"]}
	data["dungeon"] = dungeon
	mark_dirty()
	if autosave_now:
		save_progress_now("dungeon_" + clean_action)
	return {"ok": true, "message": "处理完成", "lust_gain": lust_gain, "humiliation_gain": hum_gain, "level": captive["humiliation_level"]}

func record_dungeon_event(event_id: String, autosave_now: bool = true) -> void:
	var clean_id: String = event_id.strip_edges()
	if clean_id == "":
		return
	var dungeon: Dictionary = ensure_dungeon_data()
	var events: Dictionary = dungeon["events_seen"]
	events[clean_id] = true
	dungeon["events_seen"] = events
	dungeon["last_event_id"] = clean_id
	data["dungeon"] = dungeon
	mark_dirty()
	if autosave_now:
		save_progress_now("dungeon_event")

func set_next_battle_captive_equipment(equipment_id: String, autosave_now: bool = true) -> void:
	var dungeon: Dictionary = ensure_dungeon_data()
	dungeon["next_battle_captive_equipment_id"] = equipment_id.strip_edges()
	data["dungeon"] = dungeon
	mark_dirty()
	if autosave_now:
		save_progress_now("dungeon_materialize_equipment")

func get_next_battle_captive_equipment_id() -> String:
	var dungeon: Dictionary = ensure_dungeon_data()
	return str(dungeon.get("next_battle_captive_equipment_id", "")).strip_edges()

func clear_next_battle_captive_equipment(autosave_now: bool = true) -> void:
	set_next_battle_captive_equipment("", autosave_now)

func clear_next_battle_consumables(autosave_now: bool = true, reason: String = "battle_finished") -> void:
	clear_merchant_next_battle_effects(false)
	clear_next_battle_captive_equipment(false)
	data["runtime"]["pending_battle_modifiers"] = {}
	data["runtime"]["pending_battle_sources"] = []
	data["runtime"]["last_battle_clear_reason"] = reason
	mark_dirty()
	if autosave_now:
		save_progress_now("clear_next_battle_consumables")

func unlock_story_event(event_id: String, autosave_now: bool = true) -> void:
	var clean_id: String = event_id.strip_edges()
	if clean_id == "":
		return
	unlock_item("story_events", clean_id, false)
	if clean_id.begins_with("CG_"):
		unlock_item("cg_events", clean_id, false)
	else:
		unlock_item("narrative_events", clean_id, false)
	ensure_dict(data, "story")
	ensure_dict(data["story"], "events_seen")
	ensure_dict(data["story"], "cg_seen")
	data["story"]["events_seen"][clean_id] = true
	if clean_id.begins_with("CG_"):
		data["story"]["cg_seen"][clean_id] = true
	data["story"]["last_event_id"] = clean_id
	data["story"]["pending_event_id"] = clean_id
	mark_dirty()
	if autosave_now:
		save_progress_now("unlock_story_event")

func record_dungeon_story_result(dungeon_event_id: String, story_event_id: String, autosave_now: bool = true) -> void:
	var dungeon: Dictionary = ensure_dungeon_data()
	if dungeon_event_id.strip_edges() != "":
		dungeon["last_event_id"] = dungeon_event_id.strip_edges()
		var events: Dictionary = dungeon["events_seen"]
		events[dungeon_event_id.strip_edges()] = true
		dungeon["events_seen"] = events
	if story_event_id.strip_edges() != "":
		dungeon["last_story_event_id"] = story_event_id.strip_edges()
		unlock_story_event(story_event_id.strip_edges(), false)
	data["dungeon"] = dungeon
	mark_dirty()
	if autosave_now:
		save_progress_now("dungeon_story_result")

func clear_pending_story_event(autosave_now: bool = false) -> void:
	ensure_loaded()
	data["story"]["pending_event_id"] = ""
	mark_dirty()
	if autosave_now:
		save_progress_now("clear_pending_story_event")

func set_flag(flag_key: String, value, autosave_now: bool = true) -> void:
	ensure_loaded()
	data["flags"][flag_key] = value
	mark_dirty()
	if autosave_now:
		autosave("flag")

func get_flag(flag_key: String, fallback = null):
	ensure_loaded()
	return data["flags"].get(flag_key, fallback)

func normalize_slot_path(slot_path: String) -> String:
	var clean_path := slot_path.strip_edges()
	if clean_path == "":
		return DEFAULT_SLOT_PATH
	return clean_path

func get_slot_id_from_path(slot_path: String) -> String:
	var file_name := slot_path.get_file()
	return file_name.get_basename()

func get_slot_role_from_path(slot_path: String) -> String:
	var slot_id := get_slot_id_from_path(slot_path)
	if slot_id == "Save0":
		return "template"
	if slot_id.begins_with("SaveAuto"):
		return "autosave"
	return "manual"

func update_slot_preview_image(slot_path: String, chapter_id: int = -1) -> bool:
	var target_path := get_slot_image_path(slot_path)
	var source_path := get_chapter_preview_image_path(chapter_id)
	if source_path == "" or target_path == "":
		return false

	if source_path == target_path:
		ResourceLoader.load(target_path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE)
		return true

	var ok := copy_binary_file(source_path, target_path)
	if ok:
		ResourceLoader.load(target_path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE)
	return ok

func get_slot_image_path(slot_path: String) -> String:
	var clean_path := normalize_slot_path(slot_path)
	if clean_path.get_extension().to_lower() == "txt":
		return clean_path.get_basename() + ".png"
	return clean_path

func get_chapter_preview_image_path(chapter_id: int) -> String:
	var safe_chapter: int = max(0, chapter_id)
	var candidates: Array[String] = [
		"res://GraphicAssets/04_Save_Select/SaveChapter" + str(safe_chapter) + ".png",
	]

	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate

	return DEFAULT_SAVE_IMAGE_PATH

func copy_binary_file(source_path: String, target_path: String) -> bool:
	if !FileAccess.file_exists(source_path):
		return false

	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false

	var bytes := source.get_buffer(source.get_length())
	source.close()

	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return false

	target.store_buffer(bytes)
	target.close()
	return true

func load_slot_preview_texture(slot_path: String) -> ImageTexture:
	var image_path := get_slot_image_path(slot_path)
	var image := Image.new()
	if image.load(image_path) != OK:
		image.load(DEFAULT_SAVE_IMAGE_PATH)
	return ImageTexture.create_from_image(image)

func apply_slot_preview_to_texture_rect(texture_rect: TextureRect, slot_path: String) -> void:
	if texture_rect == null:
		return
	texture_rect.texture = load_slot_preview_texture(slot_path)
