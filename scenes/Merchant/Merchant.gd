extends Control

const GOODS_CSV: String = "res://Config/MerchantGoods.csv"
const BASEMENT_SCENE_PATH: String = "res://scenes/Basement.tscn"

var rows: Array[Dictionary] = []
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
	top.name = "HBox状态"
	top.add_theme_constant_override("separation", 18)
	root.add_child(top)

	lust_label = Label.new()
	lust_label.name = "Label淫能"
	lust_label.add_theme_font_size_override("font_size", 22)
	top.add_child(lust_label)

	chapter_label = Label.new()
	chapter_label.name = "Label章节"
	chapter_label.add_theme_font_size_override("font_size", 22)
	top.add_child(chapter_label)

	var body: HBoxContainer = HBoxContainer.new()
	body.name = "HBox主体"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left: VBoxContainer = VBoxContainer.new()
	left.name = "VBox分页"
	left.custom_minimum_size = Vector2(190, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)

	add_tab_button(left, "temp", "临时强化")
	add_tab_button(left, "captive", "俘虏商品")
	add_tab_button(left, "event", "逛街剧情")

	var back_button: Button = Button.new()
	back_button.name = "Button返回营地"
	back_button.text = "返回营地"
	back_button.custom_minimum_size = Vector2(160, 48)
	back_button.pressed.connect(_on_back_pressed)
	left.add_child(back_button)

	var center_panel: PanelContainer = PanelContainer.new()
	center_panel.name = "Panel商品列表"
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll商品"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.name = "VBox商品按钮"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)

	var right: VBoxContainer = VBoxContainer.new()
	right.name = "VBox详情"
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)

	detail_label = RichTextLabel.new()
	detail_label.name = "RichText详情"
	detail_label.bbcode_enabled = true
	detail_label.fit_content = false
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_label)

	buy_button = Button.new()
	buy_button.name = "Button购买"
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(180, 52)
	buy_button.pressed.connect(_on_buy_pressed)
	right.add_child(buy_button)

	message_label = RichTextLabel.new()
	message_label.name = "RichText消息"
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
	rows.clear()
	if !FileAccess.file_exists(GOODS_CSV):
		push_warning("Missing merchant goods csv: " + GOODS_CSV)
		return
	var file: FileAccess = FileAccess.open(GOODS_CSV, FileAccess.READ)
	if file == null:
		return
	var headers: PackedStringArray = file.get_csv_line()
	while !file.eof_reached():
		var columns: PackedStringArray = file.get_csv_line()
		if columns.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(headers.size()):
			var key: String = headers[i].strip_edges()
			var value: String = ""
			if i < columns.size():
				value = columns[i].strip_edges()
			row[key] = value
		var id: String = str(row.get("id", "")).strip_edges()
		if id != "":
			rows.append(row)
	file.close()

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
	var chapter_id: int = GameState.get_chapter_id()
	for row in rows:
		var tab: String = str(row.get("tab", "temp")).strip_edges()
		if tab != current_tab:
			continue
		var button: Button = Button.new()
		var id: String = str(row.get("id", "")).strip_edges()
		var name: String = str(row.get("name", id))
		var cost: int = int(row.get("cost", 0))
		var unlock_chapter: int = int(row.get("unlock_chapter", 0))
		button.text = name + "  /  " + str(cost) + "淫能"
		if chapter_id < unlock_chapter:
			button.text += "  [章节" + str(unlock_chapter) + "]"
		if is_sold_out(row):
			button.text += "  [已售罄]"
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("merchant_id", id)
		button.pressed.connect(_on_item_pressed.bind(id))
		list_box.add_child(button)

func select_first_available() -> void:
	for row in rows:
		var tab: String = str(row.get("tab", "temp")).strip_edges()
		if tab == current_tab:
			selected_id = str(row.get("id", "")).strip_edges()
			refresh_detail()
			return
	refresh_detail()

func _on_item_pressed(id: String) -> void:
	selected_id = id
	refresh_detail()

func get_selected_row() -> Dictionary:
	for row in rows:
		var id: String = str(row.get("id", "")).strip_edges()
		if id == selected_id:
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
	var id: String = str(row.get("id", ""))
	var name: String = str(row.get("name", id))
	var desc: String = str(row.get("desc", ""))
	var cost: int = int(row.get("cost", 0))
	var unlock_chapter: int = int(row.get("unlock_chapter", 0))
	var text: String = "[font_size=26][b]" + name + "[/b][/font_size]\n"
	text += "ID：" + id + "\n"
	text += "价格：" + str(cost) + " 淫能\n"
	text += "解锁章节：" + str(unlock_chapter) + "\n\n"
	text += desc + "\n\n"
	var tab: String = str(row.get("tab", "temp"))
	if tab == "temp":
		text += "下次战斗效果：" + str(row.get("effect_key", "")) + "  " + str(row.get("value", "")) + "\n"
		var effects: Dictionary = GameState.get_merchant_next_battle_effects()
		if !effects.is_empty():
			text += "\n当前已购买的下局临时效果：\n"
			for raw_key in effects.keys():
				var key: String = str(raw_key)
				text += "- " + key + "：" + str(effects[raw_key]) + "\n"
	elif tab == "captive":
		text += "俘虏ID：" + str(row.get("captive_id", "")) + "\n"
	elif tab == "event":
		text += "事件ID：" + str(row.get("event_id", "")) + "\n"
	if is_sold_out(row):
		text += "\n[color=#ff99cc]已购买 / 已触发。[/color]"
	if detail_label != null:
		detail_label.text = text
	if buy_button != null:
		buy_button.disabled = !can_buy(row)

func can_buy(row: Dictionary) -> bool:
	var unlock_chapter: int = int(row.get("unlock_chapter", 0))
	if GameState.get_chapter_id() < unlock_chapter:
		return false
	if is_sold_out(row):
		return false
	var cost: int = int(row.get("cost", 0))
	return GameState.get_lust() >= cost

func is_sold_out(row: Dictionary) -> bool:
	var id: String = str(row.get("id", "")).strip_edges()
	var limit: int = int(row.get("purchase_limit", 0))
	if limit > 0 and GameState.get_merchant_purchase_count(id) >= limit:
		return true
	var event_id: String = str(row.get("event_id", "")).strip_edges()
	var one_time_text: String = str(row.get("one_time", "FALSE")).strip_edges().to_lower()
	var one_time: bool = one_time_text == "true" or one_time_text == "1" or one_time_text == "yes"
	if one_time and event_id != "" and GameState.has_merchant_event_seen(event_id):
		return true
	return false

func _on_buy_pressed() -> void:
	var row: Dictionary = get_selected_row()
	if row.is_empty():
		return
	var result: Dictionary = GameState.buy_merchant_item(row)
	var ok_value: Variant = result.get("ok", false)
	var ok: bool = ok_value == true or str(ok_value).to_lower() == "true" or str(ok_value) == "1"
	var message: String = str(result.get("message", ""))
	if message_label != null:
		if ok:
			message_label.text = "[color=#b7ffcc]" + message + "[/color]"
		else:
			message_label.text = "[color=#ff99aa]" + message + "[/color]"
	refresh_header()
	refresh_list()
	refresh_detail()

func _on_back_pressed() -> void:
	GameState.set_last_scene(BASEMENT_SCENE_PATH, false)
	if GameState.has_method("save_progress_now"):
		GameState.save_progress_now("merchant_back")
	else:
		GameState.autosave("merchant_back")
	get_tree().change_scene_to_file(BASEMENT_SCENE_PATH)
