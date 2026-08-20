extends Control

## Pacte is the run's card ritual. The background and emplacement art are
## authored at the game's 160x320 virtual resolution; card fronts are composed
## from the supplied sheets so every pool entry can carry its own icon metadata.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CARD_SIZE := Vector2(39.0, 61.0)
const CARD_POSITIONS: Array[Vector2] = [
	Vector2(10.0, 174.0), Vector2(61.0, 174.0), Vector2(112.0, 174.0),
]
const AUGMENT_DROP_RECT := Rect2(28.0, 256.0, 25.0, 36.0)
const POWER_DROP_RECT := Rect2(107.0, 256.0, 25.0, 36.0)
const CHOSEN_CARD_SIZE := Vector2(21.0, 33.0)
const CHOSEN_CARD_MARGIN := 2.0
const SELECTION_PREVIEW_TIME := 0.24
const PATTERN_RECOGNITION_ID := "augment_pattern_recognition"
const PATTERN_RECOGNITION_FRAME_COUNT := 5
const PATTERN_RECOGNITION_FRAME_PITCH := 39.0
const PATTERN_RECOGNITION_FPS := 7.0
const HOW_TO_CHEAT_ID := "augment_how_to_cheat"
const HOW_TO_CHEAT_FRAME_FPS := 6.0
const HOW_TO_CHEAT_FRAME_RECTS: Array[Rect2] = [
	Rect2(10.0, 744.0, 18.0, 20.0), Rect2(49.0, 748.0, 18.0, 20.0),
	Rect2(88.0, 751.0, 18.0, 20.0), Rect2(127.0, 754.0, 18.0, 20.0),
	Rect2(166.0, 758.0, 18.0, 20.0), Rect2(205.0, 761.0, 18.0, 20.0),
	Rect2(244.0, 763.0, 18.0, 20.0),
]
const GLITCH_AUGMENT_ID := "augment_glitch_2"
const GLITCH_CARD_TICK_INTERVAL := 0.62
const GLITCH_CARD_CHANCE := 0.42
## One source of truth with the draw that keeps these out of the tutorial's pool.
static var REWARD_AMP_CARD_IDS: Array[String] = PacteCards.reward_amp_ids()
const REWARD_AMP_PICKER_RECT := Rect2(10.0, 124.0, 140.0, 58.0)
# Pacte's authored split art is intentionally kept as full-canvas pieces. The
# current exports include decorative bleed around the old 160x320 play area, so
# each frame is centered around the native canvas and kept at source-pixel scale.
# The viewport/phone is responsible for trimming that bleed; gameplay geometry
# remains in the original 160x320 coordinate space.
const AUGMENT_DECK_ASSET := "pacte_scene/augment_deck.png"
const POWER_DECK_ASSET := "pacte_scene/power_deck.png"
const DEALER_ASSET := "pacte_scene/dealer.png"
const DEALER_BUBBLE_ASSET := "pacte_scene/dealer_bubble.png"
const DEALER_TEXT_FRAME_COUNT := 2
const DEALER_AUGMENT_FRAME := 0
const DEALER_POWER_FRAME := 1
const TABLE_ASSET := "pacte_scene/table.png"
const DECK_FRAME_COUNT := 1
const DECK_FRAME := 0
const EMPLACEMENT_FRAME_COUNT := 2
const EMPLACEMENT_SELECTING_FRAME := 0
const EMPLACEMENT_DROP_FRAME := 1
const FACE_DOWN_SHUFFLE_TIME := 0.24
const FACE_DOWN_SHUFFLE_OFFSET := 2.0
const DEALER_PROMPT_FONT_SIZE := 5
# Compact speech bubble sits between the dealer prompt and the card row, like a
# small information bubble attached to the inspected card. Keep enough height
# for wrapped descriptions while leaving the drag prompt and cards unobstructed.
const DESCRIPTION_BUBBLE_RECT := Rect2(5.0, 145.0, 50.0, 28.0)
# Title over body. The y here is only a starting point: _preview_card centres the pair as
# one block once it knows how many rows the blurb wrapped to (see _layout_description).
const DESCRIPTION_TITLE_RECT := Rect2(2.0, 3.0, 46.0, 7.0)
const DESCRIPTION_TEXT_RECT := Rect2(3.0, 10.0, 44.0, 16.0)
const DESCRIPTION_TITLE_FONT_SIZE := 4
const DESCRIPTION_FONT_SIZE := 3
const DESCRIPTION_BUBBLE_GAP := 1.0
const DEALER_BUBBLE_RECT := Rect2(92.0, 21.0, 48.0, 30.0)
const PHASE_LABEL_RECT := Rect2(61.0, 79.0, 36.0, 34.0)
const INSTRUCTION_RECT := Rect2(5.0, 238.0, 150.0, 10.0)
const BG_ASSET := "pacte_scene/bg.png"
const AUGMENT_EMPLACEMENT_ASSET := "pacte_scene/augment_card.png"
const POWER_EMPLACEMENT_ASSET := "pacte_scene/power_card.png"
const POWER_REPLACEMENT_PICKER_SCRIPT := preload("res://scenes/power_replacement_picker.gd")

const BACKGROUND_Z_INDEX := 0
const DEALER_Z_INDEX := 1
const TABLE_Z_INDEX := 2
const ART_Z_INDEX := 3
const UI_Z_INDEX := 4
const SELECTED_CARDS_Z_INDEX := 5

