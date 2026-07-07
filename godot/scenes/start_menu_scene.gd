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
const DEALER_SCENE_PACKED := preload("res://scenes/dealer_scene.tscn")
const MACHINE_SCENE_PACKED := preload("res://scenes/machine_scene.tscn")
const IN_RUN_DEALER_OFFER_SCENE_PACKED := preload("res://scenes/in_run_dealer_offer.tscn")
const UPGRADES_SCENE_PACKED := preload("res://scenes/upgrades_scene.tscn")
const CANVAS_W := 160.0
const CANVAS_H := 320.0
const MENU_W := 148.0
# Title sits high so the whole column (titles, meter + count, hint, buttons) fits
# the 160x320 canvas without clipping.
const MENU_Y := 44.0
const MENU_SEPARATION := 6
const TITLE_SPACER_H := 8.0
const CAMPAIGN_HINT_H := 18.0
const TUTORIAL_HIGHLIGHT_PAD := 3.0
const TUTORIAL_HIGHLIGHT_Z := 150
const TUTORIAL_PANEL_Z := 180
const TUTORIAL_POINTER_Z := 181
const TUTORIAL_PANEL_SIZE := Vector2(148.0, 156.0)
const TUTORIAL_PANEL_TOP_Y := 18.0
const TUTORIAL_BODY_H := 78.0
const TUTORIAL_INTERACTIVE_PANEL_SIZE := Vector2(148.0, 100.0)
const TUTORIAL_MACHINE_PANEL_SIZE := Vector2(148.0, 92.0)
const TUTORIAL_STATIC_COMPACT_PANEL_SIZE := Vector2(148.0, 108.0)
const DEALER_TUTORIAL_PREAMBLE := "preamble"
const DEALER_TUTORIAL_HINTS := "hints"
const DEALER_TUTORIAL_ECONOMY := "economy"
const DEALER_TUTORIAL_BUY := "buy"
const DEALER_TUTORIAL_STASH := "stash"
const DEALER_TUTORIAL_NAVIGATE := "navigate"
const DEALER_TUTORIAL_COMPLETE := "complete"
const MACHINE_TUTORIAL_MULTIPLIER := "multiplier"
const MACHINE_TUTORIAL_SPINS := "spins"
const MACHINE_TUTORIAL_REROLL := "reroll"
const MACHINE_TUTORIAL_REROLL_PICK := "reroll_pick"
const MACHINE_TUTORIAL_CONSUMABLE := "consumable"
const MACHINE_TUTORIAL_KEEP := "keep"
const MACHINE_TUTORIAL_TABLES := "tables"
const MACHINE_TUTORIAL_COMPLETE := "complete"

const TUTORIAL_STEPS := [
	{
		"title": "DEALER SHOP",
		"body": "Before a run, the Dealer sells a variety of consumables for your run. Tap SERUM or TOBACCO on the counter.",
		"scene": "dealer",
		"mode": "interactive",
		"rect": Rect2(8.0, 184.0, 144.0, 42.0),
	},
	{
		"title": "MACHINE",
		"body": "Pick a multiplier. Higher pays more but costs more spins.",
		"scene": "machine",
		"mode": "interactive",
		"rect": Rect2(34.0, 131.0, 92.0, 20.0),
	},
	{
		"title": "DEALER OFFER",
		"body": "Mid-run, the Dealer may offer run-only items. LOOK shows hints; TAKE buys, LEAVE skips.",
		"scene": "offer",
		"rect": Rect2(12.0, 118.0, 136.0, 72.0),
	},
	{
		"title": "UPGRADES",
		"body": "The lab spends saved lucidity on permanent upgrades. Brain upgrades change future runs, and eye terminals unlock machine tools.",
		"scene": "upgrades",
		"rect": Rect2(12.0, 120.0, 136.0, 90.0),
	},
	{
		"title": "READY",
		"body": "That is the loop: buy carefully, spin for wealth, survive downsides, take mid-run offers when they help, and upgrade between attempts.",
		"scene": "dealer",
	},
]

