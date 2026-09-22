extends Control

# The visual menu is assembled at runtime. Keep this script runtime-only so
# generated layers and reparented buttons cannot be serialized into the scene
# while it is open in the 2D editor.

## Start-run menu (issue #21) — the game's launch screen. From here the player
## starts a new run through Pacte, or continues an active run in its saved phase.
##
## Flow: launch -> this menu -> START RUN -> Pacte -> machine run.
## If RunStateStore still has a resumable session, START RUN becomes CONTINUE and
## routes back to Pacte, the dealer, or the machine with the current session intact.
##
## Rendering: the menu uses the scene's live controls and simple fallback
## background. The authored full-screen start_menu sheet is no longer loaded.

const DEALER_SCENE := "res://scenes/dealer_scene.tscn"
const PACTE_SCENE := "res://scenes/pacte_scene.tscn"
const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const ROUTE_SCENE := "res://scenes/dealer_choice_scene.tscn"
const ROUTE_BUILD_SCENE := "res://scenes/route_build_scene.tscn"
const ROUTE_BONUS_SCENE := "res://scenes/route_bonus_scene.tscn"
const SACRIFICE_SCENE := "res://scenes/sacrifice_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const OPTIONS_OVERLAY_SCENE := preload("res://scenes/options_overlay.tscn")
const CANVAS_W := 160.0
const CANVAS_H := 320.0
const MENU_W := 148.0
const CLOSE_BUTTON_SIZE := Vector2(12.0, 12.0)
const CLOSE_BUTTON_INSET := Vector2(16.0, 3.0) # in from the modal's top-right corner

# The retired full-screen menu sheet is no longer loaded. The live menu uses
# the title and button plates as separate overlays over the casino backdrop.
const MENU_TITLE_RECT := Rect2(6, 48, 148, 66)
const MENU_SELECTOR_ART_RECT := Rect2(8, 176, 144, 41)
const MENU_TITLE_ASSET := "ui/premium/menu_title_plate.svg"
const MENU_SYMBOLS_ASSET := "scores_polished/suits.svg" # 6 frames
const MENU_AUGMENTED_BAR_ASSET := "ui/premium/menu_selector_brass.svg"
# Standalone button plates (full-canvas overlays): the plate squashes together
# with its label on press. START is one frame; SCORES/OPTIONS carry two frames
# (locked | unlocked positions). The selector bar stays baked — no press art.
const MENU_START_PLATE_ASSET := "start_menu/start_menu_start_button.png"
const MENU_SCORES_PLATE_ASSET := "start_menu/start_menu_score_button.png"
const MENU_OPTIONS_PLATE_ASSET := "start_menu/start_menu_options_button.png"

# Baked plate rects (canvas px, frame-relative), retained for compatibility
# with the live selector layout.
const ART_START_RECT := Rect2(10.0, 143.0, 140.0, 25.0)
const ART_SCORES_LOCKED_RECT := Rect2(30.0, 178.0, 101.0, 25.0)
const ART_OPTIONS_LOCKED_RECT := Rect2(30.0, 213.0, 101.0, 25.0)
const ART_SELECTOR_RECT := Rect2(11.0, 178.0, 139.0, 37.0)
# Transparent arrow sprites pivot within these measured selector rectangles.
const ART_ARROW_LEFT_RECT := Rect2(13.0, 187.0, 12.0, 21.0)
const ART_ARROW_RIGHT_RECT := Rect2(135.0, 187.0, 12.0, 21.0)
# Centre of the selector bar — the pivot the suit bounces around when it changes.
const ART_SELECTOR_PIVOT := Vector2(80.5, 196.5)
const ART_SYMBOL_OFFSET := Vector2(68.5, 182.0)
const ART_SYMBOL_SIZE := Vector2(23.04, 23.04)
const ART_SCORES_UNLOCKED_RECT := Rect2(29.0, 226.0, 103.0, 24.0)
const ART_OPTIONS_UNLOCKED_RECT := Rect2(29.0, 262.0, 103.0, 24.0)
# Free strips around the baked plates: hint under the title, meter at the bottom.
const ART_HINT_RECT := Rect2(5.0, 118.0, 150.0, 22.0)
# The pixel font's line box leaves its slack above the glyphs, so the rect sits
# a few px above the selector-to-SCORES gap to land the text inside it.
const ART_DESC_RECT := Rect2(5.0, 208.0, 150.0, 10.0)
# Run-state modal (opened by CONTINUE while a run is held): the neuron meter
# lives here now, not on the menu, next to the resume/abandon choice.
const CONTINUE_MODAL_PANEL_RECT := Rect2(20.0, 84.0, 120.0, 152.0)

