@tool
class_name UnlockCardPopup
extends Control

## Reusable "CARD UNLOCKED" overlay (issue #52). It is the temporary presentation
## layer over the persistent Collection catalog: MetaStateStore owns which cards
## are unlocked and which are still waiting to be celebrated, and this popup only
## drains that queue one card at a time.
##
## Every display value is resolved through PacteCards.card(), so the popup and
## Collection can never disagree about a card's art, name, icon, or description.

const COLLECTION_SCENE := "res://scenes/collection_scene.tscn"
const PANEL_RECT := Rect2(12.0, 40.0, 136.0, 238.0)
const CARD_SCALE := 2.0
const DIM_COLOR := Color(0.01, 0.0, 0.03, 0.82)
const NEON_GOLD := Color(0.92, 0.86, 0.56)
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_YELLOW := Color(1.0, 0.86, 0.36)
const FLIP_HALF_DURATION := 0.14

## Card the next Collection open should scroll to and pulse. Set by VIEW
## COLLECTION and consumed once by the Collection scene, so it is presentation
## state only and never reaches the save file.
static var pending_highlight_card_id := ""

signal acknowledged(card_id: String)
signal closed

var _card_id := ""
var _pool := ""
var _dim: ColorRect = null
var _panel: PanelContainer = null
var _heading: Label = null
var _card_holder: Control = null
var _back: TextureRect = null
var _front: TextureRect = null
var _icon: TextureRect = null
var _name_label: Label = null
var _description_label: Label = null
var _view_collection_button: Button = null
var _continue_button: Button = null
var _flip_tween: Tween = null
# The autoloads are looked up once from the tree instead of by their global
# identifiers: the scene-smoke harness compiles this script as a dependency of its
# own entry script, before the autoloads are registered. Caching them also keeps
# the acknowledge/route path working for a popup detached from its host.
var _assets: Node = null
var _meta: Node = null
var _nav: Node = null
# An attached popup lives for as long as its host scene and hides between cards;
# a one-off popup frees itself once its card is acknowledged.
var _attached := false
## Optional host veto, checked before every card is raised. While it returns false
## the queue simply waits: an unlock earned mid-spin or under an ending screen must
## not steal the scene from a presentation the player is still watching. The host
## calls present_next() again once it is idle.
var present_gate := Callable()

## Mounts a popup on `host` that watches for card unlocks for the rest of that
## scene's life, and immediately drains anything already queued (an unlock earned
## just before the scene changed, or in a previous session). Being a child of the
## host means the signal connection dies with the scene.
static func attach_to(host: Node, gate := Callable()) -> UnlockCardPopup:
	if host == null or not is_instance_valid(host) or Engine.is_editor_hint():
		return null
	var existing := host.get_node_or_null(NodePath("UnlockCardPopup")) as UnlockCardPopup
	if existing != null:
		return existing
	var popup := UnlockCardPopup.new()
	popup.name = "UnlockCardPopup"
	popup._attached = true
	popup.present_gate = gate
	host.add_child(popup)
	var store := popup._meta
	if store != null and not store.is_connected("card_unlocked", popup._on_card_unlocked):
		store.connect("card_unlocked", popup._on_card_unlocked)
	popup.visible = false
	popup.present_next()
	return popup

## Mounts a one-off popup over `host` when the queue has anything to present.
## Returns the popup (already presenting its first card) or null when the queue
## is empty.
static func present_pending_in(host: Node) -> UnlockCardPopup:
	if host == null or not is_instance_valid(host):
		return null
	var store: Node = host.get_node_or_null(^"/root/MetaStateStore")
	if store == null or not bool(store.call("has_pending_card_unlocks")):
		return null
	var popup := UnlockCardPopup.new()
	host.add_child(popup)
	if not popup.present_next():
		popup.queue_free()
		return null
	return popup

