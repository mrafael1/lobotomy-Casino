@tool
extends Control

## Start-run menu (issue #21) — the game's launch screen. From here the player
## starts a new run through the dealer pre-run shop, or continues an active run
## directly in the machine.
##
## Flow: launch -> this menu -> START RUN -> dealer (pre-run shop) -> machine run.
## If RunStateStore still has an active run, START RUN becomes CONTINUE and routes
## straight back to the machine with the current score/spins/consumables intact.
## The dealer scene self-detects pre-run mode from RunStateStore.runPhase, so no
## state has to be threaded through the scene change here.
##
## Rendering (issue #111): the whole menu is the authored start_menu.png sheet —
## frame 0 before the Augmented Run unlock (three empty button plates), frame 1
## after (start plate, suit selector bar with baked arrows, two plates). Button
## labels are live text drawn over the empty plates. The selected suit renders
## through start_menu_augmented symbols.png, a full-canvas 6-frame sheet
## (no augment, heart, diamond, spade, club, joker) aligned with the bar.

const DEALER_SCENE := "res://scenes/dealer_scene.tscn"
const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const OPTIONS_OVERLAY_SCENE := preload("res://scenes/options_overlay.tscn")
const CANVAS_W := 160.0
const CANVAS_H := 320.0
const MENU_W := 148.0

# Authored menu frames (issue #111). Legacy fallback background if missing.
const MENU_FRAMES_ASSET := "start_menu/start_menu.png"                    # 2 frames
const MENU_SYMBOLS_ASSET := "start_menu/start_menu_augmented symbols.png" # 6 frames
const MENU_BG_ASSET := "start_menu/neon_casino_background.png"

# Baked plate rects (canvas px, frame-relative), measured on start_menu.png.
const ART_START_RECT := Rect2(10.0, 143.0, 140.0, 25.0)
const ART_SCORES_LOCKED_RECT := Rect2(30.0, 178.0, 101.0, 25.0)
const ART_OPTIONS_LOCKED_RECT := Rect2(30.0, 213.0, 101.0, 25.0)
const ART_SELECTOR_RECT := Rect2(11.0, 178.0, 139.0, 37.0)
const ART_SCORES_UNLOCKED_RECT := Rect2(29.0, 226.0, 103.0, 24.0)
const ART_OPTIONS_UNLOCKED_RECT := Rect2(29.0, 262.0, 103.0, 24.0)
# Free strips around the baked plates: hint under the title, meter at the bottom.
const ART_HINT_RECT := Rect2(5.0, 118.0, 150.0, 22.0)
# The pixel font's line box leaves its slack above the glyphs, so the rect sits
# a few px above the selector-to-SCORES gap to land the text inside it.
const ART_DESC_RECT := Rect2(5.0, 209.0, 150.0, 10.0)
const ART_METER_CENTER_LOCKED := Vector2(80.0, 262.0)
const ART_METER_CENTER_UNLOCKED := Vector2(80.0, 301.0)
const ART_METER_SCALE_LOCKED := 1.0
const ART_METER_SCALE_UNLOCKED := 2.5

# Neon label colors matching the baked plate outlines.
const ART_CYAN := Color(0.42, 1.0, 0.95)
const ART_PINK := Color(1.0, 0.5, 0.7)
const ART_YELLOW := Color(1.0, 0.86, 0.36)

# Augmented Run (issue #111): tier selector shown under START RUN once wealth
# has been reached. Cycling picks one suit modifier (joker = all four).
const AUGMENTED_DESCRIPTIONS := {
	"": "CLASSIC RUN",
	"heart": "JACKPOT 100, NO FREE SPIN",
	"spade": "END-OF-RUN GAIN HALVED",
	"diamond": "MAX 2 POWERS PER SPIN",
	"club": "DEALER + REWARDS HALVED",
	"joker": "ALL FOUR MODIFIERS",
}

@export_group("First Launch Tutorial")
@export var tutorial_pauses_tree: bool = true
@export var tutorial_title_text: String = "HOW TO PLAY"
@export_multiline var tutorial_bbcode: String = """[color=#d9f0ff][b]The Objective[/b][/color]
- Run 10 neurons -> attain wealth before hitting 0.

[color=#f2d37c][b]Dealer Scene[/b][/color]
- Buy consumables for your run.
- Effects are vague. Try them all to discover what they do.
- Inventory limit: 2 consumables max.

[color=#c6f08a][b]Upgrades Scene[/b][/color]
- Purchase upgrades for your run.
- Acquire powers that manipulate the machine.
- Boost your overall gains.

[color=#ff9ca8][b]Machine Scene[/b][/color]
- You have 35 spins with x1, x2, or x3 bets.
- The Dealer can pop up mid-run with run-only items.
- You always start with the "Reroll" power.
- 1 random power restores every 50 coins obtained."""

