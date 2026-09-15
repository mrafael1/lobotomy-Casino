@tool
extends Control

## WYSIWYG upgrade hub controller. Visual sprite layers stay as authored scene
## nodes; this script only coordinates frame state, contextual panels, and buys.
##
## Issue #116: each terminal ("eye"/"memory") now shows exactly one power at a
## time, cycled with prev/next navigation (pointer, keyboard ui_left/right or
## ui_up/down, and gamepad — all via the shared ui_* input actions). The
## carousel wraps at the ends: the nav art has no "disabled" frame, so wrapping
## reads better than a dead-ended arrow.

const START_MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const SETTINGS_ASSET := "ui/premium/settings.png"
const SMART_SAVE_UPGRADE_ID := "pos_smart_save"
const REWARD_AMP_IDS: Array[String] = ["corr_reward_amp_1", "corr_reward_amp_2", "corr_reward_amp_3"]
## "" marks the locked/future-achievement slot baked into the new terminal art.
const LOCKED_SLOT_ID := ""
const EYE_CAROUSEL_IDS: Array[String] = ["corr_pattern_23", "pos_learning", "pos_enlightenment", LOCKED_SLOT_ID]
## "reward_amp" is a pseudo-id resolved at display time to whichever reward-amp
## tier is next to buy (or the maxed tier once all are owned).
const REWARD_AMP_SLOT_ID := "reward_amp"
const MEMORY_CAROUSEL_IDS: Array[String] = ["perm_memory", REWARD_AMP_SLOT_ID, SMART_SAVE_UPGRADE_ID, LOCKED_SLOT_ID]
const HALLUCINATION_UPGRADE_ID := "pos_enlightenment"

## Eye terminal sheet (13 frames): 0 closed, 1-4 boot-open growth, 5-9 pattern
## fabrication idle loop, 10 book (static), 11 hallucination (static),
## 12 locked/future (static).
const EYE_TERMINAL_FRAMES := 13
const EYE_BOOT_LAST_FRAME := 4
const EYE_PATTERN_IDLE_START := 5
const EYE_PATTERN_IDLE_END := 9
const EYE_ITEM_STATIC_FRAME := { 1: 10, 2: 11, 3: 12 } # carousel index -> frame (index 0 uses the idle loop)

## Memory terminal sheet (11 frames): 0 closed, 1-3 boot-open growth, 4 lock
## (static), 5-8 reward-amp tiers 0..3 (static per owned tier), 9 smart save
## (static), 10 locked/future (static).
const MEMORY_TERMINAL_FRAMES := 11
const MEMORY_BOOT_LAST_FRAME := 3
const MEMORY_ITEM_STATIC_FRAME := { 0: 4, 2: 9, 3: 10 } # carousel index -> frame (index 1 = reward-amp tier lookup)
const MEMORY_REWARD_AMP_FRAMES := [5, 6, 7, 8] # tier 0..3
## Pixel centers of the three "+" pips baked into the reward-amp card art
## (frame-local, top-left origin — _memory_terminal.centered is false),
## measured from upgrades_scene_memory_upgrades.png. Owned tiers light the
## first N pips with a procedural glow (no new art needed).
const REWARD_AMP_PIP_CENTERS: Array[Vector2] = [Vector2(87.0, 304.0), Vector2(151.0, 304.0), Vector2(215.0, 304.0)]
const REWARD_AMP_GLOW_DIAMETER := 64.0
const REWARD_AMP_GLOW_COLOR := Color(1.0, 0.92, 0.55, 0.9)

