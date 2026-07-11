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
const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const MENU_ART_UNLOCKED := "start_menu/start_menu_background_unlocked.png"
const MENU_ART_LOCKED := "start_menu/start_menu_background_locked.png"
const CANVAS_W := 160.0
const MENU_W := 148.0
# Title sits high so the whole column (titles, meter + count, hint, buttons) fits
# the 160x320 canvas without clipping.
const MENU_Y := 44.0
const MENU_SEPARATION := 6
const TITLE_SPACER_H := 8.0
const CAMPAIGN_HINT_H := 18.0
const AUGMENTED_TIER_NAMES: Array[String] = ["HEART", "SPADE", "DIAMOND", "CLUB", "JOKER"]
const AUGMENTED_BUTTON_RECT := Rect2(18.0, 145.0, 124.0, 34.0)
const AUGMENTED_LEFT_RECT := Rect2(12.0, 184.0, 18.0, 24.0)
const AUGMENTED_RIGHT_RECT := Rect2(130.0, 184.0, 18.0, 24.0)
const AUGMENTED_TIER_RECT := Rect2(52.0, 208.0, 56.0, 14.0)
const TIER_CARD_HIGHLIGHT_POSITIONS: Array[Vector2] = [
	Vector2(68.0, 184.0), Vector2(25.0, 184.0), Vector2(47.0, 184.0),
	Vector2(91.0, 184.0), Vector2(112.0, 184.0),
]

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
## Editor-only preview toggle for the post-Wealth Augmented Run menu state.
@export var editor_preview_augmented_run: bool = true

var _font: FontFile = null
var _background: Sprite2D = null
var _start_button: Button = null
var _scores_button: Button = null
var _campaign_label: Label = null
var _campaign_meter: NeuronMeter = null # issue #38 pixel-art neuron meter
var _campaign_hint: Label = null
var _menu_overlay: Control = null
var _visual_start_button: Button = null
var _visual_augmented_button: Button = null
var _visual_scores_button: Button = null
var _augmented_left_button: Button = null
var _augmented_right_button: Button = null
var _augmented_tier_label: Label = null
var _augmented_tier_highlight: Panel = null
var _augmented_tier := 0
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
	if _background == null:
		var bg := ColorRect.new()
		bg.color = Color(0.055, 0.03, 0.11)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		_background = Sprite2D.new()
		_background.name = "GeneratedBackground"
		_background.centered = false
		_background.position = Vector2.ZERO
		add_child(_background)
	_refresh_background_art()

func _refresh_background_art() -> void:
	if _background == null:
		return
	var asset := MENU_ART_UNLOCKED if _augmented_run_unlocked() else MENU_ART_LOCKED
	var tex := Assets.texture(asset, true)
	if tex == null:
		tex = Assets.texture("dealer_shop_bg.png", true)
	if tex == null:
		return
	_background.texture = tex
	_background.centered = false
	_background.position = Vector2.ZERO
	_background.scale = Vector2(CANVAS_W / float(tex.get_width()), 320.0 / float(tex.get_height()))
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _augmented_run_unlocked() -> bool:
	if Engine.is_editor_hint():
		return editor_preview_augmented_run
	return bool(MetaStateStore.augmentedRunUnlocked)

func _build_art_menu() -> void:
	if _menu_overlay != null:
		return
	var authored_column := get_node_or_null("MenuColumn") as Control
	if authored_column != null:
		authored_column.visible = false
	_menu_overlay = Control.new()
	_menu_overlay.name = "MenuOverlay"
	_menu_overlay.size = Vector2(CANVAS_W, 320.0)
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_overlay.z_index = 10
	add_child(_menu_overlay)
	_visual_start_button = _make_art_button(
		&"StartRunButton", Rect2(22.0, 101.0, 116.0, 35.0), 8, _start_run)
	_visual_augmented_button = _make_art_button(
		&"AugmentedRunButton", AUGMENTED_BUTTON_RECT, 7, _start_augmented_run)
	_visual_scores_button = _make_art_button(
		&"ScoresButton", Rect2(26.0, 238.0, 108.0, 35.0), 9, _open_scores)
	_visual_scores_button.text = "SCORES"
	_augmented_left_button = _make_art_button(
		&"AugmentedLeftButton", AUGMENTED_LEFT_RECT, 1, _select_augmented_tier.bind(-1))
	_augmented_right_button = _make_art_button(
		&"AugmentedRightButton", AUGMENTED_RIGHT_RECT, 1, _select_augmented_tier.bind(1))
	_augmented_tier_label = _make_art_label(&"AugmentedTierLabel", AUGMENTED_TIER_RECT, 5)
	_augmented_tier_highlight = Panel.new()
	_augmented_tier_highlight.name = "AugmentedTierHighlight"
	_augmented_tier_highlight.size = Vector2(19.0, 40.0)
	_augmented_tier_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	highlight_style.border_color = Color(1.0, 0.78, 0.25, 0.9)
	highlight_style.set_border_width_all(1)
	_augmented_tier_highlight.add_theme_stylebox_override(&"panel", highlight_style)
	_menu_overlay.add_child(_augmented_tier_highlight)
	_refresh_start_button()
	_refresh_augmented_ui()

