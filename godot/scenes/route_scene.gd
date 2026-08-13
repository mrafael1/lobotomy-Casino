extends Control

## Between-machine route selection. The store owns the offer and payment; this
## scene only renders three deterministic cards and a free refusal action.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_RECTS: Array[Rect2] = [
	Rect2(5.0, 54.0, 150.0, 58.0),
	Rect2(5.0, 121.0, 150.0, 58.0),
	Rect2(5.0, 188.0, 150.0, 58.0),
]
const GOLD := Color(1.0, 0.84, 0.38)
const CYAN := Color(0.42, 1.0, 0.95)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)

var _font: FontFile = null
var _cards_layer: Control = null
var _gold_label: Label = null
var _message: Label = null
var _buttons: Array[Button] = []
var _refuse_button: Button = null

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
	var subtitle := _label("CHOOSE ONE INVESTMENT  /  OR CONTINUE FREE", Rect2(5.0, 36.0, 150.0, 9.0), 4, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	_cards_layer = Control.new()
	_cards_layer.name = "RouteCards"
	_cards_layer.size = CANVAS_SIZE
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards_layer)

	_message = _label("", Rect2(5.0, 250.0, 150.0, 17.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_refuse_button = _button("CONTINUE FREE", Rect2(29.0, 276.0, 102.0, 25.0), 7)
	_refuse_button.name = "ContinueFreeButton"
	_refuse_button.pressed.connect(_on_refuse_pressed)
	add_child(_refuse_button)

func _refresh() -> void:
	for child in _cards_layer.get_children():
		child.queue_free()
	_buttons.clear()
	if not RunStateStore.routeOfferPending:
		_message.text = "ROUTE OFFER CLOSED"
		_refuse_button.disabled = true
		return
	_gold_label.text = "RUN LUCIDITY / GOLD: %d" % int(RunStateStore.lucidityCoins)
	for index in range(mini(RouteCards.OFFER_COUNT, RunStateStore.current_route_offer().size())):
		var card := RunStateStore.current_route_offer()[index]
		var panel := Panel.new()
		panel.name = "RouteCard%d" % index
		panel.position = CARD_RECTS[index].position
		panel.size = CARD_RECTS[index].size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(
			GOLD if RunStateStore.route_card_affordable(String(card.get("id", ""))) else RED))
		_cards_layer.add_child(panel)
		var name_label := _label(String(card.get("displayName", "ROUTE")),
			Rect2(4.0, 4.0, 80.0, 10.0), 7, GOLD, panel)
		var cost := int(card.get("lucidityCost", 0))
		var affordable := RunStateStore.route_card_affordable(String(card.get("id", "")))
		var cost_label := _label(("FREE" if cost <= 0 else "%d GOLD" % cost) \
				+ ("  /  READY" if affordable else "  /  TOO EXPENSIVE"),
			Rect2(88.0, 4.0, 58.0, 10.0), 5, CYAN if affordable else RED, panel)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var description := _label(String(card.get("description", "")),
			Rect2(4.0, 18.0, 142.0, 30.0), 5, MUTED, panel)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var button := _button("SELECT", Rect2(112.0, 38.0, 34.0, 15.0), 5, panel)
		button.name = "SelectButton"
		button.disabled = not affordable
		button.pressed.connect(_on_card_pressed.bind(String(card.get("id", ""))))
		_buttons.append(button)
	_message.text = ""
	_refuse_button.disabled = false

func _on_card_pressed(card_id: String) -> void:
	if not RunStateStore.select_route(card_id):
		_message.text = "NOT ENOUGH GOLD"
		_refresh()
		return
	var route_type := RunStateStore.routeDestination
	match route_type:
		RouteCards.ROUTE_PACTE:
			SceneNav.change_to("res://scenes/pacte_scene.tscn")
		RouteCards.ROUTE_SHOP:
			SceneNav.change_to("res://scenes/route_shop_scene.tscn")
		RouteCards.ROUTE_DEALER:
			SceneNav.change_to("res://scenes/route_dealer_scene.tscn")
		_:
			_message.text = "ROUTE UNAVAILABLE"

func _on_refuse_pressed() -> void:
	if not RunStateStore.refuse_routes():
		_message.text = "ROUTE OFFER CLOSED"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _label(text_value: String, rect: Rect2, size: int, color: Color,
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
