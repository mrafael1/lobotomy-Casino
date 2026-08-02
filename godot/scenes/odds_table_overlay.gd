class_name OddsTableOverlay
extends Control

## Dealer odds table (issues #36/#50/#130) — the post-run "what's next?" phase.
## The screen is assembled from authored sheets, each a 120x240 document drawn 1:1 with
## NEAREST and centred on the canvas: ODD-TABLE bakes the per-row symbol boxes, costs.png
## the token price column, ODD-TABLE_tokens the wallet count in the header,
## ODD-TABLE_level each row's 8-segment meter, ODD-TABLE_augment_level the 9th segment only
## the Symbol Level augment can fill, and ODD-TABLE_buttons the per-row +/- with their
## pressed frames.
## Tokens display via the sheet's 0..8 frames: the pool starts at the 4-token
## budget and is capped at 8 kept or used (RunStateStore.odds_max_tokens); the last frame
## is the golden augment token the picker shows instead of a wallet.
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

# Authored sheets. Geometry constants are in document px and reach the canvas through
# CANVAS_FIT (see ART_FRAME_SIZE below).
const ART_DIR := "odd_tab/"
const ART_TABLE := "ODD-TABLE.png"
const ART_BUTTONS := "ODD-TABLE_buttons.png"
const ART_LEVELS := "ODD-TABLE_level.png"
# The 9th level segment, split out of the level meter: frame 0 while the symbol can still
# be raised, frame 2 once it is maxed (frame 1 of the sheet is blank and unused).
const ART_AUGMENT_LEVEL := "ODD-TABLE_augment_level.png"
# The token cost column, split out of the table so the augment picker can hide it: a
# Symbol Level augment charges its own golden token, not the row's price.
const ART_COSTS := "costs.png"
const ART_TOKENS := "ODD-TABLE_tokens.png"
# The authored document. It has the canvas aspect (120x240 is 160x320 x0.75), and the table
# is meant to own the screen, so one frame is stretched to the full canvas: every geometry
# constant below is in document px and reaches the canvas through CANVAS_FIT.
# The sheets themselves may be exported at any integer multiple of the document (the project
# convention is x8, like the other scenes' art). _art_export_scale measures that factor per
# sheet and divides it back out, so a 120x240 and a 960x1920 export land identically.
const ART_FRAME_SIZE := Vector2(120.0, 240.0)
const CANVAS_FIT := SRC_W / ART_FRAME_SIZE.x
# Stretched to the full width the table would reach the bottom edge, leaving the DONE action
# nowhere to go but on top of the last row. Lifting the whole thing buys that room back out
# of the canvas' top margin instead (the same trick the pre-rebuild table used). 12px is the
# most it can rise: the tallest token stack (8 chips) starts at document y9, so anything
# further clips the chips off the top of the screen.
const TABLE_LIFT := Vector2(0.0, -12.0)
const TOKEN_FRAMES := 10 # frames 0..8 = N tokens; frame 9 = the golden augment token
const TOKEN_GOLDEN_FRAME := 9
const TOKEN_SPENT_FRAME := 0 # the picker's golden token, staged onto a symbol
# Bought-row flash (issue #132): overdriven so it reads on the table's own colours.
const ROW_HIGHLIGHT_TINT := Color(2.0, 2.4, 1.6)
const ROW_HIGHLIGHT_HOLD := 0.18
const ROW_HIGHLIGHT_FADE := 0.45
const LEVEL_FRAMES := 9  # frame N = level N, 0..8
const AUGMENT_LEVEL_FRAME_ADDED := 0 # augment level bought, symbol not at the cap yet
const AUGMENT_LEVEL_FRAME_NONE := 1  # blank: this symbol has no augment level
const AUGMENT_LEVEL_FRAME_MAXED := 2 # augment level bought and the symbol is maxed

