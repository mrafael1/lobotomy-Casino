@tool
extends Control

## In-run dealer scene (M3 polish) — port of src/screens/DealerShopScreen.tsx (run
## mode). The dealer's offered items rest on the counter; you DRAG an item onto the
## dealer to TAKE it, and DRAG a stash item onto the dealer to DISCARD it (freeing a
## slot). Selecting an item shows its one-word hints on the TV: green positiveHint,
## red negativeHint (from src/content/itemHints.ts — display only, no mechanics).
##
## Reached from the machine on Visit (RunStateStore.dealerPending); take/leave
## returns to the machine. All state goes through RunStateStore (accept/decline/
## discard), so the dealer's rules stay the vector-pinned ones in dealer.gd.
##
## PRE-RUN MODE (issue #21): the same scene also serves as the start-of-run
## consumable shop, reached from the start menu BEFORE a run exists. It's detected
## from RunStateStore.runPhase (no active run => pre-run), so the presentation is
## shared and only the item pool / transaction differs: offers are the Expo pre-run
## consumables (Consumables.LIST), dragging one onto the dealer BUYS it with wallet
## Lucidity (MetaStateStore), and LEAVE becomes START RUN — it begins the run with
## the purchased consumables and hands off to the machine.

const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const UPGRADES_SCENE := "res://scenes/upgrades_scene.tscn"
const ODDS_OVERLAY_SCENE := preload("res://scenes/odds_table_overlay.tscn")

# Counter geometry: Expo coords (1280x2560) / 8 -> the 160x320 canvas.
const CIRCLE_CX := [15.5, 37.5, 59.5, 81.5, 102.5, 124.5]
# Consumables stand on the white round dots of the counter (measured centre y ~= 206
# source px). Icons are small (issue #24 follow-up: they read as objects on the counter,
# not giant badges) and rest with their base on the dot. Stash icons reuse the shared
# Assets.STASH_ICON_SIZE so they match the machine scene stash.
const PRE_RUN_OFFER_ICON := 16.0
const RUN_OFFER_ICON := 16.0
const COUNTER_DOT_CY := 206.0 # measured centre of the counter's white round dots
const ITEM_TOP := COUNTER_DOT_CY - PRE_RUN_OFFER_ICON # icon base sits on the dot
const TV := { "left": 2.0, "top": 126.0, "width": 49.0, "height": 26.0 }
const DEALER_DROP_Y := 200.0 # release above this y = dropped "on the dealer"
const DRAG_SLOP := 4.0

# One-word TV hints (display only) — ports src/content/itemHints.ts.
@export_group("Run Balance")
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS

# Pre-run pool only (Consumables.LIST). In-run item_* hints live in
# in_run_dealer_offer.gd — the two scenes own separate pools (issue #31).
@export_group("Vague Item Hints")
@export var item_hints: Dictionary = {
	"cons_cigarette": { "pos": "PAIRS", "neg": "BLIND" },
	"cons_white_powder": { "pos": "SCRAMBLE", "neg": "HIDDEN" },
	"cons_focus": { "pos": "SHARP", "neg": "NO BRAIN" },
	"cons_syringe": { "pos": "POWERS", "neg": "RANDOM" },
	"cons_tea": { "pos": "RESTORE", "neg": "NONE" },
}
const FALLBACK_HINT := { "pos": "ODD", "neg": "PRICE" }

## Corrupted item names render purple (issue #33), sharing the #7/#37 rule and
## colour. The flagged-id set lives on HintLabel so both dealer scenes agree.
@export var corrupt_name_color: Color = Color(0.66, 0.33, 0.86)
## Authored name colour restored for non-corrupted items.
@export var name_color: Color = Color(0.0, 0.9, 1.0)

# New UI assets (issue #25). The settings sheet is 2 frames (normal, pressed).
const BUBBLE_ASSET := "ui/standard_bubble_text.png"
const SETTINGS_ASSET := "ui/settings.png"
const COIN_ASSET := "ui/coin.png"
const LUCIDITY_COLOR := Color(0.92, 0.86, 0.56)
const OFFER_PRICE_COIN_SIZE := 6.0
const BUTTON_TEXT_BOTTOM_MARGIN := 2.0

# Pre-run pool only (Consumables.LIST) — see item_hints note (issue #31).
const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_cigarette": "items/cigarette.png",
	"cons_white_powder": "items/white_powder.png",
	"cons_syringe": "items/consumable_placeholder.png",
	"cons_tea": "items/herbal_tea.png",
}

