extends Control

const GOODS_CSV: String = "res://Config/MerchantGoods.csv"
const TEMP_ITEMS_CSV: String = "res://Config/TemporaryItems.csv"
const CAPTIVES_CSV: String = "res://Config/Captives.csv"
const STORY_EVENTS_CSV: String = "res://Config/StoryEvents.csv"
const BASEMENT_SCENE_PATH: String = "res://scenes/Basement.tscn"

var goods_rows: Array[Dictionary] = []
var temp_items: Dictionary = {}
var captives: Dictionary = {}
var story_events: Dictionary = {}
var current_tab: String = "temp"
var selected_id: String = ""

var lust_label: Label = null
var chapter_label: Label = null
var message_label: RichTextLabel = null
var list_box: VBoxContainer = null
var detail_label: RichTextLabel = null
var buy_button: Button = null
var tab_buttons: Dictionary = {}

func _ready() -> void:
	GameState.ensure_loaded()
	load_rows()
	build_ui()
	select_tab("temp")

func build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.name = "ColorRect背景"
	background.color = Color(0.075, 0.035, 0.085, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBox主容器"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 26.0
	root.offset_top = 22.0
	root.offset_right = -26.0
	root.offset_bottom = -22.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var title: Label = Label.new()
	title.name = "Label标题"
	title.text = "史莱姆娘商人"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	root.add_child(top)
	lust_label = Label.new()
	lust_label.add_theme_font_size_override("font_size", 22)
	top.add_child(lust_label)
	chapter_label = Label.new()
	chapter_label.add_theme_font_size_override("font_size", 22)
	top.add_child(chapter_label)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(190, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	add_tab_button(left, "temp", "临时强化")
	add_tab_button(left, "captive", "俘虏商品")
	add_tab_button(left, "event", "逛街剧情")
	var back_button: Button = Button.new()
	back_button.text = "返回营地"
	back_button.custom_minimum_size = Vector2(160, 48)
	back_button.pressed.connect(_on_back_pressed)
	left.add_child(back_button)
	var center_panel: PanelContainer = PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	detail_label = RichTextLabel.new()
	detail_label.bbcode_enabled = true
	detail_label.fit_content = false
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_label)
	buy_button = Button.new()
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(180, 52)
	buy_button.pressed.connect(_on_buy_pressed)
	right.add_child(buy_button)
	message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.custom_minimum_size = Vector2(0, 76)
	root.add_child(message_label)
	refresh_header()

func add_tab_button(parent: VBoxContainer, tab: String, label_text: String) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(160, 48)
	button.pressed.connect(select_tab.bind(tab))
	parent.add_child(button)
	tab_buttons[tab] = button

func load_rows() -> void:
	goods_rows = load_csv_array(GOODS_CSV)
	temp_items = load_csv_by_id(TEMP_ITEMS_CSV)
	captives = load_csv_by_id(CAPTIVES_CSV)
	story_events = load_csv_by_id(STORY_EVENTS_CSV)

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

func select_tab(tab: String) -> void:
	current_tab = tab
	selected_id = ""
	for raw_tab in tab_buttons.keys():
		var tab_key: String = str(raw_tab)
		var button: Button = tab_buttons[tab_key]
		button.disabled = tab_key == current_tab
	refresh_list()
	select_first_available()

func refresh_header() -> void:
	if lust_label != null:
		lust_label.text = "淫能：" + str(GameState.get_lust())
	if chapter_label != null:
		chapter_label.text = "章节：" + str(GameState.get_chapter_id()) + "  " + GameState.get_chapter_name()

func refresh_list() -> void:
	if list_box == null:
		return
	for child in list_box.get_children():
		child.queue_free()
	for row: Dictionary in goods_rows:
		var tab: String = str(row.get("tab", "temp")).strip_edges()
		if tab != current_tab:
			continue
		var id: String = str(row.get("id", "")).strip_edges()
		var button: Button = Button.new()
		button.text = get_goods_display_name(row) + "  /  " + str(get_goods_cost(row)) + "淫能"
		if !is_unlock_key_met(str(row.get("unlock_key", "START"))):
			button.text += "  [未解锁]"
		if is_sold_out(row):
			button.text += "  [已售罄]"
		elif is_temp_effect_already_prepared(row):
			button.text += "  [本次已准备]"
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_item_pressed.bind(id))
		list_box.add_child(button)

