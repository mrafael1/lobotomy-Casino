class_name OddsTableOverlay
extends Control

## Dealer odds table (issues #36/#50/#130) — the post-run "what's next?" phase.
## Issue #130 rebuilt the screen on the authored ODD-TABLE sheets (x6 full-canvas
## frames): the table background bakes the per-row symbol boxes and token costs,
## ODD-TABLE_tokens shows the wallet count (digit + chip stack) in the header,
## ODD-TABLE_levels renders each row's 8-segment level meter, and
## ODD-TABLE_buttons carries the per-row +/- buttons with pressed frames.
## Tokens display via the sheet's 0..8 frames: the pool starts at the 4-token
## budget and is capped at 8 kept or used (RunStateStore.odds_max_tokens).
## Issue #153: each row carries an "i" button under its level meter — holding it
## peeks the symbol's live draw chance — and +/- presses pop a transient
## percentage-delta bubble so the odds change reads immediately.
## Purchases are staged and undoable (-/+) while the screen is open; DONE commits
## them through RunStateStore.finalize_odds_phase() and locks the screen until the
## next run. All purchases go through RunStateStore, so the parity-locked base
## weights in Symbols are never touched (see Evaluate._build_weights).

signal closed
## Augment-picker mode only: the player chose the symbol to level up.
signal symbol_picked(symbol_id: String)

const SRC_W := 160.0
const SRC_H := 320.0

# Authored sheets (issue #130): x6 full-canvas frames, 960x1920 each.
const ART_DIR := "odd_tab/"
const ART_TABLE := "ODD-TABLE.png"
const ART_BUTTONS := "ODD-TABLE_buttons.png"
const ART_LEVELS := "ODD-TABLE_levels.png"
const ART_TOKENS := "ODD-TABLE_tokens.png"
const ART_SCALE := 6.0
const ART_FRAME_W := 960.0
const TOKEN_FRAMES := 9  # frame N = N tokens, 0..8

# Measured opaque bounds of the sheets (image px, frame 0). The authored sheets
# tighten the pitch after the third row, so keeping these offsets explicit avoids
# cutting into the syringe, vial, and flatline art.
const ROW_OFFSETS_IMG := [0.0, 256.0, 512.0, 760.0, 1008.0, 1256.0]
const BTN_PLUS_IMG := Rect2(656.0, 360.0, 152.0, 80.0)
const BTN_MINUS_Y_OFFSET_IMG := 88.0
const LEVEL_ROW_IMG := Rect2(344.0, 408.0, 264.0, 104.0)
const LEVEL_LAST_ROW_IMG := Rect2(336.0, 1664.0, 264.0, 104.0)
# Lift the authored table slightly so the final row and the DONE action have
# breathing room on the compact canvas. The dimmer remains full-screen.
const TABLE_Y_OFFSET := -8.0
# Measured outer frame of the authored modal, used to align the DONE action.
const MODAL_FRAME_RECT := Rect2(8.0, 20.0, 144.0, 299.0)
const SYMBOL_HIT_SIZE := Vector2(32.0, 32.0)
# Issue #153: per-row "i" button under the level meter (hold to peek the live
# draw chance) plus a transient percentage-delta bubble on +/- presses. The "i"
# icon is the authored one from the score-table information sheet, sized to the
# 40 img px gap between the meter and the row's bottom border.
const INFO_ICON_ART := "TABLE/TABLES SCORE_information.png"
const INFO_ICON_SRC := Rect2(1032.0, 408.0, 56.0, 56.0)
const INFO_ICON_IMG_SIZE := 36.0
const INFO_ICON_GAP_IMG := 2.0
const INFO_HIT_SIZE := Vector2(14.0, 10.0)
# Delta bubble center (frame-0 image px + row offset): the free patch inside
# each row panel between the cost digit and the + button.
const DELTA_ANCHOR_IMG := Vector2(576.0, 380.0)
const DELTA_POPUP_RISE := 6.0
const DELTA_POPUP_TIME := 0.9
# Symbol box baked into the table art (source px): the selected symbol renders
# inside it, scaled down slightly so it clears the box outline.
const SYMBOL_BOX_CENTER := Vector2(37.3, 73.3)
const ODD_ICON_SIZE := 24.0
const DONE_BUTTON_SIZE := Vector2(44.0, 12.0)
const DONE_BUTTON_Y := MODAL_FRAME_RECT.position.y + MODAL_FRAME_RECT.size.y \
	+ TABLE_Y_OFFSET - DONE_BUTTON_SIZE.y * 0.5 - 10.0

