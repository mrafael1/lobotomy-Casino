@tool
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
const DEALER_FILL := 0.86      # cropped portrait width fills most of canvas height when rotated
const HEAD_POKE := 118.0       # how far the head/upper body reaches in from the border
const DEALER_FRAME_W := 1280.0
const DEALER_CROP_X := 392.0
const DEALER_CROP_Y := 1048.0
const DEALER_CROP_W := 464.0
const DEALER_CROP_H := 640.0
const HANDS_SCALE := 1.0
# Offered items are small so they read as objects the dealer is holding out, not giant
# badges (issue #24 follow-up). Stash icons reuse the shared Assets.STASH_ICON_SIZE so
# they match the machine scene stash.
const ICON_SIZE := 16.0
# TAP TAP TAP warning timing: each tap must stay readable, but the whole warning
# has to clear well under a second so it never stalls the dealer's entrance.
const TAP_COUNT := 3
const TAP_ENTRY_TIME := 0.04   # fade/scale in
const TAP_EXIT_TIME := 0.08    # fade out
const TAP_WAIT := 0.08         # gap between taps
const TAP_FINAL_WAIT := 0.12   # beat before the dealer slides in
const ENTRY_TRANS := Tween.TRANS_BACK
const ENTRY_EASE := Tween.EASE_OUT
const ENTRY_TIME := 0.32
const ITEM_VISUAL_SIZE := Vector2(16.0, 16.0)
const OFFER_SLOT_SIZE := Vector2(32.0, 32.0)
const FULL_POCKETS_MESSAGE := "YOUR POCKETS ARE FULL,\nWANNA THROW SOMETHING ?"
const TV_POSITIVE_COLOR := Color(0.13, 0.77, 0.37)
const TV_NEGATIVE_COLOR := Color(0.94, 0.27, 0.27)
const BUBBLE_TEXT_COLOR := Color(0.12, 0.06, 0.16)
## Purple corrupted-name colour, shared with the dealer/upgrade rule (issue #33/#7).
const CORRUPT_NAME_COLOR := Color(0.66, 0.33, 0.86)
# In-run pool only (InRunItems.LIST). Pre-run cons_* hints live in
# dealer_scene.gd — the two scenes own separate pools (issue #31).
const ITEM_HINTS := {
	"item_water": { "pos": "REFRESH", "neg": "WEAK" },
	"item_pill": { "pos": "WIN GUARANTEED", "neg": "CLOSE CALL" },
	"item_energy_drink": { "pos": "FREE", "neg": "COMPULSIVE" },
	"item_cocktail": { "pos": "EASY", "neg": "STICKY" },
}
const FALLBACK_HINT := { "pos": "GIFT", "neg": "PRICE" }
const INVERTED_HINT_ITEMS := ["item_pill"]
# In-run pool only (InRunItems.LIST) — see ITEM_HINTS note (issue #31).
const ITEM_ICONS := {
	"item_energy_drink": "items/energy_drink.png",
	"item_cocktail": "items/cocktail.png",
	"item_water": "items/water.png",
	"item_pill": "items/pill.png",
}

@export var editor_preview_offer_ids: Array[String] = ["item_water", "item_pill"]:
	set(value):
		editor_preview_offer_ids = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_show_editor_preview")

@export var item_offset := Vector2.ZERO:
	set(value):
		item_offset = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_show_editor_preview")

@export_group("Drop Hitbox")
@export var left_dealer_drop_rect := Rect2(0.0, 104.0, 72.0, 168.0):
	set(value):
		left_dealer_drop_rect = value
		queue_redraw()

@export var right_dealer_drop_rect := Rect2(88.0, 104.0, 72.0, 168.0):
	set(value):
		right_dealer_drop_rect = value
		queue_redraw()

@export var show_drop_hitbox_in_editor := true:
	set(value):
		show_drop_hitbox_in_editor = value
		queue_redraw()

