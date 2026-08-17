extends Control

## Between-machine dealer choice. The dealer changes the two route doors when
## paid, and the selected door commits the route destination after confirmation.
## There is intentionally no back action once a door has been opened.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const DOOR_PATHS: Array[NodePath] = [
	NodePath("DoorChoices/DoorLeft"),
	NodePath("DoorChoices/DoorRight"),
]
const TITLE_TEXT_COLOR := Color(0.13, 0.125, 0.204)
const LUCIDITY_COLOR := Color(0.92, 0.86, 0.56)
const COIN_ASSET := "ui/coin.png"
const CREDITS_COIN_SIZE := Vector2(9.0, 9.0)
const PATH_PROMPT_RECT := Rect2(4.0, 249.0, 152.0, 12.0)
const MESSAGE_RECT := Rect2(4.0, 272.0, 152.0, 16.0)
const CONFIRM_MODAL_RECT := Rect2(12.0, 118.0, 136.0, 84.0)
const CONFIRM_BUTTON_SIZE := Vector2(54.0, 18.0)
const BUBBLE_TEXT_RECT := Rect2(104.0, 172.0, 37.0, 23.0)
const BUBBLE_TEXT_FONT_SIZE := 3
const GOLD := Color(1.0, 0.84, 0.38)
const CYAN := Color(0.42, 1.0, 0.95)
const RED := Color(1.0, 0.35, 0.42)
const BUBBLE_TEXT_COLOR := Color(0.96, 0.88, 0.77)
const DOOR_EXPLANATIONS := {
	RouteCards.ROUTE_SHOP: "I CAN TUNE\nTHE MACHINE.",
	RouteCards.ROUTE_AUGMENT: "PICK AN\nAUGMENT.",
	RouteCards.ROUTE_POWER: "PICK A\nPOWER.",
	RouteCards.ROUTE_BONUS: "TAKE 10G.\nFREE.",
	RouteCards.ROUTE_SACRIFICE: "KEEP SPINS.\nPAY LATER.",
}
const DOOR_COLORS := {
	RouteCards.ROUTE_SHOP: Color(1.0, 0.84, 0.38),
	RouteCards.ROUTE_AUGMENT: Color(0.42, 1.0, 0.95),
	RouteCards.ROUTE_POWER: Color(1.0, 0.42, 0.88),
	RouteCards.ROUTE_BONUS: Color(1.0, 0.91, 0.42),
	RouteCards.ROUTE_SACRIFICE: Color(0.67, 0.49, 1.0),
}
const DOOR_FRAMES := {
	RouteCards.ROUTE_SHOP: 0,
	RouteCards.ROUTE_AUGMENT: 1,
	RouteCards.ROUTE_POWER: 2,
	RouteCards.ROUTE_BONUS: 3,
	RouteCards.ROUTE_SACRIFICE: 4,
}

var _font: FontFile = null
var _reroll_art: Sprite2D = null
var _bubble_sprite: Sprite2D = null
var _bubble_label: Label = null
var _reroll_price: Label = null
var _message: Label = null
var _path_prompt: Label = null
var _reroll_button: Button = null
var _credits_row: HBoxContainer = null
var _credits_label: Label = null
var _credits_coin: TextureRect = null
var _door_buttons: Array[Button] = []
var _door_confirm_modal: Control = null
var _door_confirm_panel: Panel = null
var _door_confirm_route: Label = null
var _door_confirm_cost: Label = null
var _pending_door_index := -1
var _hovered_door_index := -1
var _selection_locked := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = Assets.font()
	_reroll_art = get_node_or_null("RerollArt") as Sprite2D
	_bubble_sprite = get_node_or_null("BubbleText") as Sprite2D
	_build_header()
	_build_credits_display()
	_build_bubble_text()
	_configure_doors()
	_configure_actions()
	if not Engine.is_editor_hint() \
			and not RunStateStore.state_changed.is_connected(_refresh):
		RunStateStore.state_changed.connect(_refresh)
	_refresh()