func _make_art_label(node_name: StringName, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.91, 0.68))
	label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.01, 0.06))
	label.add_theme_constant_override(&"outline_size", 1)
	if _font != null:
		label.add_theme_font_override(&"font", _font)
	_menu_overlay.add_child(label)
	return label

func _make_art_button(node_name: StringName, rect: Rect2, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", Color(1.0, 0.91, 0.68))
	button.add_theme_color_override(&"font_hover_color", Color(1.0, 1.0, 0.88))
	button.add_theme_color_override(&"font_pressed_color", Color(1.0, 0.78, 0.25))
	button.add_theme_color_override(&"font_outline_color", Color(0.04, 0.01, 0.06))
	button.add_theme_constant_override(&"outline_size", 1)
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if _font != null:
		button.add_theme_font_override(&"font", _font)
	button.pressed.connect(callback)
	_menu_overlay.add_child(button)
	return button

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
		_build_art_menu()
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
	_build_art_menu()

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

func _refresh_start_button() -> void:
	if _start_button == null:
		return
	var continuing := not Engine.is_editor_hint() and RunStateStore.runPhase == "running"
	if continuing:
		_start_button.text = "CONTINUE"
		_start_button.add_theme_font_size_override("font_size", 10)
	elif not Engine.is_editor_hint() and (MetaStateStore.campaignFailed or MetaStateStore.wealthEndingReached):
		_start_button.text = "START FRESH AGAIN"
		_start_button.add_theme_font_size_override("font_size", 8)
	else:
		_start_button.text = "START RUN"
		_start_button.add_theme_font_size_override("font_size", 11)
	if _font != null:
		_start_button.add_theme_font_override("font", _font)
	if _visual_start_button != null:
		_visual_start_button.text = _start_button.text
		_visual_start_button.add_theme_font_size_override(
			&"font_size", 8 if _start_button.text == "START FRESH AGAIN" else 9)
	_refresh_augmented_ui()

func _refresh_campaign_ui() -> void:
	_refresh_background_art()
	if _campaign_label == null or _campaign_hint == null:
		_refresh_augmented_ui()
		return
	if Engine.is_editor_hint():
		_campaign_label.text = "NEURONS"
		_campaign_hint.text = "EACH RETURN COSTS ONE"
		_refresh_augmented_ui()
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
	_refresh_start_button()
	_refresh_augmented_ui()

func _refresh_augmented_ui() -> void:
	if _visual_augmented_button == null:
		return
	var unlocked := _augmented_run_unlocked()
	var active_run := not Engine.is_editor_hint() and RunStateStore.runPhase == "running"
	_visual_augmented_button.visible = unlocked
	_visual_augmented_button.disabled = active_run
	_augmented_left_button.visible = unlocked
	_augmented_right_button.visible = unlocked
	_augmented_tier_label.visible = unlocked
	_augmented_tier_highlight.visible = unlocked
	if not unlocked:
		return
	_visual_augmented_button.text = "AUGMENTED RUN"
	_augmented_tier_label.text = "%s T%d" % [AUGMENTED_TIER_NAMES[_augmented_tier], _augmented_tier + 1]
	_augmented_tier_highlight.position = TIER_CARD_HIGHLIGHT_POSITIONS[_augmented_tier]

func _select_augmented_tier(direction: int) -> void:
	if not _augmented_run_unlocked():
		return
	_augmented_tier = posmod(_augmented_tier + direction, AUGMENTED_TIER_NAMES.size())
	_refresh_augmented_ui()

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
		RunStateStore.queue_augmented_run(0)
		_refresh_campaign_ui()
		return
	if not Engine.is_editor_hint() and not MetaStateStore.can_start_campaign_run():
		MetaStateStore.mark_campaign_failed()
		_refresh_campaign_ui()
		return
	RunStateStore.queue_augmented_run(0)
	# Begin a fresh run by visiting the dealer FIRST; the dealer scene runs in
	# pre-run shop mode and starts the run once the player leaves the counter.
	get_tree().change_scene_to_file(DEALER_SCENE)

func _start_augmented_run() -> void:
	if Engine.is_editor_hint() or not _augmented_run_unlocked():
		return
	if RunStateStore.runPhase == "running":
		return
	if MetaStateStore.campaignFailed or MetaStateStore.wealthEndingReached:
		MetaStateStore.start_new_campaign()
		RunStateStore.reset_run_state()
	if not MetaStateStore.can_start_campaign_run():
		MetaStateStore.mark_campaign_failed()
		_refresh_campaign_ui()
		return
	RunStateStore.queue_augmented_run(_augmented_tier + 1)
	get_tree().change_scene_to_file(DEALER_SCENE)

func _open_scores() -> void:
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("push_current_scene")
	get_tree().change_scene_to_file(SCORES_SCENE)