const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_GOLD := Color(1.0, 0.86, 0.36)
const TEXT_COLOR := Color(0.88, 0.98, 1.0)
const DEALER_TEXT_COLOR := Color(1.0, 0.6, 0.6)
const AUGMENT_PROMPT_COLOR := Color(0.42, 1.0, 0.95)
const DRAG_COLOR := Color(0.42, 1.0, 0.95, 0.95)
const DRAG_SLOP := 4.0

var _background: Sprite2D = null
var _table: Sprite2D = null
var _augment_deck: Sprite2D = null
var _power_deck: Sprite2D = null
var _dealer_sprite: Sprite2D = null
var _dealer_bubble: Sprite2D = null
var _augment_emplacement: Sprite2D = null
var _power_emplacement: Sprite2D = null
var _emplacement: Sprite2D = null
var _chosen_cards_layer: Control = null
var _description_bubble: Panel = null
var _description_title: Label = null
var _description_text: Label = null
var _phase_label: Label = null
var _instruction: Label = null
var _drop_label: Label = null
var _augment_drop_label: Label = null
var _power_drop_label: Label = null

var _card_buttons: Dictionary = {}
var _card_views: Dictionary = {}
var _chosen_card_views: Dictionary = {}
var _revealed: Dictionary = {}
var _offer_ids: Array[String] = []
var _pool_kind := "augment"
var _chosen_augment_id := ""
var _preview_id := ""
var _reward_amp_picker: Control = null
var _power_replacement_picker: Variant = null
var _dragging := false
var _drag_id := ""
var _drag_index := -1
var _drag_origin := Vector2.ZERO
var _press_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_origin_z := 0
var _selection_locked := false
var _reveal_generation := 0
var _deck_tween: Tween = null

## Reuse the authored Pacte room for a between-machine single-deck route without
## bringing the full two-pool ritual back. The route scene owns the selectable
## cards; this scene contributes only its background, dealer, table and the
## matching deck/emplacement art.
func configure_route_artwork(kind: String) -> void:
	var show_augment := kind == "augment"
	var show_power := kind == "power"
	if kind != "" and not show_augment and not show_power:
		return
	_close_reward_amp_picker()
	if _augment_deck != null:
		_augment_deck.visible = show_augment
	if _power_deck != null:
		_power_deck.visible = show_power
	if _augment_emplacement != null:
		_augment_emplacement.visible = show_augment
	if _power_emplacement != null:
		_power_emplacement.visible = show_power
	_emplacement = _augment_emplacement if show_augment else _power_emplacement
	if _emplacement != null:
		_emplacement.frame = EMPLACEMENT_SELECTING_FRAME
	if _dealer_bubble != null:
		_dealer_bubble.frame = DEALER_AUGMENT_FRAME if show_augment else DEALER_POWER_FRAME
		_dealer_bubble.visible = show_augment or show_power
	if _chosen_cards_layer != null:
		_chosen_cards_layer.visible = false
	if _description_bubble != null:
		_description_bubble.visible = false
	if _phase_label != null:
		_phase_label.visible = false
	if _instruction != null:
		_instruction.visible = false
	if _augment_drop_label != null:
		_augment_drop_label.visible = false
	if _power_drop_label != null:
		_power_drop_label.visible = false
	for value in _card_buttons.values():
		var card_button := value as CanvasItem
		if card_button != null:
			card_button.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

## Route build scenes use the same authored card faces as Pacte while keeping
## their selection state in the route scene. These helpers let the route scene
## compose cards above this artwork without reopening Pacte's run ritual.
func make_route_card_view(card_id: String, kind: String) -> Control:
	return _make_card_view(card_id, kind, true)

func make_route_selected_card_view(card_id: String, kind: String) -> Control:
	return _make_minimized_card_view(card_id, kind)

func set_route_emplacement_frame(kind: String, drop_hint: bool) -> void:
	var target := _augment_emplacement if kind == "augment" else _power_emplacement
	if target == null:
		return
	target.frame = EMPLACEMENT_DROP_FRAME if drop_hint else EMPLACEMENT_SELECTING_FRAME

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_overlay_ui()
	_restore_saved_selection()
	call_deferred("_restore_power_replacement")
	# Inert unless the played tutorial is running (issue #105). The autoload is not a
	# @tool script, so it does not exist in an editor preview of this scene. A
	# route-build instance is artwork only and must not attach a blocking tutorial
	# overlay to the selectable route cards.
	if not Engine.is_editor_hint() and not _is_route_artwork_context():
		Tutorial.attach(self, "pacte")

func _is_route_artwork_context() -> bool:
	var destination := String(RunStateStore.routeDestination)
	return destination == "augment" or destination == "power"

## Tutorial anchors (issue #105) — see machine_scene.tutorial_anchor.
func tutorial_anchor(id: String) -> Rect2:
	match id:
		"cards":
			# The whole play area, not just the dealt row: a Pacte card is DRAGGED from
			# the row down into its slot, so the ring has to cover the path or the
			# tutorial's mask stops the drag halfway and there is no way to choose.
			var first: Vector2 = CARD_POSITIONS[0]
			var last: Vector2 = CARD_POSITIONS[CARD_POSITIONS.size() - 1]
			var row := Rect2(first, Vector2(last.x + CARD_SIZE.x - first.x, CARD_SIZE.y))
			return row.merge(AUGMENT_DROP_RECT).merge(POWER_DROP_RECT)
	return Rect2()

