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

const DEALER_SCENE := "res://scenes/dealer_scene.tscn"
# Authored menu background (issue #111 sheet set); falls back to the shop bg.
const MENU_BG_ASSET := "start_menu/neon_casino_background.png"
# Authored menu art (issue #111): the states sheet bakes the neon title, the
# labelled buttons, and the suit selector bar. One panel spans the 160px canvas.
const MENU_SHEET := "start_menu/start_menu_states_sheet.png"
const SHEET_SCALE := 160.0 / 406.0
const SHEET_TITLE_RECT := Rect2(115.0, 55.0, 224.0, 98.0)
const SHEET_START_RECT := Rect2(113.0, 190.0, 228.0, 46.0)      # START A NEW RUN
const SHEET_CONTINUE_RECT := Rect2(553.0, 190.0, 228.0, 46.0)   # CONTINUE
const SHEET_AUGMENTED_RECT := Rect2(535.0, 625.0, 260.0, 50.0)  # AUGMENTED RUN
const SHEET_SCORES_RECT := Rect2(113.0, 265.0, 228.0, 44.0)     # SCORES
const SHEET_SELECTOR_RECT := Rect2(113.0, 688.0, 227.0, 45.0)   # < [suit] > bar
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
const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const CANVAS_W := 160.0
const MENU_W := 148.0
# Title sits high so the whole column (titles, meter + count, hint, buttons) fits
# the 160x320 canvas without clipping.
const MENU_Y := 44.0
const MENU_SEPARATION := 6
const TITLE_SPACER_H := 8.0
const CAMPAIGN_HINT_H := 18.0

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
var _background: Sprite2D = null
var _start_button: Button = null
var _scores_button: Button = null
var _campaign_label: Label = null
var _campaign_meter: NeuronMeter = null # issue #38 pixel-art neuron meter
var _campaign_hint: Label = null
var _augmented_row: Control = null
var _augmented_icon: TextureRect = null
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
	_build_background()
	_build_menu()
	_build_title_art()
	_skin_menu_button(_scores_button, SHEET_SCORES_RECT)
	_build_augmented_selector()
	if not Engine.is_editor_hint() and not RunStateStore.state_changed.is_connected(_refresh_start_button):
		RunStateStore.state_changed.connect(_refresh_start_button)
	if not Engine.is_editor_hint() and not MetaStateStore.meta_changed.is_connected(_refresh_campaign_ui):
		MetaStateStore.meta_changed.connect(_refresh_campaign_ui)
	_refresh_start_button()
	_refresh_campaign_ui()
	_layout_menu_column()
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

func _build_background() -> void:
	if _background != null:
		# Prefer the authored neon casino backdrop (issue #111); the scene's
		# placeholder/legacy texture is replaced when the asset exists.
		var neon := Assets.texture(MENU_BG_ASSET, true)
		if neon != null:
			_background.texture = neon
			_background.centered = false
			_background.position = Vector2.ZERO
			_background.scale = Vector2(160.0 / neon.get_width(), 320.0 / neon.get_height())
			# The scene's Dim rect is fully opaque (tuned for the legacy black
			# bg); soften it so the neon backdrop reads while text stays legible.
			var dim := get_node_or_null("Dim") as ColorRect
			if dim != null:
				dim.color = Color(0.02, 0.01, 0.04, 0.42)
		elif _background.texture == null:
			var tex := Assets.texture("dealer_shop_bg.png", true)
			if tex == null:
				return
			_background.texture = tex
			_background.centered = false
			_background.scale = Vector2(160.0 / tex.get_width(), 320.0 / tex.get_height())
		_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		return
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.03, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tex := Assets.texture("dealer_shop_bg.png", true)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2.ZERO
		spr.scale = Vector2(160.0 / tex.get_width(), 320.0 / tex.get_height())
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(spr)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

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

func _menu_button(text: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120.0, 22.0)
	b.add_theme_font_size_override("font_size", size)
	if _font != null:
		b.add_theme_font_override("font", _font)
	b.pressed.connect(cb)
	return b