var _font: FontFile = null
var _dealer_root: Node2D = null
var _dealer_sprite: Sprite2D = null
var _hands_sprite: Sprite2D = null
var _speech_bubble: Control = null
var _bubble_graphic: TextureRect = null
var _speech_label: Label = null
var _speech_hint_layer: Control = null
var _speech_name_hint: Label = null  # item name, purple when corrupted (issue #33)
var _speech_pos_hint: Label = null
var _speech_neg_hint: Label = null
var _tap_label: Label = null
var _message_label: Label = null
var _look_text_button: Button = null
var _ignore_action_button: Button = null
var _look_button: TextureButton = null   # valid/check icon — accept / come / look
var _ignore_button: TextureButton = null # cross icon — ignore / leave
var _ignore_text_button: Button = null
var _item_layer: Control = null
var _stash_layer: Control = null
var _offer_slots: Array[Control] = []
var _side := "left"
var _target_x := 0.0
var _offscreen_x := 0.0
var _uses_authored_base := false
var _dealer_target_left_x := 0.0
var _dealer_target_right_x := SRC_W
var _dealer_center_y := DEALER_CENTER_Y
var _bubble_left_pos := Vector2(8.0, 70.0)
var _bubble_right_pos := Vector2(52.0, 70.0)
var _hands_rest_position := Vector2.ZERO
var _hands_entry_position := Vector2.ZERO
var _finishing := false
var _items_stage := false        # hands/items shown; look button doubles as TAKE
var _selected_offer_id := ""     # tapped item — TAKE buys this one
var _offer_icons := {}           # offer id -> icon Control (selection highlight)
var _current_offer_ids: Array[String] = []