func _build_background() -> void:
	_background = _full_canvas_sprite(BG_ASSET, BACKGROUND_Z_INDEX)
	_background.name = "PacteBackground"
	add_child(_background)
	move_child(_background, 0)
	_dealer_sprite = _full_canvas_sprite(DEALER_ASSET, DEALER_Z_INDEX)
	_dealer_sprite.name = "PacteDealer"
	add_child(_dealer_sprite)
	_table = _full_canvas_sprite(TABLE_ASSET, TABLE_Z_INDEX)
	_table.name = "PacteTable"
	add_child(_table)
	_augment_deck = _full_canvas_sprite(AUGMENT_DECK_ASSET, ART_Z_INDEX)
	_augment_deck.name = "AugmentDeck"
	_configure_native_sheet(_augment_deck, DECK_FRAME_COUNT)
	add_child(_augment_deck)
	_power_deck = _full_canvas_sprite(POWER_DECK_ASSET, ART_Z_INDEX)
	_power_deck.name = "PowerDeck"
	_configure_native_sheet(_power_deck, DECK_FRAME_COUNT)
	add_child(_power_deck)
	_dealer_bubble = _full_canvas_sprite(DEALER_BUBBLE_ASSET, ART_Z_INDEX)
	_dealer_bubble.name = "DealerBubble"
	_configure_native_sheet(_dealer_bubble, DEALER_TEXT_FRAME_COUNT)
	add_child(_dealer_bubble)
	_augment_emplacement = _full_canvas_sprite(AUGMENT_EMPLACEMENT_ASSET, ART_Z_INDEX)
	_augment_emplacement.name = "SelectedCardEmplacement"
	_configure_native_sheet(_augment_emplacement, EMPLACEMENT_FRAME_COUNT)
	add_child(_augment_emplacement)
	_power_emplacement = _full_canvas_sprite(POWER_EMPLACEMENT_ASSET, ART_Z_INDEX)
	_power_emplacement.name = "PowerCardEmplacement"
	_configure_native_sheet(_power_emplacement, EMPLACEMENT_FRAME_COUNT)
	add_child(_power_emplacement)
	_emplacement = _augment_emplacement
	_set_emplacement(AUGMENT_EMPLACEMENT_ASSET)
	_set_deck_visible("augment")
	_chosen_cards_layer = Control.new()
	_chosen_cards_layer.name = "ChosenCardsLayer"
	_chosen_cards_layer.position = Vector2.ZERO
	_chosen_cards_layer.size = CANVAS_SIZE
	_chosen_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chosen_cards_layer.z_index = SELECTED_CARDS_Z_INDEX
	add_child(_chosen_cards_layer)

func _full_canvas_sprite(asset: String, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Assets.texture(asset)
	sprite.centered = false
	sprite.position = _native_art_position(sprite.texture, 1)
	sprite.z_index = z
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _configure_native_sheet(sprite: Sprite2D, frame_count: int) -> void:
	if sprite == null or sprite.texture == null:
		return
	var safe_frame_count := maxi(frame_count, 1)
	sprite.centered = false
	sprite.hframes = safe_frame_count
	sprite.vframes = 1
	sprite.frame = 0
	# Do not resize a bleed-aware export to the gameplay canvas. Its central
	# 160x320 area must retain the authored pixel scale, while the extra artwork
	# is allowed to fall outside the phone's viewport naturally.
	sprite.scale = Vector2.ONE
	sprite.position = _native_art_position(sprite.texture, safe_frame_count)

func _native_art_position(texture: Texture2D, frame_count: int) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var safe_frame_count := maxi(frame_count, 1)
	var frame_size := Vector2(
		float(texture.get_width()) / float(safe_frame_count),
		float(texture.get_height()))
	# Source art is authored on whole pixels. Round the centering offset so an
	# odd-sized future bleed never introduces a half-pixel filter/blur shift.
	return Vector2(
		roundf((CANVAS_SIZE.x - frame_size.x) * 0.5),
		roundf((CANVAS_SIZE.y - frame_size.y) * 0.5))

func _build_overlay_ui() -> void:
	_phase_label = _label("PacteTitle", PHASE_LABEL_RECT, DEALER_PROMPT_FONT_SIZE,
		AUGMENT_PROMPT_COLOR)
	_phase_label.text = "PACTE"
	_phase_label.size = PHASE_LABEL_RECT.size
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_label.clip_text = true
	_phase_label.z_index = UI_Z_INDEX + 1
	_phase_label.visible = false
	_instruction = _label("Instruction", INSTRUCTION_RECT, 5, TEXT_COLOR)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.z_index = UI_Z_INDEX

	_description_bubble = Panel.new()
	_description_bubble.name = "OddsTableDescriptionBubble"
	_description_bubble.position = DESCRIPTION_BUBBLE_RECT.position
	_description_bubble.size = DESCRIPTION_BUBBLE_RECT.size
	_description_bubble.z_index = UI_Z_INDEX
	_description_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_bubble.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(NEON_GOLD))
	add_child(_description_bubble)
	_description_title = _label("CardTitle", DESCRIPTION_TITLE_RECT,
		DESCRIPTION_TITLE_FONT_SIZE, NEON_GOLD, _description_bubble)
	_description_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_title.clip_text = true
	_description_text = _label("CardDescription", DESCRIPTION_TEXT_RECT,
		DESCRIPTION_FONT_SIZE, TEXT_COLOR, _description_bubble)
	_description_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Centred in the space UNDER the title, not pinned to the top of it. The bubble is a
	# fixed 50x28 box but the blurbs run one to three lines, so a top-pinned body left the
	# short ones floating above eight px of empty panel.
	_description_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_text.clip_text = true
	_description_bubble.visible = false

	# The hint belongs to the emplacement itself. At native resolution the slot is
	# only 25 px wide, so word wrapping keeps both words inside its card frame.
	_augment_drop_label = _drop_hint_label(
		"DropHere", Rect2(28.0, 256.0, 25.0, 36.0))
	_power_drop_label = _drop_hint_label(
		"PowerDropHere", Rect2(107.0, 256.0, 25.0, 36.0))
	_drop_label = _augment_drop_label
	_set_drop_hint_visible(false)