@export_group("First Launch Tutorial")
@export var tutorial_pauses_tree: bool = true
@export var tutorial_title_text: String = "TUTORIAL"

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
var _tutorial_modal: Control = null
var _tutorial_preview_root: Control = null
var _tutorial_panel: PanelContainer = null
var _tutorial_title: Label = null
var _tutorial_body: RichTextLabel = null
var _tutorial_step_label: Label = null
var _tutorial_prev_button: Button = null
var _tutorial_next_button: Button = null
var _tutorial_skip_button: Button = null
var _tutorial_highlight: Panel = null
var _tutorial_extra_highlights: Array[Panel] = []
var _tutorial_pointer: Label = null
var _tutorial_step_index := 0
var _tutorial_mark_seen_on_close := true
var _tutorial_start_run_after_close := false
var _tutorial_dealer_stage := DEALER_TUTORIAL_PREAMBLE
var _tutorial_dealer_selected_id := ""
var _tutorial_machine_stage := MACHINE_TUTORIAL_MULTIPLIER
var _tutorial_machine_table_visible := false

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
	_tutorial_preview_root = get_node_or_null("TutorialModal/PreviewRoot") as Control
	_tutorial_panel = get_node_or_null("TutorialModal/Panel") as PanelContainer
	_tutorial_title = get_node_or_null("TutorialModal/Panel/Margin/Content/Title") as Label
	_tutorial_body = get_node_or_null("TutorialModal/Panel/Margin/Content/Body") as RichTextLabel
	_tutorial_step_label = get_node_or_null("TutorialModal/Panel/Margin/Content/StepLabel") as Label
	_tutorial_prev_button = get_node_or_null("TutorialModal/Panel/Margin/Content/Buttons/PrevButton") as Button
	_tutorial_next_button = get_node_or_null("TutorialModal/Panel/Margin/Content/Buttons/NextButton") as Button
	_tutorial_skip_button = get_node_or_null("TutorialModal/Panel/Margin/Content/Buttons/SkipButton") as Button
	_tutorial_highlight = get_node_or_null("TutorialModal/Highlight") as Panel
	_tutorial_pointer = get_node_or_null("TutorialModal/Pointer") as Label

func _build_background() -> void:
	if _background != null:
		if _background.texture == null:
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
		_remove_tutorial_menu_button()
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

func _remove_tutorial_menu_button() -> void:
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	if col == null:
		return
	var tutorial_button := col.get_node_or_null("TutorialButton") as Button
	if tutorial_button != null:
		col.remove_child(tutorial_button)
		tutorial_button.queue_free()

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
	var blocker := _tutorial_modal.get_node_or_null("Blocker") as ColorRect
	if blocker != null:
		blocker.z_index = -1
		blocker.color = Color(0.02, 0.01, 0.04, 0.38)
		blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_tutorial_preview_root()
	if _tutorial_panel != null:
		_tutorial_panel.z_index = TUTORIAL_PANEL_Z
		_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_tutorial_highlight()
	_ensure_tutorial_controls()
	if _tutorial_title != null:
		_tutorial_title.text = tutorial_title_text
		_tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tutorial_title.add_theme_font_size_override("font_size", 10)
		if _font != null:
			_tutorial_title.add_theme_font_override("font", _font)
	if _tutorial_body != null:
		_tutorial_body.custom_minimum_size = Vector2(132.0, TUTORIAL_BODY_H)
		_tutorial_body.bbcode_enabled = true
		_tutorial_body.fit_content = false
		_tutorial_body.scroll_active = false
		_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_body.add_theme_font_size_override("normal_font_size", 6)
		_tutorial_body.add_theme_font_size_override("bold_font_size", 6)
		_tutorial_body.add_theme_color_override("default_color", Color(0.94, 0.88, 1.0))
		if _font != null:
			_tutorial_body.add_theme_font_override("normal_font", _font)
			_tutorial_body.add_theme_font_override("bold_font", _font)
	if _tutorial_step_label != null:
		_tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tutorial_step_label.add_theme_font_size_override("font_size", 6)
		if _font != null:
			_tutorial_step_label.add_theme_font_override("font", _font)
		_tutorial_step_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.64))
	_update_tutorial_step()

func _ensure_tutorial_preview_root() -> void:
	if _tutorial_modal == null:
		return
	if _tutorial_preview_root == null:
		_tutorial_preview_root = Control.new()
		_tutorial_preview_root.name = "PreviewRoot"
		_tutorial_modal.add_child(_tutorial_preview_root)
		_tutorial_modal.move_child(_tutorial_preview_root, mini(1, _tutorial_modal.get_child_count() - 1))
	_tutorial_preview_root.position = Vector2.ZERO
	_tutorial_preview_root.size = Vector2(CANVAS_W, CANVAS_H)
	_tutorial_preview_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_tutorial_preview_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_preview_root.z_index = 0

func _ensure_tutorial_highlight() -> void:
	if _tutorial_modal == null:
		return
	if _tutorial_highlight == null:
		_tutorial_highlight = Panel.new()
		_tutorial_highlight.name = "Highlight"
		_tutorial_modal.add_child(_tutorial_highlight)
		_tutorial_modal.move_child(_tutorial_highlight, mini(1, _tutorial_modal.get_child_count() - 1))
	_tutorial_highlight.add_theme_stylebox_override("panel", _tutorial_highlight_style())
	_tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_highlight.z_index = TUTORIAL_HIGHLIGHT_Z
	if _tutorial_pointer == null:
		_tutorial_pointer = Label.new()
		_tutorial_pointer.name = "Pointer"
		_tutorial_modal.add_child(_tutorial_pointer)
	_tutorial_pointer.text = "LOOK"
	_tutorial_pointer.add_theme_font_size_override("font_size", 6)
	_tutorial_pointer.add_theme_color_override("font_color", Color(1.0, 0.85, 0.22))
	_tutorial_pointer.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_pointer.add_theme_constant_override("outline_size", 1)
	if _font != null:
		_tutorial_pointer.add_theme_font_override("font", _font)
	_tutorial_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_pointer.z_index = TUTORIAL_POINTER_Z

