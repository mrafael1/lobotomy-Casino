@tool
class_name CollectionScene
extends Control

## Collection is the authoritative Pacte card catalog (issue #52). Every augment
## and power ships a permanent slot here in PacteCards order: unlocked cards show
## their authored front plus icon, locked cards show only the shared card back and
## reveal neither name nor description. MetaStateStore's unlocked ID lists are the
## single source of truth for which is which.

const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const CARD_SIZE := Vector2(39.0, 61.0)
const CARD_NAME_HEIGHT := 8.0
# Native 160x320 leaves 128px of catalog width: three 39px cards plus two 3px
# gaps, with the slimmed scrollbar taking the remainder.
const CARD_H_SEPARATION := 3
const SCROLLBAR_WIDTH := 4
const GRID_COLUMNS := 3
const NEON_GOLD := Color(0.92, 0.86, 0.56)
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const LOCKED_MODULATE := Color(0.34, 0.32, 0.42, 0.9)
const LOCKED_NAME := "LOCKED"
const LOCKED_DESCRIPTION := "NOT YET UNLOCKED."
const HIGHLIGHT_PULSES := 3
const HIGHLIGHT_PULSE_DURATION := 0.28
const SECTIONS: Array[Dictionary] = [
	{ "pool": "augment", "title": "AUGMENTS", "grid": "AugmentGrid" },
	{ "pool": "power", "title": "POWERS", "grid": "PowerGrid" },
]

@export var editor_preview_unlocked := false:
	set(value):
		editor_preview_unlocked = value
		_rebuild_grid()

@onready var _scroll := $Panel/Rows/Scroll as ScrollContainer
@onready var _catalog := $Panel/Rows/Scroll/Catalog as VBoxContainer
@onready var _modal := $UnlockModal as PanelContainer
@onready var _modal_rows := $UnlockModal/Rows as VBoxContainer
@onready var _modal_name := $UnlockModal/Rows/NameLabel as Label
@onready var _modal_description := $UnlockModal/Rows/DescriptionLabel as Label
@onready var _modal_close := $UnlockModal/Rows/CloseButton as Button
@onready var _back_button := $Panel/Rows/BackButton as Button

var _entries: Dictionary = {}
var _entry_order: Array[String] = []
var _modal_card_id := ""
var _modal_state := ""
var _modal_card_holder: Control = null
var _modal_card_art: TextureRect = null
var _modal_card_icon: TextureRect = null
var _highlighted_card_id := ""

func _ready() -> void:
	UiKit.apply_font(self)
	_slim_scrollbar()
	_build_modal_card_art()
	UiKit.connect_button(_modal_close, _hide_modal)
	UiKit.connect_button(_back_button, _go_back)
	_style_button(_modal_close, true)
	_style_button(_back_button, true)
	if not Engine.is_editor_hint() and not MetaStateStore.meta_changed.is_connected(_rebuild_grid):
		MetaStateStore.meta_changed.connect(_rebuild_grid)
	_rebuild_grid()
	_hide_modal()
	if not Engine.is_editor_hint():
		var highlight := UnlockCardPopup.take_pending_highlight()
		if highlight != "":
			highlight_card(highlight)

# ── catalog ──────────────────────────────────────────────────────────────────────

## The default scrollbar eats enough of the 128px catalog width to push the third
## card column out of the panel; slimming it keeps three native-size cards per row.
func _slim_scrollbar() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		bar.custom_minimum_size.x = SCROLLBAR_WIDTH

func _rebuild_grid() -> void:
	if not is_inside_tree() or _catalog == null:
		return
	_entries.clear()
	_entry_order.clear()
	for section in SECTIONS:
		var grid := _catalog.get_node_or_null(NodePath(String(section["grid"]))) as GridContainer
		if grid == null:
			continue
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", CARD_H_SEPARATION)
		var pool := String(section["pool"])
		# Catalog order is PacteCards' authored order, not the unlock order, so a
		# card never moves once the player earns it.
		for card_id in PacteCards.ids_for_pool(pool):
			var entry := _make_card_entry(card_id, pool)
			grid.add_child(entry)
			_entries[card_id] = entry
			_entry_order.append(card_id)
	if _highlighted_card_id != "":
		highlight_card(_highlighted_card_id)

