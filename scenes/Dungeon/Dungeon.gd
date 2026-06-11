extends Control

const BASEMENT_SCENE_PATH := "res://scenes/Basement.tscn"
const CAPTIVE_CSV := "res://Config/DungeonCaptives.csv"
const TORTURE_ITEM_CSV := "res://Config/TortureItems.csv"
const CHARACTER_CSV := "res://Config/Characters.csv"
const AVG_SCENE_PATH := "res://scenes/AVG/AVG.tscn"

var captive_rows: Dictionary = {}
var item_rows: Array[Dictionary] = []
var character_rows: Array[Dictionary] = []
var selected_captive_id: String = ""
var selected_action: String = "idle"

var lust_label: Label = null
var status_label: Label = null
var captive_list: ItemList = null
var character_option: OptionButton = null
var item_option: OptionButton = null
var detail_label: RichTextLabel = null
var action_label: Label = null

func _ready() -> void:
	GameState.ensure_loaded()
	load_tables()
	build_ui()
	refresh_all()

func load_tables() -> void:
	captive_rows = load_csv_by_id(CAPTIVE_CSV)
	item_rows = load_csv_array(TORTURE_ITEM_CSV)
	character_rows = load_csv_array(CHARACTER_CSV)

func load_csv_by_id(path: String) -> Dictionary:
	var result: Dictionary = {}
	var rows: Array[Dictionary] = load_csv_array(path)
	for row: Dictionary in rows:
		var id: String = str(row.get("id", "")).strip_edges()
		if id != "":
			result[id] = row
	return result

func load_csv_array(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if !FileAccess.file_exists(path):
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var headers: PackedStringArray = file.get_csv_line()
	while !file.eof_reached():
		var columns: PackedStringArray = file.get_csv_line()
		if columns.is_empty():
			continue
		var row: Dictionary = {}
		for i: int in range(headers.size()):
			var key: String = headers[i].strip_edges()
			var value: String = ""
			if i < columns.size():
				value = columns[i].strip_edges()
			row[key] = value
		var id: String = str(row.get("id", "")).strip_edges()
		if id != "":
			result.append(row)
	file.close()
	return result

func build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.045, 0.025, 0.055, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: HBoxContainer = HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24.0
	root.offset_top = 24.0
	root.offset_right = -24.0
	root.offset_bottom = -24.0
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	var title: Label = Label.new()
	title.text = "地窖"
	title.add_theme_font_size_override("font_size", 32)
	left.add_child(title)

	lust_label = Label.new()
	lust_label.add_theme_font_size_override("font_size", 20)
	left.add_child(lust_label)

	var captive_title: Label = Label.new()
	captive_title.text = "俘虏列表"
	captive_title.add_theme_font_size_override("font_size", 22)
	left.add_child(captive_title)

	captive_list = ItemList.new()
	captive_list.custom_minimum_size = Vector2(310, 430)
	captive_list.item_selected.connect(_on_captive_selected)
	left.add_child(captive_list)

	var idle_all_btn: Button = Button.new()
	idle_all_btn.text = "放置全部待处理俘虏"
	idle_all_btn.pressed.connect(_on_idle_all_pressed)
	left.add_child(idle_all_btn)

	var return_btn: Button = Button.new()
	return_btn.text = "返回营地"
	return_btn.pressed.connect(_on_return_pressed)
	left.add_child(return_btn)

	var middle: VBoxContainer = VBoxContainer.new()
	middle.custom_minimum_size = Vector2(420, 0)
	middle.add_theme_constant_override("separation", 10)
	root.add_child(middle)

	var action_title: Label = Label.new()
	action_title.text = "三选一操作"
	action_title.add_theme_font_size_override("font_size", 26)
	middle.add_child(action_title)

	action_label = Label.new()
	action_label.text = "当前：放置"
	action_label.add_theme_font_size_override("font_size", 20)
	middle.add_child(action_label)

	var btn_idle: Button = Button.new()
	btn_idle.text = "放置：触手自动玩弄 获得淫能大 屈辱小"
	btn_idle.pressed.connect(_select_action.bind("idle"))
	middle.add_child(btn_idle)

	var btn_torture: Button = Button.new()
	btn_torture.text = "调教：选择角色和道具 获得淫能小 屈辱中"
	btn_torture.pressed.connect(_select_action.bind("torture"))
	middle.add_child(btn_torture)

	var btn_equip: Button = Button.new()
	btn_equip.text = "物化：下次战斗临时装备化 淫能0 屈辱大"
	btn_equip.pressed.connect(_select_action.bind("materialize"))
	middle.add_child(btn_equip)

	var char_label: Label = Label.new()
	char_label.text = "调教入替角色"
	middle.add_child(char_label)
	character_option = OptionButton.new()
	middle.add_child(character_option)

	var item_label: Label = Label.new()
	item_label.text = "调教道具"
	middle.add_child(item_label)
	item_option = OptionButton.new()
	middle.add_child(item_option)

	var execute_btn: Button = Button.new()
	execute_btn.text = "执行当前操作"
	execute_btn.custom_minimum_size = Vector2(0, 54)
	execute_btn.pressed.connect(_on_execute_pressed)
	middle.add_child(execute_btn)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(390, 120)
	middle.add_child(status_label)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)

	var detail_title: Label = Label.new()
	detail_title.text = "俘虏 / 事件说明"
	detail_title.add_theme_font_size_override("font_size", 26)
	right.add_child(detail_title)

	detail_label = RichTextLabel.new()
	detail_label.bbcode_enabled = true
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(detail_label)