func _tutorial_highlight_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.82, 0.22, 0.10)
	style.border_color = Color(1.0, 0.85, 0.22, 1.0)
	style.set_border_width_all(1)
	return style

func _ensure_tutorial_controls() -> void:
	var content := get_node_or_null("TutorialModal/Panel/Margin/Content") as VBoxContainer
	if content == null:
		return
	if _tutorial_step_label == null:
		_tutorial_step_label = Label.new()
		_tutorial_step_label.name = "StepLabel"
		content.add_child(_tutorial_step_label)
		content.move_child(_tutorial_step_label, 1)
	var old_ok := content.get_node_or_null("OkButton") as Button
	if old_ok != null and old_ok.get_parent() == content:
		content.remove_child(old_ok)
	var row := content.get_node_or_null("Buttons") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "Buttons"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		content.add_child(row)
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_skip_button = _ensure_tutorial_button(row, "SkipButton", "SKIP", _skip_tutorial)
	_tutorial_prev_button = _ensure_tutorial_button(row, "PrevButton", "BACK", _previous_tutorial_step)
	_tutorial_next_button = _ensure_tutorial_button(row, "NextButton", "NEXT", _next_tutorial_step)
	if old_ok != null:
		old_ok.queue_free()

func _ensure_tutorial_button(parent: Control, node_name: String, text: String, cb: Callable) -> Button:
	var button := parent.get_node_or_null(node_name) as Button
	if button == null:
		button = Button.new()
		button.name = node_name
		parent.add_child(button)
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(38.0, 18.0)
	button.add_theme_font_size_override("font_size", 6)
	if _font != null:
		button.add_theme_font_override("font", _font)
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)
	return button

func _maybe_show_tutorial() -> void:
	if Engine.is_editor_hint() or _tutorial_modal == null:
		return
	_tutorial_modal.visible = false

func _open_tutorial(mark_seen_on_close := true) -> void:
	if Engine.is_editor_hint() or _tutorial_modal == null:
		return
	_tutorial_mark_seen_on_close = mark_seen_on_close
	_tutorial_step_index = 0
	_tutorial_dealer_stage = DEALER_TUTORIAL_PREAMBLE
	_tutorial_dealer_selected_id = ""
	_tutorial_machine_stage = MACHINE_TUTORIAL_MULTIPLIER
	_tutorial_machine_table_visible = false
	_tutorial_modal.visible = true
	_update_tutorial_step()
	if _tutorial_next_button != null:
		_tutorial_next_button.grab_focus()
	if tutorial_pauses_tree:
		get_tree().paused = true

func _skip_tutorial() -> void:
	_finish_tutorial(true)

func _dismiss_tutorial(save_immediately := true) -> void:
	if _tutorial_modal != null:
		_tutorial_modal.visible = false
	if _tutorial_highlight != null:
		_tutorial_highlight.visible = false
	for highlight in _tutorial_extra_highlights:
		if highlight != null and is_instance_valid(highlight):
			highlight.visible = false
	if _tutorial_pointer != null:
		_tutorial_pointer.visible = false
	_clear_tutorial_preview()
	if tutorial_pauses_tree:
		get_tree().paused = false
	if not Engine.is_editor_hint() and _tutorial_mark_seen_on_close:
		MetaStateStore.mark_tutorial_seen(save_immediately)

func _finish_tutorial(save_immediately := true) -> void:
	var should_start_run := _tutorial_start_run_after_close
	_tutorial_start_run_after_close = false
	_dismiss_tutorial(save_immediately)
	if should_start_run:
		_begin_start_run()

func _previous_tutorial_step() -> void:
	_tutorial_step_index = maxi(0, _tutorial_step_index - 1)
	if _tutorial_step_index == 0:
		_tutorial_dealer_stage = DEALER_TUTORIAL_PREAMBLE
		_tutorial_dealer_selected_id = ""
		_clear_tutorial_preview()
	elif _is_machine_interactive_step_index(_tutorial_step_index):
		_tutorial_machine_stage = MACHINE_TUTORIAL_MULTIPLIER
		_tutorial_machine_table_visible = false
		_clear_tutorial_preview()
	_update_tutorial_step()