const AUTHORED_FRAME_WIDTH := 1280.0
const FRAME_TIME := 0.08
## Closed terminals (frame 0) bob up/down to read as clickable. Whole-pixel
## offsets only, to keep the pixel art crisp on the 160x320 virtual canvas.
const TERMINAL_FLOAT_PERIOD := 2.6
const TERMINAL_FLOAT_AMPLITUDE := 1.0
const TERMINAL_FLOAT_MEMORY_PHASE := PI * 0.5
## Issue #109: closed terminals also flash their contours every couple of
## seconds and answer hover/focus/press, so they read as pressable buttons.
## The light rides self_modulate (the dealer LAB button trick, issue #84) —
## channels >1 brighten the sprite against the dark lab, no new art needed.
## The two computers blink on opposite half-cycles so the room feels alive.
const TERMINAL_BLINK_PERIOD := 2.5
const TERMINAL_BLINK_TIME := 0.7
const TERMINAL_BLINK_MEMORY_OFFSET := TERMINAL_BLINK_PERIOD * 0.5
const TERMINAL_GLOW_BLINK := Color(1.5, 1.45, 1.15)
const TERMINAL_GLOW_HOVER := Color(1.3, 1.28, 1.12)
const TERMINAL_GLOW_PRESSED := Color(0.78, 0.78, 0.88)
const NAV_FLASH_TIME := 0.12
const LAB_SIZE := Vector2(160.0, 240.0)
const DEFAULT_ANIMATION := &"default"
const COIN_ASSET := "ui/premium/coin.png"
const LUCIDITY_COLOR := Color(0.92, 0.86, 0.56)
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_PINK := Color(1.0, 0.5, 0.7)
## Corrupted upgrades render their NAME in purple (issue #37). This is an explicit
## per-upgrade flag, DECOUPLED from the mechanical "corrupted" category: Hallucination
## is a positive-category upgrade but must read as corrupted, while other
## category-corrupted upgrades (e.g. Sedative Protocol, Euphoria Spiral) are NOT flagged.
const CORRUPTED_NAME_IDS: Array[String] = ["corr_pattern_23", HALLUCINATION_UPGRADE_ID,
	"corr_reward_amp_1", "corr_reward_amp_2", "corr_reward_amp_3"]