func refresh_all() -> void:
	refresh_lust()
	refresh_captive_list()
	refresh_options()
	refresh_detail()

func refresh_lust() -> void:
	if lust_label != null:
		lust_label.text = "淫能：" + str(GameState.get_lust())

func refresh_captive_list() -> void:
	if captive_list == null:
		return
	captive_list.clear()
	var captives: Dictionary = GameState.get_captives()
	var keys: Array = captives.keys()
	keys.sort()
	for key_value: Variant in keys:
		var captive_id: String = str(key_value)
		var captive: Dictionary = GameState.get_captive_state(captive_id)
		var row: Dictionary = get_captive_row(captive_id)
		var name: String = str(row.get("name", captive_id))
		var level: int = int(captive.get("humiliation_level", 0))
		var xp: int = int(captive.get("humiliation_xp", 0))
		var pending: bool = as_bool(captive.get("pending_action", false))
		var mark: String = "待处理" if pending else "已处理"
		var text: String = "%s  Lv%d  XP%d  [%s]" % [name, level, xp, mark]
		var index: int = captive_list.add_item(text)
		captive_list.set_item_metadata(index, captive_id)
	if captive_list.item_count > 0:
		var found: bool = false
		for i: int in range(captive_list.item_count):
			if str(captive_list.get_item_metadata(i)) == selected_captive_id:
				captive_list.select(i)
				found = true
				break
		if !found:
			captive_list.select(0)
			selected_captive_id = str(captive_list.get_item_metadata(0))
	else:
		selected_captive_id = ""

func refresh_options() -> void:
	if character_option != null:
		character_option.clear()
		for row: Dictionary in character_rows:
			var id: String = str(row.get("id", "")).strip_edges()
			if id == "":
				continue
			if is_row_unlocked(row, "characters", id):
				character_option.add_item(str(row.get("name", id)))
				character_option.set_item_metadata(character_option.item_count - 1, id)
	if item_option != null:
		item_option.clear()
		var captive_level: int = 0
		if selected_captive_id != "":
			captive_level = GameState.get_captive_humiliation_level(selected_captive_id)
		for row: Dictionary in item_rows:
			var id: String = str(row.get("id", "")).strip_edges()
			if id == "":
				continue
			if !is_row_unlocked(row, "torture_items", id):
				continue
			var min_level: int = int(row.get("min_humiliation_level", 0))
			var suffix: String = "" if captive_level >= min_level else " 需要屈辱Lv" + str(min_level)
			item_option.add_item(str(row.get("name", id)) + suffix)
			item_option.set_item_metadata(item_option.item_count - 1, id)
			item_option.set_item_disabled(item_option.item_count - 1, captive_level < min_level)