func _next_tutorial_step() -> void:
	if _is_dealer_interactive_step_index(_tutorial_step_index):
		match _tutorial_dealer_stage:
			DEALER_TUTORIAL_HINTS:
				_enter_tutorial_dealer_stage(DEALER_TUTORIAL_ECONOMY)
				return
			DEALER_TUTORIAL_ECONOMY:
				_enter_tutorial_dealer_stage(DEALER_TUTORIAL_BUY)
				return
			DEALER_TUTORIAL_STASH:
				_enter_tutorial_dealer_stage(DEALER_TUTORIAL_NAVIGATE)
				return
			DEALER_TUTORIAL_COMPLETE:
				pass
			_:
				return
	if _is_machine_interactive_step_index(_tutorial_step_index):
		if _tutorial_machine_stage == MACHINE_TUTORIAL_KEEP:
			_enter_tutorial_machine_stage(MACHINE_TUTORIAL_TABLES)
			return
		if _tutorial_machine_stage == MACHINE_TUTORIAL_TABLES and _tutorial_machine_table_visible:
			var machine := _current_tutorial_machine()
			if machine != null:
				machine.call("_close_score_table")
			return
		if _tutorial_machine_stage != MACHINE_TUTORIAL_COMPLETE:
			return
	if _tutorial_step_index == 0 and _tutorial_dealer_stage != DEALER_TUTORIAL_COMPLETE:
		return
	if _tutorial_step_index >= TUTORIAL_STEPS.size() - 1:
		_finish_tutorial(true)
		return
	_tutorial_step_index += 1
	_update_tutorial_step()

func _update_tutorial_step() -> void:
	if _tutorial_modal == null or TUTORIAL_STEPS.is_empty():
		return
	_tutorial_step_index = clampi(_tutorial_step_index, 0, TUTORIAL_STEPS.size() - 1)
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_step_index]
	var rects := _tutorial_rects_for_step(step)
	var rect := Rect2()
	if not rects.is_empty():
		rect = rects[0]
	_update_tutorial_preview(step)
	_layout_tutorial_panel(rect)
	if _tutorial_title != null:
		_tutorial_title.text = String(step.get("title", tutorial_title_text))
	if _tutorial_body != null:
		_tutorial_body.text = _tutorial_body_for_step(step)
	if _tutorial_step_label != null:
		_tutorial_step_label.text = "%d/%d" % [_tutorial_step_index + 1, TUTORIAL_STEPS.size()]
	if _tutorial_prev_button != null:
		_tutorial_prev_button.disabled = _tutorial_step_index == 0
	if _tutorial_next_button != null:
		if _is_machine_interactive_step(step) and _tutorial_machine_stage == MACHINE_TUTORIAL_TABLES \
				and _tutorial_machine_table_visible:
			_tutorial_next_button.text = "CLOSE"
		else:
			_tutorial_next_button.text = "DONE" if _tutorial_step_index >= TUTORIAL_STEPS.size() - 1 else "NEXT"
		_tutorial_next_button.disabled = not _tutorial_next_enabled_for_step(step)
	_update_tutorial_highlights(rects)

func _tutorial_next_enabled_for_step(step: Dictionary) -> bool:
	if _tutorial_step_index >= TUTORIAL_STEPS.size() - 1:
		return true
	if _is_dealer_interactive_step(step):
		return _tutorial_dealer_stage in [
			DEALER_TUTORIAL_HINTS,
			DEALER_TUTORIAL_ECONOMY,
			DEALER_TUTORIAL_STASH,
			DEALER_TUTORIAL_COMPLETE,
		]
	if _is_machine_interactive_step(step):
		return _tutorial_machine_stage == MACHINE_TUTORIAL_KEEP \
				or _tutorial_machine_stage == MACHINE_TUTORIAL_COMPLETE \
				or (_tutorial_machine_stage == MACHINE_TUTORIAL_TABLES and _tutorial_machine_table_visible)
	return true

func _is_dealer_interactive_step(step: Dictionary) -> bool:
	return String(step.get("scene", "")) == "dealer" and String(step.get("mode", "")) == "interactive"

func _is_machine_interactive_step(step: Dictionary) -> bool:
	return String(step.get("scene", "")) == "machine" and String(step.get("mode", "")) == "interactive"

func _is_dealer_interactive_step_index(index: int) -> bool:
	if index < 0 or index >= TUTORIAL_STEPS.size():
		return false
	return _is_dealer_interactive_step(TUTORIAL_STEPS[index])

func _is_machine_interactive_step_index(index: int) -> bool:
	if index < 0 or index >= TUTORIAL_STEPS.size():
		return false
	return _is_machine_interactive_step(TUTORIAL_STEPS[index])

func _tutorial_panel_size_for_current_step() -> Vector2:
	if _is_machine_interactive_step_index(_tutorial_step_index):
		return TUTORIAL_MACHINE_PANEL_SIZE
	if _is_dealer_interactive_step_index(_tutorial_step_index):
		return TUTORIAL_INTERACTIVE_PANEL_SIZE
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_step_index]
	if String(step.get("scene", "")) == "offer":
		return TUTORIAL_STATIC_COMPACT_PANEL_SIZE
	return TUTORIAL_PANEL_SIZE

