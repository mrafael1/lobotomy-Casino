@tool
extends Control

## Pre-run shop + scores hub (Milestone 3). Spend wallet Lucidity on permanent
## upgrades (buy_upgrade) and pre-run consumables (buy_consumable_charge), review
## run history, then START RUN. All purchases go through MetaStateStore, which
## persists to user:// immediately — so the wallet/upgrades survive an app restart
## (the M3 save QA gate). This scene is the loop hub: shop -> run -> bank -> shop.

const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"

# Debug top-up is disabled for Android polish builds; parity/dev fixtures can
# still seed wallet state through MetaStateStore or save JSON when needed.
const DEBUG := false

const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_white_powder": "items/white_powder.png",
	"cons_syringe": "items/consumable_placeholder.png",
	"cons_tea": "items/herbal_tea.png",
}

var _font: FontFile = null
var _tex_cache := {}
var _header: Label = null
var _endings: Label = null
var _list: VBoxContainer = null
var _rows := {} # id -> Button
var _stash_holder: Control = null # bottom-right held-consumables stash (issue #26)
var _background_sprite: Sprite2D = null
var _portrait_sprite: Sprite2D = null
var _counter_sprite: Sprite2D = null
var _start_button: Button = null
var _scores_button: Button = null
var _menu_button: Button = null
var _stash_slot_nodes := []