@export var corrupt_name_color: Color = Color(0.66, 0.33, 0.86)
const BUBBLES_REST_FRAME := 12
const BRAIN_MONEY_TARGET := Vector2(80.0, 128.0)
const BUY_BUTTON_FONT_SIZE := 6
const OWNED_BUTTON_FONT_SIZE := 5
const REWARD_AMP_PICKER_RECT := Rect2(10.0, 136.0, 140.0, 58.0)
const BG_DEFAULT_FRAME := 3
const BG_FLASH_LAST_FRAME := 2
const DEFAULT_DESCRIPTION := "Select a lab terminal."
const LOCKED_SLOT_NAME := "???"
const LOCKED_SLOT_DESCRIPTION := "Unlocks with future achievements."
const DESCRIPTIONS := {
	"perm_shift": "Shift one reel symbol up \n or down during a run.",
	"corr_pattern_23": "Two matching symbols in slots 2 and 3 count as a triple.",
	"pos_learning": "Adds the Book symbol to the reels, but wins it completes are cut by 30%.",
	"pos_enlightenment": "Removes one reel. Visible pairs count as triples, but rewards are cut by 70%.",
	"perm_memory": "Lock a reel before spinning.",
	"corr_reward_amp_1": "Choose one symbol and increase its rewards.\n[color=#183A8C]tier I[/color].",
	"corr_reward_amp_2": "Increase the chosen symbol's rewards.\n[color=#FBBF24]tier II[/color].",
	"corr_reward_amp_3": "Increase the chosen symbol's rewards.\n[color=#D62828]tier III[/color].",
	"pos_smart_save": "Retain 50% of run lucidity on reset instead of 10%.",
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

@onready var _bg := $upgrades_scene_bg as AnimatedSprite2D
@onready var _brain := $upgrades_scene_brain as AnimatedSprite2D
@onready var _bubbles := $upgrades_scene_bubbles as AnimatedSprite2D
@onready var _eye_overlay := $upgrades_scene_eye_brain_overlay as AnimatedSprite2D
@onready var _memory_overlay := $upgrade_scene_memory_brain_overlay as AnimatedSprite2D
@onready var _cables := $upgrades_scene_cables as AnimatedSprite2D
@onready var _layer := $upgrades_scene_layer as Sprite2D
@onready var _eye_terminal := $upgrades_scene_eye_upgrades as AnimatedSprite2D
@onready var _memory_terminal := $upgrades_scene_memory_upgrades as AnimatedSprite2D
@onready var _eye_nav_sprite := $upgrades_scene_eye_buttons as AnimatedSprite2D
@onready var _memory_nav_sprite := $upgrades_scene_memory_buttons as AnimatedSprite2D
@onready var _lab_sign := $upgrades_scene_LAB_SIGN as AnimatedSprite2D
@onready var _leak := $upgrades_scene_leak as AnimatedSprite2D
@onready var _ui_container := $CanvasLayer/UI_Container as Control
@onready var _wallet_label := $CanvasLayer/UI_Container/LucidtyCoinDisplay/Label as Label
@onready var _wallet_coin := $CanvasLayer/UI_Container/LucidtyCoinDisplay/Coin as TextureRect
@onready var _power_name_box := $CanvasLayer/UI_Container/PowerNameBox as Control
@onready var _power_name_label := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PowerNameLabel as Label
@onready var _description_bubble := $CanvasLayer/UI_Container/DescriptionBubble as PanelContainer
@onready var _description_label := $CanvasLayer/UI_Container/DescriptionBubble/DescriptionCenter/Text as RichTextLabel
@onready var _eye_hitbox := $CanvasLayer/UI_Container/EyeComputerHitbox as Button
@onready var _memory_hitbox := $CanvasLayer/UI_Container/MemoryComputerHitbox as Button
@onready var _eye_prev_button := $CanvasLayer/UI_Container/EyePrevButton as Button
@onready var _eye_next_button := $CanvasLayer/UI_Container/EyeNextButton as Button
@onready var _memory_prev_button := $CanvasLayer/UI_Container/MemoryPrevButton as Button
@onready var _memory_next_button := $CanvasLayer/UI_Container/MemoryNextButton as Button
@onready var _buy_stele := $CanvasLayer/UI_Container/BuyStele as Sprite2D
@onready var _context_price_group := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup as Control
@onready var _context_price_label := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup/PriceLabel as Label
@onready var _context_price_coin := $CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup/Coin as TextureRect
@onready var _context_buy_button := $CanvasLayer/UI_Container/ContextBuyButton as Button
@onready var _back_button := $CanvasLayer/UI_Container/BackButton as Button
@onready var _options_button := $CanvasLayer/UI_Container/options as TextureButton
@onready var _options_overlay := $CanvasLayer/OptionsOverlay as OptionsOverlay

var _rng := RandomNumberGenerator.new()
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
var _eye_index := 0
var _memory_index := 0
var _reward_amp_glows: Array[Sprite2D] = []
var _terminal_float_time := 0.0
var _eye_terminal_base_pos := Vector2.ZERO
var _memory_terminal_base_pos := Vector2.ZERO
var _terminal_blink_time := 0.0
var _eye_hitbox_hot := false      # pointer hover or keyboard/controller focus
var _eye_hitbox_pressed := false
var _memory_hitbox_hot := false
var _memory_hitbox_pressed := false

func _ready() -> void:
	custom_minimum_size = Vector2(160.0, 320.0)
	_rng.randomize()
	if _eye_terminal != null:
		_eye_terminal_base_pos = _eye_terminal.position
	if _memory_terminal != null:
		_memory_terminal_base_pos = _memory_terminal.position
	_configure_sprite_frames()
	_configure_layer_visibility()
	_build_reward_amp_glows()
	_bind_buttons()
	UiKit.apply_font(self)
	_style_buttons(self)
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
	_step_terminal_float(delta)
	_step_terminal_glow(delta)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _purchase_animating:
		return
	if SceneNav.is_transition_active():
		return
	# OptionsOverlay owns the whole viewport while visible. Do not let keyboard
	# carousel navigation reach the Lab controls behind the modal.
	if _options_overlay != null and is_instance_valid(_options_overlay) \
			and _options_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_options_overlay.hide_overlay()
			get_viewport().set_input_as_handled()
		return
	# The reward-amp symbol picker is modal: while it is open, carousel
	# navigation must not leak through underneath it.
	if _reward_amp_picker != null:
		return
	if _is_eye_open():
		if event.is_action_pressed("ui_left"):
			_eye_prev()
			_flash_nav_frame(_eye_nav_sprite, 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_eye_next()
			_flash_nav_frame(_eye_nav_sprite, 2)
			get_viewport().set_input_as_handled()
	elif _is_memory_open():
		if event.is_action_pressed("ui_up"):
			_memory_prev()
			_flash_nav_frame(_memory_nav_sprite, 2)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			_memory_next()
			_flash_nav_frame(_memory_nav_sprite, 1)
			get_viewport().set_input_as_handled()

func _configure_sprite_frames() -> void:
	_configure_animated_sprite(_bg, "upgrade_scene/upgrades_scene_bg.png", 4, BG_DEFAULT_FRAME)
	_configure_animated_sprite(_brain, "upgrade_scene/upgrades_scene_brain.png", 15, 0)
	_configure_animated_sprite(_bubbles, "upgrade_scene/upgrades_scene_bubbles.png", 13, BUBBLES_REST_FRAME)
	_configure_animated_sprite(_eye_overlay, "upgrade_scene/upgrades_scene_eye_brain_overlay.png", 15, 0)
	_configure_animated_sprite(_memory_overlay, "upgrade_scene/upgrades_scene_memory_brain_overlay.png", 15, 0)
	_configure_animated_sprite(_cables, "upgrade_scene/upgrades_scene_cables.png", 11, 0)
	_configure_sprite(_layer, 1, 0)
	_configure_animated_sprite(_eye_terminal, "upgrade_scene/upgrades_scene_eye_upgrades.png", EYE_TERMINAL_FRAMES, 0)
	_configure_animated_sprite(_memory_terminal, "upgrade_scene/upgrades_scene_memory_upgrades.png", MEMORY_TERMINAL_FRAMES, 0)
	_configure_animated_sprite(_eye_nav_sprite, "upgrade_scene/upgrades_scene_eye_buttons.png", 3, 0)
	_configure_animated_sprite(_memory_nav_sprite, "upgrade_scene/upgrades_scene_memory_buttons.png", 3, 0)
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
	if _eye_nav_sprite != null:
		_eye_nav_sprite.z_index = 11
	if _memory_nav_sprite != null:
		_memory_nav_sprite.z_index = 11
	if _lab_sign != null:
		_lab_sign.z_index = 20
	if _leak != null:
		_leak.z_index = 30
	if _ui_container != null:
		_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _bind_buttons() -> void:
	UiKit.connect_button(_eye_hitbox, _activate_eye)
	UiKit.connect_button(_memory_hitbox, _activate_memory)
	_bind_terminal_feedback(_eye_hitbox, "eye")
	_bind_terminal_feedback(_memory_hitbox, "memory")
	UiKit.connect_button(_context_buy_button, _buy_selected_upgrade)
	UiKit.connect_button(_back_button, _go_back)
	UiKit.connect_button(_eye_prev_button, _eye_prev)
	UiKit.connect_button(_eye_next_button, _eye_next)
	UiKit.connect_button(_memory_prev_button, _memory_prev)
	UiKit.connect_button(_memory_next_button, _memory_next)
	_bind_nav_press_feedback(_eye_prev_button, _eye_nav_sprite, 1)
	_bind_nav_press_feedback(_eye_next_button, _eye_nav_sprite, 2)
	# MemoryPrevButton sits at the TOP hitbox, MemoryNextButton at the BOTTOM
	# one — the sheet's pressed frames are (1=bottom, 2=top), so prev maps to
	# the top-pressed frame and next to the bottom-pressed frame.
	_bind_nav_press_feedback(_memory_prev_button, _memory_nav_sprite, 2)
	_bind_nav_press_feedback(_memory_next_button, _memory_nav_sprite, 1)
	_bind_options_button()
	for button in [_eye_hitbox, _memory_hitbox, _eye_prev_button, _eye_next_button, _memory_prev_button, _memory_next_button]:
		if button != null:
			button.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
			button.add_theme_stylebox_override(&"pressed", StyleBoxEmpty.new())
			button.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
			button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())

## Swaps the paired arrow sprite to its pressed frame while a nav button is
## held, so pointer, keyboard, and gamepad presses all get the same art feedback.
func _bind_nav_press_feedback(button: Button, sprite: AnimatedSprite2D, pressed_frame: int) -> void:
	if button == null or sprite == null:
		return
	button.button_down.connect(func(): sprite.frame = pressed_frame)
	button.button_up.connect(func(): sprite.frame = 0)

## Keyboard/gamepad nav has no button_down/button_up pair, so briefly show the
## pressed arrow frame and release it after a short beat. Called after the nav
## handler (whose _refresh_all resets the sprite to frame 0), and the release
## only fires if the flash frame is still showing, so a concurrent pointer
## press is never stomped.
func _flash_nav_frame(sprite: AnimatedSprite2D, pressed_frame: int) -> void:
	if sprite == null or not is_inside_tree():
		return
	sprite.frame = pressed_frame
	var release := func() -> void:
		if is_instance_valid(sprite) and sprite.frame == pressed_frame:
			sprite.frame = 0
	get_tree().create_timer(NAV_FLASH_TIME).timeout.connect(release)


func _bind_options_button() -> void:
	if _options_button == null:
		return
	ButtonKit.skin_icon_button(_options_button, SETTINGS_ASSET, 1)
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


func _style_buttons(node: Node) -> void:
	if node is OptionsOverlay:
		return
	var skip_names := ["EyeComputerHitbox", "MemoryComputerHitbox", "EyePrevButton", "EyeNextButton", "MemoryPrevButton", "MemoryNextButton"]
	for child in node.get_children():
		if child is Button:
			var button := child as Button
			if not skip_names.has(button.name):
				if button.name == "BackButton":
					ButtonKit.start_menu_button_style(button, NEON_PINK, 7)
					ButtonKit.start_menu_button_press_feedback(button)
				elif button.name == "ContextBuyButton":
					# This authored hit area is only 22x10, so its nine-slice keeps
					# one-pixel margins instead of increasing the stele geometry.
					ButtonKit.small_neon_button_style(button, NEON_CYAN, 6, 1.0)
					ButtonKit.start_menu_button_press_feedback(button)
				else:
					ButtonKit.skin_sheet_button(button, "ui/green_button.png", 4)
		_style_buttons(child)

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
	if _power_name_box != null:
		var power_style := ButtonKit.neon_panel_style(NEON_CYAN, 3.0)
		power_style.shadow_color = Color(NEON_PINK.r, NEON_PINK.g, NEON_PINK.b, 0.48)
		power_style.shadow_size = 3
		_power_name_box.add_theme_stylebox_override(&"panel", power_style)
	if _description_bubble != null:
		var description_style := ButtonKit.neon_panel_style(NEON_PINK, 6.0)
		description_style.shadow_color = Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.42)
		description_style.shadow_size = 3
		_description_bubble.add_theme_stylebox_override(&"panel", description_style)
	if _description_label != null:
		_description_label.fit_content = true
		_description_label.scroll_active = false
		_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_description_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _power_name_label != null:
		_power_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_power_name_label.add_theme_color_override(&"font_color", NEON_CYAN)
		_power_name_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		_power_name_label.add_theme_constant_override(&"outline_size", 1)
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
	if eye_open and not _eye_active and not _eye_opening:
		_eye_terminal.frame = EYE_PATTERN_IDLE_START
	_refresh_nav_visibility()
	_refresh_memory_frame()
	_refresh_upgrade_ui()
	_refresh_power_name_box()
	_refresh_context_buy_button()