func _tutorial_body_for_step(step: Dictionary) -> String:
	if _is_dealer_interactive_step(step):
		match _tutorial_dealer_stage:
			DEALER_TUTORIAL_HINTS:
				return "The TV shows vague hints: green = upside, red = risk."
			DEALER_TUTORIAL_ECONOMY:
				return "CREDITS at bottom-left is your money. Each item shows its price above it."
			DEALER_TUTORIAL_BUY:
				return "Drag the selected item up onto the Dealer to buy it."
			DEALER_TUTORIAL_STASH:
				return "Bought items go to your stash, your consumables for the run."
			DEALER_TUTORIAL_NAVIGATE:
				return "LAB opens permanent upgrades. Tap MACHINE to start the run."
			DEALER_TUTORIAL_COMPLETE:
				return "The Dealer is set."
	if _is_machine_interactive_step(step):
		match _tutorial_machine_stage:
			MACHINE_TUTORIAL_SPINS:
				return "Pull the lever. It spends spins equal to your multiplier."
			MACHINE_TUTORIAL_REROLL:
				return "Tap REROLL to arm the power."
			MACHINE_TUTORIAL_REROLL_PICK:
				return "Now choose which reel to re-spin."
			MACHINE_TUTORIAL_CONSUMABLE:
				return "Use Energy Drink. Effects pop up, and duration appears on the TV."
			MACHINE_TUTORIAL_KEEP:
				return "At the end of a run you keep 10% of your score as lucidity."
			MACHINE_TUTORIAL_TABLES:
				return "TABLES opens the score and odds table."
			MACHINE_TUTORIAL_COMPLETE:
				return "The machine basics are set."
	return String(step.get("body", ""))

func _tutorial_dealer_item_name(id: String) -> String:
	match id:
		"cons_focus":
			return "SERUM"
		"cons_cigarette":
			return "TOBACCO"
	return "ITEM"

func _layout_tutorial_panel(highlight_rect: Rect2) -> void:
	if _tutorial_panel == null:
		return
	var panel_size := _tutorial_panel_size_for_current_step()
	var y := (CANVAS_H - panel_size.y) * 0.5
	if highlight_rect.size != Vector2.ZERO:
		if highlight_rect.get_center().y < CANVAS_H * 0.5:
			y = CANVAS_H - TUTORIAL_PANEL_TOP_Y - panel_size.y
		else:
			y = TUTORIAL_PANEL_TOP_Y
	if _is_dealer_interactive_step_index(_tutorial_step_index):
		match _tutorial_dealer_stage:
			DEALER_TUTORIAL_HINTS:
				y = CANVAS_H - TUTORIAL_PANEL_TOP_Y - panel_size.y
			DEALER_TUTORIAL_ECONOMY:
				y = 74.0
			DEALER_TUTORIAL_BUY:
				y = CANVAS_H - panel_size.y
			DEALER_TUTORIAL_STASH:
				y = TUTORIAL_PANEL_TOP_Y
			DEALER_TUTORIAL_NAVIGATE:
				y = 62.0
	if _is_machine_interactive_step_index(_tutorial_step_index):
		match _tutorial_machine_stage:
			MACHINE_TUTORIAL_MULTIPLIER, MACHINE_TUTORIAL_SPINS, MACHINE_TUTORIAL_REROLL:
				y = 8.0
			MACHINE_TUTORIAL_REROLL_PICK:
				y = 8.0
			MACHINE_TUTORIAL_CONSUMABLE:
				y = 8.0
			MACHINE_TUTORIAL_KEEP, MACHINE_TUTORIAL_TABLES:
				y = CANVAS_H - TUTORIAL_PANEL_TOP_Y - panel_size.y
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_step_index]
	match String(step.get("scene", "")):
		"offer":
			y = CANVAS_H - TUTORIAL_PANEL_TOP_Y - panel_size.y
		"upgrades":
			y = (CANVAS_H - panel_size.y) * 0.5
	_tutorial_panel.position = Vector2((CANVAS_W - panel_size.x) * 0.5, y)
	_tutorial_panel.size = panel_size
	_tutorial_panel.custom_minimum_size = panel_size
	if _tutorial_body != null:
		_tutorial_body.custom_minimum_size = Vector2(132.0, 38.0 if panel_size.y < TUTORIAL_PANEL_SIZE.y else TUTORIAL_BODY_H)