func _build_header() -> void:
	_path_prompt = _label("CHOOSE YOUR PATH", PATH_PROMPT_RECT, 5, CYAN)
	_path_prompt.name = "PathPrompt"
	_path_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_path_prompt.z_index = 20
	_message = _label("", MESSAGE_RECT, 4, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.z_index = 30
	_reroll_price = _label("", Rect2(2.0, 216.0, 48.0, 12.0), 6, GOLD)
	_reroll_price.name = "RerollPrice"
	_reroll_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reroll_price.z_index = 20

func _build_credits_display() -> void:
	_credits_row = HBoxContainer.new()
	_credits_row.name = "CreditsRow"
	_credits_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_credits_row.offset_left = 7.0
	_credits_row.offset_top = -20.0
	_credits_row.offset_right = 30.0
	_credits_row.offset_bottom = -8.0
	_credits_row.add_theme_constant_override("separation", 2)
	_credits_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_row.z_index = 20
	add_child(_credits_row)

	_credits_label = Label.new()
	_credits_label.name = "CreditsLabel"
	_credits_label.add_theme_font_size_override("font_size", 7)
	_credits_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _font != null:
		_credits_label.add_theme_font_override("font", _font)
	_credits_row.add_child(_credits_label)

	_credits_coin = TextureRect.new()
	_credits_coin.name = "Coin"
	_credits_coin.texture = Assets.texture(COIN_ASSET, true)
	_credits_coin.custom_minimum_size = CREDITS_COIN_SIZE
	_credits_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_credits_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_credits_coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_credits_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_credits_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_row.add_child(_credits_coin)

func _configure_doors() -> void:
	for index in DOOR_PATHS.size():
		var button := get_node_or_null(DOOR_PATHS[index]) as Button
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = ""
		button.flat = true
		button.tooltip_text = ""
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(_on_door_pressed.bind(index))
		button.mouse_entered.connect(_on_door_mouse_entered.bind(index))
		button.mouse_exited.connect(_on_door_mouse_exited.bind(index))
		var title := _label("", Rect2(1.0, 104.0, 62.0, 10.0), 4,
			TITLE_TEXT_COLOR, button)
		title.name = "DoorTitle"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.clip_text = true
		title.position.y += Assets.centered_text_nudge(4)
		var cost := _label("", Rect2(1.0, 114.0, 62.0, 9.0), 4, CYAN, button)
		cost.name = "DoorCost"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.position.y += Assets.centered_text_nudge(4)
		_door_buttons.append(button)

func _configure_actions() -> void:
	_reroll_button = get_node_or_null("RerollButton") as Button
	if _reroll_button != null:
		_reroll_button.text = ""
		_reroll_button.flat = true
		_reroll_button.focus_mode = Control.FOCUS_NONE
		_reroll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			_reroll_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_reroll_button.pressed.connect(_on_reroll_pressed)
		_reroll_button.button_down.connect(_on_reroll_button_down)
		_reroll_button.button_up.connect(_on_reroll_button_up)
		_set_reroll_art_frame(0)

func _refresh() -> void:
	var pending := bool(RunStateStore.routeOfferPending)
	if _credits_label != null:
		_credits_label.text = str(int(RunStateStore.lucidityCoins))
	var cards := RunStateStore.current_route_offer()
	for index in _door_buttons.size():
		var button := _door_buttons[index]
		if index >= cards.size() or not pending:
			button.visible = false
			continue
		button.visible = true
		_set_door_card(button, cards[index])
	if not pending:
		_hovered_door_index = -1
		_hide_door_explanation()
	elif _hovered_door_index >= 0 and _hovered_door_index < cards.size():
		_show_door_explanation(cards[_hovered_door_index])
	if _reroll_button != null:
		_reroll_button.visible = pending
		_reroll_button.disabled = _selection_locked or not \
			RunStateStore.route_offer_reroll_affordable()
	if _reroll_art != null:
		_reroll_art.visible = pending
	if _reroll_price != null:
		_reroll_price.visible = pending
		_reroll_price.text = "%dG" % RunStateStore.route_offer_reroll_price()
		_reroll_price.add_theme_color_override(&"font_color",
			GOLD if RunStateStore.route_offer_reroll_affordable() else RED)
	if not pending and _door_confirm_modal != null:
		_door_confirm_modal.visible = false
	if not pending and _message != null and _message.text == "":
		_message.text = "ROUTE OFFER CLOSED"

func _set_door_card(button: Button, card: Dictionary) -> void:
	var route_type := String(card.get("routeType", ""))
	var color: Color = DOOR_COLORS.get(route_type, CYAN)
	var affordable := RunStateStore.route_card_affordable(String(card.get("id", "")))
	var sprite := button.get_node_or_null("DoorSprite") as Sprite2D
	if sprite != null:
		sprite.frame = int(DOOR_FRAMES.get(route_type, 0))
		sprite.self_modulate = Color.WHITE if affordable else Color(0.55, 0.55, 0.64, 1.0)
	var title := button.get_node_or_null("DoorTitle") as Label
	if title != null:
		title.text = String(card.get("displayName", "ROUTE"))
		title.add_theme_color_override(&"font_color",
			TITLE_TEXT_COLOR if affordable else RED)
	var cost := button.get_node_or_null("DoorCost") as Label
	if cost != null:
		var price := int(card.get("lucidityCost", 0))
		cost.text = "FREE" if price <= 0 else "%dG" % price
		cost.add_theme_color_override(&"font_color", color if affordable else RED)
	# Route descriptions are intentionally not tooltips: Godot's default tooltip is a
	# large hover panel that obscures the authored door artwork on this tiny canvas.
	button.tooltip_text = ""
	button.disabled = _selection_locked or not affordable

func _on_door_pressed(index: int) -> void:
	if _selection_locked or index < 0 or index >= _door_buttons.size():
		return
	var cards := RunStateStore.current_route_offer()
	if index >= cards.size():
		return
	var card := cards[index]
	if not RunStateStore.route_card_affordable(String(card.get("id", ""))):
		return
	_hovered_door_index = -1
	_hide_door_explanation()
	_pending_door_index = index
	_selection_locked = true
	_set_interaction_locked(true)
	_show_door_confirmation(card)

func _show_door_confirmation(card: Dictionary) -> void:
	if _door_confirm_modal == null:
		_door_confirm_modal = _build_door_confirmation_modal()
	var route_type := String(card.get("routeType", ""))
	var route_color: Color = DOOR_COLORS.get(route_type, CYAN)
	if _door_confirm_panel != null:
		_door_confirm_panel.add_theme_stylebox_override("panel",
			ButtonKit.neon_panel_style(route_color))
	if _door_confirm_route != null:
		_door_confirm_route.text = String(card.get("displayName", "ROUTE"))
		_door_confirm_route.add_theme_color_override(&"font_color", route_color)
	if _door_confirm_cost != null:
		var price := int(card.get("lucidityCost", 0))
		_door_confirm_cost.text = "FREE" if price <= 0 else "COST: %dG" % price
	_door_confirm_modal.visible = true
	_door_confirm_modal.move_to_front()

func _build_door_confirmation_modal() -> Control:
	var modal := Control.new()
	modal.name = "DoorConfirmation"
	modal.position = Vector2.ZERO
	modal.size = CANVAS_SIZE
	modal.z_index = 200
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.66)
	dim.size = CANVAS_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)

	_door_confirm_panel = Panel.new()
	_door_confirm_panel.name = "Panel"
	_door_confirm_panel.position = CONFIRM_MODAL_RECT.position
	_door_confirm_panel.size = CONFIRM_MODAL_RECT.size
	_door_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_door_confirm_panel.add_theme_stylebox_override("panel",
		ButtonKit.neon_panel_style(CYAN))
	modal.add_child(_door_confirm_panel)

	var prompt := _label("ENTER THIS PATH?", Rect2(4.0, 7.0, 128.0, 12.0),
		6, Color(0.85, 0.95, 1.0), _door_confirm_panel)
	prompt.name = "Prompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var route := _label("ROUTE", Rect2(4.0, 22.0, 128.0, 13.0), 5, CYAN,
		_door_confirm_panel)
	route.name = "Route"
	route.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_door_confirm_route = route
	var cost := _label("", Rect2(4.0, 36.0, 128.0, 10.0), 4, GOLD,
		_door_confirm_panel)
	cost.name = "Cost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_door_confirm_cost = cost

	var cancel := _confirm_button(_door_confirm_panel, "CancelButton", "CANCEL",
		Vector2(10.0, 57.0), RED)
	cancel.pressed.connect(_cancel_door_confirmation)
	var confirm := _confirm_button(_door_confirm_panel, "ConfirmButton", "ENTER",
		Vector2(72.0, 57.0), CYAN)
	confirm.pressed.connect(_confirm_door_selection)
	modal.visible = false
	return modal