func refresh_detail() -> void:
	if detail_label == null:
		return
	if action_label != null:
		action_label.text = "当前：" + get_action_name(selected_action)
	if selected_captive_id == "":
		detail_label.text = "[b]暂无俘虏[/b]\n关卡结算、隐藏事件或商人购买后会获得俘虏。\n\n放置全部待处理俘虏按钮会在没有选择时自动处理待处理俘虏。"
		return
	var captive: Dictionary = GameState.get_captive_state(selected_captive_id)
	var row: Dictionary = get_captive_row(selected_captive_id)
	var name: String = str(row.get("name", selected_captive_id))
	var xp: int = int(captive.get("humiliation_xp", 0))
	var level: int = int(captive.get("humiliation_level", 0))
	var effect_key: String = str(row.get("effect_key", ""))
	var effect_value: String = str(row.get("effect_value", ""))
	var text: String = "[b]" + name + "[/b]\n"
	text += "ID：" + selected_captive_id + "\n"
	text += "屈辱：Lv" + str(level) + " / 3   XP " + str(xp) + "\n"
	text += "来源：" + str(captive.get("source", "")) + "\n"
	text += "待处理：" + str(as_bool(captive.get("pending_action", false))) + "\n"
	text += "最近操作：" + str(captive.get("last_action", "")) + "\n\n"
	text += str(row.get("description", "占位俘虏")) + "\n\n"
	text += "[b]三选一规则[/b]\n"
	text += "放置：淫能较多 屈辱少 自动触发放置CG。\n"
	text += "调教：选择角色和道具 淫能较少 屈辱中 触发道具CG。\n"
	text += "物化：下次战斗临时机制改变 淫能0 屈辱大。\n"
	if effect_key != "":
		text += "\n物化效果：" + effect_key + " +" + effect_value
	detail_label.text = text

func _on_captive_selected(index: int) -> void:
	if captive_list == null:
		return
	selected_captive_id = str(captive_list.get_item_metadata(index))
	refresh_options()
	refresh_detail()

func _select_action(action: String) -> void:
	selected_action = action
	refresh_detail()

func _on_execute_pressed() -> void:
	if selected_captive_id == "":
		show_status("没有选择俘虏。要自动放置，请点左侧放置全部待处理俘虏。")
		return
	process_one_captive(selected_captive_id, selected_action)

func _on_idle_all_pressed() -> void:
	var ids: Array[String] = GameState.get_pending_captive_ids()
	if ids.is_empty():
		show_status("没有待处理俘虏。")
		return
	var total_lust: int = 0
	var total_hum: int = 0
	for captive_id: String in ids:
		var result: Dictionary = GameState.process_captive_action("idle", captive_id, "", "", false)
		if result.get("ok", false) == true:
			total_lust += int(result.get("lust_gain", 0))
			total_hum += int(result.get("humiliation_gain", 0))
	GameState.save_progress_now("dungeon_idle_all")
	refresh_all()
	show_status("放置完成：淫能 +%d，屈辱合计 +%d" % [total_lust, total_hum])
	trigger_avg_event("dungeon_idle_all")