var _font: FontFile = null
var _tv_pos: Label = null
var _tv_neg: Label = null
var _name_label: Label = null   # selected item's name, shown UNDER its counter icon
var _offer_cx := {}             # id -> counter-circle x (to place the name under it)
var _item_nodes := {}           # offer id -> draggable Control (for selected highlight)
var _instruction: Label = null
var _instruction_bubble: Control = null # speech bubble holding the instruction text
var _message: Label = null
var _stash_holder: Control = null
var _portrait_sprite: Sprite2D = null
var _portrait_frame := 0
var _pre_run := false            # true => start-of-run consumable shop (issue #21)
var _post_run := false           # true => arrived from a finished run (issue #36)
var _odds_overlay: OddsTableOverlay = null # dealer odds table (issue #36)
var _credits_label: Label = null # wallet readout, pre-run only
var _background_sprite: Sprite2D = null
var _counter_sprite: Sprite2D = null
var _dealer_drop_zone: Control = null
var _options_button: TextureButton = null
var _options_overlay: OptionsOverlay = null
var _lab_button: Button = null
var _lab_label: Label = null
var _start_button: Button = null
var _start_label: Label = null
var _credits_row: Control = null
var _credits_coin: TextureRect = null
var _campaign_label: Label = null
var _offer_slots := []
var _stash_slot_nodes := []
var _offer_slots_by_id := {}

# Drag state (one item at a time).
var _drag_active := false
var _drag_node: Control = null
var _drag_id := ""
var _drag_kind := ""        # "offer" | "stash"
var _drag_home := Vector2.ZERO
var _drag_moved := false
var _press_pos := Vector2.ZERO

func _ready() -> void:
	_font = Assets.font()
	# No run in progress => this is the pre-run shop, not the in-run dealer visit.
	_pre_run = true if Engine.is_editor_hint() else RunStateStore.runPhase != "running"
	# A run just ended => this visit is the "what's next?" phase (issue #36).
	_post_run = (not Engine.is_editor_hint()) and _pre_run and RunStateStore.runPhase == "over"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_scene_nodes()
	_build_art()
	_build_tv()
	_build_offers()
	_build_stash()
	_build_hud()
	_restore_options_overlay_if_requested()
	_select("") # show instruction
	if _post_run:
		_setup_odds_phase()
	if not Engine.is_editor_hint():
		if not MetaStateStore.meta_changed.is_connected(_refresh_campaign_label):
			MetaStateStore.meta_changed.connect(_refresh_campaign_label)
		if _pre_run and not MetaStateStore.meta_changed.is_connected(_refresh_credits):
			MetaStateStore.meta_changed.connect(_refresh_credits)
		_refresh_credits()
	_refresh_campaign_label()

func _bind_scene_nodes() -> void:
	_background_sprite = get_node_or_null("Background")
	_portrait_sprite = get_node_or_null("DealerPortrait")
	_counter_sprite = get_node_or_null("Counter")
	_dealer_drop_zone = get_node_or_null("DealerDropZone")
	_tv_pos = get_node_or_null("TvPos")
	_tv_neg = get_node_or_null("TvNeg")
	_name_label = get_node_or_null("NameLabel")
	_instruction_bubble = get_node_or_null("InstructionBubble")
	_instruction = get_node_or_null("InstructionBubble/Instruction")
	_message = get_node_or_null("Message")
	_options_button = get_node_or_null("options")
	_options_overlay = get_node_or_null("OptionsOverlay") as OptionsOverlay
	_lab_button = get_node_or_null("LabButton")
	_lab_label = get_node_or_null("LabButtonLabel")
	_start_button = get_node_or_null("StartButton")
	_start_label = get_node_or_null("StartButton/StartLabel")
	_credits_row = get_node_or_null("CreditsRow")
	_credits_coin = get_node_or_null("CreditsRow/Coin")
	_credits_label = get_node_or_null("CreditsRow/CreditsLabel")
	_campaign_label = get_node_or_null("BottomHudLayer/neuron_number") as Label
	_offer_slots.clear()
	for i in range(1, 7):
		var slot := get_node_or_null("OfferSlot%d" % i)
		if slot != null:
			_offer_slots.append(slot)
	_stash_slot_nodes.clear()
	for i in range(1, maxi(1, max_consumable_slots) + 1):
		var slot := get_node_or_null("StashSlot%d" % i)
		if slot == null:
			slot = get_node_or_null("stash/StashSlot%d" % i)
		if slot != null:
			_stash_slot_nodes.append(slot)

func _clear_dynamic_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		if child.has_meta("_dealer_dynamic"):
			child.free()