func _update_tutorial_highlights(rects: Array) -> void:
	if _tutorial_highlight == null or _tutorial_pointer == null:
		return
	if rects.is_empty():
		_hide_tutorial_highlights()
		return
	while _tutorial_extra_highlights.size() < rects.size() - 1:
		var extra := Panel.new()
		extra.name = "Highlight%d" % (_tutorial_extra_highlights.size() + 2)
		extra.add_theme_stylebox_override("panel", _tutorial_highlight_style())
		extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		extra.z_index = TUTORIAL_HIGHLIGHT_Z
		_tutorial_modal.add_child(extra)
		_tutorial_extra_highlights.append(extra)
	for i in _tutorial_extra_highlights.size():
		_tutorial_extra_highlights[i].visible = i < rects.size() - 1
	for i in rects.size():
		var rect: Rect2 = rects[i]
		if rect.size == Vector2.ZERO:
			continue
		rect = rect.grow(TUTORIAL_HIGHLIGHT_PAD)
		var highlight := _tutorial_highlight if i == 0 else _tutorial_extra_highlights[i - 1]
		highlight.position = rect.position
		highlight.size = rect.size
		highlight.visible = true
	var pointer_rect: Rect2 = rects[0].grow(TUTORIAL_HIGHLIGHT_PAD)
	_tutorial_pointer.position = Vector2(
		clampf(pointer_rect.position.x, 2.0, CANVAS_W - 34.0),
		clampf(pointer_rect.position.y - 10.0, 2.0, 306.0)
	)
	_tutorial_pointer.visible = true

func _hide_tutorial_highlights() -> void:
	if _tutorial_highlight != null:
		_tutorial_highlight.visible = false
	for highlight in _tutorial_extra_highlights:
		if highlight != null and is_instance_valid(highlight):
			highlight.visible = false
	if _tutorial_pointer != null:
		_tutorial_pointer.visible = false

func _update_tutorial_preview(step: Dictionary) -> void:
	if _tutorial_preview_root == null:
		return
	var scene_key := String(step.get("scene", ""))
	var mode := String(step.get("mode", ""))
	if String(_tutorial_preview_root.get_meta("scene_key", "")) == scene_key \
			and String(_tutorial_preview_root.get_meta("mode", "")) == mode:
		return
	_clear_tutorial_preview()
	_tutorial_preview_root.set_meta("scene_key", scene_key)
	_tutorial_preview_root.set_meta("mode", mode)
	var preview := _tutorial_preview_for(scene_key, mode)
	if preview == null:
		return
	_tutorial_preview_root.add_child(preview)
	if scene_key == "machine" and mode == "interactive":
		preview.call("set_tutorial_stage", _tutorial_machine_stage)

func _clear_tutorial_preview() -> void:
	if _tutorial_preview_root == null:
		return
	for child in _tutorial_preview_root.get_children():
		child.free()
	_tutorial_preview_root.set_meta("scene_key", "")
	_tutorial_preview_root.set_meta("mode", "")

func _tutorial_preview_for(scene_key: String, mode: String) -> Node:
	match scene_key:
		"dealer":
			var dealer := DEALER_SCENE_PACKED.instantiate() as Control
			var interactive := mode == "interactive"
			dealer.set("tutorial_preview", true)
			dealer.set("tutorial_interactive", interactive)
			var dealer_offer_ids: Array[String] = ["cons_focus", "cons_cigarette"]
			var dealer_stash_ids: Array[String] = []
			if not interactive:
				dealer_stash_ids.append("cons_tea")
			dealer.set("tutorial_preview_offer_ids", dealer_offer_ids)
			dealer.set("tutorial_preview_stash_ids", dealer_stash_ids)
			dealer.set("tutorial_preview_wallet", 35 if interactive else 120)
			dealer.set("tutorial_preview_selected_id", "" if interactive else "cons_focus")
			if interactive:
				dealer.connect(&"tutorial_item_selected", _on_tutorial_dealer_item_selected)
				dealer.connect(&"tutorial_item_bought", _on_tutorial_dealer_item_bought)
				dealer.connect(&"tutorial_lab_pressed", _on_tutorial_dealer_lab_pressed)
				dealer.connect(&"tutorial_machine_pressed", _on_tutorial_dealer_machine_pressed)
			return dealer
		"machine":
			var machine := MACHINE_SCENE_PACKED.instantiate()
			machine.set("tutorial_preview", true)
			machine.set("tutorial_interactive", mode == "interactive")
			machine.set("tutorial_preview_mode", "effects" if mode == "effects" else "machine")
			machine.set("tutorial_preview_stash_ids", ["item_energy_drink", "item_cocktail"])
			if mode == "interactive":
				machine.connect(&"tutorial_multiplier_selected", _on_tutorial_machine_multiplier_selected)
				machine.connect(&"tutorial_spin_completed", _on_tutorial_machine_spin_completed)
				machine.connect(&"tutorial_reroll_armed", _on_tutorial_machine_reroll_armed)
				machine.connect(&"tutorial_reroll_used", _on_tutorial_machine_reroll_used)
				machine.connect(&"tutorial_consumable_used", _on_tutorial_machine_consumable_used)
				machine.connect(&"tutorial_tables_shown", _on_tutorial_machine_tables_shown)
				machine.connect(&"tutorial_tables_opened", _on_tutorial_machine_tables_opened)
			return machine
		"offer":
			var composite := Control.new()
			composite.name = "OfferTutorialPreview"
			composite.size = Vector2(CANVAS_W, CANVAS_H)
			composite.mouse_filter = Control.MOUSE_FILTER_PASS
			var machine := MACHINE_SCENE_PACKED.instantiate()
			machine.name = "MachineBackground"
			machine.set("tutorial_preview", true)
			machine.set("tutorial_interactive", false)
			machine.set("tutorial_preview_mode", "machine")
			machine.set("tutorial_preview_labels", false)
			machine.set("tutorial_preview_stash_ids", ["item_energy_drink", "item_cocktail"])
			if machine is CanvasItem:
				(machine as CanvasItem).z_index = 0
			composite.add_child(machine)
			var offer := IN_RUN_DEALER_OFFER_SCENE_PACKED.instantiate() as InRunDealerOffer
			offer.name = "OfferOverlay"
			offer.tutorial_preview = true
			offer.editor_preview_offer_ids = ["item_energy_drink", "item_pill"]
			offer.z_index = 40
			composite.add_child(offer)
			return composite
		"upgrades":
			var upgrades := UPGRADES_SCENE_PACKED.instantiate() as Control
			upgrades.set("tutorial_preview", true)
			upgrades.set("editor_preview_wallet", 500)
			return upgrades
	return null