# These are the opaque row colors in ODD-TABLE.png. Flatline has no colored
# border, so its waveform red is used for the live percentage.
const SYMBOL_PERCENT_COLORS := {
	"brain": Color("#e86a73"),
	"eye": Color("#ce3dde"),
	"pill": Color("#e3e6ff"),
	"syringe": Color("#f9a31b"),
	"vial": Color("#b4202a"),
	"flatline": Color("#8f0d16"),
}

@export_group("Odds Table Colors")
@export var percent_color: Color = Color(0.0, 0.9, 1.0)

var _font: FontFile = null
var _tokens_sprite: Sprite2D = null
var _plus_buttons := {}     # symbol -> Button (invisible hit area over the art)
var _minus_buttons := {}    # symbol -> Button
var _symbol_buttons := {}   # symbol -> Button (pressable symbol box)
var _symbol_icons := {}     # symbol -> Sprite2D
var _plus_art := {}         # symbol -> Sprite2D (region of the buttons sheet)
var _minus_art := {}        # symbol -> Sprite2D
var _level_sprites := {}    # symbol -> Sprite2D (region of the levels sheet)
var _info_buttons := {}     # symbol -> Button ("i" under the level meter, #153)
var _delta_anchors := {}    # symbol -> Vector2 (delta-bubble center, source px)
var _pct_popup: Control = null
var _delta_popup: Control = null
# Symbol Level augment picker (dealer scene): the same authored table, but with
# no token wallet, "+" as the pick action (up to the level-9 hard cap), and no
# odds-phase transaction — the dealer commits the purchase on symbol_picked.
var _augment_mode := false

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 140
	mouse_filter = Control.MOUSE_FILTER_STOP

## Opens the phase: grants banked + fresh tokens (capped at 8), then builds the table.
func open_overlay() -> void:
	RunStateStore.begin_odds_phase()
	_rebuild()
	visible = true

## Opens the table as the Symbol Level augment picker: no tokens, tapping a
## row's "+" picks that symbol (the caller charges and applies the level).
func open_augment_picker() -> void:
	_augment_mode = true
	_rebuild()
	visible = true

func _close() -> void:
	# Closing finalizes: staged purchases become permanent, leftover tokens are
	# banked for the next odds menu, and the screen locks until the next run.
	# Augment mode stages nothing, so its close is a plain cancel.
	_hide_pct_popup()
	if not _augment_mode:
		RunStateStore.finalize_odds_phase()
	visible = false
	closed.emit()

