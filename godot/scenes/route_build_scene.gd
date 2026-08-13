extends Control

## Single-deck between-machine build route. It deliberately shares Pacte card
## metadata and pricing, but never enters pacte_initial/pacte_threshold or asks
## for the other card type.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_RECTS: Array[Rect2] = [
	Rect2(5.0, 58.0, 150.0, 54.0),
	Rect2(5.0, 117.0, 150.0, 54.0),
	Rect2(5.0, 176.0, 150.0, 54.0),
]
const SYMBOL_PICKER_RECT := Rect2(4.0, 100.0, 152.0, 102.0)
const GOLD := Color(1.0, 0.84, 0.38)
const CYAN := Color(0.42, 1.0, 0.95)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)

var _font: FontFile = null
var _title: Label = null
var _gold_label: Label = null
var _message: Label = null
var _list: Control = null
var _pending_card_id := ""
var _symbol_picker: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = Assets.font()
	_build()
	_refresh()

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.025, 0.08, 1.0)
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_title = _label("BUILD ROUTE", Rect2(5.0, 7.0, 150.0, 14.0), 9, CYAN)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_gold_label = _label("", Rect2(5.0, 25.0, 150.0, 12.0), 7, GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_gold_label)
	var subtitle := _label("CHOOSE ONE CARD / NO SECOND DECK", \
			Rect2(5.0, 39.0, 150.0, 9.0), 5, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	_list = Control.new()
	_list.name = "RouteBuildCards"
	_list.size = CANVAS_SIZE
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	_message = _label("", Rect2(5.0, 238.0, 150.0, 18.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	var back := _button("BACK TO ROUTES", Rect2(20.0, 274.0, 120.0, 25.0), 7)
	back.name = "BackToRoutesButton"
	back.pressed.connect(_on_back_pressed)
	add_child(back)

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	if RunStateStore.routeDestination != RouteCards.ROUTE_AUGMENT \
			and RunStateStore.routeDestination != RouteCards.ROUTE_POWER:
		_message.text = "BUILD ROUTE CLOSED"
		return
	var kind := RunStateStore.routeDestination
	_title.text = "AUGMENT ROUTE" if kind == RouteCards.ROUTE_AUGMENT else "POWER ROUTE"
	_gold_label.text = "RUN LUCIDITY / GOLD: %d" % int(RunStateStore.lucidityCoins)
	var offer_ids := _offer_ids()
	for index in range(mini(offer_ids.size(), CARD_RECTS.size())):
		var card_id := offer_ids[index]
		var entry := PacteCards.card(card_id)
		var cost := RunStateStore.route_build_card_cost(card_id)
		var affordable := RunStateStore.route_build_card_affordable(card_id)
		var button := _button("", CARD_RECTS[index], 5)
		button.name = "BuildCard_%s" % card_id
		button.text = "%s  %s\n%s\n%s" % [
			String(entry.get("name", card_id)),
			("FREE" if cost <= 0 else "%dG" % cost),
			String(entry.get("description", "")),
			("LEFT: %dG" % RunStateStore.route_build_remaining_after(card_id))]
		button.disabled = not affordable
		button.add_theme_color_override("font_color", GOLD if affordable else RED)
		button.add_theme_color_override("font_hover_color", CYAN)
		button.pressed.connect(_on_card_pressed.bind(card_id))
		_list.add_child(button)
	_message.text = ""

func _offer_ids() -> Array[String]:
	var result: Array[String] = []
	if RunStateStore.routeBuildOfferIds is Array:
		for value in RunStateStore.routeBuildOfferIds as Array:
			result.append(PacteCards.normalise_card_id(String(value)))
	return result

func _on_card_pressed(card_id: String) -> void:
	if RunStateStore.route_build_card_requires_symbol(card_id):
		_show_symbol_picker(card_id)
		return
	_complete_card(card_id)

func _complete_card(card_id: String, reward_symbol := "") -> void:
	if not RunStateStore.complete_route_build_selection(card_id, reward_symbol):
		_message.text = "CARD PURCHASE REFUSED"
		_refresh()
		return
	if not RunStateStore.finish_route_destination():
		_message.text = "NEXT MACHINE UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _show_symbol_picker(card_id: String) -> void:
	if _symbol_picker != null:
		return
	_pending_card_id = card_id
	_symbol_picker = Control.new()
	_symbol_picker.name = "RouteRewardSymbolPicker"
	_symbol_picker.size = CANVAS_SIZE
	_symbol_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_symbol_picker.z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.size = CANVAS_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_symbol_picker.add_child(dim)
	add_child(_symbol_picker)
	var symbols: Array[String] = []
	for raw_symbol in Symbols.BASE_SYMBOL_CYCLE:
		var symbol_id := String(raw_symbol)
		if symbol_id != "flatline":
			symbols.append(symbol_id)
	SymbolPicker.build_symbol_picker_panel(_symbol_picker, symbols, "CHOOSE SYMBOL", \
			SYMBOL_PICKER_RECT, Callable(self, "_on_symbol_picked"), \
			Callable(self, "_cancel_symbol_picker"), true, true, false)

func _on_symbol_picked(symbol_id: String) -> void:
	var card_id := _pending_card_id
	_cancel_symbol_picker()
	_complete_card(card_id, symbol_id)

func _cancel_symbol_picker() -> void:
	_pending_card_id = ""
	if _symbol_picker != null:
		_symbol_picker.queue_free()
	_symbol_picker = null

func _on_back_pressed() -> void:
	if _symbol_picker != null:
		return
	if not RunStateStore.cancel_route_destination():
		_message.text = "ROUTE OFFER UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/route_scene.tscn")

func _label(text_value: String, rect: Rect2, size: int, color: Color, \
		parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	if _font != null:
		label.add_theme_font_override("font", _font)
	if parent != null:
		parent.add_child(label)
	return label

func _button(text_value: String, rect: Rect2, size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	if _font != null:
		button.add_theme_font_override("font", _font)
	return button
