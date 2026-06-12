extends Control

const BASEMENT_SCENE_PATH := "res://scenes/Basement.tscn"
const CAPTIVE_CSV := "res://Config/Captives.csv"
const TORTURE_ITEM_CSV := "res://Config/TortureItems.csv"
const CHARACTER_CSV := "res://Config/Characters.csv"
const ACTION_CSV := "res://Config/DungeonActions.csv"
const DUNGEON_EVENTS_CSV := "res://Config/DungeonEvents.csv"
const STORY_EVENTS_CSV := "res://Config/StoryEvents.csv"

var captive_rows: Dictionary = {}
var item_rows: Dictionary = {}
var character_rows: Array[Dictionary] = []
var action_rows: Dictionary = {}
var dungeon_event_rows: Array[Dictionary] = []
var story_event_rows: Dictionary = {}

var selected_captive_id: String = ""
var selected_action: String = "passive"

var lust_label: Label = null
var status_label: Label = null
var captive_list: ItemList = null
var captive_option_label: Label = null
var captive_option: OptionButton = null
var character_label: Label = null
var character_option: OptionButton = null
var item_label: Label = null
var item_option: OptionButton = null
var detail_label: RichTextLabel = null
var action_label: Label = null
var execute_button: Button = null

func _ready() -> void:
	GameState.ensure_loaded()
	load_tables()
	build_ui()
	refresh_all()
	debug_log("ready")

func load_tables() -> void:
	captive_rows = load_csv_by_id(CAPTIVE_CSV)
	item_rows = load_csv_by_id(TORTURE_ITEM_CSV)
	character_rows = load_csv_array(CHARACTER_CSV)
	action_rows = load_csv_by_id(ACTION_CSV)
	dungeon_event_rows = load_csv_array(DUNGEON_EVENTS_CSV)
	story_event_rows = load_csv_by_id(STORY_EVENTS_CSV)

