extends Control

## Between-machine route selection. The five choices are the only end-of-segment
## destinations: Shop, a single augment, a single power, Bonus, or Sacrifice Later.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_RECTS: Array[Rect2] = [
	Rect2(5.0, 49.0, 150.0, 42.0),
	Rect2(5.0, 94.0, 150.0, 42.0),
	Rect2(5.0, 139.0, 150.0, 42.0),
	Rect2(5.0, 184.0, 150.0, 42.0),
	Rect2(5.0, 229.0, 150.0, 42.0),
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
	var background := ColorRect.new()
	background.color = Color(0.035, 0.025, 0.08, 1.0)
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := _label("ROUTE / NEXT MACHINE", Rect2(5.0, 7.0, 150.0, 14.0), 9, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_gold_label = _label("", Rect2(5.0, 24.0, 150.0, 12.0), 7, GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_gold_label)
	var subtitle := _label("SHOP / AUGMENT / POWER / BONUS / SACRIFICE", \
			Rect2(3.0, 36.0, 154.0, 9.0), 4, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	_cards_layer = Control.new()
	_cards_layer.name = "RouteCards"
	_cards_layer.size = CANVAS_SIZE
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards_layer)

	_message = _label("", Rect2(5.0, 278.0, 150.0, 18.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)

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
				Rect2(4.0, 3.0, 103.0, 10.0), 6, GOLD, panel)
		var cost := int(card.get("lucidityCost", 0))
		var cost_label := _label(("FREE" if cost <= 0 else "%dG" % cost) \
				+ (" / READY" if affordable else " / LOCKED"), \
				Rect2(104.0, 3.0, 42.0, 10.0), 5, CYAN if affordable else RED, panel)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var description := _label(String(card.get("description", "")), \
				Rect2(4.0, 16.0, 105.0, 22.0), 4, MUTED, panel)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var button := _button("CHOOSE", Rect2(112.0, 24.0, 34.0, 14.0), 4, panel)
		button.name = "SelectButton"
		button.disabled = not affordable
		button.pressed.connect(_on_card_pressed.bind(card_id))
	_message.text = ""

func _on_card_pressed(card_id: String) -> void:
	if not RunStateStore.select_route(card_id):
		_message.text = "NOT ENOUGH GOLD / NO VALID CARD"
		_refresh()
		return
	match RunStateStore.routeDestination:
		RouteCards.ROUTE_SHOP:
			SceneNav.change_to("res://scenes/route_shop_scene.tscn")
		RouteCards.ROUTE_AUGMENT, RouteCards.ROUTE_POWER:
			SceneNav.change_to("res://scenes/route_build_scene.tscn")
		RouteCards.ROUTE_BONUS:
			SceneNav.change_to("res://scenes/route_bonus_scene.tscn")
		RouteCards.ROUTE_SACRIFICE:
			if RunStateStore.finish_route_destination():
				SceneNav.change_to("res://scenes/machine_scene.tscn")
			else:
				_message.text = "NEXT MACHINE UNAVAILABLE"
		_:
			_message.text = "ROUTE UNAVAILABLE"

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