func _make_card_entry(card_id: String, pool: String) -> Button:
	var entry := PacteCards.card(card_id)
	var unlocked := is_card_unlocked(card_id, pool)
	var button := Button.new()
	button.name = "Card_%s" % card_id
	button.custom_minimum_size = Vector2(CARD_SIZE.x, CARD_SIZE.y + CARD_NAME_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.set_meta(&"card_id", card_id)
	button.set_meta(&"pool", pool)
	button.set_meta(&"unlocked", unlocked)

	var art := TextureRect.new()
	art.name = "CardArt"
	art.texture = UiKit.atlas(PacteCards.sheet_for_pool(pool),
		PacteCards.front_rect_for_pool(pool) if unlocked else PacteCards.back_rect_for_pool(pool))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = CARD_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(art)

	if unlocked:
		var icon := _make_icon(entry, pool)
		if icon != null:
			button.add_child(icon)

	# The name is part of the unlocked reveal: a locked slot keeps an empty label
	# so the grid cells stay aligned without leaking the card's identity.
	var label := Label.new()
	label.name = "NameLabel"
	# clip_text first: it drops the label's minimum width to zero, so the explicit
	# card-width size below is not widened back out by a long card name. Wrapping
	# is deliberately off — it would restore a minimum width of the longest word.
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = String(entry.get("name", "")).to_upper() if unlocked else ""
	label.custom_minimum_size = Vector2(CARD_SIZE.x, CARD_NAME_HEIGHT)
	label.position = Vector2(0.0, CARD_SIZE.y)
	label.size = Vector2(CARD_SIZE.x, CARD_NAME_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 4)
	label.add_theme_constant_override("line_spacing", 0)
	label.add_theme_color_override("font_color", NEON_GOLD)
	var font := Assets.font()
	if font != null:
		label.add_theme_font_override("font", font)
	button.add_child(label)

	if not unlocked:
		button.modulate = LOCKED_MODULATE
		_add_locked_glitch(button)
	button.pressed.connect(_on_card_pressed.bind(card_id, pool))
	return button

## Muted card backs get a couple of static tear lines so a locked slot reads as
## deliberately redacted rather than as missing art.
func _add_locked_glitch(button: Button) -> void:
	var fx := Control.new()
	fx.name = "LockedGlitch"
	fx.position = Vector2.ZERO
	fx.size = CARD_SIZE
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in 2:
		var tear := ColorRect.new()
		tear.name = "Tear%d" % index
		tear.color = Color(0.55, 0.9, 1.0, 0.16)
		tear.position = Vector2(0.0, 16.0 + float(index) * 21.0)
		tear.size = Vector2(CARD_SIZE.x, 2.0)
		tear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.add_child(tear)
	button.add_child(fx)

func _make_icon(entry: Dictionary, pool: String) -> TextureRect:
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if icon_rect.size.x <= 0.0 or icon_rect.size.y <= 0.0:
		return null
	var icon := TextureRect.new()
	icon.name = "CardIcon"
	icon.texture = UiKit.atlas(PacteCards.sheet_for_pool(pool), icon_rect)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	var scale := minf(1.0, minf((CARD_SIZE.x - 6.0) / icon_rect.size.x,
		(CARD_SIZE.y - 6.0) / icon_rect.size.y))
	icon.size = icon_rect.size * scale
	icon.position = (CARD_SIZE - icon.size) * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon

func is_card_unlocked(card_id: String, pool: String = "") -> bool:
	if Engine.is_editor_hint():
		return editor_preview_unlocked
	var resolved_pool := pool if pool != "" else PacteCards.pool_of(card_id)
	if resolved_pool == "augment":
		return MetaStateStore.unlocked_augment_cards().has(card_id)
	if resolved_pool == "power":
		return MetaStateStore.unlocked_power_cards().has(card_id)
	return false

## Catalog order, augments first, for tests and for keyboard traversal.
func catalog_card_ids() -> Array[String]:
	return _entry_order.duplicate()

func card_entry(card_id: String) -> Button:
	var entry: Variant = _entries.get(PacteCards.normalise_card_id(card_id), null)
	return entry as Button if entry != null and is_instance_valid(entry as Node) else null

# ── detail modal ─────────────────────────────────────────────────────────────────

func _build_modal_card_art() -> void:
	if _modal_rows == null or _modal_card_holder != null:
		return
	_modal_card_holder = Control.new()
	_modal_card_holder.name = "CardSlot"
	_modal_card_holder.custom_minimum_size = CARD_SIZE
	_modal_card_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_rows.add_child(_modal_card_holder)
	_modal_rows.move_child(_modal_card_holder, 0)

	_modal_card_art = TextureRect.new()
	_modal_card_art.name = "CardArt"
	_modal_card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_modal_card_art.stretch_mode = TextureRect.STRETCH_SCALE
	_modal_card_art.size = CARD_SIZE
	_modal_card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_card_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_modal_card_holder.add_child(_modal_card_art)

	_modal_card_icon = TextureRect.new()
	_modal_card_icon.name = "CardIcon"
	_modal_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_modal_card_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_modal_card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_modal_card_icon.visible = false
	_modal_card_holder.add_child(_modal_card_icon)

func _on_card_pressed(card_id: String, pool: String) -> void:
	show_card_detail(card_id, pool)

## Opens the detail modal. Unlocked cards get their full authored entry; locked
## cards get the minimal LOCKED state with the card back and no real metadata.
func show_card_detail(card_id: String, pool: String = "") -> void:
	var resolved_pool := pool if pool != "" else PacteCards.pool_of(card_id)
	if resolved_pool == "":
		return
	var entry := PacteCards.card(card_id)
	var unlocked := is_card_unlocked(card_id, resolved_pool)
	_modal_card_id = card_id
	_modal_state = "unlocked" if unlocked else "locked"
	if _modal_card_art != null:
		_modal_card_art.texture = UiKit.atlas(PacteCards.sheet_for_pool(resolved_pool),
			PacteCards.front_rect_for_pool(resolved_pool) if unlocked
			else PacteCards.back_rect_for_pool(resolved_pool))
		_modal_card_art.modulate = Color.WHITE if unlocked else LOCKED_MODULATE
	_apply_modal_icon(entry, resolved_pool, unlocked)
	inject_modal_data(
		String(entry.get("name", "")) if unlocked else LOCKED_NAME,
		String(entry.get("description", "")) if unlocked else _locked_description(card_id))

## What a locked slot is allowed to say: how the card is earned, never what it
## does. Cards with no unlock rule fall back to the bare LOCKED copy.
func _locked_description(card_id: String) -> String:
	if Engine.is_editor_hint():
		return LOCKED_DESCRIPTION
	var hint := CardUnlocks.hint_for(card_id, MetaStateStore.card_unlock_progress_snapshot())
	return hint if hint != "" else LOCKED_DESCRIPTION

func _apply_modal_icon(entry: Dictionary, pool: String, unlocked: bool) -> void:
	if _modal_card_icon == null:
		return
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if not unlocked or icon_rect.size.x <= 0.0 or icon_rect.size.y <= 0.0:
		_modal_card_icon.texture = null
		_modal_card_icon.visible = false
		return
	_modal_card_icon.texture = UiKit.atlas(PacteCards.sheet_for_pool(pool), icon_rect)
	var scale := minf(1.0, minf((CARD_SIZE.x - 6.0) / icon_rect.size.x,
		(CARD_SIZE.y - 6.0) / icon_rect.size.y))
	_modal_card_icon.size = icon_rect.size * scale
	_modal_card_icon.position = (CARD_SIZE - _modal_card_icon.size) * 0.5
	_modal_card_icon.visible = true

func inject_modal_data(item_name: String, unlock_description: String) -> void:
	if _modal_name != null:
		_modal_name.text = item_name.to_upper()
	if _modal_description != null:
		_modal_description.text = unlock_description
	if _modal != null:
		_modal.visible = true

func modal_card_id() -> String:
	return _modal_card_id

func modal_state() -> String:
	return _modal_state

func _hide_modal() -> void:
	_modal_card_id = ""
	_modal_state = ""
	if _modal != null:
		_modal.visible = false

# ── unlock highlight ─────────────────────────────────────────────────────────────

## Scrolls a card into view and pulses it. Used by the unlock popup's VIEW
## COLLECTION action so the player lands on the card they just earned.
func highlight_card(card_id: String) -> bool:
	var normalised := PacteCards.normalise_card_id(card_id)
	var entry := card_entry(normalised)
	if entry == null:
		_highlighted_card_id = ""
		return false
	_highlighted_card_id = normalised
	if _scroll != null:
		_scroll.ensure_control_visible(entry)
	if Engine.is_editor_hint() or not is_inside_tree():
		return true
	var tween := entry.create_tween()
	tween.set_loops(HIGHLIGHT_PULSES)
	tween.tween_property(entry, "modulate", NEON_CYAN, HIGHLIGHT_PULSE_DURATION)
	tween.tween_property(entry, "modulate", Color.WHITE, HIGHLIGHT_PULSE_DURATION)
	return true

func highlighted_card_id() -> String:
	return _highlighted_card_id

# ── helpers ──────────────────────────────────────────────────────────────────────



func _style_button(button: Button, negative := false) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 8)
	if negative:
		ButtonKit.skin_negative_button(button)
	else:
		ButtonKit.skin_sheet_button(button, "ui/green_button.png", 4)


func _go_back() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_back(MENU_SCENE)