func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(SRC_W, SRC_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Assets.font("font/DTM-Sans.otf")
	_build_base()
	if Engine.is_editor_hint():
		_show_editor_preview()
		return
	visible = false

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		call_deferred("_show_editor_preview")

func _draw() -> void:
	if not Engine.is_editor_hint() or not show_drop_hitbox_in_editor:
		return
	var rect := _dealer_hit_rect()
	draw_rect(rect, Color(0.13, 0.77, 0.37, 0.18), true)
	draw_rect(rect, Color(0.13, 0.77, 0.37, 0.85), false, 1.0)

func start_offer(items: Array, stash_items: Array = []) -> void:
	visible = true
	_finishing = false
	_items_stage = false
	_selected_offer_id = ""
	_choose_side()
	_clear_offer_items()
	_rebuild_stash(stash_items)
	_current_offer_ids = _string_items(items)
	_setup_items(items)
	_item_layer.visible = false
	_stash_layer.visible = false
	_dealer_root.visible = false
	_hands_sprite.visible = false
	_speech_bubble.visible = false
	_set_speech_text("I've got something for ya")
	_message_label.text = ""
	_message_label.visible = false
	if _look_button != null:
		_look_button.visible = false
	if _ignore_button != null:
		_ignore_button.visible = false
	if _look_text_button != null:
		_look_text_button.text = "look"
		_look_text_button.disabled = false
		_look_text_button.visible = false
	if _ignore_action_button != null:
		_ignore_action_button.text = "ignore"
		_ignore_action_button.visible = false
	if _ignore_text_button != null:
		_ignore_text_button.visible = false
	_tap_label.visible = false
	await _play_tap_warning()
	if _finishing or not is_inside_tree():
		return
	_dealer_root.visible = true
	_dealer_root.position.x = _offscreen_x
	var tw := create_tween()
	tw.set_trans(ENTRY_TRANS)
	tw.set_ease(ENTRY_EASE)
	tw.tween_property(_dealer_root, "position:x", _target_x, ENTRY_TIME)
	await tw.finished
	if _finishing or not is_inside_tree():
		return
	_speech_bubble.visible = true
	_position_prompt_buttons()
	await get_tree().create_timer(0.18).timeout
	if _finishing or not is_inside_tree():
		return
	if _look_text_button != null:
		_look_text_button.visible = true
	elif _look_button != null:
		_look_button.visible = true
	if _ignore_action_button != null:
		_ignore_action_button.visible = true
	elif _ignore_button != null:
		_ignore_button.visible = true

func set_stash_items(stash_items: Array) -> void:
	_rebuild_stash(stash_items)

func show_full_pockets() -> void:
	if _speech_bubble != null:
		_speech_bubble.visible = true
	_set_speech_text(FULL_POCKETS_MESSAGE)
	_speech_label.pivot_offset = _speech_label.size * 0.5
	var mt := create_tween()
	mt.tween_property(_speech_label, "scale", Vector2(1.08, 1.08), 0.06)
	mt.tween_property(_speech_label, "scale", Vector2.ONE, 0.1)
	_bump_dealer()

func finish_offer() -> void:
	if _finishing:
		return
	_finishing = true
	_speech_bubble.visible = false
	if _speech_hint_layer != null:
		_speech_hint_layer.visible = false
	if _look_button != null:
		_look_button.visible = false
	if _ignore_button != null:
		_ignore_button.visible = false
	if _look_text_button != null:
		_look_text_button.visible = false
	if _ignore_action_button != null:
		_ignore_action_button.visible = false
	if _ignore_text_button != null:
		_ignore_text_button.visible = false
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
	if _bind_authored_base():
		return

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.16)
	dim.size = Vector2(SRC_W, SRC_H)
	add_child(dim)

	_tap_label = _make_label("tap", Vector2(58.0, 117.0), Vector2(44.0, 18.0), 11, Color(0.98, 0.92, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	_style_tap_label()
	_tap_label.visible = false

	_dealer_root = Node2D.new()
	_dealer_root.position = Vector2.ZERO
	add_child(_dealer_root)

	_dealer_sprite = Sprite2D.new()
	_configure_dealer_sprite(true)
	_dealer_root.add_child(_dealer_sprite)

	_hands_sprite = Sprite2D.new()
	_hands_sprite.texture = Assets.texture("dealer_hands.png", true)
	_hands_sprite.centered = false
	_hands_sprite.scale = Vector2(HANDS_SCALE, HANDS_SCALE)
	_hands_sprite.position = _hands_position()
	_hands_rest_position = _hands_sprite.position
	_hands_entry_position = Vector2(_hands_rest_position.x, -_hands_size().y - 2.0)
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
	for i in range(1, 3):
		var slot := Control.new()
		slot.name = "OfferSlot%d" % i
		slot.size = OFFER_SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_item_layer.add_child(slot)
		_offer_slots.append(slot)
	_layout_offer_slots()

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
	_speech_label = _make_label_on(_speech_bubble, "I've got something for ya", Vector2(0.0, 0.0), Vector2(_speech_bubble.size.x, 30.0), 6, BUBBLE_TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_ensure_speech_hint_layer()
	_speech_bubble.visible = false

	_message_label = _make_label("", Vector2(8.0, 219.0), Vector2(144.0, 19.0), 6, Color(1.0, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER)

	_look_text_button = Button.new()
	_look_text_button.name = "LookButton"
	_look_text_button.text = "look"
	_look_text_button.custom_minimum_size = Vector2(52.0, 16.0)
	_look_text_button.size = Vector2(52.0, 16.0)
	_look_text_button.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_look_text_button.add_theme_font_override("font", _font)
	Assets.skin_sheet_button(_look_text_button, "ui/green_button.png", 4)
	_look_text_button.pressed.connect(_on_look_pressed)
	add_child(_look_text_button)
	_look_text_button.visible = false

	_ignore_action_button = Button.new()
	_ignore_action_button.name = "IgnoreButton"
	_ignore_action_button.text = "ignore"
	_ignore_action_button.custom_minimum_size = Vector2(52.0, 16.0)
	_ignore_action_button.size = Vector2(52.0, 16.0)
	_ignore_action_button.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_ignore_action_button.add_theme_font_override("font", _font)
	Assets.skin_negative_button(_ignore_action_button)
	_ignore_action_button.pressed.connect(_on_ignore_pressed)
	add_child(_ignore_action_button)
	_ignore_action_button.visible = false

	_ignore_text_button = Button.new()
	_ignore_text_button.text = "IGNORE"
	_ignore_text_button.size = Vector2(52.0, 16.0)
	_ignore_text_button.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_ignore_text_button.add_theme_font_override("font", _font)
	Assets.skin_negative_button(_ignore_text_button)
	_ignore_text_button.pressed.connect(_on_ignore_pressed)
	add_child(_ignore_text_button)
	_ignore_text_button.visible = false

func _bind_authored_base() -> bool:
	_dealer_root = get_node_or_null("DealerRoot") as Node2D
	if _dealer_root == null:
		return false
	_uses_authored_base = true

	_tap_label = get_node_or_null("TapLabel") as Label
	_dealer_sprite = get_node_or_null("DealerRoot/DealerSprite") as Sprite2D
	_hands_sprite = get_node_or_null("Hands") as Sprite2D
	_item_layer = get_node_or_null("ItemLayer") as Control
	_stash_layer = get_node_or_null("StashLayer") as Control
	_speech_bubble = get_node_or_null("SpeechBubble") as Control
	_bubble_graphic = get_node_or_null("SpeechBubble/BubbleGraphic") as TextureRect
	_speech_label = get_node_or_null("SpeechBubble/SpeechLabel") as Label
	_speech_hint_layer = get_node_or_null("SpeechBubble/HintLayer") as Control
	_speech_name_hint = get_node_or_null("SpeechBubble/HintLayer/NameHint") as Label
	_speech_pos_hint = get_node_or_null("SpeechBubble/HintLayer/PositiveHint") as Label
	_speech_neg_hint = get_node_or_null("SpeechBubble/HintLayer/NegativeHint") as Label
	_message_label = get_node_or_null("MessageLabel") as Label
	_look_text_button = get_node_or_null("LookButton") as Button
	_ignore_action_button = get_node_or_null("IgnoreButton") as Button
	_ignore_text_button = get_node_or_null("IgnoreTextButton") as Button
	_dealer_target_left_x = _dealer_root.position.x
	_dealer_target_right_x = SRC_W - absf(_dealer_target_left_x)
	_dealer_center_y = _dealer_root.position.y
	if _speech_bubble != null:
		_bubble_left_pos = _speech_bubble.position
		_bubble_right_pos = Vector2(SRC_W - _speech_bubble.position.x - _speech_bubble.size.x, _speech_bubble.position.y)

	var dim := get_node_or_null("Dim") as ColorRect
	if dim != null:
		if dim.size == Vector2.ZERO:
			dim.size = Vector2(SRC_W, SRC_H)

	if _tap_label != null:
		if _tap_label.text == "":
			_tap_label.text = "tap"
		_style_tap_label()
		_tap_label.visible = false

	if _dealer_sprite != null:
		_configure_dealer_sprite(false)

	if _hands_sprite != null:
		if _hands_sprite.texture == null:
			_hands_sprite.texture = Assets.texture("dealer_hands.png", true)
		_hands_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hands_rest_position = _hands_sprite.position
		_hands_entry_position = Vector2(_hands_rest_position.x, -_hands_size().y - 2.0)
		_hands_sprite.visible = false

	if _item_layer != null:
		if _item_layer.size == Vector2.ZERO:
			_item_layer.size = Vector2(SRC_W, SRC_H)
		_item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bind_offer_slots()
		_layout_offer_slots()

	if _stash_layer != null:
		if _stash_layer.size == Vector2.ZERO:
			_stash_layer.size = Vector2(SRC_W, SRC_H)
		_stash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _speech_bubble != null:
		if _speech_bubble.size == Vector2.ZERO:
			_speech_bubble.size = Vector2(100.0, 38.0)
		_speech_bubble.visible = false

	if _bubble_graphic != null and _speech_bubble != null:
		if _bubble_graphic.texture == null:
			_bubble_graphic.texture = Assets.texture("ui/speech_bubble_normal.png", true)
		if _bubble_graphic.size == Vector2.ZERO:
			_bubble_graphic.size = _speech_bubble.size
		_bubble_graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _speech_label != null and _speech_bubble != null:
		if _speech_label.text == "":
			_speech_label.text = "I've got something for ya"
		_speech_label.add_theme_color_override("font_color", BUBBLE_TEXT_COLOR)
		_ensure_speech_hint_layer()

	if _look_text_button != null:
		_look_text_button.text = "look"
		_look_text_button.add_theme_font_size_override("font_size", 8)
		if _font != null:
			_look_text_button.add_theme_font_override("font", _font)
		Assets.skin_sheet_button(_look_text_button, "ui/green_button.png", 4)
		if not _look_text_button.pressed.is_connected(_on_look_pressed):
			_look_text_button.pressed.connect(_on_look_pressed)
		_look_text_button.visible = false

	if _ignore_action_button != null:
		_ignore_action_button.text = "ignore"
		_ignore_action_button.add_theme_font_size_override("font_size", 8)
		if _font != null:
			_ignore_action_button.add_theme_font_override("font", _font)
		Assets.skin_negative_button(_ignore_action_button)
		if not _ignore_action_button.pressed.is_connected(_on_ignore_pressed):
			_ignore_action_button.pressed.connect(_on_ignore_pressed)
		_ignore_action_button.visible = false

	if _ignore_text_button != null:
		if _ignore_text_button.text == "":
			_ignore_text_button.text = "IGNORE"
		if _ignore_text_button.size == Vector2.ZERO:
			_ignore_text_button.size = Vector2(52.0, 16.0)
		if not _ignore_text_button.pressed.is_connected(_on_ignore_pressed):
			_ignore_text_button.pressed.connect(_on_ignore_pressed)
		_ignore_text_button.visible = false

	return (
		_tap_label != null
		and _dealer_sprite != null
		and _hands_sprite != null
		and _item_layer != null
		and _stash_layer != null
		and _speech_bubble != null
		and _bubble_graphic != null
		and _speech_label != null
		and _message_label != null
		and _look_text_button != null
		and _ignore_action_button != null
	)

func _style_authored_label(label: Label, text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)

func _style_tap_label() -> void:
	if _tap_label == null:
		return
	_tap_label.add_theme_constant_override("outline_size", 2)
	_tap_label.add_theme_color_override("font_outline_color", Color(0.04, 0.0, 0.08, 1.0))

func _configure_dealer_sprite(apply_default_transform := false) -> void:
	if _dealer_sprite == null:
		return
	if _dealer_sprite.texture == null:
		_dealer_sprite.texture = Assets.texture("dealer_portrait.png", true)
	if apply_default_transform:
		_dealer_sprite.hframes = 1
		_dealer_sprite.frame = 0
	if apply_default_transform or not _dealer_sprite.region_enabled:
		_dealer_sprite.region_enabled = true
		_dealer_sprite.region_rect = Rect2(DEALER_CROP_X, DEALER_CROP_Y, DEALER_CROP_W, DEALER_CROP_H)
	elif _dealer_sprite.region_rect.size == Vector2.ZERO:
		_dealer_sprite.region_rect = Rect2(DEALER_CROP_X, DEALER_CROP_Y, DEALER_CROP_W, DEALER_CROP_H)
	if apply_default_transform:
		_dealer_sprite.position = Vector2.ZERO
		_dealer_sprite.centered = true
		var s := DEALER_FILL * SRC_H / DEALER_CROP_W
		_dealer_sprite.scale = Vector2(s, s)
	_dealer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _show_editor_preview() -> void:
	visible = true
	_finishing = false
	_apply_side("left")
	if _dealer_root != null:
		_dealer_root.visible = true
		_dealer_root.position = Vector2(_target_x, _dealer_center_y)
	if _tap_label != null:
		_tap_label.visible = true
		_tap_label.modulate = Color.WHITE
	if _speech_bubble != null:
		_speech_bubble.visible = true
	if _speech_label != null and _speech_label.text == "":
		_set_speech_text("I've got something for ya")
	if _look_text_button != null and _ignore_action_button != null:
		_position_prompt_buttons()
		_look_text_button.visible = true
		_ignore_action_button.visible = true
	if _hands_sprite != null:
		_hands_sprite.position = _hands_rest_position
		_hands_sprite.visible = true
	if _item_layer != null:
		_clear_offer_items()
		_layout_offer_slots()
		_item_layer.visible = true
		_current_offer_ids = editor_preview_offer_ids.duplicate()
		_setup_items(_current_offer_ids)
		_set_speech_text("I've got something for ya")
	if _stash_layer != null:
		_stash_layer.visible = false
	if _message_label != null:
		_message_label.visible = false
	if _ignore_text_button != null:
		_ignore_text_button.visible = false

func _choose_side() -> void:
	_apply_side("left" if randi() % 2 == 0 else "right")

func _apply_side(side: String) -> void:
	_side = side
	# Rotate the portrait 90deg so the head leads in from the border: from the LEFT we
	# spin clockwise (head -> right/into screen); from the RIGHT, anti-clockwise. The
	# head tip is half the portrait's (long) height from the centred sprite's middle, so
	# we place the centre such that the tip pokes HEAD_POKE px in from the border.
	var half_len := DEALER_CROP_H * absf(_dealer_sprite.scale.y) * 0.5
	if _side == "left":
		_dealer_sprite.rotation = PI / 2.0
		_target_x = _dealer_target_left_x
		_offscreen_x = _target_x - half_len - 8.0
	else:
		_dealer_sprite.rotation = -PI / 2.0
		_target_x = _dealer_target_right_x
		_offscreen_x = _target_x + half_len + 8.0
	_dealer_root.position = Vector2(_offscreen_x, _dealer_center_y)
	queue_redraw()
	# Flip only the bubble graphic so its tail points toward the dealer; the label
	# (a separate sibling) is never mirrored.
	if _bubble_graphic != null:
		_bubble_graphic.flip_h = (_side == "right")
	_speech_bubble.position = _bubble_left_pos if _side == "left" else _bubble_right_pos

func _hands_position() -> Vector2:
	return Vector2((SRC_W - 128.0 * HANDS_SCALE) * 0.5, 0.0)

func _hands_size() -> Vector2:
	if _hands_sprite == null or _hands_sprite.texture == null:
		return Vector2(128.0, 64.0) * HANDS_SCALE
	return Vector2(
		float(_hands_sprite.texture.get_width()) * absf(_hands_sprite.scale.x),
		float(_hands_sprite.texture.get_height()) * absf(_hands_sprite.scale.y)
	)

func _bind_offer_slots() -> void:
	_offer_slots.clear()
	if _item_layer == null:
		return
	for i in range(1, 3):
		var slot := _item_layer.get_node_or_null("OfferSlot%d" % i) as Control
		if slot != null:
			_offer_slots.append(slot)

func _layout_offer_slots() -> void:
	if _item_layer == null or _hands_sprite == null or _offer_slots.is_empty():
		return
	if _uses_authored_base:
		return
	var hand_size := _hands_size()
	var centers := [
		_hands_sprite.position + Vector2(hand_size.x * 0.25, hand_size.y * 0.5),
		_hands_sprite.position + Vector2(hand_size.x * 0.75, hand_size.y * 0.5),
	]
	for i in range(mini(_offer_slots.size(), centers.size())):
		var slot := _offer_slots[i]
		slot.size = OFFER_SLOT_SIZE
		slot.position = centers[i] - _item_layer.position - slot.size * 0.5

func _position_prompt_buttons() -> void:
	if _uses_authored_base:
		return
	var x := (SRC_W - _ignore_action_button.size.x) * 0.5
	var y := SRC_H - 44.0
	_ignore_action_button.position = Vector2(x, y)
	_look_text_button.position = Vector2(x, y - _look_text_button.size.y - 4.0)

func _position_item_stage_buttons() -> void:
	if _uses_authored_base:
		return
	if _ignore_action_button != null:
		_ignore_action_button.position = Vector2((SRC_W - _ignore_action_button.size.x) * 0.5, SRC_H - 44.0)

func _play_tap_warning() -> void:
	for i in TAP_COUNT:
		if _finishing or not is_inside_tree():
			return
		_tap_label.text = "tap"
		_tap_label.visible = true
		_tap_label.modulate = Color(1, 1, 1, 0)
		_tap_label.scale = Vector2(0.7, 0.7)
		var tw := create_tween()
		tw.tween_property(_tap_label, "modulate:a", 1.0, TAP_ENTRY_TIME)
		tw.parallel().tween_property(_tap_label, "scale", Vector2(1.15, 1.15), TAP_ENTRY_TIME)
		tw.tween_property(_tap_label, "modulate:a", 0.0, TAP_EXIT_TIME)
		await tw.finished
		await get_tree().create_timer(TAP_FINAL_WAIT if i == TAP_COUNT - 1 else TAP_WAIT).timeout
	_tap_label.visible = false

func _setup_items(items: Array) -> void:
	var anchors := _item_anchors()
	var count := mini(items.size(), anchors.size())
	for i in count:
		var id := String(items[i])
		if i < _offer_slots.size():
			var slot := _offer_slots[i]
			_make_item_icon_on(slot, id, "offer", _item_position_in_slot(slot), ITEM_VISUAL_SIZE.x)
		else:
			_make_item_icon(id, "offer", anchors[i] + item_offset)

func _item_anchors() -> Array:
	if not _offer_slots.is_empty():
		var out: Array = []
		for slot in _offer_slots:
			out.append(slot.position + _item_position_in_slot(slot))
		return out
	return [
		_authored_anchor_position("OfferAnchor1", Vector2(36.0, 145.0)),
		_authored_anchor_position("OfferAnchor2", Vector2(108.0, 145.0)),
	]

func _authored_anchor_position(node_name: String, fallback: Vector2) -> Vector2:
	if _item_layer == null:
		return fallback
	var node := _item_layer.get_node_or_null(node_name)
	if node is Control:
		return (node as Control).position
	if node is Node2D:
		return (node as Node2D).position
	return fallback

func _item_position_in_slot(slot: Control) -> Vector2:
	return (slot.size - ITEM_VISUAL_SIZE) * 0.5 + item_offset

func _make_item_icon(id: String, kind: String, pos: Vector2, icon_size := ICON_SIZE) -> TextureRect:
	return _make_item_icon_on(_stash_layer if kind == "stash" else _item_layer, id, kind, pos, icon_size)

func _make_item_icon_on(parent: Control, id: String, kind: String, pos: Vector2, icon_size := ICON_SIZE) -> TextureRect:
	var icon := TextureRect.new()
	icon.set_meta("_in_run_dealer_dynamic_icon", true)
	icon.texture = _icon_for(id)
	icon.position = pos
	icon.size = Vector2(icon_size, icon_size)
	icon.pivot_offset = Vector2(icon_size, icon_size) * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.gui_input.connect(_on_offer_icon_input.bind(id, kind))
	parent.add_child(icon)
	if kind == "offer":
		_offer_icons[id] = icon
	return icon

func _rebuild_stash(_stash_items: Array) -> void:
	for child in _stash_layer.get_children():
		child.queue_free()
	# Bottom-right corner, shared layout (issue #26). The machine's own stash is hidden
	# while this overlay is up, so this is the only stash visible and it sits in the same
	# spot — no duplicate.

func _clear_offer_items() -> void:
	_offer_icons.clear()
	_selected_offer_id = ""
	if _item_layer != null:
		_clear_dynamic_icons(_item_layer)

func _clear_dynamic_icons(parent: Node) -> void:
	for child in parent.get_children():
		if child.has_meta("_in_run_dealer_dynamic_icon"):
			child.queue_free()
		else:
			_clear_dynamic_icons(child)

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

func _ensure_speech_hint_layer() -> void:
	if _speech_bubble == null:
		return
	if _speech_hint_layer == null:
		_speech_hint_layer = Control.new()
		_speech_hint_layer.name = "HintLayer"
		_speech_hint_layer.position = Vector2.ZERO
		_speech_hint_layer.size = Vector2(_speech_bubble.size.x, 30.0)
		_speech_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_speech_bubble.add_child(_speech_hint_layer)
	if _speech_name_hint == null:
		_speech_name_hint = _make_label_on(_speech_hint_layer, "", Vector2(8.0, 1.0), Vector2(_speech_bubble.size.x - 16.0, 10.0), 8, BUBBLE_TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		_speech_name_hint.name = "NameHint"
	if _speech_pos_hint == null:
		_speech_pos_hint = _make_label_on(_speech_hint_layer, "", Vector2(8.0, 12.0), Vector2(_speech_bubble.size.x - 16.0, 10.0), 8, TV_POSITIVE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
		_speech_pos_hint.name = "PositiveHint"
	if _speech_neg_hint == null:
		_speech_neg_hint = _make_label_on(_speech_hint_layer, "", Vector2(8.0, 23.0), Vector2(_speech_bubble.size.x - 16.0, 10.0), 8, TV_NEGATIVE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
		_speech_neg_hint.name = "NegativeHint"
	var hint_labels: Array[Label] = [_speech_name_hint, _speech_pos_hint, _speech_neg_hint]
	for label: Label in hint_labels:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		if _font != null:
			label.add_theme_font_override("font", _font)
	# Item names no longer show in the bubble. The two hint lines keep their
	# original left alignment (the +/- prefixes line up), centred vertically in
	# the bubble body.
	_speech_name_hint.visible = false
	_speech_pos_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speech_neg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speech_pos_hint.position = Vector2(8.0, 4.0)
	_speech_neg_hint.position = Vector2(8.0, 16.0)
	_speech_pos_hint.add_theme_color_override("font_color", TV_POSITIVE_COLOR)
	_speech_neg_hint.add_theme_color_override("font_color", TV_NEGATIVE_COLOR)
	_speech_hint_layer.visible = false

func _set_speech_text(text: String) -> void:
	if _speech_label != null:
		_speech_label.text = text
		_speech_label.visible = true
		_speech_label.add_theme_color_override("font_color", BUBBLE_TEXT_COLOR)
	if _speech_hint_layer != null:
		_speech_hint_layer.visible = false

func _set_speech_hints(item_id: String, backing_text := "Interested in one?") -> void:
	if _speech_label != null:
		_speech_label.text = backing_text
		_speech_label.visible = false
	_ensure_speech_hint_layer()
	if _speech_hint_layer == null:
		_set_speech_text(backing_text)
		return
	# No item name in the bubble — just the two hint lines, so they fit nicely.
	var hints: Dictionary = ITEM_HINTS.get(item_id, FALLBACK_HINT)
	var inverted := INVERTED_HINT_ITEMS.has(item_id)
	_speech_name_hint.visible = false
	_speech_pos_hint.text = "+ %s" % String(hints["pos"])
	_speech_neg_hint.text = "- %s" % String(hints["neg"])
	_speech_pos_hint.position = Vector2(8.0, 16.0 if inverted else 4.0)
	_speech_neg_hint.position = Vector2(8.0, 4.0 if inverted else 16.0)
	_speech_hint_layer.visible = true

func _item_name(id: String) -> String:
	var imap := InRunItems.map()
	if imap.has(id):
		return String(imap[id]["name"]).to_upper()
	var cmap := Consumables.map()
	if cmap.has(id):
		return String(cmap[id]["name"]).to_upper()
	return id.to_upper()

func _string_items(items: Array) -> Array[String]:
	var out: Array[String] = []
	for item in items:
		out.append(String(item))
	return out

func _on_ignore_pressed() -> void:
	dealer_ignored.emit()

# The green button doubles up: "look" reveals the items, then it becomes "take"
# in the old look position (above leave) and buys the selected item.
func _on_look_pressed() -> void:
	if _items_stage:
		if _selected_offer_id != "":
			item_selected.emit(_selected_offer_id)
		return
	_items_stage = true
	if _look_text_button != null:
		_look_text_button.text = "take"
		_look_text_button.disabled = true # enabled once an item is tapped
		_look_text_button.visible = true
	if _look_button != null:
		_look_button.visible = false
	_position_item_stage_buttons()
	if _ignore_action_button != null:
		_ignore_action_button.text = "leave"
		_ignore_action_button.visible = true
	_set_speech_text("Interested in one?")
	_hands_sprite.position = _hands_entry_position
	_hands_sprite.visible = true
	_item_layer.visible = true
	_stash_layer.visible = false
	_message_label.visible = false
	if _ignore_text_button != null:
		_ignore_text_button.visible = false
	await _play_hands_entry()

func _play_hands_entry() -> void:
	if _hands_sprite == null:
		return
	var tw := create_tween()
	tw.set_trans(ENTRY_TRANS)
	tw.set_ease(ENTRY_EASE)
	tw.tween_property(_hands_sprite, "position:y", _hands_rest_position.y, ENTRY_TIME)
	await tw.finished
	_layout_offer_slots()

# Still used by the machine's stash-discard drag (drop a stash item on the dealer).
func has_dealer_drop_point(global_pos: Vector2) -> bool:
	return _dealer_hit_rect().has_point(global_pos)

# Offers are tap-to-select (no drag-to-buy): tapping shows the item's hints and
# arms the TAKE button with that item.
func _on_offer_icon_input(event: InputEvent, id: String, kind: String) -> void:
	if Engine.is_editor_hint() or kind != "offer":
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		_select_offer(id)

func _select_offer(id: String) -> void:
	_selected_offer_id = id
	for offer_id in _offer_icons:
		var icon := _offer_icons[offer_id] as Control
		if icon != null and is_instance_valid(icon):
			icon.scale = Vector2(1.18, 1.18) if String(offer_id) == id else Vector2.ONE
	_set_speech_hints(id)
	if _items_stage and _look_text_button != null:
		_look_text_button.disabled = false

func _dealer_hit_rect() -> Rect2:
	if _side == "left":
		return left_dealer_drop_rect
	return right_dealer_drop_rect

func _bump_dealer() -> void:
	var start_x := _dealer_root.position.x
	var tw := create_tween()
	tw.tween_property(_dealer_root, "position:x", start_x + (3.0 if _side == "left" else -3.0), 0.04)
	tw.tween_property(_dealer_root, "position:x", start_x + (-3.0 if _side == "left" else 3.0), 0.04)
	tw.tween_property(_dealer_root, "position:x", start_x, 0.05)
