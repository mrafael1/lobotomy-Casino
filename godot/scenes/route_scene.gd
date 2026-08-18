extends Control

## Between-machine route selection. The dealer presents two deterministic route
## cards after each target or survivable loss. The player may also decline both
## cards and continue for free.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_RECTS: Array[Rect2] = [
	Rect2(5.0, 171.0, 73.0, 84.0),
	Rect2(82.0, 171.0, 73.0, 84.0),
]
const GOLD := Color(1.0, 0.84, 0.38)
const CYAN := Color(0.42, 1.0, 0.95)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)

var _font: FontFile = null
var _cards_layer: Control = null
var _gold_label: Label = null
var _message: Label = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = Assets.font()
	_build()
	_refresh()

func _build() -> void:
	var title := _label("THE DEALER OFFERS", Rect2(5.0, 7.0, 150.0, 14.0), 8, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 10
	add_child(title)
	_gold_label = _label("", Rect2(5.0, 24.0, 150.0, 12.0), 6, GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.z_index = 10
	add_child(_gold_label)
	var subtitle := _label("CHOOSE ONE OF TWO PATHS", Rect2(3.0, 36.0, 154.0, 9.0), 4, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.z_index = 10
	add_child(subtitle)

	_cards_layer = Control.new()
	_cards_layer.name = "RouteCards"
	_cards_layer.size = CANVAS_SIZE
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_layer.z_index = 10
	add_child(_cards_layer)

	_message = _label("", Rect2(5.0, 258.0, 150.0, 14.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.z_index = 10
	add_child(_message)
	var continue_button := _button("CONTINUE", Rect2(42.0, 278.0, 76.0, 20.0), 6)
	continue_button.name = "ContinueButton"
	continue_button.z_index = 20
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

func _refresh() -> void:
	for child in _cards_layer.get_children():
		child.queue_free()
	if not RunStateStore.routeOfferPending:
		_message.text = "ROUTE OFFER CLOSED"
		return
	_gold_label.text = "RUN LUCIDITY / GOLD: %d" % int(RunStateStore.lucidityCoins)
	var cards := RunStateStore.current_route_offer()
	for index in range(mini(RouteCards.OFFER_COUNT, cards.size())):
		var card := cards[index]
		var card_id := String(card.get("id", ""))
		var affordable := RunStateStore.route_card_affordable(card_id)
		var panel := Panel.new()
		panel.name = "RouteCard%d" % index
		panel.position = CARD_RECTS[index].position
		panel.size = CARD_RECTS[index].size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(
			GOLD if affordable else RED))
		_cards_layer.add_child(panel)
		var name_label := _label(String(card.get("displayName", "ROUTE")), \
			Rect2(4.0, 4.0, 65.0, 11.0), 5, GOLD, panel)
		var cost := RouteCards.card_cost(card)
		var cost_label := _label(("FREE" if cost <= 0 else "%dG" % cost) \
			+ (" / READY" if affordable else " / LOCKED"), \
			Rect2(4.0, 16.0, 65.0, 9.0), 4, CYAN if affordable else RED, panel)
		var description := _label(String(card.get("description", "")), \
			Rect2(4.0, 28.0, 65.0, 36.0), 4, MUTED, panel)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var button := _button("CHOOSE", Rect2(9.0, 66.0, 55.0, 13.0), 4, panel)
		button.name = "SelectButton"
		button.z_index = 20
		button.disabled = not affordable
		button.pressed.connect(_on_card_pressed.bind(card_id, index))
	_message.text = ""

func _on_card_pressed(card_id: String, card_index: int) -> void:
	if not RunStateStore.select_route(card_id):
		_message.text = "NOT ENOUGH GOLD / NO VALID CARD"
		_refresh()
		return
	match RunStateStore.routeDestination:
		RouteCards.ROUTE_SHOP:
			SceneNav.change_to("res://scenes/route_shop_scene.tscn",
				SceneNav.TransitionKind.DOOR, card_index)
		RouteCards.ROUTE_AUGMENT, RouteCards.ROUTE_POWER:
			SceneNav.change_to("res://scenes/route_build_scene.tscn",
				SceneNav.TransitionKind.DOOR, card_index)
		RouteCards.ROUTE_BONUS:
			SceneNav.change_to("res://scenes/route_bonus_scene.tscn",
				SceneNav.TransitionKind.DOOR, card_index)
		RouteCards.ROUTE_SACRIFICE:
			if RunStateStore.finish_route_destination():
				SceneNav.change_to("res://scenes/machine_scene.tscn",
					SceneNav.TransitionKind.DOOR, card_index)
			else:
				_message.text = "NEXT MACHINE UNAVAILABLE"
		_:
			_message.text = "ROUTE UNAVAILABLE"

func _on_continue_pressed() -> void:
	if not RunStateStore.refuse_routes():
		_message.text = "ROUTE OFFER UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn", SceneNav.TransitionKind.NORMAL)

func _label(text_value: String, rect: Rect2, size: int, color: Color, \
		parent: Node = null) -> Label:
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
	if parent != null:
		parent.add_child(label)
	return label

func _button(text_value: String, rect: Rect2, size: int, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	if _font != null:
		button.add_theme_font_override("font", _font)
	if parent != null:
		parent.add_child(button)
	return button
