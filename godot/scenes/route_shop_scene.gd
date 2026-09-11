extends Control

## Run-scoped Shop route. It shares the native canvas but not the meta Shop's
## persistent wallet or Lab upgrade state.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)
const INK := Color(0.035, 0.025, 0.075)
const PANEL_RECT := Rect2(3.0, 40.0, 154.0, 198.0)
const LIST_RECT := Rect2(7.0, 45.0, 146.0, 188.0)
const ROW_HEIGHT := 32.0
const ROW_GAP := 3.0

var _font: FontFile = null
var _gold_label: Label = null
var _message: Label = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _build() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var header := _panel(Rect2(3.0, 3.0, 154.0, 34.0), CYAN, 0.88)
	add_child(header)
	var title := _label("MACHINE SHOP", Rect2(5.0, 7.0, 150.0, 11.0), 7, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_gold_label = _label("", Rect2(5.0, 23.0, 150.0, 9.0), 5, GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_gold_label)
	var panel := _panel(PANEL_RECT, Color(CYAN.r, CYAN.g, CYAN.b, 0.36), 0.96)
	add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.name = "ShopScroll"
	_scroll.position = LIST_RECT.position
	_scroll.size = LIST_RECT.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "RunShopItems"
	# Leave room for the native vertical scrollbar inside the viewport; otherwise
	# the child minimum forces the ScrollContainer three pixels wider than its panel.
	_list.custom_minimum_size = Vector2(LIST_RECT.size.x - 12.0, 0.0)
	_list.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_list)
	_message = _label("", Rect2(5.0, 239.0, 150.0, 16.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	var leave := _button("RETURN TO MACHINE", Rect2(20.0, 274.0, 120.0, 25.0), 7)
	leave.name = "ReturnButton"
	ButtonKit.small_neon_button_style(leave, CYAN, 5, 2.0)
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
		var row := _button("", Rect2(0.0, 0.0, LIST_RECT.size.x - 8.0, ROW_HEIGHT), 5)
		row.name = "Item_%s" % item_id
		row.custom_minimum_size = Vector2(LIST_RECT.size.x - 8.0, ROW_HEIGHT)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s   %dG\n%s" % [String(item.get("name", item_id)), cost,
			String(item.get("description", ""))]
		row.disabled = purchased or int(RunStateStore.lucidityCoins) < cost
		if purchased:
			row.text += "  / BOUGHT"
		_style_shop_row(row, purchased)
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

func _panel(rect: Rect2, border_color: Color, alpha: float) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ButtonKit.neon_panel_style(border_color, 1.0)
	style.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _style_shop_row(row: Button, purchased: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.11, 0.14, 0.96)
	normal.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.32)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 4.0
	normal.content_margin_right = 3.0
	normal.content_margin_top = 1.0
	normal.content_margin_bottom = 1.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.18, 0.20, 0.98)
	hover.border_color = CYAN
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.15, 0.22, 0.20, 1.0)
	pressed.content_margin_top = 3.0
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.055, 0.06, 0.09, 0.94)
	disabled.border_color = Color(0.34, 0.38, 0.45, 0.44)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		row.add_theme_stylebox_override(state, {
			"normal": normal, "hover": hover, "pressed": pressed,
			"focus": hover, "disabled": disabled,
		}[state])
	row.add_theme_color_override("font_color", Color(0.92, 0.96, 0.90))
	row.add_theme_color_override("font_hover_color", Color.WHITE)
	row.add_theme_color_override("font_pressed_color", GOLD)
	row.add_theme_color_override("font_focus_color", Color.WHITE)
	row.add_theme_color_override("font_disabled_color", Color(0.52, 0.56, 0.62))
	row.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_theme_constant_override("outline_size", 1)
	row.add_theme_font_size_override("font_size", 5 if not purchased else 4)
	row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

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
