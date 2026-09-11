extends Control

## Single-deck between-machine build route. It uses Pacte's authored room and
## card presentation, but keeps route pricing and selection state local to this
## scene so a route never reopens the full run-start ritual. The dealer door was
## already chosen before this scene opens, so this scene has no route-selection exit.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_SIZE := Vector2(39.0, 61.0)
const CARD_POSITIONS: Array[Vector2] = [
	Vector2(7.0, 148.0), Vector2(61.0, 148.0), Vector2(114.0, 148.0),
]
const AUGMENT_DROP_RECT := Rect2(25.0, 219.0, 25.0, 35.0)
const POWER_DROP_RECT := Rect2(110.0, 219.0, 25.0, 35.0)
const CHOSEN_CARD_SIZE := Vector2(21.0, 33.0)
const SELECTION_PREVIEW_TIME := 0.24
const SYMBOL_PICKER_RECT := Rect2(4.0, 100.0, 152.0, 102.0)
const DESCRIPTION_BUBBLE_RECT := Rect2(5.0, 145.0, 50.0, 28.0)
const DESCRIPTION_TITLE_RECT := Rect2(2.0, 3.0, 46.0, 7.0)
const DESCRIPTION_TEXT_RECT := Rect2(3.0, 10.0, 44.0, 16.0)
const DESCRIPTION_TITLE_FONT_SIZE := 4
const DESCRIPTION_FONT_SIZE := 3
const DESCRIPTION_BUBBLE_GAP := 1.0
const DRAG_SLOP := 4.0
const INSTRUCTION_RECT := Rect2(5.0, 247.0, 150.0, 9.0)
const MESSAGE_RECT := Rect2(5.0, 247.0, 150.0, 9.0)
const LUCIDITY_COLOR := Color(0.92, 0.86, 0.56)
const COIN_ASSET := "ui/coin.png"
const CREDITS_COIN_SIZE := Vector2(9.0, 9.0)
const CARD_COST_FONT_SIZE := 7
const CARD_COST_COIN_SIZE := Vector2(8.0, 8.0)
# Keep the build row still at rest. A serialized sweep gives the cards a
# readable interaction cue without making every card pulse continuously.
const CARD_GLINT_DELAY := 3.20
const CARD_GLINT_DURATION := 0.42
const CARD_GLINT_ALPHA := 0.72
const CARD_GLINT_START_X := -42.0
const CARD_GLINT_END_X := 42.0
const POWER_REPLACEMENT_PICKER_SCRIPT := preload("res://scenes/power_replacement_picker.gd")

const GOLD := Color(1.0, 0.84, 0.38)
const TEXT_COLOR := Color(0.88, 0.98, 1.0)
const RED := Color(1.0, 0.35, 0.42)

var _font: FontFile = null
var _instruction: Label = null
var _message: Label = null
var _credits_row: HBoxContainer = null
var _credits_label: Label = null
var _credits_coin: TextureRect = null
var _list: Control = null
var _chosen_cards_layer: Control = null
var _chosen_card_view: Control = null
var _description_bubble: Panel = null
var _description_title: Label = null
var _description_text: Label = null
var _pacte_artwork: Control = null

var _card_buttons: Dictionary = {}
var _offer_ids: Array[String] = []
var _pool_kind := "augment"
var _preview_id := ""
var _pending_card_id := ""
var _symbol_picker: Control = null
var _power_replacement_picker: Variant = null
var _selection_locked := false
var _dragging := false
var _drag_id := ""
var _drag_index := -1
var _drag_origin := Vector2.ZERO
var _press_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_origin_z := 0
var _card_glint_cycle_tween: Tween = null
var _card_glint_sweep_tween: Tween = null
var _card_glint_index := 0
var _card_glint_generation := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_native_canvas()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_pacte_artwork = get_node_or_null("PacteArtwork") as Control
	_configure_pacte_artwork()
	_font = Assets.font()
	_build()
	_refresh()
	call_deferred("_restore_power_replacement")

func _on_viewport_size_changed() -> void:
	_center_native_canvas()

func _center_native_canvas() -> void:
	var viewport_size := get_viewport_rect().size
	var extra_size := viewport_size - CANVAS_SIZE
	position = Vector2(maxf(0.0, extra_size.x * 0.5),
		maxf(0.0, extra_size.y * 0.5))

