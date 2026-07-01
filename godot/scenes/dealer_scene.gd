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
const STASH_SLOTS := 2
const DRAG_SLOP := 4.0

# One-word TV hints (display only) — ports src/content/itemHints.ts.
const ITEM_HINTS := {
	"item_water": { "pos": "CLEAR", "neg": "WEAK" },
	"item_pill": { "pos": "SLOW FALL", "neg": "NUMB" },
	"cons_white_powder": { "pos": "RUSH", "neg": "CRASH" },
	"item_energy_drink": { "pos": "FREE", "neg": "SHAKY" },
	"item_cocktail": { "pos": "EASY", "neg": "STEALS" },
	"cons_focus": { "pos": "BIG PAY", "neg": "BLIND" },
	"cons_syringe": { "pos": "BRAINS", "neg": "DULL" },
	"cons_tea": { "pos": "RESTORE", "neg": "RANDOM" },
}
const FALLBACK_HINT := { "pos": "GIFT", "neg": "PRICE" }

# New UI assets (issue #25). The settings sheet is 2 frames (normal, pressed).
const BUBBLE_ASSET := "ui/standard_bubble_text.png"
const SETTINGS_ASSET := "ui/settings.png"
const COIN_ASSET := "ui/coin.png"

const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_white_powder": "items/white_powder.png",
	"cons_syringe": "items/consumable_placeholder.png",
	"cons_tea": "items/herbal_tea.png",
	"item_energy_drink": "items/energy_drink.png",
	"item_cocktail": "items/cocktail.png",
	"item_water": "items/water.png",
	"item_pill": "items/pill.png",
}

var _font: FontFile = null
var _tv_pos: Label = null
var _tv_neg: Label = null
var _name_label: Label = null   # selected item's name, shown UNDER its counter icon
var _offer_cx := {}             # id -> counter-circle x (to place the name under it)
var _item_nodes := {}           # offer id -> TextureRect (for selected highlight)
var _instruction: Label = null
var _instruction_bubble: Control = null # speech bubble holding the instruction text
var _message: Label = null
var _stash_holder: Control = null
var _portrait_sprite: Sprite2D = null
var _portrait_frame := 0
var _pre_run := false            # true => start-of-run consumable shop (issue #21)
var _credits_label: Label = null # wallet readout, pre-run only

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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_art()
	_build_tv()
	_build_offers()
	_build_stash()
	_build_hud()
	_select("") # show instruction
	if _pre_run and not Engine.is_editor_hint():
		MetaStateStore.meta_changed.connect(_refresh_credits)
		_refresh_credits()

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
	# TV shows ONLY the green (+) / red (-) hints; the item NAME goes under its icon.
	# Same X as before; nudged up ~3.5px so the pair reads more vertically centred in the
	# TV window (issue #24 follow-up).
	_tv_pos = _mk_label(Vector2(TV["left"] + 3.0, TV["top"] + 2.5), 8, Color(0.13, 0.77, 0.37))
	_tv_neg = _mk_label(Vector2(TV["left"] + 3.0, TV["top"] + 11.5), 8, Color(0.94, 0.27, 0.27))
	_build_instruction_bubble()
	_message = _mk_label(Vector2(34.0, 50.0), 7, Color(1.0, 0.6, 0.6))
	_message.text = ""
	# Name label sits under the selected counter item (centred on its circle).
	_name_label = _mk_label(Vector2.ZERO, 7, Color(0.0, 0.9, 1.0))
	_name_label.size = Vector2(60.0, 9.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.visible = false

# Top-centre "DRAG TO BUY" prompt rendered inside the standard speech-bubble asset
# (issue #25). The graphic and the pixel-font label are siblings so the text is crisp.
func _build_instruction_bubble() -> void:
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
	_instruction.text = "DRAG TO BUY" if _pre_run else "DRAG ONE TO ME"
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

func _icon_tex(id: String) -> Texture2D:
	return Assets.texture(ITEM_ICONS.get(id, "items/consumable_placeholder.png"))

func _offer_icon_size() -> float:
	return PRE_RUN_OFFER_ICON if _pre_run else RUN_OFFER_ICON

func _make_drag_icon(id: String, kind: String, pos: Vector2, parent: Control, icon_size := -1.0) -> void:
	var size_px := Assets.STASH_ICON_SIZE if kind == "stash" else _offer_icon_size()
	if icon_size > 0.0:
		size_px = icon_size
	var t := TextureRect.new()
	t.texture = _icon_tex(id)
	t.position = pos
	t.size = Vector2(size_px, size_px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # never distorts aspect
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST       # crisp pixel rendering
	t.pivot_offset = Vector2(size_px, size_px) * 0.5 # scale/tint around centre
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(_on_item_input.bind(t, id, kind))
	parent.add_child(t)
	if kind == "offer":
		_item_nodes[id] = t

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
	var idx := 0
	var icon_size := _offer_icon_size()
	for id in _offer_ids():
		if idx >= CIRCLE_CX.size():
			break
		var cx: float = float(CIRCLE_CX[idx])
		_offer_cx[String(id)] = cx
		_make_drag_icon(String(id), "offer", Vector2(cx - icon_size * 0.5, ITEM_TOP), self, icon_size)
		idx += 1

func _build_stash() -> void:
	if _stash_holder != null:
		_stash_holder.queue_free()
	_stash_holder = Control.new()
	_stash_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stash_holder)
	var slots := _stash_slots()
	# Bottom-right corner, shared layout so every scene's stash lines up (issue #26).
	for i in slots.size():
		_make_drag_icon(String(slots[i]), "stash", Assets.stash_slot_pos(i, STASH_SLOTS), _stash_holder, Assets.STASH_ICON_SIZE)

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
			if out.size() < STASH_SLOTS:
				out.append(String(id))
	return out

func _build_hud() -> void:
	# Top-left settings/back icon (issue #25). Pre-run: BACK to the menu hub (issue #22);
	# in-run: LEAVE declines. Both ride the 2-frame settings sheet (normal, pressed).
	var back := TextureButton.new()
	back.custom_minimum_size = Vector2(20.0, 18.0)
	back.size = Vector2(20.0, 18.0)
	back.position = Vector2(4.0, 4.0) # small margin off the top-left corner
	Assets.skin_icon_button(back, SETTINGS_ASSET, 2)
	back.pressed.connect(_on_leave)
	add_child(back)
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
		start.pressed.connect(_start_run)
		add_child(start)
		_build_credits_display()
		if Engine.is_editor_hint():
			_refresh_credits()

# Bottom-centre wallet readout (issue #25): the Lucidity coin icon followed by the
# amount, replacing the old "L" suffix. A CenterContainer keeps it centred as the
# number's width changes; the coin matches the text height.
func _build_credits_display() -> void:
	var band := CenterContainer.new()
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -18.0
	band.offset_bottom = -2.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	band.add_child(row)
	var coin := TextureRect.new()
	coin.texture = Assets.texture(COIN_ASSET, true)
	coin.custom_minimum_size = Vector2(9.0, 9.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 9)
	if _font != null:
		_credits_label.add_theme_font_override("font", _font)
	_credits_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.56))
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_credits_label)

