extends Control

## Between-machine Dealer route. Tactical services live here; machine upgrades
## and consumables stay in RouteShop, and identity cards stay in Pacte.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)
const INK := Color(0.035, 0.025, 0.075)

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
	background.color = INK
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -20
	add_child(background)
	var header_panel := _panel(Rect2(3.0, 3.0, 154.0, 47.0), CYAN, 0.92)
	header_panel.name = "RouteDealerHeaderPanel"
	header_panel.z_index = -5
	add_child(header_panel)
	var catalog_panel := _panel(Rect2(3.0, 49.0, 154.0, 162.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.34), 0.96)
	catalog_panel.name = "RouteDealerCatalogPanel"
	catalog_panel.z_index = -5
	add_child(catalog_panel)
	var title := _label("DEALER / TACTICAL", Rect2(4.0, 7.0, 152.0, 14.0), 9, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_gold_label = _label("", Rect2(4.0, 25.0, 152.0, 12.0), 7, GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_gold_label)
	var subtitle := _label("POWERS, REROLLS, AND TIMING", Rect2(4.0, 38.0, 152.0, 9.0), 4, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	_list = VBoxContainer.new()
	_list.name = "ServiceList"
	_list.position = Vector2(5.0, 54.0)
	_list.size = Vector2(150.0, 150.0)
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)
	_message = _label("", Rect2(5.0, 224.0, 150.0, 24.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	var leave := _button("RETURN TO MACHINE", Rect2(20.0, 274.0, 120.0, 25.0), 7)
	leave.name = "ReturnButton"
	ButtonKit.small_neon_button_style(leave, CYAN, 6, 2.0)
	# Apply final bounds after the skin changes font and style minimums.
	leave.clip_text = true
	leave.set_deferred("size", Vector2(120.0, 25.0))
	leave.pressed.connect(_on_return_pressed)
	add_child(leave)

func _refresh() -> void:
	_gold_label.text = "RUN LUCIDITY / GOLD: %d" % int(RunStateStore.lucidityCoins)
	for child in _list.get_children():
		child.queue_free()
	for service in RunStateStore.route_dealer_services():
		var service_id := String(service.get("id", ""))
		var cost := int(service.get("cost", 0))
		var button := _button("%s  %dG\n%s" % [String(service.get("name", service_id)), cost,
			String(service.get("description", ""))], Rect2(0.0, 0.0, 150.0, 35.0), 6)
		_style_service_button(button)
		button.disabled = int(RunStateStore.lucidityCoins) < cost
		button.pressed.connect(_on_service_pressed.bind(service_id))
		_list.add_child(button)

func _on_service_pressed(service_id: String) -> void:
	if not RunStateStore.buy_route_dealer_service(service_id):
		_message.text = "THE DEALER LAUGHS"
	else:
		_message.text = "THE DEALER MOVES THE ODDS"
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
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.size = rect.size
	return button

func _panel(rect: Rect2, border_color: Color, alpha: float) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ButtonKit.neon_panel_style(border_color, 1.0)
	style.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _style_service_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.11, 0.14, 0.96)
	normal.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.30)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 4.0
	normal.content_margin_right = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.18, 0.20, 0.98)
	hover.border_color = CYAN
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.15, 0.22, 0.20, 1.0)
	pressed.content_margin_top = 2.0
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.055, 0.06, 0.09, 0.94)
	disabled.border_color = Color(0.34, 0.38, 0.45, 0.40)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, {
			"normal": normal, "hover": hover, "pressed": pressed,
			"focus": hover, "disabled": disabled,
		}[state])
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.90))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.38))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.56, 0.62))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
