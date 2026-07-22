extends Control

## Pacte is the run's card ritual. The background and emplacement art are
## authored at the game's 160x320 virtual resolution; card fronts are composed
## from the supplied sheets so every pool entry can carry its own icon metadata.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_SIZE := Vector2(39.0, 61.0)
const CARD_POSITIONS: Array[Vector2] = [
	Vector2(9.0, 175.0), Vector2(61.0, 175.0), Vector2(112.0, 175.0),
]
const AUGMENT_DROP_RECT := Rect2(28.0, 256.0, 25.0, 36.0)
const POWER_DROP_RECT := Rect2(107.0, 256.0, 25.0, 36.0)
const BG_ASSET := "pacte_scene/pacte_scene.png"
const AUGMENT_EMPLACEMENT_ASSET := "pacte_scene/pacte_scene_augment_card.png"
const POWER_EMPLACEMENT_ASSET := "pacte_scene/pacte_scene_power_card.png"
const SELECTED_OVERLAY_ASSET := "pacte_scene/pacte_scene_selected_card.png"

const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_PINK := Color(1.0, 0.42, 0.68)
const NEON_GOLD := Color(1.0, 0.86, 0.36)
const TEXT_COLOR := Color(0.88, 0.98, 1.0)
const DRAG_COLOR := Color(0.42, 1.0, 0.95, 0.95)
const DRAG_SLOP := 4.0

var _background: Sprite2D = null
var _emplacement: Sprite2D = null
var _selected_overlay: Sprite2D = null
var _description_bubble: Panel = null
var _description_title: Label = null
var _description_text: Label = null
var _phase_label: Label = null
var _instruction: Label = null
var _drop_label: Label = null
var _augment_drop_label: Label = null
var _power_drop_label: Label = null
var _cancel_button: Button = null
var _exit_button: Button = null

var _card_buttons: Dictionary = {}
var _card_views: Dictionary = {}
var _revealed: Dictionary = {}
var _offer_ids: Array[String] = []
var _pool_kind := "augment"
var _chosen_augment_id := ""
var _preview_id := ""
var _dragging := false
var _drag_id := ""
var _drag_index := -1
var _drag_origin := Vector2.ZERO
var _press_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_overlay_ui()
	_restore_saved_selection()

func _build_background() -> void:
	_background = _full_canvas_sprite(BG_ASSET, 0)
	_background.name = "PacteBackground"
	add_child(_background)
	move_child(_background, 0)
	_emplacement = _full_canvas_sprite(
		AUGMENT_EMPLACEMENT_ASSET if _pool_kind == "augment" else POWER_EMPLACEMENT_ASSET, 0)
	_emplacement.name = "SelectedCardEmplacement"
	_emplacement.visible = true
	add_child(_emplacement)
	_selected_overlay = _full_canvas_sprite(SELECTED_OVERLAY_ASSET, 0)
	_selected_overlay.name = "SelectedCardOverlay"
	_selected_overlay.hframes = 3
	_selected_overlay.visible = false
	add_child(_selected_overlay)

