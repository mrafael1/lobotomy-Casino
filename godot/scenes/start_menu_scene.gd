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
const CANVAS_W := 160.0
const MENU_W := 148.0
# Title sits high so the whole column (titles, meter + count, hint, buttons) fits
# the 160x320 canvas without clipping.
const MENU_Y := 44.0
const MENU_SEPARATION := 6
const TITLE_SPACER_H := 8.0
const CAMPAIGN_HINT_H := 18.0
const TUTORIAL_HIGHLIGHT_PAD := 3.0

const TUTORIAL_STEPS := [
	{
		"title": "BASIC CONTROLS",
		"body": "Tap buttons to move between screens. START RUN visits the Dealer first. SCORES shows records. This TUTORIAL can be reopened here any time.",
		"target": "MenuColumn/StartButton",
	},
	{
		"title": "DEALER SHOP",
		"body": "Before a run, the Dealer sells consumables. Tap an item to read its green upside and red risk. Drag an offer onto the Dealer to buy it. Drag stash items back to the Dealer to discard them.",
		"rect": Rect2(8.0, 126.0, 144.0, 92.0),
	},
	{
		"title": "STANDARD TURN",
		"body": "On the machine, choose x1, x2, or x3, then pull the lever. A spin resolves the reels, pays pairs/triples, updates wealth, and drains neurons unless a free-spin effect prevents it.",
		"rect": Rect2(22.0, 42.0, 116.0, 178.0),
	},
	{
		"title": "CONSUMABLES",
		"body": "Your stash holds two consumables. Tap a stash icon during a run to use it. Energy Drink is the simple example: it grants free no-decay spins before its downside arrives.",
		"rect": Rect2(108.0, 252.0, 44.0, 42.0),
	},
	{
		"title": "NEGATIVE EFFECTS",
		"body": "Some items have delayed debuffs. Energy Drink queues a Compulsion: the machine takes a forced x1 spin and locks manual controls until that forced spin resolves.",
		"rect": Rect2(18.0, 116.0, 124.0, 108.0),
	},
	{
		"title": "DEALER SEQUENCE",
		"body": "The Dealer can interrupt mid-run with run-only items. Resolve the offer or ignore it to continue. If a Compulsion is pending, the forced spin resolves before the Dealer flow can strand you.",
		"rect": Rect2(16.0, 78.0, 128.0, 128.0),
	},
	{
		"title": "READY",
		"body": "Skip when you know the loop. Reopen TUTORIAL from the main menu whenever you need the guide. Start a run when you are ready to chase wealth before flatline.",
		"target": "MenuColumn/StartButton",
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
var _tutorial_menu_button: Button = null
var _campaign_label: Label = null
var _campaign_meter: NeuronMeter = null # issue #38 pixel-art neuron meter
var _campaign_hint: Label = null
var _tutorial_modal: Control = null
var _tutorial_title: Label = null
var _tutorial_body: RichTextLabel = null
var _tutorial_step_label: Label = null
var _tutorial_prev_button: Button = null
var _tutorial_next_button: Button = null
var _tutorial_skip_button: Button = null
var _tutorial_highlight: Panel = null
var _tutorial_pointer: Label = null
var _tutorial_step_index := 0

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
		_tutorial_menu_button = get_node_or_null("MenuColumn/TutorialButton") as Button
		_ensure_tutorial_menu_button()
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
	_tutorial_menu_button = _menu_button("TUTORIAL", 8, _open_tutorial)
	_tutorial_menu_button.name = "TutorialButton"
	col.add_child(_tutorial_menu_button)
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

func _ensure_tutorial_menu_button() -> void:
	var col := get_node_or_null("MenuColumn") as VBoxContainer
	if col == null:
		return
	if _tutorial_menu_button == null:
		_tutorial_menu_button = _menu_button("TUTORIAL", 8, _open_tutorial)
		_tutorial_menu_button.name = "TutorialButton"
		var insert_index := _scores_button.get_index() if _scores_button != null else col.get_child_count()
		col.add_child(_tutorial_menu_button)
		col.move_child(_tutorial_menu_button, insert_index)
	else:
		_tutorial_menu_button.text = "TUTORIAL"
		_tutorial_menu_button.add_theme_font_size_override("font_size", 8)
		if _font != null:
			_tutorial_menu_button.add_theme_font_override("font", _font)
		_connect_button(_tutorial_menu_button, _open_tutorial)

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
	_ensure_tutorial_highlight()
	_ensure_tutorial_controls()
	if _tutorial_title != null:
		_tutorial_title.text = tutorial_title_text
		_tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tutorial_title.add_theme_font_size_override("font_size", 10)
		if _font != null:
			_tutorial_title.add_theme_font_override("font", _font)
	if _tutorial_body != null:
		_tutorial_body.custom_minimum_size = Vector2(132.0, 180.0)
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

func _ensure_tutorial_highlight() -> void:
	if _tutorial_modal == null:
		return
	if _tutorial_highlight == null:
		_tutorial_highlight = Panel.new()
		_tutorial_highlight.name = "Highlight"
		_tutorial_modal.add_child(_tutorial_highlight)
		_tutorial_modal.move_child(_tutorial_highlight, mini(1, _tutorial_modal.get_child_count() - 1))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.82, 0.22, 0.10)
	style.border_color = Color(1.0, 0.85, 0.22, 1.0)
	style.set_border_width_all(1)
	_tutorial_highlight.add_theme_stylebox_override("panel", style)
	_tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_highlight.z_index = 201
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
	_tutorial_pointer.z_index = 202

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
	if not MetaStateStore.is_first_launch:
		_tutorial_modal.visible = false
		return
	_open_tutorial()

func _open_tutorial() -> void:
	if Engine.is_editor_hint() or _tutorial_modal == null:
		return
	_tutorial_step_index = 0
	_tutorial_modal.visible = true
	_update_tutorial_step()
	if _tutorial_next_button != null:
		_tutorial_next_button.grab_focus()
	if tutorial_pauses_tree:
		get_tree().paused = true

func _skip_tutorial() -> void:
	_dismiss_tutorial()

func _dismiss_tutorial(save_immediately := true) -> void:
	if _tutorial_modal != null:
		_tutorial_modal.visible = false
	if _tutorial_highlight != null:
		_tutorial_highlight.visible = false
	if _tutorial_pointer != null:
		_tutorial_pointer.visible = false
	if tutorial_pauses_tree:
		get_tree().paused = false
	if not Engine.is_editor_hint():
		MetaStateStore.mark_tutorial_seen(save_immediately)

func _previous_tutorial_step() -> void:
	_tutorial_step_index = maxi(0, _tutorial_step_index - 1)
	_update_tutorial_step()

func _next_tutorial_step() -> void:
	if _tutorial_step_index >= TUTORIAL_STEPS.size() - 1:
		_dismiss_tutorial()
		return
	_tutorial_step_index += 1
	_update_tutorial_step()

func _update_tutorial_step() -> void:
	if _tutorial_modal == null or TUTORIAL_STEPS.is_empty():
		return
	_tutorial_step_index = clampi(_tutorial_step_index, 0, TUTORIAL_STEPS.size() - 1)
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_step_index]
	if _tutorial_title != null:
		_tutorial_title.text = String(step.get("title", tutorial_title_text))
	if _tutorial_body != null:
		_tutorial_body.text = String(step.get("body", ""))
	if _tutorial_step_label != null:
		_tutorial_step_label.text = "%d/%d" % [_tutorial_step_index + 1, TUTORIAL_STEPS.size()]
	if _tutorial_prev_button != null:
		_tutorial_prev_button.disabled = _tutorial_step_index == 0
	if _tutorial_next_button != null:
		_tutorial_next_button.text = "DONE" if _tutorial_step_index >= TUTORIAL_STEPS.size() - 1 else "NEXT"
	_update_tutorial_highlight(step)