func _build_menu() -> void:
	if _start_button != null or _scores_button != null:
		_build_campaign_labels()
		_connect_button(_start_button, _start_run)
		_connect_button(_scores_button, _open_scores)
		_refresh_start_button()
		_layout_menu_column()
		return
	var col := VBoxContainer.new()
	col.position = Vector2((CANVAS_W - MENU_W) * 0.5, MENU_Y)
	col.size = Vector2(MENU_W, 0.0)
	col.custom_minimum_size = Vector2(MENU_W, 0.0)
	col.add_theme_constant_override("separation", MENU_SEPARATION)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)

	col.add_child(_label("LOBOTOMY", 16, Color(0.85, 0.9, 1.0)))
	col.add_child(_label("CASINO", 16, Color(0.85, 0.9, 1.0)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, TITLE_SPACER_H)
	col.add_child(spacer)
	_campaign_label = _label("", 8, Color(0.8, 0.95, 1.0))
	_campaign_label.name = "CampaignLabel"
	col.add_child(_campaign_label)
	_campaign_hint = _label("", 7, Color(0.9, 0.78, 0.64))
	_campaign_hint.name = "CampaignHint"
	_configure_campaign_hint()
	col.add_child(_campaign_hint)

	var start := _menu_button("START RUN", 11, _start_run)
	col.add_child(start)
	_start_button = start
	col.add_child(_menu_button("SCORES", 8, _open_scores))

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
	_configure_campaign_hint()
	var start_index := _start_button.get_index() if _start_button != null else col.get_child_count()
	col.move_child(_campaign_label, maxi(0, start_index))
	col.move_child(_campaign_hint, maxi(0, start_index + 1))
	_layout_menu_column()

func _configure_campaign_hint() -> void:
	if _campaign_hint == null:
		return
	_campaign_hint.custom_minimum_size = Vector2(MENU_W, CAMPAIGN_HINT_H)
	_campaign_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_hint.clip_text = false

func _layout_menu_column() -> void:
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	if col == null:
		return
	col.position = Vector2((CANVAS_W - MENU_W) * 0.5, MENU_Y)
	col.custom_minimum_size = Vector2(MENU_W, 0.0)
	col.size.x = MENU_W
	col.add_theme_constant_override("separation", MENU_SEPARATION)
	var spacer := col.get_node_or_null("TitleSpacer") as Control
	if spacer != null:
		spacer.custom_minimum_size = Vector2(0.0, TITLE_SPACER_H)

# ── Augmented Run selector (issue #111) ────────────────────────────────────────────
# A yellow-bound suit selector under START RUN, matching the authored states
# sheet: < [suit] >. Hidden until MetaStateStore.augmentedRunUnlocked; empty
# selection = classic run. The description line spells the modifier out before
# the run starts.

func _build_augmented_selector() -> void:
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	if col == null or _start_button == null or _augmented_row != null:
		return
	var bar_size := SHEET_SELECTOR_RECT.size * SHEET_SCALE
	_augmented_row = Control.new()
	_augmented_row.name = "AugmentedSelector"
	_augmented_row.custom_minimum_size = bar_size
	_augmented_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_augmented_row)
	col.move_child(_augmented_row, _start_button.get_index() + 1)

	# Authored bar art (yellow bound, baked arrows); falls back to nothing if the
	# sheet is missing — the invisible buttons still work over the empty rect.
	var bar_tex := _sheet_crop(SHEET_SELECTOR_RECT)
	if bar_tex != null:
		var bar := TextureRect.new()
		bar.name = "BarArt"
		bar.texture = bar_tex
		bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar.stretch_mode = TextureRect.STRETCH_SCALE
		bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bar.position = Vector2.ZERO
		bar.size = bar_size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_augmented_row.add_child(bar)

	var box := Control.new()
	box.name = "SuitBox"
	box.position = bar_size * 0.5 - Vector2(6.0, 6.0)
	box.size = Vector2(12.0, 12.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_augmented_row.add_child(box)
	_augmented_icon = TextureRect.new()
	_augmented_icon.name = "SuitIcon"
	_augmented_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_augmented_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_augmented_icon.position = Vector2.ZERO
	_augmented_icon.size = box.size
	_augmented_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_augmented_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_augmented_icon)

	_augmented_row.add_child(_augmented_arrow_button(-1, bar_size))
	_augmented_row.add_child(_augmented_arrow_button(1, bar_size))

	_augmented_desc = _label("", 5, Color(0.9, 0.9, 0.62))
	_augmented_desc.name = "AugmentedDescription"
	col.add_child(_augmented_desc)
	col.move_child(_augmented_desc, _augmented_row.get_index() + 1)
	_refresh_augmented_selector()

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

func _sheet_crop(rect: Rect2) -> AtlasTexture:
	var tex := Assets.texture(MENU_SHEET, true)
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = rect
	return at