func _restore_saved_selection() -> void:
	if not RunStateStore.pacte_active():
		_instruction.text = "PACTE IS CLOSED"
		return
	# Cards chosen on an earlier visit are NOT re-shown: once the machine has
	# started, the ritual presents a clean table while the earlier picks keep
	# their effects in the active run. Only this visit's staged augment returns.
	var saved_augment := String(RunStateStore.pacteSelectedAugmentId)
	var augment_offer := _offer_array(RunStateStore.pacteOfferAugmentIds)
	# Diamond (issue #111) suppresses the augment pool when this run-start ritual
	# resolves its card rules; an empty pool is still a deliberate modifier state.
	if saved_augment != "" or augment_offer.is_empty():
		if saved_augment != "":
			_chosen_augment_id = saved_augment
			_show_chosen_card(saved_augment, "augment")
		_pool_kind = "power"
		_set_emplacement(POWER_EMPLACEMENT_ASSET)
		_show_pool(_pool_kind, _offer_array(RunStateStore.pacteOfferPowerIds))
	else:
		_show_pool("augment", augment_offer)

func _offer_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(String(item))
	return result

func _set_emplacement(asset: String) -> void:
	var target := _augment_emplacement if asset == AUGMENT_EMPLACEMENT_ASSET else _power_emplacement
	if target == null:
		return
	_emplacement = target
	_configure_native_sheet(_emplacement, EMPLACEMENT_FRAME_COUNT)
	_emplacement.frame = EMPLACEMENT_SELECTING_FRAME
	_sync_emplacement_visibility()

func _sync_emplacement_visibility() -> void:
	if _augment_emplacement != null:
		_augment_emplacement.visible = _pool_kind == "augment" or _chosen_augment_id != ""
	if _power_emplacement != null:
		_power_emplacement.visible = _pool_kind == "power"

func _show_chosen_card(card_id: String, kind: String) -> void:
	if _chosen_cards_layer == null or card_id == "":
		return
	var existing := _chosen_card_views.get(kind, null) as Control
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
	var card := _make_minimized_card_view(card_id, kind)
	if card == null:
		return
	card.name = "Chosen%sCard" % kind.capitalize()
	var drop_rect := AUGMENT_DROP_RECT if kind == "augment" else POWER_DROP_RECT
	card.position = drop_rect.position + (drop_rect.size - CHOSEN_CARD_SIZE) * 0.5
	_chosen_cards_layer.add_child(card)
	_chosen_card_views[kind] = card