func _update_tutorial_highlight(step: Dictionary) -> void:
	if _tutorial_highlight == null or _tutorial_pointer == null:
		return
	var rect := _tutorial_rect_for_step(step)
	if rect.size == Vector2.ZERO:
		_tutorial_highlight.visible = false
		_tutorial_pointer.visible = false
		return
	rect = rect.grow(TUTORIAL_HIGHLIGHT_PAD)
	_tutorial_highlight.position = rect.position
	_tutorial_highlight.size = rect.size
	_tutorial_highlight.visible = true
	_tutorial_pointer.position = Vector2(
		clampf(rect.position.x, 2.0, CANVAS_W - 34.0),
		clampf(rect.position.y - 10.0, 2.0, 306.0)
	)
	_tutorial_pointer.visible = true

func _tutorial_rect_for_step(step: Dictionary) -> Rect2:
	var target_path := String(step.get("target", ""))
	if not target_path.is_empty():
		var target := get_node_or_null(target_path) as Control
		if target != null:
			return target.get_global_rect()
	if step.has("rect"):
		var rect: Rect2 = step["rect"]
		return rect
	return Rect2()

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
	# Begin a fresh run by visiting the dealer FIRST; the dealer scene runs in
	# pre-run shop mode and starts the run once the player leaves the counter.
	get_tree().change_scene_to_file(DEALER_SCENE)

func _open_scores() -> void:
	var scene_nav := get_node_or_null("/root/SceneNav")
	if scene_nav != null:
		scene_nav.call("push_current_scene")
	get_tree().change_scene_to_file(SCORES_SCENE)