func _on_card_unlocked(_unlocked_card_id: String, _unlocked_pool: String) -> void:
	# Already showing a card: the new one waits in the queue and is presented when
	# this one is acknowledged, so simultaneous unlocks appear one after another.
	if _card_id != "":
		return
	present_next()

## Consumes the handoff set by VIEW COLLECTION. Returns "" when the Collection
## scene was opened normally.
static func take_pending_highlight() -> String:
	var card_id := pending_highlight_card_id
	pending_highlight_card_id = ""
	return card_id

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_singletons()
	# The overlay owns every click while it is up: gameplay and navigation behind
	# it stay unreachable until the card is acknowledged.
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	# The reveal and its buttons keep working if the host scene paused the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_child_count() == 0:
		_build()

func _bind_singletons() -> void:
	if not is_inside_tree():
		return
	if _assets == null:
		_assets = get_node_or_null(^"/root/Assets")
	if _meta == null:
		_meta = get_node_or_null(^"/root/MetaStateStore")
	if _nav == null:
		_nav = get_node_or_null(^"/root/SceneNav")

func _font() -> Font:
	return _assets.call("font") as Font if _assets != null else null

func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = DIM_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	# Called directly rather than through _assets: button styling left the Assets autoload
	# for ButtonKit, and ButtonKit is a plain static class, so there is no autoload to be
	# absent — which is the only reason the rest of this file goes through _assets at all.
	_panel.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(NEON_GOLD, 5.0))
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 3)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(rows)

	_heading = _make_label("Heading", "CARD UNLOCKED", 9, NEON_CYAN)
	rows.add_child(_heading)

	var card_size := PacteCards.CARD_SIZE * CARD_SCALE
	var card_slot := Control.new()
	card_slot.name = "CardSlot"
	card_slot.custom_minimum_size = card_size
	card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(card_slot)

	_card_holder = Control.new()
	_card_holder.name = "CardHolder"
	_card_holder.size = card_size
	# Flip around the card's own centre so the reveal reads as one card turning.
	_card_holder.pivot_offset = card_size * 0.5
	_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_slot.add_child(_card_holder)
	card_slot.resized.connect(_centre_card_holder)

	_back = _make_card_texture("Back", card_size)
	_card_holder.add_child(_back)
	_front = _make_card_texture("Front", card_size)
	_front.visible = false
	_card_holder.add_child(_front)
	_icon = _make_card_texture("Icon", Vector2.ZERO)
	_icon.visible = false
	_card_holder.add_child(_icon)

	_name_label = _make_label("NameLabel", "", 8, NEON_GOLD)
	rows.add_child(_name_label)

	_description_label = _make_label("DescriptionLabel", "", 6, Color(0.86, 0.9, 0.96))
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(PANEL_RECT.size.x - 12.0, 22.0)
	rows.add_child(_description_label)

	# Stacked rather than side by side: at 160px wide, a full-width plate is the
	# only way VIEW COLLECTION reads without abbreviating it.
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 2)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(actions)

	_view_collection_button = _make_action_button("ViewCollectionButton", "VIEW COLLECTION", NEON_CYAN)
	_view_collection_button.pressed.connect(_on_view_collection_pressed)
	actions.add_child(_view_collection_button)

	_continue_button = _make_action_button("ContinueButton", "CONTINUE", NEON_YELLOW)
	_continue_button.pressed.connect(_on_continue_pressed)
	actions.add_child(_continue_button)

func _centre_card_holder() -> void:
	if _card_holder == null or _card_holder.get_parent() == null:
		return
	var slot := _card_holder.get_parent() as Control
	_card_holder.position = (slot.size - _card_holder.size) * 0.5

func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var font := _font()
	if font != null:
		label.add_theme_font_override("font", font)
	return label