func _on_tutorial_dealer_item_selected(id: String) -> void:
	if not _is_dealer_interactive_step_index(_tutorial_step_index):
		return
	_tutorial_dealer_selected_id = id
	match _tutorial_dealer_stage:
		DEALER_TUTORIAL_PREAMBLE, DEALER_TUTORIAL_HINTS:
			_enter_tutorial_dealer_stage(DEALER_TUTORIAL_HINTS)
		DEALER_TUTORIAL_BUY:
			var dealer := _current_tutorial_dealer()
			if dealer != null:
				dealer.call("play_tutorial_ghost_drag", _tutorial_dealer_selected_id)
			_update_tutorial_step()
		_:
			_update_tutorial_step()

func _on_tutorial_dealer_item_bought(id: String) -> void:
	if not _is_dealer_interactive_step_index(_tutorial_step_index):
		return
	_tutorial_dealer_selected_id = id
	_enter_tutorial_dealer_stage(DEALER_TUTORIAL_STASH)

func _on_tutorial_dealer_lab_pressed() -> void:
	if not _is_dealer_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_dealer_stage == DEALER_TUTORIAL_NAVIGATE:
		if _tutorial_body != null:
			_tutorial_body.text = "LAB opens permanent upgrades between attempts. For this first run, tap MACHINE to continue."

func _on_tutorial_dealer_machine_pressed() -> void:
	if not _is_dealer_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_dealer_stage != DEALER_TUTORIAL_NAVIGATE:
		return
	_tutorial_dealer_stage = DEALER_TUTORIAL_COMPLETE
	call_deferred("_next_tutorial_step")

func _enter_tutorial_dealer_stage(stage: String) -> void:
	var previous := _tutorial_dealer_stage
	_tutorial_dealer_stage = stage
	var dealer := _current_tutorial_dealer()
	if dealer != null:
		if previous == DEALER_TUTORIAL_BUY and stage != DEALER_TUTORIAL_BUY:
			dealer.call("stop_tutorial_ghost_drag")
		if stage == DEALER_TUTORIAL_BUY and not _tutorial_dealer_selected_id.is_empty():
			dealer.call("play_tutorial_ghost_drag", _tutorial_dealer_selected_id)
		if stage == DEALER_TUTORIAL_NAVIGATE:
			dealer.call("set_tutorial_navigation_enabled", true)
		elif previous == DEALER_TUTORIAL_NAVIGATE:
			dealer.call("set_tutorial_navigation_enabled", false)
	_update_tutorial_step()

func _current_tutorial_dealer() -> Control:
	if _tutorial_preview_root == null:
		return null
	if _tutorial_preview_root.get_child_count() <= 0:
		return null
	return _tutorial_preview_root.get_child(0) as Control

func _on_tutorial_machine_multiplier_selected(_mult: int) -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_MULTIPLIER:
		_enter_tutorial_machine_stage(MACHINE_TUTORIAL_SPINS)

func _on_tutorial_machine_spin_completed() -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_SPINS:
		_enter_tutorial_machine_stage(MACHINE_TUTORIAL_REROLL)

func _on_tutorial_machine_reroll_used() -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_REROLL_PICK:
		_enter_tutorial_machine_stage(MACHINE_TUTORIAL_CONSUMABLE)

func _on_tutorial_machine_reroll_armed() -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_REROLL:
		_enter_tutorial_machine_stage(MACHINE_TUTORIAL_REROLL_PICK)

