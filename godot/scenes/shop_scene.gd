@tool
extends Control

## Wallet/meta progression + scores hub (Milestone 3). Spend wallet Lucidity on
## permanent upgrades (buy_upgrade) and review run history, then START RUN. All
## purchases go through MetaStateStore, which
## persists to user:// immediately — so the wallet/upgrades survive an app restart
## (the M3 save QA gate). This scene is a legacy/meta hub; START RUN now reserves
## the run and opens Pacte, matching the campaign menu flow.

const PACTE_SCENE := "res://scenes/pacte_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"

# Debug top-up is disabled for Android polish builds; parity/dev fixtures can
# still seed wallet state through MetaStateStore or save JSON when needed.
const DEBUG := false

# Layout, in virtual-canvas px. The column is the canvas inset on both sides; the
# readability scrim sits a little proud of it so the art still breathes at the edge.
const CANVAS_W := 160.0
const PANEL_INSET := 6.0
const PANEL_W := CANVAS_W - PANEL_INSET * 2.0  # 148
const LIST_W := PANEL_W - 2.0                  # 146: room for the scrollbar
const SCROLL_H := 196.0
const FOOTER_Y := 262.0
const READABILITY_RECT := Rect2(3.0, 3.0, 154.0, 286.0)
const INK := Color(0.035, 0.025, 0.075)
const CYAN := Color(0.42, 1.0, 0.95)
const HEADER_PANEL_RECT := Rect2(3.0, 3.0, 154.0, 47.0)
const CATALOG_PANEL_RECT := Rect2(3.0, 49.0, 154.0, 208.0)
const SHOP_ROW_HEIGHT := 22.0

const ITEM_ICONS := {
	"cons_focus": "items/generated/serum.png",
	"cons_cigarette": "items/generated/tobacco.png",
	"cons_white_powder": "items/generated/white_powder.png",
	"cons_potion": "items/generated/potion.png",
	"cons_tea": "items/generated/tea.png",
}

var _font: FontFile = null
var _tex_cache := {}
var _header: Label = null
var _campaign_meter: NeuronMeter = null # issue #38 pixel-art neuron meter
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
	UiKit.style_display_label(get_node_or_null("Root/Title") as Label, 8)
	UiKit.style_display_label(_header)
	UiKit.style_display_label(_endings)
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
	# The Lab is a progression terminal, not the stocked dealer counter. The old
	# room/counter sheets showed through the catalog and made every row look pasted
	# over the dealer, so keep those nodes as compatibility anchors but hide them.
	for art in [_background_sprite, _portrait_sprite, _counter_sprite]:
		if art != null:
			art.visible = false
	var old_readability := get_node_or_null("Readability") as ColorRect
	if old_readability != null:
		old_readability.visible = false
	var old_stash := get_node_or_null("stash") as TextureRect
	if old_stash != null:
		# Stash slots belong to the run machine; showing an empty tray in the Lab
		# reads like a broken inventory panel and competes with the footer controls.
		old_stash.visible = false
	var backdrop := ColorRect.new()
	backdrop.name = "LabBackdrop"
	backdrop.color = INK
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(CANVAS_W, 320.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -20
	add_child(backdrop)
	var header := _panel(HEADER_PANEL_RECT, CYAN, 0.92)
	header.name = "LabHeaderPanel"
	header.z_index = -10
	add_child(header)
	var catalog := _panel(CATALOG_PANEL_RECT, Color(CYAN.r, CYAN.g, CYAN.b, 0.34), 0.96)
	catalog.name = "LabCatalogPanel"
	catalog.z_index = -10
	add_child(catalog)

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
		var scroll := _list.get_parent() as ScrollContainer
		if scroll != null:
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_list.custom_minimum_size.x = LIST_W - 8.0
		_build_shop_rows(_list)
		ButtonKit.small_neon_button_style(_start_button, Color(0.42, 1.0, 0.95), 6, 2.0)
		ButtonKit.small_neon_button_style(_scores_button, Color(1.0, 0.5, 0.7), 8, 2.0)
		ButtonKit.skin_negative_button(_menu_button)
		_start_button.custom_minimum_size = Vector2(60, 20)
		_scores_button.custom_minimum_size = Vector2(46, 20)
		_menu_button.custom_minimum_size = Vector2(34, 20)
		_connect_scene_button(_start_button, _start_run)
		_connect_scene_button(_scores_button, _go_scores)
		if _menu_button != null:
			ButtonKit.skin_negative_button(_menu_button)
			_connect_scene_button(_menu_button, _go_menu)
		return

	var root := VBoxContainer.new()
	root.position = Vector2(PANEL_INSET, PANEL_INSET)
	root.custom_minimum_size = Vector2(PANEL_W, 0.0)
	add_child(root)

	root.add_child(_label("LOBOTOMY — SHOP", 11, Color(0.8, 0.9, 1.0)))
	_header = _label("", 8, Color(0.9, 0.9, 0.7))
	root.add_child(_header)
	_endings = _label("", 8, Color(0.7, 0.8, 0.9))
	root.add_child(_endings)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_W, SCROLL_H)
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_W, 0.0)
	scroll.add_child(_list)

	_list.add_child(_label("— UPGRADES —", 8, Color(1.0, 0.7, 0.5)))
	for u in Upgrades.all_upgrades():
		var b := _styled_button("", 8)
		b.pressed.connect(_buy_upgrade.bind(String(u["id"])))
		_list.add_child(b)
		_rows["U:" + String(u["id"])] = b

	# Footer sits well above the bottom-right stash row (issue #26) so the wide button
	# row never overlaps the corner stash icons.
	var footer := HBoxContainer.new()
	footer.position = Vector2(PANEL_INSET, FOOTER_Y)
	add_child(footer)
	var start := _styled_button("START RUN", 10)
	start.pressed.connect(_start_run)
	footer.add_child(start)
	var scores := _styled_button("SCORES", 8)
	scores.pressed.connect(_go_scores)
	footer.add_child(scores)
	var back := _styled_button("MENU", 8)
	ButtonKit.skin_negative_button(back)
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
	UiKit.style_display_label(l)
	return l

