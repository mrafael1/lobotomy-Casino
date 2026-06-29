class_name InRunDealerOffer
extends Control

signal item_selected(item_id: String)
signal item_discarded(item_id: String)
signal dealer_ignored
signal offer_finished

const SRC_W := 160.0
const SRC_H := 320.0
const DEALER_VISIBLE_CENTER_X := 78.0
# Dealer rotates 90deg and slides in from a side border, head first (see _choose_side).
const DEALER_CENTER_Y := 160.0 # vertical centre of the rotated portrait
const DEALER_FILL := 0.92      # portrait width fills ~92% of canvas height when rotated
const HEAD_POKE := 60.0        # how far the head tip reaches in from the border
const HANDS_SCALE := 1.0
# Offered items are small so they read as objects the dealer is holding out, not giant
# badges (issue #24 follow-up). Stash icons reuse the shared Assets.STASH_ICON_SIZE so
# they match the machine scene stash.
const ICON_SIZE := 16.0
const TAP_WAIT := 0.25
const TAP_FINAL_WAIT := 0.35
const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_cigarette": "items/cigarette.png",
	"cons_white_powder": "items/white_powder.png",
	"item_energy_drink": "items/energy_drink.png",
	"item_cocktail": "items/cocktail.png",
	"item_water": "items/water.png",
	"item_pill": "items/pill.png",
}

var _font: FontFile = null
var _dealer_root: Node2D = null
var _dealer_sprite: Sprite2D = null
var _hands_sprite: Sprite2D = null
var _speech_bubble: Control = null
var _bubble_graphic: TextureRect = null
var _speech_label: Label = null
var _tap_label: Label = null
var _message_label: Label = null
var _look_button: TextureButton = null   # valid/check icon — accept / come / look
var _ignore_button: TextureButton = null # cross icon — ignore / leave
var _item_layer: Control = null
var _stash_layer: Control = null
var _side := "left"
var _target_x := 0.0
var _offscreen_x := 0.0
var _finishing := false
var _drag_active := false
var _drag_node: Control = null
var _drag_id := ""
var _drag_kind := ""
var _drag_home := Vector2.ZERO
var _drag_press := Vector2.ZERO
var _drag_moved := false

func _ready() -> void:
	size = Vector2(SRC_W, SRC_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Assets.font("font/DTM-Sans.otf")
	_build_base()
	visible = false

func start_offer(items: Array, stash_items: Array = []) -> void:
	visible = true
	_finishing = false
	_choose_side()
	_clear_offer_items()
	_rebuild_stash(stash_items)
	_setup_items(items)
	_item_layer.visible = false
	_stash_layer.visible = false
	_dealer_root.visible = false
	_hands_sprite.visible = false
	_speech_bubble.visible = false
	_speech_label.text = "I've got something for ya"
	_message_label.text = ""
	_message_label.visible = false
	_look_button.visible = false
	_ignore_button.visible = false
	_tap_label.visible = false
	await _play_tap_warning()
	if _finishing or not is_inside_tree():
		return
	_dealer_root.visible = true
	_dealer_root.position.x = _offscreen_x
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_dealer_root, "position:x", _target_x, 0.32)
	await tw.finished
	if _finishing or not is_inside_tree():
		return
	_speech_bubble.visible = true
	_position_prompt_buttons()
	_look_button.visible = true
	_ignore_button.visible = true

func set_stash_items(stash_items: Array) -> void:
	_rebuild_stash(stash_items)

func show_full_pockets() -> void:
	_message_label.text = "YOUR POCKETS ARE FULL,\nWANNA THROW SOMETHING ?"
	_message_label.pivot_offset = _message_label.size * 0.5
	var mt := create_tween()
	mt.tween_property(_message_label, "scale", Vector2(1.08, 1.08), 0.06)
	mt.tween_property(_message_label, "scale", Vector2.ONE, 0.1)
	_bump_dealer()

