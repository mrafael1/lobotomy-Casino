@tool
extends Control

## WYSIWYG upgrade hub controller. Visual sprite layers stay as authored scene
## nodes; this script only coordinates frame state, contextual panels, and buys.

const START_MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const SETTINGS_ASSET := "ui/settings.png"
const SMART_SAVE_UPGRADE_ID := "pos_smart_save"
const REWARD_AMP_IDS: Array[String] = ["corr_reward_amp_1", "corr_reward_amp_2", "corr_reward_amp_3"]
const EYE_UPGRADE_IDS: Array[String] = ["perm_shift", "corr_pattern_23", "pos_learning", "pos_enlightenment"]
const MEMORY_STATIC_UPGRADE_IDS: Array[String] = ["perm_memory", SMART_SAVE_UPGRADE_ID]
const HALLUCINATION_UPGRADE_ID := "pos_enlightenment"
const EYE_ROW_RECTS := {
	"perm_shift": Rect2(0.0, 0.0, 18.0, 16.0),
	"pos_enlightenment": Rect2(22.0, 0.0, 20.0, 16.0),
	"corr_pattern_23": Rect2(0.0, 14.0, 18.0, 9.0),
	"pos_learning": Rect2(0.0, 23.0, 18.0, 16.0),
}
const MEMORY_ROW_RECTS := {
	"perm_memory": Rect2(12.0, 2.0, 13.0, 13.0),
	"reward_amp": Rect2(12.0, 16.0, 13.0, 10.0),
	"pos_smart_save": Rect2(12.0, 28.0, 13.0, 12.0),
}
const EYE_TERMINAL_FRAMES := 12
const AUTHORED_FRAME_WIDTH := 1280.0
const FRAME_TIME := 0.08
const LAB_SIZE := Vector2(160.0, 240.0)
const DEFAULT_ANIMATION := &"default"
const COIN_ASSET := "ui/coin.png"
const LUCIDITY_COLOR := Color(0.92, 0.86, 0.56)
## Corrupted upgrades render their NAME in purple (issue #37). This is an explicit
## per-upgrade flag, DECOUPLED from the mechanical "corrupted" category: Hallucination
## is a positive-category upgrade but must read as corrupted, while other
## category-corrupted upgrades (e.g. Sedative Protocol, Euphoria Spiral) are NOT flagged.
const CORRUPTED_NAME_IDS: Array[String] = ["corr_pattern_23", HALLUCINATION_UPGRADE_ID,
	"corr_reward_amp_1", "corr_reward_amp_2", "corr_reward_amp_3"]
@export var corrupt_name_color: Color = Color(0.66, 0.33, 0.86)
const EDITOR_HITBOX_FILL := Color(0.13, 0.77, 0.37, 0.18)
const EDITOR_HITBOX_BORDER := Color(0.13, 0.77, 0.37, 0.85)
const BUBBLES_REST_FRAME := 12
const BRAIN_MONEY_TARGET := Vector2(80.0, 128.0)
const BUY_BUTTON_FONT_SIZE := 6
const OWNED_BUTTON_FONT_SIZE := 5
const REWARD_AMP_PICKER_RECT := Rect2(14.0, 136.0, 132.0, 44.0)
const BG_DEFAULT_FRAME := 3
const BG_FLASH_LAST_FRAME := 2
const DEFAULT_DESCRIPTION := "Select a lab terminal."
const SELECT_POWER_DESCRIPTION := "Select a power."
const MACHINE_MANIPULATION_CATEGORY := "Machine Manipulations"
const GAIN_BOOST_CATEGORY := "Gain Boosts"

const DESCRIPTIONS := {
	"perm_shift": "Shift one reel symbol up \n or down during a run.",
	"corr_pattern_23": "Two matching symbols in slots 2 and 3 count as a triple.",
	"pos_learning": "Adds the Book symbol to the reels.",
	"pos_enlightenment": "Removes one reel. Visible pairs count as triples, but rewards are cut by 30%.",
	"perm_memory": "Lock a reel before spinning.",
	"corr_reward_amp_1": "Choose one symbol and increase its rewards.\n[color=#183A8C]tier I[/color].",
	"corr_reward_amp_2": "Increase the chosen symbol's rewards.\n[color=#FBBF24]tier II[/color].",
	"corr_reward_amp_3": "Increase the chosen symbol's rewards.\n[color=#D62828]tier III[/color].",
	"pos_smart_save": "Retain 20% of run lucidity on reset instead of 10%.",
}

@export var animate_in_editor: bool = true:
	set(value):
		animate_in_editor = value
		set_process(not Engine.is_editor_hint() or animate_in_editor)

@export var editor_preview_eye_active: bool = true:
	set(value):
		editor_preview_eye_active = value
		_refresh_all()

@export var editor_preview_memory_active: bool = true:
	set(value):
		editor_preview_memory_active = value
		_refresh_all()

@export var editor_preview_wallet: int = 500:
	set(value):
		editor_preview_wallet = value
		_refresh_all()

