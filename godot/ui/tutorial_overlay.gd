class_name TutorialOverlay
extends Control

## The coach mark for the played tutorial (issue #105): one instruction box, a ring around
## the control the beat is about, a mask that makes everything else untappable, and SKIP.
##
## The mask is FOUR panels around the anchor rather than one full-rect control with a hole
## drawn in it: Godot's mouse filtering is rectangular, so a drawn hole would still eat the
## tap it appears to expose. Four panels leave a real gap the scene's own button receives.
## With no anchor the four panels close up into one sheet and the whole screen is the
## "tap to continue" target.

signal tapped                      # the player tapped through a read-and-continue beat
signal skip_pressed

const Z_INDEX := 200               # over every scene overlay, including the dealer's
const CANVAS := Vector2(160.0, 320.0)
const BOX_MARGIN := 4.0
const BOX_PAD := Vector2(8.0, 6.0)
const BOX_LINE_H := 8.0
const FONT_SIZE := 5
const RING_INSET := -2.0           # px the ring stands off the control it circles
const RING_WIDTH := 1.0
const MASK_COLOR := Color(0.02, 0.0, 0.05, 0.72)
const RING_COLOR := Color(1.0, 0.86, 0.36)
const TEXT_COLOR := Color(0.95, 0.92, 0.7)
const RING_PULSE_TIME := 0.7
## The SKIP button. Wide enough for the longest label any language gives it — "passer" is
## 16px at this font size, so 30 leaves room without the button reaching the coach box.
const SKIP_SIZE := Vector2(30.0, 12.0)
const SKIP_MARGIN := 4.0   # px between the button and the right edge of the canvas
## YES / NO on the "leave the tutorial?" panel. Wide enough for both languages' words.
const CONFIRM_BUTTON_SIZE := Vector2(44.0, 18.0)

var _font: FontFile = null
var _mask_panels: Array[ColorRect] = []
var _tap_catcher: Control = null
var _box: Control = null
var _label: Label = null
var _skip: Button = null
var _confirm: Control = null       # "leave the tutorial?" — SKIP asks before it acts
var _ring_rect := Rect2()
var _ring_time := 0.0
var _anchor_rect := Rect2()
var _box_side := ""                # "top" | "bottom" | "" (decide from the anchor)

func _ready() -> void:
	name = "TutorialOverlay"
	z_index = Z_INDEX
	size = CANVAS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The tutorial pauses nothing, but scenes that DO pause (the first-launch modal) must
	# not freeze the coaching on top of them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = Assets.font()
	_build()

func _build() -> void:
	for i in 4:
		var panel := ColorRect.new()
		panel.color = MASK_COLOR
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_mask_input)
		add_child(panel)
		_mask_panels.append(panel)
	# Catches taps INSIDE the anchor hole for beats that only want to be read. Sits under
	# nothing — it is enabled only when the beat has no control to hand through.
	_tap_catcher = Control.new()
	_tap_catcher.name = "TapCatcher"
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_catcher.gui_input.connect(_on_mask_input)
	add_child(_tap_catcher)

	_box = Control.new()
	_box.name = "CoachBox"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var bg := Panel.new()
	bg.name = "Panel"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", Assets.neon_panel_style(RING_COLOR))
	_box.add_child(bg)
	_label = Label.new()
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Wrapping is on so a long line breaks INSIDE the box instead of running past its
	# border; _set_text sizes the box for the rows the wrap will produce.
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# _set_text translates and then sizes the box around the result, so the label must NOT
	# translate again — it would be handed French and look for a French key.
	_label.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ANCHORED to the panel instead of resized per beat. A Control clamps an assigned size
	# up to its minimum, and when _set_text ran the label was still holding the PREVIOUS
	# beat's copy: a one-line beat following a two-line one asked for a 10px label, was
	# clamped to the 17px the old two lines still needed, and centred its line 3px below
	# the middle of its own box. Anchors are recomputed from the panel, so every beat gets
	# the same rect regardless of what the last one said.
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	var nudge := Assets.centered_text_nudge(FONT_SIZE)
	_label.offset_left = BOX_PAD.x * 0.5
	_label.offset_top = BOX_PAD.y * 0.5 + nudge
	_label.offset_right = -BOX_PAD.x * 0.5
	_label.offset_bottom = -BOX_PAD.y * 0.5 + nudge
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_constant_override("line_spacing", 3)
	if _font != null:
		_label.add_theme_font_override("font", _font)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 1)
	bg.add_child(_label)

	_skip = Button.new()
	_skip.name = "SkipButton"
	_skip.text = "skip"
	_skip.focus_mode = Control.FOCUS_NONE
	Assets.small_neon_button_style(_skip, Assets.START_MENU_BUTTON_PINK, 5)
	# Above the mask, and alive in every beat: the tutorial must never be a room the
	# player cannot walk out of.
	_skip.z_index = 1
	_skip.pressed.connect(_show_skip_confirm)
	# IN THE TREE BEFORE IT IS SIZED. A Control clamps an assigned size up to its minimum,
	# and a Button outside the tree measures that minimum with the DEFAULT 16px theme font
	# — so this asked for 30x12 and silently became 40x31, hanging six pixels off the right
	# edge of the canvas. In French, where the label is "passer", it became 59 wide and took
	# the last letter off-screen with it, which is why the button read "passe" and looked
	# off-centre: it was centred, in a box half of which was past the edge.
	add_child(_skip)
	_skip.size = SKIP_SIZE
	# Under the machine's authored TABLES plate (which ends around y24), not on top of it,
	# and clear of the coach box: the box is centred and never reaches this column.
	_skip.position = Vector2(CANVAS.x - SKIP_SIZE.x - SKIP_MARGIN, 26.0)

