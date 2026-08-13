extends Control

## Run-scoped Shop route. It shares the native canvas but not the meta Shop's
## persistent wallet or Lab upgrade state.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)

var _font: FontFile = null
var _gold_label: Label = null
var _message: Label = null
var _list: VBoxContainer = null

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.025, 0.08, 1.0)
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := _label("SHOP / MACHINE INVESTMENT", Rect2(4.0, 7.0, 152.0, 14.0), 8, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_gold_label = _label("", Rect2(4.0, 25.0, 152.0, 12.0), 7, GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_gold_label)
	_list = VBoxContainer.new()
	_list.name = "RunShopItems"
	_list.position = Vector2(5.0, 46.0)
	_list.size = Vector2(150.0, 184.0)
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	_message = _label("", Rect2(5.0, 239.0, 150.0, 16.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	var leave := _button("RETURN TO MACHINE", Rect2(20.0, 274.0, 120.0, 25.0), 7)
	leave.name = "ReturnButton"
	leave.pressed.connect(_on_return_pressed)
	add_child(leave)

func _refresh() -> void:
	_gold_label.text = "RUN LUCIDITY / GOLD: %d" % int(RunStateStore.lucidityCoins)
	for child in _list.get_children():
		child.queue_free()
	for item in RunStateStore.route_shop_items():
		var item_id := String(item.get("id", ""))
		var cost := int(item.get("cost", 0))
		var purchased := RunStateStore.route_shop_item_purchased(item_id)
		var row := _button("", Rect2(0.0, 0.0, 150.0, 34.0), 5)
		row.name = "Item_%s" % item_id
		row.text = "%s  %dG\n%s" % [String(item.get("name", item_id)), cost,
			String(item.get("description", ""))]
		row.disabled = purchased or int(RunStateStore.lucidityCoins) < cost
		if purchased:
			row.text += "  / BOUGHT"
		row.pressed.connect(_on_item_pressed.bind(item_id))
		_list.add_child(row)

func _on_item_pressed(item_id: String) -> void:
	if not RunStateStore.buy_route_shop_item(item_id):
		_message.text = "PURCHASE REFUSED"
	else:
		_message.text = "THE MACHINE ACCEPTS THE INVESTMENT"
	_refresh()

func _on_return_pressed() -> void:
	if not RunStateStore.finish_route_destination():
		_message.text = "MACHINE UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _label(text_value: String, rect: Rect2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label

func _button(text_value: String, rect: Rect2, size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	if _font != null:
		button.add_theme_font_override("font", _font)
	return button