@export_group("Editor Hitboxes")
@export var show_terminal_hitboxes_in_editor: bool = true:
	set(value):
		show_terminal_hitboxes_in_editor = value
		if is_inside_tree():
			_style_terminal_hitboxes()

@export_group("Upgrade Categories")
@export var machine_manipulation_upgrade_ids: Array[String] = ["perm_shift", "perm_memory", "corr_pattern_23", "pos_learning"]
@export var gain_boost_upgrade_ids: Array[String] = ["corr_reward_amp_1", "corr_reward_amp_2", "corr_reward_amp_3", "pos_enlightenment", "pos_smart_save"]

@onready var _bg := $upgrades_scene_bg as AnimatedSprite2D
@onready var _brain := $upgrades_scene_brain as AnimatedSprite2D
@onready var _bubbles := $upgrades_scene_bubbles as AnimatedSprite2D
@onready var _eye_overlay := $upgrades_scene_eye_brain_overlay as AnimatedSprite2D
@onready var _memory_overlay := $upgrade_scene_memory_brain_overlay as AnimatedSprite2D
@onready var _cables := $upgrades_scene_cables as AnimatedSprite2D
@onready var _layer := $upgrades_scene_layer as Sprite2D
@onready var _eye_terminal := $upgrades_scene_eye_upgrades as AnimatedSprite2D
@onready var _memory_terminal := $upgrades_scene_memory_upgrades as AnimatedSprite2D
@onready var _lab_sign := $upgrades_scene_LAB_SIGN as AnimatedSprite2D
@onready var _leak := $upgrades_scene_leak as AnimatedSprite2D
@onready var _ui_container := $CanvasLayer/UI_Container as Control
@onready var _wallet_label := $CanvasLayer/UI_Container/LucidtyCoinDisplay/Label as Label
@onready var _wallet_coin := $CanvasLayer/UI_Container/LucidtyCoinDisplay/Coin as TextureRect
@onready var _eye_panel := $CanvasLayer/UI_Container/EyeUpgradePanel as Control
@onready var _memory_panel := $CanvasLayer/UI_Container/MemoryUpgradePanel as Control
@onready var _power_name_box := $CanvasLayer/UI_Container/PowerNameBox as Control
@onready var _power_name_label := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PowerNameLabel as Label
@onready var _description_label := $CanvasLayer/UI_Container/DescriptionBubble/DescriptionCenter/Text as RichTextLabel
@onready var _eye_hitbox := $CanvasLayer/UI_Container/EyeComputerHitbox as Button
@onready var _memory_hitbox := $CanvasLayer/UI_Container/MemoryComputerHitbox as Button
@onready var _context_price_group := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup as Control
@onready var _context_price_label := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup/PriceLabel as Label
@onready var _context_price_coin := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup/Coin as TextureRect
@onready var _context_buy_button := $CanvasLayer/UI_Container/ContextBuyButton as Button
@onready var _back_button := $CanvasLayer/UI_Container/BackButton as Button
@onready var _options_button := $CanvasLayer/UI_Container/options as TextureButton
@onready var _options_overlay := $CanvasLayer/OptionsOverlay as OptionsOverlay

var _rng := RandomNumberGenerator.new()
var _selected_upgrade_row: Control = null
var _bg_wait := 3.25
var _bg_flash_frame := -1
var _bg_flash_pause := 0.0
var _brain_time := 0.0
var _bubbles_time := 0.0
var _bubbles_wait := 0.65
var _bubbles_playing := false
var _cables_time := 0.0
var _cables_wait := 0.25
var _sign_time := 0.0
var _sign_wait := 1.5
var _sign_flickers := 0
var _leak_time := 0.0
var _leak_wait := 0.9
var _eye_active := false
var _eye_opening := false
var _eye_open_frame := 1
var _eye_open_time := 0.0
var _eye_idle_time := 0.0
var _eye_idle_wait := 1.8
var _eye_idle_frame := -1
var _memory_active := false
var _purchase_animating := false
var _reward_amp_picker: Control = null
var _pending_reward_amp_upgrade_id := ""

func _ready() -> void:
	custom_minimum_size = Vector2(160.0, 320.0)
	_rng.randomize()
	_configure_sprite_frames()
	_configure_layer_visibility()
	_bind_buttons()
	_apply_font(self)
	_style_buttons(self)
	_style_terminal_hitboxes()
	_style_lucidity_displays()
	if not Engine.is_editor_hint() and not MetaStateStore.meta_changed.is_connected(_refresh_all):
		MetaStateStore.meta_changed.connect(_refresh_all)
	_refresh_all()
	_restore_options_overlay_if_requested()
	set_process(not Engine.is_editor_hint() or animate_in_editor)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	_step_background(delta)
	_brain_time = _advance_time(_brain, 15, _brain_time, delta, true)
	_sync_brain_overlay_frames()
	_step_bubbles(delta)
	_step_cables(delta)
	_step_sign(delta)
	_step_leak(delta)
	_step_eye_terminal(delta)