## Leaving is a decision, not a slip. The SKIP button sits over a screen the player is
## tapping through, so it asks before throwing the tutorial away.
func _show_skip_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		return
	_confirm = Control.new()
	_confirm.name = "SkipConfirm"
	_confirm.size = CANVAS
	_confirm.z_index = 2
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.86)
	dim.size = CANVAS
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.add_child(dim)
	var panel_size := Vector2(112.0, 52.0)
	var panel := Panel.new()
	panel.size = panel_size
	panel.position = ((CANVAS - panel_size) * 0.5).round()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Assets.neon_panel_style(RING_COLOR))
	_confirm.add_child(panel)
	var ask := Label.new()
	ask.name = "Ask"
	ask.text = "LEAVE THE TUTORIAL?"
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ask.add_theme_font_size_override("font_size", FONT_SIZE)
	if _font != null:
		ask.add_theme_font_override("font", _font)
	ask.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(ask)
	# Geometry LAST, and clipped: a theme override invalidates the label's minimum size,
	# and a size assigned before the override gets grown back out to fit the text at
	# whatever size it was rendering at — which pushed this question off its own panel.
	ask.clip_text = true
	ask.position = Vector2(4.0, 5.0 + Assets.centered_text_nudge(FONT_SIZE))
	ask.size = Vector2(panel_size.x - 8.0, 14.0)
	var yes := _confirm_button(panel, "YES", Vector2(8.0, 26.0),
		Assets.START_MENU_BUTTON_PINK)
	yes.pressed.connect(func() -> void:
		_dismiss_skip_confirm()
		skip_pressed.emit())
	var no := _confirm_button(panel, "NO",
		Vector2(panel_size.x - 8.0 - CONFIRM_BUTTON_SIZE.x, 26.0),
		Assets.START_MENU_BUTTON_CYAN)
	no.pressed.connect(_dismiss_skip_confirm)

## The caller adds the returned button to the panel, so the rect is applied THERE rather
## than here: sized out of the tree it would be clamped up by the default 16px theme font,
## the same way the SKIP button silently became 40x31. `parent` keeps that ordering in one
## place instead of trusting every call site to remember it.
func _confirm_button(parent: Control, text: String, pos: Vector2, color: Color) -> Button:
	var b := Button.new()
	b.name = text + "Button"
	b.text = text.to_lower()
	b.focus_mode = Control.FOCUS_NONE
	Assets.small_neon_button_style(b, color, 6)
	parent.add_child(b)
	b.size = CONFIRM_BUTTON_SIZE
	b.position = pos
	return b

func _dismiss_skip_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		# Out of the tree first: queue_free alone leaves the dim in place until the end of
		# the frame, and it is MOUSE_FILTER_STOP — the tap that answered NO would be
		# followed by one more the player made and the dead panel swallowed.
		if _confirm.get_parent() != null:
			_confirm.get_parent().remove_child(_confirm)
		_confirm.queue_free()
	_confirm = null

## The beat is waiting for a screen that is not up yet, so the coaching stands down: no
## mask, no box, no ring — but SKIP STAYS. Hiding the whole overlay here was a trap: if the
## screen never came, the player was left with no tutorial UI at all and no way to end a
## tutorial that was still running with their save sealed off behind it.
func show_waiting() -> void:
	visible = true
	_ring_rect = Rect2()
	_anchor_rect = Rect2()
	_layout_mask(Rect2(Vector2.ZERO, CANVAS)) # a hole the size of the screen: no mask
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_catcher.size = Vector2.ZERO
	_box.visible = false
	_dismiss_skip_confirm()
	queue_redraw()

## Shows one beat. `anchor` is the rect to spotlight; `hand_through` decides whether taps
## inside it reach the control or just continue the tutorial.
##
## The spotlight and the input gate are two different things, and conflating them was a
## bug: a read-and-continue beat used to dim the whole screen INCLUDING the control it was
## naming, so "your health" pointed at a health bar as dark as everything around it. The
## hole in the mask is now cut wherever there is an anchor — that is the highlight — and a
## transparent catcher is laid over the top when the beat wants the tap for itself.
## `box_side` ("top" | "bottom", "" = decide from the anchor) is for beats whose anchor is
## the WHOLE screen, where "away from the thing I am pointing at" has no answer: the dealer
## brings his items down from the top of the canvas, so his beat has to say bottom or the
## coaching lands on the two items the player is being asked to choose between.
func show_beat(text: String, anchor: Rect2, hand_through: bool, box_side := "") -> void:
	visible = true
	_box_side = box_side
	_anchor_rect = anchor
	_ring_rect = anchor.grow(-RING_INSET) if anchor.size != Vector2.ZERO else Rect2()
	_ring_time = 0.0
	_dismiss_skip_confirm() # a beat that moves on takes its question with it
	_box.visible = true
	_layout_mask(anchor)
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE if hand_through \
		else Control.MOUSE_FILTER_STOP
	_tap_catcher.position = Vector2.ZERO
	_tap_catcher.size = Vector2.ZERO if hand_through else CANVAS
	_set_text(text)
	queue_redraw()