# Neon label colors matching the baked plate outlines.
const ART_CYAN := Color(0.42, 1.0, 0.95)
const ART_PINK := Color(1.0, 0.5, 0.7)
const ART_YELLOW := Color(1.0, 0.86, 0.36)

# Augmented Run (issue #111): tier selector shown under START RUN once wealth
# has been reached. Cycling picks one suit modifier (joker = all four).
const AUGMENTED_DESCRIPTIONS := {
	"": "NO AUGMENT",
	"heart": "SPINS COST 2 HEALTH",
	"spade": "POWER RESTORES EVERY 2 SPINS",
	"diamond": "MAX 2 POWERS, NO 2ND AUGMENT",
	"club": "+50% PRICES, -1 OFFER, +15% TAX",
	"joker": "ALL FOUR MODIFIERS",
}

@export_group("First Launch Tutorial")
@export var tutorial_pauses_tree: bool = true
@export var tutorial_title_text: String = "HOW TO PLAY"
@export_multiline var tutorial_bbcode: String = """[color=#d9f0ff][b]The Objective[/b][/color]
- You have 3 campaign lives. Reach 5,000 Wealth.

[color=#f2d37c][b]Pacte[/b][/color]
- Begin each run by choosing one augment and one power.
- Reroll is a choice, not a starting bonus.

[color=#c6f08a][b]Routes and Items[/b][/color]
- Between rounds, choose a route or continue for free.
- Spend run coins on cards, Shop upgrades, and items.
- The Dealer also visits during play. Take an item, then tap its stash slot to use it. Stash limit: 2.

[color=#ff9ca8][b]The Machine[/b][/color]
- Start with 15 spins. Wins raise the frenzy multiplier.
- A miss at x2 or x3 can be rescued with a power.
- Every 30 run coins restores one random spent power.
- Reach each Wealth target to open the next route choice."""

# ── campaign rebalance (issue #38) ────────────────────────────────────────────────
@export_group("Campaign")
## Game-over flatline copy — byte-for-byte from the GDD.
@export var fatal_flatline_text: String = "this time, it's fatal. No coming back"

var _font: FontFile = null
var _menu_sprite: Sprite2D = null      # title overlay (MenuArt)
var _bar_sprite: Sprite2D = null       # selector bar overlay, shown once unlocked
var _symbols_sprite: Sprite2D = null   # suit overlay, frame per selection
var _plate_sprites := {}               # Button -> full-canvas plate Sprite2D
var _background: Sprite2D = null
var _start_button: Button = null
var _scores_button: Button = null
var _options_button: Button = null
var _options_overlay: OptionsOverlay = null
var _campaign_label: Label = null
var _campaign_hint: Label = null
var _augmented_row: Control = null
var _augmented_desc: Label = null
var _arrow_buttons: Array[Button] = []
var _arrow_arts: Array[Sprite2D] = []
var _continue_modal: Control = null
var _selected_augmented_tier := ""
var _tutorial_modal: Control = null
var _tutorial_title: Label = null
var _tutorial_body: RichTextLabel = null
var _tutorial_button: Button = null
var _play_tutorial_button: Button = null # issue #105: "SHOW ME" on the first-launch card

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_scene_nodes()
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
	# Card unlocks earned mid-run are celebrated here if the run ended before the
	# popup could be shown (issue #52).
	UnlockCardPopup.attach_to(self)

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
	if rel == MENU_TITLE_ASSET or rel == MENU_AUGMENTED_BAR_ASSET:
		var bounds := MENU_TITLE_RECT if rel == MENU_TITLE_ASSET else MENU_SELECTOR_ART_RECT
		spr.position = bounds.position
		spr.scale = bounds.size / tex.get_size()
	spr.set_meta("base_scale", spr.scale) # suit-bounce anchor (_bounce_symbols)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr

func _overlay_label(label_name: String, rect: Rect2, font_size: int, color: Color,
		parent: Control = null) -> Label:
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
	l.custom_minimum_size = Vector2.ZERO
	l.clip_text = true
	var host := parent if parent != null else self
	host.add_child(l)
	l.set_deferred("size", rect.size)
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
	UiKit.connect_button(b, cb)