func _confirm_button(parent: Control, node_name: String, text_value: String,
		position_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	ButtonKit.small_neon_button_style(button, color, 5)
	parent.add_child(button)
	button.position = position_value
	button.size = CONFIRM_BUTTON_SIZE
	return button

func _cancel_door_confirmation() -> void:
	if _door_confirm_modal != null:
		_door_confirm_modal.visible = false
	_pending_door_index = -1
	_selection_locked = false
	_set_interaction_locked(false)
	_refresh()

func _confirm_door_selection() -> void:
	var index := _pending_door_index
	if index < 0 or index >= _door_buttons.size():
		_cancel_door_confirmation()
		return
	if _door_confirm_modal != null:
		_door_confirm_modal.visible = false
	_pending_door_index = -1
	var cards := RunStateStore.current_route_offer()
	if index >= cards.size():
		_selection_locked = false
		_set_interaction_locked(false)
		_message.text = "DOOR UNAVAILABLE"
		_refresh()
		return
	var card_id := String(cards[index].get("id", ""))
	if not RunStateStore.select_route(card_id):
		_selection_locked = false
		_set_interaction_locked(false)
		_message.text = "DOOR PAYMENT REFUSED"
		_refresh()
		return
	_open_destination()

func _on_reroll_pressed() -> void:
	if _selection_locked or not RunStateStore.routeOfferPending:
		return
	if not RunStateStore.reroll_route_offer():
		_message.text = "NOT ENOUGH GOLD"
		_refresh()
		return
	_refresh()
	_message.text = "DOORS CHANGED"

func _set_interaction_locked(locked: bool) -> void:
	for button in _door_buttons:
		button.disabled = locked
	if _reroll_button != null:
		_reroll_button.disabled = locked

func _open_destination() -> void:
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
				_selection_locked = false
				_set_interaction_locked(false)
				_message.text = "NEXT MACHINE UNAVAILABLE"
		_:
			_selection_locked = false
			_set_interaction_locked(false)
			_message.text = "DOOR UNAVAILABLE"

func _on_reroll_button_down() -> void:
	_set_reroll_art_frame(1)

func _on_reroll_button_up() -> void:
	_set_reroll_art_frame(0)

func _set_reroll_art_frame(frame: int) -> void:
	if _reroll_art == null or not is_instance_valid(_reroll_art):
		return
	_reroll_art.frame = clampi(frame, 0, maxi(0, _reroll_art.hframes - 1))

func _label(text_value: String, rect: Rect2, size: int, color: Color,
		parent: Node = null) -> Label:
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
	var owner := parent if parent != null else self
	owner.add_child(label)
	return label

func _build_bubble_text() -> void:
	_bubble_label = _label("", BUBBLE_TEXT_RECT, BUBBLE_TEXT_FONT_SIZE,
		BUBBLE_TEXT_COLOR)
	_bubble_label.name = "BubbleTextLabel"
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.clip_text = true
	_bubble_label.position.y += Assets.centered_text_nudge(BUBBLE_TEXT_FONT_SIZE)
	_bubble_label.z_index = 26
	_bubble_label.visible = false
	if _bubble_sprite != null:
		_bubble_sprite.visible = false

func _on_door_mouse_entered(index: int) -> void:
	if _selection_locked or not RunStateStore.routeOfferPending:
		return
	var cards := RunStateStore.current_route_offer()
	if index < 0 or index >= cards.size():
		return
	_hovered_door_index = index
	_show_door_explanation(cards[index])

func _on_door_mouse_exited(index: int) -> void:
	if _hovered_door_index != index:
		return
	_hovered_door_index = -1
	_hide_door_explanation()

func _show_door_explanation(card: Dictionary) -> void:
	if _bubble_label == null:
		return
	var route_type := String(card.get("routeType", ""))
	var fallback := String(card.get("description", ""))
	_bubble_label.text = String(DOOR_EXPLANATIONS.get(route_type, fallback))
	_bubble_label.visible = true
	if _bubble_sprite != null:
		_bubble_sprite.visible = true

func _hide_door_explanation() -> void:
	if _bubble_label != null:
		_bubble_label.text = ""
		_bubble_label.visible = false
	if _bubble_sprite != null:
		_bubble_sprite.visible = false