# ── campaign rebalance (issue #38) ────────────────────────────────────────────────
@export_group("Campaign")
## Game-over flatline copy — byte-for-byte from the GDD.
@export var fatal_flatline_text: String = "this time, it's fatal. No coming back"

var _font: FontFile = null
var _use_art := false
var _menu_sprite: Sprite2D = null      # start_menu.png, frame 0 locked / 1 unlocked
var _symbols_sprite: Sprite2D = null   # suit overlay, frame per selection
var _background: Sprite2D = null
var _start_button: Button = null
var _scores_button: Button = null
var _options_button: Button = null
var _options_overlay: OptionsOverlay = null
var _campaign_label: Label = null
var _campaign_meter: NeuronMeter = null # issue #38 pixel-art neuron meter
var _campaign_hint: Label = null
var _augmented_row: Control = null
var _augmented_desc: Label = null
var _selected_augmented_tier := ""
var _tutorial_modal: Control = null
var _tutorial_title: Label = null
var _tutorial_body: RichTextLabel = null
var _tutorial_button: Button = null

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_scene_nodes()
	_use_art = Assets.texture(MENU_FRAMES_ASSET, true) != null
	if _use_art:
		_build_art_menu()
	else:
		_build_background()
		_build_menu()
	if not Engine.is_editor_hint() and not RunStateStore.state_changed.is_connected(_refresh_start_button):
		RunStateStore.state_changed.connect(_refresh_start_button)
	if not Engine.is_editor_hint() and not MetaStateStore.meta_changed.is_connected(_refresh_campaign_ui):
		MetaStateStore.meta_changed.connect(_refresh_campaign_ui)
	_refresh_start_button()
	_refresh_campaign_ui()
	_configure_tutorial_modal()
	_maybe_show_tutorial()

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and tutorial_pauses_tree and get_tree().paused:
		get_tree().paused = false

func _bind_scene_nodes() -> void:
	_background = get_node_or_null("Background")
	_start_button = get_node_or_null("MenuColumn/StartButton")
	_scores_button = get_node_or_null("MenuColumn/ScoresButton")
	_campaign_label = get_node_or_null("MenuColumn/CampaignLabel")
	_campaign_hint = get_node_or_null("MenuColumn/CampaignHint")
	_tutorial_modal = get_node_or_null("TutorialModal") as Control
	_tutorial_title = get_node_or_null("TutorialModal/Panel/Margin/Content/Title") as Label
	_tutorial_body = get_node_or_null("TutorialModal/Panel/Margin/Content/Body") as RichTextLabel
	_tutorial_button = get_node_or_null("TutorialModal/Panel/Margin/Content/OkButton") as Button

# ── authored-frame menu (issue #111) ─────────────────────────────────────────────────