func _refresh_nav_visibility() -> void:
	var eye_open := _is_eye_open()
	var memory_open := _is_memory_open()
	if _eye_nav_sprite != null:
		_eye_nav_sprite.visible = eye_open
		_eye_nav_sprite.frame = 0
	if _memory_nav_sprite != null:
		_memory_nav_sprite.visible = memory_open
		_memory_nav_sprite.frame = 0
	for button in [_eye_prev_button, _eye_next_button]:
		if button != null:
			button.visible = eye_open
			button.disabled = not eye_open
	for button in [_memory_prev_button, _memory_next_button]:
		if button != null:
			button.visible = memory_open
			button.disabled = not memory_open

func _refresh_upgrade_ui() -> void:
	if not is_inside_tree():
		return
	_wallet_label.text = "%d" % _wallet()

## Carousel navigation — wraps at the ends (the nav art has no "disabled" state).
func _eye_prev() -> void:
	if not _is_eye_open() or EYE_CAROUSEL_IDS.is_empty():
		return
	_eye_index = (_eye_index - 1 + EYE_CAROUSEL_IDS.size()) % EYE_CAROUSEL_IDS.size()
	_refresh_all()

func _eye_next() -> void:
	if not _is_eye_open() or EYE_CAROUSEL_IDS.is_empty():
		return
	_eye_index = (_eye_index + 1) % EYE_CAROUSEL_IDS.size()
	_refresh_all()