# Measured from the art (frame 0). The rows run on an even 32/31px pitch and every row
# shares one set of rects, offset down the sheet.
const ROW_OFFSETS := [0.0, 32.0, 64.0, 95.0, 126.0, 157.0]
const BTN_PLUS_RECT := Rect2(82.0, 45.0, 19.0, 10.0)
const BTN_MINUS_Y_OFFSET := 11.0
const LEVEL_ROW_RECT := Rect2(43.0, 51.0, 33.0, 13.0)
const AUGMENT_LEVEL_ROW_RECT := Rect2(74.0, 51.0, 6.0, 13.0)
# Symbol box baked into the table art (the row's coloured square): the symbol renders
# inside it, a little smaller so it clears the outline.
const SYMBOL_BOX_CENTER := Vector2(28.0, 55.5)
const SYMBOL_HIT_SIZE := Vector2(24.0, 23.0)
const ODD_ICON_SIZE := 18.0
# Issue #153: per-row "i" button under the level meter (hold to peek the live
# draw chance) plus a transient percentage-delta bubble on +/- presses. The "i"
# icon is the authored one from the score-table information sheet.
const INFO_ICON_ART := "TABLE/TABLES SCORE_information.png"
const INFO_ICON_SRC := Rect2(1032.0, 408.0, 56.0, 56.0)
# The band between the meter's bottom (document y64) and the row panel's bottom border (y69)
# is 5px, so the icon is 4px with no gap: it centres at y66 and clears the border. Bigger
# and it overlaps the row outline. The hit box is wider than the glyph so it stays tappable.
const INFO_ICON_SIZE := 4.0
const INFO_ICON_GAP := 0.0
const INFO_HIT_SIZE := Vector2(10.0, 6.0)
# Delta bubble centre (art px + row offset): the free patch inside each row panel between
# the cost digit (x57..61) and the + button (x82..100).
const DELTA_ANCHOR := Vector2(71.0, 55.0)
const DELTA_POPUP_RISE := 6.0
const DELTA_POPUP_TIME := 0.9
# DONE hangs off the lifted table's bottom frame (document y239), filling the strip the lift
# opened up at the bottom of the canvas.
const DONE_BUTTON_SIZE := Vector2(44.0, 12.0)
const DONE_BUTTON_Y := 239.0 * CANVAS_FIT + TABLE_LIFT.y

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
var _augment_level_sprites := {} # symbol -> Sprite2D (the 9th, augment-only segment)
var _info_buttons := {}     # symbol -> Button ("i" under the level meter, #153)
var _delta_anchors := {}    # symbol -> Vector2 (delta-bubble center, source px)
var _pct_popup: Control = null
var _delta_popup: Control = null
# Symbol Level augment picker (dealer scene): the same authored table, but with
# no token wallet, "+" as the pick action (up to the level-9 hard cap), and no
# odds-phase transaction — the dealer commits the purchase on symbol_picked.
var _augment_mode := false
## Augment mode only: the symbol currently marked to receive the level. Nothing is charged
## until the action button confirms it, so this is the picker's staged state.
var _augment_pick := ""
var _done_button: Button = null

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

## Flashes one symbol's row (issue #132): the payoff for a Symbol Level buy is a line in
## this table, so the purchase points at it instead of leaving the player to spot the
## changed meter. Cosmetic and guarded — an unknown symbol or a table that has not built
## its rows yet simply does nothing.
func highlight_symbol_row(symbol_id: String) -> void:
	var targets: Array[Sprite2D] = []
	for source in [_level_sprites, _augment_level_sprites, _symbol_icons]:
		var spr := (source as Dictionary).get(symbol_id) as Sprite2D
		if spr != null and is_instance_valid(spr):
			targets.append(spr)
	if targets.is_empty():
		return
	for spr in targets:
		spr.modulate = ROW_HIGHLIGHT_TINT
		var tw := create_tween()
		tw.tween_interval(ROW_HIGHLIGHT_HOLD)
		tw.tween_property(spr, "modulate", Color.WHITE, ROW_HIGHLIGHT_FADE) \
			.set_trans(Tween.TRANS_SINE)