func _full_canvas_sprite(asset: String, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Assets.texture(asset)
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.z_index = z
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _build_overlay_ui() -> void:
	_phase_label = _label("PacteTitle", Rect2(4.0, 110.0, 152.0, 11.0), 7, NEON_CYAN)
	_phase_label.text = "PACTE"
	_instruction = _label("Instruction", Rect2(5.0, 164.0, 150.0, 10.0), 5, TEXT_COLOR)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_description_bubble = Panel.new()
	_description_bubble.name = "OddsTableDescriptionBubble"
	_description_bubble.position = Rect2(4.0, 119.0, 152.0, 42.0).position
	_description_bubble.size = Rect2(4.0, 119.0, 152.0, 42.0).size
	_description_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_bubble.add_theme_stylebox_override("panel", Assets.neon_panel_style(NEON_GOLD))
	add_child(_description_bubble)
	_description_title = _label("CardTitle", Rect2(3.0, 3.0, 146.0, 9.0), 5, NEON_GOLD, _description_bubble)
	_description_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_text = _label("CardDescription", Rect2(5.0, 14.0, 142.0, 24.0), 4, TEXT_COLOR, _description_bubble)
	_description_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_bubble.visible = false

	# The hint belongs to the emplacement itself. At native resolution the slot is
	# only 25 px wide, so word wrapping keeps both words inside its card frame.
	_augment_drop_label = _drop_hint_label(
		"DropHere", Rect2(28.0, 256.0, 25.0, 36.0))
	_power_drop_label = _drop_hint_label(
		"PowerDropHere", Rect2(107.0, 256.0, 25.0, 36.0))
	_drop_label = _augment_drop_label
	_set_drop_hint_visible(false)

	_cancel_button = _small_button("CancelSelection", "CANCEL", Rect2(112.0, 295.0, 42.0, 14.0), NEON_PINK)
	_cancel_button.pressed.connect(_cancel_selection)
	_exit_button = _small_button("ExitPacte", "EXIT", Rect2(4.0, 295.0, 35.0, 14.0), NEON_CYAN)
	_exit_button.pressed.connect(_exit_pacte)

func _restore_saved_selection() -> void:
	if not RunStateStore.pacte_active():
		_instruction.text = "PACTE IS CLOSED"
		_cancel_button.visible = false
		_exit_button.visible = false
		return
	var saved_augment := String(RunStateStore.pacteSelectedAugmentId)
	if saved_augment != "":
		_chosen_augment_id = saved_augment
		_pool_kind = "power"
		_set_emplacement(POWER_EMPLACEMENT_ASSET)
		_show_pool(_pool_kind, _offer_array(RunStateStore.pacteOfferPowerIds))
	else:
		_show_pool("augment", _offer_array(RunStateStore.pacteOfferAugmentIds))

func _offer_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(String(item))
	return result

func _set_emplacement(asset: String) -> void:
	if _emplacement == null:
		return
	_emplacement.texture = Assets.texture(asset)

func _show_pool(kind: String, ids: Array[String]) -> void:
	_pool_kind = kind
	_clear_cards()
	_offer_ids = ids.duplicate()
	_set_emplacement(AUGMENT_EMPLACEMENT_ASSET if kind == "augment" else POWER_EMPLACEMENT_ASSET)
	_drop_label = _augment_drop_label if kind == "augment" else _power_drop_label
	_set_drop_hint_visible(false)
	_phase_label.text = "CHOOSE AN AUGMENT" if kind == "augment" else "CHOOSE A POWER"
	_instruction.text = "TAP TO INSPECT  /  DRAG TO THE SLOT"
	_cancel_button.visible = true
	for index in _offer_ids.size():
		_build_card(_offer_ids[index], index)
	_reveal_cards()

func _build_card(card_id: String, index: int) -> void:
	var button := Button.new()
	button.name = "Card_%s" % card_id
	button.position = CARD_POSITIONS[index]
	button.size = CARD_SIZE
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.gui_input.connect(_on_card_gui_input.bind(card_id, index, button))
	add_child(button)
	_card_buttons[card_id] = button
	var view := _make_card_view(card_id, _pool_kind)
	button.add_child(view)
	_card_views[card_id] = view
	_revealed[card_id] = false

func _make_card_view(card_id: String, kind: String) -> Control:
	var view := Control.new()
	view.name = "CardArt"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := TextureRect.new()
	back.name = "Back"
	back.texture = _atlas(PacteCards.CARD_SHEET if kind == "augment" else PacteCards.POWER_SHEET,
		Rect2(0.0, 0.0, 39.0, 61.0))
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.size = CARD_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(back)
	var front := TextureRect.new()
	front.name = "Front"
	front.texture = _atlas(PacteCards.CARD_SHEET if kind == "augment" else PacteCards.POWER_SHEET,
		PacteCards.AUGMENT_FRONT_RECT if kind == "augment" else PacteCards.POWER_FRONT_RECT)
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.size = CARD_SIZE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.visible = false
	view.add_child(front)
	var entry := PacteCards.card(card_id)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _atlas(String(entry.get("sheet", "")), entry.get("icon_rect", Rect2()) as Rect2)
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = icon_rect.size
	icon.position = Vector2((CARD_SIZE.x - icon_rect.size.x) * 0.5,
		(CARD_SIZE.y - icon_rect.size.y) * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	view.add_child(icon)
	return view

func _atlas(asset: String, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = Assets.texture(asset)
	atlas.region = region
	return atlas

func _reveal_cards() -> void:
	for index in _offer_ids.size():
		await get_tree().create_timer(0.08 * float(index + 1)).timeout
		if not is_inside_tree():
			return
		_set_face_up(_offer_ids[index])
	if is_inside_tree():
		_instruction.text = "CHOOSE ONE CARD"

func _set_face_up(card_id: String) -> void:
	var view := _card_views.get(card_id, null) as Control
	if view == null:
		return
	var front := view.get_node_or_null("Front") as TextureRect
	var icon := view.get_node_or_null("Icon") as TextureRect
	if front != null:
		front.visible = true
	if icon != null:
		icon.visible = true
	_revealed[card_id] = true
	var button := _card_buttons.get(card_id, null) as Button
	if button != null:
		button.disabled = false

func _on_card_gui_input(event: InputEvent, card_id: String, index: int, button: Button) -> void:
	if not bool(_revealed.get(card_id, false)):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(card_id, index, button, (event as InputEventMouseButton).position)
	elif event is InputEventScreenTouch and event.index == 0 and event.pressed:
		_begin_drag(card_id, index, button, (event as InputEventScreenTouch).position)

# Card buttons stop receiving GUI events once the pointer leaves their rect. Keep
# the drag on the scene root so releasing over either emplacement is reliable.
func _input(event: InputEvent) -> void:
	if _drag_id == "":
		return
	if event is InputEventMouseMotion:
		_update_drag((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag((event as InputEventMouseButton).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0:
		_update_drag((event as InputEventScreenDrag).position)
	elif event is InputEventScreenTouch and event.index == 0 and not event.pressed:
		_finish_drag((event as InputEventScreenTouch).position)
		get_viewport().set_input_as_handled()

func _begin_drag(card_id: String, index: int, button: Button,
		global_position: Vector2) -> void:
	_press_position = global_position
	_drag_origin = button.position
	_drag_offset = button.get_global_transform_with_canvas().affine_inverse() * global_position
	_drag_id = card_id
	_drag_index = index
	_dragging = false

func _update_drag(global_position: Vector2) -> void:
	var button := _card_buttons.get(_drag_id, null) as Button
	if button == null:
		return
	if not _dragging and global_position.distance_to(_press_position) <= DRAG_SLOP:
		return
	_dragging = true
	_set_drop_hint_visible(true)
	button.position = _global_to_local(global_position) - _drag_offset

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
	button.position = _drag_origin
	if not was_dragging:
		_preview_card(card_id)
		return
	var drop_rect := AUGMENT_DROP_RECT if _pool_kind == "augment" else POWER_DROP_RECT
	# Accept the drop when the dragged card overlaps the authored slot. The
	# pointer is not necessarily at the card centre (especially after grabbing
	# an icon edge), so testing only the pointer would make valid drops miss.
	var dragged_rect := Rect2(dragged_card_position, CARD_SIZE)
	var drop_area := drop_rect.grow(4.0)
	if drop_area.intersects(dragged_rect) or drop_area.has_point(local_position):
		_accept_card(card_id)
	else:
		_preview_card(card_id)

func _global_to_local(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position

func _preview_card(card_id: String) -> void:
	if not _offer_ids.has(card_id):
		return
	_preview_id = card_id
	var entry := PacteCards.card(card_id)
	_description_bubble.visible = true
	_description_title.text = String(entry.get("name", card_id))
	_description_text.text = String(entry.get("description", ""))
	var button := _card_buttons.get(card_id, null) as Button
	for id in _offer_ids:
		var candidate := _card_buttons.get(id, null) as Button
		if candidate != null:
			candidate.scale = Vector2.ONE * (1.08 if id == card_id else 1.0)
			candidate.pivot_offset = CARD_SIZE * 0.5
	if _selected_overlay != null:
		_selected_overlay.visible = true
		_selected_overlay.frame = _offer_ids.find(card_id)

func _accept_card(card_id: String) -> void:
	if _pool_kind == "augment":
		if not RunStateStore.select_pacte_augment(card_id):
			return
		_chosen_augment_id = card_id
		_show_pool("power", _offer_array(RunStateStore.pacteOfferPowerIds))
		return
	var threshold_visit := RunStateStore.runPhase == "pacte_threshold"
	if not RunStateStore.stage_pacte_power_selection(card_id):
		return
	if threshold_visit:
		RunStateStore.force_dealer_visit()
		SceneNav.change_to("res://scenes/dealer_scene.tscn")
	else:
		SceneNav.change_to("res://scenes/machine_scene.tscn")

func _cancel_selection() -> void:
	var return_to_augments := _pool_kind == "power" and RunStateStore.pacteSelectedAugmentId != ""
	_preview_id = ""
	if _selected_overlay != null:
		_selected_overlay.visible = false
	for id in _offer_ids:
		var button := _card_buttons.get(id, null) as Button
		if button != null:
			button.scale = Vector2.ONE
	RunStateStore.cancel_pacte_selection()
	_description_bubble.visible = false
	if return_to_augments:
		_chosen_augment_id = ""
		_show_pool("augment", _offer_array(RunStateStore.pacteOfferAugmentIds))

func _exit_pacte() -> void:
	RunStateStore._commit()
	SceneNav.change_to("res://scenes/start_menu_scene.tscn")

func _clear_cards() -> void:
	for child in get_children():
		if child is Button and String(child.name).begins_with("Card_"):
			child.queue_free()
	_card_buttons.clear()
	_card_views.clear()
	_revealed.clear()
	_offer_ids = []
	_preview_id = ""
	if _selected_overlay != null:
		_selected_overlay.visible = false

func _drop_hint_label(label_name: String, rect: Rect2) -> Label:
	var label := _label(label_name, rect, 3, DRAG_COLOR)
	label.text = "DROP HERE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.z_index = 2
	return label

func _set_drop_hint_visible(visible: bool) -> void:
	_drop_label = _power_drop_label if _pool_kind == "power" else _augment_drop_label
	if _augment_drop_label != null:
		_augment_drop_label.visible = visible and _pool_kind == "augment"
	if _power_drop_label != null:
		_power_drop_label.visible = visible and _pool_kind == "power"

func _label(label_name: String, rect: Rect2, font_size: int, color: Color,
		parent: Node = null) -> Label:
	var label := Label.new()
	label.name = label_name
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	var font := Assets.font()
	if font != null:
		label.add_theme_font_override("font", font)
	(parent if parent != null else self).add_child(label)
	return label

func _small_button(button_name: String, text: String, rect: Rect2, color: Color) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.custom_minimum_size = Vector2.ZERO
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 5)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(button)
	return button