## Skins a menu Button with a baked-label crop of the states sheet. The Button's
## own text stays (logic and tests read it) but renders transparent; hover and
## press feedback come from modulating the art. Returns false if art is missing.
func _skin_menu_button(b: Button, rect: Rect2) -> bool:
	var tex := Assets.texture(MENU_SHEET, true)
	if tex == null or b == null:
		return false
	var states := { "normal": Color.WHITE, "hover": Color(1.2, 1.2, 1.2),
		"pressed": Color(0.65, 0.65, 0.65), "disabled": Color(0.5, 0.5, 0.5),
		"focus": Color(1.25, 1.25, 1.25) }
	for state in states:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.region_rect = rect
		sb.modulate_color = states[state]
		b.add_theme_stylebox_override(String(state), sb)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(String(color_name), Color(0, 0, 0, 0))
	b.custom_minimum_size = rect.size * SHEET_SCALE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return true

func _unskin_menu_button(b: Button) -> void:
	if b == null:
		return
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.remove_theme_stylebox_override(String(state))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		b.remove_theme_color_override(String(color_name))
	b.custom_minimum_size = Vector2(120.0, 22.0)

## Replaces the two title Labels with the authored neon LOBOTOMY CASINO frame.
func _build_title_art() -> void:
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	var title_tex := _sheet_crop(SHEET_TITLE_RECT)
	if col == null or title_tex == null or col.get_node_or_null("TitleArt") != null:
		return
	for node_name in ["TitleTop", "TitleBottom"]:
		var l := col.get_node_or_null(String(node_name)) as Label
		if l != null:
			l.visible = false
	var art := TextureRect.new()
	art.name = "TitleArt"
	art.texture = title_tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.custom_minimum_size = SHEET_TITLE_RECT.size * SHEET_SCALE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	col.move_child(art, 0)

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
	# The selector only applies to a FRESH run: while a run is held (CONTINUE)
	# it hides entirely — modifiers can't change mid-run (states sheet, panel 2).
	var run_held := not Engine.is_editor_hint() and RunStateStore.runPhase == "running"
	var shown := (Engine.is_editor_hint() or MetaStateStore.augmentedRunUnlocked) and not run_held
	_augmented_row.visible = shown
	if _augmented_desc != null:
		_augmented_desc.visible = shown
		_augmented_desc.text = String(AUGMENTED_DESCRIPTIONS.get(_selected_augmented_tier, ""))
	if _augmented_icon != null:
		_augmented_icon.texture = null if Engine.is_editor_hint() \
			else Assets.augmented_suit_icon(_selected_augmented_tier)

func _refresh_start_button() -> void:
	if _start_button == null:
		return
	# Run-phase changes also gate the selector (hidden while a run is held).
	_refresh_augmented_selector()
	var continuing := not Engine.is_editor_hint() and RunStateStore.runPhase == "running"
	if continuing:
		_start_button.text = "CONTINUE"
		_start_button.add_theme_font_size_override("font_size", 10)
		_skin_menu_button(_start_button, SHEET_CONTINUE_RECT)
	elif not Engine.is_editor_hint() and (MetaStateStore.campaignFailed or MetaStateStore.wealthEndingReached):
		# No authored art for this state: fall back to the plain themed button.
		_start_button.text = "START FRESH AGAIN"
		_start_button.add_theme_font_size_override("font_size", 8)
		_unskin_menu_button(_start_button)
	elif not Engine.is_editor_hint() and MetaStateStore.augmentedRunUnlocked \
			and _selected_augmented_tier != "":
		_start_button.text = "AUGMENTED RUN"
		_start_button.add_theme_font_size_override("font_size", 9)
		_skin_menu_button(_start_button, SHEET_AUGMENTED_RECT)
	else:
		_start_button.text = "START RUN"
		_start_button.add_theme_font_size_override("font_size", 11)
		_skin_menu_button(_start_button, SHEET_START_RECT)
	if _font != null:
		_start_button.add_theme_font_override("font", _font)

func _refresh_campaign_ui() -> void:
	if _campaign_label == null or _campaign_hint == null:
		return
	if Engine.is_editor_hint():
		_campaign_label.text = "NEURONS"
		_campaign_hint.text = "EACH RETURN COSTS ONE"
		return
	# Issue #38: the neuron meter replaces the text; the label holds its menu slot.
	_campaign_label.text = ""
	if _campaign_meter == null:
		_campaign_meter = NeuronMeter.attach(_campaign_label, Vector2(MENU_W * 0.5, 0.0))
		# The meter sizes itself to the authored art; reserve that height in the menu
		# column and re-centre now that the size is known.
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
	_refresh_augmented_selector()
	_refresh_start_button()

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