func process_one_captive(captive_id: String, action: String) -> void:
	var item_id: String = get_selected_item_id()
	var character_id: String = get_selected_character_id()
	if action == "torture":
		if item_id == "":
			show_status("没有可用调教道具。可在局外升级解锁道具。")
			return
		var item_row: Dictionary = get_item_row(item_id)
		var min_level: int = int(item_row.get("min_humiliation_level", 0))
		var captive_level: int = GameState.get_captive_humiliation_level(captive_id)
		if captive_level < min_level:
			show_status("俘虏屈辱等级不足，需要 Lv" + str(min_level))
			return
	var result: Dictionary = GameState.process_captive_action(action, captive_id, item_id, character_id, false)
	if result.get("ok", false) != true:
		show_status(str(result.get("message", "处理失败")))
		return
	if action == "materialize":
		apply_materialize_effect(captive_id)
	GameState.save_progress_now("dungeon_" + action)
	refresh_all()
	show_status("%s完成：淫能 +%d，屈辱 +%d" % [get_action_name(action), int(result.get("lust_gain", 0)), int(result.get("humiliation_gain", 0))])
	trigger_avg_event(make_avg_event_id(action, captive_id, item_id, character_id))

func apply_materialize_effect(captive_id: String) -> void:
	var row: Dictionary = get_captive_row(captive_id)
	var effect_key: String = str(row.get("effect_key", "")).strip_edges()
	var effect_value: float = float(row.get("effect_value", 0.0))
	if effect_key != "" and effect_value != 0.0:
		GameState.add_merchant_next_battle_effect(effect_key, effect_value, false)
		GameState.set_flag("dungeon_next_equipment_captive", captive_id, false)

func make_avg_event_id(action: String, captive_id: String, item_id: String, character_id: String) -> String:
	if action == "idle":
		var level: int = GameState.get_captive_humiliation_level(captive_id)
		return "dungeon_idle_L" + str(level)
	if action == "torture":
		if item_id != "":
			return "dungeon_torture_" + captive_id + "_" + item_id + "_" + character_id
		return "dungeon_torture_" + captive_id
	if action == "materialize":
		return "dungeon_materialize_" + captive_id
	return "dungeon_event"

func trigger_avg_event(event_id: String) -> void:
	GameState.record_dungeon_event(event_id, false)
	GameState.save_progress_now("dungeon_avg_event")
	get_tree().root.set_meta("pending_avg_event", event_id)
	# If an AVG scene exists later, it can read root meta pending_avg_event.
	# For now this is intentionally non-blocking so dungeon UI remains usable.

func show_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _on_return_pressed() -> void:
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	GameState.save_progress_now("return_basement_from_dungeon")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)

func get_captive_row(captive_id: String) -> Dictionary:
	var value: Variant = captive_rows.get(captive_id, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {"id": captive_id, "name": captive_id, "description": "占位俘虏"}

func get_item_row(item_id: String) -> Dictionary:
	for row: Dictionary in item_rows:
		if str(row.get("id", "")) == item_id:
			return row
	return {}

func get_selected_item_id() -> String:
	if item_option == null or item_option.item_count <= 0:
		return ""
	var index: int = item_option.selected
	if index < 0 or index >= item_option.item_count:
		return ""
	if item_option.is_item_disabled(index):
		return ""
	return str(item_option.get_item_metadata(index))

func get_selected_character_id() -> String:
	if character_option == null or character_option.item_count <= 0:
		return "C001"
	var index: int = character_option.selected
	if index < 0 or index >= character_option.item_count:
		return "C001"
	return str(character_option.get_item_metadata(index))

func is_row_unlocked(row: Dictionary, category: String, id: String) -> bool:
	var unlocked_text: String = str(row.get("unlocked", "FALSE")).strip_edges().to_lower()
	if unlocked_text == "true" or unlocked_text == "1" or unlocked_text == "yes":
		return true
	return GameState.is_unlocked(category, id)

func as_bool(value: Variant) -> bool:
	if value == true:
		return true
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes"

func get_action_name(action: String) -> String:
	if action == "idle":
		return "放置"
	if action == "torture":
		return "调教"
	if action == "materialize":
		return "物化"
	return action