## Full-canvas sheet sprite (dealer-scene pattern): scaled so one frame covers
## the 160x320 canvas exactly.
func _sheet_sprite(rel: String, hframes: int, frame: int) -> Sprite2D:
	var tex := Assets.texture(ART_DIR + rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	spr.position = Vector2(0.0, TABLE_Y_OFFSET)
	var frame_w := float(tex.get_width()) / float(hframes)
	spr.scale = Vector2(SRC_W / frame_w, SRC_H / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	return spr

## Region sprite cropping `rect_img` (frame-0 image px) out of a sheet; `frame`
## selects that frame's copy of the same rect. Placed at the source-px position.
func _region_sprite(rel: String, rect_img: Rect2, frame: int) -> Sprite2D:
	var tex := Assets.texture(ART_DIR + rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = Rect2(rect_img.position + Vector2(ART_FRAME_W * float(frame), 0.0), rect_img.size)
	spr.position = rect_img.position / ART_SCALE + Vector2(0.0, TABLE_Y_OFFSET)
	spr.scale = Vector2.ONE / ART_SCALE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	return spr

## Points a region sprite at another frame's copy of its rect.
func _set_region_frame(spr: Sprite2D, base_x_img: float, frame: int) -> void:
	if spr == null:
		return
	var r := spr.region_rect
	r.position.x = base_x_img + ART_FRAME_W * float(frame)
	spr.region_rect = r

func _rebuild() -> void:
	_hide_pct_popup()
	for child in get_children():
		child.queue_free()
	_plus_buttons.clear()
	_minus_buttons.clear()
	_symbol_buttons.clear()
	_symbol_icons.clear()
	_plus_art.clear()
	_minus_art.clear()
	_level_sprites.clear()
	_info_buttons.clear()
	_delta_anchors.clear()
	_delta_popup = null

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.size = Vector2(SRC_W, SRC_H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_sheet_sprite(ART_TABLE, 1, 0)
	# The augment picker has no chips to spend, so the token wallet stays off.
	_tokens_sprite = null if _augment_mode else _sheet_sprite(ART_TOKENS, TOKEN_FRAMES, 0)

	for i in Symbols.BASE_SYMBOL_CYCLE.size():
		_build_row(String(Symbols.BASE_SYMBOL_CYCLE[i]), i)

	var done := Button.new()
	done.text = "CANCEL" if _augment_mode else "DONE"
	done.position = Vector2((SRC_W - DONE_BUTTON_SIZE.x) * 0.5, DONE_BUTTON_Y)
	done.z_index = 4
	done.add_theme_font_size_override("font_size", 5)
	if _font != null:
		done.add_theme_font_override("font", _font)
	Assets.small_neon_button_style(done, Assets.START_MENU_BUTTON_CYAN, 5, 2.0)
	done.custom_minimum_size = Vector2.ZERO
	done.button_down.connect(_on_done_button_down.bind(done))
	done.button_up.connect(_on_done_button_up.bind(done))
	add_child(done)
	done.size = DONE_BUTTON_SIZE
	done.pivot_offset = DONE_BUTTON_SIZE * 0.5

	_refresh()

## One authored row: the pressable symbol inside the baked box, the level-meter
## region, and invisible hit buttons over the baked +/- art.
func _build_row(symbol_id: String, row: int) -> void:
	var row_offset_img: float = float(ROW_OFFSETS_IMG[row])

	var icon := _add_symbol_icon(symbol_id, SYMBOL_BOX_CENTER + Vector2(0.0,
		row_offset_img / ART_SCALE + TABLE_Y_OFFSET))
	_symbol_icons[symbol_id] = icon
	_symbol_buttons[symbol_id] = _build_symbol_button(symbol_id, row_offset_img, icon)

	var level_rect := LEVEL_LAST_ROW_IMG if row == Symbols.BASE_SYMBOL_CYCLE.size() - 1 \
		else Rect2(LEVEL_ROW_IMG.position + Vector2(0.0, row_offset_img), LEVEL_ROW_IMG.size)
	_level_sprites[symbol_id] = _region_sprite(ART_LEVELS, level_rect, 0)
	_info_buttons[symbol_id] = _build_info_button(symbol_id, level_rect)
	_delta_anchors[symbol_id] = (DELTA_ANCHOR_IMG + Vector2(0.0, row_offset_img)) / ART_SCALE \
		+ Vector2(0.0, TABLE_Y_OFFSET)

	var plus_rect := Rect2(BTN_PLUS_IMG.position + Vector2(0.0, row_offset_img), BTN_PLUS_IMG.size)
	var minus_rect := Rect2(plus_rect.position + Vector2(0.0, BTN_MINUS_Y_OFFSET_IMG), plus_rect.size)
	_plus_art[symbol_id] = _region_sprite(ART_BUTTONS, plus_rect, 0)
	_minus_art[symbol_id] = _region_sprite(ART_BUTTONS, minus_rect, 0)
	# The buttons sheet: frame 0 default, frame 1 "+" pressed, frame 2 "-" pressed.
	_plus_buttons[symbol_id] = _hit_button(plus_rect, symbol_id, true)
	_minus_buttons[symbol_id] = _hit_button(minus_rect, symbol_id, false)

func _add_symbol_icon(symbol_id: String, center: Vector2) -> Sprite2D:
	var tex := Assets.texture("symbols/%s.png" % symbol_id, true)
	if tex == null:
		return null
	var icon := Sprite2D.new()
	icon.texture = tex
	icon.centered = true
	icon.position = center
	# Scaled down slightly so the symbol fits cleanly inside the baked box (#130).
	icon.scale = Vector2.ONE * (ODD_ICON_SIZE / float(maxi(tex.get_width(), tex.get_height())))
	icon.set_meta("rest_scale", icon.scale)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.z_index = 2
	add_child(icon)
	return icon

## Invisible hit area over a symbol box: squash-and-pop tactile feedback only.
## The draw-chance peek moved to the "i" button under the level meter (#153).
func _build_symbol_button(symbol_id: String, row_offset_img: float, icon: Sprite2D) -> Button:
	var b := Button.new()
	b.name = "SymbolButton_%s" % symbol_id
	b.position = SYMBOL_BOX_CENTER - SYMBOL_HIT_SIZE * 0.5 + Vector2(0.0,
		row_offset_img / ART_SCALE + TABLE_Y_OFFSET)
	b.size = SYMBOL_HIT_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.button_down.connect(_on_symbol_button_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_symbol_button_up.bind(icon))
	add_child(b)
	return b

## The "i" button under a row's level meter (#153): holding it shows that
## symbol's live draw chance, same peek the score-table info buttons offer.
## The icon is cropped from the score-table information sheet and rendered
## through the overlay's shared linear+mipmaps filter.
func _build_info_button(symbol_id: String, level_rect_img: Rect2) -> Button:
	var center := Vector2(level_rect_img.get_center().x,
		level_rect_img.end.y + INFO_ICON_GAP_IMG + INFO_ICON_IMG_SIZE * 0.5) / ART_SCALE \
		+ Vector2(0.0, TABLE_Y_OFFSET)
	var icon: Sprite2D = null
	var tex := Assets.texture(INFO_ICON_ART, true)
	if tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = INFO_ICON_SRC
		icon = Sprite2D.new()
		icon.texture = atlas
		icon.centered = true
		icon.position = center
		icon.scale = Vector2.ONE * (INFO_ICON_IMG_SIZE / INFO_ICON_SRC.size.x / ART_SCALE)
		icon.set_meta("rest_scale", icon.scale)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.z_index = 2
		add_child(icon)
	var b := Button.new()
	b.name = "InfoButton_%s" % symbol_id
	b.position = center - INFO_HIT_SIZE * 0.5
	b.size = INFO_HIT_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.button_down.connect(_on_info_button_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_info_button_up.bind(icon))
	add_child(b)
	return b

func _on_info_button_down(symbol_id: String, button: Button, icon: Sprite2D) -> void:
	_squash_icon(icon)
	_show_pct_popup(symbol_id, button)

func _on_info_button_up(icon: Sprite2D) -> void:
	_pop_icon(icon)
	_hide_pct_popup()

## Invisible hit button over a baked button's art; pressing swaps the art region
## to the sheet's pressed frame for tactile feedback.
func _hit_button(rect_img: Rect2, symbol_id: String, is_plus: bool) -> Button:
	var b := Button.new()
	b.position = rect_img.position / ART_SCALE + Vector2(0.0, TABLE_Y_OFFSET)
	b.size = rect_img.size / ART_SCALE
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3
	for state in [&"normal", &"pressed", &"hover", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art: Sprite2D = _plus_art[symbol_id] if is_plus else _minus_art[symbol_id]
	var pressed_frame := 1 if is_plus else 2
	var base_x := rect_img.position.x
	b.button_down.connect(_set_region_frame.bind(art, base_x, pressed_frame))
	b.button_up.connect(_set_region_frame.bind(art, base_x, 0))
	if is_plus:
		b.pressed.connect(_on_plus_pressed.bind(symbol_id))
	else:
		b.pressed.connect(_on_minus_pressed.bind(symbol_id))
	add_child(b)
	return b

## DONE press feedback: squash while held, pop back on release, then commit.
## The close is deferred until the release tween ends so the tap reads on screen.
func _on_done_button_down(done: Button) -> void:
	done.scale = Vector2.ONE * 0.85
	var tw := create_tween()
	tw.tween_property(done, "scale", Vector2.ONE * 0.9, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_done_button_up(done: Button) -> void:
	var was_click := done.is_hovered()
	var tw := create_tween()
	tw.tween_property(done, "scale", Vector2.ONE, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if was_click:
		tw.finished.connect(_close)

func _on_symbol_button_down(_symbol_id: String, _button: Button, icon: Sprite2D) -> void:
	_squash_icon(icon)

func _on_symbol_button_up(icon: Sprite2D) -> void:
	_pop_icon(icon)

## Shared squash-and-pop press feedback for the symbol and "i" icons.
func _squash_icon(icon: Sprite2D) -> void:
	if icon == null:
		return
	var rest_scale: Vector2 = icon.get_meta("rest_scale", Vector2.ONE)
	icon.scale = rest_scale * 0.7
	var tw := create_tween()
	tw.tween_property(icon, "scale", rest_scale * 0.82, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _pop_icon(icon: Sprite2D) -> void:
	if not is_instance_valid(icon):
		return
	var rest_scale: Vector2 = icon.get_meta("rest_scale", Vector2.ONE)
	var tw := create_tween()
	tw.tween_property(icon, "scale", rest_scale, 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_pct_popup(symbol_id: String, button: Button) -> void:
	_hide_pct_popup()
	_pct_popup = _make_pct_bubble("%.1f%%" % _symbol_percent(symbol_id), symbol_id)
	_pct_popup.name = "PctPopup"
	_pct_popup.position = _popup_pos_above(button, _pct_popup.size)
	add_child(_pct_popup)

## Bubble Control (bg panel + centered label) in a symbol's row colour, sized to
## its text. Shared by the hold-to-peek popup and the +/- delta feedback (#153).
func _make_pct_bubble(text: String, symbol_id: String) -> Control:
	var bubble := Control.new()
	bubble.z_index = 5
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
	var popup_size := Vector2(maxf(text_width + 8.0, 24.0), 14.0)

	var bg_style := StyleBoxFlat.new()
	# Flatline's bubble goes deep black so its dark-red contour and text pop;
	# the other symbols keep the shared dark-violet panel.
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.97) if symbol_id == "flatline" \
		else Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = _percent_color(symbol_id)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.name = "PctBubble"
	bg.add_theme_stylebox_override(&"panel", bg_style)
	bg.size = popup_size
	bg.clip_contents = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(bg)
	var label := Label.new()
	label.name = "PctLabel"
	label.text = text
	# Fill the whole bubble so the centered alignment is symmetric (the old
	# fixed insets left the text visibly off-centre).
	label.position = Vector2.ZERO
	label.size = popup_size
	label.custom_minimum_size = Vector2.ZERO
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 5)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", _percent_color(symbol_id))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	bg.add_child(label)
	label.set_deferred("size", popup_size)
	bubble.size = popup_size
	return bubble

## Bubble position centered above `anchor`, clamped to the canvas and rounded
## (off-grid blurs the pixel font).
func _popup_pos_above(anchor: Button, popup_size: Vector2) -> Vector2:
	var pos := anchor.position + Vector2(anchor.size.x * 0.5 - popup_size.x * 0.5,
		-popup_size.y - 3.0)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup_size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup_size.y - 2.0)
	return pos.round()

## Issue #153: after a staged +/-, a "+x.x%"/"-x.x%" bubble pops inside that
## row's panel (between the cost digit and the + button) and floats away, so
## the odds change reads without holding "i". The tween is owned by the bubble,
## so replacing it mid-flight is safe.
func _show_delta_popup(symbol_id: String, delta: float) -> void:
	if _delta_popup != null:
		_delta_popup.queue_free()
		_delta_popup = null
	if not _delta_anchors.has(symbol_id):
		return
	var bubble := _make_pct_bubble("%+.1f%%" % delta, symbol_id)
	bubble.name = "DeltaPopup"
	var pos := (_delta_anchors[symbol_id] as Vector2) - bubble.size * 0.5
	pos.x = clampf(pos.x, 2.0, SRC_W - bubble.size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - bubble.size.y - 2.0)
	bubble.position = pos.round()
	add_child(bubble)
	_delta_popup = bubble
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "position:y", bubble.position.y - DELTA_POPUP_RISE, DELTA_POPUP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bubble, "modulate:a", 0.0, DELTA_POPUP_TIME * 0.6) \
		.set_delay(DELTA_POPUP_TIME * 0.4)
	tw.tween_callback(func() -> void:
		if _delta_popup == bubble:
			_delta_popup = null
		bubble.queue_free())

func _hide_pct_popup() -> void:
	if _pct_popup != null:
		_pct_popup.queue_free()
		_pct_popup = null

func _percent_color(symbol_id: String) -> Color:
	var color: Variant = SYMBOL_PERCENT_COLORS.get(symbol_id, percent_color)
	return color if color is Color else percent_color

## A symbol's current draw chance (percent) with all persisted + staged levels
## applied — the same additive weight layering Evaluate._build_weights uses for
## the reel roll, minus run-only modifiers (book/brain boosts). The machine
## scene's score table duplicates this math (autoloads are unreachable from
## static funcs, so it can't be shared as a static helper).
func _symbol_percent(symbol_id: String) -> float:
	var total := 0.0
	var weight := 0.0
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		var s := String(sym)
		var level := RunStateStore.augment_symbol_level(s) if _augment_mode \
			else RunStateStore.odds_upgrade_level(s)
		var w := float(int(Symbols.WEIGHT[s])
			+ level * RunStateStore.probability_increase_per_upgrade)
		total += w
		if s == symbol_id:
			weight = w
	return (weight / total) * 100.0 if total > 0.0 else 0.0

func _on_plus_pressed(symbol_id: String) -> void:
	if _augment_mode:
		# The pick is the whole transaction — the dealer scene charges and
		# applies the level, so the table hands off without emitting `closed`
		# (that path means cancel).
		_hide_pct_popup()
		visible = false
		symbol_picked.emit(symbol_id)
		return
	var before := _symbol_percent(symbol_id)
	if RunStateStore.buy_odds_upgrade(symbol_id):
		_refresh()
		_show_delta_popup(symbol_id, _symbol_percent(symbol_id) - before)

func _on_minus_pressed(symbol_id: String) -> void:
	var before := _symbol_percent(symbol_id)
	if RunStateStore.undo_odds_upgrade(symbol_id):
		_refresh()
		_show_delta_popup(symbol_id, _symbol_percent(symbol_id) - before)

func _refresh() -> void:
	if _tokens_sprite != null:
		# Token wallet on the sheet's 0..8 frames — the pool itself is capped at
		# odds_max_tokens (8) by the store, so the art can always show it.
		_tokens_sprite.frame = clampi(RunStateStore.oddsTokensRemaining, 0, TOKEN_FRAMES - 1)
	for symbol_id in _level_sprites:
		# Augment mode shows the EFFECTIVE level (persisted + augment levels) and
		# lets "+" push past odds_max_level, up to the level-9 hard cap.
		var level := RunStateStore.augment_symbol_level(String(symbol_id)) if _augment_mode \
			else RunStateStore.odds_upgrade_level(String(symbol_id))
		var spr := _level_sprites[symbol_id] as Sprite2D
		if spr != null:
			var base_x := LEVEL_LAST_ROW_IMG.position.x \
				if String(symbol_id) == String(Symbols.BASE_SYMBOL_CYCLE[Symbols.BASE_SYMBOL_CYCLE.size() - 1]) \
				else LEVEL_ROW_IMG.position.x
			_set_region_frame(spr, base_x, clampi(level, 0, 9))
		var plus := _plus_buttons.get(symbol_id) as Button
		if plus != null:
			if _augment_mode:
				plus.disabled = String(symbol_id) == "flatline" \
					or level >= ChipAugments.SYMBOL_LEVEL_HARD_CAP
			else:
				plus.disabled = level >= RunStateStore.odds_max_level \
					or RunStateStore.odds_token_cost(String(symbol_id)) > RunStateStore.oddsTokensRemaining
			_dim_button_art(_plus_art.get(symbol_id) as Sprite2D, plus.disabled)
		var minus := _minus_buttons.get(symbol_id) as Button
		if minus != null:
			minus.disabled = _augment_mode \
				or int(RunStateStore.oddsPendingUpgrades.get(symbol_id, 0)) <= 0
			_dim_button_art(_minus_art.get(symbol_id) as Sprite2D, minus.disabled)

## Disabled buttons dim their baked art so the state reads without a stylebox.
func _dim_button_art(spr: Sprite2D, disabled: bool) -> void:
	if spr != null:
		spr.modulate = Color(0.45, 0.45, 0.5) if disabled else Color.WHITE