func _configure_sprite_frames() -> void:
	_configure_animated_sprite(_bg, "upgrade_scene/upgrades_scene_bg.png", 4, BG_DEFAULT_FRAME)
	_configure_animated_sprite(_brain, "upgrade_scene/upgrades_scene_brain.png", 15, 0)
	_configure_animated_sprite(_bubbles, "upgrade_scene/upgrades_scene_bubbles.png", 13, BUBBLES_REST_FRAME)
	_configure_animated_sprite(_eye_overlay, "upgrade_scene/upgrades_scene_eye_brain_overlay.png", 15, 0)
	_configure_animated_sprite(_memory_overlay, "upgrade_scene/upgrades_scene_memory_brain_overlay.png", 15, 0)
	_configure_animated_sprite(_cables, "upgrade_scene/upgrades_scene_cables.png", 11, 0)
	_configure_sprite(_layer, 1, 0)
	_configure_animated_sprite(_eye_terminal, "upgrade_scene/upgrades_scene_eye_upgrades.png", EYE_TERMINAL_FRAMES, 0)
	_configure_animated_sprite(_memory_terminal, "upgrade_scene/upgrades_scene_memory_upgrades.png", 5, 0)
	_configure_animated_sprite(_lab_sign, "upgrade_scene/upgrades_scene_LAB_SIGN.png", 2, 0)
	_configure_animated_sprite(_leak, "upgrade_scene/upgrades_scene_leak.png", 11, 0)

