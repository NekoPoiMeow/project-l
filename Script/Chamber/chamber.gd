extends Control

const CHARACTERS_CSV: String = "res://Config/Characters.csv"
const WEAPONS_CSV: String = "res://Config/Weapons.csv"
const EQUIPMENTS_CSV: String = "res://Config/Equipments.csv"
const BATTLE_SCENE_PATH: String = "res://scenes/Battle/Battle_00.tscn"
const BASEMENT_SCENE_PATH: String = "res://scenes/Basement.tscn"

@onready var character_list: ItemList = $ColorRectBackground/HBoxLists/VBoxCharacter/ItemListCharacter
@onready var weapon_list: ItemList = $ColorRectBackground/HBoxLists/VBoxWeapon/ItemListWeapon
@onready var equipment_list: ItemList = $ColorRectBackground/HBoxLists/VBoxEquipment/ItemListEquipment
@onready var summary_label: Label = $ColorRectBackground/LabelSummary
@onready var detail_label: Label = $ColorRectBackground/LabelDetail
@onready var back_button: Button = $ColorRectBackground/HBoxButtons/ButtonBack
@onready var codex_button: Button = $ColorRectBackground/HBoxButtons/ButtonCodex
@onready var confirm_button: Button = $ColorRectBackground/HBoxButtons/ButtonConfirm

var character_rows: Dictionary = {}
var weapon_rows: Dictionary = {}
var equipment_rows: Dictionary = {}

var selected_character_id: String = "C001"
var selected_weapon_id: String = "W001"
var selected_equipment_id: String = "E001"

