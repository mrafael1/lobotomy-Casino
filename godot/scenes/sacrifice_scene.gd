extends Control

## Between-machine Sacrifice route. A choice is staged locally, then committed
## atomically by RunStateStore so closing the scene cannot duplicate its boon.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const HOT_GOLD := Color(1.0, 0.95, 0.62)
const MUTED := Color(0.62, 0.70, 0.78)
const ROSE := Color(1.0, 0.35, 0.66)
const RED := Color(1.0, 0.35, 0.42)
const INK := Color(0.055, 0.035, 0.105)

var _font: FontFile = null
var _balance: Label = null
var _progress: Label = null
var _instruction: Label = null
var _options: VBoxContainer = null
var _selected: Label = null
var _message: Label = null
var _confirm: Button = null
var _continue: Button = null
var _selected_option_id := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = Assets.font()
	_build()
	if not Engine.is_editor_hint() and not RunStateStore.state_changed.is_connected(_refresh):
		RunStateStore.state_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var wash := ColorRect.new()
	wash.color = Color(INK.r, INK.g, INK.b, 0.72)
	wash.position = Vector2.ZERO
	wash.size = CANVAS_SIZE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.z_index = -5
	add_child(wash)

	var header := _panel(Rect2(3.0, 3.0, 154.0, 49.0),
		Color(INK.r, INK.g, INK.b, 0.94), Color(ROSE.r, ROSE.g, ROSE.b, 0.70))
	header.z_index = 5
	add_child(header)
	var title := _label("SACRIFICE", Rect2(5.0, 6.0, 150.0, 11.0), 8, ROSE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 10
	add_child(title)
	_balance = _label("", Rect2(5.0, 20.0, 150.0, 9.0), 5, GOLD)
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance.z_index = 10
	add_child(_balance)
	_progress = _label("", Rect2(5.0, 31.0, 150.0, 9.0), 5, CYAN)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.z_index = 10
	add_child(_progress)
	_instruction = _label("", Rect2(5.0, 41.0, 150.0, 8.0), 4, MUTED)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.z_index = 10
	add_child(_instruction)

	var options_panel := _panel(Rect2(3.0, 56.0, 154.0, 160.0),
		Color(INK.r, INK.g, INK.b, 0.88), Color(CYAN.r, CYAN.g, CYAN.b, 0.42))
	options_panel.z_index = 5
	add_child(options_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "SacrificeOptionsScroll"
	scroll.position = Vector2(6.0, 59.0)
	scroll.size = Vector2(148.0, 154.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.z_index = 10
	add_child(scroll)
	_options = VBoxContainer.new()
	_options.name = "SacrificeOptions"
	_options.custom_minimum_size = Vector2(144.0, 0.0)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 3)
	scroll.add_child(_options)

	_selected = _label("", Rect2(5.0, 219.0, 150.0, 18.0), 4, HOT_GOLD)
	_selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_selected)
	_message = _label("", Rect2(5.0, 239.0, 150.0, 17.0), 4, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)

	_confirm = _button("CONFIRM SACRIFICE", Rect2(18.0, 260.0, 124.0, 21.0), 6)
	_confirm.name = "ConfirmSacrificeButton"
	_confirm.pressed.connect(_on_confirm_pressed)
	add_child(_confirm)
	_continue = _button("KEEP EVERYTHING", Rect2(25.0, 288.0, 110.0, 20.0), 5)
	_continue.name = "ContinueButton"
	_continue.pressed.connect(_on_continue_pressed)
	add_child(_continue)

func _refresh() -> void:
	var route_open := RunStateStore.routeDestination == RouteCards.ROUTE_SACRIFICE
	if _balance != null:
		_balance.text = "RUN COINS %d   NEURONS %d" % [
			int(RunStateStore.lucidityCoins), int(MetaStateStore.campaignNeuronsLeft)
		]
	if _progress != null:
		_progress.text = "SACRIFICES %d/%d" % [
			int(RunStateStore.sacrificeCount), SacrificeRules.MAX_USES
		]
		_instruction.text = "+%d RUN SPINS NEXT ROUND" % SacrificeRules.BONUS_SPINS
	if _options == null:
		return
	for child in _options.get_children():
		child.queue_free()
	if not route_open:
		_message.text = "SACRIFICE ROUTE CLOSED"
		_confirm.disabled = true
		_continue.disabled = true
		return

	var claimed := RunStateStore.sacrificeClaimed
	var maxed := int(RunStateStore.sacrificeCount) >= SacrificeRules.MAX_USES
	var choices := RunStateStore.sacrifice_options()
	if claimed:
		_selected.text = "OFFER ACCEPTED: %s" % _selected_option_name(
			String(RunStateStore.sacrificeSelectedId))
		_message.text = "+%d RUN SPINS ARE READY" % SacrificeRules.BONUS_SPINS
		_confirm.disabled = true
		_continue.disabled = false
		_continue.text = "RETURN TO MACHINE"
	elif maxed:
		_selected.text = "THE SACRIFICE DEBT IS CLOSED"
		_message.text = "THREE SACRIFICES MAXIMUM"
		_confirm.disabled = true
		_continue.disabled = false
		_continue.text = "CONTINUE"
	elif choices.is_empty():
		_selected.text = "NOTHING ELIGIBLE TO SACRIFICE"
		_message.text = "KEEP YOUR RESOURCES"
		_confirm.disabled = true
		_continue.disabled = false
		_continue.text = "CONTINUE"
	else:
		_selected.text = "SELECTED: %s" % _selected_option_name(_selected_option_id) \
			if not _selected_option_id.is_empty() else "SELECT ONE RESOURCE TO TRADE"
		_message.text = "CONFIRM THIS SACRIFICE" if not _selected_option_id.is_empty() else ""
		_confirm.disabled = _selected_option_id.is_empty()
		_continue.disabled = false
		_continue.text = "KEEP EVERYTHING"

	for option in choices:
		var option_id := String(option.get("id", ""))
		var row := _button("%s\n%s" % [String(option.get("name", "RESOURCE")),
			String(option.get("description", "SACRIFICE"))],
			Rect2(0.0, 0.0, 144.0, 28.0), 4)
		row.name = "Sacrifice_%s" % option_id.replace(":", "_")
		row.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.pressed.connect(_on_option_pressed.bind(option_id))
		row.modulate = HOT_GOLD if option_id == _selected_option_id else Color.WHITE
		_options.add_child(row)

func _selected_option_name(option_id: String) -> String:
	if option_id == SacrificeRules.OPTION_COINS:
		return "100 RUN COINS"
	if option_id == SacrificeRules.OPTION_NEURON:
		return "1 CAMPAIGN NEURON"
	if option_id.begins_with(SacrificeRules.OPTION_AUGMENT_PREFIX):
		var card_id := option_id.substr(SacrificeRules.OPTION_AUGMENT_PREFIX.length())
		return "AUGMENT / %s" % String(PacteCards.card(card_id).get("name", card_id))
	if option_id.begins_with(SacrificeRules.OPTION_POWER_PREFIX):
		var power_id := option_id.substr(SacrificeRules.OPTION_POWER_PREFIX.length())
		return "POWER / %s" % String(PacteCards.card(power_id).get("name", power_id.to_upper()))
	if option_id == "declined":
		return "NOTHING"
	return "RESOURCE"

func _on_option_pressed(option_id: String) -> void:
	if RunStateStore.sacrificeClaimed:
		return
	_selected_option_id = option_id
	_message.text = "CONFIRM THIS SACRIFICE"
	_refresh()

func _on_confirm_pressed() -> void:
	if _selected_option_id.is_empty():
		_message.text = "SELECT A RESOURCE FIRST"
		return
	if not RunStateStore.claim_sacrifice(_selected_option_id):
		_message.text = "SACRIFICE REFUSED"
		_refresh()
		return
	_selected_option_id = ""
	_refresh()

func _on_continue_pressed() -> void:
	if RunStateStore.sacrificeClaimed:
		_finish_route()
		return
	if not RunStateStore.refuse_sacrifice():
		_message.text = "MACHINE UNAVAILABLE"
		return
	_finish_route()

func _finish_route() -> void:
	if not RunStateStore.routeDestination.is_empty():
		if not RunStateStore.finish_route_destination():
			_message.text = "MACHINE UNAVAILABLE"
			return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _panel(rect: Rect2, background: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(background, border))
	return panel

func _label(text_value: String, rect: Rect2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", CYAN)
	button.add_theme_color_override("font_hover_color", HOT_GOLD)
	button.add_theme_color_override("font_pressed_color", HOT_GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_stylebox_override("normal", _style(Color(INK.r, INK.g, INK.b, 0.96), CYAN))
	button.add_theme_stylebox_override("hover", _style(Color(0.11, 0.06, 0.18, 0.98), HOT_GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color(0.18, 0.08, 0.20, 1.0), ROSE))
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.06, 0.11, 0.95), MUTED))
	return button

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.shadow_color = Color(border.r, border.g, border.b, 0.24)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style