func _shop_row_button(parent: VBoxContainer, node_name: String, cb: Callable) -> Button:
	var b := parent.get_node_or_null(node_name) as Button
	if b == null:
		b = _styled_button("", 8)
		b.name = node_name
		parent.add_child(b)
	else:
		b.add_theme_font_size_override("font_size", 6)
		if _font != null:
			b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 6)
	if _font != null:
		b.add_theme_font_override("font", _font)
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(LIST_W - 8.0, SHOP_ROW_HEIGHT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_shop_row(b)
	return b

func _style_shop_row(button: Button) -> void:
	button.add_theme_font_override("font", UiKit.control_font())
	button.add_theme_font_size_override("font_size", 8)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.085, 0.072, 0.055, 0.98)
	normal.border_color = Color(0.40, 0.32, 0.20)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 4.0
	normal.content_margin_right = 3.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.12, 0.08, 0.98)
	hover.border_color = ButtonKit.PANEL_BRASS
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.15, 0.22, 0.20, 1.0)
	pressed.content_margin_top = 2.0
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.055, 0.06, 0.09, 0.94)
	disabled.border_color = Color(0.34, 0.38, 0.45, 0.40)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, {
			"normal": normal, "hover": hover, "pressed": pressed,
			"focus": hover, "disabled": disabled,
		}[state])
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.90))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.38))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.56, 0.62))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 0)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _panel(rect: Rect2, border_color: Color, alpha: float) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ButtonKit.neon_panel_style(border_color, 1.0)
	style.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	panel.add_theme_stylebox_override("panel", style)
	return panel

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
	_header.text = tr("CREDITS %d   RUNS %d   BEST %d") % [
		wallet,
		int(history.get("runsPlayed", 0)),
		int(history.get("bestScoreRun", 0)),
	]
	# Issue #38: the campaign readout is the neuron meter, docked at the header's
	# right edge instead of the old appended "NEURONS: n/n" text. It renders at
	# native px (no resampling), so it sizes itself; right-align it to the column.
	if not Engine.is_editor_hint() and _campaign_meter == null:
		_campaign_meter = NeuronMeter.attach(_header, Vector2.ZERO)
		# The authored neuron sheet is 64px wide; scale it down for the compact
		# progression header so it reads as a status mark instead of covering the
		# credit and run totals.
		_campaign_meter.scale = Vector2(0.5, 0.5)
		_campaign_meter.position = Vector2(PANEL_W - _campaign_meter.size.x * 0.5 - 1.0, 1.0)
	# The endings are stored as IDs ("wealth", "flatline"); translate each before joining,
	# or the line reads as a list of English identifiers in a French screen.
	var reached_names := PackedStringArray()
	for ending_id in reached:
		reached_names.append(tr(String(ending_id)))
	_endings.text = tr("REACHED: %s") % (tr("none") if reached.is_empty() \
		else ", ".join(reached_names))

	var owned: Array = [] if Engine.is_editor_hint() else MetaStateStore.ownedPermanents
	for u in Upgrades.all_upgrades():
		var id := String(u["id"])
		var b: Button = _rows["U:" + id]
		var cost := int(u["cost"])
		var tier := (" " + String(u["tierLabel"])) if u.has("tierLabel") else ""
		# The row is assembled here, so the upgrade's own name and the row template each
		# have to be translated before they are joined — the finished row is not a key.
		var upgrade_name := tr(String(u["name"]))
		if owned.has(id):
			b.text = tr("%s%s  OWNED") % [upgrade_name, tier]
			b.disabled = true
		elif u.has("requiresId") and not owned.has(String(u["requiresId"])):
			b.text = tr("%s%s  (needs prev)") % [upgrade_name, tier]
			b.disabled = true
		else:
			b.text = "%s%s  %dL" % [upgrade_name, tier, cost]
			b.disabled = wallet < cost
		b.tooltip_text = b.text

	# Consumables are dealer-run items now; the old pre-run purchase/stash UI is
	# intentionally absent from this progression hub.

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
	if not RunStateStore.start_new_run(MetaStateStore.ownedPermanents, {}, true, -1, true):
		SceneNav.change_to(MENU_SCENE)
		return
	SceneNav.change_to(PACTE_SCENE)

func _go_scores() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene()
	SceneNav.change_to(SCORES_SCENE)

func _go_menu() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_to_menu(MENU_SCENE)
