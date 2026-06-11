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
		},
		"economy": {
			"lust": 0,
			"humiliation": 0,
		},
		"progress": {
			"unlocked_chapters": [],
			"cleared_levels": [],
			"level_bonus_collect": {},
			"last_level_id": "",
		},
		"unlocks": {
			"characters": ["C001"],
			"weapons": ["W001"],
			"equipments": ["E001"],
			"torture_items": [],
			"codex": [],
		},
		"upgrades": {
			"player": {},
			"tentacle": {},
			"building": {},
		},
		"dungeon": {
			"captives": {},
			"last_processed_battle_id": "",
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
	return result

func deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			deep_merge(target[key], source[key])
		else:
			target[key] = source[key]

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

func get_next_autosave_path() -> String:
	var last_auto_id := str(data.get("meta", {}).get("last_autosave_slot", "SaveAuto2"))
	if last_auto_id == "SaveAuto":
		return AUTO_SLOT_PATHS[1]
	return AUTO_SLOT_PATHS[0]

func mark_dirty() -> void:
	dirty = true

func ensure_loaded() -> void:
	if !is_loaded:
		start_new_game(DEFAULT_SLOT_PATH)

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
	data["progress"]["level_bonus_collect"][level_id] = int(data["progress"]["level_bonus_collect"].get(level_id, 0))
	mark_dirty()
	if autosave_now:
		autosave("unlock_level")

func record_level_clear(level_id: String, bonus_collect: int = 1, autosave_now: bool = true) -> void:
	ensure_loaded()
	if !data["progress"]["cleared_levels"].has(level_id):
		data["progress"]["cleared_levels"].append(level_id)
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
	if !data["upgrades"].has(group_name):
		data["upgrades"][group_name] = {}
	data["upgrades"][group_name][upgrade_id] = max(0, level)
	mark_dirty()
	if autosave_now:
		autosave("upgrade")

func get_upgrade_level(group_name: String, upgrade_id: String) -> int:
	ensure_loaded()
	if !data["upgrades"].has(group_name):
		return 0
	return int(data["upgrades"][group_name].get(upgrade_id, 0))

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