func _make_card_texture(node_name: String, texture_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = texture_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Upscaled pixel art: the enlarged card stays crisp instead of smearing.
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

func _make_action_button(node_name: String, text: String, color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(PANEL_RECT.size.x - 16.0, 17.0)
	ButtonKit.small_neon_button_style(button, color, 6)
	return button

## Presents the next queued unlock. Returns false when the queue is drained.
func present_next() -> bool:
	_bind_singletons()
	if _meta == null:
		return false
	if present_gate.is_valid() and not bool(present_gate.call()):
		return false
	var entry: Dictionary = _meta.call("next_pending_card_unlock")
	if entry.is_empty():
		return false
	return show_card(String(entry.get("cardId", "")), String(entry.get("pool", "")))

## Presents one specific card. Returns false for unknown cards or a pool that
## disagrees with the card metadata.
func show_card(card_id: String, pool: String = "") -> bool:
	if get_child_count() == 0:
		_build()
	var normalised := PacteCards.normalise_card_id(card_id)
	var entry := PacteCards.card(normalised)
	if entry.is_empty():
		return false
	var resolved_pool := String(entry.get("pool", ""))
	if pool != "" and pool != resolved_pool:
		return false
	_card_id = normalised
	_pool = resolved_pool
	_name_label.text = String(entry.get("name", "")).to_upper()
	_description_label.text = String(entry.get("description", ""))
	_back.texture = _atlas(PacteCards.GENERATED_CARD_SHEET, PacteCards.painted_face_rect(_pool, false))
	_front.texture = _atlas(PacteCards.GENERATED_CARD_SHEET, PacteCards.painted_face_rect(_pool, true))
	_apply_icon(entry)
	visible = true
	_play_flip()
	return true

func _apply_icon(entry: Dictionary) -> void:
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if icon_rect.size.x <= 0.0 or icon_rect.size.y <= 0.0:
		# GLITCH ships without an authored icon; its bare card face is intentional.
		_icon.texture = null
		_icon.visible = false
		return
	_icon.texture = PacteCards.icon_texture(entry)
	_icon.size = icon_rect.size * CARD_SCALE
	_icon.position = (_card_holder.size - _icon.size) * 0.5
	_icon.visible = false # revealed together with the front, mid-flip

func _atlas(asset: String, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _assets.call("texture", asset) as Texture2D if _assets != null else null
	atlas.region = region
	return atlas

## Short flip: the back turns edge-on, the front takes over, and the card opens
## back out. Nothing about the final frame depends on the tween finishing, so a
## headless run still lands on a fully composed card.
func _play_flip() -> void:
	_set_face(false)
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_card_holder.scale = Vector2.ONE
	if Engine.is_editor_hint() or not is_inside_tree():
		_set_face(true)
		return
	_flip_tween = create_tween()
	_flip_tween.tween_property(_card_holder, "scale:x", 0.0, FLIP_HALF_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(_set_face.bind(true))
	_flip_tween.tween_property(_card_holder, "scale:x", 1.0, FLIP_HALF_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_face(front_up: bool) -> void:
	if _back == null or _front == null:
		return
	_back.visible = not front_up
	_front.visible = front_up
	_icon.visible = front_up and _icon.texture != null

func _acknowledge() -> void:
	if _card_id == "":
		return
	var card_id := _card_id
	if _meta != null:
		_meta.call("acknowledge_card_unlock", card_id)
	acknowledged.emit(card_id)

func _on_continue_pressed() -> void:
	_acknowledge()
	# Several cards unlocking together are shown one after another; only the last
	# CONTINUE hands control back to the scene underneath.
	if present_next():
		return
	_dismiss()

func _on_view_collection_pressed() -> void:
	var card_id := _card_id
	_acknowledge()
	pending_highlight_card_id = card_id
	_dismiss()
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if _nav == null:
		return
	_nav.call("push_current_scene")
	_nav.call("change_to", COLLECTION_SCENE)

func _dismiss() -> void:
	_card_id = ""
	visible = false
	closed.emit()
	if not _attached:
		queue_free()