## Re-reads the live levels. The dealer calls this after a Symbol Level augment so
## an odds table still on screen shows the level it just paid for.
func refresh_levels() -> void:
	if _level_sprites.is_empty():
		return
	_hide_pct_popup()
	_refresh()

func _close() -> void:
	# Closing finalizes: staged purchases become permanent, leftover tokens are
	# banked for the next odds menu, and the screen locks until the next run.
	_hide_pct_popup()
	if _augment_mode:
		# The picker's action button confirms the staged pick, exactly like DONE commits the
		# odds phase; with nothing staged it is still a plain cancel. The dealer charges and
		# applies the level on symbol_picked, so that path must not also emit `closed`.
		visible = false
		if _augment_pick != "":
			symbol_picked.emit(_augment_pick)
			return
		closed.emit()
		return
	RunStateStore.finalize_odds_phase()
	visible = false
	closed.emit()

## Document px -> canvas px: the single conversion every measured constant goes through.
func _canvas_pos(doc: Vector2) -> Vector2:
	return doc * CANVAS_FIT + TABLE_LIFT


## How many sheet pixels one authored document pixel occupies — 1 for a native export, 8
## for the project's x8 convention. Measured from the height so a mixed set of sheets can
## never be drawn at the wrong size.
func _art_export_scale(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var raw := float(tex.get_height()) / ART_FRAME_SIZE.y
	var factor := maxf(1.0, round(raw))
	# A non-integer factor means the sheet is not this document: say so instead of drawing
	# the table at a silently wrong size.
	if absf(raw - factor) > 0.01:
		push_warning("Odds table sheet is %dpx tall, not an integer multiple of the %dpx document — update ART_FRAME_SIZE."
			% [tex.get_height(), int(ART_FRAME_SIZE.y)])
	return factor

## Whole-frame sheet sprite, stretched to the full canvas: the export factor cancels out, so
## a x1 and a x8 sheet of the same document render the same.
func _sheet_sprite(rel: String, hframes: int, frame: int) -> Sprite2D:
	var tex := Assets.texture(ART_DIR + rel, false)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	spr.position = TABLE_LIFT
	spr.scale = Vector2.ONE * (CANVAS_FIT / _art_export_scale(tex))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr

## Region sprite cropping `rect` (frame-0 document px) out of a sheet; `frame` selects that
## frame's copy of the same rect. It lands where that patch of the stretched table sits.
func _region_sprite(rel: String, rect: Rect2, frame: int) -> Sprite2D:
	var tex := Assets.texture(ART_DIR + rel, false)
	if tex == null:
		return null
	var art_scale := _art_export_scale(tex)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.region_enabled = true
	spr.set_meta(&"art_scale", art_scale)
	spr.region_rect = Rect2(
		(rect.position + Vector2(ART_FRAME_SIZE.x * float(frame), 0.0)) * art_scale,
		rect.size * art_scale)
	spr.position = _canvas_pos(rect.position)
	spr.scale = Vector2.ONE * (CANVAS_FIT / art_scale)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr

## Points a region sprite at another frame's copy of its rect. `base_x` is in document px.
func _set_region_frame(spr: Sprite2D, base_x: float, frame: int) -> void:
	if spr == null:
		return
	var art_scale: float = spr.get_meta(&"art_scale", 1.0)
	var r := spr.region_rect
	r.position.x = (base_x + ART_FRAME_SIZE.x * float(frame)) * art_scale
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
	_augment_level_sprites.clear()
	_info_buttons.clear()
	_delta_anchors.clear()
	_delta_popup = null
	_done_button = null # freed with the children above; rebuilt at the end of this pass

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.size = Vector2(SRC_W, SRC_H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_sheet_sprite(ART_TABLE, 1, 0)
	# The augment picker spends no tokens per row, so the cost column steps aside and the
	# wallet shows the one golden token the augment itself is worth.
	if not _augment_mode:
		_sheet_sprite(ART_COSTS, 1, 0)
	_tokens_sprite = _sheet_sprite(ART_TOKENS, TOKEN_FRAMES,
		TOKEN_GOLDEN_FRAME if _augment_mode else 0)

	for i in Symbols.BASE_SYMBOL_CYCLE.size():
		_build_row(String(Symbols.BASE_SYMBOL_CYCLE[i]), i)

	var done := Button.new()
	_done_button = done
	done.text = _action_button_text()
	done.position = Vector2((SRC_W - DONE_BUTTON_SIZE.x) * 0.5, DONE_BUTTON_Y)
	done.z_index = 4
	done.add_theme_font_size_override("font_size", 5)
	if _font != null:
		done.add_theme_font_override("font", _font)
	ButtonKit.small_neon_button_style(done, ButtonKit.START_MENU_BUTTON_CYAN, 5, 2.0)
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
	var row_offset: float = float(ROW_OFFSETS[row])

	var icon := _add_symbol_icon(symbol_id,
		_canvas_pos(SYMBOL_BOX_CENTER + Vector2(0.0, row_offset)))
	_symbol_icons[symbol_id] = icon
	_symbol_buttons[symbol_id] = _build_symbol_button(symbol_id, row_offset, icon)

	var level_rect := Rect2(LEVEL_ROW_RECT.position + Vector2(0.0, row_offset), LEVEL_ROW_RECT.size)
	_level_sprites[symbol_id] = _region_sprite(ART_LEVELS, level_rect, 0)
	# The 9th segment rides on its own sheet, immediately right of the meter.
	_augment_level_sprites[symbol_id] = _region_sprite(ART_AUGMENT_LEVEL,
		Rect2(AUGMENT_LEVEL_ROW_RECT.position + Vector2(0.0, row_offset),
			AUGMENT_LEVEL_ROW_RECT.size), AUGMENT_LEVEL_FRAME_NONE)
	_info_buttons[symbol_id] = _build_info_button(symbol_id, level_rect)
	_delta_anchors[symbol_id] = _canvas_pos(DELTA_ANCHOR + Vector2(0.0, row_offset))

	var plus_rect := Rect2(BTN_PLUS_RECT.position + Vector2(0.0, row_offset), BTN_PLUS_RECT.size)
	var minus_rect := Rect2(plus_rect.position + Vector2(0.0, BTN_MINUS_Y_OFFSET), plus_rect.size)
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
	icon.scale = Vector2.ONE \
		* (ODD_ICON_SIZE * CANVAS_FIT / float(maxi(tex.get_width(), tex.get_height())))
	icon.set_meta("rest_scale", icon.scale)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.z_index = 2
	add_child(icon)
	return icon

## Invisible hit area over a symbol box: squash-and-pop tactile feedback only.
## The draw-chance peek moved to the "i" button under the level meter (#153).
func _build_symbol_button(symbol_id: String, row_offset: float, icon: Sprite2D) -> Button:
	var b := Button.new()
	b.name = "SymbolButton_%s" % symbol_id
	b.position = _canvas_pos(SYMBOL_BOX_CENTER - SYMBOL_HIT_SIZE * 0.5 + Vector2(0.0, row_offset))
	b.size = SYMBOL_HIT_SIZE * CANVAS_FIT
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
func _build_info_button(symbol_id: String, level_rect: Rect2) -> Button:
	var center := _canvas_pos(Vector2(level_rect.get_center().x,
		level_rect.end.y + INFO_ICON_GAP + INFO_ICON_SIZE * 0.5))
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
		icon.scale = Vector2.ONE * (INFO_ICON_SIZE * CANVAS_FIT / INFO_ICON_SRC.size.x)
		icon.set_meta("rest_scale", icon.scale)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.z_index = 2
		add_child(icon)
	var b := Button.new()
	b.name = "InfoButton_%s" % symbol_id
	b.position = center - INFO_HIT_SIZE * CANVAS_FIT * 0.5
	b.size = INFO_HIT_SIZE * CANVAS_FIT
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
func _hit_button(rect: Rect2, symbol_id: String, is_plus: bool) -> Button:
	var b := Button.new()
	b.position = _canvas_pos(rect.position)
	b.size = rect.size * CANVAS_FIT
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3
	for state in [&"normal", &"pressed", &"hover", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art: Sprite2D = _plus_art[symbol_id] if is_plus else _minus_art[symbol_id]
	var pressed_frame := 1 if is_plus else 2
	var base_x := rect.position.x
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
	# fixed insets left the text visibly off-centre). Inset from the TOP by twice the
	# cap-height nudge: that moves the rect's centre — and so the glyphs — down by one
	# without letting the label hang past the bubble it belongs to. Godot centres the
	# font's ascent+descent box, and a percentage never uses the descent, so it renders
	# a pixel high without this.
	var nudge := Assets.centered_text_nudge(5)
	label.position = Vector2(0.0, nudge * 2.0)
	label.size = Vector2(popup_size.x, popup_size.y - nudge * 2.0)
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
	# Re-asserted once the label is in the tree: out of the tree a Label measures its own
	# minimum with the default 16px theme font and the size above gets clamped up to it.
	label.set_deferred("size", Vector2(popup_size.x, popup_size.y - nudge * 2.0))
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

## A symbol's current draw chance (percent) with every level that the reels
## actually roll on applied — persisted, staged this phase, and bought as a Symbol
## Level augment — the same additive weight layering Evaluate._build_weights uses,
## minus run-only modifiers (book/brain boosts). Both modes read the same level:
## an augment is live from the moment it is bought, so the odds phase must not
## keep quoting the pre-augment chance. The machine scene's score table duplicates
## this math (autoloads are unreachable from static funcs, so it can't be shared
## as a static helper).
func _symbol_percent(symbol_id: String) -> float:
	var total := 0.0
	var weight := 0.0
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		var s := String(sym)
		var w := float(int(Symbols.WEIGHT[s])
			+ RunStateStore.effective_symbol_level(s)
				* RunStateStore.probability_increase_per_upgrade)
		total += w
		if s == symbol_id:
			weight = w
	return (weight / total) * 100.0 if total > 0.0 else 0.0

func _on_plus_pressed(symbol_id: String) -> void:
	if _augment_mode:
		# Staged, not committed: the picker behaves like the odds phase — "+" marks the
		# symbol, "-" takes it back, and the action button confirms. The token is spent
		# the moment it is staged, so _refresh closes every "+" behind this one; changing
		# your mind goes through "-" rather than a second "+".
		_augment_pick = symbol_id
		_refresh()
		return
	var before := _symbol_percent(symbol_id)
	if RunStateStore.buy_odds_upgrade(symbol_id):
		_refresh()
		_show_delta_popup(symbol_id, _symbol_percent(symbol_id) - before)

func _on_minus_pressed(symbol_id: String) -> void:
	if _augment_mode:
		if _augment_pick == symbol_id:
			_augment_pick = ""
			_refresh()
		return
	var before := _symbol_percent(symbol_id)
	if RunStateStore.undo_odds_upgrade(symbol_id):
		_refresh()
		_show_delta_popup(symbol_id, _symbol_percent(symbol_id) - before)

## DONE commits: the odds phase's staged purchases, or the picker's staged symbol. With
## nothing staged the picker's button is still the way out, so it reads CANCEL.
func _action_button_text() -> String:
	if not _augment_mode:
		return "DONE"
	return "DONE" if _augment_pick != "" else "CANCEL"

func _refresh() -> void:
	if _done_button != null and is_instance_valid(_done_button):
		_done_button.text = _action_button_text()
	# Token wallet on the sheet's 0..8 frames — the pool itself is capped at odds_max_tokens
	# (8) by the store, so the art can always show it. The augment picker instead holds the
	# golden token on the last frame: one token, any symbol, one level.
	if _tokens_sprite != null:
		if _augment_mode:
			# The picker holds exactly one golden token. Staging a pick spends it on the
			# spot — the wallet drops to zero — so the player can see WHAT the "+" cost
			# before confirming, and taking the pick back hands it straight back.
			_tokens_sprite.frame = TOKEN_SPENT_FRAME if _augment_pick != "" \
				else TOKEN_GOLDEN_FRAME
		else:
			_tokens_sprite.frame = clampi(RunStateStore.oddsTokensRemaining, 0, TOKEN_FRAMES - 2)
	for symbol_id in _level_sprites:
		# `level` is what the reels actually roll on (persisted + staged + augment); the METER
		# only ever draws the bought track, because an augment level is not a bar segment —
		# it is the special 9th one on its own sheet below.
		var level := RunStateStore.effective_symbol_level(String(symbol_id))
		var purchase_level := RunStateStore.odds_upgrade_level(String(symbol_id))
		var spr := _level_sprites[symbol_id] as Sprite2D
		if spr != null:
			_set_region_frame(spr, LEVEL_ROW_RECT.position.x,
				clampi(purchase_level, 0, LEVEL_FRAMES - 1))
		# The 9th segment, which only the Symbol Level augment can fill: blank until this
		# symbol has its augment level (or the picker has one staged on it), then the added
		# segment, then the maxed one once the symbol is at the hard cap.
		var augment_levels := RunStateStore.symbol_augment_levels(String(symbol_id))
		var staged := _augment_mode and _augment_pick == String(symbol_id)
		var augment_frame := AUGMENT_LEVEL_FRAME_NONE
		if augment_levels > 0 or staged:
			augment_frame = AUGMENT_LEVEL_FRAME_MAXED \
				if level >= ChipAugments.SYMBOL_LEVEL_HARD_CAP else AUGMENT_LEVEL_FRAME_ADDED
		_set_region_frame(_augment_level_sprites.get(symbol_id) as Sprite2D,
			AUGMENT_LEVEL_ROW_RECT.position.x, augment_frame)
		var plus := _plus_buttons.get(symbol_id) as Button
		if plus != null:
			if _augment_mode:
				# One augment level per symbol: a symbol that already spent one is out,
				# even if it still has room under the hard cap. And once the golden token
				# is staged there is nothing left to spend, so EVERY "+" closes — the
				# picked symbol's included. Moving the pick means taking it back with "-"
				# first, which is the only enabled control left and cannot be misread.
				plus.disabled = _augment_pick != "" \
					or String(symbol_id) == "flatline" \
					or level >= ChipAugments.SYMBOL_LEVEL_HARD_CAP \
					or augment_levels >= ChipAugments.AUGMENT_LEVELS_PER_SYMBOL
			else:
				plus.disabled = purchase_level >= RunStateStore.odds_max_level \
					or level >= ChipAugments.SYMBOL_LEVEL_HARD_CAP \
					or RunStateStore.odds_token_cost(String(symbol_id)) > RunStateStore.oddsTokensRemaining
			_dim_button_art(_plus_art.get(symbol_id) as Sprite2D, plus.disabled)
		# The picker's "-" takes the staged mark back off this symbol.
		if _augment_mode:
			var picker_minus := _minus_buttons.get(symbol_id) as Button
			if picker_minus != null:
				picker_minus.disabled = _augment_pick != String(symbol_id)
				_dim_button_art(_minus_art.get(symbol_id) as Sprite2D, picker_minus.disabled)
			continue
		var minus := _minus_buttons.get(symbol_id) as Button
		if minus != null:
			minus.disabled = _augment_mode \
				or int(RunStateStore.oddsPendingUpgrades.get(symbol_id, 0)) <= 0
			_dim_button_art(_minus_art.get(symbol_id) as Sprite2D, minus.disabled)

## Disabled buttons dim their baked art so the state reads without a stylebox.
func _dim_button_art(spr: Sprite2D, disabled: bool) -> void:
	if spr != null:
		spr.modulate = Color(0.45, 0.45, 0.5) if disabled else Color.WHITE