func _refresh_credits() -> void:
	if _credits_label != null:
		_credits_label.text = "0" if Engine.is_editor_hint() else "%d" % MetaStateStore.lucidityWallet

# ── selection + TV ────────────────────────────────────────────────────────────────

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
	var h: Dictionary = ITEM_HINTS.get(id, FALLBACK_HINT)
	_tv_pos.text = "+ %s" % String(h["pos"])
	_tv_neg.text = "- %s" % String(h["neg"])
	# Name under the selected item's icon, centred on its counter circle. In the
	# pre-run shop the price rides alongside the name so the cost is clear.
	var cx: float = float(_offer_cx.get(id, 80.0))
	_name_label.text = ("%s  %dL" % [_item_name(id), _item_cost(id)]) if _pre_run else _item_name(id)
	_name_label.position = Vector2(cx - 30.0, ITEM_TOP + _offer_icon_size() + 1.0)
	_name_label.visible = true

func _item_cost(id: String) -> int:
	var cmap := Consumables.map()
	return int(cmap[id]["shopCost"]) if cmap.has(id) else 0

# ── drag handling ───────────────────────────────────────────────────────────────────

func _on_item_input(event: InputEvent, node: Control, id: String, kind: String) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _drag_active:
		_drag_active = true
		_drag_node = node
		_drag_id = id
		_drag_kind = kind
		_drag_home = node.position
		_drag_moved = false
		_press_pos = get_global_mouse_position()
		node.z_index = 10
		node.scale = Vector2(1.25, 1.25)        # picked-up feel
		node.modulate = Color(1.2, 1.2, 1.2)    # brighten while held

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _drag_active:
		return
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		_drag_node.global_position = m - _drag_node.size * 0.5
		if m.distance_to(_press_pos) > DRAG_SLOP:
			_drag_moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(get_global_mouse_position())

func _end_drag(release_pos: Vector2) -> void:
	var id := _drag_id
	var kind := _drag_kind
	var node := _drag_node
	var on_dealer := release_pos.y < DEALER_DROP_Y
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

func _drop_on_dealer(id: String, kind: String) -> void:
	if kind == "offer":
		if _pre_run:
			_buy_offer(id)
			return
		if Consumables.total_copies(RunStateStore.runConsumables) >= Consumables.MAX_CONSUMABLE_SLOTS:
			_message.text = "POCKETS FULL — DROP ONE"
			_flash_full_pockets()
			return
		RunStateStore.accept_dealer_offer(id)
		await _react_then_return() # show the dealer reaction, then back to the machine
	elif kind == "stash":
		if _pre_run:
			MetaStateStore.discard_pending_consumable(id) # sell it back, free a slot + refund
		else:
			RunStateStore.discard_run_consumable(id) # throw it to the dealer, free a slot
		_dealer_react()
		_build_stash()

# Pre-run purchase: pay wallet Lucidity for a consumable copy. Buying never leaves
# the counter (you can stock up to MAX_CONSUMABLE_SLOTS before starting the run).
func _buy_offer(id: String) -> void:
	if Consumables.total_copies(MetaStateStore.pendingConsumables) >= Consumables.MAX_CONSUMABLE_SLOTS:
		_message.text = "POCKETS FULL — DROP ONE"
		_flash_full_pockets()
		return
	if MetaStateStore.lucidityWallet < _item_cost(id):
		_message.text = "NOT ENOUGH CREDITS"
		_flash_full_pockets()
		return
	MetaStateStore.buy_consumable_charge(id) # deducts wallet + persists; emits meta_changed
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
	RunStateStore.start_new_run(MetaStateStore.ownedPermanents, MetaStateStore.get_pending_consumables())
	get_tree().change_scene_to_file(MACHINE_SCENE)

func _on_leave() -> void:
	if Engine.is_editor_hint():
		return
	if _pre_run:
		get_tree().change_scene_to_file(MENU_SCENE) # back to the menu hub
		return
	RunStateStore.decline_dealer_offer()
	await _react_then_return()