func _ready() -> void:
	GameState.ensure_loaded()
	character_rows = load_csv_by_id(CHARACTERS_CSV)
	weapon_rows = load_csv_by_id(WEAPONS_CSV)
	equipment_rows = load_csv_by_id(EQUIPMENTS_CSV)

	var saved_loadout: Dictionary = {}
	if GameState.has_method("get_battle_loadout"):
		saved_loadout = GameState.get_battle_loadout()
	selected_character_id = str(saved_loadout.get("character_id", selected_character_id))
	selected_weapon_id = str(saved_loadout.get("weapon_id", selected_weapon_id))
	selected_equipment_id = str(saved_loadout.get("equipment_id", selected_equipment_id))

	populate_list(character_list, character_rows, "characters", selected_character_id)
	populate_list(weapon_list, weapon_rows, "weapons", selected_weapon_id)
	populate_list(equipment_list, equipment_rows, "equipments", selected_equipment_id)

	character_list.item_selected.connect(_on_character_selected)
	weapon_list.item_selected.connect(_on_weapon_selected)
	equipment_list.item_selected.connect(_on_equipment_selected)
	back_button.pressed.connect(_on_back_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	codex_button.pressed.connect(_on_codex_pressed)

	selected_character_id = get_selected_id_or_first(character_list, selected_character_id)
	selected_weapon_id = get_selected_id_or_first(weapon_list, selected_weapon_id)
	selected_equipment_id = get_selected_id_or_first(equipment_list, selected_equipment_id)
	refresh_text()

func load_csv_by_id(path: String) -> Dictionary:
	var result: Dictionary = {}
	if !FileAccess.file_exists(path):
		push_warning("Missing CSV: " + path)
		return result
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = text.split("\n", false)
	if lines.is_empty():
		return result
	var headers: PackedStringArray = split_csv_line(lines[0])
	for i in range(1, lines.size()):
		var line: String = lines[i].strip_edges()
		if line == "":
			continue
		var parts: PackedStringArray = split_csv_line(line)
		var row: Dictionary = {}
		for h in range(headers.size()):
			var key: String = headers[h].strip_edges()
			var value: String = ""
			if h < parts.size():
				value = parts[h].strip_edges()
			row[key] = value
		var id: String = str(row.get("id", "")).strip_edges()
		if id != "":
			result[id] = row
	return result

func split_csv_line(line: String) -> PackedStringArray:
	# Current config CSV is simple and unquoted. Keep this parser intentionally small.
	return line.strip_edges().split(",", false)

func populate_list(list: ItemList, rows: Dictionary, unlock_category: String, preferred_id: String) -> void:
	list.clear()
	var ids: Array = rows.keys()
	ids.sort()
	var selected_index: int = -1
	for raw_id in ids:
		var id: String = str(raw_id)
		var row: Dictionary = rows[id]
		if !is_row_available(row, unlock_category, id):
			continue
		var label: String = str(row.get("name", id))
		var desc: String = str(row.get("description", ""))
		var index: int = list.add_item(label)
		list.set_item_metadata(index, id)
		if desc != "":
			list.set_item_tooltip(index, desc)
		if id == preferred_id:
			selected_index = index
	if list.item_count > 0:
		if selected_index < 0:
			selected_index = 0
		list.select(selected_index)

func is_row_available(row: Dictionary, unlock_category: String, id: String) -> bool:
	var unlocked_text: String = str(row.get("unlocked", "TRUE")).strip_edges().to_lower()
	if unlocked_text == "true" or unlocked_text == "1" or unlocked_text == "yes":
		return true
	return GameState.is_unlocked(unlock_category, id)

func get_selected_id_or_first(list: ItemList, fallback: String) -> String:
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() > 0:
		return str(list.get_item_metadata(selected[0]))
	if list.item_count > 0:
		list.select(0)
		return str(list.get_item_metadata(0))
	return fallback

func _on_character_selected(index: int) -> void:
	selected_character_id = str(character_list.get_item_metadata(index))
	refresh_text()

func _on_weapon_selected(index: int) -> void:
	selected_weapon_id = str(weapon_list.get_item_metadata(index))
	refresh_text()

func _on_equipment_selected(index: int) -> void:
	selected_equipment_id = str(equipment_list.get_item_metadata(index))
	refresh_text()

func refresh_text() -> void:
	var character_name: String = get_row_name(character_rows, selected_character_id)
	var weapon_name: String = get_row_name(weapon_rows, selected_weapon_id)
	var equipment_name: String = get_row_name(equipment_rows, selected_equipment_id)
	summary_label.text = "角色：" + character_name + "    武器：" + weapon_name + "    装备：" + equipment_name

	var character_desc: String = get_row_desc(character_rows, selected_character_id)
	var weapon_desc: String = get_row_desc(weapon_rows, selected_weapon_id)
	var equipment_desc: String = get_row_desc(equipment_rows, selected_equipment_id)
	var attack_id: String = str(get_row(weapon_rows, selected_weapon_id).get("attack_id", ""))
	detail_label.text = "角色：" + character_desc + "\n武器：" + weapon_desc + "\n攻击ID：" + attack_id + "\n装备：" + equipment_desc

func get_row(rows: Dictionary, id: String) -> Dictionary:
	if rows.has(id):
		return rows[id]
	return {}

func get_row_name(rows: Dictionary, id: String) -> String:
	var row: Dictionary = get_row(rows, id)
	return str(row.get("name", id))

func get_row_desc(rows: Dictionary, id: String) -> String:
	var row: Dictionary = get_row(rows, id)
	return str(row.get("description", ""))

func build_loadout() -> Dictionary:
	return {
		"character_id": selected_character_id,
		"weapon_id": selected_weapon_id,
		"equipment_id": selected_equipment_id,
	}

func _on_confirm_pressed() -> void:
	var loadout: Dictionary = build_loadout()
	get_tree().root.set_meta("pending_battle_loadout", loadout)
	if GameState.has_method("set_battle_loadout"):
		GameState.set_battle_loadout(loadout, true)
	else:
		GameState.set_flag("battle_loadout", loadout, true)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _on_back_pressed() -> void:
	var loadout: Dictionary = build_loadout()
	if GameState.has_method("set_battle_loadout"):
		GameState.set_battle_loadout(loadout, true)
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	if GameState.has_method("save_progress_now"):
		GameState.save_progress_now("chamber_back")
	else:
		GameState.autosave("chamber_back")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)

func _on_codex_pressed() -> void:
	# Placeholder. Keep the button harmless until the codex scene is wired.
	refresh_text()