func _configure_pacte_artwork() -> void:
	if _pacte_artwork == null:
		return
	if RunStateStore.routeDestination == RouteCards.ROUTE_AUGMENT:
		_pool_kind = "augment"
	elif RunStateStore.routeDestination == RouteCards.ROUTE_POWER:
		_pool_kind = "power"
	else:
		_pool_kind = ""
	_pacte_artwork.call("configure_route_artwork", _pool_kind)
	_pacte_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	# The authored OPEN sign identifies this destination. Keep the top panel clear
	# instead of adding a duplicate destination title over the room art.

	_list = Control.new()
	_list.name = "RouteBuildCards"
	_list.size = CANVAS_SIZE
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.z_index = 20
	add_child(_list)

	_chosen_cards_layer = Control.new()
	_chosen_cards_layer.name = "ChosenCardInSlot"
	_chosen_cards_layer.size = CANVAS_SIZE
	_chosen_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chosen_cards_layer.z_index = 25
	add_child(_chosen_cards_layer)

	_description_bubble = Panel.new()
	_description_bubble.name = "RouteCardDescriptionBubble"
	_description_bubble.position = DESCRIPTION_BUBBLE_RECT.position
	_description_bubble.size = DESCRIPTION_BUBBLE_RECT.size
	_description_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_bubble.z_index = 30
	_description_bubble.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(GOLD))
	add_child(_description_bubble)
	_description_title = _label("", DESCRIPTION_TITLE_RECT, DESCRIPTION_TITLE_FONT_SIZE,
		GOLD, _description_bubble)
	_description_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_title.clip_text = true
	_description_text = _label("", DESCRIPTION_TEXT_RECT, DESCRIPTION_FONT_SIZE,
		TEXT_COLOR, _description_bubble)
	_description_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_text.clip_text = true
	_description_bubble.visible = false

	_instruction = _label("TAP TO INSPECT  /  DRAG TO THE SLOT",
		INSTRUCTION_RECT, 5, TEXT_COLOR)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message = _label("", MESSAGE_RECT, 4, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	_set_instruction_text("SELECTED DOOR CANNOT BE REOPENED")
	_build_credits_display()

func _refresh() -> void:
	_clear_cards()
	_clear_selected_card()
	if _pool_kind != "augment" and _pool_kind != "power":
		_credits_label.text = ""
		_set_message_text("BUILD ROUTE CLOSED")
		return
	_credits_label.text = str(int(RunStateStore.lucidityCoins))
	_set_instruction_text("TAP TO INSPECT  /  DRAG TO THE SLOT")
	_set_drop_hint_visible(false)
	var offer_ids := _offer_ids_from_store()
	for index in range(mini(offer_ids.size(), CARD_POSITIONS.size())):
		_build_card(offer_ids[index], index)
	_offer_ids = offer_ids
	_start_card_glint_cycle()

func _offer_ids_from_store() -> Array[String]:
	var result: Array[String] = []
	if RunStateStore.routeBuildOfferIds is Array:
		for value in RunStateStore.routeBuildOfferIds as Array:
			result.append(PacteCards.normalise_card_id(String(value)))
	return result

func _build_card(card_id: String, index: int) -> void:
	var button := Button.new()
	button.name = "BuildCard_%s" % card_id
	button.position = CARD_POSITIONS[index]
	button.size = CARD_SIZE
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 5
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.gui_input.connect(_on_card_gui_input.bind(card_id, index, button))
	_list.add_child(button)
	_card_buttons[card_id] = button

	var card_view: Control = null
	if _pacte_artwork != null:
		card_view = _pacte_artwork.call("make_route_card_view", card_id, _pool_kind) as Control
	if card_view != null:
		button.add_child(card_view)

	var cost := RunStateStore.route_build_card_cost(card_id)
	var affordable := RunStateStore.route_build_card_affordable(card_id)
	_build_card_cost(button, cost, affordable)
	if card_view != null and not affordable:
		card_view.modulate = Color(0.62, 0.62, 0.72, 1.0)

func _build_card_cost(button: Button, cost: int, affordable: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "CardCost"
	row.position = Vector2(0.0, CARD_SIZE.y + 1.0)
	row.size = Vector2(CARD_SIZE.x, 10.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.z_index = 6
	button.add_child(row)

	var amount := Label.new()
	amount.name = "Amount"
	amount.text = "FREE" if cost <= 0 else str(cost)
	amount.add_theme_font_size_override("font_size", CARD_COST_FONT_SIZE)
	amount.add_theme_color_override("font_color", GOLD if affordable else RED)
	amount.add_theme_color_override("font_outline_color", Color.BLACK)
	amount.add_theme_constant_override("outline_size", 1)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		amount.add_theme_font_override("font", _font)
	row.add_child(amount)

	if cost <= 0:
		return
	var coin := TextureRect.new()
	coin.name = "Coin"
	coin.texture = Assets.texture(COIN_ASSET, true)
	coin.custom_minimum_size = CARD_COST_COIN_SIZE
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.set_meta("skip_drag_shadow", true)
	row.add_child(coin)

func _start_card_glint_cycle() -> void:
	_stop_card_glint_cycle()
	if _offer_ids.is_empty():
		return
	var generation := _card_glint_generation
	_card_glint_index = 0
	var cycle := create_tween().set_loops()
	cycle.tween_interval(CARD_GLINT_DELAY)
	cycle.tween_callback(_play_next_card_glint.bind(generation))
	cycle.tween_interval(CARD_GLINT_DURATION)
	_card_glint_cycle_tween = cycle

func _play_next_card_glint(generation: int) -> void:
	if generation != _card_glint_generation or _offer_ids.is_empty():
		return
	var offer_count := _offer_ids.size()
	for _attempt in offer_count:
		var index := _card_glint_index % offer_count
		_card_glint_index = (_card_glint_index + 1) % offer_count
		var card_id := _offer_ids[index]
		var button := _card_buttons.get(card_id, null) as Button
		if button == null:
			continue
		var card_view := button.get_node_or_null("CardArt") as Control
		if card_view != null:
			_play_card_glint(card_view)
		return

func _play_card_glint(card_view: Control) -> void:
	var glint := card_view.get_node_or_null("GoldGlint") as Polygon2D
	if glint == null:
		return
	if _card_glint_sweep_tween != null and _card_glint_sweep_tween.is_valid():
		_card_glint_sweep_tween.kill()
	glint.position = Vector2(CARD_GLINT_START_X, 0.0)
	glint.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)
	var sweep := create_tween()
	sweep.tween_property(glint, "color:a", CARD_GLINT_ALPHA, 0.04)
	sweep.parallel().tween_property(glint, "position:x", CARD_GLINT_END_X,
		CARD_GLINT_DURATION)
	sweep.tween_property(glint, "color:a", 0.0, 0.10)
	_card_glint_sweep_tween = sweep

func _stop_card_glint_cycle() -> void:
	_card_glint_generation += 1
	if _card_glint_cycle_tween != null and _card_glint_cycle_tween.is_valid():
		_card_glint_cycle_tween.kill()
	_card_glint_cycle_tween = null
	if _card_glint_sweep_tween != null and _card_glint_sweep_tween.is_valid():
		_card_glint_sweep_tween.kill()
	_card_glint_sweep_tween = null
	if _list == null:
		return
	for child in _list.get_children():
		var button := child as Button
		if button == null:
			continue
		var card_view := button.get_node_or_null("CardArt") as Control
		if card_view == null:
			continue
		var glint := card_view.get_node_or_null("GoldGlint") as Polygon2D
		if glint != null:
			glint.position = Vector2.ZERO
			glint.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)

func _on_card_gui_input(event: InputEvent, card_id: String, index: int,
		button: Button) -> void:
	if _selection_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(card_id, index, button, get_global_mouse_position())
	elif event is InputEventScreenTouch and event.index == 0 and event.pressed:
		var touch_event := event as InputEventScreenTouch
		_begin_drag(card_id, index, button, button.get_global_transform() * touch_event.position)

func _input(event: InputEvent) -> void:
	if SceneNav.is_transition_active():
		return
	if _drag_id == "":
		return
	if event is InputEventMouseMotion:
		_update_drag(get_global_mouse_position())
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0:
		var drag_event := event as InputEventScreenDrag
		_update_drag(_input_canvas_position(drag_event.position))
	elif event is InputEventScreenTouch and event.index == 0 and not event.pressed:
		var release_event := event as InputEventScreenTouch
		_finish_drag(_input_canvas_position(release_event.position))
		get_viewport().set_input_as_handled()

func _begin_drag(card_id: String, index: int, button: Button,
		global_position: Vector2) -> void:
	_press_position = global_position
	_drag_origin = button.position
	_drag_origin_z = button.z_index
	button.z_index = 30
	button.move_to_front()
	var parent := button.get_parent() as CanvasItem
	var parent_position := global_position
	if parent != null:
		parent_position = parent.get_global_transform().affine_inverse() * global_position
	_drag_offset = parent_position - button.position
	_drag_id = card_id
	_drag_index = index
	_dragging = false

func _update_drag(global_position: Vector2) -> void:
	var button := _card_buttons.get(_drag_id, null) as Button
	if button == null:
		return
	if not _dragging and global_position.distance_to(_press_position) <= DRAG_SLOP:
		return
	if not _dragging:
		DragShadow.add_drag_shadow(button)
	_dragging = true
	_description_bubble.visible = false
	_set_instruction_text("DROP THE CARD IN THE SLOT")
	_set_drop_hint_visible(true)
	button.position = _clamp_drag_position(button, _global_to_local(global_position) - _drag_offset)

func _finish_drag(global_position: Vector2) -> void:
	var card_id := _drag_id
	var button := _card_buttons.get(card_id, null) as Button
	var local_position: Vector2 = _global_to_local(global_position)
	var dragged_card_position := button.position if button != null else local_position - _drag_offset
	var was_dragging := _dragging
	_dragging = false
	_drag_id = ""
	_drag_index = -1
	_set_drop_hint_visible(false)
	if button == null:
		return
	DragShadow.remove_drag_shadow(button)
	button.position = _drag_origin
	button.z_index = _drag_origin_z
	if not was_dragging:
		_preview_card(card_id)
		return
	_description_bubble.visible = false
	var drop_rect := AUGMENT_DROP_RECT if _pool_kind == "augment" else POWER_DROP_RECT
	var dragged_rect := Rect2(dragged_card_position, CARD_SIZE)
	var drop_area := drop_rect.grow(4.0)
	if drop_area.intersects(dragged_rect) or drop_area.has_point(local_position):
		_accept_card(card_id)
	else:
		_set_instruction_text("TAP TO INSPECT  /  DRAG TO THE SLOT")

func _global_to_local(global_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_position

func _input_canvas_position(viewport_position: Vector2) -> Vector2:
	# Drag helpers consume global canvas coordinates. The route build shares Pacte's
	# expanded-phone layout, so converting through this Control would subtract its
	# centering offset twice.
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position

func _clamp_drag_position(button: Control, desired_position: Vector2) -> Vector2:
	var scale := Vector2(absf(button.scale.x), absf(button.scale.y))
	var visual_size := button.size * scale
	var pivot_offset := button.pivot_offset * (scale - Vector2.ONE)
	var minimum := pivot_offset
	var maximum := CANVAS_SIZE - visual_size + pivot_offset
	return Vector2(
		clampf(desired_position.x, minimum.x, maximum.x),
		clampf(desired_position.y, minimum.y, maximum.y))

func _set_drop_hint_visible(visible: bool) -> void:
	if _pacte_artwork != null:
		_pacte_artwork.call("set_route_emplacement_frame", _pool_kind, visible)

func _preview_card(card_id: String) -> void:
	if _selection_locked or not _offer_ids.has(card_id):
		return
	_preview_id = card_id
	var entry := PacteCards.card(card_id)
	_description_bubble.visible = true
	_description_title.text = String(entry.get("name", card_id))
	var cost := RunStateStore.route_build_card_cost(card_id)
	var remaining := RunStateStore.route_build_remaining_after(card_id)
	_description_text.text = String(entry.get("description", "")) + \
		"\nCOST: %s  LEFT: %d\n%s" % [
			("FREE" if cost <= 0 else str(cost)), remaining,
			("FREE LOSS ROUTE" if cost <= 0 else RunStateStore.run_price_label())]
	_layout_description()
	_set_instruction_text("DRAG TO THE SLOT")
	for id in _offer_ids:
		var candidate := _card_buttons.get(id, null) as Button
		if candidate != null:
			candidate.scale = Vector2.ONE * (1.08 if id == card_id else 1.0)
			candidate.pivot_offset = CARD_SIZE * 0.5
	_position_description_bubble(card_id)

func _layout_description() -> void:
	var title_h := DESCRIPTION_TITLE_RECT.size.y
	var max_body_h := DESCRIPTION_BUBBLE_RECT.size.y - title_h - 2.0
	_description_title.size = DESCRIPTION_TITLE_RECT.size
	_description_text.size = Vector2(DESCRIPTION_TEXT_RECT.size.x, max_body_h)
	var font := _description_text.get_theme_font(&"font")
	var row_h := font.get_height(DESCRIPTION_FONT_SIZE) \
		+ float(_description_text.get_theme_constant(&"line_spacing"))
	var body_h := minf(max_body_h, float(maxi(1, _description_text.get_line_count())) * row_h)
	var top := roundf((DESCRIPTION_BUBBLE_RECT.size.y - (title_h + body_h)) * 0.5)
	_description_title.position = Vector2(DESCRIPTION_TITLE_RECT.position.x, top)
	_description_text.position = Vector2(DESCRIPTION_TEXT_RECT.position.x, top + title_h)
	_description_text.size = Vector2(DESCRIPTION_TEXT_RECT.size.x, body_h)

func _position_description_bubble(card_id: String) -> void:
	var button := _card_buttons.get(card_id, null) as Button
	if button == null:
		_description_bubble.position = DESCRIPTION_BUBBLE_RECT.position
		return
	var scale := Vector2(absf(button.scale.x), absf(button.scale.y))
	var visual_top_left := button.position - button.pivot_offset * (scale - Vector2.ONE)
	var visual_size := button.size * scale
	var desired := Vector2(
		visual_top_left.x + (visual_size.x - DESCRIPTION_BUBBLE_RECT.size.x) * 0.5,
		visual_top_left.y - DESCRIPTION_BUBBLE_RECT.size.y - DESCRIPTION_BUBBLE_GAP)
	var maximum := CANVAS_SIZE - DESCRIPTION_BUBBLE_RECT.size
	_description_bubble.position = Vector2(
		clampf(desired.x, 0.0, maximum.x), clampf(desired.y, 0.0, maximum.y))

func _accept_card(card_id: String) -> void:
	if _selection_locked:
		return
	if not RunStateStore.route_build_card_affordable(card_id):
		_set_message_text("NOT ENOUGH LUCIDITY FOR THIS CARD")
		return
	_selection_locked = true
	_pending_card_id = card_id
	_description_bubble.visible = false
	_set_instruction_text("CARD SELECTED")
	_show_selected_card(card_id)
	for value in _card_buttons.values():
		var card_button := value as Button
		if card_button != null:
			card_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _pool_kind == "power" and RunStateStore.power_requires_replacement(card_id):
		if not RunStateStore.begin_power_replacement(card_id, "route_build"):
			_selection_locked = false
			_set_message_text("POWER REPLACEMENT UNAVAILABLE")
			return
		_show_power_replacement_picker()
		return
	if RunStateStore.route_build_card_requires_symbol(card_id):
		_show_symbol_picker(card_id)
	else:
		_complete_after_preview(card_id)

func _complete_after_preview(card_id: String, reward_symbol := "") -> void:
	await get_tree().create_timer(SELECTION_PREVIEW_TIME).timeout
	if not is_inside_tree():
		return
	_complete_card(card_id, reward_symbol)

func _complete_card(card_id: String, reward_symbol := "", replacement_power_id := "") -> void:
	if not RunStateStore.complete_route_build_selection(card_id, reward_symbol,
			replacement_power_id):
		_selection_locked = false
		_pending_card_id = ""
		_clear_selected_card()
		_set_message_text("CARD PURCHASE REFUSED")
		_refresh()
		return
	if not RunStateStore.finish_route_destination():
		_selection_locked = false
		_set_message_text("NEXT MACHINE UNAVAILABLE")
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _restore_power_replacement() -> void:
	if _pool_kind != "power" or RunStateStore.pendingPowerReplacement.is_empty():
		return
	var candidate := String(RunStateStore.pendingPowerReplacement.get("cardId", ""))
	if candidate == "" or not _offer_ids.has(candidate):
		RunStateStore.cancel_power_replacement()
		return
	_selection_locked = true
	_pending_card_id = candidate
	_set_instruction_text("CHOOSE A POWER TO REMOVE")
	_show_selected_card(candidate)
	for value in _card_buttons.values():
		var card_button := value as Button
		if card_button != null:
			card_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_power_replacement_picker()

func _show_power_replacement_picker() -> void:
	if _power_replacement_picker != null and is_instance_valid(_power_replacement_picker):
		return
	_power_replacement_picker = POWER_REPLACEMENT_PICKER_SCRIPT.new()
	add_child(_power_replacement_picker)
	_power_replacement_picker.power_selected.connect(_on_power_replacement_selected)
	_power_replacement_picker.cancelled.connect(_cancel_power_replacement)
	_power_replacement_picker.present(
		String(RunStateStore.pendingPowerReplacement.get("cardId", "")),
		RunStateStore.power_replacement_options())

func _on_power_replacement_selected(removed_power_id: String) -> void:
	var candidate := String(RunStateStore.pendingPowerReplacement.get("cardId", ""))
	if _power_replacement_picker != null:
		_power_replacement_picker.queue_free()
		_power_replacement_picker = null
	if candidate == "":
		_cancel_power_replacement()
		return
	_complete_card(candidate, "", removed_power_id)

func _cancel_power_replacement() -> void:
	RunStateStore.cancel_power_replacement()
	_selection_locked = false
	_pending_card_id = ""
	_clear_selected_card()
	_set_instruction_text("TAP TO INSPECT  /  DRAG TO THE SLOT")
	for value in _card_buttons.values():
		var card_button := value as Button
		if card_button != null:
			card_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _show_selected_card(card_id: String) -> void:
	_clear_selected_card()
	if _chosen_cards_layer == null or _pacte_artwork == null:
		return
	_chosen_card_view = _pacte_artwork.call(
		"make_route_selected_card_view", card_id, _pool_kind) as Control
	if _chosen_card_view == null:
		return
	_chosen_card_view.name = "Selected%sCard" % _pool_kind.capitalize()
	var drop_rect := AUGMENT_DROP_RECT if _pool_kind == "augment" else POWER_DROP_RECT
	_chosen_card_view.position = drop_rect.position + \
		(drop_rect.size - CHOSEN_CARD_SIZE) * 0.5
	_chosen_cards_layer.add_child(_chosen_card_view)

func _clear_selected_card() -> void:
	if _chosen_card_view != null and is_instance_valid(_chosen_card_view):
		_chosen_card_view.queue_free()
	_chosen_card_view = null

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
	SymbolPicker.build_symbol_picker_panel(_symbol_picker, symbols, "CHOOSE SYMBOL",
		SYMBOL_PICKER_RECT, Callable(self, "_on_symbol_picked"),
		Callable(self, "_cancel_symbol_picker"), true, true, false)

func _on_symbol_picked(symbol_id: String) -> void:
	var card_id := _pending_card_id
	_close_symbol_picker()
	_pending_card_id = ""
	if card_id != "":
		_complete_after_preview(card_id, symbol_id)

func _cancel_symbol_picker() -> void:
	_close_symbol_picker()
	_pending_card_id = ""
	_selection_locked = false
	_clear_selected_card()
	_set_instruction_text("TAP TO INSPECT  /  DRAG TO THE SLOT")
	for value in _card_buttons.values():
		var card_button := value as Button
		if card_button != null:
			card_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _close_symbol_picker() -> void:
	if _symbol_picker != null:
		_symbol_picker.queue_free()
		_symbol_picker = null

func _clear_cards() -> void:
	_stop_card_glint_cycle()
	if _list != null:
		for child in _list.get_children():
			child.queue_free()
	_card_buttons.clear()
	_offer_ids.clear()
	_preview_id = ""
	if _description_bubble != null:
		_description_bubble.visible = false

func _build_credits_display() -> void:
	_credits_row = HBoxContainer.new()
	_credits_row.name = "CreditsRow"
	_credits_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_credits_row.offset_left = 7.0
	_credits_row.offset_top = -14.0
	_credits_row.offset_right = 30.0
	_credits_row.offset_bottom = -2.0
	_credits_row.add_theme_constant_override("separation", 2)
	_credits_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_row.z_index = 40
	add_child(_credits_row)

	_credits_label = Label.new()
	_credits_label.name = "CreditsLabel"
	_credits_label.add_theme_font_size_override("font_size", 7)
	_credits_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
	_credits_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_credits_label.add_theme_constant_override("outline_size", 1)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_credits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _set_instruction_text(value: String) -> void:
	if _instruction == null:
		return
	_instruction.text = value
	_instruction.visible = true
	if _message != null:
		_message.text = ""
		_message.visible = false

func _set_message_text(value: String) -> void:
	if _message == null:
		return
	_message.text = value
	_message.visible = not value.is_empty()
	if _instruction != null:
		_instruction.visible = value.is_empty()

func _label(text_value: String, rect: Rect2, size: int, color: Color,
		parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	label.z_index = 10
	if _font != null:
		label.add_theme_font_override("font", _font)
	var owner := parent if parent != null else self
	owner.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label