func select_first_available() -> void:
	for row: Dictionary in goods_rows:
		if str(row.get("tab", "temp")).strip_edges() == current_tab:
			selected_id = str(row.get("id", "")).strip_edges()
			refresh_detail()
			return
	refresh_detail()

func _on_item_pressed(id: String) -> void:
	selected_id = id
	refresh_detail()

func get_selected_row() -> Dictionary:
	for row: Dictionary in goods_rows:
		if str(row.get("id", "")).strip_edges() == selected_id:
			return row
	return {}

func refresh_detail() -> void:
	refresh_header()
	var row: Dictionary = get_selected_row()
	if row.is_empty():
		if detail_label != null:
			detail_label.text = "没有商品。"
		if buy_button != null:
			buy_button.disabled = true
		return
	var text: String = "[font_size=26][b]" + get_goods_display_name(row) + "[/b][/font_size]\n"
	text += "ID：" + str(row.get("id", "")) + "\n"
	text += "类型：" + str(row.get("goods_type", "")) + " / " + str(row.get("ref_id", "")) + "\n"
	text += "价格：" + str(get_goods_cost(row)) + " 淫能\n"
	text += "解锁：" + str(row.get("unlock_key", "START")) + "\n\n"
	text += get_goods_description(row) + "\n"
	if is_sold_out(row):
		text += "\n[color=#ff99cc]已购买 / 已触发。[/color]"
	var temp_block: String = get_next_battle_temp_state_text(row)
	if temp_block != "":
		text += "\n" + temp_block
	if detail_label != null:
		detail_label.text = text
	if buy_button != null:
		buy_button.disabled = !can_buy(row)

func get_goods_display_name(row: Dictionary) -> String:
	var goods_type: String = str(row.get("goods_type", "temp_item")).strip_edges()
	var ref_id: String = str(row.get("ref_id", "")).strip_edges()
	if goods_type == "temp_item" and temp_items.has(ref_id):
		return str(temp_items[ref_id].get("name", ref_id))
	if goods_type == "captive" and captives.has(ref_id):
		return str(captives[ref_id].get("name", ref_id))
	if goods_type == "story_event" and story_events.has(ref_id):
		return str(story_events[ref_id].get("name", ref_id))
	return str(row.get("name", ref_id))

func get_goods_description(row: Dictionary) -> String:
	var goods_type: String = str(row.get("goods_type", "temp_item")).strip_edges()
	var ref_id: String = str(row.get("ref_id", "")).strip_edges()
	if goods_type == "temp_item" and temp_items.has(ref_id):
		return str(temp_items[ref_id].get("description", ""))
	if goods_type == "captive" and captives.has(ref_id):
		return str(captives[ref_id].get("description", ""))
	if goods_type == "story_event" and story_events.has(ref_id):
		return str(story_events[ref_id].get("description", story_events[ref_id].get("placeholder_text", "")))
	return str(row.get("description", ""))

func get_goods_cost(row: Dictionary) -> int:
	return int(row.get("cost", 0))

func can_buy(row: Dictionary) -> bool:
	if !is_unlock_key_met(str(row.get("unlock_key", "START"))):
		return false
	var goods_type: String = str(row.get("goods_type", "temp_item")).strip_edges()
	var ref_id: String = str(row.get("ref_id", "")).strip_edges()
	if is_sold_out(row):
		# 调试/修档兜底：如果商人购买次数已经写了，但俘虏没有进 dungeon.captives，允许重新买一次补写。
		if !(goods_type == "captive" and ref_id != "" and !GameState.has_captive(ref_id)):
			return false
	if is_temp_effect_already_prepared(row):
		return false
	return GameState.get_lust() >= get_goods_cost(row)

func is_sold_out(row: Dictionary) -> bool:
	var id: String = str(row.get("id", "")).strip_edges()
	var stock: int = int(row.get("stock", 0))
	if stock > 0 and GameState.get_merchant_purchase_count(id) >= stock:
		return true
	var one_time: bool = str(row.get("one_time", "FALSE")).strip_edges().to_lower() in ["true", "1", "yes"]
	if one_time and GameState.get_merchant_purchase_count(id) > 0:
		return true
	return false