func _memory_prev() -> void:
	if not _is_memory_open() or MEMORY_CAROUSEL_IDS.is_empty():
		return
	_memory_index = (_memory_index - 1 + MEMORY_CAROUSEL_IDS.size()) % MEMORY_CAROUSEL_IDS.size()
	_refresh_all()

func _memory_next() -> void:
	if not _is_memory_open() or MEMORY_CAROUSEL_IDS.is_empty():
		return
	_memory_index = (_memory_index + 1) % MEMORY_CAROUSEL_IDS.size()
	_refresh_all()

## Resolves the pseudo-id "reward_amp" to whichever reward-amp tier is next to
## buy, or the maxed tier once all are owned — mirrors the old single-row logic.
func _resolve_carousel_id(raw_id: String) -> String:
	if raw_id != REWARD_AMP_SLOT_ID:
		return raw_id
	var next_id := _next_reward_amp_id()
	return "corr_reward_amp_3" if next_id.is_empty() else next_id

## The upgrade id currently shown by whichever terminal is open, or "" if
## neither is open. Distinguishes the locked-placeholder slot (also "") from
## "nothing open" via the separate _is_eye_open()/_is_memory_open() checks at
## call sites — callers that need the locked-slot case check terminal-open
## state first.
func _current_upgrade_id() -> String:
	if _is_eye_open():
		return _resolve_carousel_id(EYE_CAROUSEL_IDS[_eye_index])
	if _is_memory_open():
		return _resolve_carousel_id(MEMORY_CAROUSEL_IDS[_memory_index])
	return ""

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