func _make_minimized_card_view(card_id: String, kind: String) -> Control:
	var entry := PacteCards.card(card_id)
	if entry.is_empty():
		return null
	var card := Control.new()
	card.size = CHOSEN_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var front := TextureRect.new()
	front.name = "Front"
	front.texture = UiKit.atlas(PacteCards.CARD_SHEET if kind == "augment" else PacteCards.POWER_SHEET,
		PacteCards.AUGMENT_FRONT_RECT if kind == "augment" else PacteCards.POWER_FRONT_RECT)
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.stretch_mode = TextureRect.STRETCH_SCALE
	front.position = Vector2.ZERO
	front.size = CHOSEN_CARD_SIZE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(front)
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if icon_rect.size.x > 0.0 and icon_rect.size.y > 0.0:
		var available := CHOSEN_CARD_SIZE - Vector2(CHOSEN_CARD_MARGIN * 2.0, CHOSEN_CARD_MARGIN * 2.0)
		var icon_scale := minf(available.x / icon_rect.size.x,
			available.y / icon_rect.size.y)
		var icon_size := icon_rect.size * icon_scale
		var icon := _make_card_icon(card_id, entry, icon_rect, icon_size)
		_set_card_icon_position(icon, (CHOSEN_CARD_SIZE - icon_size) * 0.5)
		if icon is Control:
			(icon as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	_attach_glitch_card_fx(card, card_id)
	return card

func _show_pool(kind: String, ids: Array[String]) -> void:
	_pool_kind = kind
	_reveal_generation += 1
	_clear_cards()
	_offer_ids = ids.duplicate()
	_set_emplacement(AUGMENT_EMPLACEMENT_ASSET if kind == "augment" else POWER_EMPLACEMENT_ASSET)
	_sync_emplacement_visibility()
	_set_deck_visible(kind)
	_drop_label = _augment_drop_label if kind == "augment" else _power_drop_label
	_set_drop_hint_visible(false)
	_description_bubble.visible = false
	_set_dealer_text_frame(kind)
	_phase_label.visible = false
	_phase_label.position = PHASE_LABEL_RECT.position
	_phase_label.size = PHASE_LABEL_RECT.size
	_instruction.text = "TAP TO INSPECT  /  DRAG TO THE SLOT"
	for index in _offer_ids.size():
		_build_card(_offer_ids[index], index)
	_reveal_cards(_reveal_generation)

func _set_dealer_text_frame(kind: String) -> void:
	if _dealer_bubble == null:
		return
	_dealer_bubble.frame = DEALER_AUGMENT_FRAME if kind == "augment" else DEALER_POWER_FRAME
	_dealer_bubble.visible = true

func _build_card(card_id: String, index: int) -> void:
	var button := Button.new()
	button.name = "Card_%s" % card_id
	button.position = CARD_POSITIONS[index]
	button.size = CARD_SIZE
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 10
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.gui_input.connect(_on_card_gui_input.bind(card_id, index, button))
	add_child(button)
	_card_buttons[card_id] = button
	var view := _make_card_view(card_id, _pool_kind)
	button.add_child(view)
	_card_views[card_id] = view
	_revealed[card_id] = false

func _make_card_view(card_id: String, kind: String, face_up := false) -> Control:
	var view := Control.new()
	view.name = "CardArt"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := TextureRect.new()
	back.name = "Back"
	back.texture = UiKit.atlas(PacteCards.sheet_for_pool(kind), PacteCards.back_rect_for_pool(kind))
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.size = CARD_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.visible = not face_up
	view.add_child(back)
	var front := TextureRect.new()
	front.name = "Front"
	front.texture = UiKit.atlas(PacteCards.CARD_SHEET if kind == "augment" else PacteCards.POWER_SHEET,
		PacteCards.AUGMENT_FRONT_RECT if kind == "augment" else PacteCards.POWER_FRONT_RECT)
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.size = CARD_SIZE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.visible = face_up
	view.add_child(front)
	var entry := PacteCards.card(card_id)
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if icon_rect.size.x > 0.0 and icon_rect.size.y > 0.0:
		var icon := _make_card_icon(card_id, entry, icon_rect, icon_rect.size)
		_set_card_icon_position(icon, Vector2((CARD_SIZE.x - icon_rect.size.x) * 0.5,
			(CARD_SIZE.y - icon_rect.size.y) * 0.5))
		if icon is Control:
			(icon as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(icon as CanvasItem).visible = face_up
		view.add_child(icon)
	_attach_glitch_card_fx(view, card_id)
	return view

## GLITCH 2 has no authored icon. Its card still occasionally tears for a few
## frames so the empty card face reads as intentional rather than unfinished.
func _attach_glitch_card_fx(view: Control, card_id: String) -> void:
	if card_id != GLITCH_AUGMENT_ID:
		return
	var fx := Control.new()
	fx.name = "GlitchFx"
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 3
	for index in 3:
		var strip := ColorRect.new()
		strip.name = "Tear%d" % index
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.visible = false
		fx.add_child(strip)
	view.add_child(fx)
	var timer := Timer.new()
	timer.name = "GlitchTimer"
	timer.wait_time = GLITCH_CARD_TICK_INTERVAL
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_glitch_card_tick.bind(view, fx))
	view.add_child(timer)

func _glitch_card_tick(view: Control, fx: Control) -> void:
	if not is_instance_valid(view) or not is_instance_valid(fx):
		return
	var front := view.get_node_or_null("Front") as CanvasItem
	if front != null and not front.visible:
		return
	if randf() > GLITCH_CARD_CHANCE:
		return
	view.position = Vector2(randf_range(-1.0, 1.0), 0.0)
	for child in fx.get_children():
		var strip := child as ColorRect
		if strip == null:
			continue
		strip.position = Vector2(randf_range(-2.0, 2.0), randf_range(6.0, 54.0))
		strip.size = Vector2(maxf(1.0, view.size.x + 4.0), randf_range(1.0, 2.0))
		strip.color = Color(0.2 + randf() * 0.8, 0.3 + randf() * 0.7, 1.0, 0.8)
		strip.visible = true
	var tween := create_tween()
	tween.tween_interval(0.07)
	tween.tween_callback(_clear_glitch_card_fx.bind(view, fx))

func _clear_glitch_card_fx(view: Control, fx: Control) -> void:
	if not is_instance_valid(view) or not is_instance_valid(fx):
		return
	view.position = Vector2.ZERO
	for child in fx.get_children():
		var strip := child as CanvasItem
		if strip != null:
			strip.visible = false

func _make_card_icon(card_id: String, entry: Dictionary, source_rect: Rect2,
		display_size: Vector2) -> Node:
	if card_id != PATTERN_RECOGNITION_ID and card_id != HOW_TO_CHEAT_ID:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = UiKit.atlas(String(entry.get("sheet", "")), source_rect)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = display_size
		return icon

	# Both authored animated icons use their own atlas regions so the Pacte card
	# shows one pose at a time rather than the whole source strip.
	var animated_icon := AnimatedSprite2D.new()
	animated_icon.name = "Icon"
	var sprite_frames := SpriteFrames.new()
	var animation_name := &"pattern" if card_id == PATTERN_RECOGNITION_ID else &"cheat"
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.set_animation_speed(animation_name,
		PATTERN_RECOGNITION_FPS if card_id == PATTERN_RECOGNITION_ID else HOW_TO_CHEAT_FRAME_FPS)
	var sheet := Assets.texture(String(entry.get("sheet", "")))
	var frame_rects: Array[Rect2] = []
	if card_id == PATTERN_RECOGNITION_ID:
		for frame_index in PATTERN_RECOGNITION_FRAME_COUNT:
			frame_rects.append(Rect2(
				source_rect.position + Vector2(PATTERN_RECOGNITION_FRAME_PITCH * frame_index, 0.0),
				source_rect.size))
	else:
		# The authored strip already reads front-to-back; play it as drawn.
		frame_rects = HOW_TO_CHEAT_FRAME_RECTS.duplicate()
	for frame_rect in frame_rects:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = frame_rect
		sprite_frames.add_frame(animation_name, frame)
	animated_icon.sprite_frames = sprite_frames
	animated_icon.animation = animation_name
	animated_icon.autoplay = animation_name
	animated_icon.centered = false
	var scale := display_size / source_rect.size
	animated_icon.scale = scale
	animated_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_icon.play(animation_name)
	return animated_icon

func _set_card_icon_position(icon: Node, position: Vector2) -> void:
	if icon is Control:
		(icon as Control).position = position
	elif icon is Node2D:
		(icon as Node2D).position = position

func _show_reward_amp_picker() -> void:
	_close_reward_amp_picker()
	var picker := Control.new()
	picker.name = "RewardAmpPicker"
	picker.size = CANVAS_SIZE
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.z_index = 50
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.size = CANVAS_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(dim)
	add_child(picker)
	var symbols: Array[String] = []
	for raw_symbol in Symbols.BASE_SYMBOL_CYCLE:
		var symbol_id := String(raw_symbol)
		if symbol_id != "flatline":
			symbols.append(symbol_id)
	SymbolPicker.build_symbol_picker_panel(picker, symbols, "", REWARD_AMP_PICKER_RECT,
		Callable(self, "_on_reward_amp_symbol_picked"),
		Callable(self, "_cancel_reward_amp_picker"), true, false, false)
	_reward_amp_picker = picker

func _on_reward_amp_picker_input(_event: InputEvent) -> void:
	# Reward Amplification is a mandatory choice. The full-screen blocker consumes
	# taps outside the symbol buttons, but an outside tap must not dismiss the picker.
	pass

func _cancel_reward_amp_picker() -> void:
	_close_reward_amp_picker()

func _close_reward_amp_picker() -> void:
	if _reward_amp_picker != null:
		_reward_amp_picker.queue_free()
		_reward_amp_picker = null

func _on_reward_amp_symbol_picked(symbol_id: String) -> void:
	MetaStateStore.set_reward_amp_symbol(symbol_id)
	_close_reward_amp_picker()


func _set_deck_visible(_kind: String) -> void:
	if _augment_deck != null:
		_configure_native_sheet(_augment_deck, DECK_FRAME_COUNT)
		_augment_deck.visible = true
		_augment_deck.frame = DECK_FRAME
	if _power_deck != null:
		_configure_native_sheet(_power_deck, DECK_FRAME_COUNT)
		_power_deck.visible = true
		_power_deck.frame = DECK_FRAME

func _shuffle_active_deck() -> void:
	var deck := _augment_deck if _pool_kind == "augment" else _power_deck
	if deck == null:
		return
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	var native_position := _native_art_position(deck.texture, maxi(int(deck.hframes), 1))
	deck.position = native_position
	deck.rotation = 0.0
	_deck_tween = create_tween()
	_deck_tween.tween_property(deck, "position", native_position + Vector2(-1.0, 0.0), 0.05)
	_deck_tween.tween_property(deck, "position", native_position + Vector2(1.0, 0.0), 0.05)
	_deck_tween.tween_property(deck, "position", native_position, 0.05)

func _shuffle_face_down_cards(generation: int) -> void:
	if _offer_ids.is_empty():
		return
	for index in _offer_ids.size():
		if generation != _reveal_generation:
			return
		var card_id := _offer_ids[index]
		var button := _card_buttons.get(card_id, null) as Button
		if button == null:
			continue
		var origin := CARD_POSITIONS[index]
		var direction := -1.0 if index % 2 == 0 else 1.0
		var offset := Vector2(direction * FACE_DOWN_SHUFFLE_OFFSET, 0.0)
		var tween := create_tween()
		tween.tween_interval(float(index) * 0.02)
		tween.tween_property(button, "position", origin + offset, 0.06)
		tween.tween_property(button, "position", origin - offset, 0.06)
		tween.tween_property(button, "position", origin, 0.06)
	_shuffle_active_deck()
	await get_tree().create_timer(FACE_DOWN_SHUFFLE_TIME).timeout

func _reveal_cards(generation: int) -> void:
	await _shuffle_face_down_cards(generation)
	if generation != _reveal_generation or not is_inside_tree():
		return
	for index in _offer_ids.size():
		await get_tree().create_timer(0.08 * float(index + 1)).timeout
		if generation != _reveal_generation or not is_inside_tree():
			return
		_set_face_up(_offer_ids[index])
	if generation == _reveal_generation and is_inside_tree():
		_instruction.text = "TAP TO INSPECT  /  DRAG TO THE SLOT"

func _set_face_up(card_id: String) -> void:
	var view := _card_views.get(card_id, null) as Control
	if view == null:
		return
	var front := view.get_node_or_null("Front") as TextureRect
	var icon := view.get_node_or_null("Icon") as CanvasItem
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
			_begin_drag(card_id, index, button, get_global_mouse_position())
	elif event is InputEventScreenTouch and event.index == 0 and event.pressed:
		var touch_event := event as InputEventScreenTouch
		# Events delivered through gui_input are already local to the card button,
		# so lift the grabbed point back into canvas space. The mouse branch above
		# asks the viewport directly and is already in that space.
		_begin_drag(card_id, index, button, button.get_global_transform() * touch_event.position)

# Card buttons stop receiving GUI events once the pointer leaves their rect. Keep
# the drag on the scene root so releasing over either emplacement is reliable.
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
	# Store the grabbed point in the card parent's space. This keeps the exact
	# finger anchor even while the inspected card is scaled around its pivot.
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
	# Keep the odds explanation open while a card is only being inspected. It
	# closes when the drag gesture actually leaves the card.
	_description_bubble.visible = false
	_instruction.text = ""
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
	# A release is a completed drop attempt. Do not reopen the explanation bubble
	# after a missed slot; the next explicit tap will inspect the card again.
	_description_bubble.visible = false
	var drop_rect := AUGMENT_DROP_RECT if _pool_kind == "augment" else POWER_DROP_RECT
	# Accept the drop when the dragged card overlaps the authored slot. The
	# pointer is not necessarily at the card centre (especially after grabbing
	# an icon edge), so testing only the pointer would make valid drops miss.
	var dragged_rect := Rect2(dragged_card_position, CARD_SIZE)
	var drop_area := drop_rect.grow(4.0)
	if drop_area.intersects(dragged_rect) or drop_area.has_point(local_position):
		_accept_card(card_id)
	else:
		_instruction.text = "DRAG TO THE SLOT"

func _global_to_local(global_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_position

func _input_canvas_position(viewport_position: Vector2) -> Vector2:
	return make_canvas_position_local(viewport_position)

func _clamp_drag_position(button: Control, desired_position: Vector2) -> Vector2:
	# Screen-touch coordinates can briefly report outside the scaled viewport while
	# a finger is held at an edge. Clamp the transformed card rect so it never
	# visually spawns outside the native 160x320 canvas.
	var scale := Vector2(absf(button.scale.x), absf(button.scale.y))
	var visual_size := button.size * scale
	var pivot_offset := button.pivot_offset * (scale - Vector2.ONE)
	var minimum := pivot_offset
	var maximum := CANVAS_SIZE - visual_size + pivot_offset
	return Vector2(
		clampf(desired_position.x, minimum.x, maximum.x),
		clampf(desired_position.y, minimum.y, maximum.y))

func _preview_card(card_id: String) -> void:
	if not _offer_ids.has(card_id):
		return
	_preview_id = card_id
	var entry := PacteCards.card(card_id)
	_description_bubble.visible = true
	_description_title.text = String(entry.get("name", card_id))
	var description := String(entry.get("description", ""))
	if RunStateStore.pacteCostsActive:
		var purchase_ids: Array[String] = []
		if RunStateStore.pacteSelectedAugmentId != "":
			purchase_ids.append(RunStateStore.pacteSelectedAugmentId)
		purchase_ids.append(card_id)
		var cost := RunStateStore.pacte_card_cost(card_id)
		var remaining := RunStateStore.pacte_remaining_after(purchase_ids)
		description += "\nCOST: %dG  LEFT: %dG\n%s" % [
			cost, remaining, RunStateStore.run_price_label()]
	_description_text.text = description
	# Label expands to its font line height when text is assigned. Reapply the
	# authored rects after that update so the controls themselves stay inside the
	# compact panel as well as their glyphs.
	_layout_description()
	# Tapping a card replaces the generic prompt immediately, while the compact
	# description remains visible until the player starts dragging it.
	_instruction.text = "DRAG TO THE SLOT"
	for id in _offer_ids:
		var candidate := _card_buttons.get(id, null) as Button
		if candidate != null:
			candidate.scale = Vector2.ONE * (1.08 if id == card_id else 1.0)
			candidate.pivot_offset = CARD_SIZE * 0.5
	_position_description_bubble(card_id)

## Title over body, centred in the bubble as ONE block. The panel is a fixed 50x28 but the
## blurbs wrap to one, two or three lines, so a fixed title y left the short ones hanging
## above a dead strip of panel. Ask the label how many rows the wrap actually produced —
## nothing else knows, since word wrapping breaks where the words allow.
func _layout_description() -> void:
	var title_h := DESCRIPTION_TITLE_RECT.size.y
	var max_body_h := DESCRIPTION_BUBBLE_RECT.size.y - title_h - 2.0 # 1px border either side
	# Width first: a Label cannot report its wrap until it knows how wide it is.
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
	if _description_bubble == null:
		return
	_description_bubble.position = _description_bubble_position_for_card(card_id)

func _description_bubble_position_for_card(card_id: String) -> Vector2:
	var button := _card_buttons.get(card_id, null) as Button
	if button == null:
		return DESCRIPTION_BUBBLE_RECT.position
	var scale := Vector2(absf(button.scale.x), absf(button.scale.y))
	var visual_top_left := button.position - button.pivot_offset * (scale - Vector2.ONE)
	var visual_size := button.size * scale
	var desired := Vector2(
		visual_top_left.x + (visual_size.x - DESCRIPTION_BUBBLE_RECT.size.x) * 0.5,
		visual_top_left.y - DESCRIPTION_BUBBLE_RECT.size.y - DESCRIPTION_BUBBLE_GAP)
	var maximum := CANVAS_SIZE - DESCRIPTION_BUBBLE_RECT.size
	return Vector2(
		clampf(desired.x, 0.0, maximum.x),
		clampf(desired.y, 0.0, maximum.y))

func _accept_card(card_id: String) -> void:
	if _selection_locked:
		return
	_selection_locked = true
	if _pool_kind == "augment":
		if not RunStateStore.select_pacte_augment(card_id):
			_selection_locked = false
			return
		_chosen_augment_id = card_id
		_show_chosen_card(card_id, "augment")
		_show_pool("power", _offer_array(RunStateStore.pacteOfferPowerIds))
		if REWARD_AMP_CARD_IDS.has(card_id):
			_show_reward_amp_picker()
		_selection_locked = false
		return
	var threshold_visit := RunStateStore.runPhase == "pacte_threshold"
	var route_visit := threshold_visit and RunStateStore.routePacteVisit
	# These branches only decode legacy snapshots. New route build scenes never
	# enter Pacte and therefore never take a threshold or route visit branch.
	var target_round_visit := threshold_visit and RunStateStore.pacteTargetRoundVisit
	_show_chosen_card(card_id, "power")
	if not RunStateStore.stage_pacte_power_selection(card_id):
		if not RunStateStore.pendingPowerReplacement.is_empty():
			_instruction.text = "CHOOSE A POWER TO REMOVE"
			_show_power_replacement_picker()
			return
		var chosen_power := _chosen_card_views.get("power", null) as Control
		if chosen_power != null:
			chosen_power.queue_free()
		_chosen_card_views.erase("power")
		_selection_locked = false
		return
	await _finish_power_selection()

func _finish_power_selection() -> void:
	await get_tree().create_timer(SELECTION_PREVIEW_TIME).timeout
	if not is_inside_tree():
		return
	var threshold_visit := RunStateStore.runPhase == "pacte_threshold"
	var route_visit := threshold_visit and RunStateStore.routePacteVisit
	var target_round_visit := threshold_visit and RunStateStore.pacteTargetRoundVisit
	if route_visit:
		# Legacy route Pacte snapshots complete directly into the next machine.
		if not RunStateStore.finish_route_destination():
			_selection_locked = false
			_instruction.text = "NEXT MACHINE UNAVAILABLE"
			return
		SceneNav.change_to("res://scenes/machine_scene.tscn")
	elif target_round_visit:
		# Wealth-target visit: end the run as a between-target break and hand off to
		# the persistent dealer shop, whose START begins the next fresh run.
		if not RunStateStore.begin_target_round():
			_selection_locked = false
			_instruction.text = "DEALER VISIT UNAVAILABLE"
			return
		SceneNav.change_to("res://scenes/dealer_choice_scene.tscn" if RunStateStore.routeOfferPending \
			else "res://scenes/dealer_scene.tscn")
	elif threshold_visit:
		# Health-crossing visit: rejoin the shared between-run flow (odds table ->
		# dealer shop), the same one a plain flatline uses, instead of the mid-run
		# dealer offer. The flatline already spent the neuron and set "over".
		if not RunStateStore.enter_between_run_dealer_after_flatline():
			_selection_locked = false
			_instruction.text = "DEALER VISIT UNAVAILABLE"
			return
		SceneNav.change_to("res://scenes/dealer_choice_scene.tscn" if RunStateStore.routeOfferPending \
			else "res://scenes/dealer_scene.tscn")
	else:
		SceneNav.change_to("res://scenes/machine_scene.tscn")

func _restore_power_replacement() -> void:
	if RunStateStore.pendingPowerReplacement.is_empty():
		return
	var candidate := String(RunStateStore.pendingPowerReplacement.get("cardId", ""))
	if candidate == "" or not _offer_ids.has(candidate):
		RunStateStore.cancel_power_replacement()
		return
	_selection_locked = true
	_show_chosen_card(candidate, "power")
	_instruction.text = "CHOOSE A POWER TO REMOVE"
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
	if not RunStateStore.complete_pacte_selection("", candidate, removed_power_id):
		_cancel_power_replacement()
		_instruction.text = "POWER REPLACEMENT REFUSED"
		return
	await _finish_power_selection()

func _cancel_power_replacement() -> void:
	RunStateStore.cancel_power_replacement()
	_selection_locked = false
	var chosen_power := _chosen_card_views.get("power", null) as Control
	if chosen_power != null:
		chosen_power.queue_free()
	_chosen_card_views.erase("power")
	_instruction.text = "DRAG TO THE SLOT"

func _clear_cards() -> void:
	for child in get_children():
		if child is Button and String(child.name).begins_with("Card_"):
			child.queue_free()
	_card_buttons.clear()
	_card_views.clear()
	_revealed.clear()
	_offer_ids = []
	_preview_id = ""

func _drop_hint_label(label_name: String, rect: Rect2) -> Label:
	var label := _label(label_name, rect, 3, DRAG_COLOR)
	label.text = "DROP HERE"
	# The wording is part of emplacement frame 1 now. Keep these nodes as hidden
	# scene-tooling anchors so older smoke helpers can still inspect their rects.
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.z_index = UI_Z_INDEX
	return label

func _set_drop_hint_visible(visible: bool) -> void:
	_drop_label = _power_drop_label if _pool_kind == "power" else _augment_drop_label
	if _augment_drop_label != null:
		_augment_drop_label.visible = false
	if _power_drop_label != null:
		_power_drop_label.visible = false
	if _emplacement != null:
		_emplacement.frame = EMPLACEMENT_DROP_FRAME if visible \
			else EMPLACEMENT_SELECTING_FRAME

func _label(label_name: String, rect: Rect2, font_size: int, color: Color,
		parent: Node = null) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	label.z_index = UI_Z_INDEX
	var font := Assets.font()
	if font != null:
		label.add_theme_font_override("font", font)
	# In the tree BEFORE the rect is assigned. A Control clamps an assigned size up to its
	# minimum, and a Label outside the tree measures that minimum with the DEFAULT 16px
	# theme font — theme overrides only reach the metric cache once the node has a tree —
	# so a 7px-tall title asked for 7 and quietly got 23.
	(parent if parent != null else self).add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label