func _ready() -> void:
	_font = _load_font("font/DTM-Sans.otf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_scene_nodes()
	_build()
	if not MetaStateStore.meta_changed.is_connected(_refresh):
		MetaStateStore.meta_changed.connect(_refresh)
	_refresh()

func _bind_scene_nodes() -> void:
	_background_sprite = get_node_or_null("Background")
	_portrait_sprite = get_node_or_null("Portrait")
	_counter_sprite = get_node_or_null("Counter")
	_header = get_node_or_null("Root/Header")
	_endings = get_node_or_null("Root/Endings")
	_list = get_node_or_null("Root/Scroll/List")
	_start_button = get_node_or_null("Footer/StartButton")
	_scores_button = get_node_or_null("Footer/ScoresButton")
	_menu_button = get_node_or_null("Footer/MenuButton")
	_stash_slot_nodes.clear()
	for i in range(1, Consumables.MAX_CONSUMABLE_SLOTS + 1):
		var slot := get_node_or_null("StashSlot%d" % i)
		if slot == null:
			slot = get_node_or_null("stash/StashSlot%d" % i)
		if slot != null:
			_stash_slot_nodes.append(slot)

func _load_font(rel: String) -> FontFile:
	return Assets.font(rel)

func _load_texture(rel: String, mipmaps := false) -> Texture2D:
	return Assets.texture(rel, mipmaps)

func _build_full_canvas_sheet(rel: String, hframes: int, frame: int = 0) -> Sprite2D:
	var tex := _load_texture(rel, true)
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

func _configure_full_canvas_sheet(spr: Sprite2D, rel: String, hframes: int, frame: int = 0) -> void:
	if spr == null:
		return
	if spr.texture == null:
		var tex := _load_texture(rel, true)
		if tex == null:
			return
		spr.texture = tex
		spr.hframes = hframes
		spr.frame = frame
		spr.centered = false
		var frame_w := float(tex.get_width()) / float(hframes)
		spr.scale = Vector2(160.0 / frame_w, 320.0 / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _build_shop_art_background() -> void:
	if _background_sprite != null or _portrait_sprite != null or _counter_sprite != null:
		_configure_full_canvas_sheet(_background_sprite, "dealer_shop_bg.png", 1)
		_configure_full_canvas_sheet(_portrait_sprite, "dealer_portrait.png", 2)
		_configure_full_canvas_sheet(_counter_sprite, "dealer_shop_counter.png", 1)
		return
	_build_full_canvas_sheet("dealer_shop_bg.png", 1)
	_build_full_canvas_sheet("dealer_portrait.png", 2)
	_build_full_canvas_sheet("dealer_shop_counter.png", 1)

	var readability := ColorRect.new()
	readability.color = Color(0.02, 0.015, 0.035, 0.68)
	readability.position = Vector2(3, 3)
	readability.size = Vector2(154, 286)
	add_child(readability)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	return l

func _styled_button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if _font != null:
		b.add_theme_font_override("font", _font)
	return b

func _build() -> void:
	_build_shop_art_background()
	if _list != null:
		_build_shop_rows(_list)
		_connect_scene_button(_start_button, _start_run)
		_connect_scene_button(_scores_button, _go_scores)
		if _menu_button != null:
			Assets.skin_negative_button(_menu_button)
			_connect_scene_button(_menu_button, _go_menu)
		return

	var root := VBoxContainer.new()
	root.position = Vector2(6, 6)
	root.custom_minimum_size = Vector2(148, 0)
	add_child(root)

	root.add_child(_label("LOBOTOMY — SHOP", 11, Color(0.8, 0.9, 1.0)))
	_header = _label("", 8, Color(0.9, 0.9, 0.7))
	root.add_child(_header)
	_endings = _label("", 8, Color(0.7, 0.8, 0.9))
	root.add_child(_endings)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(148, 196)
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(146, 0)
	scroll.add_child(_list)

	_list.add_child(_label("— UPGRADES —", 8, Color(1.0, 0.7, 0.5)))
	for u in Upgrades.all_upgrades():
		var b := _styled_button("", 8)
		b.pressed.connect(_buy_upgrade.bind(String(u["id"])))
		_list.add_child(b)
		_rows["U:" + String(u["id"])] = b

	_list.add_child(_label("— CONSUMABLES —", 8, Color(1.0, 0.7, 0.5)))
	for c in Consumables.LIST:
		var b := _styled_button("", 8)
		var icon := _load_texture(ITEM_ICONS.get(String(c["id"]), "items/consumable_placeholder.png"))
		if icon != null:
			b.icon = icon
			b.expand_icon = true
		b.pressed.connect(_buy_consumable.bind(String(c["id"])))
		_list.add_child(b)
		_rows["C:" + String(c["id"])] = b

	# Footer sits well above the bottom-right stash row (issue #26) so the wide button
	# row never overlaps the corner stash icons.
	var footer := HBoxContainer.new()
	footer.position = Vector2(6, 262)
	add_child(footer)
	var start := _styled_button("START RUN", 10)
	start.pressed.connect(_start_run)
	footer.add_child(start)
	var scores := _styled_button("SCORES", 8)
	scores.pressed.connect(_go_scores)
	footer.add_child(scores)
	var back := _styled_button("MENU", 8)
	Assets.skin_negative_button(back)
	back.pressed.connect(_go_menu)
	footer.add_child(back)
	if DEBUG:
		var dbg := _styled_button("+200", 8)
		dbg.pressed.connect(_debug_add_lucidity)
		footer.add_child(dbg)

func _build_shop_rows(parent: VBoxContainer) -> void:
	_rows.clear()
	_shop_section_label(parent, "UpgradesTitle", "-- UPGRADES --")
	for u in Upgrades.all_upgrades():
		var id := String(u["id"])
		var b := _shop_row_button(parent, "Upgrade_%s" % id, _buy_upgrade.bind(id))
		_rows["U:" + id] = b
	_shop_section_label(parent, "ConsumablesTitle", "-- CONSUMABLES --")
	for c in Consumables.LIST:
		var id := String(c["id"])
		var b := _shop_row_button(parent, "Consumable_%s" % id, _buy_consumable.bind(id))
		var icon := _load_texture(ITEM_ICONS.get(id, "items/consumable_placeholder.png"))
		if icon != null:
			b.icon = icon
			b.expand_icon = true
		_rows["C:" + id] = b

func _shop_section_label(parent: VBoxContainer, node_name: String, text: String) -> Label:
	var l := parent.get_node_or_null(node_name) as Label
	if l == null:
		l = _label(text, 8, Color(1.0, 0.7, 0.5))
		l.name = node_name
		parent.add_child(l)
	else:
		l.text = text
		l.add_theme_font_size_override("font_size", 8)
		if _font != null:
			l.add_theme_font_override("font", _font)
		l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	return l

func _shop_row_button(parent: VBoxContainer, node_name: String, cb: Callable) -> Button:
	var b := parent.get_node_or_null(node_name) as Button
	if b == null:
		b = _styled_button("", 8)
		b.name = node_name
		parent.add_child(b)
	else:
		b.add_theme_font_size_override("font_size", 8)
		if _font != null:
			b.add_theme_font_override("font", _font)
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)
	return b

func _connect_scene_button(button: Button, cb: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)

# ── refresh ────────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var wallet := 0 if Engine.is_editor_hint() else MetaStateStore.lucidityWallet
	var history: Dictionary = {} if Engine.is_editor_hint() else MetaStateStore.history
	var reached: Array = [] if Engine.is_editor_hint() else MetaStateStore.endingsReached
	_header.text = "CREDITS %d   RUNS %d   BEST %d" % [
		wallet,
		int(history.get("runsPlayed", 0)),
		int(history.get("bestScoreRun", 0)),
	]
	if not Engine.is_editor_hint():
		_header.text += "   %s" % MetaStateStore.campaign_status_text()
	_endings.text = "REACHED: %s" % ("none" if reached.is_empty() else ", ".join(PackedStringArray(reached)))

	var owned: Array = [] if Engine.is_editor_hint() else MetaStateStore.ownedPermanents
	for u in Upgrades.all_upgrades():
		var id := String(u["id"])
		var b: Button = _rows["U:" + id]
		var cost := int(u["cost"])
		var tier := (" " + String(u["tierLabel"])) if u.has("tierLabel") else ""
		if owned.has(id):
			b.text = "%s%s  OWNED" % [String(u["name"]), tier]
			b.disabled = true
		elif u.has("requiresId") and not owned.has(String(u["requiresId"])):
			b.text = "%s%s  (needs prev)" % [String(u["name"]), tier]
			b.disabled = true
		else:
			b.text = "%s%s  %dL" % [String(u["name"]), tier, cost]
			b.disabled = wallet < cost

	var pending: Dictionary = _preview_pending_consumables() if Engine.is_editor_hint() else MetaStateStore.get_pending_consumables()
	var slots_full := Consumables.total_copies(pending) >= Consumables.MAX_CONSUMABLE_SLOTS
	for c in Consumables.LIST:
		var id := String(c["id"])
		var b: Button = _rows["C:" + id]
		var cost := int(c["shopCost"])
		var held := int(pending.get(id, 0))
		b.text = "%s  %dL  x%d" % [String(c["name"]), cost, held]
		b.disabled = slots_full or wallet < cost

	_build_stash(pending)

func _preview_pending_consumables() -> Dictionary:
	return { "cons_focus": 1, "cons_white_powder": 1 }

# Read-only held-consumables stash, bottom-right, shared layout + scale (issue #26).
# Rebuilt on every refresh since buying changes the pending pockets.
func _build_stash(pending: Dictionary) -> void:
	var slots := _pending_stash_slots(pending)
	if not _stash_slot_nodes.is_empty():
		for i in range(_stash_slot_nodes.size()):
			var icon := _stash_icon_for_slot(_stash_slot_nodes[i])
			if icon == null:
				continue
			if i < slots.size():
				icon.texture = _load_texture(ITEM_ICONS.get(slots[i], "items/consumable_placeholder.png"))
			else:
				icon.texture = null
		return
	if _stash_holder != null:
		_stash_holder.queue_free()
	_stash_holder = Control.new()
	_stash_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stash_holder)
	for i in slots.size():
		var icon := TextureRect.new()
		icon.texture = _load_texture(ITEM_ICONS.get(slots[i], "items/consumable_placeholder.png"))
		icon.position = Assets.stash_slot_pos(i, Consumables.MAX_CONSUMABLE_SLOTS)
		icon.size = Vector2(Assets.STASH_ICON_SIZE, Assets.STASH_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_stash_holder.add_child(icon)

func _pending_stash_slots(pending: Dictionary) -> Array:
	var slots: Array = []
	for id in pending:
		for _k in int(pending[id]):
			if slots.size() < Consumables.MAX_CONSUMABLE_SLOTS:
				slots.append(String(id))
	return slots

func _stash_icon_for_slot(slot: Control) -> TextureRect:
	if slot == null:
		return null
	if slot is TextureRect:
		return slot as TextureRect
	var icon := slot.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2.ZERO
		icon.size = slot.size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(icon)
	return icon

# ── actions ──────────────────────────────────────────────────────────────────────────

func _buy_upgrade(id: String) -> void:
	if Engine.is_editor_hint():
		return
	MetaStateStore.buy_upgrade(id)

func _buy_consumable(id: String) -> void:
	if Engine.is_editor_hint():
		return
	MetaStateStore.buy_consumable_charge(id)

func _debug_add_lucidity() -> void:
	if Engine.is_editor_hint():
		return
	MetaStateStore.lucidityWallet += 200
	MetaStateStore.save_state()
	MetaStateStore.meta_changed.emit()

func _start_run() -> void:
	if Engine.is_editor_hint():
		return
	if not RunStateStore.start_new_run(MetaStateStore.ownedPermanents, MetaStateStore.get_pending_consumables()):
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	get_tree().change_scene_to_file(MACHINE_SCENE)

func _go_scores() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene()
	get_tree().change_scene_to_file(SCORES_SCENE)

func _go_menu() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_to_menu(MENU_SCENE)