## Four panels forming a frame around `hole`; an empty hole collapses them into one sheet.
func _layout_mask(hole: Rect2) -> void:
	if hole.size == Vector2.ZERO:
		for i in _mask_panels.size():
			_mask_panels[i].position = Vector2.ZERO
			_mask_panels[i].size = CANVAS if i == 0 else Vector2.ZERO
		return
	var left := maxf(0.0, hole.position.x)
	var top := maxf(0.0, hole.position.y)
	var right := minf(CANVAS.x, hole.position.x + hole.size.x)
	var bottom := minf(CANVAS.y, hole.position.y + hole.size.y)
	_place(_mask_panels[0], Rect2(0.0, 0.0, CANVAS.x, top))                          # above
	_place(_mask_panels[1], Rect2(0.0, bottom, CANVAS.x, CANVAS.y - bottom))         # below
	_place(_mask_panels[2], Rect2(0.0, top, left, bottom - top))                     # left
	_place(_mask_panels[3], Rect2(right, top, CANVAS.x - right, bottom - top))       # right

func _place(panel: ColorRect, rect: Rect2) -> void:
	panel.position = rect.position
	panel.size = Vector2(maxf(0.0, rect.size.x), maxf(0.0, rect.size.y))

## The box hugs its text (the machine's bubbles do the same) and parks on whichever half of
## the screen the ringed control is NOT on, so the coaching never covers what it points at.
func _set_text(source: String) -> void:
	# Translated HERE, once, and the label's own auto-translation is off (see _build): this
	# box sizes itself from the string it measures, so measuring the English while Godot
	# drew the French would size every box for the wrong language. Measure what you draw.
	var text := tr(source)
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var lines := text.split("\n")
	var max_w := CANVAS.x - BOX_MARGIN * 2.0
	var text_w := 0.0
	for line in lines:
		text_w = maxf(text_w, font.get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	# A line too long for the canvas WRAPS, and a wrap adds a row the "one row per authored
	# line" count never saw — which is how a line ends up drawn under the box it belongs
	# to. Count what will actually be rendered, and pin the line spacing the maths assumes.
	var inner := max_w - BOX_PAD.x
	var rows := lines.size()
	if text_w > inner:
		# Let the font do the wrap and report it: counting ceil(width / limit) rows both
		# miscounted (word wrapping breaks early rather than filling each row) and forced
		# the box out to the full canvas width, leaving the copy adrift inside it.
		var wrapped := font.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT_SIZE)
		text_w = minf(inner, wrapped.x)
		rows = maxi(1, roundi(wrapped.y / maxf(1.0, font.get_height(FONT_SIZE))))
	var line_h := maxf(BOX_LINE_H, font.get_height(FONT_SIZE) + 3)
	var box_size := Vector2(
		minf(max_w, text_w + BOX_PAD.x),
		float(rows) * line_h + BOX_PAD.y)
	_box.size = box_size
	var bg := _box.get_node("Panel") as Panel
	bg.size = box_size
	# The label is anchored to the panel (see _build), so it follows this size on its own.
	_label.text = text
	# Default: whichever half the ringed control is NOT on, so the coaching never covers
	# what it points at. A beat may override when its anchor is the whole screen.
	var below := _anchor_rect.size != Vector2.ZERO \
		and _anchor_rect.position.y + _anchor_rect.size.y * 0.5 < CANVAS.y * 0.5
	if _box_side == "bottom":
		below = true
	elif _box_side == "top":
		below = false
	_box.position = Vector2(
		roundf((CANVAS.x - box_size.x) * 0.5),
		CANVAS.y - box_size.y - BOX_MARGIN if below else BOX_MARGIN + 14.0)

func _on_mask_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		tapped.emit()

func _process(delta: float) -> void:
	if _ring_rect.size == Vector2.ZERO:
		return
	_ring_time = fmod(_ring_time + delta, RING_PULSE_TIME)
	queue_redraw()

func _draw() -> void:
	if _ring_rect.size == Vector2.ZERO:
		return
	# A breathing ring rather than a static box: at 160x320 a 1px outline that does not
	# move is easy to miss against the neon behind it.
	var phase := sin(_ring_time / RING_PULSE_TIME * TAU) * 0.5 + 0.5
	var ring := _ring_rect.grow(phase * 1.5)
	draw_rect(ring, Color(RING_COLOR, 0.35 + 0.45 * phase), false, RING_WIDTH)