func _configure_animated_sprite(sprite: AnimatedSprite2D, texture_path: String, frames: int, default_frame: int) -> void:
	if sprite == null:
		return
	if _configure_split_animated_sprite(sprite, texture_path, frames, default_frame):
		return
	var texture := Assets.texture(texture_path)
	if texture == null:
		return
	var actual_frames := _sheet_frame_count(texture, texture_path, frames)
	if _has_valid_sprite_frames(sprite, actual_frames):
		sprite.animation = DEFAULT_ANIMATION
		sprite.centered = false
		sprite.frame = clampi(default_frame, 0, actual_frames - 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(DEFAULT_ANIMATION)
	sprite_frames.set_animation_loop(DEFAULT_ANIMATION, false)
	sprite_frames.set_animation_speed(DEFAULT_ANIMATION, 1.0 / FRAME_TIME)
	var frame_width := float(texture.get_width()) / float(actual_frames)
	for i in actual_frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_width * float(i), 0.0, frame_width, float(texture.get_height()))
		sprite_frames.add_frame(DEFAULT_ANIMATION, atlas)
	sprite.sprite_frames = sprite_frames
	sprite.animation = DEFAULT_ANIMATION
	sprite.centered = false
	sprite.frame = clampi(default_frame, 0, actual_frames - 1)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _configure_split_animated_sprite(sprite: AnimatedSprite2D, texture_path: String, frames: int, default_frame: int) -> bool:
	var base_name := texture_path.get_file().get_basename()
	var split_prefix := "upgrade_scene/split/%s_" % base_name
	var first_frame_path := "%s%02d.png" % [split_prefix, 0]
	if not FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/images/" + first_frame_path)):
		return false
	if _has_valid_sprite_frames(sprite, frames):
		sprite.animation = DEFAULT_ANIMATION
		sprite.centered = false
		sprite.frame = clampi(default_frame, 0, frames - 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return true
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(DEFAULT_ANIMATION)
	sprite_frames.set_animation_loop(DEFAULT_ANIMATION, false)
	sprite_frames.set_animation_speed(DEFAULT_ANIMATION, 1.0 / FRAME_TIME)
	for i in frames:
		var frame_path := "%s%02d.png" % [split_prefix, i]
		var frame_texture := Assets.texture(frame_path)
		if frame_texture == null:
			return false
		sprite_frames.add_frame(DEFAULT_ANIMATION, frame_texture)
	sprite.sprite_frames = sprite_frames
	sprite.animation = DEFAULT_ANIMATION
	sprite.centered = false
	sprite.frame = clampi(default_frame, 0, frames - 1)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true

func _sheet_frame_count(texture: Texture2D, texture_path: String, requested_frames: int) -> int:
	var authored_count := int(round(float(texture.get_width()) / AUTHORED_FRAME_WIDTH))
	if authored_count > 0 and not is_equal_approx(float(texture.get_width()) / float(authored_count), AUTHORED_FRAME_WIDTH):
		return requested_frames
	if authored_count > 0 and authored_count != requested_frames:
		push_warning("%s has %d authored 1280px frames; using that instead of requested %d." % [texture_path, authored_count, requested_frames])
		return authored_count
	return requested_frames

func _has_valid_sprite_frames(sprite: AnimatedSprite2D, expected_frames: int) -> bool:
	if sprite.sprite_frames == null:
		return false
	if not sprite.sprite_frames.has_animation(DEFAULT_ANIMATION):
		return false
	if sprite.sprite_frames.get_frame_count(DEFAULT_ANIMATION) != expected_frames:
		return false
	return sprite.sprite_frames.get_frame_texture(DEFAULT_ANIMATION, 0) != null

func _configure_sprite(sprite: Sprite2D, frames: int, default_frame: int) -> void:
	if sprite == null:
		return
	sprite.centered = false
	sprite.hframes = frames
	sprite.vframes = 1
	sprite.frame = clampi(default_frame, 0, frames - 1)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _configure_layer_visibility() -> void:
	if _bg != null:
		_bg.z_index = -100
	if _brain != null:
		_brain.z_index = -90
	if _bubbles != null:
		_bubbles.z_index = -80
	if _eye_overlay != null:
		_eye_overlay.z_index = -70
	if _memory_overlay != null:
		_memory_overlay.z_index = -70
	if _cables != null:
		_cables.z_index = -60
	if _layer != null:
		_layer.z_index = 0
	if _eye_terminal != null:
		_eye_terminal.z_index = 10
	if _memory_terminal != null:
		_memory_terminal.z_index = 10
	if _lab_sign != null:
		_lab_sign.z_index = 20
	if _leak != null:
		_leak.z_index = 30
	if _ui_container != null:
		_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _bind_buttons() -> void:
	_connect_button(_eye_hitbox, _activate_eye)
	_connect_button(_memory_hitbox, _activate_memory)
	_connect_button(_context_buy_button, _buy_selected_upgrade)
	_connect_button(_back_button, _go_back)
	_bind_options_button()
	for row in _upgrade_rows():
		row.gui_input.connect(_inspect_row.bind(row))

func _connect_button(button: Button, cb: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)

func _bind_options_button() -> void:
	if _options_button == null:
		return
	Assets.skin_icon_button(_options_button, SETTINGS_ASSET, 2)
	if not _options_button.pressed.is_connected(_toggle_options_overlay):
		_options_button.pressed.connect(_toggle_options_overlay)

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

func _apply_font(node: Node) -> void:
	var font := Assets.font()
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			if font != null:
				label.add_theme_font_override("font", font)
		elif child is RichTextLabel:
			var rich_label := child as RichTextLabel
			if font != null:
				rich_label.add_theme_font_override("normal_font", font)
		elif child is Button:
			var button := child as Button
			if font != null:
				button.add_theme_font_override("font", font)
		_apply_font(child)

func _style_buttons(node: Node) -> void:
	if node is OptionsOverlay:
		return
	for child in node.get_children():
		if child is Button:
			var button := child as Button
			if button.name != "EyeComputerHitbox" and button.name != "MemoryComputerHitbox":
				if button.name == "BackButton":
					Assets.skin_negative_button(button)
				else:
					Assets.skin_sheet_button(button, "ui/green_button.png", 4)
		_style_buttons(child)

func _style_terminal_hitboxes() -> void:
	var stylebox: StyleBox = _make_empty_hitbox_style()
	if Engine.is_editor_hint() and show_terminal_hitboxes_in_editor:
		stylebox = _make_editor_hitbox_style()
	for button in [_eye_hitbox, _memory_hitbox]:
		if button == null:
			continue
		for state in [&"normal", &"pressed", &"hover", &"focus"]:
			button.add_theme_stylebox_override(state, stylebox)

func _make_empty_hitbox_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _make_editor_hitbox_style() -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = EDITOR_HITBOX_FILL
	stylebox.border_color = EDITOR_HITBOX_BORDER
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	return stylebox

func _style_lucidity_displays() -> void:
	for coin in [_wallet_coin, _context_price_coin]:
		if coin != null:
			coin.texture = Assets.texture(COIN_ASSET, true)
			coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _wallet_label != null:
		_wallet_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
		_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _context_price_label != null:
		_context_price_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
		_context_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_context_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _description_label != null:
		_description_label.fit_content = true
		_description_label.scroll_active = false
		_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_description_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _power_name_label != null:
		_power_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _context_buy_button != null:
		_center_button_text(_context_buy_button)

func _center_button_text(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in [&"normal", &"pressed", &"hover", &"disabled", &"focus"]:
		var stylebox := button.get_theme_stylebox(state)
		if stylebox != null:
			stylebox.content_margin_left = 0.0
			stylebox.content_margin_right = 0.0

func _refresh_all() -> void:
	if not is_inside_tree():
		return
	var eye_open := _is_eye_open()
	var memory_open := _is_memory_open()
	_eye_overlay.visible = eye_open
	_memory_overlay.visible = memory_open
	_sync_brain_overlay_frames()
	_eye_panel.visible = eye_open
	_memory_panel.visible = memory_open
	if eye_open and not _eye_active and not _eye_opening:
		_eye_terminal.frame = 7
	_refresh_memory_frame()
	_refresh_upgrade_ui()
	_refresh_power_name_box()
	_refresh_context_buy_button()

func _refresh_upgrade_ui() -> void:
	if not is_inside_tree():
		return
	var wallet := _wallet()
	_wallet_label.text = "%d" % wallet
	for id in EYE_UPGRADE_IDS:
		_refresh_row("EyeUpgradePanel", id, id)
	for id in MEMORY_STATIC_UPGRADE_IDS:
		_refresh_row("MemoryUpgradePanel", id, id)
	_refresh_reward_amp_row()

func _sync_brain_overlay_frames() -> void:
	if _brain == null:
		return
	var brain_frame := _brain.frame
	_sync_overlay_to_frame(_eye_overlay, brain_frame)
	_sync_overlay_to_frame(_memory_overlay, brain_frame)

func _sync_overlay_to_frame(overlay: AnimatedSprite2D, brain_frame: int) -> void:
	if overlay == null or not overlay.visible or overlay.sprite_frames == null:
		return
	if not overlay.sprite_frames.has_animation(DEFAULT_ANIMATION):
		return
	var frame_count := overlay.sprite_frames.get_frame_count(DEFAULT_ANIMATION)
	if frame_count <= 0:
		return
	overlay.frame = clampi(brain_frame, 0, frame_count - 1)

func _refresh_row(panel_name: String, row_name: String, upgrade_id: String) -> void:
	var row := get_node_or_null("CanvasLayer/UI_Container/%s/%s" % [panel_name, row_name]) as Control
	if row == null:
		return
	if panel_name == "EyeUpgradePanel" and EYE_ROW_RECTS.has(row_name):
		var rect: Rect2 = EYE_ROW_RECTS[row_name]
		row.position = rect.position
		row.size = rect.size
	elif panel_name == "MemoryUpgradePanel" and MEMORY_ROW_RECTS.has(row_name):
		var rect: Rect2 = MEMORY_ROW_RECTS[row_name]
		row.position = rect.position
		row.size = rect.size
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("upgrade_id", upgrade_id)
	row.set_meta("concept_category", _concept_category_for_upgrade(upgrade_id))
	var upgrade := _upgrade(upgrade_id)
	var name_label := _row_name_label(row)
	if name_label != null:
		name_label.text = _display_name(upgrade_id, upgrade)
		name_label.visible = false
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_reward_amp_row() -> void:
	var next_id := _next_reward_amp_id()
	var row := get_node_or_null("CanvasLayer/UI_Container/MemoryUpgradePanel/reward_amp") as Control
	if row == null:
		return
	if MEMORY_ROW_RECTS.has("reward_amp"):
		var rect: Rect2 = MEMORY_ROW_RECTS["reward_amp"]
		row.position = rect.position
		row.size = rect.size
	var owned_all := next_id.is_empty()
	var id := "corr_reward_amp_3" if owned_all else next_id
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("upgrade_id", id)
	row.set_meta("concept_category", _concept_category_for_upgrade(id))
	var label := _row_name_label(row)
	if label != null:
		label.text = "Rewards+"
		label.visible = false

func _concept_category_for_upgrade(upgrade_id: String) -> String:
	if machine_manipulation_upgrade_ids.has(upgrade_id):
		return MACHINE_MANIPULATION_CATEGORY
	if gain_boost_upgrade_ids.has(upgrade_id):
		return GAIN_BOOST_CATEGORY
	return "Unsorted"

func _display_name(upgrade_id: String, upgrade: Dictionary) -> String:
	if upgrade_id == "perm_shift":
		return "Shift Power"
	if upgrade_id == "pos_learning":
		return "Book Upgrade"
	if upgrade_id == HALLUCINATION_UPGRADE_ID:
		return "Hallucination"
	if upgrade_id == "perm_memory":
		return "Lock"
	if upgrade_id.begins_with("corr_reward_amp"):
		return "Rewards+"
	if upgrade_id == "pos_smart_save":
		return "Saving"
	return String(upgrade.get("name", upgrade_id))

func _row_name_label(row: Control) -> Label:
	var grouped := row.get_node_or_null("Info/NameLabel") as Label
	if grouped != null:
		return grouped
	return row.get_node_or_null("NameLabel") as Label

func _upgrade(upgrade_id: String) -> Dictionary:
	var map := Upgrades.upgrade_map()
	var found: Variant = map.get(upgrade_id, {})
	return found as Dictionary

func _wallet() -> int:
	return editor_preview_wallet if Engine.is_editor_hint() else int(MetaStateStore.lucidityWallet)

func _owned(upgrade_id: String) -> bool:
	if Engine.is_editor_hint():
		return false
	return MetaStateStore.ownedPermanents.has(upgrade_id)

func _requirements_met(upgrade: Dictionary) -> bool:
	if Engine.is_editor_hint():
		return true
	return not upgrade.has("requiresId") or MetaStateStore.ownedPermanents.has(upgrade["requiresId"])

func _next_reward_amp_id() -> String:
	for id in REWARD_AMP_IDS:
		if not _owned(id):
			return id
	return ""

func _upgrade_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for panel in [_eye_panel, _memory_panel]:
		if panel == null:
			continue
		for child in panel.get_children():
			if child is Control and child.has_node("NameLabel"):
				rows.append(child as Control)
	return rows

func _buy_selected_upgrade() -> void:
	if _purchase_animating or _selected_upgrade_row == null:
		_refresh_context_buy_button()
		return
	if Engine.is_editor_hint() or not _selected_upgrade_row.has_meta("upgrade_id"):
		_describe_row(_selected_upgrade_row)
		return
	var upgrade_id := String(_selected_upgrade_row.get_meta("upgrade_id"))
	var upgrade := _upgrade(upgrade_id)
	var price := int(upgrade.get("cost", 0)) if not upgrade.is_empty() else 0
	if _owned(upgrade_id) or price > _wallet() or not _requirements_met(upgrade):
		_refresh_context_buy_button()
		return
	if REWARD_AMP_IDS.has(upgrade_id) and String(MetaStateStore.rewardAmpSymbol) == "":
		_build_reward_amp_picker(upgrade_id)
		return
	await _complete_upgrade_purchase(upgrade_id)

func _complete_upgrade_purchase(upgrade_id: String) -> void:
	_purchase_animating = true
	_refresh_context_buy_button()
	await _animate_money_to_brain()
	MetaStateStore.buy_upgrade(upgrade_id)
	_purchase_animating = false
	_refresh_all()
	_describe_row(_selected_upgrade_row)

func _build_reward_amp_picker(upgrade_id: String) -> void:
	if _reward_amp_picker != null:
		return
	_pending_reward_amp_upgrade_id = upgrade_id
	_reward_amp_picker = Control.new()
	_reward_amp_picker.name = "RewardAmpPicker"
	_reward_amp_picker.size = LAB_SIZE
	_reward_amp_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_reward_amp_picker.z_index = 200
	_ui_container.add_child(_reward_amp_picker)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.1, 0.94)
	panel.position = REWARD_AMP_PICKER_RECT.position
	panel.size = REWARD_AMP_PICKER_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_amp_picker.add_child(panel)

	var title := Label.new()
	title.text = "BOOST SYMBOL"
	title.position = Vector2(REWARD_AMP_PICKER_RECT.position.x, REWARD_AMP_PICKER_RECT.position.y + 3.0)
	title.size = Vector2(REWARD_AMP_PICKER_RECT.size.x, 9.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 7)
	title.add_theme_color_override("font_color", Color(0.72, 1.0, 0.65))
	if Assets.font() != null:
		title.add_theme_font_override("font", Assets.font())
	_reward_amp_picker.add_child(title)

	var cell_w := REWARD_AMP_PICKER_RECT.size.x / float(maxi(1, Symbols.BASE_SYMBOL_CYCLE.size()))
	for i in Symbols.BASE_SYMBOL_CYCLE.size():
		var sym := String(Symbols.BASE_SYMBOL_CYCLE[i])
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(REWARD_AMP_PICKER_RECT.position.x + float(i) * cell_w,
			REWARD_AMP_PICKER_RECT.position.y + 14.0)
		b.size = Vector2(cell_w, 26.0)
		b.pressed.connect(_on_reward_amp_symbol_picked.bind(sym))
		_reward_amp_picker.add_child(b)
		var tex := Assets.texture("symbols/%s.png" % sym, true)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.position = Vector2((cell_w - 16.0) * 0.5, 4.0)
			icon.size = Vector2(16.0, 16.0)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(icon)

func _close_reward_amp_picker() -> void:
	if _reward_amp_picker != null:
		_reward_amp_picker.queue_free()
	_reward_amp_picker = null

func _on_reward_amp_symbol_picked(symbol_id: String) -> void:
	var upgrade_id := _pending_reward_amp_upgrade_id
	_pending_reward_amp_upgrade_id = ""
	_close_reward_amp_picker()
	MetaStateStore.set_reward_amp_symbol(symbol_id)
	await _complete_upgrade_purchase(upgrade_id)

func _animate_money_to_brain() -> void:
	if _ui_container == null or _context_price_group == null:
		return
	var texture := Assets.texture(COIN_ASSET, true)
	if texture == null:
		return
	var start: Vector2 = _context_price_group.get_global_rect().get_center() - _ui_container.get_global_rect().position
	var coin_count: int = 5
	for i in coin_count:
		var coin := Sprite2D.new()
		coin.texture = texture
		coin.centered = true
		coin.position = start + Vector2(float(i - 2) * 2.0, 0.0)
		coin.scale = Vector2(0.75, 0.75)
		coin.z_index = 80
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ui_container.add_child(coin)
		var target: Vector2 = BRAIN_MONEY_TARGET + Vector2(float(i - 2) * 3.0, -absf(float(i - 2)))
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.035)
		tween.tween_property(coin, "position", target, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "scale", Vector2(0.25, 0.25), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(coin.queue_free)
	await get_tree().create_timer(0.62).timeout

func _refresh_context_buy_button() -> void:
	if _context_buy_button == null:
		return
	var row := _selected_upgrade_row
	if row == null or not row.has_meta("upgrade_id") or not _is_selected_row_panel_open(row):
		_context_buy_button.visible = false
		if _context_price_group != null:
			_context_price_group.visible = false
		return
	var upgrade_id := String(row.get_meta("upgrade_id"))
	var upgrade := _upgrade(upgrade_id)
	var owned := _owned(upgrade_id)
	var price := int(upgrade.get("cost", 0)) if not upgrade.is_empty() else 0
	_context_buy_button.visible = true
	_context_buy_button.text = "OWNED" if owned else "BUY"
	_context_buy_button.add_theme_font_size_override("font_size", OWNED_BUTTON_FONT_SIZE if owned else BUY_BUTTON_FONT_SIZE)
	_center_button_text(_context_buy_button)
	_context_buy_button.disabled = _purchase_animating or owned or price > _wallet() or not _requirements_met(upgrade)
	if _context_price_group != null:
		_context_price_group.visible = true
	if _context_price_label != null:
		_context_price_label.text = "%d" % price

func _describe_row(row: Control) -> void:
	if row == null or not row.has_meta("upgrade_id"):
		return
	var upgrade_id := String(row.get_meta("upgrade_id"))
	_set_power_name(_display_name(upgrade_id, _upgrade(upgrade_id)), true, upgrade_id)
	var description := String(DESCRIPTIONS.get(upgrade_id, ""))
	if REWARD_AMP_IDS.has(upgrade_id) and String(MetaStateStore.rewardAmpSymbol) != "":
		description += "\nTarget: %s" % String(MetaStateStore.rewardAmpSymbol).to_upper()
	_set_description(description)

func _inspect_row(event: InputEvent, row: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		_select_row(row)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_select_row(row)
		get_viewport().set_input_as_handled()

func _select_row(row: Control) -> void:
	_selected_upgrade_row = row
	_describe_row(row)
	_refresh_context_buy_button()

func _refresh_power_name_box() -> void:
	if _power_name_box == null or _power_name_label == null:
		return
	if _selected_upgrade_row != null and _selected_upgrade_row.has_meta("upgrade_id") and _is_selected_row_panel_open(_selected_upgrade_row):
		var upgrade_id := String(_selected_upgrade_row.get_meta("upgrade_id"))
		_set_power_name(_display_name(upgrade_id, _upgrade(upgrade_id)), true, upgrade_id)
		return
	if _is_eye_open() or _is_memory_open() or Engine.is_editor_hint():
		_set_power_name("SELECT POWER", true)
	else:
		_set_power_name("", false)

func _set_power_name(text: String, visible: bool, upgrade_id := "") -> void:
	if _power_name_box != null:
		_power_name_box.visible = visible
	if _power_name_label != null:
		_power_name_label.text = text
		# Corrupted upgrades read in purple; anything else falls back to the authored
		# scene colour (remove restores it — no structural UI change). Issue #37.
		if _is_corrupted_upgrade(upgrade_id):
			_power_name_label.add_theme_color_override(&"font_color", corrupt_name_color)
		else:
			_power_name_label.remove_theme_color_override(&"font_color")

func _is_corrupted_upgrade(upgrade_id: String) -> bool:
	return CORRUPTED_NAME_IDS.has(upgrade_id)

func _set_description(text: String) -> void:
	if _description_label != null:
		_description_label.text = "[center]%s[/center]" % text

func _activate_eye() -> void:
	_reset_memory_terminal()
	if _is_eye_open():
		_clear_selected_upgrade()
		_refresh_all()
		return
	_eye_active = true
	_eye_opening = true
	_eye_open_frame = 1
	_eye_open_time = 0.0
	_eye_terminal.frame = _eye_open_frame
	_clear_selected_upgrade()
	_refresh_all()

func _activate_memory() -> void:
	_reset_eye_terminal()
	if _is_memory_open():
		_clear_selected_upgrade()
		_refresh_all()
		return
	_memory_active = true
	_clear_selected_upgrade()
	_refresh_all()

func _reset_eye_terminal() -> void:
	_eye_active = false
	_eye_opening = false
	_eye_open_frame = 1
	_eye_open_time = 0.0
	_eye_idle_time = 0.0
	_eye_idle_wait = _rng.randf_range(1.4, 3.1)
	_eye_idle_frame = -1
	if _eye_terminal != null:
		_eye_terminal.frame = 0

func _reset_memory_terminal() -> void:
	_memory_active = false
	if _memory_terminal != null:
		_memory_terminal.frame = 0

func _go_back() -> void:
	if Engine.is_editor_hint():
		return
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("go_back", START_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(START_MENU_SCENE)

func _is_eye_open() -> bool:
	return _eye_active or (Engine.is_editor_hint() and editor_preview_eye_active)

func _is_memory_open() -> bool:
	return _memory_active or (Engine.is_editor_hint() and editor_preview_memory_active)

func _is_panel_open(panel_name: String) -> bool:
	if panel_name == "EyeUpgradePanel":
		return _is_eye_open()
	if panel_name == "MemoryUpgradePanel":
		return _is_memory_open()
	return false

func _is_selected_row_panel_open(row: Control) -> bool:
	var panel := row.get_parent() as Control
	if panel == null:
		return false
	return _is_panel_open(panel.name)

func _clear_selected_upgrade() -> void:
	_selected_upgrade_row = null
	if _context_buy_button != null:
		_context_buy_button.visible = false
	if _context_price_group != null:
		_context_price_group.visible = false
	if _is_eye_open() or _is_memory_open():
		_set_description(SELECT_POWER_DESCRIPTION)
	else:
		_set_description(DEFAULT_DESCRIPTION)
	_refresh_power_name_box()

func _refresh_memory_frame() -> void:
	if _memory_terminal == null:
		return
	if not _is_memory_open():
		_memory_terminal.frame = 0
		return
	var tier := 0
	for i in REWARD_AMP_IDS.size():
		if _owned(REWARD_AMP_IDS[i]):
			tier = i + 1
	_memory_terminal.frame = clampi(1 + tier, 1, 4)

func _step_background(delta: float) -> void:
	if _bg == null:
		return
	if _bg_flash_frame > BG_FLASH_LAST_FRAME:
		_bg_flash_pause -= delta
		if _bg_flash_pause <= 0.0:
			_bg.frame = BG_DEFAULT_FRAME
			_bg_flash_frame = -1
			_bg_wait = _rng.randf_range(3.0, 4.0)
		return
	if _bg_flash_frame >= 0:
		_bg_flash_pause -= delta
		if _bg_flash_pause > 0.0:
			return
		_bg.frame = _bg_flash_frame
		if _bg_flash_frame == BG_FLASH_LAST_FRAME:
			_bg_flash_frame = BG_FLASH_LAST_FRAME + 1
			_bg_flash_pause = _rng.randf_range(2.0, 3.5)
		else:
			_bg_flash_frame += 1
			_bg_flash_pause = FRAME_TIME
		return
	_bg_wait -= delta
	if _bg_wait <= 0.0:
		_bg_flash_frame = 0
		_bg_flash_pause = 0.0

func _advance_time(sprite: AnimatedSprite2D, frame_count: int, timer: float, delta: float, loops: bool) -> float:
	if sprite == null:
		return timer
	timer += delta
	while timer >= FRAME_TIME:
		timer -= FRAME_TIME
		var next_frame := sprite.frame + 1
		if next_frame >= frame_count:
			next_frame = 0 if loops else frame_count - 1
		sprite.frame = next_frame
	return timer

func _step_bubbles(delta: float) -> void:
	if _bubbles == null:
		return
	if not _bubbles_playing:
		if _bubbles_wait > 0.0:
			_bubbles_wait -= delta
			return
		_bubbles.frame = 0
		_bubbles_time = 0.0
		_bubbles_playing = true
		return
	_bubbles_time += delta
	while _bubbles_time >= FRAME_TIME:
		_bubbles_time -= FRAME_TIME
		if _bubbles.frame >= BUBBLES_REST_FRAME:
			_bubbles.frame = BUBBLES_REST_FRAME
			_bubbles_wait = _rng.randf_range(0.75, 2.4)
			_bubbles_playing = false
			_bubbles_time = 0.0
			return
		_bubbles.frame += 1

func _step_cables(delta: float) -> void:
	if _cables_wait > 0.0:
		_cables_wait -= delta
		return
	var previous := _cables.frame
	_cables_time = _advance_time(_cables, 11, _cables_time, delta, false)
	if previous == 10 and _cables.frame == 10:
		_cables.frame = 0
		_cables_wait = _rng.randf_range(0.25, 0.75)

func _step_sign(delta: float) -> void:
	if _sign_wait > 0.0:
		_sign_wait -= delta
		return
	_sign_time += delta
	if _sign_time < 0.07:
		return
	_sign_time = 0.0
	_lab_sign.frame = 1 - _lab_sign.frame
	_sign_flickers += 1
	if _sign_flickers >= _rng.randi_range(4, 7):
		_lab_sign.frame = 0
		_sign_flickers = 0
		_sign_wait = _rng.randf_range(1.4, 3.0)

func _step_leak(delta: float) -> void:
	if _leak_wait > 0.0:
		_leak_wait -= delta
		return
	var previous := _leak.frame
	_leak_time = _advance_time(_leak, 11, _leak_time, delta, false)
	if previous == 10 and _leak.frame == 10:
		_leak.frame = 0
		_leak_wait = _rng.randf_range(1.0, 2.5)

func _step_eye_terminal(delta: float) -> void:
	if _eye_opening:
		_eye_open_time += delta
		if _eye_open_time < FRAME_TIME:
			return
		_eye_open_time = 0.0
		_eye_terminal.frame = _eye_open_frame
		_eye_open_frame += 1
		if _eye_open_frame > 7:
			_eye_opening = false
			_eye_active = true
			_eye_terminal.frame = 7
			_refresh_all()
		return
	if not _is_eye_open():
		_eye_terminal.frame = 0
		return
	if _eye_idle_frame >= 0:
		_eye_idle_time += delta
		if _eye_idle_time >= FRAME_TIME:
			_eye_idle_time = 0.0
			_eye_terminal.frame = _eye_idle_frame
			_eye_idle_frame += 1
			if _eye_idle_frame >= EYE_TERMINAL_FRAMES:
				_eye_idle_frame = -1
				_eye_terminal.frame = 7
				_eye_idle_wait = _rng.randf_range(1.4, 3.1)
		return
	_eye_idle_wait -= delta
	if _eye_idle_wait <= 0.0:
		_eye_idle_frame = 7