func load_csv_by_id(path: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in load_csv_array(path):
		var id: String = str(row.get("id", "")).strip_edges()
		if id != "":
			result[id] = row
	return result

func load_csv_array(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if !FileAccess.file_exists(path):
		push_warning("Missing CSV: " + path)
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
	captive_title.text = "俘虏列表（点选或用右侧下拉框）"
	captive_title.add_theme_font_size_override("font_size", 21)
	left.add_child(captive_title)

	captive_list = ItemList.new()
	captive_list.custom_minimum_size = Vector2(310, 430)
	captive_list.item_selected.connect(_on_captive_selected)
	left.add_child(captive_list)

	var passive_all_btn: Button = Button.new()
	passive_all_btn.text = "放置全部待处理俘虏"
	passive_all_btn.pressed.connect(_on_passive_all_pressed)
	left.add_child(passive_all_btn)

	var return_btn: Button = Button.new()
	return_btn.text = "返回营地"
	return_btn.pressed.connect(_on_return_pressed)
	left.add_child(return_btn)

	var middle: VBoxContainer = VBoxContainer.new()
	middle.custom_minimum_size = Vector2(470, 0)
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

	var btn_passive: Button = Button.new()
	btn_passive.text = "放置：母巢自动处理 / 淫能大 / 屈辱小"
	btn_passive.pressed.connect(_select_action.bind("passive"))
	middle.add_child(btn_passive)

	var btn_train: Button = Button.new()
	btn_train.text = "调教：必须 角色 + 调教道具 + 俘虏"
	btn_train.pressed.connect(_select_action.bind("train"))
	middle.add_child(btn_train)

	var btn_mat: Button = Button.new()
	btn_mat.text = "物化：俘虏变下局装备 / 淫能0 / 屈辱大"
	btn_mat.pressed.connect(_select_action.bind("materialize"))
	middle.add_child(btn_mat)

	captive_option_label = Label.new()
	captive_option_label.text = "选择俘虏"
	middle.add_child(captive_option_label)
	captive_option = OptionButton.new()
	captive_option.item_selected.connect(_on_captive_option_selected)
	middle.add_child(captive_option)

	character_label = Label.new()
	character_label.text = "调教入替角色"
	middle.add_child(character_label)
	character_option = OptionButton.new()
	middle.add_child(character_option)

	item_label = Label.new()
	item_label.text = "调教道具"
	middle.add_child(item_label)
	item_option = OptionButton.new()
	middle.add_child(item_option)

	execute_button = Button.new()
	execute_button.text = "执行放置"
	execute_button.custom_minimum_size = Vector2(0, 54)
	execute_button.pressed.connect(_on_execute_pressed)
	middle.add_child(execute_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(440, 160)
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
	update_action_visibility()

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
		var captive_name: String = str(row.get("name", captive_id))
		var level: int = int(captive.get("humiliation_level", 0))
		var xp: int = int(captive.get("humiliation_xp", 0))
		var pending: bool = as_bool(captive.get("pending_action", false))
		var mark: String = "待处理" if pending else "已处理"
		var tier_label: String = get_captive_tier_label(captive_id)
		var text: String = "%s  [%s]  Lv%d  XP%d  [%s]" % [captive_name, tier_label, level, xp, mark]
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
	if captive_option != null:
		captive_option.clear()
		var captives: Dictionary = GameState.get_captives()
		var keys: Array = captives.keys()
		keys.sort()
		var selected_index: int = -1
		for key_value: Variant in keys:
			var captive_id: String = str(key_value)
			var row: Dictionary = get_captive_row(captive_id)
			var captive: Dictionary = GameState.get_captive_state(captive_id)
			var label: String = "%s  [%s]  Lv%s" % [str(row.get("name", captive_id)), get_captive_tier_label(captive_id), str(captive.get("humiliation_level", 0))]
			var index: int = captive_option.item_count
			captive_option.add_item(label)
			captive_option.set_item_metadata(index, captive_id)
			if captive_id == selected_captive_id:
				selected_index = index
		if captive_option.item_count > 0:
			if selected_index < 0:
				selected_index = 0
			captive_option.select(selected_index)
			selected_captive_id = str(captive_option.get_item_metadata(selected_index))

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
		var ids: Array = item_rows.keys()
		ids.sort()
		for id_key: Variant in ids:
			var row: Dictionary = item_rows[id_key]
			var id: String = str(row.get("id", "")).strip_edges()
			if id == "":
				continue
			if !is_torture_item_unlocked(row, id):
				continue
			var min_level: int = int(row.get("min_humiliation_level", 0))
			var suffix: String = "" if captive_level >= min_level else "  需要屈辱Lv" + str(min_level)
			item_option.add_item(str(row.get("name", id)) + suffix)
			item_option.set_item_metadata(item_option.item_count - 1, id)
			item_option.set_item_disabled(item_option.item_count - 1, captive_level < min_level)

func refresh_detail() -> void:
	if detail_label == null:
		return
	if action_label != null:
		action_label.text = "当前：" + get_action_name(selected_action)
	if selected_captive_id == "":
		detail_label.text = "[b]暂无俘虏[/b]\n关卡结算、隐藏事件或商人购买后会获得俘虏。"
		return
	var captive: Dictionary = GameState.get_captive_state(selected_captive_id)
	var row: Dictionary = get_captive_row(selected_captive_id)
	var captive_name: String = str(row.get("name", selected_captive_id))
	var xp: int = int(captive.get("humiliation_xp", 0))
	var level: int = int(captive.get("humiliation_level", 0))
	var text: String = "[b]" + captive_name + "[/b]\n"
	text += "ID：" + selected_captive_id + "\n"
	text += "类型：" + get_captive_tier_label(selected_captive_id) + "\n"
	text += "屈辱：Lv" + str(level) + " / 3   XP " + str(xp) + "\n"
	text += "来源：" + str(captive.get("source", "")) + "\n"
	text += "待处理：" + str(as_bool(captive.get("pending_action", false))) + "\n"
	text += "最近操作：" + str(captive.get("last_action", "")) + "\n"
	if captive_can_materialize(selected_captive_id):
		text += "下局物化装备：" + str(row.get("equipment_base_id", "")) + "_LV" + str(level) + "\n\n"
	else:
		text += "下局物化装备：无（普通俘虏只参与房车/养母 Link）\n\n"
	text += str(row.get("description", "占位俘虏")) + "\n\n"
	text += "[b]当前操作说明[/b]\n"
	if selected_action == "train":
		if captive_can_train(selected_captive_id):
			text += "调教必须三件套：角色 + 调教道具 + 俘虏。缺任何一项会退回放置，不触发CG。\n"
			text += "当前角色：" + get_selected_character_id() + "\n"
			text += "当前道具：" + get_selected_item_id() + "\n"
		else:
			text += "该俘虏是普通房车俘虏，不能进入专门调教；执行时会改为放置 Link。\n"
	elif selected_action == "materialize":
		if captive_can_materialize(selected_captive_id):
			text += "物化会把俘虏按当前屈辱等级转换成下局装备，只保留到下一场战斗。\n"
		else:
			text += "该俘虏不能物化装备；执行时会改为放置 Link。\n"
	else:
		text += get_captive_passive_label(selected_captive_id) + "\n"
	detail_label.text = text

func update_action_visibility() -> void:
	var train_mode: bool = selected_action == "train" and (selected_captive_id == "" or captive_can_train(selected_captive_id))
	if character_label != null:
		character_label.visible = train_mode
	if character_option != null:
		character_option.visible = train_mode
	if item_label != null:
		item_label.visible = train_mode
	if item_option != null:
		item_option.visible = train_mode
	if execute_button != null:
		var label_action: String = selected_action
		if selected_captive_id != "" and selected_action == "train" and !captive_can_train(selected_captive_id):
			label_action = "passive"
		elif selected_captive_id != "" and selected_action == "materialize" and !captive_can_materialize(selected_captive_id):
			label_action = "passive"
		execute_button.text = "执行" + get_action_name(label_action)
	if action_label != null:
		action_label.text = "当前：" + get_action_name(selected_action)

func _on_captive_selected(index: int) -> void:
	selected_captive_id = str(captive_list.get_item_metadata(index))
	refresh_options()
	refresh_detail()
	update_action_visibility()

func _on_captive_option_selected(index: int) -> void:
	if captive_option == null or index < 0 or index >= captive_option.item_count:
		return
	selected_captive_id = str(captive_option.get_item_metadata(index))
	if captive_list != null:
		for i: int in range(captive_list.item_count):
			if str(captive_list.get_item_metadata(i)) == selected_captive_id:
				captive_list.select(i)
				break
	refresh_options()
	refresh_detail()
	update_action_visibility()

func _select_action(action: String) -> void:
	selected_action = action
	refresh_options()
	refresh_detail()
	update_action_visibility()

func _on_execute_pressed() -> void:
	if selected_captive_id == "":
		show_status("没有选择俘虏。")
		return
	process_one_captive(selected_captive_id, selected_action)

func _on_passive_all_pressed() -> void:
	var ids: Array[String] = GameState.get_pending_captive_ids()
	if ids.is_empty():
		show_status("没有待处理俘虏。")
		return
	var total_lust: int = 0
	var total_hum: int = 0
	for captive_id: String in ids:
		var result: Dictionary = process_action_with_tables("passive", captive_id, "", "")
		if result.get("ok", false) == true:
			total_lust += int(result.get("lust_gain", 0))
			total_hum += int(result.get("humiliation_gain", 0))
	GameState.save_progress_now("dungeon_passive_all")
	refresh_all()
	show_status("放置完成：淫能 +%d，屈辱合计 +%d" % [total_lust, total_hum])
	debug_log("passive_all")

func process_one_captive(captive_id: String, action: String) -> void:
	var item_id: String = get_selected_item_id()
	var character_id: String = get_selected_character_id()
	var actual_action: String = action
	if actual_action == "train" and !captive_can_train(captive_id):
		actual_action = "passive"
		show_status("普通俘虏无法专门调教，已按房车/养母 Link 放置处理。")
	elif actual_action == "materialize" and !captive_can_materialize(captive_id):
		actual_action = "passive"
		show_status("普通俘虏无法物化装备，已按房车/养母 Link 放置处理。")
	if actual_action == "train" and (character_id == "" or item_id == "" or captive_id == ""):
		actual_action = "passive"
		show_status("调教缺少角色/道具/俘虏，已按放置处理。")
	if actual_action == "train":
		var item_row: Dictionary = get_item_row(item_id)
		var min_level: int = int(item_row.get("min_humiliation_level", 0))
		var captive_level: int = GameState.get_captive_humiliation_level(captive_id)
		if captive_level < min_level:
			show_status("俘虏屈辱等级不足，需要 Lv" + str(min_level))
			return
	var result: Dictionary = process_action_with_tables(actual_action, captive_id, item_id, character_id)
	if result.get("ok", false) != true:
		show_status(str(result.get("message", "处理失败")))
		return
	var event_text: String = ""
	if actual_action == "materialize":
		apply_materialize_equipment(captive_id)
	elif actual_action == "train":
		event_text = trigger_dungeon_event(character_id, item_id, captive_id)
	GameState.save_progress_now("dungeon_" + actual_action)
	refresh_all()
	var message: String = "%s完成：淫能 +%d，屈辱 +%d" % [get_action_name(actual_action), int(result.get("lust_gain", 0)), int(result.get("humiliation_gain", 0))]
	if actual_action == "passive" and !captive_can_train(captive_id):
		message += "\n" + get_captive_passive_label(captive_id)
	if event_text != "":
		message += "\n" + event_text
	show_status(message)
	debug_log("action " + actual_action + " captive=" + captive_id)

func process_action_with_tables(action: String, captive_id: String, item_id: String, character_id: String) -> Dictionary:
	var row: Dictionary = action_rows.get(action, {})
	var lust_gain: int = int(row.get("lust_gain", -999999))
	var hum_gain: int = int(row.get("humiliation_xp", -999999))
	if action == "train" and item_id != "":
		var item_row: Dictionary = get_item_row(item_id)
		lust_gain = int(round(float(lust_gain) * float(item_row.get("lust_gain_mul", 1.0))))
		hum_gain = int(round(float(hum_gain) * float(item_row.get("humiliation_xp_mul", 1.0))))
	return GameState.process_captive_action(action, captive_id, item_id, character_id, false, lust_gain, hum_gain)

func apply_materialize_equipment(captive_id: String) -> void:
	if !captive_can_materialize(captive_id):
		show_status("该俘虏不能物化装备。")
		return
	var row: Dictionary = get_captive_row(captive_id)
	var base_id: String = str(row.get("equipment_base_id", "")).strip_edges()
	if base_id == "":
		show_status("该俘虏未配置物化装备。")
		return
	var level: int = GameState.get_captive_humiliation_level(captive_id)
	var equipment_id: String = base_id + "_LV" + str(level)
	GameState.set_next_battle_captive_equipment(equipment_id, false)
	GameState.unlock_item("equipments", equipment_id, false)

func trigger_dungeon_event(actor_id: String, item_id: String, captive_id: String) -> String:
	var event_id: String = find_dungeon_story_event(actor_id, item_id, captive_id)
	if event_id == "":
		return "未配置特殊/普通CG，显示调教占位文本。"
	GameState.record_dungeon_story_result("", event_id, false)
	get_tree().root.set_meta("pending_avg_event", event_id)
	var story_row: Dictionary = story_event_rows.get(event_id, {})
	var placeholder: String = str(story_row.get("placeholder_text", event_id))
	return placeholder

func find_dungeon_story_event(actor_id: String, item_id: String, captive_id: String) -> String:
	# 调教CG只有两类：
	# 1) actor + item + captive 特定组合的一次性 special_event_id。
	# 2) 已触发过，或只有 * + item + captive 的普通 generic_event_id。
	# 缺 actor/item/captive 时不会进入这里，外层会退回放置。
	var generic_event_id: String = ""
	for row: Dictionary in dungeon_event_rows:
		if !matches_event_value(str(row.get("item_id", "")), item_id):
			continue
		if !matches_event_value(str(row.get("captive_id", "")), captive_id):
			continue
		var min_level: int = int(row.get("min_humiliation_level", 0))
		if GameState.get_captive_humiliation_level(captive_id) < min_level:
			continue
		var row_actor: String = str(row.get("actor_id", "")).strip_edges()
		if row_actor == "*":
			if generic_event_id == "":
				generic_event_id = str(row.get("generic_event_id", row.get("event_id", ""))).strip_edges()
			continue
		if row_actor == actor_id:
			var flag_key: String = str(row.get("flag_key", "")).strip_edges()
			var special_event_id: String = str(row.get("special_event_id", "")).strip_edges()
			var row_generic: String = str(row.get("generic_event_id", "")).strip_edges()
			var already_seen: bool = false
			if flag_key != "":
				already_seen = int(GameState.get_flag(flag_key, 0)) != 0
			if !already_seen and special_event_id != "":
				if flag_key != "":
					GameState.set_flag(flag_key, 1, false)
				return special_event_id
			if row_generic != "":
				return row_generic
	if generic_event_id != "":
		return generic_event_id
	return ""

func matches_event_value(pattern: String, value: String) -> bool:
	var clean: String = pattern.strip_edges()
	return clean == "*" or clean == value

func _on_return_pressed() -> void:
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	GameState.save_progress_now("return_basement_from_dungeon")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)

func get_captive_row(captive_id: String) -> Dictionary:
	var value: Variant = captive_rows.get(captive_id, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {"id": captive_id, "name": captive_id, "description": "占位俘虏", "equipment_base_id": "", "tier": "common", "can_train": "FALSE", "can_materialize": "FALSE"}

func get_captive_tier(captive_id: String) -> String:
	var row: Dictionary = get_captive_row(captive_id)
	var tier: String = str(row.get("tier", "")).strip_edges().to_lower()
	if tier == "":
		# Backward compatibility: old Captives.csv rows without tier are treated as special.
		return "special"
	if tier == "core":
		return "special"
	return tier

func get_captive_tier_label(captive_id: String) -> String:
	var tier: String = get_captive_tier(captive_id)
	if tier == "special":
		return "特别"
	if tier == "common":
		return "普通"
	return tier

func captive_can_train(captive_id: String) -> bool:
	var row: Dictionary = get_captive_row(captive_id)
	var raw: String = str(row.get("can_train", "")).strip_edges()
	if raw == "":
		return get_captive_tier(captive_id) == "special"
	return as_bool(raw)

func captive_can_materialize(captive_id: String) -> bool:
	var row: Dictionary = get_captive_row(captive_id)
	var raw: String = str(row.get("can_materialize", "")).strip_edges()
	if raw == "":
		return get_captive_tier(captive_id) == "special" and str(row.get("equipment_base_id", "")).strip_edges() != ""
	return as_bool(raw) and str(row.get("equipment_base_id", "")).strip_edges() != ""

func get_captive_passive_label(captive_id: String) -> String:
	var row: Dictionary = get_captive_row(captive_id)
	var text: String = str(row.get("passive_label", "")).strip_edges()
	if text != "":
		return text
	if captive_can_train(captive_id):
		return "放置：房车/养母自动处理，作为 Link 样本维持资源循环。"
	return "放置：普通俘虏不进入专门调教，只作为房车/养母 Link 对象产出淫能。"

func get_item_row(item_id: String) -> Dictionary:
	var value: Variant = item_rows.get(item_id, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
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
		return ""
	var index: int = character_option.selected
	if index < 0 or index >= character_option.item_count:
		return ""
	return str(character_option.get_item_metadata(index))

func is_row_unlocked(row: Dictionary, category: String, id: String) -> bool:
	var unlocked_text: String = str(row.get("unlocked", "TRUE")).strip_edges().to_lower()
	if unlocked_text == "true" or unlocked_text == "1" or unlocked_text == "yes":
		return true
	return GameState.is_unlocked(category, id)

func is_torture_item_unlocked(row: Dictionary, id: String) -> bool:
	var unlocked_text: String = str(row.get("unlocked", "FALSE")).strip_edges().to_lower()
	if unlocked_text == "true" or unlocked_text == "1" or unlocked_text == "yes":
		return true
	return GameState.is_unlocked("torture_items", id)

func as_bool(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value) != 0.0
	var text: String = str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes"

func get_action_name(action: String) -> String:
	if action == "passive" or action == "idle":
		return "放置"
	if action == "train" or action == "torture":
		return "调教"
	if action == "materialize":
		return "物化"
	return action

func show_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func debug_log(message: String) -> void:
	var dbg: Node = get_node_or_null("/root/ProjectDebug")
	if dbg != null and dbg.has_method("log"):
		dbg.call("log", "Dungeon", message)