func _style_plate_button(b: Button, rect: Rect2, color: Color, font_size: int) -> void:
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = Vector2.ZERO
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ButtonKit.start_menu_button_style(b, color, font_size)
	# Pressed squash: shrink around the centre while held, spring back on release
	# (same feel as the machine's buttons). Signals connect once; layout refreshes
	# re-run this styling on the same button.
	b.pivot_offset = rect.size * 0.5
	if not b.button_down.is_connected(_on_plate_button_down):
		b.button_down.connect(_on_plate_button_down.bind(b))
		b.button_up.connect(_on_plate_button_up.bind(b))

func _on_plate_button_down(b: Button) -> void:
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * 0.92, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_plate(b, 0.92, 0.06, Tween.TRANS_QUAD)

func _on_plate_button_up(b: Button) -> void:
	if not is_instance_valid(b):
		return
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_plate(b, 1.0, 0.1, Tween.TRANS_BACK)

## Squashes a button's standalone plate in step with its label. The plate is a
## full-canvas sprite, so the scale pivots on the button's centre via position
## compensation (same trick as the suit bounce).
func _tween_plate(b: Button, target: float, duration: float, trans: Tween.TransitionType) -> void:
	var plate := _plate_sprites.get(b) as Sprite2D
	if plate == null or not is_instance_valid(plate):
		return
	var pivot := b.position + b.size * 0.5
	var from := float(plate.get_meta("pop_f", 1.0))
	var tw := create_tween()
	tw.tween_method(_set_plate_pop.bind(plate, pivot), from, target, duration) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)

func _set_plate_pop(f: float, plate: Sprite2D, pivot: Vector2) -> void:
	if not is_instance_valid(plate):
		return
	var base: Vector2 = plate.get_meta("base_scale", Vector2.ONE)
	plate.scale = base * f
	plate.position = pivot * (1.0 - f)
	plate.set_meta("pop_f", f)

## Independent transparent arrow: dimming and squashing never tint the felt.
func _arrow_art(rect: Rect2) -> Sprite2D:
	var tex := Assets.texture("ui/premium/menu_selector_arrow.svg")
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.flip_h = rect.position.x > CANVAS_W * 0.5
	spr.position = rect.position + rect.size * 0.5 - ART_SELECTOR_RECT.position
	spr.scale = rect.size / tex.get_size()
	spr.set_meta("rest_scale", spr.scale)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_augmented_row.add_child(spr)
	return spr

## Invisible hit area over an outer third of the selector bar; pressing
## squashes the arrow's live copy, release springs it back as the suit changes.
func _augmented_arrow_button(step: int, bar_size: Vector2, art: Sprite2D) -> Button:
	var b := Button.new()
	b.name = "CycleLeft" if step < 0 else "CycleRight"
	b.position = Vector2(0.0 if step < 0 else bar_size.x * 0.7, 0.0)
	b.size = Vector2(bar_size.x * 0.3, bar_size.y)
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.button_down.connect(_on_arrow_down.bind(art))
	b.button_up.connect(_on_arrow_up.bind(art))
	b.pressed.connect(_cycle_augmented_tier.bind(step))
	return b