func _on_tutorial_machine_consumable_used(_id: String) -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_CONSUMABLE:
		_enter_tutorial_machine_stage(MACHINE_TUTORIAL_KEEP)

func _on_tutorial_machine_tables_opened() -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_TABLES:
		_tutorial_machine_table_visible = false
		_tutorial_machine_stage = MACHINE_TUTORIAL_COMPLETE
		call_deferred("_next_tutorial_step")

func _on_tutorial_machine_tables_shown() -> void:
	if not _is_machine_interactive_step_index(_tutorial_step_index):
		return
	if _tutorial_machine_stage == MACHINE_TUTORIAL_TABLES:
		_tutorial_machine_table_visible = true
		_update_tutorial_step()

func _enter_tutorial_machine_stage(stage: String) -> void:
	_tutorial_machine_stage = stage
	if stage != MACHINE_TUTORIAL_TABLES:
		_tutorial_machine_table_visible = false
	var machine := _current_tutorial_machine()
	if machine != null:
		machine.call("set_tutorial_stage", stage)
	_update_tutorial_step()

func _current_tutorial_machine() -> Node:
	if _tutorial_preview_root == null:
		return null
	if _tutorial_preview_root.get_child_count() <= 0:
		return null
	return _tutorial_preview_root.get_child(0)

func _tutorial_rects_for_step(step: Dictionary) -> Array:
	if _is_dealer_interactive_step(step):
		match _tutorial_dealer_stage:
			DEALER_TUTORIAL_HINTS:
				return [Rect2(2.0, 124.0, 86.0, 26.0)]
			DEALER_TUTORIAL_ECONOMY:
				return [
					Rect2(2.0, 297.0, 38.0, 16.0),
					Rect2(0.0, 184.0, 58.0, 16.0),
				]
			DEALER_TUTORIAL_BUY:
				return [
					Rect2(0.0, 186.0, 56.0, 31.0),
					Rect2(56.0, 122.0, 48.0, 54.0),
				]
			DEALER_TUTORIAL_STASH:
				return [Rect2(104.0, 288.0, 52.0, 30.0)]
			DEALER_TUTORIAL_NAVIGATE:
				return [Rect2(61.0, 8.0, 88.0, 34.0)]
			DEALER_TUTORIAL_COMPLETE:
				return [Rect2(128.0, 8.0, 22.0, 34.0)]
		return [Rect2(4.0, 184.0, 48.0, 36.0)]
	if _is_machine_interactive_step(step):
		match _tutorial_machine_stage:
			MACHINE_TUTORIAL_MULTIPLIER:
				return [Rect2(36.0, 116.0, 84.0, 24.0)]
			MACHINE_TUTORIAL_SPINS:
				return [Rect2(130.0, 156.0, 27.0, 48.0)]
			MACHINE_TUTORIAL_REROLL:
				return [Rect2(18.0, 220.0, 21.0, 21.0)]
			MACHINE_TUTORIAL_REROLL_PICK:
				return [Rect2(29.0, 160.0, 93.0, 56.0)]
			MACHINE_TUTORIAL_CONSUMABLE:
				return [Rect2(104.0, 288.0, 24.0, 30.0)]
			MACHINE_TUTORIAL_KEEP:
				return [Rect2(32.0, 58.0, 104.0, 18.0)]
			MACHINE_TUTORIAL_TABLES:
				return [Rect2(108.0, 7.0, 44.0, 18.0)]
	match String(step.get("scene", "")):
		"offer":
			return [Rect2(10.0, 105.0, 140.0, 72.0)]
		"upgrades":
			return [
				Rect2(47.0, 102.0, 64.0, 72.0),
				Rect2(58.0, 4.0, 68.0, 50.0),
			]
	var target_path := String(step.get("target", ""))
	if not target_path.is_empty():
		var target := get_node_or_null(target_path) as Control
		if target != null:
			var target_rect := target.get_global_rect()
			if _tutorial_modal != null:
				var modal_rect := _tutorial_modal.get_global_rect()
				target_rect.position -= modal_rect.position
			return [target_rect]
	if step.has("rect"):
		var rect: Rect2 = step["rect"]
		return [rect]
	return []

func _start_run() -> void:
	if not Engine.is_editor_hint() and MetaStateStore.is_first_launch and RunStateStore.runPhase != "running":
		_tutorial_start_run_after_close = true
		_open_tutorial(true)
		return
	_begin_start_run()

func _begin_start_run() -> void:
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
	# Begin a fresh run by visiting the dealer FIRST; the dealer scene runs in
	# pre-run shop mode and starts the run once the player leaves the counter.
	get_tree().change_scene_to_file(DEALER_SCENE)

func _open_scores() -> void:
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("push_current_scene")
	get_tree().change_scene_to_file(SCORES_SCENE)