func finish_offer() -> void:
	if _finishing:
		return
	_finishing = true
	_drag_active = false
	_speech_bubble.visible = false
	_look_button.visible = false
	_ignore_button.visible = false
	_message_label.visible = false
	_hands_sprite.visible = false
	_item_layer.visible = false
	_stash_layer.visible = false
	if _dealer_root != null and _dealer_root.visible:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_IN)
		tw.tween_property(_dealer_root, "position:x", _offscreen_x, 0.22)
		await tw.finished
	_clear_offer_items()
	offer_finished.emit()

func _build_base() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.16)
	dim.size = Vector2(SRC_W, SRC_H)
	add_child(dim)

	_tap_label = _make_label("tap", Vector2(58.0, 117.0), Vector2(44.0, 18.0), 11, Color(0.98, 0.92, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	_tap_label.visible = false

	_dealer_root = Node2D.new()
	_dealer_root.position = Vector2.ZERO
	add_child(_dealer_root)

	_dealer_sprite = Sprite2D.new()
	_dealer_sprite.texture = Assets.texture("dealer_portrait.png", true)
	# Centred + UNIFORM scale so the portrait is never stretched. It's rotated 90deg
	# per side in _choose_side; scaling by the frame WIDTH means that once rotated the
	# portrait's width fills the canvas height and its body runs off past the border.
	_dealer_sprite.centered = true
	_dealer_sprite.hframes = 2
	_dealer_sprite.frame = 0
	if _dealer_sprite.texture != null:
		var frame_w := float(_dealer_sprite.texture.get_width()) / 2.0
		var s := DEALER_FILL * SRC_H / frame_w
		_dealer_sprite.scale = Vector2(s, s)
	_dealer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dealer_root.add_child(_dealer_sprite)

	_hands_sprite = Sprite2D.new()
	_hands_sprite.texture = Assets.texture("dealer_hands.png", true)
	_hands_sprite.centered = false
	_hands_sprite.scale = Vector2(HANDS_SCALE, HANDS_SCALE)
	_hands_sprite.position = _hands_position()
	_hands_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_hands_sprite)
	_hands_sprite.visible = false

	# Both layers are full-screen holders for their icon children. They MUST ignore the
	# mouse, otherwise the topmost (stash) layer swallows every tap before it reaches an
	# offered-item icon behind it — that was the "can't buy from the hands" bug. The icon
	# children keep MOUSE_FILTER_STOP, so they still receive taps/drags.
	_item_layer = Control.new()
	_item_layer.size = Vector2(SRC_W, SRC_H)
	_item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_item_layer)

	_stash_layer = Control.new()
	_stash_layer.size = Vector2(SRC_W, SRC_H)
	_stash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stash_layer)

	_speech_bubble = Control.new()
	_speech_bubble.size = Vector2(100.0, 38.0)
	add_child(_speech_bubble)
	# Bubble GRAPHIC and Label are separate siblings: we flip only the graphic per side
	# (_choose_side), so the text is never mirrored.
	_bubble_graphic = TextureRect.new()
	_bubble_graphic.texture = Assets.texture("ui/speech_bubble_normal.png", true)
	_bubble_graphic.size = _speech_bubble.size
	_bubble_graphic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bubble_graphic.stretch_mode = TextureRect.STRETCH_SCALE
	_bubble_graphic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble_graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_bubble.add_child(_bubble_graphic)
	# Centre the text in the bubble BODY: full width, and the top ~30px (the bottom ~8px
	# is the tail, excluded) so it reads dead centre of the rounded box (issue #24
	# follow-up). _make_label_on already vertical-centres.
	_speech_label = _make_label_on(_speech_bubble, "I've got something for ya", Vector2(0.0, 0.0), Vector2(_speech_bubble.size.x, 30.0), 6, Color(0.12, 0.06, 0.16), HORIZONTAL_ALIGNMENT_CENTER)
	_speech_bubble.visible = false

	_message_label = _make_label("", Vector2(8.0, 219.0), Vector2(144.0, 19.0), 6, Color(1.0, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER)

	# Valid (check) icon = accept / come / look. Cross icon = ignore / leave.
	_look_button = TextureButton.new()
	_look_button.custom_minimum_size = Vector2(30.0, 24.0)
	_look_button.size = Vector2(30.0, 24.0)
	Assets.skin_icon_button(_look_button, "ui/valid_button.png", 2)
	_look_button.pressed.connect(_on_look_pressed)
	add_child(_look_button)
	_look_button.visible = false

	_ignore_button = TextureButton.new()
	_ignore_button.custom_minimum_size = Vector2(28.0, 24.0)
	_ignore_button.size = Vector2(28.0, 24.0)
	Assets.skin_icon_button(_ignore_button, "ui/cancel_button.png", 2)
	_ignore_button.pressed.connect(_on_ignore_pressed)
	add_child(_ignore_button)
	_ignore_button.visible = false

func _choose_side() -> void:
	_side = "left" if randi() % 2 == 0 else "right"
	# Rotate the portrait 90deg so the head leads in from the border: from the LEFT we
	# spin clockwise (head -> right/into screen); from the RIGHT, anti-clockwise. The
	# head tip is half the portrait's (long) height from the centred sprite's middle, so
	# we place the centre such that the tip pokes HEAD_POKE px in from the border.
	var half_len := 0.5 * SRC_H # fallback if the texture failed to load
	if _dealer_sprite != null and _dealer_sprite.texture != null:
		half_len = float(_dealer_sprite.texture.get_height()) * _dealer_sprite.scale.x * 0.5
	if _side == "left":
		_dealer_sprite.rotation = PI / 2.0
		_target_x = HEAD_POKE - half_len
		_offscreen_x = -half_len - 8.0
	else:
		_dealer_sprite.rotation = -PI / 2.0
		_target_x = SRC_W - HEAD_POKE + half_len
		_offscreen_x = SRC_W + half_len + 8.0
	_dealer_root.position = Vector2(_offscreen_x, DEALER_CENTER_Y)
	_hands_sprite.position = _hands_position()
	# Flip only the bubble graphic so its tail points toward the dealer; the label
	# (a separate sibling) is never mirrored.
	if _bubble_graphic != null:
		_bubble_graphic.flip_h = (_side == "right")
	_speech_bubble.position = Vector2(8.0, 70.0) if _side == "left" else Vector2(52.0, 70.0)

func _hands_position() -> Vector2:
	return Vector2((SRC_W - 128.0 * HANDS_SCALE) * 0.5, (SRC_H - 64.0 * HANDS_SCALE) * 0.5)

func _position_prompt_buttons() -> void:
	# Check (accept/look) and cross (ignore) sit side-by-side just under the bubble.
	var x := _speech_bubble.position.x + 6.0
	var y := _speech_bubble.position.y + 42.0
	_look_button.position = Vector2(x, y)
	_ignore_button.position = Vector2(x + 40.0, y)

func _position_item_stage_buttons() -> void:
	# Bottom-RIGHT corner so the cross never overlaps the centred bottom stash row.
	_ignore_button.position = Vector2(SRC_W - _ignore_button.size.x - 6.0, SRC_H - _ignore_button.size.y - 8.0)

func _play_tap_warning() -> void:
	for i in 3:
		if _finishing or not is_inside_tree():
			return
		_tap_label.text = "tap"
		_tap_label.visible = true
		_tap_label.modulate = Color(1, 1, 1, 0)
		_tap_label.scale = Vector2(0.8, 0.8)
		var tw := create_tween()
		tw.tween_property(_tap_label, "modulate:a", 1.0, 0.04)
		tw.parallel().tween_property(_tap_label, "scale", Vector2.ONE, 0.06)
		tw.tween_property(_tap_label, "modulate:a", 0.0, 0.12)
		await tw.finished
		await get_tree().create_timer(TAP_FINAL_WAIT if i == 2 else TAP_WAIT).timeout
	_tap_label.visible = false

func _setup_items(items: Array) -> void:
	var anchors := _item_anchors()
	var count := mini(items.size(), anchors.size())
	for i in count:
		var id := String(items[i])
		_make_drag_icon(id, "offer", anchors[i])

func _item_anchors() -> Array:
	# Shifted +8px from the old 32px-icon anchors so the now-smaller 16px icons keep the
	# same on-screen centres (issue #24 follow-up).
	return [Vector2(36.0, 145.0), Vector2(108.0, 145.0), Vector2(72.0, 174.0)]

func _make_drag_icon(id: String, kind: String, pos: Vector2, icon_size := ICON_SIZE) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _icon_for(id)
	icon.position = pos
	icon.size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.gui_input.connect(_on_drag_icon_input.bind(icon, id, kind))
	if kind == "stash":
		_stash_layer.add_child(icon)
	else:
		_item_layer.add_child(icon)
	return icon

func _rebuild_stash(stash_items: Array) -> void:
	for child in _stash_layer.get_children():
		child.queue_free()
	# Bottom-right corner, shared layout (issue #26). The machine's own stash is hidden
	# while this overlay is up, so this is the only stash visible and it sits in the same
	# spot — no duplicate.
	for i in stash_items.size():
		_make_drag_icon(String(stash_items[i]), "stash", Assets.stash_slot_pos(i, Consumables.MAX_CONSUMABLE_SLOTS), Assets.STASH_ICON_SIZE)

func _clear_offer_items() -> void:
	if _item_layer != null:
		for child in _item_layer.get_children():
			child.queue_free()

func _icon_for(id: String) -> Texture2D:
	return Assets.texture(String(ITEM_ICONS.get(id, "items/consumable_placeholder.png")), true)

func _make_label(text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _make_label_on(self, text, pos, label_size, font_size, color, align)

func _make_label_on(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _on_ignore_pressed() -> void:
	dealer_ignored.emit()

func _on_look_pressed() -> void:
	_look_button.visible = false
	_position_item_stage_buttons()
	_speech_label.text = "Interested in one?"
	_hands_sprite.visible = true
	_item_layer.visible = true
	_stash_layer.visible = true
	_message_label.visible = true

func _on_drag_icon_input(event: InputEvent, node: Control, id: String, kind: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _drag_active:
		_begin_drag(node, id, kind)

func _begin_drag(node: Control, id: String, kind: String) -> void:
	_drag_active = true
	_drag_node = node
	_drag_id = id
	_drag_kind = kind
	_drag_home = node.position
	_drag_press = get_global_mouse_position()
	_drag_moved = false
	node.z_index = 30
	node.scale = Vector2(1.18, 1.18)
	node.modulate = Color(1.2, 1.2, 1.2)

func _input(event: InputEvent) -> void:
	if not _drag_active:
		return
	if event is InputEventMouseMotion:
		var pos := get_global_mouse_position()
		if _drag_node != null:
			_drag_node.global_position = pos - _drag_node.size * 0.5
		if pos.distance_to(_drag_press) > 4.0:
			_drag_moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(get_global_mouse_position())

func _end_drag(release_pos: Vector2) -> void:
	var id := _drag_id
	var kind := _drag_kind
	var node := _drag_node
	var dropped_on_dealer := _dealer_hit_rect().has_point(release_pos)
	_drag_active = false
	_drag_node = null
	_drag_id = ""
	_drag_kind = ""
	if node != null:
		node.z_index = 0
		node.position = _drag_home
		node.scale = Vector2.ONE
		node.modulate = Color.WHITE
	if not _drag_moved:
		if kind == "offer" and id != "":
			item_selected.emit(id)
		return
	if dropped_on_dealer and id != "":
		if kind == "offer":
			item_selected.emit(id)
		elif kind == "stash":
			item_discarded.emit(id)

func _dealer_hit_rect() -> Rect2:
	if _side == "left":
		return Rect2(0.0, 138.0, 48.0, 134.0)
	return Rect2(112.0, 138.0, 48.0, 134.0)

func _bump_dealer() -> void:
	var start_x := _dealer_root.position.x
	var tw := create_tween()
	tw.tween_property(_dealer_root, "position:x", start_x + (3.0 if _side == "left" else -3.0), 0.04)
	tw.tween_property(_dealer_root, "position:x", start_x + (-3.0 if _side == "left" else 3.0), 0.04)
	tw.tween_property(_dealer_root, "position:x", start_x, 0.05)