func _on_arrow_down(art: Sprite2D) -> void:
	if art == null:
		return
	var rest: Vector2 = art.get_meta("rest_scale", Vector2.ONE)
	var tw := create_tween()
	tw.tween_property(art, "scale", rest * 0.8, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_arrow_up(art: Sprite2D) -> void:
	if art == null or not is_instance_valid(art):
		return
	var rest: Vector2 = art.get_meta("rest_scale", Vector2.ONE)
	var tw := create_tween()
	tw.tween_property(art, "scale", rest, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _toggle_options_overlay() -> void:
	if _options_overlay != null:
		_options_overlay.toggle_overlay()

## Which authored layout is on screen: frame 1 once Augmented Run is unlocked.
## A held run keeps the selector visible but LOCKED (arrows disabled, showing
## the active run's suit) — modifiers can't change mid-run.
func _augmented_layout_active() -> bool:
	if Engine.is_editor_hint():
		return false
	return MetaStateStore.augmentedRunUnlocked

## Repositions the plate buttons for the current layout; the selector bar
## overlay only shows once Augmented Run is unlocked.
func _layout_art_menu(augmented: bool) -> void:
	if _bar_sprite != null:
		_bar_sprite.visible = augmented
	if _scores_button != null:
		_style_plate_button(_scores_button,
			ART_SCORES_UNLOCKED_RECT if augmented else ART_SCORES_LOCKED_RECT, ART_PINK, 8)
	if _options_button != null:
		_style_plate_button(_options_button,
			ART_OPTIONS_UNLOCKED_RECT if augmented else ART_OPTIONS_LOCKED_RECT, ART_YELLOW, 8)
	# SCORES/OPTIONS plates carry both layout positions as frames.
	for b in [_scores_button, _options_button]:
		var plate := _plate_sprites.get(b) as Sprite2D
		if plate != null and is_instance_valid(plate):
			plate.frame = 1 if augmented else 0

# ── legacy fallback (frames asset missing) ───────────────────────────────────────────

func _build_background() -> void:
	if _background != null:
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
	_menu_sprite = _frame_sprite(MENU_TITLE_ASSET, 1)
	if _menu_sprite == null:
		_menu_sprite = Sprite2D.new()
	_menu_sprite.name = "MenuArt"
	var title := _overlay_label("MenuTitle", Rect2(18, 59, 124, 40), 14, Color("ead4a6"))
	title.text = "LOBOTOMY\nCASINO"
	title.add_theme_constant_override("line_spacing", 1)
	title.add_theme_color_override("font_shadow_color", Color("020604"))
	title.add_theme_constant_override("shadow_offset_y", 1)
	_build_campaign_labels()
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	# The scene's legacy column remains as a compatibility shell; the live
	# buttons are positioned over their authored plates below.
	var start_plate := _frame_sprite(MENU_START_PLATE_ASSET, 1)
	if start_plate != null:
		_plate_sprites[_start_button] = start_plate
	var scores_plate := _frame_sprite(MENU_SCORES_PLATE_ASSET, 2)
	if scores_plate != null:
		_plate_sprites[_scores_button] = scores_plate
	var options_plate := _frame_sprite(MENU_OPTIONS_PLATE_ASSET, 2)
	_options_button = Button.new()
	_options_button.name = "OptionsButton"
	_options_button.text = "OPTIONS"
	add_child(_options_button)
	if options_plate != null:
		_plate_sprites[_options_button] = options_plate
	_reparent_plate_button(_start_button, col, ART_START_RECT, ART_CYAN, 10, _start_run)
	_reparent_plate_button(_scores_button, col, ART_SCORES_LOCKED_RECT, ART_PINK, 8, _open_scores)
	_style_plate_button(_options_button, ART_OPTIONS_LOCKED_RECT, ART_YELLOW, 8)
	_options_button.pressed.connect(_toggle_options_overlay)
	for b in [_start_button, _scores_button, _options_button]:
		if b != null:
			move_child(b, get_child_count() - 1)
	if col != null:
		col.visible = false
	_campaign_hint = _overlay_label("CampaignHint", ART_HINT_RECT, 5,
		Color(0.9, 0.78, 0.64))
	UiKit.style_display_label(_campaign_hint)
	_campaign_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_live_selector()
	if not Engine.is_editor_hint():
		_options_overlay = OPTIONS_OVERLAY_SCENE.instantiate() as OptionsOverlay
		_options_overlay.name = "OptionsOverlay"
		add_child(_options_overlay)

func _build_live_selector() -> void:
	_bar_sprite = _frame_sprite(MENU_AUGMENTED_BAR_ASSET, 1)
	if _bar_sprite != null:
		_bar_sprite.name = "AugmentedBar"
		_bar_sprite.visible = false
	_symbols_sprite = _frame_sprite(MENU_SYMBOLS_ASSET, 6)
	if _symbols_sprite != null:
		_symbols_sprite.name = "AugmentedSymbols"
		_symbols_sprite.position = ART_SYMBOL_OFFSET
		_symbols_sprite.scale = ART_SYMBOL_SIZE / Vector2(128, 128)
		_symbols_sprite.set_meta("base_scale", _symbols_sprite.scale)
		_symbols_sprite.visible = false
	_augmented_row = Control.new()
	_augmented_row.name = "AugmentedSelector"
	_augmented_row.position = ART_SELECTOR_RECT.position
	_augmented_row.size = ART_SELECTOR_RECT.size
	add_child(_augmented_row)
	for arrow in [[-1, ART_ARROW_LEFT_RECT], [1, ART_ARROW_RIGHT_RECT]]:
		var art := _arrow_art(arrow[1] as Rect2)
		var btn := _augmented_arrow_button(int(arrow[0]), ART_SELECTOR_RECT.size, art)
		_augmented_row.add_child(btn)
		_arrow_buttons.append(btn)
		if art != null:
			_arrow_arts.append(art)
	_augmented_desc = _overlay_label("AugmentedDescription", ART_DESC_RECT, 5, ART_YELLOW)

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
	if not Engine.is_editor_hint() and RunStateStore.has_resume_state():
		return # locked while a run is held
	var cycle := RunStateStore.AUGMENTED_TIER_CYCLE
	var idx := cycle.find(_selected_augmented_tier)
	idx = (idx + step + cycle.size()) % cycle.size()
	_selected_augmented_tier = cycle[idx]
	_refresh_augmented_selector()
	_refresh_start_button()
	_bounce_symbols()

## Bounce the incoming suit: the full-canvas symbols sprite pops from small to
## rest around the selector-bar centre (position compensates so the scale
## pivots on the bar, not the canvas origin).
func _bounce_symbols() -> void:
	if _symbols_sprite == null or not _symbols_sprite.visible:
		return
	var tw := create_tween()
	tw.tween_method(_set_symbols_pop, 0.7, 1.0, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_symbols_pop(f: float) -> void:
	if _symbols_sprite == null:
		return
	var base: Vector2 = _symbols_sprite.get_meta("base_scale", Vector2.ONE)
	_symbols_sprite.scale = base * f
	_symbols_sprite.position = ART_SYMBOL_OFFSET + ART_SYMBOL_SIZE * 0.5 * (1.0 - f)

func _refresh_augmented_selector() -> void:
	if _augmented_row == null:
		return
	var shown := _augmented_layout_active()
	var run_held := not Engine.is_editor_hint() and RunStateStore.has_resume_state()
	_augmented_row.visible = shown
	if _bar_sprite != null:
		_bar_sprite.visible = shown
	_layout_art_menu(shown)
	# While a run is held the row locks: arrows disabled (dimmed), and the suit
	# shown is the ACTIVE run's tier, not the menu selection.
	var displayed := _selected_augmented_tier
	if run_held:
		displayed = String(RunStateStore.augmentedTier)
	for b in _arrow_buttons:
		b.disabled = run_held
	for art in _arrow_arts:
		if is_instance_valid(art):
			art.modulate = Color(0.45, 0.45, 0.5) if run_held else Color.WHITE
	if _symbols_sprite != null:
		_symbols_sprite.visible = shown
		var cycle := RunStateStore.AUGMENTED_TIER_CYCLE
		_symbols_sprite.frame = clampi(cycle.find(displayed), 0,
			_symbols_sprite.hframes - 1)
	if _augmented_desc != null:
		_augmented_desc.visible = shown
		_augmented_desc.text = String(AUGMENTED_DESCRIPTIONS.get(displayed, ""))

func _refresh_start_button() -> void:
	if _start_button == null:
		return
	# Keep the live fallback button's press animation centered just like the
	# retired authored plate path.
	_start_button.pivot_offset = _start_button.size * 0.5
	# Run-phase changes also gate the selector (hidden while a run is held).
	_refresh_augmented_selector()
	var continuing := not Engine.is_editor_hint() and RunStateStore.has_resume_state()
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
		_start_button.text = "CLASSIC RUN"
		_start_button.add_theme_font_size_override("font_size", 10)
	_start_button.add_theme_font_override("font", UiKit.control_font())
	var translated := String(TranslationServer.translate(_start_button.text))
	var width := UiKit.control_font().get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_start_button.add_theme_font_size_override("font_size", 16 if width <= _start_button.size.x - 12.0 else 8)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_start_button()

func _refresh_campaign_ui() -> void:
	if _campaign_hint == null:
		return
	if Engine.is_editor_hint():
		_campaign_hint.text = "EACH RETURN COSTS YOU"
		return
	# The neuron meter no longer lives on the menu — CONTINUE opens the
	# run-state modal, which carries it (see _show_continue_modal).
	if MetaStateStore.campaignFailed:
		_campaign_hint.text = fatal_flatline_text
	elif MetaStateStore.wealthEndingReached:
		_campaign_hint.text = "WEALTH ENDING REACHED."
	elif MetaStateStore.campaignNeuronsLeft <= 0:
		_campaign_hint.text = "NO NEURONS. RETURNING ENDS THIS MIND."
	else:
		_campaign_hint.text = "EACH RETURN COSTS YOU. REACH WEALTH BEFORE DEATH."
	_refresh_start_button() # also lays out the art frame + meter


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
		_tutorial_body.scroll_active = true
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
	_configure_play_tutorial_button()

## The played tutorial (issue #105) is offered from the card that already explains the
## game, above the button that dismisses it: reading is the fallback, playing is the offer.
## Built in code so the authored modal keeps its single authored button.
func _configure_play_tutorial_button() -> void:
	if _tutorial_button == null or _play_tutorial_button != null:
		return
	var content := _tutorial_button.get_parent() as Control
	if content == null:
		return
	_play_tutorial_button = Button.new()
	_play_tutorial_button.name = "PlayTutorialButton"
	_play_tutorial_button.text = "SHOW ME"
	_play_tutorial_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_tutorial_button.focus_mode = Control.FOCUS_NONE
	_play_tutorial_button.add_theme_font_size_override("font_size", 6)
	if _font != null:
		_play_tutorial_button.add_theme_font_override("font", _font)
	_play_tutorial_button.pressed.connect(_on_play_tutorial_pressed)
	content.add_child(_play_tutorial_button)
	content.move_child(_play_tutorial_button, _tutorial_button.get_index())

func _on_play_tutorial_pressed() -> void:
	if Engine.is_editor_hint():
		return
	# The card is dismissed either way — whichever button was pressed, it has been read.
	_dismiss_tutorial()
	if not Tutorial.start():
		# A held run is the only refusal; say so rather than swallowing the tap.
		_show_continue_modal()

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
	if not Engine.is_editor_hint() and RunStateStore.has_resume_state():
		# CONTINUE first shows the held session with the choice to resume or
		# abandon, instead of jumping straight into another scene.
		_show_continue_modal()
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
	# starts. Reserve the campaign neuron before opening Pacte so a partial card
	# selection is a valid resumable run.
	if not Engine.is_editor_hint():
		RunStateStore.augmentedTier = _selected_augmented_tier \
			if MetaStateStore.augmentedRunUnlocked else ""
		if not RunStateStore.start_new_run(MetaStateStore.ownedPermanents, {}, true, -1, true):
			_refresh_campaign_ui()
			return
	# Pacte replaces the pre-run dealer/shop handoff. The dealer remains available
	# for in-run interruptions and the post-Wealth odds phase.
	SceneNav.change_to(PACTE_SCENE)

# ── run-state modal (held run) ───────────────────────────────────────────────────────
# CONTINUE opens this instead of switching scenes: the neuron meter (moved off
# the menu), the run's current coin balance, and the resume-or-abandon choice.

func _show_continue_modal() -> void:
	_hide_continue_modal()
	_continue_modal = Control.new()
	_continue_modal.name = "ContinueModal"
	_continue_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_continue_modal.z_index = 150
	_continue_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_continue_modal)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_continue_modal.add_child(dim)

	var panel := Panel.new()
	panel.name = "Panel"
	var style := ButtonKit.neon_panel_style(ART_CYAN)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = CONTINUE_MODAL_PANEL_RECT.position
	panel.size = CONTINUE_MODAL_PANEL_RECT.size
	_continue_modal.add_child(panel)

	var w := CONTINUE_MODAL_PANEL_RECT.size.x
	var title := _overlay_label("Title", Rect2(0.0, 7.0, w, 10.0), 7, ART_CYAN, panel)
	title.text = "RUN IN PROGRESS"
	NeuronMeter.attach(panel, Vector2(w * 0.5, 46.0))
	var stats := _overlay_label("Stats", Rect2(0.0, 88.0, w, 10.0), 5,
		Color(0.9, 0.94, 1.0), panel)
	stats.text = tr("CURRENT COINS : %d") % _current_coins()
	var close := _modal_close_button(w)
	panel.add_child(close)

	panel.add_child(_modal_button("ContinueButton", "CONTINUE",
		Rect2(16.0, 104.0, 88.0, 18.0), ART_CYAN, _resume_run))
	panel.add_child(_modal_button("GiveUpButton", "GIVE UP",
		Rect2(16.0, 128.0, 88.0, 18.0), Color(1.0, 0.4, 0.45), _give_up_run))

func _modal_close_button(panel_width: float) -> Button:
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "X"
	close.position = Vector2(panel_width - CLOSE_BUTTON_INSET.x, CLOSE_BUTTON_INSET.y)
	close.size = CLOSE_BUTTON_SIZE
	close.custom_minimum_size = Vector2.ZERO
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", 7)
	if _font != null:
		close.add_theme_font_override("font", _font)
	close.add_theme_color_override("font_color", ART_CYAN)
	close.add_theme_color_override("font_hover_color", Color.WHITE)
	close.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		close.add_theme_stylebox_override(String(state), StyleBoxEmpty.new())
	close.pressed.connect(_hide_continue_modal)
	close.set_deferred("size", Vector2(12.0, 12.0))
	return close

func _modal_button(button_name: String, text: String, rect: Rect2, color: Color,
		cb: Callable) -> Button:
	var b := Button.new()
	b.name = button_name
	b.text = text
	ButtonKit.start_menu_button_style(b, color, 6)
	b.custom_minimum_size = Vector2.ZERO
	b.position = rect.position
	b.size = rect.size
	# Something in the enter-tree pass re-inflates the rect (same class of issue
	# as the dealer confirm modal's anchor warning); re-assert it post-layout.
	b.set_deferred("size", rect.size)
	b.pivot_offset = rect.size * 0.5
	# Same squash feel as the plate buttons (no plate sprite mapped -> label only).
	b.pivot_offset = rect.size * 0.5
	b.button_down.connect(_on_plate_button_down.bind(b))
	b.button_up.connect(_on_plate_button_up.bind(b))
	b.pressed.connect(cb)
	return b

func _hide_continue_modal() -> void:
	if _continue_modal != null:
		_continue_modal.queue_free()
		_continue_modal = null

func _current_coins() -> int:
	# The active machine owns the live run balance. Dealer and post-run states
	# show the persistent wallet that the dealer actually spends and displays.
	if RunStateStore.runPhase in ["pacte_initial", "pacte_threshold", "running"] \
			or RunStateStore.routeOfferPending or RunStateStore.routeDestination != "":
		return int(RunStateStore.lucidityCoins)
	return int(MetaStateStore.lucidityWallet)

func _resume_run() -> void:
	if RunStateStore.runPhase == "pacte_threshold" \
			or RunStateStore.pacteThresholdPending \
			or RunStateStore.pacteAfterFlatlinePending:
		RunStateStore.migrate_legacy_pacte_to_route()
	if RunStateStore.routeOfferPending:
		SceneNav.change_to(ROUTE_SCENE)
		return
	if RunStateStore.routeDestination == RouteCards.ROUTE_SHOP:
		SceneNav.change_to("res://scenes/dealer_scene.tscn")
		return
	if RunStateStore.routeDestination == RouteCards.ROUTE_AUGMENT \
			or RunStateStore.routeDestination == RouteCards.ROUTE_POWER:
		SceneNav.change_to(ROUTE_BUILD_SCENE)
		return
	if RunStateStore.routeDestination == RouteCards.ROUTE_BONUS:
		SceneNav.change_to(ROUTE_BONUS_SCENE)
		return
	if RunStateStore.routeDestination == RouteCards.ROUTE_DEALER:
		SceneNav.change_to("res://scenes/route_dealer_scene.tscn")
		return
	if RunStateStore.routeDestination == RouteCards.ROUTE_SACRIFICE:
		SceneNav.change_to(SACRIFICE_SCENE)
		return
	var resume_pacte := RunStateStore.pacte_active()
	var resume_dealer := RunStateStore.runPhase == "pre_run" \
		or (RunStateStore.runPhase == "over" and str(RunStateStore.lastEnding) == "flatline") \
		or (RunStateStore.runPhase == "over" and RunStateStore.roundContinuationPending) \
		or (RunStateStore.runPhase == "running" and RunStateStore.dealerPending)
	var resume_scene := PACTE_SCENE if resume_pacte else (DEALER_SCENE if resume_dealer else MACHINE_SCENE)
	SceneNav.change_to(resume_scene)

## Abandoning starts a fresh campaign: nothing is banked, the held run is
## cleared, and the campaign neuron meter returns to its full starting count.
func _give_up_run() -> void:
	RunStateStore.reset_run_state()
	MetaStateStore.start_new_campaign()
	_hide_continue_modal()
	_refresh_campaign_ui()

func _open_scores() -> void:
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("push_current_scene")
	SceneNav.change_to(SCORES_SCENE)