func _configure_full_canvas_sprite(spr: Sprite2D, rel: String, hframes := 1, frame := 0) -> Sprite2D:
	if spr == null:
		return null
	if spr.texture == null:
		var tex := Assets.texture(rel, true)
		if tex == null:
			return spr
		spr.texture = tex
		spr.hframes = hframes
		spr.frame = frame
		spr.centered = false
		var frame_w := float(tex.get_width()) / float(hframes)
		spr.scale = Vector2(160.0 / frame_w, 320.0 / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return spr

func _full_canvas_sprite(rel: String, hframes := 1, frame := 0) -> Sprite2D:
	var tex := Assets.texture(rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	spr.position = Vector2.ZERO
	var frame_w := float(tex.get_width()) / float(hframes)
	spr.scale = Vector2(160.0 / frame_w, 320.0 / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	return spr

func _build_art() -> void:
	if _background_sprite != null or _portrait_sprite != null or _counter_sprite != null:
		_configure_full_canvas_sprite(_background_sprite, "dealer_shop_bg.png")
		_portrait_sprite = _configure_full_canvas_sprite(_portrait_sprite, "dealer_portrait.png", 2, 0)
		_configure_full_canvas_sprite(_counter_sprite, "dealer_shop_counter.png")
		return
	var bg := ColorRect.new() # wall colour behind any gap
	bg.color = Color(0.055, 0.03, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_full_canvas_sprite("dealer_shop_bg.png")
	_portrait_sprite = _full_canvas_sprite("dealer_portrait.png", 2, 0) # 2-frame sheet
	_full_canvas_sprite("dealer_shop_counter.png")

# Brief dealer reaction: swap the 2-frame portrait.
func _dealer_react() -> void:
	if _portrait_sprite == null:
		return
	_portrait_frame = 1 - _portrait_frame
	_portrait_sprite.frame = _portrait_frame

func _mk_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _build_tv() -> void:
	if _tv_pos != null or _tv_neg != null or _message != null or _name_label != null:
		_style_scene_label(_tv_pos, 8, Color(0.13, 0.77, 0.37))
		_style_scene_label(_tv_neg, 8, Color(0.94, 0.27, 0.27))
		_build_instruction_bubble()
		_style_scene_label(_message, 7, Color(1.0, 0.6, 0.6))
		if _message != null:
			_message.text = ""
		_style_scene_label(_name_label, 6, Color(0.0, 0.9, 1.0))
		if _name_label != null:
			_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_name_label.visible = false
		return
	# TV shows ONLY the green (+) / red (-) hints; the item NAME goes under its icon.
	# Same X as before; nudged up ~3.5px so the pair reads more vertically centred in the
	# TV window (issue #24 follow-up).
	_tv_pos = _mk_label(Vector2(TV["left"] + 3.0, TV["top"] + 2.5), 8, Color(0.13, 0.77, 0.37))
	_tv_neg = _mk_label(Vector2(TV["left"] + 3.0, TV["top"] + 11.5), 8, Color(0.94, 0.27, 0.27))
	_build_instruction_bubble()
	_message = _mk_label(Vector2(34.0, 50.0), 7, Color(1.0, 0.6, 0.6))
	_message.text = ""
	# Name label sits under the selected counter item (centred on its circle).
	_name_label = _mk_label(Vector2.ZERO, 6, Color(0.0, 0.9, 1.0))
	_name_label.size = Vector2(60.0, 9.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.visible = false

func _style_scene_label(l: Label, size: int, color: Color) -> void:
	if l == null:
		return
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)

# Top-centre "DRAG TO BUY" prompt rendered inside the standard speech-bubble asset
# (issue #25). The graphic and the pixel-font label are siblings so the text is crisp.
func _build_instruction_bubble() -> void:
	if _instruction_bubble != null:
		_instruction_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var graphic: TextureRect = get_node_or_null("InstructionBubble/BubbleGraphic")
		if graphic != null:
			graphic.texture = Assets.texture(BUBBLE_ASSET, true)
			graphic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			graphic.stretch_mode = TextureRect.STRETCH_SCALE
			graphic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _instruction != null:
			_instruction.text = _instruction_text()
			_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_style_scene_label(_instruction, 8, Color(0.12, 0.06, 0.16))
			_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	const BUBBLE_W := 80.0
	const BUBBLE_H := 30.0
	_instruction_bubble = Control.new()
	_instruction_bubble.size = Vector2(BUBBLE_W, BUBBLE_H)
	_instruction_bubble.position = Vector2((160.0 - BUBBLE_W) * 0.5, 10.0)
	_instruction_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_instruction_bubble)
	var graphic := TextureRect.new()
	graphic.texture = Assets.texture(BUBBLE_ASSET, true)
	graphic.size = _instruction_bubble.size
	graphic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	graphic.stretch_mode = TextureRect.STRETCH_SCALE
	graphic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_bubble.add_child(graphic)
	_instruction = Label.new()
	_instruction.text = _instruction_text()
	# Fill the whole bubble and centre both ways so the text sits dead centre of the
	# bubble asset (issue #24 follow-up).
	_instruction.size = _instruction_bubble.size
	_instruction.position = Vector2.ZERO
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_instruction.add_theme_font_override("font", _font)
	_instruction.add_theme_color_override("font_color", Color(0.12, 0.06, 0.16))
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_bubble.add_child(_instruction)

# The dealer's line for this visit: post-run he asks "what's next?" (issue #36).
func _instruction_text() -> String:
	if _post_run:
		return "WHAT'S NEXT?"
	return "DRAG TO BUY" if _pre_run else "DRAG ONE TO ME"

# ── dealer odds table (issue #36) ─────────────────────────────────────────────────
# Post-run only: the overlay opens on arrival with the fresh token budget. Once the
# player closes it the phase is finalized — it cannot be reopened until after the
# next run (upgrades are committed permanently on close).

func _setup_odds_phase() -> void:
	if not Engine.is_editor_hint() and RunStateStore.oddsPhaseCompleted:
		return
	_odds_overlay = ODDS_OVERLAY_SCENE.instantiate() as OddsTableOverlay
	add_child(_odds_overlay)
	_odds_overlay.closed.connect(_on_odds_overlay_closed)
	_odds_overlay.call_deferred("open_overlay")

func _on_odds_overlay_closed() -> void:
	_dealer_react()

func _icon_tex(id: String) -> Texture2D:
	return Assets.texture(ITEM_ICONS.get(id, "items/consumable_placeholder.png"))

func _offer_icon_size() -> float:
	return PRE_RUN_OFFER_ICON if _pre_run else RUN_OFFER_ICON

func _make_drag_icon(id: String, kind: String, pos: Vector2, parent: Control, icon_size := -1.0) -> void:
	var size_px := Assets.STASH_ICON_SIZE if kind == "stash" else _offer_icon_size()
	if icon_size > 0.0:
		size_px = icon_size
	var t := Control.new()
	t.set_meta("_dealer_dynamic", true)
	t.position = pos
	t.size = Vector2(size_px, size_px)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST       # crisp pixel rendering
	t.pivot_offset = Vector2(size_px, size_px) * 0.5 # scale/tint around centre
	t.focus_mode = Control.FOCUS_NONE
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var spr := Sprite2D.new()
	var tex := _icon_tex(id)
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2.ZERO
	if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
		spr.scale = Vector2(size_px / float(tex.get_width()), size_px / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.add_child(spr)
	t.gui_input.connect(_on_item_input.bind(t, id, kind))
	parent.add_child(t)
	if kind == "offer":
		_item_nodes[id] = t

func _style_price_label(price: Label) -> void:
	price.add_theme_font_size_override("font_size", 7)
	price.add_theme_constant_override("outline_size", 1)
	if _font != null:
		price.add_theme_font_override("font", _font)
	price.add_theme_color_override("font_color", LUCIDITY_COLOR)
	price.add_theme_color_override("font_outline_color", Color.BLACK)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _configure_offer_price_tag(row: HBoxContainer, id: String, pos: Vector2, width := 34.0, apply_layout := true) -> void:
	row.visible = _pre_run
	if apply_layout:
		row.position = pos
		row.size = Vector2(width, 8.0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price := row.get_node_or_null("Price") as Label
	if price == null:
		price = Label.new()
		price.name = "Price"
		row.add_child(price)
	price.text = "%d" % _item_cost(id)
	_style_price_label(price)
	var coin := row.get_node_or_null("Coin") as TextureRect
	var authored_coin := coin != null
	if coin == null:
		coin = TextureRect.new()
		coin.name = "Coin"
		row.add_child(coin)
	coin.texture = Assets.texture(COIN_ASSET, true)
	if not authored_coin:
		coin.custom_minimum_size = Vector2(OFFER_PRICE_COIN_SIZE, OFFER_PRICE_COIN_SIZE)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_offer_price_tag(id: String, pos: Vector2, parent: Control, width := 34.0) -> void:
	var row := parent.get_node_or_null("PriceTag") as HBoxContainer
	if row != null:
		_configure_offer_price_tag(row, id, pos, width, false)
		return
	row = HBoxContainer.new()
	row.name = "PriceTag"
	row.set_meta("_dealer_dynamic", true)
	_configure_offer_price_tag(row, id, pos, width)
	parent.add_child(row)

# Pre-run: the Expo pre-run consumables (a fixed shelf). In-run: the dealer's
# vector-pinned offer for this visit.
func _offer_ids() -> Array:
	if _pre_run:
		var ids: Array = []
		for c in Consumables.LIST:
			ids.append(String(c["id"]))
		return ids
	var offers: Variant = RunStateStore.dealerOfferIds
	return (offers as Array).duplicate() if offers != null else []

func _build_offers() -> void:
	if not _offer_slots.is_empty():
		_item_nodes.clear()
		_offer_cx.clear()
		_offer_slots_by_id.clear()
		for slot in _offer_slots:
			_clear_dynamic_children(slot)
		var ids := _offer_ids()
		var icon_size := _offer_icon_size()
		for i in range(mini(ids.size(), _offer_slots.size())):
			var id := String(ids[i])
			var slot: Control = _offer_slots[i]
			_offer_slots_by_id[id] = slot
			_offer_cx[id] = slot.position.x + slot.size.x * 0.5
			_make_offer_price_tag(id, Vector2(slot.size.x * 0.5 - 17.0, -10.0), slot)
			_make_drag_icon(id, "offer", (slot.size - Vector2(icon_size, icon_size)) * 0.5, slot, icon_size)
		return
	var idx := 0
	var icon_size := _offer_icon_size()
	for id in _offer_ids():
		if idx >= CIRCLE_CX.size():
			break
		var cx: float = float(CIRCLE_CX[idx])
		_offer_cx[String(id)] = cx
		_make_offer_price_tag(String(id), Vector2(cx - 17.0, ITEM_TOP - 10.0), self)
		_make_drag_icon(String(id), "offer", Vector2(cx - icon_size * 0.5, ITEM_TOP), self, icon_size)
		idx += 1

func _build_stash() -> void:
	if not _stash_slot_nodes.is_empty():
		for slot in _stash_slot_nodes:
			_clear_dynamic_children(slot)
		var authored_slots := _stash_slots()
		for i in range(mini(authored_slots.size(), _stash_slot_nodes.size())):
			var slot: Control = _stash_slot_nodes[i]
			var icon_size := minf(slot.size.x, slot.size.y)
			_make_drag_icon(String(authored_slots[i]), "stash", (slot.size - Vector2(icon_size, icon_size)) * 0.5, slot, icon_size)
		return
	if _stash_holder != null:
		_stash_holder.queue_free()
	_stash_holder = Control.new()
	_stash_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stash_holder)
	var slots := _stash_slots()
	# Bottom-right corner, shared layout so every scene's stash lines up (issue #26).
	for i in slots.size():
		_make_drag_icon(String(slots[i]), "stash", Assets.stash_slot_pos(i, max_consumable_slots), _stash_holder, Assets.STASH_ICON_SIZE)

# Pre-run pockets are the wallet-purchased pending consumables; in-run they are
# the live run stash.
func _stash_source() -> Dictionary:
	if Engine.is_editor_hint():
		return { "cons_focus": 1, "cons_white_powder": 1 }
	return MetaStateStore.pendingConsumables if _pre_run else RunStateStore.runConsumables

func _stash_slots() -> Array:
	var out: Array = []
	var stash: Dictionary = _stash_source()
	for id in stash:
		var copies := int(stash[id])
		for _k in copies:
			if out.size() < max_consumable_slots:
				out.append(String(id))
	return out

func _build_hud() -> void:
	_build_campaign_label()
	if _options_button != null or _start_button != null or _credits_row != null:
		if _options_button != null:
			Assets.skin_icon_button(_options_button, SETTINGS_ASSET, 2)
			var options_cb := Callable(self, "_toggle_options_overlay")
			if not _options_button.pressed.is_connected(options_cb):
				_options_button.pressed.connect(options_cb)
		_configure_lab_button()
		if _start_button != null:
			_start_button.visible = _pre_run
			_start_button.text = "" if _start_label != null else "START"
			_apply_button_text_margin(_start_button)
			var start_cb := Callable(self, "_start_run")
			if not _start_button.pressed.is_connected(start_cb):
				_start_button.pressed.connect(start_cb)
		if _start_label != null:
			_start_label.visible = _pre_run
			_start_label.text = "START"
		if _credits_row != null:
			_credits_row.visible = _pre_run
		_build_credits_display()
		return
	# Top-left settings/back icon (issue #25). Pre-run: BACK to the menu hub (issue #22);
	# in-run: LEAVE declines. Both ride the 2-frame settings sheet (normal, pressed).
	var back := TextureButton.new()
	back.name = "options"
	back.custom_minimum_size = Vector2(20.0, 18.0)
	back.size = Vector2(20.0, 18.0)
	back.position = Vector2(9.0, 15.0)
	Assets.skin_icon_button(back, SETTINGS_ASSET, 2)
	back.pressed.connect(_toggle_options_overlay)
	add_child(back)
	_options_button = back
	_configure_lab_button()
	if _pre_run:
		# Begin the run with whatever was bought; back/leave is a separate action.
		# START rides on the arrow asset (issue #24 follow-up: the art is now 39x24 and
		# narrower). Size the button to the asset's real bounds so it is never stretched,
		# vertically centred and tucked against the right border with a 3px safe margin.
		# Right-edge placement is parametric on size.x, so it stays correct on art swaps.
		const ARROW_W := 39.0
		const ARROW_H := 24.0
		var start := Button.new()
		start.text = "START"
		start.size = Vector2(ARROW_W, ARROW_H)
		start.position = Vector2(160.0 - start.size.x - 3.0, (320.0 - start.size.y) * 0.5)
		start.add_theme_font_size_override("font_size", 8)
		if _font != null:
			start.add_theme_font_override("font", _font)
		Assets.skin_sheet_button(start, "ui/arrow_button.png", 3)
		_apply_button_text_margin(start)
		start.pressed.connect(_start_run)
		add_child(start)
		_build_credits_display()
		if Engine.is_editor_hint():
			_refresh_credits()

func _build_campaign_label() -> void:
	var bottom_hud := get_node_or_null("BottomHudLayer") as Control
	if bottom_hud == null:
		bottom_hud = Control.new()
		bottom_hud.name = "BottomHudLayer"
		bottom_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bottom_hud.size = Vector2(160.0, 320.0)
		bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_hud.z_index = 120
		add_child(bottom_hud)
	_campaign_label = bottom_hud.get_node_or_null("neuron_number") as Label
	if _campaign_label == null:
		_campaign_label = Label.new()
		_campaign_label.name = "neuron_number"
		bottom_hud.add_child(_campaign_label)
		_campaign_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_campaign_label.offset_left = -46.5
		_campaign_label.offset_top = -14.0
		_campaign_label.offset_right = 46.5
		_campaign_label.offset_bottom = -4.0
	_campaign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_campaign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_label.add_theme_font_size_override("font_size", 6)
	if _font != null:
		_campaign_label.add_theme_font_override("font", _font)
	_campaign_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	_campaign_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_campaign_label.add_theme_constant_override("outline_size", 1)
	# The neuron meter no longer shows on the dealer HUD — it lives on the start
	# menu and the flatline overlay. The label stays as an editor placeholder.
	_refresh_campaign_label()

func _configure_lab_button() -> void:
	if _lab_button == null:
		return
	_lab_button.text = ""
	_lab_button.focus_mode = Control.FOCUS_NONE
	_lab_button.scale.x = absf(_lab_button.scale.x)
	var lab_cb := Callable(self, "_open_lab")
	if not _lab_button.pressed.is_connected(lab_cb):
		_lab_button.pressed.connect(lab_cb)
	if _lab_label == null:
		_lab_label = Label.new()
		_lab_label.name = "LabButtonLabel"
		_lab_label.position = _lab_button.position
		_lab_label.size = _lab_button.size
		_lab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_lab_label)
	_lab_label.text = "LAB"
	_lab_label.scale = Vector2.ONE
	_lab_label.rotation = 0.0
	_lab_label.pivot_offset = Vector2.ZERO
	_lab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lab_label.add_theme_font_size_override("font_size", 5)
	if _font != null:
		_lab_label.add_theme_font_override("font", _font)
	_lab_label.add_theme_color_override("font_color", Color.WHITE)
	_lab_label.position = _lab_button.position
	_lab_label.size = _lab_button.size
	_lab_label.z_index = _lab_button.z_index + 1

func _toggle_options_overlay() -> void:
	if _options_overlay == null:
		return
	_options_overlay.toggle_overlay()

func _restore_options_overlay_if_requested() -> void:
	if Engine.is_editor_hint() or _options_overlay == null:
		return
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null and bool(scene_nav.call("consume_restore_options", String(scene_file_path))):
		_options_overlay.call_deferred("show_overlay")

func _open_lab() -> void:
	if Engine.is_editor_hint():
		return
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("push_current_scene")
	get_tree().change_scene_to_file(UPGRADES_SCENE)

func _apply_button_text_margin(button: Button) -> void:
	if button == null:
		return
	for state in ["normal", "pressed", "hover", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state)
		if style != null:
			style.content_margin_bottom = BUTTON_TEXT_BOTTOM_MARGIN

# Bottom-left bank-box wallet readout: CreditsRow is an authored HBoxContainer so
# the editor layout stays WYSIWYG while this method only styles and refreshes content.
func _build_credits_display() -> void:
	if _credits_row != null:
		if _credits_row is HBoxContainer:
			(_credits_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
			(_credits_row as HBoxContainer).add_theme_constant_override("separation", 2)
		if _credits_coin != null and _credits_coin.texture == null:
			# Only supply the texture if the scene didn't author one. Layout/stretch/filter
			# are left to the scene so editor tweaks (e.g. stretch mode) actually take effect.
			_credits_coin.texture = Assets.texture(COIN_ASSET, true)
		if _credits_label != null:
			_credits_label.add_theme_font_size_override("font_size", 7)
			if _font != null:
				_credits_label.add_theme_font_override("font", _font)
			_credits_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
			_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_refresh_credits()
		if _credits_coin != null:
			_credits_coin.custom_minimum_size = Vector2(9.0, 9.0)
			_credits_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_credits_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_credits_coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_credits_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return
	var row := HBoxContainer.new()
	row.name = "CreditsRow"
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 7.0
	row.offset_top = -20.0
	row.offset_right = 30.0
	row.offset_bottom = -8.0
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_credits_row = row
	_credits_label = Label.new()
	_credits_label.name = "CreditsLabel"
	_credits_label.add_theme_font_size_override("font_size", 7)
	if _font != null:
		_credits_label.add_theme_font_override("font", _font)
	_credits_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_credits_label)
	var coin := TextureRect.new()
	coin.name = "Coin"
	coin.texture = Assets.texture(COIN_ASSET, true)
	coin.custom_minimum_size = Vector2(9.0, 9.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_credits_coin = coin

func _refresh_credits() -> void:
	if _credits_label != null:
		_credits_label.text = "0" if Engine.is_editor_hint() else str(MetaStateStore.lucidityWallet)

# ── selection + TV ────────────────────────────────────────────────────────────────

# The label renders no runtime text (and the editor no longer calls the
# placeholder MetaStateStore autoload); the neuron meter lives on the start menu.
func _refresh_campaign_label() -> void:
	if _campaign_label != null:
		_campaign_label.text = "NEURONS" if Engine.is_editor_hint() else ""

func _item_name(id: String) -> String:
	var imap := InRunItems.map()
	if imap.has(id):
		return String(imap[id]["name"]).to_upper()
	var cmap := Consumables.map()
	if cmap.has(id):
		return String(cmap[id]["name"]).to_upper()
	return id.to_upper()

func _highlight_selected(id: String) -> void:
	for k in _item_nodes:
		_item_nodes[k].scale = Vector2(1.12, 1.12) if k == id else Vector2.ONE

func _select(id: String) -> void:
	_message.text = ""
	if id == "":
		_tv_pos.text = ""
		_tv_neg.text = ""
		_name_label.visible = false
		_instruction_bubble.visible = true
		_highlight_selected("")
		return
	_instruction_bubble.visible = false
	_highlight_selected(id)
	_dealer_react()
	var h: Dictionary = item_hints.get(id, FALLBACK_HINT)
	_tv_pos.text = "+ %s" % String(h["pos"])
	_tv_neg.text = "- %s" % String(h["neg"])
	# Name under the selected item's icon, centred on its counter circle. Pre-run
	# prices are separate tags above each consumable.
	_name_label.text = _item_name(id)
	_name_label.add_theme_color_override(
		&"font_color", corrupt_name_color if HintLabel.item_is_corrupted(id) else name_color
	)
	if _offer_slots_by_id.has(id):
		var slot: Control = _offer_slots_by_id[id]
		_name_label.position = Vector2(
			slot.position.x + slot.size.x * 0.5 - _name_label.size.x * 0.5,
			slot.position.y + slot.size.y + 1.0
		)
	else:
		var cx: float = float(_offer_cx.get(id, 80.0))
		_name_label.position = Vector2(cx - 30.0, ITEM_TOP + _offer_icon_size() + 1.0)
	_name_label.visible = true

func _item_cost(id: String) -> int:
	var cmap := Consumables.map()
	return int(cmap[id]["shopCost"]) if cmap.has(id) else 0

# ── drag handling ───────────────────────────────────────────────────────────────────

func _on_item_input(event: InputEvent, node: Control, id: String, kind: String) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and not _drag_active:
			_begin_item_press(node, id, kind, get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and not _drag_active:
			_begin_item_press(node, id, kind, touch_event.position)

func _begin_item_press(node: Control, id: String, kind: String, press_pos: Vector2) -> void:
	_drag_active = true
	_drag_node = node
	_drag_id = id
	_drag_kind = kind
	_drag_home = node.position
	_drag_moved = false
	_press_pos = press_pos

func _begin_drag_visual() -> void:
	if _drag_node == null:
		return
	_drag_node.z_index = 10
	_drag_node.scale = Vector2(1.25, 1.25)
	_drag_node.modulate = Color(1.2, 1.2, 1.2)

func _update_drag_position(pos: Vector2) -> void:
	if _drag_node == null:
		return
	if not _drag_moved and pos.distance_to(_press_pos) > DRAG_SLOP:
		_drag_moved = true
		_begin_drag_visual()
	if _drag_moved:
		_drag_node.global_position = pos - _drag_node.size * 0.5

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _drag_active:
		return
	if event is InputEventMouseMotion:
		_update_drag_position(get_global_mouse_position())
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_update_drag_position(drag_event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(get_global_mouse_position())
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_end_drag((event as InputEventScreenTouch).position)

func _end_drag(release_pos: Vector2) -> void:
	var id := _drag_id
	var kind := _drag_kind
	var node := _drag_node
	var on_dealer := _is_on_dealer(release_pos)
	# reset state first
	_drag_active = false
	_drag_node = null
	if node != null:
		node.z_index = 0
		node.position = _drag_home # snap back
		node.scale = Vector2.ONE
		node.modulate = Color.WHITE
	if not _drag_moved:
		_select(id) # a tap selects
		return
	if on_dealer:
		_drop_on_dealer(id, kind)

func _is_on_dealer(global_pos: Vector2) -> bool:
	if _dealer_drop_zone != null:
		return _dealer_drop_zone.get_global_rect().has_point(global_pos)
	return global_pos.y < DEALER_DROP_Y

func _drop_on_dealer(id: String, kind: String) -> void:
	if kind == "offer":
		if _pre_run:
			_buy_offer(id)
			return
		if Consumables.total_copies(RunStateStore.runConsumables) >= max_consumable_slots:
			_message.text = "POCKETS FULL — DROP ONE"
			_flash_full_pockets()
			return
		RunStateStore.accept_dealer_offer_with_limit(id, max_consumable_slots)
		await _react_then_return() # show the dealer reaction, then back to the machine
	elif kind == "stash":
		if _pre_run:
			MetaStateStore.discard_pending_consumable(id) # sell it back, free a slot + refund
		else:
			RunStateStore.discard_run_consumable(id) # throw it to the dealer, free a slot
		_dealer_react()
		_build_stash()

# Pre-run purchase: pay wallet Lucidity for a consumable copy. Buying never leaves
# the counter (you can stock up to max_consumable_slots before starting the run).
func _buy_offer(id: String) -> void:
	if Consumables.total_copies(MetaStateStore.pendingConsumables) >= max_consumable_slots:
		_message.text = "POCKETS FULL — DROP ONE"
		_flash_full_pockets()
		return
	if MetaStateStore.lucidityWallet < _item_cost(id):
		_message.text = "NOT ENOUGH CREDITS"
		_flash_full_pockets()
		return
	MetaStateStore.buy_consumable_charge_with_limit(id, max_consumable_slots) # deducts wallet + persists; emits meta_changed
	_dealer_react()
	_build_stash()

# Flash the "pockets full" message and bump the dealer so the rejection is clear.
func _flash_full_pockets() -> void:
	_dealer_react()
	_message.pivot_offset = _message.size * 0.5
	var tw := create_tween()
	tw.tween_property(_message, "scale", Vector2(1.3, 1.3), 0.06)
	tw.tween_property(_message, "scale", Vector2.ONE, 0.1)
	if _portrait_sprite != null:
		var sh := create_tween()
		sh.tween_property(_portrait_sprite, "position:x", 3.0, 0.04)
		sh.tween_property(_portrait_sprite, "position:x", -3.0, 0.04)
		sh.tween_property(_portrait_sprite, "position:x", 0.0, 0.05)

func _react_then_return() -> void:
	_dealer_react()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file(MACHINE_SCENE)

func _start_run() -> void:
	if Engine.is_editor_hint():
		return
	# Carry the purchased consumables into the run and hand off to the machine.
	if not RunStateStore.start_new_run(MetaStateStore.ownedPermanents, MetaStateStore.get_pending_consumables()):
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	get_tree().change_scene_to_file(MACHINE_SCENE)

func _on_leave() -> void:
	if Engine.is_editor_hint():
		return
	if _pre_run:
		get_tree().change_scene_to_file(MENU_SCENE) # back to the menu hub
		return
	RunStateStore.decline_dealer_offer()
	await _react_then_return()