func is_temp_effect_already_prepared(row: Dictionary) -> bool:
	var goods_type: String = str(row.get("goods_type", "temp_item")).strip_edges()
	if goods_type != "temp_item":
		return false
	var ref_id: String = str(row.get("ref_id", "")).strip_edges()
	if ref_id == "":
		return false
	var temp_row: Dictionary = temp_items.get(ref_id, {})
	var effect_key: String = str(temp_row.get("effect_key", "")).strip_edges()
	if effect_key == "":
		return GameState.get_next_battle_temp_items().has(ref_id)
	if GameState.has_method("has_merchant_next_battle_effect"):
		return GameState.has_merchant_next_battle_effect(effect_key)
	return GameState.get_next_battle_temp_items().has(ref_id)

func get_next_battle_temp_state_text(row: Dictionary) -> String:
	if str(row.get("goods_type", "temp_item")).strip_edges() != "temp_item":
		return ""
	if is_temp_effect_already_prepared(row):
		return "[color=#ffee99]本次营地已准备同类临时强化。打完下一场后会清空。[/color]"
	return ""

func is_unlock_key_met(key_text: String) -> bool:
	var key: String = key_text.strip_edges()
	if key == "" or key == "START":
		return true
	if key.begins_with("CHAPTER_"):
		return GameState.get_chapter_id() >= int(key.substr("CHAPTER_".length()))
	if key.begins_with("FLAG_"):
		return int(GameState.get_flag(key, 0)) != 0
	return GameState.is_unlocked("merchant_goods", key) or GameState.is_unlocked("story_events", key)

func _on_buy_pressed() -> void:
	var row: Dictionary = get_selected_row()
	if row.is_empty():
		return
	var result: Dictionary = buy_goods(row)
	var ok: bool = result.get("ok", false) == true
	var message: String = str(result.get("message", ""))
	if message_label != null:
		message_label.text = ("[color=#b7ffcc]" if ok else "[color=#ff99aa]") + message + "[/color]"
	refresh_header()
	refresh_list()
	refresh_detail()

func buy_goods(row: Dictionary) -> Dictionary:
	var goods_id: String = str(row.get("id", "")).strip_edges()
	var goods_type: String = str(row.get("goods_type", "temp_item")).strip_edges()
	var ref_id: String = str(row.get("ref_id", "")).strip_edges()
	var cost: int = get_goods_cost(row)
	if goods_id == "" or ref_id == "":
		return {"ok": false, "message": "商品配置不完整"}
	if !can_buy(row):
		if is_temp_effect_already_prepared(row):
			return {"ok": false, "message": "本次营地已购买同类临时强化，打完下一场后才能再买。"}
		return {"ok": false, "message": "无法购买"}
	if cost > 0 and !GameState.spend_lust(cost, false):
		return {"ok": false, "message": "淫能不足"}
	if goods_type == "temp_item":
		var temp_row: Dictionary = temp_items.get(ref_id, {})
		GameState.add_next_battle_temp_item(ref_id, false)
		var effect_key: String = str(temp_row.get("effect_key", "")).strip_edges()
		var value: float = float(temp_row.get("value", 0.0))
		if effect_key != "" and value != 0.0:
			GameState.add_merchant_next_battle_effect(effect_key, value, false)
	elif goods_type == "captive":
		GameState.add_captive(ref_id, "merchant", false)
		if !GameState.has_captive(ref_id):
			return {"ok": false, "message": "俘虏写入存档失败：" + ref_id}
	elif goods_type == "story_event":
		GameState.unlock_story_event(ref_id, false)
		GameState.record_merchant_event(ref_id, false)
		get_tree().root.set_meta("pending_avg_event", ref_id)
	else:
		return {"ok": false, "message": "未知商品类型"}
	GameState.record_merchant_purchase(goods_id, false)
	GameState.save_progress_now("merchant_buy_" + goods_id)
	debug_log("buy " + goods_id + " ref=" + ref_id)
	return {"ok": true, "message": "购买完成：" + get_goods_display_name(row)}

func _on_back_pressed() -> void:
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	GameState.save_progress_now("merchant_back")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)


func debug_log(message: String) -> void:
	var dbg: Node = get_node_or_null("/root/ProjectDebug")
	if dbg != null and dbg.has_method("log"):
		dbg.call("log", "Merchant", message)
