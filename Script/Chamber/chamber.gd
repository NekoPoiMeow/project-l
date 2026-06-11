extends Control

const LEVEL_SELECT_SCENE := "res://scenes/LevelSelect/LevelSelect.tscn"
const FALLBACK_BATTLE_SCENE := "res://scenes/Battle/Battle_00.tscn"
const DEV_BATTLE_SCENE_MAP := {
	"L001": "res://scenes/Battle/Battle_00.tscn",
	"L002": "res://scenes/Battle/Battle_BulletTest.tscn",
	"L003": "res://scenes/Battle/Battle_00.tscn",
	"L004": "res://scenes/Battle/Battle_00.tscn",
}
const CHARACTERS_CSV := "res://Config/Characters.csv"
const WEAPONS_CSV := "res://Config/Weapons.csv"
const EQUIPMENTS_CSV := "res://Config/Equipments.csv"

@onready var label_level: Label = $ColorRectBackground/LabelLevel
@onready var label_summary: Label = $ColorRectBackground/LabelSummary
@onready var label_detail: Label = $ColorRectBackground/LabelDetail
@onready var character_list: ItemList = $ColorRectBackground/HBoxLists/VBoxCharacter/ItemListCharacter
@onready var weapon_list: ItemList = $ColorRectBackground/HBoxLists/VBoxWeapon/ItemListWeapon
@onready var equipment_list: ItemList = $ColorRectBackground/HBoxLists/VBoxEquipment/ItemListEquipment
@onready var button_confirm: Button = $ColorRectBackground/HBoxButtons/ButtonConfirm
@onready var button_back: Button = $ColorRectBackground/HBoxButtons/ButtonBack
@onready var button_codex: Button = $ColorRectBackground/HBoxButtons/ButtonCodex

var level_id := ""
var level_name := ""
var requested_battle_scene := ""
var battle_scene := FALLBACK_BATTLE_SCENE
var level_description := ""

var characters: Array[Dictionary] = []
var weapons: Array[Dictionary] = []
var equipments: Array[Dictionary] = []

var selected_character := ""
var selected_weapon := ""
var selected_equipment := ""

func _ready() -> void:
	load_pending_level_payload()
	characters = load_csv_catalog(CHARACTERS_CSV)
	weapons = load_csv_catalog(WEAPONS_CSV)
	equipments = load_csv_catalog(EQUIPMENTS_CSV)
	fill_list(character_list, characters)
	fill_list(weapon_list, weapons)
	fill_list(equipment_list, equipments)

	character_list.item_selected.connect(_on_character_selected)
	weapon_list.item_selected.connect(_on_weapon_selected)
	equipment_list.item_selected.connect(_on_equipment_selected)
	button_confirm.pressed.connect(_on_confirm_pressed)
	button_back.pressed.connect(_on_back_pressed)
	button_codex.pressed.connect(_on_codex_pressed)

	select_first_unlocked(character_list, characters, "character")
	select_first_unlocked(weapon_list, weapons, "weapon")
	select_first_unlocked(equipment_list, equipments, "equipment")
	update_view()

func load_pending_level_payload() -> void:
	var root := get_tree().root
	if !root.has_meta("pending_chamber_payload"):
		return

	var payload = root.get_meta("pending_chamber_payload")
	if typeof(payload) != TYPE_DICTIONARY:
		return

	level_id = str(payload.get("level_id", ""))
	level_name = str(payload.get("level_name", ""))
	requested_battle_scene = str(payload.get("battle_scene", FALLBACK_BATTLE_SCENE))
	battle_scene = resolve_battle_scene(level_id, requested_battle_scene)
	level_description = str(payload.get("description", ""))

func resolve_battle_scene(payload_level_id: String, payload_scene: String) -> String:
	var clean_scene: String = payload_scene.strip_edges()
	if clean_scene != "" and ResourceLoader.exists(clean_scene):
		return clean_scene

	if DEV_BATTLE_SCENE_MAP.has(payload_level_id):
		var mapped_scene: String = str(DEV_BATTLE_SCENE_MAP[payload_level_id])
		if ResourceLoader.exists(mapped_scene):
			return mapped_scene

	return FALLBACK_BATTLE_SCENE

func load_csv_catalog(path: String) -> Array[Dictionary]:
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

		if str(row.get("id", "")).strip_edges() != "":
			result.append(row)

	file.close()
	return result

func fill_list(list: ItemList, rows: Array[Dictionary]) -> void:
	list.clear()
	for row in rows:
		var text := str(row.get("name", row.get("id", "")))
		var index := list.add_item(text)
		list.set_item_disabled(index, !is_unlocked(row))
		list.set_item_metadata(index, row)

func select_first_unlocked(list: ItemList, rows: Array[Dictionary], kind: String) -> void:
	for i in range(rows.size()):
		if is_unlocked(rows[i]):
			list.select(i)
			set_selection(kind, rows[i])
			return

func is_unlocked(row: Dictionary) -> bool:
	var value := str(row.get("unlocked", "FALSE")).to_upper()
	return value == "TRUE" or value == "1" or value == "YES"

func set_selection(kind: String, row: Dictionary) -> void:
	if kind == "character":
		selected_character = str(row.get("id", ""))
	elif kind == "weapon":
		selected_weapon = str(row.get("id", ""))
	elif kind == "equipment":
		selected_equipment = str(row.get("id", ""))

	update_view()

func update_view() -> void:
	if label_level == null:
		return

	label_level.text = "出击准备  " + level_id + "  " + level_name
	if level_description != "":
		label_level.text += "\n" + level_description

	label_summary.text = "角色: " + selected_character + "    初始武器: " + selected_weapon + "    装备: " + selected_equipment
	label_detail.text = build_detail_text()
	button_confirm.disabled = selected_character == "" or selected_weapon == ""

func build_detail_text() -> String:
	var lines: Array[String] = []
	lines.append("确认后进入: " + battle_scene)
	lines.append("当前只保存本次出击选择；以后接存档解锁和战斗参数注入。")
	lines.append("图鉴入口预留：角色/武器/装备/地牢道具都从 Config 目录的全量表读取。")
	return "\n".join(lines)

func _on_character_selected(index: int) -> void:
	set_selection("character", character_list.get_item_metadata(index))

func _on_weapon_selected(index: int) -> void:
	set_selection("weapon", weapon_list.get_item_metadata(index))

func _on_equipment_selected(index: int) -> void:
	set_selection("equipment", equipment_list.get_item_metadata(index))

func _on_confirm_pressed() -> void:
	if GameState.is_loaded:
		GameState.data["progress"]["last_level_id"] = level_id
		GameState.data["meta"]["last_scene"] = battle_scene
		GameState.autosave("sortie_prepare")

	var root := get_tree().root
	root.set_meta("pending_battle_loadout", {
		"level_id": level_id,
		"battle_scene": battle_scene,
		"requested_battle_scene": requested_battle_scene,
		"character_id": selected_character,
		"weapon_id": selected_weapon,
		"equipment_id": selected_equipment,
	})

	if battle_scene != "" and ResourceLoader.exists(battle_scene):
		get_tree().change_scene_to_file(battle_scene)
	else:
		get_tree().change_scene_to_file(FALLBACK_BATTLE_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_codex_pressed() -> void:
	label_detail.text = "图鉴场景未接入。后续建议新建 Codex 场景，按 Config 全量表 + Save 解锁键显示。"