func _display_name(upgrade_id: String, upgrade: Dictionary) -> String:
	if upgrade_id == LOCKED_SLOT_ID:
		return LOCKED_SLOT_NAME
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

func _buy_selected_upgrade() -> void:
	if _purchase_animating:
		_refresh_context_buy_button()
		return
	if Engine.is_editor_hint():
		return
	var upgrade_id := _current_upgrade_id()
	if upgrade_id == LOCKED_SLOT_ID:
		return
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

	var symbols: Array[String] = []
	for symbol_id in Symbols.BASE_SYMBOL_CYCLE:
		if String(symbol_id) != "flatline":
			symbols.append(String(symbol_id))
	SymbolPicker.build_symbol_picker_panel(_reward_amp_picker, symbols, "", REWARD_AMP_PICKER_RECT,
		Callable(self, "_on_reward_amp_symbol_picked"), Callable(self, "_cancel_reward_amp_picker"),
		true, false, false)

func _on_reward_amp_picker_input(_event: InputEvent) -> void:
	# Reward Amplification requires a symbol choice. The modal blocker consumes
	# outside taps without providing a way to cancel the purchase.
	pass

func _cancel_reward_amp_picker() -> void:
	_pending_reward_amp_upgrade_id = ""
	_close_reward_amp_picker()

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
	# The stele is furniture: it's always visible, whether or not a terminal
	# is open, unlike the interactive BUY button and price, which only make
	# sense once a purchasable power is showing.
	if _buy_stele != null:
		_buy_stele.visible = true
	if not (_is_eye_open() or _is_memory_open()):
		_context_buy_button.visible = false
		if _context_price_group != null:
			_context_price_group.visible = false
		return
	var upgrade_id := _current_upgrade_id()
	if upgrade_id == LOCKED_SLOT_ID:
		_context_buy_button.visible = false
		if _context_price_group != null:
			_context_price_group.visible = false
		return
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

func _refresh_power_name_box() -> void:
	if _power_name_box == null or _power_name_label == null:
		return
	if _is_eye_open() or _is_memory_open():
		var upgrade_id := _current_upgrade_id()
		_set_power_name(_display_name(upgrade_id, _upgrade(upgrade_id)), true, upgrade_id)
		var description := LOCKED_SLOT_DESCRIPTION if upgrade_id == LOCKED_SLOT_ID else String(DESCRIPTIONS.get(upgrade_id, ""))
		if REWARD_AMP_IDS.has(upgrade_id) and String(MetaStateStore.rewardAmpSymbol) != "":
			description += "\nTarget: %s" % String(MetaStateStore.rewardAmpSymbol).to_upper()
		_set_description(description)
		return
	if Engine.is_editor_hint():
		_set_power_name("SELECT POWER", true)
	else:
		_set_power_name("", false)
	_set_description(DEFAULT_DESCRIPTION)

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
		# tr() the description on its own: wrapped in bbcode it is no longer a key, and the
		# label's own auto-translation only ever sees the wrapped string.
		_description_label.text = "[center]%s[/center]" % tr(text)