## Full-canvas sheet sprite scaled so one frame covers the 160x320 canvas.
## The frames are authored at native canvas resolution and only ever UPSCALE
## on screen, so they sample NEAREST — linear would soften the pixel art
## (mipmapped linear is only right for the high-res downscaled sheets).
func _frame_sprite(rel: String, hframes: int) -> Sprite2D:
	var tex := Assets.texture(rel)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = 0
	spr.centered = false
	spr.position = Vector2.ZERO
	var frame_w := float(tex.get_width()) / float(hframes)
	spr.scale = Vector2(CANVAS_W / frame_w, CANVAS_H / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr

func _build_art_menu() -> void:
	# The frames bake the full screen (background, title, plates); the legacy
	# scenery nodes stay hidden underneath.
	for node_name in ["Background", "Dim"]:
		var n := get_node_or_null(String(node_name)) as CanvasItem
		if n != null:
			n.visible = false
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	_menu_sprite = _frame_sprite(MENU_FRAMES_ASSET, 2)
	_menu_sprite.name = "MenuArt"
	_symbols_sprite = _frame_sprite(MENU_SYMBOLS_ASSET, 6)
	if _symbols_sprite != null:
		_symbols_sprite.name = "AugmentedSymbols"
		_symbols_sprite.visible = false

	# The scene's buttons move out of the VBox onto the baked plates.
	_reparent_plate_button(_start_button, col, ART_START_RECT, ART_CYAN, 10, _start_run)
	_reparent_plate_button(_scores_button, col, ART_SCORES_LOCKED_RECT, ART_PINK, 8, _open_scores)
	_options_button = Button.new()
	_options_button.name = "OptionsButton"
	_options_button.text = "OPTIONS"
	add_child(_options_button)
	_style_plate_button(_options_button, ART_OPTIONS_LOCKED_RECT, ART_YELLOW, 8)
	_options_button.pressed.connect(_toggle_options_overlay)
	if col != null:
		col.visible = false

	# Suit selector: invisible hit areas over the bar's baked arrows; the suit
	# itself comes from the symbols sheet overlay.
	_augmented_row = Control.new()
	_augmented_row.name = "AugmentedSelector"
	_augmented_row.position = ART_SELECTOR_RECT.position
	_augmented_row.size = ART_SELECTOR_RECT.size
	add_child(_augmented_row)
	_augmented_row.add_child(_augmented_arrow_button(-1, ART_SELECTOR_RECT.size))
	_augmented_row.add_child(_augmented_arrow_button(1, ART_SELECTOR_RECT.size))
	_augmented_desc = _overlay_label("AugmentedDescription", ART_DESC_RECT, 5, ART_YELLOW)

	# Campaign meter + hint live in the frame's free strips (issue #38).
	_campaign_hint = _overlay_label("CampaignHint", ART_HINT_RECT, 5, Color(0.9, 0.78, 0.64))
	_campaign_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Options overlay (shared component; same one the machine/dealer scenes use).
	if not Engine.is_editor_hint():
		_options_overlay = OPTIONS_OVERLAY_SCENE.instantiate() as OptionsOverlay
		_options_overlay.name = "OptionsOverlay"
		add_child(_options_overlay)

func _overlay_label(label_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = label_name
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 1)
	add_child(l)
	return l

## Moves a tscn menu button out of the VBox and turns it into live text over a
## baked plate: transparent styleboxes, neon text color, press-sink feedback.
func _reparent_plate_button(b: Button, col: VBoxContainer, rect: Rect2,
		color: Color, font_size: int, cb: Callable) -> void:
	if b == null:
		return
	if col != null and b.get_parent() == col:
		col.remove_child(b)
		add_child(b)
	_style_plate_button(b, rect, color, font_size)
	_connect_button(b, cb)

func _style_plate_button(b: Button, rect: Rect2, color: Color, font_size: int) -> void:
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = Vector2.ZERO
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(String(state), StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 1.0, 1.0, 0.7)
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		b.add_theme_font_override("font", _font)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", color)

## Invisible hit area over a baked arrow third of the selector bar.
func _augmented_arrow_button(step: int, bar_size: Vector2) -> Button:
	var b := Button.new()
	b.name = "CycleLeft" if step < 0 else "CycleRight"
	b.position = Vector2(0.0 if step < 0 else bar_size.x * 0.7, 0.0)
	b.size = Vector2(bar_size.x * 0.3, bar_size.y)
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(_cycle_augmented_tier.bind(step))
	return b

func _toggle_options_overlay() -> void:
	if _options_overlay != null:
		_options_overlay.toggle_overlay()

## Which authored layout is on screen: frame 1 only when the selector is usable
## (unlocked AND no held run — modifiers can't change mid-run).
func _augmented_layout_active() -> bool:
	if Engine.is_editor_hint():
		return false
	return MetaStateStore.augmentedRunUnlocked and RunStateStore.runPhase != "running"

## Repositions the plate buttons, meter and hint for the current frame layout.
func _layout_art_menu(augmented: bool) -> void:
	if _menu_sprite != null:
		_menu_sprite.frame = 1 if augmented else 0
	if _scores_button != null:
		_style_plate_button(_scores_button,
			ART_SCORES_UNLOCKED_RECT if augmented else ART_SCORES_LOCKED_RECT, ART_PINK, 8)
	if _options_button != null:
		_style_plate_button(_options_button,
			ART_OPTIONS_UNLOCKED_RECT if augmented else ART_OPTIONS_LOCKED_RECT, ART_YELLOW, 8)
	_place_campaign_meter(augmented)

## The meter sizes itself from its art; the unlocked frame only leaves the strip
## under OPTIONS, so it renders at half size there (asset_scale escape hatch).
func _place_campaign_meter(augmented: bool) -> void:
	if Engine.is_editor_hint():
		return
	var wanted_scale := ART_METER_SCALE_UNLOCKED if augmented else ART_METER_SCALE_LOCKED
	if _campaign_meter != null and not is_equal_approx(_campaign_meter.asset_scale, wanted_scale):
		_campaign_meter.queue_free()
		_campaign_meter = null
	if _campaign_meter == null:
		_campaign_meter = NeuronMeter.new()
		_campaign_meter.asset_scale = wanted_scale
		add_child(_campaign_meter) # _ready sizes the control to the authored frame
	var center := ART_METER_CENTER_UNLOCKED if augmented else ART_METER_CENTER_LOCKED
	_campaign_meter.position = center - _campaign_meter.size * 0.5
	_campaign_meter.refresh()

# ── legacy fallback (frames asset missing) ───────────────────────────────────────────

func _build_background() -> void:
	if _background != null:
		var neon := Assets.texture(MENU_BG_ASSET, true)
		if neon != null:
			_background.texture = neon
			_background.centered = false
			_background.position = Vector2.ZERO
			_background.scale = Vector2(CANVAS_W / neon.get_width(), CANVAS_H / neon.get_height())
			var dim := get_node_or_null("Dim") as ColorRect
			if dim != null:
				dim.color = Color(0.02, 0.01, 0.04, 0.42)
		_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(MENU_W, 0.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	return l

func _build_menu() -> void:
	_build_campaign_labels()
	_connect_button(_start_button, _start_run)
	_connect_button(_scores_button, _open_scores)

func _build_campaign_labels() -> void:
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	if col == null:
		return
	if _campaign_label == null:
		_campaign_label = _label("", 8, Color(0.8, 0.95, 1.0))
		_campaign_label.name = "CampaignLabel"
		col.add_child(_campaign_label)
	if _campaign_hint == null:
		_campaign_hint = _label("", 7, Color(0.9, 0.78, 0.64))
		_campaign_hint.name = "CampaignHint"
		col.add_child(_campaign_hint)
	_campaign_hint.custom_minimum_size = Vector2(MENU_W, 18.0)
	_campaign_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_hint.clip_text = false
	var start_index := _start_button.get_index() if _start_button != null else col.get_child_count()
	col.move_child(_campaign_label, maxi(0, start_index))
	col.move_child(_campaign_hint, maxi(0, start_index + 1))

# ── Augmented Run selector state (issue #111) ────────────────────────────────────────

func _cycle_augmented_tier(step: int) -> void:
	var cycle := RunStateStore.AUGMENTED_TIER_CYCLE
	var idx := cycle.find(_selected_augmented_tier)
	idx = (idx + step + cycle.size()) % cycle.size()
	_selected_augmented_tier = cycle[idx]
	_refresh_augmented_selector()
	_refresh_start_button()

func _refresh_augmented_selector() -> void:
	if _augmented_row == null:
		return
	var shown := _augmented_layout_active()
	_augmented_row.visible = shown
	if _use_art:
		_layout_art_menu(shown)
	if _symbols_sprite != null:
		_symbols_sprite.visible = shown
		var cycle := RunStateStore.AUGMENTED_TIER_CYCLE
		_symbols_sprite.frame = clampi(cycle.find(_selected_augmented_tier), 0,
			_symbols_sprite.hframes - 1)
	if _augmented_desc != null:
		_augmented_desc.visible = shown
		_augmented_desc.text = String(AUGMENTED_DESCRIPTIONS.get(_selected_augmented_tier, ""))

func _refresh_start_button() -> void:
	if _start_button == null:
		return
	# Run-phase changes also gate the selector (hidden while a run is held).
	_refresh_augmented_selector()
	var continuing := not Engine.is_editor_hint() and RunStateStore.runPhase == "running"
	if continuing:
		_start_button.text = "CONTINUE"
		_start_button.add_theme_font_size_override("font_size", 10)
	elif not Engine.is_editor_hint() and (MetaStateStore.campaignFailed or MetaStateStore.wealthEndingReached):
		_start_button.text = "START FRESH AGAIN"
		_start_button.add_theme_font_size_override("font_size", 8)
	elif not Engine.is_editor_hint() and MetaStateStore.augmentedRunUnlocked \
			and _selected_augmented_tier != "":
		_start_button.text = "AUGMENTED RUN"
		_start_button.add_theme_font_size_override("font_size", 9)
	else:
		_start_button.text = "START RUN"
		_start_button.add_theme_font_size_override("font_size", 10)
	if _font != null:
		_start_button.add_theme_font_override("font", _font)

func _refresh_campaign_ui() -> void:
	if _campaign_hint == null:
		return
	if Engine.is_editor_hint():
		_campaign_hint.text = "EACH RETURN COSTS ONE"
		return
	if not _use_art:
		# Issue #38: the meter replaces the text; the label holds its menu slot.
		if _campaign_label != null:
			_campaign_label.text = ""
			if _campaign_meter == null:
				_campaign_meter = NeuronMeter.attach(_campaign_label, Vector2(MENU_W * 0.5, 0.0))
				_campaign_label.custom_minimum_size = Vector2(0.0, _campaign_meter.size.y)
				_campaign_meter.position = Vector2(MENU_W * 0.5, _campaign_meter.size.y * 0.5) \
					- _campaign_meter.size * 0.5
			_campaign_meter.refresh()
	if MetaStateStore.campaignFailed:
		_campaign_hint.text = fatal_flatline_text
	elif MetaStateStore.wealthEndingReached:
		_campaign_hint.text = "WEALTH ENDING REACHED."
	elif MetaStateStore.campaignNeuronsLeft <= 0:
		_campaign_hint.text = "NO NEURONS. RETURNING ENDS THIS MIND."
	else:
		_campaign_hint.text = "EACH RETURN COSTS ONE. REACH WEALTH BEFORE ZERO."
	_refresh_start_button() # also lays out the art frame + meter

func _connect_button(button: Button, cb: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)

func _configure_tutorial_modal() -> void:
	if _tutorial_modal == null:
		return
	_tutorial_modal.visible = Engine.is_editor_hint()
	_tutorial_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	if _tutorial_title != null:
		_tutorial_title.text = tutorial_title_text
		_tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tutorial_title.add_theme_font_size_override("font_size", 10)
		if _font != null:
			_tutorial_title.add_theme_font_override("font", _font)
	if _tutorial_body != null:
		_tutorial_body.bbcode_enabled = true
		_tutorial_body.text = tutorial_bbcode
		_tutorial_body.fit_content = false
		_tutorial_body.scroll_active = false
		_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_body.add_theme_font_size_override("normal_font_size", 5)
		_tutorial_body.add_theme_font_size_override("bold_font_size", 5)
		_tutorial_body.add_theme_color_override("default_color", Color(0.94, 0.88, 1.0))
		if _font != null:
			_tutorial_body.add_theme_font_override("normal_font", _font)
			_tutorial_body.add_theme_font_override("bold_font", _font)
	if _tutorial_button != null:
		_tutorial_button.text = "UNDERSTOOD"
		_tutorial_button.process_mode = Node.PROCESS_MODE_ALWAYS
		_tutorial_button.add_theme_font_size_override("font_size", 6)
		if _font != null:
			_tutorial_button.add_theme_font_override("font", _font)
		if not _tutorial_button.pressed.is_connected(_dismiss_tutorial):
			_tutorial_button.pressed.connect(_dismiss_tutorial)

func _maybe_show_tutorial() -> void:
	if Engine.is_editor_hint() or _tutorial_modal == null:
		return
	if not MetaStateStore.is_first_launch:
		_tutorial_modal.visible = false
		return
	_tutorial_modal.visible = true
	if _tutorial_button != null:
		_tutorial_button.grab_focus()
	if tutorial_pauses_tree:
		get_tree().paused = true

func _dismiss_tutorial(save_immediately := true) -> void:
	if _tutorial_modal != null:
		_tutorial_modal.visible = false
	if tutorial_pauses_tree:
		get_tree().paused = false
	if not Engine.is_editor_hint():
		MetaStateStore.mark_tutorial_seen(save_immediately)

func _start_run() -> void:
	if not Engine.is_editor_hint() and RunStateStore.runPhase == "running":
		get_tree().change_scene_to_file(MACHINE_SCENE)
		return
	if not Engine.is_editor_hint() and (MetaStateStore.campaignFailed or MetaStateStore.wealthEndingReached):
		MetaStateStore.start_new_campaign()
		RunStateStore.reset_run_state()
		_refresh_campaign_ui()
		return
	if not Engine.is_editor_hint() and not MetaStateStore.can_start_campaign_run():
		MetaStateStore.mark_campaign_failed()
		_refresh_campaign_ui()
		return
	# Augmented Run (issue #111): the picked suit applies to the run this visit
	# starts. Set here (after every reset path above) so start_new_run keeps it.
	if not Engine.is_editor_hint():
		RunStateStore.augmentedTier = _selected_augmented_tier \
			if MetaStateStore.augmentedRunUnlocked else ""
	# Begin a fresh run by visiting the dealer FIRST; the dealer scene runs in
	# pre-run shop mode and starts the run once the player leaves the counter.
	get_tree().change_scene_to_file(DEALER_SCENE)

func _open_scores() -> void:
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("push_current_scene")
	get_tree().change_scene_to_file(SCORES_SCENE)