func _activate_eye() -> void:
	_reset_memory_terminal()
	if _is_eye_open():
		_eye_active = false
		_eye_terminal.frame = 0
		_refresh_all()
		return
	_eye_active = true
	_eye_opening = true
	_eye_open_frame = 1
	_eye_open_time = 0.0
	_eye_index = 0
	_eye_terminal.frame = _eye_open_frame
	_refresh_all()

func _activate_memory() -> void:
	_reset_eye_terminal()
	if _is_memory_open():
		_memory_active = false
		_refresh_all()
		return
	_memory_active = true
	_memory_index = 0
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
		SceneNav.change_to(START_MENU_SCENE)

func _is_eye_open() -> bool:
	return _eye_active or (Engine.is_editor_hint() and editor_preview_eye_active)

func _is_memory_open() -> bool:
	return _memory_active or (Engine.is_editor_hint() and editor_preview_memory_active)

func _refresh_memory_frame() -> void:
	if _memory_terminal == null:
		return
	if not _is_memory_open():
		_memory_terminal.frame = 0
		_set_reward_amp_glow_tier(0)
		return
	var raw_id := MEMORY_CAROUSEL_IDS[_memory_index]
	if raw_id == REWARD_AMP_SLOT_ID:
		var tier := 0
		for i in REWARD_AMP_IDS.size():
			if _owned(REWARD_AMP_IDS[i]):
				tier = i + 1
		_memory_terminal.frame = MEMORY_REWARD_AMP_FRAMES[clampi(tier, 0, MEMORY_REWARD_AMP_FRAMES.size() - 1)]
		_set_reward_amp_glow_tier(tier)
		return
	_memory_terminal.frame = int(MEMORY_ITEM_STATIC_FRAME.get(_memory_index, 0))
	_set_reward_amp_glow_tier(0)

## Builds a small radial-gradient glow sprite per reward-amp pip (no new art
## needed — procedural GradientTexture2D), parented under _memory_terminal so
## it inherits the terminal's 0.125 scale and lines up with the baked pips.
func _build_reward_amp_glows() -> void:
	if _memory_terminal == null or not _reward_amp_glows.is_empty():
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.width = int(REWARD_AMP_GLOW_DIAMETER)
	glow_texture.height = int(REWARD_AMP_GLOW_DIAMETER)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for center in REWARD_AMP_PIP_CENTERS:
		var glow := Sprite2D.new()
		glow.name = "RewardAmpGlow%d" % _reward_amp_glows.size()
		glow.texture = glow_texture
		glow.material = material
		glow.position = center
		glow.modulate = REWARD_AMP_GLOW_COLOR
		glow.visible = false
		_memory_terminal.add_child(glow)
		_reward_amp_glows.append(glow)

func _set_reward_amp_glow_tier(tier: int) -> void:
	for i in _reward_amp_glows.size():
		_reward_amp_glows[i].visible = i < tier

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
		if _eye_open_frame > EYE_BOOT_LAST_FRAME:
			_eye_opening = false
			_eye_active = true
			_eye_terminal.frame = EYE_PATTERN_IDLE_START
			_refresh_all()
		return
	if not _is_eye_open():
		_eye_terminal.frame = 0
		return
	# Only the pattern-fabrication slot (carousel index 0) has an idle-loop
	# animation; the other items show a single static frame (set in
	# _refresh_all/_refresh_all's caller instead of here).
	if _eye_index != 0:
		_eye_idle_frame = -1
		_eye_terminal.frame = int(EYE_ITEM_STATIC_FRAME.get(_eye_index, EYE_PATTERN_IDLE_START))
		return
	if _eye_idle_frame >= 0:
		_eye_idle_time += delta
		if _eye_idle_time >= FRAME_TIME:
			_eye_idle_time = 0.0
			# Let the counter run one past the end so the last loop frame
			# holds for a full FRAME_TIME before the rest branch takes over.
			if _eye_idle_frame > EYE_PATTERN_IDLE_END:
				_eye_idle_frame = -1
				_eye_idle_wait = _rng.randf_range(1.4, 3.1)
				_eye_terminal.frame = EYE_PATTERN_IDLE_START
			else:
				_eye_terminal.frame = _eye_idle_frame
				_eye_idle_frame += 1
		return
	# Resting on the pattern-fabrication slot: always show its rest frame
	# immediately (never leave a stale frame from a previously-shown item
	# lingering until the ambient idle-wait timer happens to expire).
	_eye_terminal.frame = EYE_PATTERN_IDLE_START
	_eye_idle_wait -= delta
	if _eye_idle_wait <= 0.0:
		_eye_idle_frame = EYE_PATTERN_IDLE_START

func _step_terminal_float(delta: float) -> void:
	_terminal_float_time = fmod(_terminal_float_time + delta, TERMINAL_FLOAT_PERIOD)
	var phase := _terminal_float_time / TERMINAL_FLOAT_PERIOD * TAU
	_apply_terminal_float(_eye_terminal, _eye_terminal_base_pos, phase)
	_apply_terminal_float(_memory_terminal, _memory_terminal_base_pos, phase + TERMINAL_FLOAT_MEMORY_PHASE)

func _apply_terminal_float(terminal: AnimatedSprite2D, base_pos: Vector2, phase: float) -> void:
	if terminal == null:
		return
	if terminal.frame != 0:
		terminal.position = base_pos
		return
	terminal.position = base_pos + Vector2(0.0, round(sin(phase) * TERMINAL_FLOAT_AMPLITUDE))

## Issue #109: hover/focus and press feedback on the computer hitboxes, mirrored
## onto the terminal art (the hitbox Buttons themselves are invisible).
func _bind_terminal_feedback(hitbox: Button, terminal_id: String) -> void:
	if hitbox == null:
		return
	hitbox.mouse_entered.connect(_set_terminal_hot.bind(terminal_id, true))
	hitbox.mouse_exited.connect(_set_terminal_hot.bind(terminal_id, false))
	hitbox.focus_entered.connect(_set_terminal_hot.bind(terminal_id, true))
	hitbox.focus_exited.connect(_set_terminal_hot.bind(terminal_id, false))
	hitbox.button_down.connect(_set_terminal_pressed.bind(terminal_id, true))
	hitbox.button_up.connect(_set_terminal_pressed.bind(terminal_id, false))

func _set_terminal_hot(terminal_id: String, hot: bool) -> void:
	if terminal_id == "eye":
		_eye_hitbox_hot = hot
	else:
		_memory_hitbox_hot = hot

func _set_terminal_pressed(terminal_id: String, pressed: bool) -> void:
	if terminal_id == "eye":
		_eye_hitbox_pressed = pressed
	else:
		_memory_hitbox_pressed = pressed

## Issue #109: while a terminal is closed (frame 0 — the "press me" state) its
## contours flash bright once per blink cycle; hover/focus holds the light on
## and a press dips it, so the computer answers the pointer like a real button.
## Open terminals are active UI, not buttons — they render untinted.
func _step_terminal_glow(delta: float) -> void:
	_terminal_blink_time = fmod(_terminal_blink_time + delta, TERMINAL_BLINK_PERIOD)
	_apply_terminal_glow(_eye_terminal, _eye_hitbox_hot, _eye_hitbox_pressed, 0.0)
	_apply_terminal_glow(_memory_terminal, _memory_hitbox_hot, _memory_hitbox_pressed,
		TERMINAL_BLINK_MEMORY_OFFSET)

func _apply_terminal_glow(terminal: AnimatedSprite2D, hot: bool, pressed: bool,
		blink_offset: float) -> void:
	if terminal == null:
		return
	if terminal.frame != 0:
		terminal.self_modulate = Color.WHITE
		return
	if pressed:
		terminal.self_modulate = TERMINAL_GLOW_PRESSED
		return
	if hot:
		terminal.self_modulate = TERMINAL_GLOW_HOVER
		return
	var t := fmod(_terminal_blink_time + blink_offset, TERMINAL_BLINK_PERIOD)
	if t >= TERMINAL_BLINK_TIME:
		terminal.self_modulate = Color.WHITE
		return
	# One smooth flash per cycle: sine ramp up to the glow peak and back down.
	terminal.self_modulate = Color.WHITE.lerp(TERMINAL_GLOW_BLINK, sin(t / TERMINAL_BLINK_TIME * PI))
